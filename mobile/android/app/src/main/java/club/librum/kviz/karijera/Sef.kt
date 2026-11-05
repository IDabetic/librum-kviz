package club.librum.kviz.karijera

/**
 * Šef Karijere (prenos iOS Sef.swift + SefBanke.swift, 05.11.2026): komentari po jačini, smeh, ometanja i izgled.
 * Tekstovi su u SefTekstovi.kt (isti kao iOS). Bez psovki i ličnih uvreda; jako kritikuje posao, ne čoveka.
 */
object Sef {
    enum class Povod { TACNO, NETACNO, ISTEKLO }
    enum class Vrsta { UPAD, ZADATAK, HAOS }

    /** Upad sam nestaje za 1,5 s; zadatak čeka „Odmah, šefe”; haos trese ili zamagli karticu. */
    data class Ometanje(val vrsta: Vrsta, val tekst: String, val trese: Boolean = false)

    /** Jačine 0 isključen, 1 blag, 2 srednji, 3 jak. Korporacija i NPC: srednji, ometanja ponekad. */
    data class Nivo(val tacno: Int = 2, val netacno: Int = 2, val ometanja: Int = 2, val smeh: Boolean = true, val lik: String = "korporacija") {
        /** Mirni režim igrača: najviše blag, bez ometanja i smeha. */
        fun mirno(da: Boolean) = if (da) Nivo(minOf(tacno, 1), minOf(netacno, 1), 0, false, lik) else this
        fun jacina(p: Povod) = if (p == Povod.TACNO) tacno else netacno
    }

    data class Lik(val id: String, val naziv: String, val zensko: Boolean)
    val likovi = listOf(
        Lik("korporacija", "Šef Korporacije", false), Lik("m_mladi", "Mladi šef", false), Lik("m_srednji", "Šef u najboljim godinama", false),
        Lik("m_stari", "Stari šef", false), Lik("z_mlada", "Mlada šefica", true), Lik("z_srednja", "Šefica u najboljim godinama", true),
        Lik("z_starija", "Iskusna šefica", true),
    )
    fun lik(id: String) = likovi.firstOrNull { it.id == id } ?: likovi[0]

    private val iskorisceno = mutableMapOf<String, MutableSet<Int>>()

    /** Primer: `oblik("{bio|bila} si, [rekao|rekla] sam", zensko = true, sefZensko = false)` → „bila si, rekao sam” */
    fun oblik(tekst: String, zensko: Boolean, sefZensko: Boolean = false): String {
        var r = tekst
        for ((otvori, zatvori, z) in listOf(Triple('{', '}', zensko), Triple('[', ']', sefZensko))) {
            while (true) {
                val o = r.indexOf(otvori); if (o < 0) break
                val k = r.indexOf(zatvori, o + 1); if (k < 0) break
                val delovi = r.substring(o + 1, k).split('|')
                r = r.substring(0, o) + delovi[if (z && delovi.size > 1) 1 else 0] + r.substring(k + 1)
            }
        }
        return r
    }

    /** Banka za povod i jačinu; isteklo vreme na blagom i jakom koristi banku netačnih te jačine. */
    fun banka(p: Povod, jacina: Int): Pair<String, List<String>> = when {
        p == Povod.TACNO && jacina <= 1 -> "tb" to SefTekstovi.blagoTacno
        p == Povod.TACNO && jacina >= 3 -> "tj" to SefTekstovi.jakoTacno
        p == Povod.TACNO -> "ts" to SefTekstovi.tacno
        jacina <= 1 -> "nb" to SefTekstovi.blagoNetacno
        jacina >= 3 -> "nj" to SefTekstovi.jakoNetacno
        p == Povod.ISTEKLO -> "is" to SefTekstovi.isteklo
        else -> "ns" to SefTekstovi.netacno
    }

    /** Rečenica bez ponavljanja dok se banka ne potroši; smeh (ako je uključen) zameni rečenicu u 1 od 4. */
    fun recenica(p: Povod, jacina: Int = 2, smeh: Boolean = false, zensko: Boolean, sefZensko: Boolean = false): String {
        val (kljuc, banka) = if (smeh && (0..3).random() == 0) {
            if (p == Povod.TACNO) "st" to SefTekstovi.smehTacno else "sn" to SefTekstovi.smehNetacno
        } else banka(p, jacina)
        val bilo = iskorisceno.getOrPut(kljuc) { mutableSetOf() }
        if (bilo.size >= banka.size) bilo.clear()
        val i = banka.indices.filter { it !in bilo }.randomOrNull() ?: 0
        bilo += i
        return oblik(banka[i], zensko, sefZensko)
    }

    fun jeSmeh(tekst: String) = tekst in SefTekstovi.smehTacno || tekst in SefTekstovi.smehNetacno

    /** Slika iz res/drawable-nodpi: karijera_sef_<lik>_<zadovoljan|ljut|nervozan|smeh>. */
    fun slika(p: Povod, lik: String = "korporacija", smeh: Boolean = false): String {
        val r = if (smeh) "smeh" else when (p) { Povod.TACNO -> "zadovoljan"; Povod.NETACNO -> "ljut"; Povod.ISTEKLO -> "nervozan" }
        return "karijera_sef_${lik}_$r"
    }

    fun slika(o: Ometanje, lik: String): String = if (lik != "korporacija") "karijera_sef_${lik}_nervozan" else when (o.vrsta) {
        Vrsta.ZADATAK -> "karijera_sef_korporacija_kafa"; Vrsta.HAOS -> "karijera_sef_korporacija_sok"; Vrsta.UPAD -> "karijera_sef_korporacija_nervozan"
    }

