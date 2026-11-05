package club.librum.kviz.karijera

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameMillis
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.sp
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/** Raspored izometrijskog grada (isto kao iOS IsoRaspored): blok 2×2 parcele + put, blokovi spiralno oko Korporacije. */
object IsoRaspored {
    const val PERIOD = 5
    const val PARCELA_KORPORACIJE = 3

    fun blokovi(broj: Int): List<Pair<Int, Int>> {
        val lista = mutableListOf(0 to 0)
        var r = 1
        while (lista.size < broj) {
            val prsten = mutableListOf<Pair<Int, Int>>()
            for (x in -r..r) for (y in -r..r) if (max(abs(x), abs(y)) == r) prsten += x to y
            prsten.sortBy { atan2(it.second.toDouble(), it.first.toDouble()) }
            lista += prsten
            r++
        }
        return lista.take(broj)
    }

    fun redni(parcela: Int) = if (parcela < PARCELA_KORPORACIJE) parcela else parcela - 1

    fun polje(parcela: Int, blokovi: List<Pair<Int, Int>>): Pair<Int, Int>? {
        if (parcela == PARCELA_KORPORACIJE) return null
        val k = redni(parcela); val b = 1 + k / 4; val s = k % 4
        if (b >= blokovi.size) return null
        return blokovi[b].first * PERIOD + (s % 2) * 2 to blokovi[b].second * PERIOD + (s / 2) * 2
    }

    fun brojBlokova(najvecaParcela: Int) = 1 + redni(max(najvecaParcela, 0)) / 4 + 1
}

private const val TW = 64f
private const val TH = 32f
private fun p(x: Float, y: Float) = Offset((x - y) * TW / 2, (x + y) * TH / 2)
private fun Offset.gore(h: Float) = Offset(x, y - h)
private fun poligon(a: Offset, b: Offset, c: Offset, d: Offset) = Path().apply { moveTo(a.x, a.y); lineTo(b.x, b.y); lineTo(c.x, c.y); lineTo(d.x, d.y); close() }
private fun poligonL(t: List<Offset>) = Path().apply { moveTo(t[0].x, t[0].y); for (i in 1 until t.size) lineTo(t[i].x, t[i].y); close() }
private fun slucajI(a: Int, b: Int): Float { val x = sin(a * 12.9898 + b * 78.233) * 43758.5453; return (x - kotlin.math.floor(x)).toFloat() }
private fun mod(a: Int, n: Int) = ((a % n) + n) % n

private class Zgrada(val f: GradFirma, val x0: Float, val y0: Float, val x1: Float, val y1: Float, val visina: Float) {
    fun obris() = poligonL(listOf(p(x0, y0).gore(visina), p(x1, y0).gore(visina), p(x1, y0), p(x1, y1), p(x0, y1), p(x0, y1).gore(visina)))
}

private class BojeZgrade(val leva: Color, val desna: Color, val krov: Color, val prozor: Color)
private fun bojeZgrade(f: GradFirma): BojeZgrade = if (f.korporacija) BojeZgrade(Color(0xFF5F8FBF), Color(0xFF3F6E9C), Color(0xFFEEF1F4), Color(0xFFBFE0F5)) else when (f.stil) {
    2 -> BojeZgrade(Color(0xFFC8674E), Color(0xFFA4513D), Color(0xFFE7E1D8), Color(0xFFBFDCF0))
    3 -> BojeZgrade(Color(0xFFFAFAFA), Color(0xFFD9DDE2), Color.White, Color(0xFF7FAED6))
    4 -> BojeZgrade(Color(0xFF8FD3C7), Color(0xFF6DB3A7), Color.White, Color(0xFF2F6F8A))
    5 -> BojeZgrade(Color(0xFFF4A33C), Color(0xFFD0832A), Color(0xFFEDE7DD), Color(0xFF4F7EA8))
    6 -> BojeZgrade(Color(0xFF9AA3AD), Color(0xFF7B848E), Color(0xFFD8DCE0), Color(0xFF24395E))
    7 -> BojeZgrade(Color(0xFFEAF3E6), Color(0xFFC9D6C3), Color(0xFF8CC56A), Color(0xFF6E9FCF))
    8 -> BojeZgrade(Color(0xFF34495E), Color(0xFF22313F), Color(0xFFF2C14E), Color(0xFFF7D774))
    else -> BojeZgrade(Color(0xFFF2F4F7), Color(0xFFD3D9E1), Color.White, Color(0xFF6E9FCF))
}

