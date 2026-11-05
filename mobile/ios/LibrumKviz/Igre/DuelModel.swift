import Foundation
import Observation

/// Soba duela, isti red tabele game_rooms kao na vebu (src/app/igraj-zajedno).
struct Soba: Decodable, Equatable {
    let id: String
    let room_code: String
    let host_id: String
    let guest_id: String?
    let status: String
    let question_ids: [String]
    let host_answers: [Int?]?
    let guest_answers: [Int?]?
    let host_score: Int?
    let guest_score: Int?
    let total_questions: Int?
    var game_format: String? = nil
    var created_at: String? = nil
}

/// Isto mešanje ponuda kao na vebu (seededShuffle), da oba igrača — i sa veba i iz
/// aplikacije — vide iste ponude u istom redu. LCG se računa kao u JavaScriptu:
/// proizvod je double, pa ToInt32, pa maska.
enum DuelMesanje {
    static func red(_ id: String) -> [Int] {
        var s = Double(id.unicodeScalars.reduce(0) { $0 + Int($1.value) })
        func rand() -> Double {
            let d = s * 1103515245 + 12345
            var m = d.truncatingRemainder(dividingBy: 4294967296)
            if m < 0 { m += 4294967296 }
            s = Double(UInt32(m) & 0x7fffffff)
            return s / Double(0x7fffffff)
        }
        var indeksi = [0, 1, 2, 3]
        for i in stride(from: 3, to: 0, by: -1) {
            let j = Int(floor(rand() * Double(i + 1)))
            indeksi.swapAt(i, j)
        }
        return indeksi
    }

    static func prikaz(_ p: Pitanje) -> Prikaz {
        let r = red(p.id)
        return Prikaz(tekst: p.question_text, opcije: r.map { p.options[$0] }, tacan: r.firstIndex(of: p.correct_answer) ?? 0)
    }
}

extension Prikaz {
    init(tekst: String, opcije: [String], tacan: Int) {
        self.tekst = tekst
        self.opcije = opcije
        self.tacan = tacan
    }
}

/// Tok duela: soba, čekanje rivala, pitanja, otkrivanje i kraj. Soba se osvežava
/// svake sekunde (veb koristi realtime, isti podaci).
@Observable
@MainActor
final class DuelModel {
    enum Faza: Equatable { case lobi, trazenje, pronadjen, cekanje, igra, kraj }
    /// Ishod jedne runde za list posle otkrivanja.
    enum Runda: Equatable { case meni, rivalu, niko, oboje }

    static let poenaTacno = 10
    static let poenaNetacno = 5
    static let bonusNapustanja = 50
    static let sekundi = 15
    static let formati = [(10, "Brzi duel"), (25, "Standardni duel"), (50, "Veliki duel")]
    static let brzihPitanja = 5
    /// Posle ovoliko sekundi traženja kit pokazuje „Još tražimo”, posle drugog „Nema rivala”.
    static let dugoTrazenje = 20
    static let bezRivala = 60
    static let formatBrzog = "brzi5"
    /// Izazov bez čekanja: izazivač odigra odmah, rival kad stigne (do 24 h); ishod kad oba završe.
    static let formatIzazova = "izazov"
    static let pitanjaIzazova = 10

    var jeIzazov: Bool { soba?.game_format == Self.formatIzazova }
    /// Izazivač je odigrao, a rival još nije: ishod stiže kasnije.
    var cekaRivala: Bool { jeIzazov && jaSamDomacin && (soba?.guest_answers ?? []).count < ukupno }

    private(set) var faza: Faza = .lobi
    private(set) var soba: Soba?
    private(set) var pitanja: [Pitanje] = []
    private(set) var tekuce = 0
    private(set) var otkriveno = false
    private(set) var greska: String?
    private(set) var radi = false
    private(set) var rivalOtisao = false
    private(set) var rivalIme = "Rival"
    private(set) var trazimSekundi = 0
    private(set) var slabaVeza = false
    private(set) var rivalNeOdgovara = false
    private(set) var zabelezeno = false
    var kod = ""
    private var neuspesnihOsvezavanja = 0

    private let sesija: Sesija
    private var osvezavanje: Task<Void, Never>?
    private var pocetakPitanja = Date()

