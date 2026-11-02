package club.librum.kviz.osvajanje

import android.graphics.Region as AndroidRegion
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Public
import androidx.compose.material.icons.rounded.Remove
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.asAndroidPath
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import club.librum.kviz.ui.Boje
import club.librum.kviz.ui.SpaceGrotesk
import club.librum.kviz.ui.naslov
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

private val NEUTRALNE = listOf(Color(0xFFCFEDE6), Color(0xFFFFD9E6), Color(0xFFFFF0BF), Color(0xFFDED5F7), Color(0xFFD3ECFA))
private val OKEAN = Color(0xFFE3EDF2)

/** Putanje država iz SVG zapisa (M/L/Z), pretvorene jednom. */
private object PutanjeMape {
    val sve: Map<String, Path> by lazy { Mapa.oblasti.associate { it.id to parsiraj(it.d) } }

    // Region za proveru dodira, u koordinatama mape ×4 (Region radi sa celim brojevima).
    val oblasti: Map<String, AndroidRegion> by lazy {
        val granica = AndroidRegion(0, 0, (Mapa.sirina * 4).toInt(), (Mapa.visina * 4).toInt())
        sve.mapValues { (_, p) ->
            val a = android.graphics.Path(p.asAndroidPath()).apply { transform(android.graphics.Matrix().apply { setScale(4f, 4f) }) }
            AndroidRegion().apply { setPath(a, granica) }
        }
    }

    fun parsiraj(d: String): Path {
        val p = Path()
        var komanda = 'M'
        val brojevi = ArrayList<Float>()
        val broj = StringBuilder()
        fun zavrsiBroj() { broj.toString().toFloatOrNull()?.let { brojevi += it }; broj.clear() }
        fun primeni() {
            var i = 0
            while (i + 1 < brojevi.size) {
                if (komanda == 'M') { p.moveTo(brojevi[i], brojevi[i + 1]); komanda = 'L' } else p.lineTo(brojevi[i], brojevi[i + 1])
                i += 2
            }
            brojevi.clear()
        }
        for (z in d) when (z) {
            'M', 'L' -> { zavrsiBroj(); primeni(); komanda = z }
            'Z', 'z' -> { zavrsiBroj(); primeni(); p.close() }
            ',', ' ' -> zavrsiBroj()
            '-' -> { zavrsiBroj(); broj.append('-') }
            else -> broj.append(z)
        }
        zavrsiBroj(); primeni()
        return p
    }
}

/**
 * Mapa sveta po državama u stilu infografike: svetle neutralne države (susedi
 * različiti), osvojene u boji igrača, bele granice, značke sa vojskama.
 * Zum i pomeranje prstima, dodir bira državu (male države i preko značke).
 */
