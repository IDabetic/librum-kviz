package club.librum.kviz.igre

import android.content.Context
import club.librum.kviz.osvajanje.Slucajno
import club.librum.kviz.servisi.Fond
import club.librum.kviz.servisi.PaketPitanja
import club.librum.kviz.servisi.Pitanje
import club.librum.kviz.servisi.Rec
import club.librum.kviz.servisi.Sesija
import club.librum.kviz.servisi.Supabase
import club.librum.kviz.servisi.slikariKviz
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.JsonElement

/**
 * Takmičenje (vlasnik 03.11.2026), verni prevod iOS Takmicenje.swift: PRO, Book, Slikari, Brzi kviz i Vešanje za 2–8
 * igrača, svako za sebe ili timovi po dvoje, protiv računara, pravih igrača ili mešano. Svi igraju isti sadržaj (domaćin ga
 * šalje u sobu), a botovi se računaju iz semena sobe, pa su isti na iPhonu i Androidu. Server: scripts/2026-11-03_takmicenja.sql.
 */
enum class IgraTakmicenja(val kljuc: String, val naziv: String, val opis: String) {
    PRO("pro", "PRO kviz", "10 pitanja iz svega, brži odgovor nosi više"),
    BOOK("book", "Book kviz", "10 pitanja iz književnosti"),
    SLIKARI("slikari", "Slikari", "10 dela: ko je naslikao?"),
    BRZI("brzi", "Brzi kviz", "60 sekundi, tačno ili netačno"),
    VESANJE("vesanje", "Vešanje", "5 reči, ko pogodi više slova");

    /** Koliko stavki domaćin šalje u sobu: pitanja, tvrdnje (Brzi troši mnogo) ili reči. */
    val broj: Int get() = when (this) { BRZI -> 60; VESANJE -> 5; else -> Takmicenje.PITANJA }

    companion object { fun od(k: String) = entries.firstOrNull { it.kljuc == k } ?: PRO }
}

object Takmicenje {
    const val PITANJA = 10
    const val SEKUNDI_PITANJA = 20
    /** Pauza posle odgovora dok kartica pokazuje tačan; botovi je poštuju da bi tempo bio isti. */
    const val PAUZA_OTKRIVANJA = 3.0
    const val OSVEZAVANJE_MS = 1500L
    /** Samo DEBUG: igra protiv računara bez servera (vidi MainActivity). */
    var proba = false

    /** Tačan odgovor: 10 poena plus do 10 za brzinu (svake 2 sekunde manje = 1 poen); netačan 0. Primer: poeni(true, 4000) = 18. */
    fun poeni(tacno: Boolean, ms: Int): Int = if (!tacno) 0 else 10 + maxOf(0, (SEKUNDI_PITANJA * 1000 - ms) / 2000)

    @Serializable data class Mesto(
        val mesto: Int, val user_id: String? = null, val bot: String? = null, val pozvan: Boolean = false, val tim: Int = 0,
        val nadimak: String? = null, val avatar: String? = null, val poeni: Int = 0, val tacnih: Int = 0, val odigrano: Int = 0,
        val ms: Int = 0, val gotov: Boolean = false,
    ) { val prazno: Boolean get() = user_id == null && bot == null }

    @Serializable data class Soba(
        val id: String, val kod: String, val igra: String, val domacin: String, val velicina: Int, val nacin: String,
        val protivnici: String, val tezina: String, val seme: Long, val broj: Int, val status: String, val mesta: List<Mesto> = emptyList(),
    ) {
        val vrsta: IgraTakmicenja get() = IgraTakmicenja.od(igra)
        val timovi: Boolean get() = nacin == "timovi"
    }

    @Serializable data class Poziv(val kod: String, val igra: String, val velicina: Int, val nacin: String, val od: String, val avatar: String? = null) {
        val naziv: String get() = IgraTakmicenja.od(igra).naziv
    }

    /** Red tabele uživo: pravi igrač sa servera, bot izračunat iz semena (isto na svakom telefonu). */
    data class Rezultat(val mesto: Int, val ime: String, val avatar: String?, val tim: Int, val poeni: Int, val tacnih: Int,
                        val odigrano: Int, val gotov: Boolean, val bot: Boolean, val ja: Boolean)

