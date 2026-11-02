import SwiftUI

/// Rang lista iz kita: postolje za prva tri, spisak, tvoje mesto na dnu.
/// Izvor je PRO kviz (survivor_sessions), isti kao veb.
/// Stanja: učitavanje, greška, prazno, prijatelji prazni, nisi rangiran.
struct RangListaView: View {
    enum Period: Hashable { case nedelja, sveVreme, prijatelji }
    struct Red: Identifiable { let id: String; let ime: String; let poeni: Int; let pitanja: Int }

    @Environment(Sesija.self) private var sesija
    @State private var period: Period = .nedelja
    @State private var stanje: Ucitano<[Red]> = .ucitava

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Rang lista").font(.naslov(38))
                    Spacer()
                    Image(systemName: "calendar").font(.system(size: 17, weight: .bold)).frame(width: 44, height: 44)
                        .background(Color.kartica, in: Circle()).overlay(Circle().stroke(Color.kremTamnija, lineWidth: 1.5)).accessibilityHidden(true)
                }
                PodvuceniIzbor(izbor: $period, opcije: [(.nedelja, "Ova nedelja"), (.sveVreme, "Sve vreme"), (.prijatelji, "Prijatelji")])
                if period == .nedelja {
                    Label("Nova lista za \(doPonedeljka) · PRO kviz", systemImage: "clock").font(.tekst(13, .semibold)).foregroundStyle(Color.sivaTekst)
                }
                sadrzaj
            }
            .padding(16)
        }
        .background(Papir())
        .toolbar(.hidden, for: .navigationBar)
        .task(id: period) { await osvezi() }
        .refreshable { await osvezi() }
    }

    @ViewBuilder private var sadrzaj: some View {
        if period == .prijatelji {
            StanjeEkrana(maskota: .zig, naslov: "Još nemaš prijatelje", tekst: "Izazovi nekoga na duel kodom sobe. Prijatelji iz duela će se pojaviti ovde.")
        } else {
            switch stanje {
            case .ucitava:
                HStack(alignment: .bottom, spacing: 10) { Skelet(visina: 90); Skelet(visina: 130); Skelet(visina: 70) }
                ForEach(0..<5, id: \.self) { _ in Skelet(visina: 56) }
            case .greska(let poruka):
                StanjeEkrana(maskota: .lumi, naslov: "Lista se nije učitala", tekst: poruka, dugme: "Pokušaj ponovo") { Task { await osvezi() } }
            case .gotovo(let redovi) where redovi.isEmpty:
                StanjeEkrana(maskota: .bloop, naslov: "Prazno je", tekst: "Još nema rezultata u ovom periodu. Odigraj PRO kviz i budi prvi.")
            case .gotovo(let redovi):
                postolje(Array(redovi.prefix(3)))
                VStack(spacing: 0) {
                    ForEach(Array(redovi.dropFirst(3).enumerated()), id: \.element.id) { i, r in
                        red(i + 4, r)
                        if i < redovi.count - 4 { Divider().overlay(Color.kremTamnija) }
                    }
                }
                .mirna()
                mojeMesto(redovi)
            }
        }
    }

    private func postolje(_ tri: [Red]) -> some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach([1, 0, 2].filter { $0 < tri.count }, id: \.self) { i in
                VStack(spacing: 6) {
                    MaskotaSlika(maskota: [Maskota.zig, .mimi, .lumi][i], velicina: i == 0 ? 64 : 52)
                        .frame(width: i == 0 ? 72 : 60, height: i == 0 ? 72 : 60).background(Color.kartica, in: Circle())
                        .overlay(Circle().stroke(Color.mastilo, lineWidth: 2))
                    Text(tri[i].ime).font(.tekst(13, .bold)).lineLimit(1)
                    Text(tri[i].poeni.formatted()).font(.tekst(12, .bold)).foregroundStyle(Color.naMastilu).padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.mastilo, in: RoundedRectangle(cornerRadius: 8))
                    Text("\(i + 1)").font(.naslov(34)).foregroundStyle(Color.tinta).frame(maxWidth: .infinity).frame(height: [120, 90, 70][i])
                        .background([Color.zuta, .nebo, .roze][i], in: UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14))
                        .overlay(UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14).stroke(Color.mastilo, lineWidth: 2))
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(i + 1). mesto: \(tri[i].ime), \(tri[i].poeni) poena")
            }
        }
        .padding(.top, 8)
    }

    private func red(_ mesto: Int, _ r: Red, istaknut: Bool = false) -> some View {
        HStack(spacing: 14) {
            Text("\(mesto)").font(.tekst(15, .bold)).monospacedDigit().frame(width: 36, height: 36)
                .background(Color.udubljeno, in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 2) {
                Text(r.ime).font(.tekst(16, .semibold)).lineLimit(1)
                Text("\(r.pitanja) pitanja").font(.tekst(12)).foregroundStyle(Color.sivaTekst)
            }
            Spacer()
            Text(r.poeni.formatted()).font(.naslov(20)).monospacedDigit()
        }
        .foregroundStyle(istaknut ? Color.tinta : Color.mastilo)
        .padding(.horizontal, 16).padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func mojeMesto(_ redovi: [Red]) -> some View {
        if let id = sesija.korisnikId, let i = redovi.firstIndex(where: { $0.id == id }) {
            red(i + 1, redovi[i], istaknut: true).pop(.zuta, radijus: 18)
        } else {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.questionmark").font(.system(size: 22))
                VStack(alignment: .leading, spacing: 2) {
                    Text(sesija.prijavljen ? "Još nisi na listi" : "Prijavi se da uđeš na listu").font(.tekst(15, .bold))
                    Text(sesija.prijavljen ? "Odigraj PRO kviz ove nedelje i upiši se." : "Rezultati bez naloga ostaju samo na telefonu.").font(.tekst(13))
                }
                Spacer()
            }
            .foregroundStyle(Color.tinta).padding(14).pop(.zuta, radijus: 18)
        }
    }

    private var doPonedeljka: String {
        var k = Calendar(identifier: .iso8601); k.timeZone = TimeZone(identifier: "Europe/Belgrade")!
        let sledeci = k.nextDate(after: .now, matching: DateComponents(hour: 0, minute: 0, weekday: 2), matchingPolicy: .nextTime) ?? .now
        let s = Int(sledeci.timeIntervalSinceNow)
        return "\(s / 86_400) d \(s % 86_400 / 3600) h"
    }

    private func osvezi() async {
        guard period != .prijatelji else { return }
        if case .gotovo = stanje {} else { stanje = .ucitava }
        do { stanje = .gotovo(try await Self.ucitaj(nedelja: period == .nedelja, limit: 20)) } catch { stanje = .greska(error.localizedDescription) }
    }

    /// Najbolji rezultat po igraču, sa imenima iz javnih profila.
    static func ucitaj(nedelja: Bool, limit: Int) async throws -> [Red] {
        struct Sesija: Decodable { let user_id: String; let score: Int; let questions_reached: Int }
        struct Profil: Decodable { let id: String; let nickname: String?; let first_name: String? }
        var upit = [
            URLQueryItem(name: "select", value: "user_id,score,questions_reached"),
            URLQueryItem(name: "order", value: "score.desc"),
            URLQueryItem(name: "limit", value: "100"),
        ]
        if nedelja {
            let od = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-7 * 24 * 3600))
            upit.append(URLQueryItem(name: "created_at", value: "gte.\(od)"))
        }
        let sesije: [Sesija] = try await Supabase.deljeni.citaj("survivor_sessions", upit: upit)
        var vidjeno = Set<String>()
        let najbolji = sesije.filter { vidjeno.insert($0.user_id).inserted }.prefix(limit)
        guard !najbolji.isEmpty else { return [] }
        let profili: [Profil] = try await Supabase.deljeni.citaj("public_profiles", upit: [
            URLQueryItem(name: "select", value: "id,nickname,first_name"), URLQueryItem(name: "id", value: "in.(\(najbolji.map(\.user_id).joined(separator: ",")))"),
        ])
        let imena = Dictionary(uniqueKeysWithValues: profili.map { ($0.id, $0.nickname ?? $0.first_name ?? "Igrač") })
        return najbolji.map { Red(id: $0.user_id, ime: imena[$0.user_id] ?? "Igrač", poeni: $0.score, pitanja: $0.questions_reached) }
    }
}
