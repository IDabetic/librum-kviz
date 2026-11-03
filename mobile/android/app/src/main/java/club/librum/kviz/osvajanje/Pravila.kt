package club.librum.kviz.osvajanje

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

import kotlin.math.max
import kotlin.math.min

// Verni prevod src/lib/osvajanje/pravila.ts (i Pravila.swift). Kad se pravila
// menjaju, menjaju se na sva tri mesta, zajedno sa testovima.

@Serializable data class Region(val id: String, val ime: String, val bonus: Int)

/** Država sa tačkom za natpis i SVG putanjom (M/L/Z) u koordinatama mape. */
@Serializable data class Oblast(
    val id: String, val ime: String, val region: String, val x: Float, val y: Float,
    val boja: Int, val povrsina: Float, val d: String,
)

@Serializable private data class Svet(val sirina: Float, val visina: Float, val regioni: List<Region>, val drzave: List<Oblast>, val veze: List<List<String>>, val more: List<List<kotlinx.serialization.json.JsonPrimitive>>)

/** Morski put sa tačkama obala, za isprekidanu liniju. */
data class MorskiPut(val a: String, val b: String, val x1: Float, val y1: Float, val x2: Float, val y2: Float)

/** Mapa država iz svet.json (isti fajl kao veb i iOS); učitava se jednom pri pokretanju. */
object Mapa {
    private lateinit var svet: Svet
    private lateinit var susedstvo: Map<String, List<String>>
    private lateinit var poId: Map<String, Oblast>

    fun ucitaj(json: String) {
        if (::svet.isInitialized) return
        svet = Json { ignoreUnknownKeys = true }.decodeFromString(Svet.serializer(), json)
        susedstvo = buildMap<String, MutableList<String>> {
            for ((a, b) in svet.veze) {
                getOrPut(a) { mutableListOf() }.add(b)
                getOrPut(b) { mutableListOf() }.add(a)
            }
        }
        poId = svet.drzave.associateBy { it.id }
    }

    val sirina get() = svet.sirina
    val visina get() = svet.visina
    val regioni get() = svet.regioni
    val oblasti get() = svet.drzave
    val veze get() = svet.veze.map { it[0] to it[1] }
    val more: List<MorskiPut> by lazy {
        svet.more.map { MorskiPut(it[0].content, it[1].content, it[2].content.toFloat(), it[3].content.toFloat(), it[4].content.toFloat(), it[5].content.toFloat()) }
    }

    fun susedi(id: String): List<String> = susedstvo[id].orEmpty()
    fun oblast(id: String): Oblast = poId.getValue(id)
}

object Pravila {
    const val POCETNE_VOJSKE_PRESTONICE = 5
    const val POCETNIH_DRZAVA = 6
    const val POCETNE_VOJSKE_DRZAVE = 2
    /** Vreme za odluku na potezu; svaki dodir ga produžava. */
    const val ROK_POTEZA_SEKUNDI = 30
    /** Tri poteza zaredom bez napada (isteklo vreme) = igrač nije u igri i ispada. */
    const val PROPUSTENIH_DO_ISPADANJA = 3
    const val NEUTRALNE_VOJSKE = 1
    /** Vojske koje igrač sam raspoređuje na početne države pre prvog kruga (isto koliko dobija i automatski). */
    const val VOJSKI_NA_POCETKU = POCETNE_VOJSKE_PRESTONICE + (POCETNIH_DRZAVA - 1) * POCETNE_VOJSKE_DRZAVE
    const val NAJMANJE_POJACANJA = 3
    const val TERITORIJA_PO_VOJSCI = 2
    /** Napada zaredom po potezu kad svako igra za sebe; u timu po igraču (tim = 2 × 2). */
    const val BITAKA_PO_POTEZU = 5
    const val BITAKA_U_TIMU_PO_IGRACU = 2
    /** Bitka za državu koju drži igrač: niz pitanja, odlučuju tačni pa brzina. */
    const val PITANJA_U_BITCI = 5
    const val BONUS_POMOCI_POBEDNIKU = 2
    const val GUBITAK_PORAZENOG_NAPADACA = 2
    const val PROBOJ_SVAKIH = 3
    const val PROBOJ_BONUS = 2
    const val PLEN_PRESTONICE = 5
    const val POENI_PO_OBLASTI = 10
    const val POENI_PO_BONUSU = 10
    const val POENI_PRESTONICA = 20
    const val SEKUNDI_PO_PITANJU = 15
    const val SEKUNDI_BRZ_SAT = 8
}

enum class Tezina(val tacnost: Double, val ime: String, val opis: String) {
    LAKO(0.5, "Lako", "Rivali greše svako drugo pitanje"),
    NORMALNO(0.62, "Normalno", "Rivali znaju oko 6 od 10"),
    TESKO(0.75, "Teško", "Rivali znaju 3 od 4"),
}

/** Boja u JSON-u partije kao na iOS-u (0xRRGGBB, bez alfe); u aplikaciji 0xFFRRGGBB. */
object BojaSerializer : kotlinx.serialization.KSerializer<Long> {
    override val descriptor = kotlinx.serialization.descriptors.PrimitiveSerialDescriptor("Boja", kotlinx.serialization.descriptors.PrimitiveKind.LONG)
    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: Long) = encoder.encodeLong(value and 0xFFFFFF)
    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): Long = 0xFF000000 or (decoder.decodeLong() and 0xFFFFFF)
}

@Serializable
data class Igrac(
    val id: String,
    val ime: String,
    @Serializable(with = BojaSerializer::class) val boja: Long,
    val covek: Boolean,
    val prestonica: String,
    val ispao: Boolean,
    /** Tim (vlasnik država). Svako za sebe: tim = id igrača. */
    val tim: String = id,
    /** Kapiten bira odbranu kontinenta (u timu član sa više tačnih na profilu). */
    val kapiten: Boolean = true,
)

