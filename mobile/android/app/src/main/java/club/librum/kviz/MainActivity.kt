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
import kotlinx.coroutines.launch
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.ui.Alignment
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.mutableStateOf
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
import club.librum.kviz.zajednica.Brojaci
import club.librum.kviz.zajednica.SanduceEkran
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import club.librum.kviz.igre.KvizIgraEkran
import club.librum.kviz.servisi.dnevniIzazov
import club.librum.kviz.servisi.temaKviz
import club.librum.kviz.servisi.slikariKviz
import club.librum.kviz.servisi.PaketPitanja
import club.librum.kviz.servisi.Fond
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

/** DEBUG: probni ekrani Karijere umesto aplikacije. */
private var karijeraProba = false

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        Mapa.ucitaj(assets.open("svet.json").bufferedReader().use { it.readText() })
        Cinjenice.ucitaj(assets.open("cinjenice.json").bufferedReader().use { it.readText() })
        Napredak.deljeni = Napredak(applicationContext)
        Zvuk.init(applicationContext)
        club.librum.kviz.servisi.IzvestajOPadu.ukljuci(applicationContext)
        kotlinx.coroutines.MainScope().launch { club.librum.kviz.servisi.IzvestajOPadu.posaljiSacuvan(applicationContext) }
        // Razvojna proba (adb ... --ez bezPrijave true): ekrani igre sa drugima bez servera i lozinke, kao iOS `-bezPrijave`.
        if (BuildConfig.DEBUG) club.librum.kviz.igre.Takmicenje.proba = intent.getBooleanExtra("bezPrijave", false)
        // `--ez karijeraProba true`: probni ekrani Karijere sa izmišljenim podacima (DEBUG).
        karijeraProba = BuildConfig.DEBUG && intent.getBooleanExtra("karijeraProba", false)
        club.librum.kviz.ui.Boje.tema = Napredak.deljeni.s.tema
        club.librum.kviz.servisi.Podsetnik.zakazi(applicationContext, Napredak.deljeni.s.podsetnik)
        setContent {
            val sistemTamno = androidx.compose.foundation.isSystemInDarkTheme()
            club.librum.kviz.ui.Boje.tamno = when (club.librum.kviz.ui.Boje.tema) { "tamna" -> true; "svetla" -> false; else -> sistemTamno }
            if (karijeraProba) club.librum.kviz.karijera.KarijeraProba() else Aplikacija()
        }
        intent?.data?.let { Pozivnica.primi(it) }
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        intent.data?.let { Pozivnica.primi(it) }
    }
}

private data class Kartica(val ruta: String, val natpis: String, val ikonica: androidx.compose.ui.graphics.vector.ImageVector)

private val KARTICE = listOf(
    Kartica("igraci", "Igrači", Icons.Rounded.Groups),
    Kartica("igre", "Igre", Icons.Rounded.SportsEsports),
    Kartica("rang", "Rang lista", Icons.Rounded.EmojiEvents),
    Kartica("profil", "Profil", Icons.Rounded.Person),
)

