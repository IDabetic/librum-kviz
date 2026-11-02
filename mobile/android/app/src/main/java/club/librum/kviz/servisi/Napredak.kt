package club.librum.kviz.servisi

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.neverEqualPolicy
import androidx.compose.runtime.setValue
import kotlinx.serialization.Serializable
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.UUID

/** Bedž iz kita: uslov se proverava nad stanjem napretka posle svake igre. */
data class Bedz(val id: String, val naziv: String, val opis: String, val boja: Long, val nagrada: Int)

/**
 * Lokalni napredak igrača (isto kao Napredak.swift): novčići, XP, niz dana, pomoći,
 * bedževi, statistika i sanduče. Čuva se na uređaju; radi i bez naloga i bez mreže.
 * shortcut: samo na uređaju; kad Supabase proradi, sinhronizacija ide u tabelu po nalogu.
 */
class Napredak(context: Context) {
    @Serializable data class Dan(var igara: Int = 0, var tacnih: Int = 0, var netacnih: Int = 0)

    @Serializable
    data class Poruka(
        val id: String = UUID.randomUUID().toString(),
        val vrsta: String,
        val naslov: String,
        val tekst: String,
        val vreme: Long,
        var procitano: Boolean = false,
        val novcici: Int = 0,
        var pokupljeno: Boolean = false,
    )

    @Serializable
    data class Stanje(
        var novcici: Int = 100,
        var xp: Int = 0,
        var nizDana: Int = 0,
        var najduziNiz: Int = 0,
        var poslednjiDanIgre: String? = null,
        var poslednjaNagrada: String? = null,
        var danaNagrade: Int = 0,
        var igara: Int = 0,
        var tacnih: Int = 0,
        var netacnih: Int = 0,
        var savrsenih: Int = 0,
        var brzihOdgovora: Int = 0,
        var pobedaDuel: Int = 0,
        val pomoci: MutableMap<String, Int> = mutableMapOf("polaPola" to 2, "nagovestaj" to 2, "vreme" to 2, "preskok" to 1),
        val bedzevi: MutableMap<String, Long> = mutableMapOf(),
        val dani: MutableMap<String, Dan> = mutableMapOf(),
        val kategorije: MutableMap<String, List<Int>> = mutableMapOf(),
        val najbolje: MutableMap<String, Int> = mutableMapOf(),
        val poruke: MutableList<Poruka> = mutableListOf(),
        var cilj: Int = 3,
        var podsetnik: Boolean = true,
        var maskota: String = "MIMI",
        var interesovanja: List<String> = emptyList(),
        var uvodZavrsen: Boolean = false,
        var zvuk: Boolean = true,
        var tema: String = "sistem",
    )

    private val prefs = context.getSharedPreferences("napredak", Context.MODE_PRIVATE)

    /** neverEqualPolicy: polja se menjaju na mestu, pa svaka dodela mora da osveži prikaz. */
    var s by mutableStateOf(
        prefs.getString("v1", null)?.let { runCatching { Supabase.json.decodeFromString<Stanje>(it) }.getOrNull() } ?: Stanje(),
        neverEqualPolicy(),
    )
        private set

    private fun sacuvaj() {
        prefs.edit().putString("v1", Supabase.json.encodeToString(Stanje.serializer(), s)).apply()
        s = s
    }

    fun podesi(izmena: Stanje.() -> Unit) { s.izmena(); sacuvaj() }

    // Nivo

    val nivo get() = nivo(s.xp).first
    val xpUNivou: Pair<Int, Int> get() = nivo(s.xp).let { (n, ostatak) -> ostatak to n * XP_PO_NIVOU }

    // Igra

    data class Ishod(val xp: Int, val novcici: Int, val noviBedzevi: List<Bedz>)

    fun zabeleziIgru(kviz: String, tacnih: Int, netacnih: Int, kategorija: String? = null, brzih: Int = 0, pobeda: Boolean = false, danas: Instant = Instant.now()): Ishod {
        val dan = dan(danas)
        if (s.poslednjiDanIgre != dan) {
            s.nizDana = if (s.poslednjiDanIgre == dan(danas.minusSeconds(86_400))) s.nizDana + 1 else 1
            s.najduziNiz = maxOf(s.najduziNiz, s.nizDana)
            s.poslednjiDanIgre = dan
        }
        val xp = tacnih + 5
        val novcici = tacnih * 2 + if (netacnih == 0 && tacnih >= 10) 50 else 0
        s.xp += xp
        s.novcici += novcici
        s.igara += 1
        s.tacnih += tacnih
        s.netacnih += netacnih
        s.brzihOdgovora += brzih
        if (pobeda) s.pobedaDuel += 1
        if (netacnih == 0 && tacnih >= 10) s.savrsenih += 1
        val d = s.dani.getOrPut(dan) { Dan() }
        d.igara += 1; d.tacnih += tacnih; d.netacnih += netacnih
        if (kategorija != null) {
            val k = s.kategorije[kategorija] ?: listOf(0, 0)
            s.kategorije[kategorija] = listOf(k[0] + tacnih, k[1] + tacnih + netacnih)
        }
        s.najbolje[kviz] = maxOf(s.najbolje[kviz] ?: 0, tacnih)
        val novi = proveriBedzeve(danas)
        sacuvaj()
        return Ishod(xp, novcici, novi)
    }

