import SwiftUI

/// Lobi i igra za 2–8 igrača (vlasnik 03.11.2026): domaćin bira igru, broj igrača, svako za sebe ili timove po dvoje,
/// protiv računara, pravih igrača ili mešano; poziva prijatelje (Sanduče + baner u aplikaciji) ili deli kod/link
/// librumkviz://soba/KOD. Pozvani bira Prihvatam ili Odbijam. Izlaz je na svakom koraku. Logika: Servisi/Takmicenje.swift.
struct TakmicenjeView: View {
    /// Gost: ulazi kodom (poziv, link).
    var kod: String? = nil
    /// Izazov sa profila: soba za dvoje, ovaj igrač je već pozvan.
    var pozovi: (id: String, ime: String)? = nil

    @Environment(Sesija.self) private var sesija
    @Environment(\.dismiss) private var zatvori

    @State private var soba: Takmicenje.Soba?
    @State private var greska: String?
    @State private var radi = false
    @State private var potvrdaIzlaska = false
    @State private var prijava = false

    // Postavka (domaćin)
    @State private var igra: IgraTakmicenja = .pro
    @State private var velicina = 4
    @State private var timovi = false
    @State private var protivnici = "mesano"
    @State private var tezina = "normalno"
    @State private var prijatelji: [PozivView.Prijatelj] = []
    @State private var pozvani: Set<String> = []

    // Igra
    @State private var pitanja: [Pitanje] = []
    @State private var reci: [Rec] = []
    @State private var pocetak: Date?
    @State private var mojKraj = false

    /// Razvojna proba na simulatoru (`-bezPrijave`): igra protiv računara bez servera, da se ekrani vide bez lozinke.
    private var proba: Bool { LibrumKvizApp.bezPrijave && !sesija.prijavljen }
    private var ja: String? { sesija.korisnikId ?? (proba ? "proba" : nil) }
    private var jaDomacin: Bool { soba?.domacin == ja }

