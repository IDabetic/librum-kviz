package club.librum.kviz.karijera

import android.provider.Settings
import androidx.compose.foundation.Canvas
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.platform.LocalContext
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.sin

/**
 * Ulica ispred zgrade (vlasnik 05.11, isto kao iOS Ulica.swift): pešaci i vozila nacrtani u kodu, kao ptice na nebu.
 * Pešaci koračaju, točkovi se okreću, hitnoj trepće rotacija. Kad su animacije u telefonu isključene, ulica miruje.
 */
@Composable
fun Ulica(modifier: Modifier, mesto: String, gustina: Double = 1.0) {
    val k = LocalContext.current
    val animacije = remember { Settings.Global.getFloat(k.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) > 0f }
    if (!animacije) return
    var t by remember { mutableDoubleStateOf(0.0) }
    LaunchedEffect(Unit) { while (true) withFrameMillis { t = it / 1000.0 } }
    val seme = mesto.fold(0) { a, c -> (a * 31 + c.code) % 997 }.toDouble()
    Canvas(modifier) {
        traka(t, size.height * 0.17f, 14.0, 4 / gustina, size.height * 0.997f, seme + 1, vozila = false)
        traka(t, size.height * 0.13f, 4.5, 3.5 / gustina, size.height * 0.995f, seme + 2, vozila = true)
    }
}

/** Pseudo-slučajan broj 0..<1 za ceo broj i seme (isti kao na iOS-u). */
internal fun slucaj(n: Double, seme: Double): Double { val x = sin(n * 12.9898 + seme * 78.233) * 43758.5453; return x - floor(x) }

private val ODECA = listOf(0xFF12907E, 0xFFE5674F, 0xFF2F4A7A, 0xFFF4A33C, 0xFF6D4BC9, 0xFF7A8794, 0xFFFF5FA2).map { Color(it) }
private val KOZA = listOf(0xFFF2C9A0, 0xFFD9A06B, 0xFF9C6B45, 0xFFF7D7B5).map { Color(it) }
private val KAROSERIJA = listOf(0xFFE5385C, 0xFF6EC3F2, 0xFF12907E, 0xFF7A8794, 0xFF2F4A7A).map { Color(it) }
private val TAMNO = Color(0xFF24303C)
private val STAKLO = Color(0xFFBFE6F5)

private fun DrawScope.traka(t: Double, visina: Float, trajanje: Double, razmak: Double, dno: Float, seme: Double, vozila: Boolean) {
    val sada = floor(t / razmak)
    var n = sada - ceil(trajanje * 1.6 / razmak)
    while (n <= sada) {
        if (slucaj(n, seme) > 0.3) {
            val vrsta = (slucaj(n, seme + 3) * 100).toInt()
            val brzina = if (vozila) listOf(1.0, 0.9, 1.1, 0.85, 1.4, 0.7)[vrsta % 6] else if (vrsta % 7 == 0) 2.0 else 0.85 + slucaj(n, seme + 5) * 0.3
            val pocetak = n * razmak + slucaj(n, seme + 7) * razmak * 0.6
            val p = ((t - pocetak) / (trajanje / brzina)).toFloat()
            if (p in 0f..1f) {
                val duzina = if (vozila) visina * (if (vrsta % 6 == 5) 4.2f else 2.4f) else visina * 0.5f
                val udesno = slucaj(n, seme + 11) < 0.5
                val x = if (udesno) -duzina + p * (size.width + duzina) else size.width - p * (size.width + duzina)
                val predjeno = p * (size.width + duzina)
                translate(x + duzina / 2, dno) {
                    scale(if (udesno) 1f else -1f, 1f, Offset.Zero) {
                        if (vozila) vozilo(vrsta % 6, visina, duzina, predjeno, t, KAROSERIJA[vrsta % KAROSERIJA.size])
                        else pesak(visina, predjeno / (visina * 0.32f), ODECA[vrsta % ODECA.size], KOZA[(vrsta / 7) % KOZA.size], vrsta % 7 == 0, vrsta % 3 == 0)
                    }
                }
            }
        }
        n += 1
    }
}

