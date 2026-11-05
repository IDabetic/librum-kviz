import Foundation

// Strategija Osvajanja (vlasnik 03.11.2026, docs/OSVAJANJE-STRATEGIJA.md): vrste vojske, ratne karte,
// savezi i brze poruke, događaji po kontinentima. Sve je u `Stanje`, pa putuje istim JSON-om između telefona.

/// Vrsta vojske koju igrač bira pre partije: svaka ima svoju prednost (Legija i Konjica napadaju, Garda i Graditelji grade odbranu).
enum VrstaVojske: String, CaseIterable, Identifiable, Codable {
    case legija, garda, graditelji, izvidnica, konjica, mudraci
    var id: String { rawValue }
    var naziv: String {
        switch self {
        case .legija: "Legija"; case .garda: "Garda"; case .graditelji: "Graditelji"
        case .izvidnica: "Izvidnica"; case .konjica: "Konjica"; case .mudraci: "Mudraci"
        }
    }
    var strategija: String {
        switch self {
        case .legija: "Napad: +1 tačan kad napadaš državu igrača."
        case .garda: "Odbrana: +1 tačan kad braniš svoju državu."
        case .graditelji: "Rast: +1 vojska svakog kruga za svaki ceo region."
        case .izvidnica: "Karte: počinje sa Špijunom, kartu dobija i za svako drugo osvajanje."
        case .konjica: "Brzina: 2 napada više u svakom potezu."
        case .mudraci: "Znanje: 5 sekundi više za svako pitanje u bitki."
        }
    }
    /// Lik vojske (Freepik/macrovector „Medieval tales characters”, Premium licenca; alati u docs/OSVAJANJE-STRATEGIJA.md).
    var heroj: String { "Heroj_" + rawValue }
    var ikonica: String {
        switch self {
        case .legija: "figure.fencing"; case .garda: "shield.lefthalf.filled"; case .graditelji: "building.columns"
        case .izvidnica: "binoculars"; case .konjica: "hare"; case .mudraci: "brain.head.profile"
        }
    }
}

/// Moći vojske u bitki (vlasnik 04.11.2026): svaka vojska ima tri SVOJE moći, nijedna se ne ponavlja; svaka jednom po krugu.
enum PomocVojske: String, CaseIterable, Identifiable, Codable {
    // Legija (napad)
    case sigurniUdar, drugiPokusaj, plen
    // Garda (odbrana)
    case stit, bedem, garnizon
    // Graditelji (rast)
    case radionica, utvrdjenje, temelj
    // Izvidnica (uvid)
    case nagovestaj, prisluskivanje, spijunskaMreza
    // Konjica (brzina)
    case juris, munja, zamena
    // Mudraci (znanje)
    case tacanOdgovor, jedanManje, savetMudraca
    var id: String { rawValue }

    /// Šta moć radi: deo menja pitanje na ekranu (BitkaView), deo ishod bitke (OsvajanjeModel / Pravila).
    enum Dejstvo: Equatable {
        case siguran, drugiPokusaj, plen, stit, bedem, garnizon, radionica, utvrdjenje, temelj
        case nagovestaj, prisluskivanje, spijunskaMreza, dvostruko, munja, zamena, tacanOdgovor, jedanManje, savetMudraca
    }

