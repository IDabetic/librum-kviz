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
data class Bedz(val id: String, val naziv: String, val opis: String, val boja: Long)

/**
 * Lokalni napredak igrača (isto kao Napredak.swift): XP, niz dana, dnevni fond pomoći,
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
        /** Za izazov: kod sobe duela. */
        val kodSobe: String? = null,
    )

    @Serializable
    data class Stanje(
        var xp: Int = 0,
        var nizDana: Int = 0,
        var najduziNiz: Int = 0,
        var poslednjiDanIgre: String? = null,
        var igara: Int = 0,
        var tacnih: Int = 0,
        var netacnih: Int = 0,
        var savrsenih: Int = 0,
        var brzihOdgovora: Int = 0,
        var pobedaDuel: Int = 0,
        var zbirMs: Int = 0,
        var brojMs: Int = 0,
        /** Dnevni fond pomoći: ciklus počinje prvom pomoći, posle 24 h fond je opet pun. */
        var pocetakCiklusaPomoci: Long? = null,
        var pomociIskorisceno: Int = 0,
        val pomociPoVrsti: MutableMap<String, Int> = mutableMapOf(),
        var partijaSaPomoci: Int = 0,
        var avatar: String? = null,
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
        /** Prihvaćena pravila zajednice (pre prve objave, komentara ili poruke). */
        var pravilaZajednice: Boolean = false,
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

    data class Ishod(val xp: Int, val noviBedzevi: List<Bedz>)

    /** Pomoć iskorišćena u partiji koja traje; zavrsiPartiju je upisuje uz rezultat. */
    var pomocUPartiji: String? = null

    fun zabeleziIgru(kviz: String, tacnih: Int, netacnih: Int, kategorija: String? = null, brzih: Int = 0, pobeda: Boolean = false, prosekMs: Int? = null, danas: Instant = Instant.now()): Ishod {
        val dan = dan(danas)
        if (s.poslednjiDanIgre != dan) {
            s.nizDana = if (s.poslednjiDanIgre == dan(danas.minusSeconds(86_400))) s.nizDana + 1 else 1
            s.najduziNiz = maxOf(s.najduziNiz, s.nizDana)
            s.poslednjiDanIgre = dan
        }
        val xp = tacnih + 5
        s.xp += xp
        s.igara += 1
        s.tacnih += tacnih
        s.netacnih += netacnih
        s.brzihOdgovora += brzih
        if (prosekMs != null && tacnih + netacnih > 0) { s.zbirMs += prosekMs * (tacnih + netacnih); s.brojMs += tacnih + netacnih }
        if (pomocUPartiji != null) s.partijaSaPomoci += 1
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
        return Ishod(xp, novi)
    }

    /** Prosečna brzina odgovora u sekundama (null dok nema merenja). */
    val prosecnaBrzina: Double? get() = if (s.brojMs > 0) s.zbirMs.toDouble() / s.brojMs / 1000 else null

    // Pomoć: 7 dnevno za svih 7 igara, jedna po partiji (to čuva igra), novi fond 24 h posle prve.

    private fun ciklusIstekao(sada: Long) = s.pocetakCiklusaPomoci?.let { sada - it >= CIKLUS_POMOCI_MS } ?: true

    fun pomociOstalo(sada: Long = System.currentTimeMillis()): Int = if (ciklusIstekao(sada)) POMOCI_DNEVNO else maxOf(0, POMOCI_DNEVNO - s.pomociIskorisceno)

    fun sledeciFondPomoci(sada: Long = System.currentTimeMillis()): Long? =
        if (ciklusIstekao(sada)) null else s.pocetakCiklusaPomoci?.plus(CIKLUS_POMOCI_MS)

    fun iskoristiPomoc(vrsta: String = "pomoc", sada: Long = System.currentTimeMillis()): Boolean {
        if (ciklusIstekao(sada)) { s.pocetakCiklusaPomoci = sada; s.pomociIskorisceno = 0 }
        if (s.pomociIskorisceno >= POMOCI_DNEVNO) return false
        s.pomociIskorisceno += 1
        s.pomociPoVrsti[vrsta] = (s.pomociPoVrsti[vrsta] ?: 0) + 1
        pomocUPartiji = vrsta
        sacuvaj()
        return true
    }

    // Sanduče

    val neprocitanih get() = s.poruke.count { !it.procitano }
    fun procitajSve() { s.poruke.forEach { it.procitano = true }; sacuvaj() }
    fun obrisiPoruku(id: String) { s.poruke.removeAll { it.id == id }; sacuvaj() }

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
            s.poruke.add(0, Poruka(vrsta = "bedz", naslov = "Novi bedž: ${b.naziv}", tekst = b.opis, vreme = danas.toEpochMilli()))
        }
        return novi
    }

    /** Za testove i brisanje naloga: vraća sve na početak. */
    fun resetuj() { s = Stanje(); sacuvaj() }

    companion object {
        /** Jedan napredak za celu aplikaciju (pravi ga MainActivity). */
        lateinit var deljeni: Napredak
        const val XP_PO_NIVOU = 250
        const val POMOCI_DNEVNO = 7
        const val CIKLUS_POMOCI_MS = 24 * 3600 * 1000L
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
            Bedz("prvi", "Prvi korak", "Odigraj prvi kviz.", 0xFF12907E),
            Bedz("niz3", "Na vatri", "Igraj 3 dana zaredom.", 0xFFFF5FA2),
            Bedz("niz7", "Nedelja znanja", "Igraj 7 dana zaredom.", 0xFFF4A33C),
            Bedz("niz30", "Mesec bez pauze", "Igraj 30 dana zaredom.", 0xFFFFD84D),
            Bedz("tacnih100", "Veliki mozak", "100 tačnih odgovora.", 0xFF6D4BC9),
            Bedz("tacnih1000", "Enciklopedija", "1.000 tačnih odgovora.", 0xFF6D4BC9),
            Bedz("savrseno", "Savršenih 10", "10 od 10 u jednom kvizu.", 0xFFFFD84D),
            Bedz("brzina", "Munja", "10 tačnih odgovora za manje od 2 sekunde.", 0xFF12907E),
            Bedz("igara25", "Stalni gost", "Odigraj 25 kvizova.", 0xFF6EC3F2),
            Bedz("igara100", "Kvizomanija", "Odigraj 100 kvizova.", 0xFFF4A33C),
            Bedz("duel1", "Prva pobeda", "Pobedi u duelu.", 0xFFFF5FA2),
            Bedz("duel10", "Šampion", "Pobedi u 10 duela.", 0xFFFFD84D),
            Bedz("svet", "Svetski putnik", "Odigraj Osvajača.", 0xFF6EC3F2),
            Bedz("knjige", "Knjiški moljac", "50 tačnih u Book kvizu.", 0xFFF4A33C),
            Bedz("nivo5", "Nivo 5", "Dostigni nivo 5.", 0xFF12907E),
            Bedz("nivo10", "Nivo 10", "Dostigni nivo 10.", 0xFF6D4BC9),
        )
    }
}
