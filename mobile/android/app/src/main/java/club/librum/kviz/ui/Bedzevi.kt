package club.librum.kviz.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.CalendarMonth
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.Flag
import androidx.compose.material.icons.rounded.Groups
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.MenuBook
import androidx.compose.material.icons.rounded.MilitaryTech
import androidx.compose.material.icons.rounded.Psychology
import androidx.compose.material.icons.rounded.Public
import androidx.compose.material.icons.rounded.SportsEsports
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.TrendingUp
import androidx.compose.material.icons.rounded.WorkspacePremium
import androidx.compose.material.icons.rounded.AutoStories
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import club.librum.kviz.karijera.KNazad
import club.librum.kviz.servisi.Bedz
import club.librum.kviz.servisi.Napredak
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/** Ikonica bedža, ista značenja kao SF Symbols na iOS-u (Napredak.sviBedzevi). */
private fun ikonica(id: String): ImageVector = when (id) {
    "prvi" -> Icons.Rounded.Flag
    "niz3" -> Icons.Rounded.LocalFireDepartment
    "niz7" -> Icons.Rounded.CalendarMonth
    "niz30" -> Icons.Rounded.WorkspacePremium
    "tacnih100" -> Icons.Rounded.Psychology
    "tacnih1000" -> Icons.Rounded.AutoStories
    "savrseno" -> Icons.Rounded.Star
    "brzina" -> Icons.Rounded.Bolt
    "igara25" -> Icons.Rounded.SportsEsports
    "igara100" -> Icons.Rounded.EmojiEvents
    "duel1" -> Icons.Rounded.Groups
    "duel10" -> Icons.Rounded.MilitaryTech
    "svet" -> Icons.Rounded.Public
    "knjige" -> Icons.Rounded.MenuBook
    "nivo5" -> Icons.Rounded.TrendingUp
    else -> Icons.Rounded.AutoAwesome
}

@Composable
fun BedzKrug(b: Bedz, otkljucan: Boolean, velicina: Dp = 64.dp) {
    Box(
        Modifier.size(velicina).background(if (otkljucan) Color(b.boja) else Boje.udubljeno, CircleShape)
            .border(2.5.dp, if (otkljucan) Boje.mastilo else Boje.kremTamnija, CircleShape)
            .semantics { contentDescription = "${b.naziv}, ${if (otkljucan) "otključan" else "zaključan"}" },
        contentAlignment = Alignment.Center,
    ) { Icon(if (otkljucan) ikonica(b.id) else Icons.Rounded.Lock, null, tint = if (otkljucan) Boje.tinta else Boje.sivaTekst, modifier = Modifier.size(velicina * 0.42f)) }
}

/** Kartica na profilu (kao iOS): prvih 5 bedževa i broj otključanih; vodi na sve bedževe. */
@Composable
fun BedzeviKartica(idi: (String) -> Unit) {
    val s = Napredak.deljeni.s
    val svi = Napredak.SVI_BEDZEVI
    Column(Modifier.fillMaxWidth().clickable(role = Role.Button) { idi("bedzevi") }, verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Bedževi", style = naslov(22.sp), modifier = Modifier.weight(1f))
            Text("${s.bedzevi.size} / ${svi.size} · Svi", style = tekst(13.sp, FontWeight.SemiBold, Boje.sivaTekst))
        }
        Row(Modifier.fillMaxWidth().mirna().padding(vertical = 12.dp), horizontalArrangement = Arrangement.SpaceEvenly) {
            svi.take(5).forEach { BedzKrug(it, s.bedzevi[it.id] != null, 52.dp) }
        }
    }
}

private val DATUM = DateTimeFormatter.ofPattern("d. MMM yyyy.", Locale.forLanguageTag("sr-Latn"))

/** Svi bedževi (prenos iOS BedzeviView): napredak, mreža 3 kolone, detalj u donjem listu. */
@Composable
fun BedzeviEkran(nazad: () -> Unit) {
    val s = Napredak.deljeni.s
    val svi = Napredak.SVI_BEDZEVI
    var detalj by remember { mutableStateOf<Bedz?>(null) }
    Box(Modifier.fillMaxSize()) {
        Papir()
        Column(Modifier.fillMaxSize().statusBarsPadding().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            KNazad { nazad() }
            Text("Bedževi", style = naslov(36.sp))
            Text("${s.bedzevi.size} od ${svi.size} otključano", style = tekst(14.sp, FontWeight.SemiBold, Boje.sivaTekst))
            Box(Modifier.fillMaxWidth().height(10.dp).background(Boje.kartica, RoundedCornerShape(5.dp)).border(1.5.dp, Boje.mastilo, RoundedCornerShape(5.dp))) {
                Box(Modifier.fillMaxHeight().fillMaxWidth(s.bedzevi.size.toFloat() / svi.size).background(Boje.roze, RoundedCornerShape(5.dp)))
            }
            svi.chunked(3).forEach { red ->
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    red.forEach { b ->
                        val otkljucan = s.bedzevi[b.id] != null
                        Column(
                            Modifier.weight(1f).height(170.dp)
                                .background(if (otkljucan) Boje.kartica else Boje.kartica.copy(alpha = 0.5f), RoundedCornerShape(20.dp))
                                .border(if (otkljucan) 2.5.dp else 1.5.dp, if (otkljucan) Boje.mastilo else Boje.kremTamnija, RoundedCornerShape(20.dp))
                                .clickable(role = Role.Button) { detalj = b }.padding(10.dp),
                            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            BedzKrug(b, otkljucan)
                            Text(b.naziv, style = tekst(if (b.naziv.length > 13) 11.sp else 13.sp, FontWeight.Bold, if (otkljucan) Boje.mastilo else Boje.sivaTekst), maxLines = 1, overflow = TextOverflow.Ellipsis)
                            Text(if (otkljucan) "Otključan" else b.opis, style = tekst(11.sp, boja = Boje.sivaTekst), maxLines = 3, textAlign = TextAlign.Center)
                        }
                    }
                    repeat(3 - red.size) { Spacer(Modifier.weight(1f)) }
                }
            }
            Spacer(Modifier.height(40.dp))
        }
        detalj?.let { b ->
            val kad = s.bedzevi[b.id]
            DonjiList({ detalj = null }) {
                BedzKrug(b, kad != null, 90.dp)
                Text(b.naziv, style = naslov(28.sp))
                if (kad != null) Text("Otključan ${DATUM.format(Instant.ofEpochMilli(kad).atZone(ZoneId.systemDefault()))}", style = tekst(13.sp, FontWeight.Bold, Boje.teal))
                Text(b.opis, style = tekst(15.sp, boja = Boje.sivaTekst), textAlign = TextAlign.Center)
                Dugme("Važi") { detalj = null }
            }
        }
    }
}

