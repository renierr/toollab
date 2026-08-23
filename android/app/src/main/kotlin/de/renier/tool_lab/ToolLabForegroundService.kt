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
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import androidx.media.app.NotificationCompat as MediaNotificationCompat

class ToolLabForegroundService : Service() {
    companion object {
        private const val CHANNEL_ID = "toollab_foreground_runtime"
        private const val CHANNEL_NAME = "Active Runtime"
        private const val CHANNEL_DESCRIPTION = "Playback and long-running tool tasks"
        private const val NOTIFICATION_ID = 42001

        private const val ACTION_START = "de.renier.tool_lab.foreground.START"
        private const val ACTION_UPDATE = "de.renier.tool_lab.foreground.UPDATE"
        private const val ACTION_PLAYBACK_STATE = "de.renier.tool_lab.foreground.PLAYBACK_STATE"
        private const val ACTION_STOP = "de.renier.tool_lab.foreground.STOP"

        private const val EXTRA_TITLE = "title"
        private const val EXTRA_TEXT = "text"
        private const val EXTRA_ACTIONS = "actions"
        private const val EXTRA_MEDIA_TITLE = "mediaTitle"
        private const val EXTRA_MEDIA_ARTIST = "mediaArtist"
        private const val EXTRA_DURATION_MS = "durationMs"
        private const val EXTRA_POSITION_MS = "positionMs"
        private const val EXTRA_PLAYING = "playing"
        private const val EXTRA_SEEKABLE = "seekable"

        private var lastTitle: String = "ToolLab active"
        private var lastText: String = "Running in background"
        private var lastActions: ArrayList<String>? = null

        // Media snapshot (null mediaTitle = plain non-media notification).
        private var lastMediaTitle: String? = null
        private var lastMediaArtist: String? = null
        private var lastDurationMs: Long = 0
        private var lastPositionMs: Long = 0
        private var lastPlaying: Boolean = false
        private var lastSeekable: Boolean = false

        fun start(
            context: Context,
            title: String,
            text: String,
            actions: List<String>?,
            media: Map<String, Any?>?,
        ) {
            applyState(title, text, actions, media)
            ContextCompat.startForegroundService(
                context,
                serviceIntent(context, ACTION_START),
            )
        }

        fun update(
            context: Context,
            title: String,
            text: String,
            actions: List<String>?,
            media: Map<String, Any?>?,
        ) {
            applyState(title, text, actions, media)
            context.startService(serviceIntent(context, ACTION_UPDATE))
        }

        fun updatePlayback(context: Context, positionMs: Long, playing: Boolean) {
            lastPositionMs = positionMs
            lastPlaying = playing
            if (lastMediaTitle == null) return
            val intent = Intent(context, ToolLabForegroundService::class.java).apply {
                action = ACTION_PLAYBACK_STATE
                putExtra(EXTRA_POSITION_MS, positionMs)
                putExtra(EXTRA_PLAYING, playing)
            }
            context.startService(intent)
        }

        fun stop(context: Context) {
            lastTitle = "ToolLab active"
            lastText = "Running in background"
            lastActions = null
            lastMediaTitle = null
            lastMediaArtist = null
            lastDurationMs = 0
            lastPositionMs = 0
            lastSeekable = false
            val intent = Intent(context, ToolLabForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }

        private fun applyState(
            title: String,
            text: String,
            actions: List<String>?,
            media: Map<String, Any?>?,
        ) {
            lastTitle = title
            lastText = text
            lastActions = actions?.let { ArrayList(it) }
            if (media == null) {
                lastMediaTitle = null
                lastMediaArtist = null
                lastDurationMs = 0
                lastSeekable = false
                return
            }
            lastMediaTitle = media["title"] as? String ?: title
            lastMediaArtist = media["artist"] as? String
            lastDurationMs = (media["durationMs"] as? Number)?.toLong() ?: 0L
            lastPositionMs = (media["positionMs"] as? Number)?.toLong() ?: 0L
            lastPlaying = media["playing"] as? Boolean ?: false
            lastSeekable = media["seekable"] as? Boolean ?: false
        }

        private fun serviceIntent(context: Context, action: String): Intent =
            Intent(context, ToolLabForegroundService::class.java).apply { this.action = action }
    }

    private var mediaSession: MediaSessionCompat? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        try {
            ensureChannel()

            if (intent == null) {
                startForegroundSafely(buildNotification())
                return START_STICKY
            }

            val action = intent.action
            if (action != null && action.startsWith("de.renier.tool_lab.foreground.action.")) {
                val actionName = action.removePrefix("de.renier.tool_lab.foreground.action.")
                sendActionToFlutter(actionName)
                return START_STICKY
            }

            when (action) {
                ACTION_START -> startForegroundSafely(buildNotification())
                ACTION_UPDATE -> notify(buildNotification())
                ACTION_PLAYBACK_STATE -> {
                    lastPositionMs = intent.getLongExtra(EXTRA_POSITION_MS, 0)
                    lastPlaying = intent.getBooleanExtra(EXTRA_PLAYING, false)
                    refreshPlaybackState()
                }
                ACTION_STOP -> {
                    releaseSession()
                    stopForeground(STOP_FOREGROUND_REMOVE)
                    stopSelf()
                }
                else -> startForegroundSafely(buildNotification())
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
        ServiceCompat.startForeground(
            this,
            NOTIFICATION_ID,
            notification,
            android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK or
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
        )
    }

    private fun notify(notification: Notification) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, notification)
    }

