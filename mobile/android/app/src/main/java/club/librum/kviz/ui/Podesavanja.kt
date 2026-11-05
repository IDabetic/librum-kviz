package club.librum.kviz.ui

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.HorizontalDivider
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
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import club.librum.kviz.BuildConfig
import club.librum.kviz.karijera.KNazad
import club.librum.kviz.karijera.KPrekidac
import club.librum.kviz.karijera.KRed
import club.librum.kviz.karijera.KSkelet
import club.librum.kviz.karijera.KarijeraPodesavanja
import club.librum.kviz.servisi.LicniPodaci
import club.librum.kviz.servisi.Napredak
import club.librum.kviz.servisi.Podsetnik
import club.librum.kviz.servisi.Sesija
import club.librum.kviz.servisi.Supabase
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable

/** Okvir podešavanja: papir, nazad, naslov i skrolovanje. */
@Composable
private fun OkvirP(naslovE: String?, nazad: () -> Unit, sadrzaj: @Composable () -> Unit) {
    Box(Modifier.fillMaxSize()) {
        Papir()
        Column(Modifier.fillMaxSize().statusBarsPadding().imePadding().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            KNazad { nazad() }
            naslovE?.let { Text(it, style = naslov(36.sp)) }
            sadrzaj()
            Spacer(Modifier.height(60.dp))
        }
    }
}

@Composable
private fun RedPrekidac(naziv: String, opis: String? = null, ukljuceno: Boolean, promeni: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 58.dp).padding(horizontal = 16.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(naziv, style = tekst(15.sp, FontWeight.SemiBold))
            opis?.let { Text(it, style = tekst(12.sp, boja = Boje.sivaTekst)) }
        }
        KPrekidac(ukljuceno, naziv, promeni)
    }
}