/**
 * Izometrijska mapa grada (isto kao iOS IsoGrad): zgrada po nivou, boja po stilu, putevi, drveće, kolica, pešaci,
 * balončići, zelenilo oko grada; pomeranje i zum prstima (ne izlazi se van grada), dodir otvara firmu.
 */
@Composable
fun IsoGrad(modifier: Modifier, firme: List<GradFirma>, moje: Set<String>, posao: String?, oznacena: String?,
            centriraj: Int?, centrirano: () -> Unit, otvori: (GradFirma) -> Unit) {
    var pomak by remember { mutableStateOf(Offset.Zero) }
    var zum by remember { mutableFloatStateOf(0.8f) }
    var t by remember { mutableDoubleStateOf(0.0) }
    LaunchedEffect(Unit) { while (true) withFrameMillis { t = it / 1000.0 } }
    val merac = rememberTextMeasurer()
    val gustina = androidx.compose.ui.platform.LocalDensity.current.density

    val najveca = firme.maxOfOrNull { it.parcela } ?: 0
    val prsten = remember(najveca) { (IsoRaspored.blokovi(IsoRaspored.brojBlokova(najveca)).maxOf { max(abs(it.first), abs(it.second)) }) + 1 }
    val blokovi = remember(prsten) { IsoRaspored.blokovi((2 * prsten + 1) * (2 * prsten + 1)) }
    val min0 = (-prsten * IsoRaspored.PERIOD - 1).toFloat()
    val max0 = (prsten * IsoRaspored.PERIOD + IsoRaspored.PERIOD).toFloat()
    val zgrade = remember(firme, blokovi) {
        firme.mapNotNull { f ->
            if (f.korporacija) Zgrada(f, 0.7f, 0.7f, 3.3f, 3.3f, 230f)
            else IsoRaspored.polje(f.parcela, blokovi)?.let { (x, y) ->
                val m = if (f.nivo <= 1) 0.45f else 0.25f
                Zgrada(f, x + m, y + m, x + 2 - m, y + 2 - m, listOf(0f, 16f, 32f, 58f, 96f, 150f)[f.nivo.coerceIn(1, 5)])
            }
        }.sortedBy { it.x1 + it.y1 }
    }
    val zauzete = remember(firme) { firme.map { it.parcela }.toSet() }
    fun ogranici(o: Offset, z: Float, g: Float): Offset {
        val r = (prsten * IsoRaspored.PERIOD + 3) * TW / 2 * z * g
        return Offset(o.x.coerceIn(-r, r), o.y.coerceIn(-r * 0.55f, r * 0.55f))
    }
    LaunchedEffect(centriraj) {
        val c = zgrade.firstOrNull { it.f.parcela == centriraj } ?: return@LaunchedEffect
        val s = p((c.x0 + c.x1) / 2, (c.y0 + c.y1) / 2)
        zum = 1.1f; pomak = Offset(-s.x * 1.1f * gustina, -(s.y - c.visina / 2) * 1.1f * gustina)
        centrirano()
    }

    Canvas(modifier
        .semantics { contentDescription = "Grad Karijeriste, ${firme.size} firmi. Pretraga iznad mape vodi do firme." }
        .pointerInput(prsten) {
            detectTransformGestures { _, pan, zoom, _ ->
                zum = (zum * zoom).coerceIn(0.25f, 2.2f)
                pomak = ogranici(pomak + pan, zum, gustina)
            }
        }
        .pointerInput(zgrade) {
            detectTapGestures { tacka ->
                val centar = Offset(size.width / 2f, size.height / 2f) + pomak
                val w = Offset((tacka.x - centar.x) / (zum * gustina), (tacka.y - centar.y) / (zum * gustina))
                zgrade.asReversed().firstOrNull { it.obris().getBounds().contains(w) && sadrzi(it, w) }?.let { otvori(it.f) }
            }
        }) {
        drawRect(Color(0xFF8CC56A))
        val centar = Offset(size.width / 2, size.height / 2) + pomak
        // Svet je u tačkama kao na iOS-u (polje 64 × 32), pa se množi gustinom ekrana.
        val k = zum * density
        withTransform({ translate(centar.x, centar.y); scale(k, k, Offset.Zero) }) {
            val vidljivo = Rect(-centar.x / k - 120, -centar.y / k - 260, (size.width - centar.x) / k + 120, (size.height - centar.y) / k + 260)
            trava(vidljivo, min0, max0)
            drawPath(poligon(p(min0, min0), p(max0, min0), p(max0, max0), p(min0, max0)), Color(0xFFE6E9EC))
            putevi(prsten, min0, max0)
            blokoviTlo(blokovi, zauzete, IsoRaspored.brojBlokova(najveca), vidljivo)
            // Zgrade, kola i pešaci u jednom redosledu od zadnjih ka prednjim (x + y), da kola ne idu preko krovova.
            val red = mutableListOf<Pair<Float, DrawScope.() -> Unit>>()
            zgrade.forEach { z -> if (vidljivo.contains(p(z.x1, z.y1)) || vidljivo.contains(p(z.x0, z.y0))) red += (z.x1 + z.y1) to { zgrada(z, zum, z.f.id in moje || z.f.id == posao || z.f.id == oznacena) } }
            red += saobracaj(prsten, min0, max0, t, vidljivo)
            red.sortedBy { it.first }.forEach { it.second(this) }
            if (zum > 0.32f) zgrade.forEach { z -> z.f.balon?.let { balon(z, it, t, zum, merac) } }
            if (zum >= 0.85f) zgrade.forEach { z -> ime(z, zum, merac) }
        }
    }
}

