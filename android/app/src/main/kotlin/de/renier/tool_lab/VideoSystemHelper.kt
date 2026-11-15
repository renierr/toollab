package de.renier.tool_lab

import android.app.Activity
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.media.MediaExtractor
import android.media.MediaFormat
import android.net.Uri
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.provider.Settings
import android.view.WindowManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlin.math.roundToInt

/** Media volume, window brightness and stream details for the Flutter video player. */
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
                "getBrightness" -> {
                    val window = (context as? Activity)?.window
                    val own = window?.attributes?.screenBrightness ?: -1f
                    result.success(if (own >= 0) own.toDouble() else systemBrightness(appContext))
                }
                "setBrightness" -> {
                    val window = (context as? Activity)?.window
                    if (window == null) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    // No value hands brightness back to the system.
                    val value = call.argument<Double>("value")
                    window.attributes = window.attributes.apply {
                        screenBrightness = value?.coerceIn(0.01, 1.0)?.toFloat()
                            ?: WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                    }
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
                            readTracks(appContext, path)
                        } catch (e: Exception) {
                            android.util.Log.w("VideoSystem", "tracks failed: ${e.message}")
                            emptyList()
                        }
                        main.post { result.success(tracks) }
                    }.start()
                }
                "resolvePath" -> {
                    val uri = call.argument<String>("uri")?.let(Uri::parse)
                    result.success(uri?.let { resolvePath(appContext, it) })
                }
                "persistUri", "releaseUri" -> {
                    val uri = call.argument<String>("uri")?.let(Uri::parse)
                    val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION
                    try {
                        if (uri != null && call.method == "persistUri") {
                            appContext.contentResolver.takePersistableUriPermission(uri, flags)
                        } else if (uri != null) {
                            appContext.contentResolver.releasePersistableUriPermission(uri, flags)
                        }
                    } catch (e: SecurityException) {
                        // Shared URIs come without a persistable grant.
                    }
                    result.success(null)
                }
                "size" -> {
                    val uri = call.argument<String>("uri")?.let(Uri::parse)
                    val size = uri?.let {
                        try {
                            appContext.contentResolver.query(it, arrayOf(OpenableColumns.SIZE), null, null, null)?.use { c ->
                                if (c.moveToFirst() && !c.isNull(0)) c.getLong(0) else null
                            }
                        } catch (e: Exception) {
                            null
                        }
                    }
                    result.success(size)
                }
                else -> result.notImplemented()
            }
        }
    }

    // Assumes the classic 0..255 range; some devices map it non-linearly.
    private fun systemBrightness(context: Context): Double = try {
        Settings.System.getInt(context.contentResolver, Settings.System.SCREEN_BRIGHTNESS) / 255.0
    } catch (e: Settings.SettingNotFoundException) {
        0.5
    }

    /** The file behind a document or media URI, if this app may read it directly. */
    private fun resolvePath(context: Context, uri: Uri): String? {
        val path = try {
            val document = DocumentsContract.isDocumentUri(context, uri)
            val id = if (document) DocumentsContract.getDocumentId(uri) else null
            when {
                id != null && id.startsWith("raw:") -> id.removePrefix("raw:")
                id != null && uri.authority == "com.android.externalstorage.documents" -> {
                    val volume = id.substringBefore(':')
                    val rest = id.substringAfter(':', "")
                    if (volume.equals("primary", ignoreCase = true)) {
                        File(Environment.getExternalStorageDirectory(), rest).path
                    } else {
                        "/storage/$volume/$rest"
                    }
                }
                id != null && uri.authority == "com.android.providers.media.documents" ->
                    id.substringAfter(':').toLongOrNull()?.let {
                        dataColumn(context, ContentUris.withAppendedId(MediaStore.Files.getContentUri("external"), it))
                    }
                document -> null
                uri.authority == MediaStore.AUTHORITY -> dataColumn(context, uri)
                else -> null
            }
        } catch (e: Exception) {
            null
        }
        return path?.takeIf { File(it).let { file -> file.isFile && file.canRead() } }
    }

    @Suppress("DEPRECATION")
    private fun dataColumn(context: Context, uri: Uri): String? =
        context.contentResolver.query(uri, arrayOf(MediaStore.MediaColumns.DATA), null, null, null)?.use { c ->
            if (c.moveToFirst() && !c.isNull(0)) c.getString(0) else null
        }

    private fun readTracks(context: Context, path: String): List<Map<String, Any?>> {
        val extractor = MediaExtractor()
        try {
            if (path.startsWith("content://")) {
                extractor.setDataSource(context, Uri.parse(path), null)
            } else {
                extractor.setDataSource(path)
            }
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
