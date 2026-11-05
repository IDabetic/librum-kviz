package club.librum.kviz.zajednica

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.automirrored.rounded.Send
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.ChatBubbleOutline
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.FavoriteBorder
import androidx.compose.material.icons.rounded.Flag
import androidx.compose.material.icons.rounded.Sensors
import androidx.compose.material.icons.rounded.RadioButtonUnchecked
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Forum
import androidx.compose.material.icons.rounded.Groups
import androidx.compose.material.icons.rounded.MoreHoriz
import androidx.compose.material.icons.rounded.Notes
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material.icons.rounded.Block
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import club.librum.kviz.servisi.Napredak
import club.librum.kviz.servisi.Sesija
import club.librum.kviz.servisi.Supabase
import club.librum.kviz.ui.AvatarSlika
import club.librum.kviz.ui.Boje
import club.librum.kviz.ui.Dijalog
import club.librum.kviz.ui.DonjiList
import club.librum.kviz.ui.Dugme
import club.librum.kviz.ui.Izbor
import club.librum.kviz.ui.Maskota
import club.librum.kviz.ui.MaskotaSlika
import club.librum.kviz.ui.Oznaka
import club.librum.kviz.ui.Papir
import club.librum.kviz.ui.VrstaDugmeta
import club.librum.kviz.ui.mirna
import club.librum.kviz.ui.naslov
import club.librum.kviz.ui.tekst
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import java.text.NumberFormat
import java.time.Duration
import java.time.OffsetDateTime
import java.util.Locale

/** Društvena mreža kviza (scripts/2026-11-03_drustvena-mreza.sql), isto kao iOS Zajednica.swift. */
object Zajednica {
    @Serializable data class Objava(
        val id: Long, val ko: String, val nadimak: String, val avatar: String? = null, val vrsta: String, val igra: String? = null,
        val tekst: String, val poeni: Int? = null, val kod_sobe: String? = null, val created_at: String,
        val srca: Int, val moje_srce: Boolean, val komentara: Int, val moja: Boolean,
    )
    @Serializable data class Komentar(
        val id: Long, val roditelj: Long? = null, val ko: String, val nadimak: String, val avatar: String? = null, val tekst: String,
        val created_at: String, val srca: Int, val moje_srce: Boolean, val moj: Boolean,
    )
    @Serializable data class Razgovor(val sa: String, val nadimak: String, val avatar: String? = null, val poslednja: String, val kad: String, val moja: Boolean, val neprocitanih: Int)
    @Serializable data class Poruka(val id: Long, val moja: Boolean, val tekst: String, val created_at: String)
    @Serializable data class Igra(val ko: String, val nadimak: String, val avatar: String? = null, val igra: String, val poeni: Int, val kad: String)
    @Serializable data class Srce(val moje_srce: Boolean, val srca: Int)

    val vrste = listOf(Triple("tekst", "Objava", Icons.Rounded.Notes), Triple("rezultat", "Moj rezultat", Icons.Rounded.EmojiEvents),
        Triple("poziv_duel", "Poziv na duel", Icons.Rounded.Bolt), Triple("poziv_tim", "Tražim tim", Icons.Rounded.Groups))
    fun nazivVrste(v: String) = vrste.firstOrNull { it.first == v }?.second ?: "Objava"
    fun ikonicaVrste(v: String): ImageVector = vrste.firstOrNull { it.first == v }?.third ?: Icons.Rounded.Notes
    val nazivIgre = mapOf("dnevni" to "Dnevni izazov", "osvajanje" to "Osvajač", "pro" to "PRO kviz", "book" to "Book kviz", "duel" to "Duel",
        "slikari" to "Slikari", "brzi" to "Brzi kviz", "vesanje" to "Vešanje", "tema" to "Kviz po temi", "karijera" to "Karijerista", "kafana" to "Kafanski kviz")

    private inline fun <reified T> citaj(s: String): T = Supabase.json.decodeFromString(s)

    suspend fun tok(s: Sesija, vrsta: String, pre: Long? = null): List<Objava> =
        citaj(Supabase.rpc("tok_objava", mapOf("p_vrsta" to vrsta, "p_pre" to pre, "p_broj" to 20), s.vazeciToken()))
    suspend fun koStaIgra(s: Sesija): List<Igra> = runCatching { citaj<List<Igra>>(Supabase.rpc("ko_sta_igra", mapOf("p_broj" to 20), s.vazeciToken())) }.getOrDefault(emptyList())
    /** Poslednja partija za „Moj rezultat” (izvor r:<id> ili k:<id>); server iz izvora upisuje igru i poene. */
    @Serializable data class MojRezultat(val izvor: String, val igra: String, val poeni: Int, val tacnih: Int? = null, val kad: String)
    suspend fun mojiRezultati(s: Sesija): List<MojRezultat> =
        runCatching { citaj<List<MojRezultat>>(Supabase.rpc("moji_poslednji_rezultati", mapOf("p_broj" to 15), s.vazeciToken())) }.getOrDefault(emptyList())
    suspend fun objavi(s: Sesija, vrsta: String, tekst: String, igra: String?, rezultat: String?) {
        Supabase.rpc("nova_objava", mapOf("p_vrsta" to vrsta, "p_tekst" to tekst, "p_igra" to igra, "p_rezultat" to rezultat), s.vazeciToken())
    }
    suspend fun srceObjavi(s: Sesija, id: Long): Srce? = runCatching { citaj<Srce>(Supabase.rpc("srce_objavi", mapOf("p_id" to id), s.vazeciToken())) }.getOrNull()
    suspend fun srceKomentaru(s: Sesija, id: Long): Srce? = runCatching { citaj<Srce>(Supabase.rpc("srce_komentaru", mapOf("p_id" to id), s.vazeciToken())) }.getOrNull()
    suspend fun komentari(s: Sesija, objava: Long): List<Komentar> = citaj(Supabase.rpc("komentari_objave", mapOf("p_objava" to objava), s.vazeciToken()))
    suspend fun komentarisi(s: Sesija, objava: Long, tekst: String, roditelj: Long?) {
        Supabase.rpc("novi_komentar", mapOf("p_objava" to objava, "p_tekst" to tekst, "p_roditelj" to roditelj), s.vazeciToken())
    }
    /** Radnje bez odgovora (brisanje, blokada, prijava): true kad nije bilo greške. */
    suspend fun radnja(s: Sesija, funkcija: String, p: Map<String, Any?>): Boolean = runCatching { Supabase.rpc(funkcija, p, s.vazeciToken()) }.isSuccess
    suspend fun razgovori(s: Sesija): List<Razgovor> = citaj(Supabase.rpc("moji_razgovori", emptyMap(), s.vazeciToken()))
    suspend fun poruke(s: Sesija, sa: String): List<Poruka> = citaj(Supabase.rpc("poruke_sa", mapOf("p_sa" to sa), s.vazeciToken()))
    suspend fun posaljiPoruku(s: Sesija, za: String, tekst: String) { Supabase.rpc("posalji_poruku", mapOf("p_za" to za, "p_tekst" to tekst), s.vazeciToken()) }

