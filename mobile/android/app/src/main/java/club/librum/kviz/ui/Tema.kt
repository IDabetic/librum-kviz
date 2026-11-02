package club.librum.kviz.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.clickable
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import club.librum.kviz.R

// Vizuelni jezik QuizPop kita, isti kao veb i iOS: krem papir, mastilo,
// debele ivice sa tvrdom senkom, Archivo Black kurziv za naslove.

/**
 * Boje teme iz kita (Quizpop · Theme), svetla i tamna. `tamno` je Compose stanje,
 * pa svaka boja koja se čita u kompoziciji prati promenu teme bez prosleđivanja.
 */
object Boje {
    var tamno by mutableStateOf(false)
    private fun t(svetlo: Long, tamna: Long) = Color(if (tamno) tamna else svetlo)

    val krem get() = t(0xFFF3F0E6, 0xFF12110F)          // surface/canvas
    val kremTamnija get() = t(0xFFE7E1D0, 0xFF3B3832)   // border/default
    val udubljeno get() = t(0xFFE7E1D0, 0xFF2E2B26)     // surface/sunken
    val skelet get() = t(0xFFDDD6C6, 0xFF3B3832)        // surface/skeleton
    val kartica get() = t(0xFFFFFFFF, 0xFF24221E)       // surface/card
    val mastilo get() = t(0xFF151515, 0xFFF3F0E6)       // text/primary, border/strong
    val naMastilu get() = t(0xFFFFFFFF, 0xFF151515)     // text/inverse
    val senka get() = t(0xFF151515, 0xFF000000)
    val sivaTekst get() = if (tamno) Color(0x99FFFFFF) else Color(0x99151515)
    val teal = Color(0xFF12907E)
    val tealSvetla get() = t(0xFFDFF3EE, 0xFF173A34)
    val roze = Color(0xFFFF5FA2)
    val ljubicasta = Color(0xFF6D4BC9)
    val zuta = Color(0xFFFFD84D)
    val narandzasta = Color(0xFFF4A33C)
    val nebo = Color(0xFF6EC3F2)
    val crvena get() = t(0xFFE5385C, 0xFFFF4D6D)
    val crvenaSvetla get() = t(0xFFFFE3EA, 0xFF3D1D26)
    /** Tekst na jarkim karticama (žuta, narandžasta, nebo) ostaje taman u obe teme. */
    val tinta = Color(0xFF151515)
}

// Archivo Black nema kurzivni rez; Compose ga naginje sintezom (FontSynthesis.Style).
val ArchivoBlack = FontFamily(Font(R.font.archivo_black))

@OptIn(androidx.compose.ui.text.ExperimentalTextApi::class)
val SpaceGrotesk = FontFamily(
    listOf(400, 500, 600, 700).map { w ->
        Font(R.font.space_grotesk, FontWeight(w), variationSettings = FontVariation.Settings(FontVariation.weight(w)))
    },
)

fun naslov(velicina: TextUnit, boja: Color = Boje.mastilo) = TextStyle(fontFamily = ArchivoBlack, fontStyle = FontStyle.Italic, fontSize = velicina, color = boja, letterSpacing = (-0.3).sp)
fun tekst(velicina: TextUnit, tezina: FontWeight = FontWeight.Medium, boja: Color = Boje.mastilo) =
    TextStyle(fontFamily = SpaceGrotesk, fontWeight = tezina, fontSize = velicina, color = boja)

/** Izražena kartica: debela ivica i tvrda senka. */
fun Modifier.pop(boja: Color = Boje.kartica, radijus: Dp = 24.dp, senka: Dp = 5.dp): Modifier = this
    .drawBehind {
        drawRoundRect(Boje.senka, topLeft = Offset(0f, senka.toPx()), size = size, cornerRadius = CornerRadius(radijus.toPx()))
    }
    .background(boja, RoundedCornerShape(radijus))
    .border(2.5.dp, Boje.mastilo, RoundedCornerShape(radijus))

/** Mirna bela kartica bez senke. */
fun Modifier.mirna(): Modifier = this
    .background(Boje.kartica, RoundedCornerShape(20.dp))
    .border(1.5.dp, Boje.kremTamnija, RoundedCornerShape(20.dp))

enum class VrstaDugmeta { PRIMARNO, SEKUNDARNO, ZUTO }

/** Dugme kao fizičko: pritisak ga spušta na senku. */
@Composable
fun Dugme(natpis: String, modifier: Modifier = Modifier, vrsta: VrstaDugmeta = VrstaDugmeta.PRIMARNO, omoguceno: Boolean = true, radnja: () -> Unit) {
    val izvor = remember { MutableInteractionSource() }
    val pritisnuto by izvor.collectIsPressedAsState()
    val haptika = LocalHapticFeedback.current
    val (pozadina, boja) = if (!omoguceno) Boje.skelet to Boje.sivaTekst else when (vrsta) {
        VrstaDugmeta.PRIMARNO -> Boje.mastilo to Boje.naMastilu
        VrstaDugmeta.SEKUNDARNO -> Boje.kartica to Boje.mastilo
        VrstaDugmeta.ZUTO -> Boje.zuta to Boje.tinta
    }
    Box(
        modifier
            .fillMaxWidth()
            .heightIn(min = 54.dp)
            .offset(y = if (pritisnuto) 3.dp else 0.dp)
            .pop(pozadina, 16.dp, if (!omoguceno) 0.dp else if (pritisnuto) 1.dp else 4.dp)
            .clickable(izvor, null, enabled = omoguceno, role = Role.Button) {
                haptika.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                radnja()
            }
            .padding(horizontal = 16.dp, vertical = 14.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(natpis, style = tekst(16.sp, FontWeight.Bold, boja))
    }
}

/** Oznaka malim verzalom, umesto kapsule. */
@Composable
fun Oznaka(tekst: String, boja: Color = Boje.sivaTekst) {
    Text(tekst.uppercase(), style = tekst(11.sp, FontWeight.Bold, boja).copy(letterSpacing = 1.3.sp))
}

/** Talasasta tekstura papira iz kita. */
@Composable
fun Papir(modifier: Modifier = Modifier) {
    Canvas(modifier.fillMaxSize().background(Boje.krem)) {
        val korak = 28.dp.toPx()
        var y = korak / 2
        while (y < size.height) {
            val p = Path().apply {
                moveTo(0f, y)
                var x = 0f
                val talas = 80.dp.toPx()
                while (x < size.width) {
                    cubicTo(x + talas / 4, y - 8, x + talas * 3 / 4, y + 8, x + talas, y)
                    x += talas
                }
            }
            drawPath(p, Boje.kremTamnija, style = Stroke(1.2.dp.toPx()))
            y += korak
        }
    }
}

enum class Maskota(val slika: Int) {
    MIMI(R.drawable.maskota_mimi), ZIG(R.drawable.maskota_zig), BLOOP(R.drawable.maskota_bloop), LUMI(R.drawable.maskota_lumi)
}

@Composable
fun MaskotaSlika(maskota: Maskota, velicina: Dp, modifier: Modifier = Modifier) {
    Image(painterResource(maskota.slika), contentDescription = null, modifier = modifier.size(velicina))
}
