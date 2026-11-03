package club.librum.kviz.osvajanje

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Computer
import androidx.compose.material.icons.rounded.Flag
import androidx.compose.material.icons.rounded.Groups
import androidx.compose.material.icons.rounded.HourglassTop
import androidx.compose.material.icons.rounded.Lightbulb
import androidx.compose.material.icons.rounded.People
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material.icons.rounded.Public
import androidx.compose.material.icons.rounded.Shield
import androidx.compose.material.icons.rounded.SkipNext
import androidx.compose.material.icons.rounded.Timer
import androidx.compose.material.icons.rounded.Warning
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import club.librum.kviz.servisi.PaketPitanja
import club.librum.kviz.servisi.Sesija
import club.librum.kviz.servisi.Supabase
import club.librum.kviz.servisi.Zvuk
import club.librum.kviz.ui.AvatarSlika
import club.librum.kviz.ui.Boje
import club.librum.kviz.ui.Cinjenice
import club.librum.kviz.ui.Dijalog
import club.librum.kviz.ui.DonjiList
import club.librum.kviz.ui.Dugme
import club.librum.kviz.ui.IkonicaPolaPola
import club.librum.kviz.ui.Izbor
import club.librum.kviz.ui.Maskota
import club.librum.kviz.ui.MaskotaSlika
import club.librum.kviz.ui.Oznaka
import club.librum.kviz.ui.Papir
import club.librum.kviz.ui.PitanjeKartica
import club.librum.kviz.ui.PomocDugme
import club.librum.kviz.ui.VrstaDugmeta
import club.librum.kviz.ui.mirna
import club.librum.kviz.ui.naslov
import club.librum.kviz.ui.pop
import club.librum.kviz.ui.tekst
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.serialization.Serializable

/** Postavka između uvoda i partije (navigacija nosi samo rutu). */
object OsvajanjeTok { var postavka by mutableStateOf<OsvajanjePostavka?>(null) }

private val MASKOTE = listOf(Maskota.BLOOP, Maskota.MIMI, Maskota.ZIG, Maskota.LUMI)

/** Uvod: ceo svet (server sam spaja igrače) ili jedan kontinent (računar odmah ili 1 na 1). */
@Composable
fun OsvajanjeUvod(ime: String?, pokreni: (OsvajanjePostavka) -> Unit) {
    var teren by remember { mutableStateOf<String?>(null) }
    var protivRacunara by remember { mutableStateOf(true) }
    var nacin by remember { mutableStateOf(OsvajanjePostavka.Nacin.SVAKO_ZA_SEBE) }
    var igraca by remember { mutableIntStateOf(3) }
    var krugova by remember { mutableIntStateOf(12) }
    var tezina by remember { mutableStateOf(Tezina.NORMALNO) }
    Box(Modifier.fillMaxSize()) {
        Papir()
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Box(Modifier.fillMaxWidth().pop(Boje.teal).clip(RoundedCornerShape(24.dp))) {
                Box(Modifier.align(Alignment.BottomEnd).size(220.dp).alpha(0.14f).background(Color.White, CircleShape))
                MaskotaSlika(Maskota.MIMI, 110.dp, Modifier.align(Alignment.BottomEnd).padding(8.dp))
                Column(Modifier.padding(22.dp).padding(end = 110.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Oznaka("Glavna igra · 2 do 12 igrača", Boje.zuta)
                    Text("Osvajanje\nsveta", style = naslov(42.sp).copy(color = Color.White, lineHeight = 44.sp))
                    Text("Biraš odakle napadaš i koga, pa pitanja odlučuju bitku.", style = tekst(15.sp, FontWeight.SemiBold, Color.White.copy(alpha = 0.9f)))
                }
            }
            Text("Gde se igra", style = tekst(15.sp, FontWeight.Bold))
            Izbor(listOf("Ceo svet", "Jedan kontinent"), if (teren == null) 0 else 1) {
                teren = if (it == 0) null else teren ?: "evr"
                if (it == 0) { nacin = OsvajanjePostavka.Nacin.SVAKO_ZA_SEBE; igraca = 3 }
            }
            val izabran = teren
            if (izabran != null) {
                Text("Kontinent", style = tekst(15.sp, FontWeight.Bold))
                Kontinenti.svi.forEach { k ->
                    RedIzbora(Icons.Rounded.Public, k.ime, "${Kontinenti.oblasti(k.id).size} država", izabran == k.id) { teren = k.id }
                }
                Text("Protivnik", style = tekst(15.sp, FontWeight.Bold))
                RedIzbora(Icons.Rounded.Computer, "Protiv računara", "Odmah, bez čekanja.", protivRacunara) { protivRacunara = true }
                RedIzbora(Icons.Rounded.Person, "Jedan na jedan", "Pravi rival na istom kontinentu.", !protivRacunara) { protivRacunara = false }
            } else {
                Text("Način igre", style = tekst(15.sp, FontWeight.Bold))
                OsvajanjePostavka.Nacin.entries.forEach { n ->
                    val ikonica = when (n) { OsvajanjePostavka.Nacin.TIMOVI -> Icons.Rounded.People; OsvajanjePostavka.Nacin.JEDAN_NA_JEDAN -> Icons.Rounded.Person; else -> Icons.Rounded.Groups }
                    RedIzbora(ikonica, n.naziv, n.opis, nacin == n) { nacin = n; igraca = n.brojevi[0] }
                }
                if (nacin.brojevi.size > 1) {
                    Text("Igrača", style = tekst(15.sp, FontWeight.Bold))
                    Izbor(nacin.brojevi.map { "$it" }, nacin.brojevi.indexOf(igraca)) { igraca = nacin.brojevi[it] }
                }
            }
            Text("Dužina", style = tekst(15.sp, FontWeight.Bold))
            Izbor(listOf("8 krugova", "12 krugova"), if (krugova == 8) 0 else 1) { krugova = if (it == 0) 8 else 12 }
            Text(if (izabran != null && protivRacunara) "Jačina računara" else "Jačina botova na praznim mestima", style = tekst(15.sp, FontWeight.Bold))
            Izbor(Tezina.entries.map { it.ime }, Tezina.entries.indexOf(tezina)) { tezina = Tezina.entries[it] }
            Dugme("Igraj") {
                val n = if (izabran == null) nacin else OsvajanjePostavka.Nacin.JEDAN_NA_JEDAN
                val broj = if (izabran == null) igraca else 2
                pokreni(OsvajanjePostavka(n, broj, krugova, tezina, OsvajanjePostavka.mesta(n, broj, ime ?: "Ti"),
                    teren = izabran, traziIgrace = !(izabran != null && protivRacunara)))
            }
            Spacer(Modifier.height(60.dp))
        }
    }
}