    /** „pre 5 min”, „pre 2 d.”: vreme objave, komentara i poruke. */
    fun pre(iso: String): String {
        val d = runCatching { Duration.between(OffsetDateTime.parse(iso), OffsetDateTime.now()) }.getOrNull() ?: return ""
        return when {
            d.toMinutes() < 1 -> "upravo"
            d.toMinutes() < 60 -> "pre ${d.toMinutes()} min"
            d.toHours() < 24 -> "pre ${d.toHours()} č."
            else -> "pre ${d.toDays()} d."
        }
    }
    fun broj(n: Int): String = NumberFormat.getIntegerInstance(Locale.forLanguageTag("sr-Latn-RS")).format(n)
}

/** Kartica „Igrači”: ko šta igra, tok objava (svi ili koje pratim), poruke i nova objava. */
@Composable
fun IgraciEkran(sesija: Sesija, idi: (String) -> Unit) {
    val nalog by sesija.nalog.collectAsState()
    val napredak = Napredak.deljeni
    var vrsta by remember { mutableIntStateOf(0) }
    var objave by remember { mutableStateOf<List<Zajednica.Objava>?>(null) }
    var greska by remember { mutableStateOf<String?>(null) }
    var igraju by remember { mutableStateOf<List<Zajednica.Igra>>(emptyList()) }
    var nova by remember { mutableStateOf(false) }
    var pravila by remember { mutableStateOf(false) }
    var komentariZa by remember { mutableStateOf<Zajednica.Objava?>(null) }
    val opseg = rememberCoroutineScope()
    val kljuc = if (vrsta == 0) "svi" else "pratim"

    suspend fun ucitaj() {
        runCatching { Zajednica.tok(sesija, kljuc) }.onSuccess { objave = it; greska = null }.onFailure { if (objave == null) greska = it.message }
    }
    LaunchedEffect(kljuc, nalog?.id) { ucitaj() }
    LaunchedEffect(nalog?.id) { igraju = Zajednica.koStaIgra(sesija) }

    Box(Modifier.fillMaxSize()) {
        Papir()
        LazyColumn(Modifier.fillMaxSize().statusBarsPadding(), contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            item {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Igrači", style = naslov(34.sp), modifier = Modifier.weight(1f))
                    // Na mreži (vlasnik 05.11): svi igrači koji su sada u aplikaciji.
                    KrugIkonica(Icons.Rounded.Sensors, "Igrači na mreži") { idi("namrezi") }
                    Spacer(Modifier.width(10.dp))
                    KrugIkonica(Icons.Rounded.Search, "Nađi igrače") { idi("igraci/trazi") }
                    Spacer(Modifier.width(10.dp))
                    KrugIkonica(Icons.AutoMirrored.Rounded.Send, "Poruke") { idi("poruke") }
                }
            }
            if (igraju.isNotEmpty()) item {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Oznaka("Ko šta igra")
                    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        igraju.forEach { g ->
                            Column(Modifier.width(76.dp).clickable { idi("igrac/${g.ko}") }, horizontalAlignment = Alignment.CenterHorizontally) {
                                AvatarSlika(g.avatar, 54.dp)
                                Text(g.nadimak, style = tekst(12.sp, FontWeight.Bold), maxLines = 1)
                                Text(Zajednica.nazivIgre[g.igra] ?: g.igra, style = tekst(11.sp, boja = Boje.sivaTekst), maxLines = 1)
                                Text(Zajednica.broj(g.poeni), style = tekst(11.sp, FontWeight.Bold))
                            }
                        }
                    }
                }
            }
            item {
                Row(
                    Modifier.fillMaxWidth().height(60.dp).mirna().clickable {
                        when { nalog == null -> idi("profil"); napredak.s.pravilaZajednice -> nova = true; else -> pravila = true }
                    }.padding(horizontal = 14.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    AvatarSlika(nalog?.avatar, 40.dp)
                    Text("Pozovi na duel, traži tim ili podeli rezultat…", style = tekst(15.sp, boja = Boje.sivaTekst), maxLines = 1, modifier = Modifier.weight(1f))
                    Icon(Icons.Rounded.Add, null, tint = Boje.mastilo)
                }
            }
            item { Izbor(listOf("Svi", "Koje pratim"), vrsta) { vrsta = it } }
            val l = objave
            when {
                greska != null && l == null -> item {
                    Column(Modifier.fillMaxWidth().mirna().padding(20.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        MaskotaSlika(Maskota.LUMI, 100.dp)
                        Text("Objave se nisu učitale", style = naslov(22.sp))
                        Dugme("Pokušaj ponovo") { opseg.launch { ucitaj() } }
                    }
                }
                l == null -> item { Box(Modifier.fillMaxWidth().padding(30.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = Boje.mastilo) } }
                l.isEmpty() -> item {
                    Column(Modifier.fillMaxWidth().mirna().padding(20.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        MaskotaSlika(Maskota.BLOOP, 100.dp)
                        Text(if (vrsta == 1) "Igrači koje pratiš još ćute" else "Još nema objava", style = naslov(22.sp))
                        Text("Budi prvi: pozovi nekog na duel ili podeli rezultat.", style = tekst(14.sp, boja = Boje.sivaTekst))
                    }
                }
                else -> items(l, key = { it.id }) { o ->
                    KarticaObjave(sesija, o, idi, komentari = { komentariZa = o }, promena = { n -> objave = objave?.map { if (it.id == n.id) n else it } },
                        nestala = { objave = objave?.filter { it.id != o.id } })
                }
            }
            item { Spacer(Modifier.height(80.dp)) }
        }
        if (pravila) PravilaZajednice(prihvati = { napredak.podesi { pravilaZajednice = true }; pravila = false; nova = true }, odustani = { pravila = false })
        if (nova) NovaObjava(sesija, zatvori = { nova = false }) { opseg.launch { ucitaj() } }
        komentariZa?.let { o -> Komentari(sesija, o, zatvori = { komentariZa = null }) { broj -> objave = objave?.map { if (it.id == o.id) it.copy(komentara = broj) else it } } }
    }
}

