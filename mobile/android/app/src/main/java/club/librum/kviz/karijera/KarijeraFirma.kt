package club.librum.kviz.karijera

import androidx.compose.ui.graphics.Color
import androidx.compose.material.icons.rounded.Payments
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.RecordVoiceOver
import androidx.compose.material.icons.rounded.CalendarMonth
import androidx.compose.material.icons.rounded.Layers
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.RadioButtonUnchecked
import androidx.compose.foundation.layout.heightIn
import androidx.compose.ui.draw.alpha
import androidx.compose.material.icons.rounded.Download
import androidx.compose.material.icons.rounded.PersonAdd
import androidx.compose.material.icons.rounded.Apartment
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
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import club.librum.kviz.servisi.Zvuk
import club.librum.kviz.ui.Boje
import club.librum.kviz.ui.Dijalog
import club.librum.kviz.ui.DonjiList
import club.librum.kviz.ui.Dugme
import club.librum.kviz.ui.Oznaka
import club.librum.kviz.ui.Papir
import club.librum.kviz.ui.Podvuceno
import club.librum.kviz.ui.VrstaDugmeta
import club.librum.kviz.ui.mirna
import club.librum.kviz.ui.naslov
import club.librum.kviz.ui.pop
import club.librum.kviz.ui.tekst
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** Okvir ekrana Karijere: papir, nazad i skrolovanje. */
@Composable
private fun KOkvir(nazad: () -> Unit, poruka: String? = null, ocisti: () -> Unit = {}, prekrivac: @Composable () -> Unit = {}, sadrzaj: @Composable () -> Unit) {
    Box(Modifier.fillMaxSize()) {
        Papir()
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            KNazad { nazad() }
            sadrzaj()
            Spacer(Modifier.height(40.dp))
        }
        poruka?.let { p ->
            LaunchedEffect(p) { delay(4000); ocisti() }
            Text(p, style = tekst(14.sp, FontWeight.Bold, Boje.naMastilu), modifier = Modifier.align(Alignment.BottomCenter).navigationBarsPadding().padding(16.dp)
                .fillMaxWidth().background(Boje.mastilo, RoundedCornerShape(16.dp)).clickable { ocisti() }.padding(14.dp))
        }
        prekrivac()
    }
}

private enum class List_ { NEMA, BOT, KLJUCNE, IME, PRIJAVA, SEF, PITANJA, SLOBODNI }

