import Foundation

// Strategija, drugi talas (vlasnik 03.11.2026, docs/OSVAJANJE-STRATEGIJA.md): teren, linije snabdevanja, čuda sveta,
// magla rata, ulog, marš, najava pohoda, izdaja, trgovina kartama i ultimatum. Sve je u `Stanje` (isti JSON za sve telefone).

enum Teren {
    /// Planine: braniocu +1 tačan.
    static let planine: Set<String> = ["CHE", "AUT", "NPL", "BTN", "BOL", "PER", "GEO", "ARM", "AZE", "AFG", "KGZ", "TJK"]
    /// Pustinja: napadač koji izgubi gubi jednu vojsku više.
    static let pustinja: Set<String> = ["SAH", "MRT", "MLI", "NER", "TCD", "LBY", "EGY", "DZA", "SDN", "SAU", "OMN", "YEM", "ARE", "QAT", "KWT", "NAM", "BWA", "MNG", "TKM"]
    /// Parovi država povezani samo morskim putem: napad preko mora traži jedan tačan više.
    static let more: Set<String> = Set(Mapa.more.map { Stanje.kljucSaveza($0.a, $0.b) })

    static func prekoMora(_ a: String, _ b: String) -> Bool { more.contains(Stanje.kljucSaveza(a, b)) }

    /// Kratak opis terena mete za ekran bitke; nil kad je ravnica.
    static func opis(odakle: String, kuda: String) -> String? {
        var l: [String] = []
        if planine.contains(kuda) { l.append("Planine: branilac +1 tačan") }
        if prekoMora(odakle, kuda) { l.append("Preko mora: napadaču treba 1 tačan više") }
        if pustinja.contains(kuda) { l.append("Pustinja: poraz košta vojsku više") }
        return l.isEmpty ? nil : l.joined(separator: " · ")
    }
}

/// Čudo sveta: jedna država po kontinentu; ko je drži, ima trajnu prednost.
struct Cudo: Equatable {
    let oblast: String
    let naziv: String
    let opis: String
    let ikonica: String

    static let sva: [Cudo] = [
        Cudo(oblast: "EGY", naziv: "Piramide", opis: "+2 vojske svakog kruga.", ikonica: "triangle.fill"),
        Cudo(oblast: "CHN", naziv: "Kineski zid", opis: "+1 tačan u odbrani država u Aziji.", ikonica: "building.columns.fill"),
        Cudo(oblast: "GRC", naziv: "Akropolj", opis: "Ratna karta svakog kruga.", ikonica: "rectangle.portrait.on.rectangle.portrait.fill"),
        Cudo(oblast: "PER", naziv: "Maču Pikču", opis: "Vidiš sve vojske na mapi (bez magle).", ikonica: "mountain.2.fill"),
        Cudo(oblast: "USA", naziv: "Kip slobode", opis: "+1 napad u svakom potezu.", ikonica: "flame.fill"),
        Cudo(oblast: "AUS", naziv: "Sidnejska opera", opis: "+5 sekundi za svako pitanje u bitki.", ikonica: "music.note.house.fill"),
    ]
    static func za(_ oblast: String) -> Cudo? { sva.first { $0.oblast == oblast } }
}

extension Stanje {
    // MARK: Čuda

    /// Da li tim drži čudo u toj državi (i da li ta država postoji u ovoj partiji).
    func drziCudo(_ tim: String, _ oblast: String) -> Bool { oblasti[oblast]?.vlasnik == tim }

    // MARK: Linije snabdevanja

