package club.librum.kviz.igre

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import club.librum.kviz.servisi.Pitanje
import club.librum.kviz.servisi.Prikaz
import club.librum.kviz.servisi.Sesija
import club.librum.kviz.servisi.Supabase
import club.librum.kviz.ui.Boje
import club.librum.kviz.ui.Dijalog
import club.librum.kviz.ui.Dugme
import club.librum.kviz.ui.Maskota
import club.librum.kviz.ui.MaskotaSlika
import club.librum.kviz.ui.OdgovorDugme
import club.librum.kviz.ui.Oznaka
import club.librum.kviz.ui.Papir
import club.librum.kviz.ui.PomociTraka
import club.librum.kviz.ui.StanjeOdgovora
import club.librum.kviz.ui.VrstaDugmeta
import club.librum.kviz.ui.mirna
import club.librum.kviz.ui.naslov
import club.librum.kviz.ui.pop
import club.librum.kviz.ui.tekst
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import java.time.Instant

/** Soba duela, isti red tabele game_rooms kao na vebu (src/app/igraj-zajedno). */
@Serializable
data class Soba(
    val id: String,
    val room_code: String,
    val host_id: String,
    val guest_id: String? = null,
    val status: String,
    val question_ids: List<String> = emptyList(),
    val host_answers: List<Int?>? = null,
    val guest_answers: List<Int?>? = null,
    val host_score: Int? = null,
    val guest_score: Int? = null,
    val total_questions: Int? = null,
    val game_format: String? = null,
)

/** Tok duela: soba, čekanje rivala, pitanja, otkrivanje i kraj; soba se osvežava svake sekunde. */
class DuelModel(private val sesija: Sesija) : ViewModel() {
    enum class Faza { LOBI, CEKANJE, IGRA, KRAJ }

    companion object {
        const val POENA_TACNO = 10
        const val POENA_NETACNO = 5
        const val BONUS_NAPUSTANJA = 50
        const val SEKUNDI = 15
        val FORMATI = listOf(10 to "Brzi duel", 25 to "Standardni duel", 50 to "Veliki duel")
        /** Izazov bez čekanja: izazivač odigra odmah, rival kad stigne (do 24 h); ishod kad oba završe. */
        const val FORMAT_IZAZOVA = "izazov"
        const val PITANJA_IZAZOVA = 10
        private fun noviKod() = (1..5).map { "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".random() }.joinToString("")
    }

    val jeIzazov get() = soba?.game_format == FORMAT_IZAZOVA
    /** Izazivač je odigrao, rival još nije. */
    val cekaRivala get() = jeIzazov && jaSamDomacin && (soba?.guest_answers.orEmpty().size < ukupno)

    /** Izazov za igrača: soba je odmah „playing”, rival je upisan, ja igram svojih 10 pitanja sad; rival dobija obaveštenje. */
    fun izazovi(rival: String) = viewModelScope.launch {
        val id = sesija.nalog.value?.id ?: return@launch
        val token = sesija.vazeciToken() ?: return@launch
        radi = true
        runCatching {
            val p = Supabase.json.decodeFromString<List<Pitanje>>(Supabase.rpc("aplikacija_pitanja", mapOf("p_igra" to "opste", "p_broj" to PITANJA_IZAZOVA + 5), token))
                .take(PITANJA_IZAZOVA)
            require(p.size >= PITANJA_IZAZOVA) { "Nema dovoljno pitanja za duel." }
            val s = dekoduj(Supabase.upisiVrati("game_rooms", mapOf(
                "room_code" to noviKod(), "host_id" to id, "guest_id" to rival, "question_ids" to p.map { it.id }, "total_questions" to PITANJA_IZAZOVA,
                "status" to "playing", "game_format" to FORMAT_IZAZOVA, "quiz_type" to "pro", "game_start_time" to Instant.now().toString(),
            ), token)).first()
            soba = s; pitanja = p
            runCatching { Supabase.upisi("izazovi", mapOf("od" to id, "za" to rival, "igra" to "duel", "kod_sobe" to s.room_code), token) }
            faza = Faza.IGRA; pocetakPitanja = System.currentTimeMillis()
            pratiSobu()
        }.onFailure { greska = it.message }
        radi = false
    }