/** Firma: svima zgrada, rekord, asistenti, zaposleni; vlasniku i upravljanje (kasa, plata, ključne oblasti, šef, pitanja, slobodni dani…). */
@Composable
fun FirmaEkran(firmaId: String, ja: String?, idi: (KEkran) -> Unit, nazad: () -> Unit) {
    var firma by remember { mutableStateOf<Karijera.FirmaDetalj?>(null) }
    var greska by remember { mutableStateOf<String?>(null) }
    var poruka by remember { mutableStateOf<String?>(null) }
    var list by remember { mutableStateOf(List_.NEMA) }
    var otpusti by remember { mutableStateOf<Karijera.Zaposleni?>(null) }
    var radi by remember { mutableStateOf(false) }
    val opseg = rememberCoroutineScope()
    suspend fun ucitaj() { runCatching { Karijera.firma(firmaId) }.onSuccess { firma = it; greska = null }.onFailure { if (firma == null) greska = it.message else poruka = it.message } }
    fun vlasnik(posao: suspend () -> Karijera.FirmaDetalj) = opseg.launch { radi = true; runCatching { posao() }.onSuccess { firma = it }.onFailure { poruka = it.message }; radi = false }
    LaunchedEffect(firmaId) { ucitaj() }

    KOkvir(nazad, poruka, { poruka = null }, prekrivac = {
        val f = firma ?: return@KOkvir
        when (list) {
            List_.NEMA -> {}
            List_.BOT -> DonjiList({ list = List_.NEMA }) {
                Text("Zaposli asistenta", style = naslov(26.sp))
                Text("1.000 iz kase. Asistent pomaže svima u firmi na 5 pitanja dnevno iz svoje teme.", style = tekst(14.sp, boja = Boje.sivaTekst))
                f.teme.forEach { t -> KRed(t.tema.replaceFirstChar { it.uppercase() }) { list = List_.NEMA; vlasnik { Karijera.zaposliBota(f.id, t.tema) } } }
            }
            List_.KLJUCNE -> {
                var izabrane by remember { mutableStateOf(f.kljucne) }
                DonjiList({ list = List_.NEMA }) {
                    Text("Ključne oblasti", style = naslov(26.sp))
                    Text("Do 3 oblasti u kojima tačan odgovor vredi duplo. Zaposleni jaki u tim oblastima dolaze kod tebe.", style = tekst(14.sp, boja = Boje.sivaTekst))
                    f.teme.map { it.tema }.forEach { t -> Izbornik(t.replaceFirstChar { it.uppercase() }, t in izabrane) { izabrane = if (t in izabrane) izabrane - t else if (izabrane.size < 3) izabrane + t else izabrane } }
                    Dugme("Sačuvaj") { list = List_.NEMA; vlasnik { Karijera.podesi(f.id, null, izabrane) } }
                }
            }
            List_.IME -> {
                var ime by remember { mutableStateOf(f.ime) }
                DonjiList({ list = List_.NEMA }) {
                    Text("Ime firme", style = naslov(26.sp))
                    Polje(ime) { ime = it.take(32) }
                    Text("3 do 32 znaka.", style = tekst(12.sp, boja = Boje.sivaTekst))
                    Dugme("Sačuvaj", omoguceno = ime.trim().length >= 3) { list = List_.NEMA; vlasnik { Karijera.preimenuj(f.id, ime) } }
                }
            }
            List_.PRIJAVA -> Dijalog("Prijavi ime firme?", "Ako ime vređa ili je neprimereno. Posle tri prijave ime se skida, a vlasnik bira novo.", "Prijavi", "Odustani",
                potvrdi = { list = List_.NEMA; opseg.launch { runCatching { Karijera.prijaviIme(f.id) }.onSuccess { poruka = "Hvala, prijava je primljena." }.onFailure { poruka = it.message } } },
                zatvori = { list = List_.NEMA })
            List_.SEF -> SefList(f.sefNivo, { list = List_.NEMA }) { n -> list = List_.NEMA; vlasnik { Karijera.podesiSefa(f.id, n) } }
            List_.PITANJA -> PitanjaFirmeList(f, { list = List_.NEMA }) { s, fo, u, t -> list = List_.NEMA; vlasnik { Karijera.podesiPitanja(f.id, s, fo, u, t) } }
            List_.SLOBODNI -> {
                var dani by remember { mutableStateOf(f.slobodni ?: emptyList()) }
                DonjiList({ list = List_.NEMA }) {
                    Text("Slobodni dani", style = naslov(26.sp))
                    Text(SLOBODNI_OBJASNJENJE, style = tekst(14.sp, boja = Boje.sivaTekst))
                    SlobodniDaniIzbor(dani) { dani = it }
                    Text("Izabrano: ${Karijera.daniOpis(dani)}", style = tekst(13.sp, FontWeight.SemiBold))
                    Dugme("Sačuvaj") { list = List_.NEMA; vlasnik { Karijera.podesiSlobodne(f.id, dani) } }
                }
            }
        }
        otpusti?.let { z ->
            Dijalog("Otpusti ${z.ime}?", "Vraća se u Korporaciju i 5 dana ne može da se vrati u tvoju firmu.", "Otpusti", "Odustani",
                potvrdi = { otpusti = null; vlasnik { Karijera.otpusti(f.id, z.id) } }, zatvori = { otpusti = null })
        }
    }) {
        val f = firma
        if (f == null) { greska?.let { KGreska(it) { opseg.launch { ucitaj() } } } ?: run { KSkelet(240.dp); KSkelet(120.dp) }; return@KOkvir }
        NaNebu(f.slika, if (f.korporacija) "korporacija" else f.id, visinaSlike = 230.dp)
        Row(verticalAlignment = Alignment.Top) {
            Column(Modifier.weight(1f)) {
                Text(f.ime, style = naslov(28.sp))
                Text(if (f.korporacija) "Šef · plata 40% · uvek otvorena" else "${Karijera.naziviNivoa[f.nivo - 1]} · vlasnik ${if (f.ja_vlasnik) "ti" else f.vlasnik_ime}${if (f.npc) " (uprava)" else ""}",
                    style = tekst(14.sp, FontWeight.SemiBold, Boje.sivaTekst))
            }
            if (f.ja_vlasnik) Text("Promeni ime", style = tekst(13.sp, FontWeight.Bold, Boje.teal), modifier = Modifier.clickable(role = Role.Button) { list = List_.IME }.padding(10.dp))
            else if (!f.npc && !f.korporacija) Text("Prijavi ime", style = tekst(13.sp, FontWeight.Bold, Boje.sivaTekst), modifier = Modifier.clickable(role = Role.Button) { list = List_.PRIJAVA }.padding(10.dp))
        }
        if (!f.korporacija) Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Plocica("${f.rekord}", f.rekord_ime?.let { "Rekord · $it" } ?: "Rekord", Boje.narandzasta, Modifier.weight(1f))
            Plocica("${f.zaposlenih}", "Zaposlenih", Boje.ljubicasta, Modifier.weight(1f))
            Plocica(if (f.ja_vlasnik) Karijera.novac(f.kasa ?: 0.0) else f.udeoNaziv.substringAfterLast(" · "), if (f.ja_vlasnik) "Kasa" else "Plata", Boje.teal, Modifier.weight(1f))
        }
        if (f.korporacija) KorporacijaObjasnjenje()
        if (!f.ja_vlasnik) Text("Šef: ${Karijera.sefOpis(f.sefNivo, f.stres)}\nPitanja: ${Karijera.mesavinaOpis(f.struka_udeo, f.fokus, f.fokus_udeo, f.teza)}\nSlobodni dani: ${Karijera.daniOpis(f.slobodni)}${if (f.slobodan_danas == true) " · danas se radi prekovremeno (+10%)" else ""}",
            style = tekst(13.sp, FontWeight.SemiBold, Boje.sivaTekst))
        // Upravljanje (vlasnik 05.11: „lepši UI, sada kao AI”): runda, kasa u tri pločice, plata, zbijen spisak podešavanja; bez kartice u kartici.
        if (f.ja_vlasnik) {
            Dugme("Igraj rundu u svojoj firmi") { idi(KEkran.RundaE(f.kratko, botovi = f.botovi)) }
            Text("Bar jedna runda dnevno. Održavanje ${Karijera.novac(f.odrzavanje.toDouble())} dnevno iz kase.", style = tekst(13.sp, boja = Boje.sivaTekst))
            // Kasa kao tamna kartica (vlasnik 05.11: „pregledno, ne bledo”): iznos krupno, tri radnje; kad radnja ne može, piše zašto.
            val cena = f.cena_nadogradnje; val treba = f.treba_zaposlenih
            val kasa = f.kasa ?: 0.0
            Column(Modifier.fillMaxWidth().background(Color(0xFF123F44), RoundedCornerShape(22.dp)).border(2.dp, Boje.mastilo, RoundedCornerShape(22.dp)).padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text("KASA FIRME", style = tekst(12.sp, FontWeight.Bold, Color.White.copy(alpha = 0.7f)))
                        Text(Karijera.novac(kasa), style = naslov(36.sp, Color.White))
                    }
                    androidx.compose.material3.Icon(androidx.compose.material.icons.Icons.Rounded.Payments, null, tint = Color(0xFF7FE0C9), modifier = Modifier.size(28.dp))
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    KasaPlocica(Modifier.weight(1f), androidx.compose.material.icons.Icons.Rounded.Download, "Dividenda",
                        if (f.dividenda_danas) "uzeta danas" else if (kasa <= 0) "kasa prazna" else "10% tebi",
                        !f.dividenda_danas && kasa > 0 && !radi) { vlasnik { Karijera.dividenda(f.id).also { Zvuk.pusti(Zvuk.Vrsta.KARIJERA_KASA, 0.5f) } } }
                    KasaPlocica(Modifier.weight(1f), androidx.compose.material.icons.Icons.Rounded.PersonAdd, "Asistent",
                        if (f.botovi.size >= f.nivo) "nema mesta" else if (kasa < 1000) "treba ${Karijera.novac(1000.0)}" else Karijera.novac(1000.0),
                        f.botovi.size < f.nivo && kasa >= 1000) { list = List_.BOT }
                    if (cena != null && treba != null) KasaPlocica(Modifier.weight(1f), androidx.compose.material.icons.Icons.Rounded.Apartment, "Nadogradi",
                        if (f.aktivnih < treba) "zaposleni ${f.aktivnih}/$treba" else if (kasa < cena) "treba ${Karijera.novac(cena)}" else Karijera.novac(cena),
                        kasa >= cena && f.aktivnih >= treba && !radi) { vlasnik { Karijera.nadogradi(f.id) } }
                }
                if (cena != null && treba != null) Text("Sledeći nivo, ${Karijera.naziviNivoa[f.nivo].lowercase()}: ${Karijera.novac(cena)} u kasi i $treba ${if (treba == 1) "aktivan zaposleni" else "aktivnih zaposlenih"}.",
                    style = tekst(12.sp, FontWeight.SemiBold, Color.White.copy(alpha = 0.75f)))
            }
            Oznaka("PLATA ZAPOSLENIMA")
            Podvuceno(listOf("skrt" to "Škrt 50%", "posten" to "Pošten 65%", "izdasan" to "Izdašan 80%"), f.udeo) { u -> vlasnik { Karijera.podesi(f.id, u, null) } }
            Text("Menja se jednom u 7 dana.", style = tekst(12.sp, boja = Boje.sivaTekst))
            Oznaka("PODEŠAVANJA FIRME")
            Column(Modifier.fillMaxWidth().mirna()) {
                RedPodesavanja(androidx.compose.material.icons.Icons.Rounded.Edit, Boje.teal, "Ime firme", f.ime) { list = List_.IME }
                HorizontalDivider(color = Boje.kremTamnija, modifier = Modifier.padding(start = 58.dp))
                RedPodesavanja(androidx.compose.material.icons.Icons.Rounded.Star, Boje.roze, "Ključne oblasti ×2", f.kljucne.ifEmpty { listOf("nijedna") }.joinToString(", ")) { list = List_.KLJUCNE }
                HorizontalDivider(color = Boje.kremTamnija, modifier = Modifier.padding(start = 58.dp))
                RedPodesavanja(androidx.compose.material.icons.Icons.Rounded.RecordVoiceOver, Boje.narandzasta, "Šef",
                    if ((f.stres ?: 0.0) > 0) "+${Math.round((f.stres ?: 0.0) * 100)}% plate" else listOf("isključen", "blag", "srednji", "jak")[maxOf(f.sefNivo.tacno, f.sefNivo.netacno)]) { list = List_.SEF }
                HorizontalDivider(color = Boje.kremTamnija, modifier = Modifier.padding(start = 58.dp))
                RedPodesavanja(androidx.compose.material.icons.Icons.Rounded.CalendarMonth, Boje.ljubicasta, "Slobodni dani", Karijera.daniOpis(f.slobodni)) { list = List_.SLOBODNI }
                HorizontalDivider(color = Boje.kremTamnija, modifier = Modifier.padding(start = 58.dp))
                RedPodesavanja(androidx.compose.material.icons.Icons.Rounded.Layers, Boje.nebo, "Pitanja u firmi", "struka ${f.struka_udeo ?: 60}%") { list = List_.PITANJA }
            }
        }
        if (f.botovi.isNotEmpty()) {
            Text("Asistenti", style = naslov(22.sp))
            f.botovi.forEach { b ->
                Row(Modifier.fillMaxWidth().mirna().padding(10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    KSlika(b.slika, Modifier.size(56.dp))
                    Column(Modifier.weight(1f)) {
                        Text("${b.ime} · ${b.tema}", style = tekst(15.sp, FontWeight.Bold))
                        Text("Tačnost ${b.nivo}% · danas još ${b.pomoci_ostalo} pomoći", style = tekst(13.sp, boja = Boje.sivaTekst))
                    }
                    val cena = Karijera.ceneObuke[b.nivo]
                    if (f.ja_vlasnik && b.nivo < 90 && cena != null) Text("Obuči\n${Karijera.novac(cena.toDouble())}", style = tekst(12.sp, FontWeight.Bold, Boje.teal),
                        modifier = Modifier.semantics { contentDescription = "Obuči asistenta ${b.ime} za $cena" }.clickable(role = Role.Button) { vlasnik { Karijera.obuciBota(b.id) } }.padding(8.dp))
                }
            }
        }
        if (f.zaposleni.isNotEmpty()) {
            Text("Zaposleni", style = naslov(22.sp))
            KSpisak {
                f.zaposleni.forEachIndexed { i, z ->
                    Row(Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f).clickable { idi(KEkran.CVE(z.id)) }.padding(vertical = 6.dp)) {
                            Text(z.ime, style = tekst(15.sp, FontWeight.Bold)); Text(Karijera.titule[minOf(z.titula, 3)], style = tekst(13.sp, boja = Boje.sivaTekst))
                        }
                        if (f.ja_vlasnik) Text("Otpusti", style = tekst(13.sp, FontWeight.Bold, Boje.crvena), modifier = Modifier.clickable(role = Role.Button) { otpusti = z }.padding(10.dp))
                    }
                    if (i < f.zaposleni.size - 1) HorizontalDivider(color = Boje.kremTamnija)
                }
            }
        }
        if (!f.ja_vlasnik && !f.korporacija) Dugme("Zaposli se ovde", vrsta = VrstaDugmeta.ZUTO, omoguceno = !radi) {
            opseg.launch {
                radi = true
                runCatching { Karijera.zaposliSe(f.id) }.onSuccess { Zvuk.pusti(Zvuk.Vrsta.KARIJERA_ZVONO, 0.6f); poruka = "Zaposlen si u firmi ${f.ime}."; ucitaj() }.onFailure { poruka = it.message }
                radi = false
            }
        }
    }
}

