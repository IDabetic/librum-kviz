package club.librum.kviz.karijera

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import club.librum.kviz.servisi.Sesija
import club.librum.kviz.servisi.Zvuk
import club.librum.kviz.ui.Boje
import club.librum.kviz.ui.DonjiList
import club.librum.kviz.ui.Dugme
import club.librum.kviz.ui.Oznaka
import club.librum.kviz.ui.Papir
import club.librum.kviz.ui.VrstaDugmeta
import club.librum.kviz.ui.mirna
import club.librum.kviz.ui.naslov
import club.librum.kviz.ui.pop
import club.librum.kviz.ui.tekst
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.Duration
import java.time.OffsetDateTime

/** Ekrani unutar Karijere (sopstveni stek; sistemsko „nazad” vraća jedan korak). */
sealed interface KEkran {
    data class FirmaE(val id: String) : KEkran
    data object BerzaE : KEkran
    data object GradE : KEkran
    data class RundaE(val firma: Karijera.Firma, val probni: Boolean = false, val botovi: List<Karijera.Bot> = emptyList()) : KEkran
    data class CVE(val igrac: String?) : KEkran
    data object PravilaE : KEkran
    data class OfficeE(val botova: Int) : KEkran
    data class DuelE(val izazov: Karijera.Izazov, val botovi: List<Karijera.Bot>) : KEkran
}

/** Muzika Karijere: najviše jedna petlja u isto vreme. */
object KarijeraMuzika {
    private val petlje = listOf(Zvuk.Vrsta.KARIJERA_UVOD, Zvuk.Vrsta.KARIJERA_KORPORACIJA, Zvuk.Vrsta.KARIJERA_FIRMA, Zvuk.Vrsta.KARIJERA_POSAO,
        Zvuk.Vrsta.KARIJERA_OFFICE, Zvuk.Vrsta.KARIJERA_PROBNI_KRAJ, Zvuk.Vrsta.KARIJERA_DUEL, Zvuk.Vrsta.KARIJERA_ODBRANA,
        Zvuk.Vrsta.KARIJERA_FIRMA_2, Zvuk.Vrsta.KARIJERA_FIRMA_3, Zvuk.Vrsta.KARIJERA_FIRMA_4)
    /** Muzika u mojoj firmi (vlasnik 05.11): 4 džez numere, svakog dana druga (isto kao iOS). */
    private val mojaFirma = listOf(Zvuk.Vrsta.KARIJERA_FIRMA, Zvuk.Vrsta.KARIJERA_FIRMA_2, Zvuk.Vrsta.KARIJERA_FIRMA_3, Zvuk.Vrsta.KARIJERA_FIRMA_4)
    fun zaMojuFirmu(id: String, sadaMs: Long = System.currentTimeMillis()): Zvuk.Vrsta {
        val dan = (sadaMs / 86_400_000L).toInt()
        val seme = id.fold(0) { a, c -> (a * 31 + c.code) % 997 }
        return mojaFirma[(dan + seme) % mojaFirma.size]
    }
    fun pusti(v: Zvuk.Vrsta, jacina: Float = 0.3f) { petlje.filter { it != v }.forEach(Zvuk::stani); Zvuk.pusti(v, jacina, ponavljaj = true) }
    fun stani() = petlje.forEach(Zvuk::stani)
}

@Composable
fun KarijeraEkran(sesija: Sesija, nazad: () -> Unit) {
    val stek = remember { mutableStateListOf<KEkran>() }
    var osvezi by remember { mutableStateOf(0) }
    val idi: (KEkran) -> Unit = { stek.add(it) }
    val vrati: () -> Unit = { if (stek.isNotEmpty()) stek.removeAt(stek.lastIndex) else nazad(); osvezi++ }
    BackHandler(stek.isNotEmpty()) { vrati() }
    val nalog by sesija.nalog.collectAsState()
    val ja = nalog?.id
    when (val e = stek.lastOrNull()) {
        null -> KarijeraHub(ja, osvezi, idi, nazad)
        is KEkran.FirmaE -> FirmaEkran(e.id, ja, idi, vrati)
        KEkran.BerzaE -> BerzaEkran(ja, idi, vrati)
        KEkran.GradE -> GradEkran(idi, vrati)
        is KEkran.RundaE -> RundaEkran(e.firma, e.probni, e.botovi, ja, vrati)
        is KEkran.CVE -> CVEkran(e.igrac, vrati)
        KEkran.PravilaE -> PravilaEkran(vrati)
        is KEkran.OfficeE -> OfficeEkran(e.botova, vrati)
        is KEkran.DuelE -> DuelEkran(e.izazov, e.botovi, ja, vrati)
    }
}

