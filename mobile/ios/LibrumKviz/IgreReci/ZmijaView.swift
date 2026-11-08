import SwiftUI

/// Zmija: reči teme dana popunjavaju celu mrežu; svaka je put kroz susedna polja. Prevuci prstom da je označiš.
struct ZmijaView: View {
    let z: ZmijaZ
    let datum: String
    /// U sobi „Igraj sa drugima”: rok i javljanje poena; bez dnevne rang liste.
    var soba: UTakmicenju? = nil
    @Environment(Sesija.self) private var sesija
    @Environment(Napredak.self) private var napredak

    struct Stanje: Codable {
        var nadjene: [String] = []
        var nagovestaj: [[Int]] = []
        var sekundi = 0
        var pomoci = 0
        var gotovo = false
        var resio = false
    }

    struct Tacka: Hashable { let x, y: Int }

    @State private var s = Stanje()
    @State private var put: [Tacka] = []
    @State private var poruka: String?
    @State private var drma: CGFloat = 0
    @State private var ishod: Ucitano<IshodReci?> = .ucitava
    @State private var potvrdaPredaje = false
    private let razmak: CGFloat = 6

    private func slovo(_ t: Tacka) -> String {
        let red = Array(z.slova[t.y])
        return t.x < red.count ? String(red[t.x]).uppercased() : ""
    }

    private var nadjenaPolja: [Tacka: Int] {
        var m: [Tacka: Int] = [:]
        for (i, r) in z.reci.enumerated() where s.nadjene.contains(r.rec) || (s.gotovo) { for p in r.put { m[Tacka(x: p[0], y: p[1])] = i } }
        return m
    }

    var body: some View {
        OkvirIgreReci(igra: .zmija, sekundi: $s.sekundi, gotovo: s.gotovo, podnaslov: "Tema dana", rok: soba?.rok, pomoc: pomoc) {
            ScrollView {
                VStack(spacing: 14) {
                    VStack(spacing: 2) {
                        Text(z.tema).font(.naslov(26)).foregroundStyle(Color.mastilo)
                        Text("\(s.nadjene.count) od \(z.reci.count) reči").font(.tekst(14, .semibold)).foregroundStyle(Color.sivaTekst)
                    }
                    Text(put.isEmpty ? " " : put.map(slovo).joined())
                        .font(.tekst(22, .bold)).foregroundStyle(Color.mastilo).frame(height: 28)
                        .modifier(Drmanje(korak: drma))
                    mreza
                    PorukaReci(tekst: poruka)
                    if s.gotovo {
                        if soba == nil { KrajIgreReci(igra: .zmija, resio: s.resio, resenje: z.reci.map { $0.rec.uppercased() }.joined(separator: " · "), sekundi: s.sekundi, ishod: ishod) }
                    } else {
                        Button { potvrdaPredaje = true } label: { Label("Predaj", systemImage: "flag").labelStyle(.iconOnly).font(.system(size: 18, weight: .bold)) }
                            .buttonStyle(.sekundarno).controlSize(.small).frame(width: 90).accessibilityLabel("Predaj")
                    }
                }
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .scrollDisabled(!put.isEmpty)
        }
        .onAppear(perform: ucitaj)
        .onChange(of: s.sekundi) { _, n in
            IgreReci.sacuvajPartiju(.zmija, datum: datum, s)
            if let soba, n >= soba.rok, !s.gotovo { zavrsi(resio: false) }
        }
        .overlay {
            if potvrdaPredaje {
                Dijalog(naslov: "Predaješ zmiju?", tekst: "Videćeš sve reči, a rezultat ulazi kao nerešen.", potvrda: "Predaj", odustani: "Igraj još", opasno: true) {
                    potvrdaPredaje = false
                    zavrsi(resio: false)
                } zatvori: { potvrdaPredaje = false }
            }
        }
    }

    private var mreza: some View {
        GeometryReader { g in
            let v = min(58, (g.size.width - CGFloat(z.sirina - 1) * razmak) / CGFloat(z.sirina))
            let korak = v + razmak
            let sirina = CGFloat(z.sirina) * korak - razmak
            let nadjena = nadjenaPolja
            let pomoc = Set(s.nagovestaj.map { Tacka(x: $0[0], y: $0[1]) })
            ZStack(alignment: .topLeading) {
                // linije nađenih reči i tekućeg poteza, ispod pločica
                Path { p in
                    for r in z.reci where s.nadjene.contains(r.rec) || s.gotovo {
                        for (i, t) in r.put.enumerated() {
                            let c = CGPoint(x: CGFloat(t[0]) * korak + v / 2, y: CGFloat(t[1]) * korak + v / 2)
                            if i == 0 { p.move(to: c) } else { p.addLine(to: c) }
                        }
                    }
                }
                .stroke(Color.teal, style: StrokeStyle(lineWidth: v * 0.42, lineCap: .round, lineJoin: .round))
                Path { p in
                    for (i, t) in put.enumerated() {
                        let c = CGPoint(x: CGFloat(t.x) * korak + v / 2, y: CGFloat(t.y) * korak + v / 2)
                        if i == 0 { p.move(to: c) } else { p.addLine(to: c) }
                    }
                }
                .stroke(Color.zuta, style: StrokeStyle(lineWidth: v * 0.42, lineCap: .round, lineJoin: .round))
                ForEach(0..<z.visina, id: \.self) { y in
                    ForEach(0..<z.sirina, id: \.self) { x in
                        let t = Tacka(x: x, y: y)
                        let stanje: StanjePloce = put.contains(t) ? .izabrano : nadjena[t] != nil ? .tacno : pomoc.contains(t) ? .istaknuto : .uneto
                        Ploca(slovo: slovo(t), stanje: stanje, velicina: v)
                            .position(x: CGFloat(x) * korak + v / 2, y: CGFloat(y) * korak + v / 2)
                    }
                }
            }
            .frame(width: sirina, height: CGFloat(z.visina) * korak - razmak)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { d in prevuci(d.location, korak: korak, v: v) }
                    .onEnded { _ in pusti() }
            )
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Mreža slova: " + z.slova.joined(separator: ", "))
        }
        .frame(height: CGFloat(z.visina) * 64)
        .sensoryFeedback(.selection, trigger: put)
    }