@Composable
private fun KrugIkonica(ikonica: ImageVector, opis: String, radnja: () -> Unit) {
    IconButton(onClick = radnja, modifier = Modifier.size(44.dp).background(Boje.kartica, CircleShape).border(1.5.dp, Boje.kremTamnija, CircleShape)) {
        Icon(ikonica, contentDescription = opis, tint = Boje.mastilo)
    }
}

@Composable
fun KarticaObjave(sesija: Sesija, o: Zajednica.Objava, idi: (String) -> Unit, komentari: () -> Unit, promena: (Zajednica.Objava) -> Unit, nestala: () -> Unit) {
    val nalog by sesija.nalog.collectAsState()
    val opseg = rememberCoroutineScope()
    var meni by remember { mutableStateOf(false) }
    var potvrda by remember { mutableStateOf<String?>(null) }
    Column(Modifier.fillMaxWidth().mirna().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(Modifier.weight(1f).clickable { idi("igrac/${o.ko}") }, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                AvatarSlika(o.avatar, 40.dp)
                Column {
                    Text(o.nadimak, style = tekst(15.sp, FontWeight.Bold), maxLines = 1)
                    Text(Zajednica.pre(o.created_at), style = tekst(12.sp, boja = Boje.sivaTekst))
                }
            }
            if (o.vrsta != "tekst") Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                Icon(Zajednica.ikonicaVrste(o.vrsta), null, tint = Boje.teal, modifier = Modifier.size(16.dp))
                Text(Zajednica.nazivVrste(o.vrsta), style = tekst(12.sp, FontWeight.Bold, Boje.teal))
            }
            if (nalog != null) IconButton(onClick = { meni = true }) { Icon(Icons.Rounded.MoreHoriz, contentDescription = "Više", tint = Boje.sivaTekst) }
        }
        if (o.tekst.isNotEmpty()) Text(o.tekst, style = tekst(16.sp))
        if (o.vrsta == "rezultat" && o.igra != null) {
            Row(Modifier.fillMaxWidth().background(Boje.udubljeno, RoundedCornerShape(14.dp)).padding(12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Box(Modifier.size(44.dp).background(Boje.zuta, RoundedCornerShape(12.dp)), contentAlignment = Alignment.Center) { Icon(Icons.Rounded.EmojiEvents, null, tint = Boje.tinta) }
                Column {
                    Text(Zajednica.nazivIgre[o.igra] ?: o.igra, style = tekst(14.sp, FontWeight.SemiBold))
                    Text("${Zajednica.broj(o.poeni ?: 0)} poena", style = naslov(22.sp))
                }
            }
        }
        if (!o.moja && nalog != null && (o.vrsta == "poziv_duel" || o.vrsta == "poziv_tim")) {
            Dugme(if (o.vrsta == "poziv_duel") "Prihvati duel" else "Javi se", vrsta = VrstaDugmeta.ZUTO) {
                if (o.vrsta == "poziv_duel") idi("duel/izazov/${o.ko}") else idi("razgovor/${o.ko}/${o.nadimak}")
            }
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(22.dp)) {
            Row(Modifier.clickable(enabled = nalog != null) { opseg.launch { Zajednica.srceObjavi(sesija, o.id)?.let { promena(o.copy(srca = it.srca, moje_srce = it.moje_srce)) } } }
                .semantics { contentDescription = if (o.moje_srce) "Ne sviđa mi se više, ${o.srca}" else "Sviđa mi se, ${o.srca}" },
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Icon(if (o.moje_srce) Icons.Rounded.Favorite else Icons.Rounded.FavoriteBorder, null, tint = if (o.moje_srce) Boje.roze else Boje.mastilo)
                if (o.srca > 0) Text("${o.srca}", style = tekst(15.sp, FontWeight.SemiBold))
            }
            Row(Modifier.clickable(onClick = komentari).semantics { contentDescription = "Komentari, ${o.komentara}" },
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Icon(Icons.Rounded.ChatBubbleOutline, null, tint = Boje.mastilo)
                if (o.komentara > 0) Text("${o.komentara}", style = tekst(15.sp, FontWeight.SemiBold))
            }
        }
    }
    if (meni) DonjiList({ meni = false }) {
        if (o.moja) StavkaMenija("Obriši objavu", Icons.Rounded.Delete, opasno = true) { meni = false; potvrda = "brisanje" }
        else {
            StavkaMenija("Pošalji poruku", Icons.AutoMirrored.Rounded.Send) { meni = false; idi("razgovor/${o.ko}/${o.nadimak}") }
            StavkaMenija("Prijavi objavu", Icons.Rounded.Flag) {
                meni = false; opseg.launch { Zajednica.radnja(sesija, "prijavi_sadrzaj", mapOf("p_objava" to o.id, "p_komentar" to null, "p_razlog" to "neprikladno")); potvrda = "hvala" }
            }
            StavkaMenija("Blokiraj ${o.nadimak}", Icons.Rounded.Block, opasno = true) { meni = false; potvrda = "blokada" }
        }
    }
    when (potvrda) {
        "brisanje" -> Dijalog("Obrisati objavu?", "Objava i komentari ispod nje nestaju za sve.", "Obriši", "Odustani",
            potvrdi = { potvrda = null; opseg.launch { if (Zajednica.radnja(sesija, "obrisi_objavu", mapOf("p_id" to o.id))) nestala() } }, zatvori = { potvrda = null })
        "blokada" -> Dijalog("Blokirati ${o.nadimak}?", "Više se nećete videti: ni objave, ni komentari, ni poruke. Praćenje se briše.", "Blokiraj", "Odustani",
            potvrdi = { potvrda = null; opseg.launch { if (Zajednica.radnja(sesija, "blokiraj", mapOf("p_id" to o.ko, "p_da" to true))) nestala() } }, zatvori = { potvrda = null })
        "hvala" -> Dijalog("Hvala na prijavi", "Posle tri prijave objava se sakriva dok je urednik ne pregleda.", "U redu", "Zatvori",
            potvrdi = { potvrda = null }, zatvori = { potvrda = null })
    }
}

