import SwiftUI

/// Igre sa rang listom (ključ u tabeli rezultati_igara) i kako izgledaju u izboru.
enum IgraListe: String, CaseIterable, Identifiable {
    case osvajanje, pro, book, duel, slikari, brzi, vesanje
    var id: String { rawValue }
    var naziv: String {
        switch self {
        case .osvajanje: "Osvajanje"
        case .pro: "PRO"
        case .book: "Book"
        case .duel: "Duel"
        case .slikari: "Slikari"
        case .brzi: "Brzi"
        case .vesanje: "Vešanje"
        }
    }
}

/// Rang lista iz kita, po igri i periodu (dan, nedelja, mesec, godina). Godišnja se
/// sama resetuje 1. januara jer broji samo tekuću godinu (RPC rang_lista_igre).
/// Stanja: učitavanje, greška, prazno, nisi rangiran / prijavi se.
struct RangListaView: View {
    enum Period: String, CaseIterable, Hashable {
        case dan, nedelja, mesec, godina
        var naziv: String { switch self { case .dan: "Dan"; case .nedelja: "Nedelja"; case .mesec: "Mesec"; case .godina: "Godina" } }
    }

    struct Red: Decodable, Identifiable {
        let mesto: Int
        let user_id: String
        let nadimak: String
        let avatar: String?
        let poeni: Int
        let partija: Int
        let prosek_ms: Int?
        var id: String { user_id }
    }
    struct MojeMesto: Decodable { let mesto: Int; let poeni: Int; let partija: Int; let prosek_ms: Int?; let ukupno: Int }

