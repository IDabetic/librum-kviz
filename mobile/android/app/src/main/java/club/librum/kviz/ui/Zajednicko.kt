package club.librum.kviz.ui

import android.annotation.SuppressLint
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Contrast
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material.icons.rounded.Lightbulb
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.Timer
import androidx.compose.material.icons.rounded.SkipNext
import androidx.compose.runtime.Composable
import android.os.Build
import android.view.ViewGroup
import android.view.WindowManager
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.compose.ui.window.DialogWindowProvider
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import club.librum.kviz.servisi.Napredak
import club.librum.kviz.servisi.Supabase
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/** Činjenice o državama (Wikidata, alati/cinjenice-drzava.mjs) za uvod u bitku. */
object Cinjenice {
    private var sve: Map<String, List<String>> = emptyMap()
    fun ucitaj(json: String) {
        sve = Supabase.json.parseToJsonElement(json).jsonObject.mapValues { (_, v) -> v.jsonArray.map { it.jsonPrimitive.content } }
    }
    fun za(id: String): List<String> = sve[id].orEmpty()
}

/**
 * Dugme pomoći: troši iz dnevnog fonda (7 za sve igre), najviše jednom po partiji.
 * Broj u uglu je koliko je pomoći ostalo danas.
 */
@Composable
fun PomocDugme(ikonica: ImageVector, naziv: String, vrsta: String, iskoriscena: Boolean, dostupno: Boolean = true,
               modifier: Modifier = Modifier, iskoristi: () -> Unit) {
    val n = Napredak.deljeni
    val ostalo = n.pomociOstalo()
    val moze = !iskoriscena && ostalo > 0 && dostupno
    Box(modifier.width(76.dp).height(54.dp)) {
        Box(
            Modifier.fillMaxSize().alpha(if (moze) 1f else 0.35f)
                .background(Boje.kartica, RoundedCornerShape(16.dp)).border(2.dp, Boje.mastilo, RoundedCornerShape(16.dp))
                .clickable(enabled = moze) { if (n.iskoristiPomoc(vrsta)) iskoristi() }
                .semantics { contentDescription = "$naziv, $ostalo pomoći danas" },
            contentAlignment = Alignment.Center,
        ) { Icon(ikonica, contentDescription = null, tint = Boje.mastilo) }
        Box(Modifier.align(Alignment.TopEnd).offset(6.dp, (-6).dp).size(20.dp).background(Boje.mastilo, CircleShape), contentAlignment = Alignment.Center) {
            Text("$ostalo", style = tekst(11.sp, FontWeight.Bold, Boje.naMastilu))
        }
    }
}

/**
 * Četiri pomoći iste za sve igre (kao iOS PomociTraka); null radnja = pomoć nema smisla u toj igri ili trenutku.
 * Vešanje nema sat, pa umesto vremena vraća život; tačno/netačno umesto 50/50 ima „Štit”.
 */
@Composable
fun PomociTraka(iskoriscena: Boolean, polaPola: (() -> Unit)?, nagovestaj: (() -> Unit)?, vreme: (() -> Unit)?, preskok: (() -> Unit)?,
                vremeJeZivot: Boolean = false, polaPolaNaziv: String = "50/50", iskoristi: () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            listOf(
                Triple(IkonicaPolaPola, polaPolaNaziv to "polaPola", polaPola),
                Triple(Icons.Rounded.Lightbulb, "Nagoveštaj" to "nagovestaj", nagovestaj),
                Triple(if (vremeJeZivot) Icons.Rounded.Favorite else Icons.Rounded.Timer, (if (vremeJeZivot) "Još jedan život" to "zivot" else "Dodatno vreme" to "vreme"), vreme),
                Triple(Icons.Rounded.SkipNext, "Preskok" to "preskok", preskok),
            ).forEach { (ik, nv, radnja) ->
                PomocDugme(ik, nv.first, nv.second, iskoriscena, radnja != null, Modifier.weight(1f)) { iskoristi(); radnja?.invoke() }
            }
        }
        PomocNapomena(iskoriscena)
    }
}

/** Jedan red ispod pomoći: pravilo i kada stiže novi fond. */
@Composable
fun PomocNapomena(iskoriscena: Boolean, boja: androidx.compose.ui.graphics.Color = Boje.sivaTekst) {
    val n = Napredak.deljeni
    val ostalo = n.pomociOstalo()
    val tekst = when {
        iskoriscena -> "Pomoć je iskorišćena u ovoj partiji."
        ostalo == 0 -> n.sledeciFondPomoci()?.let { val s = (it - System.currentTimeMillis()) / 1000; "Danas nema više pomoći. Novih ${Napredak.POMOCI_DNEVNO} za ${s / 3600} h ${s % 3600 / 60} min." }
            ?: "Danas nema više pomoći."
        else -> "Jedna pomoć po partiji · danas još $ostalo od ${Napredak.POMOCI_DNEVNO} za sve igre"
    }
    Text(tekst, style = tekst(12.sp, FontWeight.SemiBold, boja))
}