@Composable
private fun StavkaMenija(naziv: String, ikonica: ImageVector, opasno: Boolean = false, radnja: () -> Unit) {
    Row(Modifier.fillMaxWidth().clickable(onClick = radnja).padding(vertical = 14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Icon(ikonica, null, tint = if (opasno) Boje.crvena else Boje.mastilo)
        Text(naziv, style = tekst(16.sp, FontWeight.SemiBold, if (opasno) Boje.crvena else Boje.mastilo))
    }
}

@Composable
fun PravilaZajednice(prihvati: () -> Unit, odustani: () -> Unit) {
    val pravila = listOf(
        "Bez uvreda, pretnji i govora mržnje. Ni prema kome, ni u šali.",
        "Bez golotinje, nasilja i sadržaja neprikladnog za decu.",
        "Bez reklama, prevara i lažnih profila.",
        "Ne objavljuj tuđe lične podatke: telefon, adresu, mejl.",
        "Prijavi što krši pravila; tri prijave sakrivaju objavu odmah, urednik pregleda u roku od 24 h.",
        "Ko krši pravila gubi pravo na objave, a nalog može biti ugašen.",
    )
    DonjiList(odustani) {
        Text("Pravila zajednice", style = naslov(26.sp))
        Text("Igrači je prostor za izazove, rezultate i druženje. Pre prve objave prihvati pravila:", style = tekst(14.sp, boja = Boje.sivaTekst))
        pravila.forEach { p -> Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) { Text("•", style = tekst(15.sp, FontWeight.Bold, Boje.teal)); Text(p, style = tekst(15.sp)) } }
        Dugme("Prihvatam", radnja = prihvati)
    }
}

