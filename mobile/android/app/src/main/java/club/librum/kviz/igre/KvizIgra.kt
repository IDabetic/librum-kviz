package club.librum.kviz.igre

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.StarBorder
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import club.librum.kviz.servisi.Napredak
import club.librum.kviz.servisi.Pitanje
import club.librum.kviz.servisi.Prikaz
import club.librum.kviz.servisi.Sesija
import club.librum.kviz.ui.Boje
import club.librum.kviz.ui.Dugme
import club.librum.kviz.ui.Oznaka
import club.librum.kviz.ui.OdgovorDugme
import club.librum.kviz.ui.Papir
import club.librum.kviz.ui.PomociTraka
import club.librum.kviz.ui.StanjeOdgovora
import club.librum.kviz.ui.VrstaDugmeta
import club.librum.kviz.ui.naslov
import club.librum.kviz.ui.pop
import club.librum.kviz.ui.tekst
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** Pravila kviza po temi i Dnevnog izazova (kao iOS KlasicniKviz): 100 za tačan + 2 po preostaloj sekundi + 20 od trećeg tačnog zaredom. */
class KlasicniKviz {
    companion object {
        const val SEKUNDI = 15
        const val OSNOVNO = 100
        const val BRZINA_PO_SEKUNDI = 2
        const val NIZ_OD = 3
        const val BONUS_NIZA = 20

        /** 1 zvezdica za bar 40% tačnih, 2 za 70%, 3 za sve. */
        fun zvezdice(tacnih: Int, ukupno: Int): Int {
            if (ukupno == 0) return 0
            val deo = tacnih.toDouble() / ukupno
            return if (deo >= 1) 3 else if (deo >= 0.7) 2 else if (deo >= 0.4) 1 else 0
        }
    }

    var poeni = 0; private set
    var tacnih = 0; private set
    var netacnih = 0; private set
    var zbirMs = 0; private set
    private var niz = 0

    /** Vraća poene za ovaj odgovor (0 za netačan ili istek). */
    fun odgovor(p: Prikaz, izabran: Int?, ostaloSekundi: Int, ms: Int): Int {
        if (izabran != null) zbirMs += ms
        if (izabran != p.tacan) { niz = 0; netacnih++; return 0 }
        niz++; tacnih++
        val dobio = OSNOVNO + maxOf(0, ostaloSekundi) * BRZINA_PO_SEKUNDI + if (niz >= NIZ_OD) BONUS_NIZA else 0
        poeni += dobio
        return dobio
    }
}

/**
 * Klasičan kviz od 10 pitanja (Dnevni izazov; kasnije teme i Slikari): 15 s po pitanju, 4 pomoći, rezultat u rezultati_igara.
 * `igra` je ključ rang liste (npr. "dnevni").
 */
