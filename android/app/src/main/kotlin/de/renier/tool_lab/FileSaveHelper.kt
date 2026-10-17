package de.renier.tool_lab

import android.Manifest
import android.app.PendingIntent
import android.content.ContentUris
import android.content.ContentValues
import android.content.ClipData
import android.content.Context
import android.media.MediaScannerConnection
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

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

    fun resolveUniqueFileNameInDirectory(directory: File, fileName: String): String {
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

    fun getUriForPath(context: Context, path: String): Uri {
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

    private fun resolveSourceFile(context: Context, uriString: String): File? {
        return try {
            if (!uriString.startsWith("content://")) {
                val file = File(uriString)
                if (file.exists()) file else null
            } else {
                val uri = Uri.parse(uriString)
                var name = "tool_lab_${System.currentTimeMillis()}.apk"
                context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                    if (cursor.moveToFirst()) name = cursor.getString(0) ?: name
                }
                val outFile = File(context.cacheDir, name)
                context.contentResolver.openInputStream(uri)?.use { input ->
                    FileOutputStream(outFile).use { output -> input.copyTo(output) }
                } ?: return null
                if (outFile.exists()) outFile else null
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun apkPackageName(context: Context, sourceFile: File): String? {
        return try {
            @Suppress("DEPRECATION")
            context.packageManager.getPackageArchiveInfo(sourceFile.absolutePath, 0)?.packageName
        } catch (e: Exception) {
            null
        }
    }

    private fun findExistingDownloadsUri(context: Context, sourceFile: File): Uri? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        val resolver = context.contentResolver
        val projection = arrayOf(MediaStore.Downloads._ID)
        // Prefer an exact filesystem-path match so we reuse the entry for a
        // file that is already in public Downloads instead of creating a copy.
        try {
            resolver.query(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                projection,
                "_data = ?",
                arrayOf(sourceFile.absolutePath),
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    return ContentUris.withAppendedId(
                        MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                        cursor.getLong(0),
                    )
                }
            }
        } catch (_: Exception) {
            // _DATA may be unavailable on some providers; fall through.
        }
        // Fall back to display name (handles files scanned by MediaStore).
        return try {
            resolver.query(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                projection,
                "${MediaStore.Downloads.DISPLAY_NAME} = ?",
                arrayOf(sourceFile.name),
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    ContentUris.withAppendedId(
                        MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                        cursor.getLong(0),
                    )
                } else null
            }
        } catch (e: Exception) {
            null
        }
    }

    fun openFile(context: Context, uriString: String, mimeType: String) {
        // Unknown-sources gate for APK installs.
        if (mimeType == "application/vnd.android.package-archive" &&
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !context.packageManager.canRequestPackageInstalls()
        ) {
            context.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                data = Uri.parse("package:${context.packageName}")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            })
            return
        }

        var uri = getUriForPath(context, uriString)

        // Self-update mitigation: an APK whose package matches ToolLab's own must
        // be served by the system MediaProvider (survives process death) instead
        // of this app's FileProvider, otherwise the installer loses access when
        // the app process is killed mid-install.
        if (mimeType == "application/vnd.android.package-archive") {
            val sourceFile = resolveSourceFile(context, uriString)
            if (sourceFile != null && apkPackageName(context, sourceFile) == context.packageName) {
                uri = when {
                    uriString.startsWith("content://") && uriString.contains("media") -> Uri.parse(uriString)
                    else -> {
                        var existing = findExistingDownloadsUri(context, sourceFile)
                        // If the file is already in public Downloads but not yet
                        // indexed by MediaStore, scan it once and retry.
                        if (existing == null && sourceFile.absolutePath.contains("/Download/")) {
                            try {
                                val latch = java.util.concurrent.CountDownLatch(1)
                                MediaScannerConnection.scanFile(
                                    context,
                                    arrayOf(sourceFile.absolutePath),
                                    arrayOf(mimeType),
                                ) { _, _ -> latch.countDown() }
                                latch.await(2, java.util.concurrent.TimeUnit.SECONDS)
                                existing = findExistingDownloadsUri(context, sourceFile)
                            } catch (_: Exception) {
                            }
                        }
                        if (existing != null) {
                            existing
                        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            try {
                                val saved = saveToDownloadsFromPath(
                                    context,
                                    sourceFile.absolutePath,
                                    sourceFile.name,
                                    mimeType,
                                )
                                val savedUri = saved["uri"]
                                if (!savedUri.isNullOrEmpty() && savedUri.startsWith("content://")) {
                                    Uri.parse(savedUri)
                                } else {
                                    uri
                                }
                            } catch (e: Exception) {
                                uri
                            }
                        } else {
                            uri
                        }
                    }
                }
            }
        }

        val intent = Intent(
            if (mimeType == "application/vnd.android.package-archive") {
                Intent.ACTION_INSTALL_PACKAGE
            } else {
                Intent.ACTION_VIEW
            },
        ).apply {
            setDataAndType(uri, mimeType)
            clipData = ClipData.newRawUri("package", uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        // Install intents must go straight to the system package installer;
        // wrapping them in a chooser can hang/crash on some devices.
        if (mimeType == "application/vnd.android.package-archive") {
            context.startActivity(intent)
        } else {
            val chooser = Intent.createChooser(intent, "Open File").apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(chooser)
        }
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
