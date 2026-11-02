import SwiftUI

/// Najbolji PRO rezultati: ova nedelja ili sve vreme (isti izvor kao veb).
struct RangListaView: View {
    enum Period: String, CaseIterable { case nedelja = "Ova nedelja", sveVreme = "Sve vreme" }

    struct Red: Identifiable { let id: String; let ime: String; let poeni: Int; let pitanja: Int }

    @State private var period: Period = .nedelja
    @State private var redovi: [Red]?
    @State private var greska: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Rang lista").font(.naslov(40))
                Oznaka(tekst: "PRO kviz")
                HStack(spacing: 22) {
                    ForEach(Period.allCases, id: \.self) { p in
                        Button { period = p } label: {
                            Text(p.rawValue).font(.tekst(15, .bold))
                                .foregroundStyle(period == p ? Color.mastilo : .sivaTekst)
                                .padding(.vertical, 8)
                                .overlay(alignment: .bottom) {
                                    Rectangle().fill(period == p ? Color.mastilo : .clear).frame(height: 3)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(period == p ? .isSelected : [])
                    }
                }
                sadrzaj
            }
            .padding(16)
        }
        .background(Papir())
        .toolbar(.hidden, for: .navigationBar)
        .task(id: period) { await ucitaj() }
        .refreshable { await ucitaj() }
    }

    @ViewBuilder private var sadrzaj: some View {
        if let greska {
            VStack(spacing: 12) {
                Text(greska).font(.tekst(15)).foregroundStyle(Color.sivaTekst).multilineTextAlignment(.center)
                Button("Pokušaj ponovo") { Task { await ucitaj() } }.buttonStyle(.sekundarno)
            }
            .padding(20).mirna()
        } else if let redovi, redovi.isEmpty {
            VStack(spacing: 10) {
                MaskotaSlika(maskota: .lumi, velicina: 90)
                Text("Još nema rezultata u ovom periodu. Budi prvi.").font(.tekst(15)).foregroundStyle(Color.sivaTekst)
            }
            .frame(maxWidth: .infinity).padding(24).mirna()
        } else if let redovi {
            VStack(spacing: 0) {
                ForEach(Array(redovi.enumerated()), id: \.element.id) { i, r in
                    HStack(spacing: 14) {
                        Text("\(i + 1)").font(.tekst(15, .bold)).monospacedDigit()
                            .frame(width: 36, height: 36)
                            .background(i == 0 ? Color.zuta : Color.krem, in: RoundedRectangle(cornerRadius: 11))
                            .overlay(RoundedRectangle(cornerRadius: 11).stroke(i == 0 ? Color.mastilo : .clear, lineWidth: 2))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.ime).font(.tekst(16, .semibold)).lineLimit(1)
                            Text("\(r.pitanja) pitanja").font(.tekst(12)).foregroundStyle(Color.sivaTekst)
                        }
                        Spacer()
                        Text("\(r.poeni)").font(.naslov(20)).monospacedDigit()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .accessibilityElement(children: .combine)
                    if i < redovi.count - 1 { Divider().overlay(Color.kremTamnija) }
                }
            }
            .mirna()
        } else {
            ForEach(0..<6, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 14).fill(Color.kremTamnija).frame(height: 56)
            }
            .accessibilityLabel("Učitavanje")
        }
    }

    private func ucitaj() async {
        greska = nil
        struct Sesija: Decodable { let user_id: String; let score: Int; let questions_reached: Int }
        struct Profil: Decodable { let id: String; let nickname: String?; let first_name: String? }
        var upit = [
            URLQueryItem(name: "select", value: "user_id,score,questions_reached"),
            URLQueryItem(name: "order", value: "score.desc"),
            URLQueryItem(name: "limit", value: "100"),
        ]
        if period == .nedelja {
            let od = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-7 * 24 * 3600))
            upit.append(URLQueryItem(name: "created_at", value: "gte.\(od)"))
        }
        do {
            let sesije: [Sesija] = try await Supabase.deljeni.citaj("survivor_sessions", upit: upit)
            var vidjeno = Set<String>()
            let najbolji = sesije.filter { vidjeno.insert($0.user_id).inserted }.prefix(20)
            let ids = najbolji.map(\.user_id).joined(separator: ",")
            let profili: [Profil] = najbolji.isEmpty ? [] : try await Supabase.deljeni.citaj("public_profiles", upit: [
                URLQueryItem(name: "select", value: "id,nickname,first_name"), URLQueryItem(name: "id", value: "in.(\(ids))"),
            ])
            let imena = Dictionary(uniqueKeysWithValues: profili.map { ($0.id, $0.nickname ?? $0.first_name ?? "Igrač") })
            redovi = najbolji.map { Red(id: $0.user_id, ime: imena[$0.user_id] ?? "Igrač", poeni: $0.score, pitanja: $0.questions_reached) }
        } catch {
            greska = error.localizedDescription
        }
    }
}
