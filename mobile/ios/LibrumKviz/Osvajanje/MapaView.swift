import SwiftUI

/// Putanje država pretvorene iz SVG zapisa (M/L/Z) jednom, pri prvom crtanju.
enum PutanjeMape {
    static let sve: [String: Path] = Dictionary(uniqueKeysWithValues: Mapa.oblasti.map { ($0.id, parsiraj($0.d)) })

    static func parsiraj(_ d: String) -> Path {
        var p = Path()
        var komanda: Character = "M"
        var brojevi: [Double] = []
        var broj = ""
        func zavrsiBroj() { if let v = Double(broj) { brojevi.append(v) }; broj = "" }
        func primeni() {
            var i = 0
            while i + 1 < brojevi.count {
                let t = CGPoint(x: brojevi[i], y: brojevi[i + 1])
                if komanda == "M" { p.move(to: t); komanda = "L" } else { p.addLine(to: t) }
                i += 2
            }
            brojevi.removeAll()
        }
        for z in d {
            switch z {
            case "M", "L":
                zavrsiBroj(); primeni(); komanda = z
            case "Z", "z":
                zavrsiBroj(); primeni(); p.closeSubpath()
            case ",", " ":
                zavrsiBroj()
            case "-":
                zavrsiBroj(); broj = "-"
            default:
                broj.append(z)
            }
        }
        zavrsiBroj(); primeni()
        return p
    }
}

/// Mapa sveta po državama u stilu infografike: svetle neutralne države (susedi
/// različiti), osvojene u boji igrača, bele granice, značke sa vojskama.
/// Zum dvama prstima i dvostrukim dodirom, pomeranje prevlačenjem, dodir bira državu.
struct MapaView: View {
    let stanje: Stanje
    let izabrana: String?
    let mete: [String]
    let fokus: String?
    let dodir: (String) -> Void

    @State private var razmera: CGFloat = 1
    @State private var pomak: CGSize = .zero
    @GestureState private var zumPokret: CGFloat = 1
    @GestureState private var prevlacenje: CGSize = .zero

    private static let neutralne: [Color] = [Color(hex: 0xCFEDE6), Color(hex: 0xFFD9E6), Color(hex: 0xFFF0BF), Color(hex: 0xDED5F7), Color(hex: 0xD3ECFA)]
    private static let okean = Color(hex: 0xE3EDF2)

