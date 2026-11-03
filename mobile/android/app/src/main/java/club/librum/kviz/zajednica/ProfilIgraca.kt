package club.librum.kviz.zajednica

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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.automirrored.rounded.Send
import androidx.compose.material.icons.rounded.Block
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import club.librum.kviz.servisi.Sesija
import club.librum.kviz.servisi.Supabase
import club.librum.kviz.ui.AvatarSlika
import club.librum.kviz.ui.Boje
import club.librum.kviz.ui.Dijalog
import club.librum.kviz.ui.Dugme
import club.librum.kviz.ui.Maskota
import club.librum.kviz.ui.MaskotaSlika
import club.librum.kviz.ui.Oznaka
import club.librum.kviz.ui.Papir
import club.librum.kviz.ui.VrstaDugmeta
import club.librum.kviz.ui.mirna
import club.librum.kviz.ui.naslov
import club.librum.kviz.ui.tekst
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable

/** Odgovor RPC profil_igraca (scripts/2026-11-03_profil-kao-ig.sql), isti za moj i tuđi profil. */
@Serializable data class ProfilIgraca(
    val nadimak: String, val avatar: String? = null, val ime: String? = null, val grad: String? = null, val bio: String? = null,
    val pratilaca: Int = 0, val prati: Int = 0, val ja_pratim: Boolean = false,
    val poslao_pitanja: Int = 0, val u_igri_pitanja: Int = 0, val partija: Int = 0,
    val igre: List<Igra> = emptyList(), val pitanja: Pitanja? = null,
) {
    @Serializable data class Igra(val igra: String, val partija: Int, val najbolje: Int, val tacnost: Int? = null)
    @Serializable data class Pitanja(val odgovora: Int, val jedinstvenih: Int, val ponovljenih: Int, val tacnost: Int? = null)
}

@Serializable data class NadjenIgrac(val id: String, val nadimak: String, val avatar: String? = null, val pratim: Boolean = false)

object Drustvo {
    suspend fun profil(s: Sesija, id: String): ProfilIgraca =
        Supabase.json.decodeFromString(Supabase.rpc("profil_igraca", mapOf("p_id" to id), runCatching { s.vazeciToken() }.getOrNull()))

    suspend fun trazi(s: Sesija, upit: String): List<NadjenIgrac> =
        Supabase.json.decodeFromString(Supabase.rpc("trazi_igrace", mapOf("p_upit" to upit, "p_broj" to 30), s.vazeciToken()))

    /** Prati ili prestaje da prati (tabela pracenja, kao iOS Drustvo.prati); true kad je uspelo. */
    suspend fun prati(s: Sesija, id: String, da: Boolean): Boolean = runCatching {
        val ja = s.id ?: error("nisi prijavljen")
        val t = s.vazeciToken() ?: error("nisi prijavljen")
        if (da) Supabase.upisi("pracenja", mapOf("ko" to ja, "koga" to id), t)
        else Supabase.zahtev("rest/v1/pracenja", "DELETE", token = t, upit = listOf("ko" to "eq.$ja", "koga" to "eq.$id"))
    }.isSuccess
}

/** „1 pitanje”, „21 pitanje”, inače „pitanja” (2–4 i 5+ imaju isti oblik). */
internal fun pitanja(n: Int) = if (n % 10 == 1 && n % 100 != 11) "pitanje" else "pitanja"

