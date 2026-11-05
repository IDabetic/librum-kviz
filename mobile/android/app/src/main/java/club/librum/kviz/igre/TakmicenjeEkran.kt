package club.librum.kviz.igre

import android.content.Intent
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Computer
import androidx.compose.material.icons.rounded.Flag
import androidx.compose.material.icons.rounded.PersonAdd
import androidx.compose.material.icons.rounded.Remove
import androidx.compose.material.icons.rounded.Share
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import club.librum.kviz.R
import club.librum.kviz.servisi.Pitanje
import club.librum.kviz.servisi.Prikaz
import club.librum.kviz.servisi.Rec
import club.librum.kviz.servisi.Sesija
import club.librum.kviz.servisi.Supabase
import club.librum.kviz.servisi.Zvuk
import club.librum.kviz.ui.AvatarSlika
import club.librum.kviz.ui.Boje
import club.librum.kviz.ui.Dijalog
import club.librum.kviz.ui.Dugme
import club.librum.kviz.ui.Izbor
import club.librum.kviz.ui.Oznaka
import club.librum.kviz.ui.Papir
import club.librum.kviz.ui.PitanjeKartica
import club.librum.kviz.ui.VrstaDugmeta
import club.librum.kviz.ui.mirna
import club.librum.kviz.ui.naslov
import club.librum.kviz.ui.pop
import club.librum.kviz.ui.tekst
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer

/**
 * Lobi i igra za 2–8 igrača (vlasnik 03.11.2026), kao iOS TakmicenjeView: domaćin bira igru, broj igrača, svako za sebe ili
 * timove po dvoje, protiv računara, pravih igrača ili mešano; poziva prijatelje (Sanduče + baner) ili deli kod/link
 * librumkviz://soba/KOD. Pozvani bira Prihvatam ili Odbijam. Izlaz je na svakom koraku. Logika: Takmicenje.kt.
 */
