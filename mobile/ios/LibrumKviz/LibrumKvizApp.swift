import SwiftUI

@main
struct LibrumKvizApp: App {
    /// Samo razvojna verzija na simulatoru (`-bezPrijave`): ekrani se proveravaju bez lozinke. U izdanju je uvek false.
    #if DEBUG
    static let bezPrijave = ProcessInfo.processInfo.arguments.contains("-bezPrijave")
    /// Snimak Osvajanja za sajt: partija botova otvara se odmah, bez uvoda i prijave.
    static let demo = ProcessInfo.processInfo.arguments.contains("-demo")
    static let demoOdbrana = ProcessInfo.processInfo.arguments.contains("-demoOdbrana")
    /// Snimak za sajt sa igračem (`-demo -demoIgrac`): moj potez se igra sam kroz prave ekrane (izbor, napad, pitanja).
    static let demoIgrac = ProcessInfo.processInfo.arguments.contains("-demoIgrac")
    #else
    static let bezPrijave = false
    static let demo = false
    static let demoOdbrana = false
    static let demoIgrac = false
    #endif

    @UIApplicationDelegateAdaptor(AplikacijaDelegat.self) private var delegat
    @State private var sesija = Sesija()
    @State private var napredak = Napredak.deljeni
    @State private var mreza = Mreza.deljena
    @AppStorage("tema") private var tema = "sistem"
    /// Animacija pokretanja jednom po paljenju aplikacije (preko svega dok traje).
    @State private var pocetak = true

    var body: some Scene {
        WindowGroup {
            Group {
                if Self.demo {
                    // `-demoIgraca 6 -demoKrugova 30` za duge probe (pad 03.11 u 9. krugu od 30 sa šest igrača).
                    let d = UserDefaults.standard.integer(forKey: "demoIgraca")
                    let n = d >= 2 ? d : 4
                    let k = UserDefaults.standard.integer(forKey: "demoKrugova")
                    OsvajanjeIgraView(model: OsvajanjeModel(postavka: OsvajanjePostavka(nacin: .svakoZaSebe, igraca: n, krugova: k > 0 ? k : 20, tezina: .tesko,
                        igraci: OsvajanjePostavka.mesta(.svakoZaSebe, n, ime: "Librum"))))
                }
                else if !napredak.s.uvodZavrsen { UvodView() }
                else if !sesija.prijavljen && !Self.bezPrijave { PrijavaTok(obavezna: true) }
                else if sesija.trebaDopuna && !Self.bezPrijave { DopunaProfila() }
                else { Koren() }
            }
            .environment(sesija)
            .environment(napredak)
            .environment(mreza)
            .tint(.mastilo)
            .preferredColorScheme(tema == "svetla" ? .light : tema == "tamna" ? .dark : nil)
            .task { await sesija.ucitajNadimak() }
            .task(id: sesija.korisnikId) { if sesija.prijavljen { await Obavestenja.prijavi() } }
            .overlay { if pocetak { PocetakView { pocetak = false } } }
        }
    }
}

/// Četiri kartice: igrači (društvo), igre, rang lista, profil.
struct Koren: View {
    @Environment(Napredak.self) private var napredak
    @Environment(Sesija.self) private var sesija
    @State private var kartica = 1
    @State private var pocetakIgara = UUID()
    @State private var link: Link?
    /// Poziv u sobu koji čeka odgovor (baner preko aplikacije); viđeni se ne prikazuju ponovo.
    @State private var poziv: Takmicenje.Poziv?
    @State private var videniPozivi: Set<String> = []
    /// Odredište linka librumkviz://duel/KOD, librumkviz://soba/KOD ili librumkviz://igrac/ID.
    enum Link: Identifiable {
        case duel(String), igrac(String), osvajanje(String), soba(String)
        var id: String {
            switch self { case .duel(let k): "d" + k; case .igrac(let i): "i" + i; case .osvajanje(let k): "o" + k; case .soba(let k): "s" + k }
        }
    }
    var body: some View {
        TabView(selection: $kartica) {
            NavigationStack { IgraciTabView() }
                .tabItem { Label("Igrači", systemImage: "person.2") }
                .badge(Brojaci.deljeni.poruke)
                .tag(0)
            NavigationStack { PocetnaView() }
                .id(pocetakIgara)
                .tabItem { Label("Igre", systemImage: "gamecontroller") }
                .tag(1)
            NavigationStack { RangListaView() }
                .tabItem { Label("Rang lista", systemImage: "trophy") }
                .tag(2)
            NavigationStack { ProfilView() }
                .tabItem { Label("Profil", systemImage: "person") }
                .tag(3)
                .badge(napredak.neprocitanih + Brojaci.deljeni.obavestenja)
        }
        // „Početak” na kraju partije: nova stopa kartice Igre zatvara partiju i sve ekrane ispod nje.
        .onReceive(NotificationCenter.default.publisher(for: .naPocetak)) { _ in link = nil; kartica = 1; pocetakIgara = UUID() }
        .onOpenURL { url in
            guard url.scheme == "librumkviz", let vrednost = url.pathComponents.dropFirst().first else { return }
            switch url.host() {
            case "duel": link = .duel(vrednost.uppercased())
            case "igrac": link = .igrac(vrednost)
            case "osvajanje": link = .osvajanje(vrednost.uppercased())
            case "soba": link = .soba(vrednost.uppercased())
            default: break
            }
        }
        .fullScreenCover(item: $link) { l in
            NavigationStack {
                switch l {
                case .duel(let kod): DuelView(kodSobe: kod)
                case .igrac(let id): ProfilIgracaView(id: id)
                case .osvajanje(let kod): PozivView(postavka: nil, kod: kod)
                case .soba(let kod): TakmicenjeView(kod: kod)
                }
            }
        }
        .overlay(alignment: .top) {
            if let p = poziv {
                PozivBaner(poziv: p) { da in
                    withAnimation { poziv = nil }
                    if da { link = .soba(p.kod) } else { Task { await Takmicenje.odbij(p.kod) } }
                }
                .padding(.top, 4)
            }
        }
        .animation(.spring(duration: 0.4), value: poziv)
        // Pozivi u sobu: na svakih 8 s dok je aplikacija otvorena (shortcut: bez push-a; posle APNs ključa stiže i kad je zatvorena).
        .task(id: sesija.korisnikId) {
            guard sesija.prijavljen else { return }
            while !Task.isCancelled {
                if poziv == nil, link == nil, let p = await Takmicenje.pozivi().first(where: { !videniPozivi.contains($0.kod) }) {
                    videniPozivi.insert(p.kod)
                    poziv = p
                    Zvuk.pusti(.obavestenje, jacina: 0.5)
                }
                try? await Task.sleep(for: .seconds(8))
            }
        }
        // Brojači na karticama: na svakih 60 s dok je aplikacija otvorena (shortcut: bez push-a; posle Firebase-a stiže odmah).
        .task(id: sesija.korisnikId) {
            while !Task.isCancelled { await Brojaci.deljeni.osvezi(sesija); try? await Task.sleep(for: .seconds(60)) }
        }
    }
}

extension Notification.Name {
    /// Kraj partije → nazad na početnu (kartica Igre od početka).
    static let naPocetak = Notification.Name("librumkviz.naPocetak")
    /// Kraj Osvajanja → „Nova partija”: zatvaraju se čekaonica i soba, ostaje podešavanje partije.
    static let novaPartijaOsvajanja = Notification.Name("librumkviz.novaPartijaOsvajanja")
}
