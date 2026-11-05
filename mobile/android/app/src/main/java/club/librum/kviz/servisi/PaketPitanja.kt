package club.librum.kviz.servisi

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.builtins.ListSerializer
import java.io.File

@Serializable
data class Pitanje(val id: String, val question_text: String, val options: List<String>, val correct_answer: Int, val genre: String? = null,
                   val slika: String? = null, val opis: String? = null)

@Serializable
data class Rec(val id: String, val word: String, val hint: String? = null, val category: String? = null)

/** Fond pitanja po igri (RPC aplikacija_pitanja): opšti za PRO, Brzi, Duel i Osvajanje, Book za književnost. */
enum class Fond(val kljuc: String) { OPSTE("opste"), BOOK("book") }

/** Pitanje spremno za prikaz: ponude promešane, zna se koja je tačna. */
data class Prikaz(val tekst: String, val opcije: List<String>, val tacan: Int, val zanr: String? = null, val slika: String? = null, val opis: String? = null, val id: String? = null) {
    companion object {
        fun od(p: Pitanje): Prikaz {
            val red = (0..3).shuffled()
            return Prikaz(p.question_text, red.map { p.options[it] }, red.indexOf(p.correct_answer), p.genre?.takeIf { it != "Razno" }, p.slika, p.opis,
                p.id.takeIf { !it.startsWith("s-") && !it.startsWith("r") })
        }
    }
}

/**
 * Paketi pitanja i reči, keširani u fajlu. Redosled: svež paket sa servera, pa
 * poslednji keš, pa rezerva ugrađena u aplikaciju (isti fajlovi kao veb).
 */
class PaketPitanja(private val context: Context) {
    private fun fajl(ime: String) = File(context.filesDir, ime)

    suspend fun ucitaj(fond: Fond = Fond.OPSTE): List<Pitanje> = withContext(Dispatchers.IO) {
        val kes = fajl(if (fond == Fond.OPSTE) "paket-pitanja.json" else "paket-${fond.kljuc}.json")
        val svez = runCatching {
            Supabase.json.decodeFromString<List<Pitanje>>(Supabase.rpc("aplikacija_pitanja", mapOf("p_igra" to fond.kljuc, "p_broj" to 60), runCatching { Supabase.tokenIgraca?.invoke() }.getOrNull()))
                .filter { it.options.size == 4 && it.correct_answer in 0..3 }
        }.getOrNull()
        if (!svez.isNullOrEmpty()) {
            kes.writeText(Supabase.json.encodeToString(ListSerializer(Pitanje.serializer()), svez))
            return@withContext svez.shuffled()
        }
        runCatching { Supabase.json.decodeFromString<List<Pitanje>>(kes.readText()) }.getOrNull()
            ?.takeIf { it.isNotEmpty() }?.let { return@withContext it.shuffled() }
        val rezerva = runCatching {
            val ime = if (fond == Fond.OPSTE) "rezervna-pitanja.json" else "rezerva-book.json"
            Supabase.json.parseToJsonElement(context.assets.open(ime).bufferedReader().use { it.readText() }).jsonArray
                .mapIndexed { i, r ->
                    val red = r.jsonArray
                    Pitanje("r$i", red[0].jsonPrimitive.content, red[1].jsonArray.map { it.jsonPrimitive.content }, red[2].jsonPrimitive.int,
                        red.getOrNull(3)?.jsonPrimitive?.content)
                }
        }.getOrNull()
        if (!rezerva.isNullOrEmpty()) return@withContext rezerva.shuffled()
        throw Greska("Pitanja nisu stigla. Proveri internet i pokušaj ponovo.")
    }

    suspend fun reci(): List<Rec> = withContext(Dispatchers.IO) {
        val kes = fajl("paket-reci.json")
        runCatching { Supabase.json.decodeFromString<List<Rec>>(Supabase.rpc("aplikacija_reci", mapOf("p_broj" to 40))) }.getOrNull()
            ?.takeIf { it.isNotEmpty() }?.let {
                kes.writeText(Supabase.json.encodeToString(ListSerializer(Rec.serializer()), it))
                return@withContext it.shuffled()
            }
        runCatching { Supabase.json.decodeFromString<List<Rec>>(kes.readText()) }.getOrNull()
            ?.takeIf { it.isNotEmpty() }?.let { return@withContext it.shuffled() }
        runCatching {
            Supabase.json.parseToJsonElement(context.assets.open("rezerva-reci.json").bufferedReader().use { it.readText() }).jsonArray
                .mapIndexed { i, r -> val red = r.jsonArray; Rec("r$i", red[0].jsonPrimitive.content, red[1].jsonPrimitive.content, red[2].jsonPrimitive.content) }
        }.getOrNull()?.takeIf { it.isNotEmpty() }?.let { return@withContext it.shuffled() }
        throw Greska("Reči nisu stigle. Proveri internet i pokušaj ponovo.")
    }
}

/** Špil koji se vrti u krug kad se pitanja potroše. */
/** Kviz po temi (RPC aplikacija_kviz): 10 pitanja iz fonda, žanra ili samo teških; bez mreže iz keša/rezerve istog fonda. */
suspend fun PaketPitanja.temaKviz(fond: Fond, zanr: String? = null, tesko: Boolean = false, broj: Int = 10): List<Pitanje> {
    val parametri = buildMap<String, Any?> { put("p_fond", fond.kljuc); put("p_broj", broj); zanr?.let { put("p_zanr", it) }; if (tesko) put("p_tezina", "tesko") }
    runCatching { Supabase.json.decodeFromString<List<Pitanje>>(Supabase.rpc("aplikacija_kviz", parametri, runCatching { Supabase.tokenIgraca?.invoke() }.getOrNull())) }.getOrNull()
        ?.filter { it.options.size == 4 && it.correct_answer in 0..3 }?.takeIf { it.size >= minOf(broj, 5) }?.let { return it }
    val rezerva = ucitaj(fond).filter { zanr == null || it.genre == zanr }
    if (rezerva.isEmpty()) error("Za ovu temu nema sačuvanih pitanja. Poveži se na internet i pokušaj ponovo.")
    return rezerva.take(broj)
}

