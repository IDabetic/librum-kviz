package club.librum.kviz.zajednica

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import club.librum.kviz.karijera.Karijera
import club.librum.kviz.karijera.KarijeraBoje
import club.librum.kviz.karijera.KRed
import club.librum.kviz.karijera.KSkelet
import club.librum.kviz.karijera.KSlika
import club.librum.kviz.ui.Boje
import club.librum.kviz.ui.DonjiList
import club.librum.kviz.ui.Dugme
import club.librum.kviz.ui.Oznaka
import club.librum.kviz.ui.VrstaDugmeta
import club.librum.kviz.ui.mirna
import club.librum.kviz.ui.naslov
import club.librum.kviz.ui.pop
import club.librum.kviz.ui.tekst
import kotlinx.coroutines.launch
import java.time.Duration
import java.time.OffsetDateTime

// Profil fokusiran na dve glavne igre (prenos iOS ProfilFokus.swift): Osvajač i Karijera, pa ostale igre kao krugovi.

private fun broj(n: Int) = Zajednica.broj(n)

/** Osvajač i Karijera, prvo na profilu. `moj` = moj profil (talenti i zamena). */
@Composable
fun ProfilFokus(p: ProfilIgraca, igracId: String?, moj: Boolean, idi: (String) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        OsvajacKartica(p) { idi("osvajanje") }
        // ID se prosleđuje izričito: bez njega bi server vratio moj CV i na tuđem profilu.
        KarijeraProfilKartica(igracId ?: p.id, moj, idi)
    }
}

@Composable
private fun OsvajacKartica(p: ProfilIgraca, otvori: () -> Unit) {
    val g = p.igre.firstOrNull { it.igra == "osvajanje" }
    val titula = when (val n = g?.partija ?: 0) { 0 -> "Još nije krenuo u osvajanje"; in 1..4 -> "Izviđač"; in 5..19 -> "Vojskovođa"; in 20..49 -> "General"; else -> if (n >= 50) "Car sveta" else "" }
    Column(Modifier.fillMaxWidth().pop(Boje.teal, 24.dp).clickable(role = Role.Button, onClick = otvori).padding(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.Top) {
            Column(Modifier.weight(1f)) {
                Oznaka("OSVAJANJE SVETA", Color.White.copy(alpha = 0.8f))
                Text("Osvajač", style = naslov(30.sp, Color.White))
                Text(titula, style = tekst(14.sp, FontWeight.SemiBold, Color.White.copy(alpha = 0.85f)))
            }
            KSlika("igra_osvajanje", Modifier.size(72.dp))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Cip("${g?.partija ?: 0}", "partija", Modifier.weight(1f)); Cip(g?.let { broj(it.najbolje) } ?: "–", "rekord", Modifier.weight(1f))
            Cip(g?.tacnost?.let { "$it%" } ?: "–", "tačno", Modifier.weight(1f))
        }
        p.osvajanje_nacin?.takeIf { it.sam + it.savez + it.zajedno > 0 }?.let { n ->
            Text("Sam ${n.sam} · u savezu ${n.savez} · u timu ${n.zajedno}${if ((n.izdaje ?: 0) > 0) " · izdaje ${n.izdaje}" else ""}", style = tekst(12.sp, FontWeight.SemiBold, Color.White.copy(alpha = 0.85f)))
        }
    }
}

