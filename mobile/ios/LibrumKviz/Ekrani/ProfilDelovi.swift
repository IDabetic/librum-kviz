import SwiftUI

// MARK: Profil kao Instagram / Librum eBook: zaglavlje, brojevi, „o meni”, statistike sa veba i iz aplikacije.

/// Zaglavlje profila: avatar levo, brojevi desno (partija, pratilaca, prati), ispod ime, grad, „o meni”.
/// Radnje (Uredi profil, ili Prati i Izazovi) prosleđuje ekran, jer se razlikuju za moj i tuđi profil.
struct ProfilZaglavlje<Radnje: View>: View {
    let profil: ProfilIgracaView.Profil
    var nivo: Int? = nil
    @ViewBuilder let radnje: Radnje

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 18) {
                AvatarSlika(avatar: profil.avatar, velicina: 88)
                    .overlay(alignment: .bottom) {
                        if let nivo {
                            Text("NV \(nivo)").font(.tekst(11, .bold)).foregroundStyle(Color.naMastilu).padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.mastilo, in: RoundedRectangle(cornerRadius: 8)).offset(y: 8)
                        }
                    }
                HStack(spacing: 0) {
                    broj(profil.partija ?? profil.igre.reduce(0) { $0 + $1.partija }, "partija")
                    if let id = profil.id {
                        NavigationLink { PracenjaView(id: id, vrsta: .pratioci) } label: { broj(profil.pratilaca ?? 0, "pratilaca") }.buttonStyle(.plain)
                        NavigationLink { PracenjaView(id: id, vrsta: .prati) } label: { broj(profil.prati ?? 0, "prati") }.buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(profil.nadimak).font(.naslov(24))
                if let ime = profil.ime, ime != profil.nadimak { Text(ime).font(.tekst(14, .semibold)) }
                if let bio = profil.bio, !bio.isEmpty { Text(bio).font(.tekst(14)).fixedSize(horizontal: false, vertical: true) }
                HStack(spacing: 12) {
                    if let grad = profil.grad, !grad.isEmpty { Label(grad, systemImage: "mappin") }
                    if let od = profil.od?.prefix(4) { Label("od \(od).", systemImage: "calendar") }
                }
                .font(.tekst(13)).foregroundStyle(Color.sivaTekst)
                if let poslao = profil.poslao_pitanja, poslao > 0 {
                    Label("Poslao \(poslao.srpski) \(poslao == 1 ? "pitanje" : "pitanja") · \((profil.u_igri_pitanja ?? 0).srpski) u igri", systemImage: "rosette")
                        .font(.tekst(13, .bold)).foregroundStyle(Color.teal)
                }
            }
            radnje
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func broj(_ n: Int, _ naziv: String) -> some View {
        VStack(spacing: 2) {
            Text(n.srpski).font(.naslov(20)).monospacedDigit()
            Text(naziv).font(.tekst(12)).foregroundStyle(Color.sivaTekst)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// Pitanja: koliko odgovora, na koliko različitih pitanja, koliko ponovljenih, tačnost i brzina (svi modovi).
struct PitanjaStatistika: View {
    let p: ProfilIgracaView.Profil.Pitanja

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pitanja").font(.naslov(22))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                Plocica(ikonica: "text.bubble", vrednost: p.odgovora.srpski, naziv: "Odgovora")
                Plocica(ikonica: "sparkles", vrednost: p.jedinstvenih.srpski, naziv: "Različitih pitanja", boja: .roze)
                Plocica(ikonica: "arrow.triangle.2.circlepath", vrednost: p.ponovljenih.srpski, naziv: "Ponovljenih", boja: .narandzasta)
                Plocica(ikonica: "checkmark.circle", vrednost: p.tacnost.map { "\($0)%" } ?? "–", naziv: "Tačnost", boja: .ljubicasta)
            }
            if let ms = p.prosek_ms, p.odgovora > 0 {
                Label("Prosečno \((Double(ms) / 1000).formatted(.number.precision(.fractionLength(1)).locale(.srpski))) s po odgovoru", systemImage: "bolt").font(.tekst(13, .semibold)).foregroundStyle(Color.sivaTekst)
            }
        }
    }
}

/// Igre sa veba (kviz.librum.club/profil): PRO, Book, Vešanje, Brzi kviz, Duel.
struct VebIgreStatistika: View {
    let veb: ProfilIgracaView.Profil.Veb