    var body: some View {
        ZStack {
            Papir()
            if !sesija.prijavljen && !proba {
                StanjeEkrana(maskota: .zig, naslov: "Igra sa drugima traži nalog", tekst: "Ostali moraju da znaju protiv koga igraju.",
                             dugme: "Prijavi se") { prijava = true }
                    .padding(20).pop().padding(20)
            } else if let soba, soba.status == "igra", !mojKraj, pocetak != nil {
                igraEkran(soba)
            } else if let soba, soba.status == "igra" || soba.status == "kraj", pocetak != nil || soba.status == "kraj" {
                KrajTakmicenja(soba: soba, ja: ja, pocetak: pocetak ?? .distantPast, ponovo: jaDomacin ? { ponovo() } : nil) {
                    NotificationCenter.default.post(name: .naPocetak, object: nil); zatvori()
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            KrugDugme(ikonica: "xmark", opis: soba == nil ? "Zatvori" : "Izađi iz sobe") { izlaz() }
                            Spacer()
                        }
                        if let greska {
                            StanjeEkrana(maskota: .lumi, naslov: "Ne ide", tekst: greska, dugme: "Nazad") { zatvori() }.mirna()
                        } else if let soba {
                            cekaonica(soba)
                        } else if kod != nil {
                            UcitavanjeMaskota(maskota: .mimi, tekst: "Ulazim u sobu…")
                        } else {
                            postavka
                        }
                    }
                    .padding(16)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .bezSvajpaNazad()
        .fullScreenCover(isPresented: $prijava) { PrijavaTok() }
        .overlay {
            if potvrdaIzlaska {
                Dijalog(naslov: soba?.status == "igra" ? "Predaješ?" : jaDomacin ? "Otkazuješ sobu?" : "Izlaziš iz sobe?",
                        tekst: soba?.status == "igra" ? "Tvoj rezultat do sada ostaje u tabeli, ostali igraju dalje." :
                            jaDomacin ? "Pozvani će videti da je soba otkazana." : "Mesto se oslobađa za drugog igrača.",
                        potvrda: "Izađi", odustani: "Ostani", opasno: true) {
                    potvrdaIzlaska = false
                    Task { if let id = soba?.id { await Takmicenje.izadji(id) }; zatvori() }
                } zatvori: { potvrdaIzlaska = false }
            }
        }
        .task { await pripremi() }
        .task(id: soba?.id) { await prati() }
        .onChange(of: soba?.status) { _, s in if s == "igra" { Task { await ucitajSadrzaj() } } }
        .onDisappear { Zvuk.stani(.cekanje) }
    }

    private func izlaz() {
        if soba == nil || soba?.status == "otkazano" || greska != nil { zatvori() } else { potvrdaIzlaska = true }
    }

    // MARK: Postavka

    private var postavka: some View {
        VStack(alignment: .leading, spacing: 18) {
            Naslov(tekst: pozovi.map { "Izazovi: \($0.ime)" } ?? "Igraj sa drugima", velicina: 32)
            Text("Svi dobijaju ista pitanja u isto vreme, a tabela se menja uživo.").font(.tekst(15)).foregroundStyle(Color.sivaTekst)

            Oznaka(tekst: "Igra")
            VStack(spacing: 10) {
                ForEach(IgraTakmicenja.allCases) { g in
                    Button { igra = g } label: {
                        HStack(spacing: 12) {
                            Image(g.slika).resizable().scaledToFill().frame(width: 52, height: 52).clipShape(RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(g.naziv).font(.tekst(16, .bold))
                                Text(g.opis).font(.tekst(13)).foregroundStyle(Color.sivaTekst)
                            }
                            Spacer()
                            Image(systemName: igra == g ? "checkmark.circle.fill" : "circle").font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(igra == g ? Color.teal : Color.kremTamnija)
                        }
                        .foregroundStyle(Color.mastilo).padding(10)
                        .background(Color.kartica, in: RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(igra == g ? Color.mastilo : Color.kremTamnija, lineWidth: igra == g ? 2.5 : 1.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(igra == g ? .isSelected : [])
                }
            }

            if pozovi == nil {
                Oznaka(tekst: "Igrača")
                HStack(spacing: 16) {
                    KrugDugme(ikonica: "minus", opis: "Manje igrača") { velicina = max(2, velicina - 1); if velicina % 2 == 1 || velicina < 4 { timovi = false } }
                    Text("\(velicina)").font(.naslov(34)).monospacedDigit().frame(minWidth: 44)
                    KrugDugme(ikonica: "plus", opis: "Više igrača") { velicina = min(8, velicina + 1); if velicina % 2 == 1 { timovi = false } }
                    Spacer()
                }
                if velicina >= 4 && velicina % 2 == 0 {
                    PodvuceniIzbor(izbor: $timovi, opcije: [(false, "Svako za sebe"), (true, "Timovi po dvoje")])
                }
                Oznaka(tekst: "Protivnici")
                PodvuceniIzbor(izbor: $protivnici, opcije: [("racunar", "Računar"), ("pravi", "Pravi igrači"), ("mesano", "Mešano")])
                Text(protivnici == "racunar" ? "Igraš odmah protiv botova." : protivnici == "pravi" ? "Igraju samo oni koji uđu u sobu." :
                        "Ko ne stigne do početka, umesto njega igra računar.")
                    .font(.tekst(13)).foregroundStyle(Color.sivaTekst)
            }
            if protivnici != "pravi" {
                Oznaka(tekst: "Težina računara")
                PodvuceniIzbor(izbor: $tezina, opcije: [("lako", "Lako"), ("normalno", "Normalno"), ("tesko", "Teško")])
            }
            if protivnici != "racunar" && pozovi == nil && !prijatelji.isEmpty {
                Oznaka(tekst: "Pozovi (\(pozvani.count) od \(velicina - 1))")
                ForEach(prijatelji) { p in
                    let izabran = pozvani.contains(p.id)
                    Button {
                        if izabran { pozvani.remove(p.id) } else if pozvani.count < velicina - 1 { pozvani.insert(p.id) }
                    } label: {
                        HStack(spacing: 10) {
                            AvatarSlika(avatar: p.avatar, velicina: 36)
                            Text(p.nadimak).font(.tekst(15, .semibold))
                            Spacer()
                            Image(systemName: izabran ? "checkmark.circle.fill" : "plus.circle").font(.system(size: 22)).foregroundStyle(izabran ? Color.teal : Color.sivaTekst)
                        }
                        .foregroundStyle(Color.mastilo).padding(10).mirna()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(p.nadimak + (izabran ? ", pozvan" : ""))
                }
            }
            Button(radi ? "Spremam…" : protivnici == "racunar" ? "Igraj" : "Napravi sobu") { Task { await napravi() } }
                .buttonStyle(.zuto).disabled(radi)
        }
    }

    // MARK: Čekaonica

    @ViewBuilder private func cekaonica(_ s: Takmicenje.Soba) -> some View {
        Naslov(tekst: s.vrsta.naziv, velicina: 32)
        Text("\(s.velicina) igrača · \(s.timovi ? "timovi po dvoje" : "svako za sebe")").font(.tekst(14, .semibold)).foregroundStyle(Color.sivaTekst)
        VStack(spacing: 6) {
            Text("Kod sobe").font(.tekst(13, .bold))
            Text(s.kod).font(.system(size: 40, weight: .heavy, design: .monospaced)).tracking(6).textSelection(.enabled)
            ShareLink(item: "Igrajmo \(s.vrsta.naziv) u Librum kvizu! Kod sobe: \(s.kod) · librumkviz://soba/\(s.kod)") {
                Image(systemName: "square.and.arrow.up").font(.system(size: 18, weight: .bold)).foregroundStyle(Color.naMastilu)
                    .frame(width: 52, height: 46).background(Color.mastilo, in: RoundedRectangle(cornerRadius: 14))
            }
            .accessibilityLabel("Pošalji poziv")
        }
        .frame(maxWidth: .infinity).padding(16).pop(.zuta, radijus: 20)

        let usli = s.mesta.filter { $0.user_id != nil && !$0.pozvan }.count
        Text("U sobi \(usli) od \(s.velicina)").font(.tekst(16, .bold))
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(s.mesta) { m in
                HStack(spacing: 10) {
                    if m.user_id != nil { AvatarSlika(avatar: m.avatar, velicina: 36).opacity(m.pozvan ? 0.45 : 1) } else {
                        Image(systemName: "person.badge.plus").font(.system(size: 16, weight: .bold)).foregroundStyle(Color.sivaTekst).frame(width: 36, height: 36)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(m.nadimak ?? (s.protivnici == "pravi" ? "Slobodno" : "Računar ako niko ne dođe")).font(.tekst(14, .bold)).lineLimit(1)
                            .foregroundStyle(m.user_id == nil ? Color.sivaTekst : Color.mastilo)
                        Text(m.pozvan ? "čeka odgovor…" : s.timovi ? Takmicenje.imeTima(m.tim) + (m.user_id == s.domacin ? " · domaćin" : "")
                                : m.user_id == s.domacin ? "domaćin" : m.user_id == nil ? "" : "spreman")
                            .font(.tekst(11, .semibold)).foregroundStyle(m.pozvan ? Color.narandzasta : Color.sivaTekst)
                    }
                    Spacer(minLength: 0)
                }
                .padding(10).mirna()
            }
        }
        if jaDomacin {
            Button(radi ? "Pokrećem…" : "Počni") { Task { await pokreni() } }
                .buttonStyle(.zuto).disabled(radi || (s.protivnici == "pravi" && !s.timovi && usli < 2))
            if s.protivnici == "pravi" && !s.timovi && usli < 2 {
                Text("Čeka se bar jedan igrač.").font(.tekst(13)).foregroundStyle(Color.sivaTekst)
            }
        } else {
            Label("Čeka se da domaćin pokrene igru.", systemImage: "hourglass").font(.tekst(15, .semibold)).foregroundStyle(Color.sivaTekst)
        }
    }

    // MARK: Igra

    @ViewBuilder private func igraEkran(_ s: Takmicenje.Soba) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                KrugDugme(ikonica: "xmark", opis: "Predaj") { potvrdaIzlaska = true }
                TabelaUzivo(soba: s, ja: ja, pocetak: pocetak ?? Date())
            }
            .padding(.horizontal, 16).padding(.top, 8)
            switch s.vrsta {
            case .vesanje:
                VesanjeTakmicenja(reci: reci) { prijavi($0) }
            case .brzi:
                BrziTakmicenja(pitanja: pitanja, seme: s.seme) { prijavi($0) }
            case .pro, .book, .slikari:
                KvizTakmicenja(pitanja: pitanja, naziv: s.vrsta.naziv) { prijavi($0) }
            }
        }
    }

    private func prijavi(_ r: MojRezultat) {
        guard let id = soba?.id else { return }
        if r.gotov { mojKraj = true; Zvuk.pusti(.kraj, jacina: 0.4) }
        if proba, let i = soba?.mesta.firstIndex(where: { $0.user_id == ja }) {
            soba?.mesta[i].poeni = r.poeni; soba?.mesta[i].tacnih = r.tacnih; soba?.mesta[i].odigrano = r.odigrano; soba?.mesta[i].gotov = r.gotov
            return
        }
        Task {
            if let nova = try? await Takmicenje.rezultat(id, poeni: r.poeni, tacnih: r.tacnih, odigrano: r.odigrano, ms: r.ms, gotov: r.gotov) { soba = nova }
        }
    }

    // MARK: Server

    private func pripremi() async {
        guard sesija.prijavljen || proba, soba == nil else { return }
        if let kod {
            do { soba = try await Takmicenje.udji(kod) } catch { greska = Takmicenje.poruka(error) }
            return
        }
        if let p = pozovi { pozvani = [p.id]; velicina = 2; protivnici = "pravi" }
        if let t = try? await sesija.vazeciToken() {
            prijatelji = (try? await Supabase.deljeni.rpc("osvajanje_za_poziv", [:], token: t)) ?? []
        }
    }

    private func napravi() async {
        radi = true; defer { radi = false }
        if proba { await napraviProbu(); return }
        do {
            let sadrzaj = try await Takmicenje.izaberi(igra, tezina: tezina)
            let nova = try await Takmicenje.napravi(igra: igra, velicina: velicina, timovi: timovi, protivnici: protivnici, tezina: tezina,
                                                    sadrzaj: sadrzaj, pozovi: protivnici == "racunar" ? [] : Array(pozvani))
            soba = protivnici == "racunar" ? try await Takmicenje.pokreni(nova.id) : nova
        } catch { greska = Takmicenje.poruka(error) }
    }

    private func napraviProbu() async {
        do {
            let d = try JSONSerialization.data(withJSONObject: try await Takmicenje.izaberi(igra, tezina: tezina))
            if igra == .vesanje { reci = try JSONDecoder().decode([Rec].self, from: d) } else { pitanja = try JSONDecoder().decode([Pitanje].self, from: d) }
        } catch { greska = Takmicenje.poruka(error); return }
        let imena = ["Mimi", "Zig", "Bloop", "Lumi", "Luna", "Max", "Sara"]
        let timova = timovi ? velicina / 2 : velicina
        let mesta = (0..<velicina).map { m in
            Takmicenje.Mesto(mesto: m, user_id: m == 0 ? "proba" : nil, bot: m == 0 ? nil : imena[m - 1], pozvan: false, tim: m % timova,
                             nadimak: m == 0 ? "Proba" : imena[m - 1], avatar: nil, poeni: 0, tacnih: 0, odigrano: 0, ms: 0, gotov: false)
        }
        pocetak = Date()
        soba = Takmicenje.Soba(id: "proba", kod: "PROBA1", igra: igra.rawValue, domacin: "proba", velicina: velicina, nacin: timovi ? "timovi" : "svako",
                               protivnici: "racunar", tezina: tezina, seme: Int64.random(in: 1...999_999), broj: igra.broj, status: "igra", mesta: mesta)
    }

    private func pokreni() async {
        guard let id = soba?.id else { return }
        radi = true; defer { radi = false }
        do { soba = try await Takmicenje.pokreni(id) } catch { greska = Takmicenje.poruka(error) }
    }

    /// Revanš: ista postavka, novi sadržaj, isti ljudi pozvani ponovo.
    private func ponovo() {
        guard let s = soba else { return }
        igra = s.vrsta; velicina = s.velicina; timovi = s.timovi; protivnici = s.protivnici; tezina = s.tezina
        pozvani = Set(s.mesta.compactMap(\.user_id).filter { $0 != ja })
        soba = nil; pitanja = []; reci = []; pocetak = nil; mojKraj = false
        Task { await napravi() }
    }

    private func ucitajSadrzaj() async {
        guard let s = soba, pocetak == nil else { return }
        do {
            if s.vrsta == .vesanje { reci = try await Takmicenje.reci(s.id) } else { pitanja = try await Takmicenje.pitanja(s.id) }
            Zvuk.stani(.cekanje)
            pocetak = Date()
        } catch { greska = "Pitanja nisu stigla. Proveri internet." }
    }

    /// Osvežavanje sobe dok se čeka i igra; staje kad je kraj ili je soba otkazana.
    private func prati() async {
        guard soba != nil, !proba else { return }
        if soba?.status == "ceka" { Zvuk.pusti(.cekanje, jacina: 0.2, ponavljaj: true) }
        while !Task.isCancelled, let s = soba, s.status == "ceka" || s.status == "igra" {
            try? await Task.sleep(for: Takmicenje.osvezavanje)
            guard !Task.isCancelled, let nova = try? await Takmicenje.stanje(s.id) else { continue }
            let pre = s.mesta.filter { $0.user_id != nil && !$0.pozvan }.count
            if nova.mesta.filter({ $0.user_id != nil && !$0.pozvan }).count > pre { Zvuk.pusti(.protivnikUsao, jacina: 0.45) }
            soba = nova
            if nova.status == "otkazano" { greska = "Domaćin je otkazao sobu." }
        }
        Zvuk.stani(.cekanje)
    }
}

/// Šta igra javlja posle svakog odgovora (zbirno).
struct MojRezultat { var poeni = 0; var tacnih = 0; var odigrano = 0; var ms = 0; var gotov = false }

// MARK: Tabela

/// Traka uživo iznad igre: mesto, ime i poeni svih (botovi iz semena), a u timovima i zbir tima.
private struct TabelaUzivo: View {
    let soba: Takmicenje.Soba
    let ja: String?
    let pocetak: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { k in
            let redovi = Takmicenje.tabela(soba, ja: ja, proteklo: k.date.timeIntervalSince(pocetak))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if soba.timovi {
                        ForEach(Array(Takmicenje.timovi(redovi).enumerated()), id: \.element.tim) { i, t in
                            celija(mesto: i + 1, ime: Takmicenje.imeTima(t.tim), poeni: t.poeni, ja: t.clanovi.contains(where: \.ja), avatar: nil)
                        }
                        Rectangle().fill(Color.kremTamnija).frame(width: 2, height: 34).padding(.horizontal, 4).accessibilityHidden(true)
                    }
                    ForEach(Array(redovi.enumerated()), id: \.element.id) { i, r in
                        celija(mesto: i + 1, ime: r.ime, poeni: r.poeni, ja: r.ja, avatar: r.avatar, gotov: r.gotov)
                    }
                }
                .animation(.spring(duration: 0.4), value: redovi.map(\.mesto))
            }
        }
        .frame(height: 50)
    }

    private func celija(mesto: Int, ime: String, poeni: Int, ja: Bool, avatar: String?, gotov: Bool = false) -> some View {
        HStack(spacing: 6) {
            Text("\(mesto).").font(.tekst(12, .bold)).foregroundStyle(Color.sivaTekst)
            if let avatar { AvatarSlika(avatar: avatar, velicina: 24) }
            VStack(alignment: .leading, spacing: 0) {
                Text(ime).font(.tekst(12, .bold)).lineLimit(1)
                Text("\(poeni)").font(.naslov(15)).monospacedDigit().contentTransition(.numericText())
            }
            if gotov { Image(systemName: "flag.checkered").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.sivaTekst) }
        }
        .foregroundStyle(ja ? Color.tinta : Color.mastilo)
        .padding(.horizontal, 10).frame(height: 46)
        .background(ja ? Color.zuta : Color.kartica, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.mastilo, lineWidth: ja ? 2 : 1))
        .accessibilityElement(children: .combine)
    }
}

