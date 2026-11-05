package club.librum.kviz.karijera

import androidx.compose.material3.Icon
import androidx.compose.material.icons.rounded.RadioButtonUnchecked
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.MusicNote
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
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
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import club.librum.kviz.servisi.Zvuk
import club.librum.kviz.ui.Boje
import club.librum.kviz.ui.Dugme
import club.librum.kviz.ui.Oznaka
import club.librum.kviz.ui.Papir
import club.librum.kviz.ui.PitanjeKartica
import club.librum.kviz.ui.VrstaDugmeta
import club.librum.kviz.ui.mirna
import club.librum.kviz.ui.naslov
import club.librum.kviz.ui.pop
import club.librum.kviz.ui.tekst
import androidx.compose.material.icons.rounded.Share
import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.random.Random

private const val SEKUNDI = 20

/**
 * Niz pitanja Karijere (prenos iOS KarijeraPitanjaView): runda (10) ili duel (30). Kartica je plava i stoji preko officea na nebu;
 * posle odgovora kartica ode, vidi se office i šef. Pomoći: 4 izabrane (svaka jednom po rundi) i asistenti firme.
 */
@Composable
private fun KarijeraPitanja(
    pitanja: List<Karijera.Pitanje>, firmaId: String? = null, izazovId: String? = null, sef: Boolean = false, sefNivo: Sef.Nivo = Sef.Nivo(),
    pomoci: List<String> = Karijera.mojePomoci, botovi: List<Karijera.Bot> = emptyList(), pozadina: String, mesto: String,
    gotovo: (List<Map<String, Any?>>) -> Unit,
) {
    val prikazi = remember(pitanja) { pitanja.map { it.zaPrikaz } }
    var i by remember { mutableIntStateOf(0) }
    var kartica by remember { mutableStateOf(true) }
    val odgovori = remember { mutableStateListOf<Map<String, Any?>>() }
    var eliminisani by remember { mutableStateOf(setOf<Int>()) }
    var savet by remember { mutableStateOf<String?>(null) }
    val iskoriscene = remember { mutableStateOf(mapOf<String, Int>()) }
    var pomocNaPitanju by remember { mutableStateOf<String?>(null) }
    var sefPoruka by remember { mutableStateOf<Pair<Sef.Povod, String>?>(null) }
    var cekaBota by remember { mutableStateOf(false) }
    var dodatno by remember { mutableIntStateOf(0) }
    var satStoji by remember { mutableStateOf(false) }
    var raspored by remember { mutableStateOf(setOf<Int>()) }
    var velikoNa by remember { mutableStateOf<Int?>(null) }
    var ometanje by remember { mutableStateOf<Sef.Ometanje?>(null) }
    var izabranoNa by remember { mutableStateOf<Int?>(null) }
    val opseg = rememberCoroutineScope()
    val talenti = Karijera.mojiTalenti
    val sekundi = SEKUNDI + (if ("brz_um" in talenti) 5 else 0) + dodatno
    val slova = "ABCD"

    fun prviUtisak() {
        if ("prvi_utisak" !in talenti || i % 10 != 0 || i >= prikazi.size) return
        eliminisani = (0..3).filter { it != prikazi[i].tacan }.shuffled().take(2).toSet()
        savet = "Prvi utisak: dva odgovora su sklonjena."
    }

    // Ometanja: najviše jedno po pitanju, nikad u poslednjih 7 s, sat ne staje; veliko (zadatak/haos) najviše jednom u rundi.
    LaunchedEffect(i, kartica) {
        if (!kartica || !sef || sefNivo.ometanja == 0 || i >= pitanja.size) return@LaunchedEffect
        if (i % 10 == 0) {
            raspored = Sef.rasporedOmetanja(sefNivo.ometanja).map { it + i }.toSet()
            velikoNa = Sef.velikoPitanje(sefNivo.ometanja, raspored)
        }
        if (i !in raspored) return@LaunchedEffect
        val pitanjeSada = i
        delay((Random.nextDouble(2.0, maxOf(2.5, sekundi - 7.0)) * 1000).toLong())
        if (pitanjeSada != i || !kartica || odgovori.size != i || izabranoNa == i) return@LaunchedEffect
        val o = Sef.ometanje(sefNivo.ometanja, velikoNa == pitanjeSada)
        ometanje = o
        Zvuk.pusti(Zvuk.Vrsta.PORUKA)
        when (o.vrsta) {
            Sef.Vrsta.UPAD -> { delay(1500); if (ometanje == o) ometanje = null }
            Sef.Vrsta.HAOS -> { delay(1800); if (ometanje == o) ometanje = null }
            Sef.Vrsta.ZADATAK -> {}
        }
    }
    LaunchedEffect(Unit) { prviUtisak() }

    fun sledece() {
        if (odgovori.size != i + 1) return
        sefPoruka = null; savet = null; eliminisani = emptySet(); pomocNaPitanju = null; dodatno = 0; satStoji = false
        if (i + 1 >= pitanja.size) gotovo(odgovori.toList()) else { i++; kartica = true; prviUtisak() }
    }

    fun odgovori(izabran: Int?, ms: Int) {
        val q = pitanja[i]; val p = prikazi[i]
        odgovori += buildMap { put("id", q.id); put("izbor", q.izvorni(izabran, p)); put("ms", ms); pomocNaPitanju?.let { put("pomoc", it) } }
        kartica = false; ometanje = null
        val povod = if (izabran == null) Sef.Povod.ISTEKLO else if (izabran == p.tacan) Sef.Povod.TACNO else Sef.Povod.NETACNO
        val jacina = sefNivo.jacina(povod)
        if (sef && jacina > 0) sefPoruka = povod to Sef.recenica(povod, jacina, sefNivo.smeh, Karijera.mojPol == "z", Sef.lik(sefNivo.lik).zensko)
        val pitanjeSada = i
        opseg.launch { delay(if (sefPoruka != null) 2700 else 1300); if (pitanjeSada == i) sledece() }
    }

    fun pomoc(pm: KarijeraPomoc) {
        if (i >= prikazi.size || pomocNaPitanju != null) return
        val p = prikazi[i]; val pitanjeSada = i
        iskoriscene.value = iskoriscene.value + (pm.id to (iskoriscene.value[pm.id] ?: 0) + 1)
        pomocNaPitanju = pm.id
        val bonus = if ("istrazivac" in talenti) 0.1 else 0.0
        fun posle(s: Double, radnja: () -> Unit) {
            val cekaj = if ("intuicija" in talenti) 0.0 else s
            if (cekaj == 0.0) radnja() else opseg.launch { delay((cekaj * 1000).toLong()); if (pitanjeSada == i) radnja() }
        }
        val poruke = mutableListOf<String>()
        for (e in pm.efekti) when (e) {
            is KarijeraPomoc.Efekat.Ukloni -> {
                val netacni = (0..3).filter { it != p.tacan && it !in eliminisani }.shuffled().take(e.n)
                if (e.kasnjenje > 0) poruke += "Za ${e.kasnjenje.toInt()} s nestaje ${if (e.n == 1) "jedan netačan" else "${e.n} netačna"}."
                posle(e.kasnjenje) { eliminisani = eliminisani + netacni }
            }
            is KarijeraPomoc.Efekat.Vreme -> { dodatno += e.s; poruke += "+${e.s} s" }
            KarijeraPomoc.Efekat.SatStoji -> { satStoji = true; poruke += "Sat stoji." }
            KarijeraPomoc.Efekat.Otkrij -> { eliminisani = (0..3).filter { it != p.tacan }.toSet(); poruke += "Insajder: tačan je ${slova[p.tacan]}." }
            is KarijeraPomoc.Efekat.Savet -> {
                val pogodak = if (Random.nextDouble() < minOf(0.98, e.p + bonus)) p.tacan else (0..3).filter { it != p.tacan }.random()
                if (e.kasnjenje > 0 && "intuicija" !in talenti) poruke += "${pm.naziv}: stiže za ${e.kasnjenje.toInt()} s…"
                posle(e.kasnjenje) { savet = "${pm.naziv}: ${slova[pogodak]}." }
            }
            is KarijeraPomoc.Efekat.Anketa -> {
                val glavni = if (Random.nextDouble() < minOf(0.98, e.p + bonus)) p.tacan else (0..3).filter { it != p.tacan }.random()
                val g = (0..3).map { if (it == glavni) (45..65).random() else (3..20).random() }
                val zbir = g.sum()
                poruke += (0..3).joinToString(" · ") { "${slova[it]} ${g[it] * 100 / zbir}%" }
            }
            KarijeraPomoc.Efekat.PrvoSlovo -> {
                // Prvo pravo slovo (preskače navodnike i zagrade); „Prvo slovo: H”, a u Brainstormingu „prvo slovo je H.”
                val slovo = p.opcije[p.tacan].firstOrNull { it.isLetterOrDigit() }?.uppercase() ?: "?"
                poruke += if (pm.naziv == "Prvo slovo") slovo else "prvo slovo je $slovo."
            }
        }
        if (poruke.isNotEmpty()) savet = "${pm.naziv}: " + poruke.joinToString(" ")
    }

    fun pomocBota(bot: Karijera.Bot) {
        if (i >= pitanja.size || pomocNaPitanju != null) return
        val q = pitanja[i]; val p = prikazi[i]; val pitanjeSada = i
        cekaBota = true
        opseg.launch {
            runCatching { Karijera.pomocBota(firmaId, q.id, izazovId) }.onSuccess { o ->
                if (pitanjeSada != i) return@onSuccess
                val izPrikaza = q.options.getOrNull(o.izbor)?.let { p.opcije.indexOf(it) }?.takeIf { it >= 0 }
                pomocNaPitanju = "bot"
                savet = "${o.bot} (${o.tema}): ${izPrikaza?.let { slova[it].toString() } ?: "?"}, ${o.sigurnost}% siguran."
            }.onFailure { savet = it.message }
            cekaBota = false
        }
    }

    val tresi = rememberInfiniteTransition(label = "tresi").animateFloat(-9f, 9f, infiniteRepeatable(tween(70), RepeatMode.Reverse), label = "t")
    Box(Modifier.fillMaxWidth().heightIn(min = 560.dp)) {
        // Scena: nebo i office; dok je kartica gore, scena je prigušena.
        Box(Modifier.matchParentSize().clip(RoundedCornerShape(28.dp)).border(2.dp, Boje.mastilo, RoundedCornerShape(28.dp)), contentAlignment = Alignment.BottomCenter) {
            Nebo(Modifier.matchParentSize(), mesto)
            KSlika(pozadina, Modifier.heightIn(max = 440.dp).padding(horizontal = 10.dp))
            Ulica(Modifier.matchParentSize(), mesto)
            if (kartica) Box(Modifier.matchParentSize().background(Color.Black.copy(alpha = 0.3f)))
        }
        Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            if (i < prikazi.size && kartica) {
                val p = pitanja[i]
                if (p.runda != null && i % 10 == 0) Text("Runda ${p.runda} · ${p.tema?.replaceFirstChar { it.uppercase() }.orEmpty()}", style = naslov(20.sp, Color.White), modifier = Modifier.padding(horizontal = 4.dp))
                savet?.let { Text(it, style = tekst(15.sp, FontWeight.Bold, Boje.tinta), modifier = Modifier.fillMaxWidth().pop(Boje.zuta, 14.dp).padding(12.dp)) }
                val o = ometanje
                val haos = o?.vrsta == Sef.Vrsta.HAOS
                Box {
                    Box(Modifier.offset(x = if (haos && o?.trese == true) tresi.value.dp else 0.dp).blur(if (haos && o?.trese == false) 7.dp else 0.dp)) {
                        androidx.compose.runtime.key(i) {
                            PitanjeKartica("Pitanje ${i + 1} od ${pitanja.size}${p.tema?.let { " · $it" }.orEmpty()}", prikazi[i], sekundi, eliminisani = eliminisani,
                                stoji = satStoji, boja = Boje.nebo, izabrano = { izabranoNa = i; ometanje = null }) { izabran, ms -> odgovori(izabran, ms) }
                        }
                    }
                    if (o != null) Box(Modifier.matchParentSize()) { OmetanjeTraka(o, sefNivo.lik) { ometanje = null } }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    pomoci.mapNotNull { Pomoci.po(it) }.forEach { pm ->
                        val limit = if (pm.id == pomoci.firstOrNull() && "kolega_plus" in talenti) 2 else 1
                        val moze = (iskoriscene.value[pm.id] ?: 0) < limit && pomocNaPitanju == null
                        Box(Modifier.weight(1f).height(54.dp).background(Boje.kartica, RoundedCornerShape(16.dp)).border(2.dp, Boje.mastilo, RoundedCornerShape(16.dp))
                            .semantics { contentDescription = "${pm.naziv}: ${pm.opis}" }.clickable(enabled = moze, role = Role.Button) { pomoc(pm) },
                            contentAlignment = Alignment.Center) {
                            Text(pm.naziv.take(2).uppercase(), style = tekst(15.sp, FontWeight.Black, if (moze) Boje.mastilo else Boje.sivaTekst))
                        }
                    }
                    if (botovi.isNotEmpty()) {
                        val bot = botovi.firstOrNull { it.tema == p.tema && it.pomoci_ostalo > 0 } ?: if (izazovId != null) botovi.firstOrNull { it.tema == p.tema } else null
                        val moze = bot != null && pomocNaPitanju == null && !cekaBota
                        Box(Modifier.weight(1f).height(54.dp).background(Boje.kartica, RoundedCornerShape(16.dp)).border(2.dp, Boje.mastilo, RoundedCornerShape(16.dp))
                            .semantics { contentDescription = bot?.let { "Pitaj asistenta ${it.ime}, tema ${it.tema}" } ?: "Nijedan asistent ne zna ovu temu" }
                            .clickable(enabled = moze, role = Role.Button) { bot?.let { pomocBota(it) } }, contentAlignment = Alignment.Center) {
                            KSlika(bot?.slika ?: "karijera_asistent_1", Modifier.height(40.dp))
                        }
                    }
                }
            }
            Spacer(Modifier.weight(1f, fill = false))
        }
        sefPoruka?.let { (povod, t) -> Box(Modifier.align(Alignment.BottomCenter).padding(8.dp)) { SefKaze(povod, t, sefNivo.lik) { sledece() } } }
    }
}

