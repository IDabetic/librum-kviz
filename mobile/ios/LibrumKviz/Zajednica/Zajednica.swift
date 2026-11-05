import SwiftUI

/// Društvena mreža kviza (scripts/2026-11-03_drustvena-mreza.sql), po uzoru na Librum eBook:
/// objave (poziv na duel, traži tim, rezultat, tekst), srca, komentari u granama, blokade, prijave i poruke.
enum Zajednica {
    struct Objava: Codable, Identifiable, Equatable {
        let id: Int
        let ko: String
        let nadimak: String
        let avatar: String?
        let vrsta: String
        let igra: String?
        let tekst: String
        let poeni: Int?
        let kod_sobe: String?
        let created_at: String
        var srca: Int
        var moje_srce: Bool
        var komentara: Int
        let moja: Bool
    }
    struct Komentar: Decodable, Identifiable, Equatable {
        let id: Int
        let roditelj: Int?
        let ko: String
        let nadimak: String
        let avatar: String?
        let tekst: String
        let created_at: String
        var srca: Int
        var moje_srce: Bool
        let moj: Bool
    }
    struct Razgovor: Codable, Identifiable { let sa: String; let nadimak: String; let avatar: String?; let poslednja: String; let kad: String; let moja: Bool; let neprocitanih: Int; var id: String { sa } }
    struct Poruka: Decodable, Identifiable, Equatable { let id: Int; let moja: Bool; let tekst: String; let created_at: String }
    struct Igra: Decodable, Identifiable { let ko: String; let nadimak: String; let avatar: String?; let igra: String; let poeni: Int; let kad: String; var id: String { ko + kad } }
    struct Srce: Decodable { let moje_srce: Bool; let srca: Int }

    static let vrste: [(String, String, String)] = [
        ("tekst", "Objava", "text.bubble"), ("rezultat", "Moj rezultat", "trophy"),
        ("poziv_duel", "Poziv na duel", "bolt"), ("poziv_tim", "Tražim tim", "person.3"),
    ]
    static func nazivVrste(_ v: String) -> String { vrste.first { $0.0 == v }?.1 ?? "Objava" }
    static func ikonicaVrste(_ v: String) -> String { vrste.first { $0.0 == v }?.2 ?? "text.bubble" }
    static let nazivIgre = ["dnevni": "Dnevni izazov", "osvajanje": "Osvajač", "pro": "PRO kviz", "book": "Book kviz", "duel": "Duel", "slikari": "Slikari",
                            "brzi": "Brzi kviz", "vesanje": "Vešanje", "tema": "Kviz po temi", "karijera": "Karijerista", "kafana": "Kafanski kviz"]

    private static func token(_ s: Sesija) async -> String? { try? await s.vazeciToken() }

    static func tok(_ s: Sesija, vrsta: String, pre: Int? = nil) async throws -> [Objava] {
        try await Supabase.deljeni.rpc("tok_objava", ["p_vrsta": vrsta, "p_pre": pre as Any? ?? NSNull(), "p_broj": 20], token: await token(s))
    }
    struct NaMrezi: Decodable, Identifiable, Equatable { let ko: String; let nadimak: String; let avatar: String?; let igra: String?; let od: String; let pratim: Bool; var id: String { ko } }
    static func naMrezi(_ s: Sesija) async -> [NaMrezi]? { try? await Supabase.deljeni.rpc("na_mrezi", ["p_broj": 150], token: await token(s)) }
    /// Otkucaj prisustva dok je aplikacija otvorena (Koren, na 30 s); greška se ne prikazuje, sledeći otkucaj pokušava ponovo.
    static func javiPrisustvo(_ s: Sesija) async {
        guard let t = await token(s) else { return }
        do { _ = try await Supabase.deljeni.zahtev("rest/v1/rpc/javi_prisustvo", metod: "POST", telo: [:], token: t) } catch { print("Prisustvo nije javljeno: \(error)") }
    }
    static func koStaIgra(_ s: Sesija) async -> [Igra] { (try? await Supabase.deljeni.rpc("ko_sta_igra", ["p_broj": 20], token: await token(s))) ?? [] }
    /// Poslednja partija za „Moj rezultat”: izvor je `r:<id>` (igre) ili `k:<id>` (Karijerista), server iz njega upisuje igru i poene.
    struct MojRezultat: Decodable, Identifiable, Equatable { let izvor: String; let igra: String; let poeni: Int; let tacnih: Int?; let kad: String; var id: String { izvor } }
    static func mojiRezultati(_ s: Sesija) async -> [MojRezultat] {
        (try? await Supabase.deljeni.rpc("moji_poslednji_rezultati", ["p_broj": 15], token: await token(s))) ?? []
    }
    /// Rezultat se objavljuje po izvoru (izbor iz poslednjih partija) ili, posle partije, po igri i poenima koje server proveri.
    static func objavi(_ s: Sesija, vrsta: String, tekst: String, igra: String?, poeni: Int? = nil, rezultat: String? = nil) async throws {
        let _: Int = try await Supabase.deljeni.rpc("nova_objava", ["p_vrsta": vrsta, "p_tekst": tekst, "p_igra": igra as Any? ?? NSNull(),
                                                                    "p_poeni": poeni as Any? ?? NSNull(), "p_rezultat": rezultat as Any? ?? NSNull()], token: await token(s))
    }
    static func srceObjavi(_ s: Sesija, _ id: Int) async -> Srce? { try? await Supabase.deljeni.rpc("srce_objavi", ["p_id": id], token: await token(s)) }
    static func srceKomentaru(_ s: Sesija, _ id: Int) async -> Srce? { try? await Supabase.deljeni.rpc("srce_komentaru", ["p_id": id], token: await token(s)) }
    static func komentari(_ s: Sesija, _ objava: Int) async throws -> [Komentar] {
        try await Supabase.deljeni.rpc("komentari_objave", ["p_objava": objava], token: await token(s))
    }
    static func komentarisi(_ s: Sesija, objava: Int, tekst: String, roditelj: Int?) async throws {
        let _: Int = try await Supabase.deljeni.rpc("novi_komentar", ["p_objava": objava, "p_tekst": tekst, "p_roditelj": roditelj as Any? ?? NSNull()], token: await token(s))
    }
    /// Radnje bez odgovora (brisanje, blokada, prijava): uspeh je bez greške.
    static func radnja(_ s: Sesija, _ funkcija: String, _ p: [String: Any]) async -> Bool {
        guard let t = await token(s) else { return false }
        return (try? await Supabase.deljeni.zahtev("rest/v1/rpc/\(funkcija)", metod: "POST", telo: p, token: t)) != nil
    }
    static func razgovori(_ s: Sesija) async throws -> [Razgovor] { try await Supabase.deljeni.rpc("moji_razgovori", [:], token: await token(s)) }
    static func poruke(_ s: Sesija, sa: String) async throws -> [Poruka] { try await Supabase.deljeni.rpc("poruke_sa", ["p_sa": sa], token: await token(s)) }
    static func posaljiPoruku(_ s: Sesija, za: String, tekst: String) async throws {
        let _: Int = try await Supabase.deljeni.rpc("posalji_poruku", ["p_za": za, "p_tekst": tekst], token: await token(s))
    }

