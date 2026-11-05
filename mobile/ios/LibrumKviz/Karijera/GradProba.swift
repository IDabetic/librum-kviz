#if DEBUG
import SwiftUI

/// `-gradProba`: kako bi otprilike izgledao grad Karijere (vlasnik 05.11, predlog iz docs/PREGLED-APP-PREDLOZI-2026-11-05.md §3).
/// Samo prikaz sa izmišljenim firmama: ulice u redovima, zgrade po nivou, saobraćaj, balončići iznad zgrada. Prstima se pomera i zumira.
struct GradProba: View {
    struct Firma: Identifiable { let id: Int; let ime: String; let slika: String; let nivo: Int; let balon: String? }

    static let imena = ["Bit d.o.o.", "Lex Partneri", "Med Centar", "Kod i Kafa", "Arhiv 21", "Brza Pošta", "Nova Banka", "Zeleni Grad",
                        "Pixel", "Knjiga+", "Atlas", "Delta IT", "Sudnica", "Ordinacija M", "Startap 7", "Kvant", "Most", "Orbit",
                        "Mozaik", "Sever", "Jug Tim", "Plavi Toranj", "Kula", "Fabrika ideja", "Studio 5", "Vetar", "Sunce", "Zvezda"]
    static let baloni = ["+20 poena", "Traži zaposlene", "Napadnuta!", "Nov rekord", "+35 poena", "Duel danas", "Prekovremeno"]

    /// 4 ulice po 7 zgrada; Korporacija u sredini druge ulice.
    let ulice: [[Firma]] = (0..<4).map { u in
        (0..<7).map { i in
            let n = u * 7 + i
            if u == 1 && i == 3 { return Firma(id: n, ime: "Korporacija", slika: "Karijera_Korporacija_1", nivo: 6, balon: "Probni rad") }
            let nivo = 1 + (n * 7 + u) % 5
            let stil = 1 + (n * 5 + 3) % 8
            return Firma(id: n, ime: imena[n % imena.count], slika: "Karijera_Zgrada_\(nivo)_\(stil)", nivo: nivo, balon: n % 3 == 0 ? baloni[n % baloni.count] : nil)
        }
    }
    @State private var zum: CGFloat = 0.42
    @GestureState private var zumGest: CGFloat = 1

    var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(Array(ulice.enumerated()), id: \.offset) { u, red in ulica(u, red) }
            }
            .frame(width: 7 * 260)
            .scaleEffect(zum * zumGest, anchor: .topLeading)
            .frame(width: 7 * 260 * zum * zumGest, height: 4 * 380 * zum * zumGest, alignment: .topLeading)
        }
        .background(Color(hex: 0x9FD3EE))
        .gesture(MagnifyGesture().updating($zumGest) { v, s, _ in s = v.magnification }.onEnded { zum = min(1.6, max(0.4, zum * $0.magnification)) })
        .overlay(alignment: .top) {
            Text("Grad Karijere · predlog").font(.tekst(14, .bold)).padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color.kartica, in: RoundedRectangle(cornerRadius: 12)).padding(.top, 8)
        }
    }

    private func ulica(_ u: Int, _ red: [Firma]) -> some View {
        ZStack(alignment: .bottom) {
            // Nebo/park iza zgrada, pa trotoar i kolovoz napred.
            LinearGradient(colors: [Color(hex: 0xBFE3F2), Color(hex: 0xDDEFD8)], startPoint: .top, endPoint: .bottom)
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(red) { f in zgrada(f) }
            }
            .padding(.bottom, 70)
            VStack(spacing: 0) {
                Rectangle().fill(Color(hex: 0xD9D4C7)).frame(height: 14)
                ZStack {
                    Rectangle().fill(Color(hex: 0x5E6670))
                    HStack(spacing: 26) { ForEach(0..<40, id: \.self) { _ in Rectangle().fill(.white.opacity(0.8)).frame(width: 22, height: 3) } }
                }
                .frame(height: 56)
            }
            Ulica(mesto: "grad\(u)", gustina: 2.2).frame(height: 300).padding(.bottom, 4)
        }
        .frame(height: 380)
    }

    private func zgrada(_ f: Firma) -> some View {
        VStack(spacing: 4) {
            if let b = f.balon { Balon(tekst: b, kasni: Double(f.id % 5)) }
            Image(f.slika).resizable().scaledToFit()
                .frame(width: 230, height: CGFloat(f.nivo == 6 ? 250 : 90 + f.nivo * 32), alignment: .bottom)
            Text(f.ime).font(.tekst(13, .bold)).foregroundStyle(Color.tinta)
                .padding(.horizontal, 8).padding(.vertical, 3).background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 8))
        }
        .frame(width: 260, alignment: .bottom)
    }
}

/// Balončić kao dim iz dimnjaka: diže se, raste i bledi, pa opet.
private struct Balon: View {
    let tekst: String
    let kasni: Double
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: false)) { k in
            let p = ((k.date.timeIntervalSinceReferenceDate + kasni) / 4).truncatingRemainder(dividingBy: 1)
            Text(tekst).font(.tekst(14, .bold)).foregroundStyle(Color.tinta)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white).shadow(color: .black.opacity(0.12), radius: 4, y: 2))
                .overlay(alignment: .bottom) { HStack(spacing: 4) { Circle().frame(width: 9); Circle().frame(width: 6) }.foregroundStyle(.white).offset(y: 12) }
                .scaleEffect(0.8 + p * 0.3)
                .offset(y: -p * 40)
                .opacity(p < 0.15 ? p / 0.15 : p > 0.75 ? (1 - p) / 0.25 : 1)
        }
        .frame(height: 60)
    }
}
#endif
