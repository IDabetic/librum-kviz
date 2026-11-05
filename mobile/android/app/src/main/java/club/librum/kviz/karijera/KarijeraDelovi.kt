package club.librum.kviz.karijera

import android.annotation.SuppressLint
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Image
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
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.ThumbUp
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch
import club.librum.kviz.ui.Boje
import club.librum.kviz.ui.Dugme
import club.librum.kviz.ui.Oznaka
import club.librum.kviz.ui.mirna
import club.librum.kviz.ui.naslov
import club.librum.kviz.ui.pop
import club.librum.kviz.ui.tekst

object KarijeraBoje { val plava = Color(0xFF2F6FD6) }

/** Slika iz res/drawable-nodpi po imenu (isto ime kao iOS asset, malim slovima). */
@Composable
fun KSlika(ime: String, modifier: Modifier = Modifier, opis: String? = null, skala: ContentScale = ContentScale.Fit) {
    val k = LocalContext.current
    @SuppressLint("DiscouragedApi")
    val id = remember(ime) { k.resources.getIdentifier(ime, "drawable", k.packageName) }
    if (id != 0) Image(painterResource(id), opis, modifier, contentScale = skala)
}

@Composable
fun KNazad(opis: String = "Nazad", nazad: () -> Unit) {
    IconButton(onClick = nazad, modifier = Modifier.size(44.dp).background(Boje.kartica, CircleShape).border(1.5.dp, Boje.kremTamnija, CircleShape)) {
        Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = opis, tint = Boje.mastilo)
    }
}

/** Red u spisku: naziv, vrednost sivo, strelica. */
@Composable
fun KRed(naziv: String, vrednost: String? = null, boja: Color = Boje.mastilo, radnja: () -> Unit) {
    Row(Modifier.fillMaxWidth().clickable(role = Role.Button, onClick = radnja).padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(naziv, style = tekst(15.sp, FontWeight.SemiBold, boja), modifier = Modifier.weight(1f))
        if (vrednost != null) Text(vrednost, style = tekst(14.sp, boja = Boje.sivaTekst), maxLines = 1, modifier = Modifier.padding(start = 8.dp))
        Text(" ›", style = tekst(20.sp, FontWeight.Bold, Boje.sivaTekst))
    }
}

/** Prekidač u stilu aplikacije (ne sistemski). */
@Composable
fun KPrekidac(ukljuceno: Boolean, naziv: String, promeni: (Boolean) -> Unit) {
    val pomeraj by animateFloatAsState(if (ukljuceno) 1f else 0f, label = "prekidac")
    Box(
        Modifier.width(52.dp).height(32.dp).background(if (ukljuceno) Boje.teal else Boje.kremTamnija, RoundedCornerShape(16.dp))
            .border(2.dp, Boje.mastilo, RoundedCornerShape(16.dp))
            .semantics { contentDescription = naziv; selected = ukljuceno }
            .clickable(role = Role.Switch) { promeni(!ukljuceno) }.padding(3.dp),
    ) {
        Box(Modifier.offset(x = 20.dp * pomeraj).size(22.dp).background(Color.White, CircleShape).border(1.5.dp, Boje.mastilo, CircleShape))
    }
}

@Composable
fun KSkelet(visina: Dp) { Box(Modifier.fillMaxWidth().height(visina).background(Boje.skelet, RoundedCornerShape(20.dp))) }

@Composable
fun KGreska(poruka: String, ponovo: () -> Unit) {
    Column(Modifier.fillMaxWidth().pop().padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("Nije uspelo", style = naslov(22.sp))
        Text(poruka, style = tekst(15.sp))
        Dugme("Pokušaj ponovo") { ponovo() }
    }
}

/** Slika na nebu tog dana (zgrada firme, šef, asistent) u zaobljenom okviru. */
@Composable
fun NaNebu(slika: String, mesto: String, modifier: Modifier = Modifier, visinaSlike: Dp = 190.dp) {
    Box(modifier.fillMaxWidth().clip(RoundedCornerShape(24.dp)).border(2.dp, Boje.mastilo, RoundedCornerShape(24.dp)), contentAlignment = Alignment.BottomCenter) {
        Nebo(Modifier.matchParentSize(), mesto)
        KSlika(slika, Modifier.padding(top = 20.dp).height(visinaSlike))
        if (slika.contains("zgrada") || slika.contains("korporacija")) Ulica(Modifier.matchParentSize(), mesto)
    }
}

/** Šef sa oblačićem posle odgovora; dodir ga zatvara. */
@Composable
fun SefKaze(povod: Sef.Povod, tekstPoruke: String, lik: String, zatvori: () -> Unit) {
    val zensko = Sef.lik(lik).zensko
    Row(Modifier.fillMaxWidth().clickable(onClick = zatvori).semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        KSlika(Sef.slika(povod, lik, Sef.jeSmeh(tekstPoruke)), Modifier.width(80.dp).height(96.dp))
        Column(Modifier.weight(1f).pop(radijus = 18.dp, senka = 0.dp).padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Oznaka(if (zensko) "Šefica kaže" else "Šef kaže", if (povod == Sef.Povod.TACNO) Boje.teal else Boje.crvena)
            // Najviše dva reda (vlasnik 05.11); rečenice su ≤ 52 znaka, test `dvaReda`.
            Text(tekstPoruke, style = tekst(15.sp, FontWeight.Bold), maxLines = 2, overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis)
        }
    }
}