@Composable
private fun RedIzbora(ikonica: ImageVector, naslovReda: String, opis: String, izabrano: Boolean, radnja: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().background(Boje.kartica, RoundedCornerShape(18.dp))
            .border(if (izabrano) 2.5.dp else 1.5.dp, if (izabrano) Boje.mastilo else Boje.kremTamnija, RoundedCornerShape(18.dp))
            .clickable(onClick = radnja).padding(12.dp)
            .semantics(mergeDescendants = true) { contentDescription = "$naslovReda${if (izabrano) ", izabrano" else ""}" },
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(Modifier.size(44.dp).background(if (izabrano) Boje.zuta else Boje.udubljeno, RoundedCornerShape(12.dp)), contentAlignment = Alignment.Center) {
            Icon(ikonica, null, tint = Boje.tinta)
        }
        Column(Modifier.weight(1f)) {
            Text(naslovReda, style = tekst(16.sp, FontWeight.Bold))
            Text(opis, style = tekst(13.sp, boja = Boje.sivaTekst))
        }
    }
}

/** Tok posle uvoda: spajanje igrača (server), izbor kontinenata za ceo svet, pa partija. */
@Composable
fun OsvajanjeTokEkran(sesija: Sesija, izadji: () -> Unit) {
    var postavka by remember { mutableStateOf(OsvajanjeTok.postavka) }
    var korak by remember { mutableStateOf(if (postavka?.traziIgrace == true) 0 else if (postavka?.teren == null) 1 else 2) }
    val p = postavka ?: run { izadji(); return }
    when (korak) {
        0 -> Cekaonica(sesija, p, odustani = izadji) { nova -> postavka = nova; korak = if (nova.teren == null && nova.soba == null) 1 else 2 }
        1 -> IzborKontinenata(p, izadji) { nova -> postavka = nova; korak = 2 }
        else -> OsvajanjeIgra(p, sesija, izadji)
    }
}

@Serializable
private data class Soba(val id: String, val velicina: Int, val status: String, val mesta: List<Mesto> = emptyList()) {
    @Serializable data class Mesto(val user_id: String, val mesto: Int, val nadimak: String, val avatar: String? = null)
}

/** Kratko čekanje: ko stigne u 10 s igra zajedno, ostalo su botovi; igrač sobe ne vidi, raspoređuje server. */
private const val CEKANJE_PRE_BOTOVA_MS = 10_000L