    data class MojIzazov(val soba: Soba, val rival: String, val rivalIme: String, val ja: Int, val on: Int, val zavrsen: Boolean, val naMeni: Boolean)
    @Serializable private data class ImeIgraca(val id: String, val nickname: String? = null, val first_name: String? = null)

    /** Moji izazovi (poslati i primljeni, 7 dana) za lobi: ko čeka koga i ishod. */
    suspend fun mojiIzazovi(): List<MojIzazov> = runCatching {
        val id = sesija.nalog.value?.id ?: return emptyList()
        val token = sesija.vazeciToken() ?: return emptyList()
        val sobe = dekoduj(Supabase.citaj("game_rooms", listOf(
            "select" to "*", "game_format" to "eq.$FORMAT_IZAZOVA", "or" to "(host_id.eq.$id,guest_id.eq.$id)",
            "created_at" to "gte.${Instant.now().minusSeconds(7 * 86_400)}", "order" to "created_at.desc", "limit" to "20",
        ), token))
        val drugi = sobe.mapNotNull { if (it.host_id == id) it.guest_id else it.host_id }.toSet()
        val ime = if (drugi.isEmpty()) emptyMap() else Supabase.json.decodeFromString<List<ImeIgraca>>(Supabase.citaj("public_profiles",
            listOf("select" to "id,nickname,first_name", "id" to "in.(${drugi.joinToString(",")})"), token)).associate { it.id to (it.nickname ?: it.first_name ?: "Igrač") }
        sobe.map { s ->
            val domacin = s.host_id == id
            val rival = (if (domacin) s.guest_id else s.host_id).orEmpty()
            val gostOdigrao = s.guest_answers.orEmpty().size >= (s.total_questions ?: PITANJA_IZAZOVA)
            MojIzazov(s, rival, ime[rival] ?: "Igrač", (if (domacin) s.host_score else s.guest_score) ?: 0,
                (if (domacin) s.guest_score else s.host_score) ?: 0, gostOdigrao, !domacin && !gostOdigrao)
        }
    }.getOrDefault(emptyList())

    var faza by mutableStateOf(Faza.LOBI); private set
    var soba by mutableStateOf<Soba?>(null); private set
    var pitanja by mutableStateOf<List<Pitanje>>(emptyList()); private set
    var tekuce by mutableIntStateOf(0); private set
    var otkriveno by mutableStateOf(false); private set
    var greska by mutableStateOf<String?>(null); private set
    var radi by mutableStateOf(false); private set
    var rivalOtisao by mutableStateOf(false); private set
    var pocetakPitanja by mutableStateOf(System.currentTimeMillis()); private set
    /** Pomoć „Dodatno vreme” produžava samo moje tekuće pitanje. */
    var dodatnoSekundi by mutableIntStateOf(0)
    val rokMs get() = (SEKUNDI + dodatnoSekundi) * 1000L
    var kod by mutableStateOf("")

    private var osvezavanje: Job? = null

    val jaSamDomacin get() = soba?.host_id == sesija.nalog.value?.id
    val moji: List<Int?> get() = (if (jaSamDomacin) soba?.host_answers else soba?.guest_answers).orEmpty()
    val njegovi: List<Int?> get() = (if (jaSamDomacin) soba?.guest_answers else soba?.host_answers).orEmpty()
    val mojiPoeni get() = (if (jaSamDomacin) soba?.host_score else soba?.guest_score) ?: 0
    val njegoviPoeni get() = (if (jaSamDomacin) soba?.guest_score else soba?.host_score) ?: 0
    val ukupno get() = soba?.total_questions ?: 10
    val zlatno get() = tekuce >= ukupno
    val prikaz: Prikaz? get() = pitanja.getOrNull(tekuce)?.let { DuelMesanje.prikaz(it) }
    val odgovorioSam get() = tekuce < moji.size
    val odgovorioJe get() = tekuce < njegovi.size

