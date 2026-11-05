import SwiftUI

/// Firma: za sve zgrada, rekord, botovi i zaposleni; za vlasnika kasa, plata, ključne oblasti,
/// botovi (zaposli, obuči), nadogradnja, dividenda i otpuštanje; za ostale „Zaposli se”.
struct FirmaView: View {
    /// `-upravljanjeProba` (samo DEBUG): tuđa firma prikazuje Upravljanje radi provere izgleda; server radnje i dalje odbija.
    #if DEBUG
    static let probaUpravljanja = ProcessInfo.processInfo.arguments.contains("-upravljanjeProba")
    #else
    static let probaUpravljanja = false
    #endif
    let firmaId: String
    let stanje: Karijera.Stanje
    let promena: () -> Void

    @Environment(Sesija.self) private var sesija
    @State private var firma: Ucitano<Karijera.FirmaDetalj> = .ucitava
    @State private var poruka: String?
    @State private var radi = false
    @State private var botTema = false
    @State private var kljucneList = false
    @State private var otpusti: Karijera.Zaposleni?
    @State private var preimenovanje = false
    @State private var novoIme = ""
    @State private var prijavaImena = false
    @State private var sefList = false
    @State private var pitanjaList = false
    @State private var slobodniList = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GornjaTraka()
                switch firma {
                case .ucitava: VStack(spacing: 12) { Skelet(visina: 240, radijus: 24); Skelet(visina: 120) }
                case .greska(let p): StanjeEkrana(maskota: .lumi, naslov: "Firma se nije učitala", tekst: p, dugme: "Pokušaj ponovo") { Task { await ucitaj() } }
                case .gotovo(let f): sadrzaj(f)
                }
            }
            .padding(16)
        }
        .background(Papir())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task { await ucitaj() }
        .refreshable { await ucitaj() }
        .overlay(alignment: .bottom) {
            if let poruka {
                Text(poruka).font(.tekst(14, .bold)).foregroundStyle(Color.naMastilu).padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.mastilo, in: RoundedRectangle(cornerRadius: 16, style: .continuous)).padding(16)
                    .onTapGesture { self.poruka = nil }
                    .task { try? await Task.sleep(for: .seconds(4)); withAnimation { self.poruka = nil } }
            }
        }
        .overlay {
            if botTema, case .gotovo(let f) = firma {
                TemaJednaList(naslov: "Zaposli asistenta", podnaslov: "1.000 iz kase. Asistent pomaže svima u firmi na 5 pitanja dnevno iz svoje teme.",
                              teme: f.teme.map(\.tema)) { t in botTema = false; Task { await vlasnik { try await Karijera.zaposliBota(f.id, tema: t) } } } zatvori: { botTema = false }
            }
        }
        .overlay {
            if kljucneList, case .gotovo(let f) = firma {
                KljucneList(teme: f.teme.map(\.tema), izabrane: f.kljucne) { l in kljucneList = false; Task { await vlasnik { try await Karijera.podesi(f.id, udeo: nil, kljucne: l) } } } zatvori: { kljucneList = false }
            }
        }
        .overlay {
            if sefList, case .gotovo(let f) = firma {
                SefList(nivo: f.sefNivo) { n in sefList = false; Task { await vlasnik { try await Karijera.podesiSefa(f.id, n) } } } zatvori: { sefList = false }
            }
        }
        .overlay {
            if slobodniList, case .gotovo(let f) = firma {
                SlobodniDaniList(dani: f.slobodni ?? []) { d in slobodniList = false; Task { await vlasnik { try await Karijera.podesiSlobodne(f.id, dani: d) } } } zatvori: { slobodniList = false }
            }
        }
        .overlay {
            if pitanjaList, case .gotovo(let f) = firma {
                PitanjaFirmeList(struka: f.struka_udeo ?? 60, fokus: f.fokus ?? [], udeo: f.fokus_udeo ?? [], teza: f.teza ?? false) { s, fo, u, t in
                    pitanjaList = false; Task { await vlasnik { try await Karijera.podesiPitanja(f.id, struka: s, fokus: fo, udeo: u, teza: t) } }
                } zatvori: { pitanjaList = false }
            }
        }
        .overlay {
            if preimenovanje, case .gotovo(let f) = firma {
                DonjiList(zatvori: { preimenovanje = false }) {
                    VStack(alignment: .leading, spacing: 12) {
                        Naslov(tekst: "Ime firme", velicina: 26)
                        TextField("Ime firme", text: $novoIme).font(.naslov(20)).textInputAutocapitalization(.words).autocorrectionDisabled()
                            .padding(14).background(Color.kartica, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.mastilo, lineWidth: 2))
                        Text("3 do 32 znaka. Ime mora biti jedinstveno: dve firme ne mogu da se zovu isto.").font(.tekst(12)).foregroundStyle(Color.sivaTekst)
                        Button("Sačuvaj") { preimenovanje = false; Task { await vlasnik { try await Karijera.preimenuj(f.id, ime: novoIme) } } }
                            .buttonStyle(.primarno).disabled(novoIme.trimmingCharacters(in: .whitespaces).count < 3)
                    }
                }
            }
        }
        .overlay {
            if prijavaImena, case .gotovo(let f) = firma {
                Dijalog(naslov: "Prijavi ime firme?", tekst: "Ako ime vređa ili je neprimereno. Posle tri prijave ime se skida, a vlasnik bira novo.", potvrda: "Prijavi", odustani: "Odustani", opasno: true) {
                    prijavaImena = false
                    Task { do { _ = try await Karijera.prijaviIme(f.id); poruka = "Hvala, prijava je primljena." } catch { poruka = error.localizedDescription } }
                } zatvori: { prijavaImena = false }
            }
        }
        .overlay {
            if let z = otpusti, case .gotovo(let f) = firma {
                Dijalog(naslov: "Otpusti \(z.ime)?", tekst: "Vraća se u Korporaciju i 5 dana ne može da se vrati u tvoju firmu.", potvrda: "Otpusti", odustani: "Odustani", opasno: true) {
                    otpusti = nil; Task { await vlasnik { try await Karijera.otpusti(f.id, igrac: z.id) } }
                } zatvori: { otpusti = nil }
            }
        }
    }

    @ViewBuilder private func sadrzaj(_ f: Karijera.FirmaDetalj) -> some View {
        ZStack(alignment: .bottom) {
            Nebo(mesto: f.korporacija ? "korporacija" : f.id)
            Image(f.slika).resizable().scaledToFit().frame(height: 230).padding(.top, 30)
            Ulica(mesto: f.korporacija ? "korporacija" : f.id)
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.mastilo, lineWidth: 2))
        .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Naslov(tekst: f.ime, velicina: 28)
                Spacer()
                if f.ja_vlasnik {
                    Button { novoIme = f.ime; preimenovanje = true } label: { Image(systemName: "pencil").font(.system(size: 17, weight: .bold)).frame(width: 44, height: 44) }
                        .buttonStyle(.plain).accessibilityLabel("Promeni ime firme")
                } else if !f.npc && !f.korporacija {
                    Button { prijavaImena = true } label: { Image(systemName: "flag").font(.system(size: 16, weight: .bold)).frame(width: 44, height: 44) }
                        .buttonStyle(.plain).foregroundStyle(Color.sivaTekst).accessibilityLabel("Prijavi neprimereno ime firme")
                }
            }
            Text(f.korporacija ? "Šef · plata 40% · uvek otvorena" : "\(Karijera.naziviNivoa[f.nivo - 1]) · vlasnik \(f.ja_vlasnik ? "ti" : f.vlasnik_ime)\(f.npc ? " (uprava)" : "")")
                .font(.tekst(14, .semibold)).foregroundStyle(Color.sivaTekst)
        }
        if !f.korporacija {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                Plocica(ikonica: "trophy", vrednost: "\(f.rekord)", naziv: f.rekord_ime.map { "Rekord · \($0)" } ?? "Rekord", boja: .narandzasta)
                Plocica(ikonica: "person.3", vrednost: "\(f.zaposlenih)", naziv: "Zaposlenih", boja: .ljubicasta)
                Plocica(ikonica: "banknote", vrednost: f.ja_vlasnik ? Karijera.novac(f.kasa ?? 0) : f.udeoNaziv.components(separatedBy: " · ").last ?? "", naziv: f.ja_vlasnik ? "Kasa" : "Plata", boja: .teal)
                Plocica(ikonica: "star.circle", vrednost: f.kljucne.isEmpty ? "–" : "×2", naziv: f.kljucne.prefix(3).joined(separator: ", "), boja: .roze)
            }
        }
        if f.korporacija { KorporacijaObjasnjenje() }
        if !f.ja_vlasnik {
            Text("Šef: \(Karijera.sefOpis(f.sefNivo, stres: f.stres))\nPitanja: \(Karijera.mesavinaOpis(struka: f.struka_udeo, fokus: f.fokus, udeo: f.fokus_udeo, teza: f.teza))\nSlobodni dani: \(Karijera.daniOpis(f.slobodni))\(f.slobodan_danas == true ? " · danas se radi prekovremeno (+10%)" : "")")
                .font(.tekst(13, .semibold)).foregroundStyle(Color.sivaTekst)
        }
        if f.ja_vlasnik || Self.probaUpravljanja { upravljanje(f) }
        else if !f.korporacija && stanje.posao?.id != f.id {
            Button("Zaposli se ovde") { Task { await zaposliSe(f) } }.buttonStyle(.zuto).disabled(radi || stanje.uProbnom)
            if stanje.uProbnom { Text("Prvo završi probni rad u Korporaciji.").font(.tekst(13)).foregroundStyle(Color.sivaTekst) }
        }
        if !f.botovi.isEmpty {
            Text("Asistenti").font(.naslov(22)).padding(.top, 4)
            ForEach(f.botovi) { b in
                HStack(spacing: 12) {
                    Image(b.slika).resizable().scaledToFit().frame(width: 56, height: 56).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(b.ime) · \(b.tema)").font(.tekst(15, .bold))
                        Text("Tačnost \(b.nivo)% · danas još \(b.pomoci_ostalo) pomoći").font(.tekst(13)).foregroundStyle(Color.sivaTekst)
                    }
                    Spacer()
                    if f.ja_vlasnik, b.nivo < 90, let cena = Karijera.ceneObuke[b.nivo] {
                        Button { Task { await vlasnik { try await Karijera.obuciBota(b.id) } } } label: {
                            VStack(spacing: 0) { Image(systemName: "graduationcap.fill"); Text(Karijera.novac(Double(cena))).font(.tekst(11, .bold)) }
                                .frame(width: 56, height: 48)
                        }
                        .buttonStyle(.plain).foregroundStyle(Color.teal)
                        .accessibilityLabel("Obuči asistenta \(b.ime) za \(cena)")
                    }
                }
                .padding(10).mirna()
            }
        }
        if !f.zaposleni.isEmpty {
            Text("Zaposleni").font(.naslov(22)).padding(.top, 4)
            VStack(spacing: 0) {
                ForEach(f.zaposleni) { z in
                    HStack {
                        NavigationLink { KarijeraCVView(igrac: z.id) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(z.ime).font(.tekst(15, .bold))
                                Text(Karijera.titule[min(z.titula, 3)]).font(.tekst(13)).foregroundStyle(Color.sivaTekst)
                            }
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        if f.ja_vlasnik {
                            Button { otpusti = z } label: { Image(systemName: "person.badge.minus").font(.system(size: 17, weight: .semibold)).frame(width: 44, height: 44) }
                                .buttonStyle(.plain).foregroundStyle(Color.crvena).accessibilityLabel("Otpusti \(z.ime)")
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    if z.id != f.zaposleni.last?.id { Divider().overlay(Color.kremTamnija) }
                }
            }
            .mirna()
        }
    }

    /// Upravljanje (vlasnik 05.11: „lepši UI, sada kao AI”): runda, kasa u tri pločice, plata, pa zbijen spisak podešavanja
    /// sa linijama između redova; bez kartice u kartici.
    @ViewBuilder private func upravljanje(_ f: Karijera.FirmaDetalj) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink { KarijeraRundaView(firma: f.kratko, botovi: f.botovi) { Task { await ucitaj(); promena() } }.bezSvajpaNazad() } label: { Text("Igraj rundu u svojoj firmi") }
                .buttonStyle(.primarno)
            Label("Bar jedna runda dnevno. Održavanje \(Karijera.novac(Double(f.odrzavanje))) dnevno iz kase.", systemImage: "info.circle")
                .font(.tekst(13)).foregroundStyle(Color.sivaTekst)
        }
        // Kasa kao tamna kartica (vlasnik 05.11: „pregledno, ne bledo”): iznos krupno, tri radnje; kad radnja ne može, piše zašto.
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("KASA FIRME").font(.tekst(12, .bold)).tracking(1.5).foregroundStyle(.white.opacity(0.7))
                    Text(Karijera.novac(f.kasa ?? 0)).font(.naslov(36)).foregroundStyle(.white)
                }
                Spacer()
                Image(systemName: "banknote").font(.system(size: 26, weight: .semibold)).foregroundStyle(Color(hex: 0x7FE0C9))
            }
            HStack(spacing: 8) {
                KasaPlocica(ikonica: "arrow.down.circle.fill", naslov: "Dividenda",
                            opis: f.dividenda_danas ? "uzeta danas" : (f.kasa ?? 0) <= 0 ? "kasa prazna" : "10% tebi",
                            omoguceno: !f.dividenda_danas && (f.kasa ?? 0) > 0) {
                    Task { await vlasnik { try await Karijera.dividenda(f.id) }; Zvuk.pusti(.karijeraKasa, jacina: 0.5) }
                }
                KasaPlocica(ikonica: "person.crop.circle.badge.plus", naslov: "Asistent",
                            opis: f.botovi.count >= f.nivo ? "nema mesta" : (f.kasa ?? 0) < 1000 ? "treba \(Karijera.novac(1000))" : Karijera.novac(1000),
                            omoguceno: f.botovi.count < f.nivo && (f.kasa ?? 0) >= 1000) { botTema = true }
                if let cena = f.cena_nadogradnje, let treba = f.treba_zaposlenih {
                    KasaPlocica(ikonica: "building.2.fill", naslov: "Nadogradi",
                                opis: f.aktivnih < treba ? "zaposleni \(f.aktivnih)/\(treba)" : (f.kasa ?? 0) < cena ? "treba \(Karijera.novac(cena))" : Karijera.novac(cena),
                                omoguceno: (f.kasa ?? 0) >= cena && f.aktivnih >= treba) {
                        Task { await vlasnik { try await Karijera.nadogradi(f.id) } }
                    }
                }
            }
            if let cena = f.cena_nadogradnje, let treba = f.treba_zaposlenih {
                Text("Sledeći nivo, \(Karijera.naziviNivoa[f.nivo].lowercased()): \(Karijera.novac(cena)) u kasi i \(treba) \(treba == 1 ? "aktivan zaposleni" : "aktivnih zaposlenih").")
                    .font(.tekst(12, .semibold)).foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(16)
        .background(Color(hex: 0x123F44), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.mastilo, lineWidth: 2))
        VStack(alignment: .leading, spacing: 8) {
            Oznaka(tekst: "Plata zaposlenima")
            PodvuceniIzbor(izbor: Binding(get: { f.udeo }, set: { novi in Task { await vlasnik { try await Karijera.podesi(f.id, udeo: novi, kljucne: nil) } } }),
                           opcije: [("skrt", "Škrt 50%"), ("posten", "Pošten 65%"), ("izdasan", "Izdašan 80%")])
            Text("Menja se jednom u 7 dana.").font(.tekst(12)).foregroundStyle(Color.sivaTekst)
        }
        VStack(alignment: .leading, spacing: 8) {
            Oznaka(tekst: "Podešavanja firme")
            VStack(spacing: 0) {
                Button { novoIme = f.ime; preimenovanje = true } label: { RedPodesavanja(ikonica: "pencil", boja: .teal, naziv: "Ime firme", vrednost: f.ime) }
                Divider().overlay(Color.kremTamnija).padding(.leading, 60)
                Button { kljucneList = true } label: {
                    RedPodesavanja(ikonica: "star.fill", boja: .roze, naziv: "Ključne oblasti ×2", vrednost: f.kljucne.isEmpty ? "nijedna" : f.kljucne.joined(separator: ", "))
                }
                Divider().overlay(Color.kremTamnija).padding(.leading, 60)
                Button { sefList = true } label: { RedPodesavanja(ikonica: "person.wave.2.fill", boja: .narandzasta, naziv: "Šef", vrednost: (f.stres ?? 0) > 0 ? "+\(Int(((f.stres ?? 0) * 100).rounded()))% plate" : Karijera.jacine[max(f.sefNivo.tacno, f.sefNivo.netacno)]) }
                Divider().overlay(Color.kremTamnija).padding(.leading, 60)
                Button { slobodniList = true } label: { RedPodesavanja(ikonica: "calendar", boja: .ljubicasta, naziv: "Slobodni dani", vrednost: Karijera.daniOpis(f.slobodni)) }
                Divider().overlay(Color.kremTamnija).padding(.leading, 60)
                Button { pitanjaList = true } label: { RedPodesavanja(ikonica: "square.stack.3d.up.fill", boja: .nebo, naziv: "Pitanja u firmi", vrednost: "struka \(f.struka_udeo ?? 60)%") }
            }
            .buttonStyle(.plain)
            .mirna()
        }
    }

    private func ulazakTekst(_ f: Karijera.FirmaDetalj) -> String {
        "Odigraj bar jednu rundu dnevno u svojoj firmi: 1 propušten dan, asistent daje otkaz; 3 dana, firma se zatvara."
    }

    private func ucitaj() async {
        do { firma = .gotovo(try await Karijera.firma(firmaId)) }
        catch { if case .gotovo = firma { poruka = error.localizedDescription } else { firma = .greska(error.localizedDescription) } }
    }

    private func vlasnik(_ posao: () async throws -> Karijera.FirmaDetalj) async {
        radi = true; defer { radi = false }
        do { let f = try await posao(); withAnimation { firma = .gotovo(f) }; promena() }
        catch { withAnimation { poruka = error.localizedDescription } }
    }

    private func zaposliSe(_ f: Karijera.FirmaDetalj) async {
        radi = true; defer { radi = false }
        do { _ = try await Karijera.zaposliSe(f.id); Zvuk.pusti(.karijeraZvono, jacina: 0.6); poruka = "Zaposlen si u firmi \(f.ime)."; promena(); await ucitaj() }
        catch { poruka = error.localizedDescription }
    }
}