/** Podešavanja (prenos iOS PodesavanjaView): nalog, igra, Karijera, podrška, odjava i brisanje naloga. */
@Composable
fun PodesavanjaEkran(sesija: Sesija, idi: (String) -> Unit, nazad: () -> Unit) {
    val nalog by sesija.nalog.collectAsState()
    val k = LocalContext.current
    val napredak = Napredak.deljeni
    var zvuk by remember { mutableStateOf(napredak.s.zvuk) }
    var podsetnik by remember { mutableStateOf(napredak.s.podsetnik) }
    var tema by remember { mutableStateOf(napredak.s.tema) }
    var odjava by remember { mutableStateOf(false) }
    var brisanje by remember { mutableStateOf(false) }
    var greska by remember { mutableStateOf<String?>(null) }
    val opseg = rememberCoroutineScope()
    val dozvola = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { da ->
        if (!da) { podsetnik = false; napredak.podesi { this.podsetnik = false }; greska = "Obaveštenja su isključena u podešavanjima telefona." }
        Podsetnik.zakazi(k, podsetnik)
    }
    OkvirP("Podešavanja", nazad) {
        Oznaka("NALOG")
        Column(Modifier.fillMaxWidth().mirna()) {
            val n = nalog
            if (n != null) {
                KRed("Izmeni profil") { idi("izmena-profila") }
                HorizontalDivider(color = Boje.kremTamnija)
                KRed("Izaberi avatar") { idi("izmena-profila") }
                HorizontalDivider(color = Boje.kremTamnija)
                Row(Modifier.fillMaxWidth().padding(16.dp)) { Text("Email", style = tekst(15.sp, FontWeight.SemiBold), modifier = Modifier.weight(1f)); Text(n.email.orEmpty(), style = tekst(14.sp, boja = Boje.sivaTekst)) }
                HorizontalDivider(color = Boje.kremTamnija)
                KRed("Lozinka", "Promeni") {
                    opseg.launch { runCatching { n.email?.let { sesija.zaboravljenaLozinka(it) } }.onSuccess { greska = "Poslali smo ti mejl za promenu lozinke." }.onFailure { greska = it.message } }
                }
            } else KRed("Prijava ili nov nalog") { idi("profil") }
        }
        Oznaka("IGRA")
        Column(Modifier.fillMaxWidth().mirna()) {
            RedPrekidac("Zvučni efekti", ukljuceno = zvuk) { zvuk = it; napredak.podesi { this.zvuk = it } }
            HorizontalDivider(color = Boje.kremTamnija)
            RedPrekidac("Dnevni podsetnik u 19:30", ukljuceno = podsetnik) { v ->
                podsetnik = v; napredak.podesi { this.podsetnik = v }
                if (v && Build.VERSION.SDK_INT >= 33) dozvola.launch(Manifest.permission.POST_NOTIFICATIONS) else Podsetnik.zakazi(k, v)
            }
            HorizontalDivider(color = Boje.kremTamnija)
            Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("Izgled", style = tekst(15.sp, FontWeight.SemiBold))
                Podvuceno(listOf("sistem" to "Auto", "svetla" to "Svetla", "tamna" to "Tamna"), tema) { tema = it; Boje.tema = it; napredak.podesi { this.tema = it } }
            }
        }
        if (nalog != null) { Oznaka("KARIJERA"); KarijeraPodesavanja() }
        greska?.let { Text(it, style = tekst(14.sp, FontWeight.SemiBold, Boje.sivaTekst)) }
        Oznaka("PODRŠKA")
        Column(Modifier.fillMaxWidth().mirna()) {
            KRed("Pomoć i utisci") { runCatching { k.startActivity(Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:info@librum.club?subject=Librum%20kviz"))) } }
            HorizontalDivider(color = Boje.kremTamnija)
            KRed("Pošalji pitanje") { idi("dodaj/pro") }
            if (nalog != null) { HorizontalDivider(color = Boje.kremTamnija); KRed("Blokirani igrači") { idi("blokirani") } }
            HorizontalDivider(color = Boje.kremTamnija)
            KRed("Pravila igara") { idi("pravila") }
            HorizontalDivider(color = Boje.kremTamnija)
            KRed("Politika privatnosti") { idi("pravno/privatnost") }
            HorizontalDivider(color = Boje.kremTamnija)
            KRed("Uslovi korišćenja") { idi("pravno/uslovi") }
            HorizontalDivider(color = Boje.kremTamnija)
            KRed("Licence i izvori") { idi("pravno/licence") }
        }
        if (nalog != null) Column(Modifier.fillMaxWidth().mirna().padding(top = 8.dp)) { KRed("Odjavi se", boja = Boje.crvena) { odjava = true } }
        Row(Modifier.fillMaxWidth().padding(top = 10.dp), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
            Text("Librum kviz ${BuildConfig.VERSION_NAME}", style = tekst(12.sp, boja = Boje.sivaTekst))
            if (nalog != null) Text("  ·  Obriši nalog", style = tekst(12.sp, FontWeight.Bold, Boje.crvena), modifier = Modifier.clickable(role = Role.Button) { brisanje = true }.padding(8.dp))
        }
    }
    if (odjava) Dijalog("Odjaviti se?", "Niz i napredak ostaju na ovom telefonu. Prijavi se ponovo kad hoćeš.", "Odjavi se", "Ostani",
        potvrdi = { odjava = false; opseg.launch { sesija.odjava(); nazad() } }, zatvori = { odjava = false })
    if (brisanje) Dijalog("Obrisati nalog?", "Nalog, profil i svi rezultati na serveru se trajno brišu, zajedno sa napretkom na ovom telefonu. Ovo ne može da se vrati.", "Obriši zauvek", "Odustani",
        potvrdi = { brisanje = false; opseg.launch { runCatching { sesija.obrisiNalog() }.onSuccess { nazad() }.onFailure { greska = it.message } } }, zatvori = { brisanje = false })
}

/** Uredi profil (prenos iOS IzmenaProfilaView): avatar (24, pa svi), drugar u igri, nadimak, ime, prezime, grad, O meni. */
@Composable
fun IzmenaProfilaEkran(sesija: Sesija, nazad: () -> Unit) {
    val nalog by sesija.nalog.collectAsState()
    val k = LocalContext.current
    val napredak = Napredak.deljeni
    val svi = remember { sviAvatari(k) }
    var sviVidljivi by remember { mutableStateOf(false) }
    var avatar by remember { mutableStateOf(nalog?.avatar ?: napredak.s.avatar) }
    var maskota by remember { mutableStateOf(runCatching { Maskota.valueOf(napredak.s.maskota) }.getOrDefault(Maskota.MIMI)) }
    var nadimak by remember { mutableStateOf(nalog?.nadimak.orEmpty()) }
    var licni by remember { mutableStateOf(LicniPodaci()) }
    var pocetni by remember { mutableStateOf(LicniPodaci()) }
    var stanje by remember { mutableStateOf<String?>(null) }
    var cuva by remember { mutableStateOf(false) }
    var odbaci by remember { mutableStateOf(false) }
    val opseg = rememberCoroutineScope()
    LaunchedEffect(nalog?.id) { if (nalog != null) runCatching { sesija.licniPodaci() }.onSuccess { licni = it; pocetni = it } }
    val izmenjeno = (nalog != null && nadimak != nalog?.nadimak.orEmpty()) || maskota.name != napredak.s.maskota || avatar != (nalog?.avatar ?: napredak.s.avatar) || licni != pocetni
    val ispravanNadimak = Regex("^[\\p{L}0-9.\\-]{3,20}$").matches(nadimak)
    val bio = licni.bio.orEmpty()
    OkvirP(null, { if (izmenjeno && stanje != "Sačuvano.") odbaci = true else nazad() }) {
        Text("Uredi profil", style = naslov(26.sp))
        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
            AvatarSlika(avatar, 120.dp, maskota)
            Text("Avatar", style = tekst(13.sp, FontWeight.SemiBold, Boje.sivaTekst))
            (if (sviVidljivi) svi else svi.take(24)).chunked(6).forEach { red ->
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    red.forEach { a ->
                        Box(Modifier.weight(1f).border(if (avatar == a) 4.dp else 0.dp, if (avatar == a) Boje.teal else Boje.krem, CircleShape)
                            .semantics { contentDescription = "Avatar $a"; selected = avatar == a }.clickable(role = Role.RadioButton) { avatar = a }, contentAlignment = Alignment.Center) { AvatarSlika(a, 48.dp) }
                    }
                    repeat(6 - red.size) { Spacer(Modifier.weight(1f)) }
                }
            }
            if (!sviVidljivi && svi.size > 24) Text("Prikaži svih ${svi.size}", style = tekst(14.sp, FontWeight.Bold, Boje.teal), modifier = Modifier.clickable(role = Role.Button) { sviVidljivi = true }.padding(8.dp))
            Text("Drugar koji navija u igri", style = tekst(13.sp, FontWeight.SemiBold, Boje.sivaTekst))
            Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                Maskota.entries.forEach { m ->
                    Box(Modifier.size(56.dp).background(Boje.kartica, CircleShape).border(if (maskota == m) 3.dp else 1.5.dp, if (maskota == m) Boje.teal else Boje.kremTamnija, CircleShape)
                        .semantics { contentDescription = m.name; selected = maskota == m }.clickable(role = Role.RadioButton) { maskota = m }, contentAlignment = Alignment.Center) { MaskotaSlika(m, 46.dp) }
                }
            }
        }
        if (nalog != null) {
            Polje("Nadimak", nadimak) { nadimak = it.take(20); stanje = null }
            if (nadimak.isNotEmpty() && !ispravanNadimak) Text("3–20 slova, cifara, tačka ili crtica.", style = tekst(12.sp, boja = Boje.crvena))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(Modifier.weight(1f)) { Polje("Ime", licni.first_name.orEmpty()) { licni = licni.copy(first_name = it) } }
                Box(Modifier.weight(1f)) { Polje("Prezime", licni.last_name.orEmpty()) { licni = licni.copy(last_name = it) } }
            }
            Polje("Grad", licni.city.orEmpty()) { licni = licni.copy(city = it) }
            Polje("O meni", bio, visina = 110) { licni = licni.copy(bio = it) }
            Text("${bio.length} / 160", style = tekst(12.sp, boja = if (bio.length > 160) Boje.crvena else Boje.sivaTekst))
            Polje("Email", nalog?.email.orEmpty(), omoguceno = false) {}
            Text("Email se menja preko podrške, da nalog ostane bezbedan.", style = tekst(12.sp, boja = Boje.sivaTekst))
        } else Text("Bez naloga avatar ostaje na ovom telefonu. Sa nalogom ga vide i drugi igrači.", style = tekst(13.sp, boja = Boje.sivaTekst))
        stanje?.let { Text(it, style = tekst(14.sp, FontWeight.SemiBold, if (it == "Sačuvano.") Boje.teal else Boje.crvena)) }
        Dugme(if (cuva) "Čuvam…" else if (stanje == "Sačuvano.") "Sačuvano" else "Sačuvaj", omoguceno = izmenjeno && !cuva) {
            opseg.launch {
                cuva = true
                runCatching {
                    napredak.podesi { this.maskota = maskota.name; this.avatar = avatar }
                    val a = avatar
                    if (nalog != null && a != null && a != nalog?.avatar) sesija.sacuvajAvatar(a)
                    if (nalog != null && licni != pocetni) {
                        require(bio.length <= 160) { "„O meni” može da ima najviše 160 znakova." }
                        sesija.sacuvajLicnePodatke(licni); pocetni = licni
                    }
                    if (nalog != null && nadimak != nalog?.nadimak.orEmpty()) { require(ispravanNadimak) { "Nadimak: 3–20 slova, cifara, tačka ili crtica." }; sesija.sacuvajNadimak(nadimak) }
                }.onSuccess { stanje = "Sačuvano." }.onFailure { stanje = it.message }
                cuva = false
            }
        }
    }
    if (odbaci) Dijalog("Odbaciti izmene?", "Izmene koje nisi sačuvao će nestati.", "Odbaci", "Nastavi izmenu", potvrdi = { odbaci = false; nazad() }, zatvori = { odbaci = false })
}

