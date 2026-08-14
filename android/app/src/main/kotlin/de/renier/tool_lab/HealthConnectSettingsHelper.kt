package de.renier.tool_lab

import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Opens Health Connect's own screens. Granting happens through the plugin's
 * permission request; this is for inspecting and revoking. Which entry point
 * exists depends on the OS version and the OEM, so the list is ordered by
 * preference and simply tried in turn.
 */
class HealthConnectSettingsHelper(private val activity: Activity) {
    fun registerChannel(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openSettings" -> {
                    val opened = open()
                    if (opened != null) {
                        result.success(
                            mapOf(
                                "opened" to opened,
                                "fallback" to opened.startsWith("fallback:"),
                            )
                        )
                    } else {
                        result.error(
                            "HEALTH_CONNECT_UNAVAILABLE",
                            "Could not open Health Connect settings on this device.",
                            null,
                        )
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    // Started without resolveActivity first: package visibility hides the
    // provider from resolution on Android 11+ even where starting it succeeds,
    // so asking would rule out the entries that actually work.
    private fun open(): String? {
        for ((label, intent) in buildAttempts()) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                activity.startActivity(intent)
                Log.i(TAG, "$label started successfully")
                return label
            } catch (e: Exception) {
                Log.w(TAG, "$label failed to start: ${e.message}")
            }
        }
        return null
    }

    private fun buildAttempts(): List<Pair<String, Intent>> {
        val attempts = mutableListOf<Pair<String, Intent>>()
        val platform = Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE

        if (platform) {
            // Android 14+ moved Health Connect into the platform, under its own
            // action names - the androidx ones below resolve to nothing there.
            attempts.add("home:platform" to Intent("android.health.connect.action.HEALTH_HOME_SETTINGS"))
            attempts.add("data:platform" to Intent("android.health.connect.action.MANAGE_HEALTH_DATA"))
        } else {
            // Android 13 and below ship it as an ordinary APK. Targeting the
            // package keeps the implicit action from going unresolved.
            attempts.add("home:apk" to Intent(ACTION_ANDROIDX_SETTINGS).setPackage(PROVIDER_APK))
            attempts.add("data:apk" to Intent("androidx.health.ACTION_MANAGE_HEALTH_DATA").setPackage(PROVIDER_APK))
            attempts.add("home:apk_implicit" to Intent(ACTION_ANDROIDX_SETTINGS))
        }

        attempts.add("settings:samsung" to Intent("com.samsung.android.healthconnect.action.HEALTH_CONNECT_SETTINGS"))
        attempts.add("uri:healthconnect" to Intent(Intent.ACTION_VIEW, Uri.parse("healthconnect://settings")))

        // The per-app deep link the system's own settings use. Starting it needs
        // the signature permission GRANT_RUNTIME_PERMISSIONS, so it is denied on
        // most devices - kept because where it is allowed it lands on the exact
        // screen.
        val managePermissions = if (platform) {
            "android.health.connect.action.MANAGE_HEALTH_PERMISSIONS"
        } else {
            "androidx.health.ACTION_MANAGE_HEALTH_PERMISSIONS"
        }
        attempts.add("permissions:app" to Intent(managePermissions).apply {
            putExtra(Intent.EXTRA_PACKAGE_NAME, activity.packageName)
        })

        // The controller has no launcher entry on Android 14+, so its activity is
        // named explicitly. The package is renamed in Google builds, the classes
        // are not.
        listOf(PROVIDER_CONTROLLER, "com.android.healthconnect.controller").forEach { classPrefix ->
            attempts.add("component:$classPrefix" to Intent(Intent.ACTION_MAIN).apply {
                component = ComponentName(PROVIDER_CONTROLLER, "$classPrefix.MainActivity")
            })
        }

        listOf(PROVIDER_CONTROLLER, PROVIDER_APK).forEach { pkg ->
            activity.packageManager.getLaunchIntentForPackage(pkg)?.let {
                attempts.add("launcher:$pkg" to it)
            }
        }

        attempts.add("fallback:appInfo" to Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:${activity.packageName}")
        })

        return attempts
    }

    private companion object {
        const val CHANNEL = "de.renier.tool_lab/health_connect"
        const val TAG = "ToolLabHealthConnect"
        const val ACTION_ANDROIDX_SETTINGS = "androidx.health.ACTION_HEALTH_CONNECT_SETTINGS"
        const val PROVIDER_APK = "com.google.android.apps.healthdata"
        const val PROVIDER_CONTROLLER = "com.google.android.healthconnect.controller"
    }
}
