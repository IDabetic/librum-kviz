package club.librum.kviz.osvajanje

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import club.librum.kviz.ui.Boje
import club.librum.kviz.ui.naslov
import club.librum.kviz.ui.tekst
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.min
import kotlin.math.sin

private const val SIRINA = 1080f
private const val VISINA = 600f
private const val R = 44f

private val NATPISI = mapOf(
    "sam" to Offset(20f, 398f), "jam" to Offset(120f, 585f), "evr" to Offset(560f, 30f),
    "afr" to Offset(600f, 560f), "azi" to Offset(840f, 40f), "oke" to Offset(960f, 580f),
)

private fun sestougao(c: Offset, r: Float) = Path().apply {
    for (i in 0 until 6) {
        val ugao = PI / 3 * i - PI / 6
        val x = c.x + r * cos(ugao).toFloat()
        val y = c.y + r * sin(ugao).toFloat()
        if (i == 0) moveTo(x, y) else lineTo(x, y)
    }
    close()
}

/**
 * Mapa sveta: šestougaone oblasti sa vojskama, veze kao linije. Na telefonu se
 * pomera vodoravno (razmera 0,7 drži oblast oko 62 dp), na tabletu staje cela.
 * Svaka oblast ima nevidljivo dugme sa opisom za TalkBack.
 */
@Composable
fun MapaPrikaz(stanje: Stanje, izabrana: String?, mete: List<String>, dodir: (String) -> Unit, modifier: Modifier = Modifier) {
    val merac = rememberTextMeasurer()
    val pomeranje = rememberScrollState()
    val gustina = LocalDensity.current
    BoxWithConstraints(modifier) {
        val razmera = maxOf(min(maxWidth.value / SIRINA, maxHeight.value / VISINA).coerceAtMost(1f), 0.7f)
        val fokus = izabrana ?: stanje.igraci.firstOrNull { it.covek }?.prestonica ?: "balkan"
        val sirinaEkrana = with(gustina) { maxWidth.toPx() }
        LaunchedEffect(fokus) {
            val x = with(gustina) { (Mapa.oblast(fokus).x * razmera).dp.toPx() }
            pomeranje.animateScrollTo((x - sirinaEkrana / 2).toInt().coerceAtLeast(0))
        }
        Box(Modifier.align(androidx.compose.ui.Alignment.Center).horizontalScroll(pomeranje)) {
            Box(Modifier.size((SIRINA * razmera).dp, (VISINA * razmera).dp)) {
                Canvas(Modifier.fillMaxSize()) {
                    val k = size.width / SIRINA
                    crtajMapu(stanje, izabrana, mete, k, merac)
                }
                for (o in Mapa.oblasti) {
                    val st = stanje.oblasti.getValue(o.id)
                    val vlasnik = stanje.igraci.firstOrNull { it.id == st.vlasnik }
                    Box(
                        Modifier
                            .offset(((o.x - R) * razmera).dp, ((o.y - R) * razmera).dp)
                            .size((2 * R * razmera).dp)
                            .semantics {
                                contentDescription = "${o.ime}, ${st.vojske} vojski, ${vlasnik?.ime ?: "neutralno"}"
                                selected = izabrana == o.id
                            }
                            .clickable(role = Role.Button) { dodir(o.id) },
                    )
                }
            }
        }
    }
}

private fun DrawScope.crtajMapu(stanje: Stanje, izabrana: String?, mete: List<String>, k: Float, merac: androidx.compose.ui.text.TextMeasurer) {
    fun t(x: Float, y: Float) = Offset(x * k, y * k)

    for (kont in Mapa.kontinenti) {
        val p = NATPISI.getValue(kont.id)
        drawText(merac, "${kont.ime.uppercase()} +${kont.bonus}", t(p.x, p.y - 12),
            style = tekst((13 * k / density).sp, FontWeight.Bold, Boje.sivaTekst).copy(letterSpacing = 1.5.sp))
    }

    for ((a, b) in Mapa.veze) {
        val p = Mapa.oblast(a); val q = Mapa.oblast(b)
        val morska = hypot(p.x - q.x, p.y - q.y) > 150
        drawLine(
            Boje.mastilo.copy(alpha = if (morska) 0.35f else 0.55f), t(p.x, p.y), t(q.x, q.y),
            strokeWidth = (if (morska) 2f else 3f) * k, cap = StrokeCap.Round,
            pathEffect = if (morska) PathEffect.dashPathEffect(floatArrayOf(6f * k, 7f * k)) else null,
        )
    }

    val prestonice = stanje.igraci.map { it.prestonica }.toSet()
    for (o in Mapa.oblasti) {
        val st = stanje.oblasti.getValue(o.id)
        val vlasnik = stanje.igraci.firstOrNull { it.id == st.vlasnik }
        val c = t(o.x, o.y)
        val r = R * k
        if (izabrana == o.id || o.id in mete) {
            drawPath(
                sestougao(c, r + 9 * k), if (izabrana == o.id) Boje.zuta else Boje.mastilo,
                style = Stroke(width = (if (izabrana == o.id) 7f else 3f) * k,
                    pathEffect = if (o.id in mete) PathEffect.dashPathEffect(floatArrayOf(7f * k, 6f * k)) else null),
            )
        }
        drawPath(sestougao(c + Offset(0f, 5 * k), r), Boje.mastilo)
        drawPath(sestougao(c, r), vlasnik?.let { Color(it.boja) } ?: Color.White)
        drawPath(sestougao(c, r), Boje.mastilo, style = Stroke(3f * k))

        val broj = merac.measure("${st.vojske}", naslov((27 * k / density).sp).copy(color = if (vlasnik == null) Boje.mastilo else Color.White))
        drawText(broj, topLeft = c - Offset(broj.size.width / 2f, broj.size.height / 2f))
        if (o.id in prestonice) {
            val kruna = Path().apply {
                val y0 = c.y - 22 * k
                moveTo(c.x - 10 * k, y0); lineTo(c.x - 10 * k, y0 - 9 * k); lineTo(c.x - 5 * k, y0 - 4 * k); lineTo(c.x, y0 - 11 * k)
                lineTo(c.x + 5 * k, y0 - 4 * k); lineTo(c.x + 10 * k, y0 - 9 * k); lineTo(c.x + 10 * k, y0); close()
            }
            drawPath(kruna, Boje.zuta)
            drawPath(kruna, Boje.mastilo, style = Stroke(2f * k))
        }
        val ime = merac.measure(o.ime, TextStyle(fontWeight = FontWeight.Bold, fontSize = (13 * k / density).sp, color = Boje.mastilo, fontFamily = club.librum.kviz.ui.SpaceGrotesk))
        drawText(ime, topLeft = Offset(c.x - ime.size.width / 2f, c.y + r + 6 * k))
    }
}