    /// „pre 5 min”, „pre 2 d.”: vreme objave, komentara i poruke.
    static func pre(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let d = f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else { return "" }
        if Date().timeIntervalSince(d) < 60 { return "upravo" }
        return d.formatted(.relative(presentation: .named, unitsStyle: .abbreviated).locale(.srpski))
    }
}

// MARK: Kartica Igrači

/// Kartica „Igrači”: ko šta igra, tok objava (svi ili koje pratim), poruke, pretraga igrača i nova objava.
struct IgraciTabView: View {
    @Environment(Sesija.self) private var sesija
    @Environment(Napredak.self) private var napredak
    @State private var vrsta = "svi"
    @State private var objave: Ucitano<[Zajednica.Objava]> = Kes.ucitano("tok-svi")
    @State private var igraju: [Zajednica.Igra] = []
    @State private var nova = false
    @State private var prijava = false
    @State private var komentariZa: Zajednica.Objava?
    @State private var jos = true

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Naslov(tekst: "Igrači", velicina: 34)
                    Spacer()
                    // Na mreži levo od Sandučeta (vlasnik 05.11): svi igrači koji su sada u aplikaciji.
                    NavigationLink { NaMreziView() } label: {
                        krug("dot.radiowaves.left.and.right").overlay(alignment: .topTrailing) {
                            Circle().fill(Color.teal).frame(width: 12, height: 12).overlay(Circle().stroke(Color.krem, lineWidth: 2))
                        }
                    }
                    .accessibilityLabel("Igrači na mreži")
                    // Sanduče gore desno (vlasnik 03.11): izazovi, pratioci, komentari i poruke sistema.
                    NavigationLink { SanduceView() } label: {
                        krug("tray").overlay(alignment: .topTrailing) {
                            if napredak.neprocitanih + Brojaci.deljeni.obavestenja > 0 { Circle().fill(Color.roze).frame(width: 12, height: 12).overlay(Circle().stroke(Color.krem, lineWidth: 2)) }
                        }
                    }
                    .accessibilityLabel("Sanduče, \(napredak.neprocitanih + Brojaci.deljeni.obavestenja) novih")
                    NavigationLink { IgraciView() } label: { krug("magnifyingglass") }.accessibilityLabel("Nađi igrače")
                    NavigationLink { PorukeView() } label: {
                        krug("paperplane").overlay(alignment: .topTrailing) {
                            if Brojaci.deljeni.poruke > 0 { Circle().fill(Color.roze).frame(width: 12, height: 12).overlay(Circle().stroke(Color.krem, lineWidth: 2)) }
                        }
                    }
                    .accessibilityLabel("Poruke, \(Brojaci.deljeni.poruke) nepročitanih")
                }
                if !igraju.isEmpty { sadIgraju }
                Button { if !sesija.prijavljen { prijava = true } else { nova = true } } label: {
                    HStack(spacing: 12) {
                        AvatarSlika(avatar: sesija.avatar, velicina: 40)
                        Text("Pozovi na duel, traži tim ili podeli rezultat…").font(.tekst(15)).foregroundStyle(Color.sivaTekst).lineLimit(1)
                        Spacer()
                        Image(systemName: "plus").font(.system(size: 16, weight: .bold)).foregroundStyle(Color.mastilo)
                    }
                    .padding(.horizontal, 14).frame(height: 60).mirna()
                }
                .buttonStyle(.plain)
                PodvuceniIzbor(izbor: $vrsta, opcije: [("svi", "Svi"), ("pratim", "Koje pratim")])
                switch objave {
                case .ucitava: ForEach(0..<3, id: \.self) { _ in Skelet(visina: 150, radijus: 20) }
                case .greska(let p): StanjeEkrana(maskota: .lumi, naslov: "Objave se nisu učitale", tekst: p, dugme: "Pokušaj ponovo") { Task { await ucitaj() } }
                case .gotovo(let l) where l.isEmpty:
                    StanjeEkrana(maskota: .bloop, naslov: vrsta == "pratim" ? "Igrači koje pratiš još ćute" : "Još nema objava",
                                 tekst: "Budi prvi: pozovi nekog na duel ili podeli rezultat.").mirna()
                case .gotovo(let l):
                    ForEach(l) { o in
                        KarticaObjave(o: o, komentari: { komentariZa = o }, promena: { nova in zameni(nova) }, nestala: { ukloni(o.id) })
                            .onAppear { if o.id == l.last?.id && jos { Task { await ucitajJos() } } }
                    }
                }
            }
            .padding(16)
        }
        .background(Papir())
        .toolbar(.hidden, for: .navigationBar)
        .refreshable { await ucitaj() }
        .task(id: vrsta) { await ucitaj() }
        .task(id: sesija.korisnikId) {
            igraju = await Zajednica.koStaIgra(sesija)
            await Brojaci.deljeni.osvezi(sesija)
        }
        .sheet(isPresented: $nova) { NovaObjavaView { Task { await ucitaj() } } }
        .sheet(item: $komentariZa) { o in KomentariView(objava: o) { broj in var n = o; n.komentara = broj; zameni(n) } }
        .fullScreenCover(isPresented: $prijava) { PrijavaTok() }
    }

    private var sadIgraju: some View {
        VStack(alignment: .leading, spacing: 8) {
            Oznaka(tekst: "Ko šta igra")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(igraju) { g in
                        NavigationLink { ProfilIgracaView(id: g.ko) } label: {
                            VStack(spacing: 4) {
                                AvatarSlika(avatar: g.avatar, velicina: 54)
                                Text(g.nadimak).font(.tekst(12, .bold)).lineLimit(1)
                                Text(Zajednica.nazivIgre[g.igra] ?? g.igra).font(.tekst(11)).foregroundStyle(Color.sivaTekst).lineLimit(1)
                                Text(g.poeni.srpski).font(.tekst(11, .bold)).monospacedDigit()
                            }
                            .frame(width: 76)
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    private func krug(_ ikonica: String) -> some View {
        Image(systemName: ikonica).font(.system(size: 17, weight: .bold)).foregroundStyle(Color.mastilo)
            .frame(width: 44, height: 44).background(Color.kartica, in: Circle()).overlay(Circle().stroke(Color.kremTamnija, lineWidth: 1.5))
    }

    private func ucitaj() async {
        if let k: [Zajednica.Objava] = Kes.ucitaj("tok-\(vrsta)") { objave = .gotovo(k) }
        do {
            let l = try await Zajednica.tok(sesija, vrsta: vrsta)
            objave = .gotovo(l); jos = l.count == 20
            Kes.sacuvaj(l, "tok-\(vrsta)")
        } catch {
            if case .gotovo = objave { return }
            objave = .greska(error.localizedDescription)
        }
    }

    /// Keyset: sledećih 20 starijih od poslednje prikazane.
    private func ucitajJos() async {
        guard case .gotovo(let l) = objave, let posl = l.last, let nove = try? await Zajednica.tok(sesija, vrsta: vrsta, pre: posl.id) else { return }
        objave = .gotovo(l + nove); jos = nove.count == 20
    }

    private func zameni(_ o: Zajednica.Objava) {
        guard case .gotovo(var l) = objave, let i = l.firstIndex(where: { $0.id == o.id }) else { return }
        l[i] = o; objave = .gotovo(l)
    }
    private func ukloni(_ id: Int) {
        guard case .gotovo(let l) = objave else { return }
        objave = .gotovo(l.filter { $0.id != id })
    }
}

// MARK: Objava

struct KarticaObjave: View {
    let o: Zajednica.Objava
    var komentari: () -> Void
    var promena: (Zajednica.Objava) -> Void
    var nestala: () -> Void
    @Environment(Sesija.self) private var sesija
    @State private var meni = false
    @State private var duel = false
    @State private var poruka = false
    @State private var potvrda: Potvrda?
    enum Potvrda: Identifiable { case brisanje, blokada, prijava, hvala; var id: Self { self } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                NavigationLink { ProfilIgracaView(id: o.ko) } label: {
                    HStack(spacing: 10) {
                        AvatarSlika(avatar: o.avatar, velicina: 40)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(o.nadimak).font(.tekst(15, .bold)).foregroundStyle(Color.mastilo).lineLimit(1)
                            Text(Zajednica.pre(o.created_at)).font(.tekst(12)).foregroundStyle(Color.sivaTekst)
                        }
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                if o.vrsta != "tekst" {
                    Label(Zajednica.nazivVrste(o.vrsta), systemImage: Zajednica.ikonicaVrste(o.vrsta)).font(.tekst(12, .bold)).foregroundStyle(Color.teal)
                }
                if sesija.prijavljen {
                    Button { meni = true } label: {
                        Image(systemName: "ellipsis").font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.sivaTekst).frame(width: 36, height: 36)
                    }
                    .accessibilityLabel("Više")
                }
            }
            if !o.tekst.isEmpty { Text(o.tekst).font(.tekst(16)).fixedSize(horizontal: false, vertical: true) }
            if o.vrsta == "rezultat", let igra = o.igra {
                HStack(spacing: 12) {
                    Image(systemName: "trophy.fill").font(.system(size: 20, weight: .bold)).foregroundStyle(Color.tinta)
                        .frame(width: 44, height: 44).background(Color.zuta, in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Zajednica.nazivIgre[igra] ?? igra).font(.tekst(14, .semibold))
                        Text("\((o.poeni ?? 0).srpski) poena").font(.naslov(22))
                    }
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Color.udubljeno, in: RoundedRectangle(cornerRadius: 14))
            }
            if !o.moja && sesija.prijavljen && (o.vrsta == "poziv_duel" || o.vrsta == "poziv_tim") {
                Button {
                    if o.vrsta == "poziv_duel" { duel = true } else { poruka = true }
                } label: {
                    Label(o.vrsta == "poziv_duel" ? "Prihvati duel" : "Javi se", systemImage: o.vrsta == "poziv_duel" ? "bolt.fill" : "paperplane.fill")
                }
                .buttonStyle(.zuto)
            }
            HStack(spacing: 22) {
                Button { Task { if let r = await Zajednica.srceObjavi(sesija, o.id) { var n = o; n.srca = r.srca; n.moje_srce = r.moje_srce; promena(n) } } } label: {
                    HStack(spacing: 6) {
                        Image(systemName: o.moje_srce ? "heart.fill" : "heart").foregroundStyle(o.moje_srce ? Color.roze : Color.mastilo)
                            .contentTransition(.symbolEffect(.replace))
                        if o.srca > 0 { Text("\(o.srca)") }
                    }
                }
                .disabled(!sesija.prijavljen)
                .accessibilityLabel(o.moje_srce ? "Ne sviđa mi se više, \(o.srca)" : "Sviđa mi se, \(o.srca)")
                .sensoryFeedback(.impact(weight: .light), trigger: o.moje_srce)
                Button(action: komentari) {
                    HStack(spacing: 6) { Image(systemName: "bubble.right"); if o.komentara > 0 { Text("\(o.komentara)") } }
                }
                .accessibilityLabel("Komentari, \(o.komentara)")
                ShareLink(item: tekstZaDeljenje) { Image(systemName: "square.and.arrow.up") }.accessibilityLabel("Podeli")
                Spacer()
            }
            .font(.tekst(15, .semibold)).foregroundStyle(Color.mastilo).buttonStyle(.plain).frame(height: 30)
        }
        .padding(16).mirna()
        .navigationDestination(isPresented: $duel) { TakmicenjeView(pozovi: (o.ko, o.nadimak)) }
        .navigationDestination(isPresented: $poruka) { RazgovorView(sa: o.ko, nadimak: o.nadimak, avatar: o.avatar) }
        .prekoEkrana(meni || potvrda != nil) {
            ZStack {
            if meni {
                DonjiList(zatvori: { meni = false }) {
                    VStack(spacing: 0) {
                        if o.moja {
                            stavka("Obriši objavu", "trash", opasno: true) { potvrda = .brisanje }
                        } else {
                            stavka("Pošalji poruku", "paperplane") { poruka = true }
                            stavka("Prijavi objavu", "flag") { potvrda = .prijava }
                            stavka("Blokiraj \(o.nadimak)", "hand.raised", opasno: true) { potvrda = .blokada }
                        }
                    }
                }
            }
            switch potvrda {
            case .brisanje:
                Dijalog(naslov: "Obrisati objavu?", tekst: "Objava i komentari ispod nje nestaju za sve.", potvrda: "Obriši", odustani: "Odustani", opasno: true) {
                    potvrda = nil; Task { if await Zajednica.radnja(sesija, "obrisi_objavu", ["p_id": o.id]) { nestala() } }
                } zatvori: { potvrda = nil }
            case .blokada:
                Dijalog(naslov: "Blokirati \(o.nadimak)?", tekst: "Više se nećete videti: ni objave, ni komentari, ni poruke. Praćenje se briše.", potvrda: "Blokiraj", odustani: "Odustani", opasno: true) {
                    potvrda = nil; Task { if await Zajednica.radnja(sesija, "blokiraj", ["p_id": o.ko, "p_da": true]) { nestala() } }
                } zatvori: { potvrda = nil }
            case .prijava:
                DonjiList(zatvori: { potvrda = nil }) {
                    Text("Zašto prijavljuješ?").font(.naslov(22)).frame(maxWidth: .infinity, alignment: .leading)
                    VStack(spacing: 0) {
                        ForEach([("uvreda", "Uvredljivo ili govor mržnje"), ("spam", "Reklama ili lažni profil"), ("prevara", "Prevara"), ("neprikladno", "Neprikladan sadržaj"), ("drugo", "Drugo")], id: \.0) { r in
                            stavka(r.1, "flag") {
                                Task { if await Zajednica.radnja(sesija, "prijavi_sadrzaj", ["p_objava": o.id, "p_komentar": NSNull(), "p_razlog": r.0]) { potvrda = .hvala } }
                            }
                        }
                    }
                }
            case .hvala:
                Dijalog(naslov: "Hvala na prijavi", tekst: "Posle tri prijave objava se sakriva dok je urednik ne pregleda.", potvrda: "U redu", odustani: "Zatvori") { potvrda = nil } zatvori: { potvrda = nil }
            case nil: EmptyView()
            }
            }
            .environment(sesija)
        }
    }

    private func stavka(_ naziv: String, _ ikonica: String, opasno: Bool = false, radnja: @escaping () -> Void) -> some View {
        Button { meni = false; radnja() } label: {
            HStack(spacing: 12) {
                Image(systemName: ikonica).frame(width: 24)
                Text(naziv).font(.tekst(16, .semibold))
                Spacer()
            }
            .foregroundStyle(opasno ? Color.crvena : Color.mastilo).padding(.vertical, 14).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var tekstZaDeljenje: String {
        var t = o.tekst
        if o.vrsta == "rezultat", let igra = o.igra { t += "\n\(Zajednica.nazivIgre[igra] ?? igra): \((o.poeni ?? 0).srpski) poena" }
        return t + "\n\n\(o.nadimak) na Librum kvizu · https://kviz.librum.club"
    }
}

// MARK: Nova objava

struct NovaObjavaView: View {
    let objavljeno: () -> Void
    @Environment(Sesija.self) private var sesija
    @Environment(\.dismiss) private var zatvori
    @State private var vrsta = "poziv_duel"
    @State private var igra = "osvajanje"
    @State private var tekst = ""
    @State private var rezultati: Ucitano<[Zajednica.MojRezultat]> = .ucitava
    @State private var izabran: Zajednica.MojRezultat?
    @State private var greska: String?
    @State private var salje = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    KrugDugme(ikonica: "xmark", opis: "Zatvori") { zatvori() }
                    Spacer()
                    Text("Nova objava").font(.naslov(22))
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(Zajednica.vrste, id: \.0) { v in
                        Button { vrsta = v.0 } label: {
                            VStack(spacing: 6) {
                                Image(systemName: v.2).font(.system(size: 20, weight: .bold))
                                Text(v.1).font(.tekst(14, .bold))
                            }
                            .foregroundStyle(vrsta == v.0 ? Color.tinta : Color.mastilo)
                            .frame(maxWidth: .infinity).frame(height: 76)
                            .background(vrsta == v.0 ? Color.zuta : Color.kartica, in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(vrsta == v.0 ? Color.mastilo : Color.kremTamnija, lineWidth: vrsta == v.0 ? 2.5 : 1.5))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(vrsta == v.0 ? .isSelected : [])
                    }
                }
                if vrsta == "rezultat" { poslednjiRezultati }
                if vrsta != "tekst" && vrsta != "rezultat" {
                    Text("Igra").font(.tekst(14, .semibold))
                    ScrollView(.horizontal, showsIndicators: false) {
                        PodvuceniIzbor(izbor: $igra, opcije: ["osvajanje", "duel", "pro", "slikari", "book", "brzi", "vesanje"].map { ($0, Zajednica.nazivIgre[$0] ?? $0) })
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(vrsta == "poziv_duel" ? "Poruka uz poziv" : vrsta == "poziv_tim" ? "Koga tražiš" : "Tekst").font(.tekst(14, .semibold))
                    TextField(primer, text: $tekst, axis: .vertical)
                        .font(.tekst(16)).lineLimit(3...6).padding(14)
                        .background(Color.kartica, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(tekst.count > 500 ? Color.crvena : Color.kremTamnija, lineWidth: 1.5))
                    Text("\(tekst.count) / 500").font(.tekst(12)).monospacedDigit().foregroundStyle(tekst.count > 500 ? Color.crvena : Color.sivaTekst)
                }
                if let greska { Text(greska).font(.tekst(14, .semibold)).foregroundStyle(Color.crvena) }
                Button { Task { await objavi() } } label: { Text(salje ? "Objavljujem…" : "Objavi") }
                    .buttonStyle(.primarno).disabled(salje || tekst.count > 500 || (vrsta == "tekst" && tekst.trimmingCharacters(in: .whitespaces).isEmpty)
                                                     || (vrsta == "rezultat" && izabran == nil))
            }
            .padding(16)
        }
        .background(Papir())
        .task(id: vrsta) {
            guard vrsta == "rezultat", case .ucitava = rezultati else { return }
            let l = await Zajednica.mojiRezultati(sesija)
            rezultati = .gotovo(l); izabran = l.first
        }
    }

    /// Poslednje partije (vlasnik 05.11): bira se stvarni rezultat, poeni se ne kucaju.
    @ViewBuilder private var poslednjiRezultati: some View {
        Text("Izaberi rezultat").font(.tekst(14, .semibold))
        switch rezultati {
        case .ucitava: ForEach(0..<3, id: \.self) { _ in Skelet(visina: 56) }
        case .greska(let p): Text(p).font(.tekst(14)).foregroundStyle(Color.crvena)
        case .gotovo(let l) where l.isEmpty:
            Text("Još nemaš odigranih partija. Odigraj jednu, pa se vrati da je podeliš.").font(.tekst(14)).foregroundStyle(Color.sivaTekst)
        case .gotovo(let l):
            VStack(spacing: 0) {
                ForEach(l) { r in
                    Button { izabran = r } label: {
                        HStack(spacing: 12) {
                            Image(systemName: izabran == r ? "checkmark.circle.fill" : "circle").font(.system(size: 20)).foregroundStyle(izabran == r ? Color.teal : Color.kremTamnija)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(Zajednica.nazivIgre[r.igra] ?? r.igra).font(.tekst(15, .semibold)).foregroundStyle(Color.mastilo)
                                Text(Zajednica.pre(r.kad) + (r.tacnih.map { " · \($0) tačnih" } ?? "")).font(.tekst(12)).foregroundStyle(Color.sivaTekst)
                            }
                            Spacer()
                            Text("\(r.poeni.srpski)").font(.naslov(20)).foregroundStyle(Color.mastilo).monospacedDigit()
                        }
                        .padding(.vertical, 10).padding(.horizontal, 12).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(izabran == r ? .isSelected : [])
                    if r != l.last { Divider().padding(.leading, 44) }
                }
            }
            .background(Color.kartica, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.kremTamnija, lineWidth: 1.5))
        }
    }

    private var primer: String {
        switch vrsta {
        case "poziv_duel": "Ko sme na duel iz geografije?"
        case "poziv_tim": "Tražim saigrača za Osvajača, timovi po dvoje."
        case "rezultat": "Ovo mi je novi rekord!"
        default: "Šta ima novo?"
        }
    }

    private func objavi() async {
        salje = true; defer { salje = false }
        do {
            try await Zajednica.objavi(sesija, vrsta: vrsta, tekst: tekst, igra: vrsta == "tekst" || vrsta == "rezultat" ? nil : igra,
                                       rezultat: vrsta == "rezultat" ? izabran?.izvor : nil)
            objavljeno(); zatvori()
        } catch { greska = (error as? Supabase.Greska)?.poruka ?? error.localizedDescription }
    }
}

