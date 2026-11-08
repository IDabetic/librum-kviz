package club.librum.kviz.ui

import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Campaign
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.border
import androidx.compose.material.icons.rounded.Groups
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.OpenInNew
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.material.icons.rounded.SkipNext
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import club.librum.kviz.BuildConfig
import club.librum.kviz.servisi.Sesija
import club.librum.kviz.servisi.Supabase
import kotlinx.coroutines.launch
import androidx.compose.ui.semantics.contentDescription
import club.librum.kviz.servisi.LicniPodaci
import club.librum.kviz.servisi.Greska
import androidx.compose.runtime.mutableIntStateOf
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.jsonObject
import androidx.compose.ui.draw.rotate
import kotlinx.serialization.Serializable
import java.time.Instant
import java.time.temporal.ChronoUnit

private val ILUSTRACIJE = mapOf(
    "pro" to club.librum.kviz.R.drawable.igra_pro, "book" to club.librum.kviz.R.drawable.igra_book, "duel" to club.librum.kviz.R.drawable.igra_duel,
    "tema/slikari" to club.librum.kviz.R.drawable.igra_slikari, "brzi" to club.librum.kviz.R.drawable.igra_brzi, "vesanje" to club.librum.kviz.R.drawable.igra_vesanje,
)

/** Početna iz kita: veliki naslov (One UI ostavlja vazduh gore) i kartice igara; `idi` prima rutu igre. */
@Composable
fun Pocetna(nadimak: String?, idi: (String) -> Unit) {
    Box(Modifier.fillMaxSize()) {
        Papir()
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Spacer(Modifier.height(36.dp))
            Row(verticalAlignment = Alignment.Bottom) {
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    nadimak?.let { Oznaka("Zdravo, $it", Boje.teal) }
                    Text("Izaberi kviz\ni igraj.", style = naslov(40.sp).copy(lineHeight = 42.sp))
                    PitanjaUIgri()
                }
                MaskotaSlika(Maskota.BLOOP, 92.dp)
            }
            ObavestenjaAdmina()
            // Sačuvana partija Osvajanja: nastavlja se odakle je stala (kao iOS „Nastavi partiju”).
            val kontekst = androidx.compose.ui.platform.LocalContext.current
            val sacuvana = remember { club.librum.kviz.osvajanje.OsvajanjeModel.sacuvana(kontekst) }
            if (sacuvana != null) Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(Boje.kartica).border(1.5.dp, Boje.kremTamnija, RoundedCornerShape(18.dp))
                    .clickable { idi("osvajanje/nastavak") }.padding(12.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Box(Modifier.size(44.dp).background(Boje.zuta, RoundedCornerShape(12.dp)), contentAlignment = Alignment.Center) {
                    androidx.compose.material3.Icon(androidx.compose.material.icons.Icons.Rounded.SkipNext, null, tint = Boje.tinta)
                }
                Column(Modifier.weight(1f)) {
                    Text("Nastavi partiju", style = tekst(15.sp, FontWeight.Bold))
                    Text("Osvajač · krug ${minOf(sacuvana.stanje.krug, sacuvana.stanje.ukupnoKrugova)} od ${sacuvana.stanje.ukupnoKrugova}", style = tekst(13.sp, FontWeight.Normal, Boje.sivaTekst))
                }
            }
            // Vlasnik 03.11: Osvajanje sveta je jedna velika kartica, ispod šest igara u dva reda po tri.
            KarticaIgre("Osvajač", "171 država, vojske i bitke znanja protiv rivala.", Boje.teal, Color.White, Maskota.MIMI, true, ilustracija = club.librum.kviz.R.drawable.igra_osvajanje) { idi("osvajanje") }
            club.librum.kviz.karijera.KarijeraKarticaPocetna { idi("karijera") }
            listOf(
                listOf(Triple("PRO kviz", "pro", Boje.ljubicasta to Maskota.LUMI), Triple("Book kviz", "book", Color(0xFFF4A33C) to Maskota.ZIG), Triple("Duel", "duel", Boje.mastilo to Maskota.BLOOP)),
                listOf(Triple("Slikari", "tema/slikari", Boje.roze to Maskota.LUMI), Triple("Brzi kviz", "brzi", Boje.zuta to Maskota.ZIG), Triple("Vešanje", "vesanje", Color(0xFF6EC3F2) to Maskota.MIMI)),
            ).forEach { red ->
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    red.forEach { (naziv, ruta, bm) -> MalaIgra(naziv, bm.first, bm.second, ILUSTRACIJE[ruta], Modifier.weight(1f)) { idi(ruta) } }
                }
            }
            // Vlasnik 08.11: šest dnevnih igara reči (reci/).
            club.librum.kviz.reci.IgreReciKartica { idi("reci") }
            // Vlasnik 03.11: svih pet igara za 2–8 igrača ili timove, protiv računara ili pravih igrača.
            Row(
                Modifier.fillMaxWidth().pop(Boje.kartica, 20.dp).clickable { idi("takmicenje") }.padding(12.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Box(Modifier.size(48.dp).background(Boje.zuta, RoundedCornerShape(14.dp)).border(2.dp, Boje.mastilo, RoundedCornerShape(14.dp)), contentAlignment = Alignment.Center) {
                    androidx.compose.material3.Icon(androidx.compose.material.icons.Icons.Rounded.Groups, null, tint = Boje.tinta)
                }
                Column(Modifier.weight(1f)) {
                    Text("Igraj sa drugima", style = tekst(16.sp, FontWeight.Bold))
                    Text("2–8 igrača, timovi, računar", style = tekst(13.sp, FontWeight.Normal, Boje.sivaTekst), maxLines = 1)
                }
                androidx.compose.material3.Icon(androidx.compose.material.icons.Icons.AutoMirrored.Rounded.KeyboardArrowRight, null, tint = Boje.sivaTekst)
            }
            Text("Teme", style = naslov(26.sp), modifier = Modifier.padding(top = 8.dp))
            KarticaIgre("Dnevni izazov", "Istih 10 pitanja za sve danas. Jedan pokušaj, jedna rang lista.", Boje.zuta, Boje.tinta, Maskota.BLOOP, false) { idi("dnevni") }
            KarticaIgre("Opšte znanje", "10 pitanja iz svega pomalo, 15 sekundi po pitanju.", Color(0xFFF4A33C), Boje.mastilo, Maskota.BLOOP, false) { idi("tema/opste") }
            Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                KarticaIgre("Knjige", "Pisci, dela i likovi.", Boje.teal, Color.White, Maskota.ZIG, false, Modifier.weight(1f)) { idi("tema/knjige") }
                KarticaIgre("Slikari: majstori", "Manje poznata dela.", Boje.ljubicasta, Color.White, Maskota.ZIG, false, Modifier.weight(1f)) { idi("tema/slikari-tesko") }
            }
            Text("Kategorije", style = naslov(26.sp), modifier = Modifier.padding(top = 8.dp))
            // Kategorije opšteg fonda (questions.tags), isto kao iOS KvizKatalog.teme.
            listOf(
                "Film i TV" to "film i tv", "Muzika" to "muzika", "Sport" to "sport", "Geografija" to "geografija",
                "Istorija" to "istorija", "Ličnosti" to "ličnosti", "Jezik" to "jezik", "Nauka" to "nauka",
                "Priroda" to "priroda", "Kultura i tradicija" to "kultura",
                "Religija i mitologija" to "religija i mitologija", "Hrana i piće" to "hrana i piće", "Tehnika" to "tehnika",
            ).chunked(2).forEachIndexed { red, par ->
                Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    par.forEachIndexed { i, (naziv, tag) ->
                        val boje = listOf(Boje.roze, Boje.ljubicasta, Color(0xFF6EC3F2), Color(0xFFF4A33C), Boje.teal, Boje.zuta)
                        val b = boje[(red * 2 + i) % boje.size]
                        KarticaIgre(naziv, "10 pitanja", b, if (b == Boje.ljubicasta || b == Boje.teal) Color.White else Boje.tinta,
                            listOf(Maskota.MIMI, Maskota.ZIG, Maskota.BLOOP, Maskota.LUMI)[(red * 2 + i) % 4], false, Modifier.weight(1f)) {
                            idi("tema/kat:" + android.net.Uri.encode(tag))
                        }
                    }
                }
            }
            KarticaIgre("Nemoguća pitanja", "Samo najteža pitanja iz baze.", Color(0xFFE5385C), Color.White, Maskota.LUMI, false) { idi("tema/tesko") }
            Spacer(Modifier.height(80.dp))
        }
    }
}