private sealed interface Faza { data object Ucitava : Faza; data class Greska(val p: String) : Faza; data class Igra(val p: List<Karijera.Pitanje>) : Faza
    data object Salje : Faza; data class Ishod(val o: Karijera.IshodRunde) : Faza }

/** Jedna runda u firmi: 10 pitanja, pa obračun sa servera. */
@Composable
fun RundaEkran(firma: Karijera.Firma, probni: Boolean, botovi: List<Karijera.Bot>, ja: String?, nazad: () -> Unit) {
    var faza by remember { mutableStateOf<Faza>(Faza.Ucitava) }
    var pokusaj by remember { mutableIntStateOf(0) }
    val opseg = rememberCoroutineScope()
    DisposableEffect(Unit) { onDispose { KarijeraMuzika.stani() } }
    // Odbrojavanje pre runde (vlasnik 05.11): 4 s sa zanimljivošću, pitanja se učitavaju u međuvremenu.
    val kontekst = androidx.compose.ui.platform.LocalContext.current
    var priprema by remember { mutableIntStateOf(PRIPREMA_SEKUNDI) }
    // Potvrda izlaska usred runde (vlasnik 05.11: napuštena runda = 0 tačnih).
    var izlaz by remember { mutableStateOf(false) }
    var muzikaList by remember { mutableStateOf(false) }
    var izabranaMuzika by remember { mutableStateOf(KarijeraMuzika.izabrana) }
    var zanimljivost by remember { mutableStateOf<Zanimljivost?>(null) }
    var tracSlika by remember { mutableStateOf("karijera_trac_1") }
    LaunchedEffect(pokusaj) {
        faza = Faza.Ucitava
        zanimljivost = Zanimljivosti.sve(kontekst).randomOrNull()
        tracSlika = "karijera_trac_${(1..Zanimljivosti.BROJ_SLIKA).random()}"
        val stigla = kotlinx.coroutines.coroutineScope {
            val posao = async { runCatching { Karijera.pitanjaRunde(firma.id) } }
            for (s in PRIPREMA_SEKUNDI downTo 1) { priprema = s; delay(1000) }
            posao.await()
        }
        stigla.onSuccess { p ->
            faza = if (p.size == 10) Faza.Igra(p) else Faza.Greska("Stiglo je ${p.size} od 10 pitanja. Pokušaj ponovo.")
            if (p.size == 10) {
                val m = if (firma.korporacija) Zvuk.Vrsta.KARIJERA_KORPORACIJA else if (firma.vlasnik == ja) KarijeraMuzika.mojaFirmaIzbor(firma.id) else Zvuk.Vrsta.KARIJERA_POSAO
                if (m != null) KarijeraMuzika.pusti(m) else KarijeraMuzika.stani()
            }
        }.onFailure { faza = Faza.Greska(it.message ?: "Greška") }
    }
    Box(Modifier.fillMaxSize()) {
        Papir()
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                KNazad("Prekini rundu") { if (faza is Faza.Igra) izlaz = true else nazad() }
                Column {
                    Text(firma.ime, style = naslov(20.sp), maxLines = 1)
                    Text((if (probni) "Probni rad" else firma.udeoNaziv) + if (firma.slobodan_danas == true) " · slobodan dan, prekovremeno +10%" else "",
                        style = tekst(13.sp, FontWeight.SemiBold, Boje.sivaTekst), maxLines = 1)
                }
                // Svoja firma: vlasnik bira muziku runde gore desno (vlasnik 05.11).
                if (!firma.korporacija && firma.vlasnik == ja) {
                    Spacer(Modifier.weight(1f))
                    Box(Modifier.size(44.dp).background(Boje.kartica, androidx.compose.foundation.shape.CircleShape)
                        .border(1.5.dp, Boje.kremTamnija, androidx.compose.foundation.shape.CircleShape).clickable { muzikaList = true },
                        contentAlignment = Alignment.Center) {
                        Icon(androidx.compose.material.icons.Icons.Rounded.MusicNote, contentDescription = "Muzika", tint = Boje.mastilo)
                    }
                }
            }
            when (val f = faza) {
                Faza.Ucitava -> PripremaRunde(priprema, zanimljivost, tracSlika)
                Faza.Salje -> { KSkelet(380.dp); KSkelet(54.dp) }
                is Faza.Greska -> KGreska(f.p) { pokusaj++ }
                is Faza.Igra -> KarijeraPitanja(f.p, firmaId = firma.id, sef = firma.vlasnik != ja, sefNivo = firma.sefNivo.mirno(Karijera.mirni), botovi = botovi,
                    pozadina = firma.slika, mesto = if (firma.korporacija) "korporacija" else firma.id) { odg ->
                    faza = Faza.Salje; KarijeraMuzika.stani()
                    opseg.launch {
                        runCatching { Karijera.zavrsiRundu(firma.id, odg) }.onSuccess { o ->
                            faza = Faza.Ishod(o)
                            when {
                                (o.probni?.ishod ?: -1) >= 0 -> Zvuk.pusti(Zvuk.Vrsta.KARIJERA_UNAPREDJENJE)
                                o.rekord -> Zvuk.pusti(Zvuk.Vrsta.KARIJERA_REKORD)
                                o.tacnih >= 7 -> Zvuk.pusti(Zvuk.Vrsta.KARIJERA_USPEH, 0.45f)
                            }
                            if (o.plata > 0) { delay(1200); Zvuk.pusti(Zvuk.Vrsta.KARIJERA_KASA, 0.5f) }
                        }.onFailure { faza = Faza.Greska(it.message ?: "Greška") }
                    }
                }
                is Faza.Ishod -> IshodRunde(f.o, firma, { pokusaj++ }) { nazad() }
            }
        }
        val igra = faza as? Faza.Igra
        if (muzikaList) club.librum.kviz.ui.DonjiList({ muzikaList = false }) {
            Text("Muzika u firmi", style = naslov(26.sp))
            KarijeraMuzika.izbor.forEach { (k, naziv) ->
                Row(Modifier.fillMaxWidth().clickable {
                    KarijeraMuzika.izabrana = k; izabranaMuzika = k
                    KarijeraMuzika.mojaFirmaIzbor(firma.id)?.let { KarijeraMuzika.pusti(it) } ?: KarijeraMuzika.stani()
                }.padding(vertical = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Icon(if (izabranaMuzika == k) androidx.compose.material.icons.Icons.Rounded.CheckCircle else androidx.compose.material.icons.Icons.Rounded.RadioButtonUnchecked,
                        contentDescription = null, tint = if (izabranaMuzika == k) Boje.teal else Boje.kremTamnija)
                    Text(naziv, style = tekst(16.sp, FontWeight.SemiBold))
                }
            }
        }
        if (izlaz && igra != null) club.librum.kviz.ui.Dijalog("Napustiti rundu?", "Ako izađeš sada, runda se računa kao 0 tačnih od 10, a plaćena runda se troši.", "Izađi", "Nastavi",
            potvrdi = {
                izlaz = false; KarijeraMuzika.stani()
                // Napuštena runda ide kao 10 netačnih odgovora (0 tačnih), da izlazak ne bude način da se izbegne loša runda.
                opseg.launch { runCatching { Karijera.zavrsiRundu(firma.id, igra.p.map { mapOf("id" to it.id, "izbor" to -1, "ms" to 20_000) }) }; nazad() }
            }, zatvori = { izlaz = false })
    }
    androidx.activity.compose.BackHandler(enabled = faza is Faza.Igra) { izlaz = true }
}

