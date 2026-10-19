package de.renier.tool_lab

import android.Manifest
import android.app.PendingIntent
import android.content.ContentUris
import android.content.ContentValues
import android.content.ClipData
import android.content.Context
import android.media.MediaScannerConnection
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import java.io.File
import java.io.FileInputStream
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

object FileSaveHelper {

    private const val APK_MIME = "application/vnd.android.package-archive"

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

    // Content URIs are parsed through their fd path, so the APK is never copied out first.
    private fun apkInfo(context: Context, uriString: String): PackageInfo? {
        return try {
            if (uriString.startsWith("content://")) {
                context.contentResolver.openFileDescriptor(Uri.parse(uriString), "r")?.use { pfd ->
                    apkInfoAtPath(context, "/proc/self/fd/${pfd.fd}")
                }
            } else {
                apkInfoAtPath(context, uriString)
            }
        } catch (_: Exception) {
            null
        }
    }

    @Suppress("DEPRECATION")
    private fun apkInfoAtPath(context: Context, path: String): PackageInfo? =
        context.packageManager.getPackageArchiveInfo(path, 0)

    private fun PackageInfo.versionCodeCompat(): Long =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            longVersionCode
        } else {
            @Suppress("DEPRECATION")
            versionCode.toLong()
        }

    private fun downloadsUri(id: Long): Uri =
        ContentUris.withAppendedId(MediaStore.Downloads.EXTERNAL_CONTENT_URI, id)

    private fun findDownloadsUriByPath(context: Context, file: File): Uri? {
        return try {
            context.contentResolver.query(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                arrayOf(MediaStore.Downloads._ID),
                "_data = ?",
                arrayOf(file.absolutePath),
                null,
            )?.use { cursor -> if (cursor.moveToFirst()) downloadsUri(cursor.getLong(0)) else null }
        } catch (_: Exception) {
            // _data may be unavailable on some providers.
            null
        }
    }

    // A prior self-update may have saved the same build under another name.
    private fun findDownloadsUriByBuild(context: Context, file: File, info: PackageInfo): Uri? {
        return try {
            context.contentResolver.query(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                arrayOf(MediaStore.Downloads._ID),
                "${MediaStore.Downloads.SIZE} = ? AND ${MediaStore.Downloads.DISPLAY_NAME} LIKE ?",
                arrayOf(file.length().toString(), "%.apk"),
                null,
            )?.use { cursor ->
                while (cursor.moveToNext()) {
                    val uri = downloadsUri(cursor.getLong(0))
                    val entry = apkInfo(context, uri.toString()) ?: continue
                    if (entry.packageName == info.packageName &&
                        entry.versionCodeCompat() == info.versionCodeCompat()
                    ) {
                        return uri
                    }
                }
                null
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun scanIntoMediaStore(context: Context, file: File): Uri? {
        var scanned: Uri? = null
        val latch = CountDownLatch(1)
        MediaScannerConnection.scanFile(context, arrayOf(file.absolutePath), arrayOf(APK_MIME)) { _, uri ->
            scanned = uri
            latch.countDown()
        }
        latch.await(2, TimeUnit.SECONDS)
        return findDownloadsUriByPath(context, file) ?: scanned
    }

    // ToolLab's own APK must be served by MediaProvider: this app's FileProvider
    // dies with the process the install replaces.
    private fun selfUpdateUri(context: Context, file: File, info: PackageInfo): Uri? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        findDownloadsUriByPath(context, file)?.let { return it }
        findDownloadsUriByBuild(context, file, info)?.let { return it }
        if (file.absolutePath.contains("/Download/")) {
            scanIntoMediaStore(context, file)?.let { return it }
        }
        return try {
            saveToDownloadsFromPath(context, file.absolutePath, deriveApkName(file.name), APK_MIME)["uri"]
                ?.takeIf { it.startsWith("content://") }
                ?.let(Uri::parse)
        } catch (_: Exception) {
            null
        }
    }

    private fun deriveApkName(name: String): String {
        val patterns = listOf(
            Regex("^fast_drop_open_[A-Za-z0-9-]+_(.+)$"),
            Regex("^fast_drop_save_[A-Za-z0-9-]+_(.+)$"),
            Regex("^p2p_received_\\d+_(.+)$"),
            Regex("^file_manager_share_(.+)$"),
            Regex("^file_manager_(.+)$"),
        )
        for (pattern in patterns) {
            val match = pattern.matchEntire(name)
            if (match != null) return match.groupValues[1]
        }
        return name
    }

    private fun grantedIntent(action: String, uri: Uri, mimeType: String): Intent =
        Intent(action).apply {
            setDataAndType(uri, mimeType)
            clipData = ClipData.newRawUri("package", uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

    /** Returns true when the launched install replaces ToolLab itself. */
    fun openFile(context: Context, uriString: String, mimeType: String): Boolean {
        if (mimeType != APK_MIME) {
            val intent = grantedIntent(Intent.ACTION_VIEW, getUriForPath(context, uriString), mimeType)
            context.startActivity(Intent.createChooser(intent, "Open File").apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            })
            return false
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !context.packageManager.canRequestPackageInstalls()
        ) {
            context.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                data = Uri.parse("package:${context.packageName}")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            })
            return false
        }

        val selfInfo = apkInfo(context, uriString)?.takeIf { it.packageName == context.packageName }
        // Foreign content URIs outlive this process already; only file paths need MediaStore.
        val uri = if (selfInfo != null && !uriString.startsWith("content://")) {
            selfUpdateUri(context, File(uriString), selfInfo) ?: getUriForPath(context, uriString)
        } else {
            getUriForPath(context, uriString)
        }
        // Install intents must go straight to the system package installer;
        // wrapping them in a chooser can hang/crash on some devices.
        context.startActivity(grantedIntent(Intent.ACTION_INSTALL_PACKAGE, uri, mimeType))
        return selfInfo != null
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
