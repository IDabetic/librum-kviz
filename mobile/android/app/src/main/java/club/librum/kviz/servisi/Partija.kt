package club.librum.kviz.servisi

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

private val pozadina = CoroutineScope(SupervisorJob() + Dispatchers.IO)

/** Kraj svake partije: lokalni napredak (XP, bedževi, niz) i rezultat za rang listu po igri. */
fun zavrsiPartiju(sesija: Sesija, igra: String, poeni: Int, tacnih: Int, netacnih: Int, kviz: String? = null, kategorija: String? = null,
                  brzih: Int = 0, pobeda: Boolean = false, prosekMs: Int? = null): Napredak.Ishod {
    val n = Napredak.deljeni
    val pomoc = n.pomocUPartiji
    val ishod = n.zabeleziIgru(kviz ?: igra, tacnih, netacnih, kategorija, brzih, pobeda, prosekMs)
    n.pomocUPartiji = null
    pozadina.launch { sesija.upisiRezultat(igra, poeni, tacnih, netacnih, prosekMs, pomoc) }
    return ishod
}

fun prosek(zbir: Int, broj: Int): Int? = if (broj > 0) zbir / broj else null
