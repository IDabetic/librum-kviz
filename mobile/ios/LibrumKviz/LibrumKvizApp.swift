import SwiftUI

@main
struct LibrumKvizApp: App {
    @UIApplicationDelegateAdaptor(AplikacijaDelegat.self) private var delegat
    @State private var sesija = Sesija()
    @State private var napredak = Napredak.deljeni
    @State private var mreza = Mreza.deljena
    @AppStorage("tema") private var tema = "sistem"

    var body: some Scene {
        WindowGroup {
            Group {
                if napredak.s.uvodZavrsen { Koren() } else { UvodView() }
            }
            .environment(sesija)
            .environment(napredak)
            .environment(mreza)
            .tint(.mastilo)
            .preferredColorScheme(tema == "svetla" ? .light : tema == "tamna" ? .dark : nil)
            .task { await sesija.ucitajNadimak() }
            .task(id: sesija.korisnikId) { if sesija.prijavljen { await Obavestenja.prijavi() } }
        }
    }
}

/// Četiri kartice: igrači (društvo), igre, rang lista, profil.
struct Koren: View {
    @Environment(Napredak.self) private var napredak
    @Environment(Sesija.self) private var sesija
    @State private var kartica = 1
    @State private var link: Link?
    /// Odredište linka librumkviz://duel/KOD ili librumkviz://igrac/ID.
    enum Link: Identifiable { case duel(String), igrac(String); var id: String { switch self { case .duel(let k): "d" + k; case .igrac(let i): "i" + i } } }
    var body: some View {
        TabView(selection: $kartica) {
            NavigationStack { IgraciTabView() }
                .tabItem { Label("Igrači", systemImage: "person.2") }
                .badge(Brojaci.deljeni.poruke)
                .tag(0)
            NavigationStack { PocetnaView() }
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
        .onOpenURL { url in
            guard url.scheme == "librumkviz", let vrednost = url.pathComponents.dropFirst().first else { return }
            switch url.host() {
            case "duel": link = .duel(vrednost.uppercased())
            case "igrac": link = .igrac(vrednost)
            default: break
            }
        }
        .fullScreenCover(item: $link) { l in
            NavigationStack {
                switch l {
                case .duel(let kod): DuelView(kodSobe: kod)
                case .igrac(let id): ProfilIgracaView(id: id)
                }
            }
        }
        // Brojači na karticama: na svakih 60 s dok je aplikacija otvorena (shortcut: bez push-a; posle Firebase-a stiže odmah).
        .task(id: sesija.korisnikId) {
            while !Task.isCancelled { await Brojaci.deljeni.osvezi(sesija); try? await Task.sleep(for: .seconds(60)) }
        }
    }
}