    var dejstvo: Dejstvo {
        switch self {
        case .sigurniUdar: .siguran; case .drugiPokusaj: .drugiPokusaj; case .plen: .plen
        case .stit: .stit; case .bedem: .bedem; case .garnizon: .garnizon
        case .radionica: .radionica; case .utvrdjenje: .utvrdjenje; case .temelj: .temelj
        case .nagovestaj: .nagovestaj; case .prisluskivanje: .prisluskivanje; case .spijunskaMreza: .spijunskaMreza
        case .juris: .dvostruko; case .munja: .munja; case .zamena: .zamena
        case .tacanOdgovor: .tacanOdgovor; case .jedanManje: .jedanManje; case .savetMudraca: .savetMudraca
        }
    }
    var naziv: String {
        switch self {
        case .sigurniUdar: "Siguran udar"; case .drugiPokusaj: "Drugi pokušaj"; case .plen: "Plen"
        case .stit: "Štit"; case .bedem: "Bedem"; case .garnizon: "Garnizon"
        case .radionica: "Radionica"; case .utvrdjenje: "Utvrđenje"; case .temelj: "Temelj"
        case .nagovestaj: "Nagoveštaj"; case .prisluskivanje: "Prisluškivanje"; case .spijunskaMreza: "Špijunska mreža"
        case .juris: "Juriš"; case .munja: "Munja"; case .zamena: "Promena pitanja"
        case .tacanOdgovor: "Tačan odgovor"; case .jedanManje: "Jedan manje"; case .savetMudraca: "Savet mudraca"
        }
    }
    var opis: String {
        switch self {
        case .sigurniUdar: "Koji god odgovor izabereš, priznaje se kao tačan; ako pogodiš, vredi dva."
        case .drugiPokusaj: "Ako pogrešiš, biraš još jednom između preostalih odgovora."
        case .plen: "Ako osvojiš državu u ovoj bitki, dobija +1 vojsku."
        case .stit: "Ako pogrešiš, greška se briše i dobijaš novo pitanje."
        case .bedem: "Samo u odbrani: napadaču treba jedan tačan više."
        case .garnizon: "Samo u odbrani: ako odbraniš državu, dobija +2 vojske."
        case .radionica: "Svaki tačan u ovoj bitki daje +1 vojsku u prestonicu (najviše 3)."
        case .utvrdjenje: "Samo u napadu: osvojena država do kraja sledećeg kruga traži jedan tačan više od napadača."
        case .temelj: "Samo u napadu: ako izgubiš, ne gubiš državu iz koje napadaš."
        case .nagovestaj: "Pokazuje prvo slovo tačnog odgovora."
        case .prisluskivanje: "Vidiš koliko je tačnih rival imao u ovoj bitki."
        case .spijunskaMreza: "Ako dobiješ ovu bitku, dobijaš kartu Špijun."
        case .juris: "Samo u napadu: sledeći tačan odgovor vredi dva."
        case .munja: "Kod istog broja tačnih pobeđuješ ti, bez obzira na brzinu."
        case .zamena: "Menja pitanje novim."
        case .tacanOdgovor: "Pokazuje tačan odgovor."
        case .jedanManje: "Sklanja jedan netačan odgovor."
        case .savetMudraca: "Mudraci označe odgovor: tačan je u tri od četiri slučaja."
        }
    }
    var ikonica: String {
        switch self {
        case .sigurniUdar: "scope"; case .drugiPokusaj: "arrow.uturn.backward.circle.fill"; case .plen: "bag.fill"
        case .stit: "shield.fill"; case .bedem: "building.columns.fill"; case .garnizon: "person.3.fill"
        case .radionica: "hammer.fill"; case .utvrdjenje: "flag.and.flag.filled.crossed"; case .temelj: "square.stack.3d.down.forward.fill"
        case .nagovestaj: "character.cursor.ibeam"; case .prisluskivanje: "ear.fill"; case .spijunskaMreza: "eye.fill"
        case .juris: "bolt.fill"; case .munja: "hare.fill"; case .zamena: "arrow.triangle.2.circlepath"
        case .tacanOdgovor: "checkmark.seal.fill"; case .jedanManje: "minus.circle.fill"; case .savetMudraca: "brain.head.profile"
        }
    }
    /// Glavna moć vojske (prva od tri).
    var svoja: Bool { VrstaVojske.allCases.contains { $0.moc == self } }
    /// Gde moć sme: samo u napadu, samo u odbrani ili oba.
    var samoNapad: Bool { [.juris, .utvrdjenje, .temelj, .plen].contains(self) }
    var samoOdbrana: Bool { [.bedem, .garnizon].contains(self) }
}

extension VrstaVojske {
    /// Tri moći vojske; prva je glavna.
    var pomoci: [PomocVojske] {
        switch self {
        case .legija: [.sigurniUdar, .drugiPokusaj, .plen]
        case .garda: [.stit, .bedem, .garnizon]
        case .graditelji: [.radionica, .utvrdjenje, .temelj]
        case .izvidnica: [.nagovestaj, .prisluskivanje, .spijunskaMreza]
        case .konjica: [.juris, .munja, .zamena]
        case .mudraci: [.tacanOdgovor, .jedanManje, .savetMudraca]
        }
    }
    var moc: PomocVojske { pomoci[0] }
}