/** Link iz pozivnice čeka dok navigacija ne bude spremna; host je vrsta (duel, igrac), putanja je kod ili id. */
object Pozivnica {
    val ruta = kotlinx.coroutines.flow.MutableStateFlow<String?>(null)
    fun primi(uri: android.net.Uri) {
        val vrednost = uri.pathSegments.firstOrNull()?.filter { it.isLetterOrDigit() || it == '-' } ?: return
        ruta.value = when (uri.host) {
            "duel" -> "duel/kod/${vrednost.uppercase()}"; "igrac" -> "igrac/$vrednost"
            "osvajanje" -> "osvajanje/kod/${vrednost.uppercase()}"
            "soba" -> "takmicenje/kod/${vrednost.uppercase()}"
            else -> null
        }
    }
}

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
    val trebaDopuna by sesija.trebaDopuna.collectAsState()
    if (nalog != null && trebaDopuna) { club.librum.kviz.ui.DopunaProfila(sesija); return }
    val pozivnica by Pozivnica.ruta.collectAsState()
    LaunchedEffect(pozivnica) { pozivnica?.let { nav.navigate(it); Pozivnica.ruta.value = null } }
    // Brojači se osvežavaju pri svakom prelasku na karticu, kao na iOS-u.
    LaunchedEffect(ruta, nalog?.id) { Brojaci.osvezi(sesija) }
    val novaObavestenja by Brojaci.obavestenja.collectAsState()
    val novePoruke by Brojaci.poruke.collectAsState()

    Scaffold(
        containerColor = Boje.krem,
        bottomBar = {
            if (ruta in KARTICE.map { it.ruta }) {
                NavigationBar(containerColor = Boje.kartica) {
                    for (k in KARTICE) {
                        NavigationBarItem(
                            selected = trenutna?.destination?.hierarchy?.any { it.route == k.ruta } == true,
                            onClick = { nav.navigate(k.ruta) { popUpTo("igre") { saveState = true }; launchSingleTop = true; restoreState = true } },
                            icon = {
                                val broj = when (k.ruta) { "igraci" -> novePoruke; "profil" -> novaObavestenja; else -> 0 }
                                BadgedBox(badge = { if (broj > 0) Badge(containerColor = Boje.roze) { Text("$broj") } }) { Icon(k.ikonica, contentDescription = null) }
                            },
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
                composable("sanduce") { SanduceEkran(sesija, { nav.navigate(it) }) { nav.popBackStack() } }
                composable("pravila") { club.librum.kviz.ui.PravilaIgaraEkran { nav.popBackStack() } }
                composable("pravno/{vrsta}") { e -> club.librum.kviz.ui.PravniTekstEkran(e.arguments?.getString("vrsta") ?: "uslovi") { nav.popBackStack() } }
                composable("poruke") { PorukeEkran(sesija, { nav.navigate(it) }) { nav.popBackStack() } }
                composable("razgovor/{sa}/{ime}") { e -> RazgovorEkran(sesija, e.arguments?.getString("sa").orEmpty(), e.arguments?.getString("ime").orEmpty()) { nav.popBackStack() } }
                composable("rang") { RangLista(sesija) { nav.navigate(it) } }
                composable("karijera") { club.librum.kviz.karijera.KarijeraEkran(sesija) { nav.popBackStack() } }
                composable("karijeracv/{id}") { e -> club.librum.kviz.karijera.CVEkran(e.arguments?.getString("id")) { nav.popBackStack() } }
                composable("profil") { Profil(sesija) { nav.navigate(it) } }
                composable("podesavanja") { club.librum.kviz.ui.PodesavanjaEkran(sesija, { nav.navigate(it) }) { nav.popBackStack() } }
                composable("izmena-profila") { club.librum.kviz.ui.IzmenaProfilaEkran(sesija) { nav.popBackStack() } }
                composable("bedzevi") { club.librum.kviz.ui.BedzeviEkran { nav.popBackStack() } }
                composable("statistika") { club.librum.kviz.ui.StatistikaEkran { nav.popBackStack() } }
                composable("blokirani") { club.librum.kviz.ui.BlokiraniEkran(sesija) { nav.popBackStack() } }
                composable("dodaj/{vrsta}") { e -> DodajPitanjeEkran(sesija, e.arguments?.getString("vrsta") ?: "pro") { nav.popBackStack() } }
                composable("osvajanje") { OsvajanjeUvod(nalog?.nadimak, { p -> OsvajanjeTok.postavka = p; nav.navigate("osvajanje/poziv") }, { k -> nav.navigate("osvajanje/kod/$k") }) { p -> OsvajanjeTok.postavka = p; nav.navigate("osvajanje/igra") } }
                composable("osvajanje/igra") { OsvajanjeTokEkran(sesija, { nav.popBackStack() }) { nav.popBackStack("igre", false) } }
                composable("osvajanje/poziv") { club.librum.kviz.osvajanje.PozivEkran(sesija, club.librum.kviz.osvajanje.OsvajanjeTok.postavka, null, { nav.popBackStack() }) { nav.popBackStack("igre", false) } }
                composable("osvajanje/kod/{kod}") { e -> club.librum.kviz.osvajanje.PozivEkran(sesija, null, e.arguments?.getString("kod"), { nav.popBackStack() }) { nav.popBackStack("igre", false) } }
                composable("osvajanje/nastavak") { club.librum.kviz.osvajanje.OsvajanjeNastavak(sesija, { nav.popBackStack() }) { nav.popBackStack("igre", false) } }
                composable("pro") { ProKvizEkran(sesija, Survival.PRO) { nav.popBackStack() } }
                composable("book") { ProKvizEkran(sesija, Survival.BOOK) { nav.popBackStack() } }
                composable("dnevni") { KvizIgraEkran(sesija, "Dnevni izazov", "dnevni", null, { dnevniIzazov() }) { nav.popBackStack() } }
                composable("tema/{id}") { e ->
                    val kontekst = LocalContext.current.applicationContext
                    val paket = remember { PaketPitanja(kontekst) }
                    // Isti redovi u quizzes kao iOS Katalog (quiz_results za Opšte znanje i Knjige).
                    val id = e.arguments?.getString("id").orEmpty()
                    if (id.startsWith("kat:")) {
                        val tag = id.removePrefix("kat:")
                        KvizIgraEkran(sesija, tag.replaceFirstChar { it.uppercase() }, "tema", "3cc90acb-9803-429d-9163-7c2245d9e4f7", { paket.temaKviz(Fond.OPSTE, zanr = tag) }) { nav.popBackStack() }
                        return@composable
                    }
                    when (id) {
                        "knjige" -> KvizIgraEkran(sesija, "Knjige", "tema", "e4b739dc-67f6-4b2c-bf9d-def4e18b0d45", { paket.temaKviz(Fond.BOOK) }) { nav.popBackStack() }
                        "slikari" -> KvizIgraEkran(sesija, "Slikari", "slikari", null, { slikariKviz(kontekst) }) { nav.popBackStack() }
                        "slikari-tesko" -> KvizIgraEkran(sesija, "Slikari: majstori", "slikari", null, { slikariKviz(kontekst, tesko = true) }) { nav.popBackStack() }
                        "tesko" -> KvizIgraEkran(sesija, "Nemoguća pitanja", "tema", "3cc90acb-9803-429d-9163-7c2245d9e4f7", { paket.temaKviz(Fond.OPSTE, tesko = true) }) { nav.popBackStack() }
                        else -> KvizIgraEkran(sesija, "Opšte znanje", "tema", "3cc90acb-9803-429d-9163-7c2245d9e4f7", { paket.temaKviz(Fond.OPSTE) }) { nav.popBackStack() }
                    }
                }
                composable("brzi") { BrziKvizEkran(sesija) { nav.popBackStack() } }
                composable("vesanje") { VesanjeEkran(sesija) { nav.popBackStack() } }
                composable("duel") { DuelEkran(sesija) { nav.popBackStack() } }
                composable("duel/izazov/{id}") { e -> DuelEkran(sesija, izazovi = e.arguments?.getString("id")) { nav.popBackStack() } }
                composable("duel/kod/{kod}") { e -> DuelEkran(sesija, kodSobe = e.arguments?.getString("kod")) { nav.popBackStack() } }
                composable("takmicenje") { club.librum.kviz.igre.TakmicenjeEkran(sesija, izadji = { nav.popBackStack() }) { nav.popBackStack("igre", false) } }
                composable("takmicenje/kod/{kod}") { e -> club.librum.kviz.igre.TakmicenjeEkran(sesija, kod = e.arguments?.getString("kod"), izadji = { nav.popBackStack() }) { nav.popBackStack("igre", false) } }
                composable("takmicenje/izazov/{id}/{ime}") { e ->
                    club.librum.kviz.igre.TakmicenjeEkran(sesija, pozovi = e.arguments?.getString("id").orEmpty() to e.arguments?.getString("ime").orEmpty(), izadji = { nav.popBackStack() }) { nav.popBackStack("igre", false) }
                }
            }
            // Poziv u sobu stiže preko bilo kog ekrana osim same igre (kao baner na iOS-u).
            var poziv by remember { mutableStateOf<club.librum.kviz.igre.Takmicenje.Poziv?>(null) }
            val odbijeni = remember { mutableSetOf<String>() }
            LaunchedEffect(nalog?.id) {
                while (nalog != null) {
                    if (poziv == null) poziv = club.librum.kviz.igre.Takmicenje.pozivi(sesija).firstOrNull { it.kod !in odbijeni }
                    kotlinx.coroutines.delay(club.librum.kviz.igre.Takmicenje.OSVEZAVANJE_MS * 3)
                }
            }
            val opseg = rememberCoroutineScope()
            poziv?.takeIf { ruta?.startsWith("takmicenje") != true }?.let { p ->
                Box(Modifier.align(Alignment.TopCenter).statusBarsPadding()) {
                    club.librum.kviz.igre.PozivBaner(p) { prihvata ->
                        odbijeni += p.kod; poziv = null
                        if (prihvata) nav.navigate("takmicenje/kod/${p.kod}") else opseg.launch { club.librum.kviz.igre.Takmicenje.odbij(sesija, p.kod) }
                    }
                }
            }
        }
    }
}