@Composable
private fun Izbornik(naziv: String, da: Boolean, promeni: () -> Unit) {
    Text(naziv, style = tekst(15.sp, FontWeight.SemiBold, if (da) Boje.tinta else Boje.mastilo),
        modifier = Modifier.fillMaxWidth().background(if (da) Boje.zuta else Boje.kartica, RoundedCornerShape(14.dp)).border(1.dp, Boje.mastilo, RoundedCornerShape(14.dp))
            .semantics { selected = da }.clickable(role = Role.Checkbox, onClick = promeni).padding(12.dp))
}

@Composable
private fun Polje(vrednost: String, promeni: (String) -> Unit) {
    BasicTextField(vrednost, promeni, singleLine = true, textStyle = naslov(20.sp), cursorBrush = SolidColor(Boje.mastilo),
        modifier = Modifier.fillMaxWidth().background(Boje.kartica, RoundedCornerShape(16.dp)).border(2.dp, Boje.mastilo, RoundedCornerShape(16.dp)).padding(14.dp))
}

@Composable
private fun KorporacijaObjasnjenje() {
    val koraci = listOf(
        Triple("Radiš za drugog", "Šef komentariše svaki odgovor, plata je 40%. Subota i nedelja su slobodne: ko tada igra, radi prekovremeno (+10%).", "karijera_sef_korporacija_nervozan"),
        Triple("Položi probni rad", "10 rundi po 10 pitanja, može i u jednom danu. Sa 60% tačnih otvaraš svoj office, sa 90% dobijaš i 2 asistenta.", "karijera_sef_korporacija_zadovoljan"),
        Triple("Postani vlasnik", "Iz garaže rasteš do nebodera. Pravi igrači dolaze da se zaposle kod tebe i pune ti kasu, ali mogu i da ti preotmu firmu u duelu.", "karijera_zgrada_5_1"),
    )
    koraci.forEachIndexed { i, (n, t, s) ->
        Row(Modifier.fillMaxWidth().mirna().padding(12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Box(Modifier.size(32.dp).background(Boje.zuta, CircleShape).border(2.dp, Boje.mastilo, CircleShape), contentAlignment = Alignment.Center) { Text("${i + 1}", style = naslov(16.sp, Boje.tinta)) }
            Column(Modifier.weight(1f)) { Text(n, style = tekst(15.sp, FontWeight.Bold)); Text(t, style = tekst(13.sp, boja = Boje.sivaTekst)) }
            KSlika(s, Modifier.width(48.dp).height(64.dp))
        }
    }
}

/** Vlasnik podešava šefa: izgled (1 od 6), komentari na tačne i netačne, ometanja, smeh. */
@Composable
internal fun SefList(pocetni: Sef.Nivo, zatvori: () -> Unit, sacuvaj: (Sef.Nivo) -> Unit) {
    var n by remember { mutableStateOf(pocetni) }
    val jacine = listOf(0 to "Isključen", 1 to "Blag", 2 to "Srednji", 3 to "Jak")
    DonjiList(zatvori) {
        Text("Šef", style = naslov(26.sp))
        Text("Kako šef komentariše zaposlene u tvojoj firmi. Bez psovki i uvreda, ali jak šef je oštar. Srednji šef daje zaposlenima +5% plate, jak +10%, česta ometanja još +5%, iz kase.",
            style = tekst(14.sp, boja = Boje.sivaTekst))
        Text("Izgled: ${Sef.lik(n.lik).naziv}", style = tekst(15.sp, FontWeight.Bold))
        Sef.likovi.drop(1).chunked(3).forEach { red ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                red.forEach { l ->
                    Box(Modifier.weight(1f).height(96.dp).pop(if (n.lik == l.id) Boje.zuta else Boje.kartica, 14.dp).semantics { selected = n.lik == l.id; contentDescription = l.naziv }
                        .clickable(role = Role.RadioButton) { n = n.copy(lik = l.id) }.padding(6.dp), contentAlignment = Alignment.Center) { KSlika(Sef.slika(Sef.Povod.TACNO, l.id)) }
                }
            }
        }
        Text("Na tačne odgovore", style = tekst(15.sp, FontWeight.Bold)); Podvuceno(jacine, n.tacno) { n = n.copy(tacno = it) }
        Text("Na netačne odgovore", style = tekst(15.sp, FontWeight.Bold)); Podvuceno(jacine, n.netacno) { n = n.copy(netacno = it) }
        Text("Ometanja usred pitanja", style = tekst(15.sp, FontWeight.Bold)); Podvuceno(listOf(0 to "Ne", 1 to "Retko", 2 to "Ponekad", 3 to "Često"), n.ometanja) { n = n.copy(ometanja = it) }
        Text(listOf("Šef ne prekida rad.", "Jednom po rundi upadne sa pitanjem.", "2 do 3 puta po rundi upadne; u svakoj drugoj rundi jednom zada posao („Odmah, šefe”).",
            "4 do 5 puta po rundi upadne; jednom po rundi zada posao ili napravi haos.")[n.ometanja] + " Sat ne staje.", style = tekst(12.sp, boja = Boje.sivaTekst))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Smeh i reakcije bez reči", style = tekst(15.sp, FontWeight.Bold), modifier = Modifier.weight(1f))
            KPrekidac(n.smeh, "Smeh i reakcije bez reči") { n = n.copy(smeh = it) }
        }
        Text("Šef: ${Karijera.sefOpis(n, Karijera.stres(n))}", style = tekst(13.sp, FontWeight.SemiBold))
        Dugme("Sačuvaj") { sacuvaj(n) }
    }
}

