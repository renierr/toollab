package de.renier.tool_lab

import android.app.Activity
import android.content.Context
import android.os.PowerManager
import android.view.WindowManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class WakeLockHelper(private val activity: Activity) {
    private val WAKE_LOCK_CHANNEL = "de.renier.tool_lab/wake_lock"
    private var partialWakeLock: PowerManager.WakeLock? = null

    fun registerChannel(messenger: BinaryMessenger) {
        MethodChannel(messenger, WAKE_LOCK_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquirePartial" -> {
                        if (partialWakeLock == null) {
                            val pm = activity.getSystemService(Context.POWER_SERVICE) as PowerManager
                            partialWakeLock = pm.newWakeLock(
                                PowerManager.PARTIAL_WAKE_LOCK,
                                "ToolLab::PartialWakeLock"
                            )
                            partialWakeLock?.setReferenceCounted(false)
                        }
                        if (partialWakeLock?.isHeld != true) {
                            partialWakeLock?.acquire()
                        }
                        result.success(true)
                    }
                    "releasePartial" -> {
                        if (partialWakeLock?.isHeld == true) {
                            partialWakeLock?.release()
                        }
                        partialWakeLock = null
                        result.success(true)
                    }
                    "acquireFull" -> {
                        activity.runOnUiThread {
                            activity.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            result.success(true)
                        }
                    }
                    "releaseFull" -> {
                        activity.runOnUiThread {
                            activity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            result.success(true)
                        }
                    }
                    "acquire" -> {
                        if (partialWakeLock == null) {
                            val pm = activity.getSystemService(Context.POWER_SERVICE) as PowerManager
                            partialWakeLock = pm.newWakeLock(
                                PowerManager.PARTIAL_WAKE_LOCK,
                                "ToolLab::PartialWakeLock"
                            )
                            partialWakeLock?.setReferenceCounted(false)
                        }
                        if (partialWakeLock?.isHeld != true) {
                            partialWakeLock?.acquire()
                        }
                        result.success(true)
                    }
                    "release" -> {
                        if (partialWakeLock?.isHeld == true) {
                            partialWakeLock?.release()
                        }
                        partialWakeLock = null
                        result.success(true)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }
}