@Composable
private fun Cekaonica(sesija: Sesija, postavka: OsvajanjePostavka, odustani: () -> Unit, gotovo: (OsvajanjePostavka) -> Unit) {
    var soba by remember { mutableStateOf<Soba?>(null) }
    var greska by remember { mutableStateOf<String?>(null) }
    var proslo by remember { mutableLongStateOf(0L) }
    BackHandler(onBack = odustani)
    LaunchedEffect(Unit) {
        Zvuk.pusti(Zvuk.Vrsta.CEKANJE, 0.2f, ponavljaj = true)
        val token = sesija.vazeciToken() ?: run { greska = "Prijavi se da bi igrao sa drugim igračima."; return@LaunchedEffect }
        val pocetak = System.currentTimeMillis()
        var mojaSoba: Soba? = null
        try {
            val prva = Supabase.json.decodeFromString<Soba>(Supabase.rpc("osvajanje_trazi_sobu",
                mapOf("p_nacin" to postavka.nacin.kljuc, "p_velicina" to postavka.igraca, "p_teren" to postavka.teren), token))
            mojaSoba = prva; soba = prva
            while (soba?.status == "ceka") {
                delay(2000)
                proslo = System.currentTimeMillis() - pocetak
                // Posle 10 s traži se start sa botovima; server ga dozvoljava tek kad soba čeka toliko.
                val funkcija = if (proslo > CEKANJE_PRE_BOTOVA_MS) "osvajanje_pokreni" else "osvajanje_soba"
                runCatching { Supabase.json.decodeFromString<Soba>(Supabase.rpc(funkcija, mapOf("p_soba" to prva.id), token)) }.getOrNull()?.let { soba = it }
            }
            Zvuk.stani(Zvuk.Vrsta.CEKANJE)
            Zvuk.pusti(Zvuk.Vrsta.BEDZ, 0.4f)
            // Pravi igrači sedaju na mesta botova redom; čovek ostaje prvi u svom timu.
            // Isti id na svakom telefonu („u:<nalog>”, kao iOS), da partija preko servera zna ko je ko.
            val ja = sesija.nalog.value?.id.orEmpty()
            val s = soba!!
            val drugi = s.mesta.filter { it.user_id != ja }.sortedBy { it.mesto }
            var i = 0
            val igraci = postavka.igraci.map { p ->
                when {
                    p.covek -> p.copy(id = VezaOsvajanja.idIgraca(ja))
                    i >= drugi.size -> p
                    else -> NoviIgrac(VezaOsvajanja.idIgraca(drugi[i].user_id), drugi[i].nadimak, p.boja, false, p.tim, p.kapiten).also { i++ }
                }
            }
            gotovo(if (drugi.isEmpty()) postavka.copy(igraci = postavka.igraci) else
                postavka.copy(igraci = igraci, soba = s.id, korisnik = ja, domacin = s.mesta.firstOrNull { it.mesto == 0 }?.user_id == ja))
        } catch (e: CancellationException) {
            // Zatvorena čekaonica pre početka: mesto se oslobađa za druge.
            mojaSoba?.takeIf { soba?.status == "ceka" }?.let { s -> kotlinx.coroutines.withContext(kotlinx.coroutines.NonCancellable) { runCatching { Supabase.rpc("osvajanje_napusti", mapOf("p_soba" to s.id), token) } } }
            Zvuk.stani(Zvuk.Vrsta.CEKANJE)
            throw e
        } catch (e: Exception) {
            Zvuk.stani(Zvuk.Vrsta.CEKANJE)
            greska = "Server se ne javlja. Probaj ponovo ili igraj sa botovima."
        }
    }
    Box(Modifier.fillMaxSize()) {
        Papir()
        Column(
            Modifier.fillMaxSize().statusBarsPadding().padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Row(Modifier.fillMaxWidth()) { KrugIzlaz(odustani) }
            Text("Spajamo te sa igračima", style = naslov(30.sp), textAlign = TextAlign.Center)
            val g = greska
            if (g != null) {
                Text(g, style = tekst(15.sp, FontWeight.SemiBold, Boje.crvena), textAlign = TextAlign.Center)
                Dugme("Igraj sa botovima") { gotovo(postavka.copy(traziIgrace = false)) }
            } else {
                MaskotaSlika(Maskota.ZIG, 120.dp)
                Text("${soba?.mesta?.size ?: 1} od ${postavka.igraca} igrača", style = naslov(30.sp))
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) { soba?.mesta?.forEach { AvatarSlika(it.avatar, 40.dp) } }
                val ostalo = ((CEKANJE_PRE_BOTOVA_MS - proslo) / 1000).coerceAtLeast(0)
                Text(if (ostalo > 0) "Partija kreće čim se skupe igrači, najkasnije za $ostalo s." else "Krećemo, prazna mesta preuzimaju botovi…",
                    style = tekst(14.sp, FontWeight.SemiBold, Boje.sivaTekst), textAlign = TextAlign.Center)
                Icon(Icons.Rounded.HourglassTop, null, tint = Boje.sivaTekst)
            }
        }
    }
}

/** Izbor kontinenata „zmijom”: botovi biraju nasumično od slobodnih, čovek dodirom. */
@Composable
private fun IzborKontinenata(postavka: OsvajanjePostavka, odustani: () -> Unit, gotovo: (OsvajanjePostavka) -> Unit) {
    val timovi = remember { postavka.igraci.map { it.tim ?: it.id }.distinct() }
    val mojTim = postavka.igraci.first { it.covek }.tim ?: "A"
    val red = remember { Stanje.redosledIzbora(timovi.shuffled()) }
    var pocetak by remember { mutableStateOf(mapOf<String, String>()) }
    val naRedu = red.firstOrNull { it !in pocetak }
    fun ime(t: String) = if (t == mojTim) "ti" else if (postavka.nacin == OsvajanjePostavka.Nacin.TIMOVI) "tim $t" else postavka.igraci.first { (it.tim ?: it.id) == t }.ime
    LaunchedEffect(naRedu) {
        val t = naRedu ?: return@LaunchedEffect
        if (t == mojTim) return@LaunchedEffect
        delay(700)
        Kontinenti.svi.map { it.id }.filter { it !in pocetak.values }.randomOrNull()?.let { pocetak = pocetak + (t to it) }
    }
    BackHandler(onBack = odustani)
    Box(Modifier.fillMaxSize()) {
        Papir()
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            KrugIzlaz(odustani)
            Text("Izbor kontinenta", style = naslov(30.sp))
            Text(when (naRedu) { null -> "Svi su izabrali."; mojTim -> "Ti biraš. Na njemu je tvoja prestonica i prvih 6 država."; else -> "Bira ${ime(naRedu)}…" },
                style = tekst(15.sp, FontWeight.SemiBold, if (naRedu == mojTim) Boje.mastilo else Boje.sivaTekst))
            Kontinenti.svi.forEach { k ->
                val zauzeo = pocetak.entries.firstOrNull { it.value == k.id }?.key
                Box(Modifier.alpha(if (zauzeo != null) 0.6f else 1f)) {
                    RedIzbora(Icons.Rounded.Public, k.ime, "${Kontinenti.oblasti(k.id).size} država" + (zauzeo?.let { " · ${ime(it)}" } ?: ""), zauzeo == mojTim) {
                        if (naRedu == mojTim && zauzeo == null) pocetak = pocetak + (mojTim to k.id)
                    }
                }
            }
            if (naRedu == null) Dugme("Počni partiju") { gotovo(postavka.copy(pocetak = pocetak)) }
        }
    }
}

