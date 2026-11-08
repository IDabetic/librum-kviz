package club.librum.kviz.reci

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Backspace
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Lightbulb
import androidx.compose.material.icons.rounded.Timer
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.LifecycleResumeEffect
import club.librum.kviz.igre.MojRezultat
import club.librum.kviz.servisi.Sesija
import club.librum.kviz.servisi.Zvuk
import club.librum.kviz.ui.AvatarSlika
import club.librum.kviz.ui.Boje
import club.librum.kviz.ui.Dugme
import club.librum.kviz.ui.Oznaka
import club.librum.kviz.ui.Papir
import club.librum.kviz.ui.VrstaDugmeta
import club.librum.kviz.ui.mirna
import club.librum.kviz.ui.naslov
import club.librum.kviz.ui.pop
import club.librum.kviz.ui.tekst
import kotlinx.coroutines.delay

/** Stanje pločice (boje kao u celom kvizu: teal tačno, žuto na drugom mestu, sivo nema). */
enum class StanjePloce(val jacina: Int) { PRAZNO(0), UNETO(0), NEMA(1), MESTO(2), TACNO(3), IZABRANO(0), ISTAKNUTO(0) }

/** Pločica slova sa debelom ivicom; broj u uglu za Šifru i Ukrštenicu. */
@Composable
fun Ploca(slovo: String, stanje: StanjePloce = StanjePloce.UNETO, velicina: Dp = 52.dp, broj: Int? = null, modifier: Modifier = Modifier) {
    val (pozadina, boja, ivica, debljina) = when (stanje) {
        StanjePloce.PRAZNO -> Cetiri(Boje.kartica, Boje.mastilo, Boje.kremTamnija, 2.dp)
        StanjePloce.UNETO -> Cetiri(Boje.kartica, Boje.mastilo, Boje.mastilo, 2.5.dp)
        StanjePloce.NEMA -> Cetiri(Boje.skelet, Boje.sivaTekst, Color.Transparent, 0.dp)
        StanjePloce.MESTO -> Cetiri(Boje.zuta, Boje.tinta, Boje.mastilo, 2.dp)
        StanjePloce.TACNO -> Cetiri(Boje.teal, Color.White, Boje.mastilo, 2.dp)
        StanjePloce.IZABRANO -> Cetiri(Boje.zuta, Boje.tinta, Boje.mastilo, 3.dp)
        StanjePloce.ISTAKNUTO -> Cetiri(Boje.tealSvetla, Boje.mastilo, Boje.teal, 2.dp)
    }
    val oblik = RoundedCornerShape(velicina * 0.2f)
    Box(modifier.size(velicina).background(pozadina, oblik).border(debljina, ivica, oblik), contentAlignment = Alignment.Center) {
        Text(slovo, style = tekst((velicina.value * 0.46f).sp, FontWeight.ExtraBold, boja))
        if (broj != null) Text("$broj", style = tekst(maxOf(8f, velicina.value * 0.24f).sp, FontWeight.Bold,
            if (stanje == StanjePloce.TACNO) Color.White.copy(alpha = 0.85f) else Boje.sivaTekst),
            modifier = Modifier.align(Alignment.TopStart).padding(start = 3.dp, top = 1.dp))
    }
}

private data class Cetiri(val a: Color, val b: Color, val c: Color, val d: Dp)

/**
 * Unos tastaturom telefona (vlasnik 08.11: ne tastatura u igri). Vidljivo polje vezano za tekst igre: kuca se reč,
 * „Gotovo” potvrđuje i fokus ostaje. Polje se prepisuje samo za višak ili nedozvoljen znak (prepisivanje gubi slova).
 */
