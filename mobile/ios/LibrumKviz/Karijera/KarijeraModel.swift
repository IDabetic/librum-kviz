import Foundation

/// Podaci Karijere sa servera (scripts/2026-11-04_karijera.sql). Sva ekonomija se računa
/// na serveru; aplikacija samo prikazuje i šalje odgovore.
enum Karijera {
    /// Najviše rundi probnog rada dnevno (server `karijera_zavrsi_rundu`, od 05.11 umesto 4).
    static let probniDnevno = 10
    struct Pozicija: Decodable, Identifiable, Hashable {
        let id, naziv, opis, oblast, ikonica: String
        var naziv_z: String? = nil
        let teme: [String]
        func naziv(pol: String?) -> String { pol == "z" ? (naziv_z ?? naziv) : naziv }
    }

    struct Talenat: Decodable, Identifiable, Hashable { let id, naziv, opis, ikonica: String }
    struct ZamenaTalenta: Decodable { let dostupno, do_sledece, tacnih, korak: Int }

    struct Firma: Decodable, Identifiable, Hashable {
        let id: String
        let ime: String
        let korporacija: Bool
        let npc: Bool
        let vlasnik: String?
        let vlasnik_ime: String
        let pozicija: String
        let nivo: Int
        let stil: Int
        let udeo: String
        let kljucne: [String]
        let rekord: Int
        let rekord_ime: String?
        let rekord_igrac: String?
        let zaposlenih: Int
        let botova: Int
        let zastita_do: String?
        // Šef i mešavina pitanja (vlasnik podešava u svojoj firmi); stari odgovori bez polja = podrazumevano.
        let sef_tacno, sef_netacno, sef_ometanja, struka_udeo: Int?
        let sef_smeh, teza: Bool?
        let sef_lik: String?
        /// Slobodni dani firme (ISO: 1 ponedeljak … 7 nedelja) i da li je danas jedan od njih.
        let slobodni: [Int]?
        let slobodan_danas: Bool?
        let stres: Double?
        let fokus: [String]?
        let fokus_udeo: [Int]?
        var sefNivo: Sef.Nivo { Sef.Nivo(tacno: sef_tacno ?? 2, netacno: sef_netacno ?? 2, ometanja: sef_ometanja ?? 2, smeh: sef_smeh ?? true, lik: sef_lik ?? (korporacija ? "korporacija" : "m_srednji")) }

        /// Slika zgrade: Korporacija ima svoju, ostale po nivou i jednoj od 4 varijante.
        var slika: String { Karijera.slikaZgrade(korporacija: korporacija, nivo: nivo, stil: stil) }
        var udeoNaziv: String { Karijera.udeoNaziv(udeo) }
        var zasticena: Bool { (zastita_do.flatMap(Karijera.datum) ?? .distantPast) > .now }
    }

    struct Bot: Decodable, Identifiable, Hashable {
        let id, ime, tema: String
        let nivo: Int
        let pomoci_ostalo: Int
        /// Lik bota iz Assets (Karijera_Bot_1…6), stalan za isto ime.
        var slika: String { Karijera.slikaBota(ime) }
    }

    struct Zaposleni: Decodable, Identifiable, Hashable {
        let id, ime: String
        let titula: Int
    }

    struct Tema: Decodable, Hashable { let tema: String; let pitanja: Int }

    struct Izazov: Decodable, Identifiable, Hashable {
        let id: String
        let firma: Firma
        let vlasnik: String?
        let vlasnik_ime: String
        let izazivac: String
        let izazivac_ime: String
        let pokusaj: Int
        let revans: Bool
        let tema_izazivac: String
        let tema1: String?
        let tema3: String?
        let botova: Int
        let stanje: String
        let rok: String
        let ja_odigrao: Bool?
        let vlasnik_tacnih: Int?
        let izazivac_tacnih: Int?
        let pobednik: String?
        let ishod: String?

        var rokDatum: Date? { Karijera.datum(rok) }
    }

