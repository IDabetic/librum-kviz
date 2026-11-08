package club.librum.kviz.reci

import android.content.Context
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ArrowDownward
import androidx.compose.material.icons.rounded.Backspace
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.ChevronLeft
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.Flag
import androidx.compose.material.icons.rounded.Shuffle
import androidx.compose.material.icons.rounded.SportsScore
import androidx.compose.material.icons.rounded.Undo
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import club.librum.kviz.igre.MojRezultat
import club.librum.kviz.servisi.Sesija
import club.librum.kviz.servisi.Supabase
import club.librum.kviz.servisi.Zvuk
import club.librum.kviz.ui.Boje
import club.librum.kviz.ui.Dijalog
import club.librum.kviz.ui.Oznaka
import club.librum.kviz.ui.mirna
import club.librum.kviz.ui.naslov
import club.librum.kviz.ui.tekst
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin

inline fun <reified T> ucitajStanje(ctx: Context, igra: IgraReci, datum: String): T? =
    PartijeReci.ucitaj(ctx, igra, datum)?.let { runCatching { Supabase.json.decodeFromString<T>(it) }.getOrNull() }

inline fun <reified T> sacuvajStanje(ctx: Context, igra: IgraReci, datum: String, s: T) =
    PartijeReci.sacuvaj(ctx, igra, datum, Supabase.json.encodeToString(s))

// MARK: Pet slova

@Serializable data class PetStanje(val pokusaji: List<String> = emptyList(), val sekundi: Int = 0, val pomoci: Int = 0,
                                   val otkriveno: List<Int> = emptyList(), val gotovo: Boolean = false, val resio: Boolean = false)

/** Ocena u dva prolaza. Primer: oceni(KOSAA, KASAP) → [TACNO, NEMA, TACNO, TACNO, MESTO]. */
fun oceni(p: List<String>, r: List<String>): List<StanjePloce> {
    val o = MutableList(p.size) { StanjePloce.NEMA }
    val ostalo = mutableMapOf<String, Int>()
    p.indices.forEach { i -> if (i < r.size && p[i] == r[i]) o[i] = StanjePloce.TACNO else if (i < r.size) ostalo[r[i]] = (ostalo[r[i]] ?: 0) + 1 }
    p.indices.filter { o[it] != StanjePloce.TACNO }.forEach { i -> val n = ostalo[p[i]] ?: 0; if (n > 0) { o[i] = StanjePloce.MESTO; ostalo[p[i]] = n - 1 } }
    return o
}

@Composable
fun PetSlovaEkran(z: PetSlovaZ, datum: String, sesija: Sesija, zatvori: () -> Unit, soba: UTakmicenju? = null) {
    val ctx = LocalContext.current
    val igra = IgraReci.PET_SLOVA
    var s by remember { mutableStateOf(ucitajStanje<PetStanje>(ctx, igra, datum) ?: PetStanje()) }
    var unos by remember { mutableStateOf("") }
    var poruka by remember { mutableStateOf<String?>(null) }
    var ishod by remember { mutableStateOf(if (s.gotovo) upisanIshod(igra) else Ishod.Ucitava) }
    val scope = rememberCoroutineScope()
    val rec = AzbukaReci.slova(z.rec)
    fun sacuvaj() = sacuvajStanje(ctx, igra, datum, s)
    fun zavrsi(resio: Boolean) {
        s = s.copy(gotovo = true, resio = resio); sacuvaj()
        val n = s.pokusaji.size
        if (soba != null) {
            val poeni = if (resio) maxOf(0, (7 - n) * 10 + soba.bonus(s.sekundi) - 5 * s.pomoci) else 0
            return soba.javi(MojRezultat(poeni, if (resio) 1 else 0, n, s.sekundi * 1000, true))
        }
        val st = s
        scope.launch { ishod = posaljiRezultatReci(igra, mapOf("pokusaji" to st.pokusaji), resio, st.sekundi, st.pomoci, sesija) }
    }
    fun potvrdi() {
        val r = unos.lowercase()
        when {
            r.length != 5 -> scope.launch { kratko({ poruka = it }, "Reč ima pet slova.") }
            r != z.rec && !RecnikReci.postoji(r) -> scope.launch { kratko({ poruka = it }, "Te reči nema u rečniku.") }
            r in s.pokusaji -> scope.launch { kratko({ poruka = it }, "Već si probao tu reč.") }
            else -> {
                s = s.copy(pokusaji = s.pokusaji + r); unos = ""; sacuvaj()
                Zvuk.pusti(if (r == z.rec) Zvuk.Vrsta.SLOVO_DA else Zvuk.Vrsta.SLOVO_NE, 0.4f)
                if (r == z.rec || s.pokusaji.size == 6) zavrsi(r == z.rec)
            }
        }
    }
    OkvirIgreReci(igra, s.sekundi, {
        s = s.copy(sekundi = s.sekundi + 1); sacuvaj()
        if (soba != null && s.sekundi >= soba.rok && !s.gotovo) zavrsi(false)
    }, s.gotovo, zatvori, rok = soba?.rok, pomoc = {
        val poznato = s.pokusaji.flatMap { p -> oceni(AzbukaReci.slova(p), rec).withIndex().filter { it.value == StanjePloce.TACNO }.map { it.index } }.toSet()
        (0 until 5).filter { it !in poznato && it !in s.otkriveno }.randomOrNull()?.let { s = s.copy(otkriveno = s.otkriveno + it, pomoci = s.pomoci + 1); sacuvaj() }
    }) {
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(7.dp)) {
            repeat(6) { red ->
                val slova = when { red < s.pokusaji.size -> AzbukaReci.slova(s.pokusaji[red]); red == s.pokusaji.size -> AzbukaReci.slova(unos); else -> emptyList() }
                val ocene = if (red < s.pokusaji.size) oceni(slova, rec) else null
                Row(horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                    repeat(5) { i -> Ploca(slova.getOrElse(i) { "" }, ocene?.get(i) ?: if (i < slova.size) StanjePloce.UNETO else StanjePloce.PRAZNO, 54.dp) }
                }
            }
            val nema = s.pokusaji.flatMap { p -> AzbukaReci.slova(p).zip(oceni(AzbukaReci.slova(p), rec)) }
                .groupBy({ it.first }, { it.second }).filter { (_, v) -> v.all { it == StanjePloce.NEMA } }.keys.sorted()
            if (nema.isNotEmpty() && !s.gotovo) Text("Nema u reči: " + nema.joinToString(" "), style = tekst(14.sp, FontWeight.SemiBold, Boje.sivaTekst))
            if (s.otkriveno.isNotEmpty() && !s.gotovo) Text("Pomoć: " + rec.mapIndexed { i, sl -> if (i in s.otkriveno) sl else "_" }.joinToString(" "), style = tekst(14.sp, FontWeight.SemiBold, Boje.sivaTekst))
            PorukaReci(poruka)
            if (s.gotovo && soba == null) KrajIgreReci(igra, s.resio, "Reč dana: ${z.rec.uppercase()}", s.sekundi, ishod, sesija, zatvori)
        }
        if (!s.gotovo) PoljeUnosaReci(unos, { unos = it }, 5, potvrdi = ::potvrdi)
    }
}