    init(sesija: Sesija) { self.sesija = sesija }

    var jaSamDomacin: Bool { soba?.host_id == sesija.korisnikId }
    /// Nalog rivala za revanš (izazov istom igraču); nil kad rival nije poznat.
    var rivalId: String? { jaSamDomacin ? soba?.guest_id : soba?.host_id }
    var moji: [Int?] { (jaSamDomacin ? soba?.host_answers : soba?.guest_answers) ?? [] }
    var njegovi: [Int?] { (jaSamDomacin ? soba?.guest_answers : soba?.host_answers) ?? [] }
    var mojiPoeni: Int { (jaSamDomacin ? soba?.host_score : soba?.guest_score) ?? 0 }
    var njegoviPoeni: Int { (jaSamDomacin ? soba?.guest_score : soba?.host_score) ?? 0 }
    var ukupno: Int { soba?.total_questions ?? 10 }
    var zlatno: Bool { tekuce >= ukupno }
    var prikaz: Prikaz? { tekuce < pitanja.count ? DuelMesanje.prikaz(pitanja[tekuce]) : nil }
    var odgovorioSam: Bool { tekuce < moji.count }
    var odgovorioJe: Bool { tekuce < njegovi.count }
    var ostaloSekundi: Int { max(0, Self.sekundi + dodatnoSekundi - Int(Date().timeIntervalSince(pocetakPitanja))) }
    /// Pomoć „vreme” produžava samo moj sat.
    /// shortcut: rival vidi otkrivanje po svom satu, pa moj kasniji odgovor ne vidi u toj rundi; ako smeta, server da drži rok.
    var dodatnoSekundi = 0

    // MARK: Brzi meč

