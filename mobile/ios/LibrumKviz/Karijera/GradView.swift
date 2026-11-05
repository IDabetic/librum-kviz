import SwiftUI

extension Karijera {
    /// Zgrada u gradu (server `karijera_grad_mapa`, `karijera_trazi_firmu`); parcela određuje mesto na mapi (IsoRaspored).
    struct GradFirma: Decodable, Identifiable, Hashable {
        let id: String
        let ime: String
        let korporacija: Bool
        let nivo: Int
        let stil: Int
        let vlasnik_ime: String
        let parcela: Int
        var balon: String? = nil
        var slika: String { Karijera.slikaZgrade(korporacija: korporacija, nivo: nivo, stil: stil) }
    }
    /// Sve firme po 500 (keyset po parceli), dok ne stignu sve.
    static func mapaGrada() async throws -> [GradFirma] {
        var sve: [GradFirma] = []
        var posle = -1
        while true {
            let deo: [GradFirma] = try await rpc("karijera_grad_mapa", ["p_posle": posle])
            sve += deo
            guard deo.count == 500, let p = deo.last?.parcela else { return sve }
            posle = p
        }
    }
    static func traziFirmu(_ upit: String) async throws -> [GradFirma] { try await rpc("karijera_trazi_firmu", ["p_upit": upit]) }
}

/// Grad Karijere (vlasnik 05.11): jedna velika izometrijska mapa koja raste kako dolaze firme; pomeranje i zum prstima,
/// pretraga „Nađi firmu” vodi do zgrade, dodir na zgradu otvara firmu. Oko grada je zelenilo, van grada se ne ide.
struct GradView: View {
    let stanje: Karijera.Stanje
    let promena: () -> Void

    @State private var firme: [Karijera.GradFirma]?
    @State private var greska: String?
    @State private var upit = ""
    @State private var nadjene: [Karijera.GradFirma] = []
    @State private var oznacena: String?
    @State private var centriraj: Int?
    @State private var izabrana: Karijera.GradFirma?

    private var mojeFirme: Set<String> { Set(stanje.firme.map(\.id)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                GornjaTraka()
                Spacer()
                KrugDugme(ikonica: "location.fill", opis: "Moja firma") {
                    guard let f = firme else { return }
                    let moja = f.first { mojeFirme.contains($0.id) } ?? f.first { $0.id == stanje.posao?.id } ?? f.first { $0.korporacija }
                    if let moja { oznacena = moja.id; centriraj = moja.parcela }
                }
            }
            Naslov(tekst: "Grad", velicina: 34)
            pretraga
            if let greska, firme == nil {
                StanjeEkrana(maskota: .lumi, naslov: "Grad nije učitan", tekst: greska, dugme: "Pokušaj ponovo") { Task { await ucitaj() } }
            } else if let firme {
                IsoGrad(firme: firme, moje: mojeFirme, posao: stanje.posao?.id, oznacena: oznacena, centriraj: $centriraj) { izabrana = $0 }
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.mastilo, lineWidth: 2))
                Text("\(firme.count) firmi · pomeraj i zumiraj prstima, dodirni zgradu").font(.tekst(12, .semibold)).foregroundStyle(Color.sivaTekst)
            } else {
                Skelet(visina: 420, radijus: 24)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Papir())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(item: $izabrana) { f in FirmaView(firmaId: f.id, stanje: stanje, promena: promena) }
        .task { if firme == nil { await ucitaj() } }
    }

    private var pretraga: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Color.sivaTekst)
                TextField("Nađi firmu po imenu", text: $upit).font(.tekst(16)).autocorrectionDisabled().textInputAutocapitalization(.never)
                    .submitLabel(.search)
            }
            .padding(.horizontal, 16).frame(height: 50)
            .background(Color.kartica, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.mastilo, lineWidth: 2))
            .task(id: upit) {
                guard upit.count >= 2 else { nadjene = []; return }
                try? await Task.sleep(for: .milliseconds(300))
                nadjene = (try? await Karijera.traziFirmu(upit)) ?? []
            }
            if !nadjene.isEmpty {
                VStack(spacing: 0) {
                    ForEach(nadjene.prefix(6)) { f in
                        Button { oznacena = f.id; centriraj = f.parcela; upit = ""; nadjene = [] } label: {
                            HStack(spacing: 10) {
                                Image(f.slika).resizable().scaledToFit().frame(width: 34, height: 34)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(f.ime).font(.tekst(15, .bold)).foregroundStyle(Color.mastilo).lineLimit(1)
                                    Text(f.vlasnik_ime).font(.tekst(12)).foregroundStyle(Color.sivaTekst)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if f.id != nadjene.prefix(6).last?.id { Divider().overlay(Color.kremTamnija) }
                    }
                }
                .mirna()
            }
        }
    }

    private func ucitaj() async {
        do { firme = try await Karijera.mapaGrada(); greska = nil } catch { greska = error.localizedDescription }
    }
}