@Composable
private fun NovaObjava(sesija: Sesija, zatvori: () -> Unit, objavljeno: () -> Unit) {
    var vrsta by remember { mutableStateOf("poziv_duel") }
    var igra by remember { mutableStateOf("osvajanje") }
    var tekst by remember { mutableStateOf("") }
    var rezultati by remember { mutableStateOf<List<Zajednica.MojRezultat>?>(null) }
    var izabran by remember { mutableStateOf<Zajednica.MojRezultat?>(null) }
    var greska by remember { mutableStateOf<String?>(null) }
    val opseg = rememberCoroutineScope()
    LaunchedEffect(vrsta) { if (vrsta == "rezultat" && rezultati == null) Zajednica.mojiRezultati(sesija).also { rezultati = it; izabran = it.firstOrNull() } }
    val igre = listOf("osvajanje", "duel", "pro", "slikari", "book", "brzi", "vesanje", "dnevni")
    DonjiList(zatvori) {
        Text("Nova objava", style = naslov(24.sp))
        Zajednica.vrste.chunked(2).forEach { red ->
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                red.forEach { (k, naziv, ik) ->
                    val izabrano = vrsta == k
                    Column(
                        Modifier.weight(1f).height(72.dp).background(if (izabrano) Boje.zuta else Boje.kartica, RoundedCornerShape(16.dp))
                            .border(if (izabrano) 2.5.dp else 1.5.dp, if (izabrano) Boje.mastilo else Boje.kremTamnija, RoundedCornerShape(16.dp)).clickable { vrsta = k },
                        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center,
                    ) {
                        Icon(ik, null, tint = if (izabrano) Boje.tinta else Boje.mastilo)
                        Text(naziv, style = tekst(14.sp, FontWeight.Bold, if (izabrano) Boje.tinta else Boje.mastilo))
                    }
                }
            }
        }
        if (vrsta != "tekst" && vrsta != "rezultat") {
            Text("Igra", style = tekst(14.sp, FontWeight.SemiBold))
            Row(Modifier.horizontalScroll(rememberScrollState())) { Izbor(igre.map { Zajednica.nazivIgre[it] ?: it }, igre.indexOf(igra)) { igra = igre[it] } }
        }
        // Stvarni rezultat iz poslednjih partija (vlasnik 05.11), poeni se ne kucaju.
        if (vrsta == "rezultat") {
            Text("Izaberi rezultat", style = tekst(14.sp, FontWeight.SemiBold))
            val l = rezultati
            when {
                l == null -> CircularProgressIndicator(color = Boje.mastilo)
                l.isEmpty() -> Text("Još nemaš odigranih partija. Odigraj jednu, pa se vrati da je podeliš.", style = tekst(14.sp, boja = Boje.sivaTekst))
                else -> Column(Modifier.fillMaxWidth().background(Boje.kartica, RoundedCornerShape(16.dp)).border(1.5.dp, Boje.kremTamnija, RoundedCornerShape(16.dp))) {
                    l.forEach { r ->
                        Row(Modifier.fillMaxWidth().clickable { izabran = r }.padding(horizontal = 12.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            Icon(if (izabran == r) Icons.Rounded.CheckCircle else Icons.Rounded.RadioButtonUnchecked, null, tint = if (izabran == r) Boje.teal else Boje.kremTamnija)
                            Column(Modifier.weight(1f)) {
                                Text(Zajednica.nazivIgre[r.igra] ?: r.igra, style = tekst(15.sp, FontWeight.SemiBold))
                                Text(Zajednica.pre(r.kad) + (r.tacnih?.let { " · $it tačnih" } ?: ""), style = tekst(12.sp, boja = Boje.sivaTekst))
                            }
                            Text(Zajednica.broj(r.poeni), style = naslov(20.sp))
                        }
                    }
                }
            }
        }
        PoljeTeksta(tekst, when (vrsta) { "poziv_duel" -> "Ko sme na duel iz geografije?"; "poziv_tim" -> "Tražim saigrača za Osvajača"; "rezultat" -> "Ovo mi je novi rekord!"; else -> "Šta ima novo?" }, visina = 110) { tekst = it.take(500) }
        greska?.let { Text(it, style = tekst(14.sp, FontWeight.SemiBold, Boje.crvena)) }
        Dugme("Objavi", omoguceno = (vrsta != "tekst" || tekst.isNotBlank()) && (vrsta != "rezultat" || izabran != null)) {
            opseg.launch {
                runCatching { Zajednica.objavi(sesija, vrsta, tekst, if (vrsta == "tekst" || vrsta == "rezultat") null else igra, if (vrsta == "rezultat") izabran?.izvor else null) }
                    .onSuccess { objavljeno(); zatvori() }.onFailure { greska = it.message }
            }
        }
    }
}

@Composable
fun PoljeTeksta(vrednost: String, primer: String, visina: Int = 0, promena: (String) -> Unit) {
    Box(Modifier.fillMaxWidth().background(Boje.kartica, RoundedCornerShape(14.dp)).border(1.5.dp, Boje.kremTamnija, RoundedCornerShape(14.dp)).padding(14.dp)
        .then(if (visina > 0) Modifier.height(visina.dp) else Modifier)) {
        if (vrednost.isEmpty()) Text(primer, style = tekst(16.sp, boja = Boje.sivaTekst))
        BasicTextField(vrednost, promena, textStyle = tekst(16.sp), cursorBrush = SolidColor(Boje.mastilo), modifier = Modifier.fillMaxWidth())
    }
}

