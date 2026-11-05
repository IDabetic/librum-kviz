package club.librum.kviz.karijera

import club.librum.kviz.servisi.Greska
import club.librum.kviz.servisi.Prikaz
import club.librum.kviz.servisi.Supabase
import kotlinx.serialization.Serializable
import java.text.NumberFormat
import java.time.OffsetDateTime
import java.util.Locale

/**
 * Podaci Karijere sa servera (prenos iOS Karijera/KarijeraModel.swift, 05.11.2026). Sva ekonomija se računa na serveru;
 * aplikacija prikazuje i šalje odgovore. Imena polja prate JSON servera.
 */
object Karijera {
    /** Najviše rundi probnog rada dnevno (server `karijera_zavrsi_rundu`, od 05.11 umesto 4). */
    const val PROBNI_DNEVNO = 10
    @Serializable data class Pozicija(val id: String, val naziv: String, val opis: String, val oblast: String, val ikonica: String,
                                      val naziv_z: String? = null, val teme: List<String> = emptyList()) {
        fun naziv(pol: String?) = if (pol == "z") naziv_z ?: naziv else naziv
    }
    @Serializable data class Talenat(val id: String, val naziv: String, val opis: String, val ikonica: String)
    @Serializable data class ZamenaTalenta(val dostupno: Int, val do_sledece: Int, val tacnih: Int, val korak: Int)

    @Serializable data class Firma(
        val id: String, val ime: String, val korporacija: Boolean, val npc: Boolean = false, val vlasnik: String? = null,
        val vlasnik_ime: String = "", val pozicija: String = "", val nivo: Int = 1, val stil: Int = 1, val udeo: String = "posten",
        val kljucne: List<String> = emptyList(), val rekord: Int = 0, val rekord_ime: String? = null, val rekord_igrac: String? = null,
        val zaposlenih: Int = 0, val botova: Int = 0, val zastita_do: String? = null,
        val sef_tacno: Int? = null, val sef_netacno: Int? = null, val sef_ometanja: Int? = null, val struka_udeo: Int? = null,
        val sef_smeh: Boolean? = null, val teza: Boolean? = null, val sef_lik: String? = null,
        val slobodni: List<Int>? = null, val slobodan_danas: Boolean? = null, val stres: Double? = null,
        val fokus: List<String>? = null, val fokus_udeo: List<Int>? = null,
    ) {
        val sefNivo get() = Sef.Nivo(sef_tacno ?: 2, sef_netacno ?: 2, sef_ometanja ?: 2, sef_smeh ?: true, sef_lik ?: if (korporacija) "korporacija" else "m_srednji")
        val slika get() = slikaZgrade(korporacija, nivo, stil)
        val udeoNaziv get() = udeoNaziv(udeo)
        val zasticena get() = zastita_do?.let { datum(it) }?.isAfter(OffsetDateTime.now()) == true
    }

    @Serializable data class Bot(val id: String, val ime: String, val tema: String, val nivo: Int, val pomoci_ostalo: Int) {
        val slika get() = slikaBota(ime)
    }
    @Serializable data class Zaposleni(val id: String, val ime: String, val titula: Int)
    @Serializable data class Tema(val tema: String, val pitanja: Int)

    @Serializable data class Izazov(
        val id: String, val firma: Firma, val vlasnik: String? = null, val vlasnik_ime: String = "", val izazivac: String, val izazivac_ime: String = "",
        val pokusaj: Int = 1, val revans: Boolean = false, val tema_izazivac: String, val tema1: String? = null, val tema3: String? = null,
        val botova: Int = 0, val stanje: String, val rok: String, val ja_odigrao: Boolean? = null, val vlasnik_tacnih: Int? = null,
        val izazivac_tacnih: Int? = null, val pobednik: String? = null, val ishod: String? = null,
    )

