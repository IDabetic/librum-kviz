package club.librum.kviz.osvajanje

import android.content.Context
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlin.math.max
import kotlin.math.min

// Strategija Osvajanja (vlasnik 03.11.2026, docs/OSVAJANJE-STRATEGIJA.md), verni prevod Strategija.swift:
// vrste vojske, pomoći, ratne karte, savezi i brze poruke, događaji. Sve je u `Stanje` (isti JSON kao iOS).

/** Vrsta vojske koju igrač bira pre partije; nazivi u JSON-u kao iOS rawValue. */
@Serializable
enum class VrstaVojske(val naziv: String, val strategija: String) {
    @SerialName("legija") LEGIJA("Legija", "Napad: +1 tačan kad napadaš državu igrača."),
    @SerialName("garda") GARDA("Garda", "Odbrana: +1 tačan kad braniš svoju državu."),
    @SerialName("graditelji") GRADITELJI("Graditelji", "Rast: +1 vojska svakog kruga za svaki ceo region."),
    @SerialName("izvidnica") IZVIDNICA("Izvidnica", "Karte: počinje sa Špijunom, kartu dobija i za svako drugo osvajanje."),
    @SerialName("konjica") KONJICA("Konjica", "Brzina: 2 napada više u svakom potezu."),
    @SerialName("mudraci") MUDRACI("Mudraci", "Znanje: 5 sekundi više za svako pitanje u bitki.");

    /** Lik vojske (drawable `heroj_<vrsta>`, isti likovi kao iOS `Heroj_*`). */
    val heroj: String get() = "heroj_" + name.lowercase()

    /** Tri pomoći vojske: napadačke vojske imaju „dvostruko”, Garda „štit”, Mudraci najviše vremena. */
    /** Svoja moć vojske u bitki (vlasnik 03.11): po jedna za svaku, uz dve iste za sve. */
    val moc: PomocVojske get() = when (this) {
        LEGIJA -> PomocVojske.SIGURNI_UDAR; GARDA -> PomocVojske.STIT; GRADITELJI -> PomocVojske.VREME_STOJI
        IZVIDNICA -> PomocVojske.POLA_POLA; KONJICA -> PomocVojske.JURIS; MUDRACI -> PomocVojske.TACAN_ODGOVOR
    }
    val pomoci: List<PomocVojske> get() = listOf(moc, PomocVojske.ZAMENA, PomocVojske.VREME)
}

/** Šta pomoć vojske radi u pitanju. */
sealed interface Dejstvo {
    data object PolaPola : Dejstvo
    data object TacanOdgovor : Dejstvo
    data class Vreme(val sekundi: Int) : Dejstvo
    data object SatStoji : Dejstvo
    data object Zamena : Dejstvo
    data object Dvostruko : Dejstvo
    data object Siguran : Dejstvo
    data object Stit : Dejstvo
}

/** Pomoć vojske u pitanjima bitke: jedna svoja moć po vojsci i dve iste za sve, svaka jednom po krugu. Ključ = iOS rawValue. */
enum class PomocVojske(val kljuc: String, val naziv: String, val dejstvo: Dejstvo, val opis: String) {
    SIGURNI_UDAR("sigurniUdar", "Siguran udar", Dejstvo.Siguran, "Koji god odgovor izabereš, računa se kao tačan; ako pogodiš, vredi dva."),
    STIT("stit", "Štit", Dejstvo.Stit, "Ako pogrešiš, greška se briše i dobijaš novo pitanje."),
    VREME_STOJI("vremeStoji", "Vreme stoji", Dejstvo.SatStoji, "Sat se zaustavlja za ovo pitanje."),
    POLA_POLA("polaPola", "Pola-pola", Dejstvo.PolaPola, "Sklanja dva netačna odgovora."),
    JURIS("juris", "Juriš", Dejstvo.Dvostruko, "Sledeći tačan odgovor u napadu vredi dva."),
    TACAN_ODGOVOR("tacanOdgovor", "Tačan odgovor", Dejstvo.TacanOdgovor, "Pokazuje tačan odgovor."),
    ZAMENA("zamena", "Promena pitanja", Dejstvo.Zamena, "Menja pitanje novim."),
    VREME("vreme", "+10 sekundi", Dejstvo.Vreme(10), "+10 sekundi za ovo pitanje.");

