import Foundation
import Observation

/// Tok partije: pitanja, potezi botova i odbrana čoveka. Pravila su u Pravila.swift.
@Observable
@MainActor
final class OsvajanjeModel {
    enum Vrsta: Equatable { case snabdevanje }
    struct Otvoreno: Identifiable, Equatable {
        let id = UUID()
        let vrsta: Vrsta
        let prikaz: Prikaz
        var odakle: String?
        var kuda: String?
        var rival: Odgovor?
    }

    /// Bitka za državu: uvod (država, činjenice, odbrojavanje), pa pitanja, pa rezultat.
    struct Bitka: Identifiable, Equatable {
        enum Korak: Equatable { case uvod, pitanja, rezultat }
        let id = UUID()
        let napadam: Bool
        let odakle: String
        let kuda: String
        let uslov: Stanje.Uslov
        var prikazi: [Prikaz]
        /// Raste kad pomoć „Preskok” zameni pitanje, da se kartica pitanja nacrta iznova.
        var zamena = 0
        var korak: Korak = .uvod
        var redni = 0
        var tacnih = 0
        var ms = 0
        /// Skor protivnika (bot) i ishod, posle poslednjeg pitanja.
        var rival: Skor?
        var ishod: Ishod?
        var rivalIme: String
    }

    private(set) var stanje: Stanje
    private(set) var bitka: Bitka?
    private var cekaOdbranu: CheckedContinuation<Skor, Never>?
    private(set) var spremno = false
    private(set) var greska: String?
    var izabrana: String? { didSet { if izabrana != oldValue { meta = nil } } }
    /// Izabrana meta napada: pre bitke igrač vidi iz koje države napada, šta napada i šta rizikuje.
    private(set) var meta: String?
    /// Tačni i netačni odgovori igrača u partiji, za napredak (XP, bedževi).
    private(set) var tacnih = 0
    private(set) var netacnih = 0
    private(set) var zbirMs = 0
    var utvrdjivanje = false
    private(set) var otvoreno: Otvoreno?
    /// Jedna pomoć po partiji važi za celo Osvajanje, ne za svako pitanje posebno.
    var pomocIskoriscena = false
    private(set) var poruka: String?

    private var slucajno: Slucajno
    private var spil = Spil([])
    private var botRadi = false
    private let pauzaBota: Duration = .milliseconds(700)

    init(krugova: Int, tezina: Tezina, ime: String?) {
        var s = Slucajno(seme: UInt32(truncatingIfNeeded: Int(Date().timeIntervalSince1970 * 1000)))
        stanje = Stanje.nova(krugova: krugova, tezina: tezina, slucajno: &s, ime: ime)
        slucajno = s
    }

    /// Partija iz čekaonice: igrači i timovi, početni kontinenti i tajne misije.
    init(postavka p: OsvajanjePostavka) {
        var s = Slucajno(seme: UInt32(truncatingIfNeeded: Int(Date().timeIntervalSince1970 * 1000)))
        // Na jednom kontinentu nema misija: pobeđuje ko ga ceo osvoji ili ima više država na kraju.
        stanje = Stanje.nova(krugova: p.krugova, tezina: p.tezina, slucajno: &s, igraci: p.igraci, pocetak: p.pocetak,
                             misije: p.teren == nil, teren: p.teren)
        slucajno = s
        postavka = p
    }

    private(set) var postavka: OsvajanjePostavka?

    /// Tim čoveka (za misiju, odbranu i dodatne pomoći).
    var mojTim: String? { stanje.igraci.first(where: \.covek)?.tim }
    var jesamKapiten: Bool { stanje.igraci.first(where: \.covek)?.kapiten ?? false }

    /// Kontinenti koje moj tim drži ceo, a još nemaju odbranu (kapiten bira).
    var kontinentiBezOdbrane: [Kontinent] {
        guard let t = mojTim, jesamKapiten else { return [] }
        return Kontinenti.svi.filter { stanje.drziKontinent(t, $0.id) && stanje.odbrane[$0.id] == nil }
    }

