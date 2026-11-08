import SwiftUI

/// Lanac: od prve do poslednje reči menjajući po jedno slovo; svaki korak mora biti reč iz rečnika.
struct LanacView: View {
    let z: LanacZ
    let datum: String
    /// U sobi „Igraj sa drugima”: rok i javljanje poena; bez dnevne rang liste.
    var soba: UTakmicenju? = nil
    @Environment(Sesija.self) private var sesija
    @Environment(Napredak.self) private var napredak

    struct Stanje: Codable {
        var put: [String] = []
        var sekundi = 0
        var pomoci = 0
        var nagovestaj: String?
        var gotovo = false
        var resio = false
    }

    @State private var s = Stanje()
    @State private var unos = ""
    @State private var poruka: String?
    @State private var drma: CGFloat = 0
    @State private var ishod: Ucitano<IshodReci?> = .ucitava
    @State private var potvrdaPredaje = false
    private var duzina: Int { z.od.count }

    var body: some View {
        OkvirIgreReci(igra: .lanac, sekundi: $s.sekundi, gotovo: s.gotovo, rok: soba?.rok, pomoc: pomoc) {
            ScrollViewReader { skrol in
                ScrollView {
                    VStack(spacing: 8) {
                        Text("Najkraće: \(z.najmanje) koraka · ti: \(max(0, s.put.count - 1))").font(.tekst(14, .semibold)).foregroundStyle(Color.sivaTekst)
                        ForEach(Array(s.put.enumerated()), id: \.offset) { i, rec in
                            red(rec, prethodna: i > 0 ? s.put[i - 1] : nil, stanje: i == 0 ? .istaknuto : (rec == z.doReci ? .tacno : .uneto))
                        }
                        if !s.gotovo {
                            red(unos.padding(toLength: duzina, withPad: " ", startingAt: 0), prethodna: nil, stanje: .prazno, unos: true)
                                .modifier(Drmanje(korak: drma))
                            Image(systemName: "arrow.down").font(.system(size: 16, weight: .bold)).foregroundStyle(Color.sivaTekst).padding(.vertical, 2)
                            red(z.doReci, prethodna: nil, stanje: .istaknuto).accessibilityLabel("Cilj: \(z.doReci)")
                            PorukaReci(tekst: poruka ?? s.nagovestaj.map { "Pomoć: sledeći korak je \($0.uppercased())" })
                        } else if soba == nil {
                            KrajIgreReci(igra: .lanac, resio: s.resio, resenje: "Jedan od najkraćih puteva: " + z.primer.map { $0.uppercased() }.joined(separator: " → "),
                                         sekundi: s.sekundi, ishod: ishod)
                        }
                        Color.clear.frame(height: 1).id("dno")
                    }
                    .padding(.bottom, 12)
                }
                .scrollIndicators(.hidden)
                .onChange(of: s.put.count) { _, _ in withAnimation { skrol.scrollTo("dno") } }
            }
            if !s.gotovo {
                HStack(spacing: 10) {
                    Button { vratiKorak() } label: {
                        Label("Vrati korak", systemImage: "arrow.uturn.backward").labelStyle(.iconOnly).font(.system(size: 18, weight: .bold))
                            .frame(maxWidth: .infinity).frame(height: 40)
                    }
                    .buttonStyle(.sekundarno).controlSize(.small).disabled(s.put.count < 2)
                    Button { potvrdaPredaje = true } label: {
                        Label("Predaj", systemImage: "flag").labelStyle(.iconOnly).font(.system(size: 18, weight: .bold))
                            .frame(maxWidth: .infinity).frame(height: 40)
                    }
                    .buttonStyle(.sekundarno).controlSize(.small)
                }
                PoljeUnosaReci(tekst: $unos, duzina: duzina, potvrdi: potvrdi)
                    .padding(.bottom, 8)
            }
        }
        .onAppear(perform: ucitaj)
        .onChange(of: s.sekundi) { _, n in
            IgreReci.sacuvajPartiju(.lanac, datum: datum, s)
            if let soba, n >= soba.rok, !s.gotovo { zavrsi(resio: false) }
        }
        .overlay {
            if potvrdaPredaje {
                Dijalog(naslov: "Predaješ lanac?", tekst: "Videćeš jedan od najkraćih puteva, a rezultat ulazi kao nerešen.", potvrda: "Predaj", odustani: "Igraj još", opasno: true) {
                    potvrdaPredaje = false
                    zavrsi(resio: false)
                } zatvori: { potvrdaPredaje = false }
            }
        }
    }