    /** Moć po kojoj se vojska razlikuje (prva od tri). */
    val svoja: Boolean get() = this != ZAMENA && this != VREME
}

/** Ratna karta (samo Osvajanje); u ruci najviše `Pravila.NAJVISE_KARATA`. Redosled kao iOS `allCases`. */
@Serializable
enum class Karta(val naziv: String, val opis: String) {
    @SerialName("spijun") SPIJUN("Špijun", "U bitki ti otkriva tačan odgovor na prvo pitanje."),
    @SerialName("pojacanje") POJACANJE("Pojačanje", "+2 vojske na izabranu svoju državu (ili prestonicu)."),
    @SerialName("zamrzni") ZAMRZNI("Zamrzni granicu", "Izabranu svoju državu niko ne napada do kraja sledećeg kruga."),
    @SerialName("drugiPokusaj") DRUGI_POKUSAJ("Drugi pokušaj", "Pitanje koje ti ne leži menjaš novim, bez odgovora."),
    @SerialName("sabotaza") SABOTAZA("Sabotaža", "U tvom napadu protivnik gubi jedan tačan odgovor.");

    /** Karte koje se igraju na mapi, van bitke. */
    val naMapi: Boolean get() = this == POJACANJE || this == ZAMRZNI
}

/** Brza poruka u partiji (bez slobodnog teksta, pa bez moderacije). */
@Serializable
data class BrzaPoruka(val od: String, val tekst: String, val kad: Double) {
    companion object { val ponuda = listOf("Napadam te!", "Savez?", "Bravo!", "Čuvaj se!", "Hvala!", "Osveta!") }
}

/** Događaj na kontinentu: kreće svaka `DOGADJAJ_SVAKIH` kruga i traje `TRAJANJE_DOGADJAJA`. */
@Serializable
data class Dogadjaj(val kontinent: String, val od: Int, val doKruga: Int) {
    val naziv: String get() = opis[kontinent]?.first.orEmpty()
    val tekst: String get() = opis[kontinent]?.second.orEmpty()

    companion object {
        val opis = mapOf(
            "evr" to ("Zima u Evropi" to "Napadaču u Evropi treba jedan tačan više."),
            "afr" to ("Zlatno doba Afrike" to "Ceo region u Africi daje duplo vojske."),
            "azi" to ("Monsun u Aziji" to "Države u Aziji ne mogu da se napadnu."),
            "sam" to ("Zlatna groznica" to "Svaka osvojena država u Severnoj Americi daje +1 vojsku."),
            "jam" to ("Karneval" to "Pitanja u bitkama za Južnu Ameriku traju 10 s duže."),
            "oke" to ("Cunami" to "Države u Okeaniji su izgubile pola vojske."),
        )
    }
}

/** Misije koje je igrač na ovom telefonu skoro dobio: iste ne dolaze ponovo 7 dana dok ima drugih. */
object MisijeIstorija {
    private const val KLJUC = "osvajanje.misije"
    private const val NEDELJA_MS = 7L * 86_400_000

    fun skorasnje(ctx: Context, sad: Long = System.currentTimeMillis()): Set<String> {
        val p = ctx.getSharedPreferences(KLJUC, Context.MODE_PRIVATE)
        return p.all.filter { (_, v) -> v is Long && sad - v < NEDELJA_MS }.keys
    }

    fun zapamti(ctx: Context, id: String, sad: Long = System.currentTimeMillis()) {
        val p = ctx.getSharedPreferences(KLJUC, Context.MODE_PRIVATE)
        val e = p.edit()
        for ((k, v) in p.all) if (v !is Long || sad - v >= NEDELJA_MS) e.remove(k)
        e.putLong(id, sad).apply()
    }
}