/// Kraj: tabela (i timovi), dok ostali još igraju osvežava se uživo; domaćin može odmah revanš.
private struct KrajTakmicenja: View {
    let soba: Takmicenje.Soba
    let ja: String?
    let pocetak: Date
    let ponovo: (() -> Void)?
    let pocetna: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { k in
            let redovi = Takmicenje.tabela(soba, ja: ja, proteklo: soba.status == "kraj" ? .infinity : k.date.timeIntervalSince(pocetak))
            let svi = redovi.allSatisfy(\.gotov)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Naslov(tekst: svi ? (pobedio(redovi) ? "Pobeda!" : "Kraj igre") : "Čekamo ostale…", velicina: 36)
                    Text(soba.vrsta.naziv).font(.tekst(15, .semibold)).foregroundStyle(Color.sivaTekst)
                    if soba.timovi {
                        ForEach(Array(Takmicenje.timovi(redovi).enumerated()), id: \.element.tim) { i, t in
                            HStack {
                                Text("\(i + 1). \(Takmicenje.imeTima(t.tim))").font(.tekst(17, .bold))
                                Text(t.clanovi.map(\.ime).joined(separator: " i ")).font(.tekst(13)).foregroundStyle(Color.sivaTekst).lineLimit(1)
                                Spacer()
                                Text("\(t.poeni)").font(.naslov(22)).monospacedDigit()
                            }
                            .padding(14).pop(i == 0 ? .zuta : .kartica, radijus: 18)
                        }
                        Oznaka(tekst: "Igrači").padding(.top, 6)
                    }
                    ForEach(Array(redovi.enumerated()), id: \.element.id) { i, r in
                        HStack(spacing: 12) {
                            Text("\(i + 1)").font(.naslov(22)).frame(width: 30)
                            if !r.bot { AvatarSlika(avatar: r.avatar, velicina: 40) } else {
                                Image(systemName: "cpu").font(.system(size: 16, weight: .bold)).frame(width: 40, height: 40).background(Color.udubljeno, in: Circle())
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.ime + (r.ja ? " (ti)" : "")).font(.tekst(16, .bold))
                                Text(r.gotov ? "\(r.tacnih) tačnih" : "igra još…").font(.tekst(13)).foregroundStyle(Color.sivaTekst)
                            }
                            Spacer()
                            Text("\(r.poeni)").font(.naslov(24)).monospacedDigit().contentTransition(.numericText())
                        }
                        .foregroundStyle(Color.mastilo).padding(12)
                        .background(r.ja ? Color.zuta.opacity(0.35) : Color.kartica, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.mastilo, lineWidth: r.ja ? 2 : 1))
                    }
                    if let ponovo, svi { Button("Revanš", action: ponovo).buttonStyle(.zuto).padding(.top, 6) }
                    Button("Početak", action: pocetna).buttonStyle(.sekundarno)
                }
                .padding(16)
            }
            .onChange(of: svi) { _, s in if s { Zvuk.pusti(pobedio(redovi) ? .pobeda : .kraj, jacina: 0.5) } }
        }
    }

    private func pobedio(_ r: [Takmicenje.Rezultat]) -> Bool {
        soba.timovi ? Takmicenje.timovi(r).first?.clanovi.contains(where: \.ja) == true : r.first?.ja == true
    }
}

