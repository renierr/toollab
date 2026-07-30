package de.renier.tool_lab

import android.content.Intent
import android.content.pm.PackageManager
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.UUID

open class MainActivity : FlutterActivity() {
    private val SHORTCUTS_CHANNEL = "de.renier.tool_lab/shortcuts"
    private val FOREGROUND_RUNTIME_CHANNEL = "de.renier.tool_lab/foreground_runtime"
    private val FILE_SAVE_CHANNEL = "de.renier.tool_lab/file_save"
    private val FILE_PICKER_CHANNEL = "de.renier.tool_lab/file_picker"
    private val MULTICAST_CHANNEL = "de.renier.tool_lab/multicast"

    private var gpsInfoHelper: GpsInfoHelper? = null
    private var multicastLock: WifiManager.MulticastLock? = null
    private var launchRoute: String? = null
    private var filePickerResult: MethodChannel.Result? = null

    companion object {
        var channel: MethodChannel? = null

        private const val FILE_PICKER_REQUEST_CODE = 7412
        private const val ALIAS_PREFIX = "de.renier.tool_lab."
        private const val ALIAS_SUFFIX = "Alias"

        private fun aliasClassNameToRoute(className: String): String? {
            if (className == "${ALIAS_PREFIX}MainActivity") return null
            if (!className.startsWith(ALIAS_PREFIX)) return null
            val cleanName = className.removePrefix(ALIAS_PREFIX)
            val name = when {
                cleanName.endsWith(ALIAS_SUFFIX) -> cleanName.removeSuffix(ALIAS_SUFFIX)
                cleanName.endsWith("Activity") -> cleanName.removeSuffix("Activity")
                else -> return null
            }
            return "/${name.toKebabCase()}"
        }

        private fun String.toKebabCase(): String =
            replace(Regex("[A-Z]")) { "-${it.value.lowercase()}" }.trimStart('-')
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        resolveLaunchRoute(intent)
        SharingHelper.handleIntent(this, intent, null)
    }