/** Zaglavlje kao na Instagramu: slika, brojevi (partija, pratilaca, prati), ime, grad, bio i pitanja koja je igrač poslao. */
@Composable
fun ProfilZaglavlje(p: ProfilIgraca, radnje: @Composable () -> Unit = {}) {
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(18.dp)) {
            AvatarSlika(p.avatar, 88.dp)
            listOf(p.partija to "partija", p.pratilaca to "pratilaca", p.prati to "prati").forEach { (n, naziv) ->
                Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(Zajednica.broj(n), style = naslov(22.sp))
                    Text(naziv, style = tekst(13.sp, boja = Boje.sivaTekst))
                }
            }
        }
        Text(p.nadimak, style = tekst(18.sp, FontWeight.Bold))
        listOfNotNull(p.ime, p.grad).map { it.trim().replace(Regex("\\s+"), " ") }.filter { it.isNotEmpty() }.joinToString(" · ").takeIf { it.isNotEmpty() }?.let { Text(it, style = tekst(14.sp, boja = Boje.sivaTekst)) }
        p.bio?.takeIf { it.isNotBlank() }?.let { Text(it, style = tekst(15.sp)) }
        if (p.poslao_pitanja > 0) Text("Poslao ${p.poslao_pitanja} ${pitanja(p.poslao_pitanja)} · ${p.u_igri_pitanja} u igri", style = tekst(14.sp, FontWeight.SemiBold, Boje.teal))
        radnje()
    }
}

/** Pitanja (jedinstvena i ponovljena) i rekordi po igri. */
@Composable
fun ProfilStatistike(p: ProfilIgraca) {
    p.pitanja?.let { q ->
        Oznaka("Pitanja")
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            listOf(q.odgovora to "odgovora", q.jedinstvenih to "jedinstvenih", q.ponovljenih to "ponovljenih").forEach { (n, naziv) ->
                Column(Modifier.weight(1f).mirna().padding(12.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(Zajednica.broj(n), style = naslov(22.sp))
                    Text(naziv, style = tekst(12.sp, boja = Boje.sivaTekst))
                }
            }
        }
        q.tacnost?.let { Text("Tačnost $it%", style = tekst(14.sp, FontWeight.SemiBold)) }
    }
    if (p.igre.isNotEmpty()) {
        Oznaka("Po igrama")
        Column(Modifier.fillMaxWidth().mirna()) {
            p.igre.forEachIndexed { i, g ->
                Row(Modifier.fillMaxWidth().padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(Zajednica.nazivIgre[g.igra] ?: g.igra, style = tekst(15.sp, FontWeight.SemiBold))
                        Text("${g.partija} partija" + (g.tacnost?.let { " · $it% tačno" } ?: ""), style = tekst(13.sp, boja = Boje.sivaTekst))
                    }
                    Text(Zajednica.broj(g.najbolje), style = naslov(20.sp))
                }
                if (i < p.igre.size - 1) HorizontalDivider(color = Boje.kremTamnija)
            }
        }
    }
}

/** Tuđi profil: Prati, Izazovi, poruka i blokada. Dodaj pitanje/reč se ovde ne vidi. */
@Composable
fun ProfilIgracaEkran(sesija: Sesija, id: String, idi: (String) -> Unit, nazad: () -> Unit) {
    val nalog by sesija.nalog.collectAsState()
    var p by remember { mutableStateOf<ProfilIgraca?>(null) }
    var greska by remember { mutableStateOf<String?>(null) }
    var blokada by remember { mutableStateOf(false) }
    val opseg = rememberCoroutineScope()
    suspend fun ucitaj() { runCatching { Drustvo.profil(sesija, id) }.onSuccess { p = it; greska = null }.onFailure { greska = it.message } }
    LaunchedEffect(id) { ucitaj() }

    Box(Modifier.fillMaxSize()) {
        Papir()
        Column(Modifier.fillMaxSize().statusBarsPadding().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            IconButton(onClick = nazad, modifier = Modifier.size(44.dp).background(Boje.kartica, CircleShape).border(1.5.dp, Boje.kremTamnija, CircleShape)) {
                Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = "Nazad", tint = Boje.mastilo)
            }
            val pr = p
            when {
                pr == null && greska != null -> Column(Modifier.fillMaxWidth().mirna().padding(20.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    MaskotaSlika(Maskota.LUMI, 100.dp)
                    Text("Profil se nije učitao", style = naslov(22.sp))
                    Dugme("Pokušaj ponovo") { opseg.launch { ucitaj() } }
                }
                pr == null -> CircularProgressIndicator(color = Boje.mastilo)
                else -> {
                    ProfilZaglavlje(pr) {
                        if (nalog != null && nalog?.id != id) Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                            Dugme(if (pr.ja_pratim) "Pratiš" else "Prati", Modifier.weight(1f), if (pr.ja_pratim) VrstaDugmeta.SEKUNDARNO else VrstaDugmeta.PRIMARNO) {
                                opseg.launch { if (Drustvo.prati(sesija, id, !pr.ja_pratim)) ucitaj() }
                            }
                            Dugme("Izazovi", Modifier.weight(1f), VrstaDugmeta.ZUTO) { idi("duel/izazov/$id") }
                            KockaIkonica(Icons.AutoMirrored.Rounded.Send, "Pošalji poruku") { idi("razgovor/$id/${pr.nadimak}") }
                            KockaIkonica(Icons.Rounded.Block, "Blokiraj") { blokada = true }
                        }
                    }
                    ProfilStatistike(pr)
                }
            }
            Spacer(Modifier.height(40.dp))
        }
        if (blokada) Dijalog("Blokirati ${p?.nadimak}?", "Više se nećete videti: ni objave, ni komentari, ni poruke. Praćenje se briše.", "Blokiraj", "Odustani",
            potvrdi = { blokada = false; opseg.launch { if (Zajednica.radnja(sesija, "blokiraj", mapOf("p_id" to id, "p_da" to true))) nazad() } },
            zatvori = { blokada = false })
    }
}

