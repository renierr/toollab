package de.renier.tool_lab

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.os.Build

object ShortcutHelper {

    fun pinShortcut(context: Context, toolId: String, toolName: String): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val shortcutManager = context.getSystemService(ShortcutManager::class.java)
                ?: return false
            
            // Re-enable if it was disabled before (fixes the unpin/re-add bug)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1) {
                try {
                    shortcutManager.enableShortcuts(listOf(toolId))
                } catch (e: Exception) {
                    // Ignore
                }
            }

            if (shortcutManager.isRequestPinShortcutSupported) {
                val targetClassName = toolIdToActivityClassName(toolId)
                val intent = Intent().apply {
                    setClassName(context.packageName, targetClassName)
                    action = Intent.ACTION_VIEW
                    putExtra("route", "/$toolId")
                }

                val resourceName = "ic_launcher_" + toolId.replace("-", "_")
                val resId = context.resources.getIdentifier(resourceName, "mipmap", context.packageName)
                val icon = if (resId != 0) {
                    Icon.createWithResource(context, resId)
                } else {
                    Icon.createWithResource(context, R.mipmap.ic_launcher)
                }

                val shortcut = ShortcutInfo.Builder(context, toolId)
                    .setShortLabel(toolName)
                    .setLongLabel(toolName)
                    .setIcon(icon)
                    .setIntent(intent)
                    .build()

                return shortcutManager.requestPinShortcut(shortcut, null)
            }
        }
        return false
    }

    fun removeShortcut(context: Context, toolId: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1) {
            val shortcutManager = context.getSystemService(ShortcutManager::class.java) ?: return
            try {
                shortcutManager.disableShortcuts(listOf(toolId))
            } catch (e: Exception) {
                // Ignore
            }
        }
    }

    fun setDrawerIconEnabled(context: Context, toolId: String, enabled: Boolean) {
        val aliasClassName = toolIdToAliasClassName(toolId) ?: return

        val componentName = android.content.ComponentName(context.packageName, aliasClassName)
        val newState = if (enabled) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED
        } else {
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED
        }

        context.packageManager.setComponentEnabledSetting(
            componentName,
            newState,
            PackageManager.DONT_KILL_APP
        )
    }

    private fun toolIdToAliasClassName(toolId: String): String? {
        val parts = toolId.split("-").map { it.replaceFirstChar { c -> c.uppercase() } }
        if (parts.isEmpty()) return null
        return "de.renier.tool_lab.${parts.joinToString("")}Alias"
    }

    private fun toolIdToActivityClassName(toolId: String): String {
        val isolatedTools = setOf("calculator", "pdf-viewer", "file-manager", "text-editor", "ricochet", "twenty48", "chaindrop", "luma-well", "drift-bloom")
        if (isolatedTools.contains(toolId)) {
            val parts = toolId.split("-").map { it.replaceFirstChar { c -> c.uppercase() } }
            return "de.renier.tool_lab.${parts.joinToString("")}Activity"
        }
        return "de.renier.tool_lab.MainActivity"
    }
}
