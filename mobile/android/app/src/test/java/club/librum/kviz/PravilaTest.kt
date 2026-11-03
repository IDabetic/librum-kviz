package club.librum.kviz

import club.librum.kviz.osvajanje.Faza
import club.librum.kviz.osvajanje.Ishod
import club.librum.kviz.osvajanje.Mapa
import club.librum.kviz.osvajanje.Pravila
import club.librum.kviz.osvajanje.Odgovor
import club.librum.kviz.osvajanje.Slucajno
import club.librum.kviz.osvajanje.Stanje
import club.librum.kviz.osvajanje.StanjeOblasti
import club.librum.kviz.osvajanje.Tezina
import club.librum.kviz.prokviz.ProKviz
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Isti slučajevi kao tests/osvajanje.test.mjs i PravilaTests.swift. */
class PravilaTest {
    init { Mapa.ucitaj(java.io.File("../../../src/lib/osvajanje/svet.json").readText()) }

    private fun nova(seme: Int = 1) = Stanje.nova(12, Tezina.NORMALNO, Slucajno(seme))

    /** Stanje u fazi napada sa zadatim vlasnicima, ostalo neutralno sa 1 vojskom. */
    private fun napad(vararg vlasnici: Triple<String, String, Int>): Stanje {
        val s = nova()
        val oblasti = Mapa.oblasti.associate { it.id to StanjeOblasti(null, 1) }.toMutableMap()
        for ((id, v, n) in vlasnici) oblasti[id] = StanjeOblasti(v, n)
        return s.copy(faza = Faza.NAPAD, oblasti = oblasti)
    }

    @Test fun mapaDrzavaPovezanaISimetricna() {
        assertEquals(171, Mapa.oblasti.size)
        for (o in Mapa.oblasti) for (n in Mapa.susedi(o.id)) assertTrue(o.id in Mapa.susedi(n))
        val vidjeno = mutableSetOf("SRB")
        val red = ArrayDeque(listOf("SRB"))
        while (red.isNotEmpty()) for (n in Mapa.susedi(red.removeLast())) if (vidjeno.add(n)) red.add(n)
        assertEquals(171, vidjeno.size)
    }

    @Test fun istiGeneratorKaoVeb() {
        val s = Slucajno(1)
        assertEquals(0.6270739405881613, s.sledeci(), 1e-12)
        assertEquals(0.002735721180215478, s.sledeci(), 1e-12)
        assertEquals(0.5274470399599522, s.sledeci(), 1e-12)
    }

    @Test fun pocetakTriRegionaPoSestDrzava() {
        for (seme in 1..5) {
            val s = nova(seme)
            assertEquals(3, s.igraci.map { Mapa.oblast(it.prestonica).region }.toSet().size)
            for (p in s.igraci) assertEquals(Pravila.POCETNIH_DRZAVA, s.oblastiIgraca(p.id).size)
        }
    }

    @Test fun istiPocetakKaoVeb() {
        assertEquals(listOf("PNG", "ALB", "CHE"), nova(1).igraci.map { it.prestonica })
    }

    @Test fun snabdevanjeIRaspored() {
        val s = nova()
        assertEquals(3, s.snabdevanje(true).zaRaspored)
        val r = s.snabdevanje(false)
        assertEquals(1, r.zaRaspored)
        assertEquals(Faza.NAPAD, r.rasporedi(s.igraci[0].prestonica).faza)
    }

    @Test fun osvajanjeNeutralne() {
        val (novo, ishod) = napad(Triple("SRB", "ti", 5)).razresiBitku("SRB", "BGR", Odgovor(true, 1), null)
        assertTrue(ishod.osvojeno)
        assertEquals(4, novo.oblasti["BGR"]?.vojske)
        assertTrue("TUR" in novo.mete("BGR"))
    }

    @Test fun bitkaProtivIgraca() {
        val s = napad(Triple("SRB", "ti", 5), Triple("BGR", "mimi", 4))
        assertEquals(3, s.razresiBitku("SRB", "BGR", Odgovor(true, 2000), Odgovor(true, 5000)).first.oblasti["BGR"]?.vojske)
        val oba = s.razresiBitku("SRB", "BGR", Odgovor(false, 1), Odgovor(false, 1)).first
        assertEquals(4, oba.oblasti["SRB"]?.vojske)
        assertEquals(3, oba.oblasti["BGR"]?.vojske)
    }