    fun tabela(s: Soba, ja: String?, proteklo: Double): List<Rezultat> = s.mesta.filter { !it.prazno }.map { m ->
        if (m.bot != null) {
            val b = Bot.rezultat(s.vrsta, s.tezina, s.seme, m.mesto, s.broj, proteklo)
            Rezultat(m.mesto, m.bot, null, m.tim, b.poeni, b.tacnih, b.odigrano, b.gotov, true, false)
        } else Rezultat(m.mesto, m.nadimak ?: "Igrač", m.avatar, m.tim, m.poeni, m.tacnih, m.odigrano, m.gotov || s.status == "kraj", false, m.user_id == ja)
    }.sortedWith(compareByDescending<Rezultat> { it.poeni }.thenByDescending { it.tacnih }.thenBy { it.mesto })

    /** Zbir po timu, najbolji prvi. */
    fun timovi(r: List<Rezultat>): List<Triple<Int, Int, List<Rezultat>>> =
        r.groupBy { it.tim }.map { (t, c) -> Triple(t, c.sumOf { it.poeni }, c) }.sortedWith(compareByDescending<Triple<Int, Int, List<Rezultat>>> { it.second }.thenBy { it.first })

    fun imeTima(t: Int): String = "Tim ${'A' + t}"

    /** Seme za stavku i (Brzi: koja tvrdnja nudi tačan odgovor) — isto za sve u sobi, i na iOS-u. */
    fun slucajno(seme: Long, dodatak: Int): Slucajno = Slucajno(seme.toInt() xor (dodatak.toLong() * 0x9E3779B1L).toInt())

    /** Botovi: tempo i tačnost po težini, iz semena sobe i mesta; telefon ih računa iz proteklog vremena. */
    object Bot {
        data class Stanje(var poeni: Int = 0, var tacnih: Int = 0, var odigrano: Int = 0, var gotov: Boolean = false)

        fun tacnost(tezina: String) = if (tezina == "lako") 0.5 else if (tezina == "tesko") 0.84 else 0.68
        /** Sekunde po odgovoru: (najmanje, raspon). */
        fun tempo(tezina: String) = if (tezina == "lako") 8.0 to 9.0 else if (tezina == "tesko") 3.5 to 5.0 else 5.5 to 7.0

        private val izjava = BrziKviz.Izjava("", "a", true, "a")

        fun rezultat(igra: IgraTakmicenja, tezina: String, seme: Long, mesto: Int, broj: Int, proteklo: Double): Stanje {
            val r = slucajno(seme, 7919 * (mesto + 1))
            val s = Stanje()
            var vreme = 0.0
            val p = tacnost(tezina)
            when (igra) {
                IgraTakmicenja.BRZI -> {
                    val b = BrziKviz()
                    // Tvrdnja: botu treba 1,4–3,5 s (teško brže); pogodak po tačnosti, jer je tačno/netačno lakše od 4 ponude.
                    val brzina = if (tezina == "lako") 3.5 else if (tezina == "tesko") 1.4 else 2.2
                    while (true) {
                        vreme += brzina + r.sledeci() * 1.4
                        if (vreme > BrziKviz.SEKUNDI_RUNDE) { s.gotov = true; break }
                        if (vreme > proteklo) break
                        val pogodak = r.sledeci() < minOf(0.95, p + 0.1)
                        b.odgovor(izjava, pogodak, zavrsnica = vreme > BrziKviz.SEKUNDI_RUNDE - BrziKviz.SEKUNDI_ZAVRSNICE)
                        s.odigrano++
                    }
                    s.poeni = b.poeni; s.tacnih = b.tacnih
                }
                IgraTakmicenja.VESANJE -> {
                    repeat(broj) {
                        vreme += 14 + r.sledeci() * (if (tezina == "tesko") 14 else 26)
                        val pogodio = r.sledeci() < p
                        val poena = if (pogodio) 30 + (r.sledeci() * 45).toInt() else (r.sledeci() * 12).toInt()
                        if (vreme > proteklo) return s
                        s.odigrano++; s.poeni += poena; if (pogodio) s.tacnih++
                    }
                    s.gotov = true
                }
                else -> {
                    val (najmanje, raspon) = tempo(tezina)
                    repeat(broj) {
                        val sekundi = minOf(SEKUNDI_PITANJA.toDouble(), najmanje + r.sledeci() * raspon)
                        val tacno = r.sledeci() < p
                        vreme += sekundi
                        if (vreme > proteklo) return s
                        vreme += PAUZA_OTKRIVANJA
                        s.odigrano++; s.poeni += poeni(tacno, (sekundi * 1000).toInt()); if (tacno) s.tacnih++
                    }
                    s.gotov = true
                }
            }
            return s
        }
    }

    // ── Server ──

