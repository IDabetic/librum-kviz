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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import club.librum.kviz.servisi.Prikaz
import kotlinx.coroutines.delay

private const val TRAJANJE_OTKRIVANJA_MS = 3000L

/**
 * Žuta kartica pitanja iz kita sa tajmerom. Javlja odgovor (indeks ili null
 * na istek) i proteklo vreme, posle kratkog otkrivanja tačnog odgovora.
 */
@Composable
fun PitanjeKartica(
    oznaka: String,
    prikaz: Prikaz,
    sekundi: Int = 15,
    dodatak: String? = null,
    eliminisani: Set<Int> = emptySet(),
    gotovo: (izabran: Int?, ms: Int) -> Unit,
) {
    val pocetak = remember(prikaz) { System.currentTimeMillis() }
    var izabran by remember(prikaz) { mutableStateOf<Int?>(null) }
    var otkriveno by remember(prikaz) { mutableStateOf(false) }
    var sada by remember(prikaz) { mutableLongStateOf(pocetak) }
    var trajalo by remember(prikaz) { mutableIntStateOf(0) }
    val haptika = LocalHapticFeedback.current

    fun izaberi(i: Int?) {
        if (otkriveno) return
        izabran = i
        otkriveno = true
        trajalo = (System.currentTimeMillis() - pocetak).toInt()
        haptika.performHapticFeedback(HapticFeedbackType.LongPress)
    }

    LaunchedEffect(prikaz, otkriveno, sekundi) {
        while (!otkriveno) {
            sada = System.currentTimeMillis()
            if (sada - pocetak >= sekundi * 1000L) izaberi(null)
            delay(100)
        }
        delay(TRAJANJE_OTKRIVANJA_MS)
        gotovo(izabran, trajalo)
    }

    val ostalo = (sekundi - (sada - pocetak) / 1000.0).coerceAtLeast(0.0)
    Column(
        Modifier.fillMaxWidth().pop(Boje.zuta).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Oznaka(oznaka, Boje.tinta)
            Spacer(Modifier.weight(1f))
            Text("${kotlin.math.ceil(ostalo).toInt()}", style = naslov(22.sp, Boje.tinta), modifier = Modifier.semantics { contentDescription = "${ostalo.toInt()} sekundi" })
        }
        Box(Modifier.fillMaxWidth().height(8.dp).background(Color.White.copy(alpha = 0.6f), RoundedCornerShape(4.dp))) {
            Box(
                Modifier.fillMaxWidth((ostalo / sekundi).toFloat()).fillMaxHeight()
                    .background(if (ostalo / sekundi < 0.34) Boje.crvena else Boje.tinta, RoundedCornerShape(4.dp)),
            )
        }
        Text(prikaz.tekst, style = naslov(23.sp, Boje.tinta))
        prikaz.opcije.forEachIndexed { i, opcija ->
            val stanje = when {
                !otkriveno -> StanjeOdgovora.OBICNO
                i == prikaz.tacan -> StanjeOdgovora.TACNO
                i == izabran -> StanjeOdgovora.NETACNO
                else -> StanjeOdgovora.BLEDO
            }
            OdgovorDugme("ABCD"[i].toString(), opcija, stanje, omoguceno = !otkriveno && i !in eliminisani,
                modifier = Modifier.alpha(if (i in eliminisani && !otkriveno) 0.3f else 1f)) { izaberi(i) }
        }
        if (otkriveno && dodatak != null) Text(dodatak, style = tekst(15.sp, FontWeight.Bold, Boje.tinta))
    }
}

enum class StanjeOdgovora { OBICNO, TACNO, NETACNO, BLEDO }

@Composable
fun OdgovorDugme(slovo: String, natpis: String, stanje: StanjeOdgovora, omoguceno: Boolean, modifier: Modifier = Modifier, radnja: () -> Unit) {
    val (pozadina, ivica, slovoPozadina, slovoBoja) = when (stanje) {
        StanjeOdgovora.OBICNO -> listOf(Boje.kartica, Boje.mastilo, Boje.tealSvetla, Boje.teal)
        StanjeOdgovora.TACNO -> listOf(Boje.tealSvetla, Boje.teal, Boje.teal, Color.White)
        StanjeOdgovora.NETACNO -> listOf(Boje.crvenaSvetla, Boje.crvena, Boje.crvena, Color.White)
        StanjeOdgovora.BLEDO -> listOf(Boje.kartica.copy(alpha = 0.45f), Color.Transparent, Boje.tealSvetla, Boje.teal)
    }
    Row(
        modifier
            .fillMaxWidth()
            .heightIn(min = 56.dp)
            .drawBehind {
                if (stanje != StanjeOdgovora.BLEDO) drawRoundRect(ivica, Offset(0f, 4.dp.toPx()), size, CornerRadius(18.dp.toPx()))
            }
            .background(pozadina, RoundedCornerShape(18.dp))
            .border(2.dp, ivica, RoundedCornerShape(18.dp))
            .clickable(enabled = omoguceno, role = Role.Button) { radnja() }
            .semantics { contentDescription = "$slovo: $natpis" }
            .padding(10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(36.dp).background(slovoPozadina, RoundedCornerShape(12.dp)), contentAlignment = Alignment.Center) {
            Text(slovo, style = tekst(15.sp, FontWeight.Bold, slovoBoja))
        }
        Spacer(Modifier.size(12.dp))
        Text(natpis, style = tekst(16.sp, FontWeight.SemiBold))
    }
}

/** Potvrda u stilu kita (umesto sistemskog dijaloga). */
@Composable
fun Dijalog(naslovTekst: String, opis: String, potvrda: String, odustani: String, potvrdi: () -> Unit, zatvori: () -> Unit) {
    Box(
        Modifier.fillMaxSize().background(Boje.senka.copy(alpha = 0.55f)).clickable(onClick = zatvori),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            Modifier.padding(24.dp).pop().clickable(enabled = false) {}.padding(22.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text(naslovTekst, style = naslov(26.sp))
            Text(opis, style = tekst(15.sp, boja = Boje.sivaTekst))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Dugme(odustani, Modifier.weight(1f), VrstaDugmeta.SEKUNDARNO, radnja = zatvori)
                Dugme(potvrda, Modifier.weight(1f), VrstaDugmeta.PRIMARNO, radnja = potvrdi)
            }
        }
    }
}
