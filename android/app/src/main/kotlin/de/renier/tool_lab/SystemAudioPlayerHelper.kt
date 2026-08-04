package de.renier.tool_lab

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.audiofx.Visualizer
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * MediaPlayer-backed playback controlled from Dart, so ToolLab's own player UI can
 * handle every format the Android system codecs decode (aac, m4a, opus, wma, ...)
 * instead of handing the file off to a separate full-screen player activity.
 *
 * Position, end-of-stream and (when RECORD_AUDIO is granted) waveform/FFT capture
 * are pushed to Dart over an event channel so the Dart side needs no polling.
 */
class SystemAudioPlayerHelper(private val activity: Activity) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        private const val METHOD_CHANNEL = "de.renier.tool_lab/system_audio"
        private const val EVENT_CHANNEL = "de.renier.tool_lab/system_audio_events"
        private const val TICK_MS = 60L
        private const val PERMISSION_REQUEST_CODE = 1002
    }

    private val handler = Handler(Looper.getMainLooper())
    private var player: MediaPlayer? = null
    private var visualizer: Visualizer? = null
    private var events: EventChannel.EventSink? = null
    private var ticking = false
    private var waveBuffer: ByteArray? = null
    private var fftBuffer: ByteArray? = null

    private val tick = object : Runnable {
        override fun run() {
            if (!ticking) return
            emit(completed = false)
            handler.postDelayed(this, TICK_MS)
        }
    }

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler(this)
        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
        events = sink
    }

    override fun onCancel(arguments: Any?) {
        events = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "load" -> load(call, result)
            "play" -> {
                player?.start()
                startTicking()
                result.success(null)
            }
            "pause" -> {
                player?.takeIf { it.isPlaying }?.pause()
                stopTicking()
                result.success(null)
            }
            "stop" -> {
                // Pause + rewind instead of MediaPlayer.stop(), which would need a
                // fresh prepare() before the next play().
                player?.let {
                    if (it.isPlaying) it.pause()
                    it.seekTo(0)
                }
                stopTicking()
                emit(completed = false)
                result.success(null)
            }
            "seek" -> {
                val positionMs = (call.argument<Number>("positionMs") ?: 0).toInt()
                player?.seekTo(positionMs)
                result.success(null)
            }
            "setVolume" -> {
                val volume = (call.argument<Number>("volume") ?: 1.0).toFloat()
                player?.setVolume(volume, volume)
                result.success(null)
            }
            "setLooping" -> {
                player?.isLooping = call.argument<Boolean>("looping") ?: false
                result.success(null)
            }
            "release" -> {
                releasePlayer()
                result.success(null)
            }
            "hasCapturePermission" -> result.success(hasCapturePermission())
            "requestCapturePermission" -> {
                if (!hasCapturePermission()) {
                    ActivityCompat.requestPermissions(
                        activity,
                        arrayOf(Manifest.permission.RECORD_AUDIO),
                        PERMISSION_REQUEST_CODE,
                    )
                }
                result.success(hasCapturePermission())
            }
            else -> result.notImplemented()
        }
    }

    private fun load(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        if (path == null) {
            result.error("INVALID_ARGS", "path required", null)
            return
        }
        releasePlayer()
        try {
            val created = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build(),
                )
                setDataSource(path)
                setOnCompletionListener {
                    stopTicking()
                    emit(completed = true)
                }
                setOnErrorListener { _, _, _ ->
                    stopTicking()
                    emit(completed = true)
                    true
                }
                prepare()
            }
            player = created
            val visualizerReady = attachVisualizer(created.audioSessionId)
            result.success(
                mapOf(
                    "durationMs" to created.duration.coerceAtLeast(0),
                    "visualizer" to visualizerReady,
                ),
            )
        } catch (e: Exception) {
            releasePlayer()
            result.error("LOAD_ERROR", e.message, null)
        }
    }

    /** Returns true when output capture is available (needs RECORD_AUDIO). */
    private fun attachVisualizer(sessionId: Int): Boolean {
        if (!hasCapturePermission()) return false
        return try {
            val range = Visualizer.getCaptureSizeRange()
            val size = 512.coerceIn(range[0], range[1])
            visualizer = Visualizer(sessionId).apply {
                captureSize = size
                enabled = true
            }
            waveBuffer = ByteArray(size)
            fftBuffer = ByteArray(size)
            true
        } catch (e: Exception) {
            visualizer = null
            waveBuffer = null
            fftBuffer = null
            false
        }
    }

    private fun hasCapturePermission(): Boolean =
        ActivityCompat.checkSelfPermission(activity, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

    private fun startTicking() {
        if (ticking) return
        ticking = true
        handler.post(tick)
    }

    private fun stopTicking() {
        ticking = false
        handler.removeCallbacks(tick)
    }

    private fun emit(completed: Boolean) {
        val sink = events ?: return
        val active = player ?: return
        val position = try {
            active.currentPosition
        } catch (e: IllegalStateException) {
            0
        }
        val payload = mutableMapOf<String, Any?>(
            "positionMs" to position,
            "completed" to completed,
        )
        val effect = visualizer
        if (effect != null && !completed) {
            waveBuffer?.let { if (effect.getWaveForm(it) == Visualizer.SUCCESS) payload["wave"] = it }
            fftBuffer?.let { if (effect.getFft(it) == Visualizer.SUCCESS) payload["fft"] = it }
        }
        sink.success(payload)
    }

    fun releasePlayer() {
        stopTicking()
        visualizer?.let {
            try {
                it.enabled = false
            } catch (e: Exception) {
                // Already released by the framework — nothing to do.
            }
            it.release()
        }
        visualizer = null
        waveBuffer = null
        fftBuffer = null
        player?.let {
            try {
                it.reset()
            } catch (e: Exception) {
                // Reset can throw on an already-invalid player; release still applies.
            }
            it.release()
        }
        player = null
    }
}
