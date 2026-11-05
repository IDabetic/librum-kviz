import SwiftUI

/// Raspored izometrijskog grada (vlasnik 05.11: „jedna velika mapa koja se širi kako igrači dolaze”).
/// Blok = 2×2 parcele (svaka 2×2 polja) + put širine 1 polja; blokovi se nižu spiralno oko Korporacije u centru.
/// Parcela iz baze (`karijera_firme.parcela`) određuje mesto: Korporacija (3) ceo centralni blok, ostale redom po 4 u bloku.
/// Isti raspored ima i Android (`karijera/IsoGrad.kt`).
enum IsoRaspored {
    static let period = 5          // 4 polja bloka + 1 polje puta
    static let parcelaKorporacije = 3

    /// Blokovi po prstenovima oko centra, u svakom prstenu redom po uglu (isto na obe platforme).
    static func blokovi(_ broj: Int) -> [(Int, Int)] {
        var lista: [(Int, Int)] = [(0, 0)]
        var r = 1
        while lista.count < broj {
            var prsten: [(Int, Int)] = []
            for x in -r...r { for y in -r...r where max(abs(x), abs(y)) == r { prsten.append((x, y)) } }
            prsten.sort { atan2(Double($0.1), Double($0.0)) < atan2(Double($1.1), Double($1.0)) }
            lista += prsten
            r += 1
        }
        return Array(lista.prefix(broj))
    }

    /// Redni broj firme posle Korporacije (praznine od zatvorenih firmi ostaju kao parkovi).
    static func redni(_ parcela: Int) -> Int { parcela < parcelaKorporacije ? parcela : parcela - 1 }

    /// Polje (gornji levi ugao parcele) u svetu: blok × 5 + mesto u bloku × 2.
    static func polje(parcela: Int, blokovi: [(Int, Int)]) -> (Int, Int)? {
        guard parcela != parcelaKorporacije else { return nil }
        let k = redni(parcela), b = 1 + k / 4, s = k % 4
        guard b < blokovi.count else { return nil }
        return (blokovi[b].0 * period + (s % 2) * 2, blokovi[b].1 * period + (s / 2) * 2)
    }

    static func brojBlokova(najvecaParcela: Int) -> Int { 1 + redni(max(najvecaParcela, 0)) / 4 + 1 }
}

/// Izometrijska mapa grada nacrtana u kodu po vlasnikovim primerima (bele kutije, plavi prozori, ravni krovovi,
/// okruglo drveće, tamni putevi): zgrada po nivou firme, boja po stilu, kolica i pešaci, balončići, zelenilo oko grada.
struct IsoGrad: View {
    let firme: [Karijera.GradFirma]
    var moje: Set<String> = []
    var posao: String? = nil
    var oznacena: String? = nil
    /// Spolja traženo centriranje (pretraga): parcela.
    @Binding var centriraj: Int?
    let otvori: (Karijera.GradFirma) -> Void

    @State private var pomak: CGSize = .zero
    @State private var zum: CGFloat = 0.8
    @GestureState private var vuce: CGSize = .zero
    @GestureState private var stiska: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var mirno

    static let tw: CGFloat = 64, th: CGFloat = 32