/** Avatar igrača: lik sa Knjigopolisa („s3:2:4”, asset avatari/s3_2_4.jpg), stari veb profili „animal_07.png”, inače maskota. */
@SuppressLint("DiscouragedApi")
@Composable
fun AvatarSlika(avatar: String?, velicina: Dp, maskota: Maskota = Maskota.MIMI) {
    val kontekst = LocalContext.current
    val slika = remember(avatar) {
        when {
            avatar.isNullOrEmpty() -> null
            avatar.startsWith("animal_") -> null
            else -> runCatching { kontekst.assets.open("avatari/${avatar.replace(':', '_')}.jpg").use { android.graphics.BitmapFactory.decodeStream(it) } }.getOrNull()
        }
    }
    val zivotinja = remember(avatar) {
        avatar?.takeIf { it.startsWith("animal_") }?.let { kontekst.resources.getIdentifier("avatar_" + it.removePrefix("animal_").removeSuffix(".png"), "drawable", kontekst.packageName) }?.takeIf { it != 0 }
    }
    Box(Modifier.size(velicina).clip(CircleShape).border(if (velicina > 60.dp) 3.dp else 2.dp, Boje.mastilo, CircleShape).background(Boje.roze), contentAlignment = Alignment.Center) {
        when {
            slika != null -> Image(slika.asImageBitmap(), null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
            zivotinja != null -> Image(painterResource(zivotinja), null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
            else -> MaskotaSlika(maskota, velicina * 0.8f)
        }
    }
}

/** Svi likovi za izbor avatara (public/avatari/spisak.json). */
fun sviAvatari(kontekst: android.content.Context): List<String> =
    runCatching { Supabase.json.parseToJsonElement(kontekst.assets.open("avatari/spisak.json").bufferedReader().use { it.readText() }).jsonArray.map { it.jsonPrimitive.content } }
        .getOrDefault(emptyList())

/** Donji list u stilu kita (umesto sistemskog). */
@Composable
fun DonjiList(zatvori: () -> Unit, sadrzaj: @Composable () -> Unit) = PrekrivacEkrana(zatvori) {
    Box(Modifier.fillMaxSize().background(Boje.senka.copy(alpha = 0.55f)).clickable(MutableInteractionSource(), null, onClick = zatvori), contentAlignment = Alignment.BottomCenter) {
        Column(
            Modifier.fillMaxWidth().background(Boje.krem, RoundedCornerShape(topStart = 32.dp, topEnd = 32.dp))
                .border(2.5.dp, Boje.mastilo, RoundedCornerShape(topStart = 32.dp, topEnd = 32.dp))
                .clickable(MutableInteractionSource(), null) {}
                .verticalScroll(rememberScrollState()).padding(bottom = LocalDnoProzora.current).padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Box(Modifier.align(Alignment.CenterHorizontally).width(44.dp).height(5.dp).background(Boje.kremTamnija, RoundedCornerShape(3.dp)))
            sadrzaj()
        }
    }
}

/**
 * Crta sadržaj preko celog ekrana u sopstvenom prozoru (bez sistemskog zatamnjenja, izgled ostaje naš).
 * Zašto: pozvan iz stavke LazyColumn-a dobija neograničenu visinu, pa verticalScroll u njemu ruši app
 * (pad 1.0.1 na Play testu, meni „Više” na objavi). Sistemsko „nazad” zatvara.
 */
@Composable
fun PrekrivacEkrana(zatvori: () -> Unit, sadrzaj: @Composable () -> Unit) {
    // U prozoru dijaloga Compose ne dobija razmake sistemskih traka, pa donji razmak uzimamo iz glavnog prozora.
    val dno = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    Dialog(onDismissRequest = zatvori, properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false)) {
        val prozor = (LocalView.current.parent as? DialogWindowProvider)?.window
        SideEffect {
            prozor?.setDimAmount(0f)
            // Dijalog po difoltu „staje” između sistemskih traka, a sadržaj je visok koliko ekran: dno bi se odseklo.
            prozor?.addFlags(WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS)
            prozor?.attributes = prozor?.attributes?.apply {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) fitInsetsTypes = 0
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
            prozor?.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
        }
        CompositionLocalProvider(LocalDnoProzora provides dno) { sadrzaj() }
    }
}

/** Visina donje sistemske trake za sadržaj u PrekrivacEkrana (navigationBarsPadding tamo vraća 0). */
val LocalDnoProzora = staticCompositionLocalOf { 0.dp }

/** Podvučen izbor sa vrednostima bilo kog tipa. */
@Composable
fun <T> Podvuceno(opcije: List<Pair<T, String>>, izbor: T, promeni: (T) -> Unit) {
    Izbor(opcije.map { it.second }, opcije.indexOfFirst { it.first == izbor }) { promeni(opcije[it].first) }
}

@Composable
fun Red(vararg deca: @Composable () -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) { deca.forEach { it() } }
}

val IkonicaPolaPola: ImageVector get() = Icons.Rounded.Contrast

@Composable
fun Ilustracija(ime: String, velicina: Dp, modifier: Modifier = Modifier) {
    val kontekst = LocalContext.current
    @SuppressLint("DiscouragedApi")
    val id = remember(ime) { kontekst.resources.getIdentifier(ime, "drawable", kontekst.packageName) }
    if (id != 0) Image(painterResource(id), null, modifier.size(velicina))
}
