package club.librum.kviz.reci

import android.content.Context
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Apps
import androidx.compose.material.icons.rounded.Gesture
import androidx.compose.material.icons.rounded.GridOn
import androidx.compose.material.icons.rounded.Link
import androidx.compose.material.icons.rounded.Numbers
import androidx.compose.material.icons.rounded.Workspaces
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import club.librum.kviz.igre.MojRezultat
import club.librum.kviz.servisi.Napredak
import club.librum.kviz.servisi.Sesija
import club.librum.kviz.servisi.Supabase
import club.librum.kviz.ui.Boje
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement
import java.time.LocalDate
import java.time.ZoneId

/**
 * Šest dnevnih igara reči, verni prevod iOS IgreReci/ (scripts/2026-11-08_igre-reci.sql, zagonetke iz alati/igre_reci.py).
 * Ista zagonetka za sve igrače po beogradskom danu; rang listu ocenjuje server.
 */
enum class IgraReci(val kljuc: String, val naslov: String, val opis: String, val pravilo: String, val ikona: ImageVector, val boja: Color, val rok: Int) {
    PREMETALJKA("premetaljka", "Premetaljka", "Složi reči od 7 slova",
        "Dodiruj slova i složi reč od najmanje 3 slova. Glavna reč koristi svih 7.", Icons.Rounded.Workspaces, Boje.zuta, 180),
    PET_SLOVA("pet_slova", "Pet slova", "Pogodi reč u 6 pokušaja",
        "Zeleno: slovo je na mestu. Žuto: slovo je u reči, ali na drugom mestu. Sivo: nema ga.", Icons.Rounded.Apps, Boje.teal, 240),
    LANAC("lanac", "Lanac", "Menjaj po jedno slovo",
        "Od prve do poslednje reči menjaj tačno jedno slovo; svaki korak mora biti prava reč.", Icons.Rounded.Link, Boje.narandzasta, 240),
    SIFRA("sifra", "Šifra", "Svaki broj je jedno slovo",
        "Isti broj je uvek isto slovo. Dodirni polje, pa otkucaj slovo.", Icons.Rounded.Numbers, Boje.ljubicasta, 360),
    UKRSTENICA("ukrstenica", "Mini ukrštenica", "Mala ukrštenica sa opisima",
        "Dodirni polje, pročitaj opis i upiši reč. Drugi dodir menja smer.", Icons.Rounded.GridOn, Boje.nebo, 360),
    ZMIJA("zmija", "Zmija", "Pronađi reči teme dana",
        "Prevuci prstom preko susednih slova (gore, dole, levo, desno). Reči teme popunjavaju celu mrežu.", Icons.Rounded.Gesture, Boje.roze, 300);

    /** Tamna ikonica na jarkoj boji (žuta, narandžasta, nebo), bela na ostalim. */
    val tamnaIkonica: Boolean get() = this == PREMETALJKA || this == LANAC || this == UKRSTENICA

    companion object { fun od(k: String) = entries.firstOrNull { it.kljuc == k } }
}

// Zagonetke (isti JSON kao iOS)
@Serializable data class PremetaljkaZ(val slova: List<String>, val glavna: String, val reci: List<String>)
@Serializable data class PetSlovaZ(val rec: String, val tezina: String? = null)
@Serializable data class LanacZ(val od: String, @SerialName("do") val doReci: String, val primer: List<String>, val najmanje: Int)
@Serializable data class SifraZ(val sirina: Int, val visina: Int, val polja: List<List<Int>>, val kljuc: Map<String, String>, val data: List<Int>, val reci: List<String> = emptyList())
@Serializable data class UkrRec(val rec: String, val x: Int, val y: Int, val smer: String, val broj: Int, val opis: String)
@Serializable data class UkrstenicaZ(val sirina: Int, val visina: Int, val reci: List<UkrRec>)
@Serializable data class ZmijaRec(val rec: String, val put: List<List<Int>>)
@Serializable data class ZmijaZ(val tema: String, val sirina: Int, val visina: Int, val slova: List<String>, val reci: List<ZmijaRec>)

@Serializable data class ZagonetkeDana(
    val premetaljka: PremetaljkaZ? = null, @SerialName("pet_slova") val petSlova: PetSlovaZ? = null, val lanac: LanacZ? = null,
    val sifra: SifraZ? = null, val ukrstenica: UkrstenicaZ? = null, val zmija: ZmijaZ? = null,
)
@Serializable data class MojRezultatReci(val resio: Boolean, val poeni: Int, val sekundi: Int, val pomoci: Int? = null)
@Serializable data class DanReci(val datum: String, val igre: ZagonetkeDana, val moji: Map<String, MojRezultatReci> = emptyMap(), val nizovi: Map<String, Int>? = null)
@Serializable data class IshodReci(val resio: Boolean, val poeni: Int, val sekundi: Int, val mesto: Int, val ukupno: Int)
@Serializable data class RedRangaReci(val mesto: Int, val id: String, val ime: String, val avatar: String? = null, val resio: Boolean, val poeni: Int, val sekundi: Int)

/** Igra u sobi „Igraj sa drugima”: rok, bodovanje brzine i javljanje rezultata tabeli uživo. */
class UTakmicenju(val rok: Int, val javi: (MojRezultat) -> Unit) {
    /** Brzina donosi do rok/6 poena. Primer: rok 240, rešeno za 60 s → 30. */
    fun bonus(sekundi: Int) = maxOf(0, rok - sekundi) / 6
}