// MARK: Igre

/// PRO, Book i Slikari: isti niz pitanja za sve, 20 s po pitanju, brži tačan nosi više.
private struct KvizTakmicenja: View {
    let pitanja: [Pitanje]
    let naziv: String
    let javi: (MojRezultat) -> Void
    @State private var i = 0
    @State private var r = MojRezultat()
    @State private var prikazi: [Prikaz] = []
    @State private var spremna = -1

    var body: some View {
        ScrollView {
            if i < prikazi.count {
                // Slikari: delo iznad kartice (isti prikaz kao u kvizu za jednog igrača).
                if let url = prikazi[i].slika {
                    SlikaPitanja(url: url, najvisa: 240) { spremna = i }
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.mastilo, lineWidth: 2))
                        .padding(.horizontal, 16).padding(.top, 8)
                        .id("slika\(i)")
                }
                // Kartica (i njen sat) kreće tek kad je slika tu, da pitanje ne stigne pre dela.
                if prikazi[i].slika == nil || spremna == i {
                PitanjeKartica(oznaka: "\(naziv) · \(i + 1) od \(prikazi.count)", prikaz: prikazi[i], sekundi: Takmicenje.sekundiPitanja) { izabran, ms in
                    let tacno = izabran == prikazi[i].tacan
                    r.poeni += Takmicenje.poeni(tacno: tacno, ms: ms); if tacno { r.tacnih += 1 }
                    r.odigrano += 1; r.ms += ms
                    i += 1
                    r.gotov = i >= prikazi.count
                    javi(r)
                }
                .id(i)
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))
                .padding(16)
                }
            }
        }
        .animation(.spring(duration: 0.4), value: i)
        .onAppear {
            guard prikazi.isEmpty else { return }
            prikazi = pitanja.filter { $0.options.count == 4 }.map(Prikaz.init)
            SlikeUnapred.deljene.pripremi(prikazi.compactMap(\.slika))
            if prikazi.isEmpty { r.gotov = true; javi(r) }
        }
    }
}