private fun DrawScope.linija(a: Offset, b: Offset, boja: Color, debljina: Float) = drawLine(boja, a, b, debljina, StrokeCap.Round)

/** Pešak gleda udesno; (0,0) je tačka između stopala. */
private fun DrawScope.pesak(h: Float, faza: Float, boja: Color, koza: Color, bicikl: Boolean, torba: Boolean) {
    val d = max(1.2f, h * 0.075f)
    if (bicikl) {
        val r = h * 0.2f
        for (tx in listOf(-h * 0.3f, h * 0.3f)) drawCircle(TAMNO, r, Offset(tx, -r), style = Stroke(max(1f, h * 0.035f)))
        val ram = Path().apply {
            moveTo(-h * 0.3f, -r); lineTo(-h * 0.05f, -h * 0.5f); lineTo(h * 0.22f, -h * 0.5f); lineTo(h * 0.3f, -r)
            moveTo(-h * 0.05f, -h * 0.5f); lineTo(0f, -r)
        }
        drawPath(ram, boja, style = Stroke(max(1f, h * 0.045f), cap = StrokeCap.Round))
        val sediste = Offset(-h * 0.06f, -h * 0.56f)
        for (z in listOf(0.0, Math.PI)) {
            val ug = faza * 0.8 + z
            val stopalo = Offset((cos(ug) * h * 0.08).toFloat(), -r + (sin(ug) * h * 0.08).toFloat())
            val koleno = Offset((sediste.x + stopalo.x) / 2 + h * 0.1f, (sediste.y + stopalo.y) / 2 - h * 0.04f)
            linija(sediste, koleno, TAMNO, d); linija(koleno, stopalo, TAMNO, d)
        }
        linija(sediste, Offset(h * 0.06f, -h * 0.86f), boja, h * 0.14f)
        linija(Offset(h * 0.05f, -h * 0.8f), Offset(h * 0.22f, -h * 0.55f), koza, d * 0.8f)
        drawCircle(koza, h * 0.085f, Offset(h * 0.085f, -h * 0.955f))
        return
    }
    val mah = sin(faza) * 0.5f
    val kuk = Offset(0f, -h * 0.46f)
    for ((znak, alfa) in listOf(-1f to 0.75f, 1f to 1f)) {
        val u = mah * znak
        linija(kuk, Offset(kuk.x + sin(u) * h * 0.46f, kuk.y + cos(u) * h * 0.46f), TAMNO.copy(alpha = alfa), d)
    }
    val skok = abs(sin(faza)) * h * 0.02f
    val rame = Offset(h * 0.02f, -h * 0.8f - skok)
    linija(rame, Offset(rame.x - sin(mah) * h * 0.3f, rame.y + cos(mah) * h * 0.3f), boja.copy(alpha = 0.7f), d * 0.85f)
    drawRoundRect(boja, Offset(-h * 0.1f, -h * 0.86f - skok), Size(h * 0.2f, h * 0.42f), CornerRadius(h * 0.07f))
    val prednja = Offset(rame.x + sin(mah) * h * 0.3f, rame.y + cos(mah) * h * 0.3f)
    linija(rame, prednja, boja, d * 0.85f)
    if (torba) drawRoundRect(Color(0xFF3B2A20), Offset(prednja.x - h * 0.06f, prednja.y), Size(h * 0.13f, h * 0.1f), CornerRadius(h * 0.02f))
    drawCircle(koza, h * 0.085f, Offset(0.005f * h, -h * 0.955f - skok))
}

