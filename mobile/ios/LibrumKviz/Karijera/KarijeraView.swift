import SwiftUI

/// Karijera (docs/KARIJERA-PRAVILA.md): izbor pozicije, probni rad u Korporaciji, posao,
/// moje firme, izazovi i linkovi ka berzi, CV-u i rang listi. Stanje uvek stiže sa servera.
struct KarijeraView: View {
    @Environment(Sesija.self) private var sesija
    @State private var stanje: Ucitano<Karijera.Stanje> = .ucitava
    @State private var poruka: String?
    @State private var radi = false
    @State private var izazovTema: Karijera.Firma?
    @State private var prihvatanje: Karijera.Izazov?
    @State private var odmorList = false
    @State private var talentiList = false

    var body: some View {
        #if DEBUG
        // Provera neba (`-nebo`): Karijera prikazuje sva vremena umesto svog sadržaja.
        if ProcessInfo.processInfo.arguments.contains("-nebo") { NeboProba() }
        else if ProcessInfo.processInfo.arguments.contains("-ishodProba") { IshodProba() }
        else if ProcessInfo.processInfo.arguments.contains("-sefProba") { SefProba() }
        else if ProcessInfo.processInfo.arguments.contains("-gradProba") { GradProba() }
        else if ProcessInfo.processInfo.arguments.contains("-ulicaProba") {
            ZStack(alignment: .bottom) {
                Nebo(mesto: "proba")
                Image("Karijera_Zgrada_3_5").resizable().scaledToFit().frame(height: 300).padding(.top, 30)
                Ulica(mesto: "proba", gustina: 3)
            }
            .frame(height: 420).clipShape(RoundedRectangle(cornerRadius: 24)).padding(16)
        }
        else if ProcessInfo.processInfo.arguments.contains("-pripremaProba") { PripremaRunde(broj: 3, stavka: Zanimljivosti.sve.randomElement(), slika: "Karijera_Trac_\(Int.random(in: 1...14))").padding(16).background(Papir()) } else { glavni }
        #else
        glavni
        #endif
    }