/** Mala kartica igre (tri u redu): maskota i naslov. */
@Composable
private fun MalaIgra(naslovIgre: String, boja: Color, maskota: Maskota, ilustracija: Int?, modifier: Modifier = Modifier, radnja: () -> Unit) {
    val tekstBoja = if (boja == Boje.ljubicasta || boja == Boje.mastilo || boja == Boje.teal) Color.White else Boje.tinta
    Column(
        modifier.height(128.dp).pop(boja).clickable(role = Role.Button, onClick = radnja).padding(8.dp)
            .semantics(mergeDescendants = true) {},
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center,
    ) {
        if (ilustracija != null) androidx.compose.foundation.Image(androidx.compose.ui.res.painterResource(ilustracija), null, Modifier.size(64.dp)) else MaskotaSlika(maskota, 60.dp)
        Text(naslovIgre, style = naslov(15.sp).copy(color = tekstBoja, textAlign = androidx.compose.ui.text.style.TextAlign.Center, lineHeight = 16.sp), maxLines = 2)
    }
}

@Composable
private fun KarticaIgre(naslovIgre: String, opis: String, boja: Color, bojaTeksta: Color, maskota: Maskota, velika: Boolean, modifier: Modifier = Modifier, ilustracija: Int? = null, radnja: () -> Unit) {
    Box(
        modifier.fillMaxWidth().height(if (velika) 250.dp else 160.dp).pop(boja).clip(RoundedCornerShape(24.dp))
            .clickable(role = Role.Button, onClick = radnja),
    ) {
        Box(Modifier.align(Alignment.TopEnd).offset(x = 40.dp, y = (-30).dp).size(if (velika) 230.dp else 150.dp).alpha(0.22f).background(Boje.kartica, CircleShape))
        // Ilustracija igre (Freepik, mobile/ILUSTRACIJE.md) kao na iOS-u; bez nje ostaje maskota.
        if (ilustracija != null) androidx.compose.foundation.Image(androidx.compose.ui.res.painterResource(ilustracija), null,
            Modifier.align(Alignment.TopEnd).padding(top = 12.dp, end = 12.dp).size(if (velika) 128.dp else 76.dp).rotate(8f))
        else MaskotaSlika(maskota, if (velika) 160.dp else 84.dp, Modifier.align(Alignment.TopEnd).offset(y = if (velika) 4.dp else (-6).dp))
        Column(Modifier.align(Alignment.BottomStart).padding(if (velika) 22.dp else 18.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            // Dve reči („Osvajanje sveta”) idu u dva reda umesto da se drugi deo seče.
            Text(naslovIgre, style = naslov(if (velika) 36.sp else 24.sp).copy(color = bojaTeksta, lineHeight = if (velika) 38.sp else 25.sp), maxLines = 2)
            Text(opis, style = tekst(14.sp, FontWeight.SemiBold, bojaTeksta.copy(alpha = 0.85f)), modifier = Modifier.fillMaxWidth(if (velika) 0.7f else 1f))
        }
    }
}

/** Podvučen izbor umesto kapsula. */
@Composable
fun Izbor(opcije: List<String>, izabrana: Int, promeni: (Int) -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(22.dp)) {
        opcije.forEachIndexed { i, natpis ->
            Text(
                natpis, style = tekst(15.sp, FontWeight.Bold, if (i == izabrana) Boje.mastilo else Boje.sivaTekst),
                modifier = Modifier
                    .semantics { selected = i == izabrana }
                    .clickable(role = Role.Tab) { promeni(i) }
                    .drawBehind { if (i == izabrana) drawRect(Boje.mastilo, Offset(0f, size.height - 3.dp.toPx()), size.copy(height = 3.dp.toPx())) }
                    .padding(vertical = 8.dp),
            )
        }
    }
}

