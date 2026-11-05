package club.librum.kviz.osvajanje

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import club.librum.kviz.servisi.PaketPitanja
import club.librum.kviz.servisi.Prikaz
import club.librum.kviz.servisi.Spil
import club.librum.kviz.servisi.Zvuk
import club.librum.kviz.servisi.kontinent
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.util.UUID

/** Postavka partije iz čekaonice (docs/OSVAJANJE-VISE-IGRACA.md). */
data class OsvajanjePostavka(
    val nacin: Nacin,
    val igraca: Int,
    val krugova: Int,
    val tezina: Tezina,
    val igraci: List<NoviIgrac>,
    val pocetak: Map<String, String> = emptyMap(),
    /** Id kontinenta kad se igra samo na njemu; null = ceo svet. */
    val teren: String? = null,
    /** Pravi igrači se traže preko servera (sobe); inače su prazna mesta botovi odmah. */
    val traziIgrace: Boolean = false,
    /** Partija preko servera: soba, moj nalog i da li sam domaćin (mesto 0); null = igra na telefonu. */
    val soba: String? = null,
    val korisnik: String? = null,
    val domacin: Boolean = false,
) {
    /** [kljuc] je vrednost na serveru (osvajanje_sobe.nacin), ista kao na iOS-u. */
    enum class Nacin(val kljuc: String, val naziv: String, val opis: String, val brojevi: List<Int>) {
        JEDAN_NA_JEDAN("jedanNaJedan", "Jedan na jedan", "Ti protiv jednog rivala.", listOf(2)),
        TIMOVI("timovi", "Timovi po dvoje", "Dva do šest timova; saigrači dele države i misiju.", listOf(4, 6, 8, 10, 12)),
        SVAKO_ZA_SEBE("svakoZaSebe", "Svako za sebe", "Tri do šest igrača; savez traje do kraja sledećeg kruga.", listOf(3, 4, 5, 6)),
    }

    companion object {
        val BOJE = listOf(0xFF12907E, 0xFFFF5FA2, 0xFF6D4BC9, 0xFFF4A33C, 0xFF6EC3F2, 0xFFE5385C)
        val IMENA_BOTOVA = listOf("Mimi", "Zig", "Bloop", "Lumi", "Luna", "Max", "Sara", "Đole", "Ana", "Pera", "Mila")

        /** Mesta za stolom: timovi se smenjuju (A1, B1, C1, A2…), čovek je prvi u timu A i kapiten. */
        fun mesta(nacin: Nacin, igraca: Int, ime: String, vojska: VrstaVojske? = null): List<NoviIgrac> {
            val timova = if (nacin == Nacin.TIMOVI) igraca / 2 else igraca
            val poTimu = if (nacin == Nacin.TIMOVI) 2 else 1
            var bot = 0
            // Imena botova se mešaju svake partije (Mimi nije uvek prvi rival).
            val imenaBotova = IMENA_BOTOVA.shuffled()
            return (0 until poTimu).flatMap { clan ->
                (0 until timova).map { t ->
                    val covek = t == 0 && clan == 0
                    val n = if (covek) ime else imenaBotova[bot % imenaBotova.size]
                    if (!covek) bot++
                    NoviIgrac(if (covek) "ti" else "bot$bot", n, BOJE[t % BOJE.size], covek, ('A' + t).toString(), clan == 0, if (covek) vojska else null)
                }
            }
        }
    }
}

