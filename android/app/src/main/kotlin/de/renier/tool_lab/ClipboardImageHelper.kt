package de.renier.tool_lab

import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

object ClipboardImageHelper {
    private const val CHANNEL = "de.renier.tool_lab/clipboard"
    private const val DIR_NAME = "clipboard"

    // Files the pasteboard plugin left in the cache root and never deleted.
    private val legacyPasteboardFile = Regex("^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}\\.png$")

    fun register(context: Context, messenger: BinaryMessenger) {
        val appContext = context.applicationContext
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "writeImage") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val bytes = call.argument<ByteArray>("bytes")
            val mimeType = call.argument<String>("mimeType")
            if (bytes == null || bytes.isEmpty() || mimeType == null) {
                result.error("bad_args", "Missing image bytes or MIME type.", null)
                return@setMethodCallHandler
            }

            Thread {
                try {
                    val file = writeClipFile(appContext, bytes, mimeType)
                    val uri = FileProvider.getUriForFile(
                        appContext, "${appContext.packageName}.fileprovider", file
                    )
                    val clip = ClipData(
                        ClipDescription(file.name, arrayOf(mimeType)),
                        ClipData.Item(uri),
                    )
                    mainHandler.post {
                        try {
                            val manager = appContext.getSystemService(
                                Context.CLIPBOARD_SERVICE
                            ) as ClipboardManager
                            manager.setPrimaryClip(clip)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("clipboard_error", e.message, null)
                        }
                    }
                } catch (e: Exception) {
                    mainHandler.post { result.error("clipboard_error", e.message, null) }
                }
            }.start()
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    // The clip only references the file, so it must outlive the app session;
    // keeping just the newest file bounds the cache to one image.
    private fun writeClipFile(context: Context, bytes: ByteArray, mimeType: String): File {
        val dir = File(context.cacheDir, DIR_NAME).apply { mkdirs() }
        dir.listFiles()?.forEach { it.delete() }
        context.cacheDir.listFiles { f -> legacyPasteboardFile.matches(f.name) }
            ?.forEach { it.delete() }

        val extension = MimeTypeMap.getSingleton().getExtensionFromMimeType(mimeType) ?: "img"
        // A fresh name per copy, so receivers never serve a cached older image.
        val file = File(dir, "clip_${System.currentTimeMillis()}.$extension")
        file.writeBytes(bytes)
        return file
    }
}
