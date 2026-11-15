package de.renier.tool_lab

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

object SharingHelper {
    private const val SHARING_CHANNEL = "de.renier.tool_lab/sharing"
    private var pendingSharedFiles: List<Map<String, String>>? = null

    fun handleIntent(context: Context, intent: Intent?, messenger: BinaryMessenger?) {
        if (intent == null) return
        val action = intent.action
        val isSend = action == Intent.ACTION_SEND
        val isSendMultiple = action == Intent.ACTION_SEND_MULTIPLE
        val isView = action == Intent.ACTION_VIEW

        if (isSend || isSendMultiple || isView) {
            val uris = when {
                isSendMultiple -> {
                    intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                }
                isSend -> {
                    intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)?.let { arrayListOf(it) }
                }
                else -> {
                    intent.data?.let { arrayListOf(it) }
                }
            }

            if (uris != null && uris.isNotEmpty()) {
                try {
                    val filesList = mutableListOf<Map<String, String>>()
                    for (uri in uris) {
                        val mimeType = intent.type ?: context.contentResolver.getType(uri) ?: "application/octet-stream"
                        var name = "shared_file"
                        var path: String? = null

                        if (uri.scheme == "file") {
                            path = uri.path
                            if (path != null) {
                                name = File(path).name
                            }
                        }

                        var contentUri: String? = null
                        if (path == null) {
                            name = displayName(context, uri) ?: name
                            val type = context.contentResolver.getType(uri) ?: mimeType
                            // Videos stream from the provider; a tool that needs a
                            // file asks for a copy through "materialize".
                            if (uri.scheme == "content" && (type.startsWith("video/") || mimeType.startsWith("video/"))) {
                                contentUri = uri.toString()
                                path = ""
                            } else {
                                path = copyToCache(context, uri, name)
                            }
                        }

                        if (path != null) {
                            filesList.add(buildMap {
                                put("path", path)
                                put("name", name)
                                put("mimeType", mimeType)
                                contentUri?.let { put("contentUri", it) }
                            })
                        }
                    }

                    pendingSharedFiles = filesList

                    // If app is already running, notify Flutter immediately
                    if (messenger != null) {
                        if (filesList.size == 1) {
                            MethodChannel(messenger, SHARING_CHANNEL).invokeMethod("onSharedFile", filesList.first())
                        } else if (filesList.size > 1) {
                            MethodChannel(messenger, SHARING_CHANNEL).invokeMethod("onSharedFiles", filesList)
                        }
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
    }

    private fun displayName(context: Context, uri: Uri): String? =
        context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
            if (it.moveToFirst()) it.getString(0) else null
        }

    private fun copyToCache(context: Context, uri: Uri, name: String): String {
        val cacheDir = File(context.cacheDir, "shared_files")
        if (!cacheDir.exists()) cacheDir.mkdirs()
        val cleanName = name.replace("[^a-zA-Z0-9._-]".toRegex(), "_")
        var tempFile = File(cacheDir, cleanName)
        if (tempFile.exists()) {
            val base = cleanName.substringBeforeLast(".")
            val ext = cleanName.substringAfterLast(".", "")
            val extSuffix = if (ext.isNotEmpty()) ".$ext" else ""
            var counter = 1
            while (tempFile.exists()) {
                tempFile = File(cacheDir, "${base}_$counter$extSuffix")
                counter++
            }
        }
        context.contentResolver.openInputStream(uri).use { input ->
            FileOutputStream(tempFile).use { output ->
                input?.copyTo(output)
            }
        }
        return tempFile.absolutePath
    }

    fun registerChannel(context: Context, messenger: BinaryMessenger) {
        val appContext = context.applicationContext
        MethodChannel(messenger, SHARING_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "materialize" -> {
                        val uri = call.argument<String>("uri")
                        val name = call.argument<String>("name") ?: "shared_file"
                        if (uri == null) {
                            result.error("INVALID_ARGS", "uri required", null)
                            return@setMethodCallHandler
                        }
                        val main = Handler(Looper.getMainLooper())
                        Thread {
                            try {
                                val path = copyToCache(appContext, Uri.parse(uri), name)
                                main.post { result.success(path) }
                            } catch (e: Exception) {
                                main.post { result.error("COPY_FAILED", e.message, null) }
                            }
                        }.start()
                    }
                    "getSharedFile" -> {
                        result.success(pendingSharedFiles?.firstOrNull())
                        pendingSharedFiles = null
                    }
                    "clearSharedFile" -> {
                        pendingSharedFiles = null
                        result.success(true)
                    }
                    "getSharedFiles" -> {
                        result.success(pendingSharedFiles)
                        pendingSharedFiles = null
                    }
                    "clearSharedFiles" -> {
                        pendingSharedFiles = null
                        result.success(true)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }
}