struct TemaJednaList: View {
    let naslov: String
    let podnaslov: String
    let teme: [String]
    let izaberi: (String) -> Void
    let zatvori: () -> Void
    var body: some View {
        DonjiList(zatvori: zatvori) {
            VStack(alignment: .leading, spacing: 12) {
                Naslov(tekst: naslov, velicina: 26)
                Text(podnaslov).font(.tekst(14)).foregroundStyle(Color.sivaTekst)
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(teme, id: \.self) { t in
                            Button { izaberi(t) } label: {
                                Text(t.capitalized).font(.tekst(15, .semibold)).frame(maxWidth: .infinity, alignment: .leading).padding(12).mirna()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 340)
            }
        }
    }
}

struct KljucneList: View {
    let teme: [String]
    @State var izabrane: [String]
    let sacuvaj: ([String]) -> Void
    let zatvori: () -> Void
    var body: some View {
        DonjiList(zatvori: zatvori) {
            VStack(alignment: .leading, spacing: 12) {
                Naslov(tekst: "Ključne oblasti", velicina: 26)
                Text("Do 3 oblasti u kojima tačan odgovor vredi duplo. Zaposleni jaki u tim oblastima dolaze kod tebe.")
                    .font(.tekst(14)).foregroundStyle(Color.sivaTekst)
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(teme, id: \.self) { t in
                            let da = izabrane.contains(t)
                            Button {
                                if da { izabrane.removeAll { $0 == t } } else if izabrane.count < 3 { izabrane.append(t) }
                            } label: {
                                HStack {
                                    Image(systemName: da ? "checkmark.square.fill" : "square")
                                    Text(t.capitalized).font(.tekst(15, .semibold))
                                    Spacer()
                                }
                                .foregroundStyle(Color.mastilo).padding(12).mirna()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 320)
                Button("Sačuvaj") { sacuvaj(izabrane) }.buttonStyle(.primarno)
            }
        }
    }
}

/// Berza poslova: Korporacija, NPC firme i firme igrača. Filter: moja struka ili sve.
struct BerzaView: View {
    let stanje: Karijera.Stanje
    let promena: () -> Void
    @State private var samoStruka = true
    @State private var lista: Ucitano<[Karijera.Firma]> = .ucitava

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                GornjaTraka()
                Naslov(tekst: "Berza poslova", velicina: 30)
                Text("Ista tačna odgovora vrede različito u različitim firmama: ključne oblasti nose ×2, a plata zavisi od vlasnika.")
                    .font(.tekst(14)).foregroundStyle(Color.sivaTekst)
                PodvuceniIzbor(izbor: $samoStruka, opcije: [(true, "Moja struka"), (false, "Sve firme")])
                switch lista {
                case .ucitava: VStack(spacing: 10) { ForEach(0..<4, id: \.self) { _ in Skelet(visina: 120, radijus: 20) } }
                case .greska(let p): StanjeEkrana(maskota: .lumi, naslov: "Berza se nije učitala", tekst: p, dugme: "Pokušaj ponovo") { Task { await ucitaj() } }
                case .gotovo(let l) where l.isEmpty: StanjeEkrana(maskota: .bloop, naslov: "Nema firmi", tekst: "Za tvoju struku još nema otvorenih firmi.")
                case .gotovo(let l):
                    ForEach(l) { f in
                        NavigationLink { FirmaView(firmaId: f.id, stanje: stanje, promena: promena) } label: {
                            VStack(alignment: .leading, spacing: 0) {
                                FirmaKartica(firma: f, kasa: nil, mojaFirma: f.vlasnik != nil && f.vlasnik == Sesija.trenutna?.korisnikId)
                                if !f.korporacija {
                                    Text("\(f.udeoNaziv) · \(f.zaposlenih) zaposlenih · \(f.botova) \(f.botova == 1 ? "asistent" : "asistenata")\nŠef: \(Karijera.sefOpis(f.sefNivo, stres: f.stres)) · \(Karijera.mesavinaOpis(struka: f.struka_udeo, fokus: f.fokus, udeo: f.fokus_udeo, teza: f.teza))")
                                        .font(.tekst(12, .semibold)).foregroundStyle(Color.sivaTekst).padding(.horizontal, 6).padding(.top, 6)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .background(Papir())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task(id: samoStruka) { await ucitaj() }
        .refreshable { await ucitaj() }
    }

    private func ucitaj() async {
        if case .gotovo = lista {} else { lista = .ucitava }
        // Moja firma je prva na berzi (vlasnik 05.11), ostale ostaju kako ih server poređa.
        do {
            let ja = Sesija.trenutna?.korisnikId
            let l = try await Karijera.berza(pozicija: samoStruka ? stanje.pozicija : nil)
            lista = .gotovo(l.filter { $0.vlasnik != nil && $0.vlasnik == ja } + l.filter { !($0.vlasnik != nil && $0.vlasnik == ja) })
        }
        catch { lista = .greska(error.localizedDescription) }
    }
}

/// Otvaranje officea: stil zgrade (8), ime iz ponuđenih delova, botovi (koliko je probni rad dao).
struct OtvoriOfficeView: View {
    let stanje: Karijera.Stanje
    let botova: Int
    let gotovo: () -> Void

    @Environment(\.dismiss) private var nazad
    @State private var stil = 1
    /// Ime upisuje igrač (vlasnik 04.11); server proverava dužinu, znakove, ružne reči i da li je zauzeto.
    @State private var ime = ""
    @FocusState private var imeFokus: Bool
    @State private var botTeme: [String] = []
    @State private var greska: String?
    @State private var radi = false
    /// Teme sa brojem pitanja: bot za temu bez pitanja ne bi imao gde da pomogne.
    @State private var temeSaBrojem: [Karijera.Tema] = []
    @State private var slobodni: [Int] = []

    private var oblast: String { stanje.mojaPozicija?.oblast ?? "" }
    private var teme: [String] {
        temeSaBrojem.isEmpty ? (stanje.mojaPozicija?.teme ?? []) : temeSaBrojem.filter { $0.pitanja >= 10 }.map(\.tema)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GornjaTraka()
                Naslov(tekst: "Tvoj office", velicina: 30)
                Image(Karijera.slikaZgrade(korporacija: false, nivo: 1, stil: stil)).resizable().scaledToFit()
                    .frame(maxWidth: .infinity).frame(height: 200).accessibilityHidden(true)
                Text("Počinješ u garaži. Sa kasom i zaposlenima rasteš do nebodera. Ovako raste izabrani izgled:").font(.tekst(14)).foregroundStyle(Color.sivaTekst)
                // Niz od garaže do nebodera za izabrani stil (vlasnik 05.11: da se vidi u šta mala zgrada prerasta).
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(1...5, id: \.self) { n in
                        VStack(spacing: 4) {
                            Image(Karijera.slikaZgrade(korporacija: false, nivo: n, stil: stil)).resizable().scaledToFit().frame(height: CGFloat(28 + n * 12))
                            Text(Karijera.naziviNivoa[n - 1]).font(.tekst(10, .bold)).foregroundStyle(Color.sivaTekst).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        if n < 5 { Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.sivaTekst).padding(.bottom, 20) }
                    }
                }
                .padding(12).mirna()
                .accessibilityElement(children: .ignore).accessibilityLabel("Rast firme: garaža, kancelarija, sprat, poslovna zgrada, neboder")

                Oznaka(tekst: "Izgled")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                    ForEach(1...Karijera.naziviStila.count, id: \.self) { s in
                        Button { withAnimation { stil = s } } label: {
                            VStack(spacing: 4) {
                                Image(Karijera.slikaZgrade(korporacija: false, nivo: 5, stil: s)).resizable().scaledToFit().frame(height: 74)
                                Text(Karijera.naziviStila[s - 1]).font(.tekst(12, .bold))
                            }
                            .frame(maxWidth: .infinity).padding(6)
                            .pop(stil == s ? .zuta : .kartica, radijus: 14)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Stil \(Karijera.naziviStila[s - 1])")
                        .accessibilityAddTraits(stil == s ? .isSelected : [])
                    }
                }

                Oznaka(tekst: "Ime firme")
                TextField("npr. Marko Sport", text: $ime)
                    .font(.naslov(22)).textInputAutocapitalization(.words).autocorrectionDisabled()
                    .focused($imeFokus).submitLabel(.done)
                    .padding(14)
                    .background(Color.kartica, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(imeFokus ? Color.mastilo : Color.kremTamnija, lineWidth: imeFokus ? 2.5 : 1.5))
                    .onChange(of: ime) { _, n in if n.count > 32 { ime = String(n.prefix(32)) } }
                Text("3 do 32 znaka. Ime vide svi igrači; neprimereno ime se skida posle prijava.")
                    .font(.tekst(12)).foregroundStyle(Color.sivaTekst)

                if botova > 0 {
                    Oznaka(tekst: "Asistenti (\(botTeme.count) od \(botova))")
                    Text("Svaki asistent zna jednu temu i pomaže na 5 pitanja dnevno.").font(.tekst(13)).foregroundStyle(Color.sivaTekst)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(teme, id: \.self) { t in
                            let da = botTeme.contains(t)
                            Button {
                                if da { botTeme.removeAll { $0 == t } } else if botTeme.count < botova { botTeme.append(t) }
                            } label: {
                                Text(t.capitalized).font(.tekst(14, .semibold)).frame(maxWidth: .infinity).frame(height: 44)
                                    .foregroundStyle(da ? Color.tinta : .mastilo)
                                    .background(da ? Color.zuta : Color.kartica, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.mastilo, lineWidth: da ? 2 : 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Oznaka(tekst: "Slobodni dani (do 3)")
                SlobodniDaniIzbor(dani: $slobodni)
                Text(SlobodniDaniIzbor.objasnjenje).font(.tekst(12)).foregroundStyle(Color.sivaTekst).fixedSize(horizontal: false, vertical: true)
                if let greska { Text(greska).font(.tekst(14, .semibold)).foregroundStyle(Color.crvena) }
                Button("Otvori office") { Task { await otvori() } }.buttonStyle(.primarno).disabled(ime.trimmingCharacters(in: .whitespaces).count < 3 || radi)
            }
            .padding(16)
        }
        .background(Papir())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task { if let p = stanje.pozicija { temeSaBrojem = (try? await Karijera.temePozicije(p)) ?? [] } }
        .onAppear { KarijeraMuzika.pusti(.karijeraOffice, jacina: 0.3) }
        .onDisappear { KarijeraMuzika.stani() }
    }

    private func otvori() async {
        radi = true; defer { radi = false }
        do {
            let n = try await Karijera.otvoriFirmu(ime: ime, stil: stil, botovi: botTeme)
            if !slobodni.isEmpty { _ = try? await Karijera.podesiSlobodne(n.firma, dani: slobodni) }
            KarijeraMuzika.stani(); Zvuk.pusti(.karijeraUnapredjenje); gotovo(); nazad() }
        catch { greska = error.localizedDescription }
    }
}

/// CV igrača: pozicija, titula, kapital, firme, ekspertiza i vremenska linija.
struct KarijeraCVView: View {
    let igrac: String?
    @State private var cv: Ucitano<Karijera.CV> = .ucitava

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GornjaTraka()
                switch cv {
                case .ucitava: VStack(spacing: 12) { Skelet(visina: 90); Skelet(visina: 140); Skelet(visina: 200) }
                case .greska(let p): StanjeEkrana(maskota: .lumi, naslov: "CV se nije učitao", tekst: p, dugme: "Pokušaj ponovo") { Task { await ucitaj() } }
                case .gotovo(let c): sadrzaj(c)
                }
            }
            .padding(16)
        }
        .background(Papir())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task { await ucitaj() }
    }

    @ViewBuilder private func sadrzaj(_ c: Karijera.CV) -> some View {
        HStack(spacing: 14) {
            AvatarSlika(avatar: c.avatar, velicina: 72)
            VStack(alignment: .leading, spacing: 3) {
                Naslov(tekst: c.ime, velicina: 26)
                Text("\(Karijera.titule[min(c.titula, 3)]) · \(c.pozicija ?? "")").font(.tekst(14, .semibold)).foregroundStyle(Color.sivaTekst)
                if let p = c.posao { Text("Radi u: \(p.ime)").font(.tekst(13)).foregroundStyle(Color.sivaTekst).lineLimit(1) }
            }
        }
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            Plocica(ikonica: "chart.line.uptrend.xyaxis", vrednost: Karijera.novac(c.neto), naziv: "Neto vrednost", boja: .teal)
            Plocica(ikonica: "rosette", vrednost: "\(c.ugled)", naziv: "Ugled", boja: .roze)
            Plocica(ikonica: "checkmark.circle", vrednost: "\(c.tacnih)", naziv: "Tačnih u \(c.rundi) rundi", boja: .narandzasta)
            Plocica(ikonica: "shield.lefthalf.filled", vrednost: "\(c.preuzimanja) · \(c.odbrana)", naziv: "Preuzeo · odbranio", boja: .ljubicasta)
        }
        if !c.firme.isEmpty {
            Text("Firme").font(.naslov(22))
            ForEach(c.firme) { f in FirmaKartica(firma: f, kasa: nil, mojaFirma: false) }
        }
        if !c.ekspertiza.isEmpty {
            Text("Ekspertiza").font(.naslov(22))
            VStack(spacing: 8) {
                ForEach(c.ekspertiza, id: \.tema) { e in
                    HStack {
                        Text(e.tema.capitalized).font(.tekst(15, .semibold))
                        Spacer()
                        HStack(spacing: 2) {
                            ForEach(0..<5, id: \.self) { i in
                                Image(systemName: i < zvezdice(e.ocena) ? "star.fill" : "star").font(.system(size: 13)).foregroundStyle(Color.narandzasta)
                            }
                        }
                        .accessibilityLabel("\(zvezdice(e.ocena)) od 5")
                        Text("\(e.ocena)").font(.tekst(13, .bold)).monospacedDigit().frame(width: 54, alignment: .trailing)
                    }
                }
            }
            .padding(14).mirna()
        }
        if !c.dogadjaji.isEmpty {
            Text("Karijera").font(.naslov(22))
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(c.dogadjaji.enumerated()), id: \.offset) { i, d in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            Circle().fill(Color.teal).frame(width: 10, height: 10).padding(.top, 5)
                            if i < c.dogadjaji.count - 1 { Rectangle().fill(Color.kremTamnija).frame(width: 2) }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(d.tekst).font(.tekst(14, .semibold)).fixedSize(horizontal: false, vertical: true)
                            if let dt = Karijera.datum(d.kad) { Text(dt.formatted(.dateTime.day().month().year().locale(.srpski))).font(.tekst(12)).foregroundStyle(Color.sivaTekst) }
                        }
                        .padding(.bottom, 12)
                    }
                }
            }
            .padding(14).mirna()
        }
    }

    /// Zvezdice ekspertize: 1 od 100, 2 od 300, 3 od 800, 4 od 2.000, 5 od 5.000 poena.
    private func zvezdice(_ o: Int) -> Int { [100, 300, 800, 2000, 5000].filter { o >= $0 }.count }

    private func ucitaj() async {
        do { cv = .gotovo(try await Karijera.cv(igrac)) } catch { cv = .greska(error.localizedDescription) }
    }
}

