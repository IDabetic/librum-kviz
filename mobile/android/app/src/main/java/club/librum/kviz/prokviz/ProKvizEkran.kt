package club.librum.kviz.prokviz

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import club.librum.kviz.servisi.Fond
import club.librum.kviz.servisi.PaketPitanja
import club.librum.kviz.servisi.Prikaz
import club.librum.kviz.servisi.Sesija
import club.librum.kviz.servisi.Spil
import club.librum.kviz.servisi.Supabase
import club.librum.kviz.ui.Boje
import club.librum.kviz.ui.Dijalog
import club.librum.kviz.ui.Dugme
import club.librum.kviz.ui.Maskota
import club.librum.kviz.ui.MaskotaSlika
import club.librum.kviz.ui.Oznaka
import club.librum.kviz.ui.Papir
import club.librum.kviz.ui.PitanjeKartica
import club.librum.kviz.ui.VrstaDugmeta
import club.librum.kviz.ui.mirna
import club.librum.kviz.ui.naslov
import club.librum.kviz.ui.pop
import club.librum.kviz.ui.tekst
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** Survival igre sa 10 života: PRO kviz (opšti fond, Risk) i Book kviz (književnost). */
enum class Survival(val fond: Fond, val tabela: String, val imaRisk: Boolean, val maskota: Maskota) {
    PRO(Fond.OPSTE, "survivor_sessions", true, Maskota.LUMI),
    BOOK(Fond.BOOK, "book_sessions", false, Maskota.ZIG),
}