/// Ratna karta: pomoć samo za Osvajanje (dnevne pomoći ovde ne važe). Dobija se za pobedu nad igračem,
/// zatvoren region i proboj; u ruci najviše `Pravila.najviseKarata`.
enum Karta: String, CaseIterable, Identifiable, Codable {
    case spijun, pojacanje, zamrzni, drugiPokusaj, sabotaza
    var id: String { rawValue }
    var naziv: String {
        switch self {
        case .spijun: "Špijun"; case .pojacanje: "Pojačanje"; case .zamrzni: "Zamrzni granicu"
        case .drugiPokusaj: "Drugi pokušaj"; case .sabotaza: "Sabotaža"
        }
    }
    var opis: String {
        switch self {
        case .spijun: "U bitki ti otkriva tačan odgovor na prvo pitanje."
        case .pojacanje: "+2 vojske na izabranu svoju državu (ili prestonicu)."
        case .zamrzni: "Izabranu svoju državu niko ne napada do kraja sledećeg kruga."
        case .drugiPokusaj: "Pitanje koje ti ne leži menjaš novim, bez odgovora."
        case .sabotaza: "U tvom napadu protivnik gubi jedan tačan odgovor."
        }
    }
    var ikonica: String {
        switch self {
        case .spijun: "eye"; case .pojacanje: "plus.circle"; case .zamrzni: "snowflake"
        case .drugiPokusaj: "arrow.uturn.backward"; case .sabotaza: "bolt.slash"
        }
    }
    /// Karte koje se igraju na mapi, van bitke.
    var naMapi: Bool { self == .pojacanje || self == .zamrzni }
}

/// Brza poruka u partiji (bez slobodnog teksta, pa bez moderacije).
struct BrzaPoruka: Equatable, Codable {
    let od: String
    let tekst: String
    let kad: Double

    static let ponuda = ["Napadam te!", "Savez?", "Bravo!", "Čuvaj se!", "Hvala!", "Osveta!"]
}

/// Događaj na kontinentu: kreće svaka `Pravila.dogadjajSvakih` kruga i traje `Pravila.trajanjeDogadjaja`.
struct Dogadjaj: Equatable, Codable {
    let kontinent: String
    let od: Int
    let doKruga: Int

    var naziv: String { Self.opis[kontinent]?.0 ?? "" }
    var tekst: String { Self.opis[kontinent]?.1 ?? "" }
    var ikonica: String { Self.opis[kontinent]?.2 ?? "sparkles" }

    /// Za svaki kontinent jedan događaj: naziv, pravilo, ikonica.
    static let opis: [String: (String, String, String)] = [
        "evr": ("Zima u Evropi", "Napadaču u Evropi treba jedan tačan više.", "snowflake"),
        "afr": ("Zlatno doba Afrike", "Ceo region u Africi daje duplo vojske.", "sun.max"),
        "azi": ("Monsun u Aziji", "Države u Aziji ne mogu da se napadnu.", "cloud.heavyrain"),
        "sam": ("Zlatna groznica", "Svaka osvojena država u Severnoj Americi daje +1 vojsku.", "dollarsign.circle"),
        "jam": ("Karneval", "Pitanja u bitkama za Južnu Ameriku traju 10 s duže.", "music.note"),
        "oke": ("Cunami", "Države u Okeaniji su izgubile pola vojske.", "water.waves"),
    ]
}

/// Misije koje je igrač na ovom telefonu skoro dobio: iste ne dolaze ponovo 7 dana dok ima drugih.
enum MisijeIstorija {
    private static let kljuc = "osvajanje.misije"
    private static let nedelja: TimeInterval = 7 * 86_400

    static func skorasnje(_ sad: Date = .now) -> Set<String> {
        let zapis = UserDefaults.standard.dictionary(forKey: kljuc) as? [String: Double] ?? [:]
        return Set(zapis.filter { sad.timeIntervalSince1970 - $0.value < nedelja }.keys)
    }

    static func zapamti(_ id: String, _ sad: Date = .now) {
        var zapis = UserDefaults.standard.dictionary(forKey: kljuc) as? [String: Double] ?? [:]
        zapis = zapis.filter { sad.timeIntervalSince1970 - $0.value < nedelja }
        zapis[id] = sad.timeIntervalSince1970
        UserDefaults.standard.set(zapis, forKey: kljuc)
    }
}

extension Stanje {
    // MARK: Vrste vojske