/** Posle runde: rezultat na plavoj kartici sa zgradom, brojke u jednom redu, dugmad na dnu. */
@Composable
internal fun IshodRunde(o: Karijera.IshodRunde, firma: Karijera.Firma, dalje: () -> Unit, kuci: () -> Unit) {
    val imaSledecu = o.probni?.let { it.ishod == null && (it.danas ?: 0) < Karijera.PROBNI_DNEVNO } ?: true
    Column(Modifier.fillMaxSize()) {
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            val ocena = when { o.tacnih >= 9 -> "Odlična runda"; o.tacnih >= 7 -> "Dobra runda"; o.tacnih >= 5 -> "Solidno"; else -> "Teška runda" }
            Row(Modifier.fillMaxWidth().background(KarijeraBoje.plava, RoundedCornerShape(24.dp)).border(2.dp, Boje.mastilo, RoundedCornerShape(24.dp))
                .semantics(mergeDescendants = true) { contentDescription = "${o.tacnih} od 10 tačnih. $ocena" }, verticalAlignment = Alignment.Bottom) {
                Column(Modifier.weight(1f).padding(18.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(ocena, style = tekst(14.sp, FontWeight.Bold, Color.White.copy(alpha = 0.85f)))
                    Row(verticalAlignment = Alignment.Bottom) {
                        Text("${o.tacnih}", style = naslov(64.sp, Color.White))
                        Text(" / 10", style = naslov(24.sp, Color.White.copy(alpha = 0.8f)), modifier = Modifier.padding(bottom = 10.dp))
                    }
                    Text("tačnih odgovora", style = tekst(15.sp, FontWeight.SemiBold, Color.White.copy(alpha = 0.9f)))
                }
                Box(Modifier.padding(10.dp).width(130.dp).height(150.dp).clip(RoundedCornerShape(18.dp)), contentAlignment = Alignment.BottomCenter) {
                    Nebo(Modifier.matchParentSize(), if (firma.korporacija) "korporacija" else firma.id)
                    KSlika(firma.slika, Modifier.padding(top = 14.dp, start = 6.dp, end = 6.dp))
                    Ulica(Modifier.matchParentSize(), if (firma.korporacija) "korporacija" else firma.id, 0.7)
                }
            }
            if (o.prekovremeno == true) Text(Sef.oblik("Opa, prekovremeno! Danas je slobodan dan, a ti si {došao|došla}. Plata i kasa +10%.", Karijera.mojPol == "z"),
                style = tekst(15.sp, FontWeight.Bold, Boje.tinta), modifier = Modifier.fillMaxWidth().pop(Boje.zuta, 14.dp).padding(12.dp))
            if (o.rekord) Text("Nov rekord firme!", style = tekst(16.sp, FontWeight.Bold, Boje.tinta), modifier = Modifier.fillMaxWidth().pop(Boje.zuta, 14.dp).padding(12.dp))
            Column(Modifier.fillMaxWidth().mirna().padding(14.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row {
                    Broj("${o.poeni}", "Poeni", Modifier.weight(1f))
                    Broj(Karijera.novac(o.plata), "Plata", Modifier.weight(1f))
                    if (!firma.korporacija) Broj(Karijera.novac(o.kasi), "Kasi firme", Modifier.weight(1f))
                    Broj("+${o.ugled}", "Ugled", Modifier.weight(1f))
                }
                Text(if (o.placeno) "Plaćenih rundi danas: ${o.placenih_danas} od 10." else "Danas si odigrao 10 plaćenih rundi. Ova se računa samo za ugled i ekspertizu.",
                    style = tekst(13.sp, FontWeight.SemiBold, Boje.sivaTekst))
            }
            // Podeli ili objavi u Igračima (vlasnik 05.11).
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) { PodeliRundu(o, firma) }
            o.probni?.let { p ->
                Column(Modifier.fillMaxWidth().mirna().padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Oznaka("PROBNI RAD")
                    LinearProgressIndicator(progress = { p.runde.toFloat() / maxOf(p.cilj, 1) }, modifier = Modifier.fillMaxWidth(), color = Boje.teal, trackColor = Boje.kremTamnija)
                    Text("Runda ${p.runde} od ${p.cilj} · ${p.tacnih} tačnih od ${p.runde * 10}", style = tekst(14.sp, FontWeight.SemiBold))
                    p.ishod?.let { ish ->
                        if (ish >= 0) Text(when (ish) { 2 -> "Prošao si! Svoj office i 2 asistenta."; 1 -> "Prošao si! Svoj office i 1 asistent."; else -> "Prošao si! Svoj office, bez asistenata." },
                            style = tekst(16.sp, FontWeight.Bold, Boje.teal))
                        else Text("Nije dovoljno. Ostaješ u Korporaciji; novi probni rad posle 3 radna dana.", style = tekst(15.sp, FontWeight.Bold, Boje.crvena))
                    }
                }
            }
            if (!imaSledecu && o.probni?.ishod == null) Text("Za danas je to ${Karijera.PROBNI_DNEVNO} rundi probnog rada. Nastavi sutra.", style = tekst(14.sp, FontWeight.SemiBold, Boje.sivaTekst))
        }
        Column(Modifier.padding(top = 10.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            if (imaSledecu) Dugme("Sledeća runda") { dalje() }
            Dugme("Idi kući", vrsta = if (imaSledecu) VrstaDugmeta.SEKUNDARNO else VrstaDugmeta.PRIMARNO) { kuci() }
        }
    }
}

@Composable
private fun Broj(vrednost: String, naziv: String, modifier: Modifier) {
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Text(vrednost, style = naslov(20.sp), maxLines = 1)
        Text(naziv, style = tekst(12.sp, FontWeight.SemiBold, Boje.sivaTekst), maxLines = 1)
    }
}

