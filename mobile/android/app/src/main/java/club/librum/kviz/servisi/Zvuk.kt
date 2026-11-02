package club.librum.kviz.servisi

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer

/**
 * Tihi zvuci igre (mobile/zvuci, isti kao iOS). Kao zvuk igre (USAGE_GAME), poštuje
 * prekidač „Zvučni efekti” i nečujni režim telefona.
 */
object Zvuk {
    enum class Vrsta(val fajl: String) {
        TACNO("tacno"), NETACNO("netacno"), ISTEKLO("isteklo"), TIKANJE("tikanje"), ODBROJAVANJE("odbrojavanje"),
        BEDZ("bedz"), POBEDA("pobeda"), KRAJ("kraj"), OSVOJENO("osvojeno"), CEKANJE("cekanje"),
    }

    private lateinit var kontekst: Context
    private val plejeri = mutableMapOf<Vrsta, MediaPlayer>()

    fun init(k: Context) { kontekst = k.applicationContext }

    fun pusti(v: Vrsta, jacina: Float = 0.6f, ponavljaj: Boolean = false) {
        if (!::kontekst.isInitialized || !Napredak.deljeni.s.zvuk) return
        runCatching {
            val p = plejeri.getOrPut(v) {
                MediaPlayer().apply {
                    setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
                    kontekst.assets.openFd("${v.fajl}.m4a").use { setDataSource(it.fileDescriptor, it.startOffset, it.length) }
                    prepare()
                }
            }
            p.setVolume(jacina, jacina)
            p.isLooping = ponavljaj
            p.seekTo(0)
            p.start()
        }
    }

    fun stani(v: Vrsta) { plejeri[v]?.let { if (it.isPlaying) it.pause() } }
}
