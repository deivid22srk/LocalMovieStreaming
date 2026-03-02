package com.localmovie.streaming.local_movie_streaming

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.SurfaceView
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.ProgressBar
import android.widget.SeekBar
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import org.videolan.libvlc.LibVLC
import org.videolan.libvlc.Media
import org.videolan.libvlc.MediaPlayer
import org.videolan.libvlc.util.VLCVideoLayout
import java.util.Timer
import kotlin.concurrent.schedule

class VlcPlayerActivity : AppCompatActivity() {

    private var libVLC: LibVLC? = null
    private var mediaPlayer: MediaPlayer? = null
    private var videoLayout: VLCVideoLayout? = null

    private var videoUrl: String? = null
    private var videoTitle: String? = null
    private var initialPosition: Long = 0

    private lateinit var playPauseBtn: ImageButton
    private lateinit var seekBar: SeekBar
    private lateinit var timeDisplay: TextView
    private lateinit var controlsOverlay: FrameLayout
    private lateinit var loadingProgress: ProgressBar

    private var isControlsVisible = true
    private var hideTimer: Timer? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN, WindowManager.LayoutParams.FLAG_FULLSCREEN)

        setContentView(R.layout.activity_vlc_player)

        videoUrl = intent.getStringExtra("url")
        videoTitle = intent.getStringExtra("title")
        initialPosition = intent.getLongExtra("position", 0)

        videoLayout = findViewById(R.id.video_layout)
        playPauseBtn = findViewById(R.id.play_pause_btn)
        seekBar = findViewById(R.id.seek_bar)
        timeDisplay = findViewById(R.id.time_display)
        controlsOverlay = findViewById(R.id.controls_overlay)
        loadingProgress = findViewById(R.id.loading_progress)

        findViewById<TextView>(R.id.video_title).text = videoTitle
        findViewById<ImageButton>(R.id.back_btn).setOnClickListener { finishWithResult() }

        val args = ArrayList<String>()
        args.add("-vvv")
        args.add("--http-reconnect")
        args.add("--network-caching=2000")

        libVLC = LibVLC(this, args)
        mediaPlayer = MediaPlayer(libVLC)
        mediaPlayer?.attachViews(videoLayout!!, null, true, false)

        val media = Media(libVLC, Uri.parse(videoUrl))
        mediaPlayer?.media = media
        media.release()

        mediaPlayer?.play()
        if (initialPosition > 0) {
            mediaPlayer?.time = initialPosition
        }

        setupListeners()
        startHideTimer()
    }

    private fun setupListeners() {
        playPauseBtn.setOnClickListener {
            if (mediaPlayer?.isPlaying == true) {
                mediaPlayer?.pause()
                playPauseBtn.setImageResource(android.R.drawable.ic_media_play)
            } else {
                mediaPlayer?.play()
                playPauseBtn.setImageResource(android.R.drawable.ic_media_pause)
            }
            startHideTimer()
        }

        seekBar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(p0: SeekBar?, progress: Int, fromUser: Boolean) {
                if (fromUser) {
                    mediaPlayer?.time = progress.toLong()
                }
            }
            override fun onStartTrackingTouch(p0: SeekBar?) {}
            override fun onStopTrackingTouch(p0: SeekBar?) {
                startHideTimer()
            }
        })

        findViewById<View>(R.id.root_layout).setOnClickListener {
            toggleControls()
        }

        mediaPlayer?.setEventListener { event ->
            when (event.type) {
                MediaPlayer.Event.PositionChanged -> {
                    runOnUiThread {
                        seekBar.max = mediaPlayer?.length?.toInt() ?: 0
                        seekBar.progress = mediaPlayer?.time?.toInt() ?: 0
                        timeDisplay.text = formatTime(mediaPlayer?.time ?: 0) + " / " + formatTime(mediaPlayer?.length ?: 0)
                    }
                }
                MediaPlayer.Event.Buffering -> {
                    runOnUiThread {
                        loadingProgress.visibility = if (event.buffering < 100f) View.VISIBLE else View.GONE
                    }
                }
            }
        }
    }

    private fun toggleControls() {
        isControlsVisible = !isControlsVisible
        controlsOverlay.visibility = if (isControlsVisible) View.VISIBLE else View.GONE
        if (isControlsVisible) startHideTimer()
    }

    private fun startHideTimer() {
        hideTimer?.cancel()
        hideTimer = Timer()
        hideTimer?.schedule(3000) {
            runOnUiThread {
                isControlsVisible = false
                controlsOverlay.visibility = View.GONE
            }
        }
    }

    private fun formatTime(millis: Long): String {
        val seconds = (millis / 1000) % 60
        val minutes = (millis / (1000 * 60)) % 60
        val hours = (millis / (1000 * 60 * 60)) % 24
        return if (hours > 0) String.format("%d:%02d:%02d", hours, minutes, seconds)
        else String.format("%02d:%02d", minutes, seconds)
    }

    private fun finishWithResult() {
        val resultIntent = Intent()
        resultIntent.putExtra("position", mediaPlayer?.time ?: 0L)
        setResult(RESULT_OK, resultIntent)
        finish()
    }

    override fun onBackPressed() {
        finishWithResult()
    }

    override fun onStop() {
        super.onStop()
        mediaPlayer?.stop()
        mediaPlayer?.detachViews()
    }

    override fun onDestroy() {
        super.onDestroy()
        mediaPlayer?.release()
        libVLC?.release()
    }
}