/** Mešavina pitanja: udeo struke, do 2 teme fokusa u opštem delu i težina. Duel ostaje isti. */
@Composable
private fun PitanjaFirmeList(f: Karijera.FirmaDetalj, zatvori: () -> Unit, sacuvaj: (Int, List<String>, List<Int>, Boolean) -> Unit) {
    var struka by remember { mutableIntStateOf(f.struka_udeo ?: 60) }
    var fokus by remember { mutableStateOf(f.fokus ?: emptyList()) }
    var udeo by remember { mutableStateOf(f.fokus_udeo ?: emptyList()) }
    var teza by remember { mutableStateOf(f.teza ?: false) }
    var teme by remember { mutableStateOf<List<Karijera.TemaFokusa>?>(null) }
    LaunchedEffect(Unit) { teme = runCatching { Karijera.temeFokusa() }.getOrDefault(emptyList()) }
    DonjiList(zatvori) {
        Text("Pitanja u firmi", style = naslov(26.sp))
        Text("Struka", style = tekst(15.sp, FontWeight.Bold)); Podvuceno(listOf(40, 50, 60, 70, 80).map { it to "$it%" }, struka) { struka = it }
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text("Fokus u opštem delu", style = tekst(15.sp, FontWeight.Bold))
            Text("Do 2 teme. Procenat je deo opšteg dela runde.", style = tekst(12.sp, boja = Boje.sivaTekst))
        }
        val t = teme
        // Jedan spisak sa linijama između redova (ne odvojene zaobljene kartice), isto kao iOS.
        if (t == null) KSkelet(120.dp) else Column(Modifier.fillMaxWidth().mirna()) {
            t.forEachIndexed { i, tema ->
                val k = fokus.indexOf(tema.tema)
                val zakljucano = k < 0 && fokus.size >= 2
                Column(Modifier.fillMaxWidth().alpha(if (zakljucano) 0.45f else 1f).padding(horizontal = 14.dp, vertical = 10.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(Modifier.fillMaxWidth().heightIn(min = 30.dp).semantics { selected = k >= 0 }.clickable(enabled = !zakljucano, role = Role.Checkbox) {
                        if (k >= 0) { fokus = fokus.filterIndexed { j, _ -> j != k }; udeo = udeo.filterIndexed { j, _ -> j != k } } else { fokus = fokus + tema.tema; udeo = udeo + 50 }
                    }, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        androidx.compose.material3.Icon(if (k >= 0) androidx.compose.material.icons.Icons.Rounded.CheckCircle else androidx.compose.material.icons.Icons.Rounded.RadioButtonUnchecked,
                            null, tint = if (k >= 0) Boje.teal else Boje.kremTamnija, modifier = Modifier.size(22.dp))
                        Text(tema.tema.replaceFirstChar { it.uppercase() }, style = tekst(15.sp, FontWeight.SemiBold), modifier = Modifier.weight(1f))
                        if (k >= 0) Text("${udeo[k]}%", style = tekst(14.sp, FontWeight.Bold, Boje.teal))
                    }
                    if (k >= 0) Box(Modifier.padding(start = 34.dp)) { Podvuceno(listOf(20, 30, 40, 50).map { it to "$it%" }, udeo[k]) { v -> udeo = udeo.mapIndexed { j, x -> if (j == k) v else x } } }
                }
                if (i < t.size - 1) HorizontalDivider(color = Boje.kremTamnija, modifier = Modifier.padding(start = 48.dp))
            }
        }
        Text("Težina", style = tekst(15.sp, FontWeight.Bold)); Podvuceno(listOf(false to "Normalno", true to "Teže"), teza) { teza = it }
        Text("Runda: " + Karijera.mesavinaOpis(struka, fokus, udeo, teza), style = tekst(13.sp, FontWeight.SemiBold))
        Dugme("Sačuvaj") { sacuvaj(struka, fokus, udeo, teza) }
    }
}

