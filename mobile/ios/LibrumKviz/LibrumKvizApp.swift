import SwiftUI

@main
struct LibrumKvizApp: App {
    @State private var sesija = Sesija()

    var body: some Scene {
        WindowGroup {
            Koren()
                .environment(sesija)
                .tint(.mastilo)
                .task { await sesija.ucitajNadimak() }
        }
    }
}

/// Tri kartice kao svaka iOS aplikacija: igre, rang lista, profil.
struct Koren: View {
    var body: some View {
        TabView {
            NavigationStack { PocetnaView() }
                .tabItem { Label("Igre", systemImage: "gamecontroller") }
            NavigationStack { RangListaView() }
                .tabItem { Label("Rang lista", systemImage: "trophy") }
            NavigationStack { ProfilView() }
                .tabItem { Label("Profil", systemImage: "person") }
        }
    }
}
