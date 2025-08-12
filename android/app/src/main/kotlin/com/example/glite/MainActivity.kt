package com.example.glite

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    private val STORAGE_CHANNEL = "storage_permission"
    private val RECORDING_CHANNEL = "call_recording"
    private val TAG = "MainActivity"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STORAGE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openAllFilesAccessSettings" -> {
                    openAllFilesAccessSettings()
                    result.success(null)
                }
                "createGliteFolder" -> {
                    val created = createGliteFolder()
                    result.success(created)
                }
                "getGliteFolderPath" -> {
                    val path = getGliteFolderPath()
                    result.success(path)
                }
                "hasAllFilesAccess" -> {
                    val hasAccess = hasAllFilesAccess()
                    result.success(hasAccess)
                }
                "checkFolderExists" -> {
                    val exists = checkFolderExists()
                    result.success(exists)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RECORDING_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startRecording" -> {
                    val phoneNumber = call.argument<String>("phoneNumber") ?: "Unknown"
                    startCallRecordingService(phoneNumber)
                    result.success(null)
                }
                "stopRecording" -> {
                    stopCallRecordingService()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasAllFilesAccess(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            true
        }
    }

    private fun checkFolderExists(): Boolean {
        return try {
            val gliteDir = File(Environment.getExternalStorageDirectory(), "glite")
            gliteDir.exists() && gliteDir.isDirectory
        } catch (e: Exception) {
            Log.e(TAG, "Error checking folder existence: ${e.message}")
            false
        }
    }

    private fun openAllFilesAccessSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
                intent.data = Uri.parse("package:$packageName")
                startActivity(intent)
                Log.d(TAG, "Opened app-specific all files access settings")
            } catch (e: Exception) {
                Log.w(TAG, "Failed to open app-specific settings, opening general settings")
                try {
                    val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                    startActivity(intent)
                } catch (ex: Exception) {
                    Log.e(TAG, "Failed to open any all files access settings: ${ex.message}")
                }
            }
        } else {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            intent.data = Uri.parse("package:$packageName")
            startActivity(intent)
            Log.d(TAG, "Opened app settings for older Android version")
        }
    }

    private fun createGliteFolder(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && !Environment.isExternalStorageManager()) {
                Log.e(TAG, "All files access permission not granted")
                return false
            }

            val gliteDir = File(Environment.getExternalStorageDirectory(), "glite")
            if (!gliteDir.exists()) {
                val created = gliteDir.mkdirs()
                if (!created) {
                    Log.e(TAG, "Failed to create glite folder at: ${gliteDir.absolutePath}")
                    return false
                }
                Log.d(TAG, "Successfully created glite folder at: ${gliteDir.absolutePath}")
            }

            val noMediaFile = File(gliteDir, ".nomedia")
            if (!noMediaFile.exists()) {
                val created = noMediaFile.createNewFile()
                if (created) {
                    Log.d(TAG, "Created .nomedia file")
                }
            }

            val recordingsDir = File(gliteDir, "CallRecordings")
            if (!recordingsDir.exists()) {
                val created = recordingsDir.mkdirs()
                if (!created) {
                    Log.e(TAG, "Failed to create CallRecordings folder at: ${recordingsDir.absolutePath}")
                    return false
                }
                Log.d(TAG, "Successfully created CallRecordings folder at: ${recordingsDir.absolutePath}")
            }

            true
        } catch (e: Exception) {
            Log.e(TAG, "Error creating folders: ${e.message}")
            false
        }
    }

    private fun getGliteFolderPath(): String {
        return try {
            File(Environment.getExternalStorageDirectory(), "glite").absolutePath
        } catch (e: Exception) {
            Log.e(TAG, "Error getting glite folder path: ${e.message}")
            ""
        }
    }

    private fun startCallRecordingService(phoneNumber: String) {
        try {
            val intent = Intent(this, CallRecordService::class.java)
            intent.action = CallRecordService.ACTION_START_RECORDING
            intent.putExtra(CallRecordService.EXTRA_PHONE_NUMBER, phoneNumber)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }

            Log.d(TAG, "Started call recording service for: $phoneNumber")
        } catch (e: Exception) {
            Log.e(TAG, "Error starting call recording service: ${e.message}")
        }
    }

    private fun stopCallRecordingService() {
        try {
            val intent = Intent(this, CallRecordService::class.java)
            intent.action = CallRecordService.ACTION_STOP_RECORDING
            startService(intent)

            Log.d(TAG, "Stopped call recording service")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping call recording service: ${e.message}")
        }
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "Activity resumed")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (Environment.isExternalStorageManager()) {
                Log.d(TAG, "All files access granted, attempting to create folder")
                createGliteFolder()
            } else {
                Log.d(TAG, "All files access not granted")
            }
        } else {
            createGliteFolder()
        }
    }
}
