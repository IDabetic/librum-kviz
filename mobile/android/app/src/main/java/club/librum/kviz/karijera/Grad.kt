package club.librum.kviz.karijera

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.MyLocation
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import club.librum.kviz.ui.Boje
import club.librum.kviz.ui.mirna
import club.librum.kviz.ui.naslov
import club.librum.kviz.ui.tekst
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable

/** Zgrada u gradu (server `karijera_grad_mapa`, `karijera_trazi_firmu`); parcela određuje mesto na mapi (IsoRaspored). */
@Serializable
data class GradFirma(val id: String, val ime: String, val korporacija: Boolean = false, val nivo: Int = 1, val stil: Int = 1,
                     val vlasnik_ime: String = "", val parcela: Int = 0, val balon: String? = null) {
    val slika get() = Karijera.slikaZgrade(korporacija, nivo, stil)
}

/** Sve firme po 500 (keyset po parceli), dok ne stignu sve. */
suspend fun mapaGrada(): List<GradFirma> {
    val sve = mutableListOf<GradFirma>()
    var posle = -1
    while (true) {
        val deo = Karijera.rpc<List<GradFirma>>("karijera_grad_mapa", mapOf("p_posle" to posle))
        sve += deo
        if (deo.size < 500) return sve
        posle = deo.last().parcela
    }
}

/** Grad Karijere (isto kao iOS GradView): jedna velika izometrijska mapa, pretraga, dodir na zgradu otvara firmu. */
@Composable
fun GradEkran(idi: (KEkran) -> Unit, nazad: () -> Unit) {
    var firme by remember { mutableStateOf<List<GradFirma>?>(null) }
    var greska by remember { mutableStateOf<String?>(null) }
    var upit by remember { mutableStateOf("") }
    var nadjene by remember { mutableStateOf<List<GradFirma>>(emptyList()) }
    var oznacena by remember { mutableStateOf<String?>(null) }
    var centriraj by remember { mutableStateOf<Int?>(null) }
    var moje by remember { mutableStateOf(emptySet<String>()) }
    var posao by remember { mutableStateOf<String?>(null) }
    val opseg = rememberCoroutineScope()

    suspend fun ucitaj() { runCatching { mapaGrada() }.onSuccess { firme = it; greska = null }.onFailure { greska = it.message } }
    LaunchedEffect(Unit) {
        runCatching { Karijera.stanje() }.onSuccess { s -> moje = s.firme.map { it.id }.toSet(); posao = s.posao?.id }
        ucitaj()
    }
    LaunchedEffect(upit) {
        if (upit.length < 2) { nadjene = emptyList(); return@LaunchedEffect }
        delay(300)
        nadjene = runCatching { Karijera.rpc<List<GradFirma>>("karijera_trazi_firmu", mapOf("p_upit" to upit)) }.getOrDefault(emptyList())
    }

    Box(Modifier.fillMaxSize()) {
        club.librum.kviz.ui.Papir()
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.weight(1f)) { KNazad { nazad() } }
                Box(Modifier.size(44.dp).background(Boje.kartica, RoundedCornerShape(22.dp)).border(1.5.dp, Boje.kremTamnija, RoundedCornerShape(22.dp))
                    .clickable(role = Role.Button) {
                        val f = firme ?: return@clickable
                        val moja = f.firstOrNull { it.id in moje } ?: f.firstOrNull { it.id == posao } ?: f.firstOrNull { it.korporacija }
                        moja?.let { oznacena = it.id; centriraj = it.parcela }
                    }.semantics { contentDescription = "Moja firma" }, contentAlignment = Alignment.Center) {
                    Icon(Icons.Rounded.MyLocation, null, tint = Boje.mastilo)
                }
            }
            Text("Grad", style = naslov(34.sp))
            Row(Modifier.fillMaxWidth().height(50.dp).background(Boje.kartica, RoundedCornerShape(16.dp)).border(2.dp, Boje.mastilo, RoundedCornerShape(16.dp)).padding(horizontal = 14.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Icon(Icons.Rounded.Search, null, tint = Boje.sivaTekst)
                Box(Modifier.weight(1f)) {
                    if (upit.isEmpty()) Text("Nađi firmu po imenu", style = tekst(16.sp, boja = Boje.sivaTekst))
                    BasicTextField(upit, { upit = it }, singleLine = true, textStyle = tekst(16.sp), cursorBrush = SolidColor(Boje.mastilo), modifier = Modifier.fillMaxWidth())
                }
            }
            if (nadjene.isNotEmpty()) Column(Modifier.fillMaxWidth().mirna()) {
                nadjene.take(6).forEachIndexed { i, f ->
                    Row(Modifier.fillMaxWidth().clickable(role = Role.Button) { oznacena = f.id; centriraj = f.parcela; upit = ""; nadjene = emptyList() }
                        .padding(horizontal = 12.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        KSlika(f.slika, Modifier.size(34.dp))
                        Column(Modifier.weight(1f)) {
                            Text(f.ime, style = tekst(15.sp, FontWeight.Bold), maxLines = 1, overflow = TextOverflow.Ellipsis)
                            Text(f.vlasnik_ime, style = tekst(12.sp, boja = Boje.sivaTekst))
                        }
                    }
                    if (i < minOf(nadjene.size, 6) - 1) HorizontalDivider(color = Boje.kremTamnija)
                }
            }
            val f = firme
            when {
                greska != null && f == null -> KGreska(greska!!) { opseg.launch { ucitaj() } }
                f == null -> KSkelet(420.dp)
                else -> {
                    IsoGrad(Modifier.fillMaxWidth().weight(1f).clip(RoundedCornerShape(24.dp)).border(2.dp, Boje.mastilo, RoundedCornerShape(24.dp)),
                        f, moje, posao, oznacena, centriraj, { centriraj = null }) { idi(KEkran.FirmaE(it.id)) }
                    Text("${f.size} firmi · pomeraj i zumiraj prstima, dodirni zgradu", style = tekst(12.sp, FontWeight.SemiBold, Boje.sivaTekst))
                }
            }
        }
    }
}