@Composable
private fun Polje(naziv: String, vrednost: String, visina: Int = 0, omoguceno: Boolean = true, promeni: (String) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(naziv, style = tekst(14.sp, FontWeight.SemiBold))
        BasicTextField(vrednost, promeni, enabled = omoguceno, singleLine = visina == 0, textStyle = tekst(16.sp, boja = if (omoguceno) Boje.mastilo else Boje.sivaTekst), cursorBrush = SolidColor(Boje.mastilo),
            modifier = Modifier.fillMaxWidth().heightIn(min = if (visina > 0) visina.dp else 0.dp).background(Boje.kartica, RoundedCornerShape(14.dp))
                .border(1.5.dp, Boje.kremTamnija, RoundedCornerShape(14.dp)).padding(14.dp))
    }
}

@Serializable private data class Blokiran(val id: String, val nadimak: String, val avatar: String? = null)

/** Blokirani igrači (prenos iOS BlokiraniView): spisak sa „Odblokiraj”. */
@Composable
fun BlokiraniEkran(sesija: Sesija, nazad: () -> Unit) {
    var lista by remember { mutableStateOf<List<Blokiran>?>(null) }
    var greska by remember { mutableStateOf<String?>(null) }
    val opseg = rememberCoroutineScope()
    suspend fun ucitaj() { runCatching { Supabase.json.decodeFromString<List<Blokiran>>(Supabase.rpc("moje_blokade", emptyMap(), sesija.vazeciToken())) }.onSuccess { lista = it }.onFailure { greska = it.message } }
    LaunchedEffect(Unit) { ucitaj() }
    OkvirP("Blokirani", nazad) {
        Text("Blokirani igrači ne vide tvoje objave, komentare i profil, i ne mogu da ti pišu.", style = tekst(14.sp, boja = Boje.sivaTekst))
        val l = lista
        when {
            greska != null && l == null -> Text(greska!!, style = tekst(14.sp, boja = Boje.crvena))
            l == null -> repeat(3) { KSkelet(56.dp) }
            l.isEmpty() -> Text("Nikog nisi blokirao. Blokiraš iz menija objave ili sa profila igrača.", style = tekst(15.sp))
            else -> Column(Modifier.fillMaxWidth().mirna()) {
                l.forEachIndexed { i, r ->
                    Row(Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        AvatarSlika(r.avatar, 44.dp)
                        Text(r.nadimak, style = tekst(16.sp, FontWeight.SemiBold), modifier = Modifier.weight(1f))
                        Text("Odblokiraj", style = tekst(14.sp, FontWeight.Bold), modifier = Modifier.border(1.5.dp, Boje.mastilo, RoundedCornerShape(10.dp))
                            .clickable(role = Role.Button) { opseg.launch { if (club.librum.kviz.zajednica.Zajednica.radnja(sesija, "blokiraj", mapOf("p_id" to r.id, "p_da" to false))) ucitaj() } }
                            .padding(horizontal = 14.dp, vertical = 8.dp))
                    }
                    if (i < l.size - 1) HorizontalDivider(color = Boje.kremTamnija)
                }
            }
        }
    }
}
