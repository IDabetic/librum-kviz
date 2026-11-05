package club.librum.kviz.servisi

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import club.librum.kviz.MainActivity
import club.librum.kviz.R
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * Push sa servera (Supabase funkcija `obavesti`, FCM HTTP v1): izazov na duel i novi pratilac, kao APNs na iOS-u.
 * Dok je aplikacija u pozadini sistem sam prikazuje obaveštenje; dok je otvorena, prikazuje ga [onMessageReceived].
 */
class PushServis : FirebaseMessagingService() {
    override fun onNewToken(token: String) {
        // Samo razvojna gradnja: token u logu za probu slanja sa servera bez prijave na emulatoru.
        if (club.librum.kviz.BuildConfig.DEBUG) Log.d("Push", "FCM token: $token")
        CoroutineScope(Dispatchers.IO).launch { Sesija(applicationContext).sacuvajPushToken(token) }
    }

    override fun onMessageReceived(poruka: RemoteMessage) {
        val n = poruka.notification ?: return
        Push.prikazi(applicationContext, n.title ?: "Librum kviz", n.body.orEmpty(), poruka.data)
    }
}

object Push {
    const val KANAL = "obavestenja"

    /** Kanal mora da postoji pre prvog obaveštenja iz pozadine (manifest ga navodi kao podrazumevani). */
    fun napraviKanal(k: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        k.getSystemService(NotificationManager::class.java)
            ?.createNotificationChannel(NotificationChannel(KANAL, "Izazovi i pratioci", NotificationManager.IMPORTANCE_HIGH))
    }

    /**
     * Posle prijave: token uređaja ide u `push_tokeni` (isti red kao iOS, platforma android).
     * Primer: `Push.prijavi(sesija)` iz LaunchedEffect kada je nalog poznat i dozvola data.
     */
    fun prijavi(sesija: Sesija) {
        FirebaseMessaging.getInstance().token
            .addOnSuccessListener { token -> CoroutineScope(Dispatchers.IO).launch { sesija.sacuvajPushToken(token) } }
            .addOnFailureListener { Log.w("Push", "FCM token nije dobijen", it) }
    }

    fun imaDozvolu(k: Context) = Build.VERSION.SDK_INT < 33 ||
        ContextCompat.checkSelfPermission(k, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    fun prikazi(k: Context, naslov: String, tekst: String, podaci: Map<String, String>) {
        if (!imaDozvolu(k)) return
        napraviKanal(k)
        val namera = Intent(k, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
            podaci.forEach { (kljuc, vrednost) -> putExtra(kljuc, vrednost) }
        }
        val otvori = PendingIntent.getActivity(k, naslov.hashCode(), namera, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val o = NotificationCompat.Builder(k, KANAL)
            .setSmallIcon(R.mipmap.ic_launcher_foreground)
            .setContentTitle(naslov)
            .setContentText(tekst)
            .setContentIntent(otvori)
            .setAutoCancel(true)
            .build()
        k.getSystemService(NotificationManager::class.java)?.notify(System.currentTimeMillis().toInt(), o)
    }

    /** Ekran na koji vodi dodir na obaveštenje (podaci iz funkcije `obavesti`: vrsta, kod, id). */
    fun ruta(vrsta: String?, id: String?): String? = when (vrsta) {
        "izazov" -> "sanduce"
        "pratilac" -> id?.filter { it.isLetterOrDigit() || it == '-' }?.takeIf { it.isNotEmpty() }?.let { "igrac/$it" }
        else -> null
    }
}
