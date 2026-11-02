package club.librum.kviz.servisi

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.serialization.Serializable

@Serializable
private data class Profil(val nickname: String? = null, val first_name: String? = null)

data class Nalog(val id: String, val email: String?, val nadimak: String?)

/**
 * Prijavljen korisnik. Tokeni su u privatnim podešavanjima aplikacije (MODE_PRIVATE),
 * nedostupnim drugim aplikacijama; osvežavaju se pred istek.
 */
class Sesija(context: Context) {
    private val prefs = context.getSharedPreferences("sesija", Context.MODE_PRIVATE)
    private var token: Token? = prefs.getString("token", null)?.let { runCatching { Supabase.json.decodeFromString<Token>(it) }.getOrNull() }
    private val _nalog = MutableStateFlow(token?.let { Nalog(it.user.id, it.user.email, prefs.getString("nadimak", null)) })
    val nalog: StateFlow<Nalog?> = _nalog

    suspend fun prijava(email: String, lozinka: String) {
        val t = Supabase.prijava(email.trim().lowercase(), lozinka)
        sacuvaj(t)
        ucitajNadimak()
    }

    suspend fun registracija(email: String, lozinka: String, ime: String, prezime: String, nadimak: String) {
        Supabase.registracija(email.trim().lowercase(), lozinka, ime, prezime, nadimak)
    }

    suspend fun odjava() {
        token?.let { Supabase.odjava(it.access_token) }
        ocisti()
    }

    /** Trajno briše nalog na serveru (RPC obrisi_moj_nalog), pa odjavljuje. */
    suspend fun obrisiNalog() {
        val pristup = vazeciToken() ?: return
        Supabase.rpc("obrisi_moj_nalog", token = pristup)
        ocisti()
    }

    /** Token koji važi bar još minut; osvežava ga po potrebi. */
    suspend fun vazeciToken(): String? {
        val t = token ?: return null
        val istice = t.expires_at ?: return t.access_token
        if (istice - System.currentTimeMillis() / 1000 > 60) return t.access_token
        return runCatching { Supabase.osvezi(t.refresh_token) }
            .onSuccess { sacuvaj(it) }
            .onFailure { ocisti() }
            .getOrNull()?.access_token
    }

    suspend fun ucitajNadimak() {
        val id = token?.user?.id ?: return
        val redovi = runCatching {
            Supabase.json.decodeFromString<List<Profil>>(
                Supabase.citaj("public_profiles", listOf("select" to "nickname,first_name", "id" to "eq.$id")),
            )
        }.getOrNull() ?: return
        val nadimak = redovi.firstOrNull()?.let { it.nickname ?: it.first_name }
        prefs.edit().putString("nadimak", nadimak).apply()
        _nalog.value = _nalog.value?.copy(nadimak = nadimak)
    }

    private fun sacuvaj(t: Token) {
        token = t
        prefs.edit().putString("token", Supabase.json.encodeToString(Token.serializer(), t)).apply()
        _nalog.value = Nalog(t.user.id, t.user.email, _nalog.value?.nadimak)
    }

    private fun ocisti() {
        token = null
        prefs.edit().clear().apply()
        _nalog.value = null
    }
}
