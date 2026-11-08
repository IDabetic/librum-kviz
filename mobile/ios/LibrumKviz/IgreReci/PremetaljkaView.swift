import SwiftUI

/// Premetaljka: sedam slova u krugu; složi što više reči sa spiska dana, glavna reč koristi sva slova.
struct PremetaljkaView: View {
    let z: PremetaljkaZ
    let datum: String
    /// U sobi „Igraj sa drugima”: rok i javljanje poena; bez dnevne rang liste.
    var soba: UTakmicenju? = nil
    @Environment(Sesija.self) private var sesija
    @Environment(Napredak.self) private var napredak

    struct Stanje: Codable {
        var nadjene: [String] = []
        var redosled: [Int] = Array(0..<7)
        var sekundi = 0
        var pomoci = 0
        var nagovestaj: String?
        var gotovo = false
    }

    @State private var s = Stanje()
    @State private var izabrana: [Int] = []
    @State private var poruka: String?
    @State private var drma: CGFloat = 0
    @State private var ishod: Ucitano<IshodReci?> = .ucitava
    @State private var potvrdaKraja = false

    private var resio: Bool { s.nadjene.contains(z.glavna) }
    private var unos: String { izabrana.map { z.slova[$0] }.joined() }

    var body: some View {
        OkvirIgreReci(igra: .premetaljka, sekundi: $s.sekundi, gotovo: s.gotovo, rok: soba?.rok, pomoc: pomoc) {
            ScrollView {
                VStack(spacing: 16) {
                    napredakTraka
                    if s.gotovo && soba == nil {
                        KrajIgreReci(igra: .premetaljka, resio: resio, resenje: "Glavna reč: \(z.glavna.uppercased()) · našao si \(s.nadjene.count) od \(z.reci.count)",
                                     sekundi: s.sekundi, ishod: ishod)
                        propustene
                    } else {
                        trenutnaRec
                        krug
                        PorukaReci(tekst: poruka ?? s.nagovestaj.map { "Pomoć: \($0)" })
                        dugmad
                    }
                    nadjeneReci
                }
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear(perform: ucitaj)
        .onChange(of: s.sekundi) { _, n in
            IgreReci.sacuvajPartiju(.premetaljka, datum: datum, s)
            if let soba, n >= soba.rok, !s.gotovo { zavrsi() }
        }
        .overlay {
            if potvrdaKraja {
                Dijalog(naslov: "Završiti igru?", tekst: resio ? "Rezultat ide na rang listu sa \(s.nadjene.count) reči." : "Glavnu reč još nisi našao. Posle kraja vidiš sve reči.",
                        potvrda: "Završi", odustani: "Igraj još", opasno: false) {
                    potvrdaKraja = false
                    zavrsi()
                } zatvori: { potvrdaKraja = false }
            }
        }
    }

    private var napredakTraka: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(s.nadjene.count) od \(z.reci.count) reči").font(.tekst(16, .bold))
                Text(resio ? "Glavna reč je nađena" : "Glavna reč: 7 slova").font(.tekst(13)).foregroundStyle(resio ? Color.teal : Color.sivaTekst)
            }
            Spacer()
            Text("\(poeni)").font(.naslov(24)).monospacedDigit().accessibilityLabel("\(poeni) poena")
        }
        .padding(14).mirna()
    }

    private var poeni: Int { s.nadjene.reduce(0) { $0 + ($1 == z.glavna ? 15 : $1.count - 2) } }
    /// U sobi: isti poeni minus pomoći (rok je isti za sve, pa brzina ne nosi dodatak).
    private var poeniSobe: Int { max(0, poeni - 5 * s.pomoci) }

    private var trenutnaRec: some View {
        HStack(spacing: 5) {
            if izabrana.isEmpty {
                Text("Dodirni slova").font(.tekst(15)).foregroundStyle(Color.sivaTekst).frame(height: 44)
            }
            ForEach(Array(izabrana.enumerated()), id: \.offset) { _, i in Ploca(slovo: z.slova[i].uppercased(), stanje: .uneto, velicina: 44) }
        }
        .frame(height: 48)
        .modifier(Drmanje(korak: drma))
        .accessibilityLabel(izabrana.isEmpty ? "Prazna reč" : "Reč: \(unos)")
    }

    private var krug: some View {
        GeometryReader { g in
            let c = CGPoint(x: g.size.width / 2, y: g.size.height / 2)
            let r = min(g.size.width, g.size.height) / 2 - 36
            ZStack {
                Circle().stroke(Color.kremTamnija, lineWidth: 2).frame(width: r * 2, height: r * 2).position(c)
                ForEach(0..<7, id: \.self) { mesto in
                    let i = s.redosled[mesto]
                    let ugao = Double(mesto) / 7 * 2 * .pi - .pi / 2
                    let izabrano = izabrana.contains(i)
                    Button { dodir(i) } label: {
                        Ploca(slovo: z.slova[i].uppercased(), stanje: izabrano ? .nema : .tacno, velicina: 60)
                    }
                    .buttonStyle(BezPrigusenja())
                    .disabled(izabrano)
                    .position(x: c.x + r * cos(ugao), y: c.y + r * sin(ugao))
                    .accessibilityLabel("Slovo \(z.slova[i].uppercased())" + (izabrano ? ", iskorišćeno" : ""))
                }
            }
        }
        .frame(height: 280)
        .sensoryFeedback(.selection, trigger: izabrana)
    }

    private var dugmad: some View {
        HStack(spacing: 14) {
            dugme("delete.left", "Obriši poslednje slovo") { if !izabrana.isEmpty { izabrana.removeLast() } }
            dugme("shuffle", "Izmešaj slova") { withAnimation(.spring(duration: 0.4)) { s.redosled.shuffle() } }
            dugme("checkmark", "Potvrdi reč", jako: true) { potvrdi() }
            dugme("flag.checkered", "Završi igru") { potvrdaKraja = true }
        }
    }

    private func dugme(_ ikonica: String, _ opis: String, jako: Bool = false, radnja: @escaping () -> Void) -> some View {
        Button(action: radnja) {
            Image(systemName: ikonica).font(.system(size: 20, weight: .bold))
                .foregroundStyle(jako ? Color.naMastilu : Color.mastilo)
                .frame(width: 58, height: 52)
                .background(jako ? Color.mastilo : Color.kartica, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.mastilo, lineWidth: 2))
        }
        .buttonStyle(BezPrigusenja())
        .accessibilityLabel(opis)
    }

    private var nadjeneReci: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !s.nadjene.isEmpty {
                Oznaka(tekst: "Nađene reči")
                Text(s.nadjene.sorted { ($0.count, $0) > ($1.count, $1) }.map { $0.uppercased() }.joined(separator: " · "))
                    .font(.tekst(15, .semibold)).foregroundStyle(Color.mastilo).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var propustene: some View {
        let ostale = z.reci.filter { !s.nadjene.contains($0) }
        if !ostale.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Oznaka(tekst: "Propuštene reči")
                Text(ostale.map { $0.uppercased() }.joined(separator: " · ")).font(.tekst(15)).foregroundStyle(Color.sivaTekst)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func dodir(_ i: Int) {
        guard !izabrana.contains(i) else { return }
        izabrana.append(i)
    }

    private func potvrdi() {
        let r = unos
        defer { izabrana = [] }
        guard r.count >= 3 else { return pogresno("Najmanje tri slova.") }
        guard !s.nadjene.contains(r) else { return pogresno("Tu reč si već našao.") }
        guard z.reci.contains(r) else { return pogresno(RecnikReci.postoji(r) ? "Te reči nema na današnjem spisku." : "Te reči nema u rečniku.") }
        s.nadjene.append(r)
        if s.nagovestaj != nil { s.nagovestaj = nil }
        Zvuk.pusti(r == z.glavna ? .osvojeno : .slovoDa, jacina: 0.4)
        poruka = r == z.glavna ? "Glavna reč! +15" : "+\(r.count - 2)"
        Task { try? await Task.sleep(for: .seconds(1.4)); poruka = nil }
        IgreReci.sacuvajPartiju(.premetaljka, datum: datum, s)
        soba?.javi(MojRezultat(poeni: poeniSobe, tacnih: s.nadjene.count, odigrano: s.nadjene.count, ms: s.sekundi * 1000))
        if s.nadjene.count == z.reci.count { zavrsi() }
    }

    private func pogresno(_ tekst: String) {
        poruka = tekst
        withAnimation(.linear(duration: 0.35)) { drma += 1 }
        Task { try? await Task.sleep(for: .seconds(1.6)); if poruka == tekst { poruka = nil } }
    }

    /// Pomoć: jedna nenađena reč sa prvim slovom i dužinom (prvo glavna).
    private func pomoc() {
        let cilj = resio ? z.reci.filter { !s.nadjene.contains($0) }.randomElement() : z.glavna
        guard let cilj else { return }
        s.nagovestaj = cilj.prefix(1).uppercased() + String(repeating: " _", count: cilj.count - 1)
        s.pomoci += 1
        IgreReci.sacuvajPartiju(.premetaljka, datum: datum, s)
    }

    private func zavrsi() {
        s.gotovo = true
        IgreReci.sacuvajPartiju(.premetaljka, datum: datum, s)
        if let soba {
            return soba.javi(MojRezultat(poeni: poeniSobe, tacnih: s.nadjene.count, odigrano: s.nadjene.count, ms: s.sekundi * 1000, gotov: true))
        }
        let stanje = s
        Task {
            ishod = await posaljiRezultatReci(.premetaljka, odgovor: ["reci": stanje.nadjene], resio: stanje.nadjene.contains(z.glavna),
                                              sekundi: stanje.sekundi, pomoci: stanje.pomoci, sesija: sesija, napredak: napredak)
        }
    }

    private func ucitaj() {
        if let sacuvano: Stanje = IgreReci.ucitajPartiju(.premetaljka, datum: datum) {
            s = sacuvano
            if s.gotovo { ishod = IgreReci.deljeno.upisano(.premetaljka) }
        }
    }
}