    /// Države tima povezane (kroz njegove države) sa prestonicom nekog člana tima.
    /// Tim bez ijedne prestonice snabdeva se iz najveće povezane grupe, da ne propadne sve odjednom.
    func snabdevene(_ tim: String) -> Set<String> {
        let moje = Set(oblasti.filter { $0.value.vlasnik == tim }.keys)
        guard !moje.isEmpty else { return [] }
        func grupa(_ start: String) -> Set<String> {
            var vidjeno: Set = [start], red = [start]
            while let o = red.popLast() {
                for n in Mapa.susedi(o) where moje.contains(n) && !vidjeno.contains(n) { vidjeno.insert(n); red.append(n) }
            }
            return vidjeno
        }
        let prestonice = igraci.filter { $0.tim == tim && moje.contains($0.prestonica) }.map(\.prestonica)
        if !prestonice.isEmpty { return prestonice.reduce(into: Set<String>()) { $0.formUnion(grupa($1)) } }
        var ostalo = moje, najveca: Set<String> = []
        while let o = ostalo.first { let g = grupa(o); ostalo.subtract(g); if g.count > najveca.count { najveca = g } }
        return najveca
    }

    func odsecene(_ tim: String) -> Set<String> {
        Set(oblasti.filter { $0.value.vlasnik == tim }.keys).subtracting(snabdevene(tim))
    }

    // MARK: Magla rata

    /// Država čije vojske tim vidi: svoja, saveznikova, susedna svojoj, ili sve kad drži Maču Pikču.
    func vidi(_ tim: String, _ oblast: String) -> Bool {
        guard let o = oblasti[oblast] else { return false }
        if drziCudo(tim, "PER") || o.vlasnik == tim || o.vlasnik.map({ uSavezu(tim, $0) }) == true { return true }
        return Mapa.susedi(oblast).contains { oblasti[$0]?.vlasnik == tim }
    }

    /// Procena umesto broja u magli.
    static func procenaVojske(_ n: Int) -> String { n <= 2 ? "≤2" : n <= 5 ? "3–5" : "6+" }

    // MARK: Ulog

    /// Ulog pre bitke sa igračem (0–2): pobeda odnosi braniocu još toliko, poraz napadaču još toliko.
    func postaviUlog(_ n: Int) -> Stanje {
        var s = self
        s.ulog = n > 0 ? min(Pravila.najveciUlog, n) : nil
        return s
    }

    /// Najjača država tima pored `oko` (ne sama `oko`), za odbijanje vojske uloga; nil kad nema nijedne sa 2+.
    func najjacaPored(_ oko: String, tim: String) -> String? {
        Mapa.susedi(oko).filter { oblasti[$0]?.vlasnik == tim && (oblasti[$0]?.vojske ?? 0) > 1 }
            .max { (oblasti[$0]?.vojske ?? 0, $0) < (oblasti[$1]?.vojske ?? 0, $1) }
    }

    // MARK: Marš

    /// Do koje svoje države vojska stiže iz `odakle` kroz najviše `Pravila.korakaMarsa` svojih država.
    func dometMarsa(_ odakle: String) -> Set<String> {
        guard let tim = oblasti[odakle]?.vlasnik else { return [] }
        var dostupno: Set<String> = [], granica: Set = [odakle], vidjeno: Set = [odakle]
        for _ in 0..<Pravila.korakaMarsa {
            var sledeca: Set<String> = []
            for o in granica { for n in Mapa.susedi(o) where oblasti[n]?.vlasnik == tim && !vidjeno.contains(n) { vidjeno.insert(n); sledeca.insert(n) } }
            dostupno.formUnion(sledeca); granica = sledeca
        }
        return dostupno
    }

    // MARK: Najava pohoda

    /// Tajni cilj za ovaj krug: ceo region. Ako ga tim drži na početku svog sledećeg poteza: +3 vojske i karta.
    func najaviPohod(_ region: String) -> Stanje? {
        let tim = trenutni.tim
        let ids = Mapa.oblasti.filter { $0.region == region && oblasti[$0.id] != nil }.map(\.id)
        guard faza != .kraj, pohodi?[tim] == nil, !ids.isEmpty, !ids.allSatisfy({ oblasti[$0]?.vlasnik == tim }) else { return nil }
        var s = self
        var p = s.pohodi ?? [:]
        p[tim] = region
        s.pohodi = p
        return s
    }

