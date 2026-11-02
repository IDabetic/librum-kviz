import AVFoundation

/// Tihi zvuci igre (mobile/zvuci). Poštuje prekidač „Zvučni efekti” i nečujni režim
/// telefona (kategorija .ambient), i ne prekida muziku koju igrač sluša.
@MainActor
enum Zvuk {
    enum Vrsta: String { case tacno, netacno, isteklo, tikanje, odbrojavanje, bedz, pobeda, kraj, osvojeno, cekanje }

    private static var plejeri: [Vrsta: AVAudioPlayer] = [:]
    private static var podeseno = false

    static func pusti(_ v: Vrsta, jacina: Float = 0.6, ponavljaj: Bool = false) {
        guard Napredak.deljeni.s.zvuk else { return }
        if !podeseno {
            try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            podeseno = true
        }
        let p = plejeri[v] ?? Bundle.main.url(forResource: v.rawValue, withExtension: "m4a", subdirectory: "zvuci").flatMap { try? AVAudioPlayer(contentsOf: $0) }
        guard let p else { return }
        plejeri[v] = p
        p.volume = jacina
        p.numberOfLoops = ponavljaj ? -1 : 0
        p.currentTime = 0
        p.play()
    }

    static func stani(_ v: Vrsta) { plejeri[v]?.stop() }
}
