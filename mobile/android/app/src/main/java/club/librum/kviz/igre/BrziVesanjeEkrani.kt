package club.librum.kviz.igre

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.FavoriteBorder
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import club.librum.kviz.servisi.PaketPitanja
import club.librum.kviz.servisi.Pitanje
import club.librum.kviz.servisi.Rec
import club.librum.kviz.servisi.Sesija
import club.librum.kviz.servisi.Supabase
import club.librum.kviz.ui.Boje
import club.librum.kviz.ui.Dugme
import club.librum.kviz.ui.Maskota
import club.librum.kviz.ui.MaskotaSlika
import club.librum.kviz.ui.Oznaka
import club.librum.kviz.ui.Papir
import club.librum.kviz.ui.PomociTraka
import club.librum.kviz.ui.VrstaDugmeta
import club.librum.kviz.ui.mirna
import club.librum.kviz.ui.naslov
import club.librum.kviz.ui.pop
import club.librum.kviz.ui.tekst
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@Composable
internal fun KrugZatvori(opis: String, radnja: () -> Unit) {
    IconButton(onClick = radnja, modifier = Modifier.size(44.dp).background(Boje.kartica, CircleShape).border(1.5.dp, Boje.kremTamnija, CircleShape)) {
        Icon(Icons.Rounded.Close, contentDescription = opis, tint = Boje.mastilo)
    }
}

@Composable
internal fun Pokazatelj(naziv: String, vrednost: String, boja: Color, modifier: Modifier) {
    Column(
        modifier.background(boja, RoundedCornerShape(14.dp)).border(1.5.dp, Boje.mastilo, RoundedCornerShape(14.dp)).padding(vertical = 8.dp)
            .semantics(mergeDescendants = true) {},
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(vrednost, style = naslov(20.sp, if (boja == Boje.kartica) Boje.mastilo else Boje.tinta))
        Oznaka(naziv, if (boja == Boje.kartica) Boje.sivaTekst else Boje.tinta)
    }
}

@Composable
internal fun GreskaKartica(naslovTekst: String, poruka: String, nazad: () -> Unit) {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(Modifier.padding(24.dp).mirna().padding(24.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Text(naslovTekst, style = naslov(26.sp))
            Text(poruka, style = tekst(15.sp, boja = Boje.sivaTekst))
            Dugme("Nazad", radnja = nazad)
        }
    }
}