/** PRO i Book kviz: 10 života, survival, rezultat ide na rang listu za prijavljene. */
@Composable
fun ProKvizEkran(sesija: Sesija, vrsta: Survival = Survival.PRO, izadji: () -> Unit) {
    val kontekst = LocalContext.current.applicationContext
    val opseg = rememberCoroutineScope()
    var igra by remember { mutableStateOf(ProKviz()) }
    var osvezi by remember { mutableIntStateOf(0) }
    var spil by remember { mutableStateOf<Spil?>(null) }
    var pitanje by remember { mutableStateOf<Prikaz?>(null) }
    var sekundi by remember { mutableIntStateOf(ProKviz.SEKUNDI) }
    var eliminisani by remember { mutableStateOf(emptySet<Int>()) }
    var poruka by remember { mutableStateOf<String?>(null) }
    var greska by remember { mutableStateOf<String?>(null) }
    var pocetak by remember { mutableStateOf(System.currentTimeMillis()) }
    var sacuvano by remember { mutableStateOf(false) }
    var potvrdaIzlaska by remember { mutableStateOf(false) }
    BackHandler { potvrdaIzlaska = true }

    fun sledece() { eliminisani = emptySet(); sekundi = ProKviz.SEKUNDI; pitanje = spil?.sledece(); osvezi++ }
    fun javi(t: String) { poruka = t; opseg.launch { delay(2500); if (poruka == t) poruka = null } }

    suspend fun sacuvaj() {
        if (sacuvano || igra.stigao == 0) return
        val id = sesija.nalog.value?.id ?: return
        val token = sesija.vazeciToken() ?: return
        sacuvano = true
        val sekundi = ((System.currentTimeMillis() - pocetak) / 1000).toInt()
        runCatching { Supabase.upisi(vrsta.tabela, if (vrsta == Survival.PRO) igra.red(id, sekundi) else igra.redBook(id, sekundi), token) }
    }

    suspend fun ucitaj(ponovo: Boolean = false) {
        runCatching {
            if (spil == null || ponovo) spil = Spil(PaketPitanja(kontekst).ucitaj(vrsta.fond))
            if (ponovo) { igra = ProKviz(); sacuvano = false; pocetak = System.currentTimeMillis() }
            if (vrsta == Survival.BOOK) igra.porukaZa50 = "Književni majstor!"
            sledece()
        }.onFailure { greska = it.message }
    }

    LaunchedEffect(Unit) { ucitaj() }
    // ProKviz nije Compose stanje: `osvezi` se čita ovde (ključ efekta), pa svaka promena igre ponovo crta ekran.
    LaunchedEffect(igra.gotovo, osvezi) { if (igra.gotovo) sacuvaj() }

    Box(Modifier.fillMaxSize()) {
        Papir()
        val p = pitanje
        when {
            greska != null -> Column(Modifier.align(Alignment.Center).padding(24.dp).mirna().padding(24.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                Text("Pitanja nisu stigla", style = naslov(26.sp))
                Text(greska.orEmpty(), style = tekst(15.sp, boja = Boje.sivaTekst))
                Dugme("Nazad", radnja = izadji)
            }
            igra.gotovo -> Column(
                Modifier.align(Alignment.Center).padding(20.dp).pop().padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                MaskotaSlika(vrsta.maskota, 120.dp)
                Text("Kraj igre", style = naslov(36.sp))
                Text("${igra.poeni}", style = naslov(64.sp))
                Text("${igra.stigao} pitanja · ${igra.tacnih} tačnih · najbolji niz ${igra.najboljiKombo}", style = tekst(15.sp, FontWeight.SemiBold, Boje.sivaTekst))
                if (sesija.nalog.value == null) Text("Prijavi se da rezultat ode na rang listu.", style = tekst(14.sp, boja = Boje.sivaTekst))
                Dugme("Igraj ponovo", vrsta = VrstaDugmeta.ZUTO) { opseg.launch { ucitaj(ponovo = true) } }
                Dugme("Nazad", vrsta = VrstaDugmeta.SEKUNDARNO, radnja = izadji)
            }
            p == null -> CircularProgressIndicator(Modifier.align(Alignment.Center), color = Boje.mastilo)
            else -> Column(
                Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                    IconButton(onClick = { potvrdaIzlaska = true }, modifier = Modifier.size(44.dp).background(Color.White, CircleShape).border(1.5.dp, Boje.kremTamnija, CircleShape)) {
                        Icon(Icons.Rounded.Close, contentDescription = "Prekini", tint = Boje.mastilo)
                    }
                    Pokazatelj("Životi", igra.zivoti, if (igra.zivoti <= 3) Boje.crvenaSvetla else Color.White, Modifier.weight(1f))
                    Pokazatelj("Poeni", igra.poeni, Boje.zuta, Modifier.weight(1f))
                    Pokazatelj("Niz", igra.kombo, Boje.tealSvetla, Modifier.weight(1f))
                }
                if (igra.riskAktivan) Text("Risk aktivan: duplo dobit, duplo gubitak", style = tekst(14.sp, FontWeight.Bold),
                    modifier = Modifier.fillMaxWidth().pop(Boje.zuta, 14.dp).padding(12.dp))
                PitanjeKartica(p.zanr?.let { "Pitanje ${igra.stigao + 1} · $it" } ?: "Pitanje ${igra.stigao + 1}", p, sekundi = sekundi, eliminisani = eliminisani) { izabran, _ ->
                    igra.odgovor(izabran == p.tacan)?.let(::javi)
                    osvezi++
                    if (!igra.gotovo) sledece()
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Pomoc("50/50", "${igra.polaPola}×", igra.polaPola > 0 && eliminisani.isEmpty(), Modifier.weight(1f)) {
                        if (igra.iskoristiPolaPola()) eliminisani = (0..3).filter { it != p.tacan }.shuffled().take(2).toSet()
                    }
                    Pomoc("Preskoči", "${igra.preskoci}×", igra.preskoci > 0, Modifier.weight(1f)) { if (igra.iskoristiPreskok()) sledece() }
                    Pomoc("+15 s", "${igra.dodatnoVreme}×", igra.dodatnoVreme > 0 && sekundi == ProKviz.SEKUNDI, Modifier.weight(1f)) {
                        if (igra.iskoristiVreme()) { sekundi += 15; osvezi++ }
                    }
                    if (vrsta.imaRisk) Pomoc("Risk", "×2", igra.riskDostupan, Modifier.weight(1f)) { igra.aktivirajRisk(); osvezi++ }
                }
            }
        }
        poruka?.let {
            Text(it, style = tekst(15.sp, FontWeight.Bold), modifier = Modifier.align(Alignment.TopCenter).statusBarsPadding().padding(top = 70.dp, start = 24.dp, end = 24.dp).pop(Boje.zuta, 16.dp).padding(horizontal = 18.dp, vertical = 12.dp))
        }
        if (potvrdaIzlaska) Dijalog(
            "Prekidaš partiju?",
            if (sesija.nalog.value != null) "Rezultat do sada se upisuje na rang listu." else "Rezultat se ne čuva bez naloga.",
            "Prekini", "Nastavi",
            potvrdi = { opseg.launch { sacuvaj(); izadji() } },
            zatvori = { potvrdaIzlaska = false },
        )
    }
}

@Composable
private fun Pokazatelj(naziv: String, vrednost: Int, boja: Color, modifier: Modifier) {
    Column(
        modifier.background(boja, RoundedCornerShape(14.dp)).border(1.5.dp, Boje.mastilo, RoundedCornerShape(14.dp)).padding(vertical = 8.dp)
            .semantics(mergeDescendants = true) {},
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("$vrednost", style = naslov(20.sp))
        Oznaka(naziv)
    }
}

@Composable
private fun Pomoc(naziv: String, ostalo: String, aktivno: Boolean, modifier: Modifier, radnja: () -> Unit) {
    Column(
        modifier.heightIn(min = 52.dp)
            .background(if (aktivno) Color.White else Boje.kremTamnija, RoundedCornerShape(14.dp))
            .border(1.5.dp, if (aktivno) Boje.mastilo else Color.Transparent, RoundedCornerShape(14.dp))
            .clickable(enabled = aktivno, role = Role.Button, onClick = radnja)
            .padding(vertical = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(naziv, style = tekst(13.sp, FontWeight.Bold))
        Text(ostalo, style = tekst(11.sp, boja = Boje.sivaTekst))
    }
}
