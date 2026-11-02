package club.librum.kviz.osvajanje

import kotlin.math.max
import kotlin.math.min

// Verni prevod src/lib/osvajanje/pravila.ts (i Pravila.swift). Kad se pravila
// menjaju, menjaju se na sva tri mesta, zajedno sa testovima.

data class Kontinent(val id: String, val ime: String, val bonus: Int)
data class Oblast(val id: String, val ime: String, val kontinent: String, val x: Float, val y: Float)

object Mapa {
    val kontinenti = listOf(
        Kontinent("sam", "Severna Amerika", 3),
        Kontinent("jam", "Južna Amerika", 2),
        Kontinent("evr", "Evropa", 3),
        Kontinent("afr", "Afrika", 3),
        Kontinent("azi", "Azija", 4),
        Kontinent("oke", "Okeanija", 2),
    )

    val oblasti = listOf(
        Oblast("aljaska", "Aljaska", "sam", 80f, 90f),
        Oblast("kanada", "Kanada", "sam", 190f, 80f),
        Oblast("sad", "SAD", "sam", 200f, 190f),
        Oblast("meksiko", "Meksiko", "sam", 180f, 295f),
        Oblast("kolumbija", "Kolumbija", "jam", 270f, 360f),
        Oblast("peru", "Peru", "jam", 250f, 465f),
        Oblast("brazil", "Brazil", "jam", 360f, 430f),
        Oblast("argentina", "Argentina", "jam", 330f, 530f),
        Oblast("skandinavija", "Skandinavija", "evr", 480f, 70f),
        Oblast("zap-evropa", "Zapadna Evropa", "evr", 430f, 175f),
        Oblast("sre-evropa", "Srednja Evropa", "evr", 535f, 165f),
        Oblast("balkan", "Balkan", "evr", 575f, 260f),
        Oblast("sev-afrika", "Severna Afrika", "afr", 475f, 310f),
        Oblast("zap-afrika", "Zapadna Afrika", "afr", 440f, 415f),
        Oblast("ist-afrika", "Istočna Afrika", "afr", 570f, 400f),
        Oblast("juz-afrika", "Južna Afrika", "afr", 520f, 505f),
        Oblast("sibir", "Sibir", "azi", 720f, 85f),
        Oblast("bliski-istok", "Bliski istok", "azi", 670f, 285f),
        Oblast("indija", "Indija", "azi", 770f, 335f),
        Oblast("kina", "Kina", "azi", 810f, 210f),
        Oblast("japan", "Japan", "azi", 925f, 150f),
        Oblast("indonezija", "Indonezija", "oke", 870f, 400f),
        Oblast("australija", "Australija", "oke", 920f, 505f),
        Oblast("novi-zeland", "Novi Zeland", "oke", 1000f, 430f),
    )

    val veze = listOf(
        "aljaska" to "kanada", "aljaska" to "sibir", "aljaska" to "sad", "kanada" to "sad", "kanada" to "skandinavija",
        "sad" to "meksiko", "meksiko" to "kolumbija",
        "kolumbija" to "peru", "kolumbija" to "brazil", "peru" to "brazil", "peru" to "argentina", "brazil" to "argentina",
        "brazil" to "zap-afrika",
        "skandinavija" to "zap-evropa", "skandinavija" to "sre-evropa", "skandinavija" to "sibir",
        "zap-evropa" to "sre-evropa", "zap-evropa" to "sev-afrika", "sre-evropa" to "balkan", "sre-evropa" to "sibir",
        "balkan" to "bliski-istok", "balkan" to "sev-afrika",
        "sev-afrika" to "zap-afrika", "sev-afrika" to "ist-afrika", "sev-afrika" to "bliski-istok",
        "zap-afrika" to "ist-afrika", "zap-afrika" to "juz-afrika", "ist-afrika" to "juz-afrika", "ist-afrika" to "bliski-istok",
        "bliski-istok" to "indija", "bliski-istok" to "sibir", "sibir" to "kina", "sibir" to "japan",
        "kina" to "indija", "kina" to "japan", "kina" to "indonezija", "indija" to "indonezija",
        "indonezija" to "australija", "australija" to "novi-zeland", "indonezija" to "novi-zeland",
    )

    private val susedstvo: Map<String, List<String>> = buildMap<String, MutableList<String>> {
        for ((a, b) in veze) {
            getOrPut(a) { mutableListOf() }.add(b)
            getOrPut(b) { mutableListOf() }.add(a)
        }
    }

    fun susedi(id: String): List<String> = susedstvo[id].orEmpty()
    fun oblast(id: String): Oblast = oblasti.first { it.id == id }
}

object Pravila {
    const val POCETNE_VOJSKE_PRESTONICE = 4
    const val NEUTRALNE_VOJSKE = 1
    const val NAJMANJE_POJACANJA = 3
    const val BITAKA_PO_POTEZU = 6
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

    fun bonusKontinenata(id: String): Int = Mapa.kontinenti
        .filter { k -> Mapa.oblasti.filter { it.kontinent == k.id }.all { oblasti[it.id]?.vlasnik == id } }
        .sumOf { it.bonus }

    fun pojacanja(id: String, tacno: Boolean): Int {
        val puno = max(Pravila.NAJMANJE_POJACANJA, oblastiIgraca(id).size / 2) + bonusKontinenata(id)
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
        return moje.size * Pravila.POENI_PO_OBLASTI + vojske + bonusKontinenata(id) * Pravila.POENI_PO_BONUSU + prestonica
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
                val kont = Mapa.oblast(kuda).kontinent
                val fali = Mapa.oblasti.count { it.kontinent == kont && oblasti[it.id]?.vlasnik != id }
                val ocena = prednost * 2 + (if (oblasti.getValue(kuda).vlasnik == null) 3 else 0) + (if (fali == 1) 5 else 0)
                if (najbolji == null || ocena > najbolji.third) najbolji = Triple(odakle, kuda, ocena)
            }
        }
        return najbolji?.let { it.first to it.second }
    }

    companion object {
        /** Nova partija: prestonice na različitim kontinentima, ostalo neutralno. */
        fun nova(krugova: Int, tezina: Tezina, slucajno: Slucajno, ime: String? = null): Stanje {
            val kontinenti = Mapa.kontinenti.toMutableList()
            for (i in kontinenti.size - 1 downTo 1) {
                val j = (slucajno.sledeci() * (i + 1)).toInt()
                val t = kontinenti[i]; kontinenti[i] = kontinenti[j]; kontinenti[j] = t
            }
            val osnova = listOf(
                Triple("ti", "Ti", 0xFF12907E), Triple("mimi", "Mimi", 0xFFFF5FA2), Triple("zig", "Zig", 0xFF6D4BC9),
            )
            val igraci = osnova.mapIndexed { i, (id, podrazumevano, boja) ->
                val kandidati = Mapa.oblasti.filter { it.kontinent == kontinenti[i].id }
                val prestonica = kandidati[(slucajno.sledeci() * kandidati.size).toInt()].id
                val covek = i == 0
                Igrac(id, if (covek) ime ?: podrazumevano else podrazumevano, boja, covek, prestonica, false)
            }
            val oblasti = Mapa.oblasti.associate { it.id to StanjeOblasti(null, Pravila.NEUTRALNE_VOJSKE) }.toMutableMap()
            for (p in igraci) oblasti[p.prestonica] = StanjeOblasti(p.id, Pravila.POCETNE_VOJSKE_PRESTONICE)
            return Stanje(igraci, oblasti, 1, krugova, 0, Faza.SNABDEVANJE, 0, 0, 0, false, tezina.tacnost)
        }
    }
}