    func vojska(_ igracId: String) -> VrstaVojske? { igraci.first { $0.id == igracId }?.vojska }

    /// Vojska tima: kapitenova (on bira odbranu i za ceo tim).
    func vojskaTima(_ tim: String) -> VrstaVojske? {
        (igraci.first { $0.tim == tim && $0.kapiten } ?? igraci.first { $0.tim == tim })?.vojska
    }

    /// Botu vojska prema naravi, da napadač ima napadačku vojsku, a oprezan odbrambenu.
    static func vojskaBota(_ id: String, seme: UInt32? = nil) -> VrstaVojske {
        let h = seme.map { Int(mesaj(id, $0, 7) * 2) } ?? id.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        switch narav(id, seme: seme) {
        case .napadac: return h % 2 == 0 ? .legija : .konjica
        case .graditelj: return h % 2 == 0 ? .graditelji : .izvidnica
        case .oprezan: return h % 2 == 0 ? .garda : .mudraci
        }
    }

    // MARK: Pomoći vojske (jednom po krugu)

    func iskoriscenaPomoc(_ tim: String, _ p: PomocVojske) -> Bool { pomociVojske?["\(tim)|\(p.rawValue)"] == krug }

    /// Beleži pomoć za ovaj krug; nil kad tim nema tu pomoć ili ju je već iskoristio u ovom krugu.
    func iskoristiPomocVojske(_ tim: String, _ p: PomocVojske) -> Stanje? {
        guard vojskaTima(tim)?.pomoci.contains(p) == true, !iskoriscenaPomoc(tim, p), !podKaznom(tim) else { return nil }
        var s = self
        var m = s.pomociVojske ?? [:]
        m["\(tim)|\(p.rawValue)"] = krug
        s.pomociVojske = m
        return s
    }

    // MARK: Karte

    func karte(_ tim: String) -> [Karta] { karteTimova?[tim] ?? [] }

    /// Dodaje kartu timu; vrsta je određena krugom, bitkom i timom, pa je ista na svakom telefonu.
    mutating func dodeliKartu(_ tim: String) {
        var sve = karteTimova ?? [:]
        guard (sve[tim]?.count ?? 0) < Pravila.najviseKarata else { return }
        let h = tim.unicodeScalars.reduce(krug * 31 + bitaka * 7) { $0 + Int($1.value) }
        sve[tim, default: []].append(Karta.allCases[h % Karta.allCases.count])
        karteTimova = sve
    }

    /// Troši jednu kartu tima; nil kad je nema.
    func iskoristiKartu(_ tim: String, _ k: Karta) -> Stanje? {
        guard var ruka = karteTimova?[tim], let i = ruka.firstIndex(of: k) else { return nil }
        ruka.remove(at: i)
        var s = self
        s.karteTimova?[tim] = ruka
        return s
    }

    /// Pojačanje: +2 vojske na svoju državu.
    func igrajPojacanje(_ oblastId: String) -> Stanje? {
        let tim = trenutni.tim
        guard faza != .kraj, oblasti[oblastId]?.vlasnik == tim, var s = iskoristiKartu(tim, .pojacanje) else { return nil }
        s.oblasti[oblastId]!.vojske += Pravila.vojskiPojacanja
        return s
    }

    /// Zamrzni granicu: svoju državu niko ne napada do kraja sledećeg kruga.
    func igrajZamrzni(_ oblastId: String) -> Stanje? {
        let tim = trenutni.tim
        guard faza != .kraj, oblasti[oblastId]?.vlasnik == tim, var s = iskoristiKartu(tim, .zamrzni) else { return nil }
        var z = s.zamrznuto ?? [:]
        z[oblastId] = krug + 1
        s.zamrznuto = z
        return s
    }

    func jeZamrznuta(_ oblastId: String) -> Bool { (zamrznuto?[oblastId] ?? 0) >= krug }

    // MARK: Savezi

    static func kljucSaveza(_ a: String, _ b: String) -> String { [a, b].sorted().joined(separator: "|") }

    func uSavezu(_ a: String, _ b: String) -> Bool { a != b && (savezi?[Self.kljucSaveza(a, b)] ?? 0) >= krug }

    /// Savez traje dok se ne raskine ili izda (vlasnik 04.11: jedan saveznik, do kraja igre).
    static let savezDoKraja = 9999

