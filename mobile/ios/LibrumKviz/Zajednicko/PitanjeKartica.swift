import SwiftUI

/// Žuta kartica pitanja iz kita sa tajmerom. Javlja odgovor (indeks ili nil
/// na istek) i proteklo vreme; posle otkrivanja čeka `trajanjeOtkrivanja`.
struct PitanjeKartica: View {
    let oznaka: String
    let prikaz: Prikaz
    var sekundi = Pravila.sekundiPoPitanju
    var dodatak: String? = nil
    var eliminisani: Set<Int> = []
    let gotovo: (_ izabran: Int?, _ ms: Int) -> Void

    @State private var pocetak = Date()
    @State private var izabran: Int?
    @State private var otkriveno = false
    @State private var preostalo: Double = 1

    private let trajanjeOtkrivanja: Duration = .milliseconds(1400)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Oznaka(tekst: oznaka, boja: .mastilo)
                Spacer()
                TimelineView(.periodic(from: .now, by: 0.25)) { kontekst in
                    let ostalo = max(0, Double(sekundi) - kontekst.date.timeIntervalSince(pocetak))
                    Text("\(Int(ostalo.rounded(.up)))").font(.naslov(22)).monospacedDigit()
                        .onChange(of: Int(ostalo)) { _, sec in if sec == 0 && !otkriveno { izaberi(nil) } }
                        .accessibilityLabel("\(Int(ostalo)) sekundi")
                }
            }
            TimelineView(.animation(paused: otkriveno)) { kontekst in
                let deo = max(0, 1 - kontekst.date.timeIntervalSince(pocetak) / Double(sekundi))
                GeometryReader { g in
                    Capsule().fill(.white.opacity(0.6))
                        .overlay(alignment: .leading) {
                            Capsule().fill(deo < 0.34 ? Color.crvena : Color.mastilo).frame(width: g.size.width * deo)
                        }
                }
                .frame(height: 8)
            }
            Naslov(tekst: prikaz.tekst, velicina: 23)
                .padding(.bottom, 4)
            ForEach(Array(prikaz.opcije.enumerated()), id: \.offset) { i, opcija in
                OdgovorDugme(slovo: ["A", "B", "C", "D"][i], tekst: opcija, stanje: stanje(i)) { izaberi(i) }
                    .disabled(otkriveno || eliminisani.contains(i))
                    .opacity(eliminisani.contains(i) && !otkriveno ? 0.3 : 1)
            }
            if otkriveno, let dodatak {
                Text(dodatak).font(.tekst(15, .bold)).foregroundStyle(Color.mastilo)
            }
        }
        .padding(20)
        .pop(.zuta)
        .onAppear { pocetak = Date() }
        .sensoryFeedback(trigger: otkriveno) { _, _ in izabran == prikaz.tacan ? .success : .error }
    }

    private func stanje(_ i: Int) -> OdgovorDugme.Stanje {
        guard otkriveno else { return .obicno }
        if i == prikaz.tacan { return .tacno }
        if i == izabran { return .netacno }
        return .bledo
    }

    private func izaberi(_ i: Int?) {
        guard !otkriveno else { return }
        izabran = i
        otkriveno = true
        let ms = Int(Date().timeIntervalSince(pocetak) * 1000)
        Task {
            try? await Task.sleep(for: trajanjeOtkrivanja)
            gotovo(i, ms)
        }
    }
}

struct OdgovorDugme: View {
    enum Stanje { case obicno, tacno, netacno, bledo }
    let slovo: String
    let tekst: String
    let stanje: Stanje
    let radnja: () -> Void

    var body: some View {
        let (pozadina, ivica, slovoPozadina, slovoBoja): (Color, Color, Color, Color) = switch stanje {
        case .obicno: (.white, .mastilo, .tealSvetla, .teal)
        case .tacno: (.tealSvetla, .teal, .teal, .white)
        case .netacno: (.crvenaSvetla, .crvena, .crvena, .white)
        case .bledo: (.white.opacity(0.45), .clear, .tealSvetla, .teal)
        }
        Button(action: radnja) {
            HStack(spacing: 12) {
                Text(slovo).font(.tekst(15, .bold)).foregroundStyle(slovoBoja)
                    .frame(width: 36, height: 36)
                    .background(slovoPozadina, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(tekst).font(.tekst(16, .semibold)).foregroundStyle(Color.mastilo)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(minHeight: 56)
            .background(pozadina, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(ivica, lineWidth: 2))
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(ivica).offset(y: stanje == .bledo ? 0 : 4))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(slovo): \(tekst)")
    }
}