// ── Vrste vojske ──

fun Stanje.vojska(igracId: String): VrstaVojske? = igraci.firstOrNull { it.id == igracId }?.vojska

/** Vojska tima: kapitenova (on bira odbranu i za ceo tim). */
fun Stanje.vojskaTima(tim: String): VrstaVojske? = (igraci.firstOrNull { it.tim == tim && it.kapiten } ?: igraci.firstOrNull { it.tim == tim })?.vojska

// ── Pomoći vojske (jednom po krugu) ──

fun Stanje.iskoriscenaPomoc(tim: String, p: PomocVojske): Boolean = pomociVojske?.get("$tim|${p.kljuc}") == krug

/** Beleži pomoć za ovaj krug; null kad tim nema tu pomoć ili ju je već iskoristio u ovom krugu. */
fun Stanje.iskoristiPomocVojske(tim: String, p: PomocVojske): Stanje? {
    if (vojskaTima(tim)?.pomoci?.contains(p) != true || iskoriscenaPomoc(tim, p)) return null
    return copy(pomociVojske = pomociVojske.orEmpty() + ("$tim|${p.kljuc}" to krug))
}

// ── Karte ──

fun Stanje.karte(tim: String): List<Karta> = karteTimova?.get(tim).orEmpty()

/** Dodaje kartu timu; vrsta je određena krugom, bitkom i timom, pa je ista na svakom telefonu. */
fun Stanje.dodeliKartu(tim: String): Stanje {
    val sve = karteTimova.orEmpty()
    if ((sve[tim]?.size ?: 0) >= Pravila.NAJVISE_KARATA) return this
    val h = krug * 31 + bitaka * 7 + tim.zbirZnakova()
    val sveKarte = Karta.entries
    return copy(karteTimova = sve + (tim to sve[tim].orEmpty() + sveKarte[h % sveKarte.size]))
}

/** Troši jednu kartu tima; null kad je nema. */
fun Stanje.iskoristiKartu(tim: String, k: Karta): Stanje? {
    val ruka = karteTimova?.get(tim) ?: return null
    val i = ruka.indexOf(k)
    if (i < 0) return null
    return copy(karteTimova = karteTimova + (tim to ruka.toMutableList().also { it.removeAt(i) }))
}

/** Pojačanje: +2 vojske na svoju državu. */
fun Stanje.igrajPojacanje(oblastId: String): Stanje? {
    val tim = trenutni.tim
    if (faza == Faza.KRAJ || oblasti[oblastId]?.vlasnik != tim) return null
    val s = iskoristiKartu(tim, Karta.POJACANJE) ?: return null
    val o = s.oblasti.getValue(oblastId)
    return s.copy(oblasti = s.oblasti + (oblastId to o.copy(vojske = o.vojske + Pravila.VOJSKI_POJACANJA)))
}

/** Zamrzni granicu: svoju državu niko ne napada do kraja sledećeg kruga. */
fun Stanje.igrajZamrzni(oblastId: String): Stanje? {
    val tim = trenutni.tim
    if (faza == Faza.KRAJ || oblasti[oblastId]?.vlasnik != tim) return null
    val s = iskoristiKartu(tim, Karta.ZAMRZNI) ?: return null
    return s.copy(zamrznuto = s.zamrznuto.orEmpty() + (oblastId to krug + 1))
}

fun Stanje.jeZamrznuta(oblastId: String): Boolean = (zamrznuto?.get(oblastId) ?: 0) >= krug

// ── Savezi ──

fun Stanje.uSavezu(a: String, b: String): Boolean = a != b && (savezi?.get(Stanje.kljucSaveza(a, b)) ?: 0) >= krug