    /// Strana tima za kraj partije: tim i njegov saveznik pobeđuju zajedno (oznaka je manji od dva tima).
    func strana(_ tim: String) -> String { ([tim] + saveznici(tim)).min()! }

    /// Stari stalni savez iz čekaonice više ne postoji: svaki savez može da se raskine ili izda.
    func stalniSaveznik(_ a: String, _ b: String) -> Bool { false }

    /// Diplomatski raskid: savez važi do kraja ovog kruga, novi saveznik tek posle sledećeg.
    func raskiniSavez(_ tim: String) -> Stanje? {
        guard let drug = saveznici(tim).first else { return nil }
        var s = self
        s.savezi?[Self.kljucSaveza(tim, drug)] = krug
        var r = s.raskid ?? [:]
        r[tim] = krug + 1; r[drug] = krug + 1
        s.raskid = r
        return s
    }

    /// Tim je pod kaznom za izdaju (bez moći vojske i bez pomoći saveznika).
    func podKaznom(_ tim: String) -> Bool { (kaznaIzdaje?[tim] ?? 0) >= krug }

    /// Zamena misija sa saveznikom, do 5. kruga: kad obe strane predlože (ili bot prihvati), misije se menjaju.
    func predloziZamenuMisije(od: String, za: String, prihvata: Bool = false) -> Stanje? {
        guard uSavezu(od, za), krug <= Pravila.zamenaMisijaDoKruga, misije[od] != nil, misije[za] != nil else { return nil }
        var s = self
        var p = s.predloziZamene ?? []
        if prihvata || p.contains("\(za)>\(od)") {
            let (mo, mz) = (s.misije[od], s.misije[za])
            s.misije[od] = mz; s.misije[za] = mo
            let (to, tz) = (s.metaMisije[od], s.metaMisije[za])
            s.metaMisije[od] = tz; s.metaMisije[za] = to
            // Meta misije „izbaci” ne sme biti sam vlasnik misije.
            for t in [od, za] where s.metaMisije[t] == t { s.metaMisije[t] = igraci.map(\.tim).first { $0 != od && $0 != za } }
            s.misijaOd?[od] = nil; s.misijaOd?[za] = nil
            p.removeAll { $0 == "\(za)>\(od)" || $0 == "\(od)>\(za)" }
        } else if !p.contains("\(od)>\(za)") {
            p.append("\(od)>\(za)")
        }
        s.predloziZamene = p
        return s
    }

    /// Bot menja misiju kad mu je savezničeva bliža ispunjenju od njegove.
    func botPrihvataZamenu(bot: String, od: String) -> Bool {
        var probno = self
        probno.misije[bot] = misije[od]
        return probno.napredakMisije(bot) > napredakMisije(bot)
    }

    /// Države preko kojih tim može savezniku da pošalje pojačanje: (moja sa 3+ vojske, saveznikova najslabija pored nje).
    func putPomoci(od: String, za: String) -> (String, String)? {
        guard uSavezu(od, za), pomocSavezniku?[od] != krug, !podKaznom(od), !podKaznom(za) else { return nil }
        var najbolje: (String, String, Int)?
        for a in oblastiIgraca(od) where (oblasti[a]?.vojske ?? 0) >= Pravila.vojskiPomociSavezniku + 1 {
            for b in Mapa.susedi(a) where oblasti[b]?.vlasnik == za {
                let v = oblasti[b]!.vojske
                if najbolje == nil || v < najbolje!.2 { najbolje = (a, b, v) }
            }
        }
        return najbolje.map { ($0.0, $0.1) }
    }

    /// Savezničko pojačanje: 2 vojske preko zajedničke granice, jednom po krugu.
    func posaljiPomoc(od: String, za: String) -> Stanje? {
        guard faza != .kraj, let (a, b) = putPomoci(od: od, za: za) else { return nil }
        var s = self
        s.oblasti[a]!.vojske -= Pravila.vojskiPomociSavezniku
        s.oblasti[b]!.vojske += Pravila.vojskiPomociSavezniku
        var p = s.pomocSavezniku ?? [:]
        p[od] = krug
        s.pomocSavezniku = p
        s.poslednjaPomoc = [od, za, a, b, "\(krug)-\(bitaka)-\(naPotezu)"]
        return s
    }