/** Tačka unutar šestougla zgrade (konveksan obris): sa iste strane svih ivica. */
private fun sadrzi(z: Zgrada, w: Offset): Boolean {
    val t = listOf(p(z.x0, z.y0).gore(z.visina), p(z.x1, z.y0).gore(z.visina), p(z.x1, z.y0), p(z.x1, z.y1), p(z.x0, z.y1), p(z.x0, z.y1).gore(z.visina))
    var znak = 0
    for (i in t.indices) {
        val a = t[i]; val b = t[(i + 1) % t.size]
        val c = (b.x - a.x) * (w.y - a.y) - (b.y - a.y) * (w.x - a.x)
        val s = if (c > 0) 1 else if (c < 0) -1 else 0
        if (s != 0) { if (znak == 0) znak = s else if (s != znak) return false }
    }
    return true
}

private fun DrawScope.drvo(x: Float, y: Float, s: Float = 1f) {
    val o = p(x, y)
    drawOval(Color.Black.copy(alpha = 0.1f), Offset(o.x - 7 * s, o.y - 3 * s), Size(14 * s, 6 * s))
    drawLine(Color(0xFF8A5A3B), o, o.gore(10 * s), 2.2f * s)
    drawCircle(Color(0xFF3FA34D), 8 * s, Offset(o.x, o.y - 16 * s))
    drawCircle(Color(0xFF6CC36F), 3.2f * s, Offset(o.x - 1.5f * s, o.y - 19 * s))
}