    private fun filterId() = listOf("id" to "eq.${soba?.id}")
    private fun dekoduj(json: String) = Supabase.json.decodeFromString<List<Soba>>(json)

    fun napravi(brojPitanja: Int) = viewModelScope.launch {
        val id = sesija.nalog.value?.id ?: return@launch
        val token = sesija.vazeciToken() ?: return@launch
        radi = true
        runCatching {
            val p = Supabase.json.decodeFromString<List<Pitanje>>(
                Supabase.rpc("aplikacija_pitanja", mapOf("p_igra" to "opste", "p_broj" to minOf(80, brojPitanja + 10)), token),
            )
            require(p.size >= brojPitanja) { "Nema dovoljno pitanja za duel." }
            val noviKod = (1..5).map { "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".random() }.joinToString("")
            soba = dekoduj(Supabase.upisiVrati("game_rooms", mapOf(
                "room_code" to noviKod, "host_id" to id, "question_ids" to p.map { it.id }, "total_questions" to brojPitanja,
                "status" to "waiting", "game_format" to "q$brojPitanja", "quiz_type" to "pro",
            ), token)).first()
            pitanja = p
            faza = Faza.CEKANJE
            pratiSobu()
        }.onFailure { greska = it.message }
        radi = false
    }

    fun pridruzi() = viewModelScope.launch {
        val id = sesija.nalog.value?.id ?: return@launch
        val token = sesija.vazeciToken() ?: return@launch
        val k = kod.trim().uppercase()
        if (k.isEmpty()) return@launch
        radi = true
        runCatching {
            val s = dekoduj(Supabase.citaj("game_rooms", listOf("select" to "*", "room_code" to "eq.$k"), token)).firstOrNull()
                ?: error("Soba sa tim kodom ne postoji.")
            if (s.game_format == FORMAT_IZAZOVA) {
                // Izazov: igram ista pitanja; izazivačevi odgovori su već tu, pa se svaka runda otkriva čim odgovorim.
                check(s.guest_id == id) { "Ovaj izazov nije za tebe." }
                check(s.guest_answers.orEmpty().size < (s.total_questions ?: PITANJA_IZAZOVA)) { "Ovaj izazov si već odigrao." }
                soba = s
                val p = Supabase.json.decodeFromString<List<Pitanje>>(Supabase.rpc("aplikacija_pitanja_po_id", mapOf("p_igra" to "pro", "p_ids" to s.question_ids), token)).associateBy { it.id }
                pitanja = s.question_ids.mapNotNull { p[it] }
                tekuce = s.guest_answers.orEmpty().size
                faza = Faza.IGRA; pocetakPitanja = System.currentTimeMillis()
                pratiSobu()
                return@runCatching
            }
            check(s.status == "waiting") { "Igra je već počela ili završena." }
            check(s.host_id != id) { "Ne možeš da se pridružiš sopstvenoj sobi." }
            soba = dekoduj(Supabase.azuriraj("game_rooms", listOf("room_code" to "eq.$k", "guest_id" to "is.null"), mapOf("guest_id" to id), token))
                .firstOrNull() ?: error("Neko je već zauzeo ovo mesto.")
            val p = Supabase.json.decodeFromString<List<Pitanje>>(
                Supabase.rpc("aplikacija_pitanja_po_id", mapOf("p_igra" to "pro", "p_ids" to s.question_ids), token),
            ).associateBy { it.id }
            pitanja = s.question_ids.mapNotNull { p[it] }
            faza = Faza.CEKANJE
            pratiSobu()
        }.onFailure { greska = it.message }
        radi = false
    }

    fun zapocni() = viewModelScope.launch {
        val token = sesija.vazeciToken() ?: return@launch
        runCatching { Supabase.azuriraj("game_rooms", filterId(), mapOf("status" to "playing", "game_start_time" to Instant.now().toString()), token) }
    }