    private var glavni: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Na prvom ulasku IzborPozicijeView ima svoju strelicu nazad (korak po korak).
                if imaPoziciju || !(stanje.jeGotovo) { GornjaTraka() }
                switch stanje {
                case .ucitava:
                    VStack(spacing: 12) { Skelet(visina: 40); Skelet(visina: 220, radijus: 24); Skelet(visina: 120, radijus: 24) }
                case .greska(let p):
                    StanjeEkrana(maskota: .lumi, naslov: "Karijerista se nije učitao", tekst: p, dugme: "Pokušaj ponovo") { Task { await ucitaj() } }
                case .gotovo(let s):
                    if s.pozicija == nil { IzborPozicijeView(pozicije: s.pozicije, talenti: s.katalog_talenata ?? []) { id, pol, t, p in Task { await izaberi(id, pol, t, p) } } }
                    else { sadrzaj(s) }
                }
            }
            .padding(16)
        }
        // Posle izbora pozicije ekran kreće od vrha (inače ostaje skrolovan do dna spiska pozicija).
        .id(imaPoziciju)
        .background(Papir())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .refreshable { await ucitaj() }
        .task { await ucitaj() }
        .overlay(alignment: .bottom) { if let poruka { porukaTraka(poruka) } }
        .overlay { if let f = izazovTema { IzborTemeList(naslov: "Tvoja tema u duelu", podnaslov: "Vlasnik bira prvu i treću temu, ti drugu.", firmaId: f.id, izbor: 1) { teme in
            izazovTema = nil; if let t = teme.first { Task { await izazovi(f, t) } }
        } zatvori: { izazovTema = nil } } }
        .overlay { if let z = prihvatanje { IzborTemeList(naslov: "Prihvati duel", podnaslov: z.pokusaj >= 4 ? "Biraš prvu temu; treća je nasumična (\(z.pokusaj). pokušaj)." : "Biraš prvu i treću temu. Izazivač je izabrao: \(z.tema_izazivac).",
                                                          firmaId: z.firma.id, izbor: z.pokusaj >= 4 ? 1 : 2, iskljuci: [z.tema_izazivac]) { teme in
            prihvatanje = nil; Task { await prihvati(z, teme) }
        } zatvori: { prihvatanje = nil } } }
        .overlay { if talentiList, case .gotovo(let s) = stanje { ZamenaTalentaList(stanje: s) { stari, novi in talentiList = false; Task { await radnja { try await Karijera.promeniTalenat(stari: stari, novi: novi) } } } zatvori: { talentiList = false } } }
        .overlay { if odmorList, case .gotovo(let s) = stanje { OdmorList(ostalo: s.odmor_ostalo, odmorDo: s.odmor_do, izaberi: { d in odmorList = false; Task { await odmor(d) } },
                                                                                       povuci: { odmorList = false; Task { await povuciOdmor() } }, zatvori: { odmorList = false }) } }
    }

    private var imaPoziciju: Bool { if case .gotovo(let s) = stanje { s.pozicija != nil } else { false } }

    // MARK: Sadržaj

    @ViewBuilder private func sadrzaj(_ s: Karijera.Stanje) -> some View {
        zaglavlje(s)
        if let pravo = s.office_pravo {
            NavigationLink { OtvoriOfficeView(stanje: s, botova: pravo) { Task { await ucitaj() } } } label: {
                HStack(spacing: 12) {
                    Image(systemName: "key.fill").font(.system(size: 22, weight: .bold)).foregroundStyle(Color.tinta)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Otvori svoj office").font(.naslov(22)).foregroundStyle(Color.tinta)
                        Text(pravo > 0 ? "Pravo na zgradu i \(pravo) \(pravo == 1 ? "asistenta" : "asistenta")." : "Pravo na zgradu, bez asistenata.")
                            .font(.tekst(14, .semibold)).foregroundStyle(Color.tinta.opacity(0.8))
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 15, weight: .bold)).foregroundStyle(Color.tinta)
                }
                .padding(16).pop(.zuta, radijus: 20)
            }
            .buttonStyle(.plain)
        }
        if s.uProbnom { probniKartica(s) }
        else if s.probni.ishod == -1 && s.office_pravo == nil && s.firme.isEmpty { pao(s) }
        if let posao = s.posao { posaoKartica(s, posao) }
        if !s.firme.isEmpty {
            Text(s.firme.count == 1 ? "Moja firma" : "Moje firme").font(.naslov(24)).padding(.top, 4)
            ForEach(s.firme) { f in
                NavigationLink { FirmaView(firmaId: f.id, stanje: s) { Task { await ucitaj() } } } label: { FirmaKartica(firma: f.kratko, kasa: f.kasa, mojaFirma: true) }
                    .buttonStyle(.plain)
                ForEach(f.izazovi.filter { $0.stanje != "gotov" }) { z in izazovRed(z, vlasnik: true, botovi: f.botovi) }
            }
        }
        if !s.moji_izazovi.isEmpty {
            Text("Moji izazovi").font(.naslov(24)).padding(.top, 4)
            ForEach(s.moji_izazovi) { z in izazovRed(z, vlasnik: false, botovi: []) }
        }
        VStack(spacing: 0) {
            NavigationLink { GradView(stanje: s) { Task { await ucitaj() } } } label: { RedListe(ikonica: "map", naziv: "Grad", vrednost: "sve firme") }
            Divider().overlay(Color.kremTamnija)
            NavigationLink { BerzaView(stanje: s) { Task { await ucitaj() } } } label: { RedListe(ikonica: "building.2", naziv: "Berza poslova", vrednost: "promeni firmu") }
            Divider().overlay(Color.kremTamnija)
            NavigationLink { KarijeraCVView(igrac: nil) } label: { RedListe(ikonica: "person.text.rectangle", naziv: "Moj CV") }
            Divider().overlay(Color.kremTamnija)
            NavigationLink { KarijeraPravilaView() } label: { RedListe(ikonica: "book.closed", naziv: "Pravila i saveti") }

            if !s.firme.isEmpty {
                Divider().overlay(Color.kremTamnija)
                Button { withAnimation { odmorList = true } } label: {
                    RedListe(ikonica: "sun.max", naziv: "Godišnji odmor", vrednost: "\(s.odmor_ostalo) dana")
                }
            }
        }
        .buttonStyle(.plain)
        .mirna()
        .padding(.top, 4)
    }

    private func zaglavlje(_ s: Karijera.Stanje) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Oznaka(tekst: "Karijerista")
            // Titula i struka uvek u jednom redu (dugačke struke se smanje, ne lome).
            Text("\(Karijera.titule[min(s.titula, 3)]) · \(s.mojaPozicija?.naziv(pol: s.pol) ?? "")")
                .font(.naslov(28)).tracking(-0.5).foregroundStyle(Color.mastilo).lineLimit(1).minimumScaleFactor(0.5)
            HStack(spacing: 10) {
                Plocica(ikonica: "banknote", vrednost: Karijera.novac(s.kapital), naziv: "Kapital", boja: .teal)
                Plocica(ikonica: "rosette", vrednost: "\(s.ugled)", naziv: "Ugled · nivo \(s.nivo_ugleda)", boja: .roze)
                Plocica(ikonica: "clock", vrednost: "\(s.placenih_danas)/\(s.placenih_max)", naziv: "Plaćene runde", boja: .narandzasta)
            }
        }
    }

    private func probniKartica(_ s: Karijera.Stanje) -> some View {
        let p = s.probni
        let danas = p.danas ?? 0
        let korporacija = korporacijaFirma(s)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Oznaka(tekst: p.bivsi_vlasnik == true ? "Skraćeni probni rad" : "Probni rad")
                    Text("Runda \(min(p.runde + 1, p.cilj)) od \(p.cilj)").font(.naslov(24))
                    Text(p.runde == 0 ? "Najmanje 60% tačnih za svoj office, 90% za office i 2 asistenta." : "Do sada \(p.tacnih) tačnih od \(p.runde * 10) (\(p.tacnih * 10 / max(p.runde, 1))%).")
                        .font(.tekst(14, .semibold)).foregroundStyle(Color.sivaTekst)
                }
                Spacer()
                Image("Karijera_Sef_korporacija_zadovoljan").resizable().scaledToFit().frame(width: 52, height: 90).accessibilityHidden(true)
            }
            ProgressView(value: Double(p.runde), total: Double(max(p.cilj, 1))).tint(Color.teal)
            if danas >= Karijera.probniDnevno {
                Text("Danas si odigrao \(Karijera.probniDnevno) rundi probnog rada. Nastavi sutra.").font(.tekst(14, .bold)).foregroundStyle(Color.sivaTekst)
            } else {
                NavigationLink { KarijeraRundaView(firma: korporacija, probni: true, pocetnaProbnaRunda: p.runde) { Task { await ucitaj() } }.bezSvajpaNazad() } label: {
                    Text("Igraj rundu u Korporaciji")
                }
                .buttonStyle(.zuto)
            }
        }
        .padding(16).pop(radijus: 22)
    }

    private func pao(_ s: Karijera.Stanje) -> some View {
        let dana = s.probni.korporacija_dana ?? 0
        let moze = dana >= 3 || s.probni.bivsi_vlasnik == true
        return VStack(alignment: .leading, spacing: 10) {
            Oznaka(tekst: "Probni rad", boja: .crvena)
            Text("Ostaješ u Korporaciji").font(.naslov(22))
            Text(moze ? "Možeš ponovo na probni rad." : "Novi probni rad posle 3 radna dana u Korporaciji. Odrađeno: \(dana) od 3.")
                .font(.tekst(14, .semibold)).foregroundStyle(Color.sivaTekst)
            Button("Novi probni rad") { Task { await noviProbni() } }.buttonStyle(.zuto).disabled(!moze || radi)
        }
        .padding(16).pop(radijus: 22)
    }

    private func posaoKartica(_ s: Karijera.Stanje, _ f: Karijera.Firma) -> some View {
        let drzimRekord = f.rekord_igrac == sesija.korisnikId && !f.korporacija
        let staz = s.zaposlen_od.flatMap(Karijera.datum).map { Date.now.timeIntervalSince($0) / 86400 } ?? 0
        return VStack(alignment: .leading, spacing: 12) {
            Text(s.uProbnom ? "Gde radiš" : "Posao").font(.naslov(24))
            NavigationLink { FirmaView(firmaId: f.id, stanje: s) { Task { await ucitaj() } } } label: { FirmaKartica(firma: f, kasa: nil, mojaFirma: false) }
                .buttonStyle(.plain)
            if !s.uProbnom || !f.korporacija {
                NavigationLink { KarijeraRundaView(firma: f, botovi: []) { Task { await ucitaj() } }.bezSvajpaNazad() } label: { Text("Igraj rundu") }
                    .buttonStyle(.primarno)
            }
            if drzimRekord {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Držiš rekord ove firme!", systemImage: "trophy.fill").font(.tekst(15, .bold))
                    Text(staz >= 3 ? "Možeš da tražiš preuzimanje firme duelom." : "Izazov se šalje posle 3 dana u firmi.")
                        .font(.tekst(14)).foregroundStyle(Color.sivaTekst)
                    Button("Izazovi vlasnika") { withAnimation { izazovTema = f } }.buttonStyle(.zuto).disabled(staz < 3 || f.zasticena)
                    if f.zasticena { Text("Firma je trenutno zaštićena od izazova.").font(.tekst(13)).foregroundStyle(Color.sivaTekst) }
                }
                .padding(14).mirna()
            }
        }
    }

    @ViewBuilder private func izazovRed(_ z: Karijera.Izazov, vlasnik: Bool, botovi: [Karijera.Bot]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "figure.fencing").font(.system(size: 18, weight: .bold))
                Text(vlasnik ? "\(z.izazivac_ime) traži tvoju firmu" : z.firma.ime).font(.tekst(15, .bold)).lineLimit(1)
                Spacer()
                if let r = z.rokDatum, z.stanje != "gotov" { Text(r, style: .relative).font(.tekst(12, .semibold)).foregroundStyle(Color.sivaTekst) }
            }
            Text(opisIzazova(z, vlasnik: vlasnik)).font(.tekst(13)).foregroundStyle(Color.sivaTekst).fixedSize(horizontal: false, vertical: true)
            if vlasnik && z.stanje == "ceka" {
                Button("Prihvati i izaberi teme") { withAnimation { prihvatanje = z } }.buttonStyle(.zuto)
            } else if z.stanje == "u_toku" && z.ja_odigrao == false {
                NavigationLink { KarijeraDuelView(izazov: z, botovi: botovi) { Task { await ucitaj() } }.bezSvajpaNazad() } label: { Text("Igraj duel (30 pitanja)") }
                    .buttonStyle(.primarno)
            }
        }
        .padding(14).mirna()
    }

    private func opisIzazova(_ z: Karijera.Izazov, vlasnik: Bool) -> String {
        switch z.stanje {
        case "ceka": return vlasnik ? "Pokušaj \(z.pokusaj). Ako ne prihvatiš u roku, firma prelazi na izazivača." : "Čeka se da vlasnik prihvati duel."
        case "u_toku":
            let teme = [z.tema1, z.tema_izazivac, z.tema3].compactMap { $0 }.joined(separator: " · ")
            return z.ja_odigrao == true ? "Odigrao si. Čeka se drugi igrač. Teme: \(teme)." : "Teme: \(teme). Asistenti vlasnika: \(z.botova >= 99 ? "svi" : "\(z.botova)")."
        default:
            let pobeda = z.pobednik == sesija.korisnikId
            return "\(pobeda ? "Pobeda" : "Poraz") · \(z.ishod ?? "")"
        }
    }

    private func korporacijaFirma(_ s: Karijera.Stanje) -> Karijera.Firma {
        if let p = s.posao, p.korporacija { return p }
        return Karijera.Firma(id: s.korporacija, ime: "Korporacija", korporacija: true, npc: false, vlasnik: nil, vlasnik_ime: "Šef", pozicija: s.pozicija ?? "",
                              nivo: 5, stil: 1, udeo: "korporacija", kljucne: [], rekord: 0, rekord_ime: nil, rekord_igrac: nil, zaposlenih: 0, botova: 0, zastita_do: nil,
                              sef_tacno: 2, sef_netacno: 2, sef_ometanja: 2, struka_udeo: 60, sef_smeh: true, teza: false, sef_lik: "korporacija", slobodni: [6, 7], slobodan_danas: nil, stres: 0, fokus: [], fokus_udeo: [])
    }

    private func porukaTraka(_ p: String) -> some View {
        Text(p).font(.tekst(14, .bold)).foregroundStyle(Color.naMastilu)
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.mastilo, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onTapGesture { withAnimation { poruka = nil } }
            .task { try? await Task.sleep(for: .seconds(4)); withAnimation { poruka = nil } }
    }

    // MARK: Radnje

    private func ucitaj() async {
        if case .gotovo = stanje {} else { stanje = .ucitava }
        do { let s = try await Karijera.stanje(); Karijera.mojiTalenti = Set(s.talenti ?? []); Karijera.mojPol = s.pol ?? "m"; Karijera.mirni = s.mirni ?? false; if let p = s.pomoci, !p.isEmpty { Karijera.mojePomoci = p }; stanje = .gotovo(s) }
        catch { if case .gotovo = stanje { withAnimation { poruka = error.localizedDescription } } else { stanje = .greska(error.localizedDescription) } }
    }

    private func radnja(_ posao: () async throws -> Karijera.Stanje?) async {
        radi = true; defer { radi = false }
        do { if let s = try await posao() { stanje = .gotovo(s) } else { await ucitaj() } }
        catch { withAnimation { poruka = error.localizedDescription } }
    }

    private func izaberi(_ id: String, _ pol: String, _ t: [String], _ p: [String]) async { await radnja { try await Karijera.izaberiPoziciju(id, pol: pol, talenti: t, pomoci: p) } }
    private func noviProbni() async { await radnja { try await Karijera.noviProbni() } }
    private func odmor(_ d: Int) async { await radnja { try await Karijera.odmor(d) } }
    private func povuciOdmor() async { await radnja { try await Karijera.povuciOdmor() } }
    private func izazovi(_ f: Karijera.Firma, _ tema: String) async {
        await radnja { _ = try await Karijera.posaljiIzazov(f.id, tema: tema); return nil }
    }
    private func prihvati(_ z: Karijera.Izazov, _ teme: [String]) async {
        await radnja { _ = try await Karijera.prihvatiIzazov(z.id, tema1: teme[0], tema3: teme.count > 1 ? teme[1] : teme[0]); return nil }
    }
}