private fun DrawScope.trava(vidljivo: Rect, min0: Float, max0: Float) {
    val od = min0.toInt() - 24; val doo = max0.toInt() + 24
    var x = od
    while (x <= doo) {
        var y = od
        while (y <= doo) {
            val unutra = x > min0 - 1 && x < max0 + 1 && y > min0 - 1 && y < max0 + 1
            if (!unutra && slucajI(x, y) > 0.55f && vidljivo.contains(p(x.toFloat(), y.toFloat()))) drvo(x + slucajI(y, x), y.toFloat(), 1.1f)
            y += 3
        }
        x += 3
    }
}

private fun DrawScope.putevi(prsten: Int, min0: Float, max0: Float) {
    val asfalt = Color(0xFF41474E)
    for (k in (-prsten - 1)..prsten) {
        val a = (k * IsoRaspored.PERIOD + 4).toFloat()
        drawPath(poligon(p(min0, a), p(max0, a), p(max0, a + 1), p(min0, a + 1)), asfalt)
        drawPath(poligon(p(a, min0), p(a + 1, min0), p(a + 1, max0), p(a, max0)), asfalt)
        var s = min0
        while (s < max0) {
            drawLine(Color.White.copy(alpha = 0.85f), p(s, a + 0.5f), p(s + 0.4f, a + 0.5f), 1.2f)
            drawLine(Color.White.copy(alpha = 0.85f), p(a + 0.5f, s), p(a + 0.5f, s + 0.4f), 1.2f)
            s += 1f
        }
    }
}

private fun DrawScope.blokoviTlo(blokovi: List<Pair<Int, Int>>, zauzete: Set<Int>, n: Int, vidljivo: Rect) {
    blokovi.forEachIndexed { i, (bx, by) ->
        val x = (bx * IsoRaspored.PERIOD).toFloat(); val y = (by * IsoRaspored.PERIOD).toFloat()
        if (!vidljivo.contains(p(x + 2, y + 2))) return@forEachIndexed
        drawPath(poligon(p(x + 0.15f, y + 0.15f), p(x + 3.85f, y + 0.15f), p(x + 3.85f, y + 3.85f), p(x + 0.15f, y + 3.85f)), Color(if (i == 0) 0xFFF1F2F4 else 0xFFF6F7F8))
        if (i == 0) return@forEachIndexed
        for (s in 0 until 4) {
            val k = (i - 1) * 4 + s
            val prava = if (k >= IsoRaspored.PARCELA_KORPORACIJE) k + 1 else k
            if (prava in zauzete) continue
            val px = x + (s % 2) * 2; val py = y + (s / 2) * 2
            drawPath(poligon(p(px + 0.25f, py + 0.25f), p(px + 1.75f, py + 0.25f), p(px + 1.75f, py + 1.75f), p(px + 0.25f, py + 1.75f)), Color(if (i < n) 0xFF9BD17A else 0xFFA8D88A))
            drvo(px + 0.7f, py + 0.8f); drvo(px + 1.3f, py + 1.3f, 0.85f)
        }
        drvo(x + 0.15f, y + 3.85f, 0.7f); drvo(x + 3.85f, y + 3.85f, 0.7f)
    }
}