/** Berza poslova: Korporacija, NPC firme i firme igrača; filter moja struka ili sve. */
@Composable
fun BerzaEkran(ja: String?, idi: (KEkran) -> Unit, nazad: () -> Unit) {
    var samoStruka by remember { mutableStateOf(true) }
    var lista by remember { mutableStateOf<List<Karijera.Firma>?>(null) }
    var greska by remember { mutableStateOf<String?>(null) }
    var pozicija by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(samoStruka) {
        if (pozicija == null) pozicija = runCatching { Karijera.stanje().pozicija }.getOrNull()
        // Moja firma je prva na berzi (vlasnik 05.11), ostale ostaju kako ih server poređa.
        runCatching { Karijera.berza(if (samoStruka) pozicija else null) }.onSuccess { l -> lista = l.sortedBy { if (it.vlasnik != null && it.vlasnik == ja) 0 else 1 }; greska = null }.onFailure { greska = it.message }
    }
    KOkvir(nazad) {
        Text("Berza poslova", style = naslov(30.sp))
        Text("Ista tačna odgovora vrede različito u različitim firmama: ključne oblasti nose ×2, a plata zavisi od vlasnika.", style = tekst(14.sp, boja = Boje.sivaTekst))
        Podvuceno(listOf(true to "Moja struka", false to "Sve firme"), samoStruka) { samoStruka = it }
        val l = lista
        when {
            greska != null -> KGreska(greska!!) { samoStruka = !samoStruka; samoStruka = !samoStruka }
            l == null -> repeat(4) { KSkelet(120.dp) }
            l.isEmpty() -> Text("Za tvoju struku još nema otvorenih firmi.", style = tekst(15.sp))
            else -> l.forEach { f ->
                FirmaKartica(f, null, f.vlasnik != null && f.vlasnik == ja) { idi(KEkran.FirmaE(f.id)) }
                if (!f.korporacija) Text("${f.udeoNaziv} · ${f.zaposlenih} zaposlenih · ${f.botova} ${if (f.botova == 1) "asistent" else "asistenata"}\nŠef: ${Karijera.sefOpis(f.sefNivo, f.stres)} · ${Karijera.mesavinaOpis(f.struka_udeo, f.fokus, f.fokus_udeo, f.teza)}",
                    style = tekst(12.sp, FontWeight.SemiBold, Boje.sivaTekst), modifier = Modifier.padding(horizontal = 6.dp))
            }
        }
    }
}

