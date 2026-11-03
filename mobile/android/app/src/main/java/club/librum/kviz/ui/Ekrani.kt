package club.librum.kviz.ui

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.horizontalScroll
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
import kotlinx.serialization.Serializable
import java.time.Instant
import java.time.temporal.ChronoUnit

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
                }
                MaskotaSlika(Maskota.BLOOP, 92.dp)
            }
            // Vlasnik 03.11: Osvajanje sveta je jedna velika kartica, ispod šest igara u dva reda po tri.
            KarticaIgre("Osvajanje sveta", "171 država, vojske i bitke znanja protiv rivala.", Boje.teal, Color.White, Maskota.MIMI, true) { idi("osvajanje") }
            listOf(
                listOf(Triple("PRO kviz", "pro", Boje.ljubicasta to Maskota.LUMI), Triple("Book kviz", "book", Color(0xFFF4A33C) to Maskota.ZIG), Triple("Duel", "duel", Boje.mastilo to Maskota.BLOOP)),
                listOf(Triple("Slikari", "tema/slikari", Boje.roze to Maskota.LUMI), Triple("Brzi kviz", "brzi", Boje.zuta to Maskota.ZIG), Triple("Vešanje", "vesanje", Color(0xFF6EC3F2) to Maskota.MIMI)),
            ).forEach { red ->
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    red.forEach { (naziv, ruta, bm) -> MalaIgra(naziv, bm.first, bm.second, Modifier.weight(1f)) { idi(ruta) } }
                }
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
private fun MalaIgra(naslovIgre: String, boja: Color, maskota: Maskota, modifier: Modifier = Modifier, radnja: () -> Unit) {
    val tekstBoja = if (boja == Boje.ljubicasta || boja == Boje.mastilo || boja == Boje.teal) Color.White else Boje.tinta
    Column(
        modifier.height(128.dp).pop(boja).clickable(role = Role.Button, onClick = radnja).padding(8.dp)
            .semantics(mergeDescendants = true) {},
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center,
    ) {
        MaskotaSlika(maskota, 60.dp)
        Text(naslovIgre, style = naslov(15.sp).copy(color = tekstBoja, textAlign = androidx.compose.ui.text.style.TextAlign.Center, lineHeight = 16.sp), maxLines = 2)
    }
}