@Composable
private fun KrugIzlaz(radnja: () -> Unit) {
    IconButton(onClick = radnja, modifier = Modifier.size(44.dp).background(Boje.kartica, CircleShape).border(1.5.dp, Boje.kremTamnija, CircleShape)) {
        Icon(Icons.Rounded.Close, contentDescription = "Izađi", tint = Boje.mastilo)
    }
}

/** Partija: igrači gore, mapa u sredini, uputstvo i radnje dole, bitka preko svega. */
@Composable
fun OsvajanjeIgra(postavka: OsvajanjePostavka, sesija: Sesija? = null, izadji: () -> Unit) {
    val kontekst = LocalContext.current.applicationContext
    val model: OsvajanjeModel = viewModel(key = "osvajanje-${postavka.hashCode()}") {
        OsvajanjeModel(postavka.krugova, postavka.tezina, null, PaketPitanja(kontekst), postavka, sesija)
    }
    var potvrdaIzlaska by remember { mutableStateOf(false) }
    var misija by remember { mutableStateOf(false) }
    var videoMisiju by remember { mutableStateOf(false) }
    BackHandler { potvrdaIzlaska = true }
    // Ekran ne sme da se ugasi usred poteza (gašenje je izbacivalo iz partije).
    val pogled = androidx.compose.ui.platform.LocalView.current
    DisposableEffect(Unit) { pogled.keepScreenOn = true; onDispose { pogled.keepScreenOn = false } }
    // Preko servera misija i mapa stižu sa domaćinovog telefona, pa list misije čeka prvo stanje.
    LaunchedEffect(model.spremno, model.cekaPocetak) {
        if (!model.spremno || model.cekaPocetak || videoMisiju) return@LaunchedEffect
        videoMisiju = true
        // Na jednom kontinentu nema tajne misije: cilj je ceo kontinent, partija kreće odmah.
        if (postavka.teren == null) misija = true else { model.pocniPostavljanje(); model.javi("Cilj: osvoji ceo kontinent") }
    }

    Box(Modifier.fillMaxSize()) {
        Papir()
        when {
            model.greska != null -> Column(
                Modifier.align(Alignment.Center).padding(24.dp).mirna().padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                MaskotaSlika(Maskota.ZIG, 110.dp)
                Text("Pitanja nisu stigla", style = naslov(26.sp))
                Text(model.greska.orEmpty(), style = tekst(15.sp, boja = Boje.sivaTekst))
                Dugme("Nazad", radnja = izadji)
            }
            model.cekaPocetak && model.spremno -> Column(Modifier.align(Alignment.Center).padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp)) {
                CircularProgressIndicator(color = Boje.mastilo)
                Text("Domaćin postavlja mapu…", style = tekst(16.sp, FontWeight.SemiBold, Boje.sivaTekst))
            }
            !model.spremno -> CircularProgressIndicator(Modifier.align(Alignment.Center).semantics { contentDescription = "Učitavanje pitanja" }, color = Boje.mastilo)
            else -> Igra(model, { misija = true }) { potvrdaIzlaska = true }
        }

        model.poruka?.let { poruka ->
            Text(poruka, style = tekst(15.sp, FontWeight.Bold, Boje.tinta),
                modifier = Modifier.align(Alignment.TopCenter).padding(top = 150.dp, start = 24.dp, end = 24.dp).pop(Boje.zuta, 16.dp).padding(horizontal = 18.dp, vertical = 12.dp))
        }

        // Dodir mete otvara list: ime, vlasnik, zanimljivost, uslov bitke, pa Odustani ili Napadni.
        val izvor = model.izabrana
        val meta = model.meta
        if (izvor != null && meta != null && model.bitka == null) DonjiList(model::odustaniOdMete) { PanelNapada(model, izvor, meta) }

        AnimatedVisibility(model.bitka != null, enter = fadeIn(), exit = fadeOut()) {
            model.bitka?.let { BitkaEkran(model, it) }
        }
        if (misija) MisijaList(model) { misija = false; model.pocniPostavljanje() }
        if (model.stanje.faza == Faza.KRAJ) Kraj(model, izadji)
        if (potvrdaIzlaska) Dijalog("Napuštaš partiju?", "Partija se ne čuva.", "Izađi", "Ostani", potvrdi = izadji, zatvori = { potvrdaIzlaska = false })
    }
}

