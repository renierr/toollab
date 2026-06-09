package de.renier.tool_lab

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val FILE_SAVE_CHANNEL = "de.renier.tool_lab/file_save"
    private val SHORTCUTS_CHANNEL = "de.renier.tool_lab/shortcuts"
    private val SHARING_CHANNEL = "de.renier.tool_lab/sharing"

    private var launchRoute: String? = null
    private var pendingSharedFile: Map<String, String>? = null

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
        launchRoute = null
        if (intent != null) {
            val action = intent.action
            val isSend = action == Intent.ACTION_SEND
            val isView = action == Intent.ACTION_VIEW

            if (isSend || isView) {
                val uri = if (isSend) {
                    intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                } else {
                    intent.data
                }

                if (uri != null) {
                    try {
                        val mimeType = intent.type ?: contentResolver.getType(uri) ?: "application/octet-stream"
                        var name = "shared_file"
                        val cursor = contentResolver.query(uri, null, null, null, null)
                        cursor?.use {
                            if (it.moveToFirst()) {
                                val nameIndex = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                                if (nameIndex != -1) {
                                    name = it.getString(nameIndex)
                                }
                            }
                        }

                        val cacheDir = File(cacheDir, "shared_files")
                        if (!cacheDir.exists()) cacheDir.mkdirs()
                        val cleanName = name.replace("[^a-zA-Z0-9._-]".toRegex(), "_")
                        val tempFile = File(cacheDir, cleanName)
                        contentResolver.openInputStream(uri).use { input ->
                            FileOutputStream(tempFile).use { output ->
                                input?.copyTo(output)
                            }
                        }

                        val fileData = mapOf(
                            "path" to tempFile.absolutePath,
                            "name" to name,
                            "mimeType" to mimeType
                        )
                        pendingSharedFile = fileData

                        // If app is already running, notify Flutter immediately
                        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                            MethodChannel(messenger, SHARING_CHANNEL).invokeMethod("onSharedFile", fileData)
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }
            } else if (intent.hasExtra("route")) {
                launchRoute = intent.getStringExtra("route")
            } else {
                val className = intent.component?.className
                if (className != null) {
                    when (className) {
                        "de.renier.tool_lab.CalculatorAlias" -> launchRoute = "/calculator"
                        "de.renier.tool_lab.BubbleLevelAlias" -> launchRoute = "/bubble-level"
                        "de.renier.tool_lab.EmfDetectorAlias" -> launchRoute = "/emf-detector"
                        "de.renier.tool_lab.DeviceInfoAlias" -> launchRoute = "/device-info"
                        "de.renier.tool_lab.NfcTagLabAlias" -> launchRoute = "/nfc-tag-lab"
                        "de.renier.tool_lab.PdfViewerAlias" -> launchRoute = "/pdf-viewer"
                        "de.renier.tool_lab.NotesAlias" -> launchRoute = "/notes"
                        "de.renier.tool_lab.MarkdownViewerAlias" -> launchRoute = "/markdown-viewer"
                        "de.renier.tool_lab.ImageViewerAlias" -> launchRoute = "/image-viewer"
                        "de.renier.tool_lab.FastDropAlias" -> launchRoute = "/fast-drop"
                        "de.renier.tool_lab.MainActivity" -> launchRoute = "/"
                    }
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Sharing MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARING_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSharedFile" -> {
                        result.success(pendingSharedFile)
                        pendingSharedFile = null
                    }
                    "clearSharedFile" -> {
                        pendingSharedFile = null
                        result.success(true)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }

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