@Composable
private fun Cip(v: String, n: String, modifier: Modifier) {
    Column(modifier.background(Color.White.copy(alpha = 0.15f), RoundedCornerShape(12.dp)).padding(vertical = 8.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Text(v, style = naslov(19.sp, Color.White), maxLines = 1)
        Text(n, style = tekst(11.sp, FontWeight.SemiBold, Color.White.copy(alpha = 0.8f)))
    }
}

@Composable
private fun KarijeraProfilKartica(igrac: String?, moj: Boolean, idi: (String) -> Unit) {
    var cv by remember { mutableStateOf<Karijera.CV?>(null) }
    var nema by remember { mutableStateOf(false) }
    var stanje by remember { mutableStateOf<Karijera.Stanje?>(null) }
    var zamena by remember { mutableStateOf(false) }
    val opseg = rememberCoroutineScope()
    LaunchedEffect(igrac) {
        runCatching { Karijera.cv(igrac) }.onSuccess { cv = it }.onFailure { nema = true }
        if (moj) stanje = runCatching { Karijera.stanje() }.getOrNull()
    }
    val c = cv
    when {
        c != null -> Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            val firma = c.firme.firstOrNull()
            Row(Modifier.fillMaxWidth().pop(KarijeraBoje.plava, 24.dp).clickable(role = Role.Button) { idi(if (moj) "karijera" else "karijeracv/${c.id}") }.padding(18.dp),
                verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Oznaka("KARIJERA", Color.White.copy(alpha = 0.8f))
                    Text("${Karijera.titule[minOf(c.titula, 3)]} · ${c.pozicija.orEmpty()}", style = naslov(22.sp, Color.White), maxLines = 2)
                    Text(firma?.let { "Vlasnik: ${it.ime}" } ?: c.posao?.let { "Radi u: ${it.ime}" } ?: "Bez posla", style = tekst(13.sp, FontWeight.SemiBold, Color.White.copy(alpha = 0.85f)), maxLines = 1)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Cip(Karijera.novac(c.neto), "neto", Modifier.weight(1f)); Cip("${c.ugled}", "ugled", Modifier.weight(1f))
                        Cip("${c.firme.size}", if (c.firme.size == 1) "firma" else "firmi", Modifier.weight(1f))
                    }
                }
                KSlika(firma?.slika ?: "karijera_zgrada_1_1", Modifier.width(74.dp))
            }
            val s = stanje
            if (moj && s != null && s.mojiTalenti.isNotEmpty()) Column(Modifier.fillMaxWidth().mirna().clickable(role = Role.Button) { zamena = true }.padding(14.dp)
                .semantics { contentDescription = "Talenti: ${s.mojiTalenti.joinToString { it.naziv }}" }, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row {
                    Oznaka("TALENTI"); Box(Modifier.weight(1f))
                    val z = s.zamena_talenta
                    if ((z?.dostupno ?: 0) > 0) Text("zamena dostupna", style = tekst(12.sp, FontWeight.Bold, Boje.teal))
                    else if (z != null) Text("zamena za ${z.do_sledece} tačnih", style = tekst(12.sp, boja = Boje.sivaTekst))
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    s.mojiTalenti.forEach { t -> Text(t.naziv, style = tekst(12.sp, FontWeight.Bold), maxLines = 1,
                        modifier = Modifier.weight(1f).background(Boje.udubljeno, RoundedCornerShape(12.dp)).padding(vertical = 10.dp, horizontal = 6.dp)) }
                }
            }
        }
        nema && moj -> Row(Modifier.fillMaxWidth().pop(KarijeraBoje.plava, 24.dp).clickable(role = Role.Button) { idi("karijera") }.padding(18.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Oznaka("KARIJERA", Color.White.copy(alpha = 0.8f))
                Text("Kreni u karijeru", style = naslov(22.sp, Color.White))
                Text("Probni rad, svoj office i duel za tuđu firmu.", style = tekst(13.sp, FontWeight.SemiBold, Color.White.copy(alpha = 0.85f)))
            }
            KSlika("karijera_zgrada_1_1", Modifier.width(74.dp))
        }
        !nema -> KSkelet(150.dp)
    }
    val s = stanje
    if (zamena && s != null) ZamenaTalenta(s, { zamena = false }) { stari, novi ->
        zamena = false
        opseg.launch { runCatching { Karijera.promeniTalenat(stari, novi) }.onSuccess { stanje = it } }
    }
}