@Serializable private data class RedListe(val mesto: Int, val user_id: String, val nadimak: String, val avatar: String? = null, val poeni: Int, val partija: Int)

private val IGRE_LISTE = listOf("dnevni" to "Dnevni", "osvajanje" to "Osvajač", "pro" to "PRO", "book" to "Book", "duel" to "Duel", "slikari" to "Slikari", "brzi" to "Brzi", "vesanje" to "Vešanje")
private val PERIODI = listOf("dan" to "Dan", "nedelja" to "Nedelja", "mesec" to "Mesec", "godina" to "Godina")

/** Rang lista po igri i periodu (RPC rang_lista_igre), za sve ili samo igrače koje pratim; red vodi na profil. */
@Composable
fun RangLista(sesija: club.librum.kviz.servisi.Sesija, idi: (String) -> Unit) {
    val nalog by sesija.nalog.collectAsState()
    var igra by remember { mutableStateOf(1) }
    var period by remember { mutableStateOf(1) }
    var krug by remember { mutableStateOf(0) }
    var redovi by remember { mutableStateOf<List<RedListe>?>(null) }
    var greska by remember { mutableStateOf<String?>(null) }
    var pokusaj by remember { mutableStateOf(0) }
    // Glavna tabla (kao iOS): Osvajač, Karijera, Ostale igre.
    var tabla by remember { mutableStateOf(0) }

    LaunchedEffect(igra, period, krug, pokusaj, nalog?.id) {
        // Poslednja lista za ove filtere odmah (bez kruga za učitavanje), sveža stiže tiho.
        val kljuc = "rang-$igra-$period-$krug"
        greska = null; redovi = club.librum.kviz.servisi.Kes.ucitaj(kljuc)
        runCatching {
            Supabase.json.decodeFromString<List<RedListe>>(Supabase.rpc("rang_lista_igre", mapOf(
                "p_igra" to IGRE_LISTE[igra].first, "p_period" to PERIODI[period].first, "p_broj" to 50, "p_krug" to if (krug == 1) "pratim" else "svi",
            ), runCatching { sesija.vazeciToken() }.getOrNull()))
        }.onSuccess { redovi = it; club.librum.kviz.servisi.Kes.sacuvaj(kljuc, it) }.onFailure { if (redovi == null) greska = it.message }
    }

    Box(Modifier.fillMaxSize()) {
        Papir()
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Spacer(Modifier.height(20.dp))
            Text("Rang lista", style = naslov(40.sp))
            Izbor(listOf("Osvajač", "Karijerista", "Ostale igre"), tabla) { t ->
                tabla = t
                val osv = IGRE_LISTE.indexOfFirst { it.first == "osvajanje" }
                if (t == 0) igra = osv else if (t == 2 && igra == osv) igra = IGRE_LISTE.indexOfFirst { it.first == "pro" }
            }
            if (tabla == 1) { club.librum.kviz.karijera.KarijeraRang { id -> idi("karijeracv/$id") }; Spacer(Modifier.height(80.dp)); return@Column }
            if (tabla == 2) {
                val ostale = IGRE_LISTE.withIndex().filter { it.value.first != "osvajanje" }
                Row(Modifier.horizontalScroll(rememberScrollState())) { Izbor(ostale.map { it.value.second }, ostale.indexOfFirst { it.index == igra }) { igra = ostale[it].index } }
            }
            Izbor(PERIODI.map { it.second }, period) { period = it }
            if (nalog != null) Izbor(listOf("Svi igrači", "Koje pratim"), krug) { krug = it }
            val r = redovi
            when {
                greska != null -> Column(Modifier.fillMaxWidth().mirna().padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(greska.orEmpty(), style = tekst(15.sp, boja = Boje.sivaTekst))
                    Dugme("Pokušaj ponovo", vrsta = VrstaDugmeta.SEKUNDARNO) { pokusaj++ }
                }
                r == null -> CircularProgressIndicator(color = Boje.mastilo)
                r.isEmpty() -> Column(Modifier.fillMaxWidth().mirna().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    MaskotaSlika(Maskota.LUMI, 90.dp)
                    Text(if (krug == 1) "Igrači koje pratiš još nemaju rezultat u ovom periodu." else "Još nema rezultata u ovom periodu. Budi prvi.",
                        style = tekst(15.sp, boja = Boje.sivaTekst))
                }
                else -> Column(Modifier.fillMaxWidth().mirna()) {
                    r.forEachIndexed { i, red ->
                        val ja = red.user_id == nalog?.id
                        Row(Modifier.fillMaxWidth().background(if (ja) Boje.tealSvetla else Color.Transparent).clickable { idi("igrac/${red.user_id}") }
                            .padding(horizontal = 16.dp, vertical = 10.dp).semantics(mergeDescendants = true) {},
                            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            Text("${red.mesto}", style = naslov(18.sp, if (red.mesto <= 3) Boje.mastilo else Boje.sivaTekst), modifier = Modifier.width(30.dp))
                            club.librum.kviz.ui.AvatarSlika(red.avatar, 40.dp)
                            Column(Modifier.weight(1f)) {
                                Text(red.nadimak + if (ja) " (ti)" else "", style = tekst(16.sp, FontWeight.SemiBold), maxLines = 1)
                                Text("${red.partija} partija", style = tekst(12.sp, boja = Boje.sivaTekst))
                            }
                            Text("${red.poeni}", style = naslov(20.sp))
                        }
                        if (i < r.size - 1) HorizontalDivider(color = Boje.kremTamnija)
                    }
                }
            }
            Spacer(Modifier.height(80.dp))
        }
    }
}

