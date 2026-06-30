package de.renier.tool_lab

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

class ToolLabForegroundService : Service() {
    companion object {
        private const val CHANNEL_ID = "toollab_foreground_runtime"
        private const val CHANNEL_NAME = "Active Runtime"
        private const val CHANNEL_DESCRIPTION = "Playback and long-running tool tasks"
        private const val NOTIFICATION_ID = 42001

        private const val ACTION_START = "de.renier.tool_lab.foreground.START"
        private const val ACTION_UPDATE = "de.renier.tool_lab.foreground.UPDATE"
        private const val ACTION_STOP = "de.renier.tool_lab.foreground.STOP"

        private const val EXTRA_TITLE = "title"
        private const val EXTRA_TEXT = "text"
        private const val EXTRA_ACTIONS = "actions"

        private var lastTitle: String = "ToolLab active"
        private var lastText: String = "Running in background"
        private var lastActions: ArrayList<String>? = null

        fun start(context: Context, title: String, text: String, actions: List<String>?) {
            lastTitle = title
            lastText = text
            lastActions = actions?.let { ArrayList(it) }
            val intent = Intent(context, ToolLabForegroundService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_TEXT, text)
                if (actions != null) {
                    putStringArrayListExtra(EXTRA_ACTIONS, ArrayList(actions))
                }
            }
            ContextCompat.startForegroundService(context, intent)
        }

        fun update(context: Context, title: String, text: String, actions: List<String>?) {
            lastTitle = title
            lastText = text
            lastActions = actions?.let { ArrayList(it) }
            val intent = Intent(context, ToolLabForegroundService::class.java).apply {
                action = ACTION_UPDATE
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_TEXT, text)
                if (actions != null) {
                    putStringArrayListExtra(EXTRA_ACTIONS, ArrayList(actions))
                }
            }
            context.startService(intent)
        }

        fun stop(context: Context) {
            lastTitle = "ToolLab active"
            lastText = "Running in background"
            lastActions = null
            val intent = Intent(context, ToolLabForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        try {
            ensureChannel()

            if (intent == null) {
                startForegroundSafely(buildNotification(lastTitle, lastText, lastActions))
                return START_STICKY
            }

            val action = intent.action
            if (action != null && action.startsWith("de.renier.tool_lab.foreground.action.")) {
                val actionName = action.removePrefix("de.renier.tool_lab.foreground.action.")
                sendActionToFlutter(actionName)
                return START_STICKY
            }

            when (action) {
                ACTION_START -> {
                    val title = intent.getStringExtra(EXTRA_TITLE) ?: "ToolLab active"
                    val text = intent.getStringExtra(EXTRA_TEXT) ?: "Running in background"
                    val actions = intent.getStringArrayListExtra(EXTRA_ACTIONS)
                    startForegroundSafely(buildNotification(title, text, actions))
                }
                ACTION_UPDATE -> {
                    val title = intent.getStringExtra(EXTRA_TITLE) ?: "ToolLab active"
                    val text = intent.getStringExtra(EXTRA_TEXT) ?: "Running in background"
                    val actions = intent.getStringArrayListExtra(EXTRA_ACTIONS)
                    val manager =
                        getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    manager.notify(NOTIFICATION_ID, buildNotification(title, text, actions))
                }
                ACTION_STOP -> {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                    stopSelf()
                }
                else -> {
                    startForegroundSafely(buildNotification(lastTitle, lastText, lastActions))
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("ToolLabFGS", "Error in onStartCommand: ", e)
            try {
                val fallbackNotification = NotificationCompat.Builder(this, CHANNEL_ID)
                    .setSmallIcon(android.R.drawable.ic_media_play)
                    .setContentTitle("ToolLab active")
                    .setContentText("Running in background")
                    .build()
                startForegroundSafely(fallbackNotification)
            } catch (ex: Exception) {
                android.util.Log.e("ToolLabFGS", "Fatal fallback error: ", ex)
            }
        }

        return START_STICKY
    }

    private fun startForegroundSafely(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun sendActionToFlutter(actionName: String) {
        val channel = MainActivity.channel
        if (channel != null) {
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                channel.invokeMethod("onAction", actionName)
            }
        }
    }

    private fun buildNotification(title: String, text: String, actions: List<String>?): Notification {
        val openIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)

        actions?.forEach { action ->
            val icon = when (action) {
                "play" -> android.R.drawable.ic_media_play
                "pause" -> android.R.drawable.ic_media_pause
                "stop" -> android.R.drawable.ic_menu_close_clear_cancel
                "next" -> android.R.drawable.ic_media_next
                "previous" -> android.R.drawable.ic_media_previous
                else -> return@forEach
            }
            val label = when (action) {
                "play" -> "Play"
                "pause" -> "Pause"
                "stop" -> "Stop"
                "next" -> "Next"
                "previous" -> "Previous"
                else -> action.replaceFirstChar { it.uppercase() }
            }

            val actionIntent = Intent(this, ToolLabForegroundService::class.java).apply {
                this.action = "de.renier.tool_lab.foreground.action.$action"
            }
            val pendingAction = PendingIntent.getService(
                this,
                action.hashCode(),
                actionIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            builder.addAction(icon, label, pendingAction)
        }

        return builder.build()
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = CHANNEL_DESCRIPTION
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }
}