    /// Brzi meč: uđe u tuđu sobu „brzi5” koja čeka (do 2 min stara), ili napravi svoju i čeka rivala.
    func brziMec() async {
        guard let id = sesija.korisnikId, let token = try? await sesija.vazeciToken() else { greska = "Prijavi se da bi igrao duel."; return }
        faza = .trazenje
        trazimSekundi = 0
        do {
            let granica = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-120))
            let slobodne: [Soba] = try await Supabase.deljeni.citaj("game_rooms", upit: [
                .init(name: "select", value: "*"), .init(name: "status", value: "eq.waiting"), .init(name: "guest_id", value: "is.null"),
                .init(name: "game_format", value: "eq.\(Self.formatBrzog)"), .init(name: "host_id", value: "neq.\(id)"),
                .init(name: "created_at", value: "gte.\(granica)"), .init(name: "order", value: "created_at.asc"), .init(name: "limit", value: "5"),
            ], token: token)
            for kandidat in slobodne {
                let zauzeta: [Soba] = try await Supabase.deljeni.azuriraj("game_rooms",
                    filter: [.init(name: "id", value: "eq.\(kandidat.id)"), .init(name: "guest_id", value: "is.null")],
                    polja: ["guest_id": id, "status": "playing", "game_start_time": ISO8601DateFormatter().string(from: Date())], token: token)
                if let soba = zauzeta.first {
                    self.soba = soba
                    try await ucitajPitanja(token: token)
                    await ucitajRivala(token: token)
                    pronadjen()
                    return
                }
            }
            let p: [Pitanje] = try await Supabase.deljeni.rpc("aplikacija_pitanja", ["p_igra": "opste", "p_broj": Self.brzihPitanja + 5], token: token)
            guard p.count >= Self.brzihPitanja else { throw Supabase.Greska(poruka: "Nema dovoljno pitanja za duel.") }
            let redovi: [Soba] = try await Supabase.deljeni.upisiVrati("game_rooms", [
                "room_code": Self.noviKod(), "host_id": id, "question_ids": p.map(\.id), "total_questions": Self.brzihPitanja,
                "status": "waiting", "game_format": Self.formatBrzog, "quiz_type": "pro",
            ], token: token)
            soba = redovi.first
            pitanja = p
            pratiSobu()
        } catch {
            faza = .lobi
            greska = error.localizedDescription
        }
    }

    /// Prekid traženja: soba se zatvara da je niko drugi ne uzme.
    func otkaziTrazenje() async {
        osvezavanje?.cancel()
        if let s = soba, s.guest_id == nil, let token = try? await sesija.vazeciToken() {
            let _: [Soba]? = try? await Supabase.deljeni.azuriraj("game_rooms", filter: [.init(name: "id", value: "eq.\(s.id)")], polja: ["status": "finished"], token: token)
        }
        soba = nil
        faza = .lobi
    }

    private func pronadjen() {
        faza = .pronadjen
        pratiSobu()
        Task {
            try? await Task.sleep(for: .seconds(3))
            guard faza == .pronadjen else { return }
            if soba?.status == "finished" { rivalOtisao = true; faza = .kraj; return }
            faza = .igra
            pocetakPitanja = Date()
        }
    }

    private func ucitajRivala(token: String) async {
        guard let s = soba, let rivalId = jaSamDomacin ? s.guest_id : s.host_id else { return }
        struct Profil: Decodable { let nickname: String?; let first_name: String? }
        let p: [Profil]? = try? await Supabase.deljeni.citaj("public_profiles", upit: [
            .init(name: "select", value: "nickname,first_name"), .init(name: "id", value: "eq.\(rivalId)"),
        ], token: token)
        rivalIme = p?.first.flatMap { $0.nickname ?? $0.first_name } ?? "Rival"
    }

    static func noviKod() -> String { String((0..<5).map { _ in "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".randomElement()! }) }

    /// Ishod runde iz upisanih odgovora (nil dok nije otkriveno).
    var runda: Runda? {
        guard otkriveno, let p = prikaz else { return nil }
        let ja = tekuce < moji.count && moji[tekuce] == p.tacan
        let on = tekuce < njegovi.count && njegovi[tekuce] == p.tacan
        return ja && on ? .oboje : ja ? .meni : on ? .rivalu : .niko
    }

    /// Kraj meča: napredak i rezultat za rang listu, jednom.
    func zabelezi(_ napredak: Napredak) {
        guard faza == .kraj, !zabelezeno else { return }
        zabelezeno = true
        let pobeda = mojiPoeni > njegoviPoeni
        let tacnih = zip(moji, pitanja.map(DuelMesanje.prikaz)).filter { $0.0 == $0.1.tacan }.count
        zavrsiPartiju(napredak, sesija, igra: "duel", poeni: mojiPoeni, tacnih: tacnih, netacnih: max(0, moji.count - tacnih),
                      kategorija: "Opšte znanje", pobeda: pobeda)
    }

    // MARK: Izazov bez čekanja

    /// Pravim izazov za igrača: soba je odmah „playing”, rival je upisan, ja igram svojih 10 pitanja sad.
    func izazovi(_ rival: String, ime: String) async {
        guard let id = sesija.korisnikId, let token = try? await sesija.vazeciToken() else { greska = "Prijavi se da bi igrao duel."; return }
        radi = true; defer { radi = false }
        do {
            let p: [Pitanje] = try await Supabase.deljeni.rpc("aplikacija_pitanja", ["p_igra": "opste", "p_broj": Self.pitanjaIzazova + 5], token: token)
            guard p.count >= Self.pitanjaIzazova else { throw Supabase.Greska(poruka: "Nema dovoljno pitanja za duel.") }
            let redovi: [Soba] = try await Supabase.deljeni.upisiVrati("game_rooms", [
                "room_code": Self.noviKod(), "host_id": id, "guest_id": rival, "question_ids": p.prefix(Self.pitanjaIzazova).map(\.id),
                "total_questions": Self.pitanjaIzazova, "status": "playing", "game_format": Self.formatIzazova, "quiz_type": "pro",
                "game_start_time": ISO8601DateFormatter().string(from: Date()),
            ], token: token)
            soba = redovi.first
            pitanja = Array(p.prefix(Self.pitanjaIzazova))
            rivalIme = ime
            if let s = soba { await Drustvo.posaljiIzazov(sesija, za: rival, kod: s.room_code) }
            faza = .igra
            pocetakPitanja = Date()
            pratiSobu()
        } catch { greska = error.localizedDescription }
    }

    // MARK: Lobi

    func napravi(brojPitanja: Int) async {
        guard let id = sesija.korisnikId, let token = try? await sesija.vazeciToken() else { greska = "Prijavi se da bi igrao duel."; return }
        radi = true; defer { radi = false }
        do {
            let p: [Pitanje] = try await Supabase.deljeni.rpc("aplikacija_pitanja", ["p_igra": "opste", "p_broj": min(80, brojPitanja + 10)], token: token)
            guard p.count >= brojPitanja else { throw Supabase.Greska(poruka: "Nema dovoljno pitanja za duel.") }
            let noviKod = Self.noviKod()
            let redovi: [Soba] = try await Supabase.deljeni.upisiVrati("game_rooms", [
                "room_code": noviKod, "host_id": id, "question_ids": p.map(\.id), "total_questions": brojPitanja,
                "status": "waiting", "game_format": "q\(brojPitanja)", "quiz_type": "pro",
            ], token: token)
            soba = redovi.first
            pitanja = p
            faza = .cekanje
            pratiSobu()
        } catch { greska = error.localizedDescription }
    }

    func pridruzi() async {
        guard let id = sesija.korisnikId, let token = try? await sesija.vazeciToken() else { greska = "Prijavi se da bi igrao duel."; return }
        let k = kod.trimmingCharacters(in: .whitespaces).uppercased()
        guard !k.isEmpty else { return }
        radi = true; defer { radi = false }
        do {
            let nadjene: [Soba] = try await Supabase.deljeni.citaj("game_rooms", upit: [.init(name: "select", value: "*"), .init(name: "room_code", value: "eq.\(k)")], token: token)
            guard let s = nadjene.first else { throw Supabase.Greska(poruka: "Soba sa tim kodom ne postoji.") }
            if s.game_format == Self.formatIzazova {
                // Izazov: rival igra ista pitanja; izazivačevi odgovori su već tu, pa se svaka runda otkriva odmah.
                guard s.guest_id == id else { throw Supabase.Greska(poruka: "Ovaj izazov nije za tebe.") }
                guard (s.guest_answers ?? []).count < (s.total_questions ?? Self.pitanjaIzazova) else { throw Supabase.Greska(poruka: "Ovaj izazov si već odigrao.") }
                self.soba = s
                try await ucitajPitanja(token: token)
                await ucitajRivala(token: token)
                faza = .igra
                pocetakPitanja = Date()
                pratiSobu()
                return
            }
            guard s.status == "waiting" else { throw Supabase.Greska(poruka: "Igra je već počela ili završena.") }
            guard s.host_id != id else { throw Supabase.Greska(poruka: "Ne možeš da se pridružiš sopstvenoj sobi.") }
            let azurirano: [Soba] = try await Supabase.deljeni.azuriraj("game_rooms",
                filter: [.init(name: "room_code", value: "eq.\(k)"), .init(name: "guest_id", value: "is.null")], polja: ["guest_id": id], token: token)
            guard let soba = azurirano.first else { throw Supabase.Greska(poruka: "Neko je već zauzeo ovo mesto.") }
            self.soba = soba
            try await ucitajPitanja(token: token)
            await ucitajRivala(token: token)
            faza = .cekanje
            pratiSobu()
        } catch { greska = error.localizedDescription }
    }

    func zapocni() async {
        guard let s = soba, let token = try? await sesija.vazeciToken() else { return }
        let _: [Soba]? = try? await Supabase.deljeni.azuriraj("game_rooms", filter: [.init(name: "id", value: "eq.\(s.id)")],
            polja: ["status": "playing", "game_start_time": ISO8601DateFormatter().string(from: Date())], token: token)
    }

    private func ucitajPitanja(token: String) async throws {
        guard let s = soba else { return }
        let p: [Pitanje] = try await Supabase.deljeni.rpc("aplikacija_pitanja_po_id", ["p_igra": "pro", "p_ids": s.question_ids], token: token)
        let poId = Dictionary(uniqueKeysWithValues: p.map { ($0.id, $0) })
        pitanja = s.question_ids.compactMap { poId[$0] }
    }

    // MARK: Igra

    private func pratiSobu() {
        osvezavanje?.cancel()
        osvezavanje = Task { [weak self] in
            while !Task.isCancelled {
                await self?.osvezi()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func osvezi() async {
        if faza == .trazenje { trazimSekundi += 1 }
        guard let s = soba, let token = try? await sesija.vazeciToken() else { return }
        guard let nove: [Soba] = try? await Supabase.deljeni.citaj("game_rooms", upit: [.init(name: "select", value: "*"), .init(name: "id", value: "eq.\(s.id)")], token: token),
              let nova = nove.first else {
            neuspesnihOsvezavanja += 1
            slabaVeza = neuspesnihOsvezavanja >= 3
            return
        }
        neuspesnihOsvezavanja = 0
        slabaVeza = false
        soba = nova
        // Rival ćuti duže od pitanja + 5 s: verovatno je izgubio vezu.
        rivalNeOdgovara = faza == .igra && odgovorioSam && !odgovorioJe && Date().timeIntervalSince(pocetakPitanja) > Double(Self.sekundi + 5)
        switch faza {
        case .trazenje where nova.guest_id != nil:
            await ucitajRivala(token: token)
            if nova.status == "waiting" {
                let _: [Soba]? = try? await Supabase.deljeni.azuriraj("game_rooms", filter: [.init(name: "id", value: "eq.\(nova.id)")],
                    polja: ["status": "playing", "game_start_time": ISO8601DateFormatter().string(from: Date())], token: token)
            }
            pronadjen()
        case .trazenje where trazimSekundi >= Self.bezRivala:
            osvezavanje?.cancel()
            let _: [Soba]? = try? await Supabase.deljeni.azuriraj("game_rooms", filter: [.init(name: "id", value: "eq.\(nova.id)")], polja: ["status": "finished"], token: token)
        case .cekanje where nova.status == "playing" && rivalIme == "Rival":
            await ucitajRivala(token: token)
            faza = .igra
            pocetakPitanja = Date()
        case .cekanje where nova.status == "playing":
            faza = .igra
            pocetakPitanja = Date()
        case .igra where nova.status == "finished" && !jeIzazov:
            rivalOtisao = true
            zavrsi()
        case .igra:
            // U izazovu rival ne igra uživo: runda se otkriva čim ja odgovorim.
            if !otkriveno && ((odgovorioSam && (odgovorioJe || jeIzazov)) || ostaloSekundi == 0) { otkrij() }
        default: break
        }
    }

    /// Tačan odgovor +10, netačan ili istek −5 (najmanje 0), kao na vebu. Preskok (pomoć) ne menja poene.
    func odgovori(_ izabran: Int?, preskok: Bool = false) async {
        guard faza == .igra, !odgovorioSam, let p = prikaz, let s = soba, let token = try? await sesija.vazeciToken() else { return }
        let tacan = izabran == p.tacan
        let novi = preskok ? mojiPoeni : max(0, mojiPoeni + (tacan ? Self.poenaTacno : -Self.poenaNetacno))
        var odgovori = moji
        while odgovori.count < tekuce { odgovori.append(nil) }
        odgovori.append(izabran)
        let polja: [String: Any] = jaSamDomacin
            ? ["host_answers": odgovori.map { $0 as Any? ?? NSNull() }, "host_score": novi]
            : ["guest_answers": odgovori.map { $0 as Any? ?? NSNull() }, "guest_score": novi]
        if let nove: [Soba] = try? await Supabase.deljeni.azuriraj("game_rooms", filter: [.init(name: "id", value: "eq.\(s.id)")], polja: polja, token: token),
           let nova = nove.first { soba = nova }
    }

    func istekloVreme() async { if !odgovorioSam { await odgovori(nil) } }

    private func otkrij() {
        otkriveno = true
        Task {
            try? await Task.sleep(for: .milliseconds(3500))
            sledece()
        }
    }

    private func sledece() {
        guard faza == .igra else { return }
        let sledeci = tekuce + 1
        // Posle glavnog dela: nerešeno ide na zlatno pitanje dok ih ima.
        // Izazov nema zlatno pitanje: rival nije tu da ga odigra.
        if sledeci >= ukupno && (jeIzazov || !(mojiPoeni == njegoviPoeni && sledeci < pitanja.count)) {
            Task { await zatvoriSobu(); zavrsi() }
            return
        }
        tekuce = sledeci
        otkriveno = false
        dodatnoSekundi = 0
        pocetakPitanja = Date()
    }

    private func zatvoriSobu() async {
        guard let s = soba, let token = try? await sesija.vazeciToken() else { return }
        // Izazivač samo označava da je završio; sobu zatvara rival kad odigra.
        let polja: [String: Any] = jeIzazov && jaSamDomacin ? ["host_finished": true] : jeIzazov ? ["guest_finished": true, "status": "finished"] : ["status": "finished"]
        let _: [Soba]? = try? await Supabase.deljeni.azuriraj("game_rooms", filter: [.init(name: "id", value: "eq.\(s.id)")], polja: polja, token: token)
    }

    /// Napuštanje: rival dobija +50 i soba se zatvara, da bekstvo iz gubitka nije besplatno.
    func napusti() async {
        osvezavanje?.cancel()
        guard let s = soba, faza == .igra || faza == .cekanje, let token = try? await sesija.vazeciToken() else { return }
        var polja: [String: Any] = ["status": "finished"]
        if faza == .igra { polja[jaSamDomacin ? "guest_score" : "host_score"] = njegoviPoeni + Self.bonusNapustanja }
        let _: [Soba]? = try? await Supabase.deljeni.azuriraj("game_rooms", filter: [.init(name: "id", value: "eq.\(s.id)")], polja: polja, token: token)
    }

    private func zavrsi() {
        osvezavanje?.cancel()
        faza = .kraj
        Task { await osveziJednom() }
    }

    private func osveziJednom() async {
        guard let s = soba, let token = try? await sesija.vazeciToken(),
              let nove: [Soba] = try? await Supabase.deljeni.citaj("game_rooms", upit: [.init(name: "select", value: "*"), .init(name: "id", value: "eq.\(s.id)")], token: token),
              let nova = nove.first else { return }
        soba = nova
    }

    func ocistiGresku() { greska = nil }

    /// Moji izazovi (poslati i primljeni, 7 dana) za lobi: ko čeka koga i ishod.
    struct MojIzazov: Identifiable { let soba: Soba; let rival: String; let rivalIme: String; let ja: Int; let on: Int; let zavrsen: Bool; let naMeni: Bool; var id: String { soba.id } }
    func mojiIzazovi() async -> [MojIzazov] {
        guard let id = sesija.korisnikId, let token = try? await sesija.vazeciToken() else { return [] }
        let granica = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-7 * 86400))
        guard let sobe: [Soba] = try? await Supabase.deljeni.citaj("game_rooms", upit: [
            .init(name: "select", value: "*"), .init(name: "game_format", value: "eq.\(Self.formatIzazova)"),
            .init(name: "or", value: "(host_id.eq.\(id),guest_id.eq.\(id))"), .init(name: "created_at", value: "gte.\(granica)"),
            .init(name: "order", value: "created_at.desc"), .init(name: "limit", value: "20"),
        ], token: token) else { return [] }
        let drugi = Set(sobe.compactMap { $0.host_id == id ? $0.guest_id : $0.host_id })
        struct P: Decodable { let id: String; let nickname: String?; let first_name: String? }
        let profili: [P] = drugi.isEmpty ? [] : ((try? await Supabase.deljeni.citaj("public_profiles", upit: [
            .init(name: "select", value: "id,nickname,first_name"), .init(name: "id", value: "in.(\(drugi.joined(separator: ",")))"),
        ], token: token)) ?? [])
        let ime = Dictionary(uniqueKeysWithValues: profili.map { ($0.id, $0.nickname ?? $0.first_name ?? "Igrač") })
        return sobe.map { s in
            let domacin = s.host_id == id
            let rival = (domacin ? s.guest_id : s.host_id) ?? ""
            let gostOdigrao = (s.guest_answers ?? []).count >= (s.total_questions ?? Self.pitanjaIzazova)
            return MojIzazov(soba: s, rival: rival, rivalIme: ime[rival] ?? "Igrač",
                             ja: (domacin ? s.host_score : s.guest_score) ?? 0, on: (domacin ? s.guest_score : s.host_score) ?? 0,
                             zavrsen: gostOdigrao, naMeni: !domacin && !gostOdigrao)
        }
    }
}