private sealed interface DuelFaza { data object Ucitava : DuelFaza; data class Greska(val p: String) : DuelFaza; data class Igra(val p: List<Karijera.Pitanje>) : DuelFaza
    data object Salje : DuelFaza; data class Ishod(val o: Karijera.IshodDuela) : DuelFaza }

/** Duel za firmu: 30 pitanja u tri runde, pa predaja. Ishod stiže kad oba igrača odigraju (NPC odmah). */
@Composable
fun DuelEkran(z: Karijera.Izazov, botovi: List<Karijera.Bot>, ja: String?, nazad: () -> Unit) {
    var faza by remember { mutableStateOf<DuelFaza>(DuelFaza.Ucitava) }
    var pokusaj by remember { mutableIntStateOf(0) }
    val opseg = rememberCoroutineScope()
    val jaVlasnik = z.vlasnik == ja
    DisposableEffect(Unit) { onDispose { KarijeraMuzika.stani() } }
    LaunchedEffect(pokusaj) {
        faza = DuelFaza.Ucitava
        runCatching { Karijera.pitanjaDuela(z.id) }.onSuccess { p ->
            faza = if (p.size == 30) DuelFaza.Igra(p) else DuelFaza.Greska("Duel nema svih 30 pitanja.")
            KarijeraMuzika.pusti(if (jaVlasnik) Zvuk.Vrsta.KARIJERA_ODBRANA else Zvuk.Vrsta.KARIJERA_DUEL)
        }.onFailure { faza = DuelFaza.Greska(it.message ?: "Greška") }
    }
    Box(Modifier.fillMaxSize()) {
        Papir()
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                KNazad("Zatvori") { nazad() }
                Column { Text("Duel za firmu", style = naslov(20.sp)); Text("${z.vlasnik_ime} protiv ${z.izazivac_ime}", style = tekst(13.sp, FontWeight.SemiBold, Boje.sivaTekst), maxLines = 1) }
            }
            when (val f = faza) {
                DuelFaza.Ucitava, DuelFaza.Salje -> { KSkelet(380.dp); KSkelet(54.dp) }
                is DuelFaza.Greska -> KGreska(f.p) { pokusaj++ }
                is DuelFaza.Igra -> KarijeraPitanja(f.p, izazovId = z.id, pomoci = if ("duelista" in Karijera.mojiTalenti) Karijera.mojePomoci else Karijera.mojePomoci.take(2),
                    botovi = if (jaVlasnik && z.botova > 0) botovi else emptyList(), pozadina = z.firma.slika, mesto = z.firma.id) { odg ->
                    faza = DuelFaza.Salje; KarijeraMuzika.stani()
                    opseg.launch {
                        runCatching { Karijera.predajDuel(z.id, odg) }.onSuccess { o -> faza = DuelFaza.Ishod(o); if (o.stanje == "gotov" && o.pobednik == ja) Zvuk.pusti(Zvuk.Vrsta.KARIJERA_REKORD) }
                            .onFailure { faza = DuelFaza.Greska(it.message ?: "Greška") }
                    }
                }
                is DuelFaza.Ishod -> Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    val o = f.o
                    Text("${o.moji_tacni} od 30 tačnih", style = naslov(32.sp))
                    if (o.stanje == "gotov") {
                        val pobeda = o.pobednik == ja
                        Text(if (pobeda) (if (jaVlasnik) "Odbranio si firmu!" else "Firma je tvoja!") else (if (jaVlasnik) "Izgubio si firmu." else "Vlasnik je odbranio firmu."),
                            style = tekst(17.sp, FontWeight.Bold, Boje.tinta), modifier = Modifier.fillMaxWidth().pop(if (pobeda) Boje.zuta else Boje.nebo, 16.dp).padding(14.dp))
                        if (o.vlasnik_tacnih != null && o.izazivac_tacnih != null)
                            Text("Vlasnik ${o.vlasnik_tacnih} : ${o.izazivac_tacnih} izazivač${o.ishod?.let { " · $it" }.orEmpty()}", style = tekst(15.sp, FontWeight.SemiBold, Boje.sivaTekst))
                    } else Text("Tvoj rezultat je sačuvan. Ishod stiže kad i drugi igrač odigra duel (najviše 24 sata).", style = tekst(15.sp, FontWeight.SemiBold, Boje.sivaTekst))
                    Dugme("Dalje") { nazad() }
                }
            }
        }
    }
}