// MARK: Premetaljka

@Serializable data class PremStanje(val nadjene: List<String> = emptyList(), val redosled: List<Int> = (0 until 7).toList(), val sekundi: Int = 0,
                                    val pomoci: Int = 0, val nagovestaj: String? = null, val gotovo: Boolean = false)

@Composable
fun PremetaljkaEkran(z: PremetaljkaZ, datum: String, sesija: Sesija, zatvori: () -> Unit, soba: UTakmicenju? = null) {
    val ctx = LocalContext.current
    val igra = IgraReci.PREMETALJKA
    var s by remember { mutableStateOf(ucitajStanje<PremStanje>(ctx, igra, datum) ?: PremStanje()) }
    var izabrana by remember { mutableStateOf(listOf<Int>()) }
    var poruka by remember { mutableStateOf<String?>(null) }
    var kraj by remember { mutableStateOf(false) }
    var ishod by remember { mutableStateOf(if (s.gotovo) upisanIshod(igra) else Ishod.Ucitava) }
    val scope = rememberCoroutineScope()
    val resio = z.glavna in s.nadjene
    val poeni = s.nadjene.sumOf { if (it == z.glavna) 15 else it.length - 2 }
    val poeniSobe = maxOf(0, poeni - 5 * s.pomoci)
    fun sacuvaj() = sacuvajStanje(ctx, igra, datum, s)
    fun zavrsi() {
        s = s.copy(gotovo = true); sacuvaj()
        if (soba != null) return soba.javi(MojRezultat(poeniSobe, s.nadjene.size, s.nadjene.size, s.sekundi * 1000, true))
        val st = s
        scope.launch { ishod = posaljiRezultatReci(igra, mapOf("reci" to st.nadjene), z.glavna in st.nadjene, st.sekundi, st.pomoci, sesija) }
    }
    fun potvrdi() {
        val r = izabrana.joinToString("") { z.slova[it] }
        izabrana = emptyList()
        val greska = when {
            r.length < 3 -> "Najmanje tri slova."
            r in s.nadjene -> "Tu reč si već našao."
            r !in z.reci -> if (RecnikReci.postoji(r)) "Te reči nema na današnjem spisku." else "Te reči nema u rečniku."
            else -> null
        }
        if (greska != null) { scope.launch { kratko({ poruka = it }, greska) }; return }
        s = s.copy(nadjene = s.nadjene + r, nagovestaj = null); sacuvaj()
        Zvuk.pusti(if (r == z.glavna) Zvuk.Vrsta.OSVOJENO else Zvuk.Vrsta.SLOVO_DA, 0.4f)
        scope.launch { kratko({ poruka = it }, if (r == z.glavna) "Glavna reč! +15" else "+${r.length - 2}") }
        soba?.javi(MojRezultat(maxOf(0, s.nadjene.sumOf { if (it == z.glavna) 15 else it.length - 2 } - 5 * s.pomoci), s.nadjene.size, s.nadjene.size, s.sekundi * 1000))
        if (s.nadjene.size == z.reci.size) zavrsi()
    }
    OkvirIgreReci(igra, s.sekundi, {
        s = s.copy(sekundi = s.sekundi + 1); sacuvaj()
        if (soba != null && s.sekundi >= soba.rok && !s.gotovo) zavrsi()
    }, s.gotovo, zatvori, rok = soba?.rok, pomoc = {
        val cilj = if (resio) z.reci.filter { it !in s.nadjene }.randomOrNull() else z.glavna
        if (cilj != null) { s = s.copy(nagovestaj = cilj.take(1).uppercase() + " _".repeat(cilj.length - 1), pomoci = s.pomoci + 1); sacuvaj() }
    }) {
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Row(Modifier.fillMaxWidth().mirna().padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text("${s.nadjene.size} od ${z.reci.size} reči", style = tekst(16.sp, FontWeight.Bold))
                    Text(if (resio) "Glavna reč je nađena" else "Glavna reč: 7 slova", style = tekst(13.sp, boja = if (resio) Boje.teal else Boje.sivaTekst))
                }
                Text("$poeni", style = naslov(24.sp))
            }
            if (s.gotovo) {
                if (soba == null) KrajIgreReci(igra, resio, "Glavna reč: ${z.glavna.uppercase()} · našao si ${s.nadjene.size} od ${z.reci.size}", s.sekundi, ishod, sesija, zatvori)
                val ostale = z.reci.filter { it !in s.nadjene }
                if (ostale.isNotEmpty()) { Oznaka("Propuštene reči"); Text(ostale.joinToString(" · ") { it.uppercase() }, style = tekst(15.sp, boja = Boje.sivaTekst)) }
            } else {
                Row(Modifier.fillMaxWidth().height(48.dp), horizontalArrangement = Arrangement.spacedBy(5.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically) {
                    if (izabrana.isEmpty()) Text("Dodirni slova", style = tekst(15.sp, boja = Boje.sivaTekst))
                    izabrana.forEach { Ploca(z.slova[it].uppercase(), StanjePloce.UNETO, 44.dp) }
                }
                BoxWithConstraints(Modifier.fillMaxWidth().height(280.dp)) {
                    val r = minOf(maxWidth, maxHeight) / 2 - 36.dp
                    Box(Modifier.size(r * 2).align(Alignment.Center).border(2.dp, Boje.kremTamnija, CircleShape))
                    (0 until 7).forEach { mesto ->
                        val i = s.redosled[mesto]
                        val ugao = mesto / 7.0 * 2 * Math.PI - Math.PI / 2
                        val iskorisceno = i in izabrana
                        Box(Modifier.align(Alignment.Center).offset(r * cos(ugao).toFloat(), r * sin(ugao).toFloat())
                            .clickable(enabled = !iskorisceno) { izabrana = izabrana + i }
                            .semantics { contentDescription = "Slovo ${z.slova[i].uppercase()}" }) {
                            Ploca(z.slova[i].uppercase(), if (iskorisceno) StanjePloce.NEMA else StanjePloce.TACNO, 60.dp)
                        }
                    }
                }
                PorukaReci(poruka ?: s.nagovestaj?.let { "Pomoć: $it" })
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(14.dp, Alignment.CenterHorizontally)) {
                    KockaDugme(Icons.Rounded.Backspace, "Obriši poslednje slovo") { izabrana = izabrana.dropLast(1) }
                    KockaDugme(Icons.Rounded.Shuffle, "Izmešaj slova") { s = s.copy(redosled = s.redosled.shuffled()) }
                    KockaDugme(Icons.Rounded.Check, "Potvrdi reč", true, ::potvrdi)
                    KockaDugme(Icons.Rounded.SportsScore, "Završi igru") { kraj = true }
                }
            }
            if (s.nadjene.isNotEmpty()) {
                Oznaka("Nađene reči")
                Text(s.nadjene.sortedWith(compareByDescending<String> { it.length }.thenByDescending { it }).joinToString(" · ") { it.uppercase() }, style = tekst(15.sp, FontWeight.SemiBold))
            }
        }
    }
    if (kraj) Dijalog("Završiti igru?", if (resio) "Rezultat ide na rang listu sa ${s.nadjene.size} reči." else "Glavnu reč još nisi našao. Posle kraja vidiš sve reči.",
        "Završi", "Igraj još", { kraj = false; zavrsi() }) { kraj = false }
}