@Composable
fun KvizIgraEkran(sesija: Sesija, naslovKviza: String, igra: String, ucitaj: suspend () -> List<Pitanje>, izadji: () -> Unit) {
    val opseg = rememberCoroutineScope()
    var pitanja by remember { mutableStateOf<List<Prikaz>?>(null) }
    var greska by remember { mutableStateOf<String?>(null) }
    var indeks by remember { mutableIntStateOf(0) }
    var kviz by remember { mutableStateOf(KlasicniKviz()) }
    var izabran by remember { mutableStateOf<Int?>(null) }
    var otkriveno by remember { mutableStateOf(false) }
    var dobio by remember { mutableIntStateOf(0) }
    var pocetak by remember { mutableLongStateOf(System.currentTimeMillis()) }
    var dodatno by remember { mutableIntStateOf(0) }
    var sada by remember { mutableLongStateOf(System.currentTimeMillis()) }
    var eliminisani by remember { mutableStateOf(setOf<Int>()) }
    var pomocIskoriscena by remember { mutableStateOf(false) }
    var kraj by remember { mutableStateOf(false) }

    suspend fun pokreni() {
        greska = null; pitanja = null
        runCatching { ucitaj().filter { it.options.size == 4 && it.correct_answer in 0..3 }.take(10).map(Prikaz::od) }
            .onSuccess { if (it.isEmpty()) greska = "Pitanja nisu stigla." else { pitanja = it; indeks = 0; kviz = KlasicniKviz(); kraj = false; pomocIskoriscena = false
                izabran = null; otkriveno = false; eliminisani = emptySet(); dodatno = 0; pocetak = System.currentTimeMillis() } }
            .onFailure { greska = it.message }
    }
    fun sledece() {
        val l = pitanja ?: return
        if (indeks + 1 >= l.size) {
            kraj = true
            opseg.launch {
                val pomoc = Napredak.deljeni.pomocUPartiji
                val prosek = kviz.zbirMs / maxOf(1, kviz.tacnih + kviz.netacnih)
                Napredak.deljeni.zabeleziIgru(igra, kviz.tacnih, kviz.netacnih, prosekMs = prosek)
                sesija.upisiRezultat(igra, kviz.poeni, kviz.tacnih, kviz.netacnih, prosek, pomoc)
            }
            return
        }
        indeks++; izabran = null; otkriveno = false; eliminisani = emptySet(); dodatno = 0; pocetak = System.currentTimeMillis()
    }
    fun odgovori(i: Int?) {
        val p = pitanja?.getOrNull(indeks) ?: return
        if (otkriveno) return
        val ms = (System.currentTimeMillis() - pocetak).toInt()
        val ostalo = (KlasicniKviz.SEKUNDI + dodatno) - ms / 1000
        izabran = i; otkriveno = true
        dobio = kviz.odgovor(p, i, ostalo, ms)
        opseg.launch { delay(1800); sledece() }
    }

    LaunchedEffect(Unit) { pokreni() }
    LaunchedEffect(indeks, kraj, pitanja) {
        while (!kraj && pitanja != null) {
            sada = System.currentTimeMillis()
            if (!otkriveno && sada - pocetak >= (KlasicniKviz.SEKUNDI + dodatno) * 1000L) odgovori(null)
            delay(250)
        }
    }
    BackHandler(onBack = izadji)

    Box(Modifier.fillMaxSize()) {
        Papir()
        val l = pitanja
        when {
            greska != null -> GreskaKartica("Pitanja nisu stigla", greska.orEmpty(), izadji)
            l == null -> CircularProgressIndicator(Modifier.align(Alignment.Center), color = Boje.mastilo)
            kraj -> Column(Modifier.align(Alignment.Center).padding(20.dp).pop(Boje.zuta).padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
                val z = KlasicniKviz.zvezdice(kviz.tacnih, l.size)
                Row(Modifier.semantics(mergeDescendants = true) { contentDescription = "$z od 3 zvezdice" }) {
                    repeat(3) { i -> Icon(if (i < z) Icons.Rounded.Star else Icons.Rounded.StarBorder, null, tint = Boje.tinta) }
                }
                Text(naslovKviza, style = naslov(26.sp, Boje.tinta))
                Text("${kviz.poeni}", style = naslov(60.sp, Boje.tinta))
                Text("${kviz.tacnih} od ${l.size} tačno", style = tekst(16.sp, FontWeight.SemiBold, Boje.tinta))
                if (sesija.nalog.value == null) Text("Prijavi se da rezultat ode na rang listu.", style = tekst(14.sp, boja = Boje.tinta))
                if (igra != "dnevni") Dugme("Igraj ponovo") { opseg.launch { pokreni() } }
                Dugme("Nazad", vrsta = VrstaDugmeta.SEKUNDARNO, radnja = izadji)
            }
            else -> Column(Modifier.fillMaxSize().statusBarsPadding().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                val p = l[indeks]
                val ostalo = (((KlasicniKviz.SEKUNDI + dodatno) * 1000L - (sada - pocetak)) / 1000).coerceAtLeast(0)
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    KrugZatvori("Izađi", izadji)
                    Pokazatelj("Pitanje", "${indeks + 1}/${l.size}", Boje.kartica, Modifier.weight(1f))
                    Pokazatelj("Vreme", "$ostalo", if (ostalo < 5) Boje.crvenaSvetla else Boje.kartica, Modifier.weight(1f))
                    Pokazatelj("Poeni", "${kviz.poeni}", Boje.zuta, Modifier.weight(1f))
                }
                Column(Modifier.fillMaxWidth().pop(Boje.zuta).padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Oznaka(p.zanr ?: naslovKviza, Boje.tinta)
                    Text(p.tekst, style = naslov(23.sp, Boje.tinta))
                    p.opcije.forEachIndexed { i, o ->
                        val stanje = when {
                            !otkriveno -> if (i in eliminisani) StanjeOdgovora.BLEDO else StanjeOdgovora.OBICNO
                            i == p.tacan -> StanjeOdgovora.TACNO
                            i == izabran -> StanjeOdgovora.NETACNO
                            else -> StanjeOdgovora.BLEDO
                        }
                        OdgovorDugme("ABCD"[i].toString(), o, stanje, omoguceno = !otkriveno && i !in eliminisani) { odgovori(i) }
                    }
                    if (otkriveno) Text(if (izabran == p.tacan) "Tačno! +$dobio" else if (izabran == null) "Isteklo vreme." else "Netačno.",
                        style = tekst(16.sp, FontWeight.Bold, if (izabran == p.tacan) Boje.teal else Boje.crvena))
                }
                if (!otkriveno) PomociTraka(pomocIskoriscena,
                    { eliminisani = (0 until 4).filter { it != p.tacan }.shuffled().take(2).toSet() },
                    { (0 until 4).filter { it != p.tacan && it !in eliminisani }.randomOrNull()?.let { eliminisani = eliminisani + it } },
                    { dodatno += 10 }, { sledece() }) { pomocIskoriscena = true }
                Spacer(Modifier.padding(20.dp))
            }
        }
    }
}