    @Serializable data class FirmaDetalj(
        val id: String, val ime: String, val korporacija: Boolean, val npc: Boolean = false, val vlasnik: String? = null,
        val vlasnik_ime: String = "", val pozicija: String = "", val nivo: Int = 1, val stil: Int = 1, val udeo: String = "posten",
        val kljucne: List<String> = emptyList(), val rekord: Int = 0, val rekord_ime: String? = null, val rekord_igrac: String? = null,
        val zaposlenih: Int = 0, val botova: Int = 0, val zastita_do: String? = null, val zastita_izabrana: Boolean? = null, val vlasnik_od: String? = null,
        val sef_tacno: Int? = null, val sef_netacno: Int? = null, val sef_ometanja: Int? = null, val struka_udeo: Int? = null,
        val sef_smeh: Boolean? = null, val teza: Boolean? = null, val sef_lik: String? = null,
        val slobodni: List<Int>? = null, val slobodan_danas: Boolean? = null, val stres: Double? = null,
        val fokus: List<String>? = null, val fokus_udeo: List<Int>? = null,
        val ja_vlasnik: Boolean = false, val kasa: Double? = null, val odrzavanje: Int = 0, val dividenda_danas: Boolean = false,
        val udeo_menjan: String? = null, val cena_nadogradnje: Double? = null, val treba_zaposlenih: Int? = null, val aktivnih: Int = 0,
        val poslednji_ulazak: String? = null, val botovi: List<Bot> = emptyList(), val zaposleni: List<Zaposleni> = emptyList(),
        val izazovi: List<Izazov> = emptyList(), val teme: List<Tema> = emptyList(),
    ) {
        val sefNivo get() = kratko.sefNivo
        val slika get() = slikaZgrade(korporacija, nivo, stil)
        val udeoNaziv get() = udeoNaziv(udeo)
        val kratko get() = Firma(id, ime, korporacija, npc, vlasnik, vlasnik_ime, pozicija, nivo, stil, udeo, kljucne, rekord, rekord_ime, rekord_igrac,
            zaposlenih, botova, zastita_do, sef_tacno, sef_netacno, sef_ometanja, struka_udeo, sef_smeh, teza, sef_lik, slobodni, slobodan_danas, stres, fokus, fokus_udeo)
    }

    @Serializable data class Probni(val runde: Int = 0, val cilj: Int = 10, val tacnih: Int = 0, val ishod: Int? = null, val danas: Int? = null,
                                    val korporacija_dana: Int? = null, val bivsi_vlasnik: Boolean? = null)

    @Serializable data class Stanje(
        val pozicija: String? = null, val pol: String? = null, val talenti: List<String>? = null, val pomoci: List<String>? = null,
        val mirni: Boolean? = null, val katalog_talenata: List<Talenat>? = null, val zamena_talenta: ZamenaTalenta? = null,
        val kapital: Double = 0.0, val ugled: Int = 0, val titula: Int = 0, val nivo_ugleda: Int = 1, val slotova: Int = 1,
        val placenih_danas: Int = 0, val placenih_max: Int = 10, val probni: Probni = Probni(), val office_pravo: Int? = null,
        val odmor_do: String? = null, val odmor_ostalo: Int = 0, val posao: Firma? = null, val zaposlen_od: String? = null,
        val firme: List<FirmaDetalj> = emptyList(), val moji_izazovi: List<Izazov> = emptyList(), val korporacija: String = "",
        val prefiksi: List<String> = emptyList(), val oblici: List<String> = emptyList(), val pozicije: List<Pozicija> = emptyList(),
    ) {
        val mojaPozicija get() = pozicije.firstOrNull { it.id == pozicija }
        val mojiTalenti get() = (katalog_talenata ?: emptyList()).filter { talenti?.contains(it.id) == true }
        val uProbnom get() = probni.ishod == null && pozicija != null
    }

    @Serializable data class Pitanje(val id: String, val question_text: String, val options: List<String>, val correct_answer: Int,
                                     val tema: String? = null, val runda: Int? = null) {
        val zaPrikaz get() = club.librum.kviz.servisi.Pitanje(id, question_text, options, correct_answer).let { Prikaz.od(it) }
        /** Indeks izabranog odgovora u redosledu iz baze (server proverava tačnost po njemu). */
        fun izvorni(izabran: Int?, prikaz: Prikaz): Int {
            if (izabran == null) return -1
            if (izabran == prikaz.tacan) return correct_answer
            val i = options.indexOf(prikaz.opcije[izabran])
            return if (i >= 0 && i != correct_answer) i else (correct_answer + 1) % 4
        }
    }

