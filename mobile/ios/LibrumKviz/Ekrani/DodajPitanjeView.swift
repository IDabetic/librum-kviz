import SwiftUI

/// Predlog pitanja ili reči za vešanje sa mog profila (samo vlasnik profila vidi dugme).
/// Pitanje + tačan + tri netačna; za vešanje pojam, opis i kategorija. Nacrt ostaje na telefonu dok se ne pošalje.
/// Server (RPC posalji_predlog) proverava isto što i veb: duplikate, različite odgovore, dnevni limit.
struct DodajPitanjeView: View {
    enum Vrsta: String, CaseIterable, Codable { case pro, book, vesanje
        var naziv: String { switch self { case .pro: "Opšte znanje"; case .book: "Književnost"; case .vesanje: "Reč za vešanje" } }
    }
    struct Nacrt: Codable, Equatable {
        var vrsta: Vrsta = .pro
        var pitanje = ""
        var tacan = ""
        var netacni = ["", "", ""]
        var zanr = ""
    }
    static let kategorijeVesanja = ["Sport", "Geografija", "Istorija", "Kultura", "Priroda", "Predmeti"]
    private static let kljucNacrta = "nacrtPredloga"

    @Environment(Sesija.self) private var sesija
    @State private var n = Nacrt()
    @State private var stanje: Stanje = .unos
    enum Stanje: Equatable { case unos, salje, poslato, greska(String) }
    var pocetnaVrsta: Vrsta = .pro

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GornjaTraka()
                Naslov(tekst: n.vrsta == .vesanje ? "Dodaj reč" : "Dodaj pitanje", velicina: 32)
                Text("Urednici pregledaju svaki predlog. Kad prođe, ulazi u igru i piše se na tvom profilu.")
                    .font(.tekst(14)).foregroundStyle(Color.sivaTekst)
                PodvuceniIzbor(izbor: $n.vrsta, opcije: Vrsta.allCases.map { ($0, $0.naziv) })
                if n.vrsta == .vesanje {
                    PoljeUnosa(naziv: "Pojam (4–18 slova)", tekst: $n.pitanje)
                    PoljeUnosa(naziv: "Opis, bez samog pojma", tekst: $n.tacan)
                    Text("Kategorija").font(.tekst(14, .semibold))
                    PodvuceniIzbor(izbor: $n.zanr, opcije: Self.kategorijeVesanja.map { ($0, $0) })
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Pitanje").font(.tekst(14, .semibold))
                        TextField("Na primer: Koja reka protiče kroz Beograd i Novi Sad?", text: $n.pitanje, axis: .vertical)
                            .font(.tekst(16)).lineLimit(2...5).padding(14)
                            .background(Color.kartica, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.kremTamnija, lineWidth: 1.5))
                    }
                    PoljeUnosa(naziv: "Tačan odgovor", tekst: $n.tacan, stanje: n.tacan.isEmpty ? .obicno : .uRedu("Tačan"))
                    ForEach(0..<3, id: \.self) { i in PoljeUnosa(naziv: "Netačan odgovor \(i + 1)", tekst: $n.netacni[i]) }
                    if n.vrsta == .book { PoljeUnosa(naziv: "Žanr (nije obavezno)", tekst: $n.zanr) }
                }
                switch stanje {
                case .greska(let p): Label(p, systemImage: "exclamationmark.triangle").font(.tekst(14, .semibold)).foregroundStyle(Color.crvena)
                case .poslato: Label("Poslato. Hvala! Predlog čeka urednika.", systemImage: "checkmark.circle").font(.tekst(14, .semibold)).foregroundStyle(Color.teal)
                default: EmptyView()
                }
                Button { Task { await posalji() } } label: {
                    if stanje == .salje { HStack(spacing: 10) { ProgressView().tint(Color.naMastilu); Text("Šaljem…") } } else { Text("Pošalji") }
                }
                .buttonStyle(.primarno).disabled(!popunjeno || stanje == .salje)
                Button("Sačuvaj nacrt") { sacuvajNacrt(); stanje = .unos }.buttonStyle(.sekundarno).disabled(n == Nacrt())
                if !sesija.prijavljen { Text("Za slanje treba nalog; nacrt možeš da sačuvaš i bez njega.").font(.tekst(13)).foregroundStyle(Color.sivaTekst) }
            }
            .padding(16)
        }
        .background(Papir())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            if let d = UserDefaults.standard.data(forKey: Self.kljucNacrta), let s = try? JSONDecoder().decode(Nacrt.self, from: d) { n = s } else { n.vrsta = pocetnaVrsta }
            if n.vrsta == .vesanje && n.zanr.isEmpty { n.zanr = Self.kategorijeVesanja[0] }
        }
        .onChange(of: n.vrsta) { _, v in if v == .vesanje && !Self.kategorijeVesanja.contains(n.zanr) { n.zanr = Self.kategorijeVesanja[0] } }
        // Izmena briše samo grešku; poruka „Poslato” ostaje dok se ne počne novi predlog.
        .onChange(of: n) { if case .greska = stanje { stanje = .unos } }
    }

    private var popunjeno: Bool {
        !n.pitanje.trimmingCharacters(in: .whitespaces).isEmpty && !n.tacan.trimmingCharacters(in: .whitespaces).isEmpty
            && (n.vrsta == .vesanje || n.netacni.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
    }

    private func sacuvajNacrt() {
        if let d = try? JSONEncoder().encode(n) { UserDefaults.standard.set(d, forKey: Self.kljucNacrta) }
    }

    private func posalji() async {
        sacuvajNacrt()
        guard let t = try? await sesija.vazeciToken() else { stanje = .greska("Prijavi se da bi poslao predlog."); return }
        stanje = .salje
        struct Odgovor: Decodable { let ok: Bool; let greska: String? }
        do {
            let r: Odgovor = try await Supabase.deljeni.rpc("posalji_predlog", [
                "p_segment": n.vrsta.rawValue, "p_pitanje": n.pitanje, "p_tacan": n.tacan,
                "p_netacni": n.vrsta == .vesanje ? [] : n.netacni,
                // Book bez žanra ide u „Razno”, kao na vebu.
                "p_zanr": n.vrsta == .pro ? NSNull() : (n.zanr.isEmpty ? "Razno" : n.zanr),
            ], token: t)
            if r.ok {
                stanje = .poslato
                let vrsta = n.vrsta
                n = Nacrt(vrsta: vrsta)
                UserDefaults.standard.removeObject(forKey: Self.kljucNacrta)
            } else {
                stanje = .greska(r.greska ?? "Predlog nije prihvaćen.")
            }
        } catch {
            stanje = .greska(error.localizedDescription)
        }
    }
}