struct KarijeraRangView: View {
    /// Ugrađeno u glavnu Rang listu: bez strelice nazad, naslova i sopstvenog skrolovanja.
    var ugradjeno = false
    @State private var vrsta = "neto"
    @State private var lista: Ucitano<[Karijera.RedRanga]> = .ucitava

    var body: some View {
        if ugradjeno { sadrzaj.task(id: vrsta) { await ucitaj() } }
        else {
            ScrollView { sadrzaj.padding(16) }
                .background(Papir())
                .toolbar(.hidden, for: .navigationBar)
                .toolbar(.hidden, for: .tabBar)
                .task(id: vrsta) { await ucitaj() }
        }
    }

    private var sadrzaj: some View {
            VStack(alignment: .leading, spacing: 12) {
                if !ugradjeno {
                    GornjaTraka()
                    Naslov(tekst: "Rang lista", velicina: 30)
                }
                PodvuceniIzbor(izbor: $vrsta, opcije: [("neto", "Neto vrednost"), ("sezona", "Sezona"), ("firme", "Najveće firme")])
                Text(vrsta == "sezona" ? "Poeni u tekućem tromesečju. Na kraju sezone lista kreće iz početka, zgrade i CV ostaju."
                     : vrsta == "firme" ? "Broj zaposlenih u svim firmama vlasnika." : "Kapital + kasa svih firmi + vrednost zgrada.")
                    .font(.tekst(13)).foregroundStyle(Color.sivaTekst)
                switch lista {
                case .ucitava: VStack(spacing: 8) { ForEach(0..<5, id: \.self) { _ in Skelet(visina: 52) } }
                case .greska(let p): StanjeEkrana(maskota: .lumi, naslov: "Lista se nije učitala", tekst: p, dugme: "Pokušaj ponovo") { Task { await ucitaj() } }
                case .gotovo(let l) where l.isEmpty: StanjeEkrana(maskota: .bloop, naslov: "Lista je prazna", tekst: "Budi prvi: odigraj rundu.")
                case .gotovo(let l):
                    VStack(spacing: 0) {
                        ForEach(Array(l.enumerated()), id: \.element.id) { i, r in
                            NavigationLink { KarijeraCVView(igrac: r.id) } label: {
                                HStack(spacing: 12) {
                                    Text("\(i + 1)").font(.naslov(17)).frame(width: 32, height: 32)
                                        .background(i < 3 ? [Color.zuta, .nebo, .roze][i] : Color.udubljeno, in: RoundedRectangle(cornerRadius: 9))
                                        .foregroundStyle(Color.tinta)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(r.ime).font(.tekst(15, .semibold)).lineLimit(1)
                                        if let p = r.pozicija { Text(p).font(.tekst(12)).foregroundStyle(Color.sivaTekst) }
                                    }
                                    Spacer()
                                    Text(Karijera.novac(r.vrednost)).font(.naslov(17)).monospacedDigit()
                                }
                                .padding(.horizontal, 14).padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                            if i < l.count - 1 { Divider().overlay(Color.kremTamnija) }
                        }
                    }
                    .mirna()
                }
            }
    }