/** Igrač za novu partiju (čekaonica): bez prestonice, ona se bira na početku. */
data class NoviIgrac(val id: String, val ime: String, val boja: Long, val covek: Boolean, val tim: String? = null, val kapiten: Boolean = true)

@Serializable data class StanjeOblasti(val vlasnik: String? = null, val vojske: Int)

@Serializable enum class Faza {
    @kotlinx.serialization.SerialName("snabdevanje") SNABDEVANJE, @kotlinx.serialization.SerialName("raspored") RASPORED,
    @kotlinx.serialization.SerialName("napad") NAPAD, @kotlinx.serialization.SerialName("kraj") KRAJ,
}

data class Odgovor(val tacan: Boolean, val ms: Int)

/** Rezultat jedne strane u bitki od 5 pitanja. */
@Serializable data class Skor(val tacnih: Int, val ms: Int)

data class Ishod(
    val gubitakNapadaca: Int,
    val gubitakBranioca: Int,
    val osvojeno: Boolean,
    val proboj: Boolean,
    val plen: Boolean,
    /** Napadač je izgubio bitku protiv igrača, pa branilac uzima državu iz koje je napadnut. */
    val izgubljenaDrzava: Boolean = false,
)

/** Deterministički generator (mulberry32), isti kao na vebu i iOS-u. */
class Slucajno(seme: Int) {
    private var a: Int = seme
    fun sledeci(): Double {
        a += 0x6D2B79F5
        var t = a
        t = (t xor (t ushr 15)) * (t or 1)
        t = t xor (t + ((t xor (t ushr 7)) * (t or 61)))
        return ((t xor (t ushr 14)).toLong() and 0xFFFFFFFFL).toDouble() / 4294967296.0
    }
}

// ── Kontinenti, odbrane, misije (v3, docs/OSVAJANJE-VISE-IGRACA.md) ──

data class Kontinent(val id: String, val ime: String, val regioni: List<String>)

object Kontinenti {
    val svi = listOf(
        Kontinent("sam", "Severna Amerika", listOf("sam", "kar")),
        Kontinent("jam", "Južna Amerika", listOf("jam")),
        Kontinent("evr", "Evropa", listOf("sev", "zev", "jev", "iev")),
        Kontinent("afr", "Afrika", listOf("saf", "zaf", "caf", "iaf", "jaf")),
        Kontinent("azi", "Azija", listOf("bli", "caz", "iaz", "jia")),
        Kontinent("oke", "Okeanija", listOf("oke")),
    )
    fun od(oblastId: String): Kontinent { val r = Mapa.oblast(oblastId).region; return svi.first { r in it.regioni } }
    fun oblasti(id: String): List<String> {
        val k = svi.firstOrNull { it.id == id } ?: return emptyList()
        return Mapa.oblasti.filter { it.region in k.regioni }.map { it.id }
    }
}

/** Nazivi u JSON-u partije isti kao iOS rawValue (brzSat…), da telefoni dele stanje. */
@Serializable
enum class Odbrana(val naziv: String, val opis: String, val cena: Int) {
    @kotlinx.serialization.SerialName("brzSat") BRZ_SAT("Brz sat", "Napadač ima 8 sekundi umesto 15.", 0),
    @kotlinx.serialization.SerialName("bezPomoci") BEZ_POMOCI("Bez pomoći", "Napadač ne sme da koristi pomoć na ovom kontinentu.", 0),
    @kotlinx.serialization.SerialName("teskoPitanje") TESKO_PITANJE("Teško pitanje", "Napadač dobija samo teška pitanja.", 1),
    @kotlinx.serialization.SerialName("prednost") PREDNOST("Prednost", "Napadaču trebaju bar 2 tačna više od branioca da osvoji.", 2),
    @kotlinx.serialization.SerialName("temaBranioca") TEMA_BRANIOCA("Tema branioca", "Pitanja za napadača su iz teme koju je branilac izabrao.", 0),
    @kotlinx.serialization.SerialName("tvrdjava") TVRDJAVA("Tvrđava", "Prvi poraz branioca u krugu se ne računa.", 2),
    @kotlinx.serialization.SerialName("zamka") ZAMKA("Zamka", "Kad napadač pogreši, gubi 2 vojske umesto 1.", 1),
}

data class Misija(val id: String, val tekst: String, val samoPojedinacno: Boolean = false)

object Misije {
    val sve = listOf(
        Misija("evr-jam", "Osvoji Evropu i Južnu Ameriku."),
        Misija("evr-oke-jos", "Osvoji Evropu i Okeaniju, plus još jedan kontinent po izboru."),
        Misija("sam-jam", "Osvoji Severnu i Južnu Ameriku."),
        Misija("azi-jam", "Osvoji Aziju i Južnu Ameriku."),
        Misija("afr-oke", "Osvoji Afriku i Okeaniju."),
        Misija("sam-oke", "Osvoji Severnu Ameriku i Okeaniju."),
        Misija("drzava60", "Drži 60 država."),
        Misija("drzava45x2", "Drži 45 država sa najmanje 2 vojske u svakoj."),
        Misija("regiona8", "Drži 8 celih regiona (region je grupa država, npr. ceo Balkan)."),
        Misija("prestonice2", "Zauzmi prestonice dva rivala."),
        Misija("izbaci", "Izbaci određenog rivala iz igre.", samoPojedinacno = true),
        Misija("tacnih25", "Odgovori tačno na 25 pitanja i drži bar 30 država."),
    )
    fun tekst(id: String?) = sve.firstOrNull { it.id == id }?.tekst.orEmpty()
}