private const val PRIPREMA_SEKUNDI = 4

/** Tračevi i istine iz kancelarije za pripremu runde (vlasnik 05.11), src/lib/igre/kancelarija.json, isto i na iOS-u. */
@kotlinx.serialization.Serializable data class Zanimljivost(val vrsta: String, val tekst: String)
object Zanimljivosti {
    private var lista: List<Zanimljivost>? = null
    const val BROJ_SLIKA = 14
    fun sve(k: android.content.Context): List<Zanimljivost> = lista ?: runCatching {
        club.librum.kviz.servisi.Supabase.json.decodeFromString<List<Zanimljivost>>(k.assets.open("kancelarija.json").bufferedReader().use { it.readText() })
    }.getOrDefault(emptyList()).also { lista = it }
}

/** Priprema pre runde: odbrojavanje 4, 3, 2, 1, ilustracija kolega i trač ili istina iz kancelarije u oblačiću. */
@Composable
internal fun PripremaRunde(broj: Int, stavka: Zanimljivost?, slika: String) {
    Column(Modifier.fillMaxWidth().padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.weight(1f)) { Oznaka("SPREMI SE, RUNDA POČINJE ZA") }
            androidx.compose.animation.AnimatedContent(broj, label = "odbrojavanje") { b ->
                Text("$b", style = naslov(56.sp), modifier = Modifier.semantics { contentDescription = "Runda počinje za $b" })
            }
        }
        KSlika(slika, Modifier.fillMaxWidth().height(210.dp).clip(RoundedCornerShape(22.dp)).border(2.dp, Boje.mastilo, RoundedCornerShape(22.dp)),
            skala = androidx.compose.ui.layout.ContentScale.Crop)
        if (stavka != null) Column(Modifier.fillMaxWidth().pop(if (stavka.vrsta == "trac") Boje.zuta else Boje.nebo, radijus = 22.dp).padding(18.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Oznaka(if (stavka.vrsta == "trac") "TRAČ IZ KANCELARIJE" else "ISTINA, PROVERI", Boje.tinta)
            Text(stavka.tekst, style = tekst(17.sp, FontWeight.SemiBold, Boje.tinta))
        }
    }
}

