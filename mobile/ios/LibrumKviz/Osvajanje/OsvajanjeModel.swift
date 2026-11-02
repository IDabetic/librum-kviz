import Foundation
import Observation

/// Tok partije: pitanja, potezi botova i odbrana čoveka. Pravila su u Pravila.swift.
@Observable
@MainActor
final class OsvajanjeModel {
    enum Vrsta: Equatable { case snabdevanje, napad, odbrana }
    struct Otvoreno: Identifiable, Equatable {
        let id = UUID()
        let vrsta: Vrsta
        let prikaz: Prikaz
        var odakle: String?
        var kuda: String?
        var rival: Odgovor?
    }

    private(set) var stanje: Stanje
    private(set) var spremno = false
    private(set) var greska: String?
    var izabrana: String?
    /// Tačni i netačni odgovori igrača u partiji, za napredak (XP, bedževi).
    private(set) var tacnih = 0
    private(set) var netacnih = 0
    private(set) var zbirMs = 0
    var utvrdjivanje = false
    private(set) var otvoreno: Otvoreno?
    private(set) var poruka: String?

    private var slucajno: Slucajno
    private var spil = Spil([])
    private var botRadi = false
    private var odbrana: CheckedContinuation<Odgovor, Never>?
    private let pauzaBota: Duration = .milliseconds(700)

    init(krugova: Int, tezina: Tezina, ime: String?) {
        var s = Slucajno(seme: UInt32(truncatingIfNeeded: Int(Date().timeIntervalSince1970 * 1000)))
        stanje = Stanje.nova(krugova: krugova, tezina: tezina, slucajno: &s, ime: ime)
        slucajno = s
    }

    var covekNaPotezu: Bool { stanje.faza != .kraj && stanje.trenutni.covek }

    var mete: [String] {
        guard let izabrana, !utvrdjivanje, covekNaPotezu else { return [] }
        return stanje.mete(izabrana)
    }

    var uputstvo: String {
        guard covekNaPotezu else { return stanje.faza == .kraj ? "Kraj partije" : "\(stanje.trenutni.ime) je na potezu…" }
        switch stanje.faza {
        case .raspored: return "Dodirni svoje oblasti: još \(stanje.zaRaspored)"
        case .napad:
            if utvrdjivanje { return "Izaberi oblast, pa susednu svoju" }
            return izabrana == nil ? "Izaberi oblast sa 2+ vojske · bitka \(stanje.bitaka)/\(Pravila.bitakaPoPotezu)" : "Izaberi metu"
        default: return "Snabdevanje…"
        }
    }

    func pokreni() async {
        do {
            spil = Spil(try await PaketPitanja.deljeni.ucitaj())
            spremno = true
            pocniPotez(stanje)
        } catch {
            greska = error.localizedDescription
        }
    }

    // MARK: Čovek

    func dodir(_ id: String) {
        guard covekNaPotezu, otvoreno == nil, let oblast = stanje.oblasti[id] else { return }
        let moja = oblast.vlasnik == stanje.trenutni.id
        switch stanje.faza {
        case .raspored:
            if moja { stanje = stanje.rasporedi(id) }
        case .napad:
            if utvrdjivanje {
                if let izvor = izabrana, moja, Mapa.susedi(izvor).contains(id) {
                    stanje = stanje.utvrdi(odakle: izvor, kuda: id, broj: (stanje.oblasti[izvor]?.vojske ?? 1) - 1)
                    utvrdjivanje = false; izabrana = nil; javi("Vojske prebačene")
                } else {
                    izabrana = moja ? id : nil
                }
            } else if moja {
                izabrana = stanje.mete(id).isEmpty ? nil : id
            } else if let izvor = izabrana, stanje.mete(izvor).contains(id) {
                let rival = oblast.vlasnik != nil ? stanje.botOdgovor(&slucajno) : nil
                otvoreno = Otvoreno(vrsta: .napad, prikaz: spil.sledece(), odakle: izvor, kuda: id, rival: rival)
            }
        default: break
        }
    }

