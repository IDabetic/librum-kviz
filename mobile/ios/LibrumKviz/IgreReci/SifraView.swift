import SwiftUI

/// Šifra: ukrštenica bez opisa; svaki broj je jedno slovo, isto slovo je uvek isti broj.
struct SifraView: View {
    let z: SifraZ
    let datum: String
    /// U sobi „Igraj sa drugima”: rok i javljanje poena; bez dnevne rang liste.
    var soba: UTakmicenju? = nil
    @Environment(Sesija.self) private var sesija
    @Environment(Napredak.self) private var napredak

    struct Stanje: Codable {
        var dodela: [String: String] = [:]
        var otkriveno: [Int] = []
        var sekundi = 0
        var pomoci = 0
        var gotovo = false
        var resio = false
    }

    @State private var s = Stanje()
    @State private var izabran: Int?
    @State private var poruka: String?
    @State private var polje = ""
    @State private var ishod: Ucitano<IshodReci?> = .ucitava
    @State private var potvrdaPredaje = false

    private var polja: [Int: [Int: Int]] { Dictionary(grouping: z.polja, by: { $0[1] }).mapValues { Dictionary(uniqueKeysWithValues: $0.map { ($0[0], $0[2]) }) } }
    private var okvir: (x0: Int, x1: Int, y0: Int, y1: Int) {
        (z.polja.map { $0[0] }.min() ?? 0, z.polja.map { $0[0] }.max() ?? 0, z.polja.map { $0[1] }.min() ?? 0, z.polja.map { $0[1] }.max() ?? 0)
    }
    private var zakljucano: Set<Int> { Set(z.data + s.otkriveno) }

