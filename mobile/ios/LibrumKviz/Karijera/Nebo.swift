import SwiftUI

/// Nebo iza officea po stvarnom dobu dana (vlasnik 04.11): jutro, dan, veče, noć.
/// Danju oblaci i ptice koji lagano plove, noću zvezde i mesec. Crta se u kodu, bez slika.
struct Nebo: View {
    enum Doba { case jutro, dan, vece, noc
        static func sada(_ d: Date = .now) -> Doba {
            switch Calendar.current.component(.hour, from: d) {
            case 5..<9: .jutro
            case 9..<18: .dan
            case 18..<21: .vece
            default: .noc
            }
        }
        var boje: [Color] {
            switch self {
            case .jutro: [Color(hex: 0xF9C9A8), Color(hex: 0xFCE6C7), Color(hex: 0xBFE3F2)]
            case .dan: [Color(hex: 0x7FC8F0), Color(hex: 0xB9E2F7), Color(hex: 0xE6F5FC)]
            case .vece: [Color(hex: 0x3B2F6B), Color(hex: 0xC8608A), Color(hex: 0xF4A35C)]
            case .noc: [Color(hex: 0x0B1330), Color(hex: 0x1B2A55), Color(hex: 0x2C3D6E)]
            }
        }
    }

    /// Vreme za dan (vlasnik 04.11): vedro, oblačno ili kiša; ptice, avion, zvezde i oblaci preko meseca
    /// dolaze ili ne. Isti dan i isto mesto daju isto vreme; drugi dan ili druga firma, drugačije.
    struct Vreme {
        enum Nebo { case vedro, oblacno, kisa }
        let nebo: Nebo
        let ptice: Bool
        let avion: Bool
        let zvezde: Bool
        let oblaciNocu: Bool

        static func za(_ mesto: String, dan: Date = .now) -> Vreme {
            let d = Calendar.current.dateComponents([.year, .month, .day], from: dan)
            var g = SplitMix(seme: UInt64(bitPattern: Int64((d.year ?? 0) * 10000 + (d.month ?? 0) * 100 + (d.day ?? 0)))
                &+ UInt64(mesto.unicodeScalars.reduce(0) { $0 &* 31 &+ Int($1.value) } & 0xFFFFFF))
            let r = g.sledeci()
            return Vreme(nebo: r < 0.55 ? .vedro : r < 0.85 ? .oblacno : .kisa,
                         ptice: g.sledeci() < 0.6, avion: g.sledeci() < 0.4,
                         zvezde: g.sledeci() < 0.75, oblaciNocu: g.sledeci() < 0.45)
        }
    }

    var doba: Doba = .sada()
    /// Samo za proveru (NeboProba): zadato vreme umesto dnevnog.
    var zadato: Vreme? = nil
    /// Mesto (npr. id firme) od kog zavisi vreme; bez njega vreme je isto za ceo dan.
    var mesto = ""

