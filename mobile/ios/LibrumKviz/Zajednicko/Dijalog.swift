import SwiftUI

/// Potvrda u stilu kita (umesto sistemskog alerta).
struct Dijalog: View {
    let naslov: String
    let tekst: String
    let potvrda: String
    let odustani: String
    var opasno = false
    let potvrdi: () -> Void
    let zatvori: () -> Void

    var body: some View {
        ZStack {
            Color.mastilo.opacity(0.55).ignoresSafeArea().onTapGesture(perform: zatvori)
            VStack(alignment: .leading, spacing: 14) {
                Naslov(tekst: naslov, velicina: 26)
                Text(tekst).font(.tekst(15)).foregroundStyle(Color.sivaTekst)
                HStack(spacing: 10) {
                    Button(odustani, action: zatvori).buttonStyle(.sekundarno)
                    Button(potvrda, action: potvrdi).buttonStyle(DugmeStil(vrsta: opasno ? .primarno : .zuto))
                        .tint(opasno ? .crvena : nil)
                }
            }
            .padding(22)
            .pop()
            .padding(24)
            .accessibilityAddTraits(.isModal)
        }
        .transition(.opacity)
    }
}
