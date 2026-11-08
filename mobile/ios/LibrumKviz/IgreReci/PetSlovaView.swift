import SwiftUI

/// Pet slova: pogodi reč dana u šest pokušaja; boje kažu šta je na mestu.
struct PetSlovaView: View {
    let z: PetSlovaZ
    let datum: String
    /// U sobi „Igraj sa drugima”: rok i javljanje poena; bez dnevne rang liste.
    var soba: UTakmicenju? = nil
    @Environment(Sesija.self) private var sesija
    @Environment(Napredak.self) private var napredak

    struct Stanje: Codable {
        var pokusaji: [String] = []
        var sekundi = 0
        var pomoci = 0
        var otkriveno: [Int] = []
        var gotovo = false
        var resio = false
    }

    static let pokusaja = 6
    @State private var s = Stanje()
    @State private var unos = ""
    @State private var poruka: String?
    @State private var drma: CGFloat = 0
    @State private var ishod: Ucitano<IshodReci?> = .ucitava
    private var rec: [String] { AzbukaReci.slova(z.rec) }

    var body: some View {
        OkvirIgreReci(igra: .petSlova, sekundi: $s.sekundi, gotovo: s.gotovo, rok: soba?.rok, pomoc: pomoc) {
            ScrollView {
                VStack(spacing: 14) {
                    mreza
                    // tastatura je telefonska, pa slova kojih nema stoje ovde
                    let nema = stanjaTastature.filter { $0.value == .nema }.keys.sorted()
                    if !nema.isEmpty && !s.gotovo {
                        Text("Nema u reči: " + nema.joined(separator: " ")).font(.tekst(14, .semibold)).foregroundStyle(Color.sivaTekst)
                    }
                    if !s.otkriveno.isEmpty && !s.gotovo {
                        Text("Pomoć: " + rec.enumerated().map { s.otkriveno.contains($0.offset) ? $0.element : "_" }.joined(separator: " "))
                            .font(.tekst(14, .semibold)).foregroundStyle(Color.sivaTekst)
                    }
                    PorukaReci(tekst: poruka)
                    if s.gotovo && soba == nil {
                        KrajIgreReci(igra: .petSlova, resio: s.resio, resenje: "Reč dana: \(z.rec.uppercased())", sekundi: s.sekundi, ishod: ishod)
                    }
                }
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            if !s.gotovo {
                PoljeUnosaReci(tekst: $unos, duzina: 5, potvrdi: potvrdi)
                    .padding(.bottom, 8)
            }
        }
        .onAppear(perform: ucitaj)
        .onChange(of: s.sekundi) { _, n in
            IgreReci.sacuvajPartiju(.petSlova, datum: datum, s)
            if let soba, n >= soba.rok, !s.gotovo { zavrsi(resio: false) }
        }
    }

    private var mreza: some View {
        VStack(spacing: 7) {
            ForEach(0..<Self.pokusaja, id: \.self) { red in
                HStack(spacing: 7) {
                    let slova = slovaReda(red)
                    let ocene = red < s.pokusaji.count ? Self.oceni(AzbukaReci.slova(s.pokusaji[red]), rec) : nil
                    ForEach(0..<5, id: \.self) { i in
                        Ploca(slovo: i < slova.count ? slova[i] : "", stanje: ocene?[i] ?? (i < slova.count ? .uneto : .prazno), velicina: 56)
                    }
                }
                .modifier(Drmanje(korak: red == s.pokusaji.count ? drma : 0))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(opisReda(red))
            }
        }
        .padding(.top, 4)
    }

    private func slovaReda(_ red: Int) -> [String] {
        if red < s.pokusaji.count { return AzbukaReci.slova(s.pokusaji[red]) }
        return red == s.pokusaji.count ? AzbukaReci.slova(unos) : []
    }

    private func opisReda(_ red: Int) -> String {
        guard red < s.pokusaji.count else { return red == s.pokusaji.count ? "Unos: \(unos)" : "Prazan red" }
        let o = Self.oceni(AzbukaReci.slova(s.pokusaji[red]), rec)
        return zip(AzbukaReci.slova(s.pokusaji[red]), o).map { "\($0) \($1 == .tacno ? "na mestu" : $1 == .mesto ? "u reči" : "nema")" }.joined(separator: ", ")
    }

    /// Najbolje poznato stanje svakog slova za tastaturu.
    private var stanjaTastature: [String: StanjePloce] {
        var st: [String: StanjePloce] = [:]
        for p in s.pokusaji {
            for (slovo, o) in zip(AzbukaReci.slova(p), Self.oceni(AzbukaReci.slova(p), rec)) where o.jacina > (st[slovo]?.jacina ?? 0) {
                st[slovo] = o
            }
        }
        return st
    }

    /// Ocena pokušaja u dva prolaza (tačna mesta prvo, pa ostala slova koliko ih još ima).
    /// Primer: oceni(["K","O","S","A","A"], ["K","A","S","A","P"]) → [tacno, nema, tacno, tacno, mesto]
    static func oceni(_ p: [String], _ r: [String]) -> [StanjePloce] {
        var ocena = Array(repeating: StanjePloce.nema, count: p.count)
        var ostalo: [String: Int] = [:]
        for i in p.indices {
            if i < r.count && p[i] == r[i] { ocena[i] = .tacno } else if i < r.count { ostalo[r[i], default: 0] += 1 }
        }
        for i in p.indices where ocena[i] != .tacno {
            if let n = ostalo[p[i]], n > 0 { ocena[i] = .mesto; ostalo[p[i]] = n - 1 }
        }
        return ocena
    }

    private func potvrdi() {
        guard unos.count == 5 else { return pogresno("Reč ima pet slova.") }
        let r = unos.lowercased()
        guard r == z.rec || RecnikReci.postoji(r) else { return pogresno("Te reči nema u rečniku.") }
        guard !s.pokusaji.contains(r) else { return pogresno("Već si probao tu reč.") }
        s.pokusaji.append(r)
        unos = ""
        Zvuk.pusti(r == z.rec ? .slovoDa : .slovoNe, jacina: 0.4)
        if r == z.rec || s.pokusaji.count == Self.pokusaja { zavrsi(resio: r == z.rec) }
        IgreReci.sacuvajPartiju(.petSlova, datum: datum, s)
    }

    private func pogresno(_ tekst: String) {
        poruka = tekst
        withAnimation(.linear(duration: 0.35)) { drma += 1 }
        Task { try? await Task.sleep(for: .seconds(1.6)); if poruka == tekst { poruka = nil } }
    }

    /// Pomoć otkriva jedno slovo koje još nije pogođeno na mestu.
    private func pomoc() {
        let poznato = Set(s.pokusaji.flatMap { p in zip(AzbukaReci.slova(p).indices, Self.oceni(AzbukaReci.slova(p), rec)).filter { $0.1 == .tacno }.map(\.0) })
        guard let i = (0..<5).filter({ !poznato.contains($0) && !s.otkriveno.contains($0) }).randomElement() else { return }
        s.otkriveno.append(i)
        s.pomoci += 1
        IgreReci.sacuvajPartiju(.petSlova, datum: datum, s)
    }

    private func zavrsi(resio: Bool) {
        s.gotovo = true
        s.resio = resio
        IgreReci.sacuvajPartiju(.petSlova, datum: datum, s)
        if let soba {
            let n = s.pokusaji.count
            let poeni = resio ? max(0, (7 - n) * 10 + soba.bonus(s.sekundi) - 5 * s.pomoci) : 0
            return soba.javi(MojRezultat(poeni: poeni, tacnih: resio ? 1 : 0, odigrano: n, ms: s.sekundi * 1000, gotov: true))
        }
        let stanje = s
        Task {
            ishod = await posaljiRezultatReci(.petSlova, odgovor: ["pokusaji": stanje.pokusaji], resio: resio, sekundi: stanje.sekundi,
                                              pomoci: stanje.pomoci, sesija: sesija, napredak: napredak)
        }
    }

    private func ucitaj() {
        if let sacuvano: Stanje = IgreReci.ucitajPartiju(.petSlova, datum: datum) {
            s = sacuvano
            if s.gotovo { ishod = IgreReci.deljeno.upisano(.petSlova) }
        }
    }
}
