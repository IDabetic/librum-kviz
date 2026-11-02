import SwiftUI

// Vizuelni jezik QuizPop kita, isti kao veb (globals.css): krem papir, mastilo,
// debele ivice sa tvrdom senkom, Archivo Black kurziv za naslove.

extension Color {
    init(hex: UInt32, alfa: Double = 1) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: alfa)
    }
    /// Boja iz teme kita: svetla vrednost / tamna vrednost (Quizpop · Theme).
    init(svetlo: UInt32, tamno: UInt32, alfaSvetlo: Double = 1, alfaTamno: Double = 1) {
        self.init(uiColor: UIColor { t in
            let (h, a) = t.userInterfaceStyle == .dark ? (tamno, alfaTamno) : (svetlo, alfaSvetlo)
            return UIColor(red: CGFloat((h >> 16) & 0xFF) / 255, green: CGFloat((h >> 8) & 0xFF) / 255, blue: CGFloat(h & 0xFF) / 255, alpha: a)
        })
    }
    static let krem = Color(svetlo: 0xF3F0E6, tamno: 0x12110F)          // surface/canvas
    static let kremTamnija = Color(svetlo: 0xE7E1D0, tamno: 0x3B3832)   // border/default
    static let udubljeno = Color(svetlo: 0xE7E1D0, tamno: 0x2E2B26)     // surface/sunken
    static let skelet = Color(svetlo: 0xDDD6C6, tamno: 0x3B3832)        // surface/skeleton
    static let kartica = Color(svetlo: 0xFFFFFF, tamno: 0x24221E)       // surface/card
    static let mastilo = Color(svetlo: 0x151515, tamno: 0xF3F0E6)       // text/primary, border/strong
    static let naMastilu = Color(svetlo: 0xFFFFFF, tamno: 0x151515)     // text/inverse
    static let senka = Color(svetlo: 0x151515, tamno: 0x000000)
    static let sivaTekst = Color(svetlo: 0x151515, tamno: 0xFFFFFF, alfaSvetlo: 0.6, alfaTamno: 0.6)
    static let teal = Color(hex: 0x12907E)
    static let tealSvetla = Color(svetlo: 0xDFF3EE, tamno: 0x173A34)
    static let roze = Color(hex: 0xFF5FA2)
    static let narandzasta = Color(hex: 0xF4A33C)
    static let nebo = Color(hex: 0x6EC3F2)
    static let ljubicasta = Color(hex: 0x6D4BC9)
    static let zuta = Color(hex: 0xFFD84D)
    static let crvena = Color(svetlo: 0xE5385C, tamno: 0xFF4D6D)
    static let crvenaSvetla = Color(svetlo: 0xFFE3EA, tamno: 0x3D1D26)
    /// Tekst na jarkim karticama (žuta, narandžasta) ostaje taman u obe teme.
    static let tinta = Color(hex: 0x151515)
}

extension Font {
    /// Naslov iz kita: Archivo Black, nagnut kao u Figmi. Font nema kurzivni rez,
    /// pa se kosina daje matricom fonta (tačan razmak, za razliku od skew efekta).
    static func naslov(_ velicina: CGFloat) -> Font {
        let skalirano = UIFontMetrics(forTextStyle: .title1).scaledValue(for: velicina)
        guard let osnova = UIFont(name: "ArchivoBlack-Regular", size: skalirano) else { return .system(size: skalirano, weight: .black).italic() }
        let kos = osnova.fontDescriptor.withMatrix(CGAffineTransform(a: 1, b: 0, c: 0.2, d: 1, tx: 0, ty: 0))
        return Font(UIFont(descriptor: kos, size: skalirano))
    }
    static func tekst(_ velicina: CGFloat, _ tezina: Font.Weight = .medium) -> Font {
        .custom("Space Grotesk", size: velicina, relativeTo: .body).weight(tezina)
    }
}

struct Naslov: View {
    let tekst: String
    var velicina: CGFloat = 34
    var body: some View {
        Text(tekst).font(.naslov(velicina)).tracking(-0.5).foregroundStyle(Color.mastilo)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Izražena kartica: debela ivica i tvrda senka.
struct PopKartica: ViewModifier {
    var boja: Color = .kartica
    var radijus: CGFloat = 24
    func body(content: Content) -> some View {
        content
            .background(boja, in: RoundedRectangle(cornerRadius: radijus, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radijus, style: .continuous).stroke(Color.mastilo, lineWidth: 2.5))
            .background(RoundedRectangle(cornerRadius: radijus, style: .continuous).fill(Color.senka).offset(y: 5))
    }
}

/// Mirna bela kartica bez senke.
struct MirnaKartica: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.kartica, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.kremTamnija, lineWidth: 1.5))
    }
}

