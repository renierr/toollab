package de.renier.tool_lab

import android.app.Activity
import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.drawable.Icon
import android.os.Build
import android.os.Process
import android.util.Rational
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlin.math.roundToInt

/** Picture-in-picture for the Flutter video player of one activity. */
class VideoPipHelper(private val activity: Activity) {
    companion object {
        private const val CHANNEL = "de.renier.tool_lab/video_pip"
        private const val EXTRA_ACTION = "action"

        // Android rejects aspect ratios outside 1:2.39 .. 2.39:1; rounding stays inside.
        private const val MIN_ASPECT = 0.42
        private const val MAX_ASPECT = 2.39
    }

    private var channel: MethodChannel? = null
    private var enabled = false
    private var playing = false
    private var seekable = false
    private var aspect = Rational(16, 9)
    private var labels: Map<String, String> = emptyMap()
    private var receiverRegistered = false

    // Per process: every tool activity runs in a process of its own.
    private val controlAction = "${activity.packageName}.video_pip.CONTROL.${Process.myPid()}"

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val action = intent?.getStringExtra(EXTRA_ACTION) ?: return
            channel?.invokeMethod("onAction", action)
        }
    }

    private val isSupported: Boolean
        get() = activity.packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)

    fun register(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, CHANNEL).also { it.setMethodCallHandler(::onCall) }
        if (!receiverRegistered) {
            ContextCompat.registerReceiver(
                activity,
                receiver,
                IntentFilter(controlAction),
                ContextCompat.RECEIVER_NOT_EXPORTED,
            )
            receiverRegistered = true
        }
    }

    fun dispose() {
        if (receiverRegistered) {
            try {
                activity.unregisterReceiver(receiver)
            } catch (_: Exception) {}
            receiverRegistered = false
        }
    }

    private fun onCall(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(isSupported)
            "update" -> {
                enabled = call.argument<Boolean>("enabled") ?: false
                playing = call.argument<Boolean>("playing") ?: false
                seekable = call.argument<Boolean>("seekable") ?: false
                call.argument<Double>("aspectRatio")?.let { aspect = toRational(it) }
                call.argument<Map<String, String>>("labels")?.let { labels = it }
                applyParams()
                result.success(null)
            }
            "enter" -> result.success(enter())
            "leave" -> {
                if (activity.isInPictureInPictureMode) activity.moveTaskToBack(true)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /** Before Android 12 the activity enters PiP itself when the user leaves it. */
    fun onUserLeaveHint() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S && enabled && playing) enter()
    }

    /** [stopped]: the user closed the window rather than expanding it. */
    fun onPipModeChanged(inPip: Boolean, stopped: Boolean) {
        channel?.invokeMethod("onPipChanged", inPip)
        if (!inPip && stopped) channel?.invokeMethod("onDismissed", null)
    }

    private fun enter(): Boolean {
        if (!enabled || !isSupported) return false
        return try {
            activity.enterPictureInPictureMode(buildParams())
        } catch (e: IllegalStateException) {
            android.util.Log.w("VideoPip", "enter failed: ${e.message}")
            false
        }
    }

    private fun applyParams() {
        if (!isSupported) return
        try {
            activity.setPictureInPictureParams(buildParams())
        } catch (e: IllegalStateException) {
            android.util.Log.w("VideoPip", "setPictureInPictureParams failed: ${e.message}")
        }
    }

    private fun buildParams(): PictureInPictureParams {
        val builder = PictureInPictureParams.Builder()
            .setAspectRatio(aspect)
            .setActions(if (enabled) remoteActions() else emptyList())
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setAutoEnterEnabled(enabled && playing)
            builder.setSeamlessResizeEnabled(false)
        }
        return builder.build()
    }

    private fun remoteActions(): List<RemoteAction> {
        val actions = mutableListOf<RemoteAction>()
        if (seekable) actions += remoteAction("rewind", android.R.drawable.ic_media_rew)
        actions += if (playing) {
            remoteAction("pause", android.R.drawable.ic_media_pause)
        } else {
            remoteAction("play", android.R.drawable.ic_media_play)
        }
        if (seekable) actions += remoteAction("forward", android.R.drawable.ic_media_ff)
        return actions.take(activity.maxNumPictureInPictureActions)
    }

    private fun remoteAction(name: String, icon: Int): RemoteAction {
        val intent = Intent(controlAction).apply {
            setPackage(activity.packageName)
            putExtra(EXTRA_ACTION, name)
        }
        val pending = PendingIntent.getBroadcast(
            activity,
            name.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val label = labels[name] ?: name
        return RemoteAction(Icon.createWithResource(activity, icon), label, label, pending)
    }

    private fun toRational(ratio: Double): Rational {
        val clamped = ratio.coerceIn(MIN_ASPECT, MAX_ASPECT)
        return Rational((clamped * 10000).roundToInt(), 10000)
    }
}