/// Brzi kviz: 60 s, tačno/netačno; koja tvrdnja nudi tačan odgovor određuje seme sobe (isto svima).
private struct BrziTakmicenja: View {
    let pitanja: [Pitanje]
    let seme: Int64
    let javi: (MojRezultat) -> Void
    @State private var izjave: [BrziKviz.Izjava] = []
    @State private var i = 0
    @State private var igra = BrziKviz()
    @State private var pocetak = Date()
    @State private var poslednji: Bool?
    @State private var kraj = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { k in
            let ostalo = max(0, Double(BrziKviz.sekundiRunde) - k.date.timeIntervalSince(pocetak))
            VStack(spacing: 16) {
                HStack {
                    Text("\(Int(ostalo.rounded(.up))) s").font(.naslov(30)).monospacedDigit().foregroundStyle(ostalo <= 10 ? Color.crvena : Color.mastilo)
                    Spacer()
                    if igra.mnozilac > 1 { Text("×\(igra.mnozilac)").font(.naslov(26)).foregroundStyle(Color.narandzasta) }
                    Text("\(igra.poeni)").font(.naslov(30)).monospacedDigit().contentTransition(.numericText())
                }
                if i < izjave.count, !kraj {
                    let iz = izjave[i]
                    VStack(alignment: .leading, spacing: 14) {
                        Oznaka(tekst: ostalo <= Double(BrziKviz.sekundiZavrsnice) ? "Završnica · duplo" : "Tvrdnja \(i + 1)", boja: .tinta)
                        Text(iz.pitanje).font(.tekst(19, .semibold)).fixedSize(horizontal: false, vertical: true)
                        Text(iz.prikazano).font(.naslov(26)).fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(20).pop(.zuta)
                    .id(i)
                    .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                    HStack(spacing: 14) {
                        dugme("xmark", .crvena, "Netačno") { odgovori(false, ostalo: ostalo) }
                        dugme("checkmark", .teal, "Tačno") { odgovori(true, ostalo: ostalo) }
                    }
                }
                Spacer()
            }
            .padding(16)
            .onChange(of: ostalo <= 0) { _, isteklo in if isteklo { zavrsi() } }
        }
        .animation(.spring(duration: 0.3), value: i)
        .sensoryFeedback(trigger: i) { _, _ in poslednji == true ? .success : .error }
        .onAppear {
            guard izjave.isEmpty else { return }
            izjave = pitanja.enumerated().map { n, p in var r = Takmicenje.slucajno(seme, n); return BrziKviz.Izjava(p, nasumicno: { r.sledeci() }) }
            pocetak = Date()
        }
    }