// MARK: Komentari u granama

struct KomentariView: View {
    let objava: Zajednica.Objava
    var promenjenBroj: (Int) -> Void = { _ in }
    @Environment(Sesija.self) private var sesija
    @Environment(\.dismiss) private var zatvori
    @State private var stanje: Ucitano<[Zajednica.Komentar]> = .ucitava
    @State private var tekst = ""
    @State private var odgovorNa: Zajednica.Komentar?
    @State private var meniZa: Zajednica.Komentar?
    @FocusState private var fokus: Bool

    private struct Red: Identifiable { let k: Zajednica.Komentar; let dubina: Int; var id: Int { k.id } }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                KrugDugme(ikonica: "xmark", opis: "Zatvori") { zatvori() }
                Spacer()
                Text("Komentari").font(.naslov(22))
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(16)
            // Lista zauzima sav prostor između zaglavlja i polja (05.11: bez toga se sve centriralo usred lista).
            Group {
                switch stanje {
                case .gotovo(let l) where l.isEmpty:
                    VStack(spacing: 6) {
                        Image(systemName: "bubble.left.and.bubble.right").font(.system(size: 30, weight: .semibold)).foregroundStyle(Color.sivaTekst)
                        Text("Još nema komentara").font(.tekst(17, .bold)).foregroundStyle(Color.mastilo)
                        Text("Budi prvi koji će nešto reći.").font(.tekst(14)).foregroundStyle(Color.sivaTekst)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .greska(let p):
                    StanjeEkrana(maskota: .lumi, naslov: "Komentari se nisu učitali", tekst: p, dugme: "Pokušaj ponovo") { Task { await ucitaj() } }
                        .frame(maxHeight: .infinity)
                default:
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            if case .gotovo(let l) = stanje { ForEach(redovi(l)) { r in red(r) } }
                            else { ForEach(0..<4, id: \.self) { _ in Skelet(visina: 56).padding(.vertical, 6) } }
                        }
                        .padding(.horizontal, 16).padding(.top, 4)
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            if sesija.prijavljen { unos } else {
                Text("Prijavi se da bi komentarisao.").font(.tekst(14)).foregroundStyle(Color.sivaTekst).padding(16)
            }
        }
        .background(Papir())
        .task { await ucitaj() }
        .overlay {
            if let k = meniZa {
                DonjiList(zatvori: { meniZa = nil }) {
                    VStack(spacing: 0) {
                        if k.moj {
                            stavka("Obriši komentar", "trash", opasno: true) { Task { if await Zajednica.radnja(sesija, "obrisi_komentar", ["p_id": k.id]) { await ucitaj() } } }
                        } else {
                            stavka("Prijavi komentar", "flag") { Task { _ = await Zajednica.radnja(sesija, "prijavi_sadrzaj", ["p_objava": objava.id, "p_komentar": k.id, "p_razlog": "uvreda"]) } }
                            stavka("Blokiraj \(k.nadimak)", "hand.raised", opasno: true) { Task { if await Zajednica.radnja(sesija, "blokiraj", ["p_id": k.ko, "p_da": true]) { await ucitaj() } } }
                        }
                    }
                }
            }
        }
    }