extension View {
    func pop(_ boja: Color = .kartica, radijus: CGFloat = 24) -> some View { modifier(PopKartica(boja: boja, radijus: radijus)) }
    func mirna() -> some View { modifier(MirnaKartica()) }
}

/// Dugme kao fizičko: pritisak ga spušta na senku.
struct DugmeStil: ButtonStyle {
    enum Vrsta { case primarno, sekundarno, zuto, teal }
    var vrsta: Vrsta = .primarno

    func makeBody(configuration: Configuration) -> some View { DugmeTelo(konfiguracija: configuration, vrsta: vrsta) }
}

/// Telo dugmeta čita da li je omogućeno: onemogućeno je sivo, bez senke (kao u kitu).
private struct DugmeTelo: View {
    let konfiguracija: ButtonStyleConfiguration
    let vrsta: DugmeStil.Vrsta
    @Environment(\.isEnabled) private var omoguceno

    private var boje: (Color, Color) {
        guard omoguceno else { return (.skelet, .sivaTekst) }
        return switch vrsta {
        case .primarno: (.mastilo, .naMastilu)
        case .sekundarno: (.kartica, .mastilo)
        case .zuto: (.zuta, .tinta)
        case .teal: (.teal, .white)
        }
    }

    var body: some View {
        let (pozadina, tekst) = boje
        let pritisnuto = konfiguracija.isPressed
        return konfiguracija.label
            .font(.tekst(16, .bold))
            .foregroundStyle(tekst)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(pozadina, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(omoguceno ? Color.mastilo : Color.kremTamnija, lineWidth: 2))
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(omoguceno ? Color.senka : .clear).offset(y: pritisnuto ? 1 : 4))
            .offset(y: pritisnuto ? 3 : 0)
            .animation(.spring(duration: 0.15), value: pritisnuto)
            .sensoryFeedback(.impact(weight: .light), trigger: pritisnuto) { _, novo in novo }
    }
}

extension ButtonStyle where Self == DugmeStil {
    static var primarno: DugmeStil { DugmeStil(vrsta: .primarno) }
    static var sekundarno: DugmeStil { DugmeStil(vrsta: .sekundarno) }
    static var zuto: DugmeStil { DugmeStil(vrsta: .zuto) }
    static var tealDugme: DugmeStil { DugmeStil(vrsta: .teal) }
}

/// Okruglo dugme sa ikonicom (nazad, zatvori); natpis ide samo u pristupačnost.
struct KrugDugme: View {
    let ikonica: String
    let opis: String
    let radnja: () -> Void
    var body: some View {
        Button(action: radnja) {
            Image(systemName: ikonica).font(.system(size: 17, weight: .bold)).foregroundStyle(Color.mastilo)
                .frame(width: 44, height: 44)
                .background(Color.kartica, in: Circle())
                .overlay(Circle().stroke(Color.kremTamnija, lineWidth: 1.5))
        }
        .accessibilityLabel(opis)
    }
}

/// Oznaka malim verzalom, umesto kapsule.
struct Oznaka: View {
    let tekst: String
    var boja: Color = .sivaTekst
    var body: some View {
        Text(tekst.uppercased()).font(.tekst(11, .bold)).tracking(1.2).foregroundStyle(boja)
    }
}

/// Talasasta tekstura papira iz kita.
struct Papir: View {
    var tamno = false
    var body: some View {
        Canvas { ctx, size in
            let boja = tamno ? Color(hex: 0x24221E) : Color(svetlo: 0xE7E1D0, tamno: 0x24221E)
            var y: CGFloat = 14
            while y < size.height {
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y))
                var x: CGFloat = 0
                while x < size.width {
                    p.addCurve(to: CGPoint(x: x + 80, y: y), control1: CGPoint(x: x + 20, y: y - 8), control2: CGPoint(x: x + 60, y: y + 8))
                    x += 80
                }
                ctx.stroke(p, with: .color(boja), lineWidth: 1.2)
                y += 28
            }
        }
        .background(tamno ? Color(hex: 0x12110F) : Color.krem)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

enum Maskota: String { case mimi = "Mimi", zig = "Zig", bloop = "Bloop", lumi = "Lumi" }

struct MaskotaSlika: View {
    let maskota: Maskota
    var velicina: CGFloat = 120
    var body: some View {
        Image(maskota.rawValue).resizable().scaledToFit().frame(width: velicina, height: velicina).accessibilityHidden(true)
    }
}