@Composable
private fun ZamenaTalenta(s: Karijera.Stanje, zatvori: () -> Unit, zameni: (String, String) -> Unit) {
    var stari by remember { mutableStateOf<String?>(null) }
    var novi by remember { mutableStateOf<String?>(null) }
    val z = s.zamena_talenta
    val moze = (z?.dostupno ?: 0) > 0
    DonjiList(zatvori) {
        Text("Talenti", style = naslov(26.sp))
        if (z != null) {
            LinearProgressIndicator(progress = { (z.korak - z.do_sledece).toFloat() / maxOf(z.korak, 1) }, modifier = Modifier.fillMaxWidth(), color = Boje.teal, trackColor = Boje.kremTamnija)
            Text(if (moze) "Imaš ${z.dostupno} ${if (z.dostupno == 1) "zamenu" else "zamene"}. Izaberi talenat koji menjaš, pa novi." else "Sledeća zamena za ${z.do_sledece} tačnih odgovora.",
                style = tekst(14.sp, FontWeight.SemiBold, Boje.sivaTekst))
        }
        Oznaka("TVOJI")
        s.mojiTalenti.forEach { t -> TalenatRed(t, stari == t.id) { if (moze) stari = t.id } }
        if (moze && stari != null) {
            Oznaka("NOVI")
            (s.katalog_talenata ?: emptyList()).filter { (s.talenti ?: emptyList()).contains(it.id).not() }.forEach { t -> TalenatRed(t, novi == t.id) { novi = t.id } }
        }
        if (moze) Dugme("Zameni", omoguceno = stari != null && novi != null) { val a = stari; val b = novi; if (a != null && b != null) zameni(a, b) }
    }
}

@Composable
private fun TalenatRed(t: Karijera.Talenat, izabran: Boolean, radnja: () -> Unit) {
    Column(Modifier.fillMaxWidth().pop(if (izabran) Boje.zuta else Boje.kartica, 16.dp).semantics { selected = izabran }.clickable(role = Role.RadioButton, onClick = radnja).padding(12.dp)) {
        Text(t.naziv, style = tekst(15.sp, FontWeight.Bold, if (izabran) Boje.tinta else Boje.mastilo))
        Text(t.opis, style = tekst(13.sp, boja = if (izabran) Boje.tinta.copy(alpha = 0.75f) else Boje.sivaTekst))
    }
}

/** Sve posle glavnih igara: krugovi ostalih igara (jedan red, svajp) i dugme za skorašnju aktivnost. */
@Composable
fun ProfilOstalo(p: ProfilIgraca) {
    var otvoren by remember { mutableStateOf<Krug?>(null) }
    var skoro by remember { mutableStateOf(false) }
    val krugovi = remember(p) { krugovi(p) }
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        if (krugovi.isNotEmpty()) {
            Text("Ostale igre", style = naslov(22.sp))
            BoxWithConstraints(Modifier.fillMaxWidth()) {
                val sirina = (maxWidth - 20.dp) / 3
                Row(Modifier.horizontalScroll(rememberScrollState()).padding(vertical = 8.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    krugovi.forEach { k ->
                        Column(Modifier.width(sirina).clickable(role = Role.Button) { otvoren = k }
                            .semantics(mergeDescendants = true) { contentDescription = "${k.naziv}, ${k.procenat?.let { "$it posto" } ?: "bez procenta"}, detalji" },
                            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Prsten(k, 76.dp)
                            Text(k.naziv, style = tekst(12.sp, FontWeight.Bold), maxLines = 1)
                        }
                    }
                }
            }
        }
        val s = p.skoro
        if (!s.isNullOrEmpty()) Column(Modifier.fillMaxWidth().mirna()) { KRed("Skorašnja aktivnost", "poslednjih ${minOf(10, s.size)}") { skoro = true } }
    }
    otvoren?.let { k ->
        DonjiList({ otvoren = null }) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) { Prsten(k, 64.dp); Text(k.naziv, style = naslov(26.sp)) }
            Column(Modifier.fillMaxWidth().mirna()) {
                k.redovi.forEachIndexed { i, (a, b) ->
                    Row(Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 11.dp)) { Text(a, style = tekst(15.sp), modifier = Modifier.weight(1f)); Text(b, style = tekst(15.sp, FontWeight.Bold)) }
                    if (i < k.redovi.size - 1) HorizontalDivider(color = Boje.kremTamnija)
                }
            }
            if (k.id == "sve") p.pomoci?.let { PomocUpotreba(it) }
            Dugme("Zatvori", vrsta = VrstaDugmeta.SEKUNDARNO) { otvoren = null }
        }
    }
    if (skoro) DonjiList({ skoro = false }) {
        Text("Skorašnja aktivnost", style = naslov(22.sp))
        Column(Modifier.fillMaxWidth().mirna()) {
            val l = (p.skoro ?: emptyList()).take(10)
            l.forEachIndexed { i, s ->
                Row(Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 11.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(NAZIVI_AKTIVNOSTI[s.igra] ?: s.igra, style = tekst(15.sp, FontWeight.SemiBold), modifier = Modifier.weight(1f))
                    Text("${s.poeni ?: 0}", style = tekst(15.sp, FontWeight.Bold))
                    Text(kada(s.kad), style = tekst(12.sp, boja = Boje.sivaTekst), modifier = Modifier.width(80.dp).padding(start = 10.dp))
                }
                if (i < l.size - 1) HorizontalDivider(color = Boje.kremTamnija)
            }
        }
        Dugme("Zatvori", vrsta = VrstaDugmeta.SEKUNDARNO) { skoro = false }
    }
}