/** Dan sa zagonetkama, napredak partija na telefonu i slanje rezultata. */
object IgreReciServis {
    var dan: DanReci? = null
        private set

    /** Današnji datum po Beogradu, isti kao igre_reci_danas() na serveru. */
    fun danas(): String = LocalDate.now(ZoneId.of("Europe/Belgrade")).toString()

    suspend fun ucitaj(ctx: Context, sesija: Sesija): DanReci {
        val prefs = ctx.getSharedPreferences("igreReci", Context.MODE_PRIVATE)
        return try {
            val tekst = Supabase.rpc("igre_reci_dan", emptyMap(), sesija.vazeciToken())
            val d = Supabase.json.decodeFromString(DanReci.serializer(), tekst)
            prefs.edit().putString("dan", tekst).apply()
            dan = d
            d
        } catch (g: Exception) {
            // poslednji dan iz keša: igra radi i bez mreže dok je isti datum
            val kes = prefs.getString("dan", null)?.let { runCatching { Supabase.json.decodeFromString(DanReci.serializer(), it) }.getOrNull() }
            if (kes != null && kes.datum == danas()) { dan = kes; kes } else throw g
        }
    }

    fun moj(igra: IgraReci): MojRezultatReci? = dan?.moji?.get(igra.kljuc)
    fun niz(igra: IgraReci): Int = dan?.nizovi?.get(igra.kljuc) ?: 0

    /** Šalje prvi rezultat dana (ponovljena igra se ne broji). Gost dobija null. */
    suspend fun zavrsi(igra: IgraReci, odgovor: Map<String, Any?>, resio: Boolean, sekundi: Int, pomoci: Int, sesija: Sesija): IshodReci? {
        val d = dan ?: return null
        Napredak.deljeni.zabeleziIgru("reci_" + igra.kljuc, if (resio) 1 else 0, if (resio) 0 else 1, pobeda = resio)
        val token = sesija.vazeciToken() ?: return null
        val i = Supabase.json.decodeFromString(IshodReci.serializer(), Supabase.rpc("igre_reci_zavrsi", mapOf(
            "p_igra" to igra.kljuc, "p_datum" to d.datum, "p_odgovor" to odgovor, "p_sekundi" to sekundi, "p_pomoci" to pomoci), token))
        dan = d.copy(moji = d.moji + (igra.kljuc to MojRezultatReci(i.resio, i.poeni, i.sekundi, pomoci)))
        return i
    }

    suspend fun rang(igra: IgraReci): List<RedRangaReci> = runCatching {
        Supabase.json.decodeFromString(kotlinx.serialization.builtins.ListSerializer(RedRangaReci.serializer()),
            Supabase.rpc("igre_reci_rang", mapOf("p_igra" to igra.kljuc)))
    }.getOrDefault(emptyList())

    /** Domaćin sobe: nasumična zagonetka iz baze izazova (težina sobe „normalno” je srednja). */
    suspend fun izazov(igra: IgraReci, tezina: String, token: String): JsonElement =
        Supabase.json.parseToJsonElement("[" + Supabase.rpc("igre_reci_izazov", mapOf("p_igra" to igra.kljuc, "p_tezina" to tezina), token) + "]")
}

/** Rečnik za proveru unosa (alati/igre_reci.py recnik → src/lib/igre/reci.txt, ~107 hiljada oblika). */
object RecnikReci {
    @Volatile private var reci: Set<String> = emptySet()

    fun ucitaj(ctx: Context) {
        if (reci.isNotEmpty()) return
        reci = runCatching { ctx.assets.open("reci.txt").bufferedReader().readLines().toHashSet() }.getOrDefault(emptySet())
    }

    /** Primer: postoji("kuća") → true. */
    fun postoji(rec: String) = reci.contains(rec.lowercase())
    fun sve(): Set<String> = reci
}

/** Azbuka igara (latinica bez dvoslova, kao Vešanje). */
object AzbukaReci {
    val dozvoljena: Set<Char> = "ABCČĆDĐEFGHIJKLMNOPRSŠTUVZŽ".toSet()
    /** Primer: slova("kuća") → [K, U, Ć, A]. */
    fun slova(rec: String): List<String> = rec.uppercase().map { it.toString() }
    fun vreme(s: Int) = "%d:%02d".format(s / 60, s % 60)
    /** Primer: razlikaJednoSlovo("kosa", "kasa") → true. */
    fun razlikaJednoSlovo(a: String, b: String) = a.length == b.length && a.zip(b).count { it.first != it.second } == 1
}

/** Napredak partije na telefonu (izlazak i povratak ne gube igru). */
object PartijeReci {
    fun ucitaj(ctx: Context, igra: IgraReci, datum: String): String? =
        ctx.getSharedPreferences("igreReci", Context.MODE_PRIVATE).getString("${igra.kljuc}.$datum", null)
    fun sacuvaj(ctx: Context, igra: IgraReci, datum: String, json: String) =
        ctx.getSharedPreferences("igreReci", Context.MODE_PRIVATE).edit().putString("${igra.kljuc}.$datum", json).apply()
}
