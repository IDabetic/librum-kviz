package club.librum.kviz.osvajanje

import android.content.Intent
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.PersonAdd
import androidx.compose.material.icons.rounded.Share
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import club.librum.kviz.servisi.Sesija
import club.librum.kviz.servisi.Supabase
import club.librum.kviz.servisi.Zvuk
import club.librum.kviz.ui.AvatarSlika
import club.librum.kviz.ui.Boje
import club.librum.kviz.ui.Dugme
import club.librum.kviz.ui.Papir
import club.librum.kviz.ui.mirna
import club.librum.kviz.ui.naslov
import club.librum.kviz.ui.pop
import club.librum.kviz.ui.tekst
import club.librum.kviz.zajednica.Zajednica
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable

/**
 * Partija na poziv (isto kao iOS PozivView, server scripts/2026-11-03_osvajanje-privatne-sobe.sql): domaćin pravi
 * privatnu sobu sa kodom i poziva prijatelje porukom ili linkom librumkviz://osvajanje/KOD; partija kreće na „Počni”,
 * prazna mesta su botovi. Gost ulazi samo sa kodom.
 */
@Serializable
data class PrivatnaSoba(
    val id: String, val velicina: Int, val status: String, val mesta: List<Mesto> = emptyList(),
    val teren: String? = null, val nacin: String = "svakoZaSebe", val kod: String? = null,
) {
    @Serializable data class Mesto(val user_id: String, val mesto: Int, val nadimak: String, val avatar: String? = null)
}

@Serializable private data class Prijatelj(val id: String, val nadimak: String, val avatar: String? = null)

