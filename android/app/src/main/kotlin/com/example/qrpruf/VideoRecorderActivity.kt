package com.example.qrpruf

import android.Manifest
import android.annotation.SuppressLint
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.SurfaceTexture
import android.graphics.drawable.GradientDrawable
import android.hardware.camera2.*
import android.media.MediaRecorder
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.view.Gravity
import android.view.Surface
import android.view.TextureView
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import java.io.File
import java.util.Timer
import java.util.TimerTask

class VideoRecorderActivity : AppCompatActivity() {

    companion object {
        const val RESULT_FILE_PATH = "file_path"
        private const val BITRATE    = 2_500_000   // 2.5 Mbps → ~18.75 MB/min at 720p
        private const val HARD_CAP   = 300          // absolute maximum seconds
        private val TEAL = Color.parseColor("#5BBDB1")
    }

    // Views
    private lateinit var textureView: TextureView
    private lateinit var recordBtn: TextView
    private lateinit var timerText: TextView
    private lateinit var sizeText: TextView
    private lateinit var hintText: TextView

    // Camera2
    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var backgroundThread: HandlerThread? = null
    private var backgroundHandler: Handler? = null
    private var cameraId: String = "0"
    private var sensorOrientation: Int = 90

    // Recorder
    private var mediaRecorder: MediaRecorder? = null
    private var isRecording = false
    private var outputPath = ""

    // Timer — maxSeconds comes from the Flutter caller (quota-aware)
    private var maxSeconds = HARD_CAP
    private var secondsElapsed = 0
    private var countdownTimer: Timer? = null

