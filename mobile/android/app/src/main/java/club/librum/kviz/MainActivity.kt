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
import androidx.compose.material.icons.rounded.Groups
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
import club.librum.kviz.osvajanje.OsvajanjeTok
import club.librum.kviz.zajednica.IgraciEkran
import club.librum.kviz.igre.KvizIgraEkran
import club.librum.kviz.servisi.dnevniIzazov
import club.librum.kviz.zajednica.DodajPitanjeEkran
import club.librum.kviz.zajednica.ProfilIgracaEkran
import club.librum.kviz.zajednica.TraziIgraceEkran
import club.librum.kviz.zajednica.PorukeEkran
import club.librum.kviz.zajednica.RazgovorEkran
import club.librum.kviz.osvajanje.OsvajanjeTokEkran
import club.librum.kviz.osvajanje.OsvajanjeUvod
import club.librum.kviz.osvajanje.Tezina
import club.librum.kviz.prokviz.ProKvizEkran
import club.librum.kviz.prokviz.Survival
import club.librum.kviz.igre.BrziKvizEkran
import club.librum.kviz.igre.DuelEkran
import club.librum.kviz.igre.VesanjeEkran
import club.librum.kviz.servisi.Sesija
import club.librum.kviz.servisi.Napredak
import club.librum.kviz.ui.Cinjenice
import club.librum.kviz.servisi.Zvuk
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
        Cinjenice.ucitaj(assets.open("cinjenice.json").bufferedReader().use { it.readText() })
        Napredak.deljeni = Napredak(applicationContext)
        Zvuk.init(applicationContext)
        setContent { Aplikacija() }
    }
}

private data class Kartica(val ruta: String, val natpis: String, val ikonica: androidx.compose.ui.graphics.vector.ImageVector)

private val KARTICE = listOf(
    Kartica("igraci", "Igrači", Icons.Rounded.Groups),
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
                NavigationBar(containerColor = Boje.kartica) {
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
                composable("igraci") { IgraciEkran(sesija) { nav.navigate(it) } }
                composable("igrac/{id}") { e -> ProfilIgracaEkran(sesija, e.arguments?.getString("id").orEmpty(), { nav.navigate(it) }) { nav.popBackStack() } }
                composable("igraci/trazi") { TraziIgraceEkran(sesija, { nav.navigate(it) }) { nav.popBackStack() } }
                composable("poruke") { PorukeEkran(sesija, { nav.navigate(it) }) { nav.popBackStack() } }
                composable("razgovor/{sa}/{ime}") { e -> RazgovorEkran(sesija, e.arguments?.getString("sa").orEmpty(), e.arguments?.getString("ime").orEmpty()) { nav.popBackStack() } }
                composable("rang") { RangLista(sesija) { nav.navigate(it) } }
                composable("profil") { Profil(sesija) { nav.navigate(it) } }
                composable("dodaj/{vrsta}") { e -> DodajPitanjeEkran(sesija, e.arguments?.getString("vrsta") ?: "pro") { nav.popBackStack() } }
                composable("osvajanje") { OsvajanjeUvod(nalog?.nadimak) { p -> OsvajanjeTok.postavka = p; nav.navigate("osvajanje/igra") } }
                composable("osvajanje/igra") { OsvajanjeTokEkran(sesija) { nav.popBackStack() } }
                composable("pro") { ProKvizEkran(sesija, Survival.PRO) { nav.popBackStack() } }
                composable("book") { ProKvizEkran(sesija, Survival.BOOK) { nav.popBackStack() } }
                composable("dnevni") { KvizIgraEkran(sesija, "Dnevni izazov", "dnevni", { dnevniIzazov() }) { nav.popBackStack() } }
                composable("brzi") { BrziKvizEkran(sesija) { nav.popBackStack() } }
                composable("vesanje") { VesanjeEkran(sesija) { nav.popBackStack() } }
                composable("duel") { DuelEkran(sesija) { nav.popBackStack() } }
            }
        }
    }
}
