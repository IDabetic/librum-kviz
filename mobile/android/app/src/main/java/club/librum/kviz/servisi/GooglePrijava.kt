package club.librum.kviz.servisi

import android.content.Context
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.NoCredentialException
import club.librum.kviz.BuildConfig
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import java.security.MessageDigest
import java.security.SecureRandom

/**
 * Google prijava preko Credential Managera: Google vraća id_token za veb klijent (GOOGLE_WEB_CLIENT_ID),
 * a Supabase ga proverava sa istim nonce-om (Google dobija SHA-256, Supabase sirovi). Paket i SHA-1 potpisa
 * su upisani u Google Cloud „librum-kviz” kao Android klijenti (upload i debug ključ).
 *
 * @example val (idToken, nonce) = GooglePrijava.token(context) ?: return; sesija.prijavaGoogle(idToken, nonce)
 */
object GooglePrijava {
    /** id_token i sirovi nonce, ili null kad je igrač zatvorio Google prozor. */
    suspend fun token(context: Context): Pair<String, String>? {
        val nonce = ByteArray(16).also { SecureRandom().nextBytes(it) }.joinToString("") { "%02x".format(it) }
        val hes = MessageDigest.getInstance("SHA-256").digest(nonce.toByteArray()).joinToString("") { "%02x".format(it) }
        val opcija = GetSignInWithGoogleOption.Builder(BuildConfig.GOOGLE_WEB_CLIENT_ID).setNonce(hes).build()
        val odgovor = try {
            CredentialManager.create(context).getCredential(context, GetCredentialRequest.Builder().addCredentialOption(opcija).build())
        } catch (e: GetCredentialCancellationException) {
            return null
        } catch (e: NoCredentialException) {
            throw Greska("Na telefonu nema Google naloga. Dodaj ga u podešavanjima ili se prijavi email adresom.")
        } catch (e: Exception) {
            throw Greska("Google prijava nije uspela. Pokušaj ponovo.")
        }
        val c = odgovor.credential
        if (c !is CustomCredential || c.type != GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) throw Greska("Google prijava nije uspela.")
        return GoogleIdTokenCredential.createFrom(c.data).idToken to nonce
    }
}