/** Ikonica za deljenje rezultata runde: objava u Igračima i slanje teksta (Viber, poruke…). */
@Composable
private fun PodeliRundu(o: Karijera.IshodRunde, firma: Karijera.Firma) {
    val k = androidx.compose.ui.platform.LocalContext.current
    val opseg = rememberCoroutineScope()
    var otvoreno by remember { mutableStateOf(false) }
    var objavljeno by remember { mutableStateOf(false) }
    var greska by remember { mutableStateOf<String?>(null) }
    val tekstObjave = "Karijerista · ${firma.ime}: ${o.tacnih}/10 tačnih, ${o.poeni} poena"
    Box(Modifier.size(44.dp).background(Boje.kartica, androidx.compose.foundation.shape.CircleShape).border(1.5.dp, Boje.kremTamnija, androidx.compose.foundation.shape.CircleShape)
        .clickable(role = androidx.compose.ui.semantics.Role.Button) { otvoreno = true }.semantics { contentDescription = "Podeli rezultat" }, contentAlignment = Alignment.Center) {
        androidx.compose.material3.Icon(androidx.compose.material.icons.Icons.Rounded.Share, null, tint = Boje.mastilo, modifier = Modifier.size(20.dp))
    }
    // Prozor preko celog ekrana, jer je ikonica unutar skrolovanog sadržaja; izgled je naš donji list.
    if (otvoreno) androidx.compose.ui.window.Dialog({ otvoreno = false }, androidx.compose.ui.window.DialogProperties(usePlatformDefaultWidth = false)) { club.librum.kviz.ui.DonjiList({ otvoreno = false }) {
        Text("Podeli rezultat", style = naslov(26.sp))
        Text(tekstObjave, style = tekst(15.sp, FontWeight.SemiBold, Boje.sivaTekst))
        greska?.let { Text(it, style = tekst(14.sp, FontWeight.SemiBold, Boje.crvena)) }
        Dugme(if (objavljeno) "Objavljeno u Igračima" else "Objavi u Igračima", omoguceno = !objavljeno) {
            opseg.launch {
                runCatching {
                    val token = club.librum.kviz.servisi.Supabase.tokenIgraca?.invoke() ?: error("Prijavi se da bi objavio.")
                    club.librum.kviz.servisi.Supabase.rpc("nova_objava", mapOf("p_vrsta" to "rezultat", "p_tekst" to firma.ime, "p_igra" to "karijera", "p_poeni" to o.poeni), token)
                }.onSuccess { objavljeno = true; greska = null }.onFailure { greska = it.message }
            }
        }
        Dugme("Pošalji drugima", vrsta = VrstaDugmeta.SEKUNDARNO) {
            runCatching { k.startActivity(android.content.Intent.createChooser(android.content.Intent(android.content.Intent.ACTION_SEND).setType("text/plain")
                .putExtra(android.content.Intent.EXTRA_TEXT, "$tekstObjave u Librum kvizu. https://kviz.librum.club"), "Podeli rezultat")) }
        }
    } }
}