    /// Firma sa detaljima (karijera_firma): za vlasnika i kasa, botovi, zaposleni, izazovi.
    struct FirmaDetalj: Decodable, Identifiable, Hashable {
        let id: String
        let ime: String
        let korporacija: Bool
        let npc: Bool
        let vlasnik: String?
        let vlasnik_ime: String
        let pozicija: String
        let nivo: Int
        let stil: Int
        let udeo: String
        let kljucne: [String]
        let rekord: Int
        let rekord_ime: String?
        let rekord_igrac: String?
        let zaposlenih: Int
        let botova: Int
        let zastita_do: String?
        /// Vlasnik je već izabrao zaštitu od napada (3/5/7/10 dana) za ovo vlasništvo.
        let zastita_izabrana: Bool?
        let vlasnik_od: String?
        // Šef i mešavina pitanja (vlasnik podešava u svojoj firmi); stari odgovori bez polja = podrazumevano.
        let sef_tacno, sef_netacno, sef_ometanja, struka_udeo: Int?
        let sef_smeh, teza: Bool?
        let sef_lik: String?
        /// Slobodni dani firme (ISO: 1 ponedeljak … 7 nedelja) i da li je danas jedan od njih.
        let slobodni: [Int]?
        let slobodan_danas: Bool?
        let stres: Double?
        let fokus: [String]?
        let fokus_udeo: [Int]?
        var sefNivo: Sef.Nivo { Sef.Nivo(tacno: sef_tacno ?? 2, netacno: sef_netacno ?? 2, ometanja: sef_ometanja ?? 2, smeh: sef_smeh ?? true, lik: sef_lik ?? (korporacija ? "korporacija" : "m_srednji")) }
        let ja_vlasnik: Bool
        let kasa: Double?
        let odrzavanje: Int
        let dividenda_danas: Bool
        let udeo_menjan: String?
        let cena_nadogradnje: Double?
        let treba_zaposlenih: Int?
        let aktivnih: Int
        let poslednji_ulazak: String?
        let botovi: [Bot]
        let zaposleni: [Zaposleni]
        let izazovi: [Izazov]
        let teme: [Tema]

        var slika: String { Karijera.slikaZgrade(korporacija: korporacija, nivo: nivo, stil: stil) }
        var udeoNaziv: String { Karijera.udeoNaziv(udeo) }
        var kratko: Firma {
            Firma(id: id, ime: ime, korporacija: korporacija, npc: npc, vlasnik: vlasnik, vlasnik_ime: vlasnik_ime, pozicija: pozicija,
                  nivo: nivo, stil: stil, udeo: udeo, kljucne: kljucne, rekord: rekord, rekord_ime: rekord_ime, rekord_igrac: rekord_igrac,
                  zaposlenih: zaposlenih, botova: botova, zastita_do: zastita_do, sef_tacno: sef_tacno, sef_netacno: sef_netacno,
                  sef_ometanja: sef_ometanja, struka_udeo: struka_udeo, sef_smeh: sef_smeh, teza: teza, sef_lik: sef_lik, slobodni: slobodni, slobodan_danas: slobodan_danas, stres: stres, fokus: fokus, fokus_udeo: fokus_udeo)
        }
    }

    struct Probni: Decodable, Hashable {
        let runde, cilj, tacnih: Int
        let ishod: Int?
        let danas: Int?
        let korporacija_dana: Int?
        let bivsi_vlasnik: Bool?
    }

    struct Stanje: Decodable {
        let pozicija: String?
        let pol: String?
        let talenti: [String]?
        let pomoci: [String]?
        let mirni: Bool?
        let katalog_talenata: [Talenat]?
        let zamena_talenta: ZamenaTalenta?
        let kapital: Double
        let ugled: Int
        let titula: Int
        let nivo_ugleda: Int
        let slotova: Int
        let placenih_danas: Int
        let placenih_max: Int
        let probni: Probni
        let office_pravo: Int?
        let odmor_do: String?
        let odmor_ostalo: Int
        let posao: Firma?
        let zaposlen_od: String?
        let firme: [FirmaDetalj]
        let moji_izazovi: [Izazov]
        let korporacija: String
        let prefiksi: [String]
        let oblici: [String]
        let pozicije: [Pozicija]

        var mojaPozicija: Pozicija? { pozicije.first { $0.id == pozicija } }
        func ima(_ t: String) -> Bool { talenti?.contains(t) == true }
        var mojiTalenti: [Talenat] { (katalog_talenata ?? []).filter { talenti?.contains($0.id) == true } }
        var uProbnom: Bool { probni.ishod == nil && pozicija != nil }
    }

    struct Pitanje: Decodable, Identifiable {
        let id: String
        let question_text: String
        let options: [String]
        let correct_answer: Int
        let tema: String?
        var runda: Int? = nil

        var zaPrikaz: Prikaz { Prikaz(LibrumKviz.Pitanje(id: id, question_text: question_text, options: options, correct_answer: correct_answer)) }
        /// Indeks izabranog odgovora u redosledu iz baze (server proverava tačnost po njemu).
        func izvorni(_ izabran: Int?, prikaz: Prikaz) -> Int {
            guard let izabran else { return -1 }
            if izabran == prikaz.tacan { return correct_answer }
            return options.firstIndex(of: prikaz.opcije[izabran]).flatMap { $0 == correct_answer ? nil : $0 } ?? (correct_answer + 1) % 4
        }
    }