@Composable
private fun Igra(model: OsvajanjeModel, otvoriMisiju: () -> Unit, izlaz: () -> Unit) {
    val s = model.stanje
    Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(Modifier.padding(horizontal = 16.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            KrugIzlaz(izlaz)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                val krug = minOf(s.krug, s.ukupnoKrugova)
                Oznaka("Krug $krug od ${s.ukupnoKrugova}")
                Box(Modifier.fillMaxWidth().height(10.dp).background(Boje.kartica, RoundedCornerShape(5.dp)).border(1.5.dp, Boje.mastilo, RoundedCornerShape(5.dp))) {
                    Box(Modifier.fillMaxWidth(krug.toFloat() / s.ukupnoKrugova).height(10.dp).background(Boje.teal, RoundedCornerShape(5.dp)))
                }
            }
        }
        Row(Modifier.padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            s.igraci.take(4).forEachIndexed { i, p ->
                val naPotezu = p.id == s.trenutni.id && s.faza != Faza.KRAJ
                Row(
                    Modifier.weight(1f).alpha(if (p.ispao) 0.4f else 1f)
                        .background(Boje.kartica, RoundedCornerShape(14.dp))
                        .border(if (naPotezu) 2.5.dp else 1.5.dp, if (naPotezu) Boje.mastilo else Boje.kremTamnija, RoundedCornerShape(14.dp))
                        .padding(6.dp)
                        .semantics(mergeDescendants = true) { contentDescription = "${p.ime}, ${s.poeni(p.id)} poena${if (naPotezu) ", na potezu" else ""}" },
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Box(Modifier.size(36.dp).background(Color(p.boja), RoundedCornerShape(10.dp)), contentAlignment = Alignment.Center) {
                        MaskotaSlika(MASKOTE[i % MASKOTE.size], 30.dp)
                    }
                    Column {
                        Text(p.ime, style = tekst(12.sp, FontWeight.Bold), maxLines = 1)
                        Text("${s.poeni(p.id)}", style = naslov(16.sp))
                    }
                }
            }
        }
        val t = model.mojTim
        if (t != null && s.misije[t] != null) {
            Row(
                Modifier.padding(horizontal = 16.dp).fillMaxWidth().pop(Boje.zuta, 14.dp).clickable(onClick = otvoriMisiju).padding(horizontal = 12.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Icon(Icons.Rounded.Flag, contentDescription = "Tajna misija", tint = Boje.tinta)
                Text(Misije.tekst(s.misije[t]), style = tekst(13.sp, FontWeight.SemiBold, Boje.tinta), maxLines = 1, modifier = Modifier.weight(1f))
                Text("${(s.napredakMisije(t) * 100).toInt()}%", style = tekst(13.sp, FontWeight.Bold, Boje.tinta))
            }
        }
        model.kontinentiBezOdbrane.firstOrNull()?.let { k ->
            var otvoreno by remember { mutableStateOf(false) }
            Row(
                Modifier.padding(horizontal = 16.dp).fillMaxWidth().background(Boje.teal, RoundedCornerShape(14.dp)).border(2.dp, Boje.mastilo, RoundedCornerShape(14.dp))
                    .clickable { otvoreno = true }.padding(10.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Icon(Icons.Rounded.Shield, null, tint = Color.White)
                Text("Držiš ${k.ime}: izaberi odbranu", style = tekst(14.sp, FontWeight.Bold, Color.White))
            }
            if (otvoreno) DonjiList({ otvoreno = false }) {
                Text("Odbrana: ${k.ime}", style = naslov(24.sp))
                Odbrana.entries.forEach { o ->
                    RedIzbora(Icons.Rounded.Shield, "${o.naziv} · ${o.cena} vojske", o.opis, false) { model.postaviOdbranu(k.id, o); otvoreno = false }
                }
            }
        }
        MapaPrikaz(s, model.izabrana, model.mete, model.izabrana ?: s.igraci.firstOrNull { it.covek }?.prestonica,
            model::dodir, Modifier.weight(1f).fillMaxWidth().padding(horizontal = 12.dp), meta = model.meta, izvori = model.izvori)
        Column(Modifier.padding(horizontal = 16.dp).padding(bottom = 8.dp).fillMaxWidth().mirna().padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            run {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(model.uputstvo, style = tekst(15.sp, FontWeight.SemiBold), modifier = Modifier.weight(1f))
                    model.rokPoteza?.let { rok ->
                        // Odbrojavanje poteza: poslednjih 10 sekundi crveno.
                        var sada by remember { mutableLongStateOf(System.currentTimeMillis()) }
                        LaunchedEffect(rok) { while (true) { sada = System.currentTimeMillis(); delay(500) } }
                        val ostalo = ((rok - sada + 999) / 1000).coerceAtLeast(0)
                        Text("$ostalo s", style = naslov(18.sp, if (ostalo <= 10) Boje.crvena else Boje.sivaTekst),
                            modifier = Modifier.semantics { contentDescription = "Još $ostalo sekundi za potez" })
                    }
                }
                model.postavljanje?.let { p ->
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        Dugme("Ispočetka", Modifier.weight(1f), VrstaDugmeta.SEKUNDARNO, omoguceno = p.drzave.isNotEmpty(), radnja = model::ponistiPostavljanje)
                        if (p.drzave.size == Pravila.POCETNIH_DRZAVA && model.zaPostavljanje > 0)
                            Dugme("Rasporedi sam", Modifier.weight(1f), VrstaDugmeta.SEKUNDARNO, radnja = model::rasporediPostavljanjeSam)
                        else Dugme("Kreni", Modifier.weight(1f), omoguceno = p.drzave.size == Pravila.POCETNIH_DRZAVA && model.zaPostavljanje == 0, radnja = model::zavrsiPostavljanje)
                    }
                }
                if (model.covekNaPotezu && s.faza == Faza.RASPORED) Dugme("Rasporedi sam", vrsta = VrstaDugmeta.SEKUNDARNO, radnja = model::rasporediSam)
                if (model.covekNaPotezu && s.faza == Faza.NAPAD) {
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        if (!s.utvrdjeno) Dugme(if (model.utvrdjivanje) "Odustani" else "Utvrdi", Modifier.weight(1f), VrstaDugmeta.SEKUNDARNO, radnja = model::prekidacUtvrdjivanja)
                        Dugme("Kraj poteza", Modifier.weight(1f), radnja = model::krajPoteza)
                    }
                }
            }
        }
    }
}