// MARK: Lanac

@Serializable data class LanacStanje(val put: List<String> = emptyList(), val sekundi: Int = 0, val pomoci: Int = 0, val nagovestaj: String? = null,
                                     val gotovo: Boolean = false, val resio: Boolean = false)

/** Pretraga u širinu kroz reči iste dužine; sledeći korak najkraćeg puta. Primer: sledeciKorak("kosa", "kasa") → "kasa". */
fun sledeciKorak(od: String, cilj: String, iskorisceno: Set<String>): String? {
    val reci = RecnikReci.sve().filter { it.length == od.length }.toHashSet() + cilj
    val pret = hashMapOf(od to od)
    val red = ArrayDeque(listOf(od))
    while (red.isNotEmpty()) {
        val r = red.removeFirst()
        if (r == cilj) break
        for (p in r.indices) for (z in "abcčćdđefghijklmnoprsštuvzž") {
            if (z == r[p]) continue
            val n = r.substring(0, p) + z + r.substring(p + 1)
            if (n !in pret && n in reci && (n !in iskorisceno || n == cilj)) { pret[n] = r; red.add(n) }
        }
    }
    if (cilj !in pret) return null
    var k = cilj
    while (pret[k] != od) k = pret[k] ?: return null
    return k
}

@Composable
fun LanacEkran(z: LanacZ, datum: String, sesija: Sesija, zatvori: () -> Unit, soba: UTakmicenju? = null) {
    val ctx = LocalContext.current
    val igra = IgraReci.LANAC
    var s by remember { mutableStateOf(ucitajStanje<LanacStanje>(ctx, igra, datum)?.takeIf { it.put.isNotEmpty() } ?: LanacStanje(put = listOf(z.od))) }
    var unos by remember { mutableStateOf("") }
    var poruka by remember { mutableStateOf<String?>(null) }
    var predaja by remember { mutableStateOf(false) }
    var ishod by remember { mutableStateOf(if (s.gotovo) upisanIshod(igra) else Ishod.Ucitava) }
    val scope = rememberCoroutineScope()
    val duzina = z.od.length
    fun sacuvaj() = sacuvajStanje(ctx, igra, datum, s)
    fun zavrsi(resio: Boolean) {
        s = s.copy(gotovo = true, resio = resio); sacuvaj()
        val koraka = s.put.size - 1
        if (soba != null) {
            val poeni = if (resio) maxOf(0, maxOf(10, 60 - (koraka - z.najmanje) * 10) + soba.bonus(s.sekundi) - 5 * s.pomoci) else 0
            return soba.javi(MojRezultat(poeni, if (resio) 1 else 0, koraka, s.sekundi * 1000, true))
        }
        val st = s
        scope.launch { ishod = posaljiRezultatReci(igra, mapOf("put" to st.put), resio, st.sekundi, st.pomoci, sesija) }
    }
    fun potvrdi() {
        val r = unos.lowercase()
        val poslednja = s.put.last()
        val greska = when {
            r.length != duzina -> "Reč ima $duzina slova."
            !AzbukaReci.razlikaJednoSlovo(poslednja, r) -> "Promeni tačno jedno slovo."
            r != z.doReci && !RecnikReci.postoji(r) -> "Te reči nema u rečniku."
            r in s.put -> "Ta reč je već u lancu."
            else -> null
        }
        if (greska != null) { scope.launch { kratko({ poruka = it }, greska) }; return }
        s = s.copy(put = s.put + r, nagovestaj = null); unos = ""; sacuvaj()
        Zvuk.pusti(Zvuk.Vrsta.SLOVO_DA, 0.4f)
        if (r == z.doReci) zavrsi(true)
    }
    @Composable fun red(rec: String, pre: String?, stanje: StanjePloce) {
        val slova = AzbukaReci.slova(rec)
        val p = pre?.let { AzbukaReci.slova(it) }
        Row(horizontalArrangement = Arrangement.spacedBy(7.dp)) {
            slova.forEachIndexed { i, sl ->
                val promena = p != null && i < p.size && p[i] != sl
                Ploca(sl, if (promena && stanje == StanjePloce.UNETO) StanjePloce.MESTO else stanje, 52.dp)
            }
        }
    }
    OkvirIgreReci(igra, s.sekundi, {
        s = s.copy(sekundi = s.sekundi + 1); sacuvaj()
        if (soba != null && s.sekundi >= soba.rok && !s.gotovo) zavrsi(false)
    }, s.gotovo, zatvori, rok = soba?.rok, pomoc = {
        val n = sledeciKorak(s.put.last(), z.doReci, s.put.toSet())
        if (n == null) scope.launch { kratko({ poruka = it }, "Odavde nema puta, vrati korak.") }
        else { s = s.copy(nagovestaj = n, pomoci = s.pomoci + 1); sacuvaj() }
    }) {
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("Najkraće: ${z.najmanje} koraka · ti: ${s.put.size - 1}", style = tekst(14.sp, FontWeight.SemiBold, Boje.sivaTekst))
            s.put.forEachIndexed { i, r -> red(r, s.put.getOrNull(i - 1), if (i == 0) StanjePloce.ISTAKNUTO else if (r == z.doReci) StanjePloce.TACNO else StanjePloce.UNETO) }
            if (!s.gotovo) {
                Row(horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                    val sl = AzbukaReci.slova(unos)
                    repeat(duzina) { i -> Ploca(sl.getOrElse(i) { "" }, if (i < sl.size) StanjePloce.UNETO else StanjePloce.PRAZNO, 52.dp) }
                }
                Icon(Icons.Rounded.ArrowDownward, null, tint = Boje.sivaTekst)
                red(z.doReci, null, StanjePloce.ISTAKNUTO)
                PorukaReci(poruka ?: s.nagovestaj?.let { "Pomoć: sledeći korak je ${it.uppercase()}" })
            } else if (soba == null) {
                KrajIgreReci(igra, s.resio, "Jedan od najkraćih puteva: " + z.primer.joinToString(" → ") { it.uppercase() }, s.sekundi, ishod, sesija, zatvori)
            }
        }
        if (!s.gotovo) {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                KockaDugme(Icons.Rounded.Undo, "Vrati korak") { if (s.put.size > 1) { s = s.copy(put = s.put.dropLast(1)); sacuvaj() } }
                KockaDugme(Icons.Rounded.Flag, "Predaj") { predaja = true }
            }
            PoljeUnosaReci(unos, { unos = it }, duzina, potvrdi = ::potvrdi)
        }
    }
    if (predaja) Dijalog("Predaješ lanac?", "Videćeš jedan od najkraćih puteva, a rezultat ulazi kao nerešen.", "Predaj", "Igraj još", { predaja = false; zavrsi(false) }) { predaja = false }
}

