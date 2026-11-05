import SwiftUI

// Profil fokusiran na dve glavne igre (vlasnik 04.11): Osvajač (Osvajanje sveta) i Karijera.
// Ostale igre su krugovi sa procentom po bojama (dodir otvara detalje), skorašnja aktivnost je iza dugmeta.

/// Osvajač i Karijera, prvo na profilu.
struct ProfilFokus: View {
    let profil: ProfilIgracaView.Profil
    var body: some View {
        VStack(spacing: 12) {
            OsvajacKartica(profil: profil)
            KarijeraProfilKartica(igrac: profil.id)
        }
    }
}

/// Sve posle glavnih igara: krugovi ostalih igara i dugme za skorašnju aktivnost.
struct ProfilOstalo: View {
    let profil: ProfilIgracaView.Profil
    @State private var skoro = false
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            IgreKrugovi(profil: profil)
            if let s = profil.skoro, !s.isEmpty {
                Button { skoro = true } label: {
                    RedListe(ikonica: "clock.arrow.circlepath", naziv: "Skorašnja aktivnost", vrednost: "poslednjih \(min(10, s.count))")
                }
                .buttonStyle(.plain).mirna()
            }
        }
        // Preko celog ekrana (ne samo preko ovog dela), providna pozadina: izgleda kao DonjiList svuda u app.
        .fullScreenCover(isPresented: $skoro) {
            ZStack {
                DonjiList(zatvori: { skoro = false }) {
                    VStack(alignment: .leading, spacing: 12) {
                        SkorasnjaAktivnost(skoro: Array((profil.skoro ?? []).prefix(10)))
                        Button("Zatvori") { skoro = false }.buttonStyle(.sekundarno)
                    }
                }
            }
            .presentationBackground(.clear)
        }
    }
}

// MARK: Osvajač

