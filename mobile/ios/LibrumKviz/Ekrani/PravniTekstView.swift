import SwiftUI

/// Politika privatnosti i uslovi korišćenja kao ekran u aplikaciji (tekst iz igre/pravno.json, isti za iOS i Android).
struct PravniTekstView: View {
    enum Vrsta: String { case privatnost, uslovi }
    let vrsta: Vrsta

    struct Deo: Decodable { let naslov: String; let tekst: [String] }
    struct Dokument: Decodable { let naslov: String; let azurirano: String; let delovi: [Deo] }

    private var dokument: Dokument? {
        guard let url = Bundle.main.url(forResource: "pravno", withExtension: "json", subdirectory: "igre"),
              let d = try? Data(contentsOf: url),
              let sve = try? JSONDecoder().decode([String: Dokument].self, from: d) else { return nil }
        return sve[vrsta.rawValue]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GornjaTraka()
                if let d = dokument {
                    Naslov(tekst: d.naslov, velicina: 32)
                    Text(d.azurirano).font(.tekst(13)).foregroundStyle(Color.sivaTekst)
                    ForEach(Array(d.delovi.enumerated()), id: \.offset) { _, deo in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(deo.naslov).font(.tekst(17, .bold)).foregroundStyle(Color.mastilo)
                                .accessibilityAddTraits(.isHeader)
                            ForEach(Array(deo.tekst.enumerated()), id: \.offset) { _, t in
                                Text(t).font(.tekst(15)).foregroundStyle(Color.mastilo).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16).mirna()
                    }
                } else {
                    StanjeEkrana(maskota: .lumi, naslov: "Tekst nije pronađen", tekst: "Pišite nam na info@librum.club.")
                }
            }
            .padding(16)
        }
        .background(Papir())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }
}
