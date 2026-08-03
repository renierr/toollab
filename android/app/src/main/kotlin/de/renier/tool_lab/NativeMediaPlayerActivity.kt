package de.renier.tool_lab

import android.app.Activity
import android.media.AudioManager
import android.net.Uri
import android.os.Bundle
import android.view.ViewGroup
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
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
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
        setContentView(videoView)
    }
}
