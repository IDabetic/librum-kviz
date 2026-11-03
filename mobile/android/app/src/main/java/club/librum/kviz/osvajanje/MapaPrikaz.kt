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
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.CornerRadius
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
private val MORSKI_PUT = Color(0xFF4F7486)

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
fun MapaPrikaz(stanje: Stanje, izabrana: String?, mete: List<String>, fokus: String?, dodir: (String) -> Unit, modifier: Modifier = Modifier,
               meta: String? = null, izvori: List<String> = emptyList()) {
    // Partija na jednom kontinentu: u stanju su samo njegove države.
    val naKontinentu = stanje.oblasti.size < Mapa.oblasti.size
    val merac = rememberTextMeasurer()
    val gustina = LocalDensity.current.density
    var razmera by remember { mutableFloatStateOf(1f) }
    var pomak by remember { mutableStateOf(Offset.Zero) }
    var uokvirenKontinent by remember { mutableStateOf(false) }

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

        /** Ceo kontinent u kadru, bez krajnjih 10% država (Rusija, Island), da jezgro bude krupno za dodir. */
        fun uokviriKontinent() {
            val xs = stanje.oblasti.keys.map { Mapa.oblast(it).x }.sorted()
            val ys = stanje.oblasti.keys.map { Mapa.oblast(it).y }.sorted()
            val odsek = if (xs.size >= 10) xs.size / 10 else 0
            val x0 = xs[odsek]; val x1 = xs[xs.size - 1 - odsek]; val y0 = ys[odsek]; val y1 = ys[ys.size - 1 - odsek]
            val kk = min(sirinaPx / ((x1 - x0) * 1.15f + 60), visinaPx / ((y1 - y0) * 1.15f + 60))
            razmera = (kk / osnova).coerceIn(1f, 8f)
            val k = osnova * razmera
            pomak = ogranici(Offset((Mapa.sirina / 2 - (x0 + x1) / 2) * k, (Mapa.visina / 2 - (y0 + y1) / 2) * k), k)
        }

        // Telefon: mapa krene uvećana oko prestonice ili mesta bitke; na kontinentu ostaje ceo kontinent.
        LaunchedEffect(fokus) {
            // Ceo kontinent samo na prvom kadru; posle toga dodir i bitka ne vraćaju zum koji je igrač namestio.
            if (naKontinentu) { if (!uokvirenKontinent) { uokviriKontinent(); uokvirenKontinent = true }; return@LaunchedEffect }
            val id = fokus ?: return@LaunchedEffect
            val o = Mapa.oblast(id)
            if (sirinaPx / gustina < 700) razmera = max(razmera, max(2.4f, visinaPx / (Mapa.visina * osnova)))
            val k = osnova * razmera
            pomak = ogranici(Offset((Mapa.sirina / 2 - o.x) * k, (Mapa.visina / 2 - o.y) * k), k)
        }

        // Izabrana država i sve njene mete staju u kadar; samo približava: ako je igrač uvećao više, pomera se na izabranu bez umanjenja.
        LaunchedEffect(mete) {
            val id = izabrana ?: return@LaunchedEffect
            if (mete.isEmpty()) return@LaunchedEffect
            val t = (mete + id).map { Mapa.oblast(it) }
            val x0 = t.minOf { it.x }; val x1 = t.maxOf { it.x }; val y0 = t.minOf { it.y }; val y1 = t.maxOf { it.y }
            val kk = min(sirinaPx / ((x1 - x0) * 1.5f + 140), visinaPx / ((y1 - y0) * 1.5f + 140))
            val zeljena = (kk / osnova).coerceIn(1f, 8f)
            if (zeljena < razmera) {
                val o = Mapa.oblast(id); val k = osnova * razmera
                pomak = ogranici(Offset((Mapa.sirina / 2 - o.x) * k, (Mapa.visina / 2 - o.y) * k), k)
                return@LaunchedEffect
            }
            razmera = zeljena
            val k = osnova * razmera
            pomak = ogranici(Offset((Mapa.sirina / 2 - (x0 + x1) / 2) * k, (Mapa.visina / 2 - (y0 + y1) / 2) * k), k)
        }

        // Zum drži ono što je na sredini ekrana: pomak raste srazmerno, inače bi pogled odleteo ka sredini mape.
        fun zumiraj(nova: Float) {
            val r = nova.coerceIn(1f, 8f)
            val f = r / razmera
            razmera = r
            pomak = ogranici(pomak * f, osnova * r)
        }

        Canvas(
            Modifier.fillMaxSize().background(OKEAN)
                .pointerInput(Unit) {
                    detectTransformGestures { _, pan, zum, _ ->
                        zumiraj(razmera * zum)
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
                    // Morski putevi ispod država: isprekidane linije preko mora, kao u Risku.
                    for (m in Mapa.more) {
                        val jak = izabrana != null && ((m.a == izabrana && m.b in mete) || (m.b == izabrana && m.a in mete))
                        val boja = if (jak) Boje.mastilo else MORSKI_PUT.copy(alpha = 0.75f)
                        val crta = PathEffect.dashPathEffect(if (jak) floatArrayOf(7f * gustina / k, 5f * gustina / k) else floatArrayOf(5f * gustina / k, 6f * gustina / k))
                        val linija = Path()
                        if (kotlin.math.abs(m.x1 - m.x2) > Mapa.sirina / 2) {
                            // Put preko ivice karte (Aljaska–Čukotka): dva kraka ka ivicama.
                            val (lx, ly, dx, dy) = if (m.x1 < m.x2) listOf(m.x1, m.y1, m.x2, m.y2) else listOf(m.x2, m.y2, m.x1, m.y1)
                            linija.moveTo(lx, ly); linija.lineTo(0f, ly - 8)
                            linija.moveTo(dx, dy); linija.lineTo(Mapa.sirina, dy - 8)
                        } else {
                            linija.moveTo(m.x1, m.y1)
                            linija.quadraticTo((m.x1 + m.x2) / 2 - (m.y2 - m.y1) * 0.12f, (m.y1 + m.y2) / 2 + (m.x2 - m.x1) * 0.12f, m.x2, m.y2)
                        }
                        drawPath(linija, boja, style = Stroke((if (jak) 3f else 1.8f) * gustina / k, pathEffect = crta))
                    }
                    for (o in Mapa.oblasti) {
                        val put = PutanjeMape.sve[o.id] ?: continue
                        // Igra na jednom kontinentu: ostale države su bleda pozadina, bez znački.
                        val st = stanje.oblasti[o.id] ?: run { drawPath(put, NEUTRALNE[o.boja % 5].copy(alpha = 0.25f)); null } ?: continue
                        val boja = stanje.igraci.firstOrNull { it.tim == st.vlasnik }?.let { Color(it.boja) } ?: NEUTRALNE[o.boja % 5]
                        drawPath(put, boja)
                        drawPath(put, Color.White, style = Stroke(1.1f * gustina / k))
                    }
                    for (id in mete) {
                        val put = PutanjeMape.sve[id] ?: continue
                        drawPath(put, Boje.mastilo.copy(alpha = 0.08f))
                        drawPath(put, Boje.mastilo, style = Stroke(2.5f * gustina / k, pathEffect = PathEffect.dashPathEffect(floatArrayOf(6f * gustina / k, 5f * gustina / k))))
                    }
                    for (id in izvori) {
                        val put = PutanjeMape.sve[id] ?: continue
                        drawPath(put, Boje.zuta, style = Stroke(2.5f * gustina / k, join = StrokeJoin.Round))
                    }
                    izabrana?.let { id -> PutanjeMape.sve[id]?.let { drawPath(it, Boje.zuta, style = Stroke(5f * gustina / k, join = StrokeJoin.Round)) } }
                    meta?.let { id ->
                        PutanjeMape.sve[id]?.let {
                            drawPath(it, Boje.crvena.copy(alpha = 0.35f))
                            drawPath(it, Boje.crvena, style = Stroke(5f * gustina / k, join = StrokeJoin.Round))
                        }
                        // Strelica napada: od države iz koje se napada do mete.
                        izabrana?.let { iz ->
                            val a = Mapa.oblast(iz); val b = Mapa.oblast(id)
                            drawLine(Boje.crvena, Offset(a.x, a.y), Offset(b.x, b.y), 3.5f * gustina / k,
                                pathEffect = PathEffect.dashPathEffect(floatArrayOf(8f * gustina / k, 5f * gustina / k)))
                        }
                    }
                }
            }
            // Pločice sa brojem vojski, iste veličine na svakom zumu. Bez imena država i bez znački praznih polja:
            // ime, vojske i zanimljivost stižu u list kad se država dodirne. Pločica koja bi prekrila nacrtanu se preskače.
            val prestonice = stanje.igraci.map { it.prestonica }.toSet()
            val zauzeto = mutableListOf<Rect>()
            val redom = Mapa.oblasti.filter { it.id in stanje.oblasti }
                .sortedWith(compareByDescending<Oblast> { it.id == izabrana || it.id == meta }.thenByDescending { it.povrsina })
            for (o in redom) {
                val st = stanje.oblasti[o.id] ?: continue
                val vlasnik = stanje.igraci.firstOrNull { it.tim == st.vlasnik }
                if (vlasnik == null && o.id !in mete) continue
                val c = Offset(p.x + o.x * k, p.y + o.y * k)
                val okvir = Rect(c.x - 11 * gustina, c.y - 9 * gustina, c.x + 11 * gustina, c.y + 9 * gustina)
                if (zauzeto.any { it.deflate(2 * gustina).overlaps(okvir) }) continue
                zauzeto += okvir
                val ugao = CornerRadius(6 * gustina)
                drawRoundRect(Boje.tinta.copy(alpha = 0.55f), okvir.topLeft + Offset(0f, 1.5f * gustina), okvir.size, ugao)
                drawRoundRect(vlasnik?.let { Color(it.boja) } ?: Color.White, okvir.topLeft, okvir.size, ugao)
                drawRoundRect(Boje.tinta, okvir.topLeft, okvir.size, ugao, style = Stroke(1.2f * gustina))
                val broj = merac.measure("${st.vojske}", naslov(11.sp).copy(color = if (vlasnik == null) Boje.tinta else Color.White))
                drawText(broj, topLeft = c - Offset(broj.size.width / 2f, broj.size.height / 2f))
                if (o.id in prestonice) {
                    val kruna = Path().apply {
                        val x0 = c.x + 11 * gustina; val y0 = c.y - 8 * gustina
                        moveTo(x0 - 5 * gustina, y0); lineTo(x0 - 5 * gustina, y0 - 5 * gustina); lineTo(x0 - 2.5f * gustina, y0 - 2.5f * gustina)
                        lineTo(x0, y0 - 6 * gustina); lineTo(x0 + 2.5f * gustina, y0 - 2.5f * gustina); lineTo(x0 + 5 * gustina, y0 - 5 * gustina)
                        lineTo(x0 + 5 * gustina, y0); close()
                    }
                    drawPath(kruna, Boje.zuta)
                    drawPath(kruna, Boje.tinta, style = Stroke(1.2f * gustina))
                }
            }
        }

        Column(Modifier.align(Alignment.TopEnd).padding(10.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf(
                Triple(Icons.Rounded.Add, "Uvećaj") { zumiraj(razmera * 1.5f) },
                Triple(Icons.Rounded.Remove, "Umanji") { zumiraj(razmera / 1.5f) },
                Triple(Icons.Rounded.Public, if (naKontinentu) "Ceo kontinent" else "Ceo svet") { if (naKontinentu) uokviriKontinent() else { razmera = 1f; pomak = Offset.Zero } },
            ).forEach { (ikonica, opis, radnja) ->
                IconButton(onClick = radnja, modifier = Modifier.size(44.dp).background(Boje.kartica, CircleShape).border(2.dp, Boje.mastilo, CircleShape)) {
                    Icon(ikonica, contentDescription = opis, tint = Boje.mastilo)
                }
            }
        }
    }
}