    private fun pratiSobu() {
        osvezavanje?.cancel()
        osvezavanje = viewModelScope.launch {
            while (isActive) {
                osvezi()
                delay(1000)
            }
        }
    }

    private suspend fun osvezi() {
        val token = sesija.vazeciToken() ?: return
        val nova = runCatching { dekoduj(Supabase.citaj("game_rooms", listOf("select" to "*") + filterId(), token)).firstOrNull() }.getOrNull() ?: return
        soba = nova
        when {
            faza == Faza.CEKANJE && nova.status == "playing" -> { faza = Faza.IGRA; pocetakPitanja = System.currentTimeMillis() }
            faza == Faza.IGRA && nova.status == "finished" && !jeIzazov -> { rivalOtisao = true; zavrsi() }
            faza == Faza.IGRA && !otkriveno -> {
                val isteklo = System.currentTimeMillis() - pocetakPitanja >= rokMs
                // U izazovu rival ne igra uživo: runda se otkriva čim ja odgovorim.
                if ((odgovorioSam && (odgovorioJe || jeIzazov)) || isteklo) otkrij()
            }
            else -> Unit
        }
    }

    /** Tačan odgovor +10, netačan ili istek −5 (najmanje 0), kao na vebu. */
    fun odgovori(izabran: Int?) = viewModelScope.launch {
        if (faza != Faza.IGRA || odgovorioSam) return@launch
        val p = prikaz ?: return@launch
        val token = sesija.vazeciToken() ?: return@launch
        val novi = maxOf(0, mojiPoeni + if (izabran == p.tacan) POENA_TACNO else -POENA_NETACNO)
        val odgovori = moji.toMutableList().apply { while (size < tekuce) add(null); add(izabran) }
        val polja = if (jaSamDomacin) mapOf("host_answers" to odgovori, "host_score" to novi) else mapOf("guest_answers" to odgovori, "guest_score" to novi)
        runCatching { dekoduj(Supabase.azuriraj("game_rooms", filterId(), polja, token)).firstOrNull() }.getOrNull()?.let { soba = it }
    }

    private fun otkrij() {
        otkriveno = true
        viewModelScope.launch { delay(3500); sledece() }
    }

    private fun sledece() {
        if (faza != Faza.IGRA) return
        val sledeci = tekuce + 1
        // Posle glavnog dela: nerešeno ide na zlatno pitanje dok ih ima.
        // Izazov nema zlatno pitanje: rival nije tu da ga odigra.
        if (sledeci >= ukupno && (jeIzazov || !(mojiPoeni == njegoviPoeni && sledeci < pitanja.size))) {
            // Izazivač samo označava da je završio; sobu zatvara rival kad odigra.
            val polja = if (jeIzazov && jaSamDomacin) mapOf("host_finished" to true) else if (jeIzazov) mapOf("guest_finished" to true, "status" to "finished") else mapOf("status" to "finished")
            viewModelScope.launch {
                sesija.vazeciToken()?.let { t -> runCatching { Supabase.azuriraj("game_rooms", filterId(), polja, t) } }
                zavrsi()
            }
            return
        }
        tekuce = sledeci
        otkriveno = false
        pocetakPitanja = System.currentTimeMillis(); dodatnoSekundi = 0
    }

    /** Napuštanje: rival dobija +50 i soba se zatvara, da bekstvo iz gubitka nije besplatno. */
    suspend fun napusti() {
        osvezavanje?.cancel()
        if (soba == null || faza == Faza.LOBI || faza == Faza.KRAJ) return
        // Izazov se ne zatvara izlaskom: odgovoreno ostaje, ostatak se računa kao istek.
        if (jeIzazov) return
        val token = sesija.vazeciToken() ?: return
        val polja = mutableMapOf<String, Any?>("status" to "finished")
        if (faza == Faza.IGRA) polja[if (jaSamDomacin) "guest_score" else "host_score"] = njegoviPoeni + BONUS_NAPUSTANJA
        runCatching { Supabase.azuriraj("game_rooms", filterId(), polja, token) }
    }