@Composable
fun TakmicenjeEkran(sesija: Sesija, kod: String? = null, pozovi: Pair<String, String>? = null, izadji: () -> Unit, pocetak: () -> Unit) {
    val ctx = LocalContext.current
    val opseg = rememberCoroutineScope()
    val nalog by sesija.nalog.collectAsState()
    val proba = Takmicenje.proba && nalog == null
    val ja = nalog?.id ?: if (proba) "proba" else null
    var soba by remember { mutableStateOf<Takmicenje.Soba?>(null) }
    var greska by remember { mutableStateOf<String?>(null) }
    var radi by remember { mutableStateOf(false) }
    var potvrdaIzlaska by remember { mutableStateOf(false) }
    // Postavka (domaćin)
    var igra by remember { mutableStateOf(IgraTakmicenja.PRO) }
    var velicina by remember { mutableIntStateOf(if (pozovi != null) 2 else 4) }
    var timovi by remember { mutableStateOf(false) }
    var protivnici by remember { mutableStateOf(if (pozovi != null) "pravi" else "mesano") }
    var tezina by remember { mutableStateOf("normalno") }
    var prijatelji by remember { mutableStateOf<List<Prijatelj>>(emptyList()) }
    var pozvani by remember { mutableStateOf(pozovi?.let { setOf(it.first) } ?: emptySet()) }
    // Igra
    var pitanja by remember { mutableStateOf<List<Pitanje>>(emptyList()) }
    var reci by remember { mutableStateOf<List<Rec>>(emptyList()) }
    var pocetakIgre by remember { mutableStateOf<Long?>(null) }
    var mojKraj by remember { mutableStateOf(false) }
    val jaDomacin = soba?.domacin == ja

    fun izlaz() { if (soba == null || soba?.status == "otkazano" || greska != null) izadji() else potvrdaIzlaska = true }
    BackHandler { izlaz() }

    suspend fun napraviProbu() {
        val sadrzaj = runCatching { Takmicenje.izaberi(ctx, igra, tezina) }.getOrElse { greska = Takmicenje.poruka(it); return }
        if (igra == IgraTakmicenja.VESANJE) reci = Supabase.json.decodeFromJsonElement(ListSerializer(Rec.serializer()), sadrzaj)
        else pitanja = Supabase.json.decodeFromJsonElement(ListSerializer(Pitanje.serializer()), sadrzaj)
        val imena = listOf("Mimi", "Zig", "Bloop", "Lumi", "Luna", "Max", "Sara")
        val timova = if (timovi) velicina / 2 else velicina
        val mesta = (0 until velicina).map { m ->
            Takmicenje.Mesto(m, user_id = if (m == 0) "proba" else null, bot = if (m == 0) null else imena[m - 1], tim = m % timova, nadimak = if (m == 0) "Proba" else imena[m - 1])
        }
        pocetakIgre = System.currentTimeMillis()
        soba = Takmicenje.Soba("proba", "PROBA1", igra.kljuc, "proba", velicina, if (timovi) "timovi" else "svako", "racunar", tezina,
            (1L..999_999L).random(), igra.broj, "igra", mesta)
    }

    suspend fun napravi() {
        radi = true
        if (proba) { napraviProbu(); radi = false; return }
        try {
            val sadrzaj = Takmicenje.izaberi(ctx, igra, tezina)
            val nova = Takmicenje.napravi(sesija, igra, velicina, timovi, protivnici, tezina, sadrzaj, if (protivnici == "racunar") emptyList() else pozvani.toList())
            soba = if (protivnici == "racunar") Takmicenje.pokreni(sesija, nova.id) else nova
        } catch (e: Exception) { greska = Takmicenje.poruka(e) }
        radi = false
    }

    LaunchedEffect(Unit) {
        if (kod != null) runCatching { soba = Takmicenje.udji(sesija, kod) }.onFailure { greska = Takmicenje.poruka(it) }
        else runCatching {
            prijatelji = Supabase.json.decodeFromString(ListSerializer(Prijatelj.serializer()), Supabase.rpc("osvajanje_za_poziv", emptyMap(), sesija.vazeciToken()))
        }
    }
    // Osvežavanje sobe dok se čeka i igra; staje kad je kraj ili je soba otkazana.
    LaunchedEffect(soba?.id) {
        val id = soba?.id ?: return@LaunchedEffect
        if (proba) return@LaunchedEffect
        if (soba?.status == "ceka") Zvuk.pusti(Zvuk.Vrsta.CEKANJE, 0.2f, ponavljaj = true)
        while (soba?.status == "ceka" || soba?.status == "igra") {
            delay(Takmicenje.OSVEZAVANJE_MS)
            val pre = soba?.mesta?.count { it.user_id != null && !it.pozvan } ?: 0
            val nova = runCatching { Takmicenje.stanje(sesija, id) }.getOrNull() ?: continue
            if (nova.mesta.count { it.user_id != null && !it.pozvan } > pre) Zvuk.pusti(Zvuk.Vrsta.PROTIVNIK_USAO, 0.45f)
            soba = nova
            if (nova.status == "otkazano") greska = "Domaćin je otkazao sobu."
        }
        Zvuk.stani(Zvuk.Vrsta.CEKANJE)
    }
    // Igra je krenula: sadržaj stiže sa servera (isti za sve), pa kreće sat.
    LaunchedEffect(soba?.status) {
        val s = soba ?: return@LaunchedEffect
        if (s.status != "igra" || pocetakIgre != null || proba) return@LaunchedEffect
        runCatching { if (s.vrsta == IgraTakmicenja.VESANJE) reci = Takmicenje.reci(sesija, s.id) else pitanja = Takmicenje.pitanja(sesija, s.id) }
            .onFailure { greska = "Pitanja nisu stigla. Proveri internet." }
        Zvuk.stani(Zvuk.Vrsta.CEKANJE)
        pocetakIgre = System.currentTimeMillis()
    }
    DisposableEffect(Unit) { onDispose { Zvuk.stani(Zvuk.Vrsta.CEKANJE) } }

    fun prijavi(r: MojRezultat) {
        val id = soba?.id ?: return
        if (r.gotov) { mojKraj = true; Zvuk.pusti(Zvuk.Vrsta.KRAJ, 0.4f) }
        if (proba) {
            soba = soba?.let { st -> st.copy(mesta = st.mesta.map { if (it.user_id == ja) it.copy(poeni = r.poeni, tacnih = r.tacnih, odigrano = r.odigrano, gotov = r.gotov) else it }) }
            return
        }
        opseg.launch { runCatching { Takmicenje.rezultat(sesija, id, r.poeni, r.tacnih, r.odigrano, r.ms, r.gotov) }.getOrNull()?.let { soba = it } }
    }

    Box(Modifier.fillMaxSize()) {
        Papir()
        val s = soba
        when {
            nalog == null && !proba -> GreskaKartica("Igra sa drugima traži nalog", "Prijavi se u kartici Profil, da bi ostali znali protiv koga igraju.", izadji)
            s != null && s.status == "igra" && !mojKraj && pocetakIgre != null -> Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
                Row(Modifier.padding(16.dp, 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    KrugZatvori("Predaj") { potvrdaIzlaska = true }
                    TabelaUzivo(s, ja, pocetakIgre!!)
                }
                when (s.vrsta) {
                    IgraTakmicenja.VESANJE -> VesanjeTakmicenja(reci, ::prijavi)
                    IgraTakmicenja.BRZI -> BrziTakmicenja(pitanja, s.seme, ::prijavi)
                    else -> KvizTakmicenja(pitanja, s.vrsta.naziv, ::prijavi)
                }
            }
            s != null && (s.status == "kraj" || (s.status == "igra" && pocetakIgre != null)) ->
                KrajTakmicenja(s, ja, pocetakIgre ?: 0L, if (jaDomacin) ({
                    igra = s.vrsta; velicina = s.velicina; timovi = s.timovi; protivnici = s.protivnici; tezina = s.tezina
                    pozvani = s.mesta.mapNotNull { it.user_id }.filter { it != ja }.toSet()
                    soba = null; pitanja = emptyList(); reci = emptyList(); pocetakIgre = null; mojKraj = false
                    opseg.launch { napravi() }
                }) else null, pocetak)
            else -> Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                KrugZatvori(if (s == null) "Zatvori" else "Izađi iz sobe") { izlaz() }
                val g = greska
                when {
                    g != null -> { Text(g, style = tekst(15.sp, FontWeight.SemiBold, Boje.crvena)); Dugme("Nazad", radnja = izadji) }
                    s != null -> Cekaonica(s, jaDomacin, radi) {
                        radi = true
                        opseg.launch { runCatching { soba = Takmicenje.pokreni(sesija, s.id) }.onFailure { greska = Takmicenje.poruka(it) }; radi = false }
                    }
                    kod != null -> Box(Modifier.fillMaxWidth().padding(40.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = Boje.mastilo) }
                    else -> {
                        Text(pozovi?.let { "Izazovi: ${it.second}" } ?: "Igraj sa drugima", style = naslov(32.sp))
                        Text("Svi dobijaju ista pitanja u isto vreme, a tabela se menja uživo.", style = tekst(15.sp, FontWeight.Normal, Boje.sivaTekst))
                        Oznaka("Igra")
                        IgraTakmicenja.entries.forEach { g2 ->
                            Row(
                                Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(Boje.kartica)
                                    .border(if (igra == g2) 2.5.dp else 1.5.dp, if (igra == g2) Boje.mastilo else Boje.kremTamnija, RoundedCornerShape(18.dp))
                                    .clickable { igra = g2 }.padding(10.dp).semantics { contentDescription = g2.naziv + if (igra == g2) ", izabrano" else "" },
                                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
                            ) {
                                val slika = remember(g2) { ctx.resources.getIdentifier("igra_${g2.kljuc}", "drawable", ctx.packageName) }
                                if (slika != 0) Image(painterResource(slika), null, Modifier.size(52.dp).clip(RoundedCornerShape(12.dp)))
                                Column(Modifier.weight(1f)) {
                                    Text(g2.naziv, style = tekst(16.sp, FontWeight.Bold))
                                    Text(g2.opis, style = tekst(13.sp, FontWeight.Normal, Boje.sivaTekst))
                                }
                                Icon(if (igra == g2) Icons.Rounded.CheckCircle else Icons.Rounded.Add, null, tint = if (igra == g2) Boje.teal else Boje.kremTamnija)
                            }
                        }
                        if (pozovi == null) {
                            Oznaka("Igrača")
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                                KrugDugme(Icons.Rounded.Remove, "Manje igrača") { velicina = maxOf(2, velicina - 1); if (velicina % 2 == 1 || velicina < 4) timovi = false }
                                Text("$velicina", style = naslov(34.sp))
                                KrugDugme(Icons.Rounded.Add, "Više igrača") { velicina = minOf(8, velicina + 1); if (velicina % 2 == 1) timovi = false }
                            }
                            if (velicina >= 4 && velicina % 2 == 0) Izbor(listOf("Svako za sebe", "Timovi po dvoje"), if (timovi) 1 else 0) { timovi = it == 1 }
                            Oznaka("Protivnici")
                            val opcije = listOf("racunar", "pravi", "mesano")
                            Izbor(listOf("Računar", "Pravi igrači", "Mešano"), opcije.indexOf(protivnici)) { protivnici = opcije[it] }
                            Text(if (protivnici == "racunar") "Igraš odmah protiv botova." else if (protivnici == "pravi") "Igraju samo oni koji uđu u sobu."
                                else "Ko ne stigne do početka, umesto njega igra računar.", style = tekst(13.sp, FontWeight.Normal, Boje.sivaTekst))
                        }
                        if (protivnici != "pravi") {
                            Oznaka("Težina računara")
                            val t = listOf("lako", "normalno", "tesko")
                            Izbor(listOf("Lako", "Normalno", "Teško"), t.indexOf(tezina)) { tezina = t[it] }
                        }
                        if (protivnici != "racunar" && pozovi == null && prijatelji.isNotEmpty()) {
                            Oznaka("Pozovi (${pozvani.size} od ${velicina - 1})")
                            prijatelji.forEach { p ->
                                val izabran = p.id in pozvani
                                Row(Modifier.fillMaxWidth().mirna().clickable {
                                    pozvani = if (izabran) pozvani - p.id else if (pozvani.size < velicina - 1) pozvani + p.id else pozvani
                                }.padding(10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                    AvatarSlika(p.avatar, 36.dp)
                                    Text(p.nadimak, style = tekst(15.sp, FontWeight.SemiBold), modifier = Modifier.weight(1f))
                                    Icon(if (izabran) Icons.Rounded.CheckCircle else Icons.Rounded.PersonAdd, if (izabran) "pozvan" else "pozovi", tint = if (izabran) Boje.teal else Boje.sivaTekst)
                                }
                            }
                        }
                        Dugme(if (radi) "Spremam…" else if (protivnici == "racunar") "Igraj" else "Napravi sobu", vrsta = VrstaDugmeta.ZUTO, omoguceno = !radi) { opseg.launch { napravi() } }
                        Spacer(Modifier.height(40.dp))
                    }
                }
            }
        }
        if (potvrdaIzlaska) {
            val uIgri = soba?.status == "igra"
            Dijalog(if (uIgri) "Predaješ?" else if (jaDomacin) "Otkazuješ sobu?" else "Izlaziš iz sobe?",
                if (uIgri) "Tvoj rezultat do sada ostaje u tabeli, ostali igraju dalje." else if (jaDomacin) "Pozvani će videti da je soba otkazana." else "Mesto se oslobađa za drugog igrača.",
                "Izađi", "Ostani", potvrdi = { potvrdaIzlaska = false; opseg.launch { soba?.id?.let { Takmicenje.izadji(sesija, it) }; izadji() } },
                zatvori = { potvrdaIzlaska = false })
        }
    }
}