/** Otvaranje officea: izgled zgrade (4), ime, asistenti (koliko je probni rad dao) i slobodni dani. */
@Composable
fun OfficeEkran(botova: Int, nazad: () -> Unit) {
    var stil by remember { mutableIntStateOf(1) }
    var ime by remember { mutableStateOf("") }
    var botTeme by remember { mutableStateOf<List<String>>(emptyList()) }
    var slobodni by remember { mutableStateOf<List<Int>>(emptyList()) }
    var teme by remember { mutableStateOf<List<String>>(emptyList()) }
    var greska by remember { mutableStateOf<String?>(null) }
    var radi by remember { mutableStateOf(false) }
    val opseg = rememberCoroutineScope()
    LaunchedEffect(Unit) {
        KarijeraMuzika.pusti(Zvuk.Vrsta.KARIJERA_OFFICE)
        runCatching { Karijera.stanje().pozicija?.let { Karijera.temePozicije(it) } }.getOrNull()?.let { l -> teme = l.filter { it.pitanja >= 10 }.map { it.tema } }
    }
    KOkvir({ KarijeraMuzika.stani(); nazad() }) {
        Text("Tvoj office", style = naslov(30.sp))
        KSlika(Karijera.slikaZgrade(false, 1, stil), Modifier.fillMaxWidth().height(200.dp))
        Text("Počinješ u garaži. Sa kasom i zaposlenima rasteš do nebodera. Ovako raste izabrani izgled:", style = tekst(14.sp, boja = Boje.sivaTekst))
        // Niz od garaže do nebodera za izabrani stil (vlasnik 05.11: da se vidi u šta mala zgrada prerasta).
        Row(Modifier.fillMaxWidth().mirna().padding(12.dp).semantics(mergeDescendants = true) { contentDescription = "Rast firme: garaža, kancelarija, sprat, poslovna zgrada, neboder" },
            verticalAlignment = Alignment.Bottom) {
            for (n in 1..5) {
                Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    KSlika(Karijera.slikaZgrade(false, n, stil), Modifier.height((28 + n * 12).dp))
                    Text(Karijera.naziviNivoa[n - 1], style = tekst(10.sp, FontWeight.Bold, Boje.sivaTekst), maxLines = 1)
                }
                if (n < 5) Text("›", style = tekst(14.sp, FontWeight.Bold, Boje.sivaTekst), modifier = Modifier.padding(bottom = 18.dp))
            }
        }
        Oznaka("IZGLED")
        for (red in (1..Karijera.naziviStila.size).chunked(4)) Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            for (s in red) Column(Modifier.weight(1f).pop(if (stil == s) Boje.zuta else Boje.kartica, 14.dp).semantics { selected = stil == s }.clickable(role = Role.RadioButton) { stil = s }.padding(6.dp),
                horizontalAlignment = Alignment.CenterHorizontally) {
                KSlika(Karijera.slikaZgrade(false, 5, s), Modifier.height(74.dp))
                Text(Karijera.naziviStila[s - 1], style = tekst(12.sp, FontWeight.Bold, if (stil == s) Boje.tinta else Boje.mastilo))
            }
        }
        Oznaka("IME FIRME")
        Polje(ime) { ime = it.take(32) }
        Text("3 do 32 znaka. Ime vide svi igrači; neprimereno ime se skida posle prijava.", style = tekst(12.sp, boja = Boje.sivaTekst))
        if (botova > 0) {
            Oznaka("ASISTENTI (${botTeme.size} OD $botova)")
            Text("Svaki asistent zna jednu temu i pomaže na 5 pitanja dnevno.", style = tekst(13.sp, boja = Boje.sivaTekst))
            teme.forEach { t -> Izbornik(t.replaceFirstChar { it.uppercase() }, t in botTeme) { botTeme = if (t in botTeme) botTeme - t else if (botTeme.size < botova) botTeme + t else botTeme } }
        }
        Oznaka("SLOBODNI DANI (DO 3)")
        SlobodniDaniIzbor(slobodni) { slobodni = it }
        Text(SLOBODNI_OBJASNJENJE, style = tekst(12.sp, boja = Boje.sivaTekst))
        greska?.let { Text(it, style = tekst(14.sp, FontWeight.SemiBold, Boje.crvena)) }
        Dugme("Otvori office", omoguceno = ime.trim().length >= 3 && !radi) {
            opseg.launch {
                radi = true
                runCatching {
                    val n = Karijera.otvoriFirmu(ime, stil, botTeme)
                    if (slobodni.isNotEmpty()) runCatching { Karijera.podesiSlobodne(n.firma, slobodni) }
                }.onSuccess { KarijeraMuzika.stani(); Zvuk.pusti(Zvuk.Vrsta.KARIJERA_UNAPREDJENJE); nazad() }.onFailure { greska = it.message }
                radi = false
            }
        }
    }
}