    private fun zavrsi() {
        osvezavanje?.cancel()
        faza = Faza.KRAJ
        viewModelScope.launch {
            val token = sesija.vazeciToken() ?: return@launch
            runCatching { dekoduj(Supabase.citaj("game_rooms", listOf("select" to "*") + filterId(), token)).firstOrNull() }.getOrNull()?.let { soba = it }
        }
    }
}

/** Trivia duel: napravi sobu ili uđi kodom, pa ista pitanja jedan na jedan. */
@Composable
fun DuelEkran(sesija: Sesija, izazovi: String? = null, kodSobe: String? = null, izadji: () -> Unit) {
    val opseg = rememberCoroutineScope()
    var kljuc by remember { mutableIntStateOf(0) }
    val m: DuelModel = viewModel(key = "duel-$kljuc") { DuelModel(sesija) }
    LaunchedEffect(kljuc) {
        if (kljuc != 0 || m.faza != DuelModel.Faza.LOBI) return@LaunchedEffect
        if (izazovi != null) m.izazovi(izazovi) else if (kodSobe != null) { m.kod = kodSobe; m.pridruzi() }
    }
    var potvrda by remember { mutableStateOf(false) }
    val nalog = sesija.nalog.value
    BackHandler { if (m.faza == DuelModel.Faza.IGRA) potvrda = true else opseg.launch { m.napusti(); izadji() } }

    Box(Modifier.fillMaxSize()) {
        Papir()
        if (nalog == null) {
            GreskaKartica("Duel traži nalog", "Prijavi se u kartici Profil, da bi rival znao protiv koga igra.", izadji)
        } else when (m.faza) {
            DuelModel.Faza.LOBI -> Lobi(m, izadji)
            DuelModel.Faza.CEKANJE -> Column(
                Modifier.align(Alignment.Center).padding(20.dp).pop().padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                MaskotaSlika(Maskota.BLOOP, 110.dp)
                Oznaka("Kod sobe")
                Text(m.soba?.room_code.orEmpty(), style = naslov(54.sp).copy(letterSpacing = 4.sp))
                if (m.jaSamDomacin) {
                    if (m.soba?.guest_id == null) Text("Pošalji kod prijatelju. Čekamo da uđe…", style = tekst(16.sp, boja = Boje.sivaTekst))
                    else { Text("Rival je u sobi!", style = tekst(17.sp, FontWeight.Bold, Boje.teal)); Dugme("Počni duel", vrsta = VrstaDugmeta.ZUTO) { m.zapocni() } }
                } else Text("U sobi si. Čekamo da domaćin pokrene duel…", style = tekst(16.sp, boja = Boje.sivaTekst))
                Dugme("Odustani", vrsta = VrstaDugmeta.SEKUNDARNO) { opseg.launch { m.napusti(); izadji() } }
            }
            DuelModel.Faza.IGRA -> Igra(m) { potvrda = true }
            DuelModel.Faza.KRAJ -> {
                val pobeda = m.mojiPoeni > m.njegoviPoeni
                Column(Modifier.align(Alignment.Center).padding(20.dp).pop().padding(24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    MaskotaSlika(if (pobeda) Maskota.BLOOP else Maskota.ZIG, 120.dp)
                    if (m.cekaRivala) {
                        Text("Odigrao si!", style = naslov(40.sp))
                        Text("Rival ima 24 h da odigra ista pitanja. Ishod stiže u Sanduče.", style = tekst(15.sp, boja = Boje.sivaTekst))
                    } else Text(if (m.mojiPoeni == m.njegoviPoeni) "Nerešeno!" else if (pobeda) "Pobeda!" else "Poraz", style = naslov(40.sp))
                    if (m.rivalOtisao) Text("Rival je napustio duel.", style = tekst(15.sp, boja = Boje.sivaTekst))
                    Rezultati(m)
                    Dugme("Novi duel", vrsta = VrstaDugmeta.ZUTO) { kljuc++ }
                    Dugme("Nazad", vrsta = VrstaDugmeta.SEKUNDARNO, radnja = izadji)
                }
            }
        }
        if (potvrda) Dijalog("Napuštaš duel?", "Rival dobija 50 poena i pobedu.", "Izađi", "Ostani",
            potvrdi = { opseg.launch { m.napusti(); izadji() } }, zatvori = { potvrda = false })
    }
}

@Composable
private fun Lobi(m: DuelModel, izadji: () -> Unit) {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
        KrugZatvori("Nazad", izadji)
        Box(Modifier.fillMaxWidth().pop(Boje.mastilo)) {
            MaskotaSlika(Maskota.BLOOP, 100.dp, Modifier.align(Alignment.BottomEnd))
            Column(Modifier.padding(22.dp).padding(end = 90.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Oznaka("Jedan na jedan", Boje.zuta)
                Text("Trivia duel", style = naslov(40.sp).copy(color = Color.White))
                Text("Ista pitanja za oboje. Tačno +10, netačno −5. Nerešeno ide na zlatno pitanje.", style = tekst(15.sp, FontWeight.SemiBold, Color.White.copy(alpha = 0.9f)))
            }
        }
        Column(Modifier.fillMaxWidth().mirna().padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("Napravi sobu", style = naslov(24.sp))
            DuelModel.FORMATI.forEach { (broj, opis) ->
                Row(
                    Modifier.fillMaxWidth().background(Boje.kartica, RoundedCornerShape(16.dp)).border(1.5.dp, Boje.mastilo, RoundedCornerShape(16.dp))
                        .clickable(enabled = !m.radi, role = Role.Button) { m.napravi(broj) }.padding(14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(Modifier.weight(1f)) {
                        Text("$broj pitanja", style = tekst(17.sp, FontWeight.Bold))
                        Text(opis, style = tekst(13.sp, boja = Boje.sivaTekst))
                    }
                    Text("›", style = tekst(22.sp, FontWeight.Bold))
                }
            }
        }
        Column(Modifier.fillMaxWidth().mirna().padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("Uđi kodom", style = naslov(24.sp))
            OutlinedTextField(m.kod, { m.kod = it.uppercase() }, Modifier.fillMaxWidth(), placeholder = { Text("KOD SOBE") }, singleLine = true,
                textStyle = naslov(24.sp), keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Characters),
                shape = RoundedCornerShape(16.dp), colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = Boje.mastilo, unfocusedBorderColor = Boje.mastilo,
                    focusedContainerColor = Boje.kartica, unfocusedContainerColor = Boje.kartica))
            Dugme("Uđi u sobu", omoguceno = !m.radi && m.kod.isNotBlank()) { m.pridruzi() }
        }
        m.greska?.let { Text(it, style = tekst(15.sp, FontWeight.SemiBold, Boje.crvena)) }
        MojiIzazovi(m)
    }
}