@Serializable private data class Prijatelj(val id: String, val nadimak: String, val avatar: String? = null)

/** Šta igra javlja posle svakog odgovora (zbirno). */
data class MojRezultat(val poeni: Int = 0, val tacnih: Int = 0, val odigrano: Int = 0, val ms: Int = 0, val gotov: Boolean = false)

@Composable
private fun KrugDugme(ikonica: androidx.compose.ui.graphics.vector.ImageVector, opis: String, radnja: () -> Unit) {
    Box(Modifier.size(44.dp).background(Boje.kartica, CircleShape).border(1.5.dp, Boje.kremTamnija, CircleShape).clickable(onClick = radnja)
        .semantics { contentDescription = opis }, contentAlignment = Alignment.Center) { Icon(ikonica, null, tint = Boje.mastilo) }
}

@Composable
private fun Cekaonica(s: Takmicenje.Soba, jaDomacin: Boolean, radi: Boolean, pokreni: () -> Unit) {
    val ctx = LocalContext.current
    Text(s.vrsta.naziv, style = naslov(32.sp))
    Text("${s.velicina} igrača · ${if (s.timovi) "timovi po dvoje" else "svako za sebe"}", style = tekst(14.sp, FontWeight.SemiBold, Boje.sivaTekst))
    Column(Modifier.fillMaxWidth().pop(Boje.zuta, 20.dp).padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text("Kod sobe", style = tekst(13.sp, FontWeight.Bold, Boje.tinta))
        Text(s.kod, style = naslov(40.sp, Boje.tinta).copy(fontFamily = FontFamily.Monospace, letterSpacing = 6.sp))
        Box(Modifier.size(52.dp, 46.dp).background(Boje.tinta, RoundedCornerShape(14.dp)).clickable {
            ctx.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).setType("text/plain")
                .putExtra(Intent.EXTRA_TEXT, "Igrajmo ${s.vrsta.naziv} u Librum kvizu! Kod sobe: ${s.kod} · librumkviz://soba/${s.kod}"), null))
        }.semantics { contentDescription = "Pošalji poziv" }, contentAlignment = Alignment.Center) { Icon(Icons.Rounded.Share, null, tint = Boje.zuta) }
    }
    val usli = s.mesta.count { it.user_id != null && !it.pozvan }
    Text("U sobi $usli od ${s.velicina}", style = tekst(16.sp, FontWeight.Bold))
    s.mesta.chunked(2).forEach { red ->
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            red.forEach { m ->
                Row(Modifier.weight(1f).mirna().padding(10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    if (m.user_id != null) AvatarSlika(m.avatar, 36.dp) else Icon(Icons.Rounded.PersonAdd, null, tint = Boje.sivaTekst)
                    Column {
                        Text(m.nadimak ?: if (s.protivnici == "pravi") "Slobodno" else "Računar ako niko ne dođe", style = tekst(14.sp, FontWeight.Bold, if (m.user_id == null) Boje.sivaTekst else Boje.mastilo), maxLines = 1)
                        Text(if (m.pozvan) "čeka odgovor…" else if (s.timovi) Takmicenje.imeTima(m.tim) + if (m.user_id == s.domacin) " · domaćin" else ""
                            else if (m.user_id == s.domacin) "domaćin" else if (m.user_id == null) "" else "spreman",
                            style = tekst(11.sp, FontWeight.SemiBold, if (m.pozvan) Boje.narandzasta else Boje.sivaTekst))
                    }
                }
            }
        }
    }
    if (jaDomacin) {
        val ceka = s.protivnici == "pravi" && !s.timovi && usli < 2
        Dugme(if (radi) "Pokrećem…" else "Počni", vrsta = VrstaDugmeta.ZUTO, omoguceno = !radi && !ceka, radnja = pokreni)
        if (ceka) Text("Čeka se bar jedan igrač.", style = tekst(13.sp, FontWeight.Normal, Boje.sivaTekst))
    } else Text("Čeka se da domaćin pokrene igru.", style = tekst(15.sp, FontWeight.SemiBold, Boje.sivaTekst))
}