    /// Red pločica; slovo koje se promenilo u odnosu na prethodnu reč je žuto.
    private func red(_ rec: String, prethodna: String?, stanje: StanjePloce, unos: Bool = false) -> some View {
        let slova = AzbukaReci.slova(rec)
        let pre = prethodna.map(AzbukaReci.slova)
        return HStack(spacing: 7) {
            ForEach(0..<slova.count, id: \.self) { i in
                let promena = pre.map { i < $0.count && $0[i] != slova[i] } ?? false
                let prazno = slova[i] == " "
                Ploca(slovo: prazno ? "" : slova[i], stanje: unos ? (prazno ? .prazno : .uneto) : (promena && stanje == .uneto ? .mesto : stanje), velicina: 52)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(unos ? "Unos: \(self.unos)" : rec)
    }

    private func potvrdi() {
        let r = unos.lowercased()
        guard let poslednja = s.put.last else { return }
        guard r.count == duzina else { return pogresno("Reč ima \(duzina) slova.") }
        guard AzbukaReci.razlikaJednoSlovo(poslednja, r) else { return pogresno("Promeni tačno jedno slovo.") }
        guard r == z.doReci || RecnikReci.postoji(r) else { return pogresno("Te reči nema u rečniku.") }
        guard !s.put.contains(r) else { return pogresno("Ta reč je već u lancu.") }
        s.put.append(r)
        s.nagovestaj = nil
        unos = ""
        Zvuk.pusti(.slovoDa, jacina: 0.4)
        IgreReci.sacuvajPartiju(.lanac, datum: datum, s)
        if r == z.doReci { zavrsi(resio: true) }
    }

    private func vratiKorak() {
        guard s.put.count > 1 else { return }
        s.put.removeLast()
        IgreReci.sacuvajPartiju(.lanac, datum: datum, s)
    }

    private func pogresno(_ tekst: String) {
        poruka = tekst
        withAnimation(.linear(duration: 0.35)) { drma += 1 }
        Task { try? await Task.sleep(for: .seconds(1.6)); if poruka == tekst { poruka = nil } }
    }

    /// Pomoć: sledeći korak najkraćeg puta od poslednje reči do cilja (pretraga kroz rečnik na telefonu).
    private func pomoc() {
        guard let od = s.put.last, let sledeca = Self.sledeciKorak(od: od, do: z.doReci, iskorisceno: Set(s.put)) else {
            return pogresno("Odavde nema puta, vrati korak.")
        }
        s.nagovestaj = sledeca
        s.pomoci += 1
        IgreReci.sacuvajPartiju(.lanac, datum: datum, s)
    }

    /// Pretraga u širinu kroz reči iste dužine. Primer: sledeciKorak(od: "kosa", do: "kasa") → "kasa".
    static func sledeciKorak(od: String, do cilj: String, iskorisceno: Set<String>) -> String? {
        let reci = RecnikReci.reci.filter { $0.count == od.count }.union([cilj])
        var pret: [String: String] = [od: od]
        var red = [od]
        var i = 0
        while i < red.count {
            let r = red[i]; i += 1
            if r == cilj { break }
            let slova = Array(r)
            for p in slova.indices {
                for z in "abcčćdđefghijklmnoprsštuvzž" where z != slova[p] {
                    var n = slova; n[p] = z
                    let s = String(n)
                    if pret[s] == nil, reci.contains(s), !iskorisceno.contains(s) || s == cilj { pret[s] = r; red.append(s) }
                }
            }
        }
        guard pret[cilj] != nil else { return nil }
        var k = cilj
        while let p = pret[k], p != od { k = p }
        return k
    }

    private func zavrsi(resio: Bool) {
        s.gotovo = true
        s.resio = resio
        IgreReci.sacuvajPartiju(.lanac, datum: datum, s)
        if let soba {
            let koraka = s.put.count - 1
            let poeni = resio ? max(0, max(10, 60 - (koraka - z.najmanje) * 10) + soba.bonus(s.sekundi) - 5 * s.pomoci) : 0
            return soba.javi(MojRezultat(poeni: poeni, tacnih: resio ? 1 : 0, odigrano: koraka, ms: s.sekundi * 1000, gotov: true))
        }
        let stanje = s
        Task {
            ishod = await posaljiRezultatReci(.lanac, odgovor: ["put": stanje.put], resio: resio, sekundi: stanje.sekundi,
                                              pomoci: stanje.pomoci, sesija: sesija, napredak: napredak)
        }
    }

    private func ucitaj() {
        if let sacuvano: Stanje = IgreReci.ucitajPartiju(.lanac, datum: datum) {
            s = sacuvano
            if s.gotovo { ishod = IgreReci.deljeno.upisano(.lanac) }
        }
        if s.put.isEmpty { s.put = [z.od] }
    }
}

extension AzbukaReci {
    /// Primer: razlikaJednoSlovo("kosa", "kasa") → true.
    static func razlikaJednoSlovo(_ a: String, _ b: String) -> Bool {
        a.count == b.count && zip(a, b).filter { $0 != $1 }.count == 1
    }
}