/** Ometanje: upad je traka gore (ne blokira), zadatak pokriva odgovore dok se ne pritisne „Odmah, šefe” (traka sa satom ostaje). */
@Composable
fun OmetanjeTraka(o: Sef.Ometanje, lik: String, zatvori: () -> Unit) {
    val tekstO = Sef.oblik(o.tekst, Karijera.mojPol == "z")
    val zensko = Sef.lik(lik).zensko
    if (o.vrsta == Sef.Vrsta.ZADATAK) {
        Column(
            Modifier.fillMaxSize().padding(top = 50.dp).background(Boje.kartica.copy(alpha = 0.97f), RoundedCornerShape(24.dp))
                .border(2.dp, Boje.mastilo, RoundedCornerShape(24.dp)).clickable(enabled = false) {}.padding(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp, Alignment.CenterVertically),
        ) {
            KSlika(Sef.slika(o, lik), Modifier.height(90.dp))
            Text(tekstO, style = naslov(22.sp), textAlign = TextAlign.Center)
            Row(Modifier.fillMaxWidth().background(Boje.mastilo, RoundedCornerShape(18.dp)).clickable(role = Role.Button, onClick = zatvori).padding(16.dp),
                horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Rounded.ThumbUp, null, tint = Boje.naMastilu)
                Spacer(Modifier.width(8.dp))
                Text(if (zensko) "Odmah, šefice" else "Odmah, šefe", style = tekst(16.sp, FontWeight.Bold, Boje.naMastilu))
            }
        }
    } else {
        Row(
            Modifier.fillMaxWidth().padding(8.dp).rotate(-2f).background(Boje.kartica, RoundedCornerShape(18.dp)).border(2.dp, Boje.mastilo, RoundedCornerShape(18.dp))
                .padding(12.dp).semantics { contentDescription = "${if (zensko) "Šefica" else "Šef"}: $tekstO" },
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            KSlika(Sef.slika(o, lik), Modifier.width(48.dp).height(54.dp))
            Text(tekstO, style = tekst(17.sp, FontWeight.Bold), modifier = Modifier.weight(1f))
        }
    }
}

/** Sedam dana u nedelji, bira se do 3. Kvadratići, ne pilule. */
@Composable
fun SlobodniDaniIzbor(dani: List<Int>, promeni: (List<Int>) -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        for (d in 1..7) {
            val da = d in dani
            val moze = da || dani.size < 3
            Box(
                Modifier.weight(1f).height(44.dp).background(if (da) Boje.zuta else Boje.kartica, RoundedCornerShape(10.dp))
                    .border(if (da) 2.dp else 1.dp, Boje.mastilo, RoundedCornerShape(10.dp))
                    .semantics { selected = da }
                    .clickable(enabled = moze, role = Role.Checkbox) { promeni(if (da) dani - d else dani + d) },
                contentAlignment = Alignment.Center,
            ) { Text(Karijera.daniKratko[d - 1], style = tekst(13.sp, FontWeight.Bold, if (da) Boje.tinta else Boje.mastilo)) }
        }
    }
}

const val SLOBODNI_OBJASNJENJE = "Tih dana ne moraš da dolaziš u firmu, niko ne može da te izazove na duel, a ko ipak igra radi prekovremeno: plata i kasa +10%. Menja se jednom u 7 dana."

/** Kartica u spisku: neka sadržina, „mirna” podloga kao ostatak aplikacije. */
@Composable
fun KSpisak(sadrzaj: @Composable () -> Unit) { Column(Modifier.fillMaxWidth().mirna()) { sadrzaj() } }

/** Podešavanja Karijere na profilu (kao iOS): Mirni šef i Reset Karijere sa potvrdom. */
@Composable
fun KarijeraPodesavanja() {
    var mirni by androidx.compose.runtime.remember { androidx.compose.runtime.mutableStateOf(Karijera.mirni) }
    var potvrda by androidx.compose.runtime.remember { androidx.compose.runtime.mutableStateOf(false) }
    var poruka by androidx.compose.runtime.remember { androidx.compose.runtime.mutableStateOf<String?>(null) }
    val opseg = androidx.compose.runtime.rememberCoroutineScope()
    androidx.compose.runtime.LaunchedEffect(Unit) { runCatching { Karijera.stanje() }.onSuccess { mirni = it.mirni ?: false; Karijera.mirni = mirni } }
    Column(Modifier.fillMaxWidth().mirna()) {
        Row(Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text("Mirni šef u Karijeri", style = tekst(15.sp, FontWeight.SemiBold))
                Text("Šef najviše blag, bez ometanja; bez dodatka za stres.", style = tekst(12.sp, boja = Boje.sivaTekst))
            }
            KPrekidac(mirni, "Mirni šef u Karijeri") { v ->
                mirni = v
                opseg.launch { runCatching { Karijera.postaviMirni(v) }.onSuccess { mirni = it.mirni; Karijera.mirni = it.mirni }.onFailure { mirni = !v; poruka = it.message } }
            }
        }
        androidx.compose.material3.HorizontalDivider(color = Boje.kremTamnija)
        KRed("Resetuj Karijeru", boja = Boje.crvena) { potvrda = true }
    }
    poruka?.let { Text(it, style = tekst(14.sp, FontWeight.SemiBold, Boje.sivaTekst)) }
    if (potvrda) club.librum.kviz.ui.Dijalog("Resetovati Karijeru?",
        "Krećeš ispočetka: nova struka, pol i talenti. Brišu se kapital, ugled, ekspertiza i CV. Tvoje firme prelaze na upravu i mogu se preuzeti duelom. Ovo ne može da se vrati.",
        "Resetuj", "Odustani",
        potvrdi = { potvrda = false; opseg.launch { runCatching { Karijera.resetuj() }.onSuccess { poruka = "Karijera je resetovana." }.onFailure { poruka = it.message } } },
        zatvori = { potvrda = false })
}
