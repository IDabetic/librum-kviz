package club.librum.kviz.karijera

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameMillis
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import java.time.LocalDate
import java.time.LocalTime
import kotlin.math.abs
import kotlin.math.min
import kotlin.math.sin

/**
 * Nebo iza officea po stvarnom dobu dana (prenos iOS Nebo.swift): jutro, dan, veče, noć, uz vreme za dan i mesto
 * (vedro/oblačno/kiša, ptice, avion, zvezde). Isti dan i ista firma daju isto vreme kao na iPhonu (isti SplitMix).
 */
enum class Doba(val boje: List<Color>) {
    JUTRO(listOf(Color(0xFFF9C9A8), Color(0xFFFCE6C7), Color(0xFFBFE3F2))),
    DAN(listOf(Color(0xFF7FC8F0), Color(0xFFB9E2F7), Color(0xFFE6F5FC))),
    VECE(listOf(Color(0xFF3B2F6B), Color(0xFFC8608A), Color(0xFFF4A35C))),
    NOC(listOf(Color(0xFF0B1330), Color(0xFF1B2A55), Color(0xFF2C3D6E)));

    companion object {
        fun sada(): Doba = when (LocalTime.now().hour) { in 5..8 -> JUTRO; in 9..17 -> DAN; in 18..20 -> VECE; else -> NOC }
    }
}

data class Vreme(val nebo: Int, val ptice: Boolean, val avion: Boolean, val zvezde: Boolean, val oblaciNocu: Boolean) {
    companion object {
        const val VEDRO = 0; const val OBLACNO = 1; const val KISA = 2
        fun za(mesto: String, dan: LocalDate = LocalDate.now()): Vreme {
            var h = 0L
            mesto.codePoints().forEach { h = h * 31 + it }
            val seme = (dan.year * 10000 + dan.monthValue * 100 + dan.dayOfMonth).toLong().toULong() + (h and 0xFFFFFF).toULong()
            val g = SplitMix(seme)
            val r = g.sledeci()
            return Vreme(if (r < 0.55) VEDRO else if (r < 0.85) OBLACNO else KISA, g.sledeci() < 0.6, g.sledeci() < 0.4, g.sledeci() < 0.75, g.sledeci() < 0.45)
        }
    }
}

/** Mali generator sa semenom (isti kao iOS): zvezde stoje na istim mestima između kadrova. */
class SplitMix(private var stanje: ULong) {
    fun sledeci(): Double {
        stanje += 0x9E3779B97F4A7C15uL
        var z = stanje
        z = (z xor (z shr 30)) * 0xBF58476D1CE4E5B9uL
        z = (z xor (z shr 27)) * 0x94D049BB133111EBuL
        return ((z xor (z shr 31)) shr 11).toDouble() / (1L shl 53).toDouble()
    }
}

@Composable
fun Nebo(modifier: Modifier = Modifier, mesto: String = "", doba: Doba = Doba.sada(), zadato: Vreme? = null) {
    val v = remember(mesto, zadato) { zadato ?: Vreme.za(mesto) }
    var t by remember { mutableDoubleStateOf(0.0) }
    LaunchedEffect(Unit) { while (true) withFrameMillis { t = it / 1000.0 } }
    val boje = if (v.nebo == Vreme.VEDRO || doba == Doba.NOC) doba.boje else doba.boje.map { it.copy(alpha = 0.75f) }
    Canvas(modifier.background(Color(0xFF8C98A6)).background(Brush.verticalGradient(boje))) {
        if (doba == Doba.NOC) {
            if (v.zvezde && v.nebo != Vreme.KISA) zvezde(t) else mesec()
            if (v.oblaciNocu || v.nebo != Vreme.VEDRO) oblaci(t, doba, Color(0xFF3A4A7A).copy(alpha = 0.85f), if (v.nebo == Vreme.VEDRO) 2 else 3)
        } else {
            if (v.nebo != Vreme.KISA) sunce(doba)
            oblaci(t, doba, if (v.nebo == Vreme.VEDRO) null else Color(0xFFC9D2DC).copy(alpha = 0.95f), if (v.nebo == Vreme.VEDRO) 2 else 3)
            if (v.ptice && v.nebo != Vreme.KISA && (doba == Doba.JUTRO || doba == Doba.DAN)) ptice(t)
        }
        if (v.avion && v.nebo != Vreme.KISA) avion(t, doba)
        if (v.nebo == Vreme.KISA) kisa(t)
    }
}

private fun DrawScope.mesec() {
    val d = min(40.dp2px(this), min(size.width, size.height) * 0.16f)
    val o = Offset(size.width * 0.78f, size.height * 0.08f)
    drawOval(Color(0xFFF4EFD8), o, Size(d, d))
    drawOval(Color(0xFF0B1330), o + Offset(d * 0.28f, -d * 0.15f), Size(d, d))
}

private fun Float.dp2px(s: DrawScope) = this * s.density
private fun Int.dp2px(s: DrawScope) = this * s.density

