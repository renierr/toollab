package de.renier.tool_lab

import android.app.Activity
import android.content.Context
import android.os.PowerManager
import android.view.WindowManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Lives as long as the Flutter engine, which can outlive its activity: the
 * partial lock is held on the application context, and the screen-on request
 * is remembered and applied to whichever activity is attached.
 */
class WakeLockHelper(private val context: Context) {
    private val WAKE_LOCK_CHANNEL = "de.renier.tool_lab/wake_lock"
    private var partialWakeLock: PowerManager.WakeLock? = null
    private var activity: Activity? = null
    private var keepScreenOn = false

    fun attach(activity: Activity) {
        this.activity = activity
        applyScreenOn()
    }

    fun detach() {
        activity = null
    }

    fun releasePartial() {
        if (partialWakeLock?.isHeld == true) {
            partialWakeLock?.release()
        }
        partialWakeLock = null
    }

    private fun acquirePartial() {
        if (partialWakeLock == null) {
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            partialWakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "ToolLab::PartialWakeLock"
            )
            partialWakeLock?.setReferenceCounted(false)
        }
        if (partialWakeLock?.isHeld != true) {
            partialWakeLock?.acquire()
        }
    }

    private fun applyScreenOn() {
        val current = activity ?: return
        current.runOnUiThread {
            if (keepScreenOn) {
                current.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            } else {
                current.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            }
        }
    }

    fun registerChannel(messenger: BinaryMessenger) {
        MethodChannel(messenger, WAKE_LOCK_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquirePartial", "acquire" -> {
                        acquirePartial()
                        result.success(true)
                    }
                    "releasePartial", "release" -> {
                        releasePartial()
                        result.success(true)
                    }
                    "acquireFull" -> {
                        keepScreenOn = true
                        applyScreenOn()
                        result.success(true)
                    }
                    "releaseFull" -> {
                        keepScreenOn = false
                        applyScreenOn()
                        result.success(true)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }
}
