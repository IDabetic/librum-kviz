package club.librum.kviz.servisi

import club.librum.kviz.BuildConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

/** Poruka greške spremna za prikaz korisniku. */
class Greska(poruka: String) : Exception(poruka)

@Serializable
data class Korisnik(val id: String, val email: String? = null)

@Serializable
data class Token(val access_token: String, val refresh_token: String, val expires_at: Long? = null, val user: Korisnik)

/** Tanak klijent za Supabase REST (GoTrue + PostgREST), bez spoljnih biblioteka. */
object Supabase {
    val json = Json { ignoreUnknownKeys = true; explicitNulls = false }
    private val osnova = BuildConfig.SUPABASE_URL.trimEnd('/')
    private val kljuc = BuildConfig.SUPABASE_ANON_KEY

    suspend fun zahtev(
        putanja: String,
        metod: String = "GET",
        telo: String? = null,
        token: String? = null,
        upit: List<Pair<String, String>> = emptyList(),
    ): String = withContext(Dispatchers.IO) {
        val q = if (upit.isEmpty()) "" else "?" + upit.joinToString("&") { (k, v) -> "$k=${URLEncoder.encode(v, "UTF-8")}" }
        val veza = URL("$osnova/$putanja$q").openConnection() as HttpURLConnection
        try {
            veza.requestMethod = metod
            veza.connectTimeout = 15_000
            veza.readTimeout = 15_000
            veza.setRequestProperty("apikey", kljuc)
            veza.setRequestProperty("Authorization", "Bearer ${token ?: kljuc}")
            veza.setRequestProperty("Content-Type", "application/json")
            if (telo != null) {
                veza.doOutput = true
                veza.outputStream.use { it.write(telo.toByteArray()) }
            }
            val kod = veza.responseCode
            val odgovor = (if (kod in 200..299) veza.inputStream else veza.errorStream)?.bufferedReader()?.use { it.readText() }.orEmpty()
            if (kod !in 200..299) throw Greska(prevedi(odgovor, kod))
            odgovor
        } catch (e: IOException) {
            throw Greska("Nema veze sa serverom. Proveri internet i pokušaj ponovo.")
        } finally {
            veza.disconnect()
        }
    }

    /** Poruke GoTrue/PostgREST na srpskom; nepoznate se prikazuju kako stignu. */
    private fun prevedi(telo: String, kod: Int): String {
        val obj = runCatching { json.parseToJsonElement(telo).jsonObject }.getOrNull()
        val poruka = listOf("error_description", "msg", "message").firstNotNullOfOrNull { obj?.get(it)?.jsonPrimitive?.content }.orEmpty()
        return when (poruka) {
            "Invalid login credentials" -> "Pogrešan email ili lozinka."
            "User already registered" -> "Ovaj email je već registrovan."
            "Email not confirmed" -> "Potvrdi email preko linka koji smo ti poslali."
            else -> when {
                kod == 402 -> "Baza je trenutno nedostupna. Pokušaj kasnije."
                poruka.isEmpty() -> "Greška $kod. Pokušaj ponovo."
                else -> poruka
            }
        }
    }

    fun objekat(vararg par: Pair<String, Any?>): String = json.encodeToString(JsonElement.serializer(), uJson(mapOf(*par)))

    fun uJson(v: Any?): JsonElement = when (v) {
        null -> kotlinx.serialization.json.JsonNull
        is JsonElement -> v
        is String -> JsonPrimitive(v)
        is Number -> JsonPrimitive(v)
        is Boolean -> JsonPrimitive(v)
        is Map<*, *> -> JsonObject(v.entries.associate { (k, x) -> k.toString() to uJson(x) })
        else -> JsonPrimitive(v.toString())
    }

    suspend fun prijava(email: String, lozinka: String): Token = json.decodeFromString(
        zahtev("auth/v1/token", "POST", objekat("email" to email, "password" to lozinka), upit = listOf("grant_type" to "password")),
    )

    suspend fun osvezi(refresh: String): Token = json.decodeFromString(
        zahtev("auth/v1/token", "POST", objekat("refresh_token" to refresh), upit = listOf("grant_type" to "refresh_token")),
    )

    suspend fun registracija(email: String, lozinka: String, ime: String, prezime: String, nadimak: String) {
        zahtev("auth/v1/signup", "POST", objekat(
            "email" to email, "password" to lozinka,
            "data" to mapOf("first_name" to ime, "last_name" to prezime, "nickname" to nadimak),
        ))
    }

    suspend fun odjava(token: String) {
        runCatching { zahtev("auth/v1/logout", "POST", token = token) }
    }

    suspend fun rpc(ime: String, parametri: Map<String, Any?> = emptyMap(), token: String? = null): String =
        zahtev("rest/v1/rpc/$ime", "POST", json.encodeToString(JsonElement.serializer(), uJson(parametri)), token)

    suspend fun citaj(tabela: String, upit: List<Pair<String, String>>, token: String? = null): String =
        zahtev("rest/v1/$tabela", token = token, upit = upit)

    suspend fun upisi(tabela: String, red: Map<String, Any?>, token: String) {
        zahtev("rest/v1/$tabela", "POST", json.encodeToString(JsonElement.serializer(), uJson(red)), token)
    }
}