/** CV igrača: titula, firme, ekspertiza (zvezdice) i istorija napredovanja. */
@Composable
fun CVEkran(igrac: String?, nazad: () -> Unit) {
    var cv by remember { mutableStateOf<Karijera.CV?>(null) }
    var greska by remember { mutableStateOf<String?>(null) }
    var pokusaj by remember { mutableIntStateOf(0) }
    LaunchedEffect(pokusaj) { runCatching { Karijera.cv(igrac) }.onSuccess { cv = it }.onFailure { greska = it.message } }
    KOkvir(nazad) {
        val c = cv
        if (c == null) { greska?.let { KGreska(it) { pokusaj++ } } ?: run { KSkelet(90.dp); KSkelet(140.dp) }; return@KOkvir }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            club.librum.kviz.ui.AvatarSlika(c.avatar, 72.dp)
            Column {
                Text(c.ime, style = naslov(26.sp))
                Text("${Karijera.titule[minOf(c.titula, 3)]} · ${c.pozicija.orEmpty()}", style = tekst(14.sp, FontWeight.SemiBold, Boje.sivaTekst))
                c.posao?.let { Text("Radi u: ${it.ime}", style = tekst(13.sp, boja = Boje.sivaTekst), maxLines = 1) }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Plocica(Karijera.novac(c.neto), "Neto vrednost", Boje.teal, Modifier.weight(1f)); Plocica("${c.ugled}", "Ugled", Boje.roze, Modifier.weight(1f))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Plocica("${c.tacnih}", "Tačnih u ${c.rundi} rundi", Boje.narandzasta, Modifier.weight(1f)); Plocica("${c.preuzimanja} · ${c.odbrana}", "Preuzeo · odbranio", Boje.ljubicasta, Modifier.weight(1f))
        }
        if (c.firme.isNotEmpty()) { Text("Firme", style = naslov(22.sp)); c.firme.forEach { FirmaKartica(it, null, false) {} } }
        if (c.ekspertiza.isNotEmpty()) {
            Text("Ekspertiza", style = naslov(22.sp))
            Column(Modifier.fillMaxWidth().mirna().padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                c.ekspertiza.forEach { e ->
                    val z = listOf(100, 300, 800, 2000, 5000).count { e.ocena >= it }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(e.tema.replaceFirstChar { it.uppercase() }, style = tekst(15.sp, FontWeight.SemiBold), modifier = Modifier.weight(1f))
                        Text("★".repeat(z) + "☆".repeat(5 - z), style = tekst(13.sp, boja = Boje.narandzasta), modifier = Modifier.semantics { contentDescription = "$z od 5" })
                        Text("${e.ocena}", style = tekst(13.sp, FontWeight.Bold), modifier = Modifier.width(54.dp).padding(start = 8.dp))
                    }
                }
            }
        }
        if (c.dogadjaji.isNotEmpty()) {
            Text("Karijera", style = naslov(22.sp))
            Column(Modifier.fillMaxWidth().mirna().padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                c.dogadjaji.forEach { d ->
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Box(Modifier.padding(top = 5.dp).size(10.dp).background(Boje.teal, CircleShape))
                        Column {
                            Text(d.tekst, style = tekst(14.sp, FontWeight.SemiBold))
                            Karijera.datum(d.kad)?.let { Text("${it.dayOfMonth}.${it.monthValue}.${it.year}.", style = tekst(12.sp, boja = Boje.sivaTekst)) }
                        }
                    }
                }
            }
        }
    }
}