/** Poslati i primljeni izazovi: na meni je da igram, čekam rivala ili ishod. */
@Composable
private fun MojiIzazovi(m: DuelModel) {
    var lista by remember { mutableStateOf<List<DuelModel.MojIzazov>>(emptyList()) }
    LaunchedEffect(Unit) { lista = m.mojiIzazovi() }
    if (lista.isEmpty()) return
    Column(Modifier.fillMaxWidth().mirna().padding(20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text("Izazovi", style = naslov(24.sp))
        lista.forEach { iz ->
            Row(Modifier.fillMaxWidth().clickable(enabled = iz.naMeni) { m.kod = iz.soba.room_code; m.pridruzi() }.padding(vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(iz.rivalIme, style = tekst(16.sp, FontWeight.SemiBold))
                    Text(when {
                        iz.naMeni -> "Izazvao te je · igraj sad"
                        !iz.zavrsen -> "Čeka se rival"
                        iz.ja > iz.on -> "Pobeda ${iz.ja} : ${iz.on}"
                        iz.ja < iz.on -> "Poraz ${iz.ja} : ${iz.on}"
                        else -> "Nerešeno ${iz.ja} : ${iz.on}"
                    }, style = tekst(13.sp, if (iz.naMeni) FontWeight.Bold else FontWeight.Normal, if (iz.naMeni) Boje.teal else Boje.sivaTekst))
                }
                if (iz.naMeni) Text("›", style = tekst(22.sp, FontWeight.Bold))
            }
        }
    }
}

@Composable
private fun Rezultati(m: DuelModel) {
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        listOf(Triple("Ti", m.mojiPoeni, Boje.teal), Triple("Rival", m.njegoviPoeni, Boje.roze)).forEach { (ko, poeni, boja) ->
            Column(Modifier.weight(1f).background(boja, RoundedCornerShape(14.dp)).border(1.5.dp, Boje.mastilo, RoundedCornerShape(14.dp)).padding(vertical = 8.dp),
                horizontalAlignment = Alignment.CenterHorizontally) {
                Text("$poeni", style = naslov(22.sp).copy(color = Color.White))
                Text(ko.uppercase(), style = tekst(11.sp, FontWeight.Bold, Color.White))
            }
        }
    }
}

