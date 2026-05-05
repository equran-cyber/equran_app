package com.app.equran

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import android.view.Display
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
    private val notificationPermissionChannelName = "com.app.equran/notification_permissions"
    private val downloadChannelId = "com.app.equran.downloads"
    private val downloadChannelName = "Audio Downloads"
    private val refreshRateLogTag = "EquranRefreshRate"
    private val prayerNotificationPermissionRequestCode = 4201
    private var pendingPrayerNotificationPermissionResult: MethodChannel.Result? = null

    private data class RefreshRateChoice(
        val modeId: Int,
        val refreshRate: Float,
        val width: Int,
        val height: Int
    ) {
        fun toResultMap(): Map<String, Any> = mapOf(
            "modeId" to modeId,
            "refreshRate" to refreshRate,
            "width" to width,
            "height" to height
        )
    }

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
                    "setPreferredFrameRate" -> {
                        val frameRate = call.argument<Number>("frameRate")?.toFloat() ?: 0f
                        runOnUiThread {
                            applyPreferredFrameRate(frameRate)
                        }
                        result.success(null)
                    }
                    "requestLowestRefreshRate" -> {
                        runOnUiThread {
                            result.success(requestLowestRefreshRate()?.toResultMap())
                        }
                    }
                    "requestRefreshRate" -> {
                        val frameRate = call.argument<Number>("frameRate")?.toFloat() ?: 0f
                        runOnUiThread {
                            result.success(requestRefreshRate(frameRate)?.toResultMap())
                        }
                    }
                    "clearRefreshRatePreference" -> {
                        runOnUiThread {
                            clearRefreshRatePreference()
                            result.success(null)
                        }
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, notificationPermissionChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkNotificationPermission" -> {
                        result.success(notificationPermissionStatus())
                    }
                    "requestNotificationPermission" -> {
                        requestPrayerNotificationPermission(result)
                    }
                    "openNotificationSettings" -> {
                        result.success(openNotificationSettings())
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun applyPreferredFrameRate(frameRate: Float) {
        if (frameRate <= 0f) {
            clearRefreshRatePreference()
            return
        }

        val mode = findClosestRefreshMode(frameRate)
        if (mode != null) {
            applyPreferredRefreshMode(mode, "requested ${frameRate}Hz")
            return
        }

        val layoutParams = window.attributes
        layoutParams.preferredRefreshRate = frameRate
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            layoutParams.preferredDisplayModeId = 0
        }
        window.attributes = layoutParams
        Log.d(refreshRateLogTag, "Preferred refresh rate hint set to ${frameRate}Hz")
    }

    private fun requestLowestRefreshRate(): RefreshRateChoice? {
        val mode = findLowestRefreshMode()
        if (mode == null) {
            Log.d(
                refreshRateLogTag,
                "Static minimized player requested low refresh, but display modes are unavailable"
            )
            return null
        }

        // This asks Android to prefer the lowest advertised mode for a static Flutter surface.
        // True LTPO 1Hz idle behavior remains OS/panel controlled and is not forceable here.
        applyPreferredRefreshMode(mode, "static minimized audio UI")
        return mode
    }

    private fun requestRefreshRate(frameRate: Float): RefreshRateChoice? {
        if (frameRate <= 0f) {
            clearRefreshRatePreference()
            return null
        }

        val mode = findClosestRefreshMode(frameRate)
        if (mode == null) {
            applyPreferredFrameRate(frameRate)
            return null
        }

        applyPreferredRefreshMode(mode, "requested ${frameRate}Hz")
        return mode
    }

    private fun clearRefreshRatePreference() {
        val layoutParams = window.attributes
        layoutParams.preferredRefreshRate = 0f
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            layoutParams.preferredDisplayModeId = 0
        }
        window.attributes = layoutParams
        Log.d(refreshRateLogTag, "Refresh-rate preference cleared")
    }

    private fun applyPreferredRefreshMode(choice: RefreshRateChoice, reason: String) {
        val layoutParams = window.attributes
        layoutParams.preferredRefreshRate = choice.refreshRate
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            layoutParams.preferredDisplayModeId = choice.modeId
        }
        window.attributes = layoutParams
        Log.d(
            refreshRateLogTag,
            "Preferred display mode ${choice.modeId} @ ${choice.refreshRate}Hz " +
                "(${choice.width}x${choice.height}) for $reason"
        )
    }

    private fun findLowestRefreshMode(): RefreshRateChoice? {
        return supportedModesAtCurrentResolution()
            .filter { it.refreshRate > 0f }
            .minByOrNull { it.refreshRate }
            ?.toRefreshRateChoice()
    }

    private fun findClosestRefreshMode(frameRate: Float): RefreshRateChoice? {
        return supportedModesAtCurrentResolution()
            .filter { it.refreshRate > 0f }
            .minByOrNull { kotlin.math.abs(it.refreshRate - frameRate) }
            ?.toRefreshRateChoice()
    }

    private fun supportedModesAtCurrentResolution(): List<Display.Mode> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return emptyList()

        val display = windowManager.defaultDisplay
        val currentMode = display.mode
        val modes = display.supportedModes.toList()
        val sameResolutionModes = modes.filter {
            it.physicalWidth == currentMode.physicalWidth &&
                it.physicalHeight == currentMode.physicalHeight
        }

        return sameResolutionModes.ifEmpty { modes }
    }

    private fun Display.Mode.toRefreshRateChoice(): RefreshRateChoice {
        return RefreshRateChoice(
            modeId = modeId,
            refreshRate = refreshRate,
            width = physicalWidth,
            height = physicalHeight
        )
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

    private fun notificationPermissionStatus(): String {
        val notificationsEnabled = NotificationManagerCompat.from(this).areNotificationsEnabled()
        if (!notificationsEnabled) return "denied"
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return "granted"
        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
        return if (granted) "granted" else "denied"
    }

    private fun requestPrayerNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(notificationPermissionStatus())
            return
        }

        val permission = Manifest.permission.POST_NOTIFICATIONS
        val alreadyGranted = ContextCompat.checkSelfPermission(
            this,
            permission
        ) == PackageManager.PERMISSION_GRANTED
        if (alreadyGranted) {
            result.success(notificationPermissionStatus())
            return
        }

        if (pendingPrayerNotificationPermissionResult != null) {
            result.success(notificationPermissionStatus())
            return
        }

        pendingPrayerNotificationPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(permission),
            prayerNotificationPermissionRequestCode
        )
    }

    private fun openNotificationSettings(): Boolean {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            }
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            }
        }
        return try {
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != prayerNotificationPermissionRequestCode) return

        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED &&
            NotificationManagerCompat.from(this).areNotificationsEnabled()
        pendingPrayerNotificationPermissionResult?.success(
            if (granted) "granted" else "denied"
        )
        pendingPrayerNotificationPermissionResult = null
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