/** Komentari u granama (odgovor ispod roditelja, najviše tri nivoa), srca, brisanje i prijava. */
@Composable
private fun Komentari(sesija: Sesija, objava: Zajednica.Objava, zatvori: () -> Unit, promenjenBroj: (Int) -> Unit) {
    val nalog by sesija.nalog.collectAsState()
    val napredak = Napredak.deljeni
    var lista by remember { mutableStateOf<List<Zajednica.Komentar>?>(null) }
    var tekst by remember { mutableStateOf("") }
    var odgovorNa by remember { mutableStateOf<Zajednica.Komentar?>(null) }
    var pravila by remember { mutableStateOf(false) }
    val opseg = rememberCoroutineScope()
    suspend fun ucitaj() { runCatching { Zajednica.komentari(sesija, objava.id) }.onSuccess { lista = it; promenjenBroj(it.size) } }
    LaunchedEffect(objava.id) { ucitaj() }
    fun posalji() {
        if (!napredak.s.pravilaZajednice) { pravila = true; return }
        val t = tekst; tekst = ""
        opseg.launch { runCatching { Zajednica.komentarisi(sesija, objava.id, t, odgovorNa?.id) }.onSuccess { odgovorNa = null; ucitaj() }.onFailure { tekst = t } }
    }
    Box(Modifier.fillMaxSize().background(Boje.krem)) {
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().imePadding()) {
            Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                KrugIkonica(Icons.AutoMirrored.Rounded.ArrowBack, "Nazad", zatvori)
                Text("Komentari", style = naslov(22.sp), modifier = Modifier.padding(start = 12.dp))
            }
            val deca = lista.orEmpty().filter { it.roditelj != null }.groupBy { it.roditelj }
            fun grana(k: Zajednica.Komentar, d: Int): List<Pair<Zajednica.Komentar, Int>> = listOf(k to minOf(d, 3)) + (deca[k.id] ?: emptyList()).flatMap { grana(it, d + 1) }
            val redovi = lista.orEmpty().filter { it.roditelj == null }.flatMap { grana(it, 0) }
            LazyColumn(Modifier.weight(1f).padding(horizontal = 16.dp)) {
                if (lista == null) item { CircularProgressIndicator(color = Boje.mastilo) }
                // Prazno stanje u sredini slobodnog prostora, kao na iOS-u (vlasnik 05.11).
                else if (redovi.isEmpty()) item {
                    Column(Modifier.fillParentMaxSize(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                        Icon(Icons.Rounded.Forum, null, tint = Boje.sivaTekst, modifier = Modifier.size(32.dp))
                        Text("Još nema komentara", style = tekst(17.sp, FontWeight.Bold), modifier = Modifier.padding(top = 6.dp))
                        Text("Budi prvi koji će nešto reći.", style = tekst(14.sp, boja = Boje.sivaTekst))
                    }
                }
                items(redovi, key = { it.first.id }) { (k, d) ->
                    Row(Modifier.fillMaxWidth().padding(start = (d * 22).dp, top = 10.dp, bottom = 10.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        AvatarSlika(k.avatar, if (d == 0) 36.dp else 28.dp)
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                Text(k.nadimak, style = tekst(14.sp, FontWeight.Bold))
                                Text(Zajednica.pre(k.created_at), style = tekst(12.sp, boja = Boje.sivaTekst))
                            }
                            Text(k.tekst, style = tekst(15.sp))
                            if (nalog != null) Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                                Text("Odgovori", style = tekst(13.sp, FontWeight.Bold, Boje.sivaTekst), modifier = Modifier.clickable { odgovorNa = k })
                                if (k.moj) Text("Obriši", style = tekst(13.sp, FontWeight.Bold, Boje.crvena),
                                    modifier = Modifier.clickable { opseg.launch { if (Zajednica.radnja(sesija, "obrisi_komentar", mapOf("p_id" to k.id))) ucitaj() } })
                                else Text("Prijavi", style = tekst(13.sp, FontWeight.Bold, Boje.sivaTekst),
                                    modifier = Modifier.clickable { opseg.launch { Zajednica.radnja(sesija, "prijavi_sadrzaj", mapOf("p_objava" to objava.id, "p_komentar" to k.id, "p_razlog" to "uvreda")) } })
                            }
                        }
                        Column(Modifier.clickable(enabled = nalog != null) {
                            opseg.launch { Zajednica.srceKomentaru(sesija, k.id)?.let { r -> lista = lista?.map { if (it.id == k.id) it.copy(srca = r.srca, moje_srce = r.moje_srce) else it } } }
                        }, horizontalAlignment = Alignment.CenterHorizontally) {
                            Icon(if (k.moje_srce) Icons.Rounded.Favorite else Icons.Rounded.FavoriteBorder, contentDescription = "Sviđa mi se", tint = if (k.moje_srce) Boje.roze else Boje.sivaTekst)
                            if (k.srca > 0) Text("${k.srca}", style = tekst(11.sp, FontWeight.Bold, Boje.sivaTekst))
                        }
                    }
                }
            }
            if (nalog != null) Column(Modifier.background(Boje.krem).padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                odgovorNa?.let { o ->
                    Row { Text("Odgovaraš: ${o.nadimak}", style = tekst(13.sp, FontWeight.SemiBold, Boje.sivaTekst), modifier = Modifier.weight(1f)); Text("Otkaži", style = tekst(13.sp, FontWeight.Bold), modifier = Modifier.clickable { odgovorNa = null }) }
                }
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Box(Modifier.weight(1f)) { PoljeTeksta(tekst, "Napiši komentar…") { tekst = it.take(500) } }
                    IconButton(onClick = { if (tekst.isNotBlank()) posalji() }, modifier = Modifier.size(46.dp).background(Boje.mastilo, CircleShape)) {
                        Icon(Icons.AutoMirrored.Rounded.Send, contentDescription = "Pošalji", tint = Boje.naMastilu)
                    }
                }
            }
        }
        if (pravila) PravilaZajednice(prihvati = { napredak.podesi { pravilaZajednice = true }; pravila = false; posalji() }, odustani = { pravila = false })
    }
}

/** Spisak razgovora. */
@Composable
fun PorukeEkran(sesija: Sesija, idi: (String) -> Unit, nazad: () -> Unit) {
    var lista by remember { mutableStateOf<List<Zajednica.Razgovor>?>(null) }
    LaunchedEffect(Unit) { lista = runCatching { Zajednica.razgovori(sesija) }.getOrDefault(emptyList()) }
    Box(Modifier.fillMaxSize()) {
        Papir()
        Column(Modifier.fillMaxSize().statusBarsPadding().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            KrugIkonica(Icons.AutoMirrored.Rounded.ArrowBack, "Nazad", nazad)
            Text("Poruke", style = naslov(32.sp))
            val l = lista
            when {
                l == null -> CircularProgressIndicator(color = Boje.mastilo)
                l.isEmpty() -> Text("Još nema poruka. Poruku šalješ sa profila igrača ili iz objave.", style = tekst(15.sp, boja = Boje.sivaTekst))
                else -> Column(Modifier.fillMaxWidth().mirna()) {
                    l.forEachIndexed { i, r ->
                        Row(Modifier.fillMaxWidth().clickable { idi("razgovor/${r.sa}/${r.nadimak}") }.padding(horizontal = 14.dp, vertical = 10.dp),
                            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            AvatarSlika(r.avatar, 48.dp)
                            Column(Modifier.weight(1f)) {
                                Text(r.nadimak, style = tekst(16.sp, if (r.neprocitanih > 0) FontWeight.Bold else FontWeight.SemiBold))
                                Text((if (r.moja) "Ti: " else "") + r.poslednja, style = tekst(14.sp, boja = if (r.neprocitanih > 0) Boje.mastilo else Boje.sivaTekst), maxLines = 1)
                            }
                            Column(horizontalAlignment = Alignment.End) {
                                Text(Zajednica.pre(r.kad), style = tekst(12.sp, boja = Boje.sivaTekst))
                                if (r.neprocitanih > 0) Box(Modifier.size(22.dp).background(Boje.roze, CircleShape), contentAlignment = Alignment.Center) {
                                    Text("${r.neprocitanih}", style = tekst(12.sp, FontWeight.Bold, Color.White))
                                }
                            }
                        }
                        if (i < l.size - 1) HorizontalDivider(color = Boje.kremTamnija)
                    }
                }
            }
        }
    }
}

