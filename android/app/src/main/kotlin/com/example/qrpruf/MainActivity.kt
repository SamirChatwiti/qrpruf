package com.example.qrpruf

import android.content.Intent
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    private val TRIM_CHANNEL  = "com.qrpruf/media_trim"
    private val VIDEO_CHANNEL = "com.qrpruf/video_recorder"
    private val VIDEO_REQUEST = 1002
    private val TAG = "MainActivity"

    private var pendingVideoResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Trim channel (existing) ──────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TRIM_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "trimMedia") {
                    val inputPath  = call.argument<String>("inputPath")!!
                    val outputPath = call.argument<String>("outputPath")!!
                    val maxSeconds = call.argument<Int>("maxSeconds")!!
                    Thread {
                        try {
                            trimMedia(inputPath, outputPath, maxSeconds.toLong() * 1_000_000L)
                            result.success(outputPath)
                        } catch (e: Exception) {
                            Log.e(TAG, "Trim failed: ${e.message}", e)
                            result.error("TRIM_ERROR", e.message, null)
                        }
                    }.start()
                } else {
                    result.notImplemented()
                }
            }

        // ── Native video recorder channel ────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VIDEO_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "recordVideo") {
                    val maxSeconds = call.argument<Int>("maxSeconds") ?: 300
                    pendingVideoResult = result
                    val intent = Intent(this, VideoRecorderActivity::class.java)
                    intent.putExtra("maxSeconds", maxSeconds)
                    startActivityForResult(intent, VIDEO_REQUEST)
                } else {
                    result.notImplemented()
                }
            }
    }

    @Suppress("OVERRIDE_DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VIDEO_REQUEST) {
            val filePath = if (resultCode == RESULT_OK)
                data?.getStringExtra(VideoRecorderActivity.RESULT_FILE_PATH)
            else null
            pendingVideoResult?.success(filePath)
            pendingVideoResult = null
        }
    }

    // ── Media trim (existing) ────────────────────────────────────────────

    private fun trimMedia(inputPath: String, outputPath: String, maxDurationUs: Long) {
        Log.d(TAG, "trimMedia: input=$inputPath output=$outputPath maxUs=$maxDurationUs")
        File(outputPath).parentFile?.mkdirs()

        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(inputPath)
            val muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            val trackMap = mutableMapOf<Int, Int>()

            for (i in 0 until extractor.trackCount) {
                val trackFormat = extractor.getTrackFormat(i)
                val mime = trackFormat.getString(MediaFormat.KEY_MIME) ?: continue
                if (mime.startsWith("video/") || mime.startsWith("audio/")) {
                    trackMap[i] = muxer.addTrack(trackFormat)
                }
            }

            if (trackMap.isEmpty()) {
                muxer.release()
                throw Exception("No video/audio tracks found in: $inputPath")
            }

            muxer.start()
            for (i in trackMap.keys) extractor.selectTrack(i)
            extractor.seekTo(0, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)

            val buffer = java.nio.ByteBuffer.allocate(2 * 1024 * 1024)
            val bufferInfo = MediaCodec.BufferInfo()
            var sampleCount = 0

            while (true) {
                bufferInfo.offset = 0
                bufferInfo.size = extractor.readSampleData(buffer, 0)
                if (bufferInfo.size < 0) break

                val sampleTime = extractor.sampleTime
                if (sampleTime < 0) { extractor.advance(); continue }
                if (sampleTime > maxDurationUs) break

                bufferInfo.presentationTimeUs = sampleTime
                bufferInfo.flags = if (extractor.sampleFlags and MediaExtractor.SAMPLE_FLAG_SYNC != 0)
                    MediaCodec.BUFFER_FLAG_KEY_FRAME else 0

                val trackIndex = extractor.sampleTrackIndex
                if (trackMap.containsKey(trackIndex)) {
                    muxer.writeSampleData(trackMap[trackIndex]!!, buffer, bufferInfo)
                    sampleCount++
                }
                extractor.advance()
            }

            muxer.stop()
            muxer.release()
            Log.d(TAG, "Trim done: $sampleCount samples -> $outputPath")
        } finally {
            extractor.release()
        }
    }
}