    private func ucitaj() async {
        lista = .ucitava
        do { lista = .gotovo(try await Karijera.rang(vrsta)) } catch { lista = .greska(error.localizedDescription) }
    }
}

/// Korporacija ukratko (vlasnik 04.11): radiš za drugog, cilj je svoj office, pa rast do nebodera.
struct KorporacijaObjasnjenje: View {
    private let koraci: [(String, String, String, String)] = [
        ("1", "Radiš za drugog", "Šef komentariše svaki odgovor, plata je 40%. Subota i nedelja su slobodne: ko tada igra, radi prekovremeno (+10%).", "Karijera_Sef_korporacija_nervozan"),
        ("2", "Položi probni rad", "10 rundi po 10 pitanja, može i u jednom danu. Sa 60% tačnih otvaraš svoj office, sa 90% dobijaš i 2 asistenta.", "Karijera_Sef_korporacija_zadovoljan"),
        ("3", "Postani vlasnik", "Iz garaže rasteš do nebodera. Pravi igrači dolaze da se zaposle kod tebe i pune ti kasu, ali mogu i da ti preotmu firmu u duelu.", "Karijera_Zgrada_5_1"),
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Oznaka(tekst: "Kako se napreduje")
            ForEach(koraci, id: \.0) { broj, naslov, tekst, slika in
                HStack(alignment: .center, spacing: 12) {
                    Text(broj).font(.naslov(20)).foregroundStyle(Color.tinta).frame(width: 40, height: 40)
                        .background(Color.zuta, in: Circle()).overlay(Circle().stroke(Color.mastilo, lineWidth: 2))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(naslov).font(.tekst(16, .bold))
                        Text(tekst).font(.tekst(13)).foregroundStyle(Color.sivaTekst).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(slika).resizable().scaledToFit().frame(width: 52, height: 70).accessibilityHidden(true)
                }
                .padding(12).mirna()
            }
        }
    }
}

