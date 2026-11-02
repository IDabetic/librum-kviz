package club.librum.kviz.osvajanje

import androidx.compose.runtime.getValue
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

/** Tok partije: pitanja, potezi botova i odbrana čoveka. Pravila su u Pravila.kt. */
class OsvajanjeModel(private val krugova: Int, private val tezina: Tezina, private val ime: String?, private val paket: PaketPitanja) : ViewModel() {
    enum class Vrsta { SNABDEVANJE, NAPAD, ODBRANA }
    data class Otvoreno(val vrsta: Vrsta, val prikaz: Prikaz, val odakle: String? = null, val kuda: String? = null, val rival: Odgovor? = null)

    private val slucajno = Slucajno(System.currentTimeMillis().toInt())
    var stanje by mutableStateOf(Stanje.nova(krugova, tezina, slucajno, ime)); private set
    var spremno by mutableStateOf(false); private set
    var greska by mutableStateOf<String?>(null); private set
    var izabrana by mutableStateOf<String?>(null); private set
    var utvrdjivanje by mutableStateOf(false); private set
    var otvoreno by mutableStateOf<Otvoreno?>(null); private set
    var poruka by mutableStateOf<String?>(null); private set

    private var spil = Spil(emptyList())
    private var odbrana: CompletableDeferred<Odgovor>? = null
    private var potezBota: Job? = null
    private val pauzaBota = 700L

    val covekNaPotezu get() = stanje.faza != Faza.KRAJ && stanje.trenutni.covek
    val mete: List<String> get() = izabrana?.takeIf { !utvrdjivanje && covekNaPotezu }?.let { stanje.mete(it) }.orEmpty()

    val uputstvo: String get() = when {
        stanje.faza == Faza.KRAJ -> "Kraj partije"
        !covekNaPotezu -> "${stanje.trenutni.ime} je na potezu…"
        stanje.faza == Faza.RASPORED -> "Dodirni svoje oblasti: još ${stanje.zaRaspored}"
        stanje.faza == Faza.NAPAD && utvrdjivanje -> "Izaberi oblast, pa susednu svoju"
        stanje.faza == Faza.NAPAD && izabrana == null -> "Izaberi oblast sa 2+ vojske · bitka ${stanje.bitaka}/${Pravila.BITAKA_PO_POTEZU}"
        stanje.faza == Faza.NAPAD -> "Izaberi metu"
        else -> "Snabdevanje…"
    }

    init {
        viewModelScope.launch {
            runCatching { paket.ucitaj() }
                .onSuccess { spil = Spil(it); spremno = true; pocniPotez(stanje) }
                .onFailure { greska = it.message }
        }
    }

    fun dodir(id: String) {
        if (!covekNaPotezu || otvoreno != null) return
        val oblast = stanje.oblasti[id] ?: return
        val moja = oblast.vlasnik == stanje.trenutni.id
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
                    moja -> izabrana = if (stanje.mete(id).isEmpty()) null else id
                    izvor != null && id in stanje.mete(izvor) -> {
                        val rival = if (oblast.vlasnik != null) stanje.botOdgovor(slucajno) else null
                        otvoreno = Otvoreno(Vrsta.NAPAD, spil.sledece(), izvor, id, rival)
                    }
                }
            }
            else -> Unit
        }
    }

    fun rasporediSam() { stanje = stanje.botRasporedi() }
    fun prekidacUtvrdjivanja() { utvrdjivanje = !utvrdjivanje; izabrana = null }

    fun krajPoteza() {
        izabrana = null; utvrdjivanje = false
        pocniPotez(stanje.zavrsiPotez())
    }

    /** Odgovor sa kartice pitanja (null = isteklo vreme). */
    fun odgovoreno(izabran: Int?, ms: Int) {
        val o = otvoreno ?: return
        otvoreno = null
        val moj = Odgovor(izabran == o.prikaz.tacan, ms)
        when (o.vrsta) {
            Vrsta.SNABDEVANJE -> {
                stanje = stanje.snabdevanje(moj.tacan)
                javi(if (moj.tacan) "Tačno! Raspoređuješ ${stanje.zaRaspored}" else "Netačno. Dobijaš samo ${stanje.zaRaspored}")
            }
            Vrsta.ODBRANA -> odbrana?.complete(moj)
            Vrsta.NAPAD -> {
                val odakle = o.odakle ?: return
                val kuda = o.kuda ?: return
                val (novo, ishod) = stanje.razresiBitku(odakle, kuda, moj, o.rival)
                stanje = novo
                if (ishod.osvojeno) {
                    javi(if (ishod.plen) "Prestonica pala! +5 plena" else if (ishod.proboj) "Proboj! +2 vojske" else "Osvojeno! Cepaj dalje")
                    izabrana = if (novo.mete(kuda).isEmpty()) null else kuda
                } else {
                    javi(if (ishod.gubitakNapadaca == 0) "Branilac gubi ${ishod.gubitakBranioca}" else "Gubiš ${ishod.gubitakNapadaca}")
                    if (novo.mete(odakle).isEmpty()) izabrana = null
                }
            }
        }
    }

    fun novaPartija() {
        potezBota?.cancel()
        izabrana = null; utvrdjivanje = false; otvoreno = null
        stanje = Stanje.nova(krugova, tezina, slucajno, ime)
        pocniPotez(stanje)
    }

    private fun pocniPotez(novo: Stanje) {
        stanje = novo
        if (novo.faza != Faza.SNABDEVANJE) return
        if (novo.trenutni.covek) otvoreno = Otvoreno(Vrsta.SNABDEVANJE, spil.sledece())
        else potezBota = viewModelScope.launch { igrajBota() }
    }

    private suspend fun igrajBota() {
        stanje = stanje.snabdevanje(slucajno.sledeci() < stanje.tacnostBota).botRasporedi()
        delay(pauzaBota)
        while (true) {
            val (odakle, kuda) = stanje.botSledeciNapad() ?: break
            izabrana = odakle
            delay(pauzaBota)
            val napadac = stanje.botOdgovor(slucajno)
            val vlasnik = stanje.oblasti[kuda]?.vlasnik
            val branilac = when {
                vlasnik == null -> null
                stanje.igraci.first { it.id == vlasnik }.covek -> {
                    javi("${stanje.trenutni.ime} napada ${Mapa.oblast(kuda).ime}! Brani se")
                    val cekanje = CompletableDeferred<Odgovor>()
                    odbrana = cekanje
                    otvoreno = Otvoreno(Vrsta.ODBRANA, spil.sledece(), odakle, kuda)
                    cekanje.await()
                }
                else -> stanje.botOdgovor(slucajno)
            }
            stanje = stanje.razresiBitku(odakle, kuda, napadac, branilac).first
            delay(pauzaBota)
        }
        izabrana = null
        pocniPotez(stanje.zavrsiPotez())
    }

    private fun javi(tekst: String) {
        poruka = tekst
        viewModelScope.launch {
            delay(2200)
            if (poruka == tekst) poruka = null
        }
    }
}