private fun DrawScope.zvezde(t: Double) {
    val g = SplitMix(7uL)
    for (i in 0 until 70) {
        val x = g.sledeci().toFloat() * size.width; val y = g.sledeci().toFloat() * size.height * 0.75f
        val r = (0.6f + g.sledeci().toFloat() * 1.4f) * density
        val svetlo = 0.45 + 0.55 * abs(sin(t * 0.8 + i))
        drawCircle(Color.White.copy(alpha = svetlo.toFloat()), r, Offset(x + r, y + r))
    }
    mesec()
}

private fun DrawScope.sunce(doba: Doba) {
    val (x, y) = when (doba) { Doba.JUTRO -> size.width * 0.18f to size.height * 0.42f; Doba.VECE -> size.width * 0.82f to size.height * 0.55f; else -> size.width * 0.8f to size.height * 0.16f }
    val r = min(26.dp2px(this), min(size.width, size.height) * 0.1f)
    drawCircle(Color.White.copy(alpha = 0.18f), r * 1.8f, Offset(x, y))
    drawCircle(if (doba == Doba.VECE) Color(0xFFFFB36B) else Color(0xFFFFE27A), r, Offset(x, y))
}

private fun DrawScope.oblaci(t: Double, doba: Doba, posebna: Color?, broj: Int) {
    val boja = posebna ?: if (doba == Doba.VECE) Color(0xFFF7C3B5).copy(alpha = 0.75f) else Color.White.copy(alpha = 0.9f)
    val red = listOf(Triple(0.12f, 1.0f, 9.0), Triple(0.3f, 0.75f, 6.0), Triple(0.5f, 0.6f, 4.0), Triple(0.22f, 1.2f, 5.0))
    red.take(if (broj == 3 && posebna != null) 4 else broj).forEachIndexed { i, (y, v, brzina) ->
        val sirina = min(120.dp2px(this), size.width * 0.42f) * v
        val put = size.width + sirina * 2
        val x = ((t * brzina * density + i * put / 3.0) % put).toFloat() - sirina
        val h = sirina * 0.32f; val p = Offset(x, size.height * y)
        drawRoundRect(boja, p, Size(sirina, h), CornerRadius(h / 2, h / 2))
        drawOval(boja, p + Offset(sirina * 0.18f, -h * 0.55f), Size(sirina * 0.38f, h * 1.2f))
        drawOval(boja, p + Offset(sirina * 0.45f, -h * 0.85f), Size(sirina * 0.36f, h * 1.4f))
    }
}

private fun DrawScope.ptice(t: Double) {
    val put = size.width + 120 * density
    for (i in 0 until 4) {
        val x = ((t * 24 * density + i * 34 * density) % put).toFloat() - 60 * density
        val y = size.height * 0.22f + (i % 2) * 14 * density + sin(t * 1.5 + i).toFloat() * 4 * density
        val mah = sin(t * 9 + i).toFloat() * 4 * density
        val d = density
        val p = Path().apply {
            moveTo(x - 7 * d, y - mah); quadraticTo(x - 3 * d, y - 4 * d, x, y); quadraticTo(x + 3 * d, y - 4 * d, x + 7 * d, y - mah)
        }
        drawPath(p, Color(0xFF2C3D4E), style = Stroke(1.6f * d, cap = StrokeCap.Round))
    }
}

private fun DrawScope.avion(t: Double, doba: Doba) {
    val d = density
    val put = size.width + 160 * d
    val x = ((t * 30 * d) % put).toFloat() - 80 * d
    val y = size.height * 0.12f
    drawLine(Color.White.copy(alpha = if (doba == Doba.NOC) 0.15f else 0.6f), Offset(x - 70 * d, y + d), Offset(x - 8 * d, y + d), 2 * d, StrokeCap.Round)
    val boja = if (doba == Doba.NOC) Color(0xFFC9D2DC) else Color(0xFF4A5A6A)
    drawRoundRect(boja, Offset(x - 9 * d, y - 1.5f * d), Size(20 * d, 4 * d), CornerRadius(2 * d, 2 * d))
    drawPath(Path().apply { moveTo(x, y); lineTo(x - 5 * d, y - 7 * d); lineTo(x + d, y); close() }, boja)
    drawPath(Path().apply { moveTo(x - 7 * d, y); lineTo(x - 10 * d, y - 4 * d); lineTo(x - 8 * d, y); close() }, boja)
    if (doba == Doba.NOC && (t * 2).toInt() % 2 == 0) drawCircle(Color.Red, 1.5f * d, Offset(x + 10.5f * d, y + 0.5f * d))
}

private fun DrawScope.kisa(t: Double) {
    val g = SplitMix(11uL)
    for (i in 0 until 60) {
        val x0 = g.sledeci().toFloat() * size.width; val brzina = 180 + g.sledeci() * 120; val faza = g.sledeci()
        val yy = ((t * brzina * density + faza * size.height) % size.height).toFloat()
        drawLine(Color.White.copy(alpha = 0.55f), Offset(x0, yy), Offset(x0 - 3 * density, yy + 10 * density), 1.2f * density, StrokeCap.Round)
    }
}
