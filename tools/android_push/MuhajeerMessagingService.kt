package __PACKAGE__

import android.Manifest
import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class MuhajeerMessagingService : FirebaseMessagingService() {
    override fun onNewToken(token: String) {
        // Dart obtains the current token and re-enrolls it with its authenticated
        // session. Never put a customer session or token into Android logs.
        MuhajeerFcmBridge.tokenUpdated()
    }

    override fun onMessageReceived(message: RemoteMessage) {
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
            != PackageManager.PERMISSION_GRANTED) return
        val note = message.notification ?: return
        val intent = packageManager.getLaunchIntentForPackage(packageName) ?: return
        intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        for (key in listOf("kind", "order_id")) {
            message.data[key]?.let { intent.putExtra(key, it) }
        }
        val id = (message.messageId ?: System.nanoTime().toString()).hashCode()
        val pending = PendingIntent.getActivity(this, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        MuhajeerFcmBridge.channel(this)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, MuhajeerFcmBridge.CHANNEL)
            else Notification.Builder(this)
        val notification = builder.setSmallIcon(R.drawable.ic_muhajeer_notification)
            .setContentTitle(note.title ?: "Muhajeer Books")
            .setContentText(note.body ?: "")
            .setStyle(Notification.BigTextStyle().bigText(note.body ?: ""))
            .setContentIntent(pending).setAutoCancel(true)
            .setCategory(Notification.CATEGORY_MESSAGE).build()
        getSystemService(NotificationManager::class.java).notify(id, notification)
    }
}
