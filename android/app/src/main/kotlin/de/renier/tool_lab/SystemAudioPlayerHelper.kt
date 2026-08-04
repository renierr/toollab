package de.renier.tool_lab

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.media.audiofx.Visualizer
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * ExoPlayer-backed playback controlled from Dart, so ToolLab's own player UI can
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
    private var player: ExoPlayer? = null
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
                val active = player
                if (active == null) {
                    result.error("NOT_LOADED", "No audio source is loaded", null)
                    return
                }
                active.play()
                startTicking()
                result.success(null)
            }
            "pause" -> {
                player?.pause()
                stopTicking()
                result.success(null)
            }
            "stop" -> {
                player?.let {
                    it.pause()
                    it.seekTo(0L)
                }
                stopTicking()
                emit(completed = false)
                result.success(null)
            }
            "seek" -> {
                val positionMs = (call.argument<Number>("positionMs") ?: 0).toInt()
                player?.seekTo(positionMs.toLong())
                result.success(null)
            }
            "setVolume" -> {
                val volume = (call.argument<Number>("volume") ?: 1.0).toFloat()
                player?.volume = volume
                result.success(null)
            }
            "setLooping" -> {
                player?.repeatMode = if (call.argument<Boolean>("looping") == true) {
                    Player.REPEAT_MODE_ONE
                } else {
                    Player.REPEAT_MODE_OFF
                }
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
        val mimeType = call.argument<String>("mimeType")
        if (path == null) {
            result.error("INVALID_ARGS", "path required", null)
            return
        }
        releasePlayer()
        try {
            val created = ExoPlayer.Builder(activity).build()
            created.apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(C.USAGE_MEDIA)
                        .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
                        .build(),
                    true,
                )
                val sourceUri = android.net.Uri.parse(path).takeIf { it.scheme != null }
                    ?: android.net.Uri.fromFile(java.io.File(path))
                setMediaItem(
                    MediaItem.Builder()
                        .setUri(sourceUri)
                        .setMimeType(mimeType)
                        .build(),
                )
            }
            player = created
            created.addListener(object : Player.Listener {
                var settled = false

                override fun onPlaybackStateChanged(state: Int) {
                    if (state == Player.STATE_READY && !settled) {
                        settled = true
                        val visualizerReady = attachVisualizer(created.audioSessionId)
                        result.success(
                            mapOf(
                                "durationMs" to created.duration.coerceAtLeast(0),
                                "visualizer" to visualizerReady,
                            ),
                        )
                    } else if (state == Player.STATE_ENDED) {
                        stopTicking()
                        emit(completed = true)
                    }
                }

                override fun onPlayerError(error: PlaybackException) {
                    stopTicking()
                    if (!settled) {
                        settled = true
                        releasePlayer()
                        result.error("LOAD_ERROR", error.message, error.errorCodeName)
                    } else {
                        emit(error = "${error.errorCodeName}: ${error.message}")
                    }
                }
            })
            created.prepare()
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

    private fun emit(completed: Boolean = false, error: String? = null) {
        val sink = events ?: return
        val active = player ?: return
        val position = try {
            active.currentPosition
        } catch (e: Exception) {
            0
        }
        val payload = mutableMapOf<String, Any?>(
            "positionMs" to position,
            "completed" to completed,
        )
        if (error != null) payload["error"] = error
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
        player?.release()
        player = null
    }
}