    @Environment(Sesija.self) private var sesija
    @State private var igra: IgraListe = .osvajanje
    @State private var period: Period = .nedelja
    /// „svi” ili „pratim” (ja i igrači koje pratim).
    @State private var krug = "svi"
    @State private var stanje: Ucitano<[Red]> = .ucitava
    @State private var moje: MojeMesto?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Rang lista").font(.naslov(38)).padding(.top, 6)
                ScrollView(.horizontal, showsIndicators: false) {
                    PodvuceniIzbor(izbor: $igra, opcije: IgraListe.allCases.map { ($0, $0.naziv) })
                }
                if sesija.prijavljen {
                    PodvuceniIzbor(izbor: $krug, opcije: [("svi", "Svi igrači"), ("pratim", "Koje pratim")])
                }
                HStack(spacing: 8) {
                    ForEach(Period.allCases, id: \.self) { p in
                        Button { period = p } label: {
                            Text(p.naziv).font(.tekst(14, .bold)).foregroundStyle(period == p ? Color.naMastilu : Color.mastilo)
                                .frame(maxWidth: .infinity).frame(height: 40)
                                .background(period == p ? Color.mastilo : Color.kartica, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.mastilo, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(period == p ? .isSelected : [])
                    }
                }
                Label(napomena, systemImage: "clock").font(.tekst(13, .semibold)).foregroundStyle(Color.sivaTekst)
                sadrzaj
            }
            .padding(16)
        }
        .background(Papir())
        .toolbar(.hidden, for: .navigationBar)
        .task(id: "\(igra.rawValue)-\(period.rawValue)-\(krug)") { await osvezi() }
        .refreshable { await osvezi() }
    }

    private var napomena: String {
        switch period {
        case .dan: "Lista dana, nova od ponoći"
        case .nedelja: "Nova lista svakog ponedeljka"
        case .mesec: "Nova lista prvog u mesecu"
        case .godina: "Godišnja lista se resetuje 1. januara"
        }
    }

    @ViewBuilder private var sadrzaj: some View {
        switch stanje {
        case .ucitava:
            HStack(alignment: .bottom, spacing: 10) { Skelet(visina: 90); Skelet(visina: 130); Skelet(visina: 70) }
            ForEach(0..<5, id: \.self) { _ in Skelet(visina: 56) }
        case .greska(let poruka):
            StanjeEkrana(maskota: .lumi, naslov: "Lista se nije učitala", tekst: poruka, dugme: "Pokušaj ponovo") { Task { await osvezi() } }
        case .gotovo(let redovi) where redovi.isEmpty:
            StanjeEkrana(maskota: .bloop, naslov: "Prazno je", tekst: "Niko još nije igrao \(igra.naziv) u ovom periodu. Budi prvi na listi.")
        case .gotovo(let redovi):
            postolje(Array(redovi.prefix(3)))
            VStack(spacing: 0) {
                ForEach(Array(redovi.dropFirst(3).enumerated()), id: \.element.id) { i, r in
                    NavigationLink { ProfilIgracaView(id: r.user_id) } label: { red(r) }.buttonStyle(.plain)
                    if i < redovi.count - 4 { Divider().overlay(Color.kremTamnija) }
                }
            }
            .mirna()
            mojeMestoKartica
        }
    }

    private func postolje(_ tri: [Red]) -> some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach([1, 0, 2].filter { $0 < tri.count }, id: \.self) { i in
                NavigationLink { ProfilIgracaView(id: tri[i].user_id) } label: {
                    VStack(spacing: 6) {
                        AvatarSlika(avatar: tri[i].avatar, velicina: i == 0 ? 72 : 60, maskota: [Maskota.zig, .mimi, .lumi][i])
                        Text(tri[i].nadimak).font(.tekst(13, .bold)).foregroundStyle(Color.mastilo).lineLimit(1)
                        Text(tri[i].poeni.formatted()).font(.tekst(12, .bold)).foregroundStyle(Color.naMastilu).padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.mastilo, in: RoundedRectangle(cornerRadius: 8))
                        Text("\(tri[i].mesto)").font(.naslov(34)).foregroundStyle(Color.tinta).frame(maxWidth: .infinity).frame(height: [120, 90, 70][i])
                            .background([Color.zuta, .nebo, .roze][i], in: UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14))
                            .overlay(UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14).stroke(Color.mastilo, lineWidth: 2))
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("\(tri[i].mesto). mesto: \(tri[i].nadimak), \(tri[i].poeni) poena")
            }
        }
        .padding(.top, 8)
    }

    private func red(_ r: Red) -> some View {
        HStack(spacing: 12) {
            Text("\(r.mesto)").font(.tekst(15, .bold)).monospacedDigit().frame(width: 30)
            AvatarSlika(avatar: r.avatar, velicina: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(r.nadimak).font(.tekst(16, .semibold)).lineLimit(1)
                Text(detalj(partija: r.partija, ms: r.prosek_ms)).font(.tekst(12)).foregroundStyle(Color.sivaTekst)
            }
            Spacer()
            Text(r.poeni.formatted()).font(.naslov(20)).monospacedDigit()
        }
        .foregroundStyle(Color.mastilo)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func detalj(partija: Int, ms: Int?) -> String {
        let p = partija == 1 ? "1 partija" : "\(partija) partija"
        return ms.map { "\(p) · \(String(format: "%.1f", Double($0) / 1000)) s po odgovoru" } ?? p
    }

    @ViewBuilder private var mojeMestoKartica: some View {
        if let moje {
            HStack(spacing: 12) {
                Text("\(moje.mesto)").font(.naslov(22)).frame(width: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tvoje mesto od \(moje.ukupno)").font(.tekst(15, .bold))
                    Text(detalj(partija: moje.partija, ms: moje.prosek_ms)).font(.tekst(12))
                }
                Spacer()
                Text(moje.poeni.formatted()).font(.naslov(20)).monospacedDigit()
            }
            .foregroundStyle(Color.tinta).padding(14).pop(.zuta, radijus: 18)
        } else {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.questionmark").font(.system(size: 22))
                VStack(alignment: .leading, spacing: 2) {
                    Text(sesija.prijavljen ? "Još nisi na ovoj listi" : "Prijavi se da uđeš na listu").font(.tekst(15, .bold))
                    Text(sesija.prijavljen ? "Odigraj \(igra.naziv) u ovom periodu i upiši se." : "Rezultati bez naloga ostaju samo na telefonu.").font(.tekst(13))
                }
                Spacer()
            }
            .foregroundStyle(Color.tinta).padding(14).pop(.zuta, radijus: 18)
        }
    }

    private func osvezi() async {
        stanje = .ucitava
        do {
            let redovi: [Red] = try await Supabase.deljeni.rpc("rang_lista_igre", ["p_igra": igra.rawValue, "p_period": period.rawValue, "p_broj": 50, "p_krug": krug],
                                                            token: try? await sesija.vazeciToken())
            stanje = .gotovo(redovi)
        } catch {
            stanje = .greska(error.localizedDescription)
        }
        if let token = try? await sesija.vazeciToken() {
            let m: [MojeMesto]? = try? await Supabase.deljeni.rpc("moje_mesto_igre", ["p_igra": igra.rawValue, "p_period": period.rawValue], token: token)
            moje = m?.first
        } else {
            moje = nil
        }
    }

    /// Vrh nedelje za početnu: prva tri iz Osvajanja.
    static func ucitajVrh() async throws -> [Red] {
        try await Supabase.deljeni.rpc("rang_lista_igre", ["p_igra": "osvajanje", "p_period": "nedelja", "p_broj": 3])
    }
}

