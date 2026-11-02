package club.librum.kviz

import club.librum.kviz.osvajanje.Faza
import club.librum.kviz.osvajanje.Ishod
import club.librum.kviz.osvajanje.Mapa
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
    private fun nova(seme: Int = 1) = Stanje.nova(10, Tezina.NORMALNO, Slucajno(seme))

    @Test fun mapaPovezanaISimetricna() {
        assertEquals(24, Mapa.oblasti.size)
        for (o in Mapa.oblasti) for (n in Mapa.susedi(o.id)) assertTrue(o.id in Mapa.susedi(n))
        val vidjeno = mutableSetOf("aljaska")
        val red = ArrayDeque(listOf("aljaska"))
        while (red.isNotEmpty()) for (n in Mapa.susedi(red.removeLast())) if (vidjeno.add(n)) red.add(n)
        assertEquals(24, vidjeno.size)
    }

    @Test fun istiGeneratorKaoVeb() {
        val s = Slucajno(1)
        assertEquals(0.6270739405881613, s.sledeci(), 1e-12)
        assertEquals(0.002735721180215478, s.sledeci(), 1e-12)
        assertEquals(0.5274470399599522, s.sledeci(), 1e-12)
    }

    @Test fun prestoniceNaRazlicitimKontinentima() {
        assertEquals(3, nova(3).igraci.map { Mapa.oblast(it.prestonica).kontinent }.toSet().size)
    }

    @Test fun snabdevanjeIRaspored() {
        val s = nova()
        assertEquals(3, s.snabdevanje(true).zaRaspored)
        val r = s.snabdevanje(false)
        assertEquals(1, r.zaRaspored)
        assertEquals(Faza.NAPAD, r.rasporedi(s.igraci[0].prestonica).faza)
    }

    @Test fun osvajanjeIProboj() {
        var s = nova().snabdevanje(true)
        val dom = s.igraci[0].prestonica
        while (s.faza == Faza.RASPORED) s = s.rasporedi(dom)
        val meta = s.mete(dom)[0]
        val (novo, ishod) = s.razresiBitku(dom, meta, Odgovor(true, 1), null)
        assertTrue(ishod.osvojeno)
        assertEquals("ti", novo.oblasti[meta]?.vlasnik)
        assertEquals(1, novo.oblasti[dom]?.vojske)
        assertEquals(6, novo.oblasti[meta]?.vojske)
        assertTrue(novo.mete(meta).isNotEmpty())
    }

    @Test fun bitkaProtivIgraca() {
        val s = nova().snabdevanje(true).copy(faza = Faza.NAPAD).let {
            it.copy(oblasti = it.oblasti + ("balkan" to StanjeOblasti("ti", 5)) + ("bliski-istok" to StanjeOblasti("mimi", 4)))
        }
        assertEquals(3, s.razresiBitku("balkan", "bliski-istok", Odgovor(true, 2000), Odgovor(true, 5000)).first.oblasti["bliski-istok"]?.vojske)
        val oba = s.razresiBitku("balkan", "bliski-istok", Odgovor(false, 1), Odgovor(false, 1)).first
        assertEquals(4, oba.oblasti["balkan"]?.vojske)
        assertEquals(3, oba.oblasti["bliski-istok"]?.vojske)
        assertEquals(3, s.razresiBitku("balkan", "bliski-istok", Odgovor(false, 1), Odgovor(true, 1)).first.oblasti["balkan"]?.vojske)
    }

    @Test fun treceOsvajanjeDonosiProboj() {
        var s = nova().copy(faza = Faza.NAPAD).let { it.copy(oblasti = it.oblasti + ("peru" to StanjeOblasti("ti", 10))) }
        var tren = "peru"
        var poslednji: Ishod? = null
        repeat(3) {
            val meta = s.mete(tren).first { s.oblasti[it]?.vlasnik == null }
            val (novo, ishod) = s.razresiBitku(tren, meta, Odgovor(true, 1), null)
            s = novo; tren = meta; poslednji = ishod
        }
        assertEquals(true, poslednji?.proboj)
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
