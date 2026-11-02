import SwiftUI

/// Početna iz kita: veliki naslov i šarene kartice igara sa maskotama.
/// U aplikaciji su samo igre koje u njoj stvarno rade.
struct PocetnaView: View {
    @Environment(Sesija.self) private var sesija

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let ime = sesija.nadimak { Oznaka(tekst: "Zdravo, \(ime)", boja: .teal) }
                        Text("Izaberi kviz\ni igraj.").font(.naslov(40)).tracking(-0.5)
                    }
                    Spacer()
                    MaskotaSlika(maskota: .bloop, velicina: 92)
                }
                .padding(.top, 8)

                NavigationLink { OsvajanjeUvodView() } label: {
                    KarticaIgre(naslov: "Osvajanje sveta", opis: "171 država, vojske i bitke znanja protiv dva rivala.",
                                boja: .teal, tekst: .white, maskota: .mimi, velika: true)
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                    NavigationLink { ProKvizView(vrsta: .pro) } label: {
                        KarticaIgre(naslov: "PRO kviz", opis: "Deset života, rang lista.", boja: .ljubicasta, tekst: .white, maskota: .lumi, velika: false)
                    }
                    NavigationLink { ProKvizView(vrsta: .book) } label: {
                        KarticaIgre(naslov: "Book kviz", opis: "Pisci, dela, žanrovi.", boja: .narandzasta, tekst: .mastilo, maskota: .zig, velika: false)
                    }
                    NavigationLink { DuelView() } label: {
                        KarticaIgre(naslov: "Duel", opis: "Jedan na jedan.", boja: .mastilo, tekst: .white, maskota: .bloop, velika: false)
                    }
                    NavigationLink { VesanjeView() } label: {
                        KarticaIgre(naslov: "Vešanje", opis: "Reč slovo po slovo.", boja: .roze, tekst: .mastilo, maskota: .lumi, velika: false)
                    }
                }
                NavigationLink { BrziKvizView() } label: {
                    KarticaIgre(naslov: "Brzi kviz", opis: "Tačno ili netačno, 60 sekundi.", boja: .zuta, tekst: .mastilo, maskota: .zig, velika: false)
                }
            }
            .padding(16)
        }
        .background(Papir())
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct KarticaIgre: View {
    let naslov: String
    let opis: String
    let boja: Color
    let tekst: Color
    let maskota: Maskota
    let velika: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Circle().fill(.white.opacity(0.22)).frame(width: velika ? 230 : 150)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: velika ? 40 : 36, y: velika ? -30 : -34)
            MaskotaSlika(maskota: maskota, velicina: velika ? 160 : 84)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: velika ? 0 : 8, y: velika ? 4 : -8)
            VStack(alignment: .leading, spacing: 4) {
                Text(naslov).font(.naslov(velika ? 36 : 24)).foregroundStyle(tekst).lineLimit(1).minimumScaleFactor(0.8)
                Text(opis).font(.tekst(14, .semibold)).foregroundStyle(tekst.opacity(0.85))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: 240, alignment: .leading)
            }
            .padding(velika ? 22 : 18)
        }
        .frame(height: velika ? 250 : 160)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .pop(boja)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