/** 1 vojska, 2–4 vojske, 5+ vojski (i 21 vojska, 22 vojske…). */
private fun vojski(n: Int): String {
    val d = n % 10; val s = n % 100
    return "$n " + if (d == 1 && s != 11) "vojska" else if (d in 2..4 && s !in 12..14) "vojske" else "vojski"
}

/** Pre bitke: iz koje države, šta (prazno polje ili igrač), pod kojim uslovom i šta se rizikuje. */
@Composable
private fun PanelNapada(model: OsvajanjeModel, izvor: String, meta: String) {
    val s = model.stanje
    val cilj = s.oblasti[meta]
    val vlasnik = s.igraci.firstOrNull { it.tim == cilj?.vlasnik }
    val uslov = s.uslovBitke(meta)
    Oznaka(vlasnik?.let { "Drži ${it.ime}" } ?: "Prazno polje", vlasnik?.let { Color(it.boja) } ?: Boje.sivaTekst)
    Text(Mapa.oblast(meta).ime, style = naslov(34.sp))
    // Dve zanimljivosti; glavni grad je najmanje zanimljiv, pa ide poslednji.
    Cinjenice.za(meta).sortedBy { it.startsWith("Glavni grad") }.take(2).forEach { c ->
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Icon(Icons.Rounded.Lightbulb, null, tint = Boje.mastilo)
            Text(c, style = tekst(14.sp))
        }
    }
    RedDrzave("Napadaš iz", Mapa.oblast(izvor).ime, vojski(s.oblasti[izvor]?.vojske ?: 0), Color(s.trenutni.boja))
    RedDrzave("Brani", vlasnik?.ime ?: "Niko (prazno polje)", vojski(cilj?.vojske ?: 0), vlasnik?.let { Color(it.boja) } ?: Boje.kremTamnija)
    s.odbranaMete(meta)?.let { Text("Odbrana: ${it.naziv}", style = tekst(13.sp, FontWeight.Bold, Boje.crvena)) }
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Icon(if (vlasnik == null) Icons.Rounded.Flag else Icons.Rounded.Warning, null, tint = if (vlasnik == null) Boje.sivaTekst else Boje.crvena)
        Text(
            if (vlasnik == null) "${if (uslov.pitanja == 1) "Jedno pitanje" else "${uslov.pitanja} pitanja"}, ${uslov.sekundi} s. Ako pogrešiš, gubiš vojsku, a država ostaje prazna."
            else "${uslov.pitanja} pitanja po ${uslov.sekundi} s protiv igrača ${vlasnik.ime}. Ako izgubiš, ${vlasnik.ime} uzima ${Mapa.oblast(izvor).ime}.",
            style = tekst(13.sp, FontWeight.SemiBold, if (vlasnik == null) Boje.sivaTekst else Boje.crvena),
        )
    }
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Dugme("Odustani", Modifier.weight(1f), VrstaDugmeta.SEKUNDARNO, radnja = model::odustaniOdMete)
        Dugme("Napadni", Modifier.weight(1f), radnja = model::napadni)
    }
}

@Composable
private fun RedDrzave(oznaka: String, ime: String, opis: String, boja: Color) {
    Row(Modifier.semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Box(Modifier.size(14.dp).background(boja, RoundedCornerShape(4.dp)).border(1.5.dp, Boje.mastilo, RoundedCornerShape(4.dp)))
        Column(Modifier.weight(1f)) {
            Oznaka(oznaka)
            Text(ime, style = tekst(16.sp, FontWeight.Bold))
        }
        Text(opis, style = tekst(13.sp, FontWeight.SemiBold, Boje.sivaTekst))
    }
}