    var body: some View {
        let kartice = sadrzaj
        if !kartice.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Rekordi").font(.naslov(22))
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(kartice, id: \.naziv) { k in kartica(k) }
                }
            }
        }
    }

    private struct Kartica { let naziv: String; let ikonica: String; let boja: Color; let glavno: String; let glavnoNaziv: String; let ostalo: [String] }

    private var sadrzaj: [Kartica] {
        var l: [Kartica] = []
        if let g = veb.pro, (g.partija ?? 0) > 0 {
            l.append(.init(naziv: "PRO kviz", ikonica: "crown", boja: .ljubicasta, glavno: (g.rekord ?? 0).srpski, glavnoNaziv: "rekord",
                           ostalo: ["\(g.partija ?? 0) partija", "do \(g.max_pitanja ?? 0). pitanja", "niz \(g.niz ?? 0)"]))
        }
        if let g = veb.book, (g.partija ?? 0) > 0 {
            l.append(.init(naziv: "Book kviz", ikonica: "book", boja: .narandzasta, glavno: (g.rekord ?? 0).srpski, glavnoNaziv: "rekord",
                           ostalo: ["\(g.partija ?? 0) partija", "do \(g.max_pitanja ?? 0). pitanja"] + (g.zanr.map { ["najjači: \($0)"] } ?? [])))
        }
        if let g = veb.vesanje, (g.partija ?? 0) > 0 {
            let uspeh = (g.pobeda ?? 0) * 100 / max(1, g.partija ?? 1)
            l.append(.init(naziv: "Vešanje", ikonica: "textformat.abc", boja: .nebo, glavno: "\(g.pobeda ?? 0)", glavnoNaziv: "pogođenih reči",
                           ostalo: ["\(g.partija ?? 0) partija", "uspeh \(uspeh)%", "\(g.bodovi ?? 0) bodova"]))
        }
        if let g = veb.brzi, (g.partija ?? 0) > 0 {
            l.append(.init(naziv: "Brzi kviz", ikonica: "timer", boja: .zuta, glavno: (g.rekord ?? 0).srpski, glavnoNaziv: "rekord",
                           ostalo: ["\(g.partija ?? 0) rundi", "\(g.tacnih ?? 0) tačnih", "tačnost \(g.tacnost ?? 0)%"]))
        }
        if let g = veb.duel, (g.pobeda ?? 0) + (g.poraza ?? 0) + (g.nereseno ?? 0) > 0 {
            l.append(.init(naziv: "Duel", ikonica: "figure.boxing", boja: .roze, glavno: "\(g.pobeda ?? 0)", glavnoNaziv: "pobeda",
                           ostalo: ["\(g.poraza ?? 0) poraza", "\(g.nereseno ?? 0) nerešeno"]))
        }
        return l
    }

    private func kartica(_ k: Kartica) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: k.ikonica).font(.system(size: 13, weight: .bold)).foregroundStyle(Color.tinta)
                    .frame(width: 26, height: 26).background(k.boja, in: RoundedRectangle(cornerRadius: 8))
                Text(k.naziv).font(.tekst(14, .bold)).lineLimit(1)
            }
            Text(k.glavno).font(.naslov(26)).monospacedDigit()
            Text(k.glavnoNaziv).font(.tekst(12)).foregroundStyle(Color.sivaTekst)
            Text(k.ostalo.joined(separator: " · ")).font(.tekst(12, .semibold)).foregroundStyle(Color.sivaTekst).fixedSize(horizontal: false, vertical: true)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading).mirna()
        .accessibilityElement(children: .combine)
    }
}

/// Skorašnja aktivnost: poslednjih 10 partija iz svih modova (veb i aplikacija).
struct SkorasnjaAktivnost: View {
    let skoro: [ProfilIgracaView.Profil.Skoro]
    private static let nazivi = ["pro": "PRO kviz", "book": "Book kviz", "vesanje": "Vešanje", "brzi": "Brzi kviz", "duel": "Duel",
                                 "slikari": "Slikari", "osvajanje": "Osvajanje", "tema": "Kviz po temi"]

    var body: some View {
        if !skoro.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Skorašnja aktivnost").font(.naslov(22))
                VStack(spacing: 0) {
                    ForEach(Array(skoro.enumerated()), id: \.offset) { i, s in
                        HStack {
                            Text(Self.nazivi[s.igra] ?? s.igra).font(.tekst(15, .semibold))
                            Spacer()
                            Text("\(s.poeni ?? 0)").font(.tekst(15, .bold)).monospacedDigit()
                            Text(kada(s.kad)).font(.tekst(12)).foregroundStyle(Color.sivaTekst).frame(width: 70, alignment: .trailing)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        if i < skoro.count - 1 { Divider().overlay(Color.kremTamnija) }
                    }
                }
                .mirna()
            }
        }
    }

    private func kada(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let d = f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else { return "" }
        return d.formatted(.relative(presentation: .named, unitsStyle: .abbreviated))
    }
}