private sealed interface Ucitano<out T> { data object Ucitava : Ucitano<Nothing>; data class Greska(val p: String) : Ucitano<Nothing>; data class Gotovo<T>(val v: T) : Ucitano<T> }

@Composable
private fun KarijeraHub(ja: String?, osvezi: Int, idi: (KEkran) -> Unit, nazad: () -> Unit) {
    var stanje by remember { mutableStateOf<Ucitano<Karijera.Stanje>>(Ucitano.Ucitava) }
    var poruka by remember { mutableStateOf<String?>(null) }
    var radi by remember { mutableStateOf(false) }
    var izazovTema by remember { mutableStateOf<Karijera.Firma?>(null) }
    var prihvatanje by remember { mutableStateOf<Karijera.Izazov?>(null) }
    var odmorList by remember { mutableStateOf(false) }
    val opseg = rememberCoroutineScope()

    suspend fun ucitaj() {
        runCatching { Karijera.stanje() }.onSuccess { s ->
            Karijera.mojiTalenti = (s.talenti ?: emptyList()).toSet(); Karijera.mojPol = s.pol ?: "m"; Karijera.mirni = s.mirni ?: false
            s.pomoci?.takeIf { it.isNotEmpty() }?.let { Karijera.mojePomoci = it }
            stanje = Ucitano.Gotovo(s)
        }.onFailure { if (stanje is Ucitano.Gotovo) poruka = it.message else stanje = Ucitano.Greska(it.message ?: "Greška") }
    }
    fun radnja(posao: suspend () -> Karijera.Stanje?) = opseg.launch {
        radi = true
        runCatching { posao() }.onSuccess { s -> if (s != null) stanje = Ucitano.Gotovo(s) else ucitaj() }.onFailure { poruka = it.message }
        radi = false
    }
    LaunchedEffect(osvezi) { ucitaj() }

    Box(Modifier.fillMaxSize()) {
        Papir()
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            val s = (stanje as? Ucitano.Gotovo)?.v
            if (s?.pozicija != null || stanje !is Ucitano.Gotovo) KNazad { nazad() }
            when (val st = stanje) {
                Ucitano.Ucitava -> { KSkelet(40.dp); KSkelet(220.dp); KSkelet(120.dp) }
                is Ucitano.Greska -> KGreska(st.p) { opseg.launch { stanje = Ucitano.Ucitava; ucitaj() } }
                is Ucitano.Gotovo -> if (st.v.pozicija == null) IzborPozicije(st.v, nazad) { id, pol, t, p -> radnja { Karijera.izaberiPoziciju(id, pol, t, p) } }
                    else Sadrzaj(st.v, ja, radi, idi, { izazovTema = it }, { prihvatanje = it }, { odmorList = true }) { radnja { Karijera.noviProbni() } }
            }
            Spacer(Modifier.height(40.dp))
        }
        poruka?.let { p ->
            LaunchedEffect(p) { delay(4000); poruka = null }
            Text(p, style = tekst(14.sp, FontWeight.Bold, Boje.naMastilu), modifier = Modifier.align(Alignment.BottomCenter).navigationBarsPadding().padding(16.dp)
                .fillMaxWidth().background(Boje.mastilo, RoundedCornerShape(16.dp)).clickable { poruka = null }.padding(14.dp))
        }
        izazovTema?.let { f ->
            IzborTemeList("Tvoja tema u duelu", "Vlasnik bira prvu i treću temu, ti drugu.", f.id, 1, emptyList(), { izazovTema = null }) { teme ->
                izazovTema = null; teme.firstOrNull()?.let { t -> radnja { Karijera.posaljiIzazov(f.id, t); null } }
            }
        }
        prihvatanje?.let { z ->
            IzborTemeList("Prihvati duel", if (z.pokusaj >= 4) "Biraš prvu temu; treća je nasumična (${z.pokusaj}. pokušaj)." else "Biraš prvu i treću temu. Izazivač je izabrao: ${z.tema_izazivac}.",
                z.firma.id, if (z.pokusaj >= 4) 1 else 2, listOf(z.tema_izazivac), { prihvatanje = null }) { teme ->
                prihvatanje = null; radnja { Karijera.prihvatiIzazov(z.id, teme[0], teme.getOrElse(1) { teme[0] }); null }
            }
        }
        val s = (stanje as? Ucitano.Gotovo)?.v
        if (odmorList && s != null) DonjiList({ odmorList = false }) {
            Text("Godišnji odmor", style = naslov(26.sp))
            Text("Do 3 dana mesečno, unapred. Tada se dani bez ulaska u firmu ne računaju. Ostalo ovog meseca: ${s.odmor_ostalo}.", style = tekst(14.sp, boja = Boje.sivaTekst))
            s.odmor_do?.let { doKad ->
                Text("Odmor traje do $doKad.", style = tekst(14.sp, FontWeight.Bold))
                // Povlačenje odmora (vlasnik 05.11): neiskorišćeni dani se vraćaju u mesečni fond.
                Dugme("Povuci odmor i vrati se na posao", vrsta = VrstaDugmeta.ZUTO) { odmorList = false; radnja { Karijera.povuciOdmor() } }
            }
            for (d in 1..minOf(3, s.odmor_ostalo)) Dugme("$d ${if (d == 1) "dan" else "dana"}", vrsta = VrstaDugmeta.SEKUNDARNO) { odmorList = false; radnja { Karijera.odmor(d) } }
        }
    }
}

