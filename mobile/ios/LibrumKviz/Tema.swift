import SwiftUI

// Vizuelni jezik QuizPop kita, isti kao veb (globals.css): krem papir, mastilo,
// debele ivice sa tvrdom senkom, Archivo Black kurziv za naslove.

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
    static let krem = Color(hex: 0xF3F0E6)
    static let kremTamnija = Color(hex: 0xE7E1D0)
    static let mastilo = Color(hex: 0x151515)
    static let sivaTekst = Color(hex: 0x6F6C66)
    static let teal = Color(hex: 0x12907E)
    static let tealSvetla = Color(hex: 0xDFF3EE)
    static let roze = Color(hex: 0xFF5FA2)
    static let narandzasta = Color(hex: 0xF4A33C)
    static let nebo = Color(hex: 0x6EC3F2)
    static let ljubicasta = Color(hex: 0x6D4BC9)
    static let zuta = Color(hex: 0xFFD84D)
    static let crvena = Color(hex: 0xE5385C)
    static let crvenaSvetla = Color(hex: 0xFFE3EA)
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
    var boja: Color = .white
    var radijus: CGFloat = 24
    func body(content: Content) -> some View {
        content
            .background(boja, in: RoundedRectangle(cornerRadius: radijus, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radijus, style: .continuous).stroke(Color.mastilo, lineWidth: 2.5))
            .background(RoundedRectangle(cornerRadius: radijus, style: .continuous).fill(Color.mastilo).offset(y: 5))
    }
}

/// Mirna bela kartica bez senke.
struct MirnaKartica: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.kremTamnija, lineWidth: 1.5))
    }
}

extension View {
    func pop(_ boja: Color = .white, radijus: CGFloat = 24) -> some View { modifier(PopKartica(boja: boja, radijus: radijus)) }
    func mirna() -> some View { modifier(MirnaKartica()) }
}

/// Dugme kao fizičko: pritisak ga spušta na senku.
struct DugmeStil: ButtonStyle {
    enum Vrsta { case primarno, sekundarno, zuto, teal }
    var vrsta: Vrsta = .primarno

    func makeBody(configuration: Configuration) -> some View {
        let (pozadina, tekst): (Color, Color) = switch vrsta {
        case .primarno: (.mastilo, .white)
        case .sekundarno: (.white, .mastilo)
        case .zuto: (.zuta, .mastilo)
        case .teal: (.teal, .white)
        }
        let pritisnuto = configuration.isPressed
        return configuration.label
            .font(.tekst(16, .bold))
            .foregroundStyle(tekst)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(pozadina, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.mastilo, lineWidth: 2))
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.mastilo).offset(y: pritisnuto ? 1 : 4))
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
                .background(Color.white, in: Circle())
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
            let boja = tamno ? Color(hex: 0x24221E) : Color.kremTamnija
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
