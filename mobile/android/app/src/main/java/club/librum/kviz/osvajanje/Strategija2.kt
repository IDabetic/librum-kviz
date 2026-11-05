package club.librum.kviz.osvajanje

import kotlin.math.min

// Strategija, drugi talas (vlasnik 03.11.2026), verni prevod Strategija2.swift: teren, linije snabdevanja, čuda sveta,
// magla rata, ulog, marš, najava pohoda, izdaja, trgovina kartama i ultimatum. Sve je u `Stanje` (isti JSON kao iOS).

object Teren {
    /** Planine: braniocu +1 tačan. */
    val planine = setOf("CHE", "AUT", "NPL", "BTN", "BOL", "PER", "GEO", "ARM", "AZE", "AFG", "KGZ", "TJK")
    /** Pustinja: napadač koji izgubi gubi jednu vojsku više. */
    val pustinja = setOf("SAH", "MRT", "MLI", "NER", "TCD", "LBY", "EGY", "DZA", "SDN", "SAU", "OMN", "YEM", "ARE", "QAT", "KWT", "NAM", "BWA", "MNG", "TKM")
    /** Parovi država povezani samo morskim putem: napad preko mora traži jedan tačan više. */
    val more: Set<String> by lazy { Mapa.more.map { Stanje.kljucSaveza(it.a, it.b) }.toSet() }

    fun prekoMora(a: String, b: String): Boolean = Stanje.kljucSaveza(a, b) in more

    /** Kratak opis terena mete za ekran bitke; null kad je ravnica. */
    fun opis(odakle: String, kuda: String): String? {
        val l = buildList {
            if (kuda in planine) add("Planine: branilac +1 tačan")
            if (prekoMora(odakle, kuda)) add("Preko mora: napadaču treba 1 tačan više")
            if (kuda in pustinja) add("Pustinja: poraz košta vojsku više")
        }
        return if (l.isEmpty()) null else l.joinToString(" · ")
    }
}

/** Čudo sveta: jedna država po kontinentu; ko je drži, ima trajnu prednost. */
data class Cudo(val oblast: String, val naziv: String, val opis: String) {
    companion object {
        val sva = listOf(
            Cudo("EGY", "Piramide", "+2 vojske svakog kruga."),
            Cudo("CHN", "Kineski zid", "+1 tačan u odbrani država u Aziji."),
            Cudo("GRC", "Akropolj", "Ratna karta svakog kruga."),
            Cudo("PER", "Maču Pikču", "Vidiš sve vojske na mapi (bez magle)."),
            Cudo("USA", "Kip slobode", "+1 napad u svakom potezu."),
            Cudo("AUS", "Sidnejska opera", "+5 sekundi za svako pitanje u bitki."),
        )
        fun za(oblast: String): Cudo? = sva.firstOrNull { it.oblast == oblast }
    }
}

// ── Čuda ──

/** Da li tim drži čudo u toj državi (i da li ta država postoji u ovoj partiji). */
fun Stanje.drziCudo(tim: String, oblast: String): Boolean = oblasti[oblast]?.vlasnik == tim

// ── Linije snabdevanja ──

/**
 * Države tima povezane (kroz njegove države) sa prestonicom nekog člana tima.
 * Tim bez ijedne prestonice snabdeva se iz najveće povezane grupe, da ne propadne sve odjednom.
 */
fun Stanje.snabdevene(tim: String): Set<String> {
    val moje = oblasti.filter { it.value.vlasnik == tim }.keys
    if (moje.isEmpty()) return emptySet()
    fun grupa(start: String): Set<String> {
        val vidjeno = mutableSetOf(start); val red = mutableListOf(start)
        while (red.isNotEmpty()) {
            val o = red.removeAt(red.size - 1)
            for (n in Mapa.susedi(o)) if (n in moje && vidjeno.add(n)) red += n
        }
        return vidjeno
    }
    val prestonice = igraci.filter { it.tim == tim && it.prestonica in moje }.map { it.prestonica }
    if (prestonice.isNotEmpty()) return prestonice.flatMapTo(mutableSetOf()) { grupa(it) }
    val ostalo = moje.toMutableSet(); var najveca = emptySet<String>()
    while (ostalo.isNotEmpty()) { val g = grupa(ostalo.first()); ostalo -= g; if (g.size > najveca.size) najveca = g }
    return najveca
}

fun Stanje.odsecene(tim: String): Set<String> = oblasti.filter { it.value.vlasnik == tim }.keys - snabdevene(tim)

// ── Magla rata ──

