package club.librum.kviz.osvajanje

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

import kotlin.math.max
import kotlin.math.min

// Verni prevod iOS Pravila.swift (03.11.2026, sa Strategija.kt i Strategija2.kt). Kad se pravila
// menjaju, menjaju se na svim mestima, zajedno sa testovima; JSON stanja je isti kao na iOS-u.

@Serializable data class Region(val id: String, val ime: String, val bonus: Int)

/** Država sa tačkom za natpis i SVG putanjom (M/L/Z) u koordinatama mape. */
@Serializable data class Oblast(
    val id: String, val ime: String, val region: String, val x: Float, val y: Float,
    val boja: Int, val povrsina: Float, val d: String,
)

@Serializable private data class Svet(val sirina: Float, val visina: Float, val regioni: List<Region>, val drzave: List<Oblast>, val veze: List<List<String>>, val more: List<List<kotlinx.serialization.json.JsonPrimitive>>)

/** Morski put sa tačkama obala, za isprekidanu liniju. */
data class MorskiPut(val a: String, val b: String, val x1: Float, val y1: Float, val x2: Float, val y2: Float)

/** Mapa država iz svet.json (isti fajl kao veb i iOS); učitava se jednom pri pokretanju. */
object Mapa {
    private lateinit var svet: Svet
    private lateinit var susedstvo: Map<String, List<String>>
    private lateinit var poId: Map<String, Oblast>

    fun ucitaj(json: String) {
        if (::svet.isInitialized) return
        svet = Json { ignoreUnknownKeys = true }.decodeFromString(Svet.serializer(), json)
        susedstvo = buildMap<String, MutableList<String>> {
            for ((a, b) in svet.veze) {
                getOrPut(a) { mutableListOf() }.add(b)
                getOrPut(b) { mutableListOf() }.add(a)
            }
        }
        poId = svet.drzave.associateBy { it.id }
    }

    val sirina get() = svet.sirina
    val visina get() = svet.visina
    val regioni get() = svet.regioni
    val oblasti get() = svet.drzave
    val veze get() = svet.veze.map { it[0] to it[1] }
    val more: List<MorskiPut> by lazy {
        svet.more.map { MorskiPut(it[0].content, it[1].content, it[2].content.toFloat(), it[3].content.toFloat(), it[4].content.toFloat(), it[5].content.toFloat()) }
    }

    fun susedi(id: String): List<String> = susedstvo[id].orEmpty()
    /** Nepoznat ID (zastarela sačuvana partija) ne sme da obori igru: crta se prva država. */
    fun oblast(id: String): Oblast = poId[id] ?: oblasti.first()
}

object Pravila {
    const val POCETNE_VOJSKE_PRESTONICE = 5
    const val POCETNIH_DRZAVA = 6
    const val POCETNE_VOJSKE_DRZAVE = 2
    /** Vreme za odluku na potezu; svaki dodir ga produžava. */
    const val ROK_POTEZA_SEKUNDI = 30
    /** Tri poteza zaredom bez napada (isteklo vreme) = igrač nije u igri i ispada. */
    const val PROPUSTENIH_DO_ISPADANJA = 3
    const val NEUTRALNE_VOJSKE = 1
    /** Vojske koje igrač sam raspoređuje na početne države pre prvog kruga (isto koliko dobija i automatski). */
    const val VOJSKI_NA_POCETKU = POCETNE_VOJSKE_PRESTONICE + (POCETNIH_DRZAVA - 1) * POCETNE_VOJSKE_DRZAVE
    const val NAJMANJE_POJACANJA = 3
    const val TERITORIJA_PO_VOJSCI = 2
    /** Napada zaredom po potezu kad svako igra za sebe; u timu po igraču (tim = 2 × 2). */
    const val BITAKA_PO_POTEZU = 5
    const val BITAKA_U_TIMU_PO_IGRACU = 2
    /** Bitka za državu koju drži igrač: niz pitanja, odlučuju tačni pa brzina. */
    const val PITANJA_U_BITCI = 5
    const val BONUS_POMOCI_POBEDNIKU = 2
    const val GUBITAK_PORAZENOG_NAPADACA = 2
    const val PROBOJ_SVAKIH = 3
    const val PROBOJ_BONUS = 2
    const val PLEN_PRESTONICE = 5
    const val POENI_PO_OBLASTI = 10
    const val POENI_PO_BONUSU = 10
    const val POENI_PRESTONICA = 20
    /** Vreme za odgovor u bitki (vlasnik 03.11: 20 s podrazumevano). */
    const val SEKUNDI_PO_PITANJU = 20
    const val SEKUNDI_BRZ_SAT = 8
    // Strategija (Strategija.kt, docs/OSVAJANJE-STRATEGIJA.md).
    /** Višak vojske u bitki sa igračem vredi najviše ovoliko tačnih odgovora. */
    const val NAJVECA_PREDNOST_VOJSKE = 2
    /** Napad na neutralnu državu sa bar ovoliko vojske: greška ne košta vojsku. */
    const val VOJSKI_BEZ_GUBITKA_NA_NEUTRALNOJ = 3
    const val NAJVISE_KARATA = 5
    const val VOJSKI_POJACANJA = 2
    const val DOGADJAJ_SVAKIH = 4
    const val TRAJANJE_DOGADJAJA = 2
    const val SEKUNDI_MUDRACI = 5
    const val SEKUNDI_KARNEVAL = 10
    const val NAPADA_VISE_KONJICA = 2
    // Drugi talas (Strategija2.kt).
    const val NAJVECI_ULOG = 2
    const val KORAKA_MARSA = 3
    const val NAGRADA_POHODA = 3
    const val VOJSKI_PIRAMIDE = 2
    const val SEKUNDI_OPERA = 5
    /** Bitka od 5 pitanja: povlačenje je moguće posle ovoliko odgovora. */
    const val POVLACENJE_POSLE = 2
}

enum class Tezina(val tacnost: Double, val ime: String, val opis: String) {
    LAKO(0.5, "Lako", "Rivali greše svako drugo pitanje"),
    NORMALNO(0.55, "Normalno", "Rivali znaju nešto više od pola"),
    TESKO(0.75, "Teško", "Rivali znaju 3 od 4"),
}

/** Boja u JSON-u partije kao na iOS-u (0xRRGGBB, bez alfe); u aplikaciji 0xFFRRGGBB. */
object BojaSerializer : kotlinx.serialization.KSerializer<Long> {
    override val descriptor = kotlinx.serialization.descriptors.PrimitiveSerialDescriptor("Boja", kotlinx.serialization.descriptors.PrimitiveKind.LONG)
    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: Long) = encoder.encodeLong(value and 0xFFFFFF)
    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): Long = 0xFF000000 or (decoder.decodeLong() and 0xFFFFFF)
}

@Serializable
data class Igrac(
    val id: String,
    val ime: String,
    @Serializable(with = BojaSerializer::class) val boja: Long,
    /** Igrač na ovom uređaju (u partiji preko servera svaki telefon postavlja svoje). */
    val covek: Boolean,
    val prestonica: String,
    val ispao: Boolean,
    /** Tim (vlasnik država). Svako za sebe: tim = id igrača. */
    val tim: String = id,
    /** Kapiten bira odbranu kontinenta (u timu član sa više tačnih na profilu). */
    val kapiten: Boolean = true,
    /** Vrsta vojske izabrana pre partije (Strategija.kt); null u starim stanjima. */
    val vojska: VrstaVojske? = null,
)

/** Igrač za novu partiju (čekaonica): bez prestonice, ona se bira na početku. */
data class NoviIgrac(val id: String, val ime: String, val boja: Long, val covek: Boolean, val tim: String? = null, val kapiten: Boolean = true, val vojska: VrstaVojske? = null)

@Serializable data class StanjeOblasti(val vlasnik: String? = null, val vojske: Int)

@Serializable enum class Faza {
    @SerialName("snabdevanje") SNABDEVANJE, @SerialName("raspored") RASPORED,
    @SerialName("napad") NAPAD, @SerialName("kraj") KRAJ,
}

data class Odgovor(val tacan: Boolean, val ms: Int)

/** Rezultat jedne strane u bitki od 5 pitanja. */
@Serializable data class Skor(val tacnih: Int, val ms: Int)

