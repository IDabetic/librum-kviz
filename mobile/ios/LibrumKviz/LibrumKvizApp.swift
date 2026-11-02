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

/// Tri kartice kao svaka iOS aplikacija: igre, rang lista, profil.
struct Koren: View {
    @Environment(Napredak.self) private var napredak
    var body: some View {
        TabView {
            NavigationStack { PocetnaView() }
                .tabItem { Label("Igre", systemImage: "gamecontroller") }
            NavigationStack { RangListaView() }
                .tabItem { Label("Rang lista", systemImage: "trophy") }
            NavigationStack { ProfilView() }
                .tabItem { Label("Profil", systemImage: "person") }
                .badge(napredak.neprocitanih)
        }
    }
}