/** Traka uživo iznad igre: mesto, ime i poeni svih (botovi iz semena), a u timovima i zbir tima. */
@Composable
private fun TabelaUzivo(s: Takmicenje.Soba, ja: String?, pocetak: Long) {
    var sad by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) { while (true) { sad = System.currentTimeMillis(); delay(1000) } }
    val redovi = Takmicenje.tabela(s, ja, (sad - pocetak) / 1000.0)
    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
        if (s.timovi) {
            Takmicenje.timovi(redovi).forEachIndexed { i, (tim, poeni, clanovi) -> Celija(i + 1, Takmicenje.imeTima(tim), poeni, clanovi.any { it.ja }) }
            Box(Modifier.size(2.dp, 34.dp).background(Boje.kremTamnija))
        }
        redovi.forEachIndexed { i, r -> Celija(i + 1, r.ime, r.poeni, r.ja, r.gotov) }
    }
}

@Composable
private fun Celija(mesto: Int, ime: String, poeni: Int, ja: Boolean, gotov: Boolean = false) {
    Row(
        Modifier.heightIn(min = 46.dp).background(if (ja) Boje.zuta else Boje.kartica, RoundedCornerShape(12.dp))
            .border(if (ja) 2.dp else 1.dp, Boje.mastilo, RoundedCornerShape(12.dp)).padding(horizontal = 10.dp, vertical = 4.dp)
            .semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text("$mesto.", style = tekst(12.sp, FontWeight.Bold, Boje.sivaTekst))
        Column {
            Text(ime, style = tekst(12.sp, FontWeight.Bold, if (ja) Boje.tinta else Boje.mastilo), maxLines = 1)
            Text("$poeni", style = naslov(15.sp, if (ja) Boje.tinta else Boje.mastilo))
        }
        if (gotov) Icon(Icons.Rounded.Flag, "završio", tint = Boje.sivaTekst, modifier = Modifier.size(14.dp))
    }
}