    /// Na početku poteza: ispunjen pohod donosi nagradu; neispunjen se samo briše. Vraća nagradu u vojskama.
    mutating func proveriPohod(_ tim: String) -> Int {
        guard let region = pohodi?[tim] else { return 0 }
        pohodi?[tim] = nil
        let ids = Mapa.oblasti.filter { $0.region == region && oblasti[$0.id] != nil }.map(\.id)
        guard !ids.isEmpty, ids.allSatisfy({ oblasti[$0]?.vlasnik == tim }) else { return 0 }
        dodeliKartu(tim)
        var u = uspeliPohodi ?? [:]
        u[tim, default: 0] += 1
        uspeliPohodi = u
        return Pravila.nagradaPohoda
    }

    // MARK: Izdaja

    func jeIzdajnik(_ tim: String) -> Bool { izdajnici?.contains(tim) == true }

    /// Prekid saveza napadom: izdajnik gubi sve karte, svi vide oznaku, botovi s njim više ne sklapaju savez.
    func izdaj(_ tim: String, _ saveznik: String) -> Stanje {
        guard uSavezu(tim, saveznik), !stalniSaveznik(tim, saveznik) else { return self }
        var s = self
        s.savezi?[Stanje.kljucSaveza(tim, saveznik)] = nil
        s.karteTimova?[tim] = []
        if !s.jeIzdajnik(tim) { s.izdajnici = (s.izdajnici ?? []) + [tim] }
        // Kazna (vlasnik 04.11): bez karata i bez moći vojske i pomoći saveznika dva kruga; novi saveznik posle kazne.
        var k = s.kaznaIzdaje ?? [:]; k[tim] = krug + 1; s.kaznaIzdaje = k
        var i = s.izdaje ?? [:]; i[tim, default: 0] += 1; s.izdaje = i
        var r = s.raskid ?? [:]; r[saveznik] = krug; s.raskid = r
        return s
    }

    /// Susedne države saveznika (moguće samo kroz izdaju).
    func meteIzdaje(_ odakle: String) -> [String] {
        guard faza == .napad, bitaka < napadaPoPotezu, let izvor = oblasti[odakle], izvor.vlasnik == trenutni.tim, izvor.vojske >= 2 else { return [] }
        return Mapa.susedi(odakle).filter { id in oblasti[id]?.vlasnik.map { uSavezu(izvor.vlasnik!, $0) && !stalniSaveznik(izvor.vlasnik!, $0) } == true }
    }

    // MARK: Trgovina kartama

    /// Razmena sa saveznikom: daješ kartu `k`, saveznik vraća jednu koju ti nemaš (ili prvu koju ima).
    /// Bot prihvata kad on tu kartu nema. Vraća novo stanje i dobijenu kartu, ili nil kad razmene nema.
    func razmeniKartu(od: String, sa: String, daje k: Karta) -> (Stanje, Karta)? {
        guard uSavezu(od, sa), karte(od).contains(k), !karte(sa).isEmpty, !karte(sa).contains(k) else { return nil }
        let moje = karte(od)
        let vraca = karte(sa).first { !moje.contains($0) } ?? karte(sa)[0]
        var s = self
        var ruke = s.karteTimova ?? [:]
        ruke[od]!.remove(at: ruke[od]!.firstIndex(of: k)!)
        ruke[sa]!.remove(at: ruke[sa]!.firstIndex(of: vraca)!)
        ruke[od]!.append(vraca)
        ruke[sa]!.append(k)
        s.karteTimova = ruke
        return (s, vraca)
    }

    // MARK: Ultimatum

