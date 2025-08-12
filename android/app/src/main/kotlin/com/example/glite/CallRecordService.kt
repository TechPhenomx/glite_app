package com.example.glite

import android.app.*
import android.content.Context
import android.content.Intent
import android.media.MediaRecorder
import android.os.Build
import android.os.Environment
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.File
import java.io.IOException
import java.text.SimpleDateFormat
import java.util.*

class CallRecordService : Service() {

    companion object {
        const val ACTION_START_RECORDING = "com.example.glite.action.START_RECORDING"
        const val ACTION_STOP_RECORDING = "com.example.glite.action.STOP_RECORDING"
        const val EXTRA_PHONE_NUMBER = "phone_number"
        const val CHANNEL_ID = "call_record_channel"
    }

    private var mediaRecorder: MediaRecorder? = null
    private var outputFilePath: String? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_RECORDING -> {
                val phoneNumber = intent.getStringExtra(EXTRA_PHONE_NUMBER)
                Log.d("CallRecordService", "Start recording call for: $phoneNumber")
                startForegroundServiceNotification()
                startRecording(phoneNumber)
            }
            ACTION_STOP_RECORDING -> {
                Log.d("CallRecordService", "Stop recording call")
                stopRecording()
                stopSelf()
            }
            else -> {
                Log.d("CallRecordService", "Unknown action: ${intent?.action}")
            }
        }
        return START_NOT_STICKY
    }

    private fun startForegroundServiceNotification() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Call Recording",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (manager.getNotificationChannel(CHANNEL_ID) == null) {
                manager.createNotificationChannel(channel)
            }
        }

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Recording in progress")
            .setContentText("Your call is being recorded")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()

        startForeground(101, notification)
    }

    private fun startRecording(phoneNumber: String?) {
        try {
            // ✅ Save in Downloads/G-Lite folder
            val folder = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "G-Lite")
            if (!folder.exists()) {
                folder.mkdirs()
            }

            val timeStamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
            val safeNumber = phoneNumber?.replace(Regex("[^0-9+]"), "_") ?: "unknown"
            val fileName = "REC_${safeNumber}_$timeStamp.m4a"
            outputFilePath = File(folder, fileName).absolutePath

            mediaRecorder = MediaRecorder().apply {
                try {
                    // First try VOICE_COMMUNICATION (2-way audio)
                    setAudioSource(MediaRecorder.AudioSource.VOICE_COMMUNICATION)
                } catch (e: Exception) {
                    // Fallback to MIC if VOICE_COMMUNICATION fails
                    Log.w("CallRecordService", "VOICE_COMMUNICATION not supported, using MIC")
                    setAudioSource(MediaRecorder.AudioSource.MIC)
                }
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioEncodingBitRate(128000)
                setAudioSamplingRate(44100)
                setOutputFile(outputFilePath)
                prepare()
                start()
            }

            Log.d("CallRecordService", "Recording started: $outputFilePath")

        } catch (e: IOException) {
            Log.e("CallRecordService", "startRecording: IOException: ${e.message}")
        } catch (e: Exception) {
            Log.e("CallRecordService", "startRecording: Exception: ${e.message}")
        }
    }

    private fun stopRecording() {
        try {
            mediaRecorder?.apply {
                stop()
                release()
            }
            Log.d("CallRecordService", "Recording saved: $outputFilePath")
        } catch (e: Exception) {
            Log.e("CallRecordService", "stopRecording: ${e.message}")
        } finally {
            mediaRecorder = null
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        stopRecording()
    }
}