    var body: some View {
        GeometryReader { g in
            let osnova = min(g.size.width / Mapa.sirina, g.size.height / Mapa.visina)
            let k = osnova * razmera * zumPokret
            let pomakSad = CGSize(width: pomak.width + prevlacenje.width, height: pomak.height + prevlacenje.height)
            let pocetak = CGPoint(x: (g.size.width - Mapa.sirina * k) / 2 + pomakSad.width, y: (g.size.height - Mapa.visina * k) / 2 + pomakSad.height)
            Canvas { ctx, velicina in
                ctx.fill(Path(CGRect(origin: .zero, size: velicina)), with: .color(Self.okean))
                var mapa = ctx
                mapa.translateBy(x: pocetak.x, y: pocetak.y)
                mapa.scaleBy(x: k, y: k)
                let tanko = 1.1 / k
                for o in Mapa.oblasti {
                    guard let put = PutanjeMape.sve[o.id], let st = stanje.oblasti[o.id] else { continue }
                    let boja = stanje.igraci.first { $0.id == st.vlasnik }.map { Color(hex: $0.boja) } ?? Self.neutralne[o.boja % 5]
                    mapa.fill(put, with: .color(boja))
                    mapa.stroke(put, with: .color(.white), lineWidth: tanko)
                }
                for id in mete {
                    guard let put = PutanjeMape.sve[id] else { continue }
                    mapa.fill(put, with: .color(Color.mastilo.opacity(0.08)))
                    mapa.stroke(put, with: .color(.mastilo), style: StrokeStyle(lineWidth: 2.5 / k, dash: [6 / k, 5 / k]))
                }
                if let izabrana, let put = PutanjeMape.sve[izabrana] {
                    mapa.stroke(put, with: .color(.zuta), style: StrokeStyle(lineWidth: 5 / k, lineJoin: .round))
                }
                // Značke se crtaju u tačkama ekrana, da ostanu iste veličine na svakom zumu.
                let krupno = Mapa.sirina * k > velicina.width * 4.5 // neutralne značke i imena tek pri jakom zumu
                let prestonice = Set(stanje.igraci.map(\.prestonica))
                for o in Mapa.oblasti {
                    guard let st = stanje.oblasti[o.id] else { continue }
                    let vlasnik = stanje.igraci.first { $0.id == st.vlasnik }
                    guard vlasnik != nil || krupno || mete.contains(o.id) else { continue }
                    let c = CGPoint(x: pocetak.x + o.x * k, y: pocetak.y + o.y * k)
                    let r: CGFloat = 11
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r + 2, width: 2 * r, height: 2 * r)), with: .color(.mastilo))
                    let krug = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
                    ctx.fill(krug, with: .color(vlasnik.map { Color(hex: $0.boja) } ?? .white))
                    ctx.stroke(krug, with: .color(.mastilo), lineWidth: 1.8)
                    ctx.draw(Text("\(st.vojske)").font(.naslov(12)).foregroundStyle(vlasnik == nil ? Color.mastilo : .white), at: c)
                    if prestonice.contains(o.id) {
                        ctx.draw(Text(Image(systemName: "crown.fill")).font(.system(size: 11)).foregroundStyle(Color.zuta),
                                 at: CGPoint(x: c.x, y: c.y - r - 6))
                    }
                    if krupno && (o.povrsina * k * k > 2200 || mete.contains(o.id) || o.id == izabrana) {
                        ctx.draw(Text(o.ime).font(.tekst(11, .bold)).foregroundStyle(Color.mastilo), at: CGPoint(x: c.x, y: c.y + r + 9))
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                SimultaneousGesture(
                    MagnifyGesture().updating($zumPokret) { v, s, _ in s = v.magnification }
                        .onEnded { v in
                            razmera = min(8, max(1, razmera * v.magnification))
                            pomak = ogranici(pomak, k: osnova * razmera, velicina: g.size)
                        },
                    DragGesture(minimumDistance: 6).updating($prevlacenje) { v, s, _ in s = v.translation }
                        .onEnded { v in
                            pomak = ogranici(CGSize(width: pomak.width + v.translation.width, height: pomak.height + v.translation.height),
                                             k: osnova * razmera, velicina: g.size)
                        }
                )
            )
            .simultaneousGesture(SpatialTapGesture().onEnded { v in
                let x = (v.location.x - pocetak.x) / k
                let y = (v.location.y - pocetak.y) / k
                if let pogodak = Mapa.oblasti.first(where: { PutanjeMape.sve[$0.id]?.contains(CGPoint(x: x, y: y)) == true }) {
                    dodir(pogodak.id)
                } else if let blizu = Mapa.oblasti.min(by: { hypot($0.x - x, $0.y - y) < hypot($1.x - x, $1.y - y) }),
                          hypot(blizu.x - x, blizu.y - y) * k < 22 {
                    // Male države (Luksemburg, Liban) pogađaju se i preko značke.
                    dodir(blizu.id)
                }
            })
            .onChange(of: fokus, initial: true) { _, novi in centriraj(novi, velicina: g.size, osnova: osnova) }
            .overlay(alignment: .topTrailing) {
                VStack(spacing: 8) {
                    zumDugme("plus.magnifyingglass", "Uvećaj") { razmera = min(8, razmera * 1.5) }
                    zumDugme("minus.magnifyingglass", "Umanji") { razmera = max(1, razmera / 1.5); if razmera == 1 { pomak = .zero } }
                    zumDugme("globe.europe.africa", "Ceo svet") { razmera = 1; pomak = .zero }
                }
                .padding(10)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Mapa sveta")
            .accessibilityValue(izabrana.map { "Izabrana \(Mapa.oblast($0).ime), mete: \(mete.map { Mapa.oblast($0).ime }.joined(separator: ", "))" } ?? "")
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.mastilo, lineWidth: 2.5))
    }

    /// Na telefonu mapa krene uvećana oko prestonice ili mesta bitke.
    private func centriraj(_ id: String?, velicina: CGSize, osnova: CGFloat) {
        guard let id else { return }
        let o = Mapa.oblast(id)
        withAnimation(.easeInOut(duration: 0.5)) {
            // Telefon: uvećano bar toliko da mapa ispuni visinu okvira.
            if velicina.width < 700 { razmera = max(razmera, 2.4, velicina.height / (Mapa.visina * osnova)) }
            let k = osnova * razmera
            pomak = ogranici(CGSize(width: (Mapa.sirina / 2 - o.x) * k, height: (Mapa.visina / 2 - o.y) * k), k: k, velicina: velicina)
        }
    }

    /// Pomeranje ne sme da otkrije prazan okean van mape; manja osa ostaje centrirana.
    private func ogranici(_ p: CGSize, k: CGFloat, velicina: CGSize) -> CGSize {
        let mx = max(0, (Mapa.sirina * k - velicina.width) / 2)
        let my = max(0, (Mapa.visina * k - velicina.height) / 2)
        return CGSize(width: min(mx, max(-mx, p.width)), height: min(my, max(-my, p.height)))
    }

    private func zumDugme(_ ikonica: String, _ opis: String, radnja: @escaping () -> Void) -> some View {
        Button { withAnimation(.spring) { radnja() } } label: {
            Image(systemName: ikonica).font(.system(size: 16, weight: .bold)).foregroundStyle(Color.mastilo)
                .frame(width: 44, height: 44).background(.white, in: Circle())
                .overlay(Circle().stroke(Color.mastilo, lineWidth: 2))
        }
        .accessibilityLabel(opis)
    }
}