    // Dnevna nagrada

    val dnevnaNagradaSpremna get() = s.poslednjaNagrada != dan(Instant.now())
    val sledecaNagrada get() = NAGRADE_NIZA[minOf(s.danaNagrade, NAGRADE_NIZA.size - 1)]

    fun pokupiDnevnuNagradu(danas: Instant = Instant.now()): Int {
        if (s.poslednjaNagrada == dan(danas)) return 0
        s.danaNagrade = if (s.poslednjaNagrada == dan(danas.minusSeconds(86_400))) s.danaNagrade + 1 else 0
        val iznos = NAGRADE_NIZA[minOf(s.danaNagrade, NAGRADE_NIZA.size - 1)]
        s.novcici += iznos
        s.poslednjaNagrada = dan(danas)
        s.poruke.firstOrNull { it.vrsta == "nagrada" && !it.pokupljeno }?.let { it.pokupljeno = true; it.procitano = true }
        sacuvaj()
        return iznos
    }

    // Prodavnica

    enum class Pomoc(val kljuc: String, val naziv: String, val cena: Int, val opis: String) {
        POLA_POLA("polaPola", "50/50 ×5", 100, "Uklanja dva netačna odgovora."),
        NAGOVESTAJ("nagovestaj", "Nagoveštaj ×5", 150, "Maskota sklanja jedan netačan odgovor i daje trag."),
        VREME("vreme", "+10 s ×5", 120, "Deset sekundi više na jednom pitanju."),
        PRESKOK("preskok", "Preskok ×5", 200, "Preskače pitanje bez gubitka niza."),
    }

    enum class Kupovina { USPEH, NEMA_NOVCICA }

    fun kupi(p: Pomoc): Kupovina {
        if (s.novcici < p.cena) return Kupovina.NEMA_NOVCICA
        s.novcici -= p.cena
        s.pomoci[p.kljuc] = (s.pomoci[p.kljuc] ?: 0) + 5
        sacuvaj()
        return Kupovina.USPEH
    }

    fun imaPomoc(p: Pomoc) = s.pomoci[p.kljuc] ?: 0

    fun potrosi(p: Pomoc): Boolean {
        if (imaPomoc(p) <= 0) return false
        s.pomoci[p.kljuc] = imaPomoc(p) - 1
        sacuvaj()
        return true
    }

    fun dodajNovcice(n: Int) { s.novcici += n; sacuvaj() }
    fun oduzmiNovcice(n: Int): Boolean { if (s.novcici < n) return false; s.novcici -= n; sacuvaj(); return true }

    // Sanduče

    val neprocitanih get() = s.poruke.count { !it.procitano }
    fun procitajSve() { s.poruke.forEach { it.procitano = true }; sacuvaj() }
    fun obrisiPoruku(id: String) { s.poruke.removeAll { it.id == id }; sacuvaj() }

    /** Jednom dnevno, ako nagrada čeka, ubacuje podsetnik u sanduče. */
    fun osveziSanduce() {
        if (!dnevnaNagradaSpremna || s.poruke.any { it.vrsta == "nagrada" && !it.pokupljeno }) return
        s.poruke.add(0, Poruka(vrsta = "nagrada", naslov = "Dnevna nagrada je spremna",
            tekst = "Dan ${s.danaNagrade + 1} niza: $sledecaNagrada novčića čeka.", vreme = System.currentTimeMillis(), novcici = sledecaNagrada))
        sacuvaj()
    }

    // Statistika

    fun tacnostPoDanima(dana: Int, danas: Instant = Instant.now()): List<Pair<LocalDate, Double?>> = (dana - 1 downTo 0).map { i ->
        val d = danas.minusSeconds(i * 86_400L)
        val st = s.dani[dan(d)]
        val ukupno = (st?.tacnih ?: 0) + (st?.netacnih ?: 0)
        d.atZone(ZONA).toLocalDate() to if (ukupno > 0) st!!.tacnih.toDouble() / ukupno else null
    }

