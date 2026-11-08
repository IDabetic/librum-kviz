import SwiftUI

/// Mini ukrštenica: polja sa brojevima, opis izabrane reči iznad tastature.
struct UkrstenicaView: View {
    let z: UkrstenicaZ
    let datum: String
    /// U sobi „Igraj sa drugima”: rok i javljanje poena; bez dnevne rang liste.
    var soba: UTakmicenju? = nil
    @Environment(Sesija.self) private var sesija
    @Environment(Napredak.self) private var napredak

    struct Stanje: Codable {
        var unos: [String: String] = [:]
        var otkriveno: [String] = []
        var sekundi = 0
        var pomoci = 0
        var gotovo = false
        var resio = false
    }

    struct Polje: Hashable { let x, y: Int; var kljuc: String { "\(x),\(y)" } }

    @State private var s = Stanje()
    @State private var izabrano: Polje?
    @State private var smer = "v"
    @State private var proveri = false
    @State private var poruka: String?
    @State private var polje = ""
    @State private var ishod: Ucitano<IshodReci?> = .ucitava
    @State private var potvrdaPredaje = false

    /// Rešenje po polju.
    private var resenje: [Polje: String] {
        var m: [Polje: String] = [:]
        for r in z.reci { for (i, slovo) in AzbukaReci.slova(r.rec).enumerated() { m[polje(r, i)] = slovo.lowercased() } }
        return m
    }

    private func polje(_ r: UkrstenicaZ.Rec, _ i: Int) -> Polje { r.smer == "v" ? Polje(x: r.x + i, y: r.y) : Polje(x: r.x, y: r.y + i) }
    private func polja(_ r: UkrstenicaZ.Rec) -> [Polje] { (0..<r.rec.count).map { polje(r, $0) } }
    private var brojevi: [Polje: Int] { Dictionary(z.reci.map { (Polje(x: $0.x, y: $0.y), $0.broj) }, uniquingKeysWith: { a, _ in a }) }
    private var redReci: [UkrstenicaZ.Rec] { z.reci.sorted { ($0.smer == "v" ? 0 : 1, $0.broj) < ($1.smer == "v" ? 0 : 1, $1.broj) } }

    private var tekucaRec: UkrstenicaZ.Rec? {
        guard let p = izabrano else { return nil }
        let sadrze = z.reci.filter { polja($0).contains(p) }
        return sadrze.first { $0.smer == smer } ?? sadrze.first
    }