/** Saveznici tima koji još važe. */
fun Stanje.saveznici(tim: String): List<String> = igraci.map { it.tim }.toSet().filter { uSavezu(tim, it) }.sorted()

/** Savez ima smisla kad su u igri bar tri strane. */
val Stanje.mozeSavez: Boolean get() = igraci.filter { !it.ispao }.map { it.tim }.toSet().size >= 3

/** Predlog saveza: kad postoji i obrnut predlog (ili druga strana prihvata), savez važi do kraja sledećeg kruga. */
fun Stanje.predloziSavez(od: String, za: String, prihvata: Boolean = false): Stanje {
    if (od == za || uSavezu(od, za) || !mozeSavez) return this
    val predlozi = predloziSaveza.orEmpty().toMutableList()
    var sv = savezi
    if (prihvata || "$za>$od" in predlozi) {
        sv = sv.orEmpty() + (Stanje.kljucSaveza(od, za) to krug + 1)
        predlozi.removeAll { it == "$za>$od" || it == "$od>$za" }
    } else if ("$od>$za" !in predlozi) {
        predlozi += "$od>$za"
    }
    return copy(savezi = sv, predloziSaveza = predlozi)
}

/** Bot prihvata savez kad predlagač nije najjači rival (ili kad je bot oprezan) i kad već nema dva saveza. */
fun Stanje.botPrihvataSavez(bot: String, od: String): Boolean {
    val botId = igraci.firstOrNull { it.tim == bot }?.id
    if (saveznici(bot).size >= 2 || jeIzdajnik(od) || botId == null) return false
    val najjaci = igraci.filter { !it.ispao && it.tim != bot }.map { it.tim }.toSet().maxWithOrNull(compareBy { snaga(it) })
    return od != najjaci || narav(botId) == Narav.OPREZAN
}

// ── Poruke ──

fun Stanje.posalji(tekst: String, od: String, kad: Long = System.currentTimeMillis()): Stanje =
    copy(poruke = (poruke.orEmpty() + BrzaPoruka(od, tekst, kad / 1000.0)).takeLast(8))

/** Poslednja poruka igrača ako je mlađa od 6 s (oblačić iznad igrača). */
fun Stanje.svezaPoruka(igracId: String, sad: Long = System.currentTimeMillis()): String? {
    val p = poruke?.lastOrNull { it.od == igracId } ?: return null
    return if (sad / 1000.0 - p.kad < 6) p.tekst else null
}

// ── Događaji ──

fun Stanje.aktivanDogadjaj(kontinentId: String): Boolean {
    val d = dogadjaj ?: return false
    return d.kontinent == kontinentId && krug in d.od..d.doKruga
}

/** Na početku kruga deljivog sa `DOGADJAJ_SVAKIH` bira se kontinent iz igre (isto na svakom telefonu). */
fun Stanje.pokreniDogadjajAkoTreba(): Stanje {
    if (krug <= 1 || krug % Pravila.DOGADJAJ_SVAKIH != 0 || dogadjaj?.od == krug) return this
    val uIgri = Kontinenti.svi.filter { k -> Kontinenti.oblasti(k.id).any { oblasti[it] != null } }
    if (uIgri.isEmpty()) return this
    val r = Slucajno((krug * 7919 + igraci.joinToString("") { it.id }.zbirZnakova()) xor semeBitovi)
    val k = uIgri[(r.sledeci() * uIgri.size).toInt()].id
    var s = copy(dogadjaj = Dogadjaj(k, krug, krug + Pravila.TRAJANJE_DOGADJAJA - 1))
    if (k == "oke") {
        val ids = Kontinenti.oblasti(k).toSet()
        s = s.copy(oblasti = s.oblasti.mapValues { (id, o) -> if (id in ids && o.vlasnik != null) o.copy(vojske = max(1, o.vojske / 2)) else o })
    }
    return s
}

// ── Bot: karte i savezi ──