    struct IshodRunde: Decodable {
        let tacnih, poeni: Int
        let placeno: Bool
        let plata, kasi: Double
        let ugled: Int
        let rekord: Bool
        let probni: Probni?
        let placenih_danas: Int
        /// Runda na slobodan dan firme: plata i kasa ×1,1.
        let prekovremeno: Bool?
    }

    struct BotPomoc: Decodable { let bot, tema: String; let izbor, sigurnost: Int }

    struct Dogadjaj: Decodable, Hashable { let vrsta, tekst, kad: String }
    struct Ekspertiza: Decodable, Hashable { let tema: String; let ocena: Int }

    struct CV: Decodable {
        let id, ime: String
        let avatar: String?
        let pozicija: String?
        let titula, ugled: Int
        let kapital, neto: Double
        let posao: Firma?
        let firme: [Firma]
        let ekspertiza: [Ekspertiza]
        let odbrana, preuzimanja, tacnih, rundi: Int
        let dogadjaji: [Dogadjaj]
    }

    struct RedRanga: Decodable, Identifiable, Hashable { let id, ime: String; let vrednost: Double; let pozicija: String? }

    // MARK: Pozivi

    static func rpc<T: Decodable>(_ ime: String, _ p: [String: Any] = [:]) async throws -> T {
        let token = try await Sesija.trenutna?.vazeciToken()
        guard let token else { throw Supabase.Greska(poruka: "Prijavi se da bi igrao Karijeristu.") }
        return try await Supabase.deljeni.rpc(ime, p, token: token)
    }

    static func stanje() async throws -> Stanje { try await rpc("karijera_stanje") }
    static func izaberiPoziciju(_ id: String, pol: String, talenti: [String], pomoci: [String]) async throws -> Stanje {
        try await rpc("karijera_izaberi_poziciju", ["p_pozicija": id, "p_pol": pol, "p_talenti": talenti, "p_pomoci": pomoci])
    }
    struct Reset: Decodable { let ok: Bool; let firmi_predato: Int }
    static func resetuj() async throws -> Reset { try await rpc("karijera_resetuj") }
    static func promeniTalenat(stari: String, novi: String) async throws -> Stanje { try await rpc("karijera_promeni_talenat", ["p_stari": stari, "p_novi": novi]) }

    /// Talenti koje primenjuje aplikacija (ostale server); čuvaju se pri ulasku u Karijeru.
    @MainActor static var mojiTalenti: Set<String> = []
    @MainActor static var mojPol: String = "m"
    /// Mirni režim (Podešavanja): šef najviše blag, bez ometanja; igrač nema dodatak za stres.
    @MainActor static var mirni = false
    /// 4 izabrane pomoći (KarijeraPomoc.sve); stare naloge bez izbora dočekuju prve četiri.
    @MainActor static var mojePomoci: [String] = Array(KarijeraPomoc.sve.prefix(4).map(\.id))
    static func noviProbni() async throws -> Stanje { try await rpc("karijera_novi_probni") }
    static func odmor(_ dana: Int) async throws -> Stanje { try await rpc("karijera_odmor", ["p_dana": dana]) }
    static func povuciOdmor() async throws -> Stanje { try await rpc("karijera_odmor_povuci") }
    static func zaposliSe(_ firma: String) async throws -> Stanje { try await rpc("karijera_zaposli_se", ["p_firma": firma]) }

    static func pitanjaRunde(_ firma: String) async throws -> [Pitanje] {
        let p: [Pitanje] = try await rpc("karijera_runda_pitanja", ["p_firma": firma])
        return p.filter { $0.options.count == 4 && (0..<4).contains($0.correct_answer) }
    }
    static func zavrsiRundu(_ firma: String, odgovori: [[String: Any]]) async throws -> IshodRunde {
        try await rpc("karijera_zavrsi_rundu", ["p_firma": firma, "p_odgovori": odgovori])
    }
    static func pomocBota(firma: String?, pitanje: String, izazov: String? = nil) async throws -> BotPomoc {
        var p: [String: Any] = ["p_firma": firma ?? NSNull(), "p_pitanje": pitanje]
        if let izazov { p["p_izazov"] = izazov }
        return try await rpc("karijera_bot_pomoc", p)
    }

