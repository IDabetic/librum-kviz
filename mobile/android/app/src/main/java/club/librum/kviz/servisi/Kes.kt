package club.librum.kviz.servisi

/**
 * Poslednji odgovor servera po ključu, u memoriji dok aplikacija radi (kao iOS Kes): ekran se pri ponovnom
 * otvaranju odmah crta iz keša umesto skeleta, a sveži podaci stižu tiho (vlasnik 04.11: ekrani su treptali).
 *
 * @example Kes.ucitaj<List<RedListe>>("rang-0-1-0") ?: null; Kes.sacuvaj("rang-0-1-0", redovi)
 */
object Kes {
    private val memorija = java.util.concurrent.ConcurrentHashMap<String, Any>()

    @Suppress("UNCHECKED_CAST")
    fun <T> ucitaj(kljuc: String): T? = memorija[kljuc] as? T

    fun sacuvaj(kljuc: String, vrednost: Any) { memorija[kljuc] = vrednost }

    /** Odjava: drugi nalog ne sme da vidi tuđe podatke. */
    fun obrisiSve() = memorija.clear()
}