    /// Kapiten bira odbranu na svom potezu (pravilo: jednom po krugu).
    func postaviOdbranu(_ k: String, _ o: Odbrana) {
        let novo = stanje.postaviOdbranu(k, o)
        if novo == stanje { javi("Odbranu menja kapiten, jednom po krugu, na svom potezu"); return }
        stanje = novo
        javi("\(Kontinenti.svi.first { $0.id == k }?.ime ?? ""): \(o.naziv)")
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
            if izabrana == nil { return "1. Dodirni svoju državu sa žutom ivicom: odatle napadaš · bitka \(stanje.bitaka + 1)/\(stanje.napadaPoPotezu)" }
            return meta == nil ? "2. Napadaš iz: \(Mapa.oblast(izabrana!).ime). Dodirni koga napadaš (isprekidana ivica)." : ""
        default: return "Snabdevanje…"
        }
    }

    func pokreni() async {
        do {
            spil = Spil(try await PaketPitanja.deljeni.ucitaj())
            spremno = true
            // U partiji sa misijom prvi potez čeka da igrač pročita misiju.
            if postavka == nil { pocniPotez(stanje) }
        } catch {
            greska = error.localizedDescription
        }
    }

    // MARK: Čovek

    func dodir(_ id: String) {
        guard covekNaPotezu, otvoreno == nil, let oblast = stanje.oblasti[id] else { return }
        let moja = oblast.vlasnik == stanje.trenutni.tim
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
                meta = meta == id ? nil : id
            }
        default: break
        }
    }

    /// Posle lista sa misijom: kreće prvi potez.
    func zapocni() {
        guard spremno, stanje.krug == 1, stanje.faza == .snabdevanje, otvoreno == nil else { return }
        pocniPotez(stanje)
    }

    func rasporediSam() { stanje = stanje.botRasporedi() }

    func prekidacUtvrdjivanja() { utvrdjivanje.toggle(); izabrana = nil }

    /// Države iz kojih čovek sada može da napadne (žuta isprekidana ivica dok ništa nije izabrano).
    var izvori: [String] {
        guard covekNaPotezu, stanje.faza == .napad, izabrana == nil, !utvrdjivanje else { return [] }
        return stanje.oblastiIgraca(stanje.trenutni.id).filter { !stanje.mete($0).isEmpty }
    }

    /// Potvrda napada sa panela mete.
    func napadni() {
        guard let izvor = izabrana, let kuda = meta, stanje.mete(izvor).contains(kuda) else { return }
        meta = nil
        bitka = novaBitka(napadam: true, odakle: izvor, kuda: kuda)
    }

    func odustaniOdMete() { meta = nil }

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
        // Pitanja van bitke su samo snabdevanje; bitke idu kroz `bitka`.
        stanje = stanje.snabdevanje(tacno: moj.tacan)
        javi(moj.tacan ? "Tačno! Raspoređuješ \(stanje.zaRaspored)" : "Netačno. Dobijaš samo \(stanje.zaRaspored)")
    }

    // MARK: Bitka

    private func novaBitka(napadam: Bool, odakle: String, kuda: String) -> Bitka {
        let uslov = stanje.uslovBitke(kuda)
        let rival = napadam
            ? stanje.igraci.first { $0.tim == stanje.oblasti[kuda]?.vlasnik }?.ime ?? "niko (prazno polje)"
            : stanje.trenutni.ime
        return Bitka(napadam: napadam, odakle: odakle, kuda: kuda, uslov: uslov,
                     prikazi: (0..<uslov.pitanja).map { _ in spil.sledece() }, rivalIme: rival)
    }

    /// Kraj uvoda (odbrojavanje): kreću pitanja.
    func pocniPitanja() { bitka?.korak = .pitanja }

    /// Pomoć „Preskok”: tekuće pitanje se menja novim iz špila, bez odgovora.
    func zameniPitanje() {
        if var b = bitka, b.korak == .pitanja {
            b.prikazi[b.redni] = spil.sledece()
            b.zamena += 1
            bitka = b
        } else if let o = otvoreno {
            otvoreno = Otvoreno(vrsta: o.vrsta, prikaz: spil.sledece(), odakle: o.odakle, kuda: o.kuda)
        }
    }

    /// Odgovor na pitanje u bitki (nil = isteklo vreme).
    func odgovorUBitci(_ izabran: Int?, ms: Int) {
        guard var b = bitka, b.korak == .pitanja else { return }
        let tacno = izabran == b.prikazi[b.redni].tacan
        if tacno { b.tacnih += 1; tacnih += 1 } else { netacnih += 1 }
        b.ms += ms
        zbirMs += ms
        if b.redni + 1 < b.prikazi.count {
            b.redni += 1
            bitka = b
            return
        }
        if b.napadam {
            let neutralna = stanje.oblasti[b.kuda]?.vlasnik == nil
            if neutralna {
                let (novo, ishod) = stanje.razresiBitku(odakle: b.odakle, kuda: b.kuda, napadac: Odgovor(tacan: tacno, ms: ms), branilac: nil)
                stanje = novo
                b.ishod = ishod
            } else {
                let rival = stanje.botSkor(&slucajno, pitanja: b.prikazi.count)
                let (novo, ishod) = stanje.razresiBitkuSkorom(odakle: b.odakle, kuda: b.kuda, napadac: Skor(tacnih: b.tacnih, ms: b.ms), branilac: rival)
                stanje = novo
                b.rival = rival
                b.ishod = ishod
            }
        }
        b.korak = .rezultat
        bitka = b
        if !b.napadam { cekaOdbranu?.resume(returning: Skor(tacnih: b.tacnih, ms: b.ms)); cekaOdbranu = nil }
    }

    /// Rezultat odbrane (kad bot napada čoveka) upisuje se posle razrešenja u potezu bota.
    func ishodOdbrane(_ rival: Skor, _ ishod: Ishod) {
        bitka?.rival = rival
        bitka?.ishod = ishod
    }

    func zatvoriBitku() {
        guard let b = bitka else { return }
        bitka = nil
        if b.napadam, let ishod = b.ishod {
            if ishod.osvojeno {
                javi(ishod.plen ? "Prestonica pala! +5 plena" : ishod.proboj ? "Proboj! +2 vojske" : "Osvojeno! Cepaj dalje")
                izabrana = stanje.mete(b.kuda).isEmpty ? nil : b.kuda
            } else if stanje.mete(b.odakle).isEmpty {
                izabrana = nil
            }
        }
        zatvaranje?.resume()
        zatvaranje = nil
    }

    private var zatvaranje: CheckedContinuation<Void, Never>?

    /// Dodatna pomoć osvojena u bitkama od 5 pitanja (troši se pre dnevnog fonda).
    var bonusPomoci: Int { stanje.igraci.first(where: \.covek).map { stanje.bonusPomoci[$0.tim] ?? 0 } ?? 0 }

    func iskoristiBonusPomoc() -> Bool {
        guard let tim = stanje.igraci.first(where: \.covek)?.tim, let novo = stanje.iskoristiBonusPomoc(tim) else { return false }
        stanje = novo
        return true
    }

    // MARK: Tok poteza

    private func pocniPotez(_ novo: Stanje) {
        stanje = novo
        guard novo.faza == .snabdevanje else { return }
        if novo.trenutni.covek {
            // Potez čoveka počinje napadom (vlasnik 02.11): pojačanja stižu sama i idu na granice, bez pitanja.
            let tim = novo.trenutni.tim
            var s = novo.snabdevanje(tacno: true)
            s.tacnih[tim, default: 1] -= 1 // pojačanje nije tačan odgovor (misije broje tačne)
            let dobio = s.zaRaspored
            stanje = s.botRasporedi()
            javi("+\(dobio) vojski na granicama. Biraj odakle napadaš.")
        } else {
            Task { await potezBota() }
        }
    }

    private func potezBota() async {
        guard !botRadi else { return }
        botRadi = true
        defer { botRadi = false }
        stanje = stanje.snabdevanje(tacno: slucajno.sledeci() < stanje.tacnostBota).botRasporedi().botOdbrana()
        try? await Task.sleep(for: pauzaBota)
        while let napad = stanje.botSledeciNapad() {
            izabrana = napad.odakle
            try? await Task.sleep(for: pauzaBota)
            if let vlasnik = stanje.oblasti[napad.kuda]?.vlasnik {
                let napadac = stanje.botSkor(&slucajno)
                let branilac: Skor
                if stanje.igraci.first(where: { $0.tim == vlasnik })?.covek == true {
                    branilac = await withCheckedContinuation { nastavak in
                        cekaOdbranu = nastavak
                        bitka = novaBitka(napadam: false, odakle: napad.odakle, kuda: napad.kuda)
                    }
                    let (novo, ishod) = stanje.razresiBitkuSkorom(odakle: napad.odakle, kuda: napad.kuda, napadac: napadac, branilac: branilac)
                    stanje = novo
                    ishodOdbrane(napadac, ishod)
                    await withCheckedContinuation { zatvaranje = $0 }
                } else {
                    branilac = stanje.botSkor(&slucajno)
                    stanje = stanje.razresiBitkuSkorom(odakle: napad.odakle, kuda: napad.kuda, napadac: napadac, branilac: branilac).0
                }
            } else {
                stanje = stanje.razresiBitku(odakle: napad.odakle, kuda: napad.kuda, napadac: stanje.botOdgovor(&slucajno), branilac: nil).0
            }
            if stanje.faza == .kraj { break }
            try? await Task.sleep(for: pauzaBota)
        }
        izabrana = nil
        botRadi = false
        pocniPotez(stanje.zavrsiPotez())
    }

    func javi(_ tekst: String) {
        poruka = tekst
        Task {
            try? await Task.sleep(for: .seconds(4))
            if poruka == tekst { poruka = nil }
        }
    }
}