    // ── Lifecycle ─────────────────────────────────────────────────────────

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        maxSeconds = intent.getIntExtra("maxSeconds", HARD_CAP).coerceIn(1, HARD_CAP)
        window.setFlags(
            WindowManager.LayoutParams.FLAG_FULLSCREEN,
            WindowManager.LayoutParams.FLAG_FULLSCREEN
        )
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        buildUI()
    }

    override fun onResume() {
        super.onResume()
        startBackgroundThread()
        if (textureView.isAvailable) openCamera()
        else textureView.surfaceTextureListener = surfaceListener
    }

    override fun onPause() {
        closeCamera()
        stopBackgroundThread()
        super.onPause()
    }

    override fun onBackPressed() {
        if (isRecording) stopAndReturn(cancelled = true) else { setResult(RESULT_CANCELED); finish() }
    }

    // ── UI ────────────────────────────────────────────────────────────────

    private fun buildUI() {
        val root = FrameLayout(this).apply { setBackgroundColor(Color.BLACK) }

        // Preview
        textureView = TextureView(this)
        root.addView(textureView, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ))

        // Timer
        timerText = TextView(this).apply {
            text = "00:00"
            textSize = 36f
            setTextColor(Color.WHITE)
            setShadowLayer(6f, 0f, 2f, Color.BLACK)
            gravity = Gravity.CENTER
        }
        root.addView(timerText, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        ).also {
            it.gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            it.topMargin = dp(60)
        })

        // Size estimate
        sizeText = TextView(this).apply {
            text = "~0.0 MB"
            textSize = 14f
            setTextColor(Color.WHITE)
            setShadowLayer(4f, 0f, 1f, Color.BLACK)
            gravity = Gravity.CENTER
        }
        root.addView(sizeText, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        ).also {
            it.gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            it.topMargin = dp(110)
        })

        // Hint
        hintText = TextView(this).apply {
            text = "اضغط للتسجيل"
            textSize = 13f
            setTextColor(Color.WHITE)
            setShadowLayer(4f, 0f, 1f, Color.BLACK)
        }
        root.addView(hintText, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        ).also {
            it.gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            it.bottomMargin = dp(170)
        })

        // Record / Stop button
        recordBtn = TextView(this).apply {
            text = "⏺"
            textSize = 28f
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            background = circleDrawable(Color.RED)
            setOnClickListener { toggleRecording() }
        }
        root.addView(recordBtn, FrameLayout.LayoutParams(dp(80), dp(80)).also {
            it.gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            it.bottomMargin = dp(70)
        })

        // Cancel button
        val cancelBtn = TextView(this).apply {
            text = "إلغاء"
            textSize = 16f
            setTextColor(Color.WHITE)
            setShadowLayer(4f, 0f, 1f, Color.BLACK)
            setOnClickListener {
                if (isRecording) stopAndReturn(cancelled = true)
                else { setResult(RESULT_CANCELED); finish() }
            }
        }
        root.addView(cancelBtn, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        ).also {
            it.gravity = Gravity.BOTTOM or Gravity.START
            it.bottomMargin = dp(100)
            it.leftMargin = dp(40)
        })

        setContentView(root)
        textureView.surfaceTextureListener = surfaceListener
    }

    private fun circleDrawable(color: Int) = GradientDrawable().apply {
        shape = GradientDrawable.OVAL
        setColor(color)
    }

    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()

    // ── Camera ────────────────────────────────────────────────────────────

    private val surfaceListener = object : TextureView.SurfaceTextureListener {
        override fun onSurfaceTextureAvailable(s: SurfaceTexture, w: Int, h: Int) = openCamera()
        override fun onSurfaceTextureSizeChanged(s: SurfaceTexture, w: Int, h: Int) {}
        override fun onSurfaceTextureDestroyed(s: SurfaceTexture) = false
        override fun onSurfaceTextureUpdated(s: SurfaceTexture) {}
    }

    @SuppressLint("MissingPermission")
    private fun openCamera() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
            != PackageManager.PERMISSION_GRANTED) {
            setResult(RESULT_CANCELED); finish(); return
        }
        val manager = getSystemService(CAMERA_SERVICE) as CameraManager
        cameraId = manager.cameraIdList.first()
        sensorOrientation = manager.getCameraCharacteristics(cameraId)
            .get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 90
        manager.openCamera(cameraId, cameraStateCallback, backgroundHandler)
    }

    private val cameraStateCallback = object : CameraDevice.StateCallback() {
        override fun onOpened(camera: CameraDevice) { cameraDevice = camera; startPreview() }
        override fun onDisconnected(camera: CameraDevice) { camera.close(); cameraDevice = null }
        override fun onError(camera: CameraDevice, error: Int) { camera.close(); cameraDevice = null; finish() }
    }

    private fun startPreview() {
        val st = textureView.surfaceTexture ?: return
        st.setDefaultBufferSize(1280, 720)
        val previewSurface = Surface(st)

        val previewRequest = cameraDevice!!
            .createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW)
            .also { it.addTarget(previewSurface) }

        @Suppress("DEPRECATION")
        cameraDevice!!.createCaptureSession(
            listOf(previewSurface),
            object : CameraCaptureSession.StateCallback() {
                override fun onConfigured(session: CameraCaptureSession) {
                    captureSession = session
                    previewRequest.set(CaptureRequest.CONTROL_MODE, CameraMetadata.CONTROL_MODE_AUTO)
                    session.setRepeatingRequest(previewRequest.build(), null, backgroundHandler)
                }
                override fun onConfigureFailed(session: CameraCaptureSession) {}
            },
            backgroundHandler
        )
    }

    private fun closeCamera() {
        countdownTimer?.cancel()
        try { captureSession?.stopRepeating() } catch (_: Exception) {}
        captureSession?.close(); captureSession = null
        cameraDevice?.close(); cameraDevice = null
        try { if (isRecording) mediaRecorder?.stop() } catch (_: Exception) {}
        mediaRecorder?.release(); mediaRecorder = null
        isRecording = false
    }

    // ── Recording ─────────────────────────────────────────────────────────

    private fun toggleRecording() {
        if (isRecording) stopAndReturn(cancelled = false) else startRecording()
    }

    private fun setupMediaRecorder() {
        val dir = getExternalFilesDir(null) ?: filesDir
        outputPath = "${dir.path}/qrpruf_${System.currentTimeMillis()}.mp4"

        mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(this)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }

        mediaRecorder!!.apply {
            setAudioSource(MediaRecorder.AudioSource.MIC)
            setVideoSource(MediaRecorder.VideoSource.SURFACE)
            setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            setVideoEncoder(MediaRecorder.VideoEncoder.H264)
            setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            setVideoEncodingBitRate(BITRATE)    // 2.5 Mbps — enforced natively
            setAudioEncodingBitRate(64_000)
            setVideoFrameRate(30)
            setVideoSize(1280, 720)             // 720p
            setOrientationHint(sensorOrientation)
            setOutputFile(outputPath)
            prepare()
        }
    }

    private fun startRecording() {
        try {
            setupMediaRecorder()

            val st = textureView.surfaceTexture ?: return
            st.setDefaultBufferSize(1280, 720)
            val previewSurface  = Surface(st)
            val recorderSurface = mediaRecorder!!.surface

            val recordRequest = cameraDevice!!
                .createCaptureRequest(CameraDevice.TEMPLATE_RECORD)
                .also {
                    it.addTarget(previewSurface)
                    it.addTarget(recorderSurface)
                }

            @Suppress("DEPRECATION")
            cameraDevice!!.createCaptureSession(
                listOf(previewSurface, recorderSurface),
                object : CameraCaptureSession.StateCallback() {
                    override fun onConfigured(session: CameraCaptureSession) {
                        captureSession = session
                        recordRequest.set(CaptureRequest.CONTROL_MODE, CameraMetadata.CONTROL_MODE_AUTO)
                        session.setRepeatingRequest(recordRequest.build(), null, backgroundHandler)
                        mediaRecorder?.start()
                        isRecording = true
                        secondsElapsed = 0
                        runOnUiThread {
                            recordBtn.background = circleDrawable(Color.DKGRAY)
                            recordBtn.text = "⏹"
                            hintText.text = "اضغط للإيقاف"
                            startTimer()
                        }
                    }
                    override fun onConfigureFailed(session: CameraCaptureSession) {}
                },
                backgroundHandler
            )
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun stopAndReturn(cancelled: Boolean) {
        countdownTimer?.cancel(); countdownTimer = null
        try { captureSession?.stopRepeating(); captureSession?.abortCaptures() } catch (_: Exception) {}
        try { mediaRecorder?.stop() } catch (_: Exception) {}
        mediaRecorder?.release(); mediaRecorder = null
        isRecording = false

        if (cancelled || outputPath.isEmpty()) {
            runCatching { File(outputPath).delete() }
            setResult(RESULT_CANCELED)
        } else {
            setResult(RESULT_OK, Intent().putExtra(RESULT_FILE_PATH, outputPath))
        }
        finish()
    }

    // ── Timer ─────────────────────────────────────────────────────────────

    private fun startTimer() {
        countdownTimer = Timer()
        countdownTimer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                secondsElapsed++
                val estimatedMB = secondsElapsed * BITRATE / 8.0 / 1_000_000.0
                val min = secondsElapsed / 60
                val sec = secondsElapsed % 60
                runOnUiThread {
                    timerText.text = String.format("%02d:%02d", min, sec)
                    sizeText.text  = String.format("~%.1f MB", estimatedMB)
                }
                if (secondsElapsed >= maxSeconds) {
                    runOnUiThread { stopAndReturn(cancelled = false) }
                }
            }
        }, 1000L, 1000L)
    }

    // ── Background thread ─────────────────────────────────────────────────

    private fun startBackgroundThread() {
        backgroundThread = HandlerThread("CamBG").also { it.start() }
        backgroundHandler = Handler(backgroundThread!!.looper)
    }

    private fun stopBackgroundThread() {
        backgroundThread?.quitSafely()
        try { backgroundThread?.join() } catch (_: InterruptedException) {}
        backgroundThread = null
        backgroundHandler = null
    }
}
