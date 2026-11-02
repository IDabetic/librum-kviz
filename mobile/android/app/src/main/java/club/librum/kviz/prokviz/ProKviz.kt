package club.librum.kviz.prokviz

import kotlin.math.max
import kotlin.math.roundToInt

/** Pravila PRO kviza, ista kao src/app/pro-kviz/start/page.tsx i ProKviz.swift. */
class ProKviz {
    companion object {
        const val SEKUNDI = 15
        const val POCETNI_ZIVOTI = 10
        const val POENA_TACNO = 10
        const val POENA_NETACNO = 5
        const val RISK_BONUS = 10
        const val RISK_ZIVOTI = 2
        const val RISK_POENA = 10
        const val SVAKIH_ZA_NAGRADU = 50
        const val ZIVOTA_NAGRADA = 5
        val KOMBO_BONUSI = mapOf(
            5 to (10 to "Lep niz!"), 10 to (25 to "Odličan ritam!"), 20 to (60 to "Ozbiljno znanje!"),
            50 to (150 to "Librum mašina!"), 100 to (400 to "Živa enciklopedija!"),
        )
    }

    var zivoti = POCETNI_ZIVOTI; private set
    var poeni = 0; private set
    var stigao = 0; private set
    var tacnih = 0; private set
    var netacnih = 0; private set
    var preskoceno = 0; private set
    var kombo = 0; private set
    var najboljiKombo = 0; private set
    var polaPola = 1; private set
    var preskoci = 1; private set
    var dodatnoVreme = 1; private set
    private val iskorisceno = mutableMapOf("fiftyFifty" to 0, "skip" to 0, "extraTime" to 0)
    var riskAktivan = false; private set
    private var poslednjiRisk = 0
    private var riskPokusaja = 0
    private var riskTacnih = 0
    private var riskNetacnih = 0

    val gotovo get() = zivoti <= 0

    /** Risk jednom po bloku od 10 pitanja. */
    val riskDostupan get() = !riskAktivan && (poslednjiRisk == 0 || stigao / 10 > (poslednjiRisk - 1) / 10)

    /** Primenjuje odgovor; vraća poruku za prikaz (kombo ili nagrada), ako je ima. */
    fun odgovor(tacan: Boolean, nagrada: () -> Int = { (0..2).random() }): String? {
        stigao += 1
        var poruka: String? = null
        if (tacan) {
            poeni += if (riskAktivan) POENA_TACNO + RISK_BONUS else POENA_TACNO
            kombo += 1
            najboljiKombo = max(najboljiKombo, kombo)
            tacnih += 1
            if (riskAktivan) riskTacnih += 1
            KOMBO_BONUSI[kombo]?.let { (bonus, tekst) -> poeni += bonus; poruka = "$tekst +$bonus" }
            if (stigao % SVAKIH_ZA_NAGRADU == 0) {
                zivoti += ZIVOTA_NAGRADA
                when (nagrada()) { 0 -> polaPola += 1; 1 -> preskoci += 1; else -> dodatnoVreme += 1 }
                poruka = "Preživeo/la si $stigao pitanja! +$ZIVOTA_NAGRADA života + bonus pomoć"
            }
        } else {
            zivoti -= if (riskAktivan) RISK_ZIVOTI else 1
            poeni = max(0, poeni - if (riskAktivan) RISK_POENA else POENA_NETACNO)
            netacnih += 1
            kombo = 0
            if (riskAktivan) riskNetacnih += 1
        }
        riskAktivan = false
        return poruka
    }

    fun aktivirajRisk() {
        if (!riskDostupan) return
        riskAktivan = true
        poslednjiRisk = stigao + 1
        riskPokusaja += 1
    }

    fun iskoristiPolaPola(): Boolean {
        if (polaPola <= 0) return false
        polaPola -= 1; iskorisceno["fiftyFifty"] = iskorisceno.getValue("fiftyFifty") + 1
        return true
    }

    fun iskoristiPreskok(): Boolean {
        if (preskoci <= 0) return false
        preskoci -= 1; iskorisceno["skip"] = iskorisceno.getValue("skip") + 1; preskoceno += 1; stigao += 1; riskAktivan = false
        return true
    }

    fun iskoristiVreme(): Boolean {
        if (dodatnoVreme <= 0) return false
        dodatnoVreme -= 1; iskorisceno["extraTime"] = iskorisceno.getValue("extraTime") + 1
        return true
    }

    /** Red za tabelu survivor_sessions (iste kolone kao veb). */
    fun red(korisnik: String, sekundi: Int): Map<String, Any> {
        val odgovoreno = tacnih + netacnih
        val tacnost = if (odgovoreno > 0) (tacnih.toDouble() / odgovoreno * 10000).roundToInt() / 100.0 else 0.0
        return mapOf(
            "user_id" to korisnik, "score" to poeni, "questions_reached" to stigao, "correct_answers" to tacnih,
            "wrong_answers" to netacnih, "skipped_questions" to preskoceno, "accuracy" to tacnost, "best_combo" to najboljiKombo,
            "total_time_seconds" to sekundi, "used_lifelines" to iskorisceno.toMap(),
            "risk_attempts" to riskPokusaja, "risk_correct" to riskTacnih, "risk_wrong" to riskNetacnih,
        )
    }
}
