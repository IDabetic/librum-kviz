package club.librum.kviz.osvajanje

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import club.librum.kviz.servisi.PaketPitanja
import club.librum.kviz.servisi.Prikaz
import club.librum.kviz.servisi.Spil
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.UUID

/** Postavka partije iz čekaonice (docs/OSVAJANJE-VISE-IGRACA.md). */
data class OsvajanjePostavka(
    val nacin: Nacin,
    val igraca: Int,
    val krugova: Int,
    val tezina: Tezina,
    val igraci: List<NoviIgrac>,
    val pocetak: Map<String, String> = emptyMap(),
    /** Id kontinenta kad se igra samo na njemu; null = ceo svet. */
    val teren: String? = null,
    /** Pravi igrači se traže preko servera (sobe); inače su prazna mesta botovi odmah. */
    val traziIgrace: Boolean = false,
) {
    /** [kljuc] je vrednost na serveru (osvajanje_sobe.nacin), ista kao na iOS-u. */
    enum class Nacin(val kljuc: String, val naziv: String, val opis: String, val brojevi: List<Int>) {
        JEDAN_NA_JEDAN("jedanNaJedan", "Jedan na jedan", "Ti protiv jednog rivala.", listOf(2)),
        TIMOVI("timovi", "Timovi po dvoje", "Dva do šest timova; saigrači dele države i misiju.", listOf(4, 6, 8, 10, 12)),
        SVAKO_ZA_SEBE("svakoZaSebe", "Svako za sebe", "Tri do šest igrača, bez saveza.", listOf(3, 4, 5, 6)),
    }

    companion object {
        val BOJE = listOf(0xFF12907E, 0xFFFF5FA2, 0xFF6D4BC9, 0xFFF4A33C, 0xFF6EC3F2, 0xFFE5385C)
        val IMENA_BOTOVA = listOf("Mimi", "Zig", "Bloop", "Lumi", "Luna", "Max", "Sara", "Đole", "Ana", "Pera", "Mila")

        /** Mesta za stolom: timovi se smenjuju (A1, B1, C1, A2…), čovek je prvi u timu A i kapiten. */
        fun mesta(nacin: Nacin, igraca: Int, ime: String): List<NoviIgrac> {
            val timova = if (nacin == Nacin.TIMOVI) igraca / 2 else igraca
            val poTimu = if (nacin == Nacin.TIMOVI) 2 else 1
            var bot = 0
            return (0 until poTimu).flatMap { clan ->
                (0 until timova).map { t ->
                    val covek = t == 0 && clan == 0
                    val n = if (covek) ime else IMENA_BOTOVA[bot % IMENA_BOTOVA.size]
                    if (!covek) bot++
                    NoviIgrac(if (covek) "ti" else "bot$bot", n, BOJE[t % BOJE.size], covek, ('A' + t).toString(), clan == 0)
                }
            }
        }
    }
}

