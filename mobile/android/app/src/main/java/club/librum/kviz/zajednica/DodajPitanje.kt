package club.librum.kviz.zajednica

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import club.librum.kviz.servisi.Sesija
import club.librum.kviz.servisi.Supabase
import club.librum.kviz.ui.Boje
import club.librum.kviz.ui.Dugme
import club.librum.kviz.ui.Izbor
import club.librum.kviz.ui.Papir
import club.librum.kviz.ui.naslov
import club.librum.kviz.ui.tekst
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable

// Vlasnik 04.11 (isto kao iOS): samo pitanje ili reč; sva pitanja idu u jedan (opšti) fond, bez izbora igre.
private val VRSTE = listOf("pro" to "Pitanje", "vesanje" to "Reč za vešanje")
private val KATEGORIJE_VESANJA = listOf("Sport", "Geografija", "Istorija", "Kultura", "Priroda", "Predmeti")

@Serializable private data class OdgovorPredloga(val ok: Boolean, val greska: String? = null)

/**
 * Predlog pitanja ili reči sa mog profila (RPC posalji_predlog, iste provere kao veb: duplikati, različiti odgovori, dnevni limit).
 * Nacrt ostaje na telefonu dok se ne pošalje (isto kao iOS).
 */
@Composable
fun DodajPitanjeEkran(sesija: Sesija, pocetna: String, nazad: () -> Unit) {
    val prefs = androidx.compose.ui.platform.LocalContext.current.getSharedPreferences("nacrt_predloga", android.content.Context.MODE_PRIVATE)
    var vrsta by remember { mutableStateOf(prefs.getString("vrsta", null) ?: if (pocetna == "vesanje") "vesanje" else "pro") }
    var pitanje by remember { mutableStateOf(prefs.getString("pitanje", "").orEmpty()) }
    var tacan by remember { mutableStateOf(prefs.getString("tacan", "").orEmpty()) }
    var netacni by remember { mutableStateOf((prefs.getString("netacni", null)?.split("\u0001") ?: listOf("", "", "")).let { if (it.size == 3) it else listOf("", "", "") }) }
    var zanr by remember { mutableStateOf(prefs.getString("zanr", "").orEmpty()) }
    fun sacuvajNacrt() = prefs.edit().putString("vrsta", vrsta).putString("pitanje", pitanje).putString("tacan", tacan)
        .putString("netacni", netacni.joinToString("\u0001")).putString("zanr", zanr).apply()
    fun obrisiNacrt() = prefs.edit().clear().apply()
    var poruka by remember { mutableStateOf<Pair<Boolean, String>?>(null) }
    var salje by remember { mutableStateOf(false) }
    val opseg = rememberCoroutineScope()
    val vesanje = vrsta == "vesanje"
    val popunjeno = pitanje.isNotBlank() && tacan.isNotBlank() && (vesanje || netacni.all { it.isNotBlank() })

    Box(Modifier.fillMaxSize()) {
        Papir()
        Column(Modifier.fillMaxSize().statusBarsPadding().imePadding().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            IconButton(onClick = nazad, modifier = Modifier.size(44.dp).background(Boje.kartica, CircleShape).border(1.5.dp, Boje.kremTamnija, CircleShape)) {
                Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = "Nazad", tint = Boje.mastilo)
            }
            Text(if (vesanje) "Dodaj reč" else "Dodaj pitanje", style = naslov(32.sp))
            Text("Urednici pregledaju svaki predlog. Kad prođe, ulazi u igru i piše se na tvom profilu.", style = tekst(14.sp, boja = Boje.sivaTekst))
            Box(Modifier.horizontalScroll(rememberScrollState())) {
                Izbor(VRSTE.map { it.second }, VRSTE.indexOfFirst { it.first == vrsta }) {
                    vrsta = VRSTE[it].first; poruka = null
                    if (vrsta == "vesanje" && zanr !in KATEGORIJE_VESANJA) zanr = KATEGORIJE_VESANJA[0]
                }
            }
            if (vesanje) {
                Text("Pojam (4–18 slova)", style = tekst(14.sp, FontWeight.SemiBold)); PoljeTeksta(pitanje, "Dunav") { pitanje = it.take(18) }
                Text("Opis, bez samog pojma", style = tekst(14.sp, FontWeight.SemiBold)); PoljeTeksta(tacan, "Druga po dužini reka u Evropi") { tacan = it.take(200) }
                Text("Kategorija", style = tekst(14.sp, FontWeight.SemiBold))
                Box(Modifier.horizontalScroll(rememberScrollState())) { Izbor(KATEGORIJE_VESANJA, KATEGORIJE_VESANJA.indexOf(zanr).coerceAtLeast(0)) { zanr = KATEGORIJE_VESANJA[it] } }
            } else {
                Text("Pitanje", style = tekst(14.sp, FontWeight.SemiBold))
                PoljeTeksta(pitanje, "Na primer: Koja reka protiče kroz Beograd i Novi Sad?", visina = 100) { pitanje = it.take(300) }
                Text("Tačan odgovor", style = tekst(14.sp, FontWeight.SemiBold)); PoljeTeksta(tacan, "Dunav") { tacan = it.take(120) }
                netacni.forEachIndexed { i, v ->
                    Text("Netačan odgovor ${i + 1}", style = tekst(14.sp, FontWeight.SemiBold))
                    PoljeTeksta(v, "") { novo -> netacni = netacni.toMutableList().also { l -> l[i] = novo.take(120) } }
                }
                if (vrsta == "book") { Text("Žanr (nije obavezno)", style = tekst(14.sp, FontWeight.SemiBold)); PoljeTeksta(zanr, "Roman") { zanr = it.take(40) } }
            }
            poruka?.let { (ok, t) -> Text(t, style = tekst(14.sp, FontWeight.SemiBold, if (ok) Boje.teal else Boje.crvena)) }
            Dugme(if (salje) "Šaljem…" else "Pošalji", omoguceno = popunjeno && !salje) {
                salje = true
                opseg.launch {
                    runCatching {
                        val t = sesija.vazeciToken() ?: error("Prijavi se da bi poslao predlog.")
                        Supabase.json.decodeFromString<OdgovorPredloga>(Supabase.rpc("posalji_predlog", mapOf(
                            "p_segment" to vrsta, "p_pitanje" to pitanje, "p_tacan" to tacan,
                            "p_netacni" to if (vesanje) emptyList() else netacni,
                            // Book bez žanra ide u „Razno”, kao na vebu.
                            "p_zanr" to if (vrsta == "pro") null else zanr.ifBlank { "Razno" },
                        ), t))
                    }.onSuccess { r ->
                        if (r.ok) { poruka = true to "Poslato. Hvala! Predlog čeka urednika."; pitanje = ""; tacan = ""; netacni = listOf("", "", ""); obrisiNacrt() }
                        else poruka = false to (r.greska ?: "Predlog nije prihvaćen.")
                    }.onFailure { poruka = false to (it.message ?: "Slanje nije uspelo.") }
                    salje = false
                }
            }
            Dugme("Sačuvaj nacrt", vrsta = club.librum.kviz.ui.VrstaDugmeta.SEKUNDARNO, omoguceno = pitanje.isNotBlank() || tacan.isNotBlank() || netacni.any { it.isNotBlank() }) {
                sacuvajNacrt(); poruka = true to "Nacrt je sačuvan na telefonu."
            }
            Spacer(Modifier.height(40.dp))
        }
    }
}
