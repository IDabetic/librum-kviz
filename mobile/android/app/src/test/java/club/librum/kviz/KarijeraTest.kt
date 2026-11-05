package club.librum.kviz

import club.librum.kviz.karijera.Karijera
import club.librum.kviz.karijera.Pomoci
import club.librum.kviz.karijera.Sef
import club.librum.kviz.karijera.SefTekstovi
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Isto kao iOS KarijeraTests: banke, rod, ometanja i mešavina moraju biti iste na obe platforme. */
class KarijeraTest {
    @Test fun bankeIRod() {
        assertEquals(110, SefTekstovi.tacno.size); assertEquals(120, SefTekstovi.netacno.size); assertEquals(50, SefTekstovi.isteklo.size)
        listOf(SefTekstovi.blagoTacno, SefTekstovi.blagoNetacno, SefTekstovi.jakoTacno).forEach { assertEquals(40, it.size) }
        assertEquals(60, SefTekstovi.jakoNetacno.size)
        assertEquals(40, SefTekstovi.smehTacno.size + SefTekstovi.smehNetacno.size)
        assertEquals(60, SefTekstovi.ometanja.size)
        assertEquals(18, Pomoci.sve.size)
        repeat(300) {
            for (p in Sef.Povod.entries) for (j in 1..3) for (z in listOf(true, false)) {
                val r = Sef.recenica(p, j, true, z, !z)
                assertFalse(r, r.any { it in "{}[]|" })
            }
        }
        assertEquals("Bio si brz. Ponosna sam.", Sef.oblik("{Bio|Bila} si brz. [Ponosan|Ponosna] sam.", zensko = false, sefZensko = true))
    }

    @Test fun dvaReda() {
        val sve = listOf(SefTekstovi.tacno, SefTekstovi.netacno, SefTekstovi.isteklo, SefTekstovi.blagoTacno, SefTekstovi.blagoNetacno,
            SefTekstovi.jakoTacno, SefTekstovi.jakoNetacno, SefTekstovi.smehTacno, SefTekstovi.smehNetacno).flatten()
        for (t in sve) for (z in listOf(true, false)) for (sz in listOf(true, false)) {
            val r = Sef.oblik(t, z, sz); assertTrue("${r.length}: $r", r.length <= 52)
        }
    }

    @Test fun ometanja() {
        repeat(500) {
            for ((nivo, opseg) in listOf(0 to 0..0, 1 to 1..1, 2 to 2..3, 3 to 4..5)) {
                val r = Sef.rasporedOmetanja(nivo)
                assertTrue(r.all { it in 0..9 && (it + 1) !in r })
                assertTrue("$nivo $r", r.size in opseg || (nivo == 3 && r.size >= 3))
            }
            assertEquals(Sef.Vrsta.UPAD, Sef.ometanje(1, true).vrsta)
            assertEquals(Sef.Vrsta.UPAD, Sef.ometanje(3, false).vrsta)
            assertEquals(Sef.Vrsta.ZADATAK, Sef.ometanje(2, true).vrsta)
        }
        assertEquals(Sef.Nivo(1, 1, 0, false, "korporacija"), Sef.Nivo(3, 3, 3).mirno(true))
    }

    @Test fun mesavinaKaoServer() {
        assertEquals(listOf(4, 3, 2, 1), Karijera.mesavina(40, listOf("istorija", "sport"), listOf(50, 30)).map { it.second })
        for (s in listOf(40, 50, 60, 70, 80)) for (u in listOf(20, 30, 40, 50))
            assertEquals(10, Karijera.mesavina(s, listOf("a", "b"), listOf(u, u)).sumOf { it.second })
        assertEquals(0.15, Karijera.stres(Sef.Nivo(1, 3, 3)), 0.0001)
        assertEquals("sub, ned", Karijera.daniOpis(listOf(7, 6)))
    }
}