/** Tok partije: snabdevanje, bitke (uvod → pitanja → rezultat), potezi botova. Pravila su u Pravila.kt. */
class OsvajanjeModel(
    private val krugova: Int,
    private val tezina: Tezina,
    private val ime: String?,
    private val paket: PaketPitanja,
    val postavka: OsvajanjePostavka? = null,
) : ViewModel() {
    data class Otvoreno(val prikaz: Prikaz, val id: String = UUID.randomUUID().toString())

    /** Bitka za državu: uvod (država, činjenice, odbrojavanje), pa pitanja, pa rezultat. */
    data class Bitka(
        val napadam: Boolean,
        val odakle: String,
        val kuda: String,
        val uslov: Uslov,
        val prikazi: List<Prikaz>,
        val rivalIme: String,
        val korak: Korak = Korak.UVOD,
        val redni: Int = 0,
        val tacnih: Int = 0,
        val ms: Int = 0,
        val rival: Skor? = null,
        val ishod: Ishod? = null,
        /** Raste kad pomoć „Preskok” zameni pitanje, da se kartica nacrta iznova. */
        val zamena: Int = 0,
        val id: String = UUID.randomUUID().toString(),
    ) { enum class Korak { UVOD, PITANJA, REZULTAT } }

    private val slucajno = Slucajno(System.currentTimeMillis().toInt())
    var stanje by mutableStateOf(nova()); private set
    var spremno by mutableStateOf(false); private set
    var greska by mutableStateOf<String?>(null); private set
    var izabrana by mutableStateOf<String?>(null); private set
    /** Izabrana meta pre potvrde napada: igrač vidi odakle napada, šta napada i šta rizikuje. */
    var meta by mutableStateOf<String?>(null); private set
    /** Jedna pomoć po partiji važi za celo Osvajanje. */
    var pomocIskoriscena by mutableStateOf(false)
    var utvrdjivanje by mutableStateOf(false); private set
    var otvoreno by mutableStateOf<Otvoreno?>(null); private set
    var bitka by mutableStateOf<Bitka?>(null); private set
    var poruka by mutableStateOf<String?>(null); private set
    var tacnih by mutableIntStateOf(0); private set
    var netacnih by mutableIntStateOf(0); private set
    var zbirMs by mutableIntStateOf(0); private set

    private var spil = Spil(emptyList())
    private var cekaOdbranu: CompletableDeferred<Skor>? = null
    private var zatvaranje: CompletableDeferred<Unit>? = null
    private var potezBota: Job? = null
    private val pauzaBota = 700L

    // Na jednom kontinentu nema misija: pobeđuje ko ga ceo osvoji ili ima više na kraju.
    private fun nova() = postavka?.let { Stanje.nova(it.krugova, it.tezina, slucajno, igraci = it.igraci, pocetak = it.pocetak, misije = it.teren == null, teren = it.teren) }
        ?: Stanje.nova(krugova, tezina, slucajno, ime)

    val covekNaPotezu get() = stanje.faza != Faza.KRAJ && stanje.trenutni.covek
    val mete: List<String> get() = izabrana?.takeIf { !utvrdjivanje && covekNaPotezu }?.let { stanje.mete(it) }.orEmpty()
    /** Države iz kojih čovek sada može da napadne (žuta isprekidana ivica, korak 1). */
    val izvori: List<String> get() =
        if (!covekNaPotezu || stanje.faza != Faza.NAPAD || izabrana != null || utvrdjivanje) emptyList()
        else stanje.oblastiIgraca(stanje.trenutni.id).filter { stanje.mete(it).isNotEmpty() }
    val mojTim: String? get() = stanje.igraci.firstOrNull { it.covek }?.tim
    val jesamKapiten: Boolean get() = stanje.igraci.firstOrNull { it.covek }?.kapiten ?: false
    val kontinentiBezOdbrane: List<Kontinent> get() {
        val t = mojTim ?: return emptyList()
        if (!jesamKapiten) return emptyList()
        return Kontinenti.svi.filter { stanje.drziKontinent(t, it.id) && stanje.odbrane[it.id] == null }
    }
    val bonusPomoci: Int get() = mojTim?.let { stanje.bonusPomoci[it] } ?: 0

    val uputstvo: String get() = when {
        stanje.faza == Faza.KRAJ -> "Kraj partije"
        !covekNaPotezu -> "${stanje.trenutni.ime} je na potezu…"
        stanje.faza == Faza.RASPORED -> "Dodirni svoje oblasti: još ${stanje.zaRaspored}"
        stanje.faza == Faza.NAPAD && utvrdjivanje -> "Izaberi oblast, pa susednu svoju"
        stanje.faza == Faza.NAPAD && izabrana == null -> "1. Dodirni svoju državu sa žutom ivicom: odatle napadaš · bitka ${stanje.bitaka + 1}/${stanje.napadaPoPotezu}"
        stanje.faza == Faza.NAPAD -> "2. Napadaš iz: ${Mapa.oblast(izabrana!!).ime}. Dodirni koga napadaš (isprekidana ivica)."
        else -> "Snabdevanje…"
    }

    init {
        viewModelScope.launch {
            runCatching { paket.ucitaj() }
                .onSuccess { spil = Spil(it); spremno = true; if (postavka == null) pocniPotez(stanje) }
                .onFailure { greska = it.message }
        }
    }

    /** Posle lista sa misijom: kreće prvi potez. */
    fun zapocni() {
        if (!spremno || stanje.krug != 1 || stanje.faza != Faza.SNABDEVANJE || otvoreno != null || potezBota?.isActive == true) return
        pocniPotez(stanje)
    }

    fun dodir(id: String) {
        if (!covekNaPotezu || otvoreno != null || bitka != null) return
        val oblast = stanje.oblasti[id] ?: return
        val moja = oblast.vlasnik == stanje.trenutni.tim
        when (stanje.faza) {
            Faza.RASPORED -> if (moja) stanje = stanje.rasporedi(id)
            Faza.NAPAD -> {
                val izvor = izabrana
                when {
                    utvrdjivanje && izvor != null && moja && id in Mapa.susedi(izvor) -> {
                        stanje = stanje.utvrdi(izvor, id, (stanje.oblasti[izvor]?.vojske ?: 1) - 1)
                        utvrdjivanje = false; izabrana = null; javi("Vojske prebačene")
                    }
                    utvrdjivanje -> izabrana = if (moja) id else null
                    moja -> {
                        izabrana = if (stanje.mete(id).isEmpty()) null else id; meta = null
                        if (izabrana == null) javi(razlogBezNapada(id))
                    }
                    izvor != null && id in stanje.mete(izvor) -> meta = if (meta == id) null else id
                }
            }
            else -> Unit
        }
    }

    fun rasporediSam() { stanje = stanje.botRasporedi() }
    fun prekidacUtvrdjivanja() { utvrdjivanje = !utvrdjivanje; izabrana = null; meta = null }

    /** Potvrda napada sa panela mete. */
    fun napadni() {
        val izvor = izabrana ?: return
        val kuda = meta ?: return
        if (kuda !in stanje.mete(izvor)) return
        meta = null
        bitka = novaBitka(true, izvor, kuda)
    }

    fun odustaniOdMete() { meta = null }

    /** Zašto iz svoje države ne može da se napadne (inače bi dodir izgledao kao da ne radi). */
    private fun razlogBezNapada(id: String): String {
        val ime = Mapa.oblast(id).ime
        return when {
            stanje.bitaka >= stanje.napadaPoPotezu -> "Iskoristio si sve napade u ovom potezu. Završi potez."
            (stanje.oblasti[id]?.vojske ?: 0) < 2 -> "$ime ima 1 vojsku, za napad trebaju 2. Prebaci vojske dugmetom Utvrdi."
            else -> "$ime nema suseda za napad."
        }
    }

    /** Pomoć „Preskok”: tekuće pitanje bitke se menja novim iz špila. */
    fun zameniPitanje() {
        val b = bitka ?: return
        if (b.korak != Bitka.Korak.PITANJA) return
        bitka = b.copy(prikazi = b.prikazi.toMutableList().also { it[b.redni] = spil.sledece() }, zamena = b.zamena + 1)
    }

    fun krajPoteza() {
        izabrana = null; meta = null; utvrdjivanje = false
        pocniPotez(stanje.zavrsiPotez())
    }

    fun postaviOdbranu(k: String, o: Odbrana) {
        val novo = stanje.postaviOdbranu(k, o)
        if (novo == stanje) { javi("Odbranu menja kapiten, jednom po krugu, na svom potezu"); return }
        stanje = novo
        javi("${Kontinenti.svi.first { it.id == k }.ime}: ${o.naziv}")
    }

    fun iskoristiBonusPomoc(): Boolean {
        val t = mojTim ?: return false
        stanje = stanje.iskoristiBonusPomoc(t) ?: return false
        return true
    }

    /** Odgovor na pitanje snabdevanja (null = isteklo vreme). */
    fun odgovoreno(izabran: Int?, ms: Int) {
        val o = otvoreno ?: return
        otvoreno = null
        val tacno = izabran == o.prikaz.tacan
        if (tacno) tacnih++ else netacnih++
        zbirMs += ms
        stanje = stanje.snabdevanje(tacno)
        javi(if (tacno) "Tačno! Raspoređuješ ${stanje.zaRaspored}" else "Netačno. Dobijaš samo ${stanje.zaRaspored}")
    }

    // ── Bitka ──

    private fun novaBitka(napadam: Boolean, odakle: String, kuda: String): Bitka {
        val uslov = stanje.uslovBitke(kuda)
        val rival = if (napadam) stanje.igraci.firstOrNull { it.tim == stanje.oblasti[kuda]?.vlasnik }?.ime ?: "niko (prazno polje)" else stanje.trenutni.ime
        return Bitka(napadam, odakle, kuda, uslov, List(uslov.pitanja) { spil.sledece() }, rival)
    }

    fun pocniPitanja() { bitka = bitka?.copy(korak = Bitka.Korak.PITANJA) }

    fun odgovorUBitci(izabran: Int?, ms: Int) {
        var b = bitka ?: return
        if (b.korak != Bitka.Korak.PITANJA) return
        val tacno = izabran == b.prikazi[b.redni].tacan
        if (tacno) tacnih++ else netacnih++
        zbirMs += ms
        b = b.copy(tacnih = b.tacnih + if (tacno) 1 else 0, ms = b.ms + ms)
        if (b.redni + 1 < b.prikazi.size) { bitka = b.copy(redni = b.redni + 1); return }
        if (b.napadam) {
            if (stanje.oblasti[b.kuda]?.vlasnik == null) {
                val (novo, ishod) = stanje.razresiBitku(b.odakle, b.kuda, Odgovor(tacno, ms), null)
                stanje = novo; b = b.copy(ishod = ishod)
            } else {
                val rival = stanje.botSkor(slucajno, b.prikazi.size)
                val (novo, ishod) = stanje.razresiBitkuSkorom(b.odakle, b.kuda, Skor(b.tacnih, b.ms), rival)
                stanje = novo; b = b.copy(rival = rival, ishod = ishod)
            }
        }
        bitka = b.copy(korak = Bitka.Korak.REZULTAT)
        if (!b.napadam) { cekaOdbranu?.complete(Skor(b.tacnih, b.ms)); cekaOdbranu = null }
    }

    fun zatvoriBitku() {
        val b = bitka ?: return
        bitka = null
        val ishod = b.ishod
        if (b.napadam && ishod != null) {
            if (ishod.osvojeno) {
                javi(if (ishod.plen) "Prestonica pala! +5 plena" else if (ishod.proboj) "Proboj! +2 vojske" else "Osvojeno! Cepaj dalje")
                izabrana = if (stanje.mete(b.kuda).isEmpty()) null else b.kuda
            } else if (stanje.mete(b.odakle).isEmpty()) izabrana = null
        }
        zatvaranje?.complete(Unit); zatvaranje = null
    }

    fun novaPartija() {
        potezBota?.cancel()
        izabrana = null; utvrdjivanje = false; otvoreno = null; bitka = null
        stanje = nova()
        pocniPotez(stanje)
    }

    private fun pocniPotez(novo: Stanje) {
        stanje = novo
        if (novo.faza != Faza.SNABDEVANJE) return
        if (novo.trenutni.covek) {
            // Potez čoveka počinje napadom (vlasnik 02.11): pojačanja stižu sama i idu na granice, bez pitanja.
            val tim = novo.trenutni.tim
            val s = novo.snabdevanje(true)
            val dobio = s.zaRaspored
            stanje = s.copy(tacnih = s.tacnih + (tim to ((s.tacnih[tim] ?: 1) - 1))).botRasporedi()
            javi("+$dobio vojski na granicama. Biraj odakle napadaš.")
        }
        else potezBota = viewModelScope.launch { igrajBota() }
    }

    private suspend fun igrajBota() {
        stanje = stanje.snabdevanje(slucajno.sledeci() < stanje.tacnostBota).botRasporedi().botOdbrana()
        delay(pauzaBota)
        while (true) {
            val (odakle, kuda) = stanje.botSledeciNapad() ?: break
            izabrana = odakle
            delay(pauzaBota)
            val vlasnik = stanje.oblasti[kuda]?.vlasnik
            stanje = when {
                vlasnik == null -> stanje.razresiBitku(odakle, kuda, stanje.botOdgovor(slucajno), null).first
                stanje.igraci.first { it.tim == vlasnik }.covek -> {
                    val napadac = stanje.botSkor(slucajno)
                    val cekanje = CompletableDeferred<Skor>()
                    cekaOdbranu = cekanje
                    bitka = novaBitka(false, odakle, kuda)
                    val (novo, ishod) = stanje.razresiBitkuSkorom(odakle, kuda, napadac, cekanje.await())
                    bitka = bitka?.copy(rival = napadac, ishod = ishod)
                    val z = CompletableDeferred<Unit>(); zatvaranje = z; z.await()
                    novo
                }
                else -> stanje.razresiBitkuSkorom(odakle, kuda, stanje.botSkor(slucajno), stanje.botSkor(slucajno)).first
            }
            if (stanje.faza == Faza.KRAJ) break
            delay(pauzaBota)
        }
        izabrana = null
        pocniPotez(stanje.zavrsiPotez())
    }

    fun javi(tekst: String) {
        poruka = tekst
        viewModelScope.launch { delay(4000); if (poruka == tekst) poruka = null }
    }
}
