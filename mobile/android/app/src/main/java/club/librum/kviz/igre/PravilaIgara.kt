package club.librum.kviz.igre

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import club.librum.kviz.servisi.Pitanje
import club.librum.kviz.servisi.Prikaz
import java.util.Locale
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

// Pravila Brzog kviza, Vešanja i mešanje ponuda u duelu, ista kao na vebu i iOS-u
// (PravilaIgara.swift, DuelModel.swift). Polja su Compose stanje, da ekran sam prati promene.

/** Brzi kviz: 60 sekundi, prikazan odgovor je tačan ili netačan, +10 / −5. */
class BrziKviz {
    companion object {
        const val SEKUNDI_RUNDE = 60
        const val SEKUNDI_PO_IZJAVI = 10
        const val POENA_TACNO = 10
        const val POENA_NETACNO = 5
    }

    data class Izjava(val pitanje: String, val prikazano: String, val jeTacno: Boolean, val tacanOdgovor: String) {
        companion object {
            /** Polovina izjava nudi tačan odgovor, ostale nasumičan netačan. */
            fun od(p: Pitanje, nasumicno: () -> Double = { Math.random() }): Izjava {
                val tacan = p.options[p.correct_answer]
                val netacni = p.options.filterIndexed { i, _ -> i != p.correct_answer }
                val prikazano = if (nasumicno() < 0.5 || netacni.isEmpty()) tacan
                    else netacni[min(netacni.size - 1, (nasumicno() * netacni.size).toInt())]
                return Izjava(p.question_text, prikazano, prikazano == tacan, tacan)
            }
        }
    }

    var poeni by mutableIntStateOf(0); private set
    var tacnih by mutableIntStateOf(0); private set
    var netacnih by mutableIntStateOf(0); private set

    /** `stit`: pomoć Štit, promašaj se ne računa (ni poeni ni broj netačnih). */
    fun odgovor(izjava: Izjava, kaze: Boolean?, stit: Boolean = false): Boolean {
        val pogodio = kaze == izjava.jeTacno
        if (pogodio) { poeni += POENA_TACNO; tacnih++ } else if (!stit) { poeni = max(0, poeni - POENA_NETACNO); netacnih++ }
        return pogodio
    }

    fun red(korisnik: String, sekundi: Int): Map<String, Any> {
        val ukupno = tacnih + netacnih
        return mapOf(
            "user_id" to korisnik, "score" to poeni, "correct_count" to tacnih, "wrong_count" to netacnih, "total_answered" to ukupno,
            "accuracy" to if (ukupno > 0) (tacnih.toDouble() / ukupno * 10000).roundToInt() / 100.0 else 0.0,
            "duration_seconds" to sekundi.coerceIn(1, SEKUNDI_RUNDE),
        )
    }
}

/** Vešanje: 6 života, slovo +5 po pojavljivanju, promašaj −2 i život, cela reč +20 i bonusi, pogrešna cela reč −2 života. */
class Vesanje(val rec: String) {
    companion object {
        val AZBUKA = listOf("A","B","C","Č","Ć","D","Đ","E","F","G","H","I","J","K","L","M","N","O","P","R","S","Š","T","U","V","Z","Ž")
        const val POCETNI_ZIVOTI = 6
        const val POENA_SLOVO = 5
        const val POENA_PROMASAJ = 2
        const val BONUS_REC = 20
        const val BONUS_BEZ_GRESKE = 30
        const val BONUS_MALO_GRESAKA = 15
        private val SR = Locale.forLanguageTag("sr-Latn")
        private fun norm(s: String) = s.lowercase(SR)
    }

    enum class Status { IGRA, POBEDA, PORAZ }

    private var pogodjena by mutableStateOf(setOf<String>())
    private var promasena by mutableStateOf(setOf<String>())
    private var ugasena by mutableStateOf(setOf<String>())
    var zivoti by mutableIntStateOf(POCETNI_ZIVOTI); private set
    var poeni by mutableIntStateOf(0); private set
    var status by mutableStateOf(Status.IGRA); private set

