package de.renier.tool_lab

import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.os.Build

object ShortcutHelper {

    fun pinShortcut(context: Context, toolId: String, toolName: String): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val shortcutManager = context.getSystemService(ShortcutManager::class.java)
                ?: return false
            if (shortcutManager.isRequestPinShortcutSupported) {
                val intent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
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
            shortcutManager.disableShortcuts(listOf(toolId))
        }
    }
}