@Composable
fun MapaPrikaz(stanje: Stanje, izabrana: String?, mete: List<String>, fokus: String?, dodir: (String) -> Unit, modifier: Modifier = Modifier) {
    val merac = rememberTextMeasurer()
    val gustina = LocalDensity.current.density
    var razmera by remember { mutableFloatStateOf(1f) }
    var pomak by remember { mutableStateOf(Offset.Zero) }

    BoxWithConstraints(
        modifier.clip(RoundedCornerShape(24.dp)).border(2.5.dp, Boje.mastilo, RoundedCornerShape(24.dp))
            .semantics { contentDescription = "Mapa sveta" + (izabrana?.let { ", izabrana ${Mapa.oblast(it).ime}" } ?: "") },
    ) {
        val sirinaPx = constraints.maxWidth.toFloat()
        val visinaPx = constraints.maxHeight.toFloat()
        val osnova = min(sirinaPx / Mapa.sirina, visinaPx / Mapa.visina)

        // Pomeranje ne sme da otkrije prazan okean van mape; manja osa ostaje centrirana.
        fun ogranici(p: Offset, k: Float): Offset {
            val mx = max(0f, (Mapa.sirina * k - sirinaPx) / 2)
            val my = max(0f, (Mapa.visina * k - visinaPx) / 2)
            return Offset(p.x.coerceIn(-mx, mx), p.y.coerceIn(-my, my))
        }
        fun pocetak(k: Float) = Offset((sirinaPx - Mapa.sirina * k) / 2 + pomak.x, (visinaPx - Mapa.visina * k) / 2 + pomak.y)

        // Telefon: mapa krene uvećana oko prestonice ili mesta bitke.
        LaunchedEffect(fokus) {
            val id = fokus ?: return@LaunchedEffect
            val o = Mapa.oblast(id)
            if (sirinaPx / gustina < 700) razmera = max(razmera, max(2.4f, visinaPx / (Mapa.visina * osnova)))
            val k = osnova * razmera
            pomak = ogranici(Offset((Mapa.sirina / 2 - o.x) * k, (Mapa.visina / 2 - o.y) * k), k)
        }

        Canvas(
            Modifier.fillMaxSize().background(OKEAN)
                .pointerInput(Unit) {
                    detectTransformGestures { _, pan, zum, _ ->
                        razmera = (razmera * zum).coerceIn(1f, 8f)
                        pomak = ogranici(pomak + pan, osnova * razmera)
                    }
                }
                .pointerInput(stanje, mete, izabrana) {
                    detectTapGestures { t ->
                        val k = osnova * razmera
                        val p = pocetak(k)
                        val x = (t.x - p.x) / k
                        val y = (t.y - p.y) / k
                        val pogodak = Mapa.oblasti.firstOrNull { PutanjeMape.oblasti[it.id]?.contains((x * 4).toInt(), (y * 4).toInt()) == true }
                        val blizu = Mapa.oblasti.minByOrNull { hypot(it.x - x, it.y - y) }
                        when {
                            pogodak != null -> dodir(pogodak.id)
                            // Male države (Luksemburg, Liban) pogađaju se i preko značke.
                            blizu != null && hypot(blizu.x - x, blizu.y - y) * k < 22 * gustina -> dodir(blizu.id)
                        }
                    }
                },
        ) {
            val k = osnova * razmera
            val p = pocetak(k)
            translate(p.x, p.y) {
                withTransform({ scale(k, k, pivot = Offset.Zero) }) {
                    for (o in Mapa.oblasti) {
                        val put = PutanjeMape.sve[o.id] ?: continue
                        val st = stanje.oblasti[o.id] ?: continue
                        val boja = stanje.igraci.firstOrNull { it.id == st.vlasnik }?.let { Color(it.boja) } ?: NEUTRALNE[o.boja % 5]
                        drawPath(put, boja)
                        drawPath(put, Color.White, style = Stroke(1.1f * gustina / k))
                    }
                    for (id in mete) {
                        val put = PutanjeMape.sve[id] ?: continue
                        drawPath(put, Boje.mastilo.copy(alpha = 0.08f))
                        drawPath(put, Boje.mastilo, style = Stroke(2.5f * gustina / k, pathEffect = PathEffect.dashPathEffect(floatArrayOf(6f * gustina / k, 5f * gustina / k))))
                    }
                    izabrana?.let { id -> PutanjeMape.sve[id]?.let { drawPath(it, Boje.zuta, style = Stroke(5f * gustina / k, join = StrokeJoin.Round)) } }
                }
            }
            // Značke u pikselima ekrana, iste veličine na svakom zumu.
            val krupno = Mapa.sirina * k > sirinaPx * 4.5f
            val prestonice = stanje.igraci.map { it.prestonica }.toSet()
            val r = 11f * gustina
            for (o in Mapa.oblasti) {
                val st = stanje.oblasti[o.id] ?: continue
                val vlasnik = stanje.igraci.firstOrNull { it.id == st.vlasnik }
                if (vlasnik == null && !krupno && o.id !in mete) continue
                val c = Offset(p.x + o.x * k, p.y + o.y * k)
                drawCircle(Boje.mastilo, r, c + Offset(0f, 2f * gustina))
                drawCircle(vlasnik?.let { Color(it.boja) } ?: Color.White, r, c)
                drawCircle(Boje.mastilo, r, c, style = Stroke(1.8f * gustina))
                val broj = merac.measure("${st.vojske}", naslov(12.sp).copy(color = if (vlasnik == null) Boje.mastilo else Color.White))
                drawText(broj, topLeft = c - Offset(broj.size.width / 2f, broj.size.height / 2f))
                if (o.id in prestonice) {
                    val kruna = Path().apply {
                        val y0 = c.y - r - 2 * gustina
                        moveTo(c.x - 7 * gustina, y0); lineTo(c.x - 7 * gustina, y0 - 7 * gustina); lineTo(c.x - 3.5f * gustina, y0 - 3.5f * gustina)
                        lineTo(c.x, y0 - 8 * gustina); lineTo(c.x + 3.5f * gustina, y0 - 3.5f * gustina); lineTo(c.x + 7 * gustina, y0 - 7 * gustina)
                        lineTo(c.x + 7 * gustina, y0); close()
                    }
                    drawPath(kruna, Boje.zuta)
                    drawPath(kruna, Boje.mastilo, style = Stroke(1.4f * gustina))
                }
                if (krupno && (o.povrsina * k * k > 2200 * gustina * gustina || o.id in mete || o.id == izabrana)) {
                    val ime = merac.measure(o.ime, TextStyle(fontFamily = SpaceGrotesk, fontWeight = FontWeight.Bold, fontSize = 11.sp, color = Boje.mastilo))
                    drawText(ime, topLeft = Offset(c.x - ime.size.width / 2f, c.y + r + 2 * gustina))
                }
            }
        }

        Column(Modifier.align(Alignment.TopEnd).padding(10.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf(
                Triple(Icons.Rounded.Add, "Uvećaj") { razmera = min(8f, razmera * 1.5f) },
                Triple(Icons.Rounded.Remove, "Umanji") { razmera = max(1f, razmera / 1.5f); pomak = ogranici(pomak, osnova * razmera) },
                Triple(Icons.Rounded.Public, "Ceo svet") { razmera = 1f; pomak = Offset.Zero },
            ).forEach { (ikonica, opis, radnja) ->
                IconButton(onClick = radnja, modifier = Modifier.size(44.dp).background(Color.White, CircleShape).border(2.dp, Boje.mastilo, CircleShape)) {
                    Icon(ikonica, contentDescription = opis, tint = Boje.mastilo)
                }
            }
        }
    }
}