/** Bitka: uvod (država, vlasnik, odbrana, činjenice, odbrojavanje), pitanja sa 4 pomoći, rezultat. */
@Composable
private fun BitkaEkran(model: OsvajanjeModel, b: OsvajanjeModel.Bitka) {
    val drzava = Mapa.oblast(b.kuda)
    Box(Modifier.fillMaxSize().background(Boje.senka.copy(alpha = 0.96f)).clickable(enabled = false) {}) {
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().navigationBarsPadding().padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            when (b.korak) {
                OsvajanjeModel.Bitka.Korak.UVOD -> {
                    var odbrojavanje by remember(b.id) { mutableIntStateOf(4) }
                    LaunchedEffect(b.id) {
                        Zvuk.pusti(Zvuk.Vrsta.ODBROJAVANJE, 0.4f)
                        for (i in 3 downTo 0) { delay(1000); odbrojavanje = i }
                        delay(400)
                        model.pocniPitanja()
                    }
                    Column(Modifier.fillMaxWidth().pop(Boje.kartica, 26.dp).padding(20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Oznaka(if (b.napadam) "Napadaš" else "Braniš")
                        Text(drzava.ime, style = naslov(34.sp))
                        Text(if (b.napadam) "Iz: ${Mapa.oblast(b.odakle).ime} · drži: ${b.rivalIme}" else "Napada te ${b.rivalIme} iz: ${Mapa.oblast(b.odakle).ime}",
                            style = tekst(14.sp, FontWeight.SemiBold, Boje.sivaTekst))
                        Cinjenice.za(b.kuda).take(2).forEach { Text("• $it", style = tekst(14.sp)) }
                        model.stanje.odbranaMete(b.kuda)?.let { Text("Odbrana: ${it.naziv}. ${it.opis}", style = tekst(14.sp, FontWeight.Bold, Boje.crvena)) }
                        Text(if (b.uslov.pitanja > 1) "${b.uslov.pitanja} pitanja po ${b.uslov.sekundi} s. Više tačnih osvaja; kad je isto, brži."
                            else "Jedno pitanje od ${b.uslov.sekundi} s. Tačno osvaja neutralnu državu.", style = tekst(14.sp, boja = Boje.sivaTekst))
                        Box(Modifier.align(Alignment.CenterHorizontally).size(120.dp).background(Boje.zuta, CircleShape).border(3.dp, Boje.mastilo, CircleShape)
                            .semantics { contentDescription = "Počinje za $odbrojavanje" }, contentAlignment = Alignment.Center) {
                            Text(if (odbrojavanje > 0) "$odbrojavanje" else "Kreni!", style = naslov(if (odbrojavanje > 0) 54.sp else 26.sp, Boje.tinta))
                        }
                    }
                }
                OsvajanjeModel.Bitka.Korak.PITANJA -> {
                    val p = b.prikazi[b.redni]
                    var eliminisani by remember(b.id, b.redni, b.zamena) { mutableStateOf(setOf<Int>()) }
                    var dodatno by remember(b.id, b.redni, b.zamena) { mutableIntStateOf(0) }
                    Row {
                        Text(drzava.ime, style = naslov(22.sp, Color.White), modifier = Modifier.weight(1f))
                        Text("Tačno ${b.tacnih} od ${b.redni}", style = tekst(14.sp, FontWeight.Bold, Color.White))
                    }
                    key(b.id, b.redni, b.zamena) {
                        PitanjeKartica(if (b.prikazi.size > 1) "Pitanje ${b.redni + 1} od ${b.prikazi.size}" else "Bitka", p, b.uslov.sekundi + dodatno, eliminisani = eliminisani) { izabran, ms ->
                            model.odgovorUBitci(izabran, ms)
                        }
                    }
                    if (b.uslov.bezPomoci) {
                        Text("Odbrana „Bez pomoći”: ovde ne možeš da koristiš pomoć.", style = tekst(13.sp, FontWeight.SemiBold, Color.White))
                    } else {
                        val iskoriscena = model.pomocIskoriscena
                        fun netacni() = (0..3).filter { it != p.tacan && it !in eliminisani }
                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
                            PomocDugme(IkonicaPolaPola, "50/50", "polaPola", iskoriscena, eliminisani.isEmpty(), Modifier.weight(1f)) {
                                model.pomocIskoriscena = true; eliminisani = netacni().shuffled().take(2).toSet()
                            }
                            PomocDugme(Icons.Rounded.Lightbulb, "Nagoveštaj", "nagovestaj", iskoriscena, modifier = Modifier.weight(1f)) {
                                model.pomocIskoriscena = true; netacni().randomOrNull()?.let { eliminisani = eliminisani + it }
                            }
                            PomocDugme(Icons.Rounded.Timer, "Dodatno vreme", "vreme", iskoriscena, modifier = Modifier.weight(1f)) {
                                model.pomocIskoriscena = true; dodatno += 10
                            }
                            PomocDugme(Icons.Rounded.SkipNext, "Preskok", "preskok", iskoriscena, modifier = Modifier.weight(1f)) {
                                model.pomocIskoriscena = true; model.zameniPitanje()
                            }
                        }
                        Text(if (iskoriscena) "Pomoć je iskorišćena u ovoj partiji." else "Jedna pomoć po partiji, iz dnevnog fonda.",
                            style = tekst(12.sp, FontWeight.SemiBold, Color.White))
                    }
                }
                OsvajanjeModel.Bitka.Korak.REZULTAT -> {
                    val ishod = b.ishod
                    if (ishod == null) {
                        Column(Modifier.fillMaxWidth().pop(Boje.kartica, 26.dp).padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                            CircularProgressIndicator(color = Boje.mastilo)
                            Text("${b.rivalIme} odgovara…", style = tekst(15.sp, FontWeight.SemiBold))
                        }
                    } else {
                        val pobedio = if (b.napadam) ishod.osvojeno else !ishod.osvojeno
                        LaunchedEffect(b.id) { Zvuk.pusti(if (pobedio) Zvuk.Vrsta.OSVOJENO else Zvuk.Vrsta.NETACNO, 0.45f) }
                        val bojaTeksta = if (pobedio) Color.White else Boje.tinta
                        Column(
                            Modifier.fillMaxWidth().pop(if (pobedio) Boje.teal else Boje.narandzasta, 26.dp).padding(22.dp),
                            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            val naslovRezultata = if (b.napadam) { if (ishod.osvojeno) "Osvojio si ${drzava.ime}!" else "${drzava.ime} se odbranila" }
                                else { if (ishod.osvojeno) "${b.rivalIme} je osvojio ${drzava.ime}" else "Odbranio si ${drzava.ime}!" }
                            Text(naslovRezultata, style = naslov(30.sp, bojaTeksta), textAlign = TextAlign.Center)
                            b.rival?.let { r ->
                                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                    Skor("Ti", b.tacnih, b.ms, b.prikazi.size, pobedio, Modifier.weight(1f))
                                    Skor(b.rivalIme, r.tacnih, r.ms, b.prikazi.size, !pobedio, Modifier.weight(1f))
                                }
                            }
                            if (ishod.izgubljenaDrzava) Text(if (b.napadam) "${b.rivalIme} uzima ${Mapa.oblast(b.odakle).ime}" else "Uzimaš ${Mapa.oblast(b.odakle).ime}",
                                style = tekst(15.sp, FontWeight.Bold, bojaTeksta))
                            if (ishod.plen) Text("Prestonica pala: +${Pravila.PLEN_PRESTONICE} vojski", style = tekst(14.sp, FontWeight.Bold, bojaTeksta))
                            if (ishod.proboj) Text("Proboj: +${Pravila.PROBOJ_BONUS} vojske", style = tekst(14.sp, FontWeight.Bold, bojaTeksta))
                            Dugme("Nastavi", vrsta = VrstaDugmeta.SEKUNDARNO, radnja = model::zatvoriBitku)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun Skor(ime: String, tacnih: Int, ms: Int, od: Int, pobednik: Boolean, modifier: Modifier) {
    Column(
        modifier.background(if (pobednik) Boje.zuta else Color.White, RoundedCornerShape(16.dp)).border(2.dp, Boje.tinta, RoundedCornerShape(16.dp)).padding(vertical = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(ime, style = tekst(13.sp, FontWeight.Bold, Boje.tinta), maxLines = 1)
        Text("$tacnih/$od", style = naslov(30.sp, Boje.tinta))
        Text("%.1f s".format(ms / 1000.0), style = tekst(12.sp, FontWeight.SemiBold, Boje.tinta.copy(alpha = 0.75f)))
    }
}

@Composable
private fun MisijaList(model: OsvajanjeModel, zatvori: () -> Unit) {
    val s = model.stanje
    val t = model.mojTim ?: return
    DonjiList(zatvori) {
        Oznaka("Tajna misija · vidi je samo tvoj tim", Boje.roze)
        Text(Misije.tekst(s.misije[t]), style = naslov(26.sp))
        Text("Ispunjeno ${(s.napredakMisije(t) * 100).toInt()}%. Prva ispunjena misija odmah pobeđuje; inače posle poslednjeg kruga pobeđuje najviše poena.",
            style = tekst(14.sp, boja = Boje.sivaTekst))
        Dugme("Važi", radnja = zatvori)
    }
}

@Composable
private fun Kraj(model: OsvajanjeModel, izadji: () -> Unit) {
    val poredak = model.stanje.poredak
    val pobednik = poredak.first().first
    Box(Modifier.fillMaxSize().background(Boje.senka.copy(alpha = 0.6f)), contentAlignment = Alignment.Center) {
        Column(
            Modifier.padding(20.dp).pop(if (pobednik.covek) Boje.teal else Boje.kartica).padding(22.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            MaskotaSlika(if (pobednik.covek) Maskota.BLOOP else Maskota.MIMI, 120.dp)
            Text(if (pobednik.covek) "Svet je tvoj!" else "Pobeđuje ${pobednik.ime}", style = naslov(34.sp, if (pobednik.covek) Color.White else Boje.mastilo))
            poredak.forEachIndexed { i, (igrac, poeni) ->
                Row(Modifier.fillMaxWidth().pop(Boje.kartica, 16.dp).padding(12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text("${i + 1}.", style = tekst(15.sp, FontWeight.Bold))
                    Box(Modifier.size(16.dp).background(Color(igrac.boja), RoundedCornerShape(4.dp)))
                    Text(igrac.ime, style = tekst(16.sp, FontWeight.SemiBold), modifier = Modifier.weight(1f))
                    Text("$poeni", style = naslov(20.sp))
                }
            }
            Dugme("Nova partija", vrsta = VrstaDugmeta.ZUTO, radnja = model::novaPartija)
            Dugme("Nazad", vrsta = VrstaDugmeta.SEKUNDARNO, radnja = izadji)
        }
    }
}