/** Brzi kviz: 60 sekundi, za svaku izjavu „tačno” ili „netačno”. */
@Composable
fun BrziKvizEkran(sesija: Sesija, izadji: () -> Unit) {
    val kontekst = LocalContext.current.applicationContext
    val opseg = rememberCoroutineScope()
    var igra by remember { mutableStateOf(BrziKviz()) }
    var pitanja by remember { mutableStateOf<List<Pitanje>>(emptyList()) }
    var indeks by remember { mutableIntStateOf(0) }
    var izjava by remember { mutableStateOf<BrziKviz.Izjava?>(null) }
    var otkriveno by remember { mutableStateOf<Boolean?>(null) }
    var pocetak by remember { mutableLongStateOf(System.currentTimeMillis()) }
    var pocetakIzjave by remember { mutableLongStateOf(System.currentTimeMillis()) }
    var sada by remember { mutableLongStateOf(System.currentTimeMillis()) }
    var kraj by remember { mutableStateOf(false) }
    var greska by remember { mutableStateOf<String?>(null) }
    var sacuvano by remember { mutableStateOf(false) }
    var pomocIskoriscena by remember { mutableStateOf(false) }
    var stit by remember { mutableStateOf(false) }
    var nagovestaj by remember { mutableStateOf<String?>(null) }

    fun sledeca() {
        if (pitanja.isEmpty()) return
        izjava = BrziKviz.Izjava.od(pitanja[indeks % pitanja.size]); indeks++
        otkriveno = null; nagovestaj = null; pocetakIzjave = System.currentTimeMillis()
    }
    suspend fun sacuvaj() {
        if (sacuvano || igra.tacnih + igra.netacnih == 0) return
        val id = sesija.nalog.value?.id ?: return
        val token = sesija.vazeciToken() ?: return
        sacuvano = true
        runCatching { Supabase.upisi("quick_sessions", igra.red(id, ((System.currentTimeMillis() - pocetak) / 1000).toInt()), token) }
    }
    suspend fun ucitaj() {
        runCatching { pitanja = PaketPitanja(kontekst).ucitaj() }.onFailure { greska = it.message; return }
        igra = BrziKviz(); indeks = 0; kraj = false; sacuvano = false; pomocIskoriscena = false; stit = false; pocetak = System.currentTimeMillis()
        sledeca()
    }
    fun odgovori(kaze: Boolean?) {
        val iz = izjava ?: return
        if (otkriveno != null || kraj) return
        otkriveno = igra.odgovor(iz, kaze, stit)
        if (stit && otkriveno == false) stit = false
        opseg.launch { delay(700); if (!kraj) sledeca() }
    }

    LaunchedEffect(Unit) { ucitaj() }
    LaunchedEffect(izjava, kraj) {
        while (!kraj && izjava != null) {
            sada = System.currentTimeMillis()
            if (sada - pocetak >= BrziKviz.SEKUNDI_RUNDE * 1000L) { kraj = true; sacuvaj() }
            else if (otkriveno == null && sada - pocetakIzjave >= BrziKviz.SEKUNDI_PO_IZJAVI * 1000L) odgovori(null)
            delay(250)
        }
    }
    BackHandler { opseg.launch { sacuvaj(); izadji() } }

    Box(Modifier.fillMaxSize()) {
        Papir()
        val iz = izjava
        when {
            greska != null -> GreskaKartica("Pitanja nisu stigla", greska.orEmpty(), izadji)
            kraj -> Column(
                Modifier.align(Alignment.Center).padding(20.dp).pop().padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                MaskotaSlika(Maskota.ZIG, 120.dp)
                Text("Vreme je isteklo", style = naslov(32.sp))
                Text("${igra.poeni}", style = naslov(64.sp))
                Text("${igra.tacnih} tačnih · ${igra.netacnih} netačnih", style = tekst(15.sp, FontWeight.SemiBold, Boje.sivaTekst))
                if (sesija.nalog.value == null) Text("Prijavi se da rezultat ode na rang listu.", style = tekst(14.sp, boja = Boje.sivaTekst))
                Dugme("Igraj ponovo", vrsta = VrstaDugmeta.ZUTO) { opseg.launch { ucitaj() } }
                Dugme("Nazad", vrsta = VrstaDugmeta.SEKUNDARNO, radnja = izadji)
            }
            iz == null -> CircularProgressIndicator(Modifier.align(Alignment.Center), color = Boje.mastilo)
            else -> Column(Modifier.fillMaxSize().statusBarsPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                val ostaloRunda = ((BrziKviz.SEKUNDI_RUNDE * 1000L - (sada - pocetak)) / 1000).coerceAtLeast(0)
                val ostaloIzjava = ((BrziKviz.SEKUNDI_PO_IZJAVI * 1000L - (sada - pocetakIzjave) + 999) / 1000).coerceAtLeast(0)
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                    KrugZatvori("Prekini") { opseg.launch { sacuvaj(); izadji() } }
                    Pokazatelj("Vreme", "$ostaloRunda", if (ostaloRunda < 10) Boje.crvenaSvetla else Boje.kartica, Modifier.weight(1f))
                    Pokazatelj("Poeni", "${igra.poeni}", Boje.zuta, Modifier.weight(1f))
                    Pokazatelj("Tačnih", "${igra.tacnih}", Boje.tealSvetla, Modifier.weight(1f))
                }
                Column(Modifier.fillMaxWidth().pop(Boje.zuta).padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    Row { Oznaka("Tačno ili netačno?", Boje.tinta); Spacer(Modifier.weight(1f)); Text("$ostaloIzjava", style = naslov(22.sp, Boje.tinta)) }
                    Text(iz.pitanje, style = naslov(22.sp, Boje.tinta))
                    Text(iz.prikazano, style = naslov(30.sp).copy(color = Boje.teal, textAlign = TextAlign.Center),
                        modifier = Modifier.fillMaxWidth().background(Boje.kartica, RoundedCornerShape(18.dp)).border(2.dp, Boje.mastilo, RoundedCornerShape(18.dp)).padding(vertical = 22.dp))
                    otkriveno?.let {
                        Text(if (it) "Tačno!" else "Ne. Tačan odgovor: ${iz.tacanOdgovor}", style = tekst(16.sp, FontWeight.Bold, if (it) Boje.teal else Boje.crvena))
                    }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Dugme("Netačno", Modifier.weight(1f), VrstaDugmeta.SEKUNDARNO, omoguceno = otkriveno == null) { odgovori(false) }
                    Dugme("Tačno", Modifier.weight(1f), VrstaDugmeta.PRIMARNO, omoguceno = otkriveno == null) { odgovori(true) }
                }
                nagovestaj?.takeIf { otkriveno == null }?.let { Text(it, style = tekst(14.sp, FontWeight.SemiBold)) }
                // Štit: sledeći promašaj se ne računa; nagoveštaj daje prvo slovo tačnog odgovora; vreme dodaje 10 s rundi.
                val slobodno = otkriveno == null
                PomociTraka(pomocIskoriscena, if (slobodno) ({ stit = true }) else null,
                    if (slobodno) ({ nagovestaj = "Tačan odgovor počinje na „${iz.tacanOdgovor.take(1).uppercase()}”." }) else null,
                    { pocetak += 10_000 }, if (slobodno) ({ sledeca() }) else null, polaPolaNaziv = "Štit") { pomocIskoriscena = true }
            }
        }
    }
}