private fun DrawScope.zgrada(z: Zgrada, zum: Float, istaknuta: Boolean) {
    val b = bojeZgrade(z.f); val h = z.visina
    val a = p(z.x0, z.y0); val bb = p(z.x1, z.y0); val cc = p(z.x1, z.y1); val d = p(z.x0, z.y1)
    drawPath(poligon(cc, bb, Offset(bb.x + h * 0.35f, bb.y + h * 0.1f), Offset(cc.x + h * 0.35f, cc.y + h * 0.1f)), Color.Black.copy(alpha = 0.08f))
    drawPath(poligon(d, cc, cc.gore(h), d.gore(h)), b.leva)
    drawPath(poligon(cc, bb, bb.gore(h), cc.gore(h)), b.desna)
    if (zum > 0.45f) {
        val sprat = if (z.f.korporacija) 12f else 11f
        val spratova = max(1, (h / sprat).toInt() - if (h > 20) 1 else 0)
        for ((zid, alfa) in listOf((d to cc) to 1f, (cc to bb) to 0.8f)) {
            val (p0, p1) = zid
            val kolona = max(1, (hypot(p1.x - p0.x, p1.y - p0.y) / 9).toInt())
            val put = Path()
            for (s in 0 until spratova) {
                val v0 = s * sprat + sprat * 0.75f; val v1 = v0 + sprat * 0.45f
                for (k in 0 until kolona) {
                    val u0 = (k + 0.25f) / kolona; val u1 = (k + 0.75f) / kolona
                    val q0 = Offset(p0.x + (p1.x - p0.x) * u0, p0.y + (p1.y - p0.y) * u0)
                    val q1 = Offset(p0.x + (p1.x - p0.x) * u1, p0.y + (p1.y - p0.y) * u1)
                    put.addPath(poligon(q0.gore(v0), q1.gore(v0), q1.gore(v1), q0.gore(v1)))
                }
            }
            drawPath(put, b.prozor.copy(alpha = alfa))
        }
    }
    val krov = poligon(a.gore(h), bb.gore(h), cc.gore(h), d.gore(h))
    drawPath(krov, b.krov)
    drawPath(krov, Color.Black.copy(alpha = 0.08f), style = Stroke(0.8f))
    if (z.f.nivo >= 2 || z.f.korporacija) {
        val sx = (z.x0 + z.x1) / 2; val sy = (z.y0 + z.y1) / 2
        for ((dx, dy) in listOf(-0.25f to -0.1f, 0.2f to 0.15f)) { val o = p(sx + dx, sy + dy).gore(h); drawOval(Color(0xFFC9CED4), Offset(o.x - 4, o.y - 2), Size(8f, 4f)) }
    }
    if (z.f.stil == 8 && !z.f.korporacija) {
        val o = p((z.x0 + z.x1) / 2, (z.y0 + z.y1) / 2).gore(h)
        drawPath(poligonL(listOf(Offset(o.x - 6, o.y), Offset(o.x - 6, o.y - 7), Offset(o.x - 2, o.y - 3), Offset(o.x, o.y - 9), Offset(o.x + 2, o.y - 3), Offset(o.x + 6, o.y - 7), Offset(o.x + 6, o.y))), Color(0xFFF2C14E))
    }
    if (istaknuta) drawPath(krov, Color(0xFFFFD84D), style = Stroke(3f))
}

private val BOJE_AUTA = listOf(0xFFE5385C, 0xFF6EC3F2, 0xFFF7C531, 0xFFFFFFFF, 0xFF12907E, 0xFFF4A33C).map { Color(it) }

private fun saobracaj(prsten: Int, min0: Float, max0: Float, t: Double, vidljivo: Rect): List<Pair<Float, DrawScope.() -> Unit>> {
    val stavke = mutableListOf<Pair<Float, DrawScope.() -> Unit>>()
    val duzina = max0 - min0
    for (k in (-prsten - 1)..prsten) {
        val a = (k * IsoRaspored.PERIOD + 4).toFloat()
        for (i in 0 until 2) {
            val brzina = 0.6 + slucajI(k, i) * 0.6
            val napred = i == 0
            var s = ((t * brzina + slucajI(i, k) * 50) % duzina).toFloat()
            if (!napred) s = duzina - s
            for (duzX in listOf(true, false)) {
                val traka = if (napred) 0.3f else 0.7f
                val x = if (duzX) min0 + s else a + traka
                val y = if (duzX) a + traka else min0 + s
                val boja = BOJE_AUTA[mod(k + i + if (duzX) 0 else 3, BOJE_AUTA.size)]
                if (vidljivo.contains(p(x, y))) stavke += (x + y) to { auto(x, y, duzX, boja) }
            }
        }
        for (i in 0 until 2) {
            val s = ((t * 0.25 + slucajI(k, i + 7) * 30) % duzina).toFloat()
            val o = p(min0 + s, a - 0.12f - i * 0.05f)
            if (!vidljivo.contains(o)) continue
            val odeca = Color(listOf(0xFF2F4A7A, 0xFFE5674F, 0xFF6D4BC9)[mod(k + i, 3)])
            val dub = min0 + s + a - 0.12f - i * 0.05f
            stavke += dub to {
                drawRect(odeca, Offset(o.x - 1.4f, o.y - 6), Size(2.8f, 6f))
                drawCircle(Color(0xFFF2C9A0), 1.5f, Offset(o.x, o.y - 7.1f))
            }
        }
    }
    return stavke
}