/** Kraj: tabela (i timovi), dok ostali još igraju osvežava se uživo; domaćin može odmah revanš. */
@Composable
private fun KrajTakmicenja(s: Takmicenje.Soba, ja: String?, pocetak: Long, ponovo: (() -> Unit)?, pocetna: () -> Unit) {
    var sad by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) { while (true) { sad = System.currentTimeMillis(); delay(1000) } }
    val redovi = Takmicenje.tabela(s, ja, if (s.status == "kraj") Double.MAX_VALUE else (sad - pocetak) / 1000.0)
    val svi = redovi.all { it.gotov }
    val pobedio = if (s.timovi) Takmicenje.timovi(redovi).firstOrNull()?.third?.any { it.ja } == true else redovi.firstOrNull()?.ja == true
    LaunchedEffect(svi) { if (svi) Zvuk.pusti(if (pobedio) Zvuk.Vrsta.POBEDA else Zvuk.Vrsta.KRAJ, 0.5f) }
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Text(if (!svi) "Čekamo ostale…" else if (pobedio) "Pobeda!" else "Kraj igre", style = naslov(36.sp))
        Text(s.vrsta.naziv, style = tekst(15.sp, FontWeight.SemiBold, Boje.sivaTekst))
        if (s.timovi) {
            Takmicenje.timovi(redovi).forEachIndexed { i, (tim, poeni, clanovi) ->
                Row(Modifier.fillMaxWidth().pop(if (i == 0) Boje.zuta else Boje.kartica, 18.dp).padding(14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("${i + 1}. ${Takmicenje.imeTima(tim)}", style = tekst(17.sp, FontWeight.Bold))
                    Text(clanovi.joinToString(" i ") { it.ime }, style = tekst(13.sp, FontWeight.Normal, Boje.sivaTekst), maxLines = 1, modifier = Modifier.weight(1f))
                    Text("$poeni", style = naslov(22.sp))
                }
            }
            Oznaka("Igrači")
        }
        redovi.forEachIndexed { i, r ->
            Row(Modifier.fillMaxWidth().background(if (r.ja) Boje.zuta.copy(alpha = 0.35f) else Boje.kartica, RoundedCornerShape(16.dp))
                .border(if (r.ja) 2.dp else 1.dp, Boje.mastilo, RoundedCornerShape(16.dp)).padding(12.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("${i + 1}", style = naslov(22.sp))
                if (!r.bot) AvatarSlika(r.avatar, 40.dp) else Box(Modifier.size(40.dp).background(Boje.udubljeno, CircleShape), contentAlignment = Alignment.Center) { Icon(Icons.Rounded.Computer, "računar", tint = Boje.mastilo) }
                Column(Modifier.weight(1f)) {
                    Text(r.ime + if (r.ja) " (ti)" else "", style = tekst(16.sp, FontWeight.Bold))
                    Text(if (r.gotov) "${r.tacnih} tačnih" else "igra još…", style = tekst(13.sp, FontWeight.Normal, Boje.sivaTekst))
                }
                Text("${r.poeni}", style = naslov(24.sp))
            }
        }
        if (ponovo != null && svi) Dugme("Revanš", vrsta = VrstaDugmeta.ZUTO, radnja = ponovo)
        Dugme("Početak", vrsta = VrstaDugmeta.SEKUNDARNO, radnja = pocetna)
    }
}