@kotlinx.serialization.Serializable
private data class Delo(val id: String, val naziv: String, val slika: String, val ponude: List<String>, val godina: String, val pravac: String, val muzej: String, val tezina: String,
                        val pitanje: String = "")

/** Slikari iz paketa u aplikaciji (assets slikari.json, 1.167 dela): pola lakših pola ostalih, ili samo teška. */
fun slikariKviz(context: Context, broj: Int = 10, tesko: Boolean = false): List<Pitanje> {
    val dela = Supabase.json.decodeFromString<List<Delo>>(context.assets.open("slikari.json").bufferedReader().use { it.readText() })
        .filter { it.slika.isNotEmpty() } // pitanje bez slike ne ide u Slikare (vlasnik 03.11)
    val izbor = if (tesko) dela.filter { it.tezina == "teško" }.shuffled().take(broj) else {
        val lakse = dela.filter { it.tezina != "teško" }.shuffled().take(broj / 2)
        (lakse + dela.filter { d -> lakse.none { it.id == d.id } }.shuffled().take(broj - lakse.size)).shuffled()
    }
    return izbor.map { d ->
        // Delo bez slike je tekstualno pitanje: godina pomaže da naziv ne bude jedini trag.
        val imaSliku = d.slika.isNotEmpty()
        val godina = if (d.godina.isEmpty()) "" else " (${d.godina})"
        // Naziv koji odaje autora („Rubens i Izabela Brant…”) ne ide u pitanje (alati/slikari-iz-baze.py).
        val tekst = d.pitanje.ifEmpty { if (imaSliku) "Ko je naslikao delo „${d.naziv}”?" else "Ko je naslikao delo „${d.naziv}”$godina?" }
        Pitanje(d.id, tekst, d.ponude, 0, d.pravac,
            d.slika.ifEmpty { null }, (listOf(d.naziv, d.godina, d.muzej) + if (imaSliku) listOf("Slika: Wikimedia Commons") else emptyList()).filter { it.isNotEmpty() }.joinToString(" · "))
    }
}

/** Dnevni izazov (RPC dnevni_izazov): isti 10 pitanja za sve tog dana; bez mreže nema izazova, jer bi bio drugačiji od ostalih. */
suspend fun dnevniIzazov(): List<Pitanje> {
    val p = Supabase.json.decodeFromString<List<Pitanje>>(Supabase.rpc("dnevni_izazov"))
    if (p.size < 5) error("Dnevni izazov nije stigao. Proveri internet.")
    return p
}

/** Špil koji se vrti u krug kad se pitanja potroše (isto kao iOS Spil). */
class Spil(pocetna: List<Pitanje>) {
    private val pitanja = pocetna.toMutableList()
    private var indeks = 0
    /** Svi ikad dodati (i oni izbačeni po temi), da dopuna ne vrati već viđeno pitanje. */
    private val poznata = pocetna.map { it.id }.toMutableSet()
    val prazan: Boolean get() = pitanja.isEmpty()
    /** Koliko još neiskorišćenih pitanja ima pre nego što špil krene ispočetka. */
    val ostalo: Int get() = maxOf(0, pitanja.size - indeks)

    /** Dopuna novim paketom (duga partija troši stotine pitanja); vraća koliko je novih stiglo. */
    fun dodaj(nova: List<Pitanje>): Int {
        val sveza = nova.filter { poznata.add(it.id) }
        pitanja += sveza
        return sveza.size
    }

    fun sledece(): Prikaz = Prikaz.od(pitanja[indeks++ % pitanja.size])

    /** Teme (žanrovi) koje u ostatku špila imaju bar `najmanje` pitanja, najbrojnije prve. */
    fun teme(najmanje: Int): List<String> {
        val ostatak = if (pitanja.size > indeks) pitanja.subList(indeks, pitanja.size) else pitanja
        return ostatak.mapNotNull { it.genre?.takeIf { g -> g != "Razno" } }.groupingBy { it }.eachCount()
            .filter { it.value >= najmanje }.entries.sortedWith(compareByDescending<Map.Entry<String, Int>> { it.value }.thenByDescending { it.key }).map { it.key }
    }

    /** Sledeće pitanje iz teme (izbačeno iz reda, da se ne ponovi); null kad ga nema. */
    fun sledece(tema: String): Prikaz? {
        val i = (minOf(indeks, pitanja.size) until pitanja.size).firstOrNull { pitanja[it].genre == tema } ?: return null
        return Prikaz.od(pitanja.removeAt(i))
    }
}

/** Osvajanje: neviđena pitanja o jednom kontinentu (oznaka kontinent:<ime>); bez mreže prazno. */
suspend fun PaketPitanja.kontinent(ime: String, broj: Int = 20): List<Pitanje> = withContext(Dispatchers.IO) {
    runCatching {
        Supabase.json.decodeFromString<List<Pitanje>>(Supabase.rpc("aplikacija_pitanja_kontinent", mapOf("p_kontinent" to ime, "p_broj" to broj),
            runCatching { Supabase.tokenIgraca?.invoke() }.getOrNull()))
            .filter { it.options.size == 4 && it.correct_answer in 0..3 }.shuffled()
    }.getOrDefault(emptyList())
}