    /** Pitanja runde (0…9) sa ometanjem: nisko 1, srednje 2–3, visoko 4–5; nikad dva zaredom. */
    fun rasporedOmetanja(nivo: Int, pitanja: Int = 10): Set<Int> {
        val koliko = when { nivo <= 0 -> 0; nivo == 1 -> 1; nivo == 2 -> (2..3).random(); else -> (4..5).random() }
        val izbor = mutableSetOf<Int>()
        for (k in (0 until pitanja).shuffled()) if (izbor.size < koliko && (k - 1) !in izbor && (k + 1) !in izbor) izbor += k
        return izbor
    }

    /** Jedno veliko ometanje (zadatak/haos) najviše u rundi: „često” uvek, „ponekad” u pola rundi, „retko” nikad. */
    fun velikoPitanje(nivo: Int, raspored: Set<Int>): Int? = when (nivo) {
        3 -> raspored.randomOrNull()
        2 -> if ((0..1).random() == 0) raspored.randomOrNull() else null
        else -> null
    }

    fun ometanje(nivo: Int, veliko: Boolean): Ometanje {
        val vrsta = if (!veliko || nivo < 2) Vrsta.UPAD else if (nivo >= 3 && (0..2).random() == 0) Vrsta.HAOS else Vrsta.ZADATAK
        return SefTekstovi.ometanja.filter { it.vrsta == vrsta }.random()
    }
}

/** 18 pomoći (prenos iOS Pomoci.swift): svaka jednom po rundi; odgovor sa pomoći vredi manje i ne donosi ugled. */
data class KarijeraPomoc(val id: String, val naziv: String, val opis: String, val efekti: List<Efekat>) {
    sealed interface Efekat {
        data class Ukloni(val n: Int, val kasnjenje: Double = 0.0) : Efekat
        data class Vreme(val s: Int) : Efekat
        data object SatStoji : Efekat
        data object Otkrij : Efekat
        data class Savet(val p: Double, val kasnjenje: Double = 0.0) : Efekat
        data class Anketa(val p: Double) : Efekat
        data object PrvoSlovo : Efekat
    }
}

object Pomoci {
    private fun p(id: String, naziv: String, opis: String, vararg e: KarijeraPomoc.Efekat) = KarijeraPomoc(id, naziv, opis, e.toList())
    val sve = listOf(
        p("pola_stola", "Pola stola", "Sklanja dva netačna odgovora.", KarijeraPomoc.Efekat.Ukloni(2)),
        p("crvena_olovka", "Crvena olovka", "Precrta jedan netačan odgovor.", KarijeraPomoc.Efekat.Ukloni(1)),
        p("insajder", "Insajder", "Pokaže tačan odgovor, ali odgovor vredi manje.", KarijeraPomoc.Efekat.Otkrij),
        p("mentor", "Mentor", "Mentor predloži odgovor; u pravu je tri od četiri puta.", KarijeraPomoc.Efekat.Savet(0.75)),
        p("prvo_slovo", "Prvo slovo", "Otkrije prvo slovo tačnog odgovora.", KarijeraPomoc.Efekat.PrvoSlovo),
        p("produzen_rok", "Produžen rok", "+10 sekundi za ovo pitanje.", KarijeraPomoc.Efekat.Vreme(10)),
        p("pauza_kafa", "Pauza za kafu", "Sat stoji dok ne odgovoriš.", KarijeraPomoc.Efekat.SatStoji),
        p("prekovremeno", "Prekovremeno", "+20 sekundi za ovo pitanje.", KarijeraPomoc.Efekat.Vreme(20)),
        p("ekspres", "Ekspres", "Skloni jedan netačan i doda 5 sekundi.", KarijeraPomoc.Efekat.Ukloni(1), KarijeraPomoc.Efekat.Vreme(5)),
        p("hodnik", "Hodnik priča", "Anketa kolega: kako bi oni odgovorili.", KarijeraPomoc.Efekat.Anketa(0.7)),
        p("caskanje", "Ćaskanje na kafi", "Kolega šapne odgovor; u pravu je u 60% slučajeva.", KarijeraPomoc.Efekat.Savet(0.6)),
        p("mreza", "Mreža kontakata", "Posle 8 sekundi stigne odgovor; tačan u 90% slučajeva.", KarijeraPomoc.Efekat.Savet(0.9, 8.0)),
        p("ceo_tim", "Ceo tim", "Anketa celog tima, pouzdanija od hodnika.", KarijeraPomoc.Efekat.Anketa(0.85)),
        p("zamrznut_sat", "Zaključan sat", "Sat stoji i jedan netačan nestaje.", KarijeraPomoc.Efekat.SatStoji, KarijeraPomoc.Efekat.Ukloni(1)),
        p("sigurna_odluka", "Sigurna odluka", "Posle 5 sekundi nestanu dva netačna.", KarijeraPomoc.Efekat.Ukloni(2, 5.0)),
        p("brainstorming", "Brainstorming", "Prvo slovo tačnog i jedan netačan manje.", KarijeraPomoc.Efekat.PrvoSlovo, KarijeraPomoc.Efekat.Ukloni(1)),
        p("dvostruka_provera", "Dvostruka provera", "Jedan netačan manje i predlog sa 70% tačnosti.", KarijeraPomoc.Efekat.Ukloni(1), KarijeraPomoc.Efekat.Savet(0.7)),
        p("sabotaza", "Sabotaža konkurencije", "Dva netačna manje i 5 sekundi više.", KarijeraPomoc.Efekat.Ukloni(2), KarijeraPomoc.Efekat.Vreme(5)),
    )
    fun po(id: String) = sve.firstOrNull { it.id == id }
}