@Composable
fun PozivEkran(sesija: Sesija, postavka: OsvajanjePostavka?, kod: String?, izadji: () -> Unit, pocetak: () -> Unit) {
    var soba by remember { mutableStateOf<PrivatnaSoba?>(null) }
    var greska by remember { mutableStateOf<String?>(null) }
    var prijatelji by remember { mutableStateOf<List<Prijatelj>>(emptyList()) }
    var pozvani by remember { mutableStateOf(setOf<String>()) }
    var igra by remember { mutableStateOf<OsvajanjePostavka?>(null) }
    var krece by remember { mutableStateOf(false) }
    val opseg = rememberCoroutineScope()
    val kontekst = LocalContext.current
    BackHandler(onBack = izadji)

    igra?.let { OsvajanjeIgra(it, sesija, izadji, pocetak); return }

    val ja = sesija.nalog.value?.id
    val nacin = OsvajanjePostavka.Nacin.entries.firstOrNull { it.kljuc == soba?.nacin } ?: postavka?.nacin ?: OsvajanjePostavka.Nacin.SVAKO_ZA_SEBE
    val jaDomacin = soba?.mesta?.firstOrNull { it.mesto == 0 }?.user_id == ja
    val link = "librumkviz://osvajanje/${soba?.kod.orEmpty()}"

    /** Partija kreće: mesta za stolom postaju igrači (isti id na svakom telefonu), prazna su botovi. */
    fun pocni(s: PrivatnaSoba) {
        val moj = ja.orEmpty()
        val osnova = OsvajanjePostavka.mesta(nacin, s.velicina, "")
        val vojska = VrstaVojske.entries.firstOrNull { it.name == kontekst.getSharedPreferences("osvajanje", android.content.Context.MODE_PRIVATE).getString("vojska", null) }
        val igraci = osnova.mapIndexed { i, o ->
            val m = s.mesta.firstOrNull { it.mesto == i }
                ?: return@mapIndexed NoviIgrac("bot$i", OsvajanjePostavka.IMENA_BOTOVA[i % OsvajanjePostavka.IMENA_BOTOVA.size], o.boja, false, o.tim, o.kapiten)
            NoviIgrac(VezaOsvajanja.idIgraca(m.user_id), m.nadimak, o.boja, m.user_id == moj, o.tim, o.kapiten, if (m.user_id == moj) vojska else null)
        }
        val p = (postavka ?: OsvajanjePostavka(nacin, s.velicina, 12, Tezina.NORMALNO, emptyList())).copy(
            nacin = nacin, igraca = s.velicina, teren = s.teren, igraci = igraci, soba = s.id, korisnik = moj,
            domacin = s.mesta.firstOrNull { it.mesto == 0 }?.user_id == moj, traziIgrace = false,
        )
        Zvuk.pusti(Zvuk.Vrsta.BEDZ, 0.4f)
        igra = p
    }

    LaunchedEffect(Unit) {
        Zvuk.pusti(Zvuk.Vrsta.CEKANJE, 0.2f, ponavljaj = true)
        val token = sesija.vazeciToken() ?: run { greska = "Prijavi se da bi igrao sa prijateljima."; return@LaunchedEffect }
        try {
            soba = if (kod != null) Supabase.json.decodeFromString<PrivatnaSoba>(Supabase.rpc("osvajanje_udji_kodom", mapOf("p_kod" to kod), token))
            else {
                val p = postavka ?: return@LaunchedEffect
                Supabase.json.decodeFromString<PrivatnaSoba>(Supabase.rpc("osvajanje_napravi_sobu", mapOf("p_nacin" to p.nacin.kljuc, "p_velicina" to p.igraca, "p_teren" to p.teren), token))
                    .also { prijatelji = runCatching { Supabase.json.decodeFromString<List<Prijatelj>>(Supabase.rpc("osvajanje_za_poziv", emptyMap(), token)) }.getOrDefault(emptyList()) }
            }
            while (soba?.status == "ceka") {
                delay(2000)
                val s = soba ?: break
                runCatching { Supabase.json.decodeFromString<PrivatnaSoba>(Supabase.rpc("osvajanje_soba", mapOf("p_soba" to s.id), token)) }.getOrNull()?.let { nova ->
                    if (nova.mesta.size > s.mesta.size) Zvuk.pusti(Zvuk.Vrsta.PROTIVNIK_USAO, 0.45f)
                    soba = nova
                }
            }
            Zvuk.stani(Zvuk.Vrsta.CEKANJE)
            soba?.takeIf { it.status == "pocela" }?.let { pocni(it) }
        } catch (e: kotlinx.coroutines.CancellationException) {
            // Zatvorena čekaonica pre početka: mesto se oslobađa za druge.
            soba?.takeIf { it.status == "ceka" }?.let { s -> withContext(NonCancellable) { runCatching { Supabase.rpc("osvajanje_napusti", mapOf("p_soba" to s.id), token) } } }
            Zvuk.stani(Zvuk.Vrsta.CEKANJE)
            throw e
        } catch (e: Exception) {
            Zvuk.stani(Zvuk.Vrsta.CEKANJE)
            val p = e.message.orEmpty()
            greska = if ("ne postoji" in p) "Soba ne postoji ili je partija već počela. Proveri kod." else if ("puna" in p) "Soba je puna." else "Server za sobe se ne javlja. Probaj ponovo."
        }
    }
    DisposableEffect(Unit) { onDispose { Zvuk.stani(Zvuk.Vrsta.CEKANJE) } }

    Box(Modifier.fillMaxSize()) {
        Papir()
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Box(Modifier.size(44.dp).background(Boje.kartica, androidx.compose.foundation.shape.CircleShape).clickable(onClick = izadji)
                .semantics { contentDescription = "Zatvori" }, contentAlignment = Alignment.Center) { Icon(Icons.Rounded.Close, null, tint = Boje.mastilo) }
            Text("Partija sa prijateljima", style = naslov(32.sp))
            val g = greska
            val s = soba
            when {
                g != null -> { Text(g, style = tekst(15.sp, FontWeight.SemiBold, Boje.crvena)); Dugme("Nazad", radnja = izadji) }
                s == null -> CircularProgressIndicator(Modifier.align(Alignment.CenterHorizontally), color = Boje.mastilo)
                else -> {
                    Text("${nacin.naziv} · ${s.velicina} igrača · ${s.teren?.let { t -> Kontinenti.svi.firstOrNull { it.id == t }?.ime } ?: "ceo svet"}",
                        style = tekst(14.sp, FontWeight.SemiBold, Boje.sivaTekst))
                    // Kod sobe: prijatelj ga ukuca u „Imam kod” ili otvori link.
                    Column(Modifier.fillMaxWidth().pop(Boje.zuta, 20.dp).padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text("Kod sobe", style = tekst(13.sp, FontWeight.Bold, Boje.tinta))
                        Text(s.kod.orEmpty(), style = naslov(40.sp, Boje.tinta).copy(fontFamily = FontFamily.Monospace, letterSpacing = 6.sp))
                        Box(Modifier.size(52.dp, 46.dp).background(Boje.tinta, RoundedCornerShape(14.dp)).clickable {
                            kontekst.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).setType("text/plain")
                                .putExtra(Intent.EXTRA_TEXT, "Igrajmo Osvajanje sveta u Librum kvizu! Kod sobe: ${s.kod} · $link"), null))
                        }.semantics { contentDescription = "Pošalji poziv" }, contentAlignment = Alignment.Center) { Icon(Icons.Rounded.Share, null, tint = Boje.zuta) }
                    }
                    Text("Za stolom ${s.mesta.size} od ${s.velicina}", style = tekst(16.sp, FontWeight.Bold))
                    (0 until s.velicina).chunked(2).forEach { red ->
                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            red.forEach { i ->
                                val m = s.mesta.firstOrNull { it.mesto == i }
                                Row(Modifier.weight(1f).mirna().padding(10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                    if (m != null) AvatarSlika(m.avatar, 36.dp) else Icon(Icons.Rounded.PersonAdd, null, tint = Boje.sivaTekst)
                                    Column {
                                        Text(m?.nadimak ?: "Slobodno", style = tekst(14.sp, FontWeight.Bold, if (m == null) Boje.sivaTekst else Boje.mastilo), maxLines = 1)
                                        val timova = s.velicina / 2
                                        Text(if (nacin == OsvajanjePostavka.Nacin.TIMOVI) "Tim ${'A' + i % timova}" + (if (i == 0) " · domaćin" else "") else if (i == 0) "domaćin" else "igrač",
                                            style = tekst(11.sp, FontWeight.SemiBold, Boje.sivaTekst))
                                    }
                                }
                            }
                        }
                    }
                    if (jaDomacin) {
                        val ostali = prijatelji.filter { p -> s.mesta.none { it.user_id == p.id } }
                        if (ostali.isNotEmpty()) Text("Pozovi iz aplikacije", style = tekst(16.sp, FontWeight.Bold))
                        ostali.forEach { p ->
                            Row(Modifier.fillMaxWidth().mirna().padding(10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                AvatarSlika(p.avatar, 36.dp)
                                Text(p.nadimak, style = tekst(15.sp, FontWeight.SemiBold), modifier = Modifier.weight(1f))
                                val poslato = p.id in pozvani
                                Text(if (poslato) "Pozvan" else "Pozovi", style = tekst(14.sp, FontWeight.Bold, if (poslato) Boje.sivaTekst else Boje.teal),
                                    modifier = Modifier.clickable(enabled = !poslato) {
                                        pozvani = pozvani + p.id
                                        opseg.launch { runCatching { Zajednica.posaljiPoruku(sesija, p.id, "Pozivam te u Osvajanje sveta! Kod sobe: ${s.kod} · $link") } }
                                    })
                            }
                        }
                        Text(if (s.mesta.size < 2) "Čeka se bar jedan prijatelj." else "Prazna mesta preuzimaju botovi.", style = tekst(13.sp, FontWeight.Normal, Boje.sivaTekst))
                        Dugme(if (krece) "Pokrećem…" else "Počni partiju", omoguceno = s.mesta.size >= 2 && !krece) {
                            krece = true
                            opseg.launch {
                                val token = sesija.vazeciToken()
                                runCatching { Supabase.json.decodeFromString<PrivatnaSoba>(Supabase.rpc("osvajanje_pokreni_privatnu", mapOf("p_soba" to s.id), token)) }.getOrNull()?.let { soba = it }
                                krece = false
                            }
                        }
                    } else {
                        Text("Čeka se da domaćin pokrene partiju.", style = tekst(15.sp, FontWeight.SemiBold, Boje.sivaTekst))
                    }
                }
            }
        }
    }
}
