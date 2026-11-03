package club.librum.kviz.osvajanje

import club.librum.kviz.servisi.Sesija
import club.librum.kviz.servisi.Supabase
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement

/**
 * Partija Osvajanja preko servera (scripts/2026-11-03_osvajanje-potezi.sql), isto kao iOS VezaOsvajanja:
 * domaćin (mesto 0) šalje početno stanje i vodi botove; igrač na potezu šalje stanje posle bitaka i na kraju poteza;
 * bitka protiv pravog igrača je par „bitka” (napadač i njegov skor) → „odbrana” (skor branioca).
 */
class VezaOsvajanja(private val sesija: Sesija, val soba: String, val ja: String, val domacin: Boolean) {
    @Serializable data class Akcija(
        val v: String,
        val stanje: Stanje? = null,
        val odakle: String? = null,
        val kuda: String? = null,
        val skor: Skor? = null,
        /** Redni broj „bitke” na koju se „odbrana” odnosi. */
        val bitka: Int? = null,
    )
    @Serializable data class Red(val rb: Int, val ko: String, val akcija: Akcija)

    companion object {
        /** Id igrača u stanju: „u:” + id naloga, isti na svakom telefonu. */
        fun idIgraca(korisnik: String) = "u:$korisnik"
        // iOS dekoder traži svako polje stanja, pa se šalju i podrazumevane vrednosti.
        private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true; explicitNulls = false }
    }

    val mojId get() = idIgraca(ja)
    private var poslednji = 0

    suspend fun posalji(a: Akcija): Int? = runCatching {
        val t = sesija.vazeciToken() ?: return null
        val akcija = json.encodeToJsonElement(Akcija.serializer(), a)
        Supabase.rpc("osvajanje_upisi", mapOf<String, Any?>("p_soba" to soba, "p_akcija" to akcija as JsonElement), t).trim().toIntOrNull()
    }.getOrNull()

    /** Novi potezi drugih igrača (svoje već znam). */
    suspend fun novi(): List<Red> = runCatching {
        val t = sesija.vazeciToken() ?: return emptyList()
        val redovi = json.decodeFromString<List<Red>>(Supabase.rpc("osvajanje_potezi_od", mapOf("p_soba" to soba, "p_od" to poslednji), t))
        redovi.maxOfOrNull { it.rb }?.let { poslednji = it }
        redovi.filter { it.ko != ja }
    }.getOrDefault(emptyList())
}