    @Serializable data class IshodRunde(val tacnih: Int, val poeni: Int, val placeno: Boolean, val plata: Double, val kasi: Double,
                                        val ugled: Int, val rekord: Boolean, val probni: Probni? = null, val placenih_danas: Int = 0,
                                        val prekovremeno: Boolean? = null)
    @Serializable data class BotPomoc(val bot: String, val tema: String, val izbor: Int, val sigurnost: Int)
    @Serializable data class Dogadjaj(val vrsta: String, val tekst: String, val kad: String)
    @Serializable data class Ekspertiza(val tema: String, val ocena: Int)
    @Serializable data class CV(val id: String, val ime: String, val avatar: String? = null, val pozicija: String? = null, val titula: Int = 0,
                                val ugled: Int = 0, val kapital: Double = 0.0, val neto: Double = 0.0, val posao: Firma? = null,
                                val firme: List<Firma> = emptyList(), val ekspertiza: List<Ekspertiza> = emptyList(), val odbrana: Int = 0,
                                val preuzimanja: Int = 0, val tacnih: Int = 0, val rundi: Int = 0, val dogadjaji: List<Dogadjaj> = emptyList())
    @Serializable data class RedRanga(val id: String, val ime: String, val vrednost: Double, val pozicija: String? = null)
    @Serializable data class Reset(val ok: Boolean, val firmi_predato: Int = 0)
    @Serializable data class NovaFirma(val firma: String)
    @Serializable data class Ok(val ok: Boolean)
    @Serializable data class TemaFokusa(val tema: String, val pitanja: Int)
    @Serializable data class Mirni(val mirni: Boolean)
    @Serializable data class IshodDuela(val stanje: String, val moji_tacni: Int, val pobednik: String? = null, val ishod: String? = null,
                                        val vlasnik_tacnih: Int? = null, val izazivac_tacnih: Int? = null)

    // ---- Pozivi ----

    suspend inline fun <reified T> rpc(ime: String, parametri: Map<String, Any?> = emptyMap()): T {
        val token = Supabase.tokenIgraca?.invoke() ?: throw Greska("Prijavi se da bi igrao Karijeristu.")
        return Supabase.json.decodeFromString(Supabase.rpc(ime, parametri, token))
    }

