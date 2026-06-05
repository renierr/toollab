package de.renier.tool_lab

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val FILE_SAVE_CHANNEL = "de.renier.tool_lab/file_save"
    private val SHORTCUTS_CHANNEL = "de.renier.tool_lab/shortcuts"
    private var launchRoute: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
        launchRoute?.let { route ->
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, SHORTCUTS_CHANNEL).invokeMethod("onShortcutRoute", route)
                launchRoute = null
            }
        }
    }

    private fun handleIntent(intent: Intent?) {
        if (intent != null && intent.hasExtra("route")) {
            launchRoute = intent.getStringExtra("route")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Shortcuts MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHORTCUTS_CHANNEL)
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
                    else -> {
                        result.notImplemented()
                    }
                }
            }

        // File Save MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILE_SAVE_CHANNEL)
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