// MARK: Šifra

@Serializable data class SifraStanje(val dodela: Map<String, String> = emptyMap(), val otkriveno: List<Int> = emptyList(), val sekundi: Int = 0,
                                     val pomoci: Int = 0, val gotovo: Boolean = false, val resio: Boolean = false)

@Composable
fun SifraEkran(z: SifraZ, datum: String, sesija: Sesija, zatvori: () -> Unit, soba: UTakmicenju? = null) {
    val ctx = LocalContext.current
    val igra = IgraReci.SIFRA
    var s by remember { mutableStateOf(ucitajStanje<SifraStanje>(ctx, igra, datum) ?: SifraStanje()) }
    var izabran by remember { mutableStateOf<Int?>(null) }
    var polje by remember { mutableStateOf("") }
    var poruka by remember { mutableStateOf<String?>(null) }
    var predaja by remember { mutableStateOf(false) }
    var ishod by remember { mutableStateOf(if (s.gotovo) upisanIshod(igra) else Ishod.Ucitava) }
    val scope = rememberCoroutineScope()
    val zakljucano = (z.data + s.otkriveno).toSet()
    val brojevi = z.polja.map { it[2] }.toSet()
    val tacnih = s.dodela.count { z.kljuc[it.key] == it.value }
    fun sacuvaj() = sacuvajStanje(ctx, igra, datum, s)
    fun zavrsi(resio: Boolean) {
        s = s.copy(gotovo = true, resio = resio); sacuvaj(); izabran = null
        if (soba != null) {
            val poeni = if (resio) 50 + soba.bonus(s.sekundi) else tacnih * 2
            return soba.javi(MojRezultat(maxOf(0, poeni - 5 * s.pomoci), tacnih, s.dodela.size, s.sekundi * 1000, true))
        }
        val kljuc = s.dodela + zakljucano.associate { "$it" to (z.kljuc["$it"] ?: "") }
        val st = s
        scope.launch { ishod = posaljiRezultatReci(igra, mapOf("kljuc" to kljuc), resio, st.sekundi, st.pomoci, sesija) }
    }
    fun sledeciPrazan(posle: Int): Int? = brojevi.filter { it !in zakljucano && s.dodela["$it"] == null }.sorted().let { l -> l.firstOrNull { it > posle } ?: l.firstOrNull() }
    fun proveri() {
        val otvoreni = brojevi.filter { it !in zakljucano }
        if (!otvoreni.all { s.dodela["$it"] != null }) return
        if (otvoreni.all { s.dodela["$it"] == z.kljuc["$it"] }) zavrsi(true) else scope.launch { kratko({ poruka = it }, "Sva polja su popunjena, ali nešto nije tačno.") }
    }
    fun upisi(slovo: String) {
        val b = izabran ?: run { scope.launch { kratko({ poruka = it }, "Prvo dodirni polje.") }; return }
        val malo = slovo.lowercase()
        if (zakljucano.any { z.kljuc["$it"] == malo }) { scope.launch { kratko({ poruka = it }, "To slovo je već otkriveno.") }; return }
        s = s.copy(dodela = s.dodela.filterValues { it != malo } + ("$b" to malo)); sacuvaj()
        izabran = sledeciPrazan(b)
        soba?.javi(MojRezultat(s.dodela.count { z.kljuc[it.key] == it.value } * 2, s.dodela.count { z.kljuc[it.key] == it.value }, s.dodela.size, s.sekundi * 1000))
        proveri()
    }
    OkvirIgreReci(igra, s.sekundi, {
        s = s.copy(sekundi = s.sekundi + 1); sacuvaj()
        if (soba != null && s.sekundi >= soba.rok && !s.gotovo) zavrsi(false)
    }, s.gotovo, zatvori, rok = soba?.rok, pomoc = {
        val kandidati = brojevi.filter { it !in zakljucano && s.dodela["$it"] != z.kljuc["$it"] }
        val b = izabran?.takeIf { it in kandidati } ?: kandidati.minOrNull()
        if (b != null) {
            val tacno = z.kljuc["$b"]
            s = s.copy(otkriveno = s.otkriveno + b, dodela = s.dodela.filterValues { it != tacno } - "$b", pomoci = s.pomoci + 1); sacuvaj()
            izabran = sledeciPrazan(b); proveri()
        }
    }) {
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            MrezaPolja(z.polja.map { Triple(it[0], it[1], it[2]) }) { (x, y, broj), v ->
                val zak = broj in zakljucano
                val slovo = if (s.gotovo || zak) z.kljuc["$broj"] else s.dodela["$broj"]
                val st = when { zak || (s.gotovo && s.resio) -> StanjePloce.ISTAKNUTO; izabran == broj -> StanjePloce.IZABRANO; slovo == null -> StanjePloce.PRAZNO; else -> StanjePloce.UNETO }
                Ploca(slovo?.uppercase() ?: "", st, v, broj, Modifier.clickable(enabled = !zak && !s.gotovo) { izabran = broj })
            }
            PorukaReci(poruka)
            if (s.gotovo && soba == null) KrajIgreReci(igra, s.resio, z.reci.joinToString(" · ") { it.uppercase() }, s.sekundi, ishod, sesija, zatvori)
        }
        if (!s.gotovo) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(izabran?.let { "Broj $it" } ?: "Dodirni polje", style = tekst(14.sp, FontWeight.SemiBold, Boje.sivaTekst), modifier = Modifier.weight(1f))
                KockaDugme(Icons.Rounded.Flag, "Predaj") { predaja = true }
            }
            PoljeUnosaReci(polje, { n -> if (n.isNotEmpty()) { polje = ""; upisi(n.last().toString()) } }, 2, "Slovo za izabrani broj",
                brisi = { izabran?.let { s = s.copy(dodela = s.dodela - "$it"); sacuvaj() } })
        }
    }
    if (predaja) Dijalog("Predaješ šifru?", "Videćeš sva slova, a rezultat ulazi kao nerešen.", "Predaj", "Igraj još", { predaja = false; zavrsi(false) }) { predaja = false }
}

