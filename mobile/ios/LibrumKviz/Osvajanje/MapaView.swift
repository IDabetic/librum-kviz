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
    /// Izabrana meta pre potvrde napada: crvena puna ivica.
    var meta: String? = nil
    /// Države iz kojih se može napasti (korak 1 poteza).
    var izvori: [String] = []
    let fokus: String?
    let dodir: (String) -> Void

    @State private var razmera: CGFloat = 1
    @State private var uokvirenKontinent = false
    /// Partija na jednom kontinentu: u stanju su samo njegove države.
    private var naKontinentu: Bool { stanje.oblasti.count < Mapa.oblasti.count }
    @State private var pomak: CGSize = .zero
    @GestureState private var zumPokret: CGFloat = 1
    @GestureState private var prevlacenje: CGSize = .zero

    private static let neutralne: [Color] = [Color(hex: 0xCFEDE6), Color(hex: 0xFFD9E6), Color(hex: 0xFFF0BF), Color(hex: 0xDED5F7), Color(hex: 0xD3ECFA)]
    private static let okean = Color(hex: 0xE3EDF2)
    /// Jak zum da se i male države (Luksemburg, Liban) lepo vide i tapnu.
    static let najveciZum: CGFloat = 20
    private static let morskiPut = Color(hex: 0x4F7486)

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
                // Morski putevi ispod država: isprekidane linije preko mora, kao u Risku.
                for put in Mapa.more {
                    let jak = izabrana.map { (put.a == $0 && mete.contains(put.b)) || (put.b == $0 && mete.contains(put.a)) } ?? false
                    let stil = StrokeStyle(lineWidth: (jak ? 3 : 1.8) / k, lineCap: .round, dash: jak ? [7 / k, 5 / k] : [5 / k, 6 / k])
                    let boja = jak ? Color.mastilo : Self.morskiPut.opacity(0.75)
                    var linija = Path()
                    if abs(put.od.x - put.do.x) > Mapa.sirina / 2 {
                        // Put preko ivice karte (Aljaska–Čukotka): dva kraka ka ivicama.
                        let (levo, desno) = put.od.x < put.do.x ? (put.od, put.do) : (put.do, put.od)
                        linija.move(to: levo); linija.addLine(to: CGPoint(x: 0, y: levo.y - 8))
                        linija.move(to: desno); linija.addLine(to: CGPoint(x: Mapa.sirina, y: desno.y - 8))
                    } else {
                        let kontrola = CGPoint(x: (put.od.x + put.do.x) / 2 - (put.do.y - put.od.y) * 0.12,
                                               y: (put.od.y + put.do.y) / 2 + (put.do.x - put.od.x) * 0.12)
                        linija.move(to: put.od); linija.addQuadCurve(to: put.do, control: kontrola)
                    }
                    mapa.stroke(linija, with: .color(boja), style: stil)
                }
                for o in Mapa.oblasti {
                    guard let put = PutanjeMape.sve[o.id] else { continue }
                    // Igra na jednom kontinentu: ostale države su bleda pozadina, bez znački.
                    guard let st = stanje.oblasti[o.id] else { mapa.fill(put, with: .color(Self.neutralne[o.boja % 5].opacity(0.25))); continue }
                    let boja = stanje.igraci.first { $0.tim == st.vlasnik }.map { Color(hex: $0.boja) } ?? Self.neutralne[o.boja % 5]
                    mapa.fill(put, with: .color(boja))
                    mapa.stroke(put, with: .color(.white), lineWidth: tanko)
                }
                for id in mete {
                    guard let put = PutanjeMape.sve[id] else { continue }
                    mapa.fill(put, with: .color(Color.mastilo.opacity(0.08)))
                    mapa.stroke(put, with: .color(.tinta), style: StrokeStyle(lineWidth: 2 / k, dash: [5 / k, 4 / k]))
                }
                for id in izvori {
                    guard let put = PutanjeMape.sve[id] else { continue }
                    mapa.stroke(put, with: .color(.zuta), style: StrokeStyle(lineWidth: 2.5 / k, lineJoin: .round))
                }
                if let izabrana, let put = PutanjeMape.sve[izabrana] {
                    mapa.stroke(put, with: .color(.zuta), style: StrokeStyle(lineWidth: 5 / k, lineJoin: .round))
                }
                if let meta, let put = PutanjeMape.sve[meta] {
                    mapa.fill(put, with: .color(Color.crvena.opacity(0.35)))
                    mapa.stroke(put, with: .color(.crvena), style: StrokeStyle(lineWidth: 5 / k, lineJoin: .round))
                }
                // Strelica napada: od države iz koje se napada do mete.
                if let izabrana, let meta {
                    let a = Mapa.oblast(izabrana), b = Mapa.oblast(meta)
                    var strela = Path()
                    strela.move(to: CGPoint(x: a.x, y: a.y)); strela.addLine(to: CGPoint(x: b.x, y: b.y))
                    mapa.stroke(strela, with: .color(.crvena), style: StrokeStyle(lineWidth: 3.5 / k, lineCap: .round, dash: [8 / k, 5 / k]))
                }
                // Značke (pločice sa brojem vojski) u tačkama ekrana, iste veličine na svakom zumu.
                // Bez imena država i bez znački praznih polja: ime, vojske i zanimljivost stižu u listu kad se država dodirne.
                // Pločica koja bi prekrila već nacrtanu se preskače (veće države imaju prednost), da ništa ne bude nabacano.
                let prestonice = Set(stanje.igraci.map(\.prestonica))
                var zauzeto: [CGRect] = []
                let redom = Mapa.oblasti.filter { stanje.oblasti[$0.id] != nil }
                    .sorted { ($0.id == izabrana || $0.id == meta ? 1 : 0, $0.povrsina) > ($1.id == izabrana || $1.id == meta ? 1 : 0, $1.povrsina) }
                for o in redom {
                    guard let st = stanje.oblasti[o.id] else { continue }
                    let vlasnik = stanje.igraci.first { $0.tim == st.vlasnik }
                    guard vlasnik != nil || mete.contains(o.id) else { continue }
                    let c = CGPoint(x: pocetak.x + o.x * k, y: pocetak.y + o.y * k)
                    let okvir = CGRect(x: c.x - 11, y: c.y - 9, width: 22, height: 18)
                    guard !zauzeto.contains(where: { $0.insetBy(dx: 2, dy: 2).intersects(okvir) }) else { continue }
                    zauzeto.append(okvir)
                    let plocica = Path(roundedRect: okvir, cornerRadius: 6)
                    ctx.fill(plocica.offsetBy(dx: 0, dy: 1.5), with: .color(.tinta.opacity(0.55)))
                    ctx.fill(plocica, with: .color(vlasnik.map { Color(hex: $0.boja) } ?? .white))
                    ctx.stroke(plocica, with: .color(.tinta), lineWidth: 1.2)
                    ctx.draw(Text("\(st.vojske)").font(.naslov(11)).foregroundStyle(vlasnik == nil ? Color.tinta : .white), at: c)
                    if prestonice.contains(o.id) {
                        ctx.draw(Text(Image(systemName: "crown.fill")).font(.system(size: 9)).foregroundStyle(Color.zuta),
                                 at: CGPoint(x: c.x + 11, y: c.y - 10))
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                SimultaneousGesture(
                    MagnifyGesture().updating($zumPokret) { v, s, _ in s = v.magnification }
                        .onEnded { v in
                            razmera = min(Self.najveciZum, max(1, razmera * v.magnification))
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
            .onChange(of: fokus, initial: true) { _, novi in
                // Prvi kadar partije na kontinentu je ceo kontinent, da se vide sve njegove države.
                // Na kontinentu kadar ostaje ceo kontinent (malo država); mete posebno uokviruje izbor države.
                if naKontinentu {
                    if !uokvirenKontinent || novi != izabrana { uokviri(Array(stanje.oblasti.keys), velicina: g.size, osnova: osnova, tesno: true) }
                    uokvirenKontinent = true
                } else {
                    centriraj(novi, velicina: g.size, osnova: osnova)
                }
            }
            .onChange(of: mete) { _, nove in
                // Izabrana država i sve njene mete staju u kadar, da se vidi kuda se može dalje.
                guard let izabrana, !nove.isEmpty else { return }
                uokviri([izabrana] + nove, velicina: g.size, osnova: osnova)
            }
            .overlay(alignment: .topTrailing) {
                VStack(spacing: 8) {
                    zumDugme("plus.magnifyingglass", "Uvećaj") { razmera = min(Self.najveciZum, razmera * 1.5) }
                    zumDugme("minus.magnifyingglass", "Umanji") { razmera = max(1, razmera / 1.5); if razmera == 1 { pomak = .zero } }
                    if naKontinentu {
                        zumDugme("globe.europe.africa", "Ceo kontinent") { uokviri(Array(stanje.oblasti.keys), velicina: g.size, osnova: osnova, tesno: true) }
                    } else {
                        zumDugme("globe.europe.africa", "Ceo svet") { razmera = 1; pomak = .zero }
                    }
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

    /// `tesno` za ceo kontinent: manje vazduha oko ivica, da države budu krupnije.
    private func uokviri(_ ids: [String], velicina: CGSize, osnova: CGFloat, tesno: Bool = false) {
        let t = ids.map(Mapa.oblast)
        // Ceo kontinent: bez krajnjih 10% država (Rusija, Island), da jezgro bude dovoljno krupno za dodir.
        func opseg(_ v: [Double]) -> (Double, Double) {
            let l = v.sorted()
            let odsek = tesno && l.count >= 10 ? l.count / 10 : 0
            return (l[odsek], l[l.count - 1 - odsek])
        }
        let (x0, x1) = opseg(t.map(\.x))
        let (y0, y1) = opseg(t.map(\.y))
        let (puta, rub): (CGFloat, CGFloat) = tesno ? (1.15, 60) : (1.5, 140)
        let k = min(velicina.width / ((x1 - x0) * puta + rub), velicina.height / ((y1 - y0) * puta + rub))
        withAnimation(.easeInOut(duration: 0.45)) {
            razmera = min(Self.najveciZum, max(1, k / osnova))
            let kk = osnova * razmera
            pomak = ogranici(CGSize(width: (Mapa.sirina / 2 - (x0 + x1) / 2) * kk, height: (Mapa.visina / 2 - (y0 + y1) / 2) * kk), k: kk, velicina: velicina)
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
                .frame(width: 44, height: 44).background(Color.kartica, in: Circle())
                .overlay(Circle().stroke(Color.mastilo, lineWidth: 2))
        }
        .accessibilityLabel(opis)
    }
}