/** Razgovor sa jednim igračem; novo stiže na svakih 5 s dok je otvoren. */
@OptIn(androidx.compose.foundation.ExperimentalFoundationApi::class)
@Composable
fun RazgovorEkran(sesija: Sesija, sa: String, nadimak: String, nazad: () -> Unit) {
    val napredak = Napredak.deljeni
    var poruke by remember { mutableStateOf<List<Zajednica.Poruka>>(emptyList()) }
    var tekst by remember { mutableStateOf("") }
    var greska by remember { mutableStateOf<String?>(null) }
    var pravila by remember { mutableStateOf(false) }
    // Prijava tuđe poruke (dug pritisak) i blokada (tri tačke), Apple 1.2 / Google UGC.
    var meniPoruke by remember { mutableStateOf<Zajednica.Poruka?>(null) }
    var meniRazgovora by remember { mutableStateOf(false) }
    var potvrda by remember { mutableStateOf<String?>(null) }
    val opseg = rememberCoroutineScope()
    val stanjeListe = rememberLazyListState()
    LaunchedEffect(sa) {
        while (true) {
            runCatching { Zajednica.poruke(sesija, sa) }.onSuccess { if (it != poruke) poruke = it }
            delay(5000)
        }
    }
    LaunchedEffect(poruke.size) { if (poruke.isNotEmpty()) stanjeListe.animateScrollToItem(poruke.size - 1) }
    fun posalji() {
        if (!napredak.s.pravilaZajednice) { pravila = true; return }
        val t = tekst; tekst = ""
        opseg.launch {
            runCatching { Zajednica.posaljiPoruku(sesija, sa, t) }
                .onSuccess { greska = null; poruke = runCatching { Zajednica.poruke(sesija, sa) }.getOrDefault(poruke) }
                .onFailure { tekst = t; greska = it.message }
        }
    }
    Box(Modifier.fillMaxSize().background(Boje.krem)) {
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().imePadding()) {
            Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                KrugIkonica(Icons.AutoMirrored.Rounded.ArrowBack, "Nazad", nazad)
                Text(nadimak, style = tekst(18.sp, FontWeight.Bold), modifier = Modifier.weight(1f))
                KrugIkonica(Icons.Rounded.MoreHoriz, "Više") { meniRazgovora = true }
            }
            LazyColumn(Modifier.weight(1f).padding(horizontal = 16.dp), state = stanjeListe, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                if (poruke.isEmpty()) item { Text("Napiši prvu poruku.", style = tekst(14.sp, boja = Boje.sivaTekst)) }
                items(poruke, key = { it.id }) { p ->
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = if (p.moja) Arrangement.End else Arrangement.Start) {
                        Text(p.tekst, style = tekst(16.sp, boja = if (p.moja) Boje.naMastilu else Boje.mastilo),
                            modifier = Modifier
                                .then(if (p.moja) Modifier else Modifier.combinedClickable(onClickLabel = null, onLongClickLabel = "Prijavi poruku", onLongClick = { meniPoruke = p }, onClick = {}))
                                .background(if (p.moja) Boje.mastilo else Boje.kartica, RoundedCornerShape(18.dp))
                                .border(if (p.moja) 0.dp else 1.5.dp, Boje.kremTamnija, RoundedCornerShape(18.dp)).padding(horizontal = 14.dp, vertical = 10.dp))
                    }
                }
            }
            greska?.let { Text(it, style = tekst(13.sp, FontWeight.SemiBold, Boje.crvena), modifier = Modifier.padding(horizontal = 16.dp)) }
            Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(Modifier.weight(1f)) { PoljeTeksta(tekst, "Poruka…") { tekst = it.take(1000) } }
                IconButton(onClick = { if (tekst.isNotBlank()) posalji() }, modifier = Modifier.size(46.dp).background(Boje.mastilo, CircleShape)) {
                    Icon(Icons.AutoMirrored.Rounded.Send, contentDescription = "Pošalji", tint = Boje.naMastilu)
                }
            }
        }
        meniPoruke?.let { p ->
            DonjiList({ meniPoruke = null }) {
                StavkaMenija("Prijavi poruku", Icons.Rounded.Flag) {
                    meniPoruke = null
                    opseg.launch { if (Zajednica.radnja(sesija, "prijavi_poruku", mapOf("p_poruka" to p.id, "p_razlog" to "uvreda"))) potvrda = "Hvala na prijavi" }
                }
                StavkaMenija("Blokiraj $nadimak", Icons.Rounded.Block, opasno = true) { meniPoruke = null; potvrda = "blokada" }
            }
        }
        if (meniRazgovora) DonjiList({ meniRazgovora = false }) {
            Text("Zadrži prst na poruci da je prijaviš.", style = tekst(13.sp, boja = Boje.sivaTekst))
            StavkaMenija("Blokiraj $nadimak", Icons.Rounded.Block, opasno = true) { meniRazgovora = false; potvrda = "blokada" }
        }
        when (val pt = potvrda) {
            null -> Unit
            "blokada" -> Dijalog("Blokirati $nadimak?", "Više se nećete videti: ni objave, ni komentari, ni poruke. Praćenje se briše.", "Blokiraj", "Odustani",
                potvrdi = { potvrda = null; opseg.launch { if (Zajednica.radnja(sesija, "blokiraj", mapOf("p_id" to sa, "p_da" to true))) nazad() } }, zatvori = { potvrda = null })
            else -> Dijalog(pt, "Urednik pregleda prijave u roku od 24 sata.", "U redu", "Zatvori", potvrdi = { potvrda = null }, zatvori = { potvrda = null })
        }
        if (pravila) PravilaZajednice(prihvati = { napredak.podesi { pravilaZajednice = true }; pravila = false; posalji() }, odustani = { pravila = false })
    }
}