/** Mreža polja (x, y, podatak) skraćena na zauzeti deo, pločice do 46 dp. */
@Composable
fun <T> MrezaPolja(polja: List<Triple<Int, Int, T>>, celija: @Composable (Triple<Int, Int, T>, androidx.compose.ui.unit.Dp) -> Unit) {
    if (polja.isEmpty()) return
    val x0 = polja.minOf { it.first }; val x1 = polja.maxOf { it.first }
    val y0 = polja.minOf { it.second }; val y1 = polja.maxOf { it.second }
    val po = polja.associateBy { it.first to it.second }
    BoxWithConstraints(Modifier.fillMaxWidth()) {
        val kolona = x1 - x0 + 1
        val v = minOf(46.dp, (maxWidth - 3.dp * (kolona - 1)) / kolona)
        Column(Modifier.align(Alignment.Center), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            for (y in y0..y1) Row(horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                for (x in x0..x1) po[x to y]?.let { celija(it, v) } ?: Spacer(Modifier.size(v))
            }
        }
    }
}

// MARK: Mini ukrštenica

@Serializable data class UkrStanje(val unos: Map<String, String> = emptyMap(), val otkriveno: List<String> = emptyList(), val sekundi: Int = 0,
                                   val pomoci: Int = 0, val gotovo: Boolean = false, val resio: Boolean = false)