    private suspend fun token(sesija: Sesija): String = sesija.vazeciToken() ?: throw IllegalStateException("Prijavi se da bi igrao sa drugima.")
    private fun soba(t: String) = Supabase.json.decodeFromString(Soba.serializer(), t)

    suspend fun napravi(sesija: Sesija, igra: IgraTakmicenja, velicina: Int, timovi: Boolean, protivnici: String, tezina: String, sadrzaj: JsonElement, pozovi: List<String>): Soba =
        soba(Supabase.rpc("takmicenje_napravi", mapOf("p_igra" to igra.kljuc, "p_velicina" to velicina, "p_nacin" to if (timovi) "timovi" else "svako",
            "p_protivnici" to protivnici, "p_tezina" to tezina, "p_sadrzaj" to sadrzaj, "p_pozovi" to pozovi), token(sesija)))

    suspend fun udji(sesija: Sesija, kod: String) = soba(Supabase.rpc("takmicenje_udji", mapOf("p_kod" to kod), token(sesija)))
    suspend fun stanje(sesija: Sesija, id: String) = soba(Supabase.rpc("takmicenje_stanje", mapOf("p_id" to id), token(sesija)))
    suspend fun pokreni(sesija: Sesija, id: String) = soba(Supabase.rpc("takmicenje_pokreni", mapOf("p_id" to id), token(sesija)))

    suspend fun rezultat(sesija: Sesija, id: String, poeni: Int, tacnih: Int, odigrano: Int, ms: Int, gotov: Boolean) =
        soba(Supabase.rpc("takmicenje_rezultat", mapOf("p_id" to id, "p_poeni" to poeni, "p_tacnih" to tacnih, "p_odigrano" to odigrano, "p_ms" to ms, "p_gotov" to gotov), token(sesija)))

    suspend fun izadji(sesija: Sesija, id: String) { runCatching { Supabase.rpc("takmicenje_izadji", mapOf("p_id" to id), token(sesija)) } }
    suspend fun odbij(sesija: Sesija, kod: String) { runCatching { Supabase.rpc("takmicenje_odbij", mapOf("p_kod" to kod), token(sesija)) } }
    suspend fun pozivi(sesija: Sesija): List<Poziv> = runCatching {
        Supabase.json.decodeFromString(ListSerializer(Poziv.serializer()), Supabase.rpc("takmicenje_pozivi", emptyMap(), token(sesija)))
    }.getOrDefault(emptyList())

    suspend fun pitanja(sesija: Sesija, id: String): List<Pitanje> =
        Supabase.json.decodeFromString(ListSerializer(Pitanje.serializer()), Supabase.rpc("takmicenje_sadrzaj", mapOf("p_id" to id), token(sesija)))
    suspend fun reci(sesija: Sesija, id: String): List<Rec> =
        Supabase.json.decodeFromString(ListSerializer(Rec.serializer()), Supabase.rpc("takmicenje_sadrzaj", mapOf("p_id" to id), token(sesija)))

    /** Domaćinov telefon bira sadržaj istim putem kao igra za jednog (neviđena pitanja, Slikari iz paketa). */
    suspend fun izaberi(ctx: Context, igra: IgraTakmicenja, tezina: String): JsonElement {
        val paket = PaketPitanja(ctx)
        return when (igra) {
            IgraTakmicenja.PRO, IgraTakmicenja.BRZI -> Supabase.json.encodeToJsonElement(ListSerializer(Pitanje.serializer()), paket.ucitaj().take(igra.broj))
            IgraTakmicenja.BOOK -> Supabase.json.encodeToJsonElement(ListSerializer(Pitanje.serializer()), paket.ucitaj(Fond.BOOK).take(igra.broj))
            IgraTakmicenja.SLIKARI -> Supabase.json.encodeToJsonElement(ListSerializer(Pitanje.serializer()), slikariKviz(ctx, igra.broj, tezina == "tesko"))
            IgraTakmicenja.VESANJE -> Supabase.json.encodeToJsonElement(ListSerializer(Rec.serializer()), paket.reci().take(igra.broj))
        }
    }

    /** Serverske poruke na srpskom za ekran sobe. */
    fun poruka(e: Throwable): String {
        val p = e.message.orEmpty()
        return when {
            "ne postoji" in p -> "Soba ne postoji ili je igra završena. Proveri kod."
            "puna" in p -> "Soba je puna."
            "već počela" in p -> "Igra je već počela bez tebe."
            "niko nije ušao" in p -> "Još niko nije ušao. Sačekaj prijatelje ili pozovi računar."
            else -> p.ifEmpty { "Server se ne javlja. Probaj ponovo." }
        }
    }
}
