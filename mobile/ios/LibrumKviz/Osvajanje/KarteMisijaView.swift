import SwiftUI

/// Izvlačenje tajne misije (vlasnik 04.11.2026): posle izbora država igrač dobija red okrenutih karata,
/// prevlači ih i dodirom okreće jednu; ta misija je njegova. Ponuda i raspored su svaki put drugi (OsvajanjeModel.napraviPonuduMisija).
struct KarteMisijaView: View {
    let model: OsvajanjeModel
    let ponuda: [String]
    @State private var izvucena: String?
    @Environment(\.accessibilityReduceMotion) private var manjeKretanja

    private static let sirinaKarte: CGFloat = 236
    private static let visinaKarte: CGFloat = 330

    var body: some View {
        ZStack {
            Color.senka.opacity(0.94).ignoresSafeArea()
            VStack(spacing: 18) {
                VStack(spacing: 6) {
                    Oznaka(tekst: "Tajna misija · vidi je samo tvoj tim", boja: .roze)
                    Text(izvucena == nil ? "Izvuci svoju misiju" : "Tvoja misija").font(.naslov(32)).foregroundStyle(.white)
                    Text(izvucena == nil ? "Prevuci karte i dodirni jednu." : "Ispuni misiju i drži je do svog sledećeg poteza: pobeđuješ.")
                        .font(.tekst(15, .semibold)).foregroundStyle(.white.opacity(0.8))
                }
                .multilineTextAlignment(.center).padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 14) {
                        ForEach(Array(ponuda.enumerated()), id: \.element) { i, id in
                            karta(id, redni: i)
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, 40, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
                .frame(height: Self.visinaKarte + 20)
                .scrollDisabled(izvucena != nil)

                if izvucena != nil {
                    Button("Kreni u osvajanje") { model.zavrsiPostavku() }
                        .buttonStyle(.zuto).padding(.horizontal, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Text("\(ponuda.count) karata").font(.tekst(13, .bold)).foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .transition(.opacity)
    }

    private func karta(_ id: String, redni: Int) -> some View {
        let okrenuta = izvucena == id
        return ZStack {
            lice(id).opacity(okrenuta ? 1 : 0).rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            poledjina(redni).opacity(okrenuta ? 0 : 1)
        }
        .frame(width: Self.sirinaKarte, height: Self.visinaKarte)
        .rotation3DEffect(.degrees(okrenuta && !manjeKretanja ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .opacity(izvucena == nil || okrenuta ? 1 : 0.25)
        .scaleEffect(izvucena != nil && !okrenuta ? 0.92 : 1)
        .onTapGesture {
            guard izvucena == nil else { return }
            model.izvuciMisiju(id)
            withAnimation(.spring(duration: 0.6, bounce: 0.2)) { izvucena = id }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: izvucena)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(okrenuta ? "Tvoja misija: \(model.stanje.tekstMisije(id))" : "Okrenuta karta \(redni + 1) od \(ponuda.count)")
        .accessibilityHint(izvucena == nil ? "Dodirni da izvučeš ovu misiju" : "")
    }

    /// Poleđina: ista za sve karte, da se ne vidi šta je ispod.
    private func poledjina(_ redni: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22).fill(Color.teal)
            Circle().fill(.white.opacity(0.12)).frame(width: 260).offset(x: 90, y: 120)
            Circle().fill(.white.opacity(0.08)).frame(width: 160).offset(x: -80, y: -110)
            VStack(spacing: 14) {
                Image(systemName: "flag.checkered").font(.system(size: 54, weight: .bold)).foregroundStyle(.white)
                Text("TAJNA MISIJA").font(.tekst(15, .heavy)).tracking(2).foregroundStyle(.white)
                Text("\(redni + 1)").font(.naslov(28)).foregroundStyle(Color.zuta)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.tinta, lineWidth: 3))
    }

    private func lice(_ id: String) -> some View {
        let tim = model.mojTim ?? ""
        return VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "flag.checkered").font(.system(size: 26, weight: .bold)).foregroundStyle(Color.teal)
            Text(model.stanje.tekstMisije(id)).font(.naslov(24)).foregroundStyle(Color.mastilo)
                .fixedSize(horizontal: false, vertical: true).minimumScaleFactor(0.7)
            if let meta = model.stanje.metaMisije[tim], let ime = model.stanje.igraci.first(where: { $0.tim == meta })?.ime {
                Text("Meta: \(ime)").font(.tekst(16, .bold)).foregroundStyle(Color.crvena)
            }
            Spacer(minLength: 0)
            Text("Ako je niko ne ispuni, posle poslednjeg kruga pobeđuje najviše poena.")
                .font(.tekst(12, .semibold)).foregroundStyle(Color.sivaTekst)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.kartica, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.tinta, lineWidth: 3))
    }
}