    /// Bot pomaže savezniku čija je granica slaba (najviše 2 vojske), ako sam ima viška.
    func botPomazeSavezniku() -> Stanje {
        let tim = trenutni.tim
        for z in saveznici(tim) {
            if let (_, b) = putPomoci(od: tim, za: z), (oblasti[b]?.vojske ?? 0) <= 2, let novo = posaljiPomoc(od: tim, za: z) {
                return novo.posalji("Šaljem pomoć!", od: trenutni.id)
            }
        }
        return self
    }

    /// Saveznici tima koji još važe.
    func saveznici(_ tim: String) -> [String] {
        Set(igraci.map(\.tim)).filter { uSavezu(tim, $0) }.sorted()
    }

    /// Predlog saveza: kad postoji i obrnut predlog (ili druga strana prihvata), savez važi do kraja sledećeg kruga.
    func predloziSavez(od: String, za: String, prihvata: Bool = false) -> Stanje {
        // Najviše jedan saveznik; posle raskida novi tek kad prođe krug.
        guard od != za, !uSavezu(od, za), mozeSavez, saveznici(od).isEmpty, saveznici(za).isEmpty,
              (raskid?[od] ?? 0) < krug, (raskid?[za] ?? 0) < krug else { return self }
        var s = self
        var predlozi = s.predloziSaveza ?? []
        if prihvata || predlozi.contains("\(za)>\(od)") {
            var sv = s.savezi ?? [:]
            sv[Self.kljucSaveza(od, za)] = Self.savezDoKraja
            s.savezi = sv
            predlozi.removeAll { $0 == "\(za)>\(od)" || $0 == "\(od)>\(za)" }
        } else if !predlozi.contains("\(od)>\(za)") {
            predlozi.append("\(od)>\(za)")
        }
        s.predloziSaveza = predlozi
        return s
    }

    /// Savez ima smisla kad su u igri bar tri strane.
    var mozeSavez: Bool { Set(igraci.filter { !$0.ispao }.map(\.tim)).count >= 3 }

    /// Bot prihvata savez kad predlagač nije najjači rival (ili kad je bot oprezan) i kad već nema dva saveza.
    func botPrihvataSavez(bot: String, od: String) -> Bool {
        guard saveznici(bot).isEmpty, saveznici(od).isEmpty, !jeIzdajnik(od), let botId = igraci.first(where: { $0.tim == bot })?.id else { return false }
        let najjaci = Set(igraci.filter { !$0.ispao && $0.tim != bot }.map(\.tim)).max { snaga($0) < snaga($1) }
        return od != najjaci || narav(botId) == .oprezan
    }

    // MARK: Poruke

    func posalji(_ tekst: String, od: String, kad: Date = .now) -> Stanje {
        var s = self
        s.poruke = Array(((s.poruke ?? []) + [BrzaPoruka(od: od, tekst: tekst, kad: kad.timeIntervalSince1970)]).suffix(8))
        return s
    }

    /// Poslednja poruka igrača ako je mlađa od 6 s (oblačić iznad igrača).
    func svezaPoruka(_ igracId: String, sad: Date = .now) -> String? {
        guard let p = poruke?.last(where: { $0.od == igracId }), sad.timeIntervalSince1970 - p.kad < 6 else { return nil }
        return p.tekst
    }

    // MARK: Događaji

    func aktivanDogadjaj(_ kontinentId: String) -> Bool {
        guard let d = dogadjaj, d.kontinent == kontinentId else { return false }
        return (d.od...d.doKruga).contains(krug)
    }

    /// Na početku kruga deljivog sa `dogadjajSvakih` bira se kontinent iz igre (isto na svakom telefonu).
    mutating func pokreniDogadjajAkoTreba() {
        guard krug > 1, krug % Pravila.dogadjajSvakih == 0, dogadjaj?.od != krug else { return }
        let uIgri = Kontinenti.svi.filter { k in Kontinenti.oblasti(k.id).contains { oblasti[$0] != nil } }
        guard !uIgri.isEmpty else { return }
        var r = Slucajno(seme: UInt32(truncatingIfNeeded: krug * 7919 + igraci.map(\.id).joined().unicodeScalars.reduce(0) { $0 + Int($1.value) }) ^ (seme ?? 0))
        let k = uIgri[Int(r.sledeci() * Double(uIgri.count))].id
        dogadjaj = Dogadjaj(kontinent: k, od: krug, doKruga: krug + Pravila.trajanjeDogadjaja - 1)
        if k == "oke" {
            for id in Kontinenti.oblasti(k) where oblasti[id]?.vlasnik != nil { oblasti[id]!.vojske = max(1, oblasti[id]!.vojske / 2) }
        }
    }