    private fun sendActionToFlutter(actionName: String) {
        val channel = MainActivity.channel
        if (channel != null) {
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                channel.invokeMethod("onAction", actionName)
            }
        }
    }

    // ---- Media session ----

    private fun ensureSession(): MediaSessionCompat {
        mediaSession?.let { return it }
        val session = MediaSessionCompat(this, "ToolLabMediaSession")
        session.setCallback(object : MediaSessionCompat.Callback() {
            override fun onPlay() = sendActionToFlutter("play")
            override fun onPause() = sendActionToFlutter("pause")
            override fun onStop() = sendActionToFlutter("stop")
            override fun onSkipToNext() = sendActionToFlutter("next")
            override fun onSkipToPrevious() = sendActionToFlutter("previous")
            override fun onSeekTo(pos: Long) = sendActionToFlutter("seek:${pos.toInt()}")
        })
        session.isActive = true
        mediaSession = session
        return session
    }

    private fun releaseSession() {
        mediaSession?.release()
        mediaSession = null
    }

    private fun playbackActions(): Long {
        var actions = PlaybackStateCompat.ACTION_PLAY or
            PlaybackStateCompat.ACTION_PAUSE or
            PlaybackStateCompat.ACTION_PLAY_PAUSE or
            PlaybackStateCompat.ACTION_STOP
        val names = lastActions.orEmpty()
        if ("next" in names) actions = actions or PlaybackStateCompat.ACTION_SKIP_TO_NEXT
        if ("previous" in names) actions = actions or PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS
        if (lastSeekable) actions = actions or PlaybackStateCompat.ACTION_SEEK_TO
        return actions
    }

    private fun refreshPlaybackState(session: MediaSessionCompat? = null) {
        val target = session ?: mediaSession ?: return
        target.setPlaybackState(
            PlaybackStateCompat.Builder()
                .setActions(playbackActions())
                .setState(
                    if (lastPlaying) {
                        PlaybackStateCompat.STATE_PLAYING
                    } else {
                        PlaybackStateCompat.STATE_PAUSED
                    },
                    lastPositionMs.coerceAtLeast(0),
                    if (lastPlaying) 1f else 0f,
                )
                .build(),
        )
    }

    // ---- Notification building ----

    private fun buildNotification(): Notification {
        val openIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle(lastTitle)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)

        val mediaTitle = lastMediaTitle
        if (mediaTitle != null) {
            val session = ensureSession()
            session.setMetadata(
                MediaMetadataCompat.Builder()
                    .putString(MediaMetadataCompat.METADATA_KEY_TITLE, mediaTitle)
                    .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, lastMediaArtist ?: "")
                    .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, lastDurationMs.coerceAtLeast(0))
                    .build(),
            )
            refreshPlaybackState(session)

            builder
                .setContentText(lastMediaArtist ?: "")
                .setSubText(lastText)
                .setShowWhen(false)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
        } else {
            builder.setContentText(lastText)
        }

        var compactIndex = 0
        val compactIndices = mutableListOf<Int>()
        lastActions.orEmpty().forEach { name ->
            val styled = styledAction(name) ?: return@forEach
            builder.addAction(styled.first, styled.second, actionPendingIntent(name))
            if (compactIndex < 3 && name != "stop") {
                compactIndices.add(compactIndex)
            }
            compactIndex++
        }

        if (mediaTitle != null) {
            val style = MediaNotificationCompat.MediaStyle()
                .setMediaSession(ensureSession().sessionToken)
            if (compactIndices.isNotEmpty()) {
                style.setShowActionsInCompactView(*compactIndices.toIntArray())
            }
            builder.setStyle(style)
        }

        return builder.build()
    }

    private fun styledAction(name: String): Pair<Int, String>? {
        val (icon, label) = when (name) {
            "play" -> android.R.drawable.ic_media_play to "Play"
            "pause" -> android.R.drawable.ic_media_pause to "Pause"
            "stop" -> android.R.drawable.ic_menu_close_clear_cancel to "Stop"
            "next" -> android.R.drawable.ic_media_next to "Next"
            "previous" -> android.R.drawable.ic_media_previous to "Previous"
            else -> return null
        }
        return icon to label
    }

    private fun actionPendingIntent(name: String): PendingIntent {
        val actionIntent = Intent(this, ToolLabForegroundService::class.java).apply {
            this.action = "de.renier.tool_lab.foreground.action.$name"
        }
        return PendingIntent.getService(
            this,
            name.hashCode(),
            actionIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
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