    struct NovaFirma: Decodable { let firma: String }
    static func otvoriFirmu(ime: String, stil: Int, botovi: [String]) async throws -> NovaFirma {
        try await rpc("karijera_otvori_firmu", ["p_ime": ime, "p_stil": stil, "p_botovi": botovi])
    }
    static func preimenuj(_ id: String, ime: String) async throws -> FirmaDetalj { try await rpc("karijera_preimenuj", ["p_firma": id, "p_ime": ime]) }
    struct Ok: Decodable { let ok: Bool }
    static func prijaviIme(_ id: String) async throws -> Ok { try await rpc("karijera_prijavi_ime", ["p_firma": id]) }
    static func firma(_ id: String) async throws -> FirmaDetalj { try await rpc("karijera_firma", ["p_firma": id]) }
    static func podesiSefa(_ id: String, _ n: Sef.Nivo) async throws -> FirmaDetalj {
        try await rpc("karijera_podesi_sefa", ["p_firma": id, "p_tacno": n.tacno, "p_netacno": n.netacno, "p_ometanja": n.ometanja, "p_smeh": n.smeh, "p_lik": n.lik])
    }
    static func podesiPitanja(_ id: String, struka: Int, fokus: [String], udeo: [Int], teza: Bool) async throws -> FirmaDetalj {
        try await rpc("karijera_podesi_pitanja", ["p_firma": id, "p_struka": struka, "p_fokus": fokus, "p_fokus_udeo": udeo, "p_teza": teza])
    }
    /// Zaštita firme od napada (3, 5, 7 ili 10 dana od preuzimanja), jednom po vlasništvu.
    static func izaberiZastitu(_ id: String, dana: Int) async throws -> FirmaDetalj {
        let _: String = try await rpc("karijera_zastita", ["p_firma": id, "p_dana": dana])
        return try await firma(id)
    }
    static func podesiSlobodne(_ id: String, dani: [Int]) async throws -> FirmaDetalj {
        try await rpc("karijera_podesi_slobodne", ["p_firma": id, "p_dani": dani])
    }
    /// Kratki nazivi dana (ISO 1 = ponedeljak). Primer: `Karijera.daniOpis([6, 7])` → „sub, ned”
    static let daniKratko = ["pon", "uto", "sre", "čet", "pet", "sub", "ned"]
    static func daniOpis(_ d: [Int]?) -> String {
        let l = (d ?? []).sorted().compactMap { (1...7).contains($0) ? daniKratko[$0 - 1] : nil }
        return l.isEmpty ? "nema" : l.joined(separator: ", ")
    }
    struct TemaFokusa: Decodable, Identifiable, Hashable { let tema: String; let pitanja: Int; var id: String { tema } }
    static func temeFokusa() async throws -> [TemaFokusa] { try await rpc("karijera_teme_fokusa") }
    struct Mirni: Decodable { let mirni: Bool }
    static func postaviMirni(_ da: Bool) async throws -> Mirni { try await rpc("karijera_mirni", ["p_da": da]) }
    static func temePozicije(_ id: String) async throws -> [Tema] { try await rpc("karijera_teme_pozicije", ["p_pozicija": id]) }
    static func podesi(_ id: String, udeo: String?, kljucne: [String]?) async throws -> FirmaDetalj {
        try await rpc("karijera_podesi_firmu", ["p_firma": id, "p_udeo": udeo ?? NSNull(), "p_kljucne": kljucne ?? NSNull()])
    }
    static func zaposliBota(_ id: String, tema: String) async throws -> FirmaDetalj { try await rpc("karijera_zaposli_bota", ["p_firma": id, "p_tema": tema]) }
    static func obuciBota(_ bot: String) async throws -> FirmaDetalj { try await rpc("karijera_obuci_bota", ["p_bot": bot]) }
    static func nadogradi(_ id: String) async throws -> FirmaDetalj { try await rpc("karijera_nadogradi", ["p_firma": id]) }
    static func dividenda(_ id: String) async throws -> FirmaDetalj { try await rpc("karijera_dividenda", ["p_firma": id]) }
    static func otpusti(_ id: String, igrac: String) async throws -> FirmaDetalj { try await rpc("karijera_otpusti", ["p_firma": id, "p_igrac": igrac]) }
    static func berza(pozicija: String?) async throws -> [Firma] { try await rpc("karijera_berza", ["p_pozicija": pozicija ?? NSNull()]) }