    suspend fun stanje(): Stanje = rpc("karijera_stanje")
    suspend fun izaberiPoziciju(id: String, pol: String, talenti: List<String>, pomoci: List<String>): Stanje =
        rpc("karijera_izaberi_poziciju", mapOf("p_pozicija" to id, "p_pol" to pol, "p_talenti" to talenti, "p_pomoci" to pomoci))
    suspend fun resetuj(): Reset = rpc("karijera_resetuj")
    suspend fun promeniTalenat(stari: String, novi: String): Stanje = rpc("karijera_promeni_talenat", mapOf("p_stari" to stari, "p_novi" to novi))
    suspend fun noviProbni(): Stanje = rpc("karijera_novi_probni")
    suspend fun odmor(dana: Int): Stanje = rpc("karijera_odmor", mapOf("p_dana" to dana))
    suspend fun povuciOdmor(): Stanje = rpc("karijera_odmor_povuci")
    suspend fun zaposliSe(firma: String): Stanje = rpc("karijera_zaposli_se", mapOf("p_firma" to firma))
    suspend fun pitanjaRunde(firma: String): List<Pitanje> =
        rpc<List<Pitanje>>("karijera_runda_pitanja", mapOf("p_firma" to firma)).filter { it.options.size == 4 && it.correct_answer in 0..3 }
    suspend fun zavrsiRundu(firma: String, odgovori: List<Map<String, Any?>>): IshodRunde =
        rpc("karijera_zavrsi_rundu", mapOf("p_firma" to firma, "p_odgovori" to odgovori))
    suspend fun pomocBota(firma: String?, pitanje: String, izazov: String? = null): BotPomoc =
        rpc("karijera_bot_pomoc", buildMap { put("p_firma", firma); put("p_pitanje", pitanje); if (izazov != null) put("p_izazov", izazov) })
    suspend fun otvoriFirmu(ime: String, stil: Int, botovi: List<String>): NovaFirma =
        rpc("karijera_otvori_firmu", mapOf("p_ime" to ime, "p_stil" to stil, "p_botovi" to botovi))
    suspend fun preimenuj(id: String, ime: String): FirmaDetalj = rpc("karijera_preimenuj", mapOf("p_firma" to id, "p_ime" to ime))
    suspend fun prijaviIme(id: String): Ok = rpc("karijera_prijavi_ime", mapOf("p_firma" to id))
    suspend fun firma(id: String): FirmaDetalj = rpc("karijera_firma", mapOf("p_firma" to id))
    suspend fun podesiSefa(id: String, n: Sef.Nivo): FirmaDetalj = rpc("karijera_podesi_sefa",
        mapOf("p_firma" to id, "p_tacno" to n.tacno, "p_netacno" to n.netacno, "p_ometanja" to n.ometanja, "p_smeh" to n.smeh, "p_lik" to n.lik))
    suspend fun podesiPitanja(id: String, struka: Int, fokus: List<String>, udeo: List<Int>, teza: Boolean): FirmaDetalj =
        rpc("karijera_podesi_pitanja", mapOf("p_firma" to id, "p_struka" to struka, "p_fokus" to fokus, "p_fokus_udeo" to udeo, "p_teza" to teza))
    /** Zaštita od napada 3/5/7/10 dana od preuzimanja, jednom po vlasništvu (vlasnik 05.11). */
    suspend fun izaberiZastitu(id: String, dana: Int): FirmaDetalj {
        rpc<String>("karijera_zastita", mapOf("p_firma" to id, "p_dana" to dana))
        return firma(id)
    }
    suspend fun podesiSlobodne(id: String, dani: List<Int>): FirmaDetalj = rpc("karijera_podesi_slobodne", mapOf("p_firma" to id, "p_dani" to dani))
    suspend fun temeFokusa(): List<TemaFokusa> = rpc("karijera_teme_fokusa")
    suspend fun postaviMirni(da: Boolean): Mirni = rpc("karijera_mirni", mapOf("p_da" to da))
    suspend fun temePozicije(id: String): List<Tema> = rpc("karijera_teme_pozicije", mapOf("p_pozicija" to id))
    suspend fun podesi(id: String, udeo: String?, kljucne: List<String>?): FirmaDetalj =
        rpc("karijera_podesi_firmu", mapOf("p_firma" to id, "p_udeo" to udeo, "p_kljucne" to kljucne))
    suspend fun zaposliBota(id: String, tema: String): FirmaDetalj = rpc("karijera_zaposli_bota", mapOf("p_firma" to id, "p_tema" to tema))
    suspend fun obuciBota(bot: String): FirmaDetalj = rpc("karijera_obuci_bota", mapOf("p_bot" to bot))
    suspend fun nadogradi(id: String): FirmaDetalj = rpc("karijera_nadogradi", mapOf("p_firma" to id))
    suspend fun dividenda(id: String): FirmaDetalj = rpc("karijera_dividenda", mapOf("p_firma" to id))
    suspend fun otpusti(id: String, igrac: String): FirmaDetalj = rpc("karijera_otpusti", mapOf("p_firma" to id, "p_igrac" to igrac))
    suspend fun berza(pozicija: String?): List<Firma> = rpc("karijera_berza", mapOf("p_pozicija" to pozicija))
    suspend fun posaljiIzazov(firma: String, tema: String): Izazov = rpc("karijera_posalji_izazov", mapOf("p_firma" to firma, "p_tema" to tema))
    suspend fun prihvatiIzazov(id: String, tema1: String, tema3: String): Izazov =
        rpc("karijera_prihvati_izazov", mapOf("p_izazov" to id, "p_tema1" to tema1, "p_tema3" to tema3))
    suspend fun pitanjaDuela(id: String): List<Pitanje> = rpc("karijera_duel_pitanja", mapOf("p_izazov" to id))
    suspend fun predajDuel(id: String, odgovori: List<Map<String, Any?>>): IshodDuela =
        rpc("karijera_duel_predaj", mapOf("p_izazov" to id, "p_odgovori" to odgovori))
    suspend fun cv(igrac: String? = null): CV = rpc("karijera_cv", mapOf("p_igrac" to igrac))
    suspend fun rang(vrsta: String): List<RedRanga> = rpc("karijera_rang", mapOf("p_vrsta" to vrsta))

    // ---- Stanje igrača u aplikaciji (postavlja se pri ulasku u Karijeru) ----
    var mojiTalenti: Set<String> = emptySet()
    var mojPol: String = "m"
    var mirni: Boolean = false
    var mojePomoci: List<String> = Pomoci.sve.take(4).map { it.id }