/** Država čije vojske tim vidi: svoja, saveznikova, susedna svojoj, ili sve kad drži Maču Pikču. */
fun Stanje.vidi(tim: String, oblast: String): Boolean {
    val o = oblasti[oblast] ?: return false
    if (drziCudo(tim, "PER") || o.vlasnik == tim || (o.vlasnik != null && uSavezu(tim, o.vlasnik))) return true
    return Mapa.susedi(oblast).any { oblasti[it]?.vlasnik == tim }
}

// ── Ulog ──

/** Ulog pre bitke sa igračem (0–2): pobeda odnosi braniocu još toliko, poraz napadaču još toliko. */
fun Stanje.postaviUlog(n: Int): Stanje = copy(ulog = if (n > 0) min(Pravila.NAJVECI_ULOG, n) else null)

/** Najjača država tima pored `oko` (ne sama `oko`), za odbijanje vojske uloga; null kad nema nijedne sa 2+. */
fun Stanje.najjacaPored(oko: String, tim: String): String? =
    Mapa.susedi(oko).filter { oblasti[it]?.vlasnik == tim && (oblasti[it]?.vojske ?: 0) > 1 }
        .maxWithOrNull(compareBy<String>({ oblasti[it]?.vojske ?: 0 }, { it }))

// ── Marš ──

/** Do koje svoje države vojska stiže iz `odakle` kroz najviše `KORAKA_MARSA` svojih država. */
fun Stanje.dometMarsa(odakle: String): Set<String> {
    val tim = oblasti[odakle]?.vlasnik ?: return emptySet()
    val dostupno = mutableSetOf<String>(); var granica = setOf(odakle); val vidjeno = mutableSetOf(odakle)
    repeat(Pravila.KORAKA_MARSA) {
        val sledeca = mutableSetOf<String>()
        for (o in granica) for (n in Mapa.susedi(o)) if (oblasti[n]?.vlasnik == tim && vidjeno.add(n)) sledeca += n
        dostupno += sledeca; granica = sledeca
    }
    return dostupno
}

// ── Najava pohoda ──

private fun Stanje.drzaveRegiona(region: String) = Mapa.oblasti.filter { it.region == region && oblasti[it.id] != null }.map { it.id }

/** Tajni cilj za ovaj krug: ceo region. Ako ga tim drži na početku svog sledećeg poteza: +3 vojske i karta. */
fun Stanje.najaviPohod(region: String): Stanje? {
    val tim = trenutni.tim
    val ids = drzaveRegiona(region)
    if (faza == Faza.KRAJ || pohodi?.get(tim) != null || ids.isEmpty() || ids.all { oblasti[it]?.vlasnik == tim }) return null
    return copy(pohodi = pohodi.orEmpty() + (tim to region))
}

/** Na početku poteza: ispunjen pohod donosi nagradu; neispunjen se samo briše. Vraća stanje i nagradu u vojskama. */
fun Stanje.proveriPohod(tim: String): Pair<Stanje, Int> {
    val region = pohodi?.get(tim) ?: return this to 0
    var s = copy(pohodi = pohodi - tim)
    val ids = s.drzaveRegiona(region)
    if (ids.isEmpty() || !ids.all { s.oblasti[it]?.vlasnik == tim }) return s to 0
    s = s.dodeliKartu(tim)
    val u = s.uspeliPohodi.orEmpty()
    s = s.copy(uspeliPohodi = u + (tim to (u[tim] ?: 0) + 1))
    return s to Pravila.NAGRADA_POHODA
}

// ── Izdaja ──

fun Stanje.jeIzdajnik(tim: String): Boolean = izdajnici?.contains(tim) == true

/** Prekid saveza napadom: izdajnik gubi sve karte, svi vide oznaku, botovi s njim više ne sklapaju savez. */
fun Stanje.izdaj(tim: String, saveznik: String): Stanje {
    if (!uSavezu(tim, saveznik)) return this
    return copy(
        savezi = savezi?.minus(Stanje.kljucSaveza(tim, saveznik)),
        karteTimova = karteTimova?.plus(tim to emptyList()),
        izdajnici = if (jeIzdajnik(tim)) izdajnici else izdajnici.orEmpty() + tim,
    )
}

/** Susedne države saveznika (moguće samo kroz izdaju). */
fun Stanje.meteIzdaje(odakle: String): List<String> {
    val izvor = oblasti[odakle]
    if (faza != Faza.NAPAD || bitaka >= napadaPoPotezu || izvor == null || izvor.vlasnik != trenutni.tim || izvor.vojske < 2) return emptyList()
    return Mapa.susedi(odakle).filter { id -> oblasti[id]?.vlasnik?.let { uSavezu(izvor.vlasnik, it) } == true }
}

// ── Trgovina kartama ──

