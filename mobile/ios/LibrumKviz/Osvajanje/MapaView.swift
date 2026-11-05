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
    /// Kamera ide sama samo na bitku; igračev dodir (izbor, marš, raspored) ne pomera mapu (vlasnik 03.11).
    let fokus: String?
    /// Prvi kadar partije (prestonica), jednom.
    var prviKadar: String? = nil
    /// Kratke animacije posle bitke: strela i udar, brojke vojski koje iskaču, region koji zasvetli.
    var efekti = Efekti()
    /// Magla rata: države čiji se tačan broj vojski ne vidi (prikazuje se procena).
    var magla: Set<String> = []
    /// Moje države odsečene od prestonice (bez pojačanja, gube vojsku).
    var odsecene: Set<String> = []
    /// Ekran partije: mapa od ivice do ivice, bez zaobljenog okvira (vlasnik 03.11).
    var bezOkvira = false
    /// Raste kad počne moj potez: kamera se vraća na moje države (vlasnik 04.11: ostajala je gde je bot igrao).
    var mojPotez = 0
    var moje: [String] = []
    let dodir: (String) -> Void

    struct Efekti: Equatable {
        static let trajanjeIskoka: TimeInterval = 1.6
        /// Udar: strela, pa boja osvajača se razlije po državi uz oblačić prašine.
        static let trajanjeUdara: TimeInterval = 1.6
        /// Pojačanje leti iz prestonice do države pre nego što „+N” iskoči.
        static let letPojacanja: TimeInterval = 0.55
        var udar: OsvajanjeModel.Udar?
        var iskoci: [OsvajanjeModel.Iskok] = []
        var zatvoreni: [OsvajanjeModel.ZatvorenRegion] = []
        /// Ima li nečeg živog (do 2 s posle događaja), da TimelineView ne crta stalno.
        func aktivno(_ sad: Date) -> Bool {
            (udar.map { sad.timeIntervalSince($0.kad) < Self.trajanjeUdara } ?? false) || iskoci.contains { sad.timeIntervalSince($0.kad) < Self.trajanjeIskoka }
                || zatvoreni.contains { sad.timeIntervalSince($0.kad) < 2 }
        }
    }

    @Environment(\.accessibilityReduceMotion) private var manjeKretanja
    @State private var razmera: CGFloat = 1
    @State private var uokvirenKontinent = false
    @State private var pocetakCentriran = false
    /// Partija na jednom kontinentu: u stanju su samo njegove države.
    private var naKontinentu: Bool { stanje.oblasti.count < Mapa.oblasti.count }
    @State private var pomak: CGSize = .zero
    /// Štipanje: faktor i tačka između prstiju (od sredine ekrana), da zum ide oko prstiju, ne oko sredine mape.
    @GestureState private var zumPokret = Stipanje()
    @GestureState private var prevlacenje: CGSize = .zero
    /// Dok traje štipanje, prvi prst ne sme da vuče mapu (DragGesture prati samo njega, pa je pogled bežao u stranu).
    @State private var biloStipanje = false
    @State private var vucenjeTraje = false
    struct Stipanje { var f: CGFloat = 1; var c: CGSize = .zero }

    private static let neutralne: [Color] = [Color(hex: 0xCFEDE6), Color(hex: 0xFFD9E6), Color(hex: 0xFFF0BF), Color(hex: 0xDED5F7), Color(hex: 0xD3ECFA)]
    private static let okean = Color(hex: 0xE3EDF2)
    /// Jak zum da se i male države (Luksemburg, Liban) lepo vide i tapnu.
    static let najveciZum: CGFloat = 20
    private static let morskiPut = Color(hex: 0x3D6476)
    /// Države manje od ovoga (u jedinicama mape) dobijaju krug, jer se inače ne vide (Vanuatu, Fidži, Trinidad, Kipar…).
    private static let malaDrzava: Double = 70
    /// Morske veze duže od ovoga (jedinice mape) dobijaju natpis sa imenom druge obale.
    private static let dugaVeza: Double = 100
    /// Kad je mapa jako uvećana, natpisi veza bi pokrivali države.
    private static let zumBezNatpisaVeza: CGFloat = 4

    var body: some View {
        GeometryReader { g in
            let osnova = min(g.size.width / Mapa.sirina, g.size.height / Mapa.visina)
            let f = min(Self.najveciZum, max(1, razmera * zumPokret.f)) / razmera
            let k = osnova * razmera * f
            let vuce = biloStipanje ? .zero : prevlacenje
            let pomakSad = ogranici(CGSize(width: (pomak.width - zumPokret.c.width) * f + zumPokret.c.width + vuce.width,
                                           height: (pomak.height - zumPokret.c.height) * f + zumPokret.c.height + vuce.height), k: k, velicina: g.size)
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
                    // Vlasnik 04.11: morske veze se nisu primećivale; sada su deblje i tamnije, duge imaju natpis na krajevima.
                    let stil = StrokeStyle(lineWidth: (jak ? 3.4 : 2.4) / k, lineCap: .round, dash: jak ? [7 / k, 5 / k] : [6 / k, 5 / k])
                    let boja = jak ? Color.mastilo : Self.morskiPut
                    var linija = Path()
                    if abs(put.od.x - put.do.x) > Mapa.sirina / 2 {
                        // Put preko ivice karte (Aljaska–Čukotka): dva kraka ka ivicama.
                        let (levo, desno) = put.od.x < put.do.x ? (put.od, put.do) : (put.do, put.od)
                        linija.move(to: levo); linija.addLine(to: CGPoint(x: 0, y: levo.y - 8))
                        linija.move(to: desno); linija.addLine(to: CGPoint(x: Mapa.sirina, y: desno.y - 8))
                    } else {
                        let sx: CGFloat = (put.od.x + put.do.x) / 2, sy: CGFloat = (put.od.y + put.do.y) / 2
                        let dx: CGFloat = put.do.x - put.od.x, dy: CGFloat = put.do.y - put.od.y
                        let kontrola = CGPoint(x: sx - dy * 0.12, y: sy + dx * 0.12)
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
                for id in odsecene {
                    guard let put = PutanjeMape.sve[id] else { continue }
                    mapa.stroke(put, with: .color(.crvena), style: StrokeStyle(lineWidth: 2 / k, dash: [3 / k, 3 / k]))
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
                // Sitna ostrva i male države: krug u boji vlasnika oko države, da se vide i na celom svetu (vlasnik 04.11).
                for o in Mapa.oblasti where o.povrsina < Self.malaDrzava {
                    guard let st = stanje.oblasti[o.id] else { continue }
                    let boja = stanje.igraci.first { $0.tim == st.vlasnik }.map { Color(hex: $0.boja) } ?? Self.neutralne[o.boja % 5]
                    let c = CGPoint(x: pocetak.x + o.x * k, y: pocetak.y + o.y * k)
                    let r = max(9, sqrt(o.povrsina) * k * 0.9)
                    let krug = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
                    ctx.fill(krug, with: .color(boja.opacity(0.55)))
                    ctx.stroke(krug, with: .color(Self.morskiPut), style: StrokeStyle(lineWidth: 1.6, dash: [3, 2.5]))
                }
                // Natpisi na krajevima dugih morskih veza: sa kojom državom je ova obala povezana.
                if k < Self.zumBezNatpisaVeza {
                    func natpis(_ tekst: String, _ t: CGPoint, sidro: UnitPoint) {
                        let r = Text(tekst).font(.tekst(9, .heavy)).foregroundStyle(Color.white)
                        let p = CGPoint(x: pocetak.x + t.x * k, y: pocetak.y + t.y * k)
                        let sir = CGFloat(tekst.count) * 5.6 + 10
                        let okvir = CGRect(x: p.x - sir * sidro.x, y: p.y - 9 - 9 * (sidro.y - 0.5) * 2, width: sir, height: 16)
                        ctx.fill(Path(roundedRect: okvir, cornerRadius: 5), with: .color(Self.morskiPut))
                        ctx.draw(r, at: CGPoint(x: okvir.midX, y: okvir.midY))
                    }
                    for put in Mapa.more where hypot(put.od.x - put.do.x, put.od.y - put.do.y) > Self.dugaVeza {
                        let ime = { (id: String) in Mapa.oblast(id).ime }
                        if abs(put.od.x - put.do.x) > Mapa.sirina / 2 {
                            // Preko ivice karte: kod Aljaske piše Rusija, kod Čukotke SAD (Aljaska).
                            let (levo, desno, l, d) = put.od.x < put.do.x ? (put.od, put.do, put.a, put.b) : (put.do, put.od, put.b, put.a)
                            natpis("← \(ime(d))", CGPoint(x: max(levo.x - 10, 34), y: levo.y + 14), sidro: .leading)
                            natpis("\(ime(l)) →", CGPoint(x: min(desno.x + 10, Mapa.sirina - 34), y: desno.y + 14), sidro: .trailing)
                        } else {
                            natpis("→ \(ime(put.b))", CGPoint(x: put.od.x + (put.do.x - put.od.x) * 0.25, y: put.od.y + (put.do.y - put.od.y) * 0.25), sidro: .center)
                            natpis("→ \(ime(put.a))", CGPoint(x: put.do.x + (put.od.x - put.do.x) * 0.25, y: put.do.y + (put.od.y - put.do.y) * 0.25), sidro: .center)
                        }
                    }
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
                    let cudo = Cudo.za(o.id)
                    guard vlasnik != nil || mete.contains(o.id) || cudo != nil else { continue }
                    let c = CGPoint(x: pocetak.x + o.x * k, y: pocetak.y + o.y * k)
                    let skriveno = magla.contains(o.id)
                    let sirina: CGFloat = skriveno ? 30 : 22
                    let okvir = CGRect(x: c.x - sirina / 2, y: c.y - 9, width: sirina, height: 18)
                    guard !zauzeto.contains(where: { $0.insetBy(dx: 2, dy: 2).intersects(okvir) }) else { continue }
                    zauzeto.append(okvir)
                    let plocica = Path(roundedRect: okvir, cornerRadius: 6)
                    ctx.fill(plocica.offsetBy(dx: 0, dy: 1.5), with: .color(.tinta.opacity(0.55)))
                    ctx.fill(plocica, with: .color(vlasnik.map { Color(hex: $0.boja) } ?? .white))
                    ctx.stroke(plocica, with: .color(.tinta), lineWidth: 1.2)
                    ctx.draw(Text(skriveno ? Stanje.procenaVojske(st.vojske) : "\(st.vojske)").font(.naslov(skriveno ? 9 : 11))
                                .foregroundStyle(vlasnik == nil ? Color.tinta : .white), at: c)
                    // Čudo sveta: zvezdica uz značku države.
                    if cudo != nil {
                        let z = CGRect(x: okvir.minX - 13, y: c.y - 7, width: 14, height: 14)
                        ctx.fill(Path(ellipseIn: z), with: .color(.zuta))
                        ctx.stroke(Path(ellipseIn: z), with: .color(.tinta), lineWidth: 1)
                        ctx.draw(Text(Image(systemName: "star.fill")).font(.system(size: 7, weight: .bold)).foregroundStyle(Color.tinta), at: CGPoint(x: z.midX, y: z.midY))
                    }
                    if prestonice.contains(o.id) {
                        ctx.draw(Text(Image(systemName: "crown.fill")).font(.system(size: 9)).foregroundStyle(Color.zuta),
                                 at: CGPoint(x: c.x + 11, y: c.y - 10))
                    }
                }
            }
            .overlay {
                // Efekti u svom sloju, da se cela mapa ne crta iznova 60 puta u sekundi.
                TimelineView(.animation(minimumInterval: 1 / 30, paused: !efekti.aktivno(.now))) { t in
                    Canvas { ctx, _ in crtajEfekte(ctx, sad: t.date, pocetak: pocetak, k: k) }
                }
                .allowsHitTesting(false)
            }
            .overlay {
                // Stalni sloj (vlasnik 03.11, „kao da sam u igri”): strelica napada koja maršira, događaj na kontinentu, čuda svetle.
                // Kad nema ničeg živog, sat stoji; uz „Smanji kretanje” iz podešavanja telefona sve je mirno.
                TimelineView(.animation(minimumInterval: izabrana != nil && meta != nil ? 1 / 30 : 1 / 12, paused: manjeKretanja || !imaAmbijenta)) { t in
                    Canvas { ctx, _ in crtajAmbijent(ctx, sad: t.date, pocetak: pocetak, k: k) }
                }
                .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(
                SimultaneousGesture(
                    MagnifyGesture()
                        .updating($zumPokret) { v, s, _ in
                            s = Stipanje(f: v.magnification, c: CGSize(width: v.startLocation.x - g.size.width / 2, height: v.startLocation.y - g.size.height / 2))
                        }
                        .onChanged { _ in if !biloStipanje { biloStipanje = true } }
                        .onEnded { v in
                            if !vucenjeTraje { biloStipanje = false }
                            zumiraj(na: razmera * v.magnification, osnova: osnova, velicina: g.size,
                                    oko: CGSize(width: v.startLocation.x - g.size.width / 2, height: v.startLocation.y - g.size.height / 2))
                        },
                    DragGesture(minimumDistance: 6).updating($prevlacenje) { v, s, _ in s = v.translation }
                        .onChanged { _ in if !vucenjeTraje { vucenjeTraje = true } }
                        .onEnded { v in
                            defer { biloStipanje = false; vucenjeTraje = false }
                            guard !biloStipanje else { return }
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
                // Ceo kontinent samo na prvom kadru; posle toga dodir i bitka ne vraćaju zum koji je igrač namestio.
                if naKontinentu {
                    if !uokvirenKontinent { uokviri(Array(stanje.oblasti.keys), velicina: g.size, osnova: osnova, tesno: true) }
                    uokvirenKontinent = true
                } else {
                    centriraj(novi ?? (pocetakCentriran ? nil : prviKadar), velicina: g.size, osnova: osnova)
                    pocetakCentriran = true
                }
            }
            .onChange(of: mojPotez) { _, _ in
                guard !moje.isEmpty else { return }
                uokviri(moje, velicina: g.size, osnova: osnova)
            }
            .onChange(of: mete) { _, nove in
                // Izabrana država i sve njene mete staju u kadar, da se vidi kuda se može dalje.
                // Samo približava: ako je igrač uvećao više nego što treba, kadar se pomera na izabranu bez umanjenja.
                guard let izabrana, !nove.isEmpty, !vidljivo([izabrana] + nove, velicina: g.size, osnova: osnova) else { return }
                uokviri([izabrana] + nove, velicina: g.size, osnova: osnova, neUmanjuj: true)
            }
            .overlay(alignment: .topTrailing) {
                VStack(spacing: 8) {
                    zumDugme("plus.magnifyingglass", "Uvećaj") { zumiraj(na: razmera * 1.5, osnova: osnova, velicina: g.size) }
                    zumDugme("minus.magnifyingglass", "Umanji") { zumiraj(na: razmera / 1.5, osnova: osnova, velicina: g.size) }
                    if naKontinentu {
                        zumDugme("globe.europe.africa", "Ceo kontinent") { uokviri(Array(stanje.oblasti.keys), velicina: g.size, osnova: osnova, tesno: true) }
                    } else {
                        zumDugme("globe.europe.africa", "Ceo svet") { razmera = 1; pomak = .zero }
                    }
                }
                .padding(bezOkvira ? 4 : 10)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Mapa sveta")
            .accessibilityValue(izabrana.map { "Izabrana \(Mapa.oblast($0).ime), mete: \(mete.map { Mapa.oblast($0).ime }.joined(separator: ", "))" } ?? "")
        }
        .clipShape(RoundedRectangle(cornerRadius: bezOkvira ? 0 : 24, style: .continuous))
        .overlay { if !bezOkvira { RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.mastilo, lineWidth: 2.5) } }
    }

    private func crtajEfekte(_ ctx: GraphicsContext, sad: Date, pocetak: CGPoint, k: CGFloat) {
        func tacka(_ id: String) -> CGPoint { let o = Mapa.oblast(id); return CGPoint(x: pocetak.x + o.x * k, y: pocetak.y + o.y * k) }
        // Zatvoren region: ivice država trepnu u boji vlasnika.
        for z in efekti.zatvoreni {
            let t = sad.timeIntervalSince(z.kad) / 2
            guard t < 1 else { continue }
            var m = ctx
            m.translateBy(x: pocetak.x, y: pocetak.y); m.scaleBy(x: k, y: k)
            for o in Mapa.oblasti where o.region == z.region {
                guard let put = PutanjeMape.sve[o.id] else { continue }
                m.fill(put, with: .color(.white.opacity(0.45 * (1 - t))))
                m.stroke(put, with: .color(Color(hex: z.boja)), style: StrokeStyle(lineWidth: (3 + 5 * (1 - t)) / k, lineJoin: .round))
            }
        }
        // Udar: strela raste od izvora do mete, pa krug koji se širi (zelen za osvojeno, crven za odbranjeno).
        if let u = efekti.udar {
            let t = sad.timeIntervalSince(u.kad) / Efekti.trajanjeUdara
            if t < 1 {
                let a = tacka(u.odakle), b = tacka(u.kuda)
                // Stara boja drži državu od prvog kadra (stanje je već nove boje), pa se nova razlije kad strela stigne.
                if u.osvojeno, let put = PutanjeMape.sve[u.kuda] { razlij(ctx, put: put, u: u, f: max(0, min(1, (t - 0.3) / 0.45)), a: a, b: b, pocetak: pocetak, k: k) }
                if u.osvojeno, t > 0.3 { prasina(ctx, u: u, f: (t - 0.3) / 0.7, b: b) }
                let rast = min(1, t / 0.3)
                var strela = Path()
                strela.move(to: a); strela.addLine(to: CGPoint(x: a.x + (b.x - a.x) * rast, y: a.y + (b.y - a.y) * rast))
                ctx.stroke(strela, with: .color(Color.crvena.opacity(1 - max(0, t - 0.6) / 0.4)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                if t > 0.3 {
                    let f = (t - 0.3) / 0.7
                    let r = 8 + 34 * f
                    ctx.stroke(Path(ellipseIn: CGRect(x: b.x - r, y: b.y - r, width: r * 2, height: r * 2)),
                               with: .color((u.osvojeno ? Color.teal : Color.crvena).opacity(1 - f)), lineWidth: 4)
                }
            }
        }
        // Brojke vojski: „+2” ili „−1” iskoči iznad značke i nestane.
        for i in efekti.iskoci {
            let t = sad.timeIntervalSince(i.kad) / Efekti.trajanjeIskoka
            guard t < 1, i.promena != 0 else { continue }
            let c = tacka(i.oblast)
            // Pojačanje: žeton leti lukom iz prestonice vlasnika.
            let let_ = sad.timeIntervalSince(i.kad) / Efekti.letPojacanja
            if i.promena > 0, let_ < 1, let vlasnik = stanje.oblasti[i.oblast]?.vlasnik,
               let p = stanje.igraci.first(where: { $0.tim == vlasnik }), p.prestonica != i.oblast {
                let a = tacka(p.prestonica)
                let e = 1 - pow(1 - let_, 3)
                let tackaLeta = CGPoint(x: a.x + (c.x - a.x) * e, y: a.y + (c.y - a.y) * e - sin(e * .pi) * 40)
                // Žuti žeton sa tamnom ivicom: vidi se i preko sopstvene teritorije (boja tima se gubila).
                let r: CGFloat = 9
                let krug = Path(ellipseIn: CGRect(x: tackaLeta.x - r, y: tackaLeta.y - r, width: r * 2, height: r * 2))
                ctx.fill(krug.offsetBy(dx: 0, dy: 2), with: .color(.tinta.opacity(0.4)))
                ctx.fill(krug, with: .color(.zuta))
                ctx.stroke(krug, with: .color(.tinta), lineWidth: 2)
                ctx.draw(Text("+\(i.promena)").font(.naslov(10)).foregroundStyle(Color.tinta), at: tackaLeta)
                continue
            }
            // Pločica u boji (žuta za dobitak, crvena za gubitak), da se vidi na državi bilo koje boje.
            let gde = CGPoint(x: c.x, y: c.y - 20 - 22 * t)
            let okvir = Path(roundedRect: CGRect(x: gde.x - 16, y: gde.y - 11, width: 32, height: 22), cornerRadius: 7)
            var sloj = ctx
            sloj.opacity = 1 - max(0, t - 0.6) / 0.4
            sloj.fill(okvir, with: .color(i.promena > 0 ? Color.zuta : Color.crvena))
            sloj.stroke(okvir, with: .color(.tinta), lineWidth: 1.5)
            sloj.draw(Text(i.promena > 0 ? "+\(i.promena)" : "−\(-i.promena)").font(.naslov(13))
                        .foregroundStyle(i.promena > 0 ? Color.tinta : .white), at: gde)
        }
    }

    /// Nova boja se širi kao mastilo od strane napadača preko stare boje države.
    private func razlij(_ ctx: GraphicsContext, put: Path, u: OsvajanjeModel.Udar, f: Double, a: CGPoint, b: CGPoint, pocetak: CGPoint, k: CGFloat) {
        guard f < 1, let nova = u.novaBoja else { return }
        var m = ctx
        m.translateBy(x: pocetak.x, y: pocetak.y); m.scaleBy(x: k, y: k)
        m.clip(to: put)
        let okvir = put.boundingRect
        let stara = u.staraBoja.map { Color(hex: $0) } ?? Self.neutralne[Mapa.oblast(u.kuda).boja % 5]
        m.fill(Path(okvir.insetBy(dx: -2, dy: -2)), with: .color(stara))
        // Ulaz: tačka na putu od napadača ka sredini mete, malo pre sredine.
        let o = Mapa.oblast(u.kuda), od = Mapa.oblast(u.odakle)
        let ulaz = CGPoint(x: o.x + (od.x - o.x) * 0.35, y: o.y + (od.y - o.y) * 0.35)
        let r = hypot(okvir.width, okvir.height) * (0.08 + 1.1 * (1 - pow(1 - f, 2)))
        m.fill(Path(ellipseIn: CGRect(x: ulaz.x - r, y: ulaz.y - r, width: r * 2, height: r * 2)), with: .color(Color(hex: nova)))
    }

    /// Oblačić prašine: osam kuglica se razleti iz osvojene države i izblede.
    private func prasina(_ ctx: GraphicsContext, u: OsvajanjeModel.Udar, f: Double, b: CGPoint) {
        guard f < 1 else { return }
        var sloj = ctx
        sloj.opacity = 1 - f
        for i in 0..<8 {
            let ugao = Double(i) / 8 * 2 * .pi + Double(u.kuda.hashValue % 7) * 0.1
            let d = 10 + 26 * (1 - pow(1 - f, 2))
            let r = 5 * (1 - f * 0.6)
            let p = CGPoint(x: b.x + cos(ugao) * d, y: b.y + sin(ugao) * d - 10 * f)
            sloj.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(Color(hex: 0xEDE3D1)))
        }
    }

    private var aktivanDogadjaj: String? { stanje.dogadjaj.flatMap { stanje.aktivanDogadjaj($0.kontinent) ? $0.kontinent : nil } }
    /// Čuda na ovoj mapi, i neutralna: svetle kao mamac za osvajanje.
    private var cudaNaMapi: [String] { Cudo.sva.map(\.oblast).filter { stanje.oblasti[$0] != nil } }
    private var imaAmbijenta: Bool { (izabrana != nil && meta != nil) || aktivanDogadjaj != nil || !cudaNaMapi.isEmpty }

    /// Okvir kontinenta u koordinatama mape (za čestice događaja).
    private static let okviriKontinenata: [String: CGRect] = Dictionary(uniqueKeysWithValues: Kontinenti.svi.map { k in
        let t = Kontinenti.oblasti(k.id).map { Mapa.oblast($0) }
        let x = t.map(\.x), y = t.map(\.y)
        return (k.id, CGRect(x: x.min() ?? 0, y: y.min() ?? 0, width: (x.max() ?? 0) - (x.min() ?? 0), height: (y.max() ?? 0) - (y.min() ?? 0)).insetBy(dx: -30, dy: -30))
    })

    private func crtajAmbijent(_ ctx: GraphicsContext, sad: Date, pocetak: CGPoint, k: CGFloat) {
        let vreme = sad.timeIntervalSinceReferenceDate
        func tacka(_ id: String) -> CGPoint { let o = Mapa.oblast(id); return CGPoint(x: pocetak.x + o.x * k, y: pocetak.y + o.y * k) }
        // Strelica napada: strelice „marširaju” od izabrane države ka meti.
        if let izabrana, let meta {
            let a = tacka(izabrana), b = tacka(meta)
            let duzina = hypot(b.x - a.x, b.y - a.y)
            let ugao = atan2(b.y - a.y, b.x - a.x)
            let broj = max(2, Int(duzina / 26))
            for i in 0..<broj {
                let f = (Double(i) / Double(broj) + vreme * 0.6).truncatingRemainder(dividingBy: 1)
                let p = CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
                var strelica = Path()
                strelica.move(to: CGPoint(x: -5, y: -6)); strelica.addLine(to: CGPoint(x: 5, y: 0)); strelica.addLine(to: CGPoint(x: -5, y: 6))
                var s = ctx
                s.translateBy(x: p.x, y: p.y); s.rotate(by: .radians(ugao))
                s.opacity = sin(f * .pi)
                s.stroke(strelica, with: .color(.crvena), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
        }
        // Čuda sveta: blag zlatni sjaj oko države.
        for id in cudaNaMapi {
            let c = tacka(id)
            let puls = (sin(vreme * 2.2 + Double(id.count)) + 1) / 2
            let r = 16 + 6 * puls
            var s = ctx
            s.opacity = 0.25 + 0.35 * (1 - puls)
            s.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(.zuta), lineWidth: 3)
        }
        // Događaj na kontinentu: sneg, kiša, zlato, konfete ili talasi preko kontinenta.
        guard let kont = aktivanDogadjaj, let okvir = Self.okviriKontinenata[kont] else { return }
        let o = CGRect(x: pocetak.x + okvir.minX * k, y: pocetak.y + okvir.minY * k, width: okvir.width * k, height: okvir.height * k)
        var s = ctx
        s.clip(to: Path(roundedRect: o, cornerRadius: 20))
        func slucajno(_ i: Int, _ so: Double) -> Double { let x = sin(Double(i) * 12.9898 + so) * 43758.5453; return x - x.rounded(.down) }
        let broj = 46
        for i in 0..<broj {
            let x = o.minX + slucajno(i, 1) * o.width
            switch kont {
            case "evr":
                let y = o.minY + ((slucajno(i, 2) + vreme * (0.06 + 0.05 * slucajno(i, 3))).truncatingRemainder(dividingBy: 1)) * o.height
                let r = 1.5 + 2 * slucajno(i, 4)
                s.fill(Path(ellipseIn: CGRect(x: x + sin(vreme + Double(i)) * 6 - r, y: y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.9)))
            case "azi":
                let y = o.minY + ((slucajno(i, 2) + vreme * 0.5).truncatingRemainder(dividingBy: 1)) * o.height
                var kap = Path(); kap.move(to: CGPoint(x: x, y: y)); kap.addLine(to: CGPoint(x: x - 4, y: y + 12))
                s.stroke(kap, with: .color(Color(hex: 0x3D7EB8).opacity(0.6)), lineWidth: 1.5)
            case "afr", "sam":
                let sjaj = (sin(vreme * 3 + Double(i) * 1.7) + 1) / 2
                let y = o.minY + slucajno(i, 2) * o.height
                let r = 2 + 3 * sjaj
                var z = Path()
                z.move(to: CGPoint(x: x, y: y - r)); z.addLine(to: CGPoint(x: x + r * 0.3, y: y)); z.addLine(to: CGPoint(x: x, y: y + r)); z.addLine(to: CGPoint(x: x - r * 0.3, y: y)); z.closeSubpath()
                z.move(to: CGPoint(x: x - r, y: y)); z.addLine(to: CGPoint(x: x, y: y + r * 0.3)); z.addLine(to: CGPoint(x: x + r, y: y)); z.addLine(to: CGPoint(x: x, y: y - r * 0.3)); z.closeSubpath()
                s.fill(z, with: .color(Color(hex: 0xF5B800).opacity(0.35 + 0.6 * sjaj)))
            case "jam":
                let y = o.minY + ((slucajno(i, 2) + vreme * 0.12).truncatingRemainder(dividingBy: 1)) * o.height
                let boje: [UInt32] = [0xFF5FA2, 0xFFD23F, 0x12907E, 0x6D4BC9, 0x5BC0EB]
                var c = s
                c.translateBy(x: x, y: y); c.rotate(by: .radians(vreme * 3 + Double(i)))
                c.fill(Path(CGRect(x: -3, y: -1.5, width: 6, height: 3)), with: .color(Color(hex: boje[i % boje.count])))
            default:
                // Cunami: talasi koji putuju preko okeana.
                guard i < 7 else { break }
                let y = o.minY + (Double(i) + 0.5) / 7 * o.height
                var talas = Path()
                for korak in 0...24 {
                    let px = o.minX + Double(korak) / 24 * o.width
                    let py = y + sin(Double(korak) * 0.7 - vreme * 3 + Double(i)) * 5
                    if korak == 0 { talas.move(to: CGPoint(x: px, y: py)) } else { talas.addLine(to: CGPoint(x: px, y: py)) }
                }
                s.stroke(talas, with: .color(Color(hex: 0x1E6FA8).opacity(0.45)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
        }
    }

    /// Zum drži mesto ispod tačke `oko` (od sredine ekrana; dugmad zumiraju oko sredine), inače bi pogled odleteo.
    private func zumiraj(na nova: CGFloat, osnova: CGFloat, velicina: CGSize, oko c: CGSize = .zero) {
        let r = min(Self.najveciZum, max(1, nova))
        let f = r / razmera
        razmera = r
        pomak = ogranici(CGSize(width: (pomak.width - c.width) * f + c.width, height: (pomak.height - c.height) * f + c.height), k: osnova * r, velicina: velicina)
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

    /// Da li su sve države već na ekranu (uz rub za značku), pa kadar ne treba pomerati.
    private func vidljivo(_ ids: [String], velicina: CGSize, osnova: CGFloat) -> Bool {
        let k = osnova * razmera
        let rub: CGFloat = 28
        return ids.map(Mapa.oblast).allSatisfy { o in
            let x = velicina.width / 2 + (o.x - Mapa.sirina / 2) * k + pomak.width
            let y = velicina.height / 2 + (o.y - Mapa.visina / 2) * k + pomak.height
            return x > rub && x < velicina.width - rub && y > rub && y < velicina.height - rub
        }
    }

    /// `tesno` za ceo kontinent: manje vazduha oko ivica, da države budu krupnije.
    private func uokviri(_ ids: [String], velicina: CGSize, osnova: CGFloat, tesno: Bool = false, neUmanjuj: Bool = false) {
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
        let zeljena = min(Self.najveciZum, max(1, k / osnova))
        if neUmanjuj && zeljena < razmera {
            // Sve mete ne staju u igračev zum: centar na prvoj (izabranoj) državi, razmera ostaje.
            let o = t[0]
            withAnimation(.easeInOut(duration: 0.35)) {
                let kk = osnova * razmera
                pomak = ogranici(CGSize(width: (Mapa.sirina / 2 - o.x) * kk, height: (Mapa.visina / 2 - o.y) * kk), k: kk, velicina: velicina)
            }
            return
        }
        withAnimation(.easeInOut(duration: 0.45)) {
            razmera = zeljena
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
            // Na ekranu partije manja dugmad bez okvira, da ne pokrivaju mapu (dodirna površina ostaje 44).
            Image(systemName: ikonica).font(.system(size: bezOkvira ? 14 : 16, weight: .bold)).foregroundStyle(Color.mastilo)
                .frame(width: bezOkvira ? 34 : 44, height: bezOkvira ? 34 : 44).background(Color.kartica.opacity(bezOkvira ? 0.9 : 1), in: Circle())
                .overlay { if !bezOkvira { Circle().stroke(Color.mastilo, lineWidth: 2) } }
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .accessibilityLabel(opis)
    }
}