// MARK: Šef i pitanja po firmi (§14)

extension Karijera {
    static let jacine = ["isključen", "blag", "srednji", "jak"]
    static let ometanjaNazivi = ["bez ometanja", "retko ometa", "ponekad ometa", "često ometa"]

    /// Primer: „srednji/jak · često ometa · +15% plate”
    static func sefOpis(_ n: Sef.Nivo, stres: Double?) -> String {
        let komentari = n.tacno == n.netacno ? jacine[n.tacno] : "\(jacine[n.tacno])/\(jacine[n.netacno])"
        let dodatak = (stres ?? 0) > 0 ? " · +\(Int(((stres ?? 0) * 100).rounded()))% plate" : ""
        return "\(komentari) · \(ometanjaNazivi[n.ometanja])\(dodatak)"
    }

    /// Runda od 10 po mešavini firme, isto kao server (karijera_runda_pitanja). Primer: struka 60, fokus [istorija] 50 → struka 6, istorija 2, opšte 2.
    static func mesavina(struka: Int, fokus: [String], udeo: [Int]) -> [(tema: String, broj: Int)] {
        let nStruka = Int((Double(10 * struka) / 100).rounded()), nOpste = 10 - nStruka
        var delovi = [(tema: "struka", broj: nStruka)]
        for (t, u) in zip(fokus, udeo) {
            // Dve teme po 50% zaokruživanjem mogu preko 10; server isto seče (least).
            delovi.append((t, min(Int((Double(nOpste * u) / 100).rounded()), 10 - delovi.map(\.broj).reduce(0, +))))
        }
        delovi.append(("opšte", 10 - delovi.map(\.broj).reduce(0, +)))
        return delovi.filter { $0.broj > 0 }
    }