    private func prevuci(_ l: CGPoint, korak: CGFloat, v: CGFloat) {
        guard !s.gotovo else { return }
        let x = Int(l.x / korak), y = Int(l.y / korak)
        guard x >= 0, y >= 0, x < z.sirina, y < z.visina else { return }
        // samo središnji deo pločice hvata prst, da dijagonalni prelaz ne pokupi susede
        let cx = CGFloat(x) * korak + v / 2, cy = CGFloat(y) * korak + v / 2
        guard abs(l.x - cx) < v * 0.4, abs(l.y - cy) < v * 0.4 else { return }
        let t = Tacka(x: x, y: y)
        guard nadjenaPolja[t] == nil else { return }
        if let i = put.firstIndex(of: t) {
            if i == put.count - 2 { put.removeLast() }   // povratak prstom skida poslednje slovo
            return
        }
        if let zadnja = put.last, abs(zadnja.x - x) + abs(zadnja.y - y) != 1 { return }
        put.append(t)
    }

    private func pusti() {
        defer { put = [] }
        guard put.count >= 2 else { return }
        let rec = put.map(slovo).joined().lowercased()
        let polja = Set(put.map { [$0.x, $0.y] })
        if let r = z.reci.first(where: { !s.nadjene.contains($0.rec) && $0.rec == rec && Set($0.put) == polja }) {
            s.nadjene.append(r.rec)
            s.nagovestaj = []
            Zvuk.pusti(.slovoDa, jacina: 0.4)
            IgreReci.sacuvajPartiju(.zmija, datum: datum, s)
            soba?.javi(MojRezultat(poeni: s.nadjene.count * 10, tacnih: s.nadjene.count, odigrano: s.nadjene.count, ms: s.sekundi * 1000))
            if s.nadjene.count == z.reci.count { zavrsi(resio: true) }
        } else if z.reci.contains(where: { $0.rec == rec && !s.nadjene.contains(rec) }) {
            pogresno("Prava reč, ali je u mreži na drugom mestu.")
        } else {
            pogresno(RecnikReci.postoji(rec) ? "Nije iz teme dana." : "To nije reč.")
        }
    }

    private func pogresno(_ tekst: String) {
        poruka = tekst
        withAnimation(.linear(duration: 0.35)) { drma += 1 }
        Task { try? await Task.sleep(for: .seconds(1.6)); if poruka == tekst { poruka = nil } }
    }

    /// Pomoć: prvo i drugo slovo jedne nenađene reči svetle.
    private func pomoc() {
        guard let r = z.reci.first(where: { !s.nadjene.contains($0.rec) }) else { return }
        s.nagovestaj = Array(r.put.prefix(2))
        s.pomoci += 1
        IgreReci.sacuvajPartiju(.zmija, datum: datum, s)
    }

    private func zavrsi(resio: Bool) {
        s.gotovo = true
        s.resio = resio
        IgreReci.sacuvajPartiju(.zmija, datum: datum, s)
        if let soba {
            let poeni = s.nadjene.count * 10 + (resio ? 20 + soba.bonus(s.sekundi) : 0)
            return soba.javi(MojRezultat(poeni: max(0, poeni - 5 * s.pomoci), tacnih: s.nadjene.count, odigrano: s.nadjene.count, ms: s.sekundi * 1000, gotov: true))
        }
        let stanje = s
        Task {
            ishod = await posaljiRezultatReci(.zmija, odgovor: ["reci": stanje.nadjene], resio: resio, sekundi: stanje.sekundi,
                                              pomoci: stanje.pomoci, sesija: sesija, napredak: napredak)
        }
    }

    private func ucitaj() {
        if let sacuvano: Stanje = IgreReci.ucitajPartiju(.zmija, datum: datum) {
            s = sacuvano
            if s.gotovo { ishod = IgreReci.deljeno.upisano(.zmija) }
        }
    }
}
