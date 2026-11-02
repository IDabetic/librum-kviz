import SwiftUI

/// Praćenje, izazovi i pretraga igrača (tabele pracenja, izazovi; RPC trazi_igrace).
@MainActor
enum Drustvo {
    struct Igrac: Decodable, Identifiable { let id: String; let nadimak: String; let avatar: String?; let pratim: Bool; let prati_mene: Bool }
    struct Brojevi: Decodable { let pratilaca: Int; let prati: Int; let pratim: Bool }
    struct Izazov: Decodable, Identifiable { let id: Int; let od: String; let kod_sobe: String?; let created_at: String }

    static func trazi(_ sesija: Sesija, _ upit: String) async throws -> [Igrac] {
        guard let t = try await sesija.vazeciToken() else { return [] }
        return try await Supabase.deljeni.rpc("trazi_igrace", ["p_upit": upit, "p_broj": 30], token: t)
    }

    static func moji(_ sesija: Sesija) async throws -> [Igrac] {
        guard let t = try await sesija.vazeciToken() else { return [] }
        return try await Supabase.deljeni.rpc("moja_pracenja", [:], token: t)
    }

    static func brojevi(_ id: String) async -> Brojevi? {
        try? await Supabase.deljeni.rpc("broj_pratilaca", ["p_id": id], token: try? await Sesija.trenutna?.vazeciToken())
    }

    /// Prati ili prestaje da prati; true kad je uspelo.
    static func prati(_ sesija: Sesija, id: String, da: Bool) async -> Bool {
        guard let ja = sesija.korisnikId, let t = try? await sesija.vazeciToken() else { return false }
        do {
            if da {
                try await Supabase.deljeni.upisi("pracenja", ["ko": ja, "koga": id], token: t)
            } else {
                _ = try await Supabase.deljeni.zahtev("rest/v1/pracenja", metod: "DELETE", token: t,
                                                       upit: [.init(name: "ko", value: "eq.\(ja)"), .init(name: "koga", value: "eq.\(id)")])
            }
            return true
        } catch { return false }
    }

    static func posaljiIzazov(_ sesija: Sesija, za: String, kod: String) async {
        guard let ja = sesija.korisnikId, let t = try? await sesija.vazeciToken() else { return }
        try? await Supabase.deljeni.upisi("izazovi", ["od": ja, "za": za, "igra": "duel", "kod_sobe": kod], token: t)
    }

    /// Izazovi koji čekaju odgovor (poslednjih 30 minuta, posle toga soba više ne čeka).
    static func dolazni(_ sesija: Sesija) async -> [Izazov] {
        guard let ja = sesija.korisnikId, let t = try? await sesija.vazeciToken() else { return [] }
        let od = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-1800))
        return (try? await Supabase.deljeni.citaj("izazovi", upit: [
            .init(name: "select", value: "id,od,kod_sobe,created_at"), .init(name: "za", value: "eq.\(ja)"),
            .init(name: "status", value: "eq.ceka"), .init(name: "created_at", value: "gte.\(od)"), .init(name: "order", value: "created_at.desc"),
        ], token: t)) ?? []
    }

    static func odgovori(_ sesija: Sesija, izazov: Int, prihvatam: Bool) async {
        guard let t = try? await sesija.vazeciToken() else { return }
        let _: [Izazov]? = try? await Supabase.deljeni.azuriraj("izazovi", filter: [.init(name: "id", value: "eq.\(izazov)")],
                                                                polja: ["status": prihvatam ? "prihvacen" : "odbijen"], token: t)
    }
}

