package com.example.pickup_app

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ConcurrentLinkedQueue

class CourierNotificationListenerService : NotificationListenerService() {

    companion object {
        private var methodChannel: MethodChannel? = null
        private val pendingNotifications = ConcurrentLinkedQueue<Map<String, String>>()

        private val COURIER_PACKAGES = setOf(
            "com.jingdong.app.mall",           // JD
            "com.taobao.taobao",               // Taobao
            "com.tmall.wireless",              // Tmall
            "com.cainiao.wireless",            // Cainiao
            "com.xunmeng.pinduoduo",           // PDD
            "com.ss.android.ugc.aweme.lite",   // Douyin Lite
            "com.ss.android.ugc.aweme",        // Douyin
            "com.sf.activity",                 // SF Express
            "com.zto.express",                 // ZTO
            "com.yunda.express",               // YD
            "com.yuantong.express",            // YT
            "com.sto.express",                 // STO
            "com.jt.express",                  // JT Express
            "com.deppon.express",              // Deppon
            "com.ems.express",                 // EMS
            "com.android.shell",               // ADB testing
        )

        fun setChannel(channel: MethodChannel) {
            methodChannel = channel
            flushPending()
        }

        private fun flushPending() {
            while (pendingNotifications.isNotEmpty()) {
                val notification = pendingNotifications.poll()
                methodChannel?.invokeMethod("onNotification", notification)
            }
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName !in COURIER_PACKAGES) return

        val extras = sbn.notification.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""

        if (title.isEmpty() && text.isEmpty()) return

        val data = mapOf(
            "title" to title,
            "text" to text,
            "packageName" to sbn.packageName,
        )

        val channel = methodChannel
        if (channel != null) {
            channel.invokeMethod("onNotification", data)
        } else {
            pendingNotifications.add(data)
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        // No action needed
    }
}