/// Velika kartica Karijere na početnoj: put od garaže do nebodera, zgrade uspravne (crtež je gledan spreda).
struct KarijeraKartica: View {
    /// Plava Karijere (vlasnik 04.11: plava umesto ljubičaste).
    static let plava = Color(hex: 0x2F6FD6)
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                Spacer(minLength: 0)
                Text("Karijerista").font(.naslov(36)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.8)
                Text("Od Korporacije do svog nebodera: probni rad, asistenti i duel za tuđu firmu.")
                    .font(.tekst(13, .semibold)).foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image("Karijera_Zgrada_5_1").resizable().scaledToFit()
                .frame(width: 110).padding(.top, 14)
                .accessibilityHidden(true)
        }
        .padding(.leading, 22).padding(.trailing, 14).padding(.bottom, 20)
        .frame(height: 250)
        .background(Circle().fill(.white.opacity(0.14)).frame(width: 230).offset(x: 120, y: -40))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .pop(Self.plava)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// Kartica firme sa slikom zgrade.
struct FirmaKartica: View {
    let firma: Karijera.Firma
    let kasa: Double?
    let mojaFirma: Bool
    var body: some View {
        HStack(spacing: 14) {
            ZStack(alignment: .bottom) {
                Nebo(mesto: firma.id)
                Image(firma.slika).resizable().scaledToFit().padding(.top, 14).padding(.horizontal, 4)
                Ulica(mesto: firma.id, gustina: 0.6)
            }
            .frame(width: 104, height: 104)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(firma.ime).font(.tekst(17, .bold)).foregroundStyle(Color.mastilo).lineLimit(2)
                Text(firma.korporacija ? "Šef · plata 40%" : "\(Karijera.naziviNivoa[firma.nivo - 1]) · \(mojaFirma ? "vlasnik si" : firma.vlasnik_ime)")
                    .font(.tekst(13, .semibold)).foregroundStyle(Color.sivaTekst).lineLimit(1)
                if !firma.korporacija {
                    Text("Rekord \(firma.rekord)\(firma.rekord_ime.map { " · \($0)" } ?? "")").font(.tekst(13)).foregroundStyle(Color.sivaTekst).lineLimit(1)
                }
                if let kasa { Text("Kasa \(Karijera.novac(kasa))").font(.tekst(14, .bold)).foregroundStyle(Color.teal) }
                if firma.slobodan_danas == true {
                    Label("Danas je slobodan dan · prekovremeno +10%", systemImage: "moon.stars.fill")
                        .font(.tekst(12, .bold)).foregroundStyle(Color.narandzasta).lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(Color.sivaTekst)
        }
        .padding(12)
        .pop(radijus: 20)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// Prvi ulazak (vlasnik 05.11): strana priče pa izbor, naizmenično (KarijeraVodic): šta je Karijera → struka →
/// probni rad → pol → pomoći → izbor 4 pomoći → firma → 3 talenta → rivali i duel → prvi dan uz muziku.
/// Strelica nazad vraća korak po korak; tek „Prijavljujem se za posao” šalje izbor serveru.
struct IzborPozicijeView: View {
    let pozicije: [Karijera.Pozicija]
    let talenti: [Karijera.Talenat]
    let izaberi: (String, String, [String], [String]) -> Void
    @Environment(\.dismiss) private var nazad
    @State private var korak = 0
    @State private var izabrana: Karijera.Pozicija?
    @State private var pol: String?
    @State private var izabranePomoci: [String] = []
    @State private var izabraniTalenti: [String] = []

    var body: some View {
        // Svaki korak kreće od vrha (spiskovi pomoći i talenata su dugi).
        ScrollViewReader { skrol in
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                KrugDugme(ikonica: "chevron.left", opis: korak == 0 ? "Nazad" : "Prethodni korak") {
                    if korak == 0 { nazad() } else { withAnimation { korak -= 1 } }
                }
                Spacer()
            }
            .id("vrh")
            CrticeKoraka(ukupno: 10, trenutni: korak)
            switch korak {
            case 0, 2, 4, 6, 8: VodicStranaView(strana: KarijeraVodic.strane[korak / 2], zensko: pol == "z") { korak += 1 }
            case 1: pozicijaKorak
            case 3: polKorak
            case 5: pomociKorak
            case 7: talentiKorak
            default: uvod
            }
        }
        .animation(.spring(duration: 0.3), value: korak)
        .onChange(of: korak) { skrol.scrollTo("vrh", anchor: .top) }
        }
    }

    private var pozicijaKorak: some View {
        VStack(alignment: .leading, spacing: 14) {
            Naslov(tekst: "Izaberi struku", velicina: 30)
            Text("Izaberi struku. Od nje zavise pitanja: 6 od 10 su iz tvoje struke. Posle probnog rada otvaraš svoj office.")
                .font(.tekst(15)).foregroundStyle(Color.sivaTekst)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(pozicije) { p in
                    let aktivna = izabrana == p
                    Button { withAnimation(.spring(duration: 0.25)) { izabrana = p } } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Image(systemName: p.ikonica).font(.system(size: 20, weight: .semibold))
                            Text(p.naziv).font(.tekst(15, .bold)).lineLimit(2).multilineTextAlignment(.leading)
                            Text(p.opis).font(.tekst(12)).foregroundStyle(aktivna ? Color.tinta.opacity(0.75) : .sivaTekst).lineLimit(2).multilineTextAlignment(.leading)
                        }
                        .foregroundStyle(aktivna ? Color.tinta : .mastilo)
                        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
                        .padding(12)
                        .pop(aktivna ? .zuta : .kartica, radijus: 18)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(aktivna ? .isSelected : [])
                }
            }
            Button("Dalje") { korak = 2 }.buttonStyle(.primarno).disabled(izabrana == nil)
        }
    }

    private var polKorak: some View {
        VStack(alignment: .leading, spacing: 14) {
            Naslov(tekst: "Ko kreće u karijeru?", velicina: 30)
            HStack(spacing: 12) {
                ForEach([("m", "Muško", "Karijera_Asistent_1"), ("z", "Žensko", "Karijera_Asistent_2")], id: \.0) { id, naziv, slika in
                    Button { pol = id } label: {
                        VStack(spacing: 8) {
                            Image(slika).resizable().scaledToFit().frame(height: 220)
                            Text(naziv).font(.tekst(17, .bold))
                            if let izabrana { Text(izabrana.naziv(pol: id)).font(.tekst(13)).foregroundStyle(pol == id ? Color.tinta.opacity(0.75) : .sivaTekst).lineLimit(1).minimumScaleFactor(0.8) }
                        }
                        .foregroundStyle(pol == id ? Color.tinta : .mastilo)
                        .frame(maxWidth: .infinity).padding(14)
                        .pop(pol == id ? .zuta : .kartica, radijus: 20)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(pol == id ? .isSelected : [])
                }
            }
            Button("Dalje") { korak = 4 }.buttonStyle(.primarno).disabled(pol == nil)
        }
    }

    private var pomociKorak: some View {
        VStack(alignment: .leading, spacing: 14) {
            Naslov(tekst: "Tvoje 4 pomoći", velicina: 30)
            Text("U svakoj rundi svaku možeš da iskoristiš jednom. Odgovor uz pomoć vredi manje i ne donosi ugled.")
                .font(.tekst(15)).foregroundStyle(Color.sivaTekst)
            Oznaka(tekst: "Izabrano \(izabranePomoci.count) od 4")
            VStack(spacing: 8) {
                ForEach(KarijeraPomoc.sve) { p in
                    let izabrana = izabranePomoci.contains(p.id)
                    Button {
                        if let i = izabranePomoci.firstIndex(of: p.id) { izabranePomoci.remove(at: i) }
                        else if izabranePomoci.count < 4 { izabranePomoci.append(p.id) }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: p.ikonica).font(.system(size: 18, weight: .semibold)).frame(width: 40, height: 40)
                                .background(izabrana ? Color.white.opacity(0.5) : Color.udubljeno, in: RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.naziv).font(.tekst(15, .bold))
                                Text(p.opis).font(.tekst(13)).foregroundStyle(izabrana ? Color.tinta.opacity(0.75) : .sivaTekst).fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            if izabrana { Image(systemName: "checkmark").font(.system(size: 15, weight: .black)) }
                        }
                        .foregroundStyle(izabrana ? Color.tinta : .mastilo)
                        .padding(12).pop(izabrana ? .zuta : .kartica, radijus: 16)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(izabrana ? .isSelected : [])
                }
            }
            Button("Dalje") { korak = 6 }.buttonStyle(.primarno).disabled(izabranePomoci.count != 4)
        }
    }

    private var talentiKorak: some View {
        VStack(alignment: .leading, spacing: 14) {
            Naslov(tekst: "Tvoja 3 talenta", velicina: 30)
            Text("Pomažu ti celu igru. Na svakih 200 tačnih odgovora možeš da zameniš jedan.")
                .font(.tekst(15)).foregroundStyle(Color.sivaTekst)
            Oznaka(tekst: "Izabrano \(izabraniTalenti.count) od 3")
            VStack(spacing: 8) {
                ForEach(talenti) { t in
                    TalenatRed(talenat: t, izabran: izabraniTalenti.contains(t.id)) {
                        if let i = izabraniTalenti.firstIndex(of: t.id) { izabraniTalenti.remove(at: i) }
                        else if izabraniTalenti.count < 3 { izabraniTalenti.append(t.id) }
                    }
                }
            }
            Button("Dalje") { korak = 8 }.buttonStyle(.primarno).disabled(izabraniTalenti.count != 3)
        }
    }

    /// Priča pre prvog dana: zgrada Korporacije, muzika i tekst u rodu igrača.
    private var uvod: some View {
        let z = pol == "z"
        let pozicija = izabrana?.naziv(pol: pol) ?? ""
        let pasusi = [
            "Dobrodošl\(z ? "a" : "i") u Korporaciju. Od danas radiš kao \(pozicija.lowercased()), na probnom radu.",
            "Ovde radiš za drugog. Šef prati svaki tvoj odgovor: kad pogrešiš, čućeš da \(z ? "si mogla" : "si mogao") bolje, a kad pogodiš, pohvaliće te. Ni jedno ni drugo ne shvataj lično: svaka primedba je znak da se boriš još jače.",
            "Kad položiš probni rad, dobijaš mogućnost da otvoriš svoju firmu. Onda ti \(z ? "si šefica" : "si šef"): zapošljavaš asistente (botove), a pravi igrači, ljudi kao ti, dolaze da rade kod tebe. Pazi: ti isti igrači mogu da ti preotmu firmu u duelu.",
            "Važno: niko te ovde neće zaista vređati. Šef je šala na račun kancelarije, a nijedan vlasnik firme kroz Karijeristu ne može da ti piše niti da te vređa. Cilj je samo zabava i učenje kroz pitanja.",
        ]
        return VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .bottom) {
                Nebo(mesto: "korporacija")
                Image("Karijera_Korporacija_1").resizable().scaledToFit().frame(height: 210).padding(.top, 20)
                Ulica(mesto: "korporacija")
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.mastilo, lineWidth: 2))
            .accessibilityHidden(true)
            Naslov(tekst: "Tvoj prvi dan", velicina: 30)
            ForEach(Array(pasusi.enumerated()), id: \.offset) { i, t in
                UvodPasus(tekst: t, kasnjenje: Double(i) * 0.6, istaknut: i == pasusi.count - 1)
            }
            Button {
                if let izabrana, let pol { KarijeraMuzika.stani(); Zvuk.pusti(.karijeraZvono, jacina: 0.6); izaberi(izabrana.id, pol, izabraniTalenti, izabranePomoci) }
            } label: { Label("Prijavljujem se za posao", systemImage: "briefcase.fill") }
                .buttonStyle(.zuto).padding(.top, 4)
        }
        .onAppear { KarijeraMuzika.pusti(.karijeraUvod, jacina: 0.35) }
        .onDisappear { KarijeraMuzika.stani() }
    }
}