/// Javni profil drugog igrača: avatar, od kada igra i statistika po igri.
struct ProfilIgracaView: View {
    let id: String
    @Environment(Sesija.self) private var sesija
    @State private var duel = false
    @State private var blokada = false
    @Environment(\.dismiss) private var nazad
    /// Odgovor RPC profil_igraca (scripts/2026-11-03_profil-kao-ig.sql); ista struktura za moj i tuđi profil.
    struct Profil: Decodable {
        struct Igra: Decodable { let igra: String; let partija: Int; let najbolje: Int; let prosek_ms: Int?; let tacnost: Int?; let sa_pomoci: Int? }
        struct Pitanja: Decodable { let odgovora: Int; let jedinstvenih: Int; let ponovljenih: Int; let tacnost: Int?; let prosek_ms: Int? }
        struct VebIgra: Decodable {
            let partija: Int?; let rekord: Int?; let max_pitanja: Int?; let niz: Int?; let zanr: String?
            let pobeda: Int?; let bodovi: Int?; let tacnih: Int?; let tacnost: Int?; let poraza: Int?; let nereseno: Int?
        }
        struct Veb: Decodable { let pro: VebIgra?; let book: VebIgra?; let vesanje: VebIgra?; let brzi: VebIgra?; let duel: VebIgra? }
        struct Skoro: Decodable { let igra: String; let poeni: Int?; let kad: String }
        var id: String?
        let nadimak: String
        let avatar: String?
        let od: String?
        let igre: [Igra]
        let pomoci: [String: Int]?
        var ime: String?
        var grad: String?
        var bio: String?
        var pratilaca: Int?
        var prati: Int?
        var ja_pratim: Bool?
        var autor_pitanja: Int?
        var poslao_pitanja: Int?
        var u_igri_pitanja: Int?
        var pitanja: Pitanja?
        var partija: Int?
        var veb: Veb?
        var skoro: [Skoro]?
    }
    @State private var stanje: Ucitano<Profil> = .ucitava

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                GornjaTraka()
                switch stanje {
                case .ucitava:
                    Skelet(visina: 120, radijus: 60).frame(width: 120)
                    Skelet(visina: 30).frame(width: 180)
                    ForEach(0..<3, id: \.self) { _ in Skelet(visina: 70) }
                case .greska(let poruka):
                    StanjeEkrana(maskota: .lumi, naslov: "Profil se nije učitao", tekst: poruka, dugme: "Pokušaj ponovo") { Task { await ucitaj() } }
                case .gotovo(let p):
                    ProfilZaglavlje(profil: p) {
                        if sesija.prijavljen && sesija.korisnikId != id {
                            HStack(spacing: 10) {
                                Button {
                                    Task {
                                        let prati = !(p.ja_pratim ?? false)
                                        if await Drustvo.prati(sesija, id: id, da: prati) { await ucitaj(tiho: true) }
                                    }
                                } label: { Label((p.ja_pratim ?? false) ? "Pratiš" : "Prati", systemImage: (p.ja_pratim ?? false) ? "checkmark" : "person.badge.plus") }
                                    .buttonStyle(DugmeStil(vrsta: (p.ja_pratim ?? false) ? .sekundarno : .primarno))
                                Button { duel = true } label: { Label("Izazovi", systemImage: "bolt") }.buttonStyle(.zuto)
                                NavigationLink { RazgovorView(sa: id, nadimak: p.nadimak, avatar: p.avatar) } label: { ikonica("paperplane") }
                                    .accessibilityLabel("Pošalji poruku")
                                Button { blokada = true } label: { ikonica("hand.raised") }.accessibilityLabel("Blokiraj")
                            }
                        }
                    }
                    ProfilStatistike(profil: p)
                }
            }
            .padding(16)
        }
        .background(Papir())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task { await ucitaj() }
        .overlay {
            if blokada, case .gotovo(let p) = stanje {
                Dijalog(naslov: "Blokirati \(p.nadimak)?", tekst: "Više se nećete videti: ni objave, ni komentari, ni poruke. Praćenje se briše.",
                        potvrda: "Blokiraj", odustani: "Odustani", opasno: true) {
                    blokada = false
                    Task { if await Zajednica.radnja(sesija, "blokiraj", ["p_id": id, "p_da": true]) { nazad() } }
                } zatvori: { blokada = false }
            }
        }
        .navigationDestination(isPresented: $duel) {
            if case .gotovo(let p) = stanje { DuelView(izazovi: (id, p.nadimak)) }
        }
    }

    private func ikonica(_ ime: String) -> some View {
        Image(systemName: ime).font(.system(size: 17, weight: .bold)).foregroundStyle(Color.mastilo)
            .frame(width: 54, height: 54).background(Color.kartica, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.mastilo, lineWidth: 2))
    }

    /// `tiho`: posle praćenja se brojevi osveže bez skeleta.
    private func ucitaj(tiho: Bool = false) async {
        if !tiho { stanje = .ucitava }
        do {
            let p: Profil = try await Supabase.deljeni.rpc("profil_igraca", ["p_id": id], token: try? await sesija.vazeciToken())
            stanje = .gotovo(p)
        } catch {
            stanje = .greska(error.localizedDescription)
        }
    }
}