data class Uslov(val sekundi: Int, val bezPomoci: Boolean, val tesko: Boolean, val pitanja: Int, val temaBranioca: Boolean, val prednost: Int)

@Serializable
data class Stanje(
    val igraci: List<Igrac>,
    val oblasti: Map<String, StanjeOblasti>,
    val krug: Int,
    val ukupnoKrugova: Int,
    val naPotezu: Int,
    val faza: Faza,
    val zaRaspored: Int,
    val bitaka: Int,
    val niz: Int,
    val utvrdjeno: Boolean,
    val tacnostBota: Double,
    val misije: Map<String, String> = emptyMap(),
    val metaMisije: Map<String, String> = emptyMap(),
    val odbrane: Map<String, Odbrana> = emptyMap(),
    val promenaOdbrane: Map<String, Int> = emptyMap(),
    val tvrdjava: Map<String, Int> = emptyMap(),
    val tacnih: Map<String, Int> = emptyMap(),
    val pobednik: String? = null,
    val bonusPomoci: Map<String, Int> = emptyMap(),
    /** Potezi zaredom bez napada (isteklo vreme); na treći igrač ispada. Opciono, kao na iOS-u. */
    val propusteno: Map<String, Int>? = null,
) {
    val trenutni: Igrac get() = igraci[naPotezu]

    /** Tim igrača (vlasnik država); prima i id igrača i id tima. */
    fun timOd(id: String): String = igraci.firstOrNull { it.id == id }?.tim ?: id

    fun oblastiIgraca(id: String): List<String> { val tim = timOd(id); return Mapa.oblasti.filter { oblasti[it.id]?.vlasnik == tim }.map { it.id } }

    fun bonusRegiona(id: String): Int {
        val tim = timOd(id)
        return Mapa.regioni.filter { r -> Mapa.oblasti.filter { it.region == r.id }.all { oblasti[it.id]?.vlasnik == tim } }.sumOf { it.bonus }
    }

    fun pojacanja(id: String, tacno: Boolean): Int {
        val puno = max(Pravila.NAJMANJE_POJACANJA, oblastiIgraca(id).size / Pravila.TERITORIJA_PO_VOJSCI) + bonusRegiona(id)
        return if (tacno) puno else max(1, puno / 2)
    }

    fun snabdevanje(tacno: Boolean): Stanje {
        if (faza != Faza.SNABDEVANJE) return this
        val ja = trenutni
        val noviTacni = if (tacno) tacnih + (ja.tim to (tacnih[ja.tim] ?: 0) + 1) else tacnih
        var s = copy(tacnih = noviTacni)
        var vojske = s.pojacanja(ja.id, tacno)
        // Odbrane koštaju vojske jednom po krugu: plaća se na kapitenovom potezu.
        if (ja.kapiten) {
            val nove = s.odbrane.toMutableMap()
            for (k in nove.keys.sorted()) {
                if (!s.drziKontinent(ja.tim, k)) continue
                val cena = nove.getValue(k).cena
                if (cena <= vojske - 1) vojske -= cena else nove[k] = Odbrana.BRZ_SAT
            }
            s = s.copy(odbrane = nove)
        }
        return s.copy(faza = Faza.RASPORED, zaRaspored = vojske)
    }

    fun rasporedi(oblastId: String): Stanje {
        val o = oblasti[oblastId]
        if (faza != Faza.RASPORED || zaRaspored <= 0 || o?.vlasnik != trenutni.tim) return this
        val ostalo = zaRaspored - 1
        return copy(oblasti = oblasti + (oblastId to o.copy(vojske = o.vojske + 1)), zaRaspored = ostalo,
            faza = if (ostalo == 0) Faza.NAPAD else Faza.RASPORED)
    }

    /** Napada zaredom po potezu: 5 svako za sebe, 2 po igraču u timu. */
    val napadaPoPotezu: Int get() = if (igraci.map { it.tim }.toSet().size < igraci.size) Pravila.BITAKA_U_TIMU_PO_IGRACU else Pravila.BITAKA_PO_POTEZU

    fun mete(odakle: String): List<String> {
        val izvor = oblasti[odakle] ?: return emptyList()
        if (faza != Faza.NAPAD || bitaka >= napadaPoPotezu) return emptyList()
        if (izvor.vlasnik != trenutni.tim || izvor.vojske < 2) return emptyList()
        return Mapa.susedi(odakle).filter { it in oblasti && oblasti[it]?.vlasnik != izvor.vlasnik }
    }

    /** Bitka od jednog pitanja. [branilac] je null kad je oblast neutralna. */
    fun razresiBitku(odakle: String, kuda: String, napadac: Odgovor, branilac: Odgovor?): Pair<Stanje, Ishod> {
        require(kuda in mete(odakle)) { "Napad $odakle → $kuda nije dozvoljen" }
        val izvor = oblasti.getValue(odakle)
        val meta = oblasti.getValue(kuda)
        var gubitakNapadaca = 0
        var gubitakBranioca = 0
        if (meta.vlasnik == null || branilac == null) {
            if (napadac.tacan) gubitakBranioca = 1 else gubitakNapadaca = 1
        } else when {
            napadac.tacan && !branilac.tacan -> gubitakBranioca = 2
            !napadac.tacan && branilac.tacan -> gubitakNapadaca = 2
            // Nerešen odgovor rešava brzina; jednako vreme ide braniocu.
            napadac.tacan && branilac.tacan -> if (napadac.ms < branilac.ms) gubitakBranioca = 1 else gubitakNapadaca = 1
            else -> { gubitakNapadaca = 1; gubitakBranioca = 1 }
        }
        val odbrana = odbranaMete(kuda)
        val k = Kontinenti.od(kuda).id
        var tvrd = tvrdjava
        if (odbrana == Odbrana.ZAMKA && !napadac.tacan) gubitakNapadaca += 1
        if (odbrana == Odbrana.TVRDJAVA && gubitakBranioca > 0 && tvrdjava[k] != krug) { gubitakBranioca = 0; tvrd = tvrdjava + (k to krug) }

        val vojskeNapadaca = max(1, izvor.vojske - gubitakNapadaca)
        val vojskeBranioca = max(0, meta.vojske - gubitakBranioca)
        val nove = oblasti.toMutableMap()
        val osvojeno = vojskeBranioca == 0
        var niz = this.niz
        var proboj = false
        var plen = false
        if (osvojeno) {
            niz += 1
            proboj = niz % Pravila.PROBOJ_SVAKIH == 0
            plen = meta.vlasnik != null && igraci.any { it.prestonica == kuda && it.tim == meta.vlasnik }
            nove[odakle] = izvor.copy(vojske = 1)
            nove[kuda] = StanjeOblasti(izvor.vlasnik, max(1, vojskeNapadaca - 1) + (if (proboj) Pravila.PROBOJ_BONUS else 0) + (if (plen) Pravila.PLEN_PRESTONICE else 0))
        } else {
            nove[odakle] = izvor.copy(vojske = vojskeNapadaca)
            nove[kuda] = meta.copy(vojske = vojskeBranioca)
        }
        val t = tacnih.toMutableMap()
        if (napadac.tacan) t[trenutni.tim] = (t[trenutni.tim] ?: 0) + 1
        if (branilac?.tacan == true && meta.vlasnik != null) t[meta.vlasnik] = (t[meta.vlasnik] ?: 0) + 1
        val posle = copy(oblasti = nove, niz = niz, tvrdjava = tvrd, tacnih = t).posleBitke()
        return posle to Ishod(izvor.vojske - vojskeNapadaca, meta.vojske - vojskeBranioca, osvojeno, proboj, plen)
    }

    /** Bitka od 5 pitanja za državu koju drži igrač: više tačnih, pa brži; isto ide braniocu. */
    fun razresiBitkuSkorom(odakle: String, kuda: String, napadac: Skor, branilac: Skor): Pair<Stanje, Ishod> {
        require(kuda in mete(odakle)) { "Napad $odakle → $kuda nije dozvoljen" }
        val izvor = oblasti.getValue(odakle)
        val meta = oblasti.getValue(kuda)
        val braniTim = requireNotNull(meta.vlasnik) { "Bitka skorom je samo za državu koju drži igrač" }
        val napadaTim = izvor.vlasnik!!
        val odbrana = odbranaMete(kuda)
        val k = Kontinenti.od(kuda).id
        val potrebno = if (odbrana == Odbrana.PREDNOST) 2 else 1
        val razlika = napadac.tacnih - branilac.tacnih
        var pobedio = razlika >= potrebno || (potrebno == 1 && razlika == 0 && napadac.ms < branilac.ms)
        var tvrd = tvrdjava
        var gubitakBranioca = 0
        var tvrdjavaDrzi = false
        if (pobedio && odbrana == Odbrana.TVRDJAVA && tvrdjava[k] != krug) {
            // Prvi poraz u krugu: branilac zadržava državu, ali gubi jednu vojsku.
            pobedio = false
            tvrdjavaDrzi = true
            gubitakBranioca = min(1, meta.vojske - 1)
            tvrd = tvrdjava + (k to krug)
        }
        val nove = oblasti.toMutableMap()
        var niz = this.niz
        var proboj = false
        var plen = false
        var gubitakNapadaca = 0
        if (pobedio) {
            niz += 1
            proboj = niz % Pravila.PROBOJ_SVAKIH == 0
            plen = igraci.any { it.prestonica == kuda && it.tim == braniTim }
            gubitakBranioca = meta.vojske
            nove[odakle] = StanjeOblasti(napadaTim, 1)
            nove[kuda] = StanjeOblasti(napadaTim, max(1, izvor.vojske - 1) + (if (proboj) Pravila.PROBOJ_BONUS else 0) + (if (plen) Pravila.PLEN_PRESTONICE else 0))
        } else if (tvrdjavaDrzi) {
            // Tvrđava je izdržala: napadač ostaje u svojoj državi, branilac gubi vojsku.
            nove[kuda] = meta.copy(vojske = meta.vojske - gubitakBranioca)
        } else {
            // Izgubljena bitka protiv igrača: branilac uzima državu iz koje se napadalo, sa preživelim vojskama.
            val ostaje = max(1, izvor.vojske - Pravila.GUBITAK_PORAZENOG_NAPADACA - (if (odbrana == Odbrana.ZAMKA) 1 else 0))
            gubitakNapadaca = izvor.vojske
            nove[odakle] = StanjeOblasti(braniTim, ostaje)
        }
        val t = tacnih.toMutableMap()
        t[napadaTim] = (t[napadaTim] ?: 0) + napadac.tacnih
        t[braniTim] = (t[braniTim] ?: 0) + branilac.tacnih
        val pobTim = if (pobedio) napadaTim else braniTim
        val bonus = bonusPomoci + (pobTim to (bonusPomoci[pobTim] ?: 0) + Pravila.BONUS_POMOCI_POBEDNIKU)
        val posle = copy(oblasti = nove, niz = niz, tvrdjava = tvrd, tacnih = t, bonusPomoci = bonus).posleBitke()
        return posle to Ishod(gubitakNapadaca, gubitakBranioca, pobedio, proboj, plen, izgubljenaDrzava = !pobedio && !tvrdjavaDrzi)
    }

    private fun posleBitke(): Stanje {
        val noviIgraci = igraci.map { p -> if (!p.ispao && oblasti.values.none { it.vlasnik == p.tim }) p.copy(ispao = true) else p }
        val s = copy(igraci = noviIgraci, bitaka = bitaka + 1)
        val pob = s.pobednik ?: s.timSaIspunjenomMisijom
        return if (s.pobednik == null && pob != null) s.copy(pobednik = pob, faza = Faza.KRAJ) else s
    }

    /** Jednom po potezu: vojske između dve susedne svoje oblasti, u izvoru ostaje 1. */
    fun utvrdi(odakle: String, kuda: String, broj: Int): Stanje {
        val tim = trenutni.tim
        val a = oblasti[odakle]
        val b = oblasti[kuda]
        if (faza != Faza.NAPAD || utvrdjeno || a == null || b == null) return this
        if (a.vlasnik != tim || b.vlasnik != tim || kuda !in Mapa.susedi(odakle)) return this
        val n = min(broj, a.vojske - 1)
        if (n <= 0) return this
        return copy(utvrdjeno = true, oblasti = oblasti + (odakle to a.copy(vojske = a.vojske - n)) + (kuda to b.copy(vojske = b.vojske + n)))
    }

    /** Isteklo vreme na potezu: bez napada je propušten potez, treći zaredom izbacuje (države tima postaju neutralne sa pola vojske). */
    fun isteklo(id: String): Stanje {
        val p = (propusteno ?: emptyMap()) + (id to if (bitaka > 0) 0 else (propusteno?.get(id) ?: 0) + 1)
        var s = copy(propusteno = p)
        if ((p[id] ?: 0) >= Pravila.PROPUSTENIH_DO_ISPADANJA) {
            val tim = igraci.firstOrNull { it.id == id }?.tim
            val igraci2 = s.igraci.map { if (it.id == id) it.copy(ispao = true) else it }
            s = s.copy(igraci = igraci2)
            if (tim != null && igraci2.none { it.tim == tim && !it.ispao })
                s = s.copy(oblasti = s.oblasti.mapValues { (_, o) -> if (o.vlasnik == tim) StanjeOblasti(null, maxOf(1, o.vojske / 2)) else o })
        }
        return s.zavrsiPotez()
    }

    fun zavrsiPotez(): Stanje {
        if (faza == Faza.KRAJ) return this
        if (igraci.filter { !it.ispao }.map { it.tim }.toSet().size <= 1) return copy(faza = Faza.KRAJ)
        var sledeci = naPotezu
        var krug = this.krug
        do {
            sledeci = (sledeci + 1) % igraci.size
            if (sledeci == 0) krug += 1
        } while (igraci[sledeci].ispao)
        if (krug > ukupnoKrugova) return copy(faza = Faza.KRAJ)
        return copy(naPotezu = sledeci, krug = krug, faza = Faza.SNABDEVANJE, zaRaspored = 0, bitaka = 0, niz = 0, utvrdjeno = false)
    }

    fun poeni(id: String): Int {
        val tim = timOd(id)
        val moje = oblastiIgraca(id)
        val vojske = moje.sumOf { oblasti[it]?.vojske ?: 0 }
        val igrac = igraci.firstOrNull { it.id == id }
        val prestonica = if (igrac != null && oblasti[igrac.prestonica]?.vlasnik == tim) Pravila.POENI_PRESTONICA else 0
        return moje.size * Pravila.POENI_PO_OBLASTI + vojske + bonusRegiona(id) * Pravila.POENI_PO_BONUSU + prestonica
    }

    val poredak: List<Pair<Igrac, Int>> get() = igraci.map { it to poeni(it.id) }.sortedByDescending { it.second }

    // ── Kontinenti i odbrane ──

    fun drziKontinent(tim: String, kontinentId: String): Boolean {
        val l = Kontinenti.oblasti(kontinentId)
        return l.isNotEmpty() && l.all { oblasti[it]?.vlasnik == tim }
    }

    /** Odbrana koja štiti metu: važi samo dok vlasnik mete drži ceo njen kontinent. */
    fun odbranaMete(kuda: String): Odbrana? {
        val v = oblasti[kuda]?.vlasnik ?: return null
        val k = Kontinenti.od(kuda).id
        val o = odbrane[k] ?: return null
        return if (drziKontinent(v, k)) o else null
    }

    fun uslovBitke(kuda: String): Uslov {
        val o = odbranaMete(kuda)
        return Uslov(if (o == Odbrana.BRZ_SAT) Pravila.SEKUNDI_BRZ_SAT else Pravila.SEKUNDI_PO_PITANJU, o == Odbrana.BEZ_POMOCI,
            o == Odbrana.TESKO_PITANJE, if (oblasti[kuda]?.vlasnik != null) Pravila.PITANJA_U_BITCI else 1, o == Odbrana.TEMA_BRANIOCA, if (o == Odbrana.PREDNOST) 2 else 0)
    }

    /** Kapiten tima koji drži ceo kontinent bira odbranu; menja je najviše jednom po krugu. */
    fun postaviOdbranu(kontinentId: String, o: Odbrana): Stanje {
        val ja = trenutni
        if (!ja.kapiten || faza == Faza.KRAJ || !drziKontinent(ja.tim, kontinentId) || promenaOdbrane[kontinentId] == krug) return this
        return copy(odbrane = odbrane + (kontinentId to o), promenaOdbrane = promenaOdbrane + (kontinentId to krug))
    }

    /** Odbrana kontinenta: kad cilj ili jak rival dira kontinent „Prednost”, inače „Brz sat”. */
    fun botOdbrana(): Stanje {
        var s = this
        val tim = trenutni.tim
        val cilj = ciljBota(tim)
        for (k in Kontinenti.svi) if (s.odbrane[k.id] == null && s.drziKontinent(tim, k.id)) {
            val st = s
            val ugrozen = Kontinenti.oblasti(k.id).any { st.pretnja(it, tim, cilj) >= 4 }
            s = s.postaviOdbranu(k.id, if (ugrozen) Odbrana.PREDNOST else Odbrana.BRZ_SAT)
        }
        return s
    }

    fun iskoristiBonusPomoc(tim: String): Stanje? {
        val n = bonusPomoci[tim] ?: 0
        return if (n <= 0) null else copy(bonusPomoci = bonusPomoci + (tim to n - 1))
    }

    // ── Misije ──

    private fun udeo(tim: String, ids: List<String>): Double {
        val sve = ids.flatMap { Kontinenti.oblasti(it) }
        return sve.count { oblasti[it]?.vlasnik == tim }.toDouble() / sve.size
    }

    /** Napredak misije tima od 0 do 1 (1 = ispunjena). */
    fun napredakMisije(tim: String): Double {
        val drzave = Mapa.oblasti.filter { oblasti[it.id]?.vlasnik == tim }
        fun do1(x: Double) = min(1.0, x)
        return when (misije[tim]) {
            "evr-jam" -> udeo(tim, listOf("evr", "jam"))
            "evr-oke-jos" -> {
                val osnova = udeo(tim, listOf("evr", "oke"))
                val ostali = Kontinenti.svi.filter { it.id != "evr" && it.id != "oke" }.map { udeo(tim, listOf(it.id)) }
                if (osnova < 1) osnova * 0.75 else 0.75 + 0.25 * (ostali.maxOrNull() ?: 0.0)
            }
            "sam-jam" -> udeo(tim, listOf("sam", "jam"))
            "azi-jam" -> udeo(tim, listOf("azi", "jam"))
            "afr-oke" -> udeo(tim, listOf("afr", "oke"))
            "sam-oke" -> udeo(tim, listOf("sam", "oke"))
            "drzava60" -> do1(drzave.size / 60.0)
            "drzava45x2" -> do1(drzave.count { (oblasti[it.id]?.vojske ?: 0) >= 2 } / 45.0)
            "regiona8" -> do1(Mapa.regioni.count { r -> Mapa.oblasti.filter { it.region == r.id }.all { oblasti[it.id]?.vlasnik == tim } } / 8.0)
            "prestonice2" -> do1(igraci.count { it.tim != tim && oblasti[it.prestonica]?.vlasnik == tim } / 2.0)
            "izbaci" -> { val meta = metaMisije[tim]; if (igraci.filter { it.tim == meta }.all { it.ispao }) 1.0 else 0.0 }
            "tacnih25" -> do1((tacnih[tim] ?: 0) / 25.0) * 0.5 + do1(drzave.size / 30.0) * 0.5
            else -> 0.0
        }
    }

    val timSaIspunjenomMisijom: String? get() = misije.keys.sorted().firstOrNull { napredakMisije(it) >= 1.0 }

    // ── Botovi ──

    fun botOdgovor(slucajno: Slucajno): Odgovor = Odgovor(slucajno.sledeci() < tacnostBota, 3000 + (slucajno.sledeci() * 9000).toInt())

    fun botSkor(slucajno: Slucajno, pitanja: Int = Pravila.PITANJA_U_BITCI): Skor {
        var t = 0; var ms = 0
        repeat(pitanja) { val o = botOdgovor(slucajno); if (o.tacan) t++; ms += o.ms }
        return Skor(t, ms)
    }

    // ── Mozak bota (docs/OSVAJANJE-BOT.md), isto kao iOS ──
    // Koga cilja, gde stavlja vojsku, koju bitku bira (šansa × vrednost − rizik), pa prebacivanje vojske na granicu.
    // Narav menja pragove, težina koliko često bot uzme lošiji potez; pitanja i dalje odlučuje tacnostBota.

    enum class Narav { NAPADAC, GRADITELJ, OPREZAN }

    private fun jeCovek(i: Igrac) = i.covek || i.id.startsWith("u:")

    /** Snaga tima: države, vojske i celi regioni (bonus vojske svakog kruga). */
    fun snaga(tim: String): Double {
        val moje = oblasti.values.filter { it.vlasnik == tim }
        return moje.size + moje.sumOf { it.vojske } * 0.5 + bonusRegiona(tim) * 3.0
    }

    /** Koga bot cilja: sa jednim čovekom (ili jednim timom ljudi) svi botovi idu na njega; inače na najjačeg rivala. */
    fun ciljBota(tim: String): String? {
        val zivi = igraci.filter { !it.ispao && it.tim != tim }
        val ljudi = zivi.filter(::jeCovek).map { it.tim }.toSet()
        if (ljudi.size == 1 && igraci.none { jeCovek(it) && it.tim == tim }) return ljudi.first()
        return zivi.map { it.tim }.toSet().maxByOrNull { snaga(it) }
    }

    private fun pretnja(id: String, tim: String, cilj: String?): Double = Mapa.susedi(id).sumOf { n ->
        val o = oblasti[n]; val v = o?.vlasnik
        if (o == null || v == null || v == tim) 0.0 else o.vojske * (if (v == cilj) 1.5 else 1.0)
    }

    private fun fali(region: String, tim: String) = Mapa.oblasti.count { it.region == region && it.id in oblasti && oblasti[it.id]?.vlasnik != tim }

    private fun vrednost(kuda: String, tim: String, cilj: String?, narav: Narav): Double {
        val o = Mapa.oblast(kuda)
        val bonus = (Mapa.regioni.firstOrNull { it.id == o.region }?.bonus ?: 0).toDouble()
        val gradnja = if (narav == Narav.GRADITELJ) 1.4 else 1.0
        var v = 1.0
        val f = fali(o.region, tim)
        v += if (f == 1) bonus * 1.5 * gradnja else bonus * 0.3 * gradnja / maxOf(1, f)
        oblasti[kuda]?.vlasnik?.let { vlasnik ->
            if (fali(o.region, vlasnik) == 0) v += bonus * 1.2
            if (igraci.any { it.tim == vlasnik && it.prestonica == kuda }) v += 3
            if (vlasnik == cilj) v += 1.5
        }
        if (misije[tim]?.contains(Kontinenti.od(kuda).id) == true) v += 0.8
        return v
    }

    /** Ocena napada: šansa × dobitak − (1 − šansa) × gubitak; protiv igrača poraz odnosi i državu iz koje se napada. */
    fun ocenaNapada(odakle: String, kuda: String): Double {
        val tim = trenutni.tim
        val nar = narav(trenutni.id)
        val izvor = oblasti[odakle] ?: return Double.NEGATIVE_INFINITY
        val meta = oblasti[kuda] ?: return Double.NEGATIVE_INFINITY
        val dobitak = vrednost(kuda, tim, ciljBota(tim), nar)
        val p: Double
        var gubitak: Double
        val vlasnik = meta.vlasnik
        if (vlasnik != null) {
            val branilac = if (igraci.firstOrNull { it.tim == vlasnik }?.let(::jeCovek) == true) 0.65 else tacnostBota
            p = sansaBitke(tacnostBota, branilac, uslovBitke(kuda).pitanja, odbranaMete(kuda) == Odbrana.PREDNOST)
            gubitak = 1 + maxOf(0, izvor.vojske - Pravila.GUBITAK_PORAZENOG_NAPADACA) * 0.4
            if (igraci.any { it.tim == tim && it.prestonica == odakle }) gubitak += 4
            val reg = Mapa.oblast(odakle).region
            if (fali(reg, tim) == 0) gubitak += (Mapa.regioni.firstOrNull { it.id == reg }?.bonus ?: 0)
        } else {
            p = tacnostBota
            gubitak = 0.5
        }
        if (nar == Narav.OPREZAN) gubitak *= 1.3
        return p * dobitak - (1 - p) * gubitak
    }

    private fun pragNapada(n: Narav) = when (n) { Narav.NAPADAC -> 0.1; Narav.GRADITELJ -> 0.25; Narav.OPREZAN -> 0.5 }

    /** Koliko često bot uzme lošiji potez (lako 35%, normalno 12%, teško nikad). */
    private val greskaBota get() = if (tacnostBota < 0.55) 0.35 else if (tacnostBota < 0.7) 0.12 else 0.0

    fun botRasporedi(): Stanje {
        var s = this
        val tim = trenutni.tim
        val cilj = ciljBota(tim)
        while (s.faza == Faza.RASPORED) {
            val moje = s.oblastiIgraca(s.trenutni.id)
            val prva = moje.firstOrNull() ?: break
            val st = s
            // Vojska ide gde je najveća pretnja ili odakle se zatvara region; prestonica se čuva.
            fun ocena(id: String): Double {
                var v = st.pretnja(id, tim, cilj) - (st.oblasti[id]?.vojske ?: 0) * 0.6
                if (Mapa.susedi(id).any { n -> n in st.oblasti && st.oblasti[n]?.vlasnik != tim && st.fali(Mapa.oblast(n).region, tim) == 1 }) v += 3
                if (st.igraci.any { it.tim == tim && it.prestonica == id }) v += 1.5
                return v
            }
            val granica = moje.filter { st.pretnja(it, tim, cilj) > 0 }
            s = s.rasporedi((granica.ifEmpty { moje }).maxByOrNull(::ocena) ?: prva)
        }
        return s
    }

    fun botSledeciNapad(): Pair<String, String>? {
        val opcije = oblastiIgraca(trenutni.id).flatMap { o -> mete(o).map { Triple(o, it, ocenaNapada(o, it)) } }
        if (opcije.isEmpty()) return null
        // Šum je vezan za krug i bitku, da isti potez ne ispadne drugačije na dva telefona.
        val r = Slucajno(krug * 7919 + naPotezu * 131 + bitaka * 17 + 1)
        if (r.sledeci() < greskaBota) {
            val losije = opcije.filter { it.third > -1 }
            if (losije.isNotEmpty()) { val o = losije[(r.sledeci() * losije.size).toInt()]; return o.first to o.second }
        }
        val najbolja = opcije.maxBy { it.third }
        return if (najbolja.third >= pragNapada(narav(trenutni.id))) najbolja.first to najbolja.second else null
    }

    /** Pred kraj poteza: vojska iz unutrašnjosti (bez tuđih suseda) ide na najugroženiju susednu granicu. */
    fun botUtvrdi(): Stanje {
        val tim = trenutni.tim
        val cilj = ciljBota(tim)
        var najbolje: Triple<String, String, Double>? = null
        for (id in oblastiIgraca(trenutni.id)) {
            if ((oblasti[id]?.vojske ?: 0) <= 1 || pretnja(id, tim, cilj) > 0) continue
            for (n in Mapa.susedi(id)) {
                if (oblasti[n]?.vlasnik != tim) continue
                val p = pretnja(n, tim, cilj)
                if (p > 0 && (najbolje == null || p > najbolje.third)) najbolje = Triple(id, n, p)
            }
        }
        val (odakle, kuda, _) = najbolje ?: return this
        return utvrdi(odakle, kuda, (oblasti[odakle]?.vojske ?: 1) - 1)
    }

    companion object {
        /** Stalna narav po id-ju (ista na svakom telefonu i kao na iOS-u). */
        fun narav(id: String) = when (id.sumOf { it.code } % 3) { 0 -> Narav.NAPADAC; 1 -> Narav.GRADITELJ; else -> Narav.OPREZAN }

        /** Šansa napadača (tačnost a) protiv branioca (b) u bitki od n pitanja; kod jednakog broja pola-pola; prednost traži 2 više. */
        fun sansaBitke(a: Double, b: Double, n: Int, prednost: Boolean): Double {
            fun bin(p: Double) = (0..n).map { k -> var c = 1.0; for (i in 0 until k) c = c * (n - i) / (i + 1); c * Math.pow(p, k.toDouble()) * Math.pow(1 - p, (n - k).toDouble()) }
            val pa = bin(a); val pb = bin(b)
            var w = 0.0
            for (i in 0..n) for (j in 0..n) {
                val r = i - j
                if (prednost) { if (r >= 2) w += pa[i] * pb[j] } else if (r > 0) w += pa[i] * pb[j] else if (r == 0) w += pa[i] * pb[j] * 0.5
            }
            return w
        }

        val podrazumevani = listOf(
            NoviIgrac("ti", "Ti", 0xFF12907E, true), NoviIgrac("mimi", "Mimi", 0xFFFF5FA2, false), NoviIgrac("zig", "Zig", 0xFF6D4BC9, false),
        )

        /** Nova partija: prestonica na izabranom kontinentu (ili u regionu koji niko nema), šest država oko nje, ostalo neutralno. */
        /** [teren] = id kontinenta: igra se samo na njemu (1 na 1 ili protiv računara), države van njega ne postoje. */
        fun nova(krugova: Int, tezina: Tezina, slucajno: Slucajno, ime: String? = null, igraci: List<NoviIgrac>? = null,
                 pocetak: Map<String, String> = emptyMap(), misije: Boolean = false, teren: String? = null): Stanje {
            val regioni = Mapa.regioni.toMutableList()
            for (i in regioni.size - 1 downTo 1) {
                val j = (slucajno.sledeci() * (i + 1)).toInt()
                val t = regioni[i]; regioni[i] = regioni[j]; regioni[j] = t
            }
            val naTerenu = teren?.let { Kontinenti.oblasti(it).toSet() }
            val oblasti = Mapa.oblasti.filter { naTerenu?.contains(it.id) ?: true }.associate { it.id to StanjeOblasti(null, Pravila.NEUTRALNE_VOJSKE) }.toMutableMap()
            val lista = mutableListOf<Igrac>()
            for (p in igraci ?: podrazumevani) {
                val tim = p.tim ?: p.id
                fun slobodna(o: Oblast) = Mapa.susedi(o.id).count { it in oblasti } >= 3 && o.id in oblasti && oblasti[o.id]?.vlasnik == null
                var kandidati = (teren ?: pocetak[tim])?.let { k -> Mapa.oblasti.filter { Kontinenti.od(it.id).id == k && slobodna(it) } }
                    ?: regioni.firstOrNull { r -> lista.none { Mapa.oblast(it.prestonica).region == r.id } && Mapa.oblasti.any { it.region == r.id && slobodna(it) } }
                        ?.let { r -> Mapa.oblasti.filter { it.region == r.id && slobodna(it) } }.orEmpty()
                if (kandidati.isEmpty()) kandidati = Mapa.oblasti.filter { it.id in oblasti && oblasti[it.id]?.vlasnik == null }
                val prestonica = kandidati[(slucajno.sledeci() * kandidati.size).toInt()].id
                lista += Igrac(p.id, if (p.covek && igraci == null) ime ?: p.ime else p.ime, p.boja, p.covek, prestonica, false, tim, p.kapiten)
                // Početni posed: prestonica i najbliže slobodne države po vezama (pretraga u širinu).
                val posed = mutableListOf(prestonica)
                val red = ArrayDeque(listOf(prestonica))
                val vidjeno = mutableSetOf(prestonica)
                while (red.isNotEmpty() && posed.size < Pravila.POCETNIH_DRZAVA) {
                    for (n in Mapa.susedi(red.removeFirst())) {
                        if (!vidjeno.add(n)) continue
                        red.add(n)
                        if (n in oblasti && oblasti[n]?.vlasnik == null && posed.size < Pravila.POCETNIH_DRZAVA) posed += n
                    }
                }
                for (o in posed) oblasti[o] = StanjeOblasti(tim, if (o == prestonica) Pravila.POCETNE_VOJSKE_PRESTONICE else Pravila.POCETNE_VOJSKE_DRZAVE)
            }
            val s = Stanje(lista, oblasti, 1, krugova, 0, Faza.SNABDEVANJE, 0, 0, 0, false, tezina.tacnost)
            return if (misije) s.dodeliMisije(slucajno) else s
        }

        fun redosledIzbora(timovi: List<String>, krugova: Int = 1): List<String> = (0 until krugova).flatMap { if (it % 2 == 0) timovi else timovi.reversed() }
    }

    private fun dodeliMisije(slucajno: Slucajno): Stanje {
        val timovi = igraci.map { it.tim }.distinct()
        val pojedinacno = timovi.size == igraci.size
        val ponuda = Misije.sve.filter { pojedinacno || !it.samoPojedinacno }.map { it.id }.toMutableList()
        for (i in ponuda.size - 1 downTo 1) {
            val j = (slucajno.sledeci() * (i + 1)).toInt()
            val t = ponuda[i]; ponuda[i] = ponuda[j]; ponuda[j] = t
        }
        val m = mutableMapOf<String, String>()
        val meta = mutableMapOf<String, String>()
        timovi.forEachIndexed { i, tim ->
            val id = ponuda[i % ponuda.size]
            m[tim] = id
            if (id == "izbaci") { val drugi = timovi.filter { it != tim }; meta[tim] = drugi[(slucajno.sledeci() * drugi.size).toInt()] }
        }
        return copy(misije = m, metaMisije = meta)
    }
}