@Composable
private fun Sadrzaj(s: Karijera.Stanje, ja: String?, radi: Boolean, idi: (KEkran) -> Unit, izazovi: (Karijera.Firma) -> Unit,
                    prihvati: (Karijera.Izazov) -> Unit, odmor: () -> Unit, noviProbni: () -> Unit) {
    Oznaka("KARIJERA")
    Text("${Karijera.titule[minOf(s.titula, 3)]} · ${s.mojaPozicija?.naziv(s.pol).orEmpty()}", style = naslov(26.sp), maxLines = 1, overflow = TextOverflow.Ellipsis)
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Plocica(Karijera.novac(s.kapital), "Kapital", Boje.teal, Modifier.weight(1f))
        Plocica("${s.ugled}", "Ugled · nivo ${s.nivo_ugleda}", Boje.roze, Modifier.weight(1f))
        Plocica("${s.placenih_danas}/${s.placenih_max}", "Plaćene runde", Boje.narandzasta, Modifier.weight(1f))
    }
    s.office_pravo?.let { pravo ->
        Column(Modifier.fillMaxWidth().pop(Boje.zuta, 20.dp).clickable(role = Role.Button) { idi(KEkran.OfficeE(pravo)) }.padding(16.dp)) {
            Text("Otvori svoj office", style = naslov(22.sp, Boje.tinta))
            Text(if (pravo > 0) "Pravo na zgradu i $pravo ${if (pravo == 1) "asistenta" else "asistenta"}." else "Pravo na zgradu, bez asistenata.", style = tekst(14.sp, FontWeight.SemiBold, Boje.tinta))
        }
    }
    if (s.uProbnom) ProbniKartica(s) { idi(KEkran.RundaE(korporacijaFirma(s), probni = true)) }
    else if (s.probni.ishod == -1 && s.office_pravo == null && s.firme.isEmpty()) {
        val dana = s.probni.korporacija_dana ?: 0
        val moze = dana >= 3 || s.probni.bivsi_vlasnik == true
        Column(Modifier.fillMaxWidth().pop(radijus = 22.dp).padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Oznaka("PROBNI RAD", Boje.crvena)
            Text("Ostaješ u Korporaciji", style = naslov(22.sp))
            Text(if (moze) "Možeš ponovo na probni rad." else "Novi probni rad posle 3 radna dana u Korporaciji. Odrađeno: $dana od 3.", style = tekst(14.sp, FontWeight.SemiBold, Boje.sivaTekst))
            Dugme("Novi probni rad", vrsta = VrstaDugmeta.ZUTO, omoguceno = moze && !radi) { noviProbni() }
        }
    }
    s.posao?.let { f ->
        Text(if (s.uProbnom) "Gde radiš" else "Posao", style = naslov(24.sp), modifier = Modifier.semantics { heading() })
        FirmaKartica(f, null, false) { idi(KEkran.FirmaE(f.id)) }
        if (!s.uProbnom || !f.korporacija) Dugme("Igraj rundu") { idi(KEkran.RundaE(f)) }
        if (f.rekord_igrac == ja && !f.korporacija) {
            val staz = s.zaposlen_od?.let { Karijera.datum(it) }?.let { Duration.between(it, OffsetDateTime.now()).toDays() } ?: 0
            Column(Modifier.fillMaxWidth().mirna().padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Držiš rekord ove firme!", style = tekst(15.sp, FontWeight.Bold))
                Text(if (staz >= 3) "Možeš da tražiš preuzimanje firme duelom." else "Izazov se šalje posle 3 dana u firmi.", style = tekst(14.sp, boja = Boje.sivaTekst))
                Dugme("Izazovi vlasnika", vrsta = VrstaDugmeta.ZUTO, omoguceno = staz >= 3 && !f.zasticena && f.slobodan_danas != true) { izazovi(f) }
                if (f.zasticena) Text("Firma je trenutno zaštićena od izazova.", style = tekst(13.sp, boja = Boje.sivaTekst))
                if (f.slobodan_danas == true) Text("Danas je slobodan dan ove firme. Izazov pošalji sutra.", style = tekst(13.sp, boja = Boje.sivaTekst))
            }
        }
    }
    if (s.firme.isNotEmpty()) {
        Text(if (s.firme.size == 1) "Moja firma" else "Moje firme", style = naslov(24.sp))
        s.firme.forEach { f ->
            FirmaKartica(f.kratko, f.kasa, true) { idi(KEkran.FirmaE(f.id)) }
            f.izazovi.filter { it.stanje != "gotov" }.forEach { z -> IzazovRed(z, true, ja, { prihvati(z) }) { idi(KEkran.DuelE(z, f.botovi)) } }
        }
    }
    if (s.moji_izazovi.isNotEmpty()) {
        Text("Moji izazovi", style = naslov(24.sp))
        s.moji_izazovi.forEach { z -> IzazovRed(z, false, ja, {}) { idi(KEkran.DuelE(z, emptyList())) } }
    }
    KSpisak {
        KRed("Grad", "sve firme") { idi(KEkran.GradE) }
        HorizontalDivider(color = Boje.kremTamnija)
        KRed("Berza poslova", "promeni firmu") { idi(KEkran.BerzaE) }
        HorizontalDivider(color = Boje.kremTamnija)
        KRed("Moj CV") { idi(KEkran.CVE(null)) }
        HorizontalDivider(color = Boje.kremTamnija)
        KRed("Pravila i saveti") { idi(KEkran.PravilaE) }
        if (s.firme.isNotEmpty()) { HorizontalDivider(color = Boje.kremTamnija); KRed("Godišnji odmor", "${s.odmor_ostalo} dana") { odmor() } }
    }
}