    val prikaz: List<String> get() = rec.map { c -> if (!c.isLetter()) c.toString() else if (norm(c.toString()) in pogodjena) c.toString().uppercase(SR) else "_" }
    private val sveOtkriveno get() = rec.all { !it.isLetter() || norm(it.toString()) in pogodjena }
    private val bonusZaGreske get() = if (promasena.isEmpty()) BONUS_BEZ_GRESKE else if (promasena.size <= 2) BONUS_MALO_GRESAKA else 0

    fun iskorisceno(slovo: String) = norm(slovo) in pogodjena || norm(slovo) in promasena || norm(slovo) in ugasena

    fun ugaseno(slovo: String) = norm(slovo) in ugasena

    /** Pomoć 50/50: gasi polovinu slova kojih nema u reči. */
    fun skloniPolovinuSlova() {
        if (status != Status.IGRA) return
        val slovaReci = rec.map { norm(it.toString()) }.toSet()
        val suvisna = AZBUKA.map(::norm).filter { it !in slovaReci && !iskorisceno(it) }
        ugasena = ugasena + suvisna.shuffled().take(suvisna.size / 2)
    }

    /** Pomoć: jedan izgubljen život se vraća. */
    fun dodajZivot() { if (status == Status.IGRA && zivoti < POCETNI_ZIVOTI) zivoti++ }

    /** Pomoć: otkriva jedno skriveno slovo bez poena i bez trošenja života. */
    fun otkrijSlovo() {
        if (status != Status.IGRA) return
        val c = rec.firstOrNull { it.isLetter() && norm(it.toString()) !in pogodjena } ?: return
        pogodjena = pogodjena + norm(c.toString())
        if (sveOtkriveno) { poeni += bonusZaGreske; status = Status.POBEDA }
    }

    fun pogodi(slovo: String) {
        val n = norm(slovo)
        if (status != Status.IGRA || iskorisceno(slovo)) return
        val pojavljivanja = rec.count { norm(it.toString()) == n }
        if (pojavljivanja > 0) {
            pogodjena += n
            poeni += pojavljivanja * POENA_SLOVO
            if (sveOtkriveno) { poeni += bonusZaGreske; status = Status.POBEDA }
        } else {
            promasena += n
            zivoti--
            poeni = max(0, poeni - POENA_PROMASAJ)
            if (zivoti <= 0) status = Status.PORAZ
        }
    }

    fun pogodiRec(pokusaj: String) {
        if (status != Status.IGRA) return
        if (norm(pokusaj.trim()) == norm(rec)) {
            pogodjena = pogodjena + rec.filter { it.isLetter() }.map { norm(it.toString()) }
            poeni += BONUS_REC + bonusZaGreske
            status = Status.POBEDA
        } else {
            zivoti -= 2
            if (zivoti <= 0) { zivoti = 0; status = Status.PORAZ }
        }
    }

    fun red(korisnik: String, recId: String, hint: String?, kategorija: String?, sekundi: Int): Map<String, Any?> = buildMap {
        put("user_id", korisnik); put("word", rec); put("word_length", rec.count { it.isLetter() }); put("won", status == Status.POBEDA)
        put("wrong_guesses", promasena.size); put("letters_used", pogodjena.size + promasena.size); put("time_seconds", sekundi); put("score", poeni)
        if (!recId.startsWith("r")) put("word_id", recId)
        hint?.let { put("hint", it) }; kategorija?.let { put("category", it) }
    }
}

/** Isto mešanje ponuda kao seededShuffle na vebu: JS proizvod je double, pa ToInt32, pa maska. */
object DuelMesanje {
    fun red(id: String): List<Int> {
        var s = id.sumOf { it.code }.toDouble()
        fun rand(): Double {
            val d = s * 1103515245.0 + 12345.0
            var m = d % 4294967296.0
            if (m < 0) m += 4294967296.0
            s = (m.toLong() and 0x7fffffffL).toDouble()
            return s / 0x7fffffff.toDouble()
        }
        val indeksi = mutableListOf(0, 1, 2, 3)
        for (i in 3 downTo 1) {
            val j = floor(rand() * (i + 1)).toInt()
            val t = indeksi[i]; indeksi[i] = indeksi[j]; indeksi[j] = t
        }
        return indeksi
    }

    fun prikaz(p: Pitanje): Prikaz {
        val r = red(p.id)
        return Prikaz(p.question_text, r.map { p.options[it] }, r.indexOf(p.correct_answer))
    }
}
