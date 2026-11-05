package club.librum.kviz.servisi

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import club.librum.kviz.MainActivity
import club.librum.kviz.R
import java.util.Calendar

/**
 * Dnevni podsetnik u 19:30 (isto kao iOS Napredak.zakaziPodsetnik): lokalno obaveštenje, bez servera.
 * Zakazuje se pri pokretanju aplikacije i pri uključivanju u Podešavanjima; posle restarta telefona čeka prvo pokretanje.
 */
object Podsetnik {
    private const val KANAL = "podsetnik"
    private const val ID = 1930

    fun zakazi(k: Context, ukljuceno: Boolean) {
        val am = k.getSystemService(AlarmManager::class.java) ?: return
        val namera = PendingIntent.getBroadcast(k, ID, Intent(k, PodsetnikPrijemnik::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        am.cancel(namera)
        if (!ukljuceno) return
        val kad = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 19); set(Calendar.MINUTE, 30); set(Calendar.SECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_YEAR, 1)
        }
        // Neprecizno ponavljanje: ne traži posebnu dozvolu za tačne alarme, a stiže u par minuta oko 19:30.
        am.setInexactRepeating(AlarmManager.RTC_WAKEUP, kad.timeInMillis, AlarmManager.INTERVAL_DAY, namera)
    }

    fun posalji(k: Context) {
        val nm = k.getSystemService(NotificationManager::class.java) ?: return
        if (Build.VERSION.SDK_INT >= 26) nm.createNotificationChannel(NotificationChannel(KANAL, "Dnevni podsetnik", NotificationManager.IMPORTANCE_DEFAULT))
        val otvori = PendingIntent.getActivity(k, ID, Intent(k, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val o = NotificationCompat.Builder(k, KANAL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Librum kviz")
            .setContentText("Niz od ${maxOf(1, runCatching { Napredak.deljeni.s.nizDana }.getOrDefault(1))} dana te čeka. Jedan kviz i čuvaš ga.")
            .setContentIntent(otvori)
            .setAutoCancel(true)
            .build()
        runCatching { nm.notify(ID, o) }
    }
}

class PodsetnikPrijemnik : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) = Podsetnik.posalji(context)
}