@Composable
fun Plocica(vrednost: String, naziv: String, boja: Color, modifier: Modifier = Modifier) {
    Column(modifier.mirna().padding(vertical = 14.dp, horizontal = 6.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Box(Modifier.size(10.dp).background(boja, RoundedCornerShape(5.dp)))
        Text(vrednost, style = naslov(20.sp), maxLines = 1)
        Text(naziv, style = tekst(12.sp, FontWeight.SemiBold, Boje.sivaTekst), maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

@Composable
private fun ProbniKartica(s: Karijera.Stanje, igraj: () -> Unit) {
    val p = s.probni
    Column(Modifier.fillMaxWidth().pop(radijus = 22.dp).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.Top) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Oznaka(if (p.bivsi_vlasnik == true) "SKRAĆENI PROBNI RAD" else "PROBNI RAD")
                Text("Runda ${minOf(p.runde + 1, p.cilj)} od ${p.cilj}", style = naslov(24.sp))
                Text(if (p.runde == 0) "Najmanje 60% tačnih za svoj office, 90% za office i 2 asistenta." else "Do sada ${p.tacnih} tačnih od ${p.runde * 10} (${p.tacnih * 10 / maxOf(p.runde, 1)}%).",
                    style = tekst(14.sp, FontWeight.SemiBold, Boje.sivaTekst))
            }
            KSlika("karijera_sef_korporacija_zadovoljan", Modifier.width(52.dp).height(90.dp))
        }
        LinearProgressIndicator(progress = { p.runde.toFloat() / maxOf(p.cilj, 1) }, modifier = Modifier.fillMaxWidth().height(6.dp).clip(RoundedCornerShape(3.dp)), color = Boje.teal, trackColor = Boje.kremTamnija)
        if ((p.danas ?: 0) >= Karijera.PROBNI_DNEVNO) Text("Danas si odigrao ${Karijera.PROBNI_DNEVNO} rundi probnog rada. Nastavi sutra.", style = tekst(14.sp, FontWeight.Bold, Boje.sivaTekst))
        else Dugme("Igraj rundu u Korporaciji", vrsta = VrstaDugmeta.ZUTO) { igraj() }
    }
}

fun korporacijaFirma(s: Karijera.Stanje): Karijera.Firma = s.posao?.takeIf { it.korporacija }
    ?: Karijera.Firma(s.korporacija, "Korporacija", true, vlasnik_ime = "Šef", pozicija = s.pozicija.orEmpty(), nivo = 5, udeo = "korporacija",
        sef_tacno = 2, sef_netacno = 2, sef_ometanja = 2, struka_udeo = 60, sef_smeh = true, teza = false, sef_lik = "korporacija", slobodni = listOf(6, 7))

@Composable
fun FirmaKartica(firma: Karijera.Firma, kasa: Double?, mojaFirma: Boolean, otvori: () -> Unit) {
    Row(Modifier.fillMaxWidth().pop(radijus = 20.dp).clickable(role = Role.Button, onClick = otvori).padding(12.dp), verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        Box(Modifier.size(104.dp).clip(RoundedCornerShape(14.dp)), contentAlignment = Alignment.BottomCenter) {
            Nebo(Modifier.matchParentSize(), firma.id)
            KSlika(firma.slika, Modifier.padding(top = 14.dp, start = 4.dp, end = 4.dp))
            Ulica(Modifier.matchParentSize(), firma.id, 0.6)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(firma.ime, style = tekst(17.sp, FontWeight.Bold), maxLines = 2)
            Text(if (firma.korporacija) "Šef · plata 40%" else "${Karijera.naziviNivoa[firma.nivo - 1]} · ${if (mojaFirma) "vlasnik si" else firma.vlasnik_ime}", style = tekst(13.sp, FontWeight.SemiBold, Boje.sivaTekst), maxLines = 1)
            if (!firma.korporacija) Text("Rekord ${firma.rekord}${firma.rekord_ime?.let { " · $it" }.orEmpty()}", style = tekst(13.sp, boja = Boje.sivaTekst), maxLines = 1)
            if (kasa != null) Text("Kasa ${Karijera.novac(kasa)}", style = tekst(14.sp, FontWeight.Bold, Boje.teal))
            if (firma.slobodan_danas == true) Text("Danas je slobodan dan · prekovremeno +10%", style = tekst(12.sp, FontWeight.Bold, Boje.narandzasta))
        }
        Text("›", style = tekst(20.sp, FontWeight.Bold, Boje.sivaTekst))
    }
}

@Composable
private fun IzazovRed(z: Karijera.Izazov, vlasnik: Boolean, ja: String?, prihvati: () -> Unit, igraj: () -> Unit) {
    Column(Modifier.fillMaxWidth().mirna().padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(if (vlasnik) "${z.izazivac_ime} traži tvoju firmu" else z.firma.ime, style = tekst(15.sp, FontWeight.Bold), maxLines = 1)
        val opis = when (z.stanje) {
            "ceka" -> if (vlasnik) "Pokušaj ${z.pokusaj}. Ako ne prihvatiš u roku, firma prelazi na izazivača." else "Čeka se da vlasnik prihvati duel."
            "u_toku" -> {
                val teme = listOfNotNull(z.tema1, z.tema_izazivac, z.tema3).joinToString(" · ")
                if (z.ja_odigrao == true) "Odigrao si. Čeka se drugi igrač. Teme: $teme." else "Teme: $teme. Asistenti vlasnika: ${if (z.botova >= 99) "svi" else "${z.botova}"}."
            }
            else -> "${if (z.pobednik == ja) "Pobeda" else "Poraz"} · ${z.ishod.orEmpty()}"
        }
        Text(opis, style = tekst(13.sp, boja = Boje.sivaTekst))
        if (vlasnik && z.stanje == "ceka") Dugme("Prihvati i izaberi teme", vrsta = VrstaDugmeta.ZUTO) { prihvati() }
        else if (z.stanje == "u_toku" && z.ja_odigrao == false) Dugme("Igraj duel (30 pitanja)") { igraj() }
    }
}

/** Izbor jedne ili dve teme (duel). */
@Composable
fun IzborTemeList(naslovL: String, podnaslov: String, firmaId: String, izbor: Int, iskljuci: List<String>, zatvori: () -> Unit, gotovo: (List<String>) -> Unit) {
    var teme by remember { mutableStateOf<List<String>>(emptyList()) }
    var izabrane by remember { mutableStateOf<List<String>>(emptyList()) }
    LaunchedEffect(firmaId) { teme = runCatching { Karijera.firma(firmaId).teme.filter { it.pitanja >= 30 }.map { it.tema } }.getOrDefault(emptyList()) - iskljuci.toSet() }
    DonjiList(zatvori) {
        Text(naslovL, style = naslov(26.sp))
        Text(podnaslov, style = tekst(14.sp, boja = Boje.sivaTekst))
        if (teme.isEmpty()) KSkelet(120.dp)
        teme.forEach { t ->
            val da = t in izabrane
            Text(t.replaceFirstChar { it.uppercase() }, style = tekst(15.sp, FontWeight.SemiBold, if (da) Boje.tinta else Boje.mastilo),
                modifier = Modifier.fillMaxWidth().background(if (da) Boje.zuta else Boje.kartica, RoundedCornerShape(14.dp)).border(1.dp, Boje.mastilo, RoundedCornerShape(14.dp))
                    .semantics { selected = da }.clickable(role = Role.Checkbox) { izabrane = if (da) izabrane - t else if (izabrane.size < izbor) izabrane + t else izabrane }.padding(12.dp))
        }
        Dugme("Potvrdi", omoguceno = izabrane.size == izbor) { gotovo(izabrane) }
    }
}

// ---------------- Prvi ulazak: priča ↔ izbor (KarijeraVodic) ----------------

@Composable
private fun IzborPozicije(s: Karijera.Stanje, nazad: () -> Unit, izaberi: (String, String, List<String>, List<String>) -> Unit) {
    var korak by remember { mutableStateOf(0) }
    var pozicija by remember { mutableStateOf<Karijera.Pozicija?>(null) }
    var pol by remember { mutableStateOf<String?>(null) }
    var pomoci by remember { mutableStateOf<List<String>>(emptyList()) }
    var talenti by remember { mutableStateOf<List<String>>(emptyList()) }
    BackHandler(korak > 0) { korak-- }
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        KNazad(if (korak == 0) "Nazad" else "Prethodni korak") { if (korak == 0) nazad() else korak-- }
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            repeat(10) { i -> Box(Modifier.width(18.dp).height(5.dp).background(if (i == korak) Boje.roze else if (i < korak) Boje.mastilo else Boje.kremTamnija, RoundedCornerShape(3.dp))) }
        }
        when (korak) {
            0, 2, 4, 6, 8 -> VodicStrana(KarijeraVodic.strane[korak / 2], pol == "z") { korak++ }
            1 -> {
                Text("Izaberi struku", style = naslov(30.sp))
                Text("Od nje zavise pitanja: 6 od 10 su iz tvoje struke. Posle probnog rada otvaraš svoj office.", style = tekst(15.sp, boja = Boje.sivaTekst))
                s.pozicije.chunked(2).forEach { red ->
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        red.forEach { p ->
                            val da = pozicija == p
                            Column(Modifier.weight(1f).heightIn(min = 104.dp).pop(if (da) Boje.zuta else Boje.kartica, 18.dp).semantics { selected = da }
                                .clickable(role = Role.RadioButton) { pozicija = p }.padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                Text(p.naziv, style = tekst(15.sp, FontWeight.Bold, if (da) Boje.tinta else Boje.mastilo), maxLines = 2)
                                Text(p.opis, style = tekst(12.sp, boja = if (da) Boje.tinta.copy(alpha = 0.75f) else Boje.sivaTekst), maxLines = 2)
                            }
                        }
                        if (red.size == 1) Spacer(Modifier.weight(1f))
                    }
                }
                Dugme("Dalje", omoguceno = pozicija != null) { korak = 2 }
            }
            3 -> {
                Text("Ko kreće u karijeru?", style = naslov(30.sp))
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    listOf(Triple("m", "Muško", "karijera_asistent_1"), Triple("z", "Žensko", "karijera_asistent_2")).forEach { (id, naziv, slika) ->
                        val da = pol == id
                        Column(Modifier.weight(1f).pop(if (da) Boje.zuta else Boje.kartica, 20.dp).semantics { selected = da }.clickable(role = Role.RadioButton) { pol = id }.padding(14.dp),
                            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            KSlika(slika, Modifier.height(200.dp))
                            Text(naziv, style = tekst(17.sp, FontWeight.Bold, if (da) Boje.tinta else Boje.mastilo))
                            pozicija?.let { Text(it.naziv(id), style = tekst(13.sp, boja = if (da) Boje.tinta else Boje.sivaTekst), maxLines = 1) }
                        }
                    }
                }
                Dugme("Dalje", omoguceno = pol != null) { korak = 4 }
            }
            5 -> {
                Text("Tvoje 4 pomoći", style = naslov(30.sp))
                Text("U svakoj rundi svaku možeš da iskoristiš jednom. Odgovor uz pomoć vredi manje i ne donosi ugled.", style = tekst(15.sp, boja = Boje.sivaTekst))
                Oznaka("IZABRANO ${pomoci.size} OD 4")
                Pomoci.sve.forEach { p ->
                    val da = p.id in pomoci
                    Column(Modifier.fillMaxWidth().pop(if (da) Boje.zuta else Boje.kartica, 16.dp).semantics { selected = da }
                        .clickable(role = Role.Checkbox) { pomoci = if (da) pomoci - p.id else if (pomoci.size < 4) pomoci + p.id else pomoci }.padding(12.dp)) {
                        Text(p.naziv, style = tekst(15.sp, FontWeight.Bold, if (da) Boje.tinta else Boje.mastilo))
                        Text(p.opis, style = tekst(13.sp, boja = if (da) Boje.tinta.copy(alpha = 0.75f) else Boje.sivaTekst))
                    }
                }
                Dugme("Dalje", omoguceno = pomoci.size == 4) { korak = 6 }
            }
            7 -> {
                Text("Tvoja 3 talenta", style = naslov(30.sp))
                Text("Pomažu ti celu igru. Na svakih 200 tačnih odgovora možeš da zameniš jedan.", style = tekst(15.sp, boja = Boje.sivaTekst))
                Oznaka("IZABRANO ${talenti.size} OD 3")
                (s.katalog_talenata ?: emptyList()).forEach { t ->
                    val da = t.id in talenti
                    Column(Modifier.fillMaxWidth().pop(if (da) Boje.zuta else Boje.kartica, 16.dp).semantics { selected = da }
                        .clickable(role = Role.Checkbox) { talenti = if (da) talenti - t.id else if (talenti.size < 3) talenti + t.id else talenti }.padding(12.dp)) {
                        Text(t.naziv, style = tekst(15.sp, FontWeight.Bold, if (da) Boje.tinta else Boje.mastilo))
                        Text(t.opis, style = tekst(13.sp, boja = if (da) Boje.tinta.copy(alpha = 0.75f) else Boje.sivaTekst))
                    }
                }
                Dugme("Dalje", omoguceno = talenti.size == 3) { korak = 8 }
            }
            else -> PrviDan(pozicija?.naziv(pol).orEmpty(), pol == "z") {
                val p = pozicija; val pl = pol
                if (p != null && pl != null) { KarijeraMuzika.stani(); Zvuk.pusti(Zvuk.Vrsta.KARIJERA_ZVONO, 0.6f); izaberi(p.id, pl, talenti, pomoci) }
            }
        }
    }
}