    private func dugme(_ ikonica: String, _ boja: Color, _ opis: String, _ radnja: @escaping () -> Void) -> some View {
        Button(action: radnja) {
            Image(systemName: ikonica).font(.system(size: 30, weight: .heavy)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 76).background(boja, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.mastilo, lineWidth: 2.5))
        }
        .buttonStyle(BezPrigusenja())
        .accessibilityLabel(opis)
    }

    private func odgovori(_ kaze: Bool, ostalo: Double) {
        guard !kraj, i < izjave.count else { return }
        let pogodio = igra.odgovor(izjave[i], kaze: kaze, zavrsnica: ostalo <= Double(BrziKviz.sekundiZavrsnice))
        poslednji = pogodio
        Zvuk.pusti(pogodio ? .tacno : .netacno, jacina: 0.4)
        i += 1
        if i >= izjave.count { zavrsi() } else { javi(MojRezultat(poeni: igra.poeni, tacnih: igra.tacnih, odigrano: i)) }
    }

    private func zavrsi() {
        guard !kraj else { return }
        kraj = true
        javi(MojRezultat(poeni: igra.poeni, tacnih: igra.tacnih, odigrano: i, ms: BrziKviz.sekundiRunde * 1000, gotov: true))
    }
}

/// Vešanje: iste reči redom; posle pogotka ili promašaja reči sledeća stiže sama.
private struct VesanjeTakmicenja: View {
    let reci: [Rec]
    let javi: (MojRezultat) -> Void
    @State private var i = 0
    @State private var igra = Vesanje(rec: "")
    @State private var r = MojRezultat()
    @State private var pocetak = Date()