@Composable
private fun Igra(m: DuelModel, izlaz: () -> Unit) {
    var sada by remember { mutableStateOf(System.currentTimeMillis()) }
    var eliminisani by remember(m.tekuce) { mutableStateOf(setOf<Int>()) }
    var pomocIskoriscena by remember { mutableStateOf(false) }
    LaunchedEffect(m.tekuce) { while (true) { sada = System.currentTimeMillis(); if (sada - m.pocetakPitanja >= m.rokMs && !m.odgovorioSam) m.odgovori(null); delay(500) } }
    val ostalo = ((m.rokMs - (sada - m.pocetakPitanja)) / 1000).coerceAtLeast(0)
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            KrugZatvori("Napusti duel", izlaz)
            Box(Modifier.weight(1f)) { Rezultati(m) }
        }
        val p = m.prikaz ?: return@Column
        val moj = m.moji.getOrNull(m.tekuce)
        val njegov = if (m.otkriveno) m.njegovi.getOrNull(m.tekuce) else null
        Column(Modifier.fillMaxWidth().pop(if (m.zlatno) Boje.zuta.copy(red = 0.96f, green = 0.64f, blue = 0.24f) else Boje.zuta).padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Row {
                Oznaka(if (m.zlatno) "Zlatno pitanje" else "Pitanje ${m.tekuce + 1} od ${m.ukupno}", Boje.mastilo)
                Spacer(Modifier.weight(1f)); Text("$ostalo", style = naslov(22.sp))
            }
            Text(p.tekst, style = naslov(23.sp))
            p.opcije.forEachIndexed { i, o ->
                val stanje = when {
                    !m.otkriveno -> if ((m.odgovorioSam && moj != i) || i in eliminisani) StanjeOdgovora.BLEDO else StanjeOdgovora.OBICNO
                    i == p.tacan -> StanjeOdgovora.TACNO
                    moj == i -> StanjeOdgovora.NETACNO
                    else -> StanjeOdgovora.BLEDO
                }
                Box {
                    OdgovorDugme("ABCD"[i].toString(), o, stanje, omoguceno = !m.odgovorioSam && i !in eliminisani) { m.odgovori(i) }
                    if (njegov == i) Text("Rival", style = tekst(13.sp, FontWeight.Bold, Boje.roze),
                        modifier = Modifier.align(Alignment.CenterEnd).padding(end = 14.dp))
                }
            }
            if (m.odgovorioSam && !m.otkriveno) Text("Čekamo rivala…", style = tekst(15.sp, FontWeight.SemiBold, Boje.sivaTekst))
        }
        if (!m.odgovorioSam) PomociTraka(pomocIskoriscena,
            { eliminisani = (0 until 4).filter { it != p.tacan }.shuffled().take(2).toSet() },
            { (0 until 4).filter { it != p.tacan && it !in eliminisani }.randomOrNull()?.let { eliminisani = eliminisani + it } },
            { m.dodatnoSekundi += 10 }, { m.odgovori(null) }) { pomocIskoriscena = true }
    }
}
