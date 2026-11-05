import SwiftUI

/// Animacija pri pokretanju: nastavlja se na sistemski početni ekran (ista tirkizna boja i ikonica na istom mestu),
/// pa maskote iskaču oko ikonice, pojavi se natpis i sve se utopi u aplikaciju (~1,6 s).
struct PocetakView: View {
    let gotovo: () -> Void
    @State private var korak = 0
    @Environment(\.accessibilityReduceMotion) private var manjeKretanja

    private let maskote: [(Maskota, CGFloat, CGFloat, Double)] = [
        (.mimi, -118, -120, -12), (.zig, 122, -110, 10), (.lumi, -112, 128, 8), (.bloop, 116, 132, -8),
    ]

    var body: some View {
        ZStack {
            Color("TealPocetak").ignoresSafeArea()
            // Blagi sjaj iza ikonice, kao na samoj ikonici.
            Circle().fill(.white.opacity(korak >= 1 ? 0.12 : 0)).frame(width: 360).blur(radius: 30)
            ForEach(Array(maskote.enumerated()), id: \.offset) { i, m in
                MaskotaSlika(maskota: m.0, velicina: 92)
                    .rotationEffect(.degrees(m.3))
                    .offset(x: korak >= 1 ? m.1 : 0, y: korak >= 1 ? m.2 : 0)
                    .scaleEffect(korak >= 1 ? 1 : 0.2)
                    .opacity(korak >= 1 ? 1 : 0)
                    .animation(.spring(response: 0.45, dampingFraction: 0.6).delay(Double(i) * 0.06), value: korak)
            }
            Image("Pocetak").resizable().frame(width: 200, height: 200)
                .scaleEffect(korak == 1 ? 1.08 : 1)
                .shadow(color: .black.opacity(0.25), radius: 18, y: 10)
            VStack(spacing: 6) {
                Spacer()
                Text("Librum kviz").font(.naslov(40)).foregroundStyle(.white)
                Text("Znanje osvaja svet").font(.tekst(16, .bold)).foregroundStyle(Color.zuta)
            }
            .padding(.bottom, 90)
            .opacity(korak >= 1 ? 1 : 0)
            .offset(y: korak >= 1 ? 0 : 20)
        }
        .opacity(korak >= 3 ? 0 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Librum kviz")
        .task {
            if manjeKretanja { try? await Task.sleep(for: .milliseconds(500)); gotovo(); return }
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) { korak = 1 }
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(.easeOut(duration: 0.2)) { korak = 2 }
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(.easeIn(duration: 0.35)) { korak = 3 }
            try? await Task.sleep(for: .milliseconds(350))
            gotovo()
        }
    }
}