data class Ishod(
    val gubitakNapadaca: Int,
    val gubitakBranioca: Int,
    val osvojeno: Boolean,
    val proboj: Boolean,
    val plen: Boolean,
    /** Napadač je izgubio bitku protiv igrača, pa branilac uzima državu iz koje je napadnut. */
    val izgubljenaDrzava: Boolean = false,
)

/** Deterministički generator (mulberry32), isti kao na vebu i iOS-u (32-bitni, Int nosi iste bitove kao UInt32). */
class Slucajno(seme: Int) {
    private var a: Int = seme
    fun sledeci(): Double {
        a += 0x6D2B79F5
        var t = a
        t = (t xor (t ushr 15)) * (t or 1)
        t = t xor (t + ((t xor (t ushr 7)) * (t or 61)))
        return ((t xor (t ushr 14)).toLong() and 0xFFFFFFFFL).toDouble() / 4294967296.0
    }
    fun kopija(): Slucajno = Slucajno(0).also { it.a = a }
}

/** Seme kao Swift UInt32 (JSON broj 0…4294967295) ↔ Int sa istim bitovima. */
internal fun Long.bitovi(): Int = toInt()
internal fun Int.neoznacen(): Long = toLong() and 0xFFFFFFFFL

/** Zbir kodova znakova (Swift `unicodeScalars.reduce(0) { $0 + Int($1.value) }`; id-jevi su ASCII). */
internal fun String.zbirZnakova(): Int = sumOf { it.code }

// ── Kontinenti, odbrane, misije (v3, docs/OSVAJANJE-VISE-IGRACA.md) ──

data class Kontinent(val id: String, val ime: String, val regioni: List<String>)

object Kontinenti {
    val svi = listOf(
        Kontinent("sam", "Severna Amerika", listOf("sam", "kar")),
        Kontinent("jam", "Južna Amerika", listOf("jam")),
        Kontinent("evr", "Evropa", listOf("sev", "zev", "jev", "iev")),
        Kontinent("afr", "Afrika", listOf("saf", "zaf", "caf", "iaf", "jaf")),
        Kontinent("azi", "Azija", listOf("bli", "caz", "iaz", "jia")),
        Kontinent("oke", "Okeanija", listOf("oke")),
    )
    fun od(oblastId: String): Kontinent { val r = Mapa.oblast(oblastId).region; return svi.first { r in it.regioni } }
    fun oblasti(id: String): List<String> {
        val k = svi.firstOrNull { it.id == id } ?: return emptyList()
        return Mapa.oblasti.filter { it.region in k.regioni }.map { it.id }
    }
}

/** Nazivi u JSON-u partije isti kao iOS rawValue (brzSat…), da telefoni dele stanje. */
@Serializable
enum class Odbrana(val naziv: String, val opis: String, val cena: Int) {
    @SerialName("brzSat") BRZ_SAT("Brz sat", "Napadač ima 8 sekundi umesto 15.", 0),
    @SerialName("bezPomoci") BEZ_POMOCI("Bez pomoći", "Napadač ne sme da koristi pomoć na ovom kontinentu.", 0),
    @SerialName("teskoPitanje") TESKO_PITANJE("Teško pitanje", "Napadač dobija samo teška pitanja.", 1),
    @SerialName("prednost") PREDNOST("Prednost", "Napadaču trebaju bar 2 tačna više od branioca da osvoji.", 2),
    @SerialName("temaBranioca") TEMA_BRANIOCA("Tema branioca", "Pitanja za napadača su iz teme koju je branilac izabrao.", 0),
    @SerialName("tvrdjava") TVRDJAVA("Tvrđava", "Prvi poraz branioca u krugu se ne računa.", 2),
    @SerialName("zamka") ZAMKA("Zamka", "Kad napadač pogreši, gubi 2 vojske umesto 1.", 1),
}

data class Misija(val id: String, val tekst: String, val samoPojedinacno: Boolean = false, val najmanjeRivala: Int = 1)

object Misije {
    val sve = listOf(
        Misija("evr-jam", "Osvoji Evropu i Južnu Ameriku."),
        Misija("evr-oke-jos", "Osvoji Evropu i Okeaniju, plus još jedan kontinent po izboru."),
        Misija("sam-jam", "Osvoji Severnu i Južnu Ameriku."),
        Misija("azi-jam", "Osvoji Aziju i Južnu Ameriku."),
        Misija("afr-oke", "Osvoji Afriku i Okeaniju."),
        Misija("sam-oke", "Osvoji Severnu Ameriku i Okeaniju."),
        Misija("drzava60", "Drži 60 država."),
        Misija("drzava45x2", "Drži 45 država sa najmanje 2 vojske u svakoj."),
        Misija("regiona8", "Drži 8 celih regiona (region je grupa država, npr. ceo Balkan)."),
        Misija("prestonice2", "Zauzmi prestonice dva rivala."),
        Misija("izbaci", "Izbaci određenog rivala iz igre.", samoPojedinacno = true),
        Misija("tacnih25", "Odgovori tačno na 25 pitanja i drži bar 30 država."),
        // Proširenje 03.11.2026 (vlasnik: „dosta tajnih zadataka da ne bude uvek isto”).
        Misija("evr-afr", "Osvoji Evropu i Afriku."),
        Misija("sam-evr", "Osvoji Severnu Ameriku i Evropu."),
        Misija("azi-oke", "Osvoji Aziju i Okeaniju."),
        Misija("afr-jam", "Osvoji Afriku i Južnu Ameriku."),
        Misija("kontinenta2", "Drži bilo koja dva cela kontinenta."),
        Misija("drzava50", "Drži 50 država."),
        Misija("regiona10", "Drži 10 celih regiona."),
        Misija("regiona6-kontinent", "Drži 6 celih regiona i bar jedan ceo kontinent."),
        Misija("prestonice3", "Zauzmi prestonice tri rivala.", najmanjeRivala = 3),
        Misija("vojske150", "Imaj 150 vojski na mapi."),
        Misija("tacnih40", "Odgovori tačno na 40 pitanja."),
        Misija("pobeda10", "Dobij 10 bitaka protiv igrača (napad ili odbrana)."),
        Misija("ostrva", "Drži celu Okeaniju i Karibe."),
        Misija("put-svile", "Drži Bliski istok, Centralnu i Južnu Aziju i Istočnu Aziju."),
        Misija("mediteran", "Drži Južnu Evropu, Severnu Afriku i Bliski istok."),
        Misija("svuda4", "Drži bar 4 države na svakom kontinentu."),
        Misija("prestonica35", "Sačuvaj svoju prestonicu i drži 35 država."),
        Misija("amerike-pola", "Drži celu Južnu Ameriku i pola Severne Amerike."),
        Misija("cuda3", "Drži tri čuda sveta (Piramide, Kineski zid, Akropolj, Maču Pikču, Kip slobode, Sidnejska opera)."),
        Misija("pohodi3", "Ispuni tri najavljena pohoda i drži bar 25 država."),
    )
    fun tekst(id: String?) = sve.firstOrNull { it.id == id }?.tekst.orEmpty()
    /** Misije čiji brojevi (države, regioni, vojske) zavise od broja strana; tačni odgovori i prestonice ne. */
    val skalirane = setOf("drzava60", "drzava45x2", "regiona8", "drzava50", "regiona10", "regiona6-kontinent", "vojske150", "prestonica35")
}

data class Uslov(val sekundi: Int, val bezPomoci: Boolean, val tesko: Boolean, val pitanja: Int, val temaBranioca: Boolean, val prednost: Int)

enum class Narav { NAPADAC, GRADITELJ, OPREZAN }

/**
 * Stanje partije: isti JSON kao iOS `Stanje` (Codable), da telefoni dele partiju preko servera.
 * Opciona polja (null) su novija pravila; stara stanja ih nemaju.
 */
