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
        /// Ratne karte odigrane u ovoj bitki.
        var spijun = false
        var sabotaza = false
        /// Protivnik je odigrao Sabotažu: meni jedan tačan manje.
        var sabotiranSam = false
        /// Napadač bira temu pitanja od ponuđenih (uvod bitke); nil = mešano.
        var teme: [String] = []
        var tema: String?
        /// Pomoći vojske u ovoj bitki: sledeći tačan vredi dva (Juriš); greška se briše uz novo pitanje (Štit);
        /// svaki odgovor je tačan, pravi vredi dva (Siguran udar); sat tekućeg pitanja stoji (Vreme stoji).
        var dvostruko = false
        var stit = false
        var siguran = false
        var satStoji = false
        /// Moći korišćene u ovoj bitki (za efekte posle bitke i prikaz).
        var moci: Set<PomocVojske> = []
        /// Drugi pokušaj: posle greške isto pitanje, bez izabranog odgovora.
        var drugiPokusaj = false
        var iskljuceni: Set<Int> = []
        /// Rivalov skor kad je poznat unapred (bot ili napad sa drugog telefona), za Prisluškivanje.
        var rivalPoznat: Skor?
        /// Prednost u tačnim iz ugla napadača (vojska, Legija/Garda, teren, događaj), zapamćena na početku bitke
        /// jer se posle ishoda vojske pomeraju; ekran rezultata je pokazuje uz skor.
        var pomak = 0
    }

    private(set) var stanje: Stanje { didSet { zabeleziPromene(stari: oldValue); zvuciPromena(stari: oldValue) } }
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
    private var dopunaRadi = false
    /// Vlasnik 03.11: pitanja raspoređena po kontinentima; bitka za državu ima do dva pitanja o njenom kontinentu.
    private var spiloviKontinenta: [String: Spil] = [:]
    private var dopunaKontinenta: Set<String> = []
    private static let pitanjaOKontinentu = 2
    /// Kad u špilu ostane manje od ovoliko pitanja, stiže novi paket (bitka troši do 5, potez do 5 bitaka).
    private static let pragDopune = 30
    private var botRadi = false
    /// Raste kad čuvar prekine zaglavljen potez bota: stari zadatak bota tada ne sme da završi potez drugi put.
    private var generacijaBota = 0
    private var cuvar: Task<Void, Never>?
    /// Igrač je izašao iz partije (X): botovi staju, sat i zvuci se gase (vlasnik 04.11: posle izlaska su i dalje ratovali).
    private(set) var napusteno = false

    /// Gasi sve što partija radi u pozadini; sačuvana partija ostaje za nastavak.
    func napusti() {
        guard !napusteno else { return }
        napusteno = true
        satPoteza?.cancel()
        satPoteza = nil
        pauza = false
        Zvuk.staniSve()
    }
    #if DEBUG
    /// `-demoBrzo`: botovi bez pauze, za duge probe stabilnosti.
    private let pauzaBota: Duration = ProcessInfo.processInfo.arguments.contains("-demoBrzo") ? .milliseconds(40) : .milliseconds(700)
    #else
    private let pauzaBota: Duration = .milliseconds(700)
    #endif

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
                             misije: p.teren == nil, teren: p.teren, izbegniMisije: MisijeIstorija.skorasnje())
        slucajno = s
        postavka = p
        if let soba = p.soba, let ja = p.korisnik {
            veza = VezaOsvajanja(soba: soba, ja: ja, domacin: p.domacin)
            // Ostali čekaju početno stanje domaćina (njegova mapa, misije i redosled).
            cekaPocetak = !p.domacin
        }
        stanje.igraci = stanje.igraci.map { var i = $0; if let v = veza { i.covek = i.id == v.mojId }; return i }
        #if DEBUG
        // Samo provera na simulatoru (`-jedanKrug`): partija od jednog kruga, da se brzo vidi kraj.
        if ProcessInfo.processInfo.arguments.contains("-jedanKrug") { stanje.ukupnoKrugova = 1 }
        // Snimak za sajt (`-demo`): svi su botovi, partija se igra sama.
        if ProcessInfo.processInfo.arguments.contains("-demo") && !LibrumKvizApp.demoOdbrana && !LibrumKvizApp.demoIgrac { stanje.igraci = stanje.igraci.map { var i = $0; i.covek = false; return i } }
        #endif
    }

    /// Nastavak sačuvane partije (samo partije na ovom telefonu, bez servera).
    init(nastavak n: Nastavak) {
        stanje = n.stanje
        slucajno = Slucajno(seme: UInt32(truncatingIfNeeded: Int(Date().timeIntervalSince1970 * 1000)))
        tacnih = n.tacnih; netacnih = n.netacnih; zbirMs = n.zbirMs
        nastavljena = true
        postavka = OsvajanjePostavka(nacin: OsvajanjePostavka.Nacin(rawValue: n.nacin ?? "") ?? .svakoZaSebe, igraca: n.stanje.igraci.count,
                                     krugova: n.stanje.ukupnoKrugova, tezina: Tezina.allCases.first { $0.tacnost == n.stanje.tacnostBota } ?? .normalno,
                                     igraci: n.stanje.igraci.map { NoviIgrac(id: $0.id, ime: $0.ime, boja: $0.boja, covek: $0.covek, tim: $0.tim, kapiten: $0.kapiten, vojska: $0.vojska) },
                                     teren: n.teren)
    }

    // MARK: Čuvanje partije („Nastavi partiju” na početnoj)

    struct Nastavak: Codable, Identifiable {
        let stanje: Stanje; let nacin: String?; let teren: String?; let tacnih: Int; let netacnih: Int; let zbirMs: Int
        var id: String { "\(stanje.krug)-\(stanje.naPotezu)-\(stanje.bitaka)" }
    }
    private static let kljucNastavka = "osvajanje.nastavak"
    /// Partija je nastavljena iz sačuvanog stanja: bez misije i postavljanja, potez se samo nastavlja.
    private(set) var nastavljena = false

    static func sacuvana() -> Nastavak? {
        guard let d = UserDefaults.standard.data(forKey: kljucNastavka), let n = try? JSONDecoder().decode(Nastavak.self, from: d), n.stanje.faza != .kraj else { return nil }
        return n
    }

    static func obrisiSacuvanu() { UserDefaults.standard.removeObject(forKey: kljucNastavka) }

    /// Čuva se partija na telefonu (ne preko servera), posle postavljanja, na svakom potezu i bitki.
    private func sacuvaj() {
        guard veza == nil, postavljanje == nil else { return }
        if stanje.faza == .kraj { Self.obrisiSacuvanu(); return }
        let n = Nastavak(stanje: stanje, nacin: postavka?.nacin.rawValue, teren: postavka?.teren, tacnih: tacnih, netacnih: netacnih, zbirMs: zbirMs)
        if let d = try? JSONEncoder().encode(n) { UserDefaults.standard.set(d, forKey: Self.kljucNastavka) }
    }

    // MARK: Efekti na mapi (udar, brojke vojski, zatvoren region) i reprodukcija partije

    struct Udar: Equatable {
        let odakle: String; let kuda: String; let osvojeno: Bool; let kad: Date
        /// Boja države pre osvajanja (nil = neutralna), da se nova boja „razlije” preko stare.
        var staraBoja: UInt32? = nil
        var novaBoja: UInt32? = nil
    }
    struct Iskok: Equatable { let oblast: String; let promena: Int; let kad: Date }
    struct ZatvorenRegion: Equatable { let region: String; let boja: UInt32; let kad: Date }
    private(set) var udar: Udar?
    private(set) var iskoci: [Iskok] = []
    private(set) var zatvoreni: [ZatvorenRegion] = []
    /// Vlasnici država posle svake promene (za reprodukciju na kraju); najviše 400 slika.
    private(set) var istorija: [[String: String]] = []

    private func zabeleziPromene(stari: Stanje) {
        let sad = Date()
        var nove: [Iskok] = []
        var vlasniciPromenjeni = false
        for (id, o) in stanje.oblasti {
            guard let pre = stari.oblasti[id] else { continue }
            if pre.vlasnik != o.vlasnik { vlasniciPromenjeni = true }
            else if pre.vojske != o.vojske, o.vlasnik != nil { nove.append(Iskok(oblast: id, promena: o.vojske - pre.vojske, kad: sad)) }
        }
        if !nove.isEmpty { iskoci = (iskoci.filter { sad.timeIntervalSince($0.kad) < MapaView.Efekti.trajanjeIskoka } + nove).suffix(24) }
        guard vlasniciPromenjeni else { return }
        istorija.append(stanje.oblasti.compactMapValues(\.vlasnik))
        if istorija.count > 400 { istorija.removeFirst(istorija.count - 400) }
        for r in Mapa.regioni {
            let ids = Mapa.oblasti.filter { $0.region == r.id && stanje.oblasti[$0.id] != nil }.map(\.id)
            guard let v = stanje.oblasti[ids.first ?? ""]?.vlasnik, ids.allSatisfy({ stanje.oblasti[$0]?.vlasnik == v }),
                  !ids.allSatisfy({ stari.oblasti[$0]?.vlasnik == v }), let boja = stanje.igraci.first(where: { $0.tim == v })?.boja else { continue }
            zatvoreni = (zatvoreni.filter { sad.timeIntervalSince($0.kad) < 2 } + [ZatvorenRegion(region: r.id, boja: boja, kad: sad)])
            if v == mojTim { javi("Ceo region \(r.ime) je tvoj!"); efekt(.region(r.ime)) }
        }
    }

    private func udari(_ odakle: String, _ kuda: String, _ osvojeno: Bool) {
        let boja = { (tim: String?) in self.stanje.igraci.first { $0.tim == tim }?.boja }
        // Pre osvajanja: pretposlednja slika vlasnika (zabeleziPromene je već upisala novu).
        let stari = osvojeno && istorija.count > 1 ? istorija[istorija.count - 2][kuda] : nil
        udar = Udar(odakle: odakle, kuda: kuda, osvojeno: osvojeno, kad: Date(),
                    staraBoja: boja(stari), novaBoja: boja(stanje.oblasti[kuda]?.vlasnik))
        // Svoje bitke imaju zvuk na ekranu ishoda; ovde samo bot koji osvaja.
        if osvojeno, bitka == nil, stanje.oblasti[odakle]?.vlasnik != mojTim { Zvuk.pusti(.botOsvaja, jacina: 0.5) }
    }

    /// Zvuci iz promena stanja (krug, potez, pojačanja, karte, savez, izdaja, poruka, događaj, čudo, misija).
    private func zvuciPromena(stari: Stanje) {
        guard let ja = mojTim else { return }
        let n = stanje
        if n.faza == .kraj {
            if stari.faza != .kraj, n.timSaIspunjenomMisijom == ja { Zvuk.pusti(.misija, jacina: 0.55) }
            return
        }
        if n.krug > stari.krug { Zvuk.pusti(.noviKrug, jacina: 0.35) }
        if (n.naPotezu != stari.naPotezu || n.krug != stari.krug), n.trenutni.covek { Zvuk.pusti(.tvojPotez, jacina: 0.45); efekt(.tvojPotez) }
        // Kombo: druga i dalje osvojena država u istom mom potezu.
        if n.trenutni.covek, n.trenutni.tim == ja, n.niz > stari.niz, n.niz >= 2 { Zvuk.pusti(.kombo, jacina: 0.5); efekt(.kombo(n.niz)) }
        if n.trenutni.covek, n.zaRaspored > stari.zaRaspored { Zvuk.pusti(.pojacanja, jacina: 0.45) }
        if n.trenutni.covek, n.zaRaspored < stari.zaRaspored, n.zaRaspored > 0 || stari.faza == .raspored { Zvuk.pusti(.vojskaStavi, jacina: 0.4) }
        var izgubio = false, cudo = false
        for (id, o) in n.oblasti where stari.oblasti[id]?.vlasnik != o.vlasnik {
            if stari.oblasti[id]?.vlasnik == ja { izgubio = true }
            if o.vlasnik == ja, Cudo.za(id) != nil { cudo = true }
        }
        if cudo { Zvuk.pusti(.cudo, jacina: 0.55) } else if izgubio, bitka == nil { Zvuk.pusti(.izgubioDrzavu, jacina: 0.5) }
        if izgubio { udarac += 1 }
        // Tuđa prestonica pala u moje ruke: konfete.
        if n.igraci.contains(where: { $0.tim != ja && n.oblasti[$0.prestonica]?.vlasnik == ja && stari.oblasti[$0.prestonica]?.vlasnik != ja }) { efekt(.prestonica) }
        if (n.karteTimova?[ja]?.count ?? 0) > (stari.karteTimova?[ja]?.count ?? 0), let k = n.karteTimova?[ja]?.last {
            Zvuk.pusti(.kartaDobijena, jacina: 0.45)
            novaKarta = NovaKarta(karta: k)
        }
        // Saveznik mi je poslao vojsku: kartica „+2 iz …” i kamera na tu državu.
        if let p = n.poslednjaPomoc, p != stari.poslednjaPomoc, p.count >= 4, p[1] == ja, let od = n.igraci.first(where: { $0.tim == p[0] }) {
            Zvuk.pusti(.pomocVojske, jacina: 0.5)
            primljenaPomoc = PrimljenaPomoc(od: od.ime, boja: od.boja, iz: p[2], u: p[3])
            udari(p[2], p[3], false)
        }
        if (n.savezi?.count ?? 0) > (stari.savezi?.count ?? 0) { Zvuk.pusti(.savez, jacina: 0.45) }
        if (n.izdajnici?.count ?? 0) > (stari.izdajnici?.count ?? 0) { Zvuk.pusti(.izdaja, jacina: 0.5) }
        if (n.poruke?.count ?? 0) > (stari.poruke?.count ?? 0), let p = n.poruke?.last,
           n.igraci.first(where: { $0.id == p.od })?.covek != true { Zvuk.pusti(.poruka, jacina: 0.4) }
        if let d = n.dogadjaj, d != stari.dogadjaj { Zvuk.pusti(.dogadjaj, jacina: 0.5) }
        // Neko je upravo ispunio misiju: moj tim fanfara, rival uzbuna.
        for (t, _) in n.misijaOd ?? [:] where stari.misijaOd?[t] == nil {
            Zvuk.pusti(t == ja ? .misija : .uzbuna, jacina: 0.5)
            if t != ja, let i = n.igraci.first(where: { $0.tim == t }) { javi("\(i.ime) je ispunio tajnu misiju!") }
        }
    }

    // MARK: Iskakanja (nova karta, pomoć saveznika)

    struct NovaKarta: Identifiable, Equatable { let id = UUID(); let karta: Karta }
    /// Efekti preko celog ekrana (vlasnik 04.11: „više animacija, da bude živo i zarazno”).
    struct Efekat: Identifiable, Equatable {
        enum Vrsta: Equatable { case kombo(Int), region(String), prestonica, izgubio, tvojPotez, pobeda }
        let id = UUID(); let vrsta: Vrsta
    }
    var efekat: Efekat?
    /// Raste kad izgubim državu (ekran se trese).
    private(set) var udarac = 0
    private func efekt(_ v: Efekat.Vrsta) { efekat = Efekat(vrsta: v) }
    struct PrimljenaPomoc: Identifiable, Equatable { let id = UUID(); let od: String; let boja: UInt32; let iz: String; let u: String }
    var novaKarta: NovaKarta?
    /// Država na koju kamera ide na zahtev (dodir kartice pomoći).
    private(set) var pokazana: String?
    func pokaziDrzavu(_ id: String) {
        pokazana = id
        Task { try? await Task.sleep(for: .seconds(1)); if pokazana == id { pokazana = nil } }
    }
    var primljenaPomoc: PrimljenaPomoc?

    // MARK: Partija preko servera

    private(set) var veza: VezaOsvajanja?
    /// Telefon koji nije domaćin čeka prvo stanje sa servera.
    private(set) var cekaPocetak = false
    private var cekaUdaljenuOdbranu: (rb: Int, nastavak: CheckedContinuation<Skor, Never>)?
    /// Branim se od napada sa drugog telefona: redni broj „bitke” i skor napadača.
    private var udaljeniNapad: (rb: Int, napadac: Skor)?
    private var zapocetPotez: (krug: Int, igrac: Int)?
    private static let rokOdbrane: Duration = .seconds(45)

    /// Igrač sa drugog telefona (pravi nalog, ne ja i ne bot).
    private func udaljen(_ i: Igrac) -> Bool { veza != nil && i.id.hasPrefix("u:") && !i.covek }

    private func lokalizuj(_ s: Stanje) -> Stanje {
        var s = s
        s.igraci = s.igraci.map { var i = $0; i.covek = i.id == veza?.mojId; return i }
        return s
    }

    private func objavi(_ s: Stanje) {
        guard let veza else { return }
        Task { await veza.posalji(.init(v: "stanje", stanje: s)) }
    }

    /// Slušanje sobe: novi potezi na svake 1,5 s dok je partija otvorena.
    func slusaj() async {
        guard let veza else { return }
        while !Task.isCancelled && !napusteno && stanje.faza != .kraj {
            for red in await veza.novi() { primi(red) }
            try? await Task.sleep(for: .milliseconds(1500))
        }
    }

    private func primi(_ red: VezaOsvajanja.Red) {
        let a = red.akcija
        switch a.v {
        case "stanje":
            guard let novo = a.stanje else { return }
            stanje = lokalizuj(novo)
            if cekaPocetak { cekaPocetak = false; spremno = !spil.prazan }
            if let prvi = stanje.cekaPostavku?.first {
                // Domaćin je preskočio moju postavku (rok): moj izbor više ne važi.
                if prvi != mojId && (postavljanje != nil || ponudaMisija != nil) {
                    postavljanje = nil; ponudaMisija = nil
                    javi("Vreme za postavku je isteklo, igraš sa početnim državama.")
                }
                pocetakPostavke = Date()
                if spremno { nastaviPostavku() }
                return
            }
            pratiUdaljenog()
            pocniPotezAkoTreba()
        case "bitka":
            guard let odakle = a.odakle, let kuda = a.kuda, let skor = a.skor, bitka == nil,
                  let mojTim, stanje.oblasti[kuda]?.vlasnik == mojTim else { return }
            udaljeniNapad = (red.rb, skor)
            bitka = novaBitka(napadam: false, odakle: odakle, kuda: kuda)
            bitka?.rivalPoznat = skor
            Zvuk.pusti(.uzbuna, jacina: 0.5)
        case "poruka":
            // Brze poruke su javne: vide ih svi za stolom (oblačić iznad pošiljaoca).
            guard let tekst = a.tekst else { return }
            let od = VezaOsvajanja.idIgraca(red.ko)
            stanje = stanje.posalji(tekst, od: od)
        case "odgovor":
            guard let p = a.pitanje, let o = a.odgovor, let i = stanje.igraci.first(where: { $0.id == VezaOsvajanja.idIgraca(red.ko) }) else { return }
            tudjiOdgovor = TudjiOdgovor(ime: i.ime, boja: i.boja, pitanje: p, odgovor: o, tacno: a.tacno ?? false, kad: Date())
        case "odbrana":
            guard let rb = a.bitka, let skor = a.skor, let c = cekaUdaljenuOdbranu, c.rb == rb else { return }
            cekaUdaljenuOdbranu = nil
            c.nastavak.resume(returning: skor)
        default: break
        }
    }

    /// Posle stanja sa servera: ako je red na mene (ili na bota, a ja sam domaćin), potez kreće jednom.
    private func pocniPotezAkoTreba() {
        guard (stanje.cekaPostavku ?? []).isEmpty, stanje.faza == .snabdevanje, zapocetPotez.map({ $0 != (stanje.krug, stanje.naPotezu) }) ?? true else { return }
        let t = stanje.trenutni
        guard t.covek || (!udaljen(t) && veza?.domacin == true) else { return }
        pocniPotez(stanje)
    }

    /// Napad na državu pravog igrača sa drugog telefona: on odgovara na svoja pitanja; ako se ne javi u roku, umesto njega bot.
    private func udaljenaOdbrana(odakle: String, kuda: String, napadac: Skor) async -> Skor {
        guard let veza, let rb = await veza.posalji(.init(v: "bitka", odakle: odakle, kuda: kuda, skor: napadac)) else { return stanje.botSkor(&slucajno) }
        let rok = Task { [weak self] in
            try? await Task.sleep(for: Self.rokOdbrane)
            guard let self, let c = self.cekaUdaljenuOdbranu, c.rb == rb else { return }
            self.cekaUdaljenuOdbranu = nil
            c.nastavak.resume(returning: self.stanje.botSkor(&self.slucajno))
        }
        let skor = await withCheckedContinuation { cekaUdaljenuOdbranu = (rb, $0) }
        rok.cancel()
        return skor
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

    // MARK: Pauza (samo partija sa botovima na ovom telefonu)

    /// Vlasnik 04.11: pauza postoji samo kad za stolom nema pravih igrača sa drugih telefona.
    var mozePauzu: Bool { veza == nil && stanje.faza != .kraj && bitka == nil && otvoreno == nil }
    private(set) var pauza = false
    private var ostaloRoka: TimeInterval?

    func pauziraj() {
        guard mozePauzu, !pauza else { return }
        pauza = true
        ostaloRoka = rokPoteza.map { max(0, $0.timeIntervalSinceNow) }
        rokPoteza = nil
        sacuvaj()
    }

    func nastaviPartiju() {
        guard pauza else { return }
        pauza = false
        if let o = ostaloRoka { rokPoteza = Date().addingTimeInterval(max(o, 10)) }
        ostaloRoka = nil
    }

    /// Bot čeka dok je partija pauzirana ili dok igrač ne pročita obaveštenje o misiji.
    private func sacekajPauzu() async {
        while (pauza || obavestenjeMisije != nil) && !napusteno && !Task.isCancelled { try? await Task.sleep(for: .milliseconds(300)) }
    }

    // MARK: Obaveštenje o misiji (vlasnik 05.11: „sve se brzo dešava, ne vidim poruke”)

    struct ObavestenjeMisije: Equatable { let moja: Bool; let ime: String; let tekst: String }
    /// Veliko obaveštenje na sredini ekrana; botovi stoje dok ga igrač ne zatvori.
    private(set) var obavestenjeMisije: ObavestenjeMisije?
    private var najavljeneMisije: Set<String> = []

    /// Čim neki tim ispuni misiju (i usred tuđeg poteza), igrač to vidi jasno, a ne tek posle poteza.
    func najaviMisijuAkoTreba() {
        guard veza == nil, mojTim != nil, stanje.faza != .kraj, obavestenjeMisije == nil else { return }
        let ispunjene = Set(stanje.misije.keys.filter { stanje.napredakMisije($0) >= 1 })
        najavljeneMisije.formIntersection(ispunjene)
        guard let t = ispunjene.subtracting(najavljeneMisije).sorted().first else { return }
        najavljeneMisije.insert(t)
        let ime = stanje.igraci.first { $0.tim == t && $0.kapiten }?.ime ?? "Rival"
        obavestenjeMisije = .init(moja: t == mojTim, ime: ime, tekst: stanje.tekstMisije(stanje.misije[t]))
        Zvuk.pusti(.obavestenje, jacina: 0.6)
    }

    func zatvoriObavestenjeMisije() { obavestenjeMisije = nil }

    // MARK: Tuđi odgovori (partija sa pravim igračima)

    struct TudjiOdgovor: Equatable { let ime: String; let boja: UInt32; let pitanje: String; let odgovor: String; let tacno: Bool; let kad: Date }
    /// Poslednji odgovor drugog pravog igrača u bitki; ekran ga pokazuje nekoliko sekundi.
    private(set) var tudjiOdgovor: TudjiOdgovor?

    private func objaviOdgovor(_ p: Prikaz, izabran: Int?, tacno: Bool) {
        guard let veza else { return }
        let tekst = izabran.flatMap { p.opcije.indices.contains($0) ? p.opcije[$0] : nil } ?? "bez odgovora (isteklo vreme)"
        Task { await veza.posalji(.init(v: "odgovor", pitanje: p.tekst, odgovor: tekst, tacno: tacno)) }
    }

    /// Broj mojih poteza: ekran vraća kameru na moje države kad poraste.
    private(set) var mojPotez = 0

    var covekNaPotezu: Bool { stanje.faza != .kraj && stanje.trenutni.covek && (stanje.cekaPostavku ?? []).isEmpty }
    /// Moj id u stanju (na ovom telefonu).
    var mojId: String? { stanje.igraci.first(where: \.covek)?.id }

    var mete: [String] {
        guard let izabrana, covekNaPotezu else { return [] }
        // Marš: osvetljene su sve svoje države do kojih vojska stiže.
        if utvrdjivanje { return stanje.dometMarsa(izabrana).sorted() }
        return stanje.mete(izabrana) + stanje.meteIzdaje(izabrana)
    }

    // MARK: Ulog, pohod, izdaja, trgovina, ultimatum (Strategija2.swift)

    /// Ulog za sledeći napad na igrača (0–2), bira se na panelu mete.
    var ulog = 0
    /// Igrač bira region za najavu pohoda (sledeći dodir mape).
    var biraPohod = false
    /// Država saveznika koju bi napad pretvorio u izdaju: čeka potvrdu.
    private(set) var izdajaZa: String?

    var mojPohod: String? { mojTim.flatMap { stanje.pohodi?[$0] } }

    /// Države u magli za ovaj telefon (posmatrač bez tima vidi sve).
    var magla: Set<String> {
        guard let t = mojTim, stanje.faza != .kraj else { return [] }
        return Set(stanje.oblasti.keys.filter { stanje.oblasti[$0]?.vlasnik != nil && !stanje.vidi(t, $0) })
    }

    func prekidacPohoda() {
        guard covekNaPotezu, mojPohod == nil else { return }
        biraPohod.toggle(); izabrana = nil; utvrdjivanje = false
        if biraPohod { javi("Dodirni državu u regionu koji osvajaš do sledećeg poteza") }
    }

    func potvrdiIzdaju() {
        guard let id = izdajaZa, let t = mojTim, let v = stanje.oblasti[id]?.vlasnik else { return }
        izdajaZa = nil
        stanje = stanje.izdaj(t, v).posalji("Izdaja!", od: stanje.trenutni.id)
        objavi(stanje)
        meta = id
        javi("Savez je prekinut. Gubiš sve karte, a svi vide da si izdao.")
    }

    func odustaniOdIzdaje() { izdajaZa = nil }

    func razmeniKartu(_ k: Karta, sa p: Igrac) {
        guard let t = mojTim else { return }
        guard !p.covek && !p.id.hasPrefix("u:"), let (novo, dobio) = stanje.razmeniKartu(od: t, sa: p.tim, daje: k) else {
            javi("\(p.ime) ne prihvata razmenu (ima tu kartu ili nema nijednu)"); return
        }
        stanje = novo.posalji("Dogovoreno!", od: p.id)
        objavi(stanje)
        javi("Dao si \(k.naziv), dobio \(dobio.naziv)")
    }

    func ultimatum(_ kuda: String) {
        guard covekNaPotezu, let (novo, prihvaceno) = stanje.ultimatum(kuda) else {
            javi("Ultimatum ide slabijem susedu, jednom po potezu"); return
        }
        stanje = novo
        objavi(novo)
        if prihvaceno { meta = nil; izabrana = nil; javi("\(Mapa.oblast(kuda).ime) je predata bez borbe!") }
        else { javi("Odbijeno: u ovom potezu napadaš \(Mapa.oblast(kuda).ime) sa +1 tačnim") }
    }

    #if DEBUG
    /// Snimak za sajt: igrač rasporedi vojsku, izabere državu, napadne, izabere temu i odgovara (PitanjeKartica bira sama).
    private func demoPotez() async {
        func cekaj(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }
        await cekaj(1.6)
        rasporediSam()
        for _ in 0..<2 {
            await cekaj(1.4)
            guard let napad = stanje.botSledeciNapad() else { break }
            dodir(napad.odakle)
            await cekaj(1.4)
            dodir(napad.kuda)
            await cekaj(1.6)
            napadni()
            await cekaj(2.6)
            if let t = bitka?.teme.first { izaberiTemu(t); await cekaj(1.2) }
            pocniPitanja()
            for _ in 0..<200 where bitka != nil && bitka?.korak != .rezultat { await cekaj(0.3) }
            await cekaj(2.8)
            zatvoriBitku()
            if stanje.faza == .kraj { return }
        }
        await cekaj(1.2)
        krajPoteza()
    }
    #endif

    // MARK: Izbor teme i povlačenje

    func izaberiTemu(_ t: String) {
        guard var b = bitka, b.korak == .uvod, b.napadam, b.teme.contains(t) else { return }
        b.prikazi = b.prikazi.indices.map { _ in uzmiPitanje(tema: t) }
        b.tema = t
        bitka = b
    }

    /// Napadač nije izabrao temu u roku: pitanja ostaju mešana.
    func bezTeme() {
        guard var b = bitka, b.korak == .uvod, b.tema == nil else { return }
        b.teme = []
        bitka = b
    }

    /// Bitka od 5 pitanja: posle drugog odgovora napadač može da se povuče; vojska ostaje, potez se završava.
    var mozePovlacenje: Bool {
        guard let b = bitka, b.napadam, b.korak == .pitanja, b.prikazi.count == Pravila.pitanjaUBitci else { return false }
        return b.redni >= Pravila.povlacenjePosle
    }

    func povuciSe() {
        guard mozePovlacenje, let b = bitka else { return }
        Zvuk.pusti(.povlacenje, jacina: 0.45)
        bitka = nil
        stanje = stanje.postaviUlog(0)
        javi("Povukao si se iz \(Mapa.oblast(b.kuda).ime). Vojska je sačuvana, potez je gotov.")
        krajPoteza()
    }

    var uputstvo: String {
        if ponudaMisija != nil { return "Izvuci tajnu misiju: prevuci karte i dodirni jednu." }
        if postavljanje == nil, let prvi = stanje.cekaPostavku?.first, prvi != mojId {
            return "\(stanje.igraci.first { $0.id == prvi }?.ime ?? "Rival") bira države i vuče tajnu misiju…"
        }
        if let p = postavljanje {
            if p.drzave.count < Pravila.pocetnihDrzava {
                return "Izaberi svoje države (\(p.kontinent.ime)): \(p.drzave.count) od \(Pravila.pocetnihDrzava). Prva je prestonica."
            }
            return zaPostavljanje > 0 ? "Rasporedi vojsku: dodiruj svoje države, još \(zaPostavljanje)." : "Spremno. Kreni u osvajanje!"
        }
        guard covekNaPotezu else { return stanje.faza == .kraj ? "Kraj partije" : "\(stanje.trenutni.ime) je na potezu…" }
        switch stanje.faza {
        case .raspored: return "Dodirni svoje oblasti: još \(stanje.zaRaspored)"
        case .napad:
            if utvrdjivanje { return "Marš: izaberi državu, pa svoju do 3 koraka dalje" }
            if biraPohod { return "Pohod: dodirni državu u regionu koji osvajaš" }
            if izabrana == nil { return "1. Dodirni svoju državu sa žutom ivicom: odatle napadaš · bitka \(stanje.bitaka + 1)/\(stanje.napadaPoPotezu)" }
            return meta == nil ? "2. Napadaš iz: \(Mapa.oblast(izabrana!).ime). Dodirni koga napadaš (isprekidana ivica)." : ""
        default: return "Snabdevanje…"
        }
    }

    /// Vlasnik 03.11: pitanja su se ponavljala jer je partija vrtela prvih 60. Sada se špil dopunjuje pre nego što se isprazni.
    private func uzmiPitanje(tema: String? = nil) -> Prikaz {
        defer { dopuniSpilAkoTreba() }
        if let tema, let p = spil.sledece(tema: tema) { return p }
        return spil.sledece()
    }

    private func uzmiPitanjeKontinenta(_ k: String) -> Prikaz? {
        defer { dopuniKontinent(k) }
        guard var s = spiloviKontinenta[k], s.ostalo > 0 else { return nil }
        let p = s.sledece()
        spiloviKontinenta[k] = s
        return p
    }

    private func dopuniKontinent(_ k: String) {
        guard (spiloviKontinenta[k]?.ostalo ?? 0) < Self.pitanjaOKontinentu * 3, !dopunaKontinenta.contains(k) else { return }
        dopunaKontinenta.insert(k)
        Task {
            let nova = await PaketPitanja.deljeni.kontinent(k)
            if spiloviKontinenta[k] == nil { spiloviKontinenta[k] = Spil(nova) } else { spiloviKontinenta[k]?.dodaj(nova) }
            dopunaKontinenta.remove(k)
        }
    }

    private func dopuniSpilAkoTreba() {
        guard spil.ostalo < Self.pragDopune, !dopunaRadi else { return }
        dopunaRadi = true
        Task {
            if let nova = try? await PaketPitanja.deljeni.ucitaj() { spil.dodaj(nova) }
            dopunaRadi = false
        }
    }

    func pokreni() async {
        do {
            spil = Spil(try await PaketPitanja.deljeni.ucitaj())
            for k in Set(stanje.oblasti.keys.map { Kontinenti.od($0).ime }) { dopuniKontinent(k) }
            spremno = !cekaPocetak
            #if DEBUG
            // `-misijaProba`: izgled obaveštenja o ispunjenoj misiji bez igranja do misije.
            if ProcessInfo.processInfo.arguments.contains("-misijaProba") {
                obavestenjeMisije = .init(moja: true, ime: "Ti", tekst: stanje.tekstMisije(stanje.misije.values.first))
            }
            // Snimak za sajt: niko ne čita misiju, botovi kreću odmah.
            if LibrumKvizApp.demo { zapocni(); return }
            #endif
            // U partiji sa misijom prvi potez čeka da igrač pročita misiju; nastavljena partija ide dalje odmah.
            if nastavljena {
                // Sačuvano usred poteza bota (posle pojačanja): bot nastavlja svoj potez, inače bi partija stajala zauvek.
                if stanje.trenutni.covek && stanje.faza != .snabdevanje { pokreniSat() }
                else if !stanje.trenutni.covek && stanje.faza != .snabdevanje { Task { await potezBota() } }
                else { pocniPotez(stanje) }
            } else if postavka == nil {
                pocniPotez(stanje)
            }
        } catch {
            greska = error.localizedDescription
        }
    }

    // MARK: Čovek

    func dodir(_ id: String) {
        produziSat()
        defer { if stanje.faza == .napad && covekNaPotezu && rokPoteza == nil { pokreniSat() } }
        if postavljanje != nil { dodirPostavljanja(id); return }
        guard covekNaPotezu, otvoreno == nil, let oblast = stanje.oblasti[id] else { return }
        Zvuk.pusti(.izborDrzave, jacina: 0.3)
        let moja = oblast.vlasnik == stanje.trenutni.tim
        if biraPohod {
            biraPohod = false
            let region = Mapa.oblast(id).region
            if let novo = stanje.najaviPohod(region) {
                stanje = novo
                objavi(novo)
                javi("Pohod: \(Mapa.regioni.first { $0.id == region }?.ime ?? ""). Drži ga ceo na početku sledećeg poteza: +\(Pravila.nagradaPohoda) vojske i karta.")
            } else {
                javi("Taj region već držiš ceo, izaberi drugi")
            }
            return
        }
        switch stanje.faza {
        case .raspored:
            guard moja else { javi("Vojsku stavljaš samo na svoje države."); return }
            let novo = stanje.rasporedi(id)
            if novo == stanje { javi("\(Mapa.oblast(id).ime) je odsečena od prestonice: tu ne stižu pojačanja.") } else { stanje = novo }
            if stanje.faza == .napad { javi("Vojska je raspoređena. Biraj odakle napadaš.") }
        case .napad:
            if utvrdjivanje {
                if let izvor = izabrana, moja, stanje.dometMarsa(izvor).contains(id) {
                    stanje = stanje.utvrdi(odakle: izvor, kuda: id, broj: (stanje.oblasti[izvor]?.vojske ?? 1) - 1)
                    utvrdjivanje = false; izabrana = nil; javi("Vojske prebačene")
                } else {
                    izabrana = moja ? id : nil
                }
            } else if moja {
                izabrana = stanje.mete(id).isEmpty ? nil : id
                if izabrana == nil { javi(razlogBezNapada(id)) }
            } else if let izvor = izabrana, stanje.mete(izvor).contains(id) {
                meta = meta == id ? nil : id
            } else if let izvor = izabrana, stanje.meteIzdaje(izvor).contains(id) {
                izdajaZa = id
            }
        default: break
        }
    }

    /// Posle lista sa misijom: kreće prvi potez.
    // MARK: Postavljanje pre prvog kruga

    /// Igrač sam bira početne države na svom kontinentu (prva je prestonica), pa raspoređuje vojske.
    struct Postavljanje { let kontinent: Kontinent; let original: Stanje; var drzave: [String] = [] }
    private(set) var postavljanje: Postavljanje?
    var zaPostavljanje: Int { Pravila.vojskiNaPocetku - (postavljanje?.drzave.reduce(0) { $0 + (stanje.oblasti[$1]?.vojske ?? 0) } ?? 0) }

    /// Posle učitavanja (ekran): nastavljena partija ide dalje, nova kreće postavkom.
    func otvori() {
        if nastavljena { javi("Nastavljamo partiju"); return }
        zapocni()
    }

    private func oslobodiMoje() {
        guard let tim = mojTim else { return }
        for (id, o) in stanje.oblasti where o.vlasnik == tim { stanje.oblasti[id] = StanjeOblasti(vlasnik: nil, vojske: Pravila.neutralneVojske) }
    }

    private func dodirPostavljanja(_ id: String) {
        guard var p = postavljanje, let tim = mojTim, let o = stanje.oblasti[id] else { return }
        if p.drzave.count < Pravila.pocetnihDrzava {
            // Kad na kontinentu nema dovoljno slobodnih, bira se bilo gde.
            let slobodnih = Kontinenti.oblasti(p.kontinent.id).filter { stanje.oblasti[$0]?.vlasnik == nil }.count
            let naKontinentu = Kontinenti.od(id).id == p.kontinent.id || slobodnih == 0
            guard o.vlasnik == nil else { javi("\(Mapa.oblast(id).ime) je zauzeta. Biraj slobodnu državu."); return }
            if let c = Cudo.za(id) { javi("\(c.naziv): čudo sveta se osvaja u igri, ne bira na početku."); return }
            guard naKontinentu else { javi("Biraš države na kontinentu \(p.kontinent.ime).") ; return }
            Zvuk.pusti(.izborDrzave, jacina: 0.3)
            stanje.oblasti[id] = StanjeOblasti(vlasnik: tim, vojske: 1)
            p.drzave.append(id)
        } else if p.drzave.contains(id), zaPostavljanje > 0 {
            Zvuk.pusti(.vojskaStavi, jacina: 0.35)
            stanje.oblasti[id]?.vojske += 1
        }
        postavljanje = p
        // Ostali za stolom gledaju izbor uživo (i domaćinov sat zna da sam tu).
        objavi(stanje)
    }

    func ponistiPostavljanje() {
        guard let p = postavljanje else { return }
        stanje = p.original
        postavljanje = Postavljanje(kontinent: p.kontinent, original: p.original)
        oslobodiMoje()
        objavi(stanje)
    }

    /// Ostatak vojske ide redom po izabranim državama (prestonica prva).
    func rasporediPostavljanjeSam() {
        guard let p = postavljanje, p.drzave.count == Pravila.pocetnihDrzava else { return }
        var i = 0
        while zaPostavljanje > 0 { stanje.oblasti[p.drzave[i % p.drzave.count]]?.vojske += 1; i += 1 }
        objavi(stanje)
    }

    /// Države su izabrane: ako partija ima tajne misije, sledi izvlačenje karte, inače kraj postavke.
    func zavrsiPostavljanje() {
        guard let p = postavljanje, p.drzave.count == Pravila.pocetnihDrzava, zaPostavljanje == 0, let prva = p.drzave.first else { return }
        stanje.igraci = stanje.igraci.map { var i = $0; if i.covek { i.prestonica = prva }; return i }
        postavljanje = nil
        if let t = mojTim, stanje.misije[t] != nil {
            ponudaMisija = napraviPonuduMisija(t)
            objavi(stanje)
            return
        }
        zavrsiPostavku()
    }

    // MARK: Tajna misija: okrenute karte

    /// Okrenute karte sa misijama (vlasnik 04.11): svaki put druge misije drugim redom.
    private(set) var ponudaMisija: [String]?
    static let karataMisija = 6

    /// Šest misija iz ponude (bez tuđih i, kad ima dovoljno, bez skorašnjih), nasumično poređane:
    /// od ~30 misija to je preko pola miliona rasporeda, pa ista misija nije na istom mestu.
    private func napraviPonuduMisija(_ tim: String) -> [String] {
        let tudje = Set(stanje.misije.filter { $0.key != tim }.values)
        let timova = Set(stanje.igraci.map(\.tim)).count
        let pojedinacno = timova == stanje.igraci.count
        let skorasnje = MisijeIstorija.skorasnje()
        let moguce = Misije.sve.filter { (pojedinacno || !$0.samoPojedinacno) && timova - 1 >= $0.najmanjeRivala && !tudje.contains($0.id) }.map(\.id).shuffled()
        let ponuda = Array((moguce.filter { !skorasnje.contains($0) } + moguce.filter { skorasnje.contains($0) }).prefix(Self.karataMisija))
        return ponuda.isEmpty ? [stanje.misije[tim] ?? Misije.sve[0].id] : ponuda.shuffled()
    }

    /// Dodirnuta karta postaje misija mog tima; ekran je okreće, pa igrač potvrđuje sa „Kreni”.
    func izvuciMisiju(_ id: String) {
        guard let t = mojTim, ponudaMisija?.contains(id) == true else { return }
        stanje.misije[t] = id
        stanje.metaMisije[t] = nil
        if id == "izbaci" {
            let drugi = Array(Set(stanje.igraci.map(\.tim)).subtracting([t])).filter { stanje.strana($0) != stanje.strana(t) }.sorted()
            stanje.metaMisije[t] = drugi.randomElement()
        }
        MisijeIstorija.zapamti(id)
        Zvuk.pusti(.misija, jacina: 0.45)
    }

    /// Kraj moje postavke: sledeći u redu bira (ili kreće prvi krug).
    func zavrsiPostavku() {
        ponudaMisija = nil
        if let ja = mojId { stanje.cekaPostavku?.removeAll { $0 == ja } }
        objavi(stanje)
        nastaviPostavku()
    }

    /// Red postavke: kad sam ja prvi, biram države; kad je red prazan, kreće prvi krug.
    private func nastaviPostavku() {
        if let prvi = stanje.cekaPostavku?.first {
            if prvi == mojId && postavljanje == nil && ponudaMisija == nil, let ja = stanje.igraci.first(where: \.covek) {
                postavljanje = Postavljanje(kontinent: Kontinenti.od(ja.prestonica), original: stanje)
                oslobodiMoje()
                objavi(stanje)
            }
            return
        }
        if veza != nil { pocniPotezAkoTreba() } else { pocniPotez(stanje) }
    }

    /// Domaćin čeka postavku igrača sa drugog telefona najviše ovoliko od njegovog poslednjeg poteza, pa ide dalje.
    private static let rokPostavke: TimeInterval = 120
    private var pocetakPostavke: Date?

    func zapocni() {
        guard spremno, stanje.krug == 1, stanje.faza == .snabdevanje, otvoreno == nil else { return }
        // Reprodukcija kreće od početne mape, ne od biranja država.
        istorija = [stanje.oblasti.compactMapValues(\.vlasnik)]
        if veza == nil || veza?.domacin == true {
            // Postavku rade pravi igrači, prvi iz svakog tima (botove je mapa već postavila); snimak za sajt je preskače.
            if stanje.cekaPostavku == nil && !LibrumKvizApp.demo {
                var red: [String] = [], timovi: Set<String> = []
                for i in stanje.igraci where (i.covek || udaljen(i)) && !timovi.contains(i.tim) { red.append(i.id); timovi.insert(i.tim) }
                stanje.cekaPostavku = red
            }
            // Domaćin šalje početno stanje (mapa, misije, redosled, red postavke); ostali kreću kad ga prime.
            if veza?.domacin == true {
                objavi(stanje)
                pocetakPostavke = Date()
                if satPoteza == nil {
                    satPoteza = Task { [weak self] in
                        while !Task.isCancelled { try? await Task.sleep(for: .seconds(1)); self?.proveriSat() }
                    }
                }
            }
        }
        nastaviPostavku()
    }

    func rasporediSam() { stanje = stanje.botRasporedi(); javi("Vojska je na granicama. Biraj odakle napadaš.") }

    func prekidacUtvrdjivanja() { utvrdjivanje.toggle(); izabrana = nil }

    /// Države iz kojih čovek sada može da napadne (žuta isprekidana ivica dok ništa nije izabrano).
    var izvori: [String] {
        guard covekNaPotezu, stanje.faza == .napad, izabrana == nil, !utvrdjivanje else { return [] }
        return stanje.oblastiIgraca(stanje.trenutni.id).filter { !stanje.mete($0).isEmpty }
    }

    // MARK: Sat poteza (30 s, svaki dodir produžava; tri isteka bez napada = ispadanje)

    private(set) var rokPoteza: Date?
    private var satPoteza: Task<Void, Never>?
    /// Domaćin prati i poteze igrača sa drugih telefona: ako se ne jave u roku (+15 s za mrežu), potez je propušten.
    private var pocetakUdaljenogPoteza: (krug: Int, igrac: Int, kad: Date)?

    private func pokreniSat() {
        rokPoteza = Date().addingTimeInterval(TimeInterval(Pravila.rokPotezaSekundi))
        satPoteza?.cancel()
        satPoteza = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.proveriSat()
            }
        }
    }

    /// Domaćin meri koliko dugo se igrač sa drugog telefona ne javlja; svako njegovo stanje vraća sat na početak.
    private func pratiUdaljenog() {
        guard veza?.domacin == true, udaljen(stanje.trenutni), stanje.faza != .kraj else { return }
        pocetakUdaljenogPoteza = (stanje.krug, stanje.naPotezu, Date())
        if satPoteza == nil {
            satPoteza = Task { [weak self] in
                while !Task.isCancelled { try? await Task.sleep(for: .seconds(1)); self?.proveriSat() }
            }
        }
    }

    private func produziSat() {
        if rokPoteza != nil { rokPoteza = Date().addingTimeInterval(TimeInterval(Pravila.rokPotezaSekundi)) }
    }

    private func proveriSat() {
        if veza?.domacin == true, let prvi = stanje.cekaPostavku?.first, prvi != mojId, let p = pocetakPostavke,
           Date().timeIntervalSince(p) > Self.rokPostavke {
            pocetakPostavke = Date()
            stanje.cekaPostavku?.removeFirst()
            objavi(stanje)
            nastaviPostavku()
            return
        }
        // Udaljeni igrač koji se ne javlja: domaćin mu propušta potez, da partija ne stoji.
        if veza?.domacin == true, let p = pocetakUdaljenogPoteza, udaljen(stanje.trenutni), stanje.faza != .kraj,
           p.krug == stanje.krug, p.igrac == stanje.naPotezu,
           Date().timeIntervalSince(p.kad) > TimeInterval(Pravila.rokPotezaSekundi + 15) {
            pocetakUdaljenogPoteza = nil
            let novo = stanje.isteklo(stanje.trenutni.id)
            objavi(novo)
            pocniPotez(novo)
            return
        }
        if pauza { return }
        guard let rok = rokPoteza else { return }
        guard covekNaPotezu, stanje.faza == .napad || stanje.faza == .raspored else { rokPoteza = nil; return }
        // Isteklo vreme za raspoređivanje: ostatak vojske ide na granice, a sat kreće za napad.
        if stanje.faza == .raspored {
            if Date() >= rok { stanje = stanje.botRasporedi(); javi("Vreme je isteklo: ostatak vojske je na granicama."); pokreniSat() }
            return
        }
        // Bitka i otvoreno pitanje imaju svoj sat; rok poteza čeka.
        if bitka != nil || otvoreno != nil { produziSat(); return }
        if Date() >= rok { istekaoPotez() }
    }

    private func istekaoPotez() {
        rokPoteza = nil
        let ja = stanje.trenutni
        let novo = stanje.isteklo(ja.id)
        izabrana = nil; meta = nil; utvrdjivanje = false
        if novo.igraci.first(where: { $0.id == ja.id })?.ispao == true {
            javi("Ispao si: tri poteza zaredom bez napada.")
            if veza == nil { var kraj = novo; kraj.faza = .kraj; stanje = kraj; return }
        } else if stanje.bitaka == 0 {
            javi("Vreme je isteklo, potez prelazi dalje (\(novo.propusteno?[ja.id] ?? 0)/\(Pravila.propustenihDoIspadanja)).")
        }
        objavi(novo)
        pocniPotez(novo)
    }

    /// Potvrda napada sa panela mete.
    func napadni() {
        predlog = nil
        guard let izvor = izabrana, let kuda = meta, stanje.mete(izvor).contains(kuda) else { return }
        meta = nil
        if stanje.oblasti[kuda]?.vlasnik != nil { stanje = stanje.postaviUlog(ulog) }
        ulog = 0
        bitka = novaBitka(napadam: true, odakle: izvor, kuda: kuda)
    }

    func odustaniOdMete() { meta = nil }

    /// Zašto iz svoje države ne može da se napadne (inače bi dodir izgledao kao da ne radi).
    private func razlogBezNapada(_ id: String) -> String {
        let ime = Mapa.oblast(id).ime
        if stanje.bitaka >= stanje.napadaPoPotezu { return "Iskoristio si sve napade u ovom potezu. Završi potez." }
        if (stanje.oblasti[id]?.vojske ?? 0) < 2 { return "\(ime) ima 1 vojsku, za napad trebaju 2. Prebaci vojske dugmetom Utvrdi." }
        return "\(ime) nema suseda za napad."
    }

    func krajPoteza() {
        rokPoteza = nil
        izabrana = nil; utvrdjivanje = false
        let novo = stanje.zavrsiPotez()
        objavi(novo)
        pocniPotez(novo)
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
        let kontinent = Kontinenti.od(kuda).ime
        let uslov = stanje.uslovBitke(kuda, za: mojTim)
        let rival = napadam
            ? stanje.igraci.first { $0.tim == stanje.oblasti[kuda]?.vlasnik }?.ime ?? "niko (prazno polje)"
            : stanje.trenutni.ime
        var b = Bitka(napadam: napadam, odakle: odakle, kuda: kuda, uslov: uslov,
                      prikazi: (0..<uslov.pitanja).map { i in i < Self.pitanjaOKontinentu ? uzmiPitanjeKontinenta(kontinent) ?? uzmiPitanje() : uzmiPitanje() }.shuffled(),
                      rivalIme: rival)
        // Napadač bira temu (osim kad odbrana „Tema branioca” već određuje pitanja).
        if napadam && !uslov.temaBranioca { b.teme = Array(spil.teme(najmanje: uslov.pitanja).shuffled().prefix(3)) }
        if stanje.oblasti[kuda]?.vlasnik != nil { b.pomak = stanje.pomakBitke(odakle: odakle, kuda: kuda) }
        // Branilac bot: skor unapred (Prisluškivanje ga pokazuje), isti se koristi na kraju bitke.
        if napadam, let v = stanje.igraci.first(where: { $0.tim == stanje.oblasti[kuda]?.vlasnik }), !v.covek, !udaljen(v) {
            b.rivalPoznat = stanje.botSkor(&slucajno, pitanja: b.prikazi.count)
        }
        return b
    }

    /// Kraj uvoda (odbrojavanje): kreću pitanja.
    func pocniPitanja() { bitka?.korak = .pitanja }

    /// Pomoć „Preskok”: tekuće pitanje se menja novim iz špila, bez odgovora.
    func zameniPitanje() {
        if var b = bitka, b.korak == .pitanja {
            b.prikazi[b.redni] = uzmiPitanje()
            b.zamena += 1
            b.satStoji = false
            bitka = b
        } else if let o = otvoreno {
            otvoreno = Otvoreno(vrsta: o.vrsta, prikaz: uzmiPitanje(), odakle: o.odakle, kuda: o.kuda)
        }
    }

    /// Odgovor na pitanje u bitki (nil = isteklo vreme).
    func odgovorUBitci(_ izabran: Int?, ms: Int) {
        guard var b = bitka, b.korak == .pitanja else { return }
        let pogodio = izabran == b.prikazi[b.redni].tacan
        objaviOdgovor(b.prikazi[b.redni], izabran: izabran, tacno: pogodio || b.siguran)
        var tacno = pogodio
        b.ms += ms
        zbirMs += ms
        // Drugi pokušaj (Legija): isto pitanje bez izabranog odgovora.
        if !pogodio && b.drugiPokusaj, let i = izabran {
            b.drugiPokusaj = false
            b.iskljuceni.insert(i); b.zamena += 1
            bitka = b
            return
        }
        // Štit (Garda): greška se briše, umesto nje stiže novo pitanje.
        if !pogodio && b.stit {
            b.stit = false; netacnih += 1
            b.prikazi[b.redni] = uzmiPitanje(); b.zamena += 1; b.satStoji = false
            bitka = b
            return
        }
        if pogodio { tacnih += 1 } else { netacnih += 1 }
        // Siguran udar (Legija): svaki odgovor je tačan, a pogodak vredi dva.
        if b.siguran { b.siguran = false; tacno = true; b.tacnih += pogodio ? 2 : 1 }
        else if pogodio { b.tacnih += 1 }
        if pogodio && b.dvostruko { b.dvostruko = false; b.tacnih += 1 }
        b.satStoji = false
        if b.redni + 1 < b.prikazi.count {
            b.redni += 1
            b.iskljuceni = []
            bitka = b
            return
        }
        if b.napadam {
            let neutralna = stanje.oblasti[b.kuda]?.vlasnik == nil
            if neutralna {
                var (novo, ishod) = stanje.razresiBitku(odakle: b.odakle, kuda: b.kuda, napadac: Odgovor(tacan: tacno, ms: ms), branilac: nil)
                if let t = mojTim { novo.primeniEfekte(mojSkor(b), tim: t, kuda: b.kuda, pobedio: ishod.osvojeno) }
                stanje = novo
                b.ishod = ishod
                udari(b.odakle, b.kuda, ishod.osvojeno)
            } else if let branilac = stanje.igraci.first(where: { $0.tim == stanje.oblasti[b.kuda]?.vlasnik }), udaljen(branilac) {
                // Branilac je na drugom telefonu: rezultat stiže kad odgovori (ili posle roka).
                let moj = mojSkor(b)
                b.korak = .rezultat
                bitka = b
                Task {
                    var rival = await udaljenaOdbrana(odakle: b.odakle, kuda: b.kuda, napadac: moj)
                    if b.sabotaza { rival = Skor(tacnih: max(0, rival.tacnih - 1), ms: rival.ms) }
                    guard stanje.mete(b.odakle).contains(b.kuda) else { return }
                    let (novo, ishod) = stanje.razresiBitkuSkorom(odakle: b.odakle, kuda: b.kuda, napadac: moj, branilac: rival)
                    stanje = novo
                    udari(b.odakle, b.kuda, ishod.osvojeno)
                    bitka?.rival = rival
                    bitka?.ishod = ishod
                    objavi(novo)
                }
                return
            } else {
                let branilacBot = stanje.igraci.first { $0.tim == stanje.oblasti[b.kuda]?.vlasnik }
                var rival = b.rivalPoznat ?? stanje.botSkor(&slucajno, pitanja: b.prikazi.count)
                if b.sabotaza { rival = Skor(tacnih: max(0, rival.tacnih - 1), ms: rival.ms) }
                let (novo, ishod) = stanje.razresiBitkuSkorom(odakle: b.odakle, kuda: b.kuda, napadac: mojSkor(b), branilac: rival)
                stanje = novo
                b.rival = rival
                b.ishod = ishod
                udari(b.odakle, b.kuda, ishod.osvojeno)
                // Bot ponekad odgovori na poraz (brze poruke, bez slobodnog teksta).
                if ishod.osvojeno, let bot = branilacBot, slucajno.sledeci() < 0.4 {
                    stanje = stanje.posalji(["Osveta!", "Čuvaj se!"][Int(slucajno.sledeci() * 2)], od: bot.id)
                }
            }
            objavi(stanje)
        }
        b.korak = .rezultat
        if !b.napadam, let n = udaljeniNapad, let veza {
            // Odbrana od napada sa drugog telefona: šaljem svoj skor, ishod (za prikaz) po istom pravilu; mapa stiže sa servera.
            let moj = mojSkor(b)
            udaljeniNapad = nil
            Task { await veza.posalji(.init(v: "odbrana", skor: moj, bitka: n.rb)) }
            let osvojio = stanje.osvaja(odakle: b.odakle, kuda: b.kuda, napadac: n.napadac, branilac: moj)
            b.rival = n.napadac
            b.ishod = Ishod(gubitakNapadaca: 0, gubitakBranioca: 0, osvojeno: osvojio, proboj: false, plen: false, izgubljenaDrzava: !osvojio)
        }
        bitka = b
        // Napadač je odigrao Sabotažu: braniocu se računa jedan tačan manje.
        if !b.napadam {
            let m = mojSkor(b)
            cekaOdbranu?.resume(returning: Skor(tacnih: max(0, m.tacnih - (b.sabotiranSam ? 1 : 0)), ms: m.ms, efekti: m.efekti)); cekaOdbranu = nil
        }
    }

    /// Moj skor u bitki sa moćima: Bedem (+1 tačan u odbrani), Munja (pobeđuje kod jednakog), efekti za posle bitke.
    private func mojSkor(_ b: Bitka) -> Skor {
        let efekti = b.moci.filter { [.plen, .utvrdjenje, .temelj, .radionica, .garnizon, .spijunskaMreza].contains($0) }.map(\.rawValue).sorted()
        return Skor(tacnih: b.tacnih + (!b.napadam && b.moci.contains(.bedem) ? 1 : 0), ms: b.moci.contains(.munja) ? 0 : b.ms,
                    efekti: efekti.isEmpty ? nil : efekti)
    }

    /// Rezultat odbrane (kad bot napada čoveka) upisuje se posle razrešenja u potezu bota.
    func ishodOdbrane(_ rival: Skor, _ ishod: Ishod) {
        bitka?.rival = rival
        bitka?.ishod = ishod
    }

    func zatvoriBitku() {
        guard let b = bitka else { return }
        bitka = nil
        // Ishod se video preko mape; osvajanje (razlivanje boje, prašina) se pušta tek kad je mapa opet vidljiva.
        if let ishod = b.ishod { udari(b.odakle, b.kuda, ishod.osvojeno) }
        if b.napadam, let ishod = b.ishod {
            if ishod.osvojeno {
                javi(ishod.plen ? "Prestonica pala! +5 plena" : ishod.proboj ? "Proboj! +2 vojske" : "Osvojeno! Cepaj dalje")
                izabrana = stanje.mete(b.kuda).isEmpty ? nil : b.kuda
            } else if stanje.mete(b.odakle).isEmpty {
                izabrana = nil
            }
        }
        // Odbrana zatvorena pre kraja (izlazak, prekid): bot dobija skor bez tačnih umesto da čeka zauvek.
        cekaOdbranu?.resume(returning: Skor(tacnih: 0, ms: Pravila.pitanjaUBitci * Pravila.sekundiPoPitanju * 1000))
        cekaOdbranu = nil
        zatvaranje?.resume()
        zatvaranje = nil
        sacuvaj()
        najaviMisijuAkoTreba()
    }

    private var zatvaranje: CheckedContinuation<Void, Never>?

    // MARK: Pomoći vojske

    var mojaVojska: VrstaVojske? { mojTim.flatMap { stanje.vojskaTima($0) } }

    /// Troši pomoć vojske za ovaj krug; dejstva na ponuđene odgovore i vreme radi ekran bitke (vraća dejstvo), ostalo model.
    func iskoristiPomocVojske(_ p: PomocVojske) -> PomocVojske.Dejstvo? {
        guard var b = bitka, b.korak == .pitanja, let t = mojTim, mozeMoc(p, b), let novo = stanje.iskoristiPomocVojske(t, p) else { return nil }
        b.moci.insert(p)
        Zvuk.pusti(.pomocVojske, jacina: 0.45)
        stanje = novo
        switch p.dejstvo {
        case .dvostruko: b.dvostruko = true; bitka = b
        case .stit: b.stit = true; bitka = b
        case .siguran: b.siguran = true; bitka = b
        case .drugiPokusaj: b.drugiPokusaj = true; bitka = b
        case .zamena: bitka = b; zameniPitanje()
        default: break
        }
        return p.dejstvo
    }

    /// Da li moć sme u ovoj bitki: samo napad / samo odbrana; Juriš traži više pitanja; Prisluškivanje samo protiv igrača.
    func mozeMoc(_ p: PomocVojske, _ b: Bitka) -> Bool {
        if p.samoNapad && !b.napadam { return false }
        if p.samoOdbrana && b.napadam { return false }
        if p == .juris && b.prikazi.count < 2 { return false }
        if p == .prisluskivanje && stanje.oblasti[b.kuda]?.vlasnik == nil && b.napadam { return false }
        if p == .temelj && stanje.oblasti[b.kuda]?.vlasnik == nil { return false }
        return !b.moci.contains(p)
    }

    // MARK: Ratne karte (umesto dnevnih pomoći)

    var mojeKarte: [Karta] { mojTim.map { stanje.karte($0) } ?? [] }

    /// Karta sa mape (Pojačanje, Zamrzni) na izabranu svoju državu ili prestonicu, samo na svom potezu.
    func igrajKartuNaMapi(_ k: Karta) {
        guard covekNaPotezu, let ja = stanje.igraci.first(where: \.covek) else { return }
        let gde = izabrana.flatMap { stanje.oblasti[$0]?.vlasnik == ja.tim ? $0 : nil } ?? ja.prestonica
        let novo = k == .pojacanje ? stanje.igrajPojacanje(gde) : stanje.igrajZamrzni(gde)
        guard let novo else { javi("Izaberi svoju državu, pa odigraj kartu"); return }
        Zvuk.pusti(.kartaOdigrana, jacina: 0.45)
        stanje = novo
        objavi(novo)
        javi(k == .pojacanje ? "+\(Pravila.vojskiPojacanja) vojske: \(Mapa.oblast(gde).ime)" : "\(Mapa.oblast(gde).ime) je zamrznuta do kraja sledećeg kruga")
    }

    /// Karta u bitki: Špijun (tema pitanja), Drugi pokušaj (novo pitanje), Sabotaža (protivniku tačan manje, samo u napadu na igrača).
    func igrajKartuUBitci(_ k: Karta) {
        guard var b = bitka, b.korak != .rezultat, let t = mojTim, let novo = stanje.iskoristiKartu(t, k) else { return }
        Zvuk.pusti(.kartaOdigrana, jacina: 0.45)
        switch k {
        case .spijun: b.spijun = true
        case .sabotaza: guard b.napadam, stanje.oblasti[b.kuda]?.vlasnik != nil else { return }; b.sabotaza = true
        case .drugiPokusaj: guard b.korak == .pitanja else { return }
        default: return
        }
        stanje = novo
        bitka = b
        if k == .drugiPokusaj { zameniPitanje() }
    }

    // MARK: Brze poruke i savezi

    /// Brza poruka; „Savez?” igraču `za` je i predlog saveza (bot odmah odgovara).
    /// shortcut: u partiji preko servera poruke i savezi idu samo na svom potezu (stanje šalje igrač na potezu); kasnije poseban kanal.
    func posaljiPoruku(_ tekst: String, za: Igrac? = nil) {
        guard let ja = stanje.igraci.first(where: \.covek), stanje.faza != .kraj else { return }
        // Savez menja stanje, pa preko servera ide na svom potezu; obična poruka ide odmah (bag 04.11).
        if veza != nil && tekst == "Savez?" && !covekNaPotezu { javi("Savez predlažeš na svom potezu"); return }
        var novo = stanje.posalji(tekst, od: ja.id)
        if tekst == "Savez?", let za, za.tim != ja.tim {
            let bot = !za.covek && !za.id.hasPrefix("u:")
            let prihvata = bot && novo.botPrihvataSavez(bot: za.tim, od: ja.tim)
            novo = novo.predloziSavez(od: ja.tim, za: za.tim, prihvata: prihvata)
            if bot { novo = novo.posalji(prihvata ? "Može, savez!" : "Ne ovaj put.", od: za.id) }
            if novo.uSavezu(ja.tim, za.tim) { javi("Savez sa \(za.ime) do kraja igre!"); Zvuk.pusti(.savez, jacina: 0.5) }
        }
        stanje = novo
        guard let veza else { return }
        if tekst == "Savez?" { objavi(novo) }
        Task { await veza.posalji(.init(v: "poruka", tekst: tekst, za: za?.id)) }
        javi("Poslato: \(tekst)")
    }

    /// Poslednja poruka drugog igrača za oblačić na vrhu ekrana (vidi se 6 s; ranije samo sitno, pa se nije primećivala).
    var svezaPorukaRivala: (igrac: Igrac, tekst: String)? {
        guard let p = stanje.poruke?.last, p.od != mojId, Date().timeIntervalSince1970 - p.kad < 6,
              let i = stanje.igraci.first(where: { $0.id == p.od }) else { return nil }
        return (i, p.tekst)
    }

    // MARK: Savet „Šta da radim?” (jednom po potezu)

    private var savetZa: (krug: Int, igrac: Int)?
    /// Vlasnik 04.11 uveče: savet samo kaže šta (traka gore + strelica na mapi), igrač sam dodiruje i igra.
    struct Predlog: Equatable {
        let tekst: String
        var odakle: String? = nil
        var kuda: String? = nil
        let krug: Int
        let faza: Faza
    }
    var predlog: Predlog?
    /// Predlog važi samo u fazi i krugu u kojem je dat.
    var aktivanPredlog: Predlog? {
        guard let p = predlog, covekNaPotezu, p.krug == stanje.krug, p.faza == stanje.faza else { return nil }
        return p
    }
    var mozeSavet: Bool { covekNaPotezu && savetZa.map { $0 != (stanje.krug, stanje.naPotezu) } ?? true && bitka == nil }

    func savet() {
        guard mozeSavet else { javi("Savet je već iskorišćen u ovom potezu"); return }
        if stanje.faza == .raspored {
            savetZa = (stanje.krug, stanje.naPotezu)
            // Raspored koji bi bot napravio, samo kao tekst: gde i koliko, igrač stavlja sam.
            let posle = stanje.botRasporedi()
            let dodato = posle.oblasti.compactMap { id, o -> (String, Int)? in
                let n = o.vojske - (stanje.oblasti[id]?.vojske ?? 0)
                return n > 0 ? (id, n) : nil
            }.sorted { $0.1 > $1.1 }
            guard !dodato.isEmpty else { return }
            let spisak = dodato.prefix(3).map { "\(Mapa.oblast($0.0).ime) +\($0.1)" }.joined(separator: ", ")
            predlog = Predlog(tekst: "Stavi vojsku na najugroženije granice: \(spisak).", odakle: dodato.first?.0, krug: stanje.krug, faza: .raspored)
            if let id = dodato.first?.0 { pokaziDrzavu(id) }
            return
        }
        guard stanje.faza == .napad else { return }
        savetZa = (stanje.krug, stanje.naPotezu)
        guard let n = stanje.najboljiNapad(), n.ocena > -0.5 else {
            predlog = Predlog(tekst: "Nema dobrog napada. Prebaci vojsku Maršom na granicu i završi potez.", krug: stanje.krug, faza: .napad)
            return
        }
        let neutralna = stanje.oblasti[n.kuda]?.vlasnik == nil
        predlog = Predlog(tekst: "Napadni \(Mapa.oblast(n.kuda).ime)\(neutralna ? " (prazno polje)" : "") iz \(Mapa.oblast(n.odakle).ime). Dodirni \(Mapa.oblast(n.odakle).ime), pa \(Mapa.oblast(n.kuda).ime).",
                          odakle: n.odakle, kuda: n.kuda, krug: stanje.krug, faza: .napad)
        pokaziDrzavu(n.kuda)
    }

    /// Diplomatski raskid saveza (na svom potezu).
    func raskiniSavez() {
        guard covekNaPotezu, let t = mojTim, let novo = stanje.raskiniSavez(t) else { javi("Savez raskidaš na svom potezu"); return }
        stanje = novo.posalji("Raskidam savez.", od: stanje.trenutni.id)
        objavi(stanje)
        javi("Savez važi do kraja kruga. Novog saveznika biraš posle sledećeg kruga.")
    }

    /// Zamena misije sa saveznikom (do 5. kruga): bot odmah odgovara, igrač na drugom telefonu predlaže isto.
    func zameniMisiju(sa p: Igrac) {
        guard covekNaPotezu, let t = mojTim else { javi("Misiju menjaš na svom potezu"); return }
        let bot = !p.covek && !p.id.hasPrefix("u:")
        let prihvata = bot && stanje.botPrihvataZamenu(bot: p.tim, od: t)
        guard var novo = stanje.predloziZamenuMisije(od: t, za: p.tim, prihvata: prihvata) else {
            javi("Misije se menjaju sa saveznikom, do \(Pravila.zamenaMisijaDoKruga). kruga"); return
        }
        if bot { novo = novo.posalji(prihvata ? "Menjamo!" : "Zadržavam svoju.", od: p.id) }
        let promenjena = novo.misije[t] != stanje.misije[t]
        stanje = novo
        objavi(stanje)
        if promenjena { Zvuk.pusti(.misija, jacina: 0.45); javi("Nova misija: \(stanje.tekstMisije(stanje.misije[t]))") }
        else if !bot { javi("Predlog poslat: zamena važi kad i \(p.ime) predloži") }
    }

    /// Traži pomoć od saveznika: bot šalje odmah ako može, igraču stiže poruka.
    func traziPomoc(od p: Igrac) {
        guard let t = mojTim, stanje.uSavezu(t, p.tim) else { return }
        let bot = !p.covek && !p.id.hasPrefix("u:")
        if bot, let novo = stanje.posaljiPomoc(od: p.tim, za: t) {
            stanje = novo.posalji("Šaljem pomoć!", od: p.id)
            objavi(stanje)
        } else {
            posaljiPoruku("Pošalji pomoć!", za: p)
            if bot { stanje = stanje.posalji("Ne mogu sada.", od: p.id) }
        }
    }

    /// Savezničko pojačanje: 2 vojske savezniku preko zajedničke granice, jednom po krugu, na svom potezu.
    func posaljiPomoc(za p: Igrac) {
        guard covekNaPotezu, let t = mojTim else { javi("Pomoć šalješ na svom potezu"); return }
        guard let (a, b) = stanje.putPomoci(od: t, za: p.tim), let novo = stanje.posaljiPomoc(od: t, za: p.tim) else {
            javi("Nema granice sa \(p.ime) gde imaš bar \(Pravila.vojskiPomociSavezniku + 1) vojske, ili si već slao u ovom krugu"); return
        }
        Zvuk.pusti(.pojacanja, jacina: 0.45)
        stanje = novo.posalji("Šaljem pomoć!", od: stanje.trenutni.id)
        objavi(stanje)
        javi("+\(Pravila.vojskiPomociSavezniku) vojske iz \(Mapa.oblast(a).ime) u \(Mapa.oblast(b).ime)")
    }

    /// Način igre za profil: sam, u savezu ili zajedno (isti tim, ista boja).
    var nacinZaProfil: String {
        guard let ja = stanje.igraci.first(where: \.covek) else { return "sam" }
        if (stanje.savezi ?? [:]).contains(where: { $0.key.split(separator: "|").contains(Substring(ja.tim)) }) { return "savez" }
        if stanje.igraci.contains(where: { $0.id != ja.id && $0.tim == ja.tim }) { return "zajedno" }
        return "sam"
    }

    // MARK: Tok poteza

    private func pocniPotez(_ novo: Stanje) {
        guard !napusteno else { return }
        stanje = novo
        sacuvaj()
        najaviMisijuAkoTreba()
        guard novo.faza == .snabdevanje else { return }
        zapocetPotez = (novo.krug, novo.naPotezu)
        // Pravi igrač sa drugog telefona igra sam; bota vodi samo domaćin.
        if udaljen(novo.trenutni) { pratiUdaljenog(); return }
        if veza != nil && !novo.trenutni.covek && veza?.domacin != true { return }
        #if DEBUG
        // Provera odbrane (`-demo -demoOdbrana`): moj potez se preskače, botovi napadaju mene.
        if LibrumKvizApp.demoOdbrana && novo.trenutni.covek { Task { try? await Task.sleep(for: .seconds(1)); krajPoteza() }; return }
        #endif
        if novo.trenutni.covek {
            mojPotez += 1
            // Pojačanja stižu bez pitanja, a igrač ih sam raspoređuje dodirom (vlasnik 03.11); „Rasporedi sam” ih stavlja na granice.
            let tim = novo.trenutni.tim
            var s = novo.snabdevanje(tacno: true)
            s.tacnih[tim, default: 1] -= 1 // pojačanje nije tačan odgovor (misije broje tačne)
            stanje = s
            let n = s.zaRaspored
            let rec = n % 10 == 1 && n % 100 != 11 ? "vojska" : (2...4).contains(n % 10) && !(12...14).contains(n % 100) ? "vojske" : "vojski"
            javi("Stiglo je \(n) \(rec). Dodiruj svoje države gde ih želiš.")
            pokreniSat()
            #if DEBUG
            if LibrumKvizApp.demoIgrac { Task { await demoPotez() } }
            #endif
        } else {
            Task { await potezBota() }
        }
    }

    private func potezBota() async {
        guard !botRadi, !napusteno else { return }
        botRadi = true
        let generacija = generacijaBota
        pokreniCuvara()
        defer { if generacija == generacijaBota { botRadi = false } }
        var napada = 0
        stanje = stanje.snabdevanje(tacno: slucajno.sledeci() < stanje.tacnostBota).botRasporedi().botOdbrana().botIgraKarte().botTraziSavez()
            .botIzdaja().botNajaviPohod().botUltimatum().botPomazeSavezniku()
        try? await Task.sleep(for: pauzaBota)
        await sacekajPauzu()
        while !napusteno, generacija == generacijaBota, napada < Self.najviseNapadaBota, let napad = stanje.botSledeciNapad() {
            await sacekajPauzu()
            guard !napusteno, generacija == generacijaBota else { break }
            napada += 1
            let pre = (stanje.bitaka, stanje.oblasti)
            izabrana = napad.odakle
            Zvuk.pusti(.botNapada, jacina: 0.45)
            try? await Task.sleep(for: pauzaBota)
            if let vlasnik = stanje.oblasti[napad.kuda]?.vlasnik {
                let tim = stanje.trenutni.tim
                // Prva dva odgovora posebno: oprezan bot se povlači posle dve greške i završava napade.
                let prva = (0..<Pravila.povlacenjePosle).map { _ in stanje.botOdgovor(&slucajno) }
                if stanje.narav(stanje.trenutni.id) == .oprezan && prva.allSatisfy({ !$0.tacan }) {
                    stanje = stanje.posalji("Povlačim se!", od: stanje.trenutni.id)
                    break
                }
                let ostatak = stanje.botSkor(&slucajno, pitanja: Pravila.pitanjaUBitci - Pravila.povlacenjePosle)
                var napadac = Skor(tacnih: prva.filter(\.tacan).count + ostatak.tacnih, ms: prva.reduce(0) { $0 + $1.ms } + ostatak.ms)
                // Ulog kad je bitka skoro sigurna.
                let branilacCovek = stanje.igraci.first { $0.tim == vlasnik }.map { $0.covek || $0.id.hasPrefix("u:") } ?? false
                stanje = stanje.postaviUlog(Stanje.ulogBota(Stanje.sansaBitke(stanje.tacnostBota, branilacCovek ? 0.65 : stanje.tacnostBota,
                    n: Pravila.pitanjaUBitci, prednost: stanje.odbranaMete(napad.kuda) == .prednost, pomak: stanje.pomakBitke(odakle: napad.odakle, kuda: napad.kuda))))
                // Drugi pokušaj: jedno promašeno pitanje bot odgovara ponovo.
                if napadac.tacnih < Pravila.pitanjaUBitci, let novo = stanje.iskoristiKartu(tim, .drugiPokusaj) {
                    stanje = novo
                    if slucajno.sledeci() < stanje.tacnostBota { napadac = Skor(tacnih: napadac.tacnih + 1, ms: napadac.ms) }
                }
                // Sabotaža: branilac gubi jedan tačan.
                var sabotaza = false
                if let novo = stanje.iskoristiKartu(tim, .sabotaza) { stanje = novo; sabotaza = true }
                var branilac: Skor
                if let b = stanje.igraci.first(where: { $0.tim == vlasnik }), udaljen(b) {
                    branilac = await udaljenaOdbrana(odakle: napad.odakle, kuda: napad.kuda, napadac: napadac)
                    if sabotaza { branilac = Skor(tacnih: max(0, branilac.tacnih - 1), ms: branilac.ms) }
                    let (novo, ishod) = stanje.razresiBitkuSkorom(odakle: napad.odakle, kuda: napad.kuda, napadac: napadac, branilac: branilac)
                    stanje = novo
                    udari(napad.odakle, napad.kuda, ishod.osvojeno)
                    objavi(stanje)
                } else if stanje.igraci.first(where: { $0.tim == vlasnik })?.covek == true {
                    branilac = await withCheckedContinuation { nastavak in
                        cekaOdbranu = nastavak
                        var b = novaBitka(napadam: false, odakle: napad.odakle, kuda: napad.kuda)
                        b.sabotiranSam = sabotaza
                        b.rivalPoznat = napadac
                        Zvuk.pusti(.uzbuna, jacina: 0.5)
                        bitka = b
                    }
                    let (novo, ishod) = stanje.razresiBitkuSkorom(odakle: napad.odakle, kuda: napad.kuda, napadac: napadac, branilac: branilac)
                    stanje = novo
                    udari(napad.odakle, napad.kuda, ishod.osvojeno)
                    if ishod.osvojeno, slucajno.sledeci() < 0.35 { stanje = stanje.posalji(["Hvala!", "Bravo!"][Int(slucajno.sledeci() * 2)], od: stanje.trenutni.id) }
                    ishodOdbrane(napadac, ishod)
                    // Igrač je možda već zatvorio ekran bitke: tada se ne čeka (inače bot stoji zauvek, partija se zamrzne).
                    if bitka != nil { await withCheckedContinuation { zatvaranje = $0 } }
                } else {
                    branilac = stanje.botSkor(&slucajno)
                    if sabotaza { branilac = Skor(tacnih: max(0, branilac.tacnih - 1), ms: branilac.ms) }
                    let (novo, ishod) = stanje.razresiBitkuSkorom(odakle: napad.odakle, kuda: napad.kuda, napadac: napadac, branilac: branilac)
                    stanje = novo
                    udari(napad.odakle, napad.kuda, ishod.osvojeno)
                }
            } else {
                let (novo, ishod) = stanje.razresiBitku(odakle: napad.odakle, kuda: napad.kuda, napadac: stanje.botOdgovor(&slucajno), branilac: nil)
                stanje = novo
                udari(napad.odakle, napad.kuda, ishod.osvojeno)
            }
            if stanje.faza == .kraj { break }
            najaviMisijuAkoTreba()
            // Napad koji pravila odbiju ne menja ništa: bot bi ga birao zauvek i partija bi stala („Zig je na potezu”, vlasnik 05.11).
            if stanje.bitaka == pre.0 && stanje.oblasti == pre.1 { break }
            try? await Task.sleep(for: pauzaBota)
        }
        guard generacija == generacijaBota else { return }
        izabrana = nil
        botRadi = false
        await sacekajPauzu()
        guard !napusteno, generacija == generacijaBota else { return }
        // Pre kraja poteza bot prebacuje vojsku iz unutrašnjosti na ugroženu granicu.
        if stanje.faza == .napad { stanje = stanje.botUtvrdi() }
        let novo = stanje.zavrsiPotez()
        objavi(novo)
        pocniPotez(novo)
    }

    /// Najviše napada jednog bota u potezu (osigurač; pravi potez ih ima nekoliko).
    static let najviseNapadaBota = 40

    /// Čuvar poteza bota: ako se potez ne pomeri 30 s (bez pauze i otvorene bitke), potez se završava, da partija ne stane.
    private func pokreniCuvara() {
        cuvar?.cancel()
        cuvar = Task { [weak self] in
            var poslednji = ""; var isto = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard let self, !self.napusteno, self.stanje.faza != .kraj, !self.stanje.trenutni.covek, self.veza == nil else { return }
                let otisak = "\(self.stanje.krug)-\(self.stanje.naPotezu)-\(self.stanje.bitaka)-\(self.stanje.faza)"
                isto = (otisak == poslednji && !self.pauza && self.bitka == nil && self.obavestenjeMisije == nil) ? isto + 1 : 0
                poslednji = otisak
                guard isto >= 3 else { continue }
                print("Osvajač: potez bota zaglavljen (\(otisak)), završava se")
                self.generacijaBota += 1
                self.botRadi = false
                self.izabrana = nil
                let novo = self.stanje.zavrsiPotez()
                self.objavi(novo)
                self.pocniPotez(novo)
                return
            }
        }
    }

    func javi(_ tekst: String) {
        poruka = tekst
        Task {
            try? await Task.sleep(for: .seconds(7))
            if poruka == tekst { poruka = nil }
        }
    }
}