/** Na početku poteza bot igra karte sa mape: Pojačanje na najugroženiju granicu, Zamrzni na prestonicu pod pretnjom. */
fun Stanje.botIgraKarte(): Stanje {
    var s = this
    val tim = trenutni.tim
    val cilj = ciljBota(tim)
    val moje = oblastiIgraca(trenutni.id)
    while (Karta.POJACANJE in s.karte(tim)) {
        val st = s
        val gde = moje.maxWithOrNull(compareBy { st.pretnja(it, tim, cilj) }) ?: break
        s = s.igrajPojacanje(gde) ?: break
    }
    val prestonica = trenutni.prestonica
    if (Karta.ZAMRZNI in s.karte(tim) && s.oblasti[prestonica]?.vlasnik == tim && !s.jeZamrznuta(prestonica) && s.pretnja(prestonica, tim, cilj) >= 4) {
        s.igrajZamrzni(prestonica)?.let { s = it }
    }
    return s
}

/** Kad neko pobegne (snaga 1,4 puta veća od botove), bot nudi savez susednom rivalu koji nije taj vođa. */
fun Stanje.botTraziSavez(): Stanje {
    val tim = trenutni.tim
    val zivi = igraci.filter { !it.ispao && it.tim != tim }.map { it.tim }.toSet()
    if (saveznici(tim).isNotEmpty()) return this
    val vodja = zivi.maxWithOrNull(compareBy<String>({ snaga(it) }, { it })) ?: return this
    if (snaga(vodja) <= snaga(tim) * 1.4) return this
    val moje = oblasti.filter { it.value.vlasnik == tim }.keys
    val susedi = moje.flatMap { Mapa.susedi(it) }.mapNotNull { oblasti[it]?.vlasnik }.toSet().intersect(zivi) - vodja
    val drug = susedi.sorted().firstOrNull { t -> igraci.any { it.tim == t && !it.covek && !it.id.startsWith("u:") } } ?: return this
    if (!botPrihvataSavez(drug, tim)) return this
    return predloziSavez(tim, drug, prihvata = true).posalji("Savez?", trenutni.id)
}

// ── Prednost u bitki ──

/** Prednost napadača u tačnim odgovorima (negativno = branioca): višak vojske (najviše ±2), Legija, Garda, Zima, teren, čuda. */
fun Stanje.pomakBitke(odakle: String, kuda: String): Int {
    val izvor = oblasti[odakle] ?: return 0
    val meta = oblasti[kuda] ?: return 0
    val branilac = meta.vlasnik ?: return 0
    val visak = (izvor.vojske - 1) - meta.vojske
    var p = min(Pravila.NAJVECA_PREDNOST_VOJSKE, max(-Pravila.NAJVECA_PREDNOST_VOJSKE, visak))
    if (izvor.vlasnik != null && vojskaTima(izvor.vlasnik) == VrstaVojske.LEGIJA) p += 1
    if (vojskaTima(branilac) == VrstaVojske.GARDA) p -= 1
    if (aktivanDogadjaj("evr") && Kontinenti.od(kuda).id == "evr") p -= 1
    if (kuda in Teren.planine) p -= 1
    if (Teren.prekoMora(odakle, kuda)) p -= 1
    if (drziCudo(branilac, "CHN") && Kontinenti.od(kuda).id == "azi") p -= 1
    if (izvor.vlasnik != null && odbioUltimatum(izvor.vlasnik, kuda)) p += 1
    return p
}

/** Da li napadač osvaja državu igrača: tačni + prednost, kod jednakog brži (osim uz odbranu „Prednost”). */
fun Stanje.osvaja(odakle: String, kuda: String, napadac: Skor, branilac: Skor): Boolean {
    val potrebno = if (odbranaMete(kuda) == Odbrana.PREDNOST) 2 else 1
    val razlika = napadac.tacnih - branilac.tacnih + pomakBitke(odakle, kuda)
    return razlika >= potrebno || (potrebno == 1 && razlika == 0 && napadac.ms < branilac.ms)
}