/** Rang lista Karijere (ugrađuje se u glavnu Rang listu). */
@Composable
fun KarijeraRang(otvoriCV: (String) -> Unit) {
    var vrsta by remember { mutableStateOf("neto") }
    var lista by remember { mutableStateOf<List<Karijera.RedRanga>?>(null) }
    LaunchedEffect(vrsta) { lista = null; lista = runCatching { Karijera.rang(vrsta) }.getOrDefault(emptyList()) }
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Podvuceno(listOf("neto" to "Neto vrednost", "sezona" to "Sezona", "firme" to "Najveće firme"), vrsta) { vrsta = it }
        Text(when (vrsta) { "sezona" -> "Poeni u tekućem tromesečju. Na kraju sezone lista kreće iz početka, zgrade i CV ostaju."; "firme" -> "Broj zaposlenih u svim firmama vlasnika."; else -> "Kapital + kasa svih firmi + vrednost zgrada." },
            style = tekst(13.sp, boja = Boje.sivaTekst))
        val l = lista
        when {
            l == null -> repeat(5) { KSkelet(52.dp) }
            l.isEmpty() -> Text("Lista je prazna. Budi prvi: odigraj rundu.", style = tekst(15.sp))
            else -> KSpisak {
                l.forEachIndexed { i, r ->
                    Row(Modifier.fillMaxWidth().clickable { otvoriCV(r.id) }.padding(horizontal = 14.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Box(Modifier.size(32.dp).background(if (i < 3) listOf(Boje.zuta, Boje.nebo, Boje.roze)[i] else Boje.udubljeno, RoundedCornerShape(9.dp)), contentAlignment = Alignment.Center) {
                            Text("${i + 1}", style = naslov(17.sp, Boje.tinta))
                        }
                        Column(Modifier.weight(1f)) { Text(r.ime, style = tekst(15.sp, FontWeight.SemiBold), maxLines = 1); r.pozicija?.let { Text(it, style = tekst(12.sp, boja = Boje.sivaTekst)) } }
                        Text(Karijera.novac(r.vrednost), style = naslov(17.sp))
                    }
                    if (i < l.size - 1) HorizontalDivider(color = Boje.kremTamnija)
                }
            }
        }
    }
}

/** Lobi → „Pravila i saveti”: iste strane kao pri prvom ulasku i saveti. */
@Composable
fun PravilaEkran(nazad: () -> Unit) {
    KOkvir(nazad) {
        Text("Pravila i saveti", style = naslov(30.sp))
        KarijeraVodic.strane.forEach { s ->
            Column(Modifier.fillMaxWidth().mirna().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(s.naslov, style = naslov(22.sp))
                s.pasusi.forEach { Text(Sef.oblik(it, Karijera.mojPol == "z"), style = tekst(15.sp)) }
            }
        }
        Text("Saveti", style = naslov(22.sp))
        Column(Modifier.fillMaxWidth().mirna().padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            KarijeraVodic.saveti.forEach { Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) { Text("•", style = tekst(15.sp, FontWeight.Bold, Boje.narandzasta)); Text(it, style = tekst(15.sp)) } }
        }
    }
}


/** Radnja iz kase na tamnoj kartici (isto kao iOS): ikonica, naziv i cena ili razlog zašto ne može (ne bledi). */
@Composable
private fun KasaPlocica(modifier: Modifier, ikonica: androidx.compose.ui.graphics.vector.ImageVector, naslov: String, opis: String, omoguceno: Boolean, akcija: () -> Unit) {
    Column(modifier.heightIn(min = 86.dp)
        .background(if (omoguceno) Color(0xFF7FE0C9) else Color.White.copy(alpha = 0.1f), RoundedCornerShape(14.dp))
        .border(1.dp, Color.White.copy(alpha = if (omoguceno) 0f else 0.25f), RoundedCornerShape(14.dp))
        .clickable(enabled = omoguceno, role = Role.Button, onClick = akcija)
        .semantics(mergeDescendants = true) { contentDescription = "$naslov, $opis" }
        .padding(10.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        androidx.compose.material3.Icon(ikonica, null, tint = if (omoguceno) Color(0xFF123F44) else Color.White.copy(alpha = 0.55f), modifier = Modifier.size(24.dp))
        Text(naslov, style = tekst(14.sp, FontWeight.Bold, if (omoguceno) Boje.tinta else Color.White))
        Text(opis, style = tekst(11.sp, FontWeight.SemiBold, if (omoguceno) Boje.tinta.copy(alpha = 0.65f) else Color.White.copy(alpha = 0.7f)), maxLines = 1)
    }
}

/** Red podešavanja sa obojenim kvadratom za ikonicu (kao podešavanja telefona). */
@Composable
private fun RedPodesavanja(ikonica: androidx.compose.ui.graphics.vector.ImageVector, boja: Color, naziv: String, vrednost: String, akcija: () -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 54.dp).clickable(role = Role.Button, onClick = akcija).padding(horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        Box(Modifier.size(30.dp).background(boja, RoundedCornerShape(8.dp)), contentAlignment = Alignment.Center) {
            androidx.compose.material3.Icon(ikonica, null, tint = Color.White, modifier = Modifier.size(17.dp))
        }
        Text(naziv, style = tekst(15.sp, FontWeight.SemiBold), modifier = Modifier.weight(1f))
        Text(vrednost, style = tekst(14.sp, FontWeight.SemiBold, Boje.sivaTekst), maxLines = 1, overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
        Text("›", style = tekst(20.sp, FontWeight.Bold, Boje.sivaTekst))
    }
}
