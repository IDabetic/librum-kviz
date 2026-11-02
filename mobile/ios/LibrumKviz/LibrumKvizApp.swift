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
    @State private var kartica = 1
    var body: some View {
        TabView(selection: $kartica) {
            NavigationStack { IgraciTabView() }
                .tabItem { Label("Igrači", systemImage: "person.2") }
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
                .badge(napredak.neprocitanih)
        }
    }
}