private val NAZIVI_AKTIVNOSTI = mapOf("pro" to "PRO kviz", "book" to "Book kviz", "vesanje" to "Vešanje", "brzi" to "Brzi kviz", "duel" to "Duel",
    "slikari" to "Slikari", "osvajanje" to "Osvajanje", "tema" to "Kviz po temi", "karijera" to "Karijera")

private fun kada(iso: String): String {
    val d = runCatching { OffsetDateTime.parse(iso) }.getOrNull() ?: return ""
    val m = Duration.between(d, OffsetDateTime.now()).toMinutes()
    return when { m < 60 -> "pre ${maxOf(m, 1)} min"; m < 1440 -> "pre ${m / 60} h"; else -> "pre ${m / 1440} d" }
}

/** Upotreba pomoći po vrsti (kao iOS PomocUpotreba). */
@Composable
fun PomocUpotreba(poVrsti: Map<String, Int>) {
    val ukupno = poVrsti.values.sum()
    if (ukupno == 0) return
    val nazivi = mapOf("polaPola" to "50/50", "nagovestaj" to "Nagoveštaj", "vreme" to "Dodatno vreme", "preskok" to "Preskok", "slovo" to "Otkriveno slovo")
    Column(Modifier.fillMaxWidth().mirna().padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("Pomoći", style = tekst(15.sp, FontWeight.Bold))
        poVrsti.entries.sortedByDescending { it.value }.forEach { (k, v) ->
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(nazivi[k] ?: k, style = tekst(14.sp, FontWeight.SemiBold), modifier = Modifier.width(120.dp))
                Box(Modifier.weight(1f).height(8.dp).background(Boje.udubljeno, RoundedCornerShape(4.dp))) {
                    Box(Modifier.fillMaxWidth(v.toFloat() / ukupno).height(8.dp).background(Boje.roze, RoundedCornerShape(4.dp)))
                }
                Text("$v×", style = tekst(13.sp, FontWeight.Bold), modifier = Modifier.width(40.dp))
            }
        }
    }
}

data class Krug(val id: String, val naziv: String, val boja: Color, val procenat: Int?, val redovi: List<Pair<String, String>>)

private val BOJE_KRUGA get() = mapOf("pro" to Boje.ljubicasta, "book" to Boje.narandzasta, "vesanje" to Boje.nebo, "brzi" to Boje.zuta, "duel" to Boje.roze,
    "slikari" to Boje.roze, "tema" to Boje.teal, "dnevni" to Boje.zuta)
private val NAZIVI_KRUGA = mapOf("pro" to "PRO kviz", "book" to "Book kviz", "vesanje" to "Vešanje", "brzi" to "Brzi kviz", "duel" to "Duel", "slikari" to "Slikari",
    "tema" to "Teme", "dnevni" to "Dnevni izazov")

