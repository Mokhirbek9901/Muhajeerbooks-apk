package __PACKAGE__

import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import com.google.firebase.FirebaseApp
import com.google.firebase.messaging.FirebaseMessaging
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

object MuhajeerFcmBridge {
    const val CHANNEL = "muhajeer_books"
    private var channel: MethodChannel? = null
    private var activity: Activity? = null

    fun channel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(NotificationChannel(
                CHANNEL, "Muhajeer Books", NotificationManager.IMPORTANCE_HIGH
            ).apply { description = "Buyurtmalar va kitob yangiliklari" })
        }
    }

    fun attach(owner: Activity, engine: FlutterEngine) {
        activity = owner
        channel(owner)
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, "muhajeerbooks/android_fcm")
        channel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "getToken" -> {
                    if (Settings.System.getString(owner.contentResolver, "firebase.test.lab") == "true") {
                        result.success("")
                    } else if (FirebaseApp.getApps(owner).isEmpty()) {
                        result.error("fcm_unconfigured", "Bildirishnoma xizmati hali ulanmagan", null)
                    } else {
                        val messaging = FirebaseMessaging.getInstance()
                        messaging.isAutoInitEnabled = true
                        messaging.token.addOnCompleteListener { task ->
                            if (task.isSuccessful) result.success(task.result)
                            else result.error("fcm_registration", "Bildirishnomani ulab bo‘lmadi", null)
                        }
                    }
                }
                "getPendingNotification" -> result.success(consume(owner.intent))
                else -> result.notImplemented()
            }
        }
    }

    fun detach(owner: Activity) {
        if (activity === owner) {
            channel?.setMethodCallHandler(null)
            channel = null
            activity = null
        }
    }

    fun tokenUpdated() {
        Handler(Looper.getMainLooper()).post { channel?.invokeMethod("tokenUpdated", null) }
    }

    private fun consume(intent: Intent?): Map<String, String>? {
        if (intent == null) return null
        val kind = intent.getStringExtra("kind") ?: return null
        if (kind !in listOf("admin_new_order", "customer_order", "customer_broadcast")) return null
        val data = mapOf("kind" to kind, "order_id" to (intent.getStringExtra("order_id") ?: ""))
        intent.removeExtra("kind")
        intent.removeExtra("order_id")
        return data
    }

    fun opened(intent: Intent) {
        val data = consume(intent) ?: return
        channel?.invokeMethod("notificationTapped", data)
    }
}