/** PRO, Book i Slikari: isti niz pitanja za sve, 20 s po pitanju, brži tačan nosi više; slika pre pitanja (Slikari). */
@Composable
private fun KvizTakmicenja(pitanja: List<Pitanje>, naziv: String, javi: (MojRezultat) -> Unit) {
    val prikazi = remember(pitanja) { pitanja.filter { it.options.size == 4 }.map { Prikaz.od(it) }.also { l -> SlikeUnapred.pripremi(l.mapNotNull { it.slika }) } }
    var i by remember { mutableIntStateOf(0) }
    var r by remember { mutableStateOf(MojRezultat()) }
    var spremna by remember { mutableIntStateOf(-1) }
    LaunchedEffect(prikazi) { if (prikazi.isEmpty()) javi(MojRezultat(gotov = true)) }
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        if (i < prikazi.size) {
            val p = prikazi[i]
            p.slika?.let { url -> key(i) { SlikaSaMreze(url, Modifier.fillMaxWidth().height(240.dp)) { spremna = i } } }
            // Kartica (i njen sat) kreće tek kad je slika tu, da pitanje ne stigne pre dela.
            if (p.slika == null || spremna == i) key(i) {
                PitanjeKartica("$naziv · ${i + 1} od ${prikazi.size}", p, Takmicenje.SEKUNDI_PITANJA) { izabran, ms ->
                    val tacno = izabran == p.tacan
                    i += 1
                    r = r.copy(poeni = r.poeni + Takmicenje.poeni(tacno, ms), tacnih = r.tacnih + if (tacno) 1 else 0, odigrano = r.odigrano + 1, ms = r.ms + ms, gotov = i >= prikazi.size)
                    javi(r)
                }
            }
        }
    }
}