/** Vešanje: pogodi pojam slovo po slovo, uz opis i kategoriju. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun VesanjeEkran(sesija: Sesija, izadji: () -> Unit) {
    val kontekst = LocalContext.current.applicationContext
    val opseg = rememberCoroutineScope()
    var reci by remember { mutableStateOf<List<Rec>>(emptyList()) }
    var indeks by remember { mutableIntStateOf(0) }
    var rec by remember { mutableStateOf<Rec?>(null) }
    var igra by remember { mutableStateOf(Vesanje("")) }
    var pocetak by remember { mutableLongStateOf(System.currentTimeMillis()) }
    var greska by remember { mutableStateOf<String?>(null) }
    var celaRec by remember { mutableStateOf(false) }
    var pokusaj by remember { mutableStateOf("") }
    var sacuvano by remember { mutableStateOf(false) }
    var unos by remember { mutableStateOf("") }
    var pomocIskoriscena by remember { mutableStateOf(false) }
    val fokus = remember { FocusRequester() }
    val tastatura = LocalSoftwareKeyboardController.current

    fun sledeca() {
        if (reci.isEmpty()) return
        unos = ""; pomocIskoriscena = false
        val r = reci[indeks % reci.size]; indeks++
        rec = r; igra = Vesanje(r.word); pocetak = System.currentTimeMillis(); sacuvano = false; celaRec = false
    }
    suspend fun sacuvaj() {
        val r = rec ?: return
        if (sacuvano) return
        val id = sesija.nalog.value?.id ?: return
        val token = sesija.vazeciToken() ?: return
        sacuvano = true
        runCatching { Supabase.upisi("hangman_sessions", igra.red(id, r.id, r.hint, r.category, ((System.currentTimeMillis() - pocetak) / 1000).toInt()), token) }
    }
    fun posle() { if (igra.status != Vesanje.Status.IGRA) opseg.launch { sacuvaj() } }

    LaunchedEffect(Unit) { runCatching { reci = PaketPitanja(kontekst).reci(); sledeca() }.onFailure { greska = it.message } }
    BackHandler(onBack = izadji)

    Box(Modifier.fillMaxSize()) {
        Papir()
        val r = rec
        when {
            greska != null -> GreskaKartica("Reči nisu stigle", greska.orEmpty(), izadji)
            r == null -> CircularProgressIndicator(Modifier.align(Alignment.Center), color = Boje.mastilo)
            else -> Column(
                Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    KrugZatvori("Izađi", izadji)
                    Spacer(Modifier.weight(1f))
                    Row(Modifier.semantics(mergeDescendants = true) { contentDescription = "${igra.zivoti} života" }) {
                        repeat(Vesanje.POCETNI_ZIVOTI) { i ->
                            Icon(if (i < igra.zivoti) Icons.Rounded.Favorite else Icons.Rounded.FavoriteBorder, null,
                                tint = if (i < igra.zivoti) Boje.crvena else Boje.kremTamnija)
                        }
                    }
                    Text("${igra.poeni}", style = naslov(22.sp), modifier = Modifier.padding(start = 10.dp))
                }
                Column(Modifier.fillMaxWidth().pop(Boje.zuta).padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            r.category?.let { Oznaka(it, Boje.tinta) }
                            r.hint?.let { Text(it, style = tekst(17.sp, FontWeight.SemiBold, Boje.tinta)) }
                        }
                        VesalaCrtez(Vesanje.POCETNI_ZIVOTI - igra.zivoti, igra.status == Vesanje.Status.PORAZ, Modifier.size(96.dp, 116.dp))
                    }
                    FlowRow(Modifier.fillMaxWidth().padding(vertical = 8.dp), horizontalArrangement = Arrangement.spacedBy(5.dp, Alignment.CenterHorizontally),
                        verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        igra.prikaz.forEach { z ->
                            if (z == " ") Spacer(Modifier.width(18.dp))
                            else Text(if (z == "_") " " else z, style = naslov(22.sp).copy(textAlign = TextAlign.Center),
                                modifier = Modifier.width(26.dp).height(36.dp).drawBehind {
                                    drawRect(Boje.mastilo, Offset(0f, size.height - 3.dp.toPx()), size.copy(height = 3.dp.toPx()))
                                })
                        }
                    }
                }
                if (igra.status == Vesanje.Status.IGRA) {
                    if (!celaRec) {
                        // Skriveno polje drži tastaturu telefona; svako slovo u polju je pokušaj, a već iskorišćena se preskaču,
                        // pa brzo kucanje i IME koji prepisuje kompoziciju ne gube slova.
                        BasicTextField(unos, { novo ->
                            novo.forEach { z ->
                                val slovo = z.toString().uppercase(java.util.Locale.forLanguageTag("sr-Latn"))
                                if (igra.status == Vesanje.Status.IGRA && slovo in Vesanje.AZBUKA && !igra.iskorisceno(slovo)) { igra.pogodi(slovo); posle() }
                            }
                            unos = novo
                        }, Modifier.size(1.dp).alpha(0.01f).focusRequester(fokus).semantics { contentDescription = "Otkucaj slovo" },
                            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Characters, autoCorrectEnabled = false))
                        LaunchedEffect(r.id) { delay(300); runCatching { fokus.requestFocus() }; tastatura?.show() }
                        val iskoriscena = Vesanje.AZBUKA.filter { igra.iskorisceno(it) }
                        if (iskoriscena.isNotEmpty()) FlowRow(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            iskoriscena.forEach { sl ->
                                val pogodak = r.word.uppercase(java.util.Locale.forLanguageTag("sr-Latn")).contains(sl)
                                Text(sl, style = tekst(18.sp, FontWeight.Bold, if (pogodak) Boje.teal else if (igra.ugaseno(sl)) Boje.kremTamnija else Boje.crvena),
                                    textDecoration = if (pogodak) null else TextDecoration.LineThrough)
                            }
                        }
                        Dugme("Kucaj slova", vrsta = VrstaDugmeta.SEKUNDARNO) { runCatching { fokus.requestFocus() }; tastatura?.show() }
                    }
                    if (celaRec) {
                        OutlinedTextField(pokusaj, { pokusaj = it }, Modifier.fillMaxWidth(), label = { Text("Cela reč") }, singleLine = true,
                            shape = RoundedCornerShape(14.dp), colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = Boje.mastilo, unfocusedBorderColor = Boje.mastilo,
                                focusedContainerColor = Boje.kartica, unfocusedContainerColor = Boje.kartica))
                        Dugme("Pogodi") { igra.pogodiRec(pokusaj); pokusaj = ""; celaRec = false; posle() }
                        Text("Pogrešna cela reč odnosi 2 života.", style = tekst(13.sp, boja = Boje.sivaTekst))
                    } else {
                        Dugme("Pogodi celu reč", vrsta = VrstaDugmeta.SEKUNDARNO) { tastatura?.hide(); celaRec = true }
                        // 50/50 gasi pola suvišnih slova, nagoveštaj otkriva slovo, umesto vremena vraća se život.
                        PomociTraka(pomocIskoriscena, { igra.skloniPolovinuSlova() }, { igra.otkrijSlovo(); posle() },
                            if (igra.zivoti < Vesanje.POCETNI_ZIVOTI) ({ igra.dodajZivot() }) else null, { sledeca() }, vremeJeZivot = true) { pomocIskoriscena = true }
                    }
                } else {
                    val pobeda = igra.status == Vesanje.Status.POBEDA
                    Column(Modifier.fillMaxWidth().pop(if (pobeda) Boje.tealSvetla else Boje.crvenaSvetla).padding(20.dp),
                        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Text(if (pobeda) "Bravo!" else "Kraj igre", style = naslov(30.sp))
                        Text(if (pobeda) "Pogodio/la si: ${r.word.uppercase()}" else "Reč je bila: ${r.word.uppercase()}", style = tekst(16.sp, FontWeight.SemiBold))
                        if (sesija.nalog.value == null) Text("Prijavi se da rezultat ode na rang listu.", style = tekst(14.sp, boja = Boje.sivaTekst))
                        Dugme("Sledeća reč", vrsta = VrstaDugmeta.ZUTO) { sledeca() }
                    }
                }
            }
        }
    }
}

/** Vešala: konstrukcija stalno, pa glava, telo, ruke i noge, deo po deo na svaki izgubljen život (kao iOS VesalaCrtez). */
@Composable
private fun VesalaCrtez(greske: Int, kraj: Boolean, modifier: Modifier) {
    Canvas(modifier.semantics { contentDescription = if (greske == 0) "Vešala, još nijedan promašaj" else "Vešala, $greske od ${Vesanje.POCETNI_ZIVOTI} delova" }) {
        val w = size.width; val h = size.height
        val debljina = 4.dp.toPx()
        fun linija(boja: Color, x1: Float, y1: Float, x2: Float, y2: Float) = drawLine(boja, Offset(w * x1, h * y1), Offset(w * x2, h * y2), debljina, StrokeCap.Round)
        linija(Boje.tinta, 0.08f, 0.96f, 0.62f, 0.96f); linija(Boje.tinta, 0.22f, 0.96f, 0.22f, 0.05f); linija(Boje.tinta, 0.22f, 0.05f, 0.72f, 0.05f)
        linija(Boje.tinta, 0.22f, 0.22f, 0.38f, 0.05f); linija(Boje.tinta, 0.72f, 0.05f, 0.72f, 0.17f)
        val boja = if (kraj) Boje.crvena else Boje.tinta
        val glava = h * 0.09f
        val vrat = (h * 0.17f + glava * 2) / h
        if (greske >= 1) drawCircle(boja, glava, Offset(w * 0.72f, h * 0.17f + glava), style = Stroke(debljina))
        if (greske >= 2) linija(boja, 0.72f, vrat, 0.72f, 0.62f)
        if (greske >= 3) linija(boja, 0.72f, vrat + 0.06f, 0.56f, vrat + 0.2f)
        if (greske >= 4) linija(boja, 0.72f, vrat + 0.06f, 0.88f, vrat + 0.2f)
        if (greske >= 5) linija(boja, 0.72f, 0.62f, 0.58f, 0.86f)
        if (greske >= 6) linija(boja, 0.72f, 0.62f, 0.86f, 0.86f)
    }
}
