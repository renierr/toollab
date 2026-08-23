package de.renier.tool_lab

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Environment
import android.os.StatFs
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

object InstalledAppsHelper {
    private const val CHANNEL = "de.renier.tool_lab/installed_apps"
    private const val ICON_SIZE = 96

    fun register(context: Context, messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "list" -> Thread {
                    try {
                        val apps = loadLaunchableApps(context)
                        postResult(result) { result.success(apps) }
                    } catch (e: Exception) {
                        postResult(result) { result.error("APP_LIST_ERROR", e.message, null) }
                    }
                }.start()
                "storageInfo" -> try {
                    val stat = StatFs(Environment.getExternalStorageDirectory().path)
                    result.success(
                        mapOf(
                            "totalBytes" to stat.totalBytes,
                            "freeBytes" to stat.availableBytes,
                        )
                    )
                } catch (e: Exception) {
                    result.error("STORAGE_ERROR", e.message, null)
                }
                "openAppSettings" -> {
                    val packageName = call.arguments as? String
                    if (packageName.isNullOrEmpty()) {
                        result.error("INVALID_ARGS", "packageName required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        context.startActivity(
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                        )
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("APP_SETTINGS_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    // Launchable apps only: covered by the manifest <queries> entry, so no
    // QUERY_ALL_PACKAGES permission is needed.
    private fun loadLaunchableApps(context: Context): List<Map<String, Any?>> {
        val packageManager = context.packageManager
        val launcherIntent = Intent(Intent.ACTION_MAIN)
        launcherIntent.addCategory(Intent.CATEGORY_LAUNCHER)
        val resolveInfos = packageManager.queryIntentActivities(launcherIntent, 0)
        val apps = ArrayList<Map<String, Any?>>(resolveInfos.size)
        for (resolveInfo in resolveInfos) {
            val activityInfo = resolveInfo.activityInfo ?: continue
            val appInfo = activityInfo.applicationInfo ?: continue
            val packageName = appInfo.packageName
            val label = resolveInfo.loadLabel(packageManager).toString()
            var version = ""
            runCatching {
                version = packageManager.getPackageInfo(packageName, 0)?.versionName ?: ""
            }
            var sizeBytes = 0L
            runCatching {
                sizeBytes = File(appInfo.sourceDir ?: "").length()
            }
            var icon: ByteArray? = null
            runCatching {
                icon = iconBytes(packageManager.getApplicationIcon(packageName))
            }
            apps.add(
                mapOf(
                    "name" to label,
                    "packageName" to packageName,
                    "version" to version,
                    "sizeBytes" to sizeBytes,
                    "isSystem" to ((appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0),
                    "icon" to icon,
                )
            )
        }
        return apps
    }

    private fun iconBytes(drawable: Drawable): ByteArray {
        val bitmap = Bitmap.createBitmap(ICON_SIZE, ICON_SIZE, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, ICON_SIZE, ICON_SIZE)
        drawable.draw(canvas)
        return ByteArrayOutputStream().use { stream ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            bitmap.recycle()
            stream.toByteArray()
        }
    }

    private fun postResult(result: MethodChannel.Result, block: () -> Unit) {
        android.os.Handler(android.os.Looper.getMainLooper()).post(block)
    }
}
