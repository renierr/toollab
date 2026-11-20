package de.renier.tool_lab.bridge

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

/** Registered on every engine, so headless background runs reach the app too. */
class ToolLabBridgePlugin : FlutterPlugin {
    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "de.renier.tool_lab/bridge").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "broadcast" -> {
                        val action = call.argument<String>("action")
                        if (action == null) {
                            result.error("args", "action missing", null)
                            return@setMethodCallHandler
                        }
                        val intent = Intent(action).setPackage(context.packageName)
                        call.argument<Map<String, Any?>>("extras")?.forEach { (key, value) ->
                            when (value) {
                                is String -> intent.putExtra(key, value)
                                is Int -> intent.putExtra(key, value)
                                is Long -> intent.putExtra(key, value)
                                is Double -> intent.putExtra(key, value)
                                is Boolean -> intent.putExtra(key, value)
                            }
                        }
                        context.sendBroadcast(intent)
                        result.success(null)
                    }
                    "notificationsEnabled" -> result.success(
                        context.getSystemService(NotificationManager::class.java).areNotificationsEnabled(),
                    )
                    "openNotificationSettings" -> {
                        context.startActivity(
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }
}
