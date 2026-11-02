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
    const val NEUTRALNE_VOJSKE = 1
    const val NAJMANJE_POJACANJA = 3
    const val TERITORIJA_PO_VOJSCI = 3
    const val BITAKA_PO_POTEZU = 8
    const val PROBOJ_SVAKIH = 3
    const val PROBOJ_BONUS = 2
    const val PLEN_PRESTONICE = 5
    const val POENI_PO_OBLASTI = 10
    const val POENI_PO_BONUSU = 10
    const val POENI_PRESTONICA = 20
    const val SEKUNDI_PO_PITANJU = 15
}

enum class Tezina(val tacnost: Double, val ime: String, val opis: String) {
    LAKO(0.5, "Lako", "Rivali greše svako drugo pitanje"),
    NORMALNO(0.62, "Normalno", "Rivali znaju oko 6 od 10"),
    TESKO(0.75, "Teško", "Rivali znaju 3 od 4"),
}

data class Igrac(
    val id: String,
    val ime: String,
    val boja: Long,
    val covek: Boolean,
    val prestonica: String,
    val ispao: Boolean,
)

data class StanjeOblasti(val vlasnik: String?, val vojske: Int)

enum class Faza { SNABDEVANJE, RASPORED, NAPAD, KRAJ }

data class Odgovor(val tacan: Boolean, val ms: Int)