struct OsvajacKartica: View {
    let profil: ProfilIgracaView.Profil
    var body: some View {
        let g = profil.igre.first { $0.igra == "osvajanje" }
        let n = profil.osvajanje_nacin
        NavigationLink { OsvajanjeUvodView() } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Oznaka(tekst: "Osvajač", boja: .white.opacity(0.8))
                        Text("Osvajač").font(.naslov(30)).foregroundStyle(.white)
                        Text(titula(g?.partija ?? 0)).font(.tekst(14, .semibold)).foregroundStyle(.white.opacity(0.85))
                    }
                    Spacer()
                    Image("Igra_osvajanje").resizable().scaledToFit().frame(width: 72, height: 72).accessibilityHidden(true)
                }
                HStack(spacing: 8) {
                    cip("\(g?.partija ?? 0)", "partija")
                    cip(g.map { $0.najbolje.srpski } ?? "–", "rekord")
                    cip(g?.tacnost.map { "\($0)%" } ?? "–", "tačno")
                }
                if let n, n.sam + n.savez + n.zajedno > 0 {
                    Text("Sam \(n.sam) · u savezu \(n.savez) · u timu \(n.zajedno)\((n.izdaje ?? 0) > 0 ? " · izdaje \(n.izdaje!)" : "")")
                        .font(.tekst(12, .semibold)).foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding(18)
            .pop(.teal, radijus: 24)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    /// Titula Osvajača po broju partija.
    private func titula(_ p: Int) -> String {
        switch p { case 0: "Još nije krenuo u osvajanje"; case 1..<5: "Izviđač"; case 5..<20: "Vojskovođa"; case 20..<50: "General"; default: "Car sveta" }
    }

    private func cip(_ v: String, _ n: String) -> some View {
        VStack(spacing: 1) {
            Text(v).font(.naslov(20)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
            Text(n).font(.tekst(11, .semibold)).opacity(0.8)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity).padding(.vertical, 8)
        .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: Karijera

struct KarijeraProfilKartica: View {
    let igrac: String?
    @Environment(Sesija.self) private var sesija
    @State private var cv: Karijera.CV?
    @State private var nema = false
    /// Moje stanje (samo na mom profilu): talenti i zamena talenta.
    @State private var stanje: Karijera.Stanje?
    @State private var talentiList = false

    private var moj: Bool { igrac == nil || igrac == sesija.korisnikId }

    var body: some View {
        Group {
            if let cv {
                VStack(spacing: 10) {
                    NavigationLink { KarijeraCVView(igrac: igrac) } label: { kartica(cv) }.buttonStyle(.plain)
                    if moj, let s = stanje, !s.mojiTalenti.isEmpty { talenti(s) }
                }
            } else if nema, igrac == nil || igrac == sesija.korisnikId {
                NavigationLink { KarijeraView() } label: { prazna }.buttonStyle(.plain)
            } else if !nema {
                Skelet(visina: 150, radijus: 24)
            }
        }
        .task(id: igrac) {
            do { cv = try await Karijera.cv(igrac) } catch { nema = true }
            if moj { stanje = try? await Karijera.stanje() }
        }
        .fullScreenCover(isPresented: $talentiList) {
            if let s = stanje {
                ZamenaTalentaList(stanje: s) { stari, novi in
                    talentiList = false
                    Task { if let n = try? await Karijera.promeniTalenat(stari: stari, novi: novi) { stanje = n } }
                } zatvori: { talentiList = false }
                .presentationBackground(.clear)
            }
        }
    }

    /// Talenti na profilu (vlasnik 04.11: ne u meniju Karijere); dodir otvara zamenu talenta.
    private func talenti(_ s: Karijera.Stanje) -> some View {
        Button { talentiList = true } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Oznaka(tekst: "Talenti")
                    Spacer()
                    if (s.zamena_talenta?.dostupno ?? 0) > 0 { Text("zamena dostupna").font(.tekst(12, .bold)).foregroundStyle(Color.teal) }
                    else if let z = s.zamena_talenta { Text("zamena za \(z.do_sledece) tačnih").font(.tekst(12)).foregroundStyle(Color.sivaTekst) }
                }
                HStack(spacing: 8) {
                    ForEach(s.mojiTalenti) { t in
                        VStack(spacing: 4) {
                            Image(systemName: t.ikonica).font(.system(size: 18, weight: .semibold))
                            Text(t.naziv).font(.tekst(12, .bold)).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .foregroundStyle(Color.mastilo)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Color.udubljeno, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(14).mirna()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Talenti: \(s.mojiTalenti.map(\.naziv).joined(separator: ", "))")
    }

    private func kartica(_ c: Karijera.CV) -> some View {
        let firma = c.firme.first
        return HStack(alignment: .bottom, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                Oznaka(tekst: "Karijerista", boja: .white.opacity(0.8))
                Text("\(Karijera.titule[min(c.titula, 3)]) · \(c.pozicija ?? "")").font(.naslov(22)).foregroundStyle(.white)
                    .lineLimit(2).minimumScaleFactor(0.8)
                Text(firma.map { "Vlasnik: \($0.ime)" } ?? c.posao.map { "Radi u: \($0.ime)" } ?? "Bez posla")
                    .font(.tekst(13, .semibold)).foregroundStyle(.white.opacity(0.85)).lineLimit(1)
                HStack(spacing: 8) {
                    cip(Karijera.novac(c.neto), "neto")
                    cip("\(c.ugled)", "ugled")
                    cip("\(c.firme.count)", c.firme.count == 1 ? "firma" : "firmi")
                }
            }
            Image(firma?.slika ?? "Karijera_Zgrada_1_1").resizable().scaledToFit().frame(width: 74).accessibilityHidden(true)
        }
        .padding(18)
        .pop(KarijeraKartica.plava, radijus: 24)
        .accessibilityElement(children: .combine)
    }

    private var prazna: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Oznaka(tekst: "Karijerista", boja: .white.opacity(0.8))
                Text("Kreni u karijeru").font(.naslov(22)).foregroundStyle(.white)
                Text("Probni rad, svoj office i duel za tuđu firmu.").font(.tekst(13, .semibold)).foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
            Image("Karijera_Zgrada_1_1").resizable().scaledToFit().frame(width: 74).accessibilityHidden(true)
        }
        .padding(18)
        .pop(KarijeraKartica.plava, radijus: 24)
    }

    private func cip(_ v: String, _ n: String) -> some View {
        VStack(spacing: 1) {
            Text(v).font(.naslov(17)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            Text(n).font(.tekst(11, .semibold)).opacity(0.8)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity).padding(.vertical, 7)
        .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: Ostale igre kao krugovi

/// Jedna igra kao krug: procenat (tačnost ili uspeh) u boji igre, dodir otvara detalje.
struct IgreKrugovi: View {
    let profil: ProfilIgracaView.Profil
    @State private var otvorena: Krug?

    struct Krug: Identifiable {
        let id: String
        let naziv: String
        let boja: Color
        let procenat: Int?
        let redovi: [(String, String)]
    }

    private static let boje: [String: Color] = ["pro": .ljubicasta, "book": .narandzasta, "vesanje": .nebo, "brzi": .zuta,
                                                "duel": .roze, "slikari": .roze, "tema": .teal, "dnevni": .zuta]

    private var krugovi: [Krug] {
        var l: [Krug] = []
        let veb = profil.veb
        let ids = Set(profil.igre.map(\.igra)).subtracting(["osvajanje", "karijera"])
            .union([veb?.pro, veb?.book, veb?.vesanje, veb?.brzi].enumerated().compactMap { i, g in (g?.partija ?? 0) > 0 ? ["pro", "book", "vesanje", "brzi"][i] : nil })
            .union((veb?.duel).map { ($0.pobeda ?? 0) + ($0.poraza ?? 0) + ($0.nereseno ?? 0) > 0 ? ["duel"] : [] } ?? [])
        for id in ["pro", "book", "slikari", "brzi", "vesanje", "duel", "dnevni", "tema"] where ids.contains(id) {
            let a = profil.igre.first { $0.igra == id }
            let w: ProfilIgracaView.Profil.VebIgra? = switch id { case "pro": veb?.pro; case "book": veb?.book; case "vesanje": veb?.vesanje; case "brzi": veb?.brzi; case "duel": veb?.duel; default: nil }
            var redovi: [(String, String)] = []
            let partija = (a?.partija ?? 0) + (w?.partija ?? 0)
            if partija > 0 { redovi.append(("Partija", partija.srpski)) }
            if let r = max(a?.najbolje ?? 0, w?.rekord ?? 0) as Int?, r > 0 { redovi.append(("Rekord", r.srpski)) }
            if let t = a?.tacnost ?? w?.tacnost { redovi.append(("Tačnost", "\(t)%")) }
            if let ms = a?.prosek_ms { redovi.append(("Prosek odgovora", String(format: "%.1f s", locale: .srpski, Double(ms) / 1000))) }
            if let p = a?.sa_pomoci, p > 0 { redovi.append(("Sa pomoći", "\(p)")) }
            if let m = w?.max_pitanja, m > 0 { redovi.append(("Najdalje", "\(m). pitanje")) }
            if let z = w?.zanr { redovi.append(("Najjači žanr", z)) }
            if id == "vesanje", let p = w?.pobeda { redovi.append(("Pogođenih reči", "\(p)")) }
            if id == "duel", let w { redovi += [("Pobeda", "\(w.pobeda ?? 0)"), ("Poraza", "\(w.poraza ?? 0)"), ("Nerešeno", "\(w.nereseno ?? 0)")] }
            let procenat: Int? = switch id {
            case "duel": w.map { d in let u = (d.pobeda ?? 0) + (d.poraza ?? 0) + (d.nereseno ?? 0); return u > 0 ? (d.pobeda ?? 0) * 100 / u : 0 }
            case "vesanje": a?.tacnost ?? w.map { ($0.pobeda ?? 0) * 100 / max(1, $0.partija ?? 1) }
            default: a?.tacnost ?? w?.tacnost
            }
            let naziv = IgraListe(rawValue: id)?.naziv ?? (id == "tema" ? "Teme" : id == "dnevni" ? "Dnevni izazov" : id.capitalized)
            l.append(Krug(id: id, naziv: naziv, boja: Self.boje[id] ?? .teal, procenat: procenat, redovi: redovi))
        }
        if let p = profil.pitanja, p.odgovora > 0 {
            l.append(Krug(id: "sve", naziv: "Sva pitanja", boja: .teal, procenat: p.tacnost,
                          redovi: [("Odgovora", p.odgovora.srpski), ("Različitih pitanja", p.jedinstvenih.srpski), ("Ponovljenih", p.ponovljenih.srpski)]
                            + (p.prosek_ms.map { [("Prosek odgovora", String(format: "%.1f s", locale: .srpski, Double($0) / 1000))] } ?? [])))
        }
        // Najbolji procenat prvi: u redu koji se svajpuje uvek se vide tri najjače igre (vlasnik 04.11).
        return l.sorted { ($0.procenat ?? -1) > ($1.procenat ?? -1) }
    }

    var body: some View {
        let l = krugovi
        if !l.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Ostale igre").font(.naslov(22))
                // Jedan red: tri kruga staju na ekran, ostale igre se otkrivaju svajpom.
                GeometryReader { g in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(l) { k in
                                Button { otvorena = k } label: { krug(k) }.buttonStyle(.plain)
                                    .frame(width: (g.size.width - 20) / 3)
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.vertical, 8)
                    }
                    .scrollTargetBehavior(.viewAligned)
                }
                .frame(height: 128)
            }
            .fullScreenCover(item: $otvorena) { k in
                ZStack {
                    DonjiList(zatvori: { otvorena = nil }) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 14) {
                                prsten(k, velicina: 64)
                                Naslov(tekst: k.naziv, velicina: 26)
                            }
                            VStack(spacing: 0) {
                                ForEach(Array(k.redovi.enumerated()), id: \.offset) { i, r in
                                    HStack { Text(r.0).font(.tekst(15)); Spacer(); Text(r.1).font(.tekst(15, .bold)).monospacedDigit() }
                                        .padding(.horizontal, 14).padding(.vertical, 11)
                                    if i < k.redovi.count - 1 { Divider().overlay(Color.kremTamnija) }
                                }
                            }
                            .mirna()
                            if k.id == "sve", let pomoci = profil.pomoci { PomocUpotreba(poVrsti: pomoci) }
                            Button("Zatvori") { otvorena = nil }.buttonStyle(.sekundarno)
                        }
                    }
                }
                .presentationBackground(.clear)
            }
        }
    }

    private func krug(_ k: Krug) -> some View {
        VStack(spacing: 6) {
            prsten(k, velicina: 76)
            Text(k.naziv).font(.tekst(12, .bold)).foregroundStyle(Color.mastilo).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(k.naziv), \(k.procenat.map { "\($0) posto" } ?? "bez procenta"), detalji")
        .accessibilityAddTraits(.isButton)
    }

    private func prsten(_ k: Krug, velicina: CGFloat) -> some View {
        ZStack {
            Circle().stroke(k.boja.opacity(0.22), lineWidth: velicina * 0.12)
            Circle().trim(from: 0, to: Double(k.procenat ?? 0) / 100)
                .stroke(k.boja, style: StrokeStyle(lineWidth: velicina * 0.12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(k.procenat.map { "\($0)%" } ?? "–").font(.naslov(velicina * 0.24)).foregroundStyle(Color.mastilo).monospacedDigit()
        }
        .frame(width: velicina, height: velicina)
    }
}
