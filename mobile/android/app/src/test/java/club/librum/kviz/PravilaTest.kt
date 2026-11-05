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
import club.librum.kviz.osvajanje.*

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
/** Sat poteza: tri isteka zaredom bez napada izbacuju igrača; napad briše niz (isto kao iOS SatPotezaTests). */
class SatPotezaTest {
    init { Mapa.ucitaj(java.io.File("../../../src/lib/osvajanje/svet.json").readText()) }

    @Test fun triIstekaIzbacuju() {
        var s = Stanje.nova(12, Tezina.NORMALNO, Slucajno(5)).let { it.copy(faza = Faza.NAPAD) }
        val ja = s.trenutni.id; val tim = s.trenutni.tim
        for (i in 1..3) {
            s = s.isteklo(ja)
            assertEquals(i, s.propusteno?.get(ja))
            while (s.trenutni.id != ja && s.faza != Faza.KRAJ) s = s.zavrsiPotez()
            s = s.copy(faza = Faza.NAPAD)
        }
        assertTrue(s.igraci.first { it.id == ja }.ispao)
        assertFalse(s.oblasti.values.any { it.vlasnik == tim })
    }

    @Test fun napadBriseNiz() {
        var s = Stanje.nova(12, Tezina.NORMALNO, Slucajno(5)).let { it.copy(faza = Faza.NAPAD) }
        val ja = s.trenutni.id
        s = s.isteklo(ja)
        while (s.trenutni.id != ja) s = s.zavrsiPotez()
        assertEquals(0, s.copy(faza = Faza.NAPAD, bitaka = 1).isteklo(ja).propusteno?.get(ja))
    }
}

/** Mozak bota (docs/OSVAJANJE-BOT.md), isti slučajevi kao iOS BotTests. */
class BotTest {
    init { Mapa.ucitaj(java.io.File("../../../src/lib/osvajanje/svet.json").readText()) }

    private fun botNaPotezu(vararg v: Triple<String, String, Int>, tacnost: Double = 0.75): Stanje {
        val s = Stanje.nova(12, Tezina.TESKO, Slucajno(3))
        val oblasti = Mapa.oblasti.associate { it.id to StanjeOblasti(null, 1) } + v.associate { it.first to StanjeOblasti(it.second, it.third) }
        return s.copy(faza = Faza.NAPAD, naPotezu = s.igraci.indexOfFirst { it.id == "mimi" }, tacnostBota = tacnost, oblasti = oblasti)
    }

    @Test fun sansaBitke() {
        assertEquals(0.5, Stanje.sansaBitke(0.5, 0.5, 5, false), 0.001)
        assertTrue(Stanje.sansaBitke(0.75, 0.5, 5, false) > 0.7)
        assertTrue(Stanje.sansaBitke(0.75, 0.5, 5, true) < Stanje.sansaBitke(0.75, 0.5, 5, false))
    }

    /** Vlasnik 03.11: botovi ne idu samo na čoveka; cilj je najjači sused, bio on čovek ili bot (iOS isto). */
    @Test fun botoviCiljajuRavnopravno() {
        val s = botNaPotezu(Triple("SRB", "ti", 3), Triple("FRA", "mimi", 3), Triple("DEU", "zig", 9))
        assertEquals("zig", s.ciljBota("mimi"))
        assertEquals("mimi", s.ciljBota("zig"))
        val jak = botNaPotezu(Triple("HUN", "ti", 12), Triple("ROU", "mimi", 3), Triple("UKR", "zig", 2))
        assertEquals("jak čovek u susedstvu je cilj kao i svaki drugi", "ti", jak.ciljBota("mimi"))
    }

    @Test fun botZatvaraRegion() {
        val srb = Mapa.oblast("SRB").region
        val s = botNaPotezu(*Mapa.oblasti.filter { it.region == srb && it.id != "SRB" }.map { Triple(it.id, "mimi", 3) }.toTypedArray())
        assertEquals("SRB", s.botSledeciNapad()?.second)
    }

    @Test fun botNeRizikujePrestonicuKadSlaboZna() {
        val s = botNaPotezu(Triple("FRA", "mimi", 8), Triple("DEU", "ti", 2), tacnost = 0.3)
        val t = s.copy(igraci = s.igraci.map { if (it.id == "mimi") it.copy(prestonica = "FRA") else it })
        assertTrue(t.ocenaNapada("FRA", "DEU") < 0)
    }
}

/** Stanje partije putuje između iOS-a i Androida (osvajanje_potezi): isti ključevi i vrednosti kao iOS Codable. */
class FormatStanjaTest {
    init { Mapa.ucitaj(java.io.File("../../../src/lib/osvajanje/svet.json").readText()) }
    private val json = kotlinx.serialization.json.Json { ignoreUnknownKeys = true; encodeDefaults = true; explicitNulls = false }