    static func mesavinaOpis(struka: Int?, fokus: [String]?, udeo: [Int]?, teza: Bool?) -> String {
        let d = mesavina(struka: struka ?? 60, fokus: fokus ?? [], udeo: udeo ?? []).map { "\($0.broj) \($0.tema)" }.joined(separator: ", ")
        return d + (teza == true ? " · teže" : "")
    }
}

/// Vlasnik podešava šefa: komentari na tačne i netačne, ometanja, smeh. Jači šef = veća plata zaposlenima (iz kase).
struct SefList: View {
    @State var nivo: Sef.Nivo
    let sacuvaj: (Sef.Nivo) -> Void
    let zatvori: () -> Void
    private let jacine = [(0, "Isključen"), (1, "Blag"), (2, "Srednji"), (3, "Jak")]

    var body: some View {
        DonjiList(zatvori: zatvori) {
            VStack(alignment: .leading, spacing: 12) {
                Naslov(tekst: "Šef", velicina: 26)
                Text("Kako šef komentariše zaposlene u tvojoj firmi. Bez psovki i uvreda, ali jak šef je oštar. Srednji šef daje zaposlenima +5% plate, jak +10%, česta ometanja još +5%, iz kase.")
                    .font(.tekst(14)).foregroundStyle(Color.sivaTekst).fixedSize(horizontal: false, vertical: true)
                Text("Izgled: \(Sef.lik(nivo.lik).naziv)").font(.tekst(15, .bold))
                // Šef Korporacije ostaje samo u Korporaciji; vlasnik bira jedan od 6.
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(Sef.likovi.dropFirst()) { l in
                        Button { nivo.lik = l.id } label: {
                            Image(Sef.slika(.tacno, lik: l.id)).resizable().scaledToFit().frame(height: 84)
                                .frame(maxWidth: .infinity).padding(6)
                                .pop(nivo.lik == l.id ? .zuta : .kartica, radijus: 14)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(l.naziv)
                        .accessibilityAddTraits(nivo.lik == l.id ? .isSelected : [])
                    }
                }
                Text("Na tačne odgovore").font(.tekst(15, .bold))
                PodvuceniIzbor(izbor: $nivo.tacno, opcije: jacine)
                Text("Na netačne odgovore").font(.tekst(15, .bold))
                PodvuceniIzbor(izbor: $nivo.netacno, opcije: jacine)
                Text("Ometanja usred pitanja").font(.tekst(15, .bold))
                PodvuceniIzbor(izbor: $nivo.ometanja, opcije: [(0, "Ne"), (1, "Retko"), (2, "Ponekad"), (3, "Često")])
                Text(["Šef ne prekida rad.", "Jednom po rundi upadne sa pitanjem.", "2 do 3 puta po rundi upadne; u svakoj drugoj rundi jednom zada posao („Odmah, šefe”).", "4 do 5 puta po rundi upadne; jednom po rundi zada posao ili napravi haos."][nivo.ometanja] + " Sat ne staje.")
                    .font(.tekst(12)).foregroundStyle(Color.sivaTekst)
                HStack {
                    Text("Smeh i reakcije bez reči").font(.tekst(15, .bold))
                    Spacer()
                    Prekidac(ukljuceno: $nivo.smeh, naziv: "Smeh i reakcije bez reči")
                }
                Text("Šef: \(Karijera.sefOpis(nivo, stres: Karijera.stres(nivo)))").font(.tekst(13, .semibold)).foregroundStyle(Color.mastilo)
                Button("Sačuvaj") { sacuvaj(nivo) }.buttonStyle(.primarno)
            }
        }
    }
}

