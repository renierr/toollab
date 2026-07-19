package de.renier.tool_lab

import android.Manifest
import android.app.PendingIntent
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import java.io.File
import java.io.FileInputStream

object FileSaveHelper {

    private fun splitBaseAndExtension(fileName: String): Pair<String, String> {
        val dotIndex = fileName.lastIndexOf('.')
        if (dotIndex <= 0 || dotIndex == fileName.length - 1) {
            return Pair(fileName, "")
        }
        return Pair(fileName.substring(0, dotIndex), fileName.substring(dotIndex))
    }

    private fun indexedName(base: String, extension: String, index: Int): String {
        return if (index <= 0) "$base$extension" else "$base ($index)$extension"
    }

    private fun mediaStoreNameExists(context: Context, candidateName: String): Boolean {
        val resolver = context.contentResolver
        val projection = arrayOf(MediaStore.Downloads._ID)
        val selection = "${MediaStore.Downloads.DISPLAY_NAME} = ?"
        val selectionArgs = arrayOf(candidateName)
        resolver.query(
            MediaStore.Downloads.EXTERNAL_CONTENT_URI,
            projection,
            selection,
            selectionArgs,
            null,
        ).use { cursor ->
            return cursor?.moveToFirst() == true
        }
    }

    private fun resolveUniqueMediaStoreName(context: Context, fileName: String): String {
        val (base, extension) = splitBaseAndExtension(fileName)
        var index = 0
        while (true) {
            val candidate = indexedName(base, extension, index)
            if (!mediaStoreNameExists(context, candidate)) {
                return candidate
            }
            index++
        }
    }

    private fun resolveUniqueFileNameInDirectory(directory: File, fileName: String): String {
        val (base, extension) = splitBaseAndExtension(fileName)
        var index = 0
        while (true) {
            val candidate = indexedName(base, extension, index)
            if (!File(directory, candidate).exists()) {
                return candidate
            }
            index++
        }
    }

    fun saveToDownloads(context: Context, bytes: ByteArray, fileName: String, mimeType: String): Map<String, String> {
        val resolver = context.contentResolver
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolvedName = resolveUniqueMediaStoreName(context, fileName)
            val contentValues = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, resolvedName)
                put(MediaStore.Downloads.MIME_TYPE, mimeType)
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            }
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
                ?: throw Exception("Failed to create MediaStore entry")
            resolver.openOutputStream(uri)?.use { outputStream ->
                outputStream.write(bytes)
            } ?: throw Exception("Failed to open output stream")
            
            return mapOf(
                "uri" to uri.toString(),
                "filePath" to "${Environment.DIRECTORY_DOWNLOADS}/$resolvedName",
                "fileName" to resolvedName,
            )
        } else {
            val downloadsDir = Environment.getExternalStoragePublicDirectory(
                Environment.DIRECTORY_DOWNLOADS
            )
            if (!downloadsDir.exists()) downloadsDir.mkdirs()
            val resolvedName = resolveUniqueFileNameInDirectory(downloadsDir, fileName)
            val file = File(downloadsDir, resolvedName)
            file.writeBytes(bytes)
            
            return mapOf(
                "uri" to Uri.fromFile(file).toString(),
                "filePath" to file.absolutePath,
                "fileName" to resolvedName,
            )
        }
    }

    fun saveToDownloadsFromPath(context: Context, sourcePath: String, fileName: String, mimeType: String): Map<String, String> {
        val resolver = context.contentResolver
        val sourceFile = File(sourcePath)
        if (!sourceFile.exists()) {
            throw Exception("Source file does not exist")
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolvedName = resolveUniqueMediaStoreName(context, fileName)
            val contentValues = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, resolvedName)
                put(MediaStore.Downloads.MIME_TYPE, mimeType)
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            }
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
                ?: throw Exception("Failed to create MediaStore entry")
            resolver.openOutputStream(uri)?.use { outputStream ->
                FileInputStream(sourceFile).use { inputStream ->
                    inputStream.copyTo(outputStream)
                }
            } ?: throw Exception("Failed to open output stream")

            return mapOf(
                "uri" to uri.toString(),
                "filePath" to "${Environment.DIRECTORY_DOWNLOADS}/$resolvedName",
                "fileName" to resolvedName,
            )
        } else {
            val downloadsDir = Environment.getExternalStoragePublicDirectory(
                Environment.DIRECTORY_DOWNLOADS
            )
            if (!downloadsDir.exists()) downloadsDir.mkdirs()
            val resolvedName = resolveUniqueFileNameInDirectory(downloadsDir, fileName)
            val file = File(downloadsDir, resolvedName)
            sourceFile.copyTo(file, overwrite = true)

            return mapOf(
                "uri" to Uri.fromFile(file).toString(),
                "filePath" to file.absolutePath,
                "fileName" to resolvedName,
            )
        }
    }

    private fun getUriForPath(context: Context, path: String): Uri {
        return if (path.startsWith("content://")) {
            Uri.parse(path)
        } else {
            val file = File(path)
            FileProvider.getUriForFile(
                context,
                "${context.packageName}.fileprovider",
                file
            )
        }
    }

    fun openFile(context: Context, uriString: String, mimeType: String) {
        val uri = getUriForPath(context, uriString)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mimeType)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        val chooser = Intent.createChooser(intent, "Open File").apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(chooser)
    }

    fun showSystemNotification(context: Context, activity: MainActivity, fileName: String, uriString: String, mimeType: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(activity, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 101)
            }
        }

        val uri = getUriForPath(context, uriString)

        val openIntent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mimeType)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        val openPendingIntent = PendingIntent.getActivity(
            context,
            0,
            Intent.createChooser(openIntent, "Open File"),
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        val shareIntent = Intent(Intent.ACTION_SEND).apply {
            type = mimeType
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        val sharePendingIntent = PendingIntent.getActivity(
            context,
            1,
            Intent.createChooser(shareIntent, "Share File"),
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        NotificationHelper.showNotification(
            context = context,
            title = "File Saved Successfully",
            message = fileName,
            channelId = "file_save_channel",
            channelName = "File Downloads",
            pendingIntents = listOf(
                Pair("Open", openPendingIntent),
                Pair("Share", sharePendingIntent)
            )
        )
    }
}