    var body: some View {
        let v = zadato ?? Vreme.za(mesto)
        TimelineView(.animation(minimumInterval: 1 / 20, paused: false)) { kontekst in
            let t = kontekst.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                if doba == .noc {
                    if v.zvezde && v.nebo != .kisa { zvezde(ctx, size, t) } else { mesec(ctx, size) }
                    if v.oblaciNocu || v.nebo != .vedro { oblaci(ctx, size, t, boja: Color(hex: 0x3A4A7A).opacity(0.85), broj: v.nebo == .vedro ? 2 : 3) }
                } else {
                    if v.nebo != .kisa { sunce(ctx, size) }
                    oblaci(ctx, size, t, boja: v.nebo == .vedro ? nil : Color(hex: 0xC9D2DC).opacity(0.95), broj: v.nebo == .vedro ? 2 : 3)
                    if v.ptice && v.nebo != .kisa && (doba == .jutro || doba == .dan) { ptice(ctx, size, t) }
                }
                if v.avion && v.nebo != .kisa { avion(ctx, size, t) }
                if v.nebo == .kisa { kisa(ctx, size, t) }
            }
        }
        .background(LinearGradient(colors: v.nebo == .vedro || doba == .noc ? doba.boje : doba.boje.map { $0.opacity(0.75) }, startPoint: .top, endPoint: .bottom)
            .background(Color(hex: 0x8C98A6)))
        .accessibilityHidden(true)
    }

    private func mesec(_ ctx: GraphicsContext, _ s: CGSize) {
        let d = min(40, min(s.width, s.height) * 0.16)
        let m = CGRect(x: s.width * 0.78, y: s.height * 0.08, width: d, height: d)
        ctx.fill(Path(ellipseIn: m), with: .color(Color(hex: 0xF4EFD8)))
        ctx.fill(Path(ellipseIn: m.offsetBy(dx: d * 0.28, dy: -d * 0.15)), with: .color(Color(hex: 0x0B1330)))
    }

    private func kisa(_ ctx: GraphicsContext, _ s: CGSize, _ t: Double) {
        var g = SplitMix(seme: 11)
        for _ in 0..<60 {
            let x0 = CGFloat(g.sledeci()) * s.width, brzina = 180 + g.sledeci() * 120, faza = g.sledeci()
            let y = CGFloat((t * brzina + faza * Double(s.height)).truncatingRemainder(dividingBy: Double(s.height)))
            var p = Path(); p.move(to: CGPoint(x: x0, y: y)); p.addLine(to: CGPoint(x: x0 - 3, y: y + 10))
            ctx.stroke(p, with: .color(.white.opacity(0.55)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        }
    }

    private func avion(_ ctx: GraphicsContext, _ s: CGSize, _ t: Double) {
        let put = s.width + 160
        let x = (t * 30).truncatingRemainder(dividingBy: put) - 80
        let y = s.height * 0.12
        var trag = Path(); trag.move(to: CGPoint(x: x - 70, y: y + 1)); trag.addLine(to: CGPoint(x: x - 8, y: y + 1))
        ctx.stroke(trag, with: .color(.white.opacity(doba == .noc ? 0.15 : 0.6)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        var telo = Path()
        telo.addRoundedRect(in: CGRect(x: x - 9, y: y - 1.5, width: 20, height: 4), cornerSize: CGSize(width: 2, height: 2))
        telo.move(to: CGPoint(x: x, y: y)); telo.addLine(to: CGPoint(x: x - 5, y: y - 7)); telo.addLine(to: CGPoint(x: x + 1, y: y))
        telo.move(to: CGPoint(x: x - 7, y: y)); telo.addLine(to: CGPoint(x: x - 10, y: y - 4)); telo.addLine(to: CGPoint(x: x - 8, y: y))
        ctx.fill(telo, with: .color(doba == .noc ? Color(hex: 0xC9D2DC) : Color(hex: 0x4A5A6A)))
        if doba == .noc, Int(t * 2) % 2 == 0 {
            ctx.fill(Path(ellipseIn: CGRect(x: x + 9, y: y - 1, width: 3, height: 3)), with: .color(.red))
        }
    }

    private func sunce(_ ctx: GraphicsContext, _ s: CGSize) {
        let (x, y): (CGFloat, CGFloat) = switch doba {
        case .jutro: (s.width * 0.18, s.height * 0.42)
        case .vece: (s.width * 0.82, s.height * 0.55)
        default: (s.width * 0.8, s.height * 0.16)
        }
        let r: CGFloat = min(26, min(s.width, s.height) * 0.1)
        ctx.fill(Path(ellipseIn: CGRect(x: x - r * 1.8, y: y - r * 1.8, width: r * 3.6, height: r * 3.6)), with: .color(.white.opacity(0.18)))
        ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                 with: .color(doba == .vece ? Color(hex: 0xFFB36B) : Color(hex: 0xFFE27A)))
    }

    private func zvezde(_ ctx: GraphicsContext, _ s: CGSize, _ t: Double) {
        // Stalan raspored (isti seme), treptanje po zvezdi.
        var g = SplitMix(seme: 7)
        for i in 0..<70 {
            let x = CGFloat(g.sledeci()) * s.width, y = CGFloat(g.sledeci()) * s.height * 0.75
            let r = 0.6 + CGFloat(g.sledeci()) * 1.4
            let svetlo = 0.45 + 0.55 * abs(sin(t * 0.8 + Double(i)))
            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)), with: .color(.white.opacity(svetlo)))
        }
        let d = min(40, min(s.width, s.height) * 0.16)
        let m = CGRect(x: s.width * 0.78, y: s.height * 0.08, width: d, height: d)
        ctx.fill(Path(ellipseIn: m), with: .color(Color(hex: 0xF4EFD8)))
        ctx.fill(Path(ellipseIn: m.offsetBy(dx: d * 0.28, dy: -d * 0.15)), with: .color(Color(hex: 0x0B1330)))
    }

    private func oblaci(_ ctx: GraphicsContext, _ s: CGSize, _ t: Double, boja posebna: Color? = nil, broj: Int = 3) {
        let boja: Color = posebna ?? (doba == .vece ? Color(hex: 0xF7C3B5).opacity(0.75) : .white.opacity(0.9))
        for (i, (y, v, brzina)) in [(0.12, 1.0, 9.0), (0.3, 0.75, 6.0), (0.5, 0.6, 4.0), (0.22, 1.2, 5.0)].prefix(broj == 3 && posebna != nil ? 4 : broj).enumerated() {
            let sirina = min(120, s.width * 0.42) * v
            let put = s.width + sirina * 2
            let x = (t * brzina + Double(i) * put / 3).truncatingRemainder(dividingBy: put) - sirina
            oblak(ctx, CGPoint(x: x, y: s.height * y), sirina, boja)
        }
    }

    private func oblak(_ ctx: GraphicsContext, _ p: CGPoint, _ w: CGFloat, _ boja: Color) {
        let h = w * 0.32
        var o = Path()
        o.addRoundedRect(in: CGRect(x: p.x, y: p.y, width: w, height: h), cornerSize: CGSize(width: h / 2, height: h / 2))
        o.addEllipse(in: CGRect(x: p.x + w * 0.18, y: p.y - h * 0.55, width: w * 0.38, height: h * 1.2))
        o.addEllipse(in: CGRect(x: p.x + w * 0.45, y: p.y - h * 0.85, width: w * 0.36, height: h * 1.4))
        ctx.fill(o, with: .color(boja))
    }

    private func ptice(_ ctx: GraphicsContext, _ s: CGSize, _ t: Double) {
        let put = s.width + 120
        for i in 0..<4 {
            let x = (t * 24 + Double(i) * 34).truncatingRemainder(dividingBy: put) - 60
            let y = s.height * 0.22 + CGFloat(i % 2) * 14 + CGFloat(sin(t * 1.5 + Double(i))) * 4
            let mah = CGFloat(sin(t * 9 + Double(i))) * 4
            var p = Path()
            p.move(to: CGPoint(x: x - 7, y: y - mah))
            p.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x - 3, y: y - 4))
            p.addQuadCurve(to: CGPoint(x: x + 7, y: y - mah), control: CGPoint(x: x + 3, y: y - 4))
            ctx.stroke(p, with: .color(Color(hex: 0x2C3D4E)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        }
    }
}