/** Profil: prijava i registracija, ili moj profil; nalog, odjava i brisanje su u Podešavanjima. */
@Composable
fun Profil(sesija: Sesija, idi: (String) -> Unit = {}) {
    val nalog by sesija.nalog.collectAsState()
    var mojProfil by remember { mutableStateOf<club.librum.kviz.zajednica.ProfilIgraca?>(null) }
    LaunchedEffect(nalog?.id) { mojProfil = nalog?.id?.let { id -> runCatching { club.librum.kviz.zajednica.Drustvo.profil(sesija, id) }.getOrNull() } }
    val kontekst = LocalContext.current

    Box(Modifier.fillMaxSize()) {
        Papir()
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            // Kao iOS: zupčanik gore desno vodi u Podešavanja (nalog, igra, podrška, odjava).
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                Box(Modifier.size(44.dp).clickable(role = Role.Button) { idi("podesavanja") }.semantics { contentDescription = "Podešavanja" }, contentAlignment = Alignment.Center) {
                    Icon(androidx.compose.material.icons.Icons.Rounded.Settings, contentDescription = null, tint = Boje.mastilo, modifier = Modifier.size(26.dp))
                }
            }
            val n = nalog
            if (n != null) {
                val mp = mojProfil
                if (mp != null) {
                    club.librum.kviz.zajednica.ProfilZaglavlje(mp) {
                        // Samo na mom profilu; drugi vide „Poslao N pitanja · M u igri”.
                        // Isto kao iOS: jedno dugme, unutra izbor pitanje ili reč.
                        Dugme("Dodaj pitanje", vrsta = VrstaDugmeta.SEKUNDARNO) { idi("dodaj/pro") }
                    }
                    val nova by club.librum.kviz.zajednica.Brojaci.obavestenja.collectAsState()
                    Row(Modifier.fillMaxWidth().mirna().clickable { idi("sanduce") }.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text("Sanduče", style = tekst(16.sp, FontWeight.SemiBold), modifier = Modifier.weight(1f))
                        if (nova > 0) Text("$nova novo", style = tekst(14.sp, FontWeight.Bold, Boje.roze))
                    }
                    // Fokus profila (kao iOS): Osvajač i Karijera, pa ostale igre kao krugovi.
                    club.librum.kviz.zajednica.ProfilFokus(mp, n.id, true, idi)
                    club.librum.kviz.zajednica.ProfilOstalo(mp)
                }
                if (mp == null) Column(Modifier.fillMaxWidth().pop().padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                        Box(Modifier.size(84.dp).background(Boje.teal, CircleShape).border(2.5.dp, Boje.mastilo, CircleShape), contentAlignment = Alignment.Center) {
                            MaskotaSlika(Maskota.BLOOP, 70.dp)
                        }
                        Column {
                            Text(n.nadimak ?: "Igrač", style = naslov(28.sp))
                            Text(n.email.orEmpty(), style = tekst(14.sp, boja = Boje.sivaTekst))
                        }
                    }
                }
            } else {
                PrijavaForma(sesija)
            }
            // Kao iOS: bedževi i statistika su na ovom telefonu, vide se i bez naloga.
            BedzeviKartica(idi)
            Row(Modifier.fillMaxWidth().mirna().clickable(role = Role.Button) { idi("statistika") }.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("Statistika", style = tekst(15.sp, FontWeight.SemiBold), modifier = Modifier.weight(1f))
                Text("›", style = tekst(20.sp, FontWeight.Bold, Boje.sivaTekst))
            }
            Spacer(Modifier.height(80.dp))
        }
    }
}