/// Pasus uvoda koji se pojavi sa malim zakašnjenjem (priča se „odvija”).
struct UvodPasus: View {
    let tekst: String
    let kasnjenje: Double
    var istaknut = false
    @State private var vidljiv = false
    var body: some View {
        Text(tekst).font(.tekst(16, istaknut ? .bold : .medium)).foregroundStyle(Color.mastilo)
            .fixedSize(horizontal: false, vertical: true)
            .padding(istaknut ? 14 : 0)
            .background(istaknut ? Color.tealSvetla : .clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(vidljiv ? 1 : 0).offset(y: vidljiv ? 0 : 10)
            .onAppear { withAnimation(.easeOut(duration: 0.5).delay(kasnjenje)) { vidljiv = true } }
    }
}

struct TalenatRed: View {
    let talenat: Karijera.Talenat
    let izabran: Bool
    let radnja: () -> Void
    var body: some View {
        Button(action: radnja) {
            HStack(spacing: 12) {
                Image(systemName: talenat.ikonica).font(.system(size: 18, weight: .semibold)).frame(width: 40, height: 40)
                    .background(izabran ? Color.white.opacity(0.5) : Color.udubljeno, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text(talenat.naziv).font(.tekst(15, .bold))
                    Text(talenat.opis).font(.tekst(13)).foregroundStyle(izabran ? Color.tinta.opacity(0.75) : .sivaTekst).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if izabran { Image(systemName: "checkmark").font(.system(size: 15, weight: .black)) }
            }
            .foregroundStyle(izabran ? Color.tinta : .mastilo)
            .padding(12)
            .pop(izabran ? .zuta : .kartica, radijus: 16)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(izabran ? .isSelected : [])
    }
}

/// Talenti i zamena: na svakih 200 tačnih jedna zamena (server proverava).
struct ZamenaTalentaList: View {
    let stanje: Karijera.Stanje
    let zameni: (String, String) -> Void
    let zatvori: () -> Void
    @State private var stari: String?
    @State private var novi: String?

    var body: some View {
        DonjiList(zatvori: zatvori) {
            VStack(alignment: .leading, spacing: 12) {
                Naslov(tekst: "Talenti", velicina: 26)
                let z = stanje.zamena_talenta
                let moze = (z?.dostupno ?? 0) > 0
                if let z {
                    ProgressView(value: Double(z.korak - z.do_sledece), total: Double(z.korak)).tint(Color.teal)
                    Text(moze ? "Imaš \(z.dostupno) \(z.dostupno == 1 ? "zamenu" : "zamene"). Izaberi talenat koji menjaš, pa novi."
                              : "Sledeća zamena za \(z.do_sledece) tačnih odgovora.")
                        .font(.tekst(14, .semibold)).foregroundStyle(Color.sivaTekst)
                }
                ScrollView {
                    VStack(spacing: 8) {
                        Oznaka(tekst: "Tvoji").frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(stanje.mojiTalenti) { t in TalenatRed(talenat: t, izabran: stari == t.id) { if moze { stari = t.id } } }
                        if moze, stari != nil {
                            Oznaka(tekst: "Novi").frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6)
                            ForEach((stanje.katalog_talenata ?? []).filter { !(stanje.talenti ?? []).contains($0.id) }) { t in
                                TalenatRed(talenat: t, izabran: novi == t.id) { novi = t.id }
                            }
                        }
                    }
                }
                .frame(maxHeight: 420)
                if moze { Button("Zameni") { if let stari, let novi { zameni(stari, novi) } }.buttonStyle(.primarno).disabled(stari == nil || novi == nil) }
            }
        }
    }
}

/// Donji list za izbor tema duela (iz tema firme sa bar 10 pitanja).
struct IzborTemeList: View {
    let naslov: String
    let podnaslov: String
    let firmaId: String
    /// Koliko tema se bira (1 izazivač, 2 vlasnik).
    let izbor: Int
    var iskljuci: [String] = []
    let gotovo: ([String]) -> Void
    let zatvori: () -> Void
    @State private var teme: Ucitano<[Karijera.Tema]> = .ucitava
    @State private var izabrane: [String] = []