    /** Tačnost i broj igara od datuma (null = sve vreme), ili null ako nije igrano. */
    fun tacnost(od: Instant?): Pair<Double, Int>? {
        val granica = od?.let { dan(it) } ?: ""
        val izabrani = s.dani.filterKeys { it >= granica }.values
        val t = izabrani.sumOf { it.tacnih }
        val n = izabrani.sumOf { it.netacnih }
        return if (t + n == 0) null else t.toDouble() / (t + n) to izabrani.sumOf { it.igara }
    }

    // Bedževi

    private fun ispunjen(id: String): Boolean = when (id) {
        "prvi" -> s.igara >= 1
        "niz3" -> s.najduziNiz >= 3
        "niz7" -> s.najduziNiz >= 7
        "niz30" -> s.najduziNiz >= 30
        "tacnih100" -> s.tacnih >= 100
        "tacnih1000" -> s.tacnih >= 1000
        "savrseno" -> s.savrsenih >= 1
        "brzina" -> s.brzihOdgovora >= 10
        "igara25" -> s.igara >= 25
        "igara100" -> s.igara >= 100
        "duel1" -> s.pobedaDuel >= 1
        "duel10" -> s.pobedaDuel >= 10
        "svet" -> s.najbolje.containsKey("osvajanje")
        "knjige" -> s.kategorije.filterKeys { it.startsWith("Knjige") }.values.sumOf { it[0] } >= 50
        "nivo5" -> nivo >= 5
        "nivo10" -> nivo >= 10
        else -> false
    }

    private fun proveriBedzeve(danas: Instant): List<Bedz> {
        val novi = SVI_BEDZEVI.filter { s.bedzevi[it.id] == null && ispunjen(it.id) }
        for (b in novi) {
            s.bedzevi[b.id] = danas.toEpochMilli()
            s.novcici += b.nagrada
            s.poruke.add(0, Poruka(vrsta = "bedz", naslov = "Novi bedž: ${b.naziv}", tekst = "${b.opis} +${b.nagrada} novčića.", vreme = danas.toEpochMilli()))
        }
        return novi
    }

    /** Za testove i brisanje naloga: vraća sve na početak. */
    fun resetuj() { s = Stanje(); sacuvaj() }

    companion object {
        const val XP_PO_NIVOU = 250
        val NAGRADE_NIZA = listOf(10, 20, 30, 40, 50, 60, 100)
        private val ZONA: ZoneId = ZoneId.of("Europe/Belgrade")

        /** Nivo n traži 250 × n XP da se pređe u n+1 (1→2 = 250, 12→13 = 3.000). */
        fun nivo(xp: Int): Pair<Int, Int> {
            var n = 1
            var ostatak = xp
            while (ostatak >= n * XP_PO_NIVOU) { ostatak -= n * XP_PO_NIVOU; n++ }
            return n to ostatak
        }

        fun dan(t: Instant): String = t.atZone(ZONA).toLocalDate().toString()

        val SVI_BEDZEVI = listOf(
            Bedz("prvi", "Prvi korak", "Odigraj prvi kviz.", 0xFF12907E, 50),
            Bedz("niz3", "Na vatri", "Igraj 3 dana zaredom.", 0xFFFF5FA2, 100),
            Bedz("niz7", "Nedelja znanja", "Igraj 7 dana zaredom.", 0xFFF4A33C, 200),
            Bedz("niz30", "Mesec bez pauze", "Igraj 30 dana zaredom.", 0xFFFFD84D, 500),
            Bedz("tacnih100", "Veliki mozak", "100 tačnih odgovora.", 0xFF6D4BC9, 100),
            Bedz("tacnih1000", "Enciklopedija", "1.000 tačnih odgovora.", 0xFF6D4BC9, 300),
            Bedz("savrseno", "Savršenih 10", "10 od 10 u jednom kvizu.", 0xFFFFD84D, 150),
            Bedz("brzina", "Munja", "10 tačnih odgovora za manje od 2 sekunde.", 0xFF12907E, 100),
            Bedz("igara25", "Stalni gost", "Odigraj 25 kvizova.", 0xFF6EC3F2, 100),
            Bedz("igara100", "Kvizomanija", "Odigraj 100 kvizova.", 0xFFF4A33C, 300),
            Bedz("duel1", "Prva pobeda", "Pobedi u duelu.", 0xFFFF5FA2, 100),
            Bedz("duel10", "Šampion", "Pobedi u 10 duela.", 0xFFFFD84D, 300),
            Bedz("svet", "Svetski putnik", "Odigraj Osvajanje sveta.", 0xFF6EC3F2, 100),
            Bedz("knjige", "Knjiški moljac", "50 tačnih u Book kvizu.", 0xFFF4A33C, 150),
            Bedz("nivo5", "Nivo 5", "Dostigni nivo 5.", 0xFF12907E, 200),
            Bedz("nivo10", "Nivo 10", "Dostigni nivo 10.", 0xFF6D4BC9, 500),
        )
    }
}