/** Isto kao iOS IgreKrugovi.krugovi: najbolji procenat prvi. */
fun krugovi(p: ProfilIgraca): List<Krug> {
    val veb = p.veb
    val ids = p.igre.map { it.igra }.toMutableSet().apply { removeAll(setOf("osvajanje", "karijera")) }
    listOf("pro" to veb?.pro, "book" to veb?.book, "vesanje" to veb?.vesanje, "brzi" to veb?.brzi).forEach { (id, g) -> if ((g?.partija ?: 0) > 0) ids += id }
    veb?.duel?.let { if ((it.pobeda ?: 0) + (it.poraza ?: 0) + (it.nereseno ?: 0) > 0) ids += "duel" }
    val l = mutableListOf<Krug>()
    for (id in listOf("pro", "book", "slikari", "brzi", "vesanje", "duel", "dnevni", "tema")) {
        if (id !in ids) continue
        val a = p.igre.firstOrNull { it.igra == id }
        val w = when (id) { "pro" -> veb?.pro; "book" -> veb?.book; "vesanje" -> veb?.vesanje; "brzi" -> veb?.brzi; "duel" -> veb?.duel; else -> null }
        val redovi = mutableListOf<Pair<String, String>>()
        val partija = (a?.partija ?: 0) + (w?.partija ?: 0)
        if (partija > 0) redovi += "Partija" to broj(partija)
        maxOf(a?.najbolje ?: 0, w?.rekord ?: 0).takeIf { it > 0 }?.let { redovi += "Rekord" to broj(it) }
        (a?.tacnost ?: w?.tacnost)?.let { redovi += "Tačnost" to "$it%" }
        a?.prosek_ms?.let { redovi += "Prosek odgovora" to String.format(java.util.Locale.forLanguageTag("sr"), "%.1f s", it / 1000.0) }
        a?.sa_pomoci?.takeIf { it > 0 }?.let { redovi += "Sa pomoći" to "$it" }
        w?.max_pitanja?.takeIf { it > 0 }?.let { redovi += "Najdalje" to "$it. pitanje" }
        w?.zanr?.let { redovi += "Najjači žanr" to it }
        if (id == "vesanje") w?.pobeda?.let { redovi += "Pogođenih reči" to "$it" }
        if (id == "duel" && w != null) redovi += listOf("Pobeda" to "${w.pobeda ?: 0}", "Poraza" to "${w.poraza ?: 0}", "Nerešeno" to "${w.nereseno ?: 0}")
        val procenat = when (id) {
            "duel" -> w?.let { d -> val u = (d.pobeda ?: 0) + (d.poraza ?: 0) + (d.nereseno ?: 0); if (u > 0) (d.pobeda ?: 0) * 100 / u else 0 }
            "vesanje" -> a?.tacnost ?: w?.let { (it.pobeda ?: 0) * 100 / maxOf(1, it.partija ?: 1) }
            else -> a?.tacnost ?: w?.tacnost
        }
        l += Krug(id, NAZIVI_KRUGA[id] ?: id, BOJE_KRUGA[id] ?: Boje.teal, procenat, redovi)
    }
    p.pitanja?.takeIf { it.odgovora > 0 }?.let { q ->
        l += Krug("sve", "Sva pitanja", Boje.teal, q.tacnost, listOf("Odgovora" to broj(q.odgovora), "Različitih pitanja" to broj(q.jedinstvenih), "Ponovljenih" to broj(q.ponovljenih)) +
            (q.prosek_ms?.let { listOf("Prosek odgovora" to String.format(java.util.Locale.forLanguageTag("sr"), "%.1f s", it / 1000.0)) } ?: emptyList()))
    }
    return l.sortedByDescending { it.procenat ?: -1 }
}

@Composable
private fun Prsten(k: Krug, velicina: Dp) {
    Box(Modifier.size(velicina), contentAlignment = Alignment.Center) {
        Canvas(Modifier.size(velicina)) {
            val d = size.minDimension * 0.12f
            val r = Size(size.width - d, size.height - d)
            drawArc(k.boja.copy(alpha = 0.22f), 0f, 360f, false, Offset(d / 2, d / 2), r, style = Stroke(d))
            drawArc(k.boja, -90f, 360f * (k.procenat ?: 0) / 100f, false, Offset(d / 2, d / 2), r, style = Stroke(d, cap = StrokeCap.Round))
        }
        Text(k.procenat?.let { "$it%" } ?: "–", style = naslov((velicina.value * 0.24f).sp))
    }
}