extension Karijera {
    /// Isto kao server karijera_stres (van Korporacije).
    static func stres(_ n: Sef.Nivo) -> Double {
        (max(n.tacno, n.netacno) == 3 ? 0.10 : max(n.tacno, n.netacno) == 2 ? 0.05 : 0) + (n.ometanja == 3 ? 0.05 : 0)
    }
}

/// Vlasnik bira mešavinu pitanja: udeo struke, do 2 teme fokusa u opštem delu i težinu. Duel ostaje isti.
struct PitanjaFirmeList: View {
    @State var struka: Int
    @State var fokus: [String]
    @State var udeo: [Int]
    @State var teza: Bool
    let sacuvaj: (Int, [String], [Int], Bool) -> Void
    let zatvori: () -> Void
    @State private var teme: Ucitano<[Karijera.TemaFokusa]> = .ucitava

    var body: some View {
        DonjiList(zatvori: zatvori) {
            VStack(alignment: .leading, spacing: 12) {
                Naslov(tekst: "Pitanja u firmi", velicina: 26)
                Text("Struka").font(.tekst(15, .bold))
                PodvuceniIzbor(izbor: $struka, opcije: [40, 50, 60, 70, 80].map { ($0, "\($0)%") })
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fokus u opštem delu").font(.tekst(15, .bold))
                    Text("Do 2 teme. Procenat je deo opšteg dela runde.").font(.tekst(12)).foregroundStyle(Color.sivaTekst)
                }
                ScrollView {
                    switch teme {
                    case .ucitava: VStack(spacing: 8) { ForEach(0..<4, id: \.self) { _ in Skelet(visina: 44) } }
                    case .greska(let p): Text(p).font(.tekst(13)).foregroundStyle(Color.crvena)
                    case .gotovo(let l):
                        // Jedan spisak sa linijama između redova (ne odvojene zaobljene kartice).
                        VStack(spacing: 0) {
                            ForEach(l) { t in
                                red(t)
                                if t.id != l.last?.id { Divider().overlay(Color.kremTamnija).padding(.leading, 46) }
                            }
                        }
                        .mirna()
                    }
                }
                .frame(maxHeight: 280)
                Text("Težina").font(.tekst(15, .bold))
                PodvuceniIzbor(izbor: $teza, opcije: [(false, "Normalno"), (true, "Teže")])
                Text("Runda: " + Karijera.mesavinaOpis(struka: struka, fokus: fokus, udeo: udeo, teza: teza)).font(.tekst(13, .semibold)).foregroundStyle(Color.mastilo)
                Button("Sačuvaj") { sacuvaj(struka, fokus, udeo, teza) }.buttonStyle(.primarno)
            }
        }
        .task {
            do { teme = .gotovo(try await Karijera.temeFokusa()) } catch { teme = .greska(error.localizedDescription) }
        }
    }

    @ViewBuilder private func red(_ t: Karijera.TemaFokusa) -> some View {
        let k = fokus.firstIndex(of: t.tema)
        VStack(alignment: .leading, spacing: 8) {
            Button {
                if let k { fokus.remove(at: k); udeo.remove(at: k) } else if fokus.count < 2 { fokus.append(t.tema); udeo.append(50) }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: k != nil ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .semibold)).foregroundStyle(k != nil ? Color.teal : Color.kremTamnija)
                    Text(t.tema.prefix(1).uppercased() + t.tema.dropFirst()).font(.tekst(15, .semibold)).foregroundStyle(Color.mastilo)
                    Spacer()
                    if let k { Text("\(udeo[k])%").font(.tekst(14, .bold)).foregroundStyle(Color.teal) }
                }
                .frame(minHeight: 30).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(k == nil && fokus.count >= 2)
            if let k {
                PodvuceniIzbor(izbor: Binding(get: { udeo[k] }, set: { udeo[k] = $0 }), opcije: [20, 30, 40, 50].map { ($0, "\($0)%") })
                    .padding(.leading, 32)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .opacity(k == nil && fokus.count >= 2 ? 0.45 : 1)
    }
}