@Composable
private fun VodicStrana(strana: KarijeraVodic.Strana, zensko: Boolean, dalje: () -> Unit) {
    NaNebu(strana.slika, "korporacija")
    Text(strana.naslov, style = naslov(30.sp), modifier = Modifier.semantics { heading() })
    strana.pasusi.forEach { Text(Sef.oblik(it, zensko), style = tekst(16.sp)) }
    Dugme("Dalje") { dalje() }
}

@Composable
private fun PrviDan(pozicija: String, z: Boolean, prijava: () -> Unit) {
    LaunchedEffect(Unit) { KarijeraMuzika.pusti(Zvuk.Vrsta.KARIJERA_UVOD, 0.35f) }
    NaNebu("karijera_korporacija_1", "korporacija", visinaSlike = 210.dp)
    Text("Tvoj prvi dan", style = naslov(30.sp))
    Text("Dobrodošl${if (z) "a" else "i"} u Korporaciju. Od danas radiš kao ${pozicija.lowercase()}, na probnom radu.", style = tekst(16.sp))
    Text("Ovde radiš za drugog. Šef prati svaki tvoj odgovor: kad pogrešiš, čućeš da ${if (z) "si mogla" else "si mogao"} bolje, a kad pogodiš, pohvaliće te. Ni jedno ni drugo ne shvataj lično: svaka primedba je znak da se boriš još jače.", style = tekst(16.sp))
    Text("Kad položiš probni rad, dobijaš mogućnost da otvoriš svoju firmu. Onda ti ${if (z) "si šefica" else "si šef"}: zapošljavaš asistente (botove), a pravi igrači, ljudi kao ti, dolaze da rade kod tebe. Pazi: ti isti igrači mogu da ti preotmu firmu u duelu.", style = tekst(16.sp))
    Text("Važno: niko te ovde neće zaista vređati. Šef je šala na račun kancelarije, a nijedan vlasnik firme kroz Karijeru ne može da ti piše niti da te vređa. Cilj je samo zabava i učenje kroz pitanja.",
        style = tekst(16.sp, FontWeight.Bold), modifier = Modifier.fillMaxWidth().background(Boje.tealSvetla, RoundedCornerShape(16.dp)).padding(14.dp))
    Dugme("Prijavljujem se za posao", vrsta = VrstaDugmeta.ZUTO) { prijava() }
}

