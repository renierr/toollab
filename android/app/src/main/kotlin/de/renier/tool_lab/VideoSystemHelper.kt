package de.renier.tool_lab

import android.content.Context
import android.media.AudioManager
import android.media.MediaExtractor
import android.media.MediaFormat
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlin.math.roundToInt

/** Media volume and stream details for the Flutter video player. */
object VideoSystemHelper {
    private const val CHANNEL = "de.renier.tool_lab/video_system"

    fun register(context: Context, messenger: BinaryMessenger) {
        val appContext = context.applicationContext
        val audio = appContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getVolume" -> {
                    val max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    val current = audio.getStreamVolume(AudioManager.STREAM_MUSIC)
                    result.success(if (max > 0) current.toDouble() / max else 0.0)
                }
                "setVolume" -> {
                    val value = (call.argument<Double>("value") ?: 0.0).coerceIn(0.0, 1.0)
                    val max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    audio.setStreamVolume(AudioManager.STREAM_MUSIC, (value * max).roundToInt(), 0)
                    result.success(null)
                }
                "tracks" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("INVALID_ARGS", "path required", null)
                        return@setMethodCallHandler
                    }
                    val main = Handler(Looper.getMainLooper())
                    Thread {
                        val tracks = try {
                            readTracks(path)
                        } catch (e: Exception) {
                            android.util.Log.w("VideoSystem", "tracks failed: ${e.message}")
                            emptyList()
                        }
                        main.post { result.success(tracks) }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun readTracks(path: String): List<Map<String, Any?>> {
        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(path)
            return (0 until extractor.trackCount).map { index ->
                val format = extractor.getTrackFormat(index)
                mapOf(
                    "mime" to format.getStringOrNull(MediaFormat.KEY_MIME),
                    "width" to format.getIntOrNull(MediaFormat.KEY_WIDTH),
                    "height" to format.getIntOrNull(MediaFormat.KEY_HEIGHT),
                    "frameRate" to format.getNumberOrNull(MediaFormat.KEY_FRAME_RATE),
                    "bitrate" to format.getIntOrNull(MediaFormat.KEY_BIT_RATE),
                    "sampleRate" to format.getIntOrNull(MediaFormat.KEY_SAMPLE_RATE),
                    "channels" to format.getIntOrNull(MediaFormat.KEY_CHANNEL_COUNT),
                    "language" to format.getStringOrNull(MediaFormat.KEY_LANGUAGE),
                )
            }
        } finally {
            extractor.release()
        }
    }

    private fun MediaFormat.getStringOrNull(key: String): String? =
        if (containsKey(key)) getString(key) else null

    private fun MediaFormat.getIntOrNull(key: String): Int? =
        if (containsKey(key)) try { getInteger(key) } catch (_: ClassCastException) { null } else null

    // Containers store the frame rate as either an int or a float.
    private fun MediaFormat.getNumberOrNull(key: String): Double? {
        if (!containsKey(key)) return null
        return try {
            getInteger(key).toDouble()
        } catch (_: ClassCastException) {
            try { getFloat(key).toDouble() } catch (_: ClassCastException) { null }
        }
    }
}
