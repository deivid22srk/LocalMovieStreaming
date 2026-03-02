package com.localmovie.streaming.local_movie_streaming

import android.app.PictureInPictureParams
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.util.Rational
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.ProgressBar
import android.widget.SeekBar
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import org.videolan.libvlc.LibVLC
import org.videolan.libvlc.Media
import org.videolan.libvlc.MediaPlayer
import org.videolan.libvlc.util.VLCVideoLayout
import java.util.Timer
import kotlin.concurrent.schedule

class VlcPlayerActivity : AppCompatActivity() {

    private val TAG = "VlcPlayerActivity"
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

    private val aspectRatios = arrayOf(null, "16:9", "4:3", "16:10", "2.35:1")
    private var currentAspectRatioIndex = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        hideSystemUI()

        setContentView(R.layout.activity_vlc_player)

        videoUrl = intent.getStringExtra("url")
        videoTitle = intent.getStringExtra("title")
        initialPosition = intent.getLongExtra("position", 0L)

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
        args.add("--network-caching=5000")
        args.add("--avcodec-hw=all")
        args.add("--drop-late-frames")
        args.add("--skip-frames")
        args.add("--clock-jitter=0")
        args.add("--clock-synchro=0")

        try {
            libVLC = LibVLC(this, args)
            mediaPlayer = MediaPlayer(libVLC)
            mediaPlayer?.attachViews(videoLayout!!, null, true, false)

            if (videoUrl != null) {
                Log.d(TAG, "Loading URL: $videoUrl")
                val media = Media(libVLC, Uri.parse(videoUrl))
                mediaPlayer?.media = media
                media.release()
            }

            mediaPlayer?.play()
            if (initialPosition > 0) {
                mediaPlayer?.time = initialPosition
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing VLC", e)
        }

        setupListeners()
        startHideTimer()
    }

    private fun hideSystemUI() {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        WindowInsetsControllerCompat(window, window.decorView).let { controller ->
            controller.hide(WindowInsetsCompat.Type.systemBars())
            controller.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        }
    }

    private fun cycleAspectRatio() {
        currentAspectRatioIndex = (currentAspectRatioIndex + 1) % aspectRatios.size
        val newRatio = aspectRatios[currentAspectRatioIndex]
        mediaPlayer?.aspectRatio = newRatio
        val toastText = if (newRatio == null) "Original" else newRatio
        android.widget.Toast.makeText(this, "Aspect Ratio: $toastText", android.widget.Toast.LENGTH_SHORT).show()
        Log.d(TAG, "Aspect Ratio changed to: $newRatio")
    }

    private fun enterPipMode() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(Rational(16, 9))
                .build()
            enterPictureInPictureMode(params)
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        if (isInPictureInPictureMode) {
            controlsOverlay.visibility = View.GONE
        } else {
            controlsOverlay.visibility = if (isControlsVisible) View.VISIBLE else View.GONE
        }
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

        findViewById<ImageButton>(R.id.aspect_ratio_btn).setOnClickListener {
            cycleAspectRatio()
            startHideTimer()
        }

        findViewById<ImageButton>(R.id.pip_btn).setOnClickListener {
            enterPipMode()
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
                MediaPlayer.Event.EncounteredError -> {
                    Log.e(TAG, "VLC Player encountered error")
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
        val currentPos = mediaPlayer?.time ?: 0L
        // Only return positive position, otherwise return initial position to avoid overwriting with 0/negative
        resultIntent.putExtra("position", if (currentPos > 0) currentPos else initialPosition)
        setResult(RESULT_OK, resultIntent)
        finish()
    }

    override fun onBackPressed() {
        finishWithResult()
    }

    override fun onStop() {
        super.onStop()
        if (isFinishing) {
            val resultIntent = Intent()
            val currentPos = mediaPlayer?.time ?: 0L
            resultIntent.putExtra("position", if (currentPos > 0) currentPos else initialPosition)
            setResult(RESULT_OK, resultIntent)
        }
        mediaPlayer?.stop()
        mediaPlayer?.detachViews()
    }

    override fun onDestroy() {
        super.onDestroy()
        mediaPlayer?.release()
        libVLC?.release()
    }
}
