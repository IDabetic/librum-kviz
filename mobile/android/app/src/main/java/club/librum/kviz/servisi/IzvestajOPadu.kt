package club.librum.kviz.servisi

import android.content.Context
import club.librum.kviz.BuildConfig
import java.io.File

/**
 * Pad aplikacije (vlasnik 03.11: pad usred partije koji nije mogao da se ponovi): stek se upiše u fajl pre gašenja,
 * a pri sledećem pokretanju ide u `izvestaji_o_padu` (bez ličnih podataka), kao MetricKit na iOS-u.
 *
 * @example IzvestajOPadu.ukljuci(applicationContext); lifecycleScope.launch { IzvestajOPadu.posaljiSacuvan(applicationContext) }
 */
object IzvestajOPadu {
    private const val FAJL = "poslednji-pad.txt"
    private const val NAJVISE_ZNAKOVA = 60_000

    fun ukljuci(ctx: Context) {
        val prethodni = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { nit, greska ->
            runCatching { File(ctx.filesDir, FAJL).writeText("${nit.name}\n${greska.stackTraceToString()}".take(NAJVISE_ZNAKOVA)) }
            prethodni?.uncaughtException(nit, greska)
        }
    }

    suspend fun posaljiSacuvan(ctx: Context) {
        val f = File(ctx.filesDir, FAJL)
        if (!f.exists()) return
        val red = mapOf(
            "platforma" to "android",
            "verzija" to "${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})",
            "izvestaj" to mapOf("stek" to f.readText(), "uredjaj" to "${android.os.Build.MANUFACTURER} ${android.os.Build.MODEL}, Android ${android.os.Build.VERSION.RELEASE}"),
        )
        // Fajl se briše tek posle uspešnog slanja, da se izveštaj ne izgubi bez mreže.
        runCatching { Supabase.zahtev("rest/v1/izvestaji_o_padu", "POST", Supabase.objekat(*red.toList().toTypedArray())) }
            .onSuccess { f.delete() }
    }
}