    var body: some View {
        OkvirIgreReci(igra: .ukrstenica, sekundi: $s.sekundi, gotovo: s.gotovo, rok: soba?.rok, pomoc: pomoc) {
            ScrollView {
                VStack(spacing: 12) {
                    mreza
                    PorukaReci(tekst: poruka)
                    if s.gotovo && soba == nil {
                        KrajIgreReci(igra: .ukrstenica, resio: s.resio, resenje: redReci.map { "\($0.broj). \($0.rec.uppercased())" }.joined(separator: " · "),
                                     sekundi: s.sekundi, ishod: ishod)
                    }
                }
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
            if !s.gotovo {
                opis
                PoljeUnosaReci(tekst: $polje, duzina: 2, natpis: "Kucaj slova", brisi: obrisi)
                    .onChange(of: polje) { _, n in if let z = n.last { polje = ""; upisi(String(z)) } }
                    .padding(.bottom, 8)
            }
        }
        .onAppear(perform: ucitaj)
        .onChange(of: s.sekundi) { _, n in
            IgreReci.sacuvajPartiju(.ukrstenica, datum: datum, s)
            if let soba, n >= soba.rok, !s.gotovo { zavrsi(resio: false) }
        }
        .overlay {
            if potvrdaPredaje {
                Dijalog(naslov: "Predaješ ukrštenicu?", tekst: "Videćeš sve reči, a rezultat ulazi kao nerešen.", potvrda: "Predaj", odustani: "Igraj još", opasno: true) {
                    potvrdaPredaje = false
                    zavrsi(resio: false)
                } zatvori: { potvrdaPredaje = false }
            }
        }
    }

    private var opis: some View {
        HStack(spacing: 8) {
            Button { pomeriRec(-1) } label: { Image(systemName: "chevron.left").font(.system(size: 16, weight: .bold)).frame(width: 36, height: 44) }
                .buttonStyle(BezPrigusenja()).accessibilityLabel("Prethodna reč")
            VStack(spacing: 2) {
                if let r = tekucaRec {
                    Text("\(r.broj) \(r.smer == "v" ? "vodoravno" : "uspravno") · \(r.rec.count) slova").font(.tekst(12, .bold)).foregroundStyle(Color.sivaTekst)
                    Text(r.opis).font(.tekst(15, .semibold)).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8)
                } else {
                    Text("Dodirni polje").font(.tekst(15, .semibold)).foregroundStyle(Color.sivaTekst)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            Button { pomeriRec(1) } label: { Image(systemName: "chevron.right").font(.system(size: 16, weight: .bold)).frame(width: 36, height: 44) }
                .buttonStyle(BezPrigusenja()).accessibilityLabel("Sledeća reč")
            Button { potvrdaPredaje = true } label: { Image(systemName: "flag").font(.system(size: 16, weight: .bold)).frame(width: 36, height: 44) }
                .buttonStyle(BezPrigusenja()).accessibilityLabel("Predaj")
        }
        .foregroundStyle(Color.mastilo)
        .padding(.horizontal, 6).padding(.vertical, 4)
        .background(Color.tealSvetla, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var mreza: some View {
        let sva = Array(resenje.keys)
        let x0 = sva.map(\.x).min() ?? 0, x1 = sva.map(\.x).max() ?? 0, y0 = sva.map(\.y).min() ?? 0, y1 = sva.map(\.y).max() ?? 0
        let kolona = x1 - x0 + 1
        let istaknuta = Set(tekucaRec.map(polja) ?? [])
        return GeometryReader { g in
            let v = min(46, (g.size.width - CGFloat(kolona - 1) * 3) / CGFloat(kolona))
            VStack(spacing: 3) {
                ForEach(y0...y1, id: \.self) { y in
                    HStack(spacing: 3) {
                        ForEach(x0...x1, id: \.self) { x in
                            let p = Polje(x: x, y: y)
                            if let tacno = resenje[p] {
                                let slovo = s.gotovo ? tacno : s.unos[p.kljuc]
                                let pogresno = proveri && slovo != nil && slovo != tacno
                                let stanje: StanjePloce = s.otkriveno.contains(p.kljuc) || (s.gotovo && s.resio) ? .tacno
                                    : izabrano == p ? .izabrano : pogresno ? .mesto : istaknuta.contains(p) ? .istaknuto : (slovo == nil ? .prazno : .uneto)
                                Button { dodir(p) } label: { Ploca(slovo: slovo?.uppercased() ?? "", stanje: stanje, velicina: v, broj: brojevi[p]) }
                                    .buttonStyle(BezPrigusenja())
                                    .accessibilityLabel((brojevi[p].map { "Broj \($0), " } ?? "") + (slovo.map { "slovo \($0.uppercased())" } ?? "prazno"))
                            } else {
                                Color.clear.frame(width: v, height: v)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: CGFloat(y1 - y0 + 1) * 49)
    }

    private func dodir(_ p: Polje) {
        guard !s.gotovo else { return }
        if izabrano == p {
            smer = smer == "v" ? "u" : "v"   // drugi dodir menja smer
        } else {
            izabrano = p
            if !z.reci.contains(where: { $0.smer == smer && polja($0).contains(p) }) { smer = smer == "v" ? "u" : "v" }
        }
    }

    private func pomeriRec(_ korak: Int) {
        let lista = redReci
        let i = tekucaRec.flatMap { lista.firstIndex(of: $0) } ?? -1
        let r = lista[(i + korak + lista.count) % lista.count]
        smer = r.smer
        izabrano = polja(r).first { s.unos[$0.kljuc] == nil } ?? polja(r).first
    }

    private func upisi(_ slovo: String) {
        guard let p = izabrano, let r = tekucaRec else { return poruci("Prvo dodirni polje.") }
        if !s.otkriveno.contains(p.kljuc) { s.unos[p.kljuc] = slovo.lowercased() }
        proveri = false
        let lista = polja(r)
        if let i = lista.firstIndex(of: p), i + 1 < lista.count { izabrano = lista[i + 1] }
        IgreReci.sacuvajPartiju(.ukrstenica, datum: datum, s)
        soba?.javi(MojRezultat(poeni: tacnihPolja, tacnih: tacnihPolja, odigrano: s.unos.count, ms: s.sekundi * 1000))
        proveriKraj()
    }

    private var tacnihPolja: Int { resenje.filter { s.unos[$0.key.kljuc] == $0.value }.count }

    private func obrisi() {
        guard let p = izabrano, let r = tekucaRec else { return }
        if s.unos[p.kljuc] != nil, !s.otkriveno.contains(p.kljuc) {
            s.unos[p.kljuc] = nil
        } else {
            let lista = polja(r)
            if let i = lista.firstIndex(of: p), i > 0 {
                izabrano = lista[i - 1]
                if !s.otkriveno.contains(lista[i - 1].kljuc) { s.unos[lista[i - 1].kljuc] = nil }
            }
        }
    }

    private func proveriKraj() {
        guard resenje.keys.allSatisfy({ s.unos[$0.kljuc] != nil }) else { return }
        if resenje.allSatisfy({ s.unos[$0.key.kljuc] == $0.value }) { zavrsi(resio: true) } else {
            proveri = true
            poruci("Žuta polja nisu tačna.")
        }
    }

    private func poruci(_ tekst: String) {
        poruka = tekst
        Task { try? await Task.sleep(for: .seconds(1.8)); if poruka == tekst { poruka = nil } }
    }

    /// Pomoć: tačno slovo u izabranom polju (ili prvom praznom).
    private func pomoc() {
        let p = izabrano.flatMap { s.otkriveno.contains($0.kljuc) ? nil : $0 }
            ?? resenje.keys.sorted { ($0.y, $0.x) < ($1.y, $1.x) }.first { s.unos[$0.kljuc] != resenje[$0] }
        guard let p, let tacno = resenje[p] else { return }
        s.unos[p.kljuc] = tacno
        s.otkriveno.append(p.kljuc)
        s.pomoci += 1
        IgreReci.sacuvajPartiju(.ukrstenica, datum: datum, s)
        proveriKraj()
    }

    private func zavrsi(resio: Bool) {
        s.gotovo = true
        s.resio = resio
        izabrano = nil
        IgreReci.sacuvajPartiju(.ukrstenica, datum: datum, s)
        if let soba {
            let poeni = resio ? 50 + soba.bonus(s.sekundi) : tacnihPolja
            return soba.javi(MojRezultat(poeni: max(0, poeni - 5 * s.pomoci), tacnih: tacnihPolja, odigrano: s.unos.count, ms: s.sekundi * 1000, gotov: true))
        }
        let reci = z.reci.map { r in polja(r).map { s.unos[$0.kljuc] ?? "" }.joined() }
        let stanje = s
        Task {
            ishod = await posaljiRezultatReci(.ukrstenica, odgovor: ["reci": reci], resio: resio, sekundi: stanje.sekundi,
                                              pomoci: stanje.pomoci, sesija: sesija, napredak: napredak)
        }
    }

    private func ucitaj() {
        if let sacuvano: Stanje = IgreReci.ucitajPartiju(.ukrstenica, datum: datum) {
            s = sacuvano
            if s.gotovo { ishod = IgreReci.deljeno.upisano(.ukrstenica) }
        }
        if izabrano == nil, !s.gotovo, let prva = redReci.first { smer = prva.smer; izabrano = polja(prva).first }
    }
}