/** Tok partije: pitanja, potezi botova i odbrana čoveka; verni prevod iOS OsvajanjeModel.swift. Pravila su u Pravila.kt. */
class OsvajanjeModel(
    private val krugova: Int,
    private val tezina: Tezina,
    private val ime: String?,
    private val paket: PaketPitanja,
    postavkaUlaz: OsvajanjePostavka? = null,
    sesija: club.librum.kviz.servisi.Sesija? = null,
    /** Za čuvanje partije („Nastavi partiju”) i istoriju misija; bez njega se ništa ne čuva. */
    private val kontekst: Context? = null,
    nastavak: Nastavak? = null,
) : ViewModel() {
    data class Otvoreno(val prikaz: Prikaz, val id: String = UUID.randomUUID().toString())

    /** Bitka za državu: uvod (država, činjenice, odbrojavanje), pa pitanja, pa rezultat. */
    data class Bitka(
        val napadam: Boolean,
        val odakle: String,
        val kuda: String,
        val uslov: Uslov,
        val prikazi: List<Prikaz>,
        val rivalIme: String,
        val korak: Korak = Korak.UVOD,
        val redni: Int = 0,
        val tacnih: Int = 0,
        val ms: Int = 0,
        val rival: Skor? = null,
        val ishod: Ishod? = null,
        /** Raste kad pomoć zameni pitanje, da se kartica nacrta iznova. */
        val zamena: Int = 0,
        /** Ratne karte odigrane u ovoj bitki. */
        val spijun: Boolean = false,
        val sabotaza: Boolean = false,
        /** Protivnik je odigrao Sabotažu: meni jedan tačan manje. */
        val sabotiranSam: Boolean = false,
        /** Napadač bira temu pitanja od ponuđenih (uvod bitke); null = mešano. */
        val teme: List<String> = emptyList(),
        val tema: String? = null,
        /** Pomoći vojske u ovoj bitki: sledeći tačan vredi dva (Juriš); greška se briše uz novo pitanje (Štit);
         *  svaki odgovor je tačan, pravi vredi dva (Siguran udar); sat tekućeg pitanja stoji (Vreme stoji). */
        val dvostruko: Boolean = false,
        val stit: Boolean = false,
        val siguran: Boolean = false,
        val satStoji: Boolean = false,
        /** Prednost u tačnim iz ugla napadača, zapamćena na početku bitke (posle ishoda se vojske pomeraju). */
        val pomak: Int = 0,
        val id: String = UUID.randomUUID().toString(),
    ) { enum class Korak { UVOD, PITANJA, REZULTAT } }

    /** Sačuvana partija na telefonu (ne preko servera), isti sadržaj kao iOS Nastavak. */
    @Serializable
    data class Nastavak(val stanje: Stanje, val nacin: String? = null, val teren: String? = null, val tacnih: Int = 0, val netacnih: Int = 0, val zbirMs: Int = 0)

    data class Udar(val odakle: String, val kuda: String, val osvojeno: Boolean, val kad: Long, val staraBoja: Long? = null, val novaBoja: Long? = null)
    data class Iskok(val oblast: String, val promena: Int, val kad: Long)
    data class ZatvorenRegion(val region: String, val boja: Long, val kad: Long)

    private val slucajno = Slucajno(System.currentTimeMillis().toInt())
    var postavka: OsvajanjePostavka? = postavkaUlaz; private set
    /** Partija je nastavljena iz sačuvanog stanja: bez misije i postavljanja, potez se samo nastavlja. */
    val nastavljena = nastavak != null

    private var stanjeIzvor by mutableStateOf(nastavak?.stanje ?: nova())
    var stanje: Stanje
        get() = stanjeIzvor
        private set(novo) { val stari = stanjeIzvor; stanjeIzvor = novo; zabeleziPromene(stari); zvuciPromena(stari) }
    var spremno by mutableStateOf(false); private set
    var greska by mutableStateOf<String?>(null); private set
    private var izabranaIzvor by mutableStateOf<String?>(null)
    var izabrana: String?
        get() = izabranaIzvor
        private set(v) { if (v != izabranaIzvor) meta = null; izabranaIzvor = v }
    /** Izabrana meta pre potvrde napada: igrač vidi odakle napada, šta napada i šta rizikuje. */
    var meta by mutableStateOf<String?>(null); private set
    /** Jedna pomoć po partiji važi za celo Osvajanje. */
    var pomocIskoriscena by mutableStateOf(false)
    var utvrdjivanje by mutableStateOf(false); private set
    var otvoreno by mutableStateOf<Otvoreno?>(null); private set
    var bitka by mutableStateOf<Bitka?>(null); private set
    var poruka by mutableStateOf<String?>(null); private set
    var tacnih by mutableIntStateOf(nastavak?.tacnih ?: 0); private set
    var netacnih by mutableIntStateOf(nastavak?.netacnih ?: 0); private set
    var zbirMs by mutableIntStateOf(nastavak?.zbirMs ?: 0); private set

    // Efekti na mapi i reprodukcija partije
    var udar by mutableStateOf<Udar?>(null); private set
    var iskoci by mutableStateOf<List<Iskok>>(emptyList()); private set
    var zatvoreni by mutableStateOf<List<ZatvorenRegion>>(emptyList()); private set
    /** Vlasnici država posle svake promene (za reprodukciju na kraju); najviše 400 slika. */
    var istorija by mutableStateOf<List<Map<String, String>>>(emptyList()); private set

    private var spil = Spil(emptyList())
    private var dopunaRadi = false
    /** Pitanja po kontinentima: bitka za državu ima do dva pitanja o njenom kontinentu. */
    private val spiloviKontinenta = mutableMapOf<String, Spil>()
    private val dopunaKontinenta = mutableSetOf<String>()
    private var cekaOdbranu: CompletableDeferred<Skor>? = null
    private var zatvaranje: CompletableDeferred<Unit>? = null
    private var potezBota: Job? = null
    private var botRadi = false
    private val pauzaBota = 700L

    companion object {
        private const val PITANJA_O_KONTINENTU = 2
        /** Kad u špilu ostane manje od ovoliko pitanja, stiže novi paket (bitka troši do 5, potez do 5 bitaka). */
        private const val PRAG_DOPUNE = 30
        private const val KLJUC_NASTAVKA = "osvajanje.nastavak"
        private val json = Json { ignoreUnknownKeys = true; explicitNulls = false }

        fun sacuvana(ctx: Context): Nastavak? = runCatching {
            val t = ctx.getSharedPreferences(KLJUC_NASTAVKA, Context.MODE_PRIVATE).getString("partija", null) ?: return null
            json.decodeFromString(Nastavak.serializer(), t).takeIf { it.stanje.faza != Faza.KRAJ }
        }.getOrNull()

        fun obrisiSacuvanu(ctx: Context) { ctx.getSharedPreferences(KLJUC_NASTAVKA, Context.MODE_PRIVATE).edit().remove("partija").apply() }
    }

    /** Čuva se partija na telefonu (ne preko servera), posle postavljanja, na svakom potezu i bitki. */
    private fun sacuvaj() {
        val ctx = kontekst ?: return
        if (veza != null || postavljanje != null) return
        if (stanje.faza == Faza.KRAJ) { obrisiSacuvanu(ctx); return }
        val n = Nastavak(stanje, postavka?.nacin?.kljuc, postavka?.teren, tacnih, netacnih, zbirMs)
        ctx.getSharedPreferences(KLJUC_NASTAVKA, Context.MODE_PRIVATE).edit().putString("partija", json.encodeToString(Nastavak.serializer(), n)).apply()
    }

    private fun bojaTima(tim: String?) = stanje.igraci.firstOrNull { it.tim == tim }?.boja

    private fun zabeleziPromene(stari: Stanje) {
        val sad = System.currentTimeMillis()
        val nove = mutableListOf<Iskok>()
        var vlasniciPromenjeni = false
        for ((id, o) in stanje.oblasti) {
            val pre = stari.oblasti[id] ?: continue
            if (pre.vlasnik != o.vlasnik) vlasniciPromenjeni = true
            else if (pre.vojske != o.vojske && o.vlasnik != null) nove += Iskok(id, o.vojske - pre.vojske, sad)
        }
        if (nove.isNotEmpty()) iskoci = (iskoci.filter { sad - it.kad < 1400 } + nove).takeLast(24)
        if (!vlasniciPromenjeni) return
        istorija = (istorija + listOf(stanje.oblasti.mapNotNull { (k, v) -> v.vlasnik?.let { k to it } }.toMap())).takeLast(400)
        for (r in Mapa.regioni) {
            val ids = Mapa.oblasti.filter { it.region == r.id && stanje.oblasti[it.id] != null }.map { it.id }
            val v = stanje.oblasti[ids.firstOrNull() ?: ""]?.vlasnik ?: continue
            if (!ids.all { stanje.oblasti[it]?.vlasnik == v } || ids.all { stari.oblasti[it]?.vlasnik == v }) continue
            val boja = bojaTima(v) ?: continue
            zatvoreni = zatvoreni.filter { sad - it.kad < 2000 } + ZatvorenRegion(r.id, boja, sad)
            if (v == mojTim) javi("Ceo region ${r.ime} je tvoj!")
        }
    }

    private fun udari(odakle: String, kuda: String, osvojeno: Boolean) {
        // Pre osvajanja: pretposlednja slika vlasnika (zabeleziPromene je već upisala novu).
        val stari = if (osvojeno && istorija.size > 1) istorija[istorija.size - 2][kuda] else null
        udar = Udar(odakle, kuda, osvojeno, System.currentTimeMillis(), bojaTima(stari), bojaTima(stanje.oblasti[kuda]?.vlasnik))
        // Svoje bitke imaju zvuk na ekranu ishoda; ovde samo bot koji osvaja.
        if (osvojeno && bitka == null && stanje.oblasti[odakle]?.vlasnik != mojTim) Zvuk.pusti(Zvuk.Vrsta.BOT_OSVAJA, 0.5f)
    }

    /** Zvuci iz promena stanja (krug, potez, pojačanja, karte, savez, izdaja, poruka, događaj, čudo, misija). */
    private fun zvuciPromena(stari: Stanje) {
        val ja = mojTim ?: return
        val n = stanje
        if (n.faza == Faza.KRAJ) {
            if (stari.faza != Faza.KRAJ && n.timSaIspunjenomMisijom == ja) Zvuk.pusti(Zvuk.Vrsta.MISIJA, 0.55f)
            return
        }
        if (n.krug > stari.krug) Zvuk.pusti(Zvuk.Vrsta.NOVI_KRUG, 0.35f)
        if ((n.naPotezu != stari.naPotezu || n.krug != stari.krug) && n.trenutni.covek) Zvuk.pusti(Zvuk.Vrsta.TVOJ_POTEZ, 0.45f)
        if (n.trenutni.covek && n.zaRaspored > stari.zaRaspored) Zvuk.pusti(Zvuk.Vrsta.POJACANJA, 0.45f)
        if (n.trenutni.covek && n.zaRaspored < stari.zaRaspored && (n.zaRaspored > 0 || stari.faza == Faza.RASPORED)) Zvuk.pusti(Zvuk.Vrsta.VOJSKA_STAVI, 0.4f)
        var izgubio = false; var cudo = false
        for ((id, o) in n.oblasti) {
            if (stari.oblasti[id]?.vlasnik == o.vlasnik) continue
            if (stari.oblasti[id]?.vlasnik == ja) izgubio = true
            if (o.vlasnik == ja && Cudo.za(id) != null) cudo = true
        }
        if (cudo) Zvuk.pusti(Zvuk.Vrsta.CUDO, 0.55f) else if (izgubio && bitka == null) Zvuk.pusti(Zvuk.Vrsta.IZGUBIO_DRZAVU, 0.5f)
        if ((n.karteTimova?.get(ja)?.size ?: 0) > (stari.karteTimova?.get(ja)?.size ?: 0)) Zvuk.pusti(Zvuk.Vrsta.KARTA_DOBIJENA, 0.45f)
        if ((n.savezi?.size ?: 0) > (stari.savezi?.size ?: 0)) Zvuk.pusti(Zvuk.Vrsta.SAVEZ, 0.45f)
        if ((n.izdajnici?.size ?: 0) > (stari.izdajnici?.size ?: 0)) Zvuk.pusti(Zvuk.Vrsta.IZDAJA, 0.5f)
        val p = n.poruke?.lastOrNull()
        if ((n.poruke?.size ?: 0) > (stari.poruke?.size ?: 0) && p != null && n.igraci.firstOrNull { it.id == p.od }?.covek != true) Zvuk.pusti(Zvuk.Vrsta.PORUKA, 0.4f)
        if (n.dogadjaj != null && n.dogadjaj != stari.dogadjaj) Zvuk.pusti(Zvuk.Vrsta.DOGADJAJ, 0.5f)
    }

    // ── Partija preko servera ──
    val veza: VezaOsvajanja? = postavka?.soba?.let { s -> postavka?.korisnik?.let { k -> sesija?.let { VezaOsvajanja(it, s, k, postavka!!.domacin) } } }
    /** Telefon koji nije domaćin čeka prvo stanje sa servera. */
    var cekaPocetak by mutableStateOf(veza != null && veza.domacin.not()); private set
    private var cekaUdaljenuOdbranu: Pair<Int, CompletableDeferred<Skor>>? = null
    /** Branim se od napada sa drugog telefona: redni broj „bitke” i skor napadača. */
    private var udaljeniNapad: Pair<Int, Skor>? = null
    private var zapocetPotez: Pair<Int, Int>? = null
    private val rokOdbraneMs = 45_000L

    /** Igrač sa drugog telefona (pravi nalog, ne ja i ne bot). */
    private fun udaljen(i: Igrac) = veza != null && i.id.startsWith("u:") && !i.covek
    private fun lokalizuj(s: Stanje) = s.copy(igraci = s.igraci.map { it.copy(covek = it.id == veza?.mojId) })
    private fun objavi(s: Stanje) { val v = veza ?: return; viewModelScope.launch { v.posalji(VezaOsvajanja.Akcija("stanje", stanje = s)) } }

    private fun primi(red: VezaOsvajanja.Red) {
        val a = red.akcija
        when (a.v) {
            "stanje" -> {
                stanje = lokalizuj(a.stanje ?: return)
                if (cekaPocetak) { cekaPocetak = false; spremno = !spil.prazan }
                pratiUdaljenog()
                pocniPotezAkoTreba()
            }
            "bitka" -> {
                val odakle = a.odakle ?: return; val kuda = a.kuda ?: return; val skor = a.skor ?: return
                if (bitka != null || mojTim == null || stanje.oblasti[kuda]?.vlasnik != mojTim) return
                udaljeniNapad = red.rb to skor
                bitka = novaBitka(false, odakle, kuda)
                Zvuk.pusti(Zvuk.Vrsta.UZBUNA, 0.5f)
            }
            "odbrana" -> {
                val c = cekaUdaljenuOdbranu ?: return
                if (a.bitka != c.first) return
                cekaUdaljenuOdbranu = null
                c.second.complete(a.skor ?: return)
            }
        }
    }

    /** Posle stanja sa servera: ako je red na mene (ili na bota, a ja sam domaćin), potez kreće jednom. */
    private fun pocniPotezAkoTreba() {
        if (stanje.faza != Faza.SNABDEVANJE || zapocetPotez == (stanje.krug to stanje.naPotezu)) return
        val t = stanje.trenutni
        if (t.covek || (!udaljen(t) && veza?.domacin == true)) pocniPotez(stanje)
    }

    /** Napad na državu pravog igrača: on odgovara na svoja pitanja; ako se ne javi za 45 s, umesto njega bot. */
    private suspend fun udaljenaOdbrana(odakle: String, kuda: String, napadac: Skor): Skor {
        val v = veza ?: return stanje.botSkor(slucajno)
        val rb = v.posalji(VezaOsvajanja.Akcija("bitka", odakle = odakle, kuda = kuda, skor = napadac)) ?: return stanje.botSkor(slucajno)
        val cekanje = CompletableDeferred<Skor>()
        cekaUdaljenuOdbranu = rb to cekanje
        return kotlinx.coroutines.withTimeoutOrNull(rokOdbraneMs) { cekanje.await() }
            ?: stanje.botSkor(slucajno).also { cekaUdaljenuOdbranu = null }
    }

    // Na jednom kontinentu nema misija: pobeđuje ko ga ceo osvoji ili ima više na kraju.
    private fun nova(): Stanje {
        val izbegni = kontekst?.let { MisijeIstorija.skorasnje(it) }.orEmpty()
        return postavka?.let { Stanje.nova(it.krugova, it.tezina, slucajno, igraci = it.igraci, pocetak = it.pocetak, misije = it.teren == null, teren = it.teren, izbegniMisije = izbegni) }
            ?: Stanje.nova(krugova, tezina, slucajno, ime)
    }

    /** Tim čoveka (za misiju, odbranu i dodatne pomoći). */
    val mojTim: String? get() = stanje.igraci.firstOrNull { it.covek }?.tim
    val jesamKapiten: Boolean get() = stanje.igraci.firstOrNull { it.covek }?.kapiten ?: false
    val covekNaPotezu get() = stanje.faza != Faza.KRAJ && stanje.trenutni.covek

    /** Kontinenti koje moj tim drži ceo, a još nemaju odbranu (kapiten bira). */
    val kontinentiBezOdbrane: List<Kontinent> get() {
        val t = mojTim ?: return emptyList()
        if (!jesamKapiten) return emptyList()
        return Kontinenti.svi.filter { stanje.drziKontinent(t, it.id) && stanje.odbrane[it.id] == null }
    }
    val bonusPomoci: Int get() = mojTim?.let { stanje.bonusPomoci[it] } ?: 0

    val mete: List<String> get() {
        val iz = izabrana ?: return emptyList()
        if (!covekNaPotezu) return emptyList()
        // Marš: osvetljene su sve svoje države do kojih vojska stiže.
        if (utvrdjivanje) return stanje.dometMarsa(iz).sorted()
        return stanje.mete(iz) + stanje.meteIzdaje(iz)
    }

    /** Države iz kojih čovek sada može da napadne (žuta isprekidana ivica dok ništa nije izabrano). */
    val izvori: List<String> get() =
        if (!covekNaPotezu || stanje.faza != Faza.NAPAD || izabrana != null || utvrdjivanje) emptyList()
        else stanje.oblastiIgraca(stanje.trenutni.id).filter { stanje.mete(it).isNotEmpty() }

    // ── Ulog, pohod, izdaja, trgovina, ultimatum (Strategija2.kt) ──

    /** Ulog za sledeći napad na igrača (0–2), bira se na panelu mete. */
    var ulog by mutableIntStateOf(0)
    /** Igrač bira region za najavu pohoda (sledeći dodir mape). */
    var biraPohod by mutableStateOf(false); private set
    /** Država saveznika koju bi napad pretvorio u izdaju: čeka potvrdu. */
    var izdajaZa by mutableStateOf<String?>(null); private set

    val mojPohod: String? get() = mojTim?.let { stanje.pohodi?.get(it) }

    /** Države u magli za ovaj telefon (posmatrač bez tima vidi sve). */
    val magla: Set<String> get() {
        val t = mojTim ?: return emptySet()
        if (stanje.faza == Faza.KRAJ) return emptySet()
        return stanje.oblasti.keys.filter { stanje.oblasti[it]?.vlasnik != null && !stanje.vidi(t, it) }.toSet()
    }

    fun prekidacPohoda() {
        if (!covekNaPotezu || mojPohod != null) return
        biraPohod = !biraPohod; izabrana = null; utvrdjivanje = false
        if (biraPohod) javi("Dodirni državu u regionu koji osvajaš do sledećeg poteza")
    }

    fun potvrdiIzdaju() {
        val id = izdajaZa ?: return; val t = mojTim ?: return; val v = stanje.oblasti[id]?.vlasnik ?: return
        izdajaZa = null
        stanje = stanje.izdaj(t, v).posalji("Izdaja!", stanje.trenutni.id)
        objavi(stanje)
        meta = id
        javi("Savez je prekinut. Gubiš sve karte, a svi vide da si izdao.")
    }

    fun odustaniOdIzdaje() { izdajaZa = null }

    fun razmeniKartu(k: Karta, sa: Igrac) {
        val t = mojTim ?: return
        val r = if (!sa.covek && !sa.id.startsWith("u:")) stanje.razmeniKartu(t, sa.tim, k) else null
        if (r == null) { javi("${sa.ime} ne prihvata razmenu (ima tu kartu ili nema nijednu)"); return }
        stanje = r.first.posalji("Dogovoreno!", sa.id)
        objavi(stanje)
        javi("Dao si ${k.naziv}, dobio ${r.second.naziv}")
    }

    fun ultimatum(kuda: String) {
        val r = if (covekNaPotezu) stanje.ultimatum(kuda) else null
        if (r == null) { javi("Ultimatum ide slabijem susedu, jednom po potezu"); return }
        stanje = r.first
        objavi(r.first)
        if (r.second) { meta = null; izabrana = null; javi("${Mapa.oblast(kuda).ime} je predata bez borbe!") }
        else javi("Odbijeno: u ovom potezu napadaš ${Mapa.oblast(kuda).ime} sa +1 tačnim")
    }

    val uputstvo: String get() = postavljanje?.let { p ->
        if (p.drzave.size < Pravila.POCETNIH_DRZAVA) "Izaberi svoje države (${p.kontinent.ime}): ${p.drzave.size} od ${Pravila.POCETNIH_DRZAVA}. Prva je prestonica."
        else if (zaPostavljanje > 0) "Rasporedi vojsku: dodiruj svoje države, još $zaPostavljanje." else "Spremno. Kreni u osvajanje!"
    } ?: when {
        !covekNaPotezu -> if (stanje.faza == Faza.KRAJ) "Kraj partije" else "${stanje.trenutni.ime} je na potezu…"
        stanje.faza == Faza.RASPORED -> "Dodirni svoje oblasti: još ${stanje.zaRaspored}"
        stanje.faza == Faza.NAPAD && utvrdjivanje -> "Marš: izaberi državu, pa svoju do 3 koraka dalje"
        stanje.faza == Faza.NAPAD && biraPohod -> "Pohod: dodirni državu u regionu koji osvajaš"
        stanje.faza == Faza.NAPAD && izabrana == null -> "1. Dodirni svoju državu sa žutom ivicom: odatle napadaš · bitka ${stanje.bitaka + 1}/${stanje.napadaPoPotezu}"
        stanje.faza == Faza.NAPAD -> if (meta == null) "2. Napadaš iz: ${Mapa.oblast(izabrana!!).ime}. Dodirni koga napadaš (isprekidana ivica)." else ""
        else -> "Snabdevanje…"
    }

    init {
        if (nastavak != null) {
            postavka = OsvajanjePostavka(
                OsvajanjePostavka.Nacin.entries.firstOrNull { it.kljuc == nastavak.nacin } ?: OsvajanjePostavka.Nacin.SVAKO_ZA_SEBE,
                nastavak.stanje.igraci.size, nastavak.stanje.ukupnoKrugova,
                Tezina.entries.firstOrNull { it.tacnost == nastavak.stanje.tacnostBota } ?: Tezina.NORMALNO,
                nastavak.stanje.igraci.map { NoviIgrac(it.id, it.ime, it.boja, it.covek, it.tim, it.kapiten, it.vojska) }, teren = nastavak.teren,
            )
        }
        mojTim?.let { t -> stanje.misije[t]?.let { m -> kontekst?.let { MisijeIstorija.zapamti(it, m) } } }
        viewModelScope.launch {
            runCatching { paket.ucitaj() }
                .onSuccess { p ->
                    spil = Spil(p)
                    for (k in stanje.oblasti.keys.map { Kontinenti.od(it).ime }.toSet()) dopuniKontinent(k)
                    spremno = !cekaPocetak
                    // U partiji sa misijom prvi potez čeka da igrač pročita misiju; nastavljena partija ide dalje odmah.
                    // Sačuvano usred poteza bota (posle pojačanja): bot nastavlja svoj potez, inače bi partija stajala zauvek.
                    if (nastavljena) {
                        if (stanje.trenutni.covek && stanje.faza != Faza.SNABDEVANJE) pokreniSat()
                        else if (!stanje.trenutni.covek && stanje.faza != Faza.SNABDEVANJE) potezBota = viewModelScope.launch { igrajBota() }
                        else pocniPotez(stanje)
                    }
                    else if (postavka == null) pocniPotez(stanje)
                }
                .onFailure { greska = it.message }
        }
        // Slušanje sobe: novi potezi na svake 1,5 s dok je partija otvorena.
        veza?.let { v ->
            stanje = lokalizuj(stanje)
            viewModelScope.launch { while (stanje.faza != Faza.KRAJ) { v.novi().forEach(::primi); delay(1500) } }
        }
    }

    // ── Pitanja: špil se dopunjuje pre nego što se isprazni (pitanja se ne ponavljaju) ──

    private fun uzmiPitanje(tema: String? = null): Prikaz {
        val p = tema?.let { spil.sledece(it) } ?: spil.sledece()
        dopuniSpilAkoTreba()
        return p
    }

    private fun uzmiPitanjeKontinenta(k: String): Prikaz? {
        val s = spiloviKontinenta[k]
        val p = if (s != null && s.ostalo > 0) s.sledece() else null
        dopuniKontinent(k)
        return p
    }

    private fun dopuniKontinent(k: String) {
        if ((spiloviKontinenta[k]?.ostalo ?: 0) >= PITANJA_O_KONTINENTU * 3 || k in dopunaKontinenta) return
        dopunaKontinenta += k
        viewModelScope.launch {
            val nova = paket.kontinent(k)
            spiloviKontinenta[k]?.dodaj(nova) ?: run { spiloviKontinenta[k] = Spil(nova) }
            dopunaKontinenta -= k
        }
    }

    private fun dopuniSpilAkoTreba() {
        if (spil.ostalo >= PRAG_DOPUNE || dopunaRadi) return
        dopunaRadi = true
        viewModelScope.launch {
            runCatching { paket.ucitaj() }.onSuccess { spil.dodaj(it) }
            dopunaRadi = false
        }
    }

    // ── Izbor teme i povlačenje ──

    fun izaberiTemu(t: String) {
        val b = bitka ?: return
        if (b.korak != Bitka.Korak.UVOD || !b.napadam || t !in b.teme) return
        bitka = b.copy(prikazi = b.prikazi.map { uzmiPitanje(t) }, tema = t)
    }

    /** Bitka od 5 pitanja: posle drugog odgovora napadač može da se povuče; vojska ostaje, potez se završava. */
    val mozePovlacenje: Boolean get() {
        val b = bitka ?: return false
        if (!b.napadam || b.korak != Bitka.Korak.PITANJA || b.prikazi.size != Pravila.PITANJA_U_BITCI) return false
        return b.redni >= Pravila.POVLACENJE_POSLE
    }

    fun povuciSe() {
        val b = bitka ?: return
        if (!mozePovlacenje) return
        Zvuk.pusti(Zvuk.Vrsta.POVLACENJE, 0.45f)
        bitka = null
        stanje = stanje.postaviUlog(0)
        javi("Povukao si se iz ${Mapa.oblast(b.kuda).ime}. Vojska je sačuvana, potez je gotov.")
        krajPoteza()
    }

    // ── Postavljanje pre prvog kruga ──

    /** Igrač sam bira početne države na svom kontinentu (prva je prestonica), pa raspoređuje vojske. */
    data class Postavljanje(val kontinent: Kontinent, val original: Stanje, val drzave: List<String> = emptyList())
    var postavljanje by mutableStateOf<Postavljanje?>(null); private set
    val zaPostavljanje: Int get() = Pravila.VOJSKI_NA_POCETKU - (postavljanje?.drzave?.sumOf { stanje.oblasti[it]?.vojske ?: 0 } ?: 0)

    /** Posle misije: partija na telefonu kreće postavljanjem; preko servera mapu postavlja domaćin, pa odmah počinje. */
    fun pocniPostavljanje() {
        if (postavljanje != null) return
        val ja = stanje.igraci.firstOrNull { it.covek }
        if (veza != null || stanje.krug != 1 || stanje.faza != Faza.SNABDEVANJE || ja == null) { zapocni(); return }
        postavljanje = Postavljanje(Kontinenti.od(ja.prestonica), stanje)
        oslobodiMoje()
    }

    private fun oslobodiMoje() {
        val tim = mojTim ?: return
        stanje = stanje.copy(oblasti = stanje.oblasti.mapValues { (_, o) -> if (o.vlasnik == tim) StanjeOblasti(null, Pravila.NEUTRALNE_VOJSKE) else o })
    }

    private fun dodirPostavljanja(id: String) {
        val p = postavljanje ?: return
        val tim = mojTim ?: return
        val o = stanje.oblasti[id] ?: return
        if (p.drzave.size < Pravila.POCETNIH_DRZAVA) {
            // Kad na kontinentu nema slobodnih, bira se bilo gde.
            val slobodnih = Kontinenti.oblasti(p.kontinent.id).count { stanje.oblasti[it]?.vlasnik == null }
            if (o.vlasnik != null) { javi("${Mapa.oblast(id).ime} je zauzeta. Biraj slobodnu državu."); return }
            Cudo.za(id)?.let { javi("${it.naziv}: čudo sveta se osvaja u igri, ne bira na početku."); return }
            if (Kontinenti.od(id).id != p.kontinent.id && slobodnih > 0) { javi("Biraš države na kontinentu ${p.kontinent.ime}."); return }
            stanje = stanje.copy(oblasti = stanje.oblasti + (id to StanjeOblasti(tim, 1)))
            postavljanje = p.copy(drzave = p.drzave + id)
        } else if (id in p.drzave && zaPostavljanje > 0) {
            stanje = stanje.copy(oblasti = stanje.oblasti + (id to o.copy(vojske = o.vojske + 1)))
        }
    }

    fun ponistiPostavljanje() {
        val p = postavljanje ?: return
        stanje = p.original
        postavljanje = Postavljanje(p.kontinent, p.original)
        oslobodiMoje()
    }

    /** Ostatak vojske ide redom po izabranim državama (prestonica prva). */
    fun rasporediPostavljanjeSam() {
        val p = postavljanje ?: return
        if (p.drzave.size < Pravila.POCETNIH_DRZAVA) return
        var i = 0
        while (zaPostavljanje > 0) {
            val id = p.drzave[i++ % p.drzave.size]
            val o = stanje.oblasti.getValue(id)
            stanje = stanje.copy(oblasti = stanje.oblasti + (id to o.copy(vojske = o.vojske + 1)))
        }
    }

    fun zavrsiPostavljanje() {
        val p = postavljanje ?: return
        val prva = p.drzave.firstOrNull() ?: return
        if (p.drzave.size < Pravila.POCETNIH_DRZAVA || zaPostavljanje > 0) return
        stanje = stanje.copy(igraci = stanje.igraci.map { if (it.covek) it.copy(prestonica = prva) else it })
        postavljanje = null
        zapocni()
    }

    fun zapocni() {
        if (!spremno || stanje.krug != 1 || stanje.faza != Faza.SNABDEVANJE || otvoreno != null || potezBota?.isActive == true) return
        // Reprodukcija kreće od početne mape, ne od biranja država.
        istorija = listOf(stanje.oblasti.mapNotNull { (k, v) -> v.vlasnik?.let { k to it } }.toMap())
        // Domaćin šalje početno stanje (mapa, misije, redosled); ostali kreću kad ga prime.
        if (veza?.domacin == true) objavi(stanje)
        if (veza != null) { pocniPotezAkoTreba(); return }
        pocniPotez(stanje)
    }

    fun dodir(id: String) {
        produziSat()
        if (postavljanje != null) { dodirPostavljanja(id); return }
        if (!covekNaPotezu || otvoreno != null || bitka != null) return
        val oblast = stanje.oblasti[id] ?: return
        Zvuk.pusti(Zvuk.Vrsta.IZBOR_DRZAVE, 0.3f)
        val moja = oblast.vlasnik == stanje.trenutni.tim
        if (biraPohod) {
            biraPohod = false
            val region = Mapa.oblast(id).region
            val novo = stanje.najaviPohod(region)
            if (novo != null) {
                stanje = novo
                objavi(novo)
                javi("Pohod: ${Mapa.regioni.firstOrNull { it.id == region }?.ime.orEmpty()}. Drži ga ceo na početku sledećeg poteza: +${Pravila.NAGRADA_POHODA} vojske i karta.")
            } else javi("Taj region već držiš ceo, izaberi drugi")
            return
        }
        when (stanje.faza) {
            Faza.RASPORED -> {
                if (!moja) { javi("Vojsku stavljaš samo na svoje države."); return }
                val novo = stanje.rasporedi(id)
                if (novo == stanje) javi("${Mapa.oblast(id).ime} je odsečena od prestonice: tu ne stižu pojačanja.") else stanje = novo
                if (stanje.faza == Faza.NAPAD) javi("Vojska je raspoređena. Biraj odakle napadaš.")
            }
            Faza.NAPAD -> {
                val izvor = izabrana
                if (utvrdjivanje) {
                    if (izvor != null && moja && id in stanje.dometMarsa(izvor)) {
                        stanje = stanje.utvrdi(izvor, id, (stanje.oblasti[izvor]?.vojske ?: 1) - 1)
                        utvrdjivanje = false; izabrana = null; javi("Vojske prebačene")
                    } else izabrana = if (moja) id else null
                } else if (moja) {
                    izabrana = if (stanje.mete(id).isEmpty()) null else id
                    if (izabrana == null) javi(razlogBezNapada(id))
                } else if (izvor != null && id in stanje.mete(izvor)) {
                    meta = if (meta == id) null else id
                } else if (izvor != null && id in stanje.meteIzdaje(izvor)) {
                    izdajaZa = id
                }
            }
            else -> Unit
        }
    }

    fun rasporediSam() { stanje = stanje.botRasporedi(); javi("Vojska je na granicama. Biraj odakle napadaš.") }
    fun prekidacUtvrdjivanja() { utvrdjivanje = !utvrdjivanje; izabrana = null }

    /** Potvrda napada sa panela mete. */
    fun napadni() {
        val izvor = izabrana ?: return
        val kuda = meta ?: return
        if (kuda !in stanje.mete(izvor)) return
        meta = null
        if (stanje.oblasti[kuda]?.vlasnik != null) stanje = stanje.postaviUlog(ulog)
        ulog = 0
        bitka = novaBitka(true, izvor, kuda)
    }

    fun odustaniOdMete() { meta = null }

    /** Zašto iz svoje države ne može da se napadne (inače bi dodir izgledao kao da ne radi). */
    private fun razlogBezNapada(id: String): String {
        val ime = Mapa.oblast(id).ime
        return when {
            stanje.bitaka >= stanje.napadaPoPotezu -> "Iskoristio si sve napade u ovom potezu. Završi potez."
            (stanje.oblasti[id]?.vojske ?: 0) < 2 -> "$ime ima 1 vojsku, za napad trebaju 2. Prebaci vojske dugmetom Utvrdi."
            else -> "$ime nema suseda za napad."
        }
    }

    /** Pomoć „Preskok”: tekuće pitanje se menja novim iz špila, bez odgovora. */
    fun zameniPitanje() {
        val b = bitka
        if (b != null && b.korak == Bitka.Korak.PITANJA) {
            bitka = b.copy(prikazi = b.prikazi.toMutableList().also { it[b.redni] = uzmiPitanje() }, zamena = b.zamena + 1, satStoji = false)
        } else otvoreno?.let { otvoreno = Otvoreno(uzmiPitanje()) }
    }

    // ── Sat poteza (30 s, svaki dodir produžava; tri isteka bez napada = ispadanje) ──

    var rokPoteza by mutableStateOf<Long?>(null); private set
    private var satPoteza: Job? = null
    /** Domaćin prati igrača sa drugog telefona: ako se ne javi u roku (+15 s za mrežu), potez je propušten. */
    private var pocetakUdaljenogPoteza: Triple<Int, Int, Long>? = null

    private fun pokreniPetlju() {
        if (satPoteza?.isActive == true) return
        satPoteza = viewModelScope.launch { while (true) { delay(1000); proveriSat() } }
    }

    private fun pokreniSat() { rokPoteza = System.currentTimeMillis() + Pravila.ROK_POTEZA_SEKUNDI * 1000L; pokreniPetlju() }
    private fun produziSat() { if (rokPoteza != null) rokPoteza = System.currentTimeMillis() + Pravila.ROK_POTEZA_SEKUNDI * 1000L }

    private fun pratiUdaljenog() {
        if (veza?.domacin != true || !udaljen(stanje.trenutni) || stanje.faza == Faza.KRAJ) return
        pocetakUdaljenogPoteza = Triple(stanje.krug, stanje.naPotezu, System.currentTimeMillis())
        pokreniPetlju()
    }

    private fun proveriSat() {
        val p = pocetakUdaljenogPoteza
        if (veza?.domacin == true && p != null && udaljen(stanje.trenutni) && stanje.faza != Faza.KRAJ &&
            p.first == stanje.krug && p.second == stanje.naPotezu &&
            System.currentTimeMillis() - p.third > (Pravila.ROK_POTEZA_SEKUNDI + 15) * 1000L) {
            pocetakUdaljenogPoteza = null
            val novo = stanje.isteklo(stanje.trenutni.id)
            objavi(novo); pocniPotez(novo)
            return
        }
        val rok = rokPoteza ?: return
        if (!covekNaPotezu || (stanje.faza != Faza.NAPAD && stanje.faza != Faza.RASPORED)) { rokPoteza = null; return }
        // Isteklo vreme za raspoređivanje: ostatak vojske ide na granice, a sat kreće za napad.
        if (stanje.faza == Faza.RASPORED) {
            if (System.currentTimeMillis() >= rok) { stanje = stanje.botRasporedi(); javi("Vreme je isteklo: ostatak vojske je na granicama."); pokreniSat() }
            return
        }
        // Bitka i otvoreno pitanje imaju svoj sat; rok poteza čeka.
        if (bitka != null || otvoreno != null) { produziSat(); return }
        if (System.currentTimeMillis() >= rok) istekaoPotez()
    }

    private fun istekaoPotez() {
        rokPoteza = null
        val ja = stanje.trenutni
        val novo = stanje.isteklo(ja.id)
        izabrana = null; meta = null; utvrdjivanje = false
        if (novo.igraci.firstOrNull { it.id == ja.id }?.ispao == true) {
            javi("Ispao si: tri poteza zaredom bez napada.")
            if (veza == null) { stanje = novo.copy(faza = Faza.KRAJ); return }
        } else if (stanje.bitaka == 0) {
            javi("Vreme je isteklo, potez prelazi dalje (${novo.propusteno?.get(ja.id) ?: 0}/${Pravila.PROPUSTENIH_DO_ISPADANJA}).")
        }
        objavi(novo)
        pocniPotez(novo)
    }

    fun krajPoteza() {
        rokPoteza = null
        izabrana = null; utvrdjivanje = false
        val novo = stanje.zavrsiPotez()
        objavi(novo)
        pocniPotez(novo)
    }

    fun postaviOdbranu(k: String, o: Odbrana) {
        val novo = stanje.postaviOdbranu(k, o)
        if (novo == stanje) { javi("Odbranu menja kapiten, jednom po krugu, na svom potezu"); return }
        stanje = novo
        javi("${Kontinenti.svi.first { it.id == k }.ime}: ${o.naziv}")
    }

    fun iskoristiBonusPomoc(): Boolean {
        val t = mojTim ?: return false
        stanje = stanje.iskoristiBonusPomoc(t) ?: return false
        return true
    }

    /** Odgovor na pitanje snabdevanja (null = isteklo vreme). */
    fun odgovoreno(izabran: Int?, ms: Int) {
        val o = otvoreno ?: return
        otvoreno = null
        val tacno = izabran == o.prikaz.tacan
        if (tacno) tacnih++ else netacnih++
        zbirMs += ms
        stanje = stanje.snabdevanje(tacno)
        javi(if (tacno) "Tačno! Raspoređuješ ${stanje.zaRaspored}" else "Netačno. Dobijaš samo ${stanje.zaRaspored}")
    }

    // ── Bitka ──

    private fun novaBitka(napadam: Boolean, odakle: String, kuda: String): Bitka {
        val kontinent = Kontinenti.od(kuda).ime
        val uslov = stanje.uslovBitke(kuda, mojTim)
        val rival = if (napadam) stanje.igraci.firstOrNull { it.tim == stanje.oblasti[kuda]?.vlasnik }?.ime ?: "niko (prazno polje)" else stanje.trenutni.ime
        val prikazi = (0 until uslov.pitanja).map { i -> if (i < PITANJA_O_KONTINENTU) uzmiPitanjeKontinenta(kontinent) ?: uzmiPitanje() else uzmiPitanje() }.shuffled()
        // Napadač bira temu (osim kad odbrana „Tema branioca” već određuje pitanja).
        val teme = if (napadam && !uslov.temaBranioca) spil.teme(uslov.pitanja).shuffled().take(3) else emptyList()
        val pomak = if (stanje.oblasti[kuda]?.vlasnik != null) stanje.pomakBitke(odakle, kuda) else 0
        return Bitka(napadam, odakle, kuda, uslov, prikazi, rival, teme = teme, pomak = pomak)
    }

    fun pocniPitanja() { bitka = bitka?.copy(korak = Bitka.Korak.PITANJA) }

    /** Odgovor na pitanje u bitki (null = isteklo vreme). */
    fun odgovorUBitci(izabran: Int?, ms: Int) {
        var b = bitka ?: return
        if (b.korak != Bitka.Korak.PITANJA) return
        val pravi = izabran == b.prikazi[b.redni].tacan
        var tacno = pravi
        b = b.copy(ms = b.ms + ms)
        zbirMs += ms
        // Štit (Garda): greška se briše, umesto nje stiže novo pitanje.
        if (!pravi && b.stit) {
            netacnih++
            bitka = b.copy(stit = false, satStoji = false, zamena = b.zamena + 1, prikazi = b.prikazi.toMutableList().also { it[b.redni] = uzmiPitanje() })
            return
        }
        if (pravi) tacnih++ else netacnih++
        // Siguran udar (Legija): svaki odgovor je tačan, a pogodak vredi dva.
        if (b.siguran) { b = b.copy(siguran = false, tacnih = b.tacnih + if (pravi) 2 else 1); tacno = true }
        else if (pravi) b = b.copy(tacnih = b.tacnih + 1)
        if (pravi && b.dvostruko) b = b.copy(dvostruko = false, tacnih = b.tacnih + 1)
        b = b.copy(satStoji = false)
        if (b.redni + 1 < b.prikazi.size) { bitka = b.copy(redni = b.redni + 1); return }
        if (b.napadam) {
            val vlasnik = stanje.oblasti[b.kuda]?.vlasnik
            val branilac = stanje.igraci.firstOrNull { it.tim == vlasnik }
            if (vlasnik == null) {
                val (novo, ishod) = stanje.razresiBitku(b.odakle, b.kuda, Odgovor(tacno, ms), null)
                stanje = novo; b = b.copy(ishod = ishod)
                udari(b.odakle, b.kuda, ishod.osvojeno)
            } else if (branilac != null && udaljen(branilac)) {
                // Branilac je na drugom telefonu: rezultat stiže kad odgovori (ili posle roka).
                val moj = Skor(b.tacnih, b.ms)
                val zavrsena = b.copy(korak = Bitka.Korak.REZULTAT)
                bitka = zavrsena
                viewModelScope.launch {
                    var rival = udaljenaOdbrana(zavrsena.odakle, zavrsena.kuda, moj)
                    if (zavrsena.sabotaza) rival = Skor(maxOf(0, rival.tacnih - 1), rival.ms)
                    if (zavrsena.kuda !in stanje.mete(zavrsena.odakle)) return@launch
                    val (novo, ishod) = stanje.razresiBitkuSkorom(zavrsena.odakle, zavrsena.kuda, moj, rival)
                    stanje = novo
                    udari(zavrsena.odakle, zavrsena.kuda, ishod.osvojeno)
                    bitka = bitka?.copy(rival = rival, ishod = ishod)
                    objavi(novo)
                }
                return
            } else {
                var rival = stanje.botSkor(slucajno, b.prikazi.size)
                if (b.sabotaza) rival = Skor(maxOf(0, rival.tacnih - 1), rival.ms)
                val (novo, ishod) = stanje.razresiBitkuSkorom(b.odakle, b.kuda, Skor(b.tacnih, b.ms), rival)
                stanje = novo; b = b.copy(rival = rival, ishod = ishod)
                udari(b.odakle, b.kuda, ishod.osvojeno)
                // Bot ponekad odgovori na poraz (brze poruke, bez slobodnog teksta).
                if (ishod.osvojeno && branilac != null && slucajno.sledeci() < 0.4) {
                    stanje = stanje.posalji(listOf("Osveta!", "Čuvaj se!")[(slucajno.sledeci() * 2).toInt()], branilac.id)
                }
            }
            objavi(stanje)
        }
        val n = udaljeniNapad
        if (!b.napadam && n != null && veza != null) {
            // Odbrana od napada sa drugog telefona: šaljem svoj skor; ishod za prikaz po istom pravilu, mapa stiže sa servera.
            val moj = Skor(b.tacnih, b.ms)
            udaljeniNapad = null
            viewModelScope.launch { veza.posalji(VezaOsvajanja.Akcija("odbrana", skor = moj, bitka = n.first)) }
            val osvojio = stanje.osvaja(b.odakle, b.kuda, n.second, moj)
            b = b.copy(rival = n.second, ishod = Ishod(0, 0, osvojio, false, false, izgubljenaDrzava = !osvojio))
        }
        bitka = b.copy(korak = Bitka.Korak.REZULTAT)
        // Napadač je odigrao Sabotažu: braniocu se računa jedan tačan manje.
        if (!b.napadam) { cekaOdbranu?.complete(Skor(maxOf(0, b.tacnih - if (b.sabotiranSam) 1 else 0), b.ms)); cekaOdbranu = null }
    }

    /** Rezultat odbrane (kad bot napada čoveka) upisuje se posle razrešenja u potezu bota. */
    private fun ishodOdbrane(rival: Skor, ishod: Ishod) { bitka = bitka?.copy(rival = rival, ishod = ishod) }

    fun zatvoriBitku() {
        val b = bitka ?: return
        bitka = null
        val ishod = b.ishod
        // Ishod se video preko mape; osvajanje se pušta tek kad je mapa opet vidljiva.
        if (ishod != null) udari(b.odakle, b.kuda, ishod.osvojeno)
        if (b.napadam && ishod != null) {
            if (ishod.osvojeno) {
                javi(if (ishod.plen) "Prestonica pala! +5 plena" else if (ishod.proboj) "Proboj! +2 vojske" else "Osvojeno! Cepaj dalje")
                izabrana = if (stanje.mete(b.kuda).isEmpty()) null else b.kuda
            } else if (stanje.mete(b.odakle).isEmpty()) izabrana = null
        }
        // Odbrana zatvorena pre kraja (izlazak, prekid): bot dobija skor bez tačnih umesto da čeka zauvek.
        cekaOdbranu?.complete(Skor(0, Pravila.PITANJA_U_BITCI * Pravila.SEKUNDI_PO_PITANJU * 1000)); cekaOdbranu = null
        zatvaranje?.complete(Unit); zatvaranje = null
        sacuvaj()
        najaviMisijuAkoTreba()
    }

    // ── Pomoći vojske ──

    val mojaVojska: VrstaVojske? get() = mojTim?.let { stanje.vojskaTima(it) }

    /** Troši pomoć vojske za ovaj krug; dejstva na odgovore i vreme radi ekran bitke (vraća dejstvo), ostalo model. */
    fun iskoristiPomocVojske(p: PomocVojske): Dejstvo? {
        val b = bitka ?: return null
        val t = mojTim ?: return null
        if (b.korak != Bitka.Korak.PITANJA) return null
        val novo = stanje.iskoristiPomocVojske(t, p) ?: return null
        if (p.dejstvo == Dejstvo.Dvostruko && !(b.napadam && b.prikazi.size > 1)) return null
        Zvuk.pusti(Zvuk.Vrsta.POMOC_VOJSKE, 0.45f)
        stanje = novo
        when (p.dejstvo) {
            Dejstvo.Dvostruko -> bitka = b.copy(dvostruko = true)
            Dejstvo.Stit -> bitka = b.copy(stit = true)
            Dejstvo.Siguran -> bitka = b.copy(siguran = true)
            Dejstvo.SatStoji -> bitka = b.copy(satStoji = true)
            Dejstvo.Zamena -> zameniPitanje()
            else -> Unit
        }
        return p.dejstvo
    }

    // ── Ratne karte (umesto dnevnih pomoći) ──

    val mojeKarte: List<Karta> get() = mojTim?.let { stanje.karte(it) }.orEmpty()

    /** Karta sa mape (Pojačanje, Zamrzni) na izabranu svoju državu ili prestonicu, samo na svom potezu. */
    fun igrajKartuNaMapi(k: Karta) {
        val ja = stanje.igraci.firstOrNull { it.covek } ?: return
        if (!covekNaPotezu) return
        val gde = izabrana?.takeIf { stanje.oblasti[it]?.vlasnik == ja.tim } ?: ja.prestonica
        val novo = (if (k == Karta.POJACANJE) stanje.igrajPojacanje(gde) else stanje.igrajZamrzni(gde))
        if (novo == null) { javi("Izaberi svoju državu, pa odigraj kartu"); return }
        Zvuk.pusti(Zvuk.Vrsta.KARTA_ODIGRANA, 0.45f)
        stanje = novo
        objavi(novo)
        javi(if (k == Karta.POJACANJE) "+${Pravila.VOJSKI_POJACANJA} vojske: ${Mapa.oblast(gde).ime}" else "${Mapa.oblast(gde).ime} je zamrznuta do kraja sledećeg kruga")
    }

    /** Karta u bitki: Špijun (odgovor na prvo pitanje), Drugi pokušaj (novo pitanje), Sabotaža (protivniku tačan manje). */
    fun igrajKartuUBitci(k: Karta) {
        var b = bitka ?: return
        val t = mojTim ?: return
        if (b.korak == Bitka.Korak.REZULTAT) return
        val novo = stanje.iskoristiKartu(t, k) ?: return
        when (k) {
            Karta.SPIJUN -> b = b.copy(spijun = true)
            Karta.SABOTAZA -> { if (!b.napadam || stanje.oblasti[b.kuda]?.vlasnik == null) return; b = b.copy(sabotaza = true) }
            Karta.DRUGI_POKUSAJ -> if (b.korak != Bitka.Korak.PITANJA) return
            else -> return
        }
        Zvuk.pusti(Zvuk.Vrsta.KARTA_ODIGRANA, 0.45f)
        stanje = novo
        bitka = b
        if (k == Karta.DRUGI_POKUSAJ) zameniPitanje()
    }

    // ── Brze poruke i savezi ──

    /**
     * Brza poruka; „Savez?” igraču `za` je i predlog saveza (bot odmah odgovara).
     * shortcut: preko servera poruke i savezi idu samo na svom potezu (stanje šalje igrač na potezu); kasnije poseban kanal.
     */
    fun posaljiPoruku(tekst: String, za: Igrac? = null) {
        val ja = stanje.igraci.firstOrNull { it.covek } ?: return
        if (stanje.faza == Faza.KRAJ) return
        if (veza != null && !covekNaPotezu) { javi("Poruke i savezi idu na tvom potezu"); return }
        var novo = stanje.posalji(tekst, ja.id)
        if (tekst == "Savez?" && za != null && za.tim != ja.tim) {
            val bot = !za.covek && !za.id.startsWith("u:")
            val prihvata = bot && novo.botPrihvataSavez(za.tim, ja.tim)
            novo = novo.predloziSavez(ja.tim, za.tim, prihvata)
            if (bot) novo = novo.posalji(if (prihvata) "Može, savez!" else "Ne ovaj put.", za.id)
            if (novo.uSavezu(ja.tim, za.tim)) javi("Savez sa ${za.ime} do kraja sledećeg kruga")
        }
        stanje = novo
        objavi(novo)
    }

    // ── Tok poteza ──

    fun novaPartija() {
        potezBota?.cancel()
        izabrana = null; utvrdjivanje = false; otvoreno = null; bitka = null
        stanje = nova()
        pocniPotez(stanje)
    }

    private fun pocniPotez(novo: Stanje) {
        stanje = novo
        sacuvaj()
        najaviMisijuAkoTreba()
        if (novo.faza != Faza.SNABDEVANJE) return
        zapocetPotez = novo.krug to novo.naPotezu
        // Pravi igrač sa drugog telefona igra sam; bota vodi samo domaćin.
        if (udaljen(novo.trenutni)) { pratiUdaljenog(); return }
        if (veza != null && !novo.trenutni.covek && veza.domacin.not()) return
        if (novo.trenutni.covek) {
            // Pojačanja stižu bez pitanja, a igrač ih sam raspoređuje dodirom (vlasnik 03.11); „Rasporedi sam” ih stavlja na granice.
            val tim = novo.trenutni.tim
            val s = novo.snabdevanje(true)
            stanje = s.copy(tacnih = s.tacnih + (tim to ((s.tacnih[tim] ?: 1) - 1))) // pojačanje nije tačan odgovor (misije broje tačne)
            val n = s.zaRaspored
            val rec = if (n % 10 == 1 && n % 100 != 11) "vojska" else if (n % 10 in 2..4 && n % 100 !in 12..14) "vojske" else "vojski"
            javi("Stiglo je $n $rec. Dodiruj svoje države gde ih želiš.")
            pokreniSat()
        } else potezBota = viewModelScope.launch { igrajBota() }
    }

    /** Najviše napada jednog bota u potezu (osigurač; pravi potez ih ima nekoliko). */
    private val NAJVISE_NAPADA_BOTA = 40

    private suspend fun igrajBota() {
        if (botRadi) return
        botRadi = true
        pokreniCuvara()
        var napada = 0
        try {
            stanje = stanje.snabdevanje(slucajno.sledeci() < stanje.tacnostBota).botRasporedi().botOdbrana().botIgraKarte().botTraziSavez()
                .botIzdaja().botNajaviPohod().botUltimatum()
            delay(pauzaBota)
            while (napada < NAJVISE_NAPADA_BOTA) {
                sacekajObavestenje()
                val (odakle, kuda) = stanje.botSledeciNapad() ?: break
                napada++
                val preBitaka = stanje.bitaka; val preOblasti = stanje.oblasti
                izabrana = odakle
                Zvuk.pusti(Zvuk.Vrsta.BOT_NAPADA, 0.45f)
                delay(pauzaBota)
                val vlasnik = stanje.oblasti[kuda]?.vlasnik
                if (vlasnik != null) {
                    val tim = stanje.trenutni.tim
                    // Prva dva odgovora posebno: oprezan bot se povlači posle dve greške i završava napade.
                    val prva = (0 until Pravila.POVLACENJE_POSLE).map { stanje.botOdgovor(slucajno) }
                    if (stanje.narav(stanje.trenutni.id) == Narav.OPREZAN && prva.none { it.tacan }) {
                        stanje = stanje.posalji("Povlačim se!", stanje.trenutni.id)
                        break
                    }
                    val ostatak = stanje.botSkor(slucajno, Pravila.PITANJA_U_BITCI - Pravila.POVLACENJE_POSLE)
                    var napadac = Skor(prva.count { it.tacan } + ostatak.tacnih, prva.sumOf { it.ms } + ostatak.ms)
                    // Ulog kad je bitka skoro sigurna.
                    val branilacCovek = stanje.igraci.firstOrNull { it.tim == vlasnik }?.let { it.covek || it.id.startsWith("u:") } ?: false
                    stanje = stanje.postaviUlog(Stanje.ulogBota(Stanje.sansaBitke(stanje.tacnostBota, if (branilacCovek) 0.65 else stanje.tacnostBota,
                        Pravila.PITANJA_U_BITCI, stanje.odbranaMete(kuda) == Odbrana.PREDNOST, stanje.pomakBitke(odakle, kuda))))
                    // Drugi pokušaj: jedno promašeno pitanje bot odgovara ponovo.
                    if (napadac.tacnih < Pravila.PITANJA_U_BITCI) stanje.iskoristiKartu(tim, Karta.DRUGI_POKUSAJ)?.let { novo ->
                        stanje = novo
                        if (slucajno.sledeci() < stanje.tacnostBota) napadac = Skor(napadac.tacnih + 1, napadac.ms)
                    }
                    // Sabotaža: branilac gubi jedan tačan.
                    var sabotaza = false
                    stanje.iskoristiKartu(tim, Karta.SABOTAZA)?.let { stanje = it; sabotaza = true }
                    val b = stanje.igraci.firstOrNull { it.tim == vlasnik }
                    if (b != null && udaljen(b)) {
                        var branilac = udaljenaOdbrana(odakle, kuda, napadac)
                        if (sabotaza) branilac = Skor(maxOf(0, branilac.tacnih - 1), branilac.ms)
                        val (novo, ishod) = stanje.razresiBitkuSkorom(odakle, kuda, napadac, branilac)
                        stanje = novo
                        udari(odakle, kuda, ishod.osvojeno)
                        objavi(stanje)
                    } else if (b?.covek == true) {
                        val cekanje = CompletableDeferred<Skor>()
                        cekaOdbranu = cekanje
                        bitka = novaBitka(false, odakle, kuda).copy(sabotiranSam = sabotaza)
                        Zvuk.pusti(Zvuk.Vrsta.UZBUNA, 0.5f)
                        val branilac = cekanje.await()
                        val (novo, ishod) = stanje.razresiBitkuSkorom(odakle, kuda, napadac, branilac)
                        stanje = novo
                        udari(odakle, kuda, ishod.osvojeno)
                        if (ishod.osvojeno && slucajno.sledeci() < 0.35) stanje = stanje.posalji(listOf("Hvala!", "Bravo!")[(slucajno.sledeci() * 2).toInt()], stanje.trenutni.id)
                        ishodOdbrane(napadac, ishod)
                        // Igrač je možda već zatvorio ekran bitke: tada se ne čeka (inače bot stoji zauvek, partija se zamrzne).
                        if (bitka != null) { val z = CompletableDeferred<Unit>(); zatvaranje = z; z.await() }
                    } else {
                        var branilac = stanje.botSkor(slucajno)
                        if (sabotaza) branilac = Skor(maxOf(0, branilac.tacnih - 1), branilac.ms)
                        val (novo, ishod) = stanje.razresiBitkuSkorom(odakle, kuda, napadac, branilac)
                        stanje = novo
                        udari(odakle, kuda, ishod.osvojeno)
                    }
                } else {
                    val (novo, ishod) = stanje.razresiBitku(odakle, kuda, stanje.botOdgovor(slucajno), null)
                    stanje = novo
                    udari(odakle, kuda, ishod.osvojeno)
                }
                if (stanje.faza == Faza.KRAJ) break
                najaviMisijuAkoTreba()
                // Napad koji pravila odbiju ne menja ništa: bot bi ga birao zauvek i partija bi stala (vlasnik 05.11).
                if (stanje.bitaka == preBitaka && stanje.oblasti == preOblasti) break
                delay(pauzaBota)
            }
            izabrana = null
        } finally { botRadi = false }
        // Pre kraja poteza bot prebacuje vojsku iz unutrašnjosti na ugroženu granicu.
        if (stanje.faza == Faza.NAPAD) stanje = stanje.botUtvrdi()
        val novo = stanje.zavrsiPotez()
        objavi(novo)
        pocniPotez(novo)
    }

    private var cuvar: kotlinx.coroutines.Job? = null

    /** Čuvar poteza bota: ako se potez ne pomeri 30 s (bez pauze i otvorene bitke), potez se završava, da partija ne stane. */
    private fun pokreniCuvara() {
        cuvar?.cancel()
        cuvar = viewModelScope.launch {
            var poslednji = ""; var isto = 0
            while (true) {
                delay(10_000)
                if (stanje.faza == Faza.KRAJ || stanje.trenutni.covek || veza != null) return@launch
                val otisak = "${stanje.krug}-${stanje.naPotezu}-${stanje.bitaka}-${stanje.faza}"
                isto = if (otisak == poslednji && bitka == null && obavestenjeMisije == null) isto + 1 else 0
                poslednji = otisak
                if (isto < 3) continue
                android.util.Log.w("Osvajac", "potez bota zaglavljen ($otisak), završava se")
                potezBota?.cancel()
                botRadi = false
                izabrana = null
                val novo = stanje.zavrsiPotez()
                objavi(novo)
                pocniPotez(novo)
                return@launch
            }
        }
    }

    fun javi(tekst: String) {
        poruka = tekst
        viewModelScope.launch { delay(7000); if (poruka == tekst) poruka = null }
    }

    // ── Obaveštenje o misiji (vlasnik 05.11: „sve se brzo dešava, ne vidim poruke”) ──

    data class ObavestenjeMisije(val moja: Boolean, val ime: String, val tekst: String)
    /** Veliko obaveštenje na sredini ekrana; botovi stoje dok ga igrač ne zatvori. Isto kao iOS. */
    var obavestenjeMisije by mutableStateOf<ObavestenjeMisije?>(null); private set
    private val najavljeneMisije = mutableSetOf<String>()

    /** Čim neki tim ispuni misiju (i usred tuđeg poteza), igrač to vidi jasno, a ne tek posle poteza. */
    fun najaviMisijuAkoTreba() {
        if (veza != null || mojTim == null || stanje.faza == Faza.KRAJ || obavestenjeMisije != null) return
        val ispunjene = stanje.misije.keys.filter { stanje.napredakMisije(it) >= 1 }.toSet()
        najavljeneMisije.retainAll(ispunjene)
        val t = (ispunjene - najavljeneMisije).sorted().firstOrNull() ?: return
        najavljeneMisije += t
        val ime = stanje.igraci.firstOrNull { it.tim == t && it.kapiten }?.ime ?: "Rival"
        obavestenjeMisije = ObavestenjeMisije(t == mojTim, ime, stanje.tekstMisije(stanje.misije[t]))
        Zvuk.pusti(Zvuk.Vrsta.OBAVESTENJE, 0.6f)
    }

    fun zatvoriObavestenjeMisije() { obavestenjeMisije = null }

    private suspend fun sacekajObavestenje() { while (obavestenjeMisije != null) delay(300) }
}