@Composable
fun UkrstenicaEkran(z: UkrstenicaZ, datum: String, sesija: Sesija, zatvori: () -> Unit, soba: UTakmicenju? = null) {
    val ctx = LocalContext.current
    val igra = IgraReci.UKRSTENICA
    var s by remember { mutableStateOf(ucitajStanje<UkrStanje>(ctx, igra, datum) ?: UkrStanje()) }
    fun polja(r: UkrRec) = r.rec.indices.map { if (r.smer == "v") (r.x + it) to r.y else r.x to (r.y + it) }
    val resenje = remember(z) { z.reci.flatMap { r -> polja(r).zip(AzbukaReci.slova(r.rec).map { it.lowercase() }) }.toMap() }
    val brojevi = remember(z) { z.reci.associate { (it.x to it.y) to it.broj } }
    val redReci = remember(z) { z.reci.sortedWith(compareBy<UkrRec> { if (it.smer == "v") 0 else 1 }.thenBy { it.broj }) }
    var izabrano by remember { mutableStateOf(if (s.gotovo) null else redReci.firstOrNull()?.let { polja(it).first() }) }
    var smer by remember { mutableStateOf(redReci.firstOrNull()?.smer ?: "v") }
    var proveri by remember { mutableStateOf(false) }
    var polje by remember { mutableStateOf("") }
    var poruka by remember { mutableStateOf<String?>(null) }
    var predaja by remember { mutableStateOf(false) }
    var ishod by remember { mutableStateOf(if (s.gotovo) upisanIshod(igra) else Ishod.Ucitava) }
    val scope = rememberCoroutineScope()
    fun kljuc(p: Pair<Int, Int>) = "${p.first},${p.second}"
    val tekuca = izabrano?.let { p -> z.reci.filter { p in polja(it) }.let { l -> l.firstOrNull { it.smer == smer } ?: l.firstOrNull() } }
    val tacnihPolja = resenje.count { s.unos[kljuc(it.key)] == it.value }
    fun sacuvaj() = sacuvajStanje(ctx, igra, datum, s)
    fun zavrsi(resio: Boolean) {
        s = s.copy(gotovo = true, resio = resio); sacuvaj(); izabrano = null
        if (soba != null) {
            val poeni = if (resio) 50 + soba.bonus(s.sekundi) else tacnihPolja
            return soba.javi(MojRezultat(maxOf(0, poeni - 5 * s.pomoci), tacnihPolja, s.unos.size, s.sekundi * 1000, true))
        }
        val reci = z.reci.map { r -> polja(r).joinToString("") { s.unos[kljuc(it)] ?: "" } }
        val st = s
        scope.launch { ishod = posaljiRezultatReci(igra, mapOf("reci" to reci), resio, st.sekundi, st.pomoci, sesija) }
    }
    fun proveriKraj() {
        if (!resenje.keys.all { s.unos[kljuc(it)] != null }) return
        if (resenje.all { s.unos[kljuc(it.key)] == it.value }) zavrsi(true) else { proveri = true; scope.launch { kratko({ poruka = it }, "Žuta polja nisu tačna.") } }
    }
    fun upisi(slovo: String) {
        val p = izabrano; val r = tekuca
        if (p == null || r == null) { scope.launch { kratko({ poruka = it }, "Prvo dodirni polje.") }; return }
        if (kljuc(p) !in s.otkriveno) s = s.copy(unos = s.unos + (kljuc(p) to slovo.lowercase()))
        proveri = false
        val l = polja(r); val i = l.indexOf(p)
        if (i + 1 < l.size) izabrano = l[i + 1]
        sacuvaj()
        soba?.javi(MojRezultat(resenje.count { s.unos[kljuc(it.key)] == it.value }, resenje.count { s.unos[kljuc(it.key)] == it.value }, s.unos.size, s.sekundi * 1000))
        proveriKraj()
    }
    fun obrisi() {
        val p = izabrano ?: return; val r = tekuca ?: return
        if (s.unos[kljuc(p)] != null && kljuc(p) !in s.otkriveno) { s = s.copy(unos = s.unos - kljuc(p)); return }
        val l = polja(r); val i = l.indexOf(p)
        if (i > 0) { izabrano = l[i - 1]; if (kljuc(l[i - 1]) !in s.otkriveno) s = s.copy(unos = s.unos - kljuc(l[i - 1])) }
    }
    fun pomeri(korak: Int) {
        val i = tekuca?.let { redReci.indexOf(it) } ?: -1
        val r = redReci[(i + korak + redReci.size) % redReci.size]
        smer = r.smer; izabrano = polja(r).firstOrNull { s.unos[kljuc(it)] == null } ?: polja(r).first()
    }
    OkvirIgreReci(igra, s.sekundi, {
        s = s.copy(sekundi = s.sekundi + 1); sacuvaj()
        if (soba != null && s.sekundi >= soba.rok && !s.gotovo) zavrsi(false)
    }, s.gotovo, zatvori, rok = soba?.rok, pomoc = {
        val p = izabrano?.takeIf { kljuc(it) !in s.otkriveno } ?: resenje.keys.sortedWith(compareBy({ it.second }, { it.first })).firstOrNull { s.unos[kljuc(it)] != resenje[it] }
        val tacno = p?.let { resenje[it] }
        if (p != null && tacno != null) { s = s.copy(unos = s.unos + (kljuc(p) to tacno), otkriveno = s.otkriveno + kljuc(p), pomoci = s.pomoci + 1); sacuvaj(); proveriKraj() }
    }) {
        val istaknuta = tekuca?.let { polja(it).toSet() } ?: emptySet()
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            MrezaPolja(resenje.map { (p, t) -> Triple(p.first, p.second, t) }) { (x, y, tacno), v ->
                val p = x to y
                val slovo = if (s.gotovo) tacno else s.unos[kljuc(p)]
                val st = when {
                    kljuc(p) in s.otkriveno || (s.gotovo && s.resio) -> StanjePloce.TACNO
                    izabrano == p -> StanjePloce.IZABRANO
                    proveri && slovo != null && slovo != tacno -> StanjePloce.MESTO
                    p in istaknuta -> StanjePloce.ISTAKNUTO
                    slovo == null -> StanjePloce.PRAZNO
                    else -> StanjePloce.UNETO
                }
                Ploca(slovo?.uppercase() ?: "", st, v, brojevi[p], Modifier.clickable(enabled = !s.gotovo) {
                    if (izabrano == p) smer = if (smer == "v") "u" else "v"
                    else { izabrano = p; if (z.reci.none { it.smer == smer && p in polja(it) }) smer = if (smer == "v") "u" else "v" }
                })
            }
            PorukaReci(poruka)
            if (s.gotovo && soba == null) KrajIgreReci(igra, s.resio, redReci.joinToString(" · ") { "${it.broj}. ${it.rec.uppercase()}" }, s.sekundi, ishod, sesija, zatvori)
        }
        if (!s.gotovo) {
            Row(Modifier.fillMaxWidth().background(Boje.tealSvetla, RoundedCornerShape(14.dp)).padding(6.dp), verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Rounded.ChevronLeft, "Prethodna reč", Modifier.size(36.dp).clickable { pomeri(-1) }, tint = Boje.mastilo)
                Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                    tekuca?.let {
                        Text("${it.broj} ${if (it.smer == "v") "vodoravno" else "uspravno"} · ${it.rec.length} slova", style = tekst(12.sp, FontWeight.Bold, Boje.sivaTekst))
                        Text(it.opis, style = tekst(15.sp, FontWeight.SemiBold), textAlign = TextAlign.Center, maxLines = 2)
                    } ?: Text("Dodirni polje", style = tekst(15.sp, FontWeight.SemiBold, Boje.sivaTekst))
                }
                Icon(Icons.Rounded.ChevronRight, "Sledeća reč", Modifier.size(36.dp).clickable { pomeri(1) }, tint = Boje.mastilo)
                Icon(Icons.Rounded.Flag, "Predaj", Modifier.size(36.dp).clickable { predaja = true }, tint = Boje.mastilo)
            }
            PoljeUnosaReci(polje, { n -> if (n.isNotEmpty()) { polje = ""; upisi(n.last().toString()) } }, 2, "Kucaj slova", brisi = ::obrisi)
        }
    }
    if (predaja) Dijalog("Predaješ ukrštenicu?", "Videćeš sve reči, a rezultat ulazi kao nerešen.", "Predaj", "Igraj još", { predaja = false; zavrsi(false) }) { predaja = false }
}

