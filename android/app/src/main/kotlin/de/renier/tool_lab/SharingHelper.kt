package de.renier.tool_lab

import android.content.Context
import android.content.Intent
import android.net.Uri
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
                    val cacheDir = File(context.cacheDir, "shared_files")
                    if (!cacheDir.exists()) cacheDir.mkdirs()

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

                        if (path == null) {
                            val cursor = context.contentResolver.query(uri, null, null, null, null)
                            cursor?.use {
                                if (it.moveToFirst()) {
                                    val nameIndex = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                                    if (nameIndex != -1) {
                                        name = it.getString(nameIndex)
                                    }
                                }
                            }

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
                            path = tempFile.absolutePath
                        }

                        if (path != null) {
                            filesList.add(mapOf(
                                "path" to path,
                                "name" to name,
                                "mimeType" to mimeType
                            ))
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

    fun registerChannel(messenger: BinaryMessenger) {
        MethodChannel(messenger, SHARING_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
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
