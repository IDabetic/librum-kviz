package club.librum.kviz.osvajanje

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import club.librum.kviz.servisi.PaketPitanja
import club.librum.kviz.ui.Boje
import club.librum.kviz.ui.Dijalog
import club.librum.kviz.ui.Dugme
import club.librum.kviz.ui.Maskota
import club.librum.kviz.ui.MaskotaSlika
import club.librum.kviz.ui.Oznaka
import club.librum.kviz.ui.Papir
import club.librum.kviz.ui.PitanjeKartica
import club.librum.kviz.ui.VrstaDugmeta
import club.librum.kviz.ui.mirna
import club.librum.kviz.ui.naslov
import club.librum.kviz.ui.pop
import club.librum.kviz.ui.tekst

private val PRAVILA = listOf(
    "Snabdevanje" to "Na početku poteza jedno pitanje. Tačno donosi pune vojske, netačno pola.",
    "Napad" to "Iz oblasti sa bar 2 vojske napadaš susednu. Protiv rivala odgovarate oboje, a izjednačenje rešava brzina.",
    "Proboj" to "Posle osvajanja cepaš dalje iz nove oblasti. Svako treće osvajanje u nizu donosi +2 vojske.",
    "Regioni" to "Svet je podeljen na 17 regiona. Ceo region donosi bonus vojske svakog poteza.",
    "Prestonica" to "Počinješ sa prestonicom i pet susednih država. Tuđa prestonica nosi +5 vojski plena.",
)

/** Uvod: izbor jačine i dužine partije, pravila. */
@Composable
fun OsvajanjeUvod(pokreni: (Tezina, Int) -> Unit) {
    Box(Modifier.fillMaxSize()) {
        Papir()
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            Box(Modifier.fillMaxWidth().pop(Boje.teal).clip(RoundedCornerShape(24.dp))) {
                Box(Modifier.align(Alignment.BottomEnd).padding(end = 0.dp).size(220.dp).alpha(0.14f).background(Color.White, CircleShape))
                MaskotaSlika(Maskota.MIMI, 110.dp, Modifier.align(Alignment.BottomEnd).padding(8.dp))
                Column(Modifier.padding(22.dp).padding(end = 110.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Oznaka("Glavna igra · 3 igrača", Boje.zuta)
                    Text("Osvajanje\nsveta", style = naslov(42.sp).copy(color = Color.White, lineHeight = 44.sp))
                    Text("171 država, 17 regiona i dva rivala. Svaku državu osvajaš pitanjem.", style = tekst(15.sp, FontWeight.SemiBold, Color.White.copy(alpha = 0.9f)))
                }
            }
            Column(Modifier.fillMaxWidth().mirna().padding(20.dp)) {
                Text("Nova partija", style = naslov(26.sp))
                Tezina.entries.forEachIndexed { i, t ->
                    Column(Modifier.padding(vertical = 14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(t.ime, style = tekst(17.sp, FontWeight.Bold))
                        Text(t.opis, style = tekst(13.sp, boja = Boje.sivaTekst))
                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            Dugme("8 krugova", Modifier.weight(1f), VrstaDugmeta.SEKUNDARNO) { pokreni(t, 8) }
                            Dugme("12 krugova", Modifier.weight(1f)) { pokreni(t, 12) }
                        }
                    }
                    if (i < Tezina.entries.size - 1) HorizontalDivider(color = Boje.kremTamnija)
                }
            }
            Column(Modifier.fillMaxWidth().mirna().padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("Pravila", style = naslov(26.sp))
                PRAVILA.forEachIndexed { i, (naslovPravila, opis) ->
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Box(Modifier.size(28.dp).background(Boje.zuta, RoundedCornerShape(8.dp)).border(1.5.dp, Boje.mastilo, RoundedCornerShape(8.dp)), contentAlignment = Alignment.Center) {
                            Text("${i + 1}", style = tekst(13.sp, FontWeight.Bold))
                        }
                        Text(buildAnnotatedString {
                            withStyle(SpanStyle(fontWeight = FontWeight.Bold)) { append("$naslovPravila. ") }
                            append(opis)
                        }, style = tekst(14.sp))
                    }
                }
            }
            Spacer(Modifier.height(80.dp))
        }
    }
}

private val MASKOTE = mapOf("ti" to Maskota.BLOOP, "mimi" to Maskota.MIMI, "zig" to Maskota.ZIG)

