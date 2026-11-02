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
data class Pitanje(val id: String, val question_text: String, val options: List<String>, val correct_answer: Int, val genre: String? = null)

@Serializable
data class Rec(val id: String, val word: String, val hint: String? = null, val category: String? = null)

/** Fond pitanja po igri (RPC aplikacija_pitanja): opšti za PRO, Brzi, Duel i Osvajanje, Book za književnost. */
enum class Fond(val kljuc: String) { OPSTE("opste"), BOOK("book") }

/** Pitanje spremno za prikaz: ponude promešane, zna se koja je tačna. */
data class Prikaz(val tekst: String, val opcije: List<String>, val tacan: Int, val zanr: String? = null) {
    companion object {
        fun od(p: Pitanje): Prikaz {
            val red = (0..3).shuffled()
            return Prikaz(p.question_text, red.map { p.options[it] }, red.indexOf(p.correct_answer), p.genre?.takeIf { it != "Razno" })
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
            Supabase.json.decodeFromString<List<Pitanje>>(Supabase.rpc("aplikacija_pitanja", mapOf("p_igra" to fond.kljuc, "p_broj" to 60)))
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
class Spil(private val pitanja: List<Pitanje>) {
    private var indeks = 0
    fun sledece(): Prikaz = Prikaz.od(pitanja[indeks++ % pitanja.size])
}