    // MARK: Bot: karte i savezi

    /// Na početku poteza bot igra karte sa mape: Pojačanje na najugroženiju granicu, Zamrzni na prestonicu pod pretnjom.
    func botIgraKarte() -> Stanje {
        var s = self
        let tim = trenutni.tim
        let cilj = ciljBota(tim)
        let moje = oblastiIgraca(trenutni.id)
        while s.karte(tim).contains(.pojacanje), let gde = moje.max(by: { s.pretnja($0, tim: tim, cilj: cilj) < s.pretnja($1, tim: tim, cilj: cilj) }),
              let novo = s.igrajPojacanje(gde) { s = novo }
        if s.karte(tim).contains(.zamrzni), s.oblasti[trenutni.prestonica]?.vlasnik == tim, !s.jeZamrznuta(trenutni.prestonica),
           s.pretnja(trenutni.prestonica, tim: tim, cilj: cilj) >= 4, let novo = s.igrajZamrzni(trenutni.prestonica) { s = novo }
        return s
    }

    /// Kad neko pobegne (snaga 1,4 puta veća od botove), bot nudi savez susednom rivalu koji nije taj vođa.
    func botTraziSavez() -> Stanje {
        let tim = trenutni.tim
        let zivi = Set(igraci.filter { !$0.ispao && $0.tim != tim }.map(\.tim))
        guard saveznici(tim).isEmpty, let vodja = zivi.max(by: { (snaga($0), $0) < (snaga($1), $1) }), snaga(vodja) > snaga(tim) * 1.4 else { return self }
        let moje = oblasti.filter { $0.value.vlasnik == tim }.keys
        let susedi = Set(moje.flatMap { Mapa.susedi($0) }.compactMap { oblasti[$0]?.vlasnik }).intersection(zivi).subtracting([vodja])
        guard let drug = susedi.sorted().first(where: { t in igraci.contains { $0.tim == t && !$0.covek && !$0.id.hasPrefix("u:") } }),
              botPrihvataSavez(bot: drug, od: tim) else { return self }
        return predloziSavez(od: tim, za: drug, prihvata: true).posalji("Savez?", od: trenutni.id)
    }

    // MARK: Prednost u bitki

    /// Prednost napadača u tačnim odgovorima (negativno = branioca): višak vojske (najviše ±2), Legija, Garda, Zima u Evropi.
    func pomakBitke(odakle: String, kuda: String) -> Int {
        guard let izvor = oblasti[odakle], let meta = oblasti[kuda], let branilac = meta.vlasnik else { return 0 }
        let visak = (izvor.vojske - 1) - meta.vojske
        var p = min(Pravila.najvecaPrednostVojske, max(-Pravila.najvecaPrednostVojske, visak))
        if let n = izvor.vlasnik, vojskaTima(n) == .legija { p += 1 }
        if vojskaTima(branilac) == .garda { p -= 1 }
        if aktivanDogadjaj("evr") && Kontinenti.od(kuda).id == "evr" { p -= 1 }
        // Teren, Kineski zid i odbijen ultimatum.
        if Teren.planine.contains(kuda) { p -= 1 }
        if Teren.prekoMora(odakle, kuda) { p -= 1 }
        if drziCudo(branilac, "CHN") && Kontinenti.od(kuda).id == "azi" { p -= 1 }
        if let n = izvor.vlasnik, odbioUltimatum(n, kuda) { p += 1 }
        if let n = izvor.vlasnik, kontranapad?[n] == odakle { p += 1 }
        if (bedemi?[kuda] ?? 0) >= krug { p -= 1 }
        return p
    }

    /// Da li napadač osvaja državu igrača: tačni + prednost, kod jednakog brži (osim uz odbranu „Prednost”).
    func osvaja(odakle: String, kuda: String, napadac: Skor, branilac: Skor) -> Bool {
        let potrebno = odbranaMete(kuda) == .prednost ? 2 : 1
        let razlika = napadac.tacnih - branilac.tacnih + pomakBitke(odakle: odakle, kuda: kuda)
        return razlika >= potrebno || (potrebno == 1 && razlika == 0 && napadac.ms < branilac.ms)
    }
}