    var body: some View {
        OkvirIgreReci(igra: .sifra, sekundi: $s.sekundi, gotovo: s.gotovo, rok: soba?.rok, pomoc: pomoc) {
            ScrollView {
                VStack(spacing: 12) {
                    mreza
                    PorukaReci(tekst: poruka)
                    if s.gotovo && soba == nil {
                        KrajIgreReci(igra: .sifra, resio: s.resio, resenje: (z.reci ?? []).map { $0.uppercased() }.joined(separator: " · "), sekundi: s.sekundi, ishod: ishod)
                    }
                }
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
            if !s.gotovo {
                HStack {
                    Text(izabran.map { "Broj \($0)" } ?? "Dodirni polje").font(.tekst(14, .semibold)).foregroundStyle(Color.sivaTekst)
                    Spacer()
                    Button { potvrdaPredaje = true } label: { Image(systemName: "flag").font(.system(size: 17, weight: .bold)).frame(width: 44, height: 36) }
                        .buttonStyle(BezPrigusenja()).foregroundStyle(Color.mastilo).accessibilityLabel("Predaj")
                }
                PoljeUnosaReci(tekst: $polje, duzina: 2, natpis: "Slovo za izabrani broj", brisi: obrisi)
                    .onChange(of: polje) { _, n in if let z = n.last { polje = ""; upisi(String(z)) } }
                    .padding(.bottom, 8)
            }
        }
        .onAppear(perform: ucitaj)
        .onChange(of: s.sekundi) { _, n in
            IgreReci.sacuvajPartiju(.sifra, datum: datum, s)
            if let soba, n >= soba.rok, !s.gotovo { zavrsi(resio: false) }
        }
        .overlay {
            if potvrdaPredaje {
                Dijalog(naslov: "Predaješ šifru?", tekst: "Videćeš sva slova, a rezultat ulazi kao nerešen.", potvrda: "Predaj", odustani: "Igraj još", opasno: true) {
                    potvrdaPredaje = false
                    zavrsi(resio: false)
                } zatvori: { potvrdaPredaje = false }
            }
        }
    }

    private var mreza: some View {
        let o = okvir
        let kolona = o.x1 - o.x0 + 1
        return GeometryReader { g in
            let v = min(46, (g.size.width - CGFloat(kolona - 1) * 3) / CGFloat(kolona))
            VStack(spacing: 3) {
                ForEach(o.y0...o.y1, id: \.self) { y in
                    HStack(spacing: 3) {
                        ForEach(o.x0...o.x1, id: \.self) { x in
                            if let broj = polja[y]?[x] { polje(broj, velicina: v) } else { Color.clear.frame(width: v, height: v) }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: CGFloat(o.y1 - o.y0 + 1) * 49)
    }

    private func polje(_ broj: Int, velicina: CGFloat) -> some View {
        let slovo = s.gotovo ? z.kljuc["\(broj)"] : (zakljucano.contains(broj) ? z.kljuc["\(broj)"] : s.dodela["\(broj)"])
        let stanje: StanjePloce = zakljucano.contains(broj) || (s.gotovo && s.resio) ? .istaknuto : (izabran == broj ? .izabrano : (slovo == nil ? .prazno : .uneto))
        return Button { if !zakljucano.contains(broj) && !s.gotovo { izabran = broj } } label: {
            Ploca(slovo: slovo?.uppercased() ?? "", stanje: stanje, velicina: velicina, broj: broj)
        }
        .buttonStyle(BezPrigusenja())
        .accessibilityLabel("Broj \(broj), " + (slovo.map { "slovo \($0.uppercased())" } ?? "prazno"))
    }

    private func upisi(_ slovo: String) {
        guard let b = izabran else { return poruci("Prvo dodirni polje.") }
        let malo = slovo.lowercased()
        if zakljucano.contains(where: { z.kljuc["\($0)"] == malo }) { return poruci("To slovo je već otkriveno.") }
        for (k, v) in s.dodela where v == malo { s.dodela[k] = nil }
        s.dodela["\(b)"] = malo
        izabran = sledeciPrazan(posle: b)
        IgreReci.sacuvajPartiju(.sifra, datum: datum, s)
        soba?.javi(MojRezultat(poeni: tacnihBrojeva * 2, tacnih: tacnihBrojeva, odigrano: s.dodela.count, ms: s.sekundi * 1000))
        proveri()
    }

    /// Brojevi kojima je upisano tačno slovo (bez datih i otkrivenih).
    private var tacnihBrojeva: Int { s.dodela.filter { z.kljuc[$0.key] == $0.value }.count }

    private func obrisi() {
        guard let b = izabran else { return }
        s.dodela["\(b)"] = nil
    }

    private func sledeciPrazan(posle b: Int) -> Int? {
        let brojevi = Set(z.polja.map { $0[2] }).filter { !zakljucano.contains($0) && s.dodela["\($0)"] == nil }.sorted()
        return brojevi.first { $0 > b } ?? brojevi.first
    }

    private func proveri() {
        let brojevi = Set(z.polja.map { $0[2] }).filter { !zakljucano.contains($0) }
        guard brojevi.allSatisfy({ s.dodela["\($0)"] != nil }) else { return }
        if brojevi.allSatisfy({ s.dodela["\($0)"] == z.kljuc["\($0)"] }) { zavrsi(resio: true) } else { poruci("Sva polja su popunjena, ali nešto nije tačno.") }
    }

    private func poruci(_ tekst: String) {
        poruka = tekst
        Task { try? await Task.sleep(for: .seconds(1.8)); if poruka == tekst { poruka = nil } }
    }

    /// Pomoć otkriva izabrani broj (ili prvi pogrešan/prazan) i zaključava ga.
    private func pomoc() {
        let kandidati = Set(z.polja.map { $0[2] }).filter { !zakljucano.contains($0) && s.dodela["\($0)"] != z.kljuc["\($0)"] }
        guard let b = izabran.flatMap({ kandidati.contains($0) ? $0 : nil }) ?? kandidati.sorted().first else { return }
        s.otkriveno.append(b)
        let tacno = z.kljuc["\(b)"]
        for (k, v) in s.dodela where v == tacno { s.dodela[k] = nil }
        s.dodela["\(b)"] = nil
        s.pomoci += 1
        izabran = sledeciPrazan(posle: b)
        IgreReci.sacuvajPartiju(.sifra, datum: datum, s)
        proveri()
    }

    private func zavrsi(resio: Bool) {
        s.gotovo = true
        s.resio = resio
        izabran = nil
        IgreReci.sacuvajPartiju(.sifra, datum: datum, s)
        if let soba {
            let poeni = resio ? 50 + soba.bonus(s.sekundi) : tacnihBrojeva * 2
            return soba.javi(MojRezultat(poeni: max(0, poeni - 5 * s.pomoci), tacnih: tacnihBrojeva, odigrano: s.dodela.count, ms: s.sekundi * 1000, gotov: true))
        }
        var kljuc = s.dodela
        for b in zakljucano { kljuc["\(b)"] = z.kljuc["\(b)"] }
        let stanje = s
        Task {
            ishod = await posaljiRezultatReci(.sifra, odgovor: ["kljuc": kljuc], resio: resio, sekundi: stanje.sekundi,
                                              pomoci: stanje.pomoci, sesija: sesija, napredak: napredak)
        }
    }

    private func ucitaj() {
        if let sacuvano: Stanje = IgreReci.ucitajPartiju(.sifra, datum: datum) {
            s = sacuvano
            if s.gotovo { ishod = IgreReci.deljeno.upisano(.sifra) }
        }
    }
}
