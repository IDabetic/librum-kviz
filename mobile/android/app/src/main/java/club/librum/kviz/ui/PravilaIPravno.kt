package club.librum.kviz.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material.icons.rounded.KeyboardArrowUp
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import club.librum.kviz.servisi.Supabase
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/** Igre na ekranu pravila: ključ u pravila-igara.json, naziv i boja kartice (isto kao iOS katalog). */
private val IGRE_PRAVILA = listOf(
    Triple("dnevni", "Dnevni izazov", 0xFFFFD84D), Triple("osvajanje", "Osvajanje sveta", 0xFF12907E), Triple("pro", "PRO kviz", 0xFF6D4BC9),
    Triple("book", "Book kviz", 0xFFF4A33C), Triple("duel", "Duel", 0xFF151515), Triple("brzi", "Brzi kviz", 0xFFFFD84D),
    Triple("vesanje", "Vešanje", 0xFFFF5FA2), Triple("slikari", "Slikari", 0xFFFF5FA2), Triple("tema", "Kvizovi po temi", 0xFFF4A33C),
)

@Composable
private fun Nazad(nazad: () -> Unit) {
    IconButton(onClick = nazad, modifier = Modifier.size(44.dp).background(Boje.kartica, CircleShape).border(1.5.dp, Boje.kremTamnija, CircleShape)) {
        Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = "Nazad", tint = Boje.mastilo)
    }
}

@Composable
private fun Tacka(tekst: String, boja: Color) {
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Box(Modifier.padding(top = 6.dp).size(10.dp).background(boja, CircleShape).border(1.5.dp, Boje.mastilo, CircleShape))
        Text(tekst, style = tekst(15.sp))
    }
}

/** Pravila na profilu: šta važi za sve igre, pa pravila i bodovanje svake igre (src/lib/igre/pravila-igara.json). */
@Composable
fun PravilaIgaraEkran(nazad: () -> Unit) {
    val kontekst = LocalContext.current
    val pravila = remember {
        runCatching {
            Supabase.json.parseToJsonElement(kontekst.assets.open("pravila-igara.json").bufferedReader().use { it.readText() }).jsonObject
                .filterValues { it is kotlinx.serialization.json.JsonArray }.mapValues { (_, v) -> v.jsonArray.map { it.jsonPrimitive.content } }
        }.getOrDefault(emptyMap())
    }
    var otvorena by remember { mutableStateOf<String?>(null) }
    Box(Modifier.fillMaxSize()) {
        Papir()
        Column(Modifier.fillMaxSize().statusBarsPadding().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Nazad(nazad)
            Text("Pravila igara", style = naslov(32.sp), modifier = Modifier.semantics { heading() })
            Column(Modifier.fillMaxWidth().mirna().padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("Za sve igre", style = tekst(17.sp, FontWeight.Bold))
                pravila["zaSve"].orEmpty().forEach { Tacka(it, Boje.zuta) }
            }
            IGRE_PRAVILA.forEach { (kljuc, naziv, boja) ->
                val otvoreno = otvorena == kljuc
                Column(Modifier.fillMaxWidth().mirna().padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Row(Modifier.fillMaxWidth().clickable { otvorena = if (otvoreno) null else kljuc }, verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Box(Modifier.size(14.dp).background(Color(boja), CircleShape).border(1.5.dp, Boje.mastilo, CircleShape))
                        Text(naziv, style = tekst(17.sp, FontWeight.Bold), modifier = Modifier.weight(1f))
                        Icon(if (otvoreno) Icons.Rounded.KeyboardArrowUp else Icons.Rounded.KeyboardArrowDown,
                            contentDescription = if (otvoreno) "Zatvori pravila" else "Otvori pravila", tint = Boje.sivaTekst)
                    }
                    if (otvoreno) pravila[kljuc].orEmpty().forEach { Tacka(it, Color(boja)) }
                }
            }
            Spacer(Modifier.height(40.dp))
        }
    }
}

@Serializable private data class Deo(val naslov: String, val tekst: List<String>)
@Serializable private data class Dokument(val naslov: String, val azurirano: String, val delovi: List<Deo>)

/** Politika privatnosti („privatnost”) ili uslovi korišćenja („uslovi”) iz src/lib/igre/pravno.json, isto kao iOS. */
@Composable
fun PravniTekstEkran(vrsta: String, nazad: () -> Unit) {
    val kontekst = LocalContext.current
    val d = remember(vrsta) {
        runCatching {
            Supabase.json.decodeFromString<Map<String, Dokument>>(kontekst.assets.open("pravno.json").bufferedReader().use { it.readText() })[vrsta]
        }.getOrNull()
    }
    Box(Modifier.fillMaxSize()) {
        Papir()
        Column(Modifier.fillMaxSize().statusBarsPadding().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Nazad(nazad)
            if (d == null) Text("Tekst nije pronađen. Pišite nam na info@librum.club.", style = tekst(15.sp))
            else {
                Text(d.naslov, style = naslov(30.sp), modifier = Modifier.semantics { heading() })
                Text(d.azurirano, style = tekst(13.sp, boja = Boje.sivaTekst))
                d.delovi.forEach { deo ->
                    Column(Modifier.fillMaxWidth().mirna().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(deo.naslov, style = tekst(17.sp, FontWeight.Bold), modifier = Modifier.semantics { heading() })
                        deo.tekst.forEach { Text(it, style = tekst(15.sp)) }
                    }
                }
            }
            Spacer(Modifier.height(40.dp))
        }
    }
}