data class Ishod(
    val gubitakNapadaca: Int,
    val gubitakBranioca: Int,
    val osvojeno: Boolean,
    val proboj: Boolean,
    val plen: Boolean,
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
) {
    val trenutni: Igrac get() = igraci[naPotezu]

    fun oblastiIgraca(id: String): List<String> = Mapa.oblasti.filter { oblasti[it.id]?.vlasnik == id }.map { it.id }

    fun bonusRegiona(id: String): Int = Mapa.regioni
        .filter { r -> Mapa.oblasti.filter { it.region == r.id }.all { oblasti[it.id]?.vlasnik == id } }
        .sumOf { it.bonus }

    fun pojacanja(id: String, tacno: Boolean): Int {
        val puno = max(Pravila.NAJMANJE_POJACANJA, oblastiIgraca(id).size / Pravila.TERITORIJA_PO_VOJSCI) + bonusRegiona(id)
        return if (tacno) puno else max(1, puno / 2)
    }

    fun snabdevanje(tacno: Boolean): Stanje {
        if (faza != Faza.SNABDEVANJE) return this
        return copy(faza = Faza.RASPORED, zaRaspored = pojacanja(trenutni.id, tacno))
    }

    fun rasporedi(oblastId: String): Stanje {
        val o = oblasti[oblastId]
        if (faza != Faza.RASPORED || zaRaspored <= 0 || o?.vlasnik != trenutni.id) return this
        val ostalo = zaRaspored - 1
        return copy(
            oblasti = oblasti + (oblastId to o.copy(vojske = o.vojske + 1)),
            zaRaspored = ostalo,
            faza = if (ostalo == 0) Faza.NAPAD else Faza.RASPORED,
        )
    }

    fun mete(odakle: String): List<String> {
        val izvor = oblasti[odakle] ?: return emptyList()
        if (faza != Faza.NAPAD || bitaka >= Pravila.BITAKA_PO_POTEZU) return emptyList()
        if (izvor.vlasnik != trenutni.id || izvor.vojske < 2) return emptyList()
        return Mapa.susedi(odakle).filter { oblasti[it]?.vlasnik != izvor.vlasnik }
    }

    /** Razrešava bitku. [branilac] je null kad je oblast neutralna. */
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

        val vojskeNapadaca = max(1, izvor.vojske - gubitakNapadaca)
        val vojskeBranioca = max(0, meta.vojske - gubitakBranioca)
        val nove = oblasti.toMutableMap()
        val osvojeno = vojskeBranioca == 0
        var niz = this.niz
        var proboj = false
        var plen = false

        if (osvojeno) {
            val prelazi = vojskeNapadaca - 1
            niz += 1
            proboj = niz % Pravila.PROBOJ_SVAKIH == 0
            plen = meta.vlasnik != null && igraci.any { it.prestonica == kuda && it.id == meta.vlasnik }
            nove[odakle] = izvor.copy(vojske = 1)
            nove[kuda] = StanjeOblasti(
                izvor.vlasnik,
                max(1, prelazi) + (if (proboj) Pravila.PROBOJ_BONUS else 0) + (if (plen) Pravila.PLEN_PRESTONICE else 0),
            )
        } else {
            nove[odakle] = izvor.copy(vojske = vojskeNapadaca)
            nove[kuda] = meta.copy(vojske = vojskeBranioca)
        }

        val noviIgraci = igraci.map { p ->
            if (!p.ispao && Mapa.oblasti.none { nove[it.id]?.vlasnik == p.id }) p.copy(ispao = true) else p
        }
        val ishod = Ishod(izvor.vojske - vojskeNapadaca, meta.vojske - vojskeBranioca, osvojeno, proboj, plen)
        return copy(oblasti = nove, igraci = noviIgraci, bitaka = bitaka + 1, niz = niz) to ishod
    }

    /** Jednom po potezu: vojske između dve susedne svoje oblasti, u izvoru ostaje 1. */
    fun utvrdi(odakle: String, kuda: String, broj: Int): Stanje {
        val id = trenutni.id
        val a = oblasti[odakle]
        val b = oblasti[kuda]
        if (faza != Faza.NAPAD || utvrdjeno || a == null || b == null) return this
        if (a.vlasnik != id || b.vlasnik != id || kuda !in Mapa.susedi(odakle)) return this
        val n = min(broj, a.vojske - 1)
        if (n <= 0) return this
        return copy(
            utvrdjeno = true,
            oblasti = oblasti + (odakle to a.copy(vojske = a.vojske - n)) + (kuda to b.copy(vojske = b.vojske + n)),
        )
    }

    fun zavrsiPotez(): Stanje {
        if (faza == Faza.KRAJ) return this
        if (igraci.count { !it.ispao } <= 1) return copy(faza = Faza.KRAJ)
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
        val moje = oblastiIgraca(id)
        val vojske = moje.sumOf { oblasti[it]?.vojske ?: 0 }
        val igrac = igraci.firstOrNull { it.id == id }
        val prestonica = if (igrac != null && oblasti[igrac.prestonica]?.vlasnik == id) Pravila.POENI_PRESTONICA else 0
        return moje.size * Pravila.POENI_PO_OBLASTI + vojske + bonusRegiona(id) * Pravila.POENI_PO_BONUSU + prestonica
    }

    val poredak: List<Pair<Igrac, Int>> get() = igraci.map { it to poeni(it.id) }.sortedByDescending { it.second }

    // ── Botovi ──

    fun botOdgovor(slucajno: Slucajno): Odgovor =
        Odgovor(slucajno.sledeci() < tacnostBota, 3000 + (slucajno.sledeci() * 9000).toInt())

    fun botRasporedi(): Stanje {
        var s = this
        while (s.faza == Faza.RASPORED) {
            val id = s.trenutni.id
            val moje = s.oblastiIgraca(id)
            fun pretnja(o: String) = Mapa.susedi(o).count { s.oblasti[it]?.vlasnik != id }
            val cilj = moje.fold(moje[0]) { najbolja, o -> if (pretnja(o) > pretnja(najbolja)) o else najbolja }
            s = s.rasporedi(cilj)
        }
        return s
    }

    fun botSledeciNapad(): Pair<String, String>? {
        val id = trenutni.id
        var najbolji: Triple<String, String, Int>? = null
        for (odakle in oblastiIgraca(id)) {
            for (kuda in mete(odakle)) {
                val prednost = oblasti.getValue(odakle).vojske - oblasti.getValue(kuda).vojske
                if (prednost < 1) continue
                val reg = Mapa.oblast(kuda).region
                val fali = Mapa.oblasti.count { it.region == reg && oblasti[it.id]?.vlasnik != id }
                val ocena = prednost * 2 + (if (oblasti.getValue(kuda).vlasnik == null) 3 else 0) + (if (fali == 1) 5 else 0)
                if (najbolji == null || ocena > najbolji.third) najbolji = Triple(odakle, kuda, ocena)
            }
        }
        return najbolji?.let { it.first to it.second }
    }

    companion object {
        /** Nova partija: prestonice u različitim regionima, po šest država oko njih, ostalo neutralno. */
        fun nova(krugova: Int, tezina: Tezina, slucajno: Slucajno, ime: String? = null): Stanje {
            val regioni = Mapa.regioni.toMutableList()
            for (i in regioni.size - 1 downTo 1) {
                val j = (slucajno.sledeci() * (i + 1)).toInt()
                val t = regioni[i]; regioni[i] = regioni[j]; regioni[j] = t
            }
            val oblasti = Mapa.oblasti.associate { it.id to StanjeOblasti(null, Pravila.NEUTRALNE_VOJSKE) }.toMutableMap()
            val osnova = listOf(
                Triple("ti", "Ti", 0xFF12907E), Triple("mimi", "Mimi", 0xFFFF5FA2), Triple("zig", "Zig", 0xFF6D4BC9),
            )
            val igraci = mutableListOf<Igrac>()
            for ((i, p) in osnova.withIndex()) {
                val (id, podrazumevano, boja) = p
                // Prestonica je država sa bar 3 suseda, u regionu koji niko drugi nema.
                fun kandidati(r: Region) = Mapa.oblasti.filter { it.region == r.id && Mapa.susedi(it.id).size >= 3 && oblasti[it.id]?.vlasnik == null }
                val region = regioni.first { r -> igraci.none { Mapa.oblast(it.prestonica).region == r.id } && kandidati(r).isNotEmpty() }
                val lista = kandidati(region)
                val prestonica = lista[(slucajno.sledeci() * lista.size).toInt()].id
                val covek = i == 0
                igraci += Igrac(id, if (covek) ime ?: podrazumevano else podrazumevano, boja, covek, prestonica, false)
                // Početni posed: prestonica i najbliže slobodne države po vezama (pretraga u širinu).
                val posed = mutableListOf(prestonica)
                val red = ArrayDeque(listOf(prestonica))
                val vidjeno = mutableSetOf(prestonica)
                while (red.isNotEmpty() && posed.size < Pravila.POCETNIH_DRZAVA) {
                    for (n in Mapa.susedi(red.removeFirst())) {
                        if (!vidjeno.add(n)) continue
                        red.add(n)
                        if (oblasti[n]?.vlasnik == null && posed.size < Pravila.POCETNIH_DRZAVA) posed += n
                    }
                }
                for (o in posed) oblasti[o] = StanjeOblasti(id, if (o == prestonica) Pravila.POCETNE_VOJSKE_PRESTONICE else Pravila.POCETNE_VOJSKE_DRZAVE)
            }
            return Stanje(igraci, oblasti, 1, krugova, 0, Faza.SNABDEVANJE, 0, 0, 0, false, tezina.tacnost)
        }
    }
}