@Composable
fun PoljeUnosaReci(tekst: String, promeni: (String) -> Unit, duzina: Int, natpis: String = "Kucaj reč", brisi: (() -> Unit)? = null, potvrdi: (() -> Unit)? = null) {
    val fokus = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { fokus.requestFocus() } }
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.weight(1f).height(48.dp).background(Boje.kartica, RoundedCornerShape(14.dp)).border(2.dp, Boje.mastilo, RoundedCornerShape(14.dp)).padding(horizontal = 14.dp),
            contentAlignment = Alignment.CenterStart) {
            if (tekst.isEmpty()) Text(natpis, style = tekst(17.sp, FontWeight.Bold, Boje.sivaTekst))
            BasicTextField(
                value = tekst,
                onValueChange = { novo -> promeni(novo.filter { it.uppercaseChar() in AzbukaReci.dozvoljena }.take(duzina)) },
                singleLine = true,
                textStyle = tekst(18.sp, FontWeight.Bold),
                cursorBrush = SolidColor(Boje.mastilo),
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Characters, autoCorrectEnabled = false, imeAction = ImeAction.Done),
                keyboardActions = KeyboardActions(onDone = { potvrdi?.invoke() }),
                modifier = Modifier.fillMaxWidth().focusRequester(fokus).semantics { contentDescription = natpis },
            )
        }
        if (brisi != null) KockaDugme(Icons.Rounded.Backspace, "Obriši", false, brisi)
        if (potvrdi != null) KockaDugme(Icons.Rounded.Check, "Potvrdi", true, potvrdi)
    }
}

@Composable
fun KockaDugme(ikona: androidx.compose.ui.graphics.vector.ImageVector, opis: String, jako: Boolean = false, radnja: () -> Unit) {
    Box(Modifier.size(56.dp, 48.dp).background(if (jako) Boje.mastilo else Boje.kartica, RoundedCornerShape(14.dp))
        .border(2.dp, Boje.mastilo, RoundedCornerShape(14.dp)).clickable(onClick = radnja).semantics { contentDescription = opis },
        contentAlignment = Alignment.Center) {
        Icon(ikona, null, tint = if (jako) Boje.naMastilu else Boje.mastilo)
    }
}

/** Zajednički okvir igre: zatvaranje, naslov, sat (u sobi odbrojava), pomoć i pravilo; sat ide dok je ekran otvoren. */
@Composable
fun OkvirIgreReci(igra: IgraReci, sekundi: Int, tik: () -> Unit, gotovo: Boolean, zatvori: () -> Unit, podnaslov: String? = null,
                  rok: Int? = null, pomoc: (() -> Unit)? = null, sadrzaj: @Composable ColumnScope.() -> Unit) {
    var aktivno by remember { mutableStateOf(true) }
    LifecycleResumeEffect(Unit) { aktivno = true; onPauseOrDispose { aktivno = false } }
    LaunchedEffect(gotovo, aktivno) { while (!gotovo && aktivno) { delay(1000); if (!gotovo && aktivno) tik() } }
    BackHandler(enabled = rok == null) { zatvori() }
    Box(Modifier.fillMaxSize()) {
        Papir(Modifier.fillMaxSize())
        Column(Modifier.fillMaxSize().statusBarsPadding().imePadding().navigationBarsPadding().padding(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                if (rok == null) KockaDugme(Icons.Rounded.Close, "Izađi", radnja = zatvori) else Spacer(Modifier.size(56.dp, 48.dp))
                Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(podnaslov ?: if (rok == null) "Igra dana" else "Igra sa drugima", style = tekst(12.sp, FontWeight.SemiBold, Boje.sivaTekst))
                    Text(igra.naslov, style = naslov(20.sp))
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Rounded.Timer, null, Modifier.size(14.dp), tint = Boje.sivaTekst)
                        Text(AzbukaReci.vreme(rok?.let { maxOf(0, it - sekundi) } ?: sekundi), style = tekst(13.sp, FontWeight.Bold, Boje.sivaTekst))
                    }
                }
                if (pomoc != null && !gotovo) KockaDugme(Icons.Rounded.Lightbulb, "Pomoć, oduzima 5 poena", radnja = pomoc) else Spacer(Modifier.size(56.dp, 48.dp))
            }
            if (!gotovo) Text(igra.pravilo, style = tekst(13.sp, boja = Boje.sivaTekst), textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
            sadrzaj()
        }
    }
}