    static func posaljiIzazov(_ firma: String, tema: String) async throws -> Izazov { try await rpc("karijera_posalji_izazov", ["p_firma": firma, "p_tema": tema]) }
    static func prihvatiIzazov(_ id: String, tema1: String, tema3: String) async throws -> Izazov {
        try await rpc("karijera_prihvati_izazov", ["p_izazov": id, "p_tema1": tema1, "p_tema3": tema3])
    }
    static func pitanjaDuela(_ id: String) async throws -> [Pitanje] { try await rpc("karijera_duel_pitanja", ["p_izazov": id]) }
    struct IshodDuela: Decodable { let stanje: String; let moji_tacni: Int; let pobednik: String?; let ishod: String?; let vlasnik_tacnih: Int?; let izazivac_tacnih: Int? }
    static func predajDuel(_ id: String, odgovori: [[String: Any]]) async throws -> IshodDuela {
        try await rpc("karijera_duel_predaj", ["p_izazov": id, "p_odgovori": odgovori])
    }
    static func cv(_ igrac: String? = nil) async throws -> CV { try await rpc("karijera_cv", ["p_igrac": igrac ?? NSNull()]) }
    static func rang(_ vrsta: String) async throws -> [RedRanga] { try await rpc("karijera_rang", ["p_vrsta": vrsta]) }

    // MARK: Prikaz

    static let titule = ["Junior", "Senior", "Menadžer", "Direktor"]
    static let naziviNivoa = ["Garaža", "Kancelarija", "Sprat", "Poslovna zgrada", "Neboder"]
    /// 8 stilova zgrade (vlasnik 05.11: još zgrada, od garaže do nebodera u istom crtežu).
    static let naziviStila = ["Moderno", "Cigla", "Belo", "Kreativno", "Kontejner", "Loft", "Zeleno", "Kruna"]

    static func slikaZgrade(korporacija: Bool, nivo: Int, stil: Int) -> String {
        korporacija ? "Karijera_Korporacija_1" : "Karijera_Zgrada_\(min(max(nivo, 1), 5))_\(min(max(stil, 1), naziviStila.count))"
    }
    static let ceneObuke = [60: 3000, 75: 8000]

    static func udeoNaziv(_ u: String) -> String {
        switch u {
        case "skrt": "Škrt · 50% plata"
        case "izdasan": "Izdašan · 80% plata"
        case "korporacija": "Korporacija · 40% plata"
        default: "Pošten · 65% plata"
        }
    }

    /// Lik asistenta prati ime (karijera_imena_botova na serveru): muška imena 1/3/5, ženska 2/4/6.
    static func slikaBota(_ ime: String) -> String {
        let muska: Set = ["Luka", "Vuk", "Pavle", "Đorđe", "Filip", "Marko", "Relja", "Bogdan", "Stefan", "Ognjen"]
        let zbir = ime.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let izbor = muska.contains(ime) ? [1, 3, 5] : [2, 4, 6]
        return "Karijera_Asistent_\(izbor[zbir % 3])"
    }

    static func novac(_ v: Double) -> String { Int(v.rounded()).formatted(.number.locale(.srpski)) }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
    }()
    private static let isoBez = ISO8601DateFormatter()
    static func datum(_ s: String) -> Date? {
        if s == "infinity" { return .distantFuture }
        return iso.date(from: s) ?? isoBez.date(from: s)
    }
}

/// Muzika Karijere: u svakom trenutku svira najviše jedna petlja (tiho, ispod pitanja).
@MainActor
enum KarijeraMuzika {
    private static let petlje: [Zvuk.Vrsta] = [.karijeraUvod, .karijeraKorporacija, .karijeraFirma, .karijeraPosao, .karijeraOffice,
                                               .karijeraProbniKraj, .karijeraDuel, .karijeraOdbrana, .karijeraFirma2, .karijeraFirma3, .karijeraFirma4]
    /// Muzika u mojoj firmi (vlasnik 05.11): 4 džez numere, svakog dana druga (i različito za različite firme).
    static let mojaFirma: [Zvuk.Vrsta] = [.karijeraFirma, .karijeraFirma2, .karijeraFirma3, .karijeraFirma4]
    static func zaMojuFirmu(_ id: String, dan: Date = .now) -> Zvuk.Vrsta {
        let danBroj = Int(dan.timeIntervalSince1970 / 86_400)
        let seme = id.unicodeScalars.reduce(0) { ($0 * 31 + Int($1.value)) % 997 }
        return mojaFirma[(danBroj + seme) % mojaFirma.count]
    }
    static func pusti(_ v: Zvuk.Vrsta, jacina: Float = 0.3) {
        petlje.filter { $0 != v }.forEach(Zvuk.stani)
        Zvuk.pusti(v, jacina: jacina, ponavljaj: true)
    }
    static func stani() { petlje.forEach(Zvuk.stani) }
}