    override fun onNewIntent(intent: Intent) {
        val isMainLauncherIntent = intent.action == Intent.ACTION_MAIN &&
                intent.hasCategory(Intent.CATEGORY_LAUNCHER) &&
                intent.component?.className == "de.renier.tool_lab.MainActivity"
        if (isMainLauncherIntent) {
            return
        }

        super.onNewIntent(intent)
        setIntent(intent)
        val messenger = flutterEngine?.dartExecutor?.binaryMessenger
        resolveLaunchRoute(intent)
        SharingHelper.handleIntent(this, intent, messenger)
        
        launchRoute?.let { route ->
            if (messenger != null) {
                MethodChannel(messenger, SHORTCUTS_CHANNEL).invokeMethod("onShortcutRoute", route)
                launchRoute = null
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != FILE_PICKER_REQUEST_CODE) return

        val result = filePickerResult ?: return
        filePickerResult = null
        if (resultCode != RESULT_OK || data == null) {
            result.success(emptyList<Map<String, String>>())
            return
        }

        val uris = buildList {
            data.clipData?.let { clip ->
                for (index in 0 until clip.itemCount) add(clip.getItemAt(index).uri)
            } ?: data.data?.let(::add)
        }
        Thread {
            try {
                val files = uris.map { uri -> copyPickedFileToCache(uri) }
                runOnUiThread { result.success(files) }
            } catch (e: Exception) {
                runOnUiThread { result.error("PICK_ERROR", e.message, null) }
            }
        }.start()
    }

    private fun copyPickedFileToCache(uri: android.net.Uri): Map<String, String> {
        var name = "file"
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                name = cursor.getString(0) ?: name
            }
        }
        val safeName = name.replace(Regex("[\\\\/:*?\"<>|]"), "_")
        val directory = File(cacheDir, "fast_drop/${UUID.randomUUID()}").apply { mkdirs() }
        val output = File(directory, safeName)
        contentResolver.openInputStream(uri)?.use { input ->
            FileOutputStream(output).use { outputStream ->
                input.copyTo(outputStream, bufferSize = 64 * 1024)
            }
        } ?: throw IllegalStateException("Unable to open selected file")
        return mapOf(
            "path" to output.path,
            "name" to name,
            "mimeType" to (contentResolver.getType(uri) ?: "application/octet-stream"),
        )
    }

    override fun onDestroy() {
        channel = null
        multicastLock?.release()
        multicastLock = null
        gpsInfoHelper?.stopGpsInfoUpdates()
        super.onDestroy()
    }

    private fun resolveLaunchRoute(intent: Intent?) {
        if (intent == null) return
        if (intent.hasExtra("route")) {
            launchRoute = intent.getStringExtra("route")
            return
        }
        val aliasRoute = intent.component?.className?.let { aliasClassNameToRoute(it) }
        if (aliasRoute != null) {
            launchRoute = aliasRoute
            return
        }
        val action = intent.action
        if (action == Intent.ACTION_SEND || action == Intent.ACTION_SEND_MULTIPLE || action == Intent.ACTION_VIEW) {
            // Sharing intent - handled separately via SharingHelper
            return
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, FILE_PICKER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickFiles" -> {
                    if (filePickerResult != null) {
                        result.error("PICK_IN_PROGRESS", "A file picker is already open", null)
                        return@setMethodCallHandler
                    }
                    filePickerResult = result
                    val allowMultiple = call.argument<Boolean>("multiple") ?: false
                    val mimeTypes = call.argument<List<String>>("mimeTypes") ?: emptyList()
                    startActivityForResult(
                        Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, allowMultiple)
                            if (mimeTypes.isNotEmpty()) {
                                putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes.toTypedArray())
                            }
                        },
                        FILE_PICKER_REQUEST_CODE,
                    )
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, MULTICAST_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    if (enabled) {
                        val wifiManager = applicationContext.getSystemService(WIFI_SERVICE) as WifiManager
                        if (multicastLock == null) {
                            multicastLock = wifiManager.createMulticastLock("tool_lab_fast_drop").apply {
                                setReferenceCounted(false)
                            }
                        }
                        multicastLock?.takeIf { !it.isHeld }?.acquire()
                    } else {
                        multicastLock?.takeIf { it.isHeld }?.release()
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Register custom helpers
        SharingHelper.registerChannel(messenger)
        
        val wakeLockHelper = WakeLockHelper(this)
        wakeLockHelper.registerChannel(messenger)

        val gps = GpsInfoHelper(this)
        gpsInfoHelper = gps
        gps.registerChannel(messenger)

        DeviceInfoHelper.registerChannels(this, messenger)

        // Foreground Runtime MethodChannel
        val channelInstance = MethodChannel(messenger, FOREGROUND_RUNTIME_CHANNEL)
        channel = channelInstance
        channelInstance.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val title = call.argument<String>("title") ?: "ToolLab active"
                    val text = call.argument<String>("text") ?: "Running in background"
                    val actions = call.argument<List<String>>("actions")
                    ToolLabForegroundService.start(this, title, text, actions)
                    result.success(true)
                }
                "update" -> {
                    val title = call.argument<String>("title") ?: "ToolLab active"
                    val text = call.argument<String>("text") ?: "Running in background"
                    val actions = call.argument<List<String>>("actions")
                    ToolLabForegroundService.update(this, title, text, actions)
                    result.success(true)
                }
                "stop" -> {
                    ToolLabForegroundService.stop(this)
                    result.success(true)
                }
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        if (checkSelfPermission(
                                android.Manifest.permission.POST_NOTIFICATIONS,
                            ) != PackageManager.PERMISSION_GRANTED
                        ) {
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                                1001,
                            )
                        }
                    }
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Shortcuts MethodChannel
        MethodChannel(messenger, SHORTCUTS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getLaunchRoute" -> {
                        result.success(launchRoute)
                        launchRoute = null
                    }
                    "pinShortcut" -> {
                        val toolId = call.argument<String>("id")
                        val toolName = call.argument<String>("name")
                        if (toolId == null || toolName == null) {
                            result.error("INVALID_ARGS", "tool id and name required", null)
                            return@setMethodCallHandler
                        }
                        val success = ShortcutHelper.pinShortcut(this, toolId, toolName)
                        result.success(success)
                    }
                    "removeShortcut" -> {
                        val toolId = call.argument<String>("id")
                        if (toolId == null) {
                            result.error("INVALID_ARGS", "tool id required", null)
                            return@setMethodCallHandler
                        }
                        ShortcutHelper.removeShortcut(this, toolId)
                        result.success(true)
                    }
                    "setDrawerIconEnabled" -> {
                        val toolId = call.argument<String>("id")
                        val enabled = call.argument<Boolean>("enabled")
                        if (toolId == null || enabled == null) {
                            result.error("INVALID_ARGS", "tool id and enabled state required", null)
                            return@setMethodCallHandler
                        }
                        ShortcutHelper.setDrawerIconEnabled(this, toolId, enabled)
                        result.success(true)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }

        // File Save MethodChannel
        MethodChannel(messenger, FILE_SAVE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveToDownloads" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val fileName = call.argument<String>("fileName")
                        val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                        if (bytes == null || fileName == null) {
                            result.error("INVALID_ARGS", "bytes and fileName required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val savedInfo = FileSaveHelper.saveToDownloads(this, bytes, fileName, mimeType)
                            result.success(savedInfo)
                        } catch (e: Exception) {
                            result.error("SAVE_ERROR", e.message, null)
                        }
                    }
                    "saveToDownloadsFromPath" -> {
                        val sourcePath = call.argument<String>("sourcePath")
                        val fileName = call.argument<String>("fileName")
                        val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                        if (sourcePath == null || fileName == null) {
                            result.error("INVALID_ARGS", "sourcePath and fileName required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val savedInfo = FileSaveHelper.saveToDownloadsFromPath(this, sourcePath, fileName, mimeType)
                            result.success(savedInfo)
                        } catch (e: Exception) {
                            result.error("SAVE_ERROR", e.message, null)
                        }
                    }
                    "openFile" -> {
                        val uriString = call.argument<String>("uri")
                        val mimeType = call.argument<String>("mimeType") ?: "*/*"
                        if (uriString == null) {
                            result.error("INVALID_ARGS", "uri required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            FileSaveHelper.openFile(this, uriString, mimeType)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("OPEN_ERROR", e.message, null)
                        }
                    }
                    "showSystemNotification" -> {
                        val fileName = call.argument<String>("fileName")
                        val uriString = call.argument<String>("uri")
                        val mimeType = call.argument<String>("mimeType") ?: "*/*"
                        if (fileName == null || uriString == null) {
                            result.error("INVALID_ARGS", "fileName and uri required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            FileSaveHelper.showSystemNotification(this, this, fileName, uriString, mimeType)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("NOTIFICATION_ERROR", e.message, null)
                        }
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }
}

class CalculatorActivity : MainActivity()
class PdfViewerActivity : MainActivity()