/** Kraj partije: ishod, rešenje, mesto i rang lista dana. */
@Composable
fun KrajIgreReci(igra: IgraReci, resio: Boolean, resenje: String, sekundi: Int, ishod: Ishod, sesija: Sesija, nazad: () -> Unit) {
    var rang by remember { mutableStateOf<List<RedRangaReci>>(emptyList()) }
    val ja = sesija.nalog.collectAsState().value
    LaunchedEffect(ishod) { rang = IgreReciServis.rang(igra) }
    Column(Modifier.fillMaxWidth().pop(if (resio) Boje.tealSvetla else Boje.kartica).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Text(if (resio) "Rešeno!" else "Kraj igre", style = naslov(30.sp))
        Text(resenje, style = tekst(16.sp, FontWeight.SemiBold), textAlign = TextAlign.Center)
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Plocica(Icons.Rounded.Timer, AzbukaReci.vreme(sekundi), "Vreme", Boje.teal, Modifier.weight(1f))
            (ishod as? Ishod.Gotovo)?.i?.let { i ->
                Plocica(Icons.Rounded.Star, "${i.poeni}", "Poeni", Boje.narandzasta, Modifier.weight(1f))
                if (i.ukupno > 0) Plocica(Icons.Rounded.EmojiEvents, "${i.mesto}. / ${i.ukupno}", "Mesto danas", Boje.ljubicasta, Modifier.weight(1f))
            }
        }
        when (ishod) {
            Ishod.Ucitava -> CircularProgressIndicator(color = Boje.mastilo)
            is Ishod.Greska -> Text(ishod.poruka, style = tekst(14.sp, boja = Boje.crvena), textAlign = TextAlign.Center)
            is Ishod.Gotovo -> if (ishod.i == null && ja == null) Text("Prijavi se da rezultat ode na rang listu.", style = tekst(14.sp, boja = Boje.sivaTekst))
        }
        if (rang.isNotEmpty()) Column(Modifier.fillMaxWidth().mirna().padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Oznaka("Najbolji danas")
            rang.take(10).forEach { r ->
                val boja = if (r.id == ja?.id) Boje.teal else Boje.mastilo
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text("${r.mesto}.", style = tekst(14.sp, FontWeight.Bold, boja), modifier = Modifier.width(28.dp))
                    AvatarSlika(r.avatar, 28.dp)
                    Text(r.ime, style = tekst(14.sp, FontWeight.SemiBold, boja), maxLines = 1, modifier = Modifier.weight(1f))
                    if (r.resio) Text("${r.poeni}", style = tekst(14.sp, FontWeight.Bold, boja))
                    Text(AzbukaReci.vreme(r.sekundi), style = tekst(13.sp, boja = Boje.sivaTekst))
                }
            }
        }
        Text("Nova zagonetka stiže sutra.", style = tekst(13.sp, boja = Boje.sivaTekst))
        Dugme("Nazad na igre", vrsta = VrstaDugmeta.ZUTO, radnja = nazad)
    }
}

@Composable
private fun Plocica(ikona: androidx.compose.ui.graphics.vector.ImageVector, vrednost: String, naziv: String, boja: Color, modifier: Modifier) {
    Column(modifier.mirna().padding(vertical = 12.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Icon(ikona, null, tint = boja)
        Text(vrednost, style = naslov(20.sp), maxLines = 1)
        Text(naziv, style = tekst(12.sp, boja = Boje.sivaTekst), maxLines = 1)
    }
}

/** Ishod slanja rezultata (null = gost ili ranije upisano bez mesta). */
sealed interface Ishod {
    data object Ucitava : Ishod
    data class Greska(val poruka: String) : Ishod
    data class Gotovo(val i: IshodReci?) : Ishod
}

/** Rezultat već upisan na serveru, za ponovo otvorenu završenu igru. */
fun upisanIshod(igra: IgraReci): Ishod = Ishod.Gotovo(IgreReciServis.moj(igra)?.let { IshodReci(it.resio, it.poeni, it.sekundi, 0, 0) })

suspend fun posaljiRezultatReci(igra: IgraReci, odgovor: Map<String, Any?>, resio: Boolean, sekundi: Int, pomoci: Int, sesija: Sesija): Ishod =
    try {
        val i = IgreReciServis.zavrsi(igra, odgovor, resio, sekundi, pomoci, sesija)
        Zvuk.pusti(if (resio) Zvuk.Vrsta.OSVOJENO else Zvuk.Vrsta.NETACNO, 0.5f)
        Ishod.Gotovo(i)
    } catch (g: Exception) { Ishod.Greska(g.message ?: "Rezultat nije poslat.") }

/** Poruka ispod igre koja se sama skloni. */
@Composable
fun PorukaReci(tekst: String?) {
    Text(tekst ?: " ", style = tekst(14.sp, FontWeight.SemiBold), textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().height(20.dp))
}

/** Prikaže poruku na 1,6 s. */
suspend fun kratko(postavi: (String?) -> Unit, tekst: String) { postavi(tekst); delay(1600); postavi(null) }