    /// Grane: odgovor ide ispod roditelja, uvučen (najviše tri nivoa, dalje ostaje na trećem).
    private func redovi(_ l: [Zajednica.Komentar]) -> [Red] {
        let deca = Dictionary(grouping: l.filter { $0.roditelj != nil }, by: { $0.roditelj! })
        func grana(_ k: Zajednica.Komentar, _ d: Int) -> [Red] { [Red(k: k, dubina: min(d, 3))] + (deca[k.id] ?? []).flatMap { grana($0, d + 1) } }
        return l.filter { $0.roditelj == nil }.flatMap { grana($0, 0) }
    }

    private func red(_ r: Red) -> some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarSlika(avatar: r.k.avatar, velicina: r.dubina == 0 ? 36 : 28)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(r.k.nadimak).font(.tekst(14, .bold))
                    Text(Zajednica.pre(r.k.created_at)).font(.tekst(12)).foregroundStyle(Color.sivaTekst)
                }
                Text(r.k.tekst).font(.tekst(15)).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 18) {
                    if sesija.prijavljen {
                        Button("Odgovori") { odgovorNa = r.k; fokus = true }.font(.tekst(13, .bold)).foregroundStyle(Color.sivaTekst)
                        Button { meniZa = r.k } label: { Image(systemName: "ellipsis").foregroundStyle(Color.sivaTekst) }.accessibilityLabel("Više")
                    }
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Button { Task { await srce(r.k) } } label: {
                VStack(spacing: 2) {
                    Image(systemName: r.k.moje_srce ? "heart.fill" : "heart").foregroundStyle(r.k.moje_srce ? Color.roze : Color.sivaTekst)
                    if r.k.srca > 0 { Text("\(r.k.srca)").font(.tekst(11, .bold)).foregroundStyle(Color.sivaTekst) }
                }
            }
            .buttonStyle(.plain).disabled(!sesija.prijavljen)
            .accessibilityLabel(r.k.moje_srce ? "Ne sviđa mi se više" : "Sviđa mi se")
        }
        .padding(.leading, CGFloat(r.dubina) * 22).padding(.vertical, 10)
    }

    private var unos: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let o = odgovorNa {
                HStack {
                    Text("Odgovaraš: \(o.nadimak)").font(.tekst(13, .semibold)).foregroundStyle(Color.sivaTekst)
                    Spacer()
                    Button { odgovorNa = nil } label: { Image(systemName: "xmark").foregroundStyle(Color.sivaTekst) }.accessibilityLabel("Otkaži odgovor")
                }
            }
            HStack(spacing: 10) {
                TextField("Napiši komentar…", text: $tekst, axis: .vertical).font(.tekst(16)).lineLimit(1...4).focused($fokus)
                    .padding(12).background(Color.kartica, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.kremTamnija, lineWidth: 1.5))
                Button { Task { await posalji() } } label: {
                    Image(systemName: "arrow.up").font(.system(size: 17, weight: .bold)).foregroundStyle(Color.naMastilu)
                        .frame(width: 46, height: 46).background(Color.mastilo, in: Circle())
                }
                .disabled(tekst.trimmingCharacters(in: .whitespaces).isEmpty || tekst.count > 500)
                .accessibilityLabel("Pošalji")
            }
        }
        .padding(16).background(Color.krem)
    }

    private func stavka(_ naziv: String, _ ikonica: String, opasno: Bool = false, radnja: @escaping () -> Void) -> some View {
        Button { meniZa = nil; radnja() } label: {
            HStack(spacing: 12) { Image(systemName: ikonica).frame(width: 24); Text(naziv).font(.tekst(16, .semibold)); Spacer() }
                .foregroundStyle(opasno ? Color.crvena : Color.mastilo).padding(.vertical, 14).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func ucitaj() async {
        do {
            let l = try await Zajednica.komentari(sesija, objava.id)
            stanje = .gotovo(l); promenjenBroj(l.count)
        } catch { stanje = .greska(error.localizedDescription) }
    }

    private func posalji() async {
        let t = tekst
        tekst = ""
        do { try await Zajednica.komentarisi(sesija, objava: objava.id, tekst: t, roditelj: odgovorNa?.id); odgovorNa = nil; await ucitaj() }
        catch { tekst = t }
    }

    private func srce(_ k: Zajednica.Komentar) async {
        guard let r = await Zajednica.srceKomentaru(sesija, k.id), case .gotovo(var l) = stanje, let i = l.firstIndex(where: { $0.id == k.id }) else { return }
        l[i].srca = r.srca; l[i].moje_srce = r.moje_srce
        stanje = .gotovo(l)
    }
}

// MARK: Poruke

struct PorukeView: View {
    @Environment(Sesija.self) private var sesija
    @State private var stanje: Ucitano<[Zajednica.Razgovor]> = Kes.ucitano("razgovori")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GornjaTraka()
                Naslov(tekst: "Poruke", velicina: 32)
                if !sesija.prijavljen {
                    StanjeEkrana(maskota: .zig, naslov: "Poruke traže nalog", tekst: "Prijavi se da bi se dopisivao sa igračima.")
                } else {
                    switch stanje {
                    case .ucitava: ForEach(0..<4, id: \.self) { _ in Skelet(visina: 64) }
                    case .greska(let p): StanjeEkrana(maskota: .lumi, naslov: "Poruke se nisu učitale", tekst: p, dugme: "Pokušaj ponovo") { Task { await ucitaj() } }
                    case .gotovo(let l) where l.isEmpty:
                        StanjeEkrana(maskota: .bloop, naslov: "Još nema poruka", tekst: "Poruku šalješ sa profila igrača ili iz objave.")
                    case .gotovo(let l):
                        VStack(spacing: 0) {
                            ForEach(Array(l.enumerated()), id: \.element.id) { i, r in
                                NavigationLink { RazgovorView(sa: r.sa, nadimak: r.nadimak, avatar: r.avatar) } label: {
                                    HStack(spacing: 12) {
                                        AvatarSlika(avatar: r.avatar, velicina: 48)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(r.nadimak).font(.tekst(16, r.neprocitanih > 0 ? .bold : .semibold))
                                            Text((r.moja ? "Ti: " : "") + r.poslednja).font(.tekst(14)).foregroundStyle(r.neprocitanih > 0 ? Color.mastilo : Color.sivaTekst).lineLimit(1)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 4) {
                                            Text(Zajednica.pre(r.kad)).font(.tekst(12)).foregroundStyle(Color.sivaTekst)
                                            if r.neprocitanih > 0 {
                                                Text("\(r.neprocitanih)").font(.tekst(12, .bold)).foregroundStyle(.white).frame(minWidth: 22, minHeight: 22)
                                                    .background(Color.roze, in: Circle())
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 14).padding(.vertical, 10).contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                if i < l.count - 1 { Divider().overlay(Color.kremTamnija) }
                            }
                        }
                        .mirna()
                    }
                }
            }
            .padding(16)
        }
        .background(Papir())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task { await ucitaj() }
        .refreshable { await ucitaj() }
    }

    private func ucitaj() async {
        guard sesija.prijavljen else { return }
        do {
            let l = try await Zajednica.razgovori(sesija)
            stanje = .gotovo(l)
            Kes.sacuvaj(l, "razgovori")
        } catch { if case .gotovo = stanje {} else { stanje = .greska(error.localizedDescription) } }
    }
}