@Composable
private fun KarticaIgre(naslovIgre: String, opis: String, boja: Color, bojaTeksta: Color, maskota: Maskota, velika: Boolean, modifier: Modifier = Modifier, radnja: () -> Unit) {
    Box(
        modifier.fillMaxWidth().height(if (velika) 250.dp else 160.dp).pop(boja).clip(RoundedCornerShape(24.dp))
            .clickable(role = Role.Button, onClick = radnja),
    ) {
        Box(Modifier.align(Alignment.TopEnd).offset(x = 40.dp, y = (-30).dp).size(if (velika) 230.dp else 150.dp).alpha(0.22f).background(Boje.kartica, CircleShape))
        MaskotaSlika(maskota, if (velika) 160.dp else 84.dp, Modifier.align(Alignment.TopEnd).offset(y = if (velika) 4.dp else (-6).dp))
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

private val IGRE_LISTE = listOf("dnevni" to "Dnevni", "osvajanje" to "Osvajanje", "pro" to "PRO", "book" to "Book", "duel" to "Duel", "brzi" to "Brzi", "vesanje" to "Vešanje")
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

    LaunchedEffect(igra, period, krug, pokusaj, nalog?.id) {
        greska = null; redovi = null
        runCatching {
            Supabase.json.decodeFromString<List<RedListe>>(Supabase.rpc("rang_lista_igre", mapOf(
                "p_igra" to IGRE_LISTE[igra].first, "p_period" to PERIODI[period].first, "p_broj" to 50, "p_krug" to if (krug == 1) "pratim" else "svi",
            ), runCatching { sesija.vazeciToken() }.getOrNull()))
        }.onSuccess { redovi = it }.onFailure { greska = it.message }
    }

    Box(Modifier.fillMaxSize()) {
        Papir()
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Spacer(Modifier.height(20.dp))
            Text("Rang lista", style = naslov(40.sp))
            Row(Modifier.horizontalScroll(rememberScrollState())) { Izbor(IGRE_LISTE.map { it.second }, igra) { igra = it } }
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

/** Profil: prijava i registracija, ili nalog sa odjavom i brisanjem. */
@Composable
fun Profil(sesija: Sesija, idi: (String) -> Unit = {}) {
    val nalog by sesija.nalog.collectAsState()
    var mojProfil by remember { mutableStateOf<club.librum.kviz.zajednica.ProfilIgraca?>(null) }
    LaunchedEffect(nalog?.id) { mojProfil = nalog?.id?.let { id -> runCatching { club.librum.kviz.zajednica.Drustvo.profil(sesija, id) }.getOrNull() } }
    val kontekst = LocalContext.current
    val opseg = rememberCoroutineScope()
    var potvrdaBrisanja by remember { mutableStateOf(false) }
    var greska by remember { mutableStateOf<String?>(null) }

    Box(Modifier.fillMaxSize()) {
        Papir()
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Spacer(Modifier.height(36.dp))
            val n = nalog
            if (n != null) {
                val mp = mojProfil
                if (mp != null) {
                    club.librum.kviz.zajednica.ProfilZaglavlje(mp) {
                        // Samo na mom profilu; drugi vide „Poslao N pitanja · M u igri”.
                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            Dugme("Dodaj pitanje", Modifier.weight(1f), VrstaDugmeta.ZUTO) { idi("dodaj/pro") }
                            Dugme("Dodaj reč", Modifier.weight(1f), VrstaDugmeta.SEKUNDARNO) { idi("dodaj/vesanje") }
                        }
                    }
                    val nova by club.librum.kviz.zajednica.Brojaci.obavestenja.collectAsState()
                    Row(Modifier.fillMaxWidth().mirna().clickable { idi("sanduce") }.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text("Sanduče", style = tekst(16.sp, FontWeight.SemiBold), modifier = Modifier.weight(1f))
                        if (nova > 0) Text("$nova novo", style = tekst(14.sp, FontWeight.Bold, Boje.roze))
                    }
                    club.librum.kviz.zajednica.ProfilStatistike(mp)
                }
                Column(Modifier.fillMaxWidth().pop().padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    if (mp == null) Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                        Box(Modifier.size(84.dp).background(Boje.teal, CircleShape).border(2.5.dp, Boje.mastilo, CircleShape), contentAlignment = Alignment.Center) {
                            MaskotaSlika(Maskota.BLOOP, 70.dp)
                        }
                        Column {
                            Text(n.nadimak ?: "Igrač", style = naslov(28.sp))
                            Text(n.email.orEmpty(), style = tekst(14.sp, boja = Boje.sivaTekst))
                        }
                    } else Text(n.email.orEmpty(), style = tekst(14.sp, boja = Boje.sivaTekst))
                    greska?.let { Text(it, style = tekst(14.sp, FontWeight.SemiBold, Boje.crvena)) }
                    Dugme("Odjavi se", vrsta = VrstaDugmeta.SEKUNDARNO) { opseg.launch { sesija.odjava() } }
                    Text("Obriši nalog", style = tekst(15.sp, FontWeight.Bold, Boje.crvena),
                        modifier = Modifier.fillMaxWidth().clickable(role = Role.Button) { potvrdaBrisanja = true }.padding(14.dp))
                }
            } else {
                PrijavaForma(sesija)
            }
            Column(Modifier.fillMaxWidth().mirna()) {
                listOf(
                    "Pravila igara" to "pravila",
                    "Pošalji pitanje za kviz" to "dodaj/pro",
                    "Politika privatnosti" to "pravno/privatnost",
                    "Uslovi korišćenja" to "pravno/uslovi",
                ).forEachIndexed { i, (naziv, ruta) ->
                    Row(
                        Modifier.fillMaxWidth().clickable(role = Role.Button) { idi(ruta) }.padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(naziv, style = tekst(15.sp, FontWeight.SemiBold), modifier = Modifier.weight(1f))
                        Text("›", style = tekst(20.sp, FontWeight.Bold, Boje.sivaTekst))
                    }
                    if (i < 3) HorizontalDivider(color = Boje.kremTamnija)
                }
            }
            Text("Librum kviz ${BuildConfig.VERSION_NAME}", style = tekst(12.sp, boja = Boje.sivaTekst), modifier = Modifier.align(Alignment.CenterHorizontally))
            Spacer(Modifier.height(80.dp))
        }
        if (potvrdaBrisanja) Dijalog(
            "Obrisati nalog?", "Nalog, profil i svi rezultati se trajno brišu. Ovo ne može da se vrati.", "Obriši", "Odustani",
            potvrdi = {
                potvrdaBrisanja = false
                opseg.launch { runCatching { sesija.obrisiNalog() }.onFailure { greska = it.message } }
            },
            zatvori = { potvrdaBrisanja = false },
        )
    }
}

@Composable
private fun PrijavaForma(sesija: Sesija) {
    val opseg = rememberCoroutineScope()
    var registracija by remember { mutableStateOf(false) }
    var email by remember { mutableStateOf("") }
    var lozinka by remember { mutableStateOf("") }
    var ime by remember { mutableStateOf("") }
    var prezime by remember { mutableStateOf("") }
    var nadimak by remember { mutableStateOf("") }
    var radi by remember { mutableStateOf(false) }
    var greska by remember { mutableStateOf<String?>(null) }
    var poslato by remember { mutableStateOf(false) }

    Column(Modifier.fillMaxWidth().pop().padding(20.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Row(verticalAlignment = Alignment.Bottom) {
            Text(if (registracija) "Napravi nalog" else "Prijava", style = naslov(34.sp), modifier = Modifier.weight(1f))
            MaskotaSlika(Maskota.ZIG, 70.dp)
        }
        Text("Nalog služi da rezultati odu na rang listu. Isti nalog važi i na kviz.librum.club.", style = tekst(14.sp, boja = Boje.sivaTekst))
        Izbor(listOf("Prijava", "Registracija"), if (registracija) 1 else 0) { registracija = it == 1; greska = null }
        if (poslato) Text("Poslali smo ti email. Potvrdi adresu preko linka, pa se prijavi.", style = tekst(15.sp, FontWeight.SemiBold),
            modifier = Modifier.fillMaxWidth().pop(Boje.tealSvetla, 16.dp).padding(14.dp))
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
                "@" !in email || "." !in email -> "Upiši ispravan email."
                lozinka.length < 6 -> "Lozinka mora imati najmanje 6 karaktera."
                registracija && (ime.isBlank() || nadimak.isBlank()) -> "Upiši ime i nadimak."
                else -> null
            }
            if (greska != null) return@Dugme
            radi = true
            opseg.launch {
                runCatching {
                    if (registracija) { sesija.registracija(email, lozinka, ime, prezime, nadimak); poslato = true; registracija = false }
                    else sesija.prijava(email, lozinka)
                }.onFailure { greska = it.message }
                radi = false
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
