package club.librum.kviz.zajednica

import androidx.compose.animation.animateContentSize
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
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
import club.librum.kviz.ui.Papir
import club.librum.kviz.ui.naslov
import club.librum.kviz.ui.tekst
import kotlinx.coroutines.delay
import kotlinx.serialization.Serializable

/** Igrač koji je sada u aplikaciji (RPC na_mrezi, scripts/2026-11-05_na-mrezi.sql). */
@Serializable data class NaMrezi(val ko: String, val nadimak: String, val avatar: String? = null, val igra: String? = null, val od: String, val pratim: Boolean)

object Prisustvo {
    suspend fun lista(s: Sesija): List<NaMrezi>? =
        runCatching { Supabase.json.decodeFromString<List<NaMrezi>>(Supabase.rpc("na_mrezi", mapOf("p_broj" to 150), s.vazeciToken())) }.getOrNull()

    /** Otkucaj na 30 s dok je aplikacija otvorena; neuspeh se samo beleži, sledeći otkucaj pokušava ponovo. */
    suspend fun javi(s: Sesija) {
        runCatching { Supabase.rpc("javi_prisustvo", emptyMap(), s.vazeciToken()) }.onFailure { android.util.Log.w("Prisustvo", "nije javljeno", it) }
    }
}

/**
 * Svi igrači na mreži (ne samo praćeni): broj gore, spisak ispod, dodir otvara profil. Isto kao iOS NaMreziView.
 * shortcut: osvežava se na 8 s dok je ekran otvoren; kad igrača bude mnogo više, preći na Supabase Realtime presence.
 */
@Composable
fun NaMreziEkran(sesija: Sesija, idi: (String) -> Unit, nazad: () -> Unit) {
    var lista by remember { mutableStateOf<List<NaMrezi>?>(null) }
    var greska by remember { mutableStateOf(false) }
    val ja by sesija.nalog.collectAsState()
    LaunchedEffect(Unit) {
        while (true) {
            val l = Prisustvo.lista(sesija)
            if (l != null) { lista = l; greska = false } else if (lista == null) greska = true
            delay(8_000)
        }
    }
    Box(Modifier.fillMaxSize()) {
        Papir()
        LazyColumn(Modifier.fillMaxSize().statusBarsPadding(), contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)) {
            item {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.size(44.dp).background(Boje.kartica, CircleShape).border(1.5.dp, Boje.kremTamnija, CircleShape).clickable(onClick = nazad),
                        contentAlignment = Alignment.Center) { Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = "Nazad", tint = Boje.mastilo) }
                    Spacer(Modifier.width(12.dp))
                    Text("Na mreži", style = naslov(30.sp))
                }
            }
            val l = lista
            when {
                greska -> item { Text("Spisak se nije učitao. Proveri internet vezu.", style = tekst(15.sp, boja = Boje.crvena)) }
                l == null -> item { CircularProgressIndicator(color = Boje.mastilo) }
                else -> {
                    item {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            Box(Modifier.size(10.dp).background(Boje.teal, CircleShape))
                            Text("${l.size}", style = naslov(34.sp))
                            Text(if (l.size == 1) "igrač je sada u igri" else "igrača je sada u igri", style = tekst(15.sp, FontWeight.SemiBold, Boje.sivaTekst))
                        }
                    }
                    if (l.isEmpty()) item { Text("Trenutno nema nikog. Kad neko otvori aplikaciju, pojaviće se ovde.", style = tekst(15.sp, boja = Boje.sivaTekst)) }
                    else item {
                        Column(Modifier.fillMaxWidth().animateContentSize().background(Boje.kartica, RoundedCornerShape(20.dp))
                            .border(1.5.dp, Boje.kremTamnija, RoundedCornerShape(20.dp)).padding(horizontal = 12.dp)) {
                            l.forEach { i -> Red(i, mojId = ja?.id) { idi("igrac/${i.ko}") } }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun Red(i: NaMrezi, mojId: String?, otvori: () -> Unit) {
    Row(Modifier.fillMaxWidth().clickable(onClick = otvori).padding(vertical = 10.dp), verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Box {
            AvatarSlika(i.avatar, 44.dp)
            Box(Modifier.align(Alignment.BottomEnd).size(12.dp).background(Boje.teal, CircleShape).border(2.dp, Boje.krem, CircleShape))
        }
        Column(Modifier.weight(1f)) {
            Text(if (i.ko == mojId) "${i.nadimak} (ti)" else i.nadimak, style = tekst(15.sp, FontWeight.Bold), maxLines = 1)
            Text(i.igra?.let { "igra " + (Zajednica.nazivIgre[it] ?: it) } ?: "u aplikaciji", style = tekst(13.sp, boja = Boje.sivaTekst), maxLines = 1)
        }
        Text(Zajednica.pre(i.od), style = tekst(12.sp, boja = Boje.sivaTekst))
        Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, contentDescription = null, tint = Boje.sivaTekst)
    }
}
