package com.example.sim_vault

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder

class KeepAliveService : Service() {
    private val CHANNEL_ID = "sim_vault_keep_alive"

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        val notification: Notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
                .setContentTitle("SIMVault 守护运行中")
                .setContentText("保障到期提醒不被系统拦截")
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .build()
        } else {
            Notification.Builder(this)
                .setContentTitle("SIMVault 守护运行中")
                .setContentText("保障到期提醒不被系统拦截")
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .build()
        }
        startForeground(999, notification)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // START_STICKY ensures the OS recreates the service if it is killed.
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        // Self-revive when swiped away from recents
        val restartServiceIntent = Intent(applicationContext, this.javaClass)
        restartServiceIntent.setPackage(packageName)
        startService(restartServiceIntent)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "后台守护服务",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }
}
