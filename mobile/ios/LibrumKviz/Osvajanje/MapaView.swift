import SwiftUI

/// Mapa sveta: šestougaone oblasti sa vojskama, veze kao linije. Na telefonu
/// se mapa pomera vodoravno, da oblast ostane dovoljno velika za prst.
struct MapaView: View {
    let stanje: Stanje
    let izabrana: String?
    let mete: [String]
    let dodir: (String) -> Void

    static let sirina: CGFloat = 1080
    static let visina: CGFloat = 600
    private let r: CGFloat = 44

    private static let natpisi: [String: CGPoint] = [
        "sam": .init(x: 20, y: 398), "jam": .init(x: 120, y: 585), "evr": .init(x: 560, y: 30),
        "afr": .init(x: 600, y: 560), "azi": .init(x: 840, y: 40), "oke": .init(x: 960, y: 580),
    ]

    var body: some View {
        GeometryReader { g in
            // Cela mapa kad stane (iPad); na telefonu 0,7 da šestougao ostane ~62 pt, pa se pomera.
            let razmera = max(min(g.size.height / Self.visina, g.size.width / Self.sirina, 1), 0.7)
            // Uspravno pomeranje samo kad mapa ne staje, inače bi se centrirala i ostavila prazninu gore.
            let osovine: Axis.Set = Self.visina * razmera > g.size.height + 1 ? [.horizontal, .vertical] : .horizontal
            ScrollViewReader { pomeranje in
            ScrollView(osovine, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    veze
                    ForEach(Mapa.kontinenti, id: \.id) { k in
                        let p = Self.natpisi[k.id]!
                        Text("\(k.ime.uppercased()) +\(k.bonus)").font(.tekst(13, .bold)).tracking(1.5)
                            .foregroundStyle(Color.sivaTekst).fixedSize()
                            .position(x: p.x + 70, y: p.y - 4)
                    }
                    ForEach(Mapa.oblasti, id: \.id) { o in
                        oblast(o).position(x: o.x, y: o.y)
                    }
                }
                .frame(width: Self.sirina, height: Self.visina)
                .scaleEffect(razmera, anchor: .topLeading)
                .frame(width: Self.sirina * razmera, height: Self.visina * razmera, alignment: .topLeading)
                // Sidra u neskaliranim koordinatama: scaleEffect ne pomera raspored, pa scrollTo ide na njih.
                .overlay(alignment: .topLeading) {
                    ForEach(Mapa.oblasti, id: \.id) { o in
                        Color.clear.frame(width: 1, height: 1).position(x: o.x * razmera, y: o.y * razmera).id(o.id)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .onAppear { pomeranje.scrollTo(fokus, anchor: .center) }
            .onChange(of: fokus) { _, novo in withAnimation(.easeInOut) { pomeranje.scrollTo(novo, anchor: .center) } }
            }
        }
    }

    /// Oblast koju mapa drži na ekranu: izabrana (i kod poteza bota), inače tvoja prestonica.
    private var fokus: String {
        izabrana ?? stanje.igraci.first(where: \.covek)?.prestonica ?? "balkan"
    }

    private var veze: some View {
        Canvas { ctx, _ in
            for (a, b) in Mapa.veze {
                let p = Mapa.oblast(a), q = Mapa.oblast(b)
                var put = Path()
                put.move(to: CGPoint(x: p.x, y: p.y))
                put.addLine(to: CGPoint(x: q.x, y: q.y))
                let morska = hypot(p.x - q.x, p.y - q.y) > 150
                ctx.stroke(put, with: .color(Color.mastilo.opacity(morska ? 0.35 : 0.55)),
                           style: StrokeStyle(lineWidth: morska ? 2 : 3, lineCap: .round, dash: morska ? [6, 7] : []))
            }
        }
        .frame(width: Self.sirina, height: Self.visina)
        .allowsHitTesting(false)
    }

    private func oblast(_ o: Oblast) -> some View {
        let st = stanje.oblasti[o.id]!
        let vlasnik = stanje.igraci.first { $0.id == st.vlasnik }
        let jeMeta = mete.contains(o.id)
        let jeIzabrana = izabrana == o.id
        let prestonica = stanje.igraci.contains { $0.prestonica == o.id }
        return Button { dodir(o.id) } label: {
                ZStack {
                    if jeIzabrana || jeMeta {
                        Sestougao().stroke(jeIzabrana ? Color.zuta : Color.mastilo,
                                           style: StrokeStyle(lineWidth: jeIzabrana ? 7 : 3, dash: jeMeta ? [7, 6] : []))
                            .frame(width: (r + 9) * 2, height: (r + 9) * 2)
                    }
                    Sestougao().fill(Color.mastilo).frame(width: r * 2, height: r * 2).offset(y: 5)
                    Sestougao().fill(vlasnik.map { Color(hex: $0.boja) } ?? .white).frame(width: r * 2, height: r * 2)
                    Sestougao().stroke(Color.mastilo, lineWidth: 3).frame(width: r * 2, height: r * 2)
                    Text("\(st.vojske)").font(.naslov(27))
                        .foregroundStyle(vlasnik == nil ? Color.mastilo : .white)
                        .contentTransition(.numericText())
                    if prestonica {
                        Image(systemName: "crown.fill").font(.system(size: 15)).foregroundStyle(Color.zuta)
                            .shadow(color: .mastilo, radius: 0, x: 1, y: 1)
                            .offset(y: -27)
                    }
                }
                .frame(width: (r + 10) * 2, height: (r + 10) * 2)
                // Ime ispod šestougla ne menja okvir, pa središte ostaje tačno na (x, y).
                .overlay(alignment: .bottom) {
                    Text(o.ime).font(.tekst(13, .bold)).foregroundStyle(Color.mastilo).fixedSize()
                        .padding(.horizontal, 3)
                        .background(Color.krem.opacity(0.85), in: RoundedRectangle(cornerRadius: 4))
                        .offset(y: 8)
                }
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.3), value: st)
        .accessibilityLabel("\(o.ime), \(st.vojske) vojski, \(vlasnik?.ime ?? "neutralno")\(prestonica ? ", prestonica" : "")")
        .accessibilityAddTraits(jeIzabrana ? .isSelected : [])
    }
}

/// Šestougao sa šiljkom gore (isti ugao kao na vebu).
struct Sestougao: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        var p = Path()
        for i in 0..<6 {
            let ugao = Double.pi / 3 * Double(i) - Double.pi / 6
            let tacka = CGPoint(x: c.x + r * cos(ugao), y: c.y + r * sin(ugao))
            if i == 0 { p.move(to: tacka) } else { p.addLine(to: tacka) }
        }
        p.closeSubpath()
        return p
    }
}