    var body: some View {
        ScrollView {
            if i < reci.count {
                let rec = reci[i]
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                Oznaka(tekst: "Reč \(i + 1) od \(reci.count)" + (rec.category.map { " · \($0)" } ?? ""), boja: .tinta)
                                if let h = rec.hint { Text(h).font(.tekst(17, .semibold)).fixedSize(horizontal: false, vertical: true) }
                            }
                            Spacer(minLength: 0)
                            VesalaCrtez(greske: Vesanje.pocetniZivoti - igra.zivoti, kraj: igra.status == .poraz).frame(width: 80, height: 96)
                        }
                        Text(igra.prikaz.joined(separator: " ")).font(.system(size: 26, weight: .heavy, design: .monospaced))
                            .frame(maxWidth: .infinity).minimumScaleFactor(0.5).lineLimit(2)
                            .accessibilityLabel(igra.prikaz.map { $0 == "_" ? "prazno" : $0 }.joined(separator: " "))
                    }
                    .padding(20).pop(igra.status == .pobeda ? .tealSvetla : igra.status == .poraz ? .crvenaSvetla : .zuta)
                    if igra.status == .igra {
                        AzbukaTastatura(igra: igra) { slovo in
                            igra.pogodi(slovo)
                            Zvuk.pusti(igra.rec.uppercased().contains(slovo) ? .slovoDa : .slovoNe, jacina: 0.4)
                        }
                    } else {
                        Text(igra.status == .pobeda ? "Pogođeno: +\(igra.poeni)" : "Reč je bila: \(rec.word.uppercased())").font(.tekst(17, .bold))
                    }
                }
                .padding(16)
            }
        }
        .onAppear { if i < reci.count, igra.rec.isEmpty { igra = Vesanje(rec: reci[i].word); pocetak = Date() } }
        .onChange(of: igra.status) { _, s in
            guard s != .igra else { return }
            Zvuk.pusti(s == .pobeda ? .osvojeno : .netacno, jacina: 0.5)
            r.poeni += igra.poeni; r.odigrano += 1; if s == .pobeda { r.tacnih += 1 }
            r.ms += Int(Date().timeIntervalSince(pocetak) * 1000)
            r.gotov = i + 1 >= reci.count
            javi(r)
            Task {
                try? await Task.sleep(for: .seconds(1.6))
                guard !r.gotov else { return }
                i += 1; igra = Vesanje(rec: reci[i].word); pocetak = Date()
            }
        }
    }
}