/** Brojači za kartice (RPC moji_brojevi): nova obaveštenja (Profil) i nepročitane poruke (Igrači). */
object Brojaci {
    @Serializable private data class B(val obavestenja: Int, val poruke: Int)
    val obavestenja = kotlinx.coroutines.flow.MutableStateFlow(0)
    val poruke = kotlinx.coroutines.flow.MutableStateFlow(0)

    suspend fun osvezi(s: Sesija) {
        if (s.nalog.value == null) { obavestenja.value = 0; poruke.value = 0; return }
        val b = runCatching { Supabase.json.decodeFromString<B>(Supabase.rpc("moji_brojevi", emptyMap(), s.vazeciToken())) }.getOrNull() ?: return
        obavestenja.value = b.obavestenja; poruke.value = b.poruke
    }
}

@Serializable data class ObavestenjeServera(
    val vrsta: String, val ko: String, val nadimak: String, val avatar: String? = null, val tekst: String? = null,
    val objava: Long? = null, val kod_sobe: String? = null, val kad: String, val novo: Boolean,
)

/** Sanduče: izazovi, novi pratioci, komentari, odgovori, srca i ishodi izazova (poslednjih 30 dana); otvaranje ih označava pročitanim. */
@Composable
fun SanduceEkran(sesija: Sesija, idi: (String) -> Unit, nazad: () -> Unit) {
    var redovi by remember { mutableStateOf<List<ObavestenjeServera>?>(null) }
    LaunchedEffect(Unit) {
        redovi = runCatching { Supabase.json.decodeFromString<List<ObavestenjeServera>>(Supabase.rpc("moja_obavestenja", mapOf("p_oznaci" to true), sesija.vazeciToken())) }
            .getOrDefault(emptyList())
        Brojaci.obavestenja.value = 0
    }
    Box(Modifier.fillMaxSize()) {
        Papir()
        Column(Modifier.fillMaxSize().statusBarsPadding().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            KrugIkonica(Icons.AutoMirrored.Rounded.ArrowBack, "Nazad", nazad)
            Text("Sanduče", style = naslov(32.sp))
            val l = redovi
            when {
                l == null -> CircularProgressIndicator(color = Boje.mastilo)
                l.isEmpty() -> Column(Modifier.fillMaxWidth().mirna().padding(20.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    MaskotaSlika(Maskota.BLOOP, 90.dp)
                    Text("Ovde stižu izazovi, novi pratioci i komentari.", style = tekst(15.sp, boja = Boje.sivaTekst))
                }
                else -> l.forEach { r ->
                    val (ikonica, opis) = when (r.vrsta) {
                        "izazov" -> Icons.Rounded.Bolt to "te izaziva na duel"
                        "soba" -> Icons.Rounded.Groups to "te zove: " + (r.tekst?.let { club.librum.kviz.igre.IgraTakmicenja.od(it).naziv } ?: "kviz")
                        "pratilac" -> Icons.Rounded.Groups to "te sada prati"
                        "komentar" -> Icons.Rounded.ChatBubbleOutline to "je komentarisao tvoju objavu"
                        "odgovor" -> Icons.Rounded.ChatBubbleOutline to "ti je odgovorio"
                        "ishod" -> Icons.Rounded.EmojiEvents to "je odigrao tvoj izazov"
                        else -> Icons.Rounded.Favorite to "voli tvoju objavu"
                    }
                    Row(
                        Modifier.fillMaxWidth().background(Boje.kartica, RoundedCornerShape(20.dp))
                            .border(if (r.novo) 2.5.dp else 1.5.dp, if (r.novo) Boje.mastilo else Boje.kremTamnija, RoundedCornerShape(20.dp))
                            .clickable(enabled = r.vrsta != "ishod") {
                                if (r.vrsta == "izazov" && r.kod_sobe != null) idi("duel/kod/${r.kod_sobe}")
                                else if (r.vrsta == "soba" && r.kod_sobe != null) idi("takmicenje/kod/${r.kod_sobe}") else idi("igrac/${r.ko}")
                            }
                            .padding(14.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        Box {
                            AvatarSlika(r.avatar, 44.dp)
                            Box(Modifier.align(Alignment.BottomEnd).size(20.dp).background(Boje.roze, CircleShape).border(2.dp, Boje.krem, CircleShape), contentAlignment = Alignment.Center) {
                                Icon(ikonica, null, tint = Color.White, modifier = Modifier.size(11.dp))
                            }
                        }
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                            Text(androidx.compose.ui.text.buildAnnotatedString {
                                pushStyle(androidx.compose.ui.text.SpanStyle(fontWeight = FontWeight.Bold)); append(r.nadimak); pop(); append(" $opis")
                            }, style = tekst(15.sp))
                            r.tekst?.takeIf { r.vrsta != "soba" }?.let { Text("„$it”", style = tekst(13.sp, boja = Boje.sivaTekst), maxLines = 2) }
                            Text(Zajednica.pre(r.kad), style = tekst(12.sp, boja = Boje.sivaTekst))
                        }
                        if (r.novo) Box(Modifier.size(10.dp).background(Boje.roze, CircleShape).semantics { contentDescription = "Novo" })
                    }
                }
            }
        }
    }
}