/** Vozilo gleda udesno; (0,0) je sredina ispod točkova. 0–2 auto, 3 kombi, 4 hitna, 5 autobus. */
private fun DrawScope.vozilo(vrsta: Int, h: Float, L: Float, predjeno: Float, t: Double, boja: Color) {
    val r = h * 0.2f
    val lim = when (vrsta) { 3, 4 -> Color(0xFFF4F6F8); 5 -> Color(0xFF5BB36A); 2 -> Color(0xFFF7C531); else -> boja }
    val telo = Path()
    when (vrsta) {
        3, 4 -> {
            telo.addRoundRect(androidx.compose.ui.geometry.RoundRect(-L / 2, -h * 1.15f, -L / 2 + L * 0.78f, -h * 0.2f, CornerRadius(h * 0.1f)))
            telo.addRoundRect(androidx.compose.ui.geometry.RoundRect(-L / 2 + L * 0.7f, -h * 0.85f, L / 2, -h * 0.2f, CornerRadius(h * 0.18f)))
        }
        5 -> telo.addRoundRect(androidx.compose.ui.geometry.RoundRect(-L / 2, -h * 1.25f, L / 2, -h * 0.2f, CornerRadius(h * 0.15f)))
        else -> {
            telo.addRoundRect(androidx.compose.ui.geometry.RoundRect(-L / 2, -h * 0.62f, L / 2, -h * 0.2f, CornerRadius(h * 0.16f)))
            telo.moveTo(-L * 0.3f, -h * 0.6f); telo.lineTo(-L * 0.18f, -h * 1.0f); telo.lineTo(L * 0.14f, -h * 1.0f); telo.lineTo(L * 0.3f, -h * 0.6f); telo.close()
        }
    }
    drawPath(telo, lim)
    drawPath(telo, TAMNO.copy(alpha = 0.35f), style = Stroke(max(0.6f, h * 0.03f)))
    when (vrsta) {
        3, 4 -> {
            drawRoundRect(STAKLO, Offset(L * 0.24f, -h * 0.78f), Size(L * 0.2f, h * 0.28f), CornerRadius(h * 0.06f))
            if (vrsta == 4) {
                drawRect(Color(0xFFE5385C), Offset(-L / 2, -h * 0.6f), Size(L * 0.78f, h * 0.12f))
                val trepce = (t * 4).toInt() % 2 == 0
                drawRoundRect(if (trepce) Color(0xFF3A7BFF) else Color(0xFFE5385C), Offset(-L * 0.05f, -h * 1.3f), Size(h * 0.25f, h * 0.15f), CornerRadius(h * 0.04f))
            }
        }
        5 -> for (i in 0 until 6) drawRoundRect(STAKLO, Offset(-L / 2 + L * 0.05f + i * L * 0.15f, -h * 1.1f), Size(L * 0.12f, h * 0.38f), CornerRadius(h * 0.05f))
        else -> {
            drawPath(Path().apply { moveTo(-L * 0.24f, -h * 0.64f); lineTo(-L * 0.16f, -h * 0.92f); lineTo(-L * 0.02f, -h * 0.92f); lineTo(-L * 0.02f, -h * 0.64f); close() }, STAKLO)
            drawPath(Path().apply { moveTo(L * 0.02f, -h * 0.64f); lineTo(L * 0.02f, -h * 0.92f); lineTo(L * 0.12f, -h * 0.92f); lineTo(L * 0.23f, -h * 0.64f); close() }, STAKLO)
            if (vrsta == 2) drawRoundRect(Color(0xFFFFF3B0), Offset(-L * 0.06f, -h * 1.12f), Size(L * 0.12f, h * 0.12f), CornerRadius(h * 0.03f))
        }
    }
    drawCircle(Color(0xFFFFE27A), h * 0.05f, Offset(L / 2 - h * 0.07f, -h * 0.45f))
    val ugao = predjeno / r
    for (tx in listOf(-L / 2 + L * 0.2f, L / 2 - L * 0.2f)) {
        drawCircle(TAMNO, r, Offset(tx, -r))
        drawCircle(Color(0xFFC9D2DC), r * 0.45f, Offset(tx, -r))
        linija(Offset(tx - cos(ugao) * r * 0.45f, -r - sin(ugao) * r * 0.45f), Offset(tx + cos(ugao) * r * 0.45f, -r + sin(ugao) * r * 0.45f), TAMNO, max(0.6f, r * 0.18f))
    }
}