/// Spisak pratilaca ili praćenih, sa dugmetom Prati kod svakog (kao na Instagramu).
struct PracenjaView: View {
    enum Vrsta: String { case pratioci, prati }
    let id: String
    let vrsta: Vrsta
    @Environment(Sesija.self) private var sesija
    struct Red: Decodable, Identifiable { let id: String; let nadimak: String; let avatar: String?; var ja_pratim: Bool }
    @State private var stanje: Ucitano<[Red]> = .ucitava

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    GornjaTraka()
                }
                Naslov(tekst: vrsta == .pratioci ? "Pratioci" : "Prati", velicina: 30)
                switch stanje {
                case .ucitava: ForEach(0..<5, id: \.self) { _ in Skelet(visina: 56) }
                case .greska(let p): StanjeEkrana(maskota: .lumi, naslov: "Spisak se nije učitao", tekst: p, dugme: "Pokušaj ponovo") { Task { await ucitaj() } }
                case .gotovo(let redovi) where redovi.isEmpty:
                    StanjeEkrana(maskota: .bloop, naslov: vrsta == .pratioci ? "Još nema pratilaca" : "Još nikog ne prati",
                                 tekst: "Igrače nađeš u Društvu, pa ih zapratiš sa njihovog profila.")
                case .gotovo(let redovi):
                    VStack(spacing: 0) {
                        ForEach(Array(redovi.enumerated()), id: \.element.id) { i, r in
                            HStack(spacing: 12) {
                                NavigationLink { ProfilIgracaView(id: r.id) } label: {
                                    HStack(spacing: 12) {
                                        AvatarSlika(avatar: r.avatar, velicina: 44)
                                        Text(r.nadimak).font(.tekst(16, .semibold)).foregroundStyle(Color.mastilo)
                                    }
                                }
                                .buttonStyle(.plain)
                                Spacer()
                                if sesija.prijavljen && r.id != sesija.korisnikId {
                                    Button(r.ja_pratim ? "Pratiš" : "Prati") { Task { await prebaci(i, r) } }
                                        .font(.tekst(14, .bold)).padding(.horizontal, 14).frame(height: 36)
                                        .foregroundStyle(r.ja_pratim ? Color.mastilo : Color.naMastilu)
                                        .background(r.ja_pratim ? Color.kartica : Color.mastilo, in: RoundedRectangle(cornerRadius: 10))
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.mastilo, lineWidth: 1.5))
                                }
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            if i < redovi.count - 1 { Divider().overlay(Color.kremTamnija) }
                        }
                    }
                    .mirna()
                }
            }
            .padding(16)
        }
        .background(Papir())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task { await ucitaj() }
    }

    private func ucitaj() async {
        do {
            let r: [Red] = try await Supabase.deljeni.rpc("spisak_pracenja", ["p_id": id, "p_vrsta": vrsta.rawValue], token: try? await sesija.vazeciToken())
            stanje = .gotovo(r)
        } catch { stanje = .greska(error.localizedDescription) }
    }

    private func prebaci(_ i: Int, _ r: Red) async {
        guard case .gotovo(var redovi) = stanje, await Drustvo.prati(sesija, id: r.id, da: !r.ja_pratim) else { return }
        redovi[i].ja_pratim.toggle()
        stanje = .gotovo(redovi)
    }
}

/// Sve statistike profila redom: pitanja, rekordi sa veba, igre iz aplikacije i pomoći, skorašnja aktivnost.
struct ProfilStatistike: View {
    let profil: ProfilIgracaView.Profil

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let p = profil.pitanja, p.odgovora > 0 { PitanjaStatistika(p: p) }
            if let veb = profil.veb { VebIgreStatistika(veb: veb) }
            if !profil.igre.isEmpty {
                Text("U aplikaciji").font(.naslov(22))
                StatistikaPoIgrama(profil: profil)
            }
            SkorasnjaAktivnost(skoro: profil.skoro ?? [])
            if (profil.partija ?? 0) == 0 && profil.igre.isEmpty {
                StanjeEkrana(maskota: .bloop, naslov: "Još nema partija", tekst: "Kad se odigra prva igra sa nalogom, rezultati će stajati ovde.")
            }
        }
    }
}

extension Locale { static let srpski = Locale(identifier: "sr_Latn_RS") }
/// Brojevi na profilu po srpskom pravopisu: 8.544, ne 8,544.
extension Int { var srpski: String { formatted(.number.locale(.srpski)) } }