    /// Zahtev slabijem susedu da preda pograničnu državu. Prihvata kad je mnogo slabiji (snaga < 0,6 tvoje) i
    /// država nije prestonica; odbijanje daje napadaču +1 tačan na tu državu do kraja poteza. Jedan po potezu.
    func ultimatum(_ kuda: String) -> (Stanje, prihvaceno: Bool)? {
        let tim = trenutni.tim
        guard faza == .napad, ultimatumKrug?[tim] != krug, let vlasnik = oblasti[kuda]?.vlasnik, vlasnik != tim, !uSavezu(tim, vlasnik),
              Mapa.susedi(kuda).contains(where: { oblasti[$0]?.vlasnik == tim }), snaga(vlasnik) < snaga(tim) else { return nil }
        var s = self
        var uk = s.ultimatumKrug ?? [:]
        uk[tim] = krug
        s.ultimatumKrug = uk
        let prestonica = igraci.contains { $0.tim == vlasnik && $0.prestonica == kuda }
        if !prestonica && snaga(vlasnik) < snaga(tim) * 0.6 && oblasti.values.filter({ $0.vlasnik == vlasnik }).count > 1 {
            s.oblasti[kuda]!.vlasnik = tim
            s = s.posalji("Predajem \(Mapa.oblast(kuda).ime).", od: igraci.first { $0.tim == vlasnik }!.id)
            return (s, true)
        }
        var o = s.odbijeniUltimatumi ?? [:]
        o["\(tim)>\(kuda)"] = krug
        s.odbijeniUltimatumi = o
        s = s.posalji("Nikad!", od: igraci.first { $0.tim == vlasnik }!.id)
        return (s, false)
    }

    func odbioUltimatum(_ tim: String, _ kuda: String) -> Bool { odbijeniUltimatumi?["\(tim)>\(kuda)"] == krug }

    // MARK: Bot

    /// Bot najavljuje pohod na region kome mu fale jedna ili dve države.
    func botNajaviPohod() -> Stanje {
        let tim = trenutni.tim
        guard pohodi?[tim] == nil else { return self }
        let kandidat = Mapa.regioni.map(\.id).first { r in
            let ids = Mapa.oblasti.filter { $0.region == r && oblasti[$0.id] != nil }.map(\.id)
            let fali = ids.filter { oblasti[$0]?.vlasnik != tim }.count
            return !ids.isEmpty && (1...2).contains(fali) && ids.contains { oblasti[$0]?.vlasnik == tim }
        }
        return kandidat.flatMap { najaviPohod($0) } ?? self
    }

    /// Napadač bot u poslednja dva kruga izdaje saveznika koji je upola slabiji od njega.
    func botIzdaja() -> Stanje {
        let tim = trenutni.tim
        guard narav(trenutni.id) == .napadac, krug >= ukupnoKrugova - 1 else { return self }
        guard let zrtva = saveznici(tim).first(where: { snaga($0) * 2 < snaga(tim) && !stalniSaveznik(tim, $0) }) else { return self }
        return izdaj(tim, zrtva).posalji("Izdaja!", od: trenutni.id)
    }

    /// Bot šalje ultimatum slabom susednom botu.
    func botUltimatum() -> Stanje {
        let tim = trenutni.tim
        let moje = oblasti.filter { $0.value.vlasnik == tim }.keys
        let mete = Set(moje.flatMap { Mapa.susedi($0) }).filter { id in
            guard let v = oblasti[id]?.vlasnik, v != tim, let i = igraci.first(where: { $0.tim == v }) else { return false }
            return !i.covek && !i.id.hasPrefix("u:") && snaga(v) < snaga(tim) * 0.6
        }
        guard let kuda = mete.sorted().first, let (s, _) = ultimatum(kuda) else { return self }
        return s
    }

    /// Bot ulaže kad je bitka skoro sigurna (šansa > 0,7 jedan, > 0,85 dva).
    static func ulogBota(_ sansa: Double) -> Int { sansa > 0.85 ? 2 : sansa > 0.7 ? 1 : 0 }
}