    var body: some View {
        DonjiList(zatvori: zatvori) {
            VStack(alignment: .leading, spacing: 12) {
                Naslov(tekst: naslov, velicina: 26)
                Text(podnaslov).font(.tekst(14)).foregroundStyle(Color.sivaTekst)
                switch teme {
                case .ucitava: VStack(spacing: 8) { Skelet(visina: 48); Skelet(visina: 48) }
                case .greska(let p): Text(p).font(.tekst(14, .semibold)).foregroundStyle(Color.crvena)
                case .gotovo(let l):
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(l.filter { !iskljuci.contains($0.tema) }, id: \.tema) { t in
                                let i = izabrane.firstIndex(of: t.tema)
                                Button { prebaci(t.tema) } label: {
                                    HStack {
                                        Text(i.map { "\($0 == 0 ? "1." : "3.") " } ?? "").font(.tekst(15, .bold)).frame(width: 26, alignment: .leading)
                                        Text(t.tema.capitalized).font(.tekst(15, .semibold))
                                        Spacer()
                                        Text("\(t.pitanja) pitanja").font(.tekst(12)).foregroundStyle(Color.sivaTekst)
                                    }
                                    .foregroundStyle(i != nil ? Color.tinta : .mastilo)
                                    .padding(12).frame(maxWidth: .infinity)
                                    .background(i != nil ? Color.zuta : Color.kartica, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.mastilo, lineWidth: i != nil ? 2 : 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 340)
                }
                Button("Potvrdi") { gotovo(izabrane) }.buttonStyle(.primarno).disabled(izabrane.count != izbor)
            }
        }
        .task {
            do { teme = .gotovo(try await Karijera.firma(firmaId).teme) } catch { teme = .greska(error.localizedDescription) }
        }
    }

    private func prebaci(_ t: String) {
        if let i = izabrane.firstIndex(of: t) { izabrane.remove(at: i) }
        else if izabrane.count < izbor { izabrane.append(t) }
        else { izabrane[izbor - 1] = t }
    }
}

struct OdmorList: View {
    let ostalo: Int
    let odmorDo: String?
    let izaberi: (Int) -> Void
    var povuci: (() -> Void)? = nil
    let zatvori: () -> Void
    var body: some View {
        DonjiList(zatvori: zatvori) {
            VStack(alignment: .leading, spacing: 12) {
                Naslov(tekst: "Godišnji odmor", velicina: 26)
                Text("Dok si na odmoru, asistenti ne daju otkaz i firma se ne zatvara. Mesečno 3 dana.")
                    .font(.tekst(15)).foregroundStyle(Color.sivaTekst)
                if let odmorDo {
                    Text("Odmor traje do \(odmorDo).").font(.tekst(14, .bold))
                    // Povlačenje odmora (vlasnik 05.11): neiskorišćeni dani se vraćaju u mesečni fond.
                    if let povuci { Button("Povuci odmor i vrati se na posao", action: povuci).buttonStyle(.zuto) }
                }
                HStack(spacing: 10) {
                    ForEach(1...3, id: \.self) { d in
                        Button("\(d) \(d == 1 ? "dan" : "dana")") { izaberi(d) }.buttonStyle(.sekundarno).disabled(d > ostalo)
                    }
                }
            }
        }
    }
}

private extension Ucitano {
    var jeGotovo: Bool { if case .gotovo = self { true } else { false } }
}

#if DEBUG
/// `-sefProba`: najduže rečenice šefa u oblačiću, provera da staju u dva reda.
private struct SefProba: View {
    var body: some View {
        let sve = Sef.netacno + Sef.jakoNetacno + Sef.smehNetacno + Sef.isteklo
        let duge = sve.map { Sef.oblik($0, zensko: true, sefZensko: true) }.sorted { $0.count > $1.count }.prefix(4)
        VStack(spacing: 14) {
            ForEach(Array(duge), id: \.self) { SefKaze(povod: .netacno, tekst: $0, lik: "z_srednja") }
            SefKaze(povod: .tacno, tekst: Sef.oblik(Sef.smehTacno[0], zensko: true), lik: "korporacija")
        }
        .padding(16).frame(maxHeight: .infinity).background(Papir())
    }
}

/// `-ishodProba`: ekran posle runde sa izmišljenim brojkama, bez igranja na nalogu.
private struct IshodProba: View {
    @State private var dani = [6, 7]
    var body: some View {
        let json = #"{"tacnih":5,"poeni":125,"placeno":true,"plata":50,"kasi":0,"ugled":30,"rekord":false,"probni":{"runde":1,"cilj":10,"tacnih":5,"danas":1},"placenih_danas":1,"prekovremeno":true}"#
        let ishod = try! JSONDecoder().decode(Karijera.IshodRunde.self, from: Data(json.utf8))
        let firma = Karijera.Firma(id: "proba", ime: "Korporacija", korporacija: true, npc: false, vlasnik: nil, vlasnik_ime: "Šef", pozicija: "",
                                   nivo: 5, stil: 1, udeo: "korporacija", kljucne: [], rekord: 0, rekord_ime: nil, rekord_igrac: nil, zaposlenih: 0, botova: 0, zastita_do: nil,
                                   sef_tacno: 2, sef_netacno: 2, sef_ometanja: 2, struka_udeo: 60, sef_smeh: true, teza: false, sef_lik: "korporacija", slobodni: [6, 7], slobodan_danas: nil, stres: 0, fokus: [], fokus_udeo: [])
        VStack(alignment: .leading, spacing: 12) {
            SlobodniDaniIzbor(dani: $dani)
            Text("Korporacija").font(.naslov(20))
            IshodRundeView(ishod: ishod, firma: firma) {} kuci: {}
        }
        .padding(16).background(Papir())
    }
}
#endif