    static func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: (x - y) * tw / 2, y: (x + y) * th / 2) }

    struct Zgrada { let f: Karijera.GradFirma; let x0, y0, x1, y1: CGFloat; let visina: CGFloat }

    /// Prsten poslednjeg bloka sa firmom; grad crta još jedan prsten parkova oko njega (mesto za nove igrače).
    private var prsten: Int {
        let n = IsoRaspored.brojBlokova(najvecaParcela: firme.map(\.parcela).max() ?? 0)
        return (IsoRaspored.blokovi(n).map { max(abs($0.0), abs($0.1)) }.max() ?? 0) + 1
    }

    /// Svi blokovi do tog prstena (puni kvadrat), istim spiralnim redom kao parcele.
    private var blokovi: [(Int, Int)] { IsoRaspored.blokovi((2 * prsten + 1) * (2 * prsten + 1)) }

    /// Granice grada u poljima: putevi idu tačno do ivice, posle je trava.
    private var granice: (CGFloat, CGFloat) { (CGFloat(-prsten * IsoRaspored.period - 1), CGFloat(prsten * IsoRaspored.period + IsoRaspored.period)) }

    private var zgrade: [Zgrada] {
        let b = blokovi
        var z: [Zgrada] = []
        for f in firme {
            if f.korporacija {
                z.append(Zgrada(f: f, x0: 0.7, y0: 0.7, x1: 3.3, y1: 3.3, visina: 230))
            } else if let (x, y) = IsoRaspored.polje(parcela: f.parcela, blokovi: b) {
                let m: CGFloat = f.nivo <= 1 ? 0.45 : 0.25
                z.append(Zgrada(f: f, x0: CGFloat(x) + m, y0: CGFloat(y) + m, x1: CGFloat(x) + 2 - m, y1: CGFloat(y) + 2 - m,
                                visina: [0, 16, 32, 58, 96, 150][min(max(f.nivo, 1), 5)]))
            }
        }
        // Crta se od zadnjih ka prednjim (veći x + y je bliže gledaocu).
        return z.sorted { ($0.x1 + $0.y1) < ($1.x1 + $1.y1) }
    }

    var body: some View {
        GeometryReader { g in
            let sve = zgrade
            TimelineView(.animation(minimumInterval: 1 / 30, paused: mirno)) { k in
                Canvas { ctx, size in
                    let t = k.date.timeIntervalSinceReferenceDate
                    let z = zum * stiska
                    let centar = CGPoint(x: size.width / 2 + pomak.width + vuce.width, y: size.height / 2 + pomak.height + vuce.height)
                    nacrtaj(ctx, size: size, centar: centar, z: z, t: t, sve: sve)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4)
                    .updating($vuce) { v, s, _ in s = v.translation }
                    .onEnded { v in pomak = ogranici(CGSize(width: pomak.width + v.translation.width, height: pomak.height + v.translation.height)) }
                    .simultaneously(with: MagnifyGesture()
                        .updating($stiska) { v, s, _ in s = v.magnification }
                        .onEnded { v in zum = min(2.2, max(0.25, zum * v.magnification)); pomak = ogranici(pomak) })
            )
            .simultaneousGesture(SpatialTapGesture().onEnded { v in
                if let f = pogodak(v.location, size: g.size, sve: sve) { otvori(f) }
            })
            .onChange(of: centriraj) { _, parcela in
                guard let parcela, let c = sve.first(where: { $0.f.parcela == parcela }) else { return }
                let s = Self.p((c.x0 + c.x1) / 2, (c.y0 + c.y1) / 2)
                withAnimation(.easeInOut(duration: 0.5)) { zum = 1.1; pomak = CGSize(width: -s.x * 1.1, height: -(s.y - c.visina / 2) * 1.1) }
                centriraj = nil
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Grad Karijere, \(firme.count) firmi. Pretraga iznad mape vodi do firme.")
        }
    }

    // MARK: Pomeranje i dodir

    /// Ne pušta pomeranje van grada: centar ekrana ostaje u granicama grada.
    private func ogranici(_ s: CGSize) -> CGSize {
        let r = CGFloat(prsten * IsoRaspored.period + 3) * Self.tw / 2 * zum
        return CGSize(width: min(r, max(-r, s.width)), height: min(r * 0.55, max(-r * 0.55, s.height)))
    }

    private func pogodak(_ tacka: CGPoint, size: CGSize, sve: [Zgrada]) -> Karijera.GradFirma? {
        let centar = CGPoint(x: size.width / 2 + pomak.width, y: size.height / 2 + pomak.height)
        let w = CGPoint(x: (tacka.x - centar.x) / zum, y: (tacka.y - centar.y) / zum)
        for z in sve.reversed() where obris(z).contains(w) { return z.f }
        return nil
    }

    private func obris(_ z: Zgrada) -> Path {
        let a = Self.p(z.x0, z.y0), b = Self.p(z.x1, z.y0), c = Self.p(z.x1, z.y1), d = Self.p(z.x0, z.y1)
        var p = Path()
        p.move(to: CGPoint(x: a.x, y: a.y - z.visina)); p.addLine(to: CGPoint(x: b.x, y: b.y - z.visina)); p.addLine(to: b)
        p.addLine(to: c); p.addLine(to: d); p.addLine(to: CGPoint(x: d.x, y: d.y - z.visina)); p.closeSubpath()
        return p
    }

    // MARK: Crtanje

    private func poligon(_ tacke: [CGPoint]) -> Path { var p = Path(); p.addLines(tacke); p.closeSubpath(); return p }

    private func nacrtaj(_ ctx: GraphicsContext, size: CGSize, centar: CGPoint, z: CGFloat, t: Double, sve: [Zgrada]) {
        // Zelenilo svuda (i van grada), da nigde ne bude prazno.
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0x8CC56A)))
        var c = ctx
        c.translateBy(x: centar.x, y: centar.y)
        c.scaleBy(x: z, y: z)
        let vidljivo = CGRect(x: -centar.x / z, y: -centar.y / z, width: size.width / z, height: size.height / z).insetBy(dx: -120, dy: -260)
        let (min0, max0) = granice
        travaVanGrada(c, vidljivo: vidljivo, min0: min0, max0: max0)
        // Tlo grada (trotoari i trgovi).
        c.fill(poligon([Self.p(min0, min0), Self.p(max0, min0), Self.p(max0, max0), Self.p(min0, max0)]), with: .color(Color(hex: 0xE6E9EC)))
        putevi(c, min0: min0, max0: max0, t: t)
        blokoviTlo(c, vidljivo: vidljivo)
        // Zgrade, kola i pešaci u jednom redosledu od zadnjih ka prednjim (x + y), da kola ne idu preko krovova.
        var red: [(CGFloat, (GraphicsContext) -> Void)] = sve.compactMap { zg in
            guard vidljivo.contains(Self.p(zg.x1, zg.y1)) || vidljivo.contains(Self.p(zg.x0, zg.y0)) else { return nil }
            return (zg.x1 + zg.y1, { zgrada($0, zg, z: z) })
        }
        red += saobracaj(min0: min0, max0: max0, t: t, vidljivo: vidljivo)
        for (_, crtaj) in red.sorted(by: { $0.0 < $1.0 }) { crtaj(c) }
        for zg in sve where zg.f.balon != nil && z > 0.32 { balon(c, zg, t: t, z: z) }
        if z >= 0.85 { for zg in sve { ime(c, zg, z: z) } }
    }

    private func slucaj(_ a: Int, _ b: Int) -> Double { let x = sin(Double(a) * 12.9898 + Double(b) * 78.233) * 43758.5453; return x - x.rounded(.down) }

    private func drvo(_ c: GraphicsContext, _ x: CGFloat, _ y: CGFloat, velicina s: CGFloat = 1) {
        let o = Self.p(x, y)
        c.fill(Path(ellipseIn: CGRect(x: o.x - 7 * s, y: o.y - 3 * s, width: 14 * s, height: 6 * s)), with: .color(.black.opacity(0.1)))
        var stablo = Path(); stablo.move(to: o); stablo.addLine(to: CGPoint(x: o.x, y: o.y - 10 * s))
        c.stroke(stablo, with: .color(Color(hex: 0x8A5A3B)), lineWidth: 2.2 * s)
        c.fill(Path(ellipseIn: CGRect(x: o.x - 8 * s, y: o.y - 24 * s, width: 16 * s, height: 16 * s)), with: .color(Color(hex: 0x3FA34D)))
        c.fill(Path(ellipseIn: CGRect(x: o.x - 5 * s, y: o.y - 22 * s, width: 7 * s, height: 6 * s)), with: .color(Color(hex: 0x6CC36F)))
    }

    private func travaVanGrada(_ c: GraphicsContext, vidljivo: CGRect, min0: CGFloat, max0: CGFloat) {
        // Retko drveće po travi oko grada, na istim mestima pri svakom crtanju.
        let korak = 3
        let od = Int(min0) - 24, doo = Int(max0) + 24
        for x in stride(from: od, through: doo, by: korak) {
            for y in stride(from: od, through: doo, by: korak) {
                let fx = CGFloat(x), fy = CGFloat(y)
                if fx > min0 - 1 && fx < max0 + 1 && fy > min0 - 1 && fy < max0 + 1 { continue }
                guard slucaj(x, y) > 0.55 else { continue }
                let o = Self.p(fx, fy)
                guard vidljivo.contains(o) else { continue }
                drvo(c, fx + CGFloat(slucaj(y, x)), fy, velicina: 1.1)
            }
        }
    }

    private func putevi(_ c: GraphicsContext, min0: CGFloat, max0: CGFloat, t: Double) {
        let asfalt = Color(hex: 0x41474E)
        for k in (-prsten - 1)...prsten {
            let a = CGFloat(k * IsoRaspored.period + 4)
            // put duž x (konstantno y = a..a+1) i duž y (konstantno x)
            c.fill(poligon([Self.p(min0, a), Self.p(max0, a), Self.p(max0, a + 1), Self.p(min0, a + 1)]), with: .color(asfalt))
            c.fill(poligon([Self.p(a, min0), Self.p(a + 1, min0), Self.p(a + 1, max0), Self.p(a, max0)]), with: .color(asfalt))
            var crta = Path(), crta2 = Path()
            var s = min0
            while s < max0 {
                crta.move(to: Self.p(s, a + 0.5)); crta.addLine(to: Self.p(s + 0.4, a + 0.5))
                crta2.move(to: Self.p(a + 0.5, s)); crta2.addLine(to: Self.p(a + 0.5, s + 0.4))
                s += 1
            }
            c.stroke(crta, with: .color(.white.opacity(0.85)), lineWidth: 1.2)
            c.stroke(crta2, with: .color(.white.opacity(0.85)), lineWidth: 1.2)
        }
    }

    private func blokoviTlo(_ c: GraphicsContext, vidljivo: CGRect) {
        let zauzete = Set(firme.map(\.parcela))
        let n = IsoRaspored.brojBlokova(najvecaParcela: firme.map(\.parcela).max() ?? 0)
        let b = blokovi
        for (i, blok) in b.enumerated() {
            let x = CGFloat(blok.0 * IsoRaspored.period), y = CGFloat(blok.1 * IsoRaspored.period)
            guard vidljivo.contains(Self.p(x + 2, y + 2)) else { continue }
            c.fill(poligon([Self.p(x + 0.15, y + 0.15), Self.p(x + 3.85, y + 0.15), Self.p(x + 3.85, y + 3.85), Self.p(x + 0.15, y + 3.85)]),
                   with: .color(Color(hex: i == 0 ? 0xF1F2F4 : 0xF6F7F8)))
            if i == 0 { continue }
            // Prazne parcele (još neprodate ili zatvorene firme) su travnjak sa drvećem.
            for s in 0..<4 {
                let parcela = (i - 1) * 4 + s
                let prava = parcela >= IsoRaspored.parcelaKorporacije ? parcela + 1 : parcela
                guard !zauzete.contains(prava) else { continue }
                let px = x + CGFloat(s % 2) * 2, py = y + CGFloat(s / 2) * 2
                c.fill(poligon([Self.p(px + 0.25, py + 0.25), Self.p(px + 1.75, py + 0.25), Self.p(px + 1.75, py + 1.75), Self.p(px + 0.25, py + 1.75)]),
                       with: .color(Color(hex: i < n ? 0x9BD17A : 0xA8D88A)))
                drvo(c, px + 0.7, py + 0.8); drvo(c, px + 1.3, py + 1.3, velicina: 0.85)
            }
            drvo(c, x + 0.15, y + 3.85, velicina: 0.7); drvo(c, x + 3.85, y + 3.85, velicina: 0.7)
        }
    }

    private struct Boje { let leva, desna, krov, prozor: Color }
    private func boje(_ f: Karijera.GradFirma) -> Boje {
        if f.korporacija { return Boje(leva: Color(hex: 0x5F8FBF), desna: Color(hex: 0x3F6E9C), krov: Color(hex: 0xEEF1F4), prozor: Color(hex: 0xBFE0F5)) }
        switch f.stil {
        case 2: return Boje(leva: Color(hex: 0xC8674E), desna: Color(hex: 0xA4513D), krov: Color(hex: 0xE7E1D8), prozor: Color(hex: 0xBFDCF0))
        case 3: return Boje(leva: Color(hex: 0xFAFAFA), desna: Color(hex: 0xD9DDE2), krov: .white, prozor: Color(hex: 0x7FAED6))
        case 4: return Boje(leva: Color(hex: 0x8FD3C7), desna: Color(hex: 0x6DB3A7), krov: .white, prozor: Color(hex: 0x2F6F8A))
        case 5: return Boje(leva: Color(hex: 0xF4A33C), desna: Color(hex: 0xD0832A), krov: Color(hex: 0xEDE7DD), prozor: Color(hex: 0x4F7EA8))
        case 6: return Boje(leva: Color(hex: 0x9AA3AD), desna: Color(hex: 0x7B848E), krov: Color(hex: 0xD8DCE0), prozor: Color(hex: 0x24395E))
        case 7: return Boje(leva: Color(hex: 0xEAF3E6), desna: Color(hex: 0xC9D6C3), krov: Color(hex: 0x8CC56A), prozor: Color(hex: 0x6E9FCF))
        case 8: return Boje(leva: Color(hex: 0x34495E), desna: Color(hex: 0x22313F), krov: Color(hex: 0xF2C14E), prozor: Color(hex: 0xF7D774))
        default: return Boje(leva: Color(hex: 0xF2F4F7), desna: Color(hex: 0xD3D9E1), krov: .white, prozor: Color(hex: 0x6E9FCF))
        }
    }

    private func zgrada(_ c: GraphicsContext, _ zg: Zgrada, z: CGFloat) {
        let b = boje(zg.f), H = zg.visina
        let a = Self.p(zg.x0, zg.y0), bb = Self.p(zg.x1, zg.y0), cc = Self.p(zg.x1, zg.y1), d = Self.p(zg.x0, zg.y1)
        func gore(_ q: CGPoint, _ h: CGFloat) -> CGPoint { CGPoint(x: q.x, y: q.y - h) }
        // senka na tlu
        c.fill(poligon([cc, bb, CGPoint(x: bb.x + H * 0.35, y: bb.y + H * 0.1), CGPoint(x: cc.x + H * 0.35, y: cc.y + H * 0.1)]), with: .color(.black.opacity(0.08)))
        c.fill(poligon([d, cc, gore(cc, H), gore(d, H)]), with: .color(b.leva))
        c.fill(poligon([cc, bb, gore(bb, H), gore(cc, H)]), with: .color(b.desna))
        // prozori: spratovi po visini, kolone po dužini zida
        if z > 0.45 {
            let sprat: CGFloat = zg.f.korporacija ? 12 : 11
            let spratova = max(1, Int(H / sprat) - (H > 20 ? 1 : 0))
            for (p0, p1, boja) in [(d, cc, b.prozor), (cc, bb, b.prozor.opacity(0.8))] {
                let duzina = hypot(p1.x - p0.x, p1.y - p0.y)
                let kolona = max(1, Int(duzina / 9))
                var put = Path()
                for s in 0..<spratova {
                    let v0 = CGFloat(s) * sprat + sprat * 0.75, v1 = v0 + sprat * 0.45
                    for k in 0..<kolona {
                        let u0 = (CGFloat(k) + 0.25) / CGFloat(kolona), u1 = (CGFloat(k) + 0.75) / CGFloat(kolona)
                        let q0 = CGPoint(x: p0.x + (p1.x - p0.x) * u0, y: p0.y + (p1.y - p0.y) * u0)
                        let q1 = CGPoint(x: p0.x + (p1.x - p0.x) * u1, y: p0.y + (p1.y - p0.y) * u1)
                        put.addLines([gore(q0, v0), gore(q1, v0), gore(q1, v1), gore(q0, v1)]); put.closeSubpath()
                    }
                }
                c.fill(put, with: .color(boja))
            }
        }
        // krov sa ivicom i ventilacijom
        c.fill(poligon([gore(a, H), gore(bb, H), gore(cc, H), gore(d, H)]), with: .color(b.krov))
        c.stroke(poligon([gore(a, H), gore(bb, H), gore(cc, H), gore(d, H)]), with: .color(.black.opacity(0.08)), lineWidth: 0.8)
        if zg.f.nivo >= 2 || zg.f.korporacija {
            let sx = (zg.x0 + zg.x1) / 2, sy = (zg.y0 + zg.y1) / 2
            for (dx, dy) in [(-0.25, -0.1), (0.2, 0.15)] {
                let o = gore(Self.p(sx + dx, sy + dy), H)
                c.fill(Path(ellipseIn: CGRect(x: o.x - 4, y: o.y - 2, width: 8, height: 4)), with: .color(Color(hex: 0xC9CED4)))
            }
        }
        if zg.f.stil == 8 && !zg.f.korporacija {
            let o = gore(Self.p((zg.x0 + zg.x1) / 2, (zg.y0 + zg.y1) / 2), H)
            c.fill(poligon([CGPoint(x: o.x - 6, y: o.y), CGPoint(x: o.x - 6, y: o.y - 7), CGPoint(x: o.x - 2, y: o.y - 3), CGPoint(x: o.x, y: o.y - 9),
                            CGPoint(x: o.x + 2, y: o.y - 3), CGPoint(x: o.x + 6, y: o.y - 7), CGPoint(x: o.x + 6, y: o.y)]), with: .color(Color(hex: 0xF2C14E)))
        }
        if moje.contains(zg.f.id) || posao == zg.f.id || oznacena == zg.f.id {
            c.stroke(poligon([gore(a, H), gore(bb, H), gore(cc, H), gore(d, H)]), with: .color(Color(hex: 0xFFD84D)), lineWidth: 3)
        }
    }

    private func saobracaj(min0: CGFloat, max0: CGFloat, t: Double, vidljivo: CGRect) -> [(CGFloat, (GraphicsContext) -> Void)] {
        var stavke: [(CGFloat, (GraphicsContext) -> Void)] = []
        let boje: [UInt32] = [0xE5385C, 0x6EC3F2, 0xF7C531, 0xFFFFFF, 0x12907E, 0xF4A33C]
        let duzina = max0 - min0
        for k in (-prsten - 1)...prsten {
            let a = CGFloat(k * IsoRaspored.period + 4)
            for i in 0..<2 {
                let brzina = 0.6 + slucaj(k, i) * 0.6
                let napred = i == 0
                var s = CGFloat((t * brzina + slucaj(i, k) * 50).truncatingRemainder(dividingBy: Double(duzina)))
                if !napred { s = duzina - s }
                for duzX in [true, false] {
                    let traka: CGFloat = napred ? 0.3 : 0.7
                    let (x, y) = duzX ? (min0 + s, a + traka) : (a + traka, min0 + s)
                    let o = Self.p(x, y)
                    guard vidljivo.contains(o) else { continue }
                    let boja = Color(hex: boje[(((k + i + (duzX ? 0 : 3)) % boje.count) + boje.count) % boje.count])
                    stavke.append((x + y, { auto($0, x: x, y: y, duzX: duzX, boja: boja) }))
                }
            }
            // Pešaci: tačkice duž trotoara bloka.
            for i in 0..<2 {
                let s = CGFloat((t * 0.25 + slucaj(k, i + 7) * 30).truncatingRemainder(dividingBy: Double(duzina)))
                let x = min0 + s, y = a - 0.12 - CGFloat(i) * 0.05
                let o = Self.p(x, y)
                guard vidljivo.contains(o) else { continue }
                let odeca = Color(hex: [0x2F4A7A, 0xE5674F, 0x6D4BC9][(((k + i) % 3) + 3) % 3])
                stavke.append((x + y, { c in
                    c.fill(Path(roundedRect: CGRect(x: o.x - 1.4, y: o.y - 6, width: 2.8, height: 6), cornerRadius: 1.2), with: .color(odeca))
                    c.fill(Path(ellipseIn: CGRect(x: o.x - 1.5, y: o.y - 8.6, width: 3, height: 3)), with: .color(Color(hex: 0xF2C9A0)))
                }))
            }
        }
        return stavke
    }

    private func auto(_ c: GraphicsContext, x: CGFloat, y: CGFloat, duzX: Bool, boja: Color) {
        let (dx, dy): (CGFloat, CGFloat) = duzX ? (0.32, 0.14) : (0.14, 0.32)
        let a = Self.p(x - dx, y - dy), b = Self.p(x + dx, y - dy), cc = Self.p(x + dx, y + dy), d = Self.p(x - dx, y + dy)
        let h: CGFloat = 5
        func g(_ q: CGPoint) -> CGPoint { CGPoint(x: q.x, y: q.y - h) }
        c.fill(poligon([d, cc, g(cc), g(d)]), with: .color(boja.opacity(0.85)))
        c.fill(poligon([cc, b, g(b), g(cc)]), with: .color(boja.opacity(0.65)))
        c.fill(poligon([g(a), g(b), g(cc), g(d)]), with: .color(boja))
        let s = Self.p(x, y)
        c.fill(Path(ellipseIn: CGRect(x: s.x - 3, y: s.y - h - 2.5, width: 6, height: 3)), with: .color(Color(hex: 0xBFE6F5)))
    }

    private func balon(_ c: GraphicsContext, _ zg: Zgrada, t: Double, z: CGFloat) {
        guard let tekst = zg.f.balon else { return }
        let kasni = Double(zg.f.parcela % 7) * 1.3
        let ciklus = ((t + kasni) / 9).truncatingRemainder(dividingBy: 1)
        let p = mirno ? 0.5 : min(1, ciklus / 0.45)
        let alfa = mirno ? 1 : (p < 0.15 ? p / 0.15 : p > 0.75 ? (1 - p) / 0.25 : 1)
        guard alfa > 0.02 else { return }
        let vrh = Self.p((zg.x0 + zg.x1) / 2, (zg.y0 + zg.y1) / 2)
        let y = vrh.y - zg.visina - 14 - CGFloat(p) * 18
        let s = 1 / max(z, 0.5)
        let natpis = c.resolve(Text(tekst).font(.tekst(11 * s, .bold)).foregroundColor(tekst.hasPrefix("Napad") ? Color(hex: 0xE5385C) : Color(hex: 0x1F2A36)))
        let vel = natpis.measure(in: CGSize(width: 400, height: 100))
        var cc = c
        cc.opacity = alfa
        let okvir = CGRect(x: vrh.x - vel.width / 2 - 7 * s, y: y - vel.height / 2 - 4 * s, width: vel.width + 14 * s, height: vel.height + 8 * s)
        cc.fill(Path(roundedRect: okvir, cornerRadius: 8 * s), with: .color(.white))
        cc.draw(natpis, at: CGPoint(x: vrh.x, y: y))
    }

    private func ime(_ c: GraphicsContext, _ zg: Zgrada, z: CGFloat) {
        let dno = Self.p(zg.x1, zg.y1)
        let natpis = c.resolve(Text(zg.f.ime).font(.tekst(9 / z * 0.9, .bold)).foregroundColor(Color(hex: 0x1F2A36)))
        let vel = natpis.measure(in: CGSize(width: 300, height: 60))
        let okvir = CGRect(x: dno.x - vel.width / 2 - 4, y: dno.y + 3, width: vel.width + 8, height: vel.height + 3)
        c.fill(Path(roundedRect: okvir, cornerRadius: 4), with: .color(.white.opacity(0.85)))
        c.draw(natpis, at: CGPoint(x: dno.x, y: okvir.midY))
    }
}