/** Velika kartica Karijere na početnoj. */
@Composable
fun KarijeraKarticaPocetna(otvori: () -> Unit) {
    Row(Modifier.fillMaxWidth().height(250.dp).pop(KarijeraBoje.plava).clickable(role = Role.Button, onClick = otvori).padding(start = 22.dp, end = 14.dp, bottom = 20.dp),
        verticalAlignment = Alignment.Bottom) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text("Karijera", style = naslov(36.sp, Color.White))
            Text("Od Korporacije do svog nebodera: probni rad, asistenti i duel za tuđu firmu.", style = tekst(13.sp, FontWeight.SemiBold, Color.White.copy(alpha = 0.9f)))
        }
        KSlika("karijera_zgrada_5_1", Modifier.width(110.dp).padding(top = 14.dp))
    }
}

/** DEBUG (`adb shell am start ... --ez karijeraProba true`): ekrani Karijere sa izmišljenim podacima, bez naloga. */
@Composable
fun KarijeraProba() {
    var ekran by remember { mutableStateOf(0) }
    val stanje = remember {
        Karijera.Stanje(pozicije = listOf(
            Karijera.Pozicija("lekar", "Lekar", "Medicina, anatomija, bolesti i ishrana.", "medicina", "", "Lekarka"),
            Karijera.Pozicija("advokat", "Advokat", "Pravo, ustav, suđenja i institucije.", "pravo", "", "Advokatica"),
            Karijera.Pozicija("programer", "Programer", "Računari, internet i tehnološke firme.", "it", "", "Programerka"),
        ), katalog_talenata = listOf(Karijera.Talenat("pregovarac", "Pregovarač", "+10% na svaku platu.", ""), Karijera.Talenat("stedisa", "Štediša", "Održavanje je 25% jeftinije.", ""),
            Karijera.Talenat("lider", "Lider", "+10% prometa od zaposlenih.", ""), Karijera.Talenat("brz_um", "Brz um", "+5 sekundi na svako pitanje.", "")))
    }
    val firma = remember { Karijera.Firma("proba", "Korporacija", true, udeo = "korporacija", nivo = 5, slobodni = listOf(6, 7), slobodan_danas = true) }
    var sef by remember { mutableStateOf(false) }
    Box(Modifier.fillMaxSize()) {
        Papir()
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            club.librum.kviz.ui.Izbor(listOf("Uvod", "Posle runde", "Šef", "Ometanja", "Grad", "Priprema"), ekran) { ekran = it }
            when (ekran) {
                0 -> IzborPozicije(stanje, {}) { _, _, _, _ -> }
                1 -> Box(Modifier.height(720.dp)) { IshodRunde(Karijera.IshodRunde(5, 125, true, 50.0, 0.0, 30, false, Karijera.Probni(1, 10, 5, danas = 1), 1, true), firma, {}) {} }
                2 -> { Dugme("Otvori podešavanje šefa") { sef = true }; FirmaKartica(firma, null, false) {} ; SefKaze(Sef.Povod.NETACNO, Sef.recenica(Sef.Povod.NETACNO, 3, false, false, true), "z_srednja") {} }
                4 -> {
                    val firme = (0 until 30).filter { it != 9 && it != 14 }.map { n -> GradFirma("p$n", listOf("Bit d.o.o.", "Lex Partneri", "Med Centar", "Kod i Kafa", "Atlas", "Kvant", "Most")[n % 7],
                        n == 3, 1 + (n * 7) % 5, 1 + (n * 5 + 3) % 8, "Igrač $n", n, if (n % 4 == 0) "+20 poena" else null) }
                    IsoGrad(Modifier.fillMaxWidth().height(560.dp), firme, setOf("p5"), "p8", null, null, {}) {}
                }
                5 -> { val k = androidx.compose.ui.platform.LocalContext.current; PripremaRunde(3, Zanimljivosti.sve(k).firstOrNull { it.vrsta == "trac" }, "karijera_trac_4") }
                else -> SefTekstovi.ometanja.filterIndexed { i, _ -> i % 12 == 0 }.forEach { o -> Box(Modifier.height(if (o.vrsta == Sef.Vrsta.ZADATAK) 320.dp else 90.dp)) { OmetanjeTraka(o, "korporacija") {} } }
            }
        }
        if (sef) SefList(Sef.Nivo(lik = "z_mlada"), { sef = false }) { sef = false }
    }
}
