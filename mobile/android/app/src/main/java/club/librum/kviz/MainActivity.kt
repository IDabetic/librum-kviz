package club.librum.kviz

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material.icons.rounded.SportsEsports
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import club.librum.kviz.osvajanje.Mapa
import club.librum.kviz.osvajanje.OsvajanjeIgra
import club.librum.kviz.osvajanje.OsvajanjeUvod
import club.librum.kviz.osvajanje.Tezina
import club.librum.kviz.prokviz.ProKvizEkran
import club.librum.kviz.prokviz.Survival
import club.librum.kviz.igre.BrziKvizEkran
import club.librum.kviz.igre.DuelEkran
import club.librum.kviz.igre.VesanjeEkran
import club.librum.kviz.servisi.Sesija
import club.librum.kviz.ui.Boje
import club.librum.kviz.ui.Pocetna
import club.librum.kviz.ui.Profil
import club.librum.kviz.ui.RangLista
import club.librum.kviz.ui.tekst

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        Mapa.ucitaj(assets.open("svet.json").bufferedReader().use { it.readText() })
        setContent { Aplikacija() }
    }
}

private data class Kartica(val ruta: String, val natpis: String, val ikonica: androidx.compose.ui.graphics.vector.ImageVector)

private val KARTICE = listOf(
    Kartica("igre", "Igre", Icons.Rounded.SportsEsports),
    Kartica("rang", "Rang lista", Icons.Rounded.EmojiEvents),
    Kartica("profil", "Profil", Icons.Rounded.Person),
)

/** Tri kartice dole kao One UI: igre, rang lista, profil; igre preko celog ekrana. */
@Composable
private fun Aplikacija() {
    val kontekst = LocalContext.current.applicationContext
    val sesija = remember { Sesija(kontekst) }
    val nalog by sesija.nalog.collectAsState()
    val nav = rememberNavController()
    val trenutna by nav.currentBackStackEntryAsState()
    val ruta = trenutna?.destination?.route
    LaunchedEffect(nalog?.id) { sesija.ucitajNadimak() }

    Scaffold(
        containerColor = Boje.krem,
        bottomBar = {
            if (ruta in KARTICE.map { it.ruta }) {
                NavigationBar(containerColor = Color.White) {
                    for (k in KARTICE) {
                        NavigationBarItem(
                            selected = trenutna?.destination?.hierarchy?.any { it.route == k.ruta } == true,
                            onClick = { nav.navigate(k.ruta) { popUpTo("igre") { saveState = true }; launchSingleTop = true; restoreState = true } },
                            icon = { Icon(k.ikonica, contentDescription = null) },
                            label = { Text(k.natpis, style = tekst(12.sp, FontWeight.Bold)) },
                            colors = NavigationBarItemDefaults.colors(
                                selectedIconColor = Boje.mastilo, unselectedIconColor = Boje.sivaTekst,
                                indicatorColor = Color.Transparent, selectedTextColor = Boje.mastilo, unselectedTextColor = Boje.sivaTekst,
                            ),
                        )
                    }
                }
            }
        },
    ) { razmak ->
        Box(Modifier.fillMaxSize().padding(bottom = if (ruta in KARTICE.map { it.ruta }) razmak.calculateBottomPadding() else 0.dp)) {
            NavHost(nav, startDestination = "igre") {
                composable("igre") { Pocetna(nalog?.nadimak) { nav.navigate(it) } }
                composable("rang") { RangLista() }
                composable("profil") { Profil(sesija) }
                composable("osvajanje") { OsvajanjeUvod { t, k -> nav.navigate("osvajanje/${t.name}/$k") } }
                composable("osvajanje/{tezina}/{krugova}") { e ->
                    val tezina = Tezina.valueOf(e.arguments?.getString("tezina") ?: Tezina.NORMALNO.name)
                    val krugova = e.arguments?.getString("krugova")?.toIntOrNull() ?: 10
                    OsvajanjeIgra(tezina, krugova, nalog?.nadimak) { nav.popBackStack() }
                }
                composable("pro") { ProKvizEkran(sesija, Survival.PRO) { nav.popBackStack() } }
                composable("book") { ProKvizEkran(sesija, Survival.BOOK) { nav.popBackStack() } }
                composable("brzi") { BrziKvizEkran(sesija) { nav.popBackStack() } }
                composable("vesanje") { VesanjeEkran(sesija) { nav.popBackStack() } }
                composable("duel") { DuelEkran(sesija) { nav.popBackStack() } }
            }
        }
    }
}
