package club.librum.kviz.reci

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CalendarMonth
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.ChevronLeft
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.Groups
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Cancel
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import club.librum.kviz.igre.MojRezultat
import club.librum.kviz.servisi.Sesija
import club.librum.kviz.servisi.Supabase
import club.librum.kviz.ui.Boje
import club.librum.kviz.ui.Dugme
import club.librum.kviz.ui.Papir
import club.librum.kviz.ui.VrstaDugmeta
import club.librum.kviz.ui.naslov
import club.librum.kviz.ui.pop
import club.librum.kviz.ui.tekst
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.jsonArray

/** Igre reči: šest dnevnih zagonetki (ruta "reci"), igra se otvara rutom "reci/<igra>". */
@Composable
fun IgreReciEkran(sesija: Sesija, idi: (String) -> Unit, nazad: () -> Unit) {
    val ctx = LocalContext.current
    var dan by remember { mutableStateOf(IgreReciServis.dan) }
    var greska by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(Unit) {
        RecnikReci.ucitaj(ctx)
        runCatching { IgreReciServis.ucitaj(ctx, sesija) }.onSuccess { dan = it; greska = null }.onFailure { if (dan == null) greska = it.message ?: "Zagonetke nisu stigle." }
    }
    Box(Modifier.fillMaxSize()) {
        Papir(Modifier.fillMaxSize())
        Column(Modifier.fillMaxSize().statusBarsPadding().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            KockaDugme(Icons.Rounded.ChevronLeft, "Nazad", radnja = nazad)
            Text("Igre reči", style = naslov(34.sp))
            Text("Šest novih zagonetki svaki dan. Ista zagonetka za sve, rang lista do ponoći.", style = tekst(15.sp, boja = Boje.sivaTekst))
            val d = dan
            when {
                greska != null -> Text(greska!!, style = tekst(15.sp, boja = Boje.crvena))
                d == null -> Box(Modifier.fillMaxWidth().padding(40.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = Boje.mastilo) }
                else -> {
                    d.igre.petSlova?.tezina?.let { t ->
                        Text(when (t) { "lako" -> "Danas: lake zagonetke"; "tesko" -> "Danas: teške zagonetke (vikend)"; else -> "Danas: srednje zagonetke" },
                            style = tekst(14.sp, FontWeight.Bold, when (t) { "lako" -> Boje.teal; "tesko" -> Boje.crvena; else -> Boje.narandzasta }))
                    }
                    Row(Modifier.fillMaxWidth().pop(radijus = 18.dp).clickable { idi("takmicenje/reci") }.padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Box(Modifier.size(44.dp).background(Boje.zuta, RoundedCornerShape(12.dp)).border(2.dp, Boje.mastilo, RoundedCornerShape(12.dp)), contentAlignment = Alignment.Center) {
                            Icon(Icons.Rounded.Groups, null, tint = Boje.tinta)
                        }
                        Column(Modifier.weight(1f)) {
                            Text("Igraj sa drugima", style = tekst(16.sp, FontWeight.Bold))
                            Text("2–8 igrača, ista zagonetka, lako do teško", style = tekst(13.sp, boja = Boje.sivaTekst))
                        }
                        Icon(Icons.Rounded.ChevronRight, null, tint = Boje.sivaTekst)
                    }
                    IgraReci.entries.chunked(2).forEach { par ->
                        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            par.forEach { igra -> Kartica(igra, IgreReciServis.moj(igra), IgreReciServis.niz(igra), Modifier.weight(1f)) { idi("reci/${igra.kljuc}") } }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun Kartica(igra: IgraReci, moj: MojRezultatReci?, niz: Int, modifier: Modifier, otvori: () -> Unit) {
    Column(modifier.heightIn(min = 190.dp).pop(radijus = 20.dp).clickable(onClick = otvori).padding(14.dp)
        .semantics { contentDescription = "${igra.naslov}. ${igra.opis}." }, verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Box(Modifier.size(48.dp).background(igra.boja, RoundedCornerShape(14.dp)).border(2.dp, Boje.mastilo, RoundedCornerShape(14.dp)), contentAlignment = Alignment.Center) {
            Icon(igra.ikona, null, tint = if (igra.tamnaIkonica) Boje.tinta else Color.White)
        }
        Text(igra.naslov, style = tekst(16.sp, FontWeight.Bold), maxLines = 1)
        Text(igra.opis, style = tekst(13.sp, boja = Boje.sivaTekst), modifier = Modifier.weight(1f, fill = false))
        Spacer(Modifier.weight(1f))
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            if (moj != null) {
                Icon(if (moj.resio) Icons.Rounded.CheckCircle else Icons.Rounded.Cancel, null, Modifier.size(18.dp), tint = if (moj.resio) Boje.teal else Boje.crvena)
                Text(AzbukaReci.vreme(moj.sekundi), style = tekst(13.sp, FontWeight.Bold))
            } else {
                Icon(Icons.Rounded.PlayArrow, null, Modifier.size(18.dp), tint = Boje.mastilo)
                Text("Igraj", style = tekst(13.sp, FontWeight.Bold))
            }
            Spacer(Modifier.weight(1f))
            if (niz > 0) { Icon(Icons.Rounded.CalendarMonth, null, Modifier.size(16.dp), tint = Boje.mastilo); Text("$niz", style = tekst(13.sp, FontWeight.Bold)) }
        }
    }
}

/** Jedna igra dana (ruta "reci/<igra>"). */
@Composable
fun IgraReciEkran(sesija: Sesija, kljuc: String, nazad: () -> Unit) {
    val ctx = LocalContext.current
    var dan by remember { mutableStateOf(IgreReciServis.dan) }
    LaunchedEffect(Unit) { RecnikReci.ucitaj(ctx); if (dan == null) dan = runCatching { IgreReciServis.ucitaj(ctx, sesija) }.getOrNull() }
    val d = dan ?: return Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = Boje.mastilo) }
    val z = d.igre
    when (IgraReci.od(kljuc)) {
        IgraReci.PREMETALJKA -> z.premetaljka?.let { PremetaljkaEkran(it, d.datum, sesija, nazad) }
        IgraReci.PET_SLOVA -> z.petSlova?.let { PetSlovaEkran(it, d.datum, sesija, nazad) }
        IgraReci.LANAC -> z.lanac?.let { LanacEkran(it, d.datum, sesija, nazad) }
        IgraReci.SIFRA -> z.sifra?.let { SifraEkran(it, d.datum, sesija, nazad) }
        IgraReci.UKRSTENICA -> z.ukrstenica?.let { UkrstenicaEkran(it, d.datum, sesija, nazad) }
        IgraReci.ZMIJA -> z.zmija?.let { ZmijaEkran(it, d.datum, sesija, nazad) }
        null -> nazad()
    }
}

/** Igra reči u sobi „Igraj sa drugima”: sadržaj sobe je niz sa jednom zagonetkom. */
@Composable
fun IgraReciUSobi(igra: IgraReci, sadrzaj: JsonElement, sobaId: String, sesija: Sesija, javi: (MojRezultat) -> Unit) {
    val ctx = LocalContext.current
    LaunchedEffect(Unit) { RecnikReci.ucitaj(ctx) }
    val z = remember(sadrzaj) { runCatching { sadrzaj.jsonArray.first() }.getOrNull() } ?: return
    val datum = "soba-$sobaId"
    val soba = remember { UTakmicenju(igra.rok, javi) }
    val j = Supabase.json
    when (igra) {
        IgraReci.PREMETALJKA -> PremetaljkaEkran(j.decodeFromJsonElement(PremetaljkaZ.serializer(), z), datum, sesija, {}, soba)
        IgraReci.PET_SLOVA -> PetSlovaEkran(j.decodeFromJsonElement(PetSlovaZ.serializer(), z), datum, sesija, {}, soba)
        IgraReci.LANAC -> LanacEkran(j.decodeFromJsonElement(LanacZ.serializer(), z), datum, sesija, {}, soba)
        IgraReci.SIFRA -> SifraEkran(j.decodeFromJsonElement(SifraZ.serializer(), z), datum, sesija, {}, soba)
        IgraReci.UKRSTENICA -> UkrstenicaEkran(j.decodeFromJsonElement(UkrstenicaZ.serializer(), z), datum, sesija, {}, soba)
        IgraReci.ZMIJA -> ZmijaEkran(j.decodeFromJsonElement(ZmijaZ.serializer(), z), datum, sesija, {}, soba)
    }
}

/** Kartica na početnoj: ulaz u šest igara reči. */
@Composable
fun IgreReciKartica(otvori: () -> Unit) {
    Row(Modifier.fillMaxWidth().pop(radijus = 20.dp).clickable(onClick = otvori).padding(12.dp), verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy((-10).dp)) {
            listOf(IgraReci.PREMETALJKA, IgraReci.PET_SLOVA, IgraReci.ZMIJA).forEach { igra ->
                Box(Modifier.size(36.dp).background(igra.boja, RoundedCornerShape(10.dp)).border(2.dp, Boje.mastilo, RoundedCornerShape(10.dp)), contentAlignment = Alignment.Center) {
                    Icon(igra.ikona, null, Modifier.size(18.dp), tint = Boje.tinta)
                }
            }
        }
        Column(Modifier.weight(1f)) {
            Text("Igre reči", style = tekst(16.sp, FontWeight.Bold))
            Text("6 novih zagonetki svaki dan", style = tekst(13.sp, boja = Boje.sivaTekst), maxLines = 1)
        }
        Icon(Icons.Rounded.ChevronRight, null, tint = Boje.sivaTekst)
    }
}