struct RazgovorView: View {
    let sa: String
    let nadimak: String
    let avatar: String?
    @Environment(Sesija.self) private var sesija
    @State private var poruke: [Zajednica.Poruka] = []
    @State private var tekst = ""
    @State private var greska: String?
    /// Meni tuđe poruke (dug pritisak) ili razgovora (tri tačke): prijava i blokada, Apple 1.2.
    @State private var meniPoruke: Zajednica.Poruka?
    @State private var meniRazgovora = false
    @State private var potvrda: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                GornjaTraka()
                NavigationLink { ProfilIgracaView(id: sa) } label: {
                    HStack(spacing: 10) { AvatarSlika(avatar: avatar, velicina: 36); Text(nadimak).font(.tekst(17, .bold)).foregroundStyle(Color.mastilo) }
                }
                .buttonStyle(.plain)
                Spacer()
                Button { meniRazgovora = true } label: {
                    Image(systemName: "ellipsis").font(.system(size: 18, weight: .bold)).foregroundStyle(Color.mastilo).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Više")
            }
            .padding(16)
            ScrollViewReader { skrol in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if poruke.isEmpty { Text("Napiši prvu poruku.").font(.tekst(14)).foregroundStyle(Color.sivaTekst).padding(.top, 30) }
                        ForEach(poruke) { p in
                            HStack {
                                if p.moja { Spacer(minLength: 50) }
                                Text(p.tekst).font(.tekst(16)).foregroundStyle(p.moja ? Color.naMastilu : Color.mastilo)
                                    .padding(.horizontal, 14).padding(.vertical, 10)
                                    .background(p.moja ? Color.mastilo : Color.kartica, in: RoundedRectangle(cornerRadius: 18))
                                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(p.moja ? Color.clear : Color.kremTamnija, lineWidth: 1.5))
                                if !p.moja { Spacer(minLength: 50) }
                            }
                            .id(p.id)
                            .onLongPressGesture { if !p.moja { meniPoruke = p } }
                            .accessibilityAction(named: "Prijavi poruku") { if !p.moja { meniPoruke = p } }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .onChange(of: poruke.last?.id) { _, id in if let id { withAnimation { skrol.scrollTo(id, anchor: .bottom) } } }
            }
            if let greska { Text(greska).font(.tekst(13, .semibold)).foregroundStyle(Color.crvena).padding(.horizontal, 16) }
            HStack(spacing: 10) {
                TextField("Poruka…", text: $tekst, axis: .vertical).font(.tekst(16)).lineLimit(1...4)
                    .padding(12).background(Color.kartica, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.kremTamnija, lineWidth: 1.5))
                Button { Task { await posalji() } } label: {
                    Image(systemName: "arrow.up").font(.system(size: 17, weight: .bold)).foregroundStyle(Color.naMastilu)
                        .frame(width: 46, height: 46).background(Color.mastilo, in: Circle())
                }
                .disabled(tekst.trimmingCharacters(in: .whitespaces).isEmpty || tekst.count > 1000)
                .accessibilityLabel("Pošalji")
            }
            .padding(16)
        }
        .background(Papir())
        .overlay {
            if let p = meniPoruke {
                DonjiList(zatvori: { meniPoruke = nil }) {
                    VStack(spacing: 0) {
                        stavka("Prijavi poruku", "flag") { Task { await prijavi(p) } }
                        stavka("Blokiraj \(nadimak)", "hand.raised", opasno: true) { Task { await blokiraj() } }
                    }
                }
            } else if meniRazgovora {
                DonjiList(zatvori: { meniRazgovora = false }) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Zadrži prst na poruci da je prijaviš.").font(.tekst(13)).foregroundStyle(Color.sivaTekst).padding(.bottom, 6)
                        stavka("Blokiraj \(nadimak)", "hand.raised", opasno: true) { Task { await blokiraj() } }
                    }
                }
            } else if let potvrda {
                Dijalog(naslov: potvrda, tekst: "Urednik pregleda prijave u roku od 24 sata.", potvrda: "U redu", odustani: "Zatvori") { self.potvrda = nil } zatvori: { self.potvrda = nil }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task {
            // Novo stiže na svakih 5 s dok je razgovor otvoren (shortcut: bez realtime kanala; kad bude potrebno, Supabase Realtime).
            while !Task.isCancelled {
                if let l = try? await Zajednica.poruke(sesija, sa: sa), l != poruke { poruke = l }
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    private func stavka(_ naziv: String, _ ikonica: String, opasno: Bool = false, radnja: @escaping () -> Void) -> some View {
        Button { meniPoruke = nil; meniRazgovora = false; radnja() } label: {
            HStack(spacing: 12) { Image(systemName: ikonica).frame(width: 24); Text(naziv).font(.tekst(16, .semibold)); Spacer() }
                .foregroundStyle(opasno ? Color.crvena : Color.mastilo).padding(.vertical, 14).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func prijavi(_ p: Zajednica.Poruka) async {
        if await Zajednica.radnja(sesija, "prijavi_poruku", ["p_poruka": p.id, "p_razlog": "uvreda"]) { potvrda = "Hvala na prijavi" }
    }

    private func blokiraj() async {
        if await Zajednica.radnja(sesija, "blokiraj", ["p_id": sa, "p_da": true]) { potvrda = "\(nadimak) je blokiran" }
    }

    private func posalji() async {
        let t = tekst
        tekst = ""
        do {
            try await Zajednica.posaljiPoruku(sesija, za: sa, tekst: t)
            greska = nil
            poruke = (try? await Zajednica.poruke(sesija, sa: sa)) ?? poruke
        } catch {
            tekst = t
            greska = (error as? Supabase.Greska)?.poruka ?? error.localizedDescription
        }
    }
}


// MARK: Blokirani

/// Spisak blokiranih igrača sa odblokiranjem (Podešavanja → Blokirani).
struct BlokiraniView: View {
    @Environment(Sesija.self) private var sesija
    struct Red: Decodable, Identifiable { let id: String; let nadimak: String; let avatar: String? }
    @State private var stanje: Ucitano<[Red]> = .ucitava

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GornjaTraka()
                Naslov(tekst: "Blokirani", velicina: 30)
                Text("Blokirani igrači ne vide tvoje objave, komentare i profil, i ne mogu da ti pišu.").font(.tekst(14)).foregroundStyle(Color.sivaTekst)
                switch stanje {
                case .ucitava: ForEach(0..<3, id: \.self) { _ in Skelet(visina: 56) }
                case .greska(let p): StanjeEkrana(maskota: .lumi, naslov: "Spisak se nije učitao", tekst: p, dugme: "Pokušaj ponovo") { Task { await ucitaj() } }
                case .gotovo(let l) where l.isEmpty: StanjeEkrana(maskota: .bloop, naslov: "Nikog nisi blokirao", tekst: "Blokiraš iz menija objave ili sa profila igrača.")
                case .gotovo(let l):
                    VStack(spacing: 0) {
                        ForEach(Array(l.enumerated()), id: \.element.id) { i, r in
                            HStack(spacing: 12) {
                                AvatarSlika(avatar: r.avatar, velicina: 44)
                                Text(r.nadimak).font(.tekst(16, .semibold))
                                Spacer()
                                Button("Odblokiraj") {
                                    Task { if await Zajednica.radnja(sesija, "blokiraj", ["p_id": r.id, "p_da": false]) { await ucitaj() } }
                                }
                                .font(.tekst(14, .bold)).foregroundStyle(Color.mastilo).padding(.horizontal, 14).frame(height: 36)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.mastilo, lineWidth: 1.5))
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            if i < l.count - 1 { Divider().overlay(Color.kremTamnija) }
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
        do { stanje = .gotovo(try await Supabase.deljeni.rpc("moje_blokade", [:], token: try? await sesija.vazeciToken())) }
        catch { stanje = .greska(error.localizedDescription) }
    }
}


// MARK: Obaveštenja sa servera i brojači

/// Brojači za kartice: nova obaveštenja (Profil → Sanduče) i nepročitane poruke (Igrači).
@MainActor @Observable
final class Brojaci {
    static let deljeni = Brojaci()
    private(set) var obavestenja = 0
    private(set) var poruke = 0

    func osvezi(_ s: Sesija) async {
        struct B: Decodable { let obavestenja: Int; let poruke: Int }
        guard s.prijavljen, let t = try? await s.vazeciToken(), let b: B = try? await Supabase.deljeni.rpc("moji_brojevi", [:], token: t) else { return }
        if b.obavestenja + b.poruke > obavestenja + poruke { Zvuk.pusti(.obavestenje, jacina: 0.35) }
        obavestenja = b.obavestenja; poruke = b.poruke
    }
    func procitanaObavestenja() { obavestenja = 0 }
}

/// Aktivnost u Sandučetu: izazovi, novi pratioci, komentari, odgovori i srca (poslednjih 30 dana).
struct ServerskaObavestenja: View {
    @Environment(Sesija.self) private var sesija
    struct Red: Decodable, Identifiable {
        let vrsta: String; let ko: String; let nadimak: String; let avatar: String?; let tekst: String?
        let objava: Int?; let kod_sobe: String?; let kad: String; let novo: Bool
        var id: String { vrsta + ko + kad }
    }
    @State private var redovi: [Red] = []
    @State private var duelKod: String?
    @State private var sobaKod: String?

    var body: some View {
        VStack(spacing: 10) {
            ForEach(redovi) { r in red(r) }
        }
        .task {
            guard sesija.prijavljen, let t = try? await sesija.vazeciToken() else { return }
            redovi = (try? await Supabase.deljeni.rpc("moja_obavestenja", ["p_oznaci": true], token: t)) ?? []
            Brojaci.deljeni.procitanaObavestenja()
        }
        .navigationDestination(item: $duelKod) { kod in DuelView(kodSobe: kod) }
        .navigationDestination(item: $sobaKod) { kod in TakmicenjeView(kod: kod) }
    }

    @ViewBuilder private func red(_ r: Red) -> some View {
        let (ikonica, opis): (String, String) = switch r.vrsta {
        case "izazov": ("bolt.fill", "te izaziva na duel")
        case "soba": ("person.3.fill", "te zove: " + (r.tekst.flatMap(IgraTakmicenja.init(rawValue:))?.naziv ?? "kviz"))
        case "pratilac": ("person.badge.plus", "te sada prati")
        case "komentar": ("bubble.right.fill", "je komentarisao tvoju objavu")
        case "odgovor": ("arrowshape.turn.up.left.fill", "ti je odgovorio")
        case "ishod": ("flag.checkered", "je odigrao tvoj izazov")
        default: ("heart.fill", "voli tvoju objavu")
        }
        let sadrzaj = HStack(alignment: .top, spacing: 12) {
            AvatarSlika(avatar: r.avatar, velicina: 44)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: ikonica).font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 20, height: 20).background(Color.roze, in: Circle()).overlay(Circle().stroke(Color.krem, lineWidth: 2)).offset(x: 4, y: 4)
                }
            VStack(alignment: .leading, spacing: 3) {
                (Text(r.nadimak).font(.tekst(15, .bold)) + Text(" " + opis).font(.tekst(15)))
                if let t = r.tekst, r.vrsta != "soba" { Text("„\(t)”").font(.tekst(13)).foregroundStyle(Color.sivaTekst).lineLimit(2) }
                Text(Zajednica.pre(r.kad)).font(.tekst(12)).foregroundStyle(Color.sivaTekst)
            }
            Spacer(minLength: 0)
            if r.novo { Circle().fill(Color.roze).frame(width: 10, height: 10).accessibilityLabel("Novo") }
        }
        .padding(14)
        .background(Color.kartica, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(r.novo ? Color.mastilo : Color.kremTamnija, lineWidth: r.novo ? 2.5 : 1.5))
        .accessibilityElement(children: .combine)
        if r.vrsta == "ishod" {
            sadrzaj
        } else if r.vrsta == "izazov", let kod = r.kod_sobe {
            Button { duelKod = kod } label: { sadrzaj }.buttonStyle(.plain)
        } else if r.vrsta == "soba", let kod = r.kod_sobe {
            Button { sobaKod = kod } label: { sadrzaj }.buttonStyle(.plain)
        } else {
            NavigationLink { ProfilIgracaView(id: r.ko) } label: { sadrzaj }.buttonStyle(.plain)
        }
    }
}


// MARK: Na mreži

/// Svi igrači koji su sada u aplikaciji (ne samo praćeni): broj gore, spisak ispod, ulasci i izlasci uživo.
/// shortcut: osvežava se na 8 s dok je ekran otvoren; kad igrača bude mnogo više, preći na Supabase Realtime presence.
struct NaMreziView: View {
    @Environment(Sesija.self) private var sesija
    @Environment(\.dismiss) private var nazad
    @State private var lista: Ucitano<[Zajednica.NaMrezi]> = .ucitava

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    KrugDugme(ikonica: "chevron.left", opis: "Nazad") { nazad() }
                    Naslov(tekst: "Na mreži", velicina: 30)
                    Spacer()
                }
                switch lista {
                case .ucitava: ForEach(0..<5, id: \.self) { _ in Skelet(visina: 64) }
                case .greska(let p): StanjeEkrana(maskota: .lumi, naslov: "Spisak se nije učitao", tekst: p, dugme: "Pokušaj ponovo") { Task { await ucitaj() } }
                case .gotovo(let l):
                    HStack(spacing: 10) {
                        Circle().fill(Color.teal).frame(width: 10, height: 10)
                        Text("\(l.count)").font(.naslov(34)).monospacedDigit().contentTransition(.numericText())
                        Text(l.count == 1 ? "igrač je sada u igri" : "igrača je sada u igri").font(.tekst(15, .semibold)).foregroundStyle(Color.sivaTekst)
                    }
                    .animation(.snappy, value: l.count)
                    if l.isEmpty {
                        StanjeEkrana(maskota: .bloop, naslov: "Trenutno nema nikog", tekst: "Kad neko otvori aplikaciju, pojaviće se ovde.")
                    } else {
                        VStack(spacing: 0) {
                            ForEach(l) { i in
                                NavigationLink { ProfilIgracaView(id: i.ko) } label: { red(i) }
                                    .buttonStyle(.plain)
                                    .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                                if i != l.last { Divider().padding(.leading, 68) }
                            }
                        }
                        .padding(.horizontal, 12).mirna()
                        .animation(.spring(duration: 0.4), value: l)
                    }
                }
            }
            .padding(16)
        }
        .background(Papir())
        .toolbar(.hidden, for: .navigationBar)
        .refreshable { await ucitaj() }
        .task {
            while !Task.isCancelled { await ucitaj(); try? await Task.sleep(for: .seconds(8)) }
        }
    }

    private func red(_ i: Zajednica.NaMrezi) -> some View {
        HStack(spacing: 12) {
            AvatarSlika(avatar: i.avatar, velicina: 44)
                .overlay(alignment: .bottomTrailing) { Circle().fill(Color.teal).frame(width: 12, height: 12).overlay(Circle().stroke(Color.krem, lineWidth: 2)) }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(i.ko == sesija.korisnikId ? "\(i.nadimak) (ti)" : i.nadimak).font(.tekst(15, .bold)).foregroundStyle(Color.mastilo).lineLimit(1)
                    if i.pratim { Image(systemName: "person.fill.checkmark").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.teal).accessibilityLabel("pratiš") }
                }
                Text(i.igra.map { "igra " + (Zajednica.nazivIgre[$0] ?? $0) } ?? "u aplikaciji").font(.tekst(13)).foregroundStyle(Color.sivaTekst).lineLimit(1)
            }
            Spacer()
            Text(Zajednica.pre(i.od)).font(.tekst(12)).foregroundStyle(Color.sivaTekst)
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.sivaTekst)
        }
        .padding(.vertical, 10).contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func ucitaj() async {
        guard let l = await Zajednica.naMrezi(sesija) else { if case .ucitava = lista { lista = .greska("Proveri internet vezu.") }; return }
        withAnimation { lista = .gotovo(l) }
    }
}