/** Koraci prijave kao na iOS-u: kod iz mejla (registracija i zaboravljena lozinka), ponovno slanje, nova lozinka. */
private sealed interface KorakPrijave {
    data object Prijava : KorakPrijave
    data object Registracija : KorakPrijave
    data object Zaboravljena : KorakPrijave
    data class Kod(val email: String, val oporavak: Boolean) : KorakPrijave
}

private const val DUZINA_KODA = 6
// Supabase može da bude podešen i na 8 cifara; prihvatamo oba.
private const val NAJDUZI_KOD = 8
private const val CEKANJE_PONOVO_S = 60
private const val NAJVISE_POKUSAJA = 5

@Composable
private fun PrijavaForma(sesija: Sesija) {
    val opseg = rememberCoroutineScope()
    var korak by remember { mutableStateOf<KorakPrijave>(KorakPrijave.Prijava) }
    var email by remember { mutableStateOf("") }
    var lozinka by remember { mutableStateOf("") }
    var lozinka2 by remember { mutableStateOf("") }
    var ime by remember { mutableStateOf("") }
    var prezime by remember { mutableStateOf("") }
    var nadimak by remember { mutableStateOf("") }
    var kod by remember { mutableStateOf("") }
    var pokusaja by remember { mutableIntStateOf(0) }
    var ponovoZa by remember { mutableIntStateOf(0) }
    var radi by remember { mutableStateOf(false) }
    var greska by remember { mutableStateOf<String?>(null) }
    var obavestenje by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(ponovoZa) { if (ponovoZa > 0) { kotlinx.coroutines.delay(1000); ponovoZa -= 1 } }
    fun idi(k: KorakPrijave) { korak = k; greska = null; obavestenje = null; kod = ""; pokusaja = 0 }
    fun radnja(posao: suspend () -> Unit) {
        radi = true; greska = null
        opseg.launch { runCatching { posao() }.onFailure { greska = it.message }; radi = false }
    }
    fun ispravanEmail() = "@" in email && "." in email.substringAfter("@")

    Column(Modifier.fillMaxWidth().pop().padding(20.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        val naslovKoraka = when (val k = korak) {
            KorakPrijave.Prijava -> "Prijava"; KorakPrijave.Registracija -> "Napravi nalog"
            KorakPrijave.Zaboravljena -> "Zaboravio si lozinku?"; is KorakPrijave.Kod -> if (k.oporavak) "Nova lozinka" else "Proveri sanduče"
        }
        Row(verticalAlignment = Alignment.Bottom) {
            Text(naslovKoraka, style = naslov(30.sp), modifier = Modifier.weight(1f))
            MaskotaSlika(Maskota.ZIG, 70.dp)
        }
        when (val k = korak) {
            KorakPrijave.Prijava, KorakPrijave.Registracija -> {
                val registracija = k == KorakPrijave.Registracija
                Text("Nalog služi da rezultati odu na rang listu. Isti nalog važi i na iPhonu.", style = tekst(14.sp, boja = Boje.sivaTekst))
                Izbor(listOf("Prijava", "Registracija"), if (registracija) 1 else 0) { idi(if (it == 1) KorakPrijave.Registracija else KorakPrijave.Prijava) }
                if (registracija) {
                    Polje("Ime", ime) { ime = it }
                    Polje("Prezime", prezime) { prezime = it }
                    Polje("Nadimak", nadimak) { nadimak = it }
                }
                Polje("Email", email, KeyboardType.Email) { email = it }
                Polje("Lozinka", lozinka, KeyboardType.Password, sakriveno = true) { lozinka = it }
                greska?.let { Text(it, style = tekst(14.sp, FontWeight.SemiBold, Boje.crvena)) }
                Dugme(if (radi) "Sačekaj…" else if (registracija) "Napravi nalog" else "Prijavi se", omoguceno = !radi) {
                    greska = when {
                        !ispravanEmail() -> "Upiši ispravan email."
                        lozinka.length < 6 -> "Lozinka mora imati najmanje 6 karaktera."
                        registracija && (ime.isBlank() || nadimak.isBlank()) -> "Upiši ime i nadimak."
                        else -> null
                    }
                    if (greska != null) return@Dugme
                    radnja {
                        if (registracija) {
                            sesija.registracija(email, lozinka, ime, prezime, nadimak)
                            idi(KorakPrijave.Kod(email.trim().lowercase(), oporavak = false)); ponovoZa = CEKANJE_PONOVO_S
                        } else runCatching { sesija.prijava(email, lozinka) }.onFailure {
                            // Nepotvrđen nalog: odmah na unos koda, uz novi kod.
                            if (it.message?.startsWith("Potvrdi email") == true) {
                                runCatching { sesija.posaljiKodPonovo(email) }
                                idi(KorakPrijave.Kod(email.trim().lowercase(), oporavak = false)); ponovoZa = CEKANJE_PONOVO_S
                            } else throw it
                        }
                    }
                }
                if (!registracija) Text("Zaboravio si lozinku?", style = tekst(15.sp, FontWeight.Bold, Boje.teal),
                    modifier = Modifier.clickable(role = Role.Button) { idi(KorakPrijave.Zaboravljena) }.padding(vertical = 6.dp))
                // Google (vlasnik 04.11: na Androidu samo Google, bez Apple); radnja je ikonica, natpis je u pristupačnosti.
                val kontekst = androidx.compose.ui.platform.LocalContext.current
                Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                    Box(Modifier.size(56.dp).background(Color.White, CircleShape).border(1.5.dp, Boje.kremTamnija, CircleShape)
                        .clickable(enabled = !radi, role = Role.Button) {
                            radnja {
                                val (idToken, nonce) = club.librum.kviz.servisi.GooglePrijava.token(kontekst) ?: return@radnja
                                sesija.prijavaGoogle(idToken, nonce)
                            }
                        }.semantics { contentDescription = "Prijava preko Google naloga" },
                        contentAlignment = Alignment.Center) {
                        Text("G", style = tekst(26.sp, FontWeight.Bold, Color(0xFF4285F4)))
                    }
                }
                Text("Preko Google naloga prihvataš uslove korišćenja i politiku privatnosti.", style = tekst(12.sp, boja = Boje.sivaTekst),
                    modifier = Modifier.fillMaxWidth(), textAlign = androidx.compose.ui.text.style.TextAlign.Center)
            }
            KorakPrijave.Zaboravljena -> {
                Text("Upiši email naloga. Poslaćemo ti kod od $DUZINA_KODA cifara za novu lozinku.", style = tekst(15.sp, boja = Boje.sivaTekst))
                Polje("Email", email, KeyboardType.Email) { email = it }
                greska?.let { Text(it, style = tekst(14.sp, FontWeight.SemiBold, Boje.crvena)) }
                Dugme(if (radi) "Šaljem…" else "Pošalji kod", omoguceno = !radi) {
                    if (!ispravanEmail()) { greska = "Hmm, ovaj email ne izgleda ispravno."; return@Dugme }
                    radnja { sesija.zaboravljenaLozinka(email); idi(KorakPrijave.Kod(email.trim().lowercase(), oporavak = true)); ponovoZa = CEKANJE_PONOVO_S }
                }
                Text("Setio si se? Prijavi se", style = tekst(15.sp, FontWeight.Bold, Boje.mastilo),
                    modifier = Modifier.clickable(role = Role.Button) { idi(KorakPrijave.Prijava) }.padding(vertical = 6.dp))
            }
            is KorakPrijave.Kod -> {
                Text(if (k.oporavak) "Ako postoji nalog za ${k.email}, stigao je kod od $DUZINA_KODA cifara. Upiši ga i novu lozinku. Proveri i neželjenu poštu."
                    else "Poslali smo kod od $DUZINA_KODA cifara na ${k.email}. Možeš i da dodirneš link u mejlu, pa se prijaviš.",
                    style = tekst(15.sp, boja = Boje.sivaTekst))
                Polje("Kod iz mejla", kod, KeyboardType.Number) { kod = it.filter(Char::isDigit).take(NAJDUZI_KOD) }
                if (k.oporavak) {
                    Polje("Nova lozinka", lozinka, KeyboardType.Password, sakriveno = true) { lozinka = it }
                    Polje("Ponovi lozinku", lozinka2, KeyboardType.Password, sakriveno = true) { lozinka2 = it }
                }
                greska?.let { Text(it, style = tekst(14.sp, FontWeight.SemiBold, Boje.crvena)) }
                obavestenje?.let { Text(it, style = tekst(14.sp, FontWeight.SemiBold, Boje.teal)) }
                Dugme(if (radi) "Proveravam…" else if (k.oporavak) "Sačuvaj lozinku" else "Potvrdi",
                    omoguceno = !radi && kod.length >= DUZINA_KODA && pokusaja < NAJVISE_POKUSAJA) {
                    if (k.oporavak) {
                        greska = when {
                            lozinka.length < 6 -> "Lozinka mora imati najmanje 6 karaktera."
                            lozinka != lozinka2 -> "Lozinke se ne poklapaju."
                            else -> null
                        }
                        if (greska != null) return@Dugme
                    }
                    pokusaja += 1
                    radnja {
                        runCatching { if (k.oporavak) sesija.oporaviLozinku(k.email, kod, lozinka) else sesija.potvrdiKod(k.email, kod, false) }
                            .onFailure {
                                throw Greska(if (pokusaja >= NAJVISE_POKUSAJA) "Previše pokušaja. Zatraži novi kod."
                                    else "${it.message} Ostalo pokušaja: ${NAJVISE_POKUSAJA - pokusaja}.")
                            }
                    }
                }
                if (ponovoZa > 0) Text("Nije stigao? Ponovo za 0:${"%02d".format(ponovoZa)}", style = tekst(14.sp, boja = Boje.sivaTekst))
                else Text("Pošalji kod ponovo", style = tekst(15.sp, FontWeight.Bold, Boje.teal),
                    modifier = Modifier.clickable(role = Role.Button) {
                        radnja {
                            if (k.oporavak) sesija.zaboravljenaLozinka(k.email) else sesija.posaljiKodPonovo(k.email)
                            kod = ""; pokusaja = 0; ponovoZa = CEKANJE_PONOVO_S; obavestenje = "Novi kod je poslat."
                        }
                    }.padding(vertical = 6.dp))
                Text("Pogrešan email? Promeni ga", style = tekst(15.sp, FontWeight.Bold, Boje.mastilo),
                    modifier = Modifier.clickable(role = Role.Button) { idi(if (k.oporavak) KorakPrijave.Zaboravljena else KorakPrijave.Registracija) }.padding(vertical = 6.dp))
            }
        }
    }
}

