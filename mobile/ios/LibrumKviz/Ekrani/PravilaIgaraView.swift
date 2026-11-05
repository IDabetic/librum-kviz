import SwiftUI

/// Pravila na profilu: šta važi za sve igre, pa pravila i bodovanje svake igre (isti tekst kao „Kako se igra” na kartici).
struct PravilaIgaraView: View {
    /// Igre i glavne teme; žanrovi knjiga imaju ista pravila kao „Knjige”, pa se ne ponavljaju.
    private var igre: [KvizStavka] { KvizKatalog.sve.filter { !$0.id.hasPrefix("zanr-") && !$0.id.hasPrefix("tema-") } }
    @State private var otvorena: String?

    static let zaSve = [
        "Pomoć: jedna po partiji, iz dnevnog fonda od \(Napredak.pomociDnevno) za sve igre. Fond se puni posle 24 sata.",
        "Pitanja se ne ponavljaju 7 dana. Posle toga najviše 10% partije sme biti već viđeno, dok ne prođeš ceo fond.",
        "Redosled odgovora se meša svake nedelje, pa ne vredi pamtiti „bilo je pod A”.",
        "Rang liste se vode po igri za dan, nedelju, mesec i godinu; godišnja se briše 1. januara.",
        "Rezultat ide na rang listu samo sa nalogom. Bez naloga igra radi, a napredak ostaje na telefonu.",
        "Netačno pitanje prijavi zastavicom na kartici; urednik ga proveri i ispravi.",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GornjaTraka()
                Naslov(tekst: "Pravila igara", velicina: 34)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Za sve igre").font(.tekst(17, .bold)).foregroundStyle(Color.mastilo)
                    ForEach(Array(Self.zaSve.enumerated()), id: \.offset) { _, t in stavka(t, boja: 0xFFD84D) }
                }
                .padding(16).mirna()
                ForEach(igre) { igra in
                    VStack(alignment: .leading, spacing: 10) {
                        Button {
                            withAnimation(.snappy) { otvorena = otvorena == igra.id ? nil : igra.id }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: igra.ikonica).font(.system(size: 17, weight: .bold)).foregroundStyle(Color.tinta)
                                    .frame(width: 40, height: 40).background(Color(hex: igra.boja), in: RoundedRectangle(cornerRadius: 12))
                                Text(igra.naslov).font(.tekst(17, .bold)).foregroundStyle(Color.mastilo)
                                Spacer()
                                Image(systemName: otvorena == igra.id ? "chevron.up" : "chevron.down").foregroundStyle(Color.sivaTekst)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(igra.naslov), pravila")
                        .accessibilityValue(otvorena == igra.id ? "otvoreno" : "zatvoreno")
                        if otvorena == igra.id {
                            ForEach(Array(igra.pravila.enumerated()), id: \.offset) { _, t in stavka(t, boja: igra.boja) }
                        }
                    }
                    .padding(16).mirna()
                }
            }
            .padding(16)
        }
        .background(Papir())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }

    private func stavka(_ t: String, boja: UInt32) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(Color(hex: boja)).overlay(Circle().stroke(Color.mastilo, lineWidth: 1.5)).frame(width: 10, height: 10).padding(.top, 6)
            Text(t).font(.tekst(15)).foregroundStyle(Color.mastilo).fixedSize(horizontal: false, vertical: true)
        }
    }
}
