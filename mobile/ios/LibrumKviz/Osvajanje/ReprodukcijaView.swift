import SwiftUI

/// Reprodukcija partije na kraju: mapa prolazi kroz sve promene vlasnika, kako se ko širio.
struct ReprodukcijaView: View {
    let istorija: [[String: String]]
    let stanje: Stanje
    let zatvori: () -> Void
    @State private var pocetak = Date()

    /// Jedna slika na 0,12 s, pa cela partija traje nekoliko sekundi.
    private static let poSlici: TimeInterval = 0.12

    /// Granice država u igri (bez krajnjih 5%, da Rusija i ostrva ne smanje kadar).
    private var okvirIgre: CGRect {
        let o = Mapa.oblasti.filter { stanje.oblasti[$0.id] != nil }
        guard o.count < Mapa.oblasti.count, o.count > 3 else { return CGRect(x: 0, y: 0, width: Mapa.sirina, height: Mapa.visina) }
        func opseg(_ v: [Double]) -> (Double, Double) { let l = v.sorted(); let odsek = l.count / 20; return (l[odsek], l[l.count - 1 - odsek]) }
        let (x0, x1) = opseg(o.map(\.x)), (y0, y1) = opseg(o.map(\.y))
        let rub = max(x1 - x0, y1 - y0) * 0.15
        return CGRect(x: x0 - rub, y: y0 - rub, width: x1 - x0 + rub * 2, height: y1 - y0 + rub * 2)
    }

    var body: some View {
        ZStack {
            Color.senka.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 14) {
                Naslov(tekst: "Kako se svet menjao", velicina: 26).foregroundStyle(.white)
                TimelineView(.animation(minimumInterval: Self.poSlici)) { t in
                    let i = min(istorija.count - 1, Int(t.date.timeIntervalSince(pocetak) / Self.poSlici))
                    VStack(spacing: 8) {
                        Canvas { ctx, velicina in
                            // Kadar su države u igri (ceo svet ili jedan kontinent), uz malo vazduha.
                            let okvir = okvirIgre
                            let k = min(velicina.width / okvir.width, velicina.height / okvir.height)
                            ctx.translateBy(x: (velicina.width - okvir.width * k) / 2 - okvir.minX * k, y: (velicina.height - okvir.height * k) / 2 - okvir.minY * k)
                            ctx.scaleBy(x: k, y: k)
                            let vlasnici = istorija[max(0, i)]
                            for o in Mapa.oblasti where stanje.oblasti[o.id] != nil {
                                guard let put = PutanjeMape.sve[o.id] else { continue }
                                let boja = vlasnici[o.id].flatMap { t in stanje.igraci.first { $0.tim == t } }.map { Color(hex: $0.boja) } ?? Color(hex: 0xE8E2D2)
                                ctx.fill(put, with: .color(boja))
                                ctx.stroke(put, with: .color(.white), lineWidth: 0.8 / k)
                            }
                        }
                        .aspectRatio(okvirIgre.width / okvirIgre.height, contentMode: .fit)
                        .background(Color(hex: 0xE3EDF2), in: RoundedRectangle(cornerRadius: 16))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .accessibilityLabel("Reprodukcija partije, korak \(i + 1) od \(istorija.count)")
                        ProgressView(value: Double(i + 1), total: Double(istorija.count)).tint(Color.zuta)
                    }
                }
                HStack(spacing: 10) {
                    Button("Ponovo") { pocetak = Date() }.buttonStyle(.sekundarno)
                    Button("Zatvori", action: zatvori).buttonStyle(.zuto)
                }
            }
            .padding(20)
        }
    }
}
