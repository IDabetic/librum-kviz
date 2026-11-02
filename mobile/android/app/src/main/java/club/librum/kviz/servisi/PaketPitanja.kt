package club.librum.kviz.servisi

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonPrimitive
import java.io.File

@Serializable
data class Pitanje(val id: String, val question_text: String, val options: List<String>, val correct_answer: Int)

/** Pitanje spremno za prikaz: ponude promešane, zna se koja je tačna. */
data class Prikaz(val tekst: String, val opcije: List<String>, val tacan: Int) {
    companion object {
        fun od(p: Pitanje): Prikaz {
            val red = (0..3).shuffled()
            return Prikaz(p.question_text, red.map { p.options[it] }, red.indexOf(p.correct_answer))
        }
    }
}

/**
 * Paket pitanja iz RPC `osvajanje_pitanja`, keširan u fajlu. Bez mreže igra ide
 * iz poslednjeg paketa; jedna partija troši jedan mali zahtev.
 */
class PaketPitanja(private val context: Context) {
    private val fajl = File(context.filesDir, "paket-pitanja.json")

    suspend fun ucitaj(): List<Pitanje> = withContext(Dispatchers.IO) {
        val svez = runCatching {
            Supabase.json.decodeFromString<List<Pitanje>>(Supabase.rpc("osvajanje_pitanja", mapOf("p_broj" to 60)))
                .filter { it.options.size == 4 && it.correct_answer in 0..3 }
        }.getOrNull()
        if (!svez.isNullOrEmpty()) {
            fajl.writeText(Supabase.json.encodeToString(kotlinx.serialization.builtins.ListSerializer(Pitanje.serializer()), svez))
            return@withContext svez.shuffled()
        }
        val kes = runCatching { Supabase.json.decodeFromString<List<Pitanje>>(fajl.readText()) }.getOrNull()
        if (!kes.isNullOrEmpty()) return@withContext kes.shuffled()
        // Prvo pokretanje bez mreže ili baza ne odgovara: rezervni paket ugrađen u aplikaciju (isti kao veb).
        val rezerva = runCatching {
            Supabase.json.parseToJsonElement(context.assets.open("rezervna-pitanja.json").bufferedReader().use { it.readText() }).jsonArray
                .mapIndexed { i, r ->
                    val red = r.jsonArray
                    Pitanje("r$i", red[0].jsonPrimitive.content, red[1].jsonArray.map { it.jsonPrimitive.content }, red[2].jsonPrimitive.int)
                }
        }.getOrNull()
        if (!rezerva.isNullOrEmpty()) return@withContext rezerva.shuffled()
        throw Greska("Pitanja nisu stigla. Proveri internet i pokušaj ponovo.")
    }
}

/** Špil koji se vrti u krug kad se pitanja potroše. */
class Spil(private val pitanja: List<Pitanje>) {
    private var indeks = 0
    fun sledece(): Prikaz = Prikaz.od(pitanja[indeks++ % pitanja.size])
}