/** Brzi kviz: 60 s, tačno/netačno; koja tvrdnja nudi tačan odgovor određuje seme sobe (isto svima, i na iPhonu). */
@Composable
private fun BrziTakmicenja(pitanja: List<Pitanje>, seme: Long, javi: (MojRezultat) -> Unit) {
    val izjave = remember(pitanja) { pitanja.mapIndexed { n, p -> val r = Takmicenje.slucajno(seme, n); BrziKviz.Izjava.od(p) { r.sledeci() } } }
    val igra = remember { BrziKviz() }
    var i by remember { mutableIntStateOf(0) }
    var kraj by remember { mutableStateOf(false) }
    val pocetak = remember { System.currentTimeMillis() }
    var sad by remember { mutableLongStateOf(pocetak) }
    fun zavrsi() { if (kraj) return; kraj = true; javi(MojRezultat(igra.poeni, igra.tacnih, i, BrziKviz.SEKUNDI_RUNDE * 1000, true)) }
    LaunchedEffect(Unit) { while (!kraj) { sad = System.currentTimeMillis(); if (sad - pocetak >= BrziKviz.SEKUNDI_RUNDE * 1000L) zavrsi(); delay(250) } }
    val ostalo = ((BrziKviz.SEKUNDI_RUNDE * 1000L - (sad - pocetak) + 999) / 1000).coerceAtLeast(0)
    fun odgovori(kaze: Boolean) {
        if (kraj || i >= izjave.size) return
        val pogodio = igra.odgovor(izjave[i], kaze, zavrsnica = ostalo <= BrziKviz.SEKUNDI_ZAVRSNICE)
        Zvuk.pusti(if (pogodio) Zvuk.Vrsta.TACNO else Zvuk.Vrsta.NETACNO, 0.4f)
        i += 1
        if (i >= izjave.size) zavrsi() else javi(MojRezultat(igra.poeni, igra.tacnih, i))
    }
    Column(Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("$ostalo s", style = naslov(30.sp, if (ostalo <= 10) Boje.crvena else Boje.mastilo), modifier = Modifier.weight(1f))
            if (igra.mnozilac > 1) Text("×${igra.mnozilac}  ", style = naslov(26.sp, Boje.narandzasta))
            Text("${igra.poeni}", style = naslov(30.sp))
        }
        if (i < izjave.size && !kraj) {
            val iz = izjave[i]
            Column(Modifier.fillMaxWidth().pop(Boje.zuta).padding(20.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                Oznaka(if (ostalo <= BrziKviz.SEKUNDI_ZAVRSNICE) "Završnica · duplo" else "Tvrdnja ${i + 1}", Boje.tinta)
                Text(iz.pitanje, style = tekst(19.sp, FontWeight.SemiBold, Boje.tinta))
                Text(iz.prikazano, style = naslov(26.sp, Boje.tinta))
            }
            Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                listOf(Triple(false, Icons.Rounded.Close, Boje.crvena), Triple(true, Icons.Rounded.Check, Boje.teal)).forEach { (kaze, ikonica, boja) ->
                    Box(Modifier.weight(1f).height(76.dp).background(boja, RoundedCornerShape(20.dp)).border(2.5.dp, Boje.mastilo, RoundedCornerShape(20.dp))
                        .clickable { odgovori(kaze) }.semantics { contentDescription = if (kaze) "Tačno" else "Netačno" }, contentAlignment = Alignment.Center) {
                        Icon(ikonica, null, tint = Color.White, modifier = Modifier.size(34.dp))
                    }
                }
            }
        }
    }
}