@Composable
private fun Polje(naziv: String, vrednost: String, tastatura: KeyboardType = KeyboardType.Text, sakriveno: Boolean = false, promena: (String) -> Unit) {
    OutlinedTextField(
        vrednost, promena,
        modifier = Modifier.fillMaxWidth(),
        label = { Text(naziv, style = tekst(14.sp, boja = Boje.sivaTekst)) },
        textStyle = tekst(16.sp),
        singleLine = true,
        visualTransformation = if (sakriveno) PasswordVisualTransformation() else androidx.compose.ui.text.input.VisualTransformation.None,
        keyboardOptions = KeyboardOptions(keyboardType = tastatura),
        shape = RoundedCornerShape(16.dp),
        colors = OutlinedTextFieldDefaults.colors(
            focusedBorderColor = Boje.mastilo, unfocusedBorderColor = Boje.kremTamnija, cursorColor = Boje.mastilo,
            focusedContainerColor = Boje.kartica, unfocusedContainerColor = Boje.kartica,
        ),
    )
}

/** Vlasnik 03.11: na ulazu piše koliko je pitanja u igri, uživo (isti RPC kao iOS); petlja staje kad početna nestane. */
@Composable
private fun PitanjaUIgri() {
    var broj by remember { mutableStateOf<Int?>(null) }
    LaunchedEffect(Unit) {
        while (true) {
            runCatching {
                val o = Supabase.json.parseToJsonElement(Supabase.rpc("pitanja_u_igri")).jsonObject
                broj = listOf("kviz", "knjige", "kafana").sumOf { o[it]?.jsonPrimitive?.intOrNull ?: 0 }
            }
            kotlinx.coroutines.delay(OSVEZAVANJE_PITANJA_MS)
        }
    }
    val b = broj ?: return
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Box(Modifier.size(7.dp).background(Boje.teal, CircleShape))
        Text("${java.text.NumberFormat.getIntegerInstance(java.util.Locale.forLanguageTag("sr-Latn")).format(b)} pitanja u igri", style = tekst(13.sp, FontWeight.Bold, Boje.sivaTekst))
    }
}