    @Test fun androidPiseKaoIos() {
        val s = Stanje.nova(8, Tezina.NORMALNO, Slucajno(7), "Ti")
            .let { it.copy(odbrane = mapOf("evr" to club.librum.kviz.osvajanje.Odbrana.BRZ_SAT)) }
        val o = json.parseToJsonElement(json.encodeToString(Stanje.serializer(), s)).let { it as kotlinx.serialization.json.JsonObject }
        assertEquals("\"snabdevanje\"", o["faza"].toString())
        assertEquals("\"brzSat\"", (o["odbrane"] as kotlinx.serialization.json.JsonObject)["evr"].toString())
        // iOS dekoder traži i prazne mape.
        listOf("misije", "metaMisije", "promenaOdbrane", "tvrdjava", "tacnih", "bonusPomoci").forEach { assertTrue(it, o.containsKey(it)) }
        val boja = ((o["igraci"] as kotlinx.serialization.json.JsonArray)[0] as kotlinx.serialization.json.JsonObject)["boja"].toString().toLong()
        assertTrue("boja bez alfe", boja <= 0xFFFFFF)
        assertEquals(s, json.decodeFromString(Stanje.serializer(), json.encodeToString(Stanje.serializer(), s)))
    }

    @Test fun androidCitaIos() {
        val ios = """{"igraci":[{"id":"u:a","ime":"Ana","boja":1216638,"covek":false,"prestonica":"SRB","ispao":false,"tim":"A","kapiten":true}],
            "oblasti":{"SRB":{"vlasnik":"A","vojske":5},"HRV":{"vojske":1}},"krug":2,"ukupnoKrugova":8,"naPotezu":0,"faza":"napad","zaRaspored":0,
            "bitaka":1,"niz":0,"utvrdjeno":false,"tacnostBota":0.62,"misije":{},"metaMisije":{},"odbrane":{"evr":"tvrdjava"},"promenaOdbrane":{},
            "tvrdjava":{},"tacnih":{"A":3},"bonusPomoci":{}}"""
        val s = json.decodeFromString(Stanje.serializer(), ios)
        assertEquals(Faza.NAPAD, s.faza)
        assertEquals(0xFF12907E, s.igraci[0].boja)
        assertEquals(null, s.oblasti["HRV"]?.vlasnik)
        assertEquals(club.librum.kviz.osvajanje.Odbrana.TVRDJAVA, s.odbrane["evr"])
    }
}

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

/** Iste provere kao iOS (PravilaTests.swift): cele partije botova, isto seme = ista partija, nevažeći napad ne ruši. */
class StrategijaTest {
    init { Mapa.ucitaj(java.io.File("../../../src/lib/osvajanje/svet.json").readText()) }

    @Test fun celePartijeBotovaBezPadaIZaglavljivanja() {
        for (seme in 1..20) for (igraca in listOf(2, 4, 6)) {
            val r = Slucajno(seme * -1640531535)
            val imena = listOf("Bloop", "Mimi", "Zig", "Lumi", "Sara", "Max")
            val igraci = (0 until igraca).map { NoviIgrac("b$it", imena[it], 0xFF12907E, covek = false, tim = "T$it") }
            var s = Stanje.nova(8, Tezina.TESKO, r, igraci = igraci)
            var koraka = 0
            while (s.faza != Faza.KRAJ && koraka < 5_000) {
                koraka++
                s = s.snabdevanje(r.sledeci() < s.tacnostBota).botRasporedi().botOdbrana().botIgraKarte().botTraziSavez()
                    .botIzdaja().botNajaviPohod().botUltimatum()
                var napada = 0
                while (napada < 40) {
                    val n = s.botSledeciNapad() ?: break
                    napada++
                    s = if (s.oblasti[n.second]?.vlasnik != null) s.postaviUlog(Stanje.ulogBota(0.8)).razresiBitkuSkorom(n.first, n.second, s.botSkor(r), s.botSkor(r)).first
                    else s.razresiBitku(n.first, n.second, s.botOdgovor(r), null).first
                    if (s.faza == Faza.KRAJ) break
                }
                assertTrue("bot ne prestaje da napada", napada < 40)
                if (s.faza == Faza.NAPAD) s = s.botUtvrdi()
                if (s.faza != Faza.KRAJ) s = s.zavrsiPotez()
            }
            assertTrue("partija $seme/$igraca zaglavljena", koraka < 5_000)
        }
    }

    @Test fun istoSemeIstaPartija() {
        val a = Stanje.nova(12, Tezina.NORMALNO, Slucajno(42), misije = true)
        val b = Stanje.nova(12, Tezina.NORMALNO, Slucajno(42), misije = true)
        assertEquals(a, b)
        assertTrue(a.seme != null)
    }