/** Vešanje: iste reči redom; posle pogotka ili promašaja reči sledeća stiže sama. */
@Composable
private fun VesanjeTakmicenja(reci: List<Rec>, javi: (MojRezultat) -> Unit) {
    var i by remember { mutableIntStateOf(0) }
    var igra by remember(reci) { mutableStateOf(Vesanje(reci.firstOrNull()?.word.orEmpty())) }
    var r by remember { mutableStateOf(MojRezultat()) }
    var pocetak by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(reci) { if (reci.isEmpty()) javi(MojRezultat(gotov = true)) }
    LaunchedEffect(igra.status) {
        if (igra.status == Vesanje.Status.IGRA) return@LaunchedEffect
        Zvuk.pusti(if (igra.status == Vesanje.Status.POBEDA) Zvuk.Vrsta.OSVOJENO else Zvuk.Vrsta.NETACNO, 0.5f)
        r = r.copy(poeni = r.poeni + igra.poeni, odigrano = r.odigrano + 1, tacnih = r.tacnih + if (igra.status == Vesanje.Status.POBEDA) 1 else 0,
            ms = r.ms + (System.currentTimeMillis() - pocetak).toInt(), gotov = i + 1 >= reci.size)
        javi(r)
        delay(1600)
        if (!r.gotov) { i += 1; igra = Vesanje(reci[i].word); pocetak = System.currentTimeMillis() }
    }
    if (i >= reci.size) return
    val rec = reci[i]
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Column(Modifier.fillMaxWidth().pop(if (igra.status == Vesanje.Status.POBEDA) Boje.tealSvetla else if (igra.status == Vesanje.Status.PORAZ) Boje.crvenaSvetla else Boje.zuta).padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row {
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Oznaka("Reč ${i + 1} od ${reci.size}" + (rec.category?.let { " · $it" } ?: ""), Boje.tinta)
                    rec.hint?.let { Text(it, style = tekst(17.sp, FontWeight.SemiBold, Boje.tinta)) }
                }
                VesalaCrtez(Vesanje.POCETNI_ZIVOTI - igra.zivoti, igra.status == Vesanje.Status.PORAZ, Modifier.size(80.dp, 96.dp))
            }
            Text(igra.prikaz.joinToString(" "), style = naslov(26.sp, Boje.tinta).copy(fontFamily = FontFamily.Monospace), modifier = Modifier.fillMaxWidth())
        }
        if (igra.status == Vesanje.Status.IGRA) AzbukaTastatura(igra) { slovo -> igra.pogodi(slovo); Zvuk.pusti(if (igra.rec.uppercase().contains(slovo)) Zvuk.Vrsta.SLOVO_DA else Zvuk.Vrsta.SLOVO_NE, 0.4f) }
        else Text(if (igra.status == Vesanje.Status.POBEDA) "Pogođeno: +${igra.poeni}" else "Reč je bila: ${rec.word.uppercase()}", style = tekst(17.sp, FontWeight.Bold))
    }
}

/** Baner preko cele aplikacije kad te neko pozove u sobu: Odbijam (✕) ili Prihvatam (✓). */
@Composable
fun PozivBaner(poziv: Takmicenje.Poziv, odgovor: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth().padding(12.dp).pop(Boje.kartica, 20.dp).padding(12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        AvatarSlika(poziv.avatar, 44.dp)
        Column(Modifier.weight(1f)) {
            Text("${poziv.od} te zove", style = tekst(15.sp, FontWeight.Bold))
            Text("${poziv.naziv} · ${poziv.velicina} igrača${if (poziv.nacin == "timovi") " · timovi" else ""}", style = tekst(13.sp, FontWeight.Normal, Boje.sivaTekst))
        }
        Box(Modifier.size(44.dp).background(Boje.udubljeno, CircleShape).clickable { odgovor(false) }.semantics { contentDescription = "Odbijam" }, contentAlignment = Alignment.Center) {
            Icon(Icons.Rounded.Close, null, tint = Boje.mastilo)
        }
        Box(Modifier.size(44.dp).background(Boje.teal, CircleShape).clickable { odgovor(true) }.semantics { contentDescription = "Prihvatam" }, contentAlignment = Alignment.Center) {
            Icon(Icons.Rounded.Check, null, tint = Color.White)
        }
    }
}