private const val OSVEZAVANJE_PITANJA_MS = 30_000L

/** Prvi ulaz preko Google naloga (kao iOS DopunaProfila): ime, prezime, nadimak i grad su obavezni pre igre. */
@Composable
fun DopunaProfila(sesija: Sesija) {
    val opseg = rememberCoroutineScope()
    var ime by remember { mutableStateOf("") }
    var prezime by remember { mutableStateOf("") }
    var nadimak by remember { mutableStateOf("") }
    var grad by remember { mutableStateOf("") }
    var radi by remember { mutableStateOf(false) }
    var greska by remember { mutableStateOf<String?>(null) }
    // Ime i prezime iz Google naloga (okidač handle_new_user ih upisuje u profil).
    LaunchedEffect(Unit) {
        runCatching { sesija.licniPodaci() }.onSuccess { l ->
            ime = l.first_name.orEmpty(); prezime = l.last_name.orEmpty(); grad = l.city.orEmpty()
        }
    }
    Box(Modifier.fillMaxSize()) {
        Papir()
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Spacer(Modifier.height(24.dp))
            Row(verticalAlignment = Alignment.Bottom) {
                Text("Još malo\no tebi", style = naslov(36.sp).copy(lineHeight = 38.sp), modifier = Modifier.weight(1f))
                MaskotaSlika(Maskota.MIMI, 80.dp)
            }
            Text("Nadimak vide drugi igrači i rang lista.", style = tekst(15.sp, boja = Boje.sivaTekst))
            Polje("Ime", ime) { ime = it.take(40) }
            Polje("Prezime", prezime) { prezime = it.take(40) }
            Polje("Nadimak", nadimak) { nadimak = it.filter { c -> c.isLetterOrDigit() || c in "._-" }.take(20) }
            Polje("Grad", grad) { grad = it.take(40) }
            greska?.let { Text(it, style = tekst(14.sp, FontWeight.SemiBold, Boje.crvena)) }
            Dugme(if (radi) "Čuvam…" else "Nastavi", omoguceno = !radi) {
                greska = when {
                    ime.isBlank() -> "Upiši ime."
                    prezime.isBlank() -> "Upiši prezime."
                    nadimak.length < 3 -> "Nadimak mora imati bar 3 znaka."
                    grad.isBlank() -> "Upiši grad."
                    else -> null
                }
                if (greska != null) return@Dugme
                radi = true
                opseg.launch {
                    runCatching { sesija.dopuniProfil(LicniPodaci(ime.trim(), prezime.trim(), grad.trim()), nadimak.trim()) }
                        .onFailure { greska = it.message }
                    radi = false
                }
            }
            Text("Odjavi se", style = tekst(15.sp, FontWeight.Bold, Boje.sivaTekst),
                modifier = Modifier.clickable(role = Role.Button) { opseg.launch { sesija.odjava() } }.padding(vertical = 6.dp))
        }
    }
}