// MARK: Poziv

/// Baner preko cele aplikacije kad te neko pozove u sobu: Odbijam (✕) ili Prihvatam (✓).
struct PozivBaner: View {
    let poziv: Takmicenje.Poziv
    let odgovor: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            AvatarSlika(avatar: poziv.avatar, velicina: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(poziv.od) te zove").font(.tekst(15, .bold))
                Text("\(poziv.naziv) · \(poziv.velicina) igrača\(poziv.nacin == "timovi" ? " · timovi" : "")").font(.tekst(13)).foregroundStyle(Color.sivaTekst)
            }
            Spacer(minLength: 0)
            Button { odgovor(false) } label: {
                Image(systemName: "xmark").font(.system(size: 16, weight: .bold)).foregroundStyle(Color.mastilo).frame(width: 44, height: 44).background(Color.udubljeno, in: Circle())
            }
            .accessibilityLabel("Odbijam")
            Button { odgovor(true) } label: {
                Image(systemName: "checkmark").font(.system(size: 16, weight: .bold)).foregroundStyle(.white).frame(width: 44, height: 44).background(Color.teal, in: Circle())
            }
            .accessibilityLabel("Prihvatam")
        }
        .foregroundStyle(Color.mastilo)
        .padding(12).pop(radijus: 20)
        .padding(.horizontal, 12)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
