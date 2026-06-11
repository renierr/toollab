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
                val intent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    setPackage(context.packageName)
                    putExtra("route", "/$toolId")
                }

                val shortcut = ShortcutInfo.Builder(context, toolId)
                    .setShortLabel(toolName)
                    .setLongLabel(toolName)
                    .setIcon(Icon.createWithResource(context, R.mipmap.ic_launcher))
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
        val packageName = context.packageName
        val aliasClassName = when (toolId) {
            "calculator" -> "de.renier.tool_lab.CalculatorAlias"
            "bubble-level" -> "de.renier.tool_lab.BubbleLevelAlias"
            "emf-detector" -> "de.renier.tool_lab.EmfDetectorAlias"
            "device-info" -> "de.renier.tool_lab.DeviceInfoAlias"
            "nfc-tag-lab" -> "de.renier.tool_lab.NfcTagLabAlias"
            "pdf-viewer" -> "de.renier.tool_lab.PdfViewerAlias"
            "notes" -> "de.renier.tool_lab.NotesAlias"
            "markdown-viewer" -> "de.renier.tool_lab.MarkdownViewerAlias"
            "image-viewer" -> "de.renier.tool_lab.ImageViewerAlias"
            "fast-drop" -> "de.renier.tool_lab.FastDropAlias"
            "images-to-pdf" -> "de.renier.tool_lab.ImagesToPdfAlias"
            "chiptune" -> "de.renier.tool_lab.ChiptuneAlias"
            else -> return
        }

        val componentName = android.content.ComponentName(packageName, aliasClassName)
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
}