/** Obaveštenje iz admina (RPC aktivna_obavestenja, /majmun/obavestenja). */
@Serializable data class ObavestenjeAdmina(val id: Long, val naslov: String, val tekst: String)

/** Kartice obaveštenja na početnoj; zatvorena se pamte po id-u na ovom telefonu. Isto kao iOS. */
@Composable
private fun ObavestenjaAdmina() {
    val kontekst = androidx.compose.ui.platform.LocalContext.current
    val prefs = remember { kontekst.getSharedPreferences("obavestenja", android.content.Context.MODE_PRIVATE) }
    var lista by remember { mutableStateOf<List<ObavestenjeAdmina>>(emptyList()) }
    var zatvorena by remember { mutableStateOf(prefs.getStringSet("zatvorena", emptySet())!!.toSet()) }
    LaunchedEffect(Unit) {
        lista = runCatching {
            club.librum.kviz.servisi.Supabase.json.decodeFromString<List<ObavestenjeAdmina>>(
                club.librum.kviz.servisi.Supabase.rpc("aktivna_obavestenja", mapOf("p_platforma" to "android"), null))
        }.getOrDefault(emptyList())
    }
    lista.filter { it.id.toString() !in zatvorena }.forEach { o ->
        Row(Modifier.fillMaxWidth().background(Boje.kartica, RoundedCornerShape(20.dp)).border(1.5.dp, Boje.kremTamnija, RoundedCornerShape(20.dp)).padding(14.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Box(Modifier.size(40.dp).background(Boje.zuta, RoundedCornerShape(12.dp)), contentAlignment = Alignment.Center) {
                Icon(androidx.compose.material.icons.Icons.Rounded.Campaign, null, tint = Boje.tinta)
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(o.naslov, style = tekst(16.sp, FontWeight.Bold))
                Text(o.tekst, style = tekst(14.sp, boja = Boje.sivaTekst))
            }
            Icon(androidx.compose.material.icons.Icons.Rounded.Close, contentDescription = "Zatvori obaveštenje", tint = Boje.sivaTekst,
                modifier = Modifier.size(32.dp).clickable {
                    zatvorena = zatvorena + o.id.toString()
                    prefs.edit().putStringSet("zatvorena", zatvorena).apply()
                }.padding(6.dp))
        }
    }
}