    @Test fun probojIBonusRegiona() {
        var s = napad(Triple("SRB", "ti", 12))
        var tren = "SRB"
        var poslednji: Ishod? = null
        for (meta in listOf("BGR", "TUR", "GRC")) {
            val (novo, ishod) = s.razresiBitku(tren, meta, Odgovor(true, 1), null)
            s = novo; tren = meta; poslednji = ishod
        }
        assertEquals(true, poslednji?.proboj)
        val zev = napad(*Mapa.oblasti.filter { it.region == "zev" }.map { Triple(it.id, "ti", 1) }.toTypedArray())
        // Pojačanja = max(3, države / 2) + bonus kontinenta.
        val drzava = Mapa.oblasti.count { it.region == "zev" }
        assertEquals(maxOf(3, drzava / 2) + Mapa.regioni.first { it.id == "zev" }.bonus, zev.pojacanja("ti", true))
    }

    @Test fun celaPartijaBotova() {
        val rnd = Slucajno(42)
        var s = Stanje.nova(10, Tezina.TESKO, rnd)
        var koraka = 0
        while (s.faza != Faza.KRAJ && koraka++ < 5000) {
            s = s.snabdevanje(rnd.sledeci() < 0.6).botRasporedi()
            while (true) {
                val (odakle, kuda) = s.botSledeciNapad() ?: break
                val b = if (s.oblasti[kuda]?.vlasnik != null) s.botOdgovor(rnd) else null
                s = s.razresiBitku(odakle, kuda, s.botOdgovor(rnd), b).first
            }
            s = s.zavrsiPotez()
        }
        assertEquals(Faza.KRAJ, s.faza)
    }

    @Test fun proKvizBodovanjeKaoVeb() {
        val p = ProKviz()
        repeat(5) { p.odgovor(true) }
        assertEquals(60, p.poeni)
        p.odgovor(false)
        assertEquals(55, p.poeni)
        assertEquals(9, p.zivoti)
        p.aktivirajRisk()
        p.odgovor(false)
        assertEquals(7, p.zivoti)
        assertEquals(45, p.poeni)
        assertFalse(p.riskDostupan)
    }
}

/** Pravila ostalih igara, isti brojevi kao na vebu i iOS-u. */
class IgreTest {
    @Test fun vesanjeSlovaIBonus() {
        val v = club.librum.kviz.igre.Vesanje("kiša")
        listOf("K", "I", "Š").forEach { v.pogodi(it) }
        assertEquals(15, v.poeni)
        v.pogodi("A")
        assertEquals(club.librum.kviz.igre.Vesanje.Status.POBEDA, v.status)
        assertEquals(20 + club.librum.kviz.igre.Vesanje.BONUS_BEZ_GRESKE, v.poeni)
    }

    @Test fun vesanjePromasajICelaRec() {
        val v = club.librum.kviz.igre.Vesanje("berlinski zid")
        v.pogodi("X"); assertEquals(5, v.zivoti)
        v.pogodiRec("pogrešno"); assertEquals(3, v.zivoti)
        v.pogodiRec("Berlinski zid")
        assertEquals(club.librum.kviz.igre.Vesanje.BONUS_REC + club.librum.kviz.igre.Vesanje.BONUS_MALO_GRESAKA, v.poeni)
    }

    @Test fun brziKviz() {
        val p = club.librum.kviz.servisi.Pitanje("x", "?", listOf("a", "b", "c", "d"), 2)
        val iz = club.librum.kviz.igre.BrziKviz.Izjava.od(p) { 0.1 }
        assertTrue(iz.jeTacno)
        val b = club.librum.kviz.igre.BrziKviz()
        assertTrue(b.odgovor(iz, true)); assertFalse(b.odgovor(iz, null))
        assertEquals(5, b.poeni)
    }

    @Test fun duelMesanjeKaoVeb() {
        assertEquals(listOf(2, 1, 0, 3), club.librum.kviz.igre.DuelMesanje.red("31628f47-f1e2-4f92-8be0-791c3cf231e3"))
        assertEquals(listOf(3, 1, 2, 0), club.librum.kviz.igre.DuelMesanje.red("abc"))
    }
}