@Composable
private fun KockaIkonica(ikonica: androidx.compose.ui.graphics.vector.ImageVector, opis: String, radnja: () -> Unit) {
    IconButton(onClick = radnja, modifier = Modifier.size(54.dp).background(Boje.kartica, RoundedCornerShape(16.dp)).border(2.dp, Boje.mastilo, RoundedCornerShape(16.dp))) {
        Icon(ikonica, contentDescription = opis, tint = Boje.mastilo)
    }
}

/** Pretraga igrača po nadimku. */
@Composable
fun TraziIgraceEkran(sesija: Sesija, idi: (String) -> Unit, nazad: () -> Unit) {
    var upit by remember { mutableStateOf("") }
    var nadjeni by remember { mutableStateOf<List<NadjenIgrac>>(emptyList()) }
    LaunchedEffect(upit) {
        if (upit.trim().length < 2) { nadjeni = emptyList(); return@LaunchedEffect }
        kotlinx.coroutines.delay(300)
        nadjeni = runCatching { Drustvo.trazi(sesija, upit.trim()) }.getOrDefault(emptyList())
    }
    Box(Modifier.fillMaxSize()) {
        Papir()
        Column(Modifier.fillMaxSize().statusBarsPadding().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            IconButton(onClick = nazad, modifier = Modifier.size(44.dp).background(Boje.kartica, CircleShape).border(1.5.dp, Boje.kremTamnija, CircleShape)) {
                Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = "Nazad", tint = Boje.mastilo)
            }
            Text("Nađi igrače", style = naslov(30.sp))
            PoljeTeksta(upit, "Nadimak…") { upit = it.take(40) }
            if (upit.trim().length >= 2 && nadjeni.isEmpty()) Text("Nema igrača sa tim nadimkom.", style = tekst(15.sp, boja = Boje.sivaTekst))
            if (nadjeni.isNotEmpty()) Column(Modifier.fillMaxWidth().mirna()) {
                nadjeni.forEachIndexed { i, g ->
                    Row(Modifier.fillMaxWidth().clickable { idi("igrac/${g.id}") }.padding(horizontal = 14.dp, vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        AvatarSlika(g.avatar, 44.dp)
                        Text(g.nadimak, style = tekst(16.sp, FontWeight.SemiBold), modifier = Modifier.weight(1f))
                        if (g.pratim) Text("Pratiš", style = tekst(13.sp, FontWeight.Bold, Boje.teal))
                    }
                    if (i < nadjeni.size - 1) HorizontalDivider(color = Boje.kremTamnija)
                }
            }
        }
    }
}