/** Partija: igrači gore, mapa u sredini, radnje dole, pitanje preko svega. */
@Composable
fun OsvajanjeIgra(tezina: Tezina, krugova: Int, ime: String?, izadji: () -> Unit) {
    val kontekst = LocalContext.current.applicationContext
    val model: OsvajanjeModel = viewModel(key = "osvajanje-$tezina-$krugova") { OsvajanjeModel(krugova, tezina, ime, PaketPitanja(kontekst)) }
    var potvrdaIzlaska by remember { mutableStateOf(false) }
    BackHandler { potvrdaIzlaska = true }

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
            !model.spremno -> CircularProgressIndicator(Modifier.align(Alignment.Center).semantics { contentDescription = "Učitavanje pitanja" }, color = Boje.mastilo)
            else -> Igra(model) { potvrdaIzlaska = true }
        }

        model.poruka?.let { poruka ->
            Text(poruka, style = tekst(15.sp, FontWeight.Bold),
                modifier = Modifier.align(Alignment.TopCenter).padding(top = 150.dp).pop(Boje.zuta, 16.dp).padding(horizontal = 18.dp, vertical = 12.dp))
        }

        AnimatedVisibility(model.otvoreno != null, enter = fadeIn(), exit = fadeOut()) {
            val o = model.otvoreno
            Box(Modifier.fillMaxSize().background(Boje.mastilo.copy(alpha = 0.6f))) {
                if (o != null) {
                    Column(Modifier.verticalScroll(rememberScrollState()).statusBarsPadding().padding(16.dp).padding(top = 30.dp)) {
                        val oznaka = when (o.vrsta) {
                            OsvajanjeModel.Vrsta.SNABDEVANJE -> "Snabdevanje"
                            OsvajanjeModel.Vrsta.NAPAD -> "Napad · ${Mapa.oblast(o.kuda!!).ime}"
                            OsvajanjeModel.Vrsta.ODBRANA -> "Odbrana · ${Mapa.oblast(o.kuda!!).ime}"
                        }
                        val dodatak = o.rival?.let { "Rival je odgovorio ${if (it.tacan) "tačno" else "netačno"} za ${"%.1f".format(it.ms / 1000.0)} s" }
                        PitanjeKartica(oznaka, o.prikaz, dodatak = dodatak) { izabran, ms -> model.odgovoreno(izabran, ms) }
                    }
                }
            }
        }

        if (model.stanje.faza == Faza.KRAJ) Kraj(model, izadji)
        if (potvrdaIzlaska) Dijalog("Napuštaš partiju?", "Partija se ne čuva.", "Izađi", "Ostani", potvrdi = izadji, zatvori = { potvrdaIzlaska = false })
    }
}

@Composable
private fun Igra(model: OsvajanjeModel, izlaz: () -> Unit) {
    val s = model.stanje
    Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(Modifier.padding(horizontal = 16.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            IconButton(onClick = izlaz, modifier = Modifier.size(44.dp).background(Color.White, CircleShape).border(1.5.dp, Boje.kremTamnija, CircleShape)) {
                Icon(Icons.Rounded.Close, contentDescription = "Izađi", tint = Boje.mastilo)
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                val krug = minOf(s.krug, s.ukupnoKrugova)
                Oznaka("Krug $krug od ${s.ukupnoKrugova}")
                Box(Modifier.fillMaxWidth().height(10.dp).background(Color.White, RoundedCornerShape(5.dp)).border(1.5.dp, Boje.mastilo, RoundedCornerShape(5.dp))) {
                    Box(Modifier.fillMaxWidth(krug.toFloat() / s.ukupnoKrugova).height(10.dp).background(Boje.teal, RoundedCornerShape(5.dp)))
                }
            }
        }
        Row(Modifier.padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            for (p in s.igraci) {
                val naPotezu = p.id == s.trenutni.id && s.faza != Faza.KRAJ
                Row(
                    Modifier.weight(1f).alpha(if (p.ispao) 0.4f else 1f)
                        .background(Color.White, RoundedCornerShape(14.dp))
                        .border(if (naPotezu) 2.5.dp else 1.5.dp, if (naPotezu) Boje.mastilo else Boje.kremTamnija, RoundedCornerShape(14.dp))
                        .padding(6.dp)
                        .semantics(mergeDescendants = true) { contentDescription = "${p.ime}, ${s.poeni(p.id)} poena${if (naPotezu) ", na potezu" else ""}" },
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Box(Modifier.size(36.dp).background(Color(p.boja), RoundedCornerShape(10.dp)), contentAlignment = Alignment.Center) {
                        MaskotaSlika(MASKOTE[p.id] ?: Maskota.BLOOP, 30.dp)
                    }
                    Column {
                        Text(p.ime, style = tekst(12.sp, FontWeight.Bold), maxLines = 1)
                        Text("${s.poeni(p.id)}", style = naslov(16.sp))
                    }
                }
            }
        }
        MapaPrikaz(s, model.izabrana, model.mete, model.otvoreno?.kuda ?: model.izabrana ?: s.igraci.firstOrNull { it.covek }?.prestonica,
            model::dodir, Modifier.weight(1f).fillMaxWidth().padding(horizontal = 12.dp))
        Column(Modifier.padding(horizontal = 16.dp).padding(bottom = 8.dp).fillMaxWidth().mirna().padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(model.uputstvo, style = tekst(15.sp, FontWeight.SemiBold))
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

@Composable
private fun Kraj(model: OsvajanjeModel, izadji: () -> Unit) {
    val poredak = model.stanje.poredak
    val pobednik = poredak.first().first
    Box(Modifier.fillMaxSize().background(Boje.mastilo.copy(alpha = 0.6f)), contentAlignment = Alignment.Center) {
        Column(
            Modifier.padding(20.dp).pop(if (pobednik.covek) Boje.teal else Color.White).padding(22.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            MaskotaSlika(MASKOTE[pobednik.id] ?: Maskota.BLOOP, 120.dp)
            Text(if (pobednik.covek) "Svet je tvoj!" else "Pobeđuje ${pobednik.ime}", style = naslov(34.sp).copy(color = if (pobednik.covek) Color.White else Boje.mastilo))
            poredak.forEachIndexed { i, (igrac, poeni) ->
                Row(Modifier.fillMaxWidth().pop(Color.White, 16.dp).padding(12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
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
