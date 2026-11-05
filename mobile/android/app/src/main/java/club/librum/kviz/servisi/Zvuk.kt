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
        // Osvajanje i ostale igre (03.11.2026, isti fajlovi i imena kao iOS Zvuk.Vrsta).
        BOT_NAPADA("bot_napada"), BOT_OSVAJA("bot_osvaja"), UZBUNA("uzbuna"), TVOJ_POTEZ("tvoj_potez"), NOVI_KRUG("novi_krug"),
        POJACANJA("pojacanja"), VOJSKA_STAVI("vojska_stavi"), IZBOR_DRZAVE("izbor_drzave"), KARTA_DOBIJENA("karta_dobijena"),
        KARTA_ODIGRANA("karta_odigrana"), POMOC_VOJSKE("pomoc_vojske"), PRESTONICA_PALA("prestonica_pala"),
        IZGUBIO_DRZAVU("izgubio_drzavu"), POVLACENJE("povlacenje"), SAVEZ("savez"), IZDAJA("izdaja"), PORUKA("poruka"),
        DOGADJAJ("dogadjaj"), CUDO("cudo"), MISIJA("misija"), NIVO_GORE("nivo_gore"), NIZ("niz"), ZIVOT("zivot"),
        SLOVO_DA("slovo_da"), SLOVO_NE("slovo_ne"), PROTIVNIK_USAO("protivnik_usao"), OBAVESTENJE("obavestenje"),
        // Karijera (05.11.2026, isti fajlovi kao iOS): petlje muzike i kratki zvuci.
        KARIJERA_UVOD("karijera_uvod"), KARIJERA_KORPORACIJA("karijera_korporacija"), KARIJERA_FIRMA("karijera_firma"),
        KARIJERA_FIRMA_2("karijera_firma_2"), KARIJERA_FIRMA_3("karijera_firma_3"), KARIJERA_FIRMA_4("karijera_firma_4"),
        KARIJERA_POSAO("karijera_posao"), KARIJERA_OFFICE("karijera_office"), KARIJERA_PROBNI_KRAJ("karijera_probni_kraj"),
        KARIJERA_DUEL("karijera_duel"), KARIJERA_ODBRANA("karijera_odbrana"), KARIJERA_UNAPREDJENJE("karijera_unapredjenje"),
        KARIJERA_REKORD("karijera_rekord"), KARIJERA_USPEH("karijera_uspeh"), KARIJERA_KASA("karijera_kasa"), KARIJERA_ZVONO("karijera_zvono"),
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
