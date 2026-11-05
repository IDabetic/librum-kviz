import AVFoundation

/// Tihi zvuci igre (mobile/zvuci). Poštuje prekidač „Zvučni efekti” i nečujni režim
/// telefona (kategorija .ambient), i ne prekida muziku koju igrač sluša.
@MainActor
enum Zvuk {
    /// Ime fajla u mobile/zvuci (.m4a). Zvukovi posle tacno…cekanje su iz Magnific/ElevenLabs generatora (vlasnik 03.11).
    enum Vrsta: String {
        case tacno, netacno, isteklo, tikanje, odbrojavanje, bedz, pobeda, kraj, osvojeno, cekanje
        case botNapada = "bot_napada", botOsvaja = "bot_osvaja", uzbuna, tvojPotez = "tvoj_potez", noviKrug = "novi_krug"
        case pojacanja, vojskaStavi = "vojska_stavi", izborDrzave = "izbor_drzave", kartaDobijena = "karta_dobijena"
        case kartaOdigrana = "karta_odigrana", pomocVojske = "pomoc_vojske", prestonicaPala = "prestonica_pala"
        case izgubioDrzavu = "izgubio_drzavu", povlacenje, savez, izdaja, poruka, dogadjaj, cudo, misija
        case petSekundi = "pet_sekundi", kombo
        case nivoGore = "nivo_gore", niz, zivot, slovoDa = "slovo_da", slovoNe = "slovo_ne", protivnikUsao = "protivnik_usao", obavestenje
        // Karijera (alati/karijera_muzika.py): muzika po mestu i kratki zvuci.
        case karijeraUvod = "karijera_uvod", karijeraKorporacija = "karijera_korporacija", karijeraFirma = "karijera_firma"
        case karijeraPosao = "karijera_posao", karijeraOffice = "karijera_office", karijeraProbniKraj = "karijera_probni_kraj"
        case karijeraDuel = "karijera_duel", karijeraOdbrana = "karijera_odbrana", karijeraUnapredjenje = "karijera_unapredjenje"
        case karijeraFirma2 = "karijera_firma_2", karijeraFirma3 = "karijera_firma_3", karijeraFirma4 = "karijera_firma_4"
        case karijeraRekord = "karijera_rekord", karijeraUspeh = "karijera_uspeh", karijeraKasa = "karijera_kasa", karijeraZvono = "karijera_zvono"
    }

    private static var plejeri: [Vrsta: AVAudioPlayer] = [:]
    private static var podeseno = false

    static func pusti(_ v: Vrsta, jacina: Float = 0.6, ponavljaj: Bool = false) {
        guard Napredak.deljeni.s.zvuk else { return }
        #if DEBUG
        // Provera na simulatoru (`-bezZvuka`): bez zvuka na vlasnikovom Macu.
        if ProcessInfo.processInfo.arguments.contains("-bezZvuka") { return }
        #endif
        if !podeseno {
            try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            podeseno = true
        }
        // Fajl koji još ne postoji se preskače (app ćuti); vlasnik ubacuje m4a, mp3 ili wav pod istim imenom.
        let p = plejeri[v] ?? ["m4a", "mp3", "wav"].lazy.compactMap { Bundle.main.url(forResource: v.rawValue, withExtension: $0, subdirectory: "zvuci") }
            .first.flatMap { try? AVAudioPlayer(contentsOf: $0) }
        guard let p else { return }
        plejeri[v] = p
        p.volume = jacina
        p.numberOfLoops = ponavljaj ? -1 : 0
        p.currentTime = 0
        p.play()
    }

    static func stani(_ v: Vrsta) { plejeri[v]?.stop() }

    /// Izlazak iz igre: utišava sve što još svira (petlje i zvuke koji su upravo krenuli).
    static func staniSve() { plejeri.values.forEach { $0.stop() } }
}