/// Mali generator sa semenom: zvezde stoje na istim mestima između kadrova.
struct SplitMix {
    var stanje: UInt64
    init(seme: UInt64) { stanje = seme }
    mutating func sledeci() -> Double {
        stanje &+= 0x9E3779B97F4A7C15
        var z = stanje
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return Double((z ^ (z >> 31)) >> 11) / Double(1 << 53)
    }
}

#if DEBUG
/// Provera neba (`-nebo`): sva doba dana i vremena na jednom ekranu.
struct NeboProba: View {
    var body: some View {
        let vremena: [Nebo.Vreme] = [
            .init(nebo: .vedro, ptice: true, avion: true, zvezde: true, oblaciNocu: false),
            .init(nebo: .oblacno, ptice: false, avion: false, zvezde: false, oblaciNocu: true),
            .init(nebo: .kisa, ptice: false, avion: false, zvezde: false, oblaciNocu: true),
        ]
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                ForEach(0..<12, id: \.self) { k in
                    let d = [Nebo.Doba.jutro, .dan, .vece, .noc][k / 3], i = k % 3
                    ZStack(alignment: .bottom) {
                        Nebo(doba: d, zadato: vremena[i])
                        Image("Karijera_Zgrada_3_1").resizable().scaledToFit().frame(height: 90)
                    }
                    .frame(height: 170).clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(8)
        }
        .background(Color.black)
    }
}
#endif
