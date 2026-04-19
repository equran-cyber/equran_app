package com.app.equran

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val channelName = "com.app.equran/read_page"
    private val downloadChannelId = "com.app.equran.downloads"
    private val downloadChannelName = "Audio Downloads"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createDownloadNotificationChannel()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setKeepScreenOn" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        runOnUiThread {
                            if (enabled) {
                                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            }
                        }
                        result.success(null)
                    }
                    "showDownloadProgress" -> {
                        val id = call.argument<Int>("id") ?: 1001
                        val title = call.argument<String>("title") ?: "Downloading audio"
                        val progress = call.argument<Int>("progress") ?: 0
                        val max = call.argument<Int>("max") ?: 100
                        val indeterminate = call.argument<Boolean>("indeterminate") ?: false
                        showDownloadProgress(id, title, progress, max, indeterminate)
                        result.success(null)
                    }
                    "completeDownload" -> {
                        val id = call.argument<Int>("id") ?: 1001
                        val title = call.argument<String>("title") ?: "Download complete"
                        completeDownload(id, title)
                        result.success(null)
                    }
                    "failDownload" -> {
                        val id = call.argument<Int>("id") ?: 1001
                        val title = call.argument<String>("title") ?: "Download failed"
                        failDownload(id, title)
                        result.success(null)
                    }
                    "cancelDownloadNotification" -> {
                        val id = call.argument<Int>("id") ?: 1001
                        NotificationManagerCompat.from(this).cancel(id)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun createDownloadNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                downloadChannelId,
                downloadChannelName,
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            1002
        )
    }

    private fun showDownloadProgress(
        id: Int,
        title: String,
        progress: Int,
        max: Int,
        indeterminate: Boolean
    ) {
        requestNotificationPermissionIfNeeded()
        val notification = NotificationCompat.Builder(this, downloadChannelId)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle(title)
            .setContentText(if (indeterminate) "Downloading…" else "$progress%")
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .setProgress(max, progress, indeterminate)
            .build()

        notifyDownload(id, notification)
    }

    private fun completeDownload(id: Int, title: String) {
        val notification = NotificationCompat.Builder(this, downloadChannelId)
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .setContentTitle(title)
            .setContentText("Download complete")
            .setOngoing(false)
            .setAutoCancel(true)
            .build()

        notifyDownload(id, notification)
    }

    private fun failDownload(id: Int, title: String) {
        val notification = NotificationCompat.Builder(this, downloadChannelId)
            .setSmallIcon(android.R.drawable.stat_notify_error)
            .setContentTitle(title)
            .setContentText("Download failed")
            .setOngoing(false)
            .setAutoCancel(true)
            .build()

        notifyDownload(id, notification)
    }

    private fun notifyDownload(id: Int, notification: android.app.Notification) {
        try {
            NotificationManagerCompat.from(this).notify(id, notification)
        } catch (_: SecurityException) {
            // Android 13+ can deny POST_NOTIFICATIONS. Downloads still continue.
        }
    }
}