/// Statistika po igri (kao kartice na starom profilu sajta) i upotreba pomoći.
struct StatistikaPoIgrama: View {
    let profil: ProfilIgracaView.Profil

    var body: some View {
        let ukupno = profil.igre.reduce(0) { $0 + $1.partija }
        let brzine = profil.igre.compactMap(\.prosek_ms)
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Plocica(ikonica: "gamecontroller", vrednost: "\(ukupno)", naziv: "Partija")
                Plocica(ikonica: "bolt", vrednost: brzine.isEmpty ? "–" : String(format: "%.1f s", Double(brzine.reduce(0, +)) / Double(brzine.count) / 1000),
                        naziv: "Prosek odgovora", boja: .narandzasta)
                Plocica(ikonica: "lifepreserver", vrednost: ukupno == 0 ? "–" : "\(profil.igre.reduce(0) { $0 + ($1.sa_pomoci ?? 0) } * 100 / ukupno)%",
                        naziv: "Sa pomoći", boja: .roze)
            }
            PomocUpotreba(poVrsti: profil.pomoci ?? [:])
            if profil.igre.isEmpty {
                StanjeEkrana(maskota: .bloop, naslov: "Još nema partija", tekst: "Kad se odigra prva igra sa nalogom, rezultati će stajati ovde.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(profil.igre.enumerated()), id: \.offset) { i, g in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(IgraListe(rawValue: g.igra)?.naziv ?? (g.igra == "tema" ? "Teme" : g.igra)).font(.tekst(15, .bold))
                                Text([g.partija == 1 ? "1 partija" : "\(g.partija) partija", g.tacnost.map { "\($0)% tačno" },
                                      g.prosek_ms.map { String(format: "%.1f s po odgovoru", Double($0) / 1000) },
                                      (g.sa_pomoci ?? 0) > 0 ? "pomoć u \(g.sa_pomoci!)" : nil].compactMap { $0 }.joined(separator: " · "))
                                    .font(.tekst(12)).foregroundStyle(Color.sivaTekst)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 0) {
                                Text(g.najbolje.formatted()).font(.naslov(20)).monospacedDigit()
                                Oznaka(tekst: "rekord")
                            }
                        }
                        .padding(14)
                        if i < profil.igre.count - 1 { Divider().overlay(Color.kremTamnija) }
                    }
                }
                .mirna()
            }
        }
    }
}

/// Koju pomoć igrač koristi i koliko često (ključ vrste → broj).
struct PomocUpotreba: View {
    let poVrsti: [String: Int]
    static let nazivi = ["polaPola": "50/50", "nagovestaj": "Nagoveštaj", "vreme": "Dodatno vreme", "preskok": "Preskok", "slovo": "Otkriveno slovo"]

    var body: some View {
        let ukupno = poVrsti.values.reduce(0, +)
        if ukupno > 0 {
            VStack(alignment: .leading, spacing: 8) {
                Text("Pomoći").font(.tekst(15, .bold))
                ForEach(poVrsti.sorted { $0.value > $1.value }, id: \.key) { k, v in
                    HStack(spacing: 10) {
                        Text(Self.nazivi[k] ?? k).font(.tekst(14, .semibold)).frame(width: 120, alignment: .leading)
                        GeometryReader { g in
                            RoundedRectangle(cornerRadius: 4).fill(Color.udubljeno)
                                .overlay(alignment: .leading) { RoundedRectangle(cornerRadius: 4).fill(Color.roze).frame(width: g.size.width * Double(v) / Double(ukupno)) }
                        }
                        .frame(height: 8)
                        Text("\(v)×").font(.tekst(13, .bold)).monospacedDigit().frame(width: 40, alignment: .trailing)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading).mirna()
        }
    }
}
