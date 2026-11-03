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
private data class Delo(val id: String, val naziv: String, val slika: String, val ponude: List<String>, val godina: String, val pravac: String, val muzej: String, val tezina: String)

/** Slikari iz paketa u aplikaciji (assets slikari.json, 1.439 dela): pola lakših pola ostalih, ili samo teška. */
fun slikariKviz(context: Context, broj: Int = 10, tesko: Boolean = false): List<Pitanje> {
    val dela = Supabase.json.decodeFromString<List<Delo>>(context.assets.open("slikari.json").bufferedReader().use { it.readText() })
    val izbor = if (tesko) dela.filter { it.tezina == "teško" }.shuffled().take(broj) else {
        val lakse = dela.filter { it.tezina != "teško" }.shuffled().take(broj / 2)
        (lakse + dela.filter { d -> lakse.none { it.id == d.id } }.shuffled().take(broj - lakse.size)).shuffled()
    }
    return izbor.map { d ->
        // Delo bez slike je tekstualno pitanje: godina pomaže da naziv ne bude jedini trag.
        val imaSliku = d.slika.isNotEmpty()
        val godina = if (d.godina.isEmpty()) "" else " (${d.godina})"
        Pitanje(d.id, if (imaSliku) "Ko je naslikao delo „${d.naziv}”?" else "Ko je naslikao delo „${d.naziv}”$godina?", d.ponude, 0, d.pravac,
            d.slika.ifEmpty { null }, (listOf(d.naziv, d.godina, d.muzej) + if (imaSliku) listOf("Slika: Wikimedia Commons") else emptyList()).filter { it.isNotEmpty() }.joinToString(" · "))
    }
}

/** Dnevni izazov (RPC dnevni_izazov): isti 10 pitanja za sve tog dana; bez mreže nema izazova, jer bi bio drugačiji od ostalih. */
suspend fun dnevniIzazov(): List<Pitanje> {
    val p = Supabase.json.decodeFromString<List<Pitanje>>(Supabase.rpc("dnevni_izazov"))
    if (p.size < 5) error("Dnevni izazov nije stigao. Proveri internet.")
    return p
}

class Spil(private val pitanja: List<Pitanje>) {
    private var indeks = 0
    fun sledece(): Prikaz = Prikaz.od(pitanja[indeks++ % pitanja.size])
}
