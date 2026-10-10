package de.renier.tool_lab

import android.app.Activity
import android.graphics.Color
import android.media.AudioManager
import android.net.Uri
import android.os.Bundle
import android.view.Gravity
import android.widget.FrameLayout
import android.widget.MediaController
import android.widget.VideoView

class NativeMediaPlayerActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val uri = intent.data ?: run {
            finish()
            return
        }
        val isVideo = intent.type?.startsWith("video/") == true
        if (!isVideo) {
            volumeControlStream = AudioManager.STREAM_MUSIC
        }

        val videoView = VideoView(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
                Gravity.CENTER,
            )
            setVideoURI(uri)
            setMediaController(MediaController(this@NativeMediaPlayerActivity).also {
                it.setAnchorView(this)
            })
            setOnPreparedListener { start() }
            setOnCompletionListener { finish() }
            setOnErrorListener { _, _, _ ->
                finish()
                true
            }
        }
        val frame = FrameLayout(this).apply {
            setBackgroundColor(Color.BLACK)
            addView(videoView)
        }
        setContentView(frame)
    }
}