/// Igrači: koga pratiš i ko prati tebe, i pretraga po nadimku da pronađeš nove.
struct IgraciView: View {
    @Environment(Sesija.self) private var sesija
    enum Prikaz: Hashable { case pratim, pratioci }
    @State private var prikaz: Prikaz = .pratim
    @State private var upit = ""
    @State private var moji: Ucitano<[Drustvo.Igrac]> = .ucitava
    @State private var nadjeni: [Drustvo.Igrac]?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GornjaTraka()
            Naslov(tekst: "Igrači", velicina: 36)
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.badge.plus").foregroundStyle(Color.sivaTekst)
                TextField("Pronađi igrača po nadimku", text: $upit).font(.tekst(16)).autocorrectionDisabled().textInputAutocapitalization(.never)
            }
            .padding(.horizontal, 16).frame(height: 54)
            .background(Color.kartica, in: RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.mastilo, lineWidth: 2))
            ScrollView {
                VStack(spacing: 10) {
                    if !sesija.prijavljen {
                        StanjeEkrana(maskota: .zig, naslov: "Prijavi se", tekst: "Praćenje i izazovi rade sa nalogom.")
                    } else if let nadjeni {
                        if nadjeni.isEmpty {
                            StanjeEkrana(maskota: .lumi, naslov: "Nema takvog nadimka", tekst: "Probaj prva dva-tri slova nadimka.")
                        }
                        ForEach(nadjeni) { red($0) }
                    } else {
                        PodvuceniIzbor(izbor: $prikaz, opcije: [(.pratim, "Pratim"), (.pratioci, "Prate me")])
                        switch moji {
                        case .ucitava: ForEach(0..<4, id: \.self) { _ in Skelet(visina: 64, radijus: 18) }
                        case .greska(let p): StanjeEkrana(maskota: .lumi, naslov: "Spisak se nije učitao", tekst: p, dugme: "Pokušaj ponovo") { Task { await ucitaj() } }
                        case .gotovo(let l):
                            let lista = l.filter { prikaz == .pratim ? $0.pratim : $0.prati_mene }
                            if lista.isEmpty {
                                StanjeEkrana(maskota: .bloop, naslov: prikaz == .pratim ? "Još nikog ne pratiš" : "Još te niko ne prati",
                                             tekst: "Pronađi drugare po nadimku gore, ili ih nađi na rang listi i otvori profil.")
                            }
                            ForEach(lista) { red($0) }
                        }
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .padding(.horizontal, 16)
        .background(Papir())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task { await ucitaj() }
        .task(id: upit) {
            let u = upit.trimmingCharacters(in: .whitespaces)
            guard u.count >= 2 else { nadjeni = nil; return }
            try? await Task.sleep(for: .milliseconds(300))
            nadjeni = (try? await Drustvo.trazi(sesija, u)) ?? []
        }
    }

    private func red(_ i: Drustvo.Igrac) -> some View {
        NavigationLink { ProfilIgracaView(id: i.id) } label: {
            HStack(spacing: 12) {
                AvatarSlika(avatar: i.avatar, velicina: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(i.nadimak).font(.tekst(16, .bold))
                    Text(i.pratim && i.prati_mene ? "Pratite se" : i.pratim ? "Pratiš" : i.prati_mene ? "Prati te" : "").font(.tekst(12)).foregroundStyle(Color.sivaTekst)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(Color.sivaTekst)
            }
            .foregroundStyle(Color.mastilo).padding(12).mirna()
        }
        .buttonStyle(.plain)
    }

    private func ucitaj() async {
        guard sesija.prijavljen else { return }
        do { moji = .gotovo(try await Drustvo.moji(sesija)) } catch { moji = .greska(error.localizedDescription) }
    }
}

/// Dolazni izazovi na vrhu sandučeta: prihvati (ulaziš u sobu) ili odbij.
struct DolazniIzazovi: View {
    @Environment(Sesija.self) private var sesija
    @State private var lista: [Drustvo.Izazov] = []
    @State private var imena: [String: String] = [:]
    @State private var ulazak: String?

    var body: some View {
        VStack(spacing: 10) {
            ForEach(lista) { iz in
                HStack(spacing: 12) {
                    Image(systemName: "bolt.fill").foregroundStyle(Color.tinta).frame(width: 44, height: 44).background(Color.zuta, in: Circle())
                        .overlay(Circle().stroke(Color.mastilo, lineWidth: 2))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(imena[iz.od] ?? "Igrač") te izaziva na duel").font(.tekst(15, .bold))
                        Text("Soba \(iz.kod_sobe ?? "")").font(.tekst(12)).foregroundStyle(Color.sivaTekst)
                    }
                    Spacer()
                    Button { Task { await Drustvo.odgovori(sesija, izazov: iz.id, prihvatam: false); await ucitaj() } } label: {
                        Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).frame(width: 40, height: 40).background(Color.udubljeno, in: Circle())
                    }
                    .accessibilityLabel("Odbij")
                    Button { Task { await Drustvo.odgovori(sesija, izazov: iz.id, prihvatam: true); ulazak = iz.kod_sobe } } label: {
                        Image(systemName: "checkmark").font(.system(size: 15, weight: .bold)).foregroundStyle(.white).frame(width: 40, height: 40).background(Color.teal, in: Circle())
                    }
                    .accessibilityLabel("Prihvati")
                }
                .foregroundStyle(Color.mastilo).padding(12).pop(radijus: 20)
            }
        }
        .task { await ucitaj() }
        .navigationDestination(item: $ulazak) { DuelView(kodSobe: $0) }
    }

    private func ucitaj() async {
        lista = await Drustvo.dolazni(sesija)
        let ids = Set(lista.map(\.od)).joined(separator: ",")
        guard !ids.isEmpty else { return }
        struct P: Decodable { let id: String; let nickname: String?; let first_name: String? }
        let p: [P]? = try? await Supabase.deljeni.citaj("public_profiles", upit: [.init(name: "select", value: "id,nickname,first_name"), .init(name: "id", value: "in.(\(ids))")])
        imena = Dictionary(uniqueKeysWithValues: (p ?? []).map { ($0.id, $0.nickname ?? $0.first_name ?? "Igrač") })
    }
}