// MARK: Slobodni dani (vlasnik 05.11)

/// Sedam dana u nedelji, bira se do 3. Kvadratići, ne pilule.
struct SlobodniDaniIzbor: View {
    @Binding var dani: [Int]
    static let objasnjenje = "Tih dana ne moraš da dolaziš u firmu, niko ne može da te izazove na duel, a ko ipak igra radi prekovremeno: plata i kasa +10%. Menja se jednom u 7 dana."

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { d in
                let da = dani.contains(d)
                Button {
                    if da { dani.removeAll { $0 == d } } else if dani.count < 3 { dani.append(d) }
                } label: {
                    Text(Karijera.daniKratko[d - 1]).font(.tekst(13, .bold))
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .foregroundStyle(da ? Color.tinta : .mastilo)
                        .background(da ? Color.zuta : Color.kartica, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.mastilo, lineWidth: da ? 2 : 1))
                }
                .buttonStyle(.plain)
                .disabled(!da && dani.count >= 3)
                .accessibilityAddTraits(da ? .isSelected : [])
            }
        }
    }
}

struct SlobodniDaniList: View {
    @State var dani: [Int]
    let sacuvaj: ([Int]) -> Void
    let zatvori: () -> Void
    var body: some View {
        DonjiList(zatvori: zatvori) {
            VStack(alignment: .leading, spacing: 12) {
                Naslov(tekst: "Slobodni dani", velicina: 26)
                Text(SlobodniDaniIzbor.objasnjenje).font(.tekst(14)).foregroundStyle(Color.sivaTekst).fixedSize(horizontal: false, vertical: true)
                SlobodniDaniIzbor(dani: $dani)
                Text("Izabrano: \(Karijera.daniOpis(dani))").font(.tekst(13, .semibold)).foregroundStyle(Color.mastilo)
                Button("Sačuvaj") { sacuvaj(dani) }.buttonStyle(.primarno)
            }
        }
    }
}


/// Radnja iz kase na tamnoj kartici: ikonica, naziv i cena ili razlog zašto ne može (ne bledi).
struct KasaPlocica: View {
    let ikonica: String
    let naslov: String
    let opis: String
    let omoguceno: Bool
    let akcija: () -> Void
    var body: some View {
        Button(action: akcija) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: ikonica).font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(omoguceno ? Color(hex: 0x123F44) : .white.opacity(0.55))
                Text(naslov).font(.tekst(14, .bold)).foregroundStyle(omoguceno ? Color.tinta : .white)
                Text(opis).font(.tekst(11, .semibold)).foregroundStyle(omoguceno ? Color.tinta.opacity(0.65) : .white.opacity(0.7))
                    .lineLimit(1).minimumScaleFactor(0.75)
            }
            .padding(10).frame(maxWidth: .infinity, minHeight: 86, alignment: .topLeading)
            .background(omoguceno ? Color(hex: 0x7FE0C9) : .white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(omoguceno ? 0 : 0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!omoguceno)
        .accessibilityLabel("\(naslov), \(opis)")
    }
}

/// Red podešavanja sa obojenim kvadratom za ikonicu (kao podešavanja telefona).
struct RedPodesavanja: View {
    let ikonica: String
    let boja: Color
    let naziv: String
    var vrednost: String? = nil
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: ikonica).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                .frame(width: 30, height: 30).background(boja, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(naziv).font(.tekst(15, .semibold)).foregroundStyle(Color.mastilo)
            Spacer(minLength: 8)
            if let vrednost { Text(vrednost).font(.tekst(14, .semibold)).foregroundStyle(Color.sivaTekst).lineLimit(1) }
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(Color.sivaTekst)
        }
        .padding(.horizontal, 14).frame(minHeight: 54)
        .contentShape(Rectangle())
    }
}
