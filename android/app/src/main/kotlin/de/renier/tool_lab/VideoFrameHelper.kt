package de.renier.tool_lab

import android.app.Activity
import android.graphics.Bitmap
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.view.PixelCopy
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
import io.flutter.embedding.android.FlutterSurfaceView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.lang.ref.WeakReference

/** Reads the current frame of the video player's SurfaceView, which Flutter cannot capture. */
object VideoFrameHelper {
    private const val CHANNEL = "de.renier.tool_lab/video_frame"
    private const val MAX_SIDE = 4096

    fun register(activity: Activity, messenger: BinaryMessenger) {
        val ref = WeakReference(activity)
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "capture") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val view = ref.get()?.window?.decorView?.let(::largestVideoSurface)
            if (view == null) {
                result.success(null)
                return@setMethodCallHandler
            }
            val width = call.argument<Int>("width")?.takeIf { it > 0 } ?: view.width
            val height = call.argument<Int>("height")?.takeIf { it > 0 } ?: view.height
            val scale = minOf(1.0, MAX_SIDE.toDouble() / maxOf(width, height))
            capture(view, (width * scale).toInt(), (height * scale).toInt(), result)
        }
    }

    private fun capture(view: SurfaceView, width: Int, height: Int, result: MethodChannel.Result) {
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val thread = HandlerThread("VideoFrameCopy").apply { start() }
        val main = Handler(Looper.getMainLooper())
        try {
            PixelCopy.request(view, bitmap, { status ->
                if (status != PixelCopy.SUCCESS) {
                    bitmap.recycle()
                    thread.quitSafely()
                    main.post { result.error("copy_failed", "PixelCopy status $status", null) }
                    return@request
                }
                val png = ByteArrayOutputStream().use {
                    bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)
                    it.toByteArray()
                }
                bitmap.recycle()
                thread.quitSafely()
                main.post { result.success(png) }
            }, Handler(thread.looper))
        } catch (e: IllegalArgumentException) {
            bitmap.recycle()
            thread.quitSafely()
            result.error("copy_failed", e.message, null)
        }
    }

    private fun largestVideoSurface(root: View): SurfaceView? {
        var best: SurfaceView? = null
        fun visit(view: View) {
            if (view is SurfaceView && view !is FlutterSurfaceView && view.isShown &&
                view.holder.surface.isValid &&
                view.width * view.height > (best?.let { it.width * it.height } ?: 0)
            ) {
                best = view
            }
            if (view is ViewGroup) {
                for (i in 0 until view.childCount) visit(view.getChildAt(i))
            }
        }
        visit(root)
        return best
    }
}