private fun DrawScope.auto(x: Float, y: Float, duzX: Boolean, boja: Color) {
    val dx = if (duzX) 0.32f else 0.14f; val dy = if (duzX) 0.14f else 0.32f
    val a = p(x - dx, y - dy); val b = p(x + dx, y - dy); val c = p(x + dx, y + dy); val d = p(x - dx, y + dy)
    val h = 5f
    drawPath(poligon(d, c, c.gore(h), d.gore(h)), boja.copy(alpha = 0.85f))
    drawPath(poligon(c, b, b.gore(h), c.gore(h)), boja.copy(alpha = 0.65f))
    drawPath(poligon(a.gore(h), b.gore(h), c.gore(h), d.gore(h)), boja)
    val s = p(x, y)
    drawOval(Color(0xFFBFE6F5), Offset(s.x - 3, s.y - h - 2.5f), Size(6f, 3f))
}

private fun DrawScope.balon(z: Zgrada, tekst: String, t: Double, zum: Float, merac: androidx.compose.ui.text.TextMeasurer) {
    val ciklus = ((t + (z.f.parcela % 7) * 1.3) / 9) % 1.0
    val pr = min(1.0, ciklus / 0.45).toFloat()
    val alfa = if (pr < 0.15f) pr / 0.15f else if (pr > 0.75f) (1 - pr) / 0.25f else 1f
    if (alfa <= 0.02f) return
    val vrh = p((z.x0 + z.x1) / 2, (z.y0 + z.y1) / 2)
    val y = vrh.y - z.visina - 14 - pr * 18
    val s = 1 / max(zum, 0.5f)
    val r = merac.measure(tekst, TextStyle(fontSize = (11 * s).sp, fontWeight = FontWeight.Bold, color = if (tekst.startsWith("Napad")) Color(0xFFE5385C) else Color(0xFF1F2A36)))
    val w = r.size.width / density; val hh = r.size.height / density
    drawRoundRect(Color.White.copy(alpha = alfa), Offset(vrh.x - w / 2 - 7 * s, y - hh / 2 - 4 * s), Size(w + 14 * s, hh + 8 * s), androidx.compose.ui.geometry.CornerRadius(8 * s))
    val g = density
    withTransform({ translate(vrh.x - w / 2, y - hh / 2); scale(1 / g, 1 / g, Offset.Zero) }) { drawText(r, alpha = alfa) }
}

private fun DrawScope.ime(z: Zgrada, zum: Float, merac: androidx.compose.ui.text.TextMeasurer) {
    val dno = p(z.x1, z.y1)
    val r = merac.measure(z.f.ime, TextStyle(fontSize = (9 / zum * 0.9f).sp, fontWeight = FontWeight.Bold, color = Color(0xFF1F2A36)))
    val w = r.size.width / density; val hh = r.size.height / density
    drawRoundRect(Color.White.copy(alpha = 0.85f), Offset(dno.x - w / 2 - 4, dno.y + 3), Size(w + 8, hh + 3), androidx.compose.ui.geometry.CornerRadius(4f))
    val g = density
    withTransform({ translate(dno.x - w / 2, dno.y + 4.5f); scale(1 / g, 1 / g, Offset.Zero) }) { drawText(r) }
}