/**
 * Razmena sa saveznikom: daješ kartu `k`, saveznik vraća jednu koju ti nemaš (ili prvu koju ima).
 * Vraća novo stanje i dobijenu kartu, ili null kad razmene nema.
 */
fun Stanje.razmeniKartu(od: String, sa: String, daje: Karta): Pair<Stanje, Karta>? {
    if (!uSavezu(od, sa) || daje !in karte(od) || karte(sa).isEmpty() || daje in karte(sa)) return null
    val moje = karte(od)
    val vraca = karte(sa).firstOrNull { it !in moje } ?: karte(sa)[0]
    val mojaRuka = moje.toMutableList().also { it.remove(daje) } + vraca
    val njegova = karte(sa).toMutableList().also { it.remove(vraca) } + daje
    return copy(karteTimova = karteTimova.orEmpty() + mapOf(od to mojaRuka, sa to njegova)) to vraca
}

// ── Ultimatum ──

/**
 * Zahtev slabijem susedu da preda pograničnu državu. Prihvata kad je mnogo slabiji (snaga < 0,6 tvoje) i država nije
 * prestonica; odbijanje daje napadaču +1 tačan na tu državu do kraja poteza. Jedan po potezu.
 */
fun Stanje.ultimatum(kuda: String): Pair<Stanje, Boolean>? {
    val tim = trenutni.tim
    val vlasnik = oblasti[kuda]?.vlasnik
    if (faza != Faza.NAPAD || ultimatumKrug?.get(tim) == krug || vlasnik == null || vlasnik == tim || uSavezu(tim, vlasnik) ||
        Mapa.susedi(kuda).none { oblasti[it]?.vlasnik == tim } || snaga(vlasnik) >= snaga(tim)) return null
    var s = copy(ultimatumKrug = ultimatumKrug.orEmpty() + (tim to krug))
    val prestonica = igraci.any { it.tim == vlasnik && it.prestonica == kuda }
    val odVlasnika = igraci.first { it.tim == vlasnik }.id
    if (!prestonica && snaga(vlasnik) < snaga(tim) * 0.6 && oblasti.values.count { it.vlasnik == vlasnik } > 1) {
        s = s.copy(oblasti = s.oblasti + (kuda to s.oblasti.getValue(kuda).copy(vlasnik = tim)))
        return s.posalji("Predajem ${Mapa.oblast(kuda).ime}.", odVlasnika) to true
    }
    s = s.copy(odbijeniUltimatumi = s.odbijeniUltimatumi.orEmpty() + ("$tim>$kuda" to krug))
    return s.posalji("Nikad!", odVlasnika) to false
}

fun Stanje.odbioUltimatum(tim: String, kuda: String): Boolean = odbijeniUltimatumi?.get("$tim>$kuda") == krug

// ── Bot ──

/** Bot najavljuje pohod na region kome mu fale jedna ili dve države. */
fun Stanje.botNajaviPohod(): Stanje {
    val tim = trenutni.tim
    if (pohodi?.get(tim) != null) return this
    val kandidat = Mapa.regioni.map { it.id }.firstOrNull { r ->
        val ids = drzaveRegiona(r)
        val fali = ids.count { oblasti[it]?.vlasnik != tim }
        ids.isNotEmpty() && fali in 1..2 && ids.any { oblasti[it]?.vlasnik == tim }
    }
    return kandidat?.let { najaviPohod(it) } ?: this
}

/** Napadač bot u poslednja dva kruga izdaje saveznika koji je upola slabiji od njega. */
fun Stanje.botIzdaja(): Stanje {
    val tim = trenutni.tim
    if (narav(trenutni.id) != Narav.NAPADAC || krug < ukupnoKrugova - 1) return this
    val zrtva = saveznici(tim).firstOrNull { snaga(it) * 2 < snaga(tim) } ?: return this
    return izdaj(tim, zrtva).posalji("Izdaja!", trenutni.id)
}

/** Bot šalje ultimatum slabom susednom botu. */
fun Stanje.botUltimatum(): Stanje {
    val tim = trenutni.tim
    val moje = oblasti.filter { it.value.vlasnik == tim }.keys
    val mete = moje.flatMap { Mapa.susedi(it) }.toSet().filter { id ->
        val v = oblasti[id]?.vlasnik ?: return@filter false
        if (v == tim) return@filter false
        val i = igraci.firstOrNull { it.tim == v } ?: return@filter false
        !i.covek && !i.id.startsWith("u:") && snaga(v) < snaga(tim) * 0.6
    }
    val kuda = mete.sorted().firstOrNull() ?: return this
    return ultimatum(kuda)?.first ?: this
}