    // ---- Prikaz ----
    val titule = listOf("Junior", "Senior", "Menadžer", "Direktor")
    val naziviNivoa = listOf("Garaža", "Kancelarija", "Sprat", "Poslovna zgrada", "Neboder")
    /** 8 stilova zgrade (vlasnik 05.11). */
    val naziviStila = listOf("Moderno", "Cigla", "Belo", "Kreativno", "Kontejner", "Loft", "Zeleno", "Kruna")
    val ceneObuke = mapOf(60 to 3000, 75 to 8000)
    val daniKratko = listOf("pon", "uto", "sre", "čet", "pet", "sub", "ned")

    /** Ime slike u res/drawable-nodpi (isto kao iOS Assets, malim slovima). */
    fun slikaZgrade(korporacija: Boolean, nivo: Int, stil: Int) =
        if (korporacija) "karijera_korporacija_1" else "karijera_zgrada_${nivo.coerceIn(1, 5)}_${stil.coerceIn(1, naziviStila.size)}"

    fun udeoNaziv(u: String) = when (u) {
        "skrt" -> "Škrt · 50% plata"; "izdasan" -> "Izdašan · 80% plata"; "korporacija" -> "Korporacija · 40% plata"; else -> "Pošten · 65% plata"
    }

    /** Lik asistenta prati ime: muška imena 1/3/5, ženska 2/4/6 (isto kao iOS). */
    fun slikaBota(ime: String): String {
        val muska = setOf("Luka", "Vuk", "Pavle", "Đorđe", "Filip", "Marko", "Relja", "Bogdan", "Stefan", "Ognjen")
        val zbir = ime.codePoints().toArray().sum()
        val izbor = if (ime in muska) listOf(1, 3, 5) else listOf(2, 4, 6)
        return "karijera_asistent_${izbor[zbir % 3]}"
    }

    /** Primer: `daniOpis(listOf(6, 7))` → „sub, ned” */
    fun daniOpis(d: List<Int>?): String = (d ?: emptyList()).sorted().filter { it in 1..7 }.joinToString(", ") { daniKratko[it - 1] }.ifEmpty { "nema" }

    fun novac(v: Double): String = NumberFormat.getIntegerInstance(Locale.forLanguageTag("sr-Latn-RS")).format(Math.round(v))

    fun datum(s: String): OffsetDateTime? = if (s == "infinity") OffsetDateTime.MAX else runCatching { OffsetDateTime.parse(s) }.getOrNull()

    /** Primer: `sefOpis(Sef.Nivo(), 0.05)` → „srednji · ponekad ometa · +5% plate” */
    fun sefOpis(n: Sef.Nivo, stres: Double?): String {
        val j = listOf("isključen", "blag", "srednji", "jak")
        val om = listOf("bez ometanja", "retko ometa", "ponekad ometa", "često ometa")
        val komentari = if (n.tacno == n.netacno) j[n.tacno] else "${j[n.tacno]}/${j[n.netacno]}"
        val dodatak = if ((stres ?: 0.0) > 0) " · +${Math.round((stres ?: 0.0) * 100)}% plate" else ""
        return "$komentari · ${om[n.ometanja]}$dodatak"
    }

    /** Runda od 10 po mešavini firme, isto kao server (karijera_runda_pitanja). */
    fun mesavina(struka: Int, fokus: List<String>, udeo: List<Int>): List<Pair<String, Int>> {
        val nStruka = Math.round(10 * struka / 100.0).toInt(); val nOpste = 10 - nStruka
        val delovi = mutableListOf("struka" to nStruka)
        fokus.zip(udeo).forEach { (t, u) -> delovi += t to minOf(Math.round(nOpste * u / 100.0).toInt(), 10 - delovi.sumOf { it.second }) }
        delovi += "opšte" to 10 - delovi.sumOf { it.second }
        return delovi.filter { it.second > 0 }
    }

    fun mesavinaOpis(struka: Int?, fokus: List<String>?, udeo: List<Int>?, teza: Boolean?) =
        mesavina(struka ?: 60, fokus ?: emptyList(), udeo ?: emptyList()).joinToString(", ") { "${it.second} ${it.first}" } + if (teza == true) " · teže" else ""

    fun stres(n: Sef.Nivo): Double {
        val m = maxOf(n.tacno, n.netacno)
        return (if (m == 3) 0.10 else if (m == 2) 0.05 else 0.0) + if (n.ometanja == 3) 0.05 else 0.0
    }

}