// MARK: Zmija

@Serializable data class ZmijaStanje(val nadjene: List<String> = emptyList(), val nagovestaj: List<List<Int>> = emptyList(), val sekundi: Int = 0,
                                     val pomoci: Int = 0, val gotovo: Boolean = false, val resio: Boolean = false)

@Composable
fun ZmijaEkran(z: ZmijaZ, datum: String, sesija: Sesija, zatvori: () -> Unit, soba: UTakmicenju? = null) {
    val ctx = LocalContext.current
    val igra = IgraReci.ZMIJA
    var s by remember { mutableStateOf(ucitajStanje<ZmijaStanje>(ctx, igra, datum) ?: ZmijaStanje()) }
    var put by remember { mutableStateOf(listOf<Pair<Int, Int>>()) }
    var poruka by remember { mutableStateOf<String?>(null) }
    var predaja by remember { mutableStateOf(false) }
    var ishod by remember { mutableStateOf(if (s.gotovo) upisanIshod(igra) else Ishod.Ucitava) }
    val scope = rememberCoroutineScope()
    fun slovo(p: Pair<Int, Int>) = z.slova[p.second].getOrNull(p.first)?.uppercase() ?: ""
    val nadjenaPolja = z.reci.filter { it.rec in s.nadjene || s.gotovo }.flatMap { r -> r.put.map { it[0] to it[1] } }.toSet()
    fun sacuvaj() = sacuvajStanje(ctx, igra, datum, s)
    fun zavrsi(resio: Boolean) {
        s = s.copy(gotovo = true, resio = resio); sacuvaj()
        if (soba != null) {
            val poeni = s.nadjene.size * 10 + if (resio) 20 + soba.bonus(s.sekundi) else 0
            return soba.javi(MojRezultat(maxOf(0, poeni - 5 * s.pomoci), s.nadjene.size, s.nadjene.size, s.sekundi * 1000, true))
        }
        val st = s
        scope.launch { ishod = posaljiRezultatReci(igra, mapOf("reci" to st.nadjene), resio, st.sekundi, st.pomoci, sesija) }
    }
    fun pusti() {
        val p = put; put = emptyList()
        if (p.size < 2) return
        val rec = p.joinToString("") { slovo(it) }.lowercase()
        val polja = p.map { listOf(it.first, it.second) }.toSet()
        val r = z.reci.firstOrNull { it.rec !in s.nadjene && it.rec == rec && it.put.toSet() == polja }
        when {
            r != null -> {
                s = s.copy(nadjene = s.nadjene + r.rec, nagovestaj = emptyList()); sacuvaj()
                Zvuk.pusti(Zvuk.Vrsta.SLOVO_DA, 0.4f)
                soba?.javi(MojRezultat(s.nadjene.size * 10, s.nadjene.size, s.nadjene.size, s.sekundi * 1000))
                if (s.nadjene.size == z.reci.size) zavrsi(true)
            }
            z.reci.any { it.rec == rec && it.rec !in s.nadjene } -> scope.launch { kratko({ poruka = it }, "Prava reč, ali je u mreži na drugom mestu.") }
            else -> scope.launch { kratko({ poruka = it }, if (RecnikReci.postoji(rec)) "Nije iz teme dana." else "To nije reč.") }
        }
    }
    OkvirIgreReci(igra, s.sekundi, {
        s = s.copy(sekundi = s.sekundi + 1); sacuvaj()
        if (soba != null && s.sekundi >= soba.rok && !s.gotovo) zavrsi(false)
    }, s.gotovo, zatvori, podnaslov = "Tema dana", rok = soba?.rok, pomoc = {
        z.reci.firstOrNull { it.rec !in s.nadjene }?.let { s = s.copy(nagovestaj = it.put.take(2), pomoci = s.pomoci + 1); sacuvaj() }
    }) {
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState(), enabled = put.isEmpty()), horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(z.tema, style = naslov(26.sp))
            Text("${s.nadjene.size} od ${z.reci.size} reči", style = tekst(14.sp, FontWeight.SemiBold, Boje.sivaTekst))
            Text(put.joinToString("") { slovo(it) }.ifEmpty { " " }, style = tekst(22.sp, FontWeight.Bold))
            val gustina = LocalDensity.current
            BoxWithConstraints(Modifier.fillMaxWidth()) {
                val razmak = 6.dp
                val v = minOf(58.dp, (maxWidth - razmak * (z.sirina - 1)) / z.sirina)
                val korak = v + razmak
                val korakPx = with(gustina) { korak.toPx() }
                val vPx = with(gustina) { v.toPx() }
                val pomoc = s.nagovestaj.map { it[0] to it[1] }.toSet()
                Box(Modifier.align(Alignment.Center).size(korak * z.sirina - razmak, korak * z.visina - razmak)
                    .pointerInput(s.gotovo, s.nadjene) {
                        if (s.gotovo) return@pointerInput
                        awaitEachGesture {
                            fun dodir(o: Offset) {
                                val x = (o.x / korakPx).toInt(); val y = (o.y / korakPx).toInt()
                                if (x !in 0 until z.sirina || y !in 0 until z.visina) return
                                // samo središnji deo pločice hvata prst, da dijagonalni prelaz ne pokupi susede
                                if (abs(o.x - (x * korakPx + vPx / 2)) > vPx * 0.4f || abs(o.y - (y * korakPx + vPx / 2)) > vPx * 0.4f) return
                                val t = x to y
                                if (t in nadjenaPolja) return
                                val i = put.indexOf(t)
                                if (i >= 0) { if (i == put.size - 2) put = put.dropLast(1); return }
                                val zadnja = put.lastOrNull()
                                if (zadnja != null && abs(zadnja.first - x) + abs(zadnja.second - y) != 1) return
                                put = put + t
                            }
                            dodir(awaitFirstDown().position)
                            do {
                                val e = awaitPointerEvent()
                                e.changes.forEach { dodir(it.position); it.consume() }
                            } while (e.changes.any { it.pressed })
                            pusti()
                        }
                    }
                    .semantics { contentDescription = "Mreža slova: " + z.slova.joinToString(", ") }) {
                    Canvas(Modifier.matchParentSize()) {
                        fun crtaj(tacke: List<Pair<Int, Int>>, boja: androidx.compose.ui.graphics.Color) {
                            if (tacke.isEmpty()) return
                            val p = Path()
                            tacke.forEachIndexed { i, t ->
                                val c = Offset(t.first * korakPx + vPx / 2, t.second * korakPx + vPx / 2)
                                if (i == 0) p.moveTo(c.x, c.y) else p.lineTo(c.x, c.y)
                            }
                            drawPath(p, boja, style = Stroke(vPx * 0.42f, cap = StrokeCap.Round, join = StrokeJoin.Round))
                        }
                        z.reci.filter { it.rec in s.nadjene || s.gotovo }.forEach { r -> crtaj(r.put.map { it[0] to it[1] }, Boje.teal) }
                        crtaj(put, Boje.zuta)
                    }
                    for (y in 0 until z.visina) for (x in 0 until z.sirina) {
                        val t = x to y
                        val st = when { t in put -> StanjePloce.IZABRANO; t in nadjenaPolja -> StanjePloce.TACNO; t in pomoc -> StanjePloce.ISTAKNUTO; else -> StanjePloce.UNETO }
                        Ploca(slovo(t), st, v, modifier = Modifier.offset(korak * x, korak * y))
                    }
                }
            }
            PorukaReci(poruka)
            if (s.gotovo) {
                if (soba == null) KrajIgreReci(igra, s.resio, z.reci.joinToString(" · ") { it.rec.uppercase() }, s.sekundi, ishod, sesija, zatvori)
            } else KockaDugme(Icons.Rounded.Flag, "Predaj") { predaja = true }
        }
    }
    if (predaja) Dijalog("Predaješ zmiju?", "Videćeš sve reči, a rezultat ulazi kao nerešen.", "Predaj", "Igraj još", { predaja = false; zavrsi(false) }) { predaja = false }
}