    func rasporediSam() { stanje = stanje.botRasporedi() }

    func prekidacUtvrdjivanja() { utvrdjivanje.toggle(); izabrana = nil }

    func krajPoteza() {
        izabrana = nil; utvrdjivanje = false
        pocniPotez(stanje.zavrsiPotez())
    }

    /// Odgovor sa kartice pitanja (nil = isteklo vreme).
    func odgovoreno(_ izabran: Int?, ms: Int) {
        guard let o = otvoreno else { return }
        otvoreno = nil
        let moj = Odgovor(tacan: izabran == o.prikaz.tacan, ms: ms)
        if moj.tacan { tacnih += 1 } else { netacnih += 1 }
        zbirMs += ms
        switch o.vrsta {
        case .snabdevanje:
            stanje = stanje.snabdevanje(tacno: moj.tacan)
            javi(moj.tacan ? "Tačno! Raspoređuješ \(stanje.zaRaspored)" : "Netačno. Dobijaš samo \(stanje.zaRaspored)")
        case .odbrana:
            odbrana?.resume(returning: moj)
            odbrana = nil
        case .napad:
            guard let odakle = o.odakle, let kuda = o.kuda else { return }
            let (novo, ishod) = stanje.razresiBitku(odakle: odakle, kuda: kuda, napadac: moj, branilac: o.rival)
            stanje = novo
            if ishod.osvojeno {
                javi(ishod.plen ? "Prestonica pala! +5 plena" : ishod.proboj ? "Proboj! +2 vojske" : "Osvojeno! Cepaj dalje")
                izabrana = novo.mete(kuda).isEmpty ? nil : kuda
            } else {
                javi(ishod.gubitakNapadaca == 0 ? "Branilac gubi \(ishod.gubitakBranioca)" : "Gubiš \(ishod.gubitakNapadaca)")
                if novo.mete(odakle).isEmpty { izabrana = nil }
            }
        }
    }

    // MARK: Tok poteza

    private func pocniPotez(_ novo: Stanje) {
        stanje = novo
        guard novo.faza == .snabdevanje else { return }
        if novo.trenutni.covek {
            otvoreno = Otvoreno(vrsta: .snabdevanje, prikaz: spil.sledece())
        } else {
            Task { await potezBota() }
        }
    }

    private func potezBota() async {
        guard !botRadi else { return }
        botRadi = true
        defer { botRadi = false }
        stanje = stanje.snabdevanje(tacno: slucajno.sledeci() < stanje.tacnostBota).botRasporedi()
        try? await Task.sleep(for: pauzaBota)
        while let napad = stanje.botSledeciNapad() {
            izabrana = napad.odakle
            try? await Task.sleep(for: pauzaBota)
            let napadac = stanje.botOdgovor(&slucajno)
            var branilac: Odgovor?
            if let vlasnik = stanje.oblasti[napad.kuda]?.vlasnik {
                if stanje.igraci.first(where: { $0.id == vlasnik })?.covek == true {
                    javi("\(stanje.trenutni.ime) napada \(Mapa.oblast(napad.kuda).ime)! Brani se")
                    branilac = await withCheckedContinuation { nastavak in
                        odbrana = nastavak
                        otvoreno = Otvoreno(vrsta: .odbrana, prikaz: spil.sledece(), odakle: napad.odakle, kuda: napad.kuda)
                    }
                } else {
                    branilac = stanje.botOdgovor(&slucajno)
                }
            }
            stanje = stanje.razresiBitku(odakle: napad.odakle, kuda: napad.kuda, napadac: napadac, branilac: branilac).0
            try? await Task.sleep(for: pauzaBota)
        }
        izabrana = nil
        botRadi = false
        pocniPotez(stanje.zavrsiPotez())
    }

    private func javi(_ tekst: String) {
        poruka = tekst
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            if poruka == tekst { poruka = nil }
        }
    }
}
