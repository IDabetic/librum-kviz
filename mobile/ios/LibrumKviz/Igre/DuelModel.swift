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
    enum Faza: Equatable { case lobi, cekanje, igra, kraj }

    static let poenaTacno = 10
    static let poenaNetacno = 5
    static let bonusNapustanja = 50
    static let sekundi = 15
    static let formati = [(10, "Brzi duel"), (25, "Standardni duel"), (50, "Veliki duel")]

    private(set) var faza: Faza = .lobi
    private(set) var soba: Soba?
    private(set) var pitanja: [Pitanje] = []
    private(set) var tekuce = 0
    private(set) var otkriveno = false
    private(set) var greska: String?
    private(set) var radi = false
    private(set) var rivalOtisao = false
    var kod = ""

    private let sesija: Sesija
    private var osvezavanje: Task<Void, Never>?
    private var pocetakPitanja = Date()

    init(sesija: Sesija) { self.sesija = sesija }

    var jaSamDomacin: Bool { soba?.host_id == sesija.korisnikId }
    var moji: [Int?] { (jaSamDomacin ? soba?.host_answers : soba?.guest_answers) ?? [] }
    var njegovi: [Int?] { (jaSamDomacin ? soba?.guest_answers : soba?.host_answers) ?? [] }
    var mojiPoeni: Int { (jaSamDomacin ? soba?.host_score : soba?.guest_score) ?? 0 }
    var njegoviPoeni: Int { (jaSamDomacin ? soba?.guest_score : soba?.host_score) ?? 0 }
    var ukupno: Int { soba?.total_questions ?? 10 }
    var zlatno: Bool { tekuce >= ukupno }
    var prikaz: Prikaz? { tekuce < pitanja.count ? DuelMesanje.prikaz(pitanja[tekuce]) : nil }
    var odgovorioSam: Bool { tekuce < moji.count }
    var odgovorioJe: Bool { tekuce < njegovi.count }
    var ostaloSekundi: Int { max(0, Self.sekundi - Int(Date().timeIntervalSince(pocetakPitanja))) }

    // MARK: Lobi

    func napravi(brojPitanja: Int) async {
        guard let id = sesija.korisnikId, let token = try? await sesija.vazeciToken() else { greska = "Prijavi se da bi igrao duel."; return }
        radi = true; defer { radi = false }
        do {
            let p: [Pitanje] = try await Supabase.deljeni.rpc("aplikacija_pitanja", ["p_igra": "opste", "p_broj": min(80, brojPitanja + 10)], token: token)
            guard p.count >= brojPitanja else { throw Supabase.Greska(poruka: "Nema dovoljno pitanja za duel.") }
            let noviKod = String((0..<5).map { _ in "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".randomElement()! })
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
            guard s.status == "waiting" else { throw Supabase.Greska(poruka: "Igra je već počela ili završena.") }
            guard s.host_id != id else { throw Supabase.Greska(poruka: "Ne možeš da se pridružiš sopstvenoj sobi.") }
            let azurirano: [Soba] = try await Supabase.deljeni.azuriraj("game_rooms",
                filter: [.init(name: "room_code", value: "eq.\(k)"), .init(name: "guest_id", value: "is.null")], polja: ["guest_id": id], token: token)
            guard let soba = azurirano.first else { throw Supabase.Greska(poruka: "Neko je već zauzeo ovo mesto.") }
            self.soba = soba
            try await ucitajPitanja(token: token)
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
        guard let s = soba, let token = try? await sesija.vazeciToken() else { return }
        guard let nove: [Soba] = try? await Supabase.deljeni.citaj("game_rooms", upit: [.init(name: "select", value: "*"), .init(name: "id", value: "eq.\(s.id)")], token: token),
              let nova = nove.first else { return }
        soba = nova
        switch faza {
        case .cekanje where nova.status == "playing":
            faza = .igra
            pocetakPitanja = Date()
        case .igra where nova.status == "finished":
            rivalOtisao = true
            zavrsi()
        case .igra:
            if !otkriveno && ((odgovorioSam && odgovorioJe) || ostaloSekundi == 0) { otkrij() }
        default: break
        }
    }

    /// Tačan odgovor +10, netačan ili istek −5 (najmanje 0), kao na vebu.
    func odgovori(_ izabran: Int?) async {
        guard faza == .igra, !odgovorioSam, let p = prikaz, let s = soba, let token = try? await sesija.vazeciToken() else { return }
        let tacan = izabran == p.tacan
        let novi = max(0, mojiPoeni + (tacan ? Self.poenaTacno : -Self.poenaNetacno))
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
        if sledeci >= ukupno && !(mojiPoeni == njegoviPoeni && sledeci < pitanja.count) {
            Task { await zatvoriSobu(); zavrsi() }
            return
        }
        tekuce = sledeci
        otkriveno = false
        pocetakPitanja = Date()
    }

    private func zatvoriSobu() async {
        guard let s = soba, let token = try? await sesija.vazeciToken() else { return }
        let _: [Soba]? = try? await Supabase.deljeni.azuriraj("game_rooms", filter: [.init(name: "id", value: "eq.\(s.id)")], polja: ["status": "finished"], token: token)
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
}
