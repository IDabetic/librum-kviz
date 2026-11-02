package club.librum.kviz.ui

import android.content.Intent
import android.net.Uri
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
            KarticaIgre("Osvajanje sveta", "171 država, vojske i bitke znanja protiv dva rivala.", Boje.teal, Color.White, Maskota.MIMI, true) { idi("osvajanje") }
            Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                KarticaIgre("PRO kviz", "Deset života, rang lista.", Boje.ljubicasta, Color.White, Maskota.LUMI, false, Modifier.weight(1f)) { idi("pro") }
                KarticaIgre("Book kviz", "Pisci, dela, žanrovi.", Color(0xFFF4A33C), Boje.mastilo, Maskota.ZIG, false, Modifier.weight(1f)) { idi("book") }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                KarticaIgre("Duel", "Jedan na jedan.", Boje.mastilo, Color.White, Maskota.BLOOP, false, Modifier.weight(1f)) { idi("duel") }
                KarticaIgre("Vešanje", "Reč slovo po slovo.", Boje.roze, Boje.mastilo, Maskota.LUMI, false, Modifier.weight(1f)) { idi("vesanje") }
            }
            KarticaIgre("Brzi kviz", "Tačno ili netačno, 60 sekundi.", Boje.zuta, Boje.mastilo, Maskota.ZIG, false) { idi("brzi") }
            Spacer(Modifier.height(80.dp))
        }
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
            Text(naslovIgre, style = naslov(if (velika) 36.sp else 24.sp).copy(color = bojaTeksta), maxLines = 1)
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

@Serializable private data class Sesija_(val user_id: String, val score: Int, val questions_reached: Int)
@Serializable private data class Profil_(val id: String, val nickname: String? = null, val first_name: String? = null)
private data class Red(val id: String, val ime: String, val poeni: Int, val pitanja: Int)

/** Najbolji PRO rezultati: ova nedelja ili sve vreme (isti izvor kao veb). */
@Composable
fun RangLista() {
    var period by remember { mutableStateOf(0) }
    var redovi by remember { mutableStateOf<List<Red>?>(null) }
    var greska by remember { mutableStateOf<String?>(null) }
    var pokusaj by remember { mutableStateOf(0) }

    LaunchedEffect(period, pokusaj) {
        greska = null; redovi = null
        runCatching {
            val upit = mutableListOf("select" to "user_id,score,questions_reached", "order" to "score.desc", "limit" to "100")
            if (period == 0) upit += "created_at" to "gte.${Instant.now().minus(7, ChronoUnit.DAYS)}"
            val sesije = Supabase.json.decodeFromString<List<Sesija_>>(Supabase.citaj("survivor_sessions", upit))
            val vidjeno = mutableSetOf<String>()
            val najbolji = sesije.filter { vidjeno.add(it.user_id) }.take(20)
            val imena = if (najbolji.isEmpty()) emptyMap() else Supabase.json.decodeFromString<List<Profil_>>(
                Supabase.citaj("public_profiles", listOf("select" to "id,nickname,first_name", "id" to "in.(${najbolji.joinToString(",") { it.user_id }})")),
            ).associate { it.id to (it.nickname ?: it.first_name ?: "Igrač") }
            najbolji.map { Red(it.user_id, imena[it.user_id] ?: "Igrač", it.score, it.questions_reached) }
        }.onSuccess { redovi = it }.onFailure { greska = it.message }
    }

    Box(Modifier.fillMaxSize()) {
        Papir()
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Spacer(Modifier.height(36.dp))
            Text("Rang lista", style = naslov(40.sp))
            Oznaka("PRO kviz")
            Izbor(listOf("Ova nedelja", "Sve vreme"), period) { period = it }
            val r = redovi
            when {
                greska != null -> Column(Modifier.fillMaxWidth().mirna().padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(greska.orEmpty(), style = tekst(15.sp, boja = Boje.sivaTekst))
                    Dugme("Pokušaj ponovo", vrsta = VrstaDugmeta.SEKUNDARNO) { pokusaj++ }
                }
                r == null -> CircularProgressIndicator(color = Boje.mastilo)
                r.isEmpty() -> Column(Modifier.fillMaxWidth().mirna().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    MaskotaSlika(Maskota.LUMI, 90.dp)
                    Text("Još nema rezultata u ovom periodu. Budi prvi.", style = tekst(15.sp, boja = Boje.sivaTekst))
                }
                else -> Column(Modifier.fillMaxWidth().mirna()) {
                    r.forEachIndexed { i, red ->
                        Row(Modifier.padding(horizontal = 16.dp, vertical = 12.dp).semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                            Box(
                                Modifier.size(36.dp).background(if (i == 0) Boje.zuta else Boje.krem, RoundedCornerShape(11.dp))
                                    .border(2.dp, if (i == 0) Boje.mastilo else Color.Transparent, RoundedCornerShape(11.dp)),
                                contentAlignment = Alignment.Center,
                            ) { Text("${i + 1}", style = tekst(15.sp, FontWeight.Bold)) }
                            Column(Modifier.weight(1f)) {
                                Text(red.ime, style = tekst(16.sp, FontWeight.SemiBold), maxLines = 1)
                                Text("${red.pitanja} pitanja", style = tekst(12.sp, boja = Boje.sivaTekst))
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
fun Profil(sesija: Sesija) {
    val nalog by sesija.nalog.collectAsState()
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
                Column(Modifier.fillMaxWidth().pop().padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                        Box(Modifier.size(84.dp).background(Boje.teal, CircleShape).border(2.5.dp, Boje.mastilo, CircleShape), contentAlignment = Alignment.Center) {
                            MaskotaSlika(Maskota.BLOOP, 70.dp)
                        }
                        Column {
                            Text(n.nadimak ?: "Igrač", style = naslov(28.sp))
                            Text(n.email.orEmpty(), style = tekst(14.sp, boja = Boje.sivaTekst))
                        }
                    }
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
                    "Politika privatnosti" to "https://kviz.librum.club/politika-privatnosti",
                    "Uslovi korišćenja" to "https://kviz.librum.club/uslovi-koriscenja",
                    "Pošalji pitanje za kviz" to "https://kviz.librum.club/dodaj-pitanja",
                ).forEachIndexed { i, (naziv, adresa) ->
                    Row(
                        Modifier.fillMaxWidth().clickable(role = Role.Button) { kontekst.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(adresa))) }.padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(naziv, style = tekst(15.sp, FontWeight.SemiBold), modifier = Modifier.weight(1f))
                        Icon(Icons.AutoMirrored.Rounded.OpenInNew, contentDescription = null, tint = Boje.sivaTekst, modifier = Modifier.size(18.dp))
                    }
                    if (i < 2) HorizontalDivider(color = Boje.kremTamnija)
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