/** Statistika (prenos iOS StatistikaView): tačnost za period, stubići po danima, teme. */
@Composable
fun StatistikaEkran(nazad: () -> Unit) {
    val n = Napredak.deljeni
    var period by remember { mutableStateOf(7) }
    val minimum = 3
    Box(Modifier.fillMaxSize()) {
        Papir()
        Column(Modifier.fillMaxSize().statusBarsPadding().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            KNazad { nazad() }
            Text("Tvoja statistika", style = naslov(34.sp))
            Podvuceno(listOf(7 to "Nedelja", 30 to "Mesec", 0 to "Sve vreme"), period) { period = it }
            val t = n.tacnost(if (period == 0) null else Instant.now().minusSeconds((period - 1) * 86_400L))
            if (t != null && t.second >= minimum) {
                val dani = n.tacnostPoDanima(7)
                Column(Modifier.fillMaxWidth().background(Boje.teal, RoundedCornerShape(24.dp)).border(2.5.dp, Boje.mastilo, RoundedCornerShape(24.dp)).padding(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Oznaka("TAČNOST", Color.White)
                    Text("${(t.first * 100).toInt()}%", style = naslov(46.sp).copy(color = Color.White))
                    Row(Modifier.fillMaxWidth().height(140.dp).semantics { contentDescription = "Tačnost po danima: " + dani.joinToString { d -> d.second?.let { "${(it * 100).toInt()}%" } ?: "nije igrano" } },
                        horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.Bottom) {
                        dani.forEachIndexed { i, (dan, tac) ->
                            Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                Box(Modifier.fillMaxWidth().height(maxOf(10f, 110f * (tac ?: 0.0).toFloat()).dp)
                                    .background((if (i == dani.size - 1) Boje.zuta else Color(0xFFDFF3EE)).copy(alpha = if (tac == null) 0.35f else 1f), RoundedCornerShape(8.dp))
                                    .border(2.dp, Boje.tinta, RoundedCornerShape(8.dp)))
                                Text(dan.dayOfWeek.getDisplayName(java.time.format.TextStyle.NARROW, Locale.forLanguageTag("sr-Latn")).uppercase(), style = tekst(11.sp, FontWeight.Bold, Color.White))
                            }
                        }
                    }
                }
            } else Column(Modifier.fillMaxWidth().pop().padding(20.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                MaskotaSlika(Maskota.ZIG, 80.dp)
                Text("Još nema statistike", style = naslov(22.sp))
                Text("Odigraj bar $minimum kviza u ovom periodu da se pojave grafikoni.", style = tekst(14.sp, boja = Boje.sivaTekst), textAlign = TextAlign.Center)
            }
            Text("Po temama", style = naslov(22.sp), modifier = Modifier.padding(top = 6.dp))
            val teme = n.s.kategorije.entries.sortedByDescending { it.value.getOrElse(1) { 0 } }
            if (teme.isEmpty()) Text("Teme se pojavljuju posle prvih kvizova.", style = tekst(14.sp, boja = Boje.sivaTekst))
            teme.forEach { (naziv, v) ->
                val deo = if (v.getOrElse(1) { 0 } > 0) v[0].toFloat() / v[1] else null
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Row { Text(naziv, style = tekst(15.sp, FontWeight.Bold), modifier = Modifier.weight(1f)); Text(deo?.let { "${(it * 100).toInt()}%" } ?: "–", style = tekst(14.sp, FontWeight.Bold)) }
                    Box(Modifier.fillMaxWidth().height(8.dp).background(Boje.udubljeno, RoundedCornerShape(4.dp))) {
                        Box(Modifier.fillMaxHeight().fillMaxWidth(deo ?: 0f).background(Boje.teal, RoundedCornerShape(4.dp)))
                    }
                }
            }
            Spacer(Modifier.height(40.dp))
        }
    }
}