@Serializable
data class Stanje(
    val igraci: List<Igrac>,
    val oblasti: Map<String, StanjeOblasti>,
    val krug: Int,
    val ukupnoKrugova: Int,
    val naPotezu: Int,
    val faza: Faza,
    val zaRaspored: Int,
    val bitaka: Int,
    val niz: Int,
    val utvrdjeno: Boolean,
    val tacnostBota: Double,
    val misije: Map<String, String> = emptyMap(),
    val metaMisije: Map<String, String> = emptyMap(),
    val odbrane: Map<String, Odbrana> = emptyMap(),
    val promenaOdbrane: Map<String, Int> = emptyMap(),
    val tvrdjava: Map<String, Int> = emptyMap(),
    val tacnih: Map<String, Int> = emptyMap(),
    val pobednik: String? = null,
    val bonusPomoci: Map<String, Int> = emptyMap(),
    /** Potezi zaredom bez napada (isteklo vreme); na treći igrač ispada. */
    val propusteno: Map<String, Int>? = null,
    // Strategija (opciono, da stara stanja sa servera i dalje čitaju).
    val karteTimova: Map<String, List<Karta>>? = null,
    val zamrznuto: Map<String, Int>? = null,
    val savezi: Map<String, Int>? = null,
    val predloziSaveza: List<String>? = null,
    val poruke: List<BrzaPoruka>? = null,
    val dogadjaj: Dogadjaj? = null,
    val pobedaBitaka: Map<String, Int>? = null,
    val ulog: Int? = null,
    /** Pomoći vojske: „tim|pomoć” → krug u kom je iskorišćena. */
    val pomociVojske: Map<String, Int>? = null,
    val pohodi: Map<String, String>? = null,
    val uspeliPohodi: Map<String, Int>? = null,
    val izdajnici: List<String>? = null,
    val ultimatumKrug: Map<String, Int>? = null,
    val odbijeniUltimatumi: Map<String, Int>? = null,
    /** Seme partije (Swift UInt32 kao Long): narav, vojska i šum botova; null = staro stanje. */
    val seme: Long? = null,
) {
    val trenutni: Igrac get() = igraci[naPotezu]

    /** Seme kao 32-bitni Int (0 kad ga nema), za mešanje sa drugim brojevima kao na iOS-u. */
    internal val semeBitovi: Int get() = seme?.bitovi() ?: 0

    companion object {
        /** Ceo broj iz id-a pomešan sa semenom partije (za narav, vojsku i šum bota). */
        fun mesaj(id: String, seme: Int, dodatak: Int = 0): Double {
            var h = 2166136261L.toInt()
            for (c in id) h = (h xor c.code) * 16777619
            val r = Slucajno(h xor seme xor (dodatak.toLong() * 2654435761L).toInt())
            return r.sledeci()
        }

        /** Fisher–Yates mešanje istim generatorom (ponovljivo iz semena). */
        fun <T> promesaj(niz: List<T>, r: Slucajno): List<T> {
            val n = niz.toMutableList()
            for (i in n.size - 1 downTo 1) { val j = (r.sledeci() * (i + 1)).toInt(); val t = n[i]; n[i] = n[j]; n[j] = t }
            return n
        }

        val podrazumevani = listOf(
            NoviIgrac("ti", "Ti", 0xFF12907E, covek = true),
            NoviIgrac("mimi", "Mimi", 0xFFFF5FA2, covek = false),
            NoviIgrac("zig", "Zig", 0xFF6D4BC9, covek = false),
        )

        /**
         * Nova partija: prestonica na izabranom kontinentu (ili u regionu koji niko nema), po šest država oko nje,
         * ostalo neutralno; po želji tajne misije. `teren` = id kontinenta: igra se samo na njemu.
         */
        fun nova(
            krugova: Int, tezina: Tezina, slucajno: Slucajno, ime: String? = null, igraci: List<NoviIgrac>? = null,
            pocetak: Map<String, String> = emptyMap(), misije: Boolean = false, teren: String? = null,
            vojska: VrstaVojske? = null, izbegniMisije: Set<String> = emptySet(),
        ): Stanje {
            // Seme iz kopije generatora: glavni niz (prestonice, misije) ostaje isti kao na vebu za isto seme.
            val kopija = slucajno.kopija()
            val seme = ((kopija.sledeci() * 4_294_967_295.0).toLong().toInt()) xor 0x9E3779B9L.toInt()
            val mesanje = Slucajno(seme)
            val regioni = Mapa.regioni.toMutableList()
            for (i in regioni.size - 1 downTo 1) { val j = (slucajno.sledeci() * (i + 1)).toInt(); val t = regioni[i]; regioni[i] = regioni[j]; regioni[j] = t }
            val oblasti = mutableMapOf<String, StanjeOblasti>()
            val naTerenu = teren?.let { Kontinenti.oblasti(it).toSet() }
            for (o in Mapa.oblasti) if (naTerenu?.contains(o.id) != false) oblasti[o.id] = StanjeOblasti(null, Pravila.NEUTRALNE_VOJSKE)
            val lista = mutableListOf<Igrac>()
            for (p in igraci ?: podrazumevani) {
                val tim = p.tim ?: p.id
                // Čuda sveta se osvajaju, ne dobijaju na početku.
                fun slobodna(o: Oblast) = Mapa.susedi(o.id).count { oblasti[it] != null } >= 3 && oblasti[o.id] != null &&
                    oblasti[o.id]?.vlasnik == null && Cudo.za(o.id) == null
                val k = teren ?: pocetak[tim]
                var kandidati: List<Oblast> = if (k != null) {
                    Mapa.oblasti.filter { Kontinenti.od(it.id).id == k && slobodna(it) }
                } else {
                    val region = regioni.firstOrNull { r -> lista.none { Mapa.oblast(it.prestonica).region == r.id } && Mapa.oblasti.any { it.region == r.id && slobodna(it) } }
                    if (region != null) Mapa.oblasti.filter { it.region == region.id && slobodna(it) } else emptyList()
                }
                if (kandidati.isEmpty()) kandidati = Mapa.oblasti.filter { oblasti[it.id] != null && oblasti[it.id]?.vlasnik == null }
                val prestonica = kandidati[(slucajno.sledeci() * kandidati.size).toInt()].id
                lista += Igrac(
                    p.id, if (p.covek && igraci == null) (ime ?: p.ime) else p.ime, p.boja, p.covek, prestonica, false, tim, p.kapiten,
                    p.vojska ?: (if (p.covek && igraci == null) vojska else null) ?: vojskaBota(p.id, if (p.covek) null else seme),
                )
                // Početni posed: prestonica i najbliže slobodne države po vezama (pretraga u širinu).
                val posed = mutableListOf(prestonica)
                val red = ArrayDeque(listOf(prestonica))
                val vidjeno = mutableSetOf(prestonica)
                while (red.isNotEmpty() && posed.size < Pravila.POCETNIH_DRZAVA) {
                    for (n in promesaj(Mapa.susedi(red.removeFirst()), mesanje)) {
                        if (n in vidjeno) continue
                        vidjeno += n
                        red += n
                        if (oblasti[n] != null && oblasti[n]?.vlasnik == null && Cudo.za(n) == null && posed.size < Pravila.POCETNIH_DRZAVA) posed += n
                    }
                }
                for (id in posed) oblasti[id] = StanjeOblasti(tim, if (id == prestonica) Pravila.POCETNE_VOJSKE_PRESTONICE else Pravila.POCETNE_VOJSKE_DRZAVE)
            }
            val karte = mutableMapOf<String, List<Karta>>()
            for (p in lista) if (p.kapiten && p.vojska == VrstaVojske.IZVIDNICA) karte[p.tim] = karte[p.tim].orEmpty() + Karta.SPIJUN
            var s = Stanje(lista, oblasti, 1, krugova, 0, Faza.SNABDEVANJE, 0, 0, 0, false, tezina.tacnost, seme = seme.neoznacen(), karteTimova = karte)
            if (misije) s = s.dodeliMisije(slucajno, izbegniMisije)
            return s
        }

        fun redosledIzbora(timovi: List<String>, krugova: Int = 1): List<String> =
            (0 until krugova).flatMap { if (it % 2 == 0) timovi else timovi.reversed() }

        /** Narav bota u partiji: iz id-a i semena (nova partija, nova narav); bez semena stara, stalna po id-ju. */
        fun narav(id: String, seme: Int? = null): Narav {
            if (seme == null || seme == 0) return when (id.zbirZnakova() % 3) { 0 -> Narav.NAPADAC; 1 -> Narav.GRADITELJ; else -> Narav.OPREZAN }
            return when ((mesaj(id, seme) * 3).toInt()) { 0 -> Narav.NAPADAC; 1 -> Narav.GRADITELJ; else -> Narav.OPREZAN }
        }

        /** Botu vojska prema naravi, da napadač ima napadačku vojsku, a oprezan odbrambenu. */
        fun vojskaBota(id: String, seme: Int? = null): VrstaVojske {
            val h = if (seme != null) (mesaj(id, seme, 7) * 2).toInt() else id.zbirZnakova()
            return when (narav(id, seme)) {
                Narav.NAPADAC -> if (h % 2 == 0) VrstaVojske.LEGIJA else VrstaVojske.KONJICA
                Narav.GRADITELJ -> if (h % 2 == 0) VrstaVojske.GRADITELJI else VrstaVojske.IZVIDNICA
                Narav.OPREZAN -> if (h % 2 == 0) VrstaVojske.GARDA else VrstaVojske.MUDRACI
            }
        }

        /** Šansa da napadač sa tačnošću `a` dobije bitku od `n` pitanja; `prednost` traži 2 tačna više. */
        fun sansaBitke(a: Double, b: Double, n: Int, prednost: Boolean, pomak: Int = 0): Double {
            fun bin(p: Double) = (0..n).map { k ->
                var c = 1.0
                for (i in 0 until k) c = c * (n - i) / (i + 1)
                c * Math.pow(p, k.toDouble()) * Math.pow(1 - p, (n - k).toDouble())
            }
            val pa = bin(a); val pb = bin(b)
            var w = 0.0
            for (i in 0..n) for (j in 0..n) {
                val r = i - j + pomak
                if (prednost) { if (r >= 2) w += pa[i] * pb[j] }
                else if (r > 0) w += pa[i] * pb[j] else if (r == 0) w += pa[i] * pb[j] * 0.5
            }
            return w
        }

        /** Bot ulaže kad je bitka skoro sigurna (šansa > 0,7 jedan, > 0,85 dva). */
        fun ulogBota(sansa: Double): Int = if (sansa > 0.85) 2 else if (sansa > 0.7) 1 else 0

        fun kljucSaveza(a: String, b: String): String = listOf(a, b).sorted().joinToString("|")

        /** Procena umesto broja u magli. */
        fun procenaVojske(n: Int): String = if (n <= 2) "≤2" else if (n <= 5) "3–5" else "6+"
    }

    /** Tim igrača (vlasnik država); prima i id igrača i id tima. */
    fun timOd(id: String): String = igraci.firstOrNull { it.id == id }?.tim ?: id

    /** Države igrača, tj. njegovog tima. */
    fun oblastiIgraca(id: String): List<String> { val tim = timOd(id); return Mapa.oblasti.filter { oblasti[it.id]?.vlasnik == tim }.map { it.id } }

    private fun celiRegioniTima(tim: String) = Mapa.regioni.filter { r -> Mapa.oblasti.filter { it.region == r.id }.all { oblasti[it.id]?.vlasnik == tim } }

    fun bonusRegiona(id: String): Int = celiRegioniTima(timOd(id)).sumOf { it.bonus }

    fun pojacanja(id: String, tacno: Boolean): Int {
        val tim = timOd(id)
        val celi = celiRegioniTima(tim)
        // Zlatno doba Afrike duplira bonus afričkih regiona; Graditelji dobijaju +1 po celom regionu.
        val afrika = Kontinenti.svi.first { it.id == "afr" }.regioni
        val zlatno = if (aktivanDogadjaj("afr")) celi.filter { it.id in afrika }.sumOf { it.bonus } else 0
        val puno = max(Pravila.NAJMANJE_POJACANJA, oblastiIgraca(id).size / Pravila.TERITORIJA_PO_VOJSCI) + bonusRegiona(id) + zlatno +
            (if (vojskaTima(tim) == VrstaVojske.GRADITELJI) celi.size else 0)
        return if (tacno) puno else max(1, puno / 2)
    }

    fun snabdevanje(tacno: Boolean): Stanje {
        if (faza != Faza.SNABDEVANJE) return this
        var s = this
        val ja = trenutni
        if (tacno) s = s.copy(tacnih = s.tacnih + (ja.tim to (s.tacnih[ja.tim] ?: 0) + 1))
        val (posle, pohod) = s.proveriPohod(ja.tim)
        s = posle
        var vojske = s.pojacanja(ja.id, tacno) + pohod + (if (s.drziCudo(ja.tim, "EGY")) Pravila.VOJSKI_PIRAMIDE else 0)
        if (s.drziCudo(ja.tim, "GRC")) s = s.dodeliKartu(ja.tim)
        // Odsečene države (bez puta do prestonice) gube jednu vojsku po krugu.
        val obl = s.oblasti.toMutableMap()
        for (id in s.odsecene(ja.tim)) { val o = obl.getValue(id); if (o.vojske > 1) obl[id] = o.copy(vojske = o.vojske - 1) }
        s = s.copy(oblasti = obl)
        // Odbrane koštaju vojske jednom po krugu: plaća se na kapitenovom potezu.
        if (ja.kapiten) {
            val odb = s.odbrane.toMutableMap()
            for (k in s.odbrane.keys.sorted()) {
                if (!s.drziKontinent(ja.tim, k)) continue
                val cena = odb.getValue(k).cena
                if (cena <= vojske - 1) vojske -= cena else odb[k] = Odbrana.BRZ_SAT
            }
            s = s.copy(odbrane = odb)
        }
        return s.copy(faza = Faza.RASPORED, zaRaspored = vojske)
    }

    fun rasporedi(oblastId: String): Stanje {
        // Pojačanja stižu samo u države povezane sa prestonicom (linije snabdevanja).
        if (faza != Faza.RASPORED || zaRaspored <= 0 || oblasti[oblastId]?.vlasnik != trenutni.tim || oblastId !in snabdevene(trenutni.tim)) return this
        val o = oblasti.getValue(oblastId)
        val ostalo = zaRaspored - 1
        return copy(oblasti = oblasti + (oblastId to o.copy(vojske = o.vojske + 1)), zaRaspored = ostalo, faza = if (ostalo == 0) Faza.NAPAD else faza)
    }

    /** Napada zaredom po potezu: 5 svako za sebe, 2 po igraču u timu. */
    val napadaPoPotezu: Int get() =
        (if (igraci.map { it.tim }.toSet().size < igraci.size) Pravila.BITAKA_U_TIMU_PO_IGRACU else Pravila.BITAKA_PO_POTEZU) +
            (if (trenutni.vojska == VrstaVojske.KONJICA) Pravila.NAPADA_VISE_KONJICA else 0) +
            (if (drziCudo(trenutni.tim, "USA")) 1 else 0)

    fun mete(odakle: String): List<String> {
        val izvor = oblasti[odakle]
        if (faza != Faza.NAPAD || bitaka >= napadaPoPotezu || izvor == null || izvor.vlasnik != trenutni.tim || izvor.vojske < 2) return emptyList()
        // Ne napada se saveznik, zamrznuta država ni Azija za vreme Monsuna.
        return Mapa.susedi(odakle).filter { id ->
            val o = oblasti[id] ?: return@filter false
            if (o.vlasnik == izvor.vlasnik) return@filter false
            if (o.vlasnik != null && uSavezu(o.vlasnik, izvor.vlasnik!!)) return@filter false
            if (jeZamrznuta(id)) return@filter false
            !(aktivanDogadjaj("azi") && Kontinenti.od(id).id == "azi")
        }
    }

    val mozeDaNapada: Boolean get() = oblastiIgraca(trenutni.id).any { mete(it).isNotEmpty() }

    /** Bitka od jednog pitanja. [branilac] je null kad je oblast neutralna. */
    fun razresiBitku(odakle: String, kuda: String, napadac: Odgovor, branilac: Odgovor?): Pair<Stanje, Ishod> {
        // Napad koji više ne važi (stanje se promenilo dok je igrač branio) se preskače umesto pada aplikacije (iOS isto, 03.11).
        if (kuda !in mete(odakle)) return this to Ishod(0, 0, osvojeno = false, proboj = false, plen = false)
        val izvor = oblasti.getValue(odakle)
        val meta = oblasti.getValue(kuda)
        var gubitakNapadaca = 0
        var gubitakBranioca = 0
        if (meta.vlasnik == null || branilac == null) {
            // Jaka vojska (3+ u napadu) ne gubi vojsku kad promaši neutralnu državu.
            if (napadac.tacan) gubitakBranioca = 1 else if (izvor.vojske - 1 < Pravila.VOJSKI_BEZ_GUBITKA_NA_NEUTRALNOJ) gubitakNapadaca = 1
        } else {
            when {
                napadac.tacan && !branilac.tacan -> gubitakBranioca = 2
                !napadac.tacan && branilac.tacan -> gubitakNapadaca = 2
                // Nerešen odgovor rešava brzina; jednako vreme ide braniocu.
                napadac.tacan && branilac.tacan -> if (napadac.ms < branilac.ms) gubitakBranioca = 1 else gubitakNapadaca = 1
                else -> { gubitakNapadaca = 1; gubitakBranioca = 1 }
            }
        }
        val odbrana = odbranaMete(kuda)
        val k = Kontinenti.od(kuda).id
        var s = this
        if (odbrana == Odbrana.ZAMKA && !napadac.tacan) gubitakNapadaca += 1
        if (odbrana == Odbrana.TVRDJAVA && gubitakBranioca > 0 && tvrdjava[k] != krug) {
            gubitakBranioca = 0
            s = s.copy(tvrdjava = s.tvrdjava + (k to krug))
        }
        if (gubitakNapadaca > 0 && kuda in Teren.pustinja) gubitakNapadaca += 1
        val vojskeNapadaca = max(1, izvor.vojske - gubitakNapadaca)
        val vojskeBranioca = max(0, meta.vojske - gubitakBranioca)
        val osvojeno = vojskeBranioca == 0
        var proboj = false
        var plen = false
        if (osvojeno) {
            val prelazi = vojskeNapadaca - 1
            val niz = s.niz + 1
            proboj = niz % Pravila.PROBOJ_SVAKIH == 0
            plen = meta.vlasnik != null && igraci.any { it.prestonica == kuda && it.tim == meta.vlasnik }
            s = s.copy(niz = niz, oblasti = s.oblasti + mapOf(
                odakle to StanjeOblasti(izvor.vlasnik, 1),
                kuda to StanjeOblasti(izvor.vlasnik, max(1, prelazi) + (if (proboj) Pravila.PROBOJ_BONUS else 0) + (if (plen) Pravila.PLEN_PRESTONICE else 0) + s.groznica(kuda)),
            ))
            s = s.nagradiOsvajanje(izvor.vlasnik!!, kuda, proboj)
        } else {
            s = s.copy(oblasti = s.oblasti + mapOf(odakle to izvor.copy(vojske = vojskeNapadaca), kuda to meta.copy(vojske = vojskeBranioca)))
        }
        val t = s.tacnih.toMutableMap()
        if (napadac.tacan) t[trenutni.tim] = (t[trenutni.tim] ?: 0) + 1
        if (branilac?.tacan == true && meta.vlasnik != null) t[meta.vlasnik] = (t[meta.vlasnik] ?: 0) + 1
        s = s.copy(tacnih = t).posleBitke()
        return s to Ishod(izvor.vojske - vojskeNapadaca, meta.vojske - vojskeBranioca, osvojeno, proboj, plen)
    }

    /** Bitka od 5 pitanja za državu koju drži igrač: više tačnih, pa brži; isto ide braniocu. */
    fun razresiBitkuSkorom(odakle: String, kuda: String, napadac: Skor, branilac: Skor): Pair<Stanje, Ishod> {
        if (kuda !in mete(odakle)) return this to Ishod(0, 0, osvojeno = false, proboj = false, plen = false)
        val izvor = oblasti.getValue(odakle)
        val meta = oblasti.getValue(kuda)
        val braniTim = meta.vlasnik!!
        val napadaTim = izvor.vlasnik!!
        val odbrana = odbranaMete(kuda)
        val k = Kontinenti.od(kuda).id
        var pobedio = osvaja(odakle, kuda, napadac, branilac)
        var s = this
        var gubitakBranioca = 0
        var tvrdjavaDrzi = false
        if (pobedio && odbrana == Odbrana.TVRDJAVA && tvrdjava[k] != krug) {
            // Prvi poraz u krugu: branilac zadržava državu, ali gubi jednu vojsku.
            pobedio = false
            tvrdjavaDrzi = true
            gubitakBranioca = min(1, meta.vojske - 1)
            s = s.copy(tvrdjava = s.tvrdjava + (k to krug))
        }
        var proboj = false
        var plen = false
        var gubitakNapadaca = 0
        if (pobedio) {
            val niz = s.niz + 1
            proboj = niz % Pravila.PROBOJ_SVAKIH == 0
            plen = igraci.any { it.prestonica == kuda && it.tim == braniTim }
            gubitakBranioca = meta.vojske
            s = s.copy(niz = niz, oblasti = s.oblasti + mapOf(
                odakle to StanjeOblasti(napadaTim, 1),
                kuda to StanjeOblasti(napadaTim, max(1, izvor.vojske - 1) + (if (proboj) Pravila.PROBOJ_BONUS else 0) + (if (plen) Pravila.PLEN_PRESTONICE else 0) + s.groznica(kuda)),
            ))
            s = s.nagradiOsvajanje(napadaTim, kuda, proboj)
            // Ulog: osvojena država dobija ulog, a branilac gubi još toliko iz najjače susedne države.
            ulog?.let { u ->
                val obl = s.oblasti.toMutableMap()
                obl[kuda] = obl.getValue(kuda).let { it.copy(vojske = it.vojske + u) }
                s.najjacaPored(kuda, braniTim)?.let { n -> obl[n] = obl.getValue(n).let { it.copy(vojske = max(1, it.vojske - u)) } }
                s = s.copy(oblasti = obl)
            }
        } else if (tvrdjavaDrzi) {
            // Tvrđava je izdržala: napadač ostaje u svojoj državi, branilac gubi vojsku.
            s = s.copy(oblasti = s.oblasti + (kuda to meta.copy(vojske = meta.vojske - gubitakBranioca)))
        } else {
            // Izgubljena bitka protiv igrača: branilac uzima državu iz koje se napadalo, sa preživelim vojskama.
            val ostaje = max(1, izvor.vojske - Pravila.GUBITAK_PORAZENOG_NAPADACA - (if (odbrana == Odbrana.ZAMKA) 1 else 0) - (if (kuda in Teren.pustinja) 1 else 0))
            gubitakNapadaca = izvor.vojske
            s = s.copy(oblasti = s.oblasti + (odakle to StanjeOblasti(braniTim, ostaje)))
            // Ulog: napadač gubi još toliko iz svoje najjače države pored izgubljene.
            val u = ulog
            val n = if (u != null) s.najjacaPored(odakle, napadaTim) else null
            if (u != null && n != null) s = s.copy(oblasti = s.oblasti + (n to s.oblasti.getValue(n).let { it.copy(vojske = max(1, it.vojske - u)) }))
        }
        val t = s.tacnih.toMutableMap()
        t[napadaTim] = (t[napadaTim] ?: 0) + napadac.tacnih
        t[braniTim] = (t[braniTim] ?: 0) + branilac.tacnih
        s = s.copy(tacnih = t)
        // Pobeda nad igračem (napad ili odbrana) donosi ratnu kartu.
        val pobednikBitke = if (pobedio) napadaTim else braniTim
        if (!tvrdjavaDrzi) {
            s = s.dodeliKartu(pobednikBitke)
            val p = s.pobedaBitaka.orEmpty()
            s = s.copy(pobedaBitaka = p + (pobednikBitke to (p[pobednikBitke] ?: 0) + 1))
        }
        s = s.posleBitke()
        return s to Ishod(gubitakNapadaca, gubitakBranioca, pobedio, proboj, plen, izgubljenaDrzava = !pobedio && !tvrdjavaDrzi)
    }

    /** Zlatna groznica: osvojena država u Severnoj Americi daje +1 vojsku. */
    fun groznica(kuda: String): Int = if (aktivanDogadjaj("sam") && Kontinenti.od(kuda).id == "sam") 1 else 0

    /** Karte za osvajanje: zatvoren region i proboj uvek, Izvidnica i za svako drugo osvajanje zaredom. */
    fun nagradiOsvajanje(tim: String, kuda: String, proboj: Boolean): Stanje {
        val region = Mapa.oblast(kuda).region
        val zatvoren = Mapa.oblasti.filter { it.region == region && oblasti[it.id] != null }.all { oblasti[it.id]?.vlasnik == tim }
        var s = this
        if (zatvoren) s = s.dodeliKartu(tim)
        if (proboj) s = s.dodeliKartu(tim)
        if (!zatvoren && !proboj && vojskaTima(tim) == VrstaVojske.IZVIDNICA && niz % 2 == 0) s = s.dodeliKartu(tim)
        return s
    }

    private fun posleBitke(): Stanje {
        val igr = igraci.map { i -> if (!i.ispao && oblasti.values.none { it.vlasnik == i.tim }) i.copy(ispao = true) else i }
        var s = copy(igraci = igr, bitaka = bitaka + 1, ulog = null)
        if (s.pobednik == null) s.timSaIspunjenomMisijom?.let { s = s.copy(pobednik = it, faza = Faza.KRAJ) }
        return s
    }

    /** Marš, jednom po potezu: vojske do svoje države udaljene najviše 3 koraka kroz svoje države; u izvoru ostaje 1. */
    fun utvrdi(odakle: String, kuda: String, broj: Int): Stanje {
        val tim = trenutni.tim
        val a = oblasti[odakle]; val b = oblasti[kuda]
        if (faza != Faza.NAPAD || utvrdjeno || a == null || b == null || a.vlasnik != tim || b.vlasnik != tim || kuda !in dometMarsa(odakle)) return this
        val n = min(broj, a.vojske - 1)
        if (n <= 0) return this
        return copy(utvrdjeno = true, oblasti = oblasti + mapOf(odakle to a.copy(vojske = a.vojske - n), kuda to b.copy(vojske = b.vojske + n)))
    }

    /**
     * Isteklo vreme na potezu igrača `id`: bez ijednog napada to je propušten potez; treći zaredom ga izbacuje,
     * a države njegovog tima (ako niko iz tima nije ostao) postaju neutralne sa pola vojske.
     */
    fun isteklo(id: String): Stanje {
        val p = propusteno.orEmpty().toMutableMap()
        p[id] = if (bitaka > 0) 0 else (p[id] ?: 0) + 1
        var s = copy(propusteno = p)
        val i = s.igraci.indexOfFirst { it.id == id }
        if ((p[id] ?: 0) >= Pravila.PROPUSTENIH_DO_ISPADANJA && i >= 0) {
            val igr = s.igraci.toMutableList(); igr[i] = igr[i].copy(ispao = true)
            s = s.copy(igraci = igr)
            val tim = igr[i].tim
            if (igr.none { it.tim == tim && !it.ispao }) {
                s = s.copy(oblasti = s.oblasti.mapValues { (_, o) -> if (o.vlasnik == tim) StanjeOblasti(null, max(1, o.vojske / 2)) else o })
            }
        }
        return s.zavrsiPotez()
    }

    fun zavrsiPotez(): Stanje {
        if (faza == Faza.KRAJ) return this
        if (igraci.filter { !it.ispao }.map { it.tim }.toSet().size <= 1) return copy(faza = Faza.KRAJ)
        var sledeci = naPotezu
        var krug = this.krug
        do {
            sledeci = (sledeci + 1) % igraci.size
            if (sledeci == 0) krug += 1
        } while (igraci[sledeci].ispao)
        if (krug > ukupnoKrugova) return copy(faza = Faza.KRAJ)
        var s = copy(naPotezu = sledeci, krug = krug, faza = Faza.SNABDEVANJE, zaRaspored = 0, bitaka = 0, niz = 0, utvrdjeno = false)
        if (krug != this.krug) s = s.pokreniDogadjajAkoTreba()
        return s
    }

    fun poeni(id: String): Int {
        val tim = timOd(id)
        val moje = oblastiIgraca(id)
        val vojske = moje.sumOf { oblasti[it]?.vojske ?: 0 }
        val prestonica = igraci.firstOrNull { it.id == id }?.let { if (oblasti[it.prestonica]?.vlasnik == tim) Pravila.POENI_PRESTONICA else 0 } ?: 0
        return moje.size * Pravila.POENI_PO_OBLASTI + vojske + bonusRegiona(id) * Pravila.POENI_PO_BONUSU + prestonica
    }

    val poredak: List<Pair<Igrac, Int>> get() = igraci.map { it to poeni(it.id) }.sortedByDescending { it.second }

    // ── Kontinenti i odbrane ──

    fun drziKontinent(tim: String, kontinentId: String): Boolean {
        val l = Kontinenti.oblasti(kontinentId)
        return l.isNotEmpty() && l.all { oblasti[it]?.vlasnik == tim }
    }

    /** Odbrana koja štiti metu: važi samo dok vlasnik mete drži ceo njen kontinent. */
    fun odbranaMete(kuda: String): Odbrana? {
        val v = oblasti[kuda]?.vlasnik ?: return null
        val k = Kontinenti.od(kuda).id
        val o = odbrane[k] ?: return null
        return if (drziKontinent(v, k)) o else null
    }

    /** Uslov bitke za metu; `za` = tim koji odgovara (Mudraci imaju više vremena), Karneval produžava sat u Južnoj Americi. */
    fun uslovBitke(kuda: String, za: String? = null): Uslov {
        val o = odbranaMete(kuda)
        val dodatak = (if (za != null && vojskaTima(za) == VrstaVojske.MUDRACI) Pravila.SEKUNDI_MUDRACI else 0) +
            (if (za != null && drziCudo(za, "AUS")) Pravila.SEKUNDI_OPERA else 0) +
            (if (aktivanDogadjaj("jam") && Kontinenti.od(kuda).id == "jam") Pravila.SEKUNDI_KARNEVAL else 0)
        return Uslov(
            (if (o == Odbrana.BRZ_SAT) Pravila.SEKUNDI_BRZ_SAT else Pravila.SEKUNDI_PO_PITANJU) + dodatak, o == Odbrana.BEZ_POMOCI,
            o == Odbrana.TESKO_PITANJE, if (oblasti[kuda]?.vlasnik != null) Pravila.PITANJA_U_BITCI else 1,
            o == Odbrana.TEMA_BRANIOCA, if (o == Odbrana.PREDNOST) 2 else 0,
        )
    }

    /** Kapiten tima koji drži ceo kontinent bira odbranu; menja je najviše jednom po krugu. */
    fun postaviOdbranu(kontinentId: String, o: Odbrana): Stanje {
        val ja = trenutni
        if (!ja.kapiten || faza == Faza.KRAJ || !drziKontinent(ja.tim, kontinentId) || promenaOdbrane[kontinentId] == krug) return this
        return copy(odbrane = odbrane + (kontinentId to o), promenaOdbrane = promenaOdbrane + (kontinentId to krug))
    }

    /** Odbrana kontinenta: kad cilj ili jak rival dira kontinent, „Prednost”, inače „Brz sat”. */
    fun botOdbrana(): Stanje {
        var s = this
        val tim = trenutni.tim
        val cilj = ciljBota(tim)
        for (k in Kontinenti.svi) {
            if (s.odbrane[k.id] != null || !s.drziKontinent(tim, k.id)) continue
            val ugrozen = Kontinenti.oblasti(k.id).any { s.pretnja(it, tim, cilj) >= 4 }
            s = s.postaviOdbranu(k.id, if (ugrozen) Odbrana.PREDNOST else Odbrana.BRZ_SAT)
        }
        return s
    }

    fun iskoristiBonusPomoc(tim: String): Stanje? {
        val n = bonusPomoci[tim] ?: 0
        if (n <= 0) return null
        return copy(bonusPomoci = bonusPomoci + (tim to n - 1))
    }

    // ── Misije ──

    private fun udeo(tim: String, ids: List<String>): Double {
        val sve = ids.flatMap { Kontinenti.oblasti(it) }
        return sve.count { oblasti[it]?.vlasnik == tim }.toDouble() / sve.size
    }

    /** Napredak misije tima od 0 do 1 (1 = ispunjena). */
    fun napredakMisije(tim: String): Double {
        val drzave = Mapa.oblasti.filter { oblasti[it.id]?.vlasnik == tim }
        fun do1(x: Double) = min(1.0, x)
        return when (misije[tim]) {
            "evr-jam" -> udeo(tim, listOf("evr", "jam"))
            "evr-oke-jos" -> {
                val osnova = udeo(tim, listOf("evr", "oke"))
                val ostali = Kontinenti.svi.filter { it.id != "evr" && it.id != "oke" }.map { udeo(tim, listOf(it.id)) }
                if (osnova < 1) osnova * 0.75 else 0.75 + 0.25 * (ostali.maxOrNull() ?: 0.0)
            }
            "sam-jam" -> udeo(tim, listOf("sam", "jam"))
            "azi-jam" -> udeo(tim, listOf("azi", "jam"))
            "afr-oke" -> udeo(tim, listOf("afr", "oke"))
            "sam-oke" -> udeo(tim, listOf("sam", "oke"))
            "drzava60" -> do1(drzave.size / prag(60.0))
            "drzava45x2" -> do1(drzave.count { (oblasti[it.id]?.vojske ?: 0) >= 2 } / prag(45.0))
            "regiona8" -> do1(celiRegioni(tim) / prag(8.0))
            "prestonice2" -> do1(igraci.count { it.tim != tim && oblasti[it.prestonica]?.vlasnik == tim } / 2.0)
            "izbaci" -> { val meta = metaMisije[tim]; if (igraci.filter { it.tim == meta }.all { it.ispao }) 1.0 else 0.0 }
            "tacnih25" -> do1((tacnih[tim] ?: 0) / 25.0) * 0.5 + do1(drzave.size / 30.0) * 0.5
            "evr-afr" -> udeo(tim, listOf("evr", "afr"))
            "sam-evr" -> udeo(tim, listOf("sam", "evr"))
            "azi-oke" -> udeo(tim, listOf("azi", "oke"))
            "afr-jam" -> udeo(tim, listOf("afr", "jam"))
            "kontinenta2" -> { val u = Kontinenti.svi.map { udeo(tim, listOf(it.id)) }.sortedDescending(); (u[0] + u[1]) / 2 }
            "drzava50" -> do1(drzave.size / prag(50.0))
            "regiona10" -> do1(celiRegioni(tim) / prag(10.0))
            "regiona6-kontinent" -> do1(celiRegioni(tim) / prag(6.0)) * 0.5 + (Kontinenti.svi.maxOfOrNull { udeo(tim, listOf(it.id)) } ?: 0.0) * 0.5
            "prestonice3" -> do1(igraci.count { it.tim != tim && oblasti[it.prestonica]?.vlasnik == tim } / 3.0)
            "vojske150" -> do1(drzave.sumOf { oblasti[it.id]?.vojske ?: 0 } / prag(150.0))
            "tacnih40" -> do1((tacnih[tim] ?: 0) / 40.0)
            "pobeda10" -> do1((pobedaBitaka?.get(tim) ?: 0) / 10.0)
            "ostrva" -> udeoRegiona(tim, listOf("oke", "kar"))
            "put-svile" -> udeoRegiona(tim, listOf("bli", "caz", "iaz"))
            "mediteran" -> udeoRegiona(tim, listOf("jev", "saf", "bli"))
            "svuda4" -> Kontinenti.svi.sumOf { k -> do1(Kontinenti.oblasti(k.id).count { oblasti[it]?.vlasnik == tim } / 4.0) } / Kontinenti.svi.size
            "prestonica35" -> if (igraci.any { it.tim == tim && oblasti[it.prestonica]?.vlasnik == tim }) do1(drzave.size / prag(35.0)) else 0.0
            "amerike-pola" -> udeo(tim, listOf("jam")) * 0.5 + do1(udeo(tim, listOf("sam")) * 2) * 0.5
            "cuda3" -> do1(Cudo.sva.count { oblasti[it.oblast]?.vlasnik == tim } / 3.0)
            "pohodi3" -> do1((uspeliPohodi?.get(tim) ?: 0) / 3.0) * 0.6 + do1(drzave.size / 25.0) * 0.4
            else -> 0.0
        }
    }

    /** Misije su pravljene za 3 strane; sa više strana pragovi se srazmerno smanjuju (6 strana = pola), najviše na pola. */
    val faktorMisije: Double get() = min(1.0, max(0.5, 3.0 / max(1, igraci.map { it.tim }.toSet().size)))
    fun prag(n: Double): Double = max(1.0, Math.round(n * faktorMisije).toDouble())

    /** Tekst misije sa brojevima prilagođenim broju strana (npr. „Drži 30 država” kad igra šestoro). */
    fun tekstMisije(id: String?): String {
        val t = Misije.tekst(id)
        if (id == null || id !in Misije.skalirane) return t
        return Regex("\\d+").replace(t) { prag(it.value.toDouble()).toInt().toString() }
    }

    fun celiRegioni(tim: String): Int = celiRegioniTima(tim).size

    fun udeoRegiona(tim: String, regioni: List<String>): Double {
        val sve = Mapa.oblasti.filter { it.region in regioni }
        return sve.count { oblasti[it.id]?.vlasnik == tim }.toDouble() / max(1, sve.size)
    }

    val timSaIspunjenomMisijom: String? get() = misije.keys.sorted().firstOrNull { napredakMisije(it) >= 1 }

    /** Tajne misije: svaki tim svoju; misije iz `izbegni` (čovek ih je imao ove nedelje) idu na kraj reda. */
    private fun dodeliMisije(slucajno: Slucajno, izbegni: Set<String> = emptySet()): Stanje {
        val timovi = mutableListOf<String>()
        for (p in igraci) if (p.tim !in timovi) timovi += p.tim
        val pojedinacno = timovi.size == igraci.size
        val ponuda = Misije.sve.filter { (pojedinacno || !it.samoPojedinacno) && timovi.size - 1 >= it.najmanjeRivala }.map { it.id }.toMutableList()
        for (i in ponuda.size - 1 downTo 1) { val j = (slucajno.sledeci() * (i + 1)).toInt(); val t = ponuda[i]; ponuda[i] = ponuda[j]; ponuda[j] = t }
        val red = ponuda.filter { it !in izbegni } + ponuda.filter { it in izbegni }
        val mis = misije.toMutableMap(); val meta = metaMisije.toMutableMap()
        for ((i, tim) in timovi.withIndex()) {
            val m = red[i % red.size]
            mis[tim] = m
            if (m == "izbaci") { val drugi = timovi.filter { it != tim }; meta[tim] = drugi[(slucajno.sledeci() * drugi.size).toInt()] }
        }
        return copy(misije = mis, metaMisije = meta)
    }

    // ── Botovi ──

    fun botOdgovor(slucajno: Slucajno): Odgovor = Odgovor(slucajno.sledeci() < tacnostBota, 3000 + (slucajno.sledeci() * 9000).toInt())

    fun botSkor(slucajno: Slucajno, pitanja: Int = Pravila.PITANJA_U_BITCI): Skor {
        var t = 0; var ms = 0
        repeat(pitanja) { val o = botOdgovor(slucajno); if (o.tacan) t++; ms += o.ms }
        return Skor(t, ms)
    }

    // Mozak bota (docs/OSVAJANJE-BOT.md): koga cilja, gde stavlja vojsku, koju bitku bira (šansa × vrednost − rizik),
    // pa pred kraj poteza prebacuje vojsku iz unutrašnjosti na najugroženiju granicu.

    fun narav(id: String): Narav = narav(id, seme?.bitovi())

    /** Ljudi u partiji: igrač na ovom telefonu ili pravi nalog („u:”). */
    private fun jeCovek(i: Igrac) = i.covek || i.id.startsWith("u:")

    /** Snaga tima: države, vojske i celi regioni (bonus vojske svakog kruga). */
    fun snaga(tim: String): Double {
        val moje = oblasti.values.filter { it.vlasnik == tim }
        return moje.size + moje.sumOf { it.vojske } * 0.5 + bonusRegiona(tim) * 3.0
    }

    /** Koga bot cilja (svi ravnopravno, i ljudi i botovi): najjačeg suseda koji nije saveznik; inače najjačeg rivala. */
    fun ciljBota(tim: String): String? {
        val rivali = igraci.filter { !it.ispao && it.tim != tim && !uSavezu(tim, it.tim) }.map { it.tim }.toSet()
        val moje = oblasti.filter { it.value.vlasnik == tim }.keys
        val susedi = moje.flatMap { Mapa.susedi(it) }.mapNotNull { oblasti[it]?.vlasnik }.toSet().intersect(rivali)
        return (if (susedi.isEmpty()) rivali else susedi).maxWithOrNull(compareBy<String>({ snaga(it) }, { it }))
    }

    /** Koliko tuđe vojske preti državi (cilj se računa jače). */
    fun pretnja(id: String, tim: String, cilj: String?): Double = Mapa.susedi(id).sumOf { n ->
        val o = oblasti[n]; val v = o?.vlasnik
        if (o == null || v == null || v == tim) 0.0 else o.vojske * (if (v == cilj) 1.5 else 1.0)
    }

    /** Koliko država regiona još fali timu. */
    private fun fali(region: String, tim: String) = Mapa.oblasti.count { it.region == region && oblasti[it.id] != null && oblasti[it.id]?.vlasnik != tim }

    /** Vrednost države za tim: region koji se zatvara, tuđi region koji se ruši, prestonica, cilj, kontinent iz misije. */
    private fun vrednost(kuda: String, tim: String, cilj: String?, narav: Narav): Double {
        val o = Mapa.oblast(kuda)
        val bonus = (Mapa.regioni.firstOrNull { it.id == o.region }?.bonus ?: 0).toDouble()
        val gradnja = if (narav == Narav.GRADITELJ) 1.4 else 1.0
        var v = 1.0
        val f = fali(o.region, tim)
        v += if (f == 1) bonus * 1.5 * gradnja else bonus * 0.3 * gradnja / max(1, f)
        oblasti[kuda]?.vlasnik?.let { vlasnik ->
            if (fali(o.region, vlasnik) == 0) v += bonus * 1.2
            if (igraci.any { it.tim == vlasnik && it.prestonica == kuda }) v += 3
            if (vlasnik == cilj) v += 1.5
        }
        misije[tim]?.let { if (it.contains(Kontinenti.od(kuda).id)) v += 0.8 }
        if (Cudo.za(kuda) != null) v += 2.5
        if (pohodi?.get(tim) == o.region) v += 1.5
        return v
    }

    /** Ocena napada: šansa × dobitak − (1 − šansa) × gubitak. Protiv igrača poraz odnosi i državu iz koje se napada. */
    fun ocenaNapada(odakle: String, kuda: String): Double {
        val tim = trenutni.tim
        val nar = narav(trenutni.id, null as Int?) // kao iOS: `Stanje.narav(trenutni.id)` bez semena
        val cilj = ciljBota(tim)
        val izvor = oblasti[odakle] ?: return Double.NEGATIVE_INFINITY
        val meta = oblasti[kuda] ?: return Double.NEGATIVE_INFINITY
        val dobitak = vrednost(kuda, tim, cilj, nar)
        val p: Double
        var gubitak: Double
        val vlasnik = meta.vlasnik
        if (vlasnik != null) {
            val branilac = if (igraci.firstOrNull { it.tim == vlasnik }?.let(::jeCovek) == true) 0.65 else tacnostBota
            p = sansaBitke(tacnostBota, branilac, uslovBitke(kuda).pitanja, odbranaMete(kuda) == Odbrana.PREDNOST, pomakBitke(odakle, kuda))
            gubitak = 1 + max(0, izvor.vojske - Pravila.GUBITAK_PORAZENOG_NAPADACA) * 0.4
            if (igraci.any { it.tim == tim && it.prestonica == odakle }) gubitak += 4
            val region = Mapa.oblast(odakle).region
            if (fali(region, tim) == 0) gubitak += Mapa.regioni.firstOrNull { it.id == region }?.bonus ?: 0
        } else {
            p = tacnostBota
            gubitak = if (izvor.vojske - 1 >= Pravila.VOJSKI_BEZ_GUBITKA_NA_NEUTRALNOJ) 0.0 else 0.5
        }
        if (nar == Narav.OPREZAN) gubitak *= 1.3
        return p * dobitak - (1 - p) * gubitak
    }

    /** Prag ispod kog bot ne napada. */
    private fun pragNapada(nar: Narav) = when (nar) { Narav.NAPADAC -> 0.1; Narav.GRADITELJ -> 0.25; Narav.OPREZAN -> 0.5 }

    /** Koliko od najboljeg poteza bot još smatra dobrim (lako 1,2, normalno 0,6, teško 0,25 poena ocene). */
    val rasipanjeBota: Double get() = if (tacnostBota < 0.55) 1.2 else if (tacnostBota < 0.7) 0.6 else 0.25

    /** Koliko često bot uzme lošiji potez (lako 35%, normalno 12%, teško nikad). */
    private val greskaBota: Double get() = if (tacnostBota < 0.55) 0.35 else if (tacnostBota < 0.7) 0.12 else 0.0

    fun botRasporedi(): Stanje {
        var s = this
        val tim = trenutni.tim
        val cilj = ciljBota(tim)
        while (s.faza == Faza.RASPORED) {
            val snabdevene = s.snabdevene(tim)
            val moje = s.oblastiIgraca(s.trenutni.id).filter { it in snabdevene }
            val prva = moje.firstOrNull()
            if (prva == null) { s = s.copy(zaRaspored = 0, faza = Faza.NAPAD); break }
            // Vojska ide tamo gde je najveća pretnja ili odakle se zatvara region; prestonica se čuva.
            val st = s
            fun ocena(id: String): Double {
                var v = st.pretnja(id, tim, cilj) - (st.oblasti[id]?.vojske ?: 0) * 0.6
                if (Mapa.susedi(id).any { n -> st.oblasti[n] != null && st.oblasti[n]?.vlasnik != tim && st.fali(Mapa.oblast(n).region, tim) == 1 }) v += 3
                if (st.igraci.any { it.tim == tim && it.prestonica == id }) v += 1.5
                // Šum iz semena partije: raspored nije svake partije isti.
                st.seme?.let { v += mesaj(id, it.bitovi(), st.krug * 31 + st.zaRaspored) * st.rasipanjeBota * 2 }
                return v
            }
            val granica = moje.filter { s.pretnja(it, tim, cilj) > 0 }
            val cel = (if (granica.isEmpty()) moje else granica).maxWithOrNull(compareBy { ocena(it) }) ?: prva
            s = s.rasporedi(cel)
        }
        return s
    }

    fun botSledeciNapad(): Pair<String, String>? {
        val nar = narav(trenutni.id)
        val opcije = mutableListOf<Triple<String, String, Double>>()
        for (odakle in oblastiIgraca(trenutni.id)) for (kuda in mete(odakle)) opcije += Triple(odakle, kuda, ocenaNapada(odakle, kuda))
        if (opcije.isEmpty()) return null
        // Šum je vezan za krug, bitku i seme partije: isti na dva telefona, različit od partije do partije.
        val r = Slucajno((krug * 7919 + naPotezu * 131 + bitaka * 17 + 1) xor semeBitovi)
        if (r.sledeci() < greskaBota) {
            val losije = opcije.filter { it.third > -1 }
            if (losije.isNotEmpty()) { val o = losije[(r.sledeci() * losije.size).toInt()]; return o.first to o.second }
        }
        val najbolja = opcije.maxWithOrNull(compareBy { it.third })!!
        if (najbolja.third < pragNapada(nar)) return null
        // Ne uvek isti potez: bot bira među skoro najboljim (lako šire, teško uže), težinski po oceni.
        val dobri = opcije.filter { it.third >= max(pragNapada(nar), najbolja.third - rasipanjeBota) }
        val tezine = dobri.map { it.third - (najbolja.third - rasipanjeBota) + 0.05 }
        var x = r.sledeci() * tezine.sum()
        for ((o, t) in dobri.zip(tezine)) { x -= t; if (x <= 0) return o.first to o.second }
        return najbolja.first to najbolja.second
    }

    /** Pred kraj poteza: vojska iz unutrašnjosti (bez tuđih suseda) ide na najugroženiju susednu granicu. */
    fun botUtvrdi(): Stanje {
        val tim = trenutni.tim
        val cilj = ciljBota(tim)
        var najbolje: Triple<String, String, Double>? = null
        for (id in oblastiIgraca(trenutni.id)) {
            if ((oblasti[id]?.vojske ?: 0) <= 1 || pretnja(id, tim, cilj) != 0.0) continue
            for (n in Mapa.susedi(id)) {
                if (oblasti[n]?.vlasnik != tim) continue
                val p = pretnja(n, tim, cilj)
                if (p > 0 && (najbolje == null || p > najbolje.third)) najbolje = Triple(id, n, p)
            }
        }
        val (odakle, kuda) = najbolje ?: return this
        return utvrdi(odakle, kuda, (oblasti[odakle]?.vojske ?: 1) - 1)
    }
}
