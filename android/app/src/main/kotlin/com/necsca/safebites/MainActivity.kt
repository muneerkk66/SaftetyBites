package com.necsca.safebites

import android.app.NotificationManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val badgeChannelName = "com.necsca.safebitesapp/badge"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, badgeChannelName)
            .setMethodCallHandler { call, result ->
                val notificationManager =
                    getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                when (call.method) {
                    "hasUnread" -> {
                        val hasUnread = Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                            notificationManager.activeNotifications.isNotEmpty()
                        result.success(hasUnread)
                    }
                    "markUnread" -> result.success(null)
                    "clearUnread" -> {
                        notificationManager.cancelAll()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
