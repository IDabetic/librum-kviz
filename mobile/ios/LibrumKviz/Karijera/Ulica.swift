import SwiftUI

/// Ulica ispred zgrade (vlasnik 05.11: „kola koja prolaze ispred zgrade, ljudi, da se uživi”; „kao ptice: pešaci da koračaju”).
/// Prolaznici i vozila su nacrtani u kodu, kao ptice na nebu: pešaci koračaju (noge i ruke se njišu), točkovi se okreću,
/// hitnoj trepće rotacija. Raspored je izveden iz vremena, bez stanja i bez servera.
/// Sa „Smanji pokrete” u podešavanjima telefona ulica miruje (ništa se ne crta).
struct Ulica: View {
    let mesto: String
    /// Manje kartice (npr. 104 pt) dobijaju ređi saobraćaj.
    var gustina: Double = 1
    @Environment(\.accessibilityReduceMotion) private var mirno

    var body: some View {
        if !mirno {
            TimelineView(.animation(minimumInterval: 1 / 30, paused: false)) { kontekst in
                Canvas { ctx, size in
                    let t = kontekst.date.timeIntervalSinceReferenceDate
                    let seme = Double(mesto.unicodeScalars.reduce(0) { ($0 * 31 + Int($1.value)) % 997 })
                    // Pešaci iza, vozila napred (bliže gledaocu).
                    Self.traka(ctx, size, t, visina: size.height * 0.17, trajanje: 14, razmak: 4 / gustina,
                               dno: size.height * 0.997, seme: seme + 1, vozila: false)
                    Self.traka(ctx, size, t, visina: size.height * 0.13, trajanje: 4.5, razmak: 3.5 / gustina,
                               dno: size.height * 0.995, seme: seme + 2, vozila: true)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    /// Pseudo-slučajan broj 0..<1 za ceo broj i seme (isti ulaz, isti izlaz; isto i na Androidu).
    static func slucaj(_ n: Double, _ seme: Double) -> Double {
        let x = sin(n * 12.9898 + seme * 78.233) * 43758.5453
        return x - x.rounded(.down)
    }

    static let odeca: [UInt32] = [0x12907E, 0xE5674F, 0x2F4A7A, 0xF4A33C, 0x6D4BC9, 0x7A8794, 0xFF5FA2]
    static let koza: [UInt32] = [0xF2C9A0, 0xD9A06B, 0x9C6B45, 0xF7D7B5]
    static let karoserija: [UInt32] = [0xE5385C, 0x6EC3F2, 0x12907E, 0x7A8794, 0x2F4A7A]

    /// Jedna traka: u svakom „slotu” od `razmak` sekundi možda krene jedan prolaznik i pređe ceo ekran.
    private static func traka(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double, visina: CGFloat,
                              trajanje: Double, razmak: Double, dno: CGFloat, seme: Double, vozila: Bool) {
        let sada = (t / razmak).rounded(.down)
        let unazad = (trajanje * 1.6 / razmak).rounded(.up)
        for n in stride(from: sada - unazad, through: sada, by: 1) {
            guard slucaj(n, seme) > 0.3 else { continue }
            let vrsta = Int(slucaj(n, seme + 3) * 100)
            let brzina = vozila ? [1.0, 0.9, 1.1, 0.85, 1.4, 0.7][vrsta % 6] : (vrsta % 7 == 0 ? 2.0 : 0.85 + slucaj(n, seme + 5) * 0.3)
            let pocetak = n * razmak + slucaj(n, seme + 7) * razmak * 0.6
            let p = (t - pocetak) / (trajanje / brzina)
            guard p >= 0, p <= 1 else { continue }
            let duzina = vozila ? visina * (vrsta % 6 == 5 ? 4.2 : 2.4) : visina * 0.5
            let udesno = slucaj(n, seme + 11) < 0.5
            let x = udesno ? -duzina + p * (size.width + duzina) : size.width - p * (size.width + duzina)
            var c = ctx
            c.translateBy(x: x + duzina / 2, y: dno)
            if !udesno { c.scaleBy(x: -1, y: 1) }
            let predjeno = p * (size.width + duzina)
            if vozila { vozilo(c, vrsta: vrsta % 6, h: visina, duzina: duzina, predjeno: predjeno, t: t, boja: karoserija[vrsta % karoserija.count]) }
            else { pesak(c, h: visina, faza: predjeno / (visina * 0.32), boja: odeca[vrsta % odeca.count],
                         koza: koza[(vrsta / 7) % koza.count], bicikl: vrsta % 7 == 0, torba: vrsta % 3 == 0) }
        }
    }

    /// Pešak gleda udesno; (0,0) je tačka između stopala. `faza` raste sa pređenim putem, pa korak prati brzinu.
    private static func pesak(_ c: GraphicsContext, h: CGFloat, faza: Double, boja: UInt32, koza: UInt32, bicikl: Bool, torba: Bool) {
        let tamno = Color(hex: 0x24303C)
        let debljina = max(1.2, h * 0.075)
        let kuk = CGPoint(x: 0, y: -h * 0.46)
        if bicikl {
            let r = h * 0.2
            let pedala = faza * 0.8
            for tx in [-h * 0.3, h * 0.3] {
                c.stroke(Path(ellipseIn: CGRect(x: tx - r, y: -2 * r, width: 2 * r, height: 2 * r)), with: .color(tamno), lineWidth: max(1, h * 0.035))
            }
            var ram = Path(); ram.move(to: CGPoint(x: -h * 0.3, y: -r)); ram.addLine(to: CGPoint(x: -h * 0.05, y: -h * 0.5))
            ram.addLine(to: CGPoint(x: h * 0.22, y: -h * 0.5)); ram.addLine(to: CGPoint(x: h * 0.3, y: -r)); ram.move(to: CGPoint(x: -h * 0.05, y: -h * 0.5)); ram.addLine(to: CGPoint(x: 0, y: -r))
            c.stroke(ram, with: .color(Color(hex: boja)), style: StrokeStyle(lineWidth: max(1, h * 0.045), lineCap: .round, lineJoin: .round))
            let sediste = CGPoint(x: -h * 0.06, y: -h * 0.56)
            for z in [0.0, Double.pi] {
                let stopalo = CGPoint(x: CGFloat(cos(pedala + z)) * h * 0.08, y: -r + CGFloat(sin(pedala + z)) * h * 0.08)
                let koleno = CGPoint(x: (sediste.x + stopalo.x) / 2 + h * 0.1, y: (sediste.y + stopalo.y) / 2 - h * 0.04)
                var noga = Path(); noga.move(to: sediste); noga.addLine(to: koleno); noga.addLine(to: stopalo)
                c.stroke(noga, with: .color(tamno), style: StrokeStyle(lineWidth: debljina, lineCap: .round, lineJoin: .round))
            }
            var telo = Path(); telo.move(to: sediste); telo.addLine(to: CGPoint(x: h * 0.06, y: -h * 0.86))
            c.stroke(telo, with: .color(Color(hex: boja)), style: StrokeStyle(lineWidth: h * 0.14, lineCap: .round))
            var ruka = Path(); ruka.move(to: CGPoint(x: h * 0.05, y: -h * 0.8)); ruka.addLine(to: CGPoint(x: h * 0.22, y: -h * 0.55))
            c.stroke(ruka, with: .color(Color(hex: koza)), style: StrokeStyle(lineWidth: debljina * 0.8, lineCap: .round))
            c.fill(Path(ellipseIn: CGRect(x: h * 0.0, y: -h * 1.04, width: h * 0.17, height: h * 0.17)), with: .color(Color(hex: koza)))
            return
        }
        let mah = CGFloat(sin(faza)) * 0.5
        // Noge: dve „makaze” oko kuka; zadnja tamnija.
        for (znak, nijansa) in [(-1.0, 0.75), (1.0, 1.0)] {
            let ugao = mah * CGFloat(znak)
            let stopalo = CGPoint(x: kuk.x + sin(ugao) * h * 0.46, y: kuk.y + cos(ugao) * h * 0.46)
            var noga = Path(); noga.move(to: kuk); noga.addLine(to: stopalo)
            c.stroke(noga, with: .color(tamno.opacity(nijansa)), style: StrokeStyle(lineWidth: debljina, lineCap: .round))
        }
        // Telo blago poskakuje uz korak.
        let skok = CGFloat(abs(sin(faza))) * h * 0.02
        let rame = CGPoint(x: h * 0.02, y: -h * 0.8 - skok)
        let zadnjaRuka = CGPoint(x: rame.x - sin(mah) * h * 0.3, y: rame.y + cos(mah) * h * 0.3)
        var r1 = Path(); r1.move(to: rame); r1.addLine(to: zadnjaRuka)
        c.stroke(r1, with: .color(Color(hex: boja).opacity(0.7)), style: StrokeStyle(lineWidth: debljina * 0.85, lineCap: .round))
        c.fill(Path(roundedRect: CGRect(x: -h * 0.1, y: -h * 0.86 - skok, width: h * 0.2, height: h * 0.42), cornerRadius: h * 0.07), with: .color(Color(hex: boja)))
        let prednjaRuka = CGPoint(x: rame.x + sin(mah) * h * 0.3, y: rame.y + cos(mah) * h * 0.3)
        var r2 = Path(); r2.move(to: rame); r2.addLine(to: prednjaRuka)
        c.stroke(r2, with: .color(Color(hex: boja)), style: StrokeStyle(lineWidth: debljina * 0.85, lineCap: .round))
        if torba { c.fill(Path(roundedRect: CGRect(x: prednjaRuka.x - h * 0.06, y: prednjaRuka.y, width: h * 0.13, height: h * 0.1), cornerRadius: h * 0.02), with: .color(Color(hex: 0x3B2A20))) }
        c.fill(Path(ellipseIn: CGRect(x: -h * 0.08, y: -h * 1.04 - skok, width: h * 0.17, height: h * 0.17)), with: .color(Color(hex: koza)))
    }

    /// Vozilo gleda udesno; (0,0) je sredina ispod točkova. 0–2 auto, 3 kombi, 4 hitna, 5 autobus.
    private static func vozilo(_ c: GraphicsContext, vrsta: Int, h: CGFloat, duzina L: CGFloat, predjeno: CGFloat, t: Double, boja: UInt32) {
        let r = h * 0.2
        let staklo = Color(hex: 0xBFE6F5)
        let lim: Color = switch vrsta { case 3, 4: Color(hex: 0xF4F6F8); case 5: Color(hex: 0x5BB36A); case 2: Color(hex: 0xF7C531); default: Color(hex: boja) }
        let ivica = Color(hex: 0x24303C)
        var telo = Path()
        switch vrsta {
        case 3, 4: // kombi: visoka kutija sa kabinom napred
            telo.addRoundedRect(in: CGRect(x: -L / 2, y: -h * 1.15, width: L * 0.78, height: h * 0.95), cornerSize: CGSize(width: h * 0.1, height: h * 0.1))
            telo.addRoundedRect(in: CGRect(x: -L / 2 + L * 0.7, y: -h * 0.85, width: L * 0.3, height: h * 0.65), cornerSize: CGSize(width: h * 0.18, height: h * 0.18))
        case 5: // autobus
            telo.addRoundedRect(in: CGRect(x: -L / 2, y: -h * 1.25, width: L, height: h * 1.05), cornerSize: CGSize(width: h * 0.15, height: h * 0.15))
        default: // auto: donji deo i kabina
            telo.addRoundedRect(in: CGRect(x: -L / 2, y: -h * 0.62, width: L, height: h * 0.42), cornerSize: CGSize(width: h * 0.16, height: h * 0.16))
            telo.move(to: CGPoint(x: -L * 0.3, y: -h * 0.6)); telo.addLine(to: CGPoint(x: -L * 0.18, y: -h * 1.0))
            telo.addLine(to: CGPoint(x: L * 0.14, y: -h * 1.0)); telo.addLine(to: CGPoint(x: L * 0.3, y: -h * 0.6)); telo.closeSubpath()
        }
        c.fill(telo, with: .color(lim))
        c.stroke(telo, with: .color(ivica.opacity(0.35)), lineWidth: max(0.6, h * 0.03))
        // Prozori
        switch vrsta {
        case 3, 4:
            c.fill(Path(roundedRect: CGRect(x: L * 0.24, y: -h * 0.78, width: L * 0.2, height: h * 0.28), cornerRadius: h * 0.06), with: .color(staklo))
            if vrsta == 4 {
                c.fill(Path(CGRect(x: -L / 2, y: -h * 0.6, width: L * 0.78, height: h * 0.12)), with: .color(Color(hex: 0xE5385C)))
                let trepce = Int(t * 4) % 2 == 0
                c.fill(Path(roundedRect: CGRect(x: -L * 0.05, y: -h * 1.3, width: h * 0.25, height: h * 0.15), cornerRadius: h * 0.04), with: .color(trepce ? Color(hex: 0x3A7BFF) : Color(hex: 0xE5385C)))
            }
        case 5:
            for i in 0..<6 { c.fill(Path(roundedRect: CGRect(x: -L / 2 + L * 0.05 + CGFloat(i) * L * 0.15, y: -h * 1.1, width: L * 0.12, height: h * 0.38), cornerRadius: h * 0.05), with: .color(staklo)) }
        default:
            var p1 = Path(); p1.move(to: CGPoint(x: -L * 0.24, y: -h * 0.64)); p1.addLine(to: CGPoint(x: -L * 0.16, y: -h * 0.92)); p1.addLine(to: CGPoint(x: -L * 0.02, y: -h * 0.92)); p1.addLine(to: CGPoint(x: -L * 0.02, y: -h * 0.64)); p1.closeSubpath()
            var p2 = Path(); p2.move(to: CGPoint(x: L * 0.02, y: -h * 0.64)); p2.addLine(to: CGPoint(x: L * 0.02, y: -h * 0.92)); p2.addLine(to: CGPoint(x: L * 0.12, y: -h * 0.92)); p2.addLine(to: CGPoint(x: L * 0.23, y: -h * 0.64)); p2.closeSubpath()
            c.fill(p1, with: .color(staklo)); c.fill(p2, with: .color(staklo))
            if vrsta == 2 { c.fill(Path(roundedRect: CGRect(x: -L * 0.06, y: -h * 1.12, width: L * 0.12, height: h * 0.12), cornerRadius: h * 0.03), with: .color(Color(hex: 0xFFF3B0))) }
        }
        // Far napred
        c.fill(Path(ellipseIn: CGRect(x: L / 2 - h * 0.12, y: -h * 0.5, width: h * 0.1, height: h * 0.1)), with: .color(Color(hex: 0xFFE27A)))
        // Točkovi se okreću koliko je vozilo prešlo.
        let ugao = predjeno / r
        for tx in [-L / 2 + L * 0.2, L / 2 - L * 0.2] {
            c.fill(Path(ellipseIn: CGRect(x: tx - r, y: -2 * r, width: 2 * r, height: 2 * r)), with: .color(ivica))
            c.fill(Path(ellipseIn: CGRect(x: tx - r * 0.45, y: -r - r * 0.45, width: r * 0.9, height: r * 0.9)), with: .color(Color(hex: 0xC9D2DC)))
            var zbica = Path()
            zbica.move(to: CGPoint(x: tx - cos(ugao) * r * 0.45, y: -r - sin(ugao) * r * 0.45))
            zbica.addLine(to: CGPoint(x: tx + cos(ugao) * r * 0.45, y: -r + sin(ugao) * r * 0.45))
            c.stroke(zbica, with: .color(ivica), lineWidth: max(0.6, r * 0.18))
        }
    }
}
