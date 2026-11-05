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
        vratiRed: Boolean = false,
        dodatnaZaglavlja: Map<String, String> = emptyMap(),
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
            if (vratiRed) veza.setRequestProperty("Prefer", "return=representation")
            for ((k, v) in dodatnaZaglavlja) veza.setRequestProperty(k, v)
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
        val oznaka = listOf("error_code", "code").firstNotNullOfOrNull { obj?.get(it)?.jsonPrimitive?.content }.orEmpty()
        if (kod == 429 || "rate_limit" in oznaka || "only request this after" in poruka) return "Previše pokušaja. Sačekaj malo pa probaj ponovo."
        if (oznaka == "otp_expired" || "expired" in poruka) return "Kod je istekao ili nije tačan. Zatraži novi."
        if (oznaka == "same_password") return "Nova lozinka mora da se razlikuje od stare."
        return when (poruka) {
            "Invalid login credentials" -> "Pogrešan email ili lozinka."
            "User already registered" -> "Ovaj email je već registrovan."
            "Email not confirmed" -> "Potvrdi email kodom (ili linkom) koji smo ti poslali."
            else -> when {
                kod == 402 -> "Baza je trenutno nedostupna. Pokušaj kasnije."
                // Greške baze (SQLSTATE, 5 znakova) se ne prikazuju; samo naše poruke iz funkcija (isto kao iOS, 05.11).
                oznaka.length == 5 && oznaka.all { it.isDigit() || it.isUpperCase() } && oznaka !in setOf("22023", "P0001", "P0002", "42501") ->
                    "Nešto nije u redu na serveru. Pokušaj ponovo za koji trenutak."
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
        is List<*> -> kotlinx.serialization.json.JsonArray(v.map { uJson(it) })
        else -> JsonPrimitive(v.toString())
    }

    suspend fun prijava(email: String, lozinka: String): Token = json.decodeFromString(
        zahtev("auth/v1/token", "POST", objekat("email" to email, "password" to lozinka), upit = listOf("grant_type" to "password")),
    )

    /** Prijava tokenom sa telefona (Google): Supabase proverava potpis i nonce. */
    suspend fun prijavaTokenom(provajder: String, idToken: String, nonce: String?): Token = json.decodeFromString(
        zahtev("auth/v1/token", "POST", objekat("provider" to provajder, "id_token" to idToken, "nonce" to nonce), upit = listOf("grant_type" to "id_token")),
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

    /** Kod iz mejla (registracija „signup” ili zaboravljena lozinka „recovery”); vraća sesiju. */
    suspend fun potvrdiKod(email: String, kod: String, vrsta: String): Token =
        json.decodeFromString(zahtev("auth/v1/verify", "POST", objekat("type" to vrsta, "email" to email, "token" to kod)))

    suspend fun posaljiKodPonovo(email: String) {
        zahtev("auth/v1/resend", "POST", objekat("type" to "signup", "email" to email))
    }

    suspend fun zaboravljenaLozinka(email: String) {
        zahtev("auth/v1/recover", "POST", objekat("email" to email))
    }

    suspend fun novaLozinka(lozinka: String, token: String) {
        zahtev("auth/v1/user", "PUT", objekat("password" to lozinka), token)
    }

    suspend fun odjava(token: String) {
        runCatching { zahtev("auth/v1/logout", "POST", token = token) }
    }

    /** Token prijavljenog igrača za pakete pitanja (server tada 7 dana ne šalje ista pitanja); postavlja ga Sesija. */
    var tokenIgraca: (suspend () -> String?)? = null

    suspend fun rpc(ime: String, parametri: Map<String, Any?> = emptyMap(), token: String? = null): String =
        zahtev("rest/v1/rpc/$ime", "POST", json.encodeToString(JsonElement.serializer(), uJson(parametri)), token)

    suspend fun citaj(tabela: String, upit: List<Pair<String, String>>, token: String? = null): String =
        zahtev("rest/v1/$tabela", token = token, upit = upit)

    /** PATCH sa filterom (npr. "room_code" to "eq.ABC"); vraća izmenjene redove kao JSON. */
    suspend fun azuriraj(tabela: String, filter: List<Pair<String, String>>, polja: Map<String, Any?>, token: String): String =
        zahtev("rest/v1/$tabela", "PATCH", json.encodeToString(JsonElement.serializer(), uJson(polja)), token, filter, vratiRed = true)

    suspend fun upisiVrati(tabela: String, red: Map<String, Any?>, token: String): String =
        zahtev("rest/v1/$tabela", "POST", json.encodeToString(JsonElement.serializer(), uJson(red)), token, vratiRed = true)

    suspend fun upisi(tabela: String, red: Map<String, Any?>, token: String) {
        zahtev("rest/v1/$tabela", "POST", json.encodeToString(JsonElement.serializer(), uJson(red)), token)
    }
}