    @Test fun napadKojiViseNeVaziSePreskace() {
        var s = Stanje.nova(5, Tezina.NORMALNO, Slucajno(99)).snabdevanje(true)
        while (s.faza == Faza.RASPORED) s = s.rasporedi(s.oblastiIgraca(s.trenutni.id).first())
        val odakle = s.oblastiIgraca(s.trenutni.id).first { s.mete(it).isNotEmpty() }
        val kuda = s.mete(odakle).first()
        val promenjeno = s.copy(faza = Faza.RASPORED)
        val (posle, ishod) = promenjeno.razresiBitkuSkorom(odakle, kuda, Skor(5, 1), Skor(0, 1))
        assertEquals(promenjeno, posle)
        assertFalse(ishod.osvojeno)
    }

    @Test fun jsonStanjaKaoIos() {
        val s = Stanje.nova(12, Tezina.NORMALNO, Slucajno(7), misije = true)
        val json = kotlinx.serialization.json.Json { encodeDefaults = false; explicitNulls = false }
        val tekst = json.encodeToString(Stanje.serializer(), s)
        assertTrue(tekst.contains("\"seme\":"))
        assertEquals(s, json.decodeFromString(Stanje.serializer(), tekst))
    }
}

/** Otisak partije za isto seme mora biti isti na iOS-u (PravilaTests.swift, OtisakPartijeTests) i Androidu. */
class OtisakPartijeTest {
    init { Mapa.ucitaj(java.io.File("../../../src/lib/osvajanje/svet.json").readText()) }

    @Test fun otisak() {
        val r = Slucajno(42)
        var s = Stanje.nova(12, Tezina.NORMALNO, r, misije = true)
        repeat(6) {
            s = s.snabdevanje(true).botRasporedi().botOdbrana().botIgraKarte().botTraziSavez().botIzdaja().botNajaviPohod().botUltimatum()
            var n = 0
            while (n < 10) { val a = s.botSledeciNapad() ?: break; n++; s = if (s.oblasti[a.second]?.vlasnik != null) s.razresiBitkuSkorom(a.first, a.second, s.botSkor(r), s.botSkor(r)).first else s.razresiBitku(a.first, a.second, s.botOdgovor(r), null).first }
            if (s.faza == Faza.NAPAD) s = s.botUtvrdi()
            s = s.zavrsiPotez()
        }
        val otisak = "${s.seme}|" + s.igraci.joinToString(",") { "${it.id}:${it.prestonica}:${it.vojska?.name?.lowercase()}" } + "|" +
            s.misije.toSortedMap().entries.joinToString(",") { "${it.key}=${it.value}" } + "|" +
            s.igraci.joinToString(",") { "${it.tim}=${s.oblastiIgraca(it.id).size}/${s.oblastiIgraca(it.id).sumOf { o -> s.oblasti[o]!!.vojske }}" }
        assertEquals("131503810|ti:PRK:mudraci,mimi:FRA:izvidnica,zig:AFG:graditelji|mimi=regiona6-kontinent,ti=drzava45x2,zig=evr-afr|ti=8/20,mimi=10/20,zig=9/10", otisak)
    }
}

/** Botovi takmičenja: isti rezultati kao iOS (KvizTests.swift, TakmicenjeTests.testBotIstiKaoAndroid) za isto seme sobe. */
class TakmicenjeBotTest {
    @Test fun otisakBotova() {
        val otisak = club.librum.kviz.igre.IgraTakmicenja.entries.joinToString(",") { g ->
            val b = club.librum.kviz.igre.Takmicenje.Bot.rezultat(g, "normalno", 1095258902L, 2, g.broj, 40.0)
            "${g.kljuc}=${b.poeni}/${b.tacnih}/${b.odigrano}"
        }
        assertEquals("pro=48/3/3,book=48/3/3,slikari=48/3/3,brzi=205/11/14,vesanje=36/1/1", otisak)
    }
}

/** Vlasnik 03.11: svaka vojska ima jednu svoju moć i dve iste za sve (ključevi kao iOS rawValue). */
class MocVojskeTest {
    @org.junit.Test fun svakaVojskaSvojaMoc() {
        val sve = club.librum.kviz.osvajanje.VrstaVojske.entries
        org.junit.Assert.assertEquals(6, sve.map { it.moc }.toSet().size)
        sve.forEach { org.junit.Assert.assertEquals(listOf(it.moc, club.librum.kviz.osvajanje.PomocVojske.ZAMENA, club.librum.kviz.osvajanje.PomocVojske.VREME), it.pomoci) }
        org.junit.Assert.assertEquals(listOf("sigurniUdar", "stit", "vremeStoji", "polaPola", "juris", "tacanOdgovor", "zamena", "vreme"),
            club.librum.kviz.osvajanje.PomocVojske.entries.map { it.kljuc })
    }
}
