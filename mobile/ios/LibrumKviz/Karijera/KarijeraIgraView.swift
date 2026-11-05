import SwiftUI

/// Niz pitanja Karijere: runda (10) ili duel za firmu (30, tri teme). Pomoći su igračeve 4 izabrane
/// (KarijeraPomoc, svaka jednom po rundi) i asistenti firme (server, samo u njihovoj temi). Jedna pomoć po pitanju.
struct KarijeraPitanjaView: View {
    let pitanja: [Karijera.Pitanje]
    /// Firma čiji botovi pomažu (runda); u duelu ide izazov.
    var firmaId: String? = nil
    var izazovId: String? = nil
    /// Šef komentariše kad igrač radi kod drugog; nivo podešava vlasnik firme (Mirni režim ga stišava).
    var sef = false
    var sefNivo = Sef.Nivo()
    var pomoci: [String] = Karijera.mojePomoci
    var botovi: [Karijera.Bot] = []
    /// Office iza kartice (slika zgrade firme); posle odgovora kartica ode i vidi se ceo.
    var pozadina = "Karijera_Korporacija_1"
    /// Mesto za vreme na nebu (id firme): isto nebo kao na kartici firme tog dana.
    var mesto = "korporacija"
    let gotovo: ([[String: Any]]) -> Void

    /// Kartica je na ekranu; false dok se gleda office između dva pitanja.
    @State private var kartica = true
    @State private var i = 0
    @State private var prikazi: [Prikaz] = []
    @State private var odgovori: [[String: Any]] = []
    @State private var eliminisani: Set<Int> = []
    @State private var savet: String?
    @State private var iskoriscene: [String: Int] = [:]
    @State private var pomocNaPitanju: String?
    @State private var sefPoruka: (Sef.Povod, String)?
    @State private var cekaBota = false
    /// Pomoći „Produžen rok”, „Pauza za kafu”: dodatne sekunde i zaustavljen sat za tekuće pitanje.
    @State private var dodatnoVreme = 0
    @State private var satStoji = false
    /// Ometanja (§14): pitanja runde koja ih dobijaju, tekuće ometanje i tresenje kartice za haos.
    @State private var raspored: Set<Int> = []
    @State private var ometanje: Sef.Ometanje?
    @State private var tresi = false
    /// Pitanje (indeks u nizu) na kom dolazi jedino veliko ometanje runde (zadatak ili haos), ako ga ima.
    @State private var velikoNa: Int?
    /// Igrač je izabrao odgovor (kartica još otkriva tačan): ometanje tada više ne sme da iskoči.
    @State private var izabranoNa: Int?

    var body: some View {
        ZStack(alignment: .bottom) {
            // Office iza: dok je kartica gore, prigušen; između pitanja ceo i jasan.
            // Scena: nebo po dobu dana i office na tlu; dok je kartica gore, scena je prigušena.
            ZStack(alignment: .bottom) {
                Nebo(mesto: mesto)
                Image(pozadina).resizable().scaledToFit()
                    .frame(maxHeight: 440)
                    .padding(.horizontal, 10)
                Ulica(mesto: mesto)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.mastilo, lineWidth: 2))
            .brightness(kartica ? -0.25 : 0)
            .saturation(kartica ? 0.7 : 1)
            .accessibilityHidden(true)
            VStack(spacing: 12) {
                if i < prikazi.count, kartica {
                    let p = pitanja[i]
                    VStack(spacing: 12) {
                        if let r = p.runda, i % 10 == 0 {
                            Text("Runda \(r) · \(p.tema?.capitalized ?? "")").font(.naslov(20)).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if let savet {
                            Label(savet, systemImage: "lightbulb.fill").font(.tekst(15, .bold)).foregroundStyle(Color.tinta)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(12).pop(.zuta, radijus: 14)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        PitanjeKartica(oznaka: "Pitanje \(i + 1) od \(pitanja.count)\(p.tema.map { " · \($0)" } ?? "")",
                                       prikaz: prikazi[i], sekundi: sekundi, eliminisani: eliminisani, stoji: satStoji, boja: .nebo,
                                       izabrano: { izabranoNa = i; ometanje = nil; tresi = false }) { izabran, ms in
                            odgovori(izabran, ms)
                        }
                        .blur(radius: ometanje?.vrsta == .haos && ometanje?.trese == false ? 7 : 0)
                        .offset(x: tresi ? 9 : 0)
                        .overlay(alignment: .top) { if let ometanje { OmetanjeView(ometanje: ometanje, lik: sefNivo.lik) { self.ometanje = nil } } }
                        pomociTraka
                    }
                    .id(i)
                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .move(edge: .bottom).combined(with: .opacity)))
                }
                Spacer(minLength: 0)
                if let (povod, tekst) = sefPoruka {
                    SefKaze(povod: povod, tekst: tekst, lik: sefNivo.lik)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onTapGesture { sledece() }
                }
            }
        }
        .animation(.spring(duration: 0.35), value: savet)
        .animation(.spring(duration: 0.45), value: kartica)
        .animation(.spring(duration: 0.35), value: sefPoruka?.1)
        .animation(.spring(duration: 0.3), value: ometanje)
        .onAppear { if prikazi.isEmpty { prikazi = pitanja.map(\.zaPrikaz); prviUtisak(); zakaziOmetanje() } }
    }

    private var sekundi: Int { Pravila.sekundiPoPitanju + (talenti.contains("brz_um") ? 5 : 0) + dodatnoVreme }

    /// Najviše jedno ometanje po pitanju, nikad u poslednjih 5 s; sat se ne zaustavlja.
    private func zakaziOmetanje() {
        guard sef, sefNivo.ometanja > 0, i < pitanja.count else { return }
        if i % 10 == 0 {
            raspored = Sef.rasporedOmetanja(nivo: sefNivo.ometanja).reduce(into: []) { $0.insert(i + $1) }
            velikoNa = Sef.velikoPitanje(nivo: sefNivo.ometanja, raspored: raspored)
        }
        #if DEBUG
        // -ometanjeSvako: svako pitanje, vrste redom (upad, zadatak, haos) za proveru izgleda.
        let proba = CommandLine.arguments.contains("-ometanjeSvako")
        if proba { raspored.insert(i) }
        #else
        let proba = false
        #endif
        guard raspored.contains(i) else { return }
        let pitanjeSada = i, kraj = proba ? 2.5 : Double(sekundi) - 7
        Task {
            try? await Task.sleep(for: .seconds(Double.random(in: 2...max(2.5, kraj))))
            guard pitanjeSada == i, kartica, odgovori.count == i, izabranoNa != i else { return }
            let o = proba ? Sef.ometanja.filter { $0.vrsta == [.upad, .zadatak, .haos][pitanjeSada % 3] }.randomElement()! : Sef.ometanje(nivo: sefNivo.ometanja, veliko: velikoNa == pitanjeSada)
            ometanje = o
            Zvuk.pusti(.poruka)
            switch o.vrsta {
            case .upad:
                try? await Task.sleep(for: .seconds(1.5))
                if ometanje == o { ometanje = nil }
            case .haos:
                if o.trese { withAnimation(.linear(duration: 0.07).repeatCount(24, autoreverses: true)) { tresi = true } }
                try? await Task.sleep(for: .seconds(1.8))
                tresi = false
                if ometanje == o { ometanje = nil }
            case .zadatak: break // čeka dugme „Odmah, šefe”
            }
        }
    }

    private var pomociTraka: some View {
        HStack(spacing: 10) {
            ForEach(pomoci.compactMap(KarijeraPomoc.po)) { p in
                // Talenat „Dobar kolega”: prva izabrana pomoć može dvaput u rundi.
                let limit = p.id == pomoci.first && talenti.contains("kolega_plus") ? 2 : 1
                dugme(p.id, ikonica: p.ikonica, naziv: "\(p.naziv): \(p.opis)", moze: (iskoriscene[p.id] ?? 0) < limit) { pomoc(p) }
            }
            if !botovi.isEmpty {
                let bot = botZaPitanje
                Button { pomocBota() } label: {
                    Image(bot.map { $0.slika } ?? "Karijera_Asistent_1").resizable().scaledToFit().frame(height: 40)
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background(Color.kartica, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.mastilo, lineWidth: 2))
                }
                .buttonStyle(BezPrigusenja())
                .disabled(pomocNaPitanju != nil || cekaBota || bot == nil)
                .opacity(pomocNaPitanju == nil && bot != nil ? 1 : 0.35)
                .accessibilityLabel(bot.map { "Pitaj asistenta \($0.ime), tema \($0.tema)" } ?? "Nijedan asistent ne zna ovu temu")
            }
        }
    }

    /// Bot čija je tema ista kao tema pitanja (server proverava i ostale oznake pitanja).
    private var botZaPitanje: Karijera.Bot? {
        guard i < pitanja.count else { return nil }
        return botovi.first { $0.tema == pitanja[i].tema && $0.pomoci_ostalo > 0 } ?? (izazovId == nil ? nil : botovi.first { $0.tema == pitanja[i].tema })
    }

    private func dugme(_ vrsta: String, ikonica: String, naziv: String, moze: Bool, radnja: @escaping () -> Void) -> some View {
        let aktivno = moze && pomocNaPitanju == nil
        return Button(action: radnja) {
            Image(systemName: ikonica).font(.system(size: 20, weight: .semibold)).foregroundStyle(Color.mastilo)
                .frame(maxWidth: .infinity).frame(height: 54)
                .background(Color.kartica, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.mastilo, lineWidth: 2))
        }
        .buttonStyle(BezPrigusenja())
        .disabled(!aktivno)
        .opacity(aktivno ? 1 : 0.35)
        .accessibilityLabel(naziv)
    }

    /// Talenti koje primenjuje aplikacija (ostale računa server).
    private var talenti: Set<String> { Karijera.mojiTalenti }

    /// Talenat „Prvi utisak”: prvo pitanje svake runde od 10 dobija besplatno pola-pola (ne računa se kao pomoć).
    private func prviUtisak() {
        guard talenti.contains("prvi_utisak"), i % 10 == 0, i < prikazi.count else { return }
        eliminisani = Set((0..<4).filter { $0 != prikazi[i].tacan }.shuffled().prefix(2))
        savet = "Prvi utisak: dva odgovora su sklonjena."
    }

    /// Izvodi efekte pomoći (Pomoci.swift). Talenti: Istraživač +10% tačnosti saveta, Intuicija bez čekanja.
    private func pomoc(_ pomoc: KarijeraPomoc) {
        guard i < prikazi.count, pomocNaPitanju == nil else { return }
        let p = prikazi[i], pitanjeSada = i
        iskoriscene[pomoc.id, default: 0] += 1
        pomocNaPitanju = pomoc.id
        let bonus = talenti.contains("istrazivac") ? 0.1 : 0
        func posle(_ s: Double, _ radnja: @escaping () -> Void) {
            let cekaj = talenti.contains("intuicija") ? 0 : s
            if cekaj == 0 { radnja(); return }
            Task { try? await Task.sleep(for: .seconds(cekaj)); if pitanjeSada == i { withAnimation { radnja() } } }
        }
        var poruke: [String] = []
        for e in pomoc.efekti {
            switch e {
            case .ukloni(let n, let k):
                let netacni = (0..<4).filter { $0 != p.tacan && !eliminisani.contains($0) }.shuffled().prefix(n)
                if k > 0 { poruke.append("Za \(Int(k)) s nestaje \(n == 1 ? "jedan netačan" : "\(n) netačna").") }
                posle(k) { eliminisani.formUnion(netacni) }
            case .vreme(let s): dodatnoVreme += s; poruke.append("+\(s) s")
            case .satStoji: satStoji = true; poruke.append("Sat stoji.")
            case .otkrij: eliminisani = Set((0..<4).filter { $0 != p.tacan }); poruke.append("Insajder: tačan je \(["A", "B", "C", "D"][p.tacan]).")
            case .savet(let v, let k):
                let pogodak = Double.random(in: 0..<1) < min(0.98, v + bonus) ? p.tacan : (0..<4).filter { $0 != p.tacan }.randomElement()!
                if k > 0 && !talenti.contains("intuicija") { poruke.append("\(pomoc.naziv): stiže za \(Int(k)) s…") }
                posle(k) { savet = "\(pomoc.naziv): \(["A", "B", "C", "D"][pogodak])." }
            case .anketa(let v):
                let glavni = Double.random(in: 0..<1) < min(0.98, v + bonus) ? p.tacan : (0..<4).filter { $0 != p.tacan }.randomElement()!
                var glasovi = (0..<4).map { $0 == glavni ? Int.random(in: 45...65) : Int.random(in: 3...20) }
                let zbir = glasovi.reduce(0, +); glasovi = glasovi.map { $0 * 100 / zbir }
                poruke.append((0..<4).map { "\(["A", "B", "C", "D"][$0]) \(glasovi[$0])%" }.joined(separator: " · "))
            case .prvoSlovo:
                // Prvo pravo slovo (preskače navodnike i zagrade); „Prvo slovo: H”, a u Brainstormingu „prvo slovo je H.”
                let slovo = p.opcije[p.tacan].first { $0.isLetter || $0.isNumber }.map { String($0).uppercased() } ?? "?"
                poruke.append(pomoc.naziv == "Prvo slovo" ? slovo : "prvo slovo je \(slovo).")
            }
        }
        if !poruke.isEmpty { savet = "\(pomoc.naziv): " + poruke.joined(separator: " ") }
    }

    private func pomocBota() {
        guard i < pitanja.count, pomocNaPitanju == nil else { return }
        let q = pitanja[i], p = prikazi[i], pitanjeSada = i
        cekaBota = true
        Task {
            defer { cekaBota = false }
            do {
                let o = try await Karijera.pomocBota(firma: firmaId, pitanje: q.id, izazov: izazovId)
                guard pitanjeSada == i else { return }
                let izPrikaza = q.options.indices.contains(o.izbor) ? p.opcije.firstIndex(of: q.options[o.izbor]) : nil
                pomocNaPitanju = "bot"
                savet = "\(o.bot) (\(o.tema)): \(izPrikaza.map { ["A", "B", "C", "D"][$0] } ?? "?"), \(o.sigurnost)% siguran."
            } catch {
                savet = error.localizedDescription
            }
        }
    }

    private func odgovori(_ izabran: Int?, _ ms: Int) {
        let q = pitanja[i], p = prikazi[i]
        var o: [String: Any] = ["id": q.id, "izbor": q.izvorni(izabran, prikaz: p), "ms": ms]
        if let pomocNaPitanju { o["pomoc"] = pomocNaPitanju }
        odgovori.append(o)
        // Kartica ode, vidi se office (u Korporaciji i šef), pa dolazi sledeće pitanje.
        kartica = false
        ometanje = nil
        tresi = false
        let povod: Sef.Povod = izabran == nil ? .isteklo : izabran == p.tacan ? .tacno : .netacno
        let jacina = sefNivo.jacina(povod)
        if sef, jacina > 0 {
            sefPoruka = (povod, Sef.recenica(povod, jacina: jacina, smeh: sefNivo.smeh, zensko: Karijera.mojPol == "z", sefZensko: Sef.lik(sefNivo.lik).zensko))
        }
        let pitanjeSada = i
        Task { try? await Task.sleep(for: .seconds(sefPoruka != nil ? 2.7 : 1.3)); if pitanjeSada == i { sledece() } }
    }

    private func sledece() {
        guard odgovori.count == i + 1 else { return }
        sefPoruka = nil
        savet = nil
        eliminisani = []
        pomocNaPitanju = nil
        dodatnoVreme = 0
        satStoji = false
        if i + 1 >= pitanja.count { gotovo(odgovori) } else { i += 1; kartica = true; prviUtisak(); zakaziOmetanje() }
    }
}

/// Jedna runda u firmi: 10 pitanja, pa obračun sa servera.
struct KarijeraRundaView: View {
    let firma: Karijera.Firma
    var botovi: [Karijera.Bot] = []
    var probni = false
    let zavrseno: () -> Void

    @Environment(\.dismiss) private var nazad
    enum Faza { case ucitava, greska(String), igra([Karijera.Pitanje]), salje, ishod(Karijera.IshodRunde) }
    @State private var faza: Faza = .ucitava
    /// Koliko je rundi probnog rada već odigrano (za napetiju muziku u poslednjoj).
    @State private var probniRunda = 0
    var pocetnaProbnaRunda = 0
    /// Odbrojavanje pre runde (vlasnik 05.11): 4 s sa zanimljivošću, pitanja se učitavaju u međuvremenu.
    @State private var priprema = 0
    @State private var zanimljivost: Zanimljivosti.Stavka?
    @State private var tracSlika = "Karijera_Trac_1"
    /// Potvrda izlaska usred runde (vlasnik 05.11: napuštena runda = 0 tačnih).
    @State private var izlaz = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                KrugDugme(ikonica: "xmark", opis: "Prekini rundu") { if case .igra = faza { izlaz = true } else { nazad() } }
                VStack(alignment: .leading, spacing: 2) {
                    Text(firma.ime).font(.naslov(20)).lineLimit(1)
                    Text((probni ? "Probni rad" : firma.udeoNaziv) + (firma.slobodan_danas == true ? " · slobodan dan, prekovremeno +10%" : ""))
                        .font(.tekst(13, .semibold)).foregroundStyle(Color.sivaTekst).lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer()
            }
            switch faza {
            case .ucitava:
                PripremaRunde(broj: max(priprema, 1), stavka: zanimljivost, slika: tracSlika)
            case .salje:
                VStack(spacing: 12) { Skelet(visina: 380, radijus: 24); Skelet(visina: 54) }
            case .greska(let poruka):
                StanjeEkrana(maskota: .lumi, naslov: "Runda nije krenula", tekst: poruka, dugme: "Pokušaj ponovo") { Task { await ucitaj() } }
            case .igra(let pitanja):
                KarijeraPitanjaView(pitanja: pitanja, firmaId: firma.id, sef: firma.vlasnik != Sesija.trenutna?.korisnikId,
                                    sefNivo: firma.sefNivo.mirno(Karijera.mirni), botovi: botovi, pozadina: firma.slika, mesto: firma.korporacija ? "korporacija" : firma.id) { odg in
                    Task { await posalji(odg) }
                }
            case .ishod(let o):
                IshodRundeView(ishod: o, firma: firma) { zavrseno(); Task { await ucitaj() } } kuci: { zavrseno(); nazad() }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Papir())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task { probniRunda = pocetnaProbnaRunda; await ucitaj() }
        .overlay {
            if izlaz, case .igra(let pitanja) = faza {
                Dijalog(naslov: "Napustiti rundu?", tekst: "Ako izađeš sada, runda se računa kao 0 tačnih od 10, a plaćena runda se troši.",
                        potvrda: "Izađi", odustani: "Nastavi", opasno: true,
                        potvrdi: { izlaz = false; Task { await predaj(pitanja); zavrseno(); nazad() } }, zatvori: { izlaz = false })
            }
        }
        .onDisappear { KarijeraMuzika.stani() }
    }

    private func ucitaj() async {
        faza = .ucitava
        (zanimljivost, tracSlika) = Zanimljivosti.nasumicna()
        async let stigla = Karijera.pitanjaRunde(firma.id)
        for s in stride(from: PripremaRunde.sekundi, to: 0, by: -1) {
            priprema = s
            try? await Task.sleep(for: .seconds(1))
        }
        do {
            let p = try await stigla
            guard p.count == 10 else { faza = .greska("Stiglo je \(p.count) od 10 pitanja. Pokušaj ponovo."); return }
            faza = .igra(p)
            KarijeraMuzika.pusti(muzikaRunde)
        } catch { faza = .greska(error.localizedDescription) }
    }

    /// Korporacija: džez klavir (poslednja runda probnog rada napetija); svoja firma: lounge; tuđa: valcer.
    private var muzikaRunde: Zvuk.Vrsta {
        if firma.korporacija { return probni && probniRunda == 9 ? .karijeraProbniKraj : .karijeraKorporacija }
        return firma.vlasnik == Sesija.trenutna?.korisnikId ? KarijeraMuzika.zaMojuFirmu(firma.id) : .karijeraPosao
    }

    /// Napuštena runda: šalje se kao 10 netačnih odgovora (0 tačnih), da izlazak ne bude način da se izbegne loša runda.
    private func predaj(_ pitanja: [Karijera.Pitanje]) async {
        KarijeraMuzika.stani()
        let odg: [[String: Any]] = pitanja.map { ["id": $0.id, "izbor": -1, "ms": Pravila.sekundiPoPitanju * 1000] }
        _ = try? await Karijera.zavrsiRundu(firma.id, odgovori: odg)
    }

    private func posalji(_ odg: [[String: Any]]) async {
        faza = .salje
        KarijeraMuzika.stani()
        do {
            let o = try await Karijera.zavrsiRundu(firma.id, odgovori: odg)
            probniRunda = o.probni?.runde ?? probniRunda
            faza = .ishod(o)
            // Pohvala zvukom: položen probni > rekord > dobra runda; plata zvoni kasom.
            if let p = o.probni, let i = p.ishod, i >= 0 { Zvuk.pusti(.karijeraUnapredjenje) }
            else if o.rekord { Zvuk.pusti(.karijeraRekord) }
            else if o.tacnih >= 7 { Zvuk.pusti(.karijeraUspeh, jacina: 0.45) }
            if o.plata > 0 { Task { try? await Task.sleep(for: .seconds(1.2)); Zvuk.pusti(.karijeraKasa, jacina: 0.5) } }
        }
        catch { faza = .greska(error.localizedDescription) }
    }
}

struct IshodRundeView: View {
    let ishod: Karijera.IshodRunde
    let firma: Karijera.Firma
    /// Odmah nova runda u istoj firmi.
    let dalje: () -> Void
    /// Izlaz iz igre, nazad na Karijeru.
    let kuci: () -> Void

    /// Posle 10. runde probnog rada (ili kad je probni gotov) sledeće runde u probnom nema.
    private var imaSledecu: Bool {
        if let p = ishod.probni { return p.ishod == nil && (p.danas ?? 0) < Karijera.probniDnevno }
        return true
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                rezultat
                if ishod.prekovremeno == true {
                    Label(Sef.oblik("Opa, prekovremeno! Danas je slobodan dan, a ti si {došao|došla}. Plata i kasa +10%.", zensko: Karijera.mojPol == "z"), systemImage: "moon.stars.fill")
                        .font(.tekst(15, .bold)).foregroundStyle(Color.tinta)
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading).pop(.zuta, radijus: 14)
                }
                if ishod.rekord {
                    Label("Nov rekord firme!", systemImage: "trophy.fill").font(.tekst(16, .bold)).foregroundStyle(Color.tinta)
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading).pop(.zuta, radijus: 14)
                }
                brojke
                // Podeli ili objavi u Igračima (vlasnik 05.11), isto kao ostale igre.
                HStack {
                    Spacer()
                    PodeliRezultat(igra: "Karijera", naslov: firma.ime, veliko: "\(ishod.tacnih)/10",
                                   detalji: ["\(ishod.poeni) poena", "+\(ishod.ugled) ugleda"], ilustracija: firma.slika, boja: .nebo,
                                   objava: (igra: "karijera", poeni: ishod.poeni))
                }
                if let p = ishod.probni { probni(p) }
                if !imaSledecu && ishod.probni?.ishod == nil {
                    Text("Za danas je to \(Karijera.probniDnevno) rundi probnog rada. Nastavi sutra.").font(.tekst(14, .semibold)).foregroundStyle(Color.sivaTekst)
                }
            }
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
        // Dugmad stoje na dnu ekrana, da posle kratkog sadržaja ne ostane prazna polovina.
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                if imaSledecu {
                    Button { dalje() } label: { Label("Sledeća runda", systemImage: "arrow.right") }.buttonStyle(.primarno)
                }
                Button { kuci() } label: { Label("Idi kući", systemImage: "house") }.buttonStyle(imaSledecu ? .sekundarno : .primarno)
            }
            .padding(.top, 10)
            .background(Papir())
        }
    }

    /// Rezultat runde na plavoj kartici, sa zgradom firme na nebu tog dana.
    private var rezultat: some View {
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(ocena).font(.tekst(14, .bold)).foregroundStyle(.white.opacity(0.85))
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(ishod.tacnih)").font(.naslov(64)).foregroundStyle(.white)
                    Text("/ 10").font(.naslov(24)).foregroundStyle(.white.opacity(0.8))
                }
                Text("tačnih odgovora").font(.tekst(15, .semibold)).foregroundStyle(.white.opacity(0.9))
            }
            .padding(18)
            Spacer(minLength: 0)
            ZStack(alignment: .bottom) {
                Nebo(mesto: firma.korporacija ? "korporacija" : firma.id)
                Image(firma.slika).resizable().scaledToFit().padding(.top, 14).padding(.horizontal, 6)
                Ulica(mesto: firma.korporacija ? "korporacija" : firma.id, gustina: 0.7)
            }
            .frame(width: 130, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(10)
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .background(KarijeraKartica.plava, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.mastilo, lineWidth: 2))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(ishod.tacnih) od 10 tačnih. \(ocena)")
    }

    private var ocena: String {
        switch ishod.tacnih {
        case 9...: "Odlična runda"
        case 7...8: "Dobra runda"
        case 5...6: "Solidno"
        default: "Teška runda"
        }
    }

    /// Sve brojke u jednom redu (3 ili 4 kolone), bez praznog mesta u mreži.
    private var brojke: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                broj("star.fill", "\(ishod.poeni)", "Poeni", .narandzasta)
                Divider().frame(height: 44)
                broj("banknote", Karijera.novac(ishod.plata), "Plata", .teal)
                if !firma.korporacija {
                    Divider().frame(height: 44)
                    broj("building.2", Karijera.novac(ishod.kasi), "Kasi firme", .ljubicasta)
                }
                Divider().frame(height: 44)
                broj("rosette", "+\(ishod.ugled)", "Ugled", .roze)
            }
            Divider()
            Text(ishod.placeno ? "Plaćenih rundi danas: \(ishod.placenih_danas) od 10." : "Danas si odigrao 10 plaćenih rundi. Ova se računa samo za ugled i ekspertizu.")
                .font(.tekst(13, .semibold)).foregroundStyle(Color.sivaTekst).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14).mirna()
    }

    private func broj(_ ikonica: String, _ vrednost: String, _ naziv: String, _ boja: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: ikonica).font(.system(size: 16, weight: .semibold)).foregroundStyle(boja)
            Text(vrednost).font(.naslov(20)).foregroundStyle(Color.mastilo).lineLimit(1).minimumScaleFactor(0.6)
            Text(naziv).font(.tekst(12, .semibold)).foregroundStyle(Color.sivaTekst).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func probni(_ p: Karijera.Probni) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Oznaka(tekst: "Probni rad")
            ProgressView(value: Double(p.runde), total: Double(max(p.cilj, 1))).tint(Color.teal)
            Text("Runda \(p.runde) od \(p.cilj) · \(p.tacnih) tačnih od \(p.runde * 10)").font(.tekst(14, .semibold))
            if let ishod = p.ishod {
                if ishod >= 0 {
                    Label(ishod == 2 ? "Prošao si! Svoj office i 2 asistenta." : ishod == 1 ? "Prošao si! Svoj office i 1 asistent." : "Prošao si! Svoj office, bez asistenata.",
                          systemImage: "party.popper.fill").font(.tekst(16, .bold)).foregroundStyle(Color.teal)
                } else {
                    Label("Nije dovoljno. Ostaješ u Korporaciji; novi probni rad posle 3 radna dana.", systemImage: "exclamationmark.triangle.fill")
                        .font(.tekst(15, .bold)).foregroundStyle(Color.crvena)
                }
            }
        }
        .padding(14).mirna()
    }
}

/// Duel za firmu: 30 pitanja u tri runde, pa predaja. Ishod stiže kad oba igrača odigraju (NPC odmah).
struct KarijeraDuelView: View {
    let izazov: Karijera.Izazov
    /// Botovi firme pomažu vlasniku (server proverava pokušaj i broj pomoći).
    var botovi: [Karijera.Bot] = []
    let zavrseno: () -> Void

    @Environment(Sesija.self) private var sesija
    @Environment(\.dismiss) private var nazad
    enum Faza { case ucitava, greska(String), igra([Karijera.Pitanje]), salje, ishod(Karijera.IshodDuela) }
    @State private var faza: Faza = .ucitava

    private var jaVlasnik: Bool { izazov.vlasnik == sesija.korisnikId }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                KrugDugme(ikonica: "xmark", opis: "Zatvori") { nazad() }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Duel za firmu").font(.naslov(20))
                    Text("\(izazov.vlasnik_ime) protiv \(izazov.izazivac_ime)").font(.tekst(13, .semibold)).foregroundStyle(Color.sivaTekst).lineLimit(1)
                }
                Spacer()
            }
            switch faza {
            case .ucitava, .salje:
                VStack(spacing: 12) { Skelet(visina: 380, radijus: 24); Skelet(visina: 54) }
            case .greska(let poruka):
                StanjeEkrana(maskota: .lumi, naslov: "Duel nije krenuo", tekst: poruka, dugme: "Pokušaj ponovo") { Task { await ucitaj() } }
            case .igra(let pitanja):
                KarijeraPitanjaView(pitanja: pitanja, izazovId: izazov.id, pomoci: Karijera.mojiTalenti.contains("duelista") ? Karijera.mojePomoci : Array(Karijera.mojePomoci.prefix(2)),
                                    botovi: jaVlasnik && izazov.botova > 0 ? botovi : [], pozadina: izazov.firma.slika, mesto: izazov.firma.id) { odg in Task { await predaj(odg) } }
            case .ishod(let o):
                ishodView(o)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Papir())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task { await ucitaj() }
        .onDisappear { KarijeraMuzika.stani() }
    }

    @ViewBuilder private func ishodView(_ o: Karijera.IshodDuela) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Naslov(tekst: "\(o.moji_tacni) od 30 tačnih", velicina: 32)
            if o.stanje == "gotov" {
                let pobeda = o.pobednik == sesija.korisnikId
                Label(pobeda ? (jaVlasnik ? "Odbranio si firmu!" : "Firma je tvoja!") : (jaVlasnik ? "Izgubio si firmu." : "Vlasnik je odbranio firmu."),
                      systemImage: pobeda ? "crown.fill" : "xmark.octagon.fill")
                    .font(.tekst(17, .bold)).foregroundStyle(Color.tinta)
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading).pop(pobeda ? .zuta : .nebo, radijus: 16)
                if let v = o.vlasnik_tacnih, let z = o.izazivac_tacnih {
                    Text("Vlasnik \(v) : \(z) izazivač\(o.ishod.map { " · \($0)" } ?? "")").font(.tekst(15, .semibold)).foregroundStyle(Color.sivaTekst)
                }
            } else {
                Text("Tvoj rezultat je sačuvan. Ishod stiže kad i drugi igrač odigra duel (najviše 24 sata).")
                    .font(.tekst(15, .semibold)).foregroundStyle(Color.sivaTekst)
            }
            Button("Dalje") { zavrseno(); nazad() }.buttonStyle(.primarno)
            Spacer()
        }
    }

    private func ucitaj() async {
        faza = .ucitava
        do {
            let p = try await Karijera.pitanjaDuela(izazov.id)
            guard p.count == 30 else { faza = .greska("Duel nema svih 30 pitanja."); return }
            faza = .igra(p)
            KarijeraMuzika.pusti(jaVlasnik ? .karijeraOdbrana : .karijeraDuel)
        } catch { faza = .greska(error.localizedDescription) }
    }

    private func predaj(_ odg: [[String: Any]]) async {
        faza = .salje
        KarijeraMuzika.stani()
        do {
            let o = try await Karijera.predajDuel(izazov.id, odgovori: odg)
            faza = .ishod(o)
            if o.stanje == "gotov", o.pobednik == sesija.korisnikId { Zvuk.pusti(.karijeraRekord) }
        }
        catch { faza = .greska(error.localizedDescription) }
    }
}


/// Tračevi i istine iz kancelarije za pripremu runde (vlasnik 05.11), src/lib/igre/kancelarija.json, isto i na Androidu.
enum Zanimljivosti {
    struct Stavka: Decodable { let vrsta: String; let tekst: String }
    static let sve: [Stavka] = {
        guard let url = Bundle.main.url(forResource: "kancelarija", withExtension: "json"),
              let d = try? Data(contentsOf: url), let s = try? JSONDecoder().decode([Stavka].self, from: d) else { return [] }
        return s
    }()
    static let brojSlika = 14
    static func nasumicna() -> (Stavka?, String) { (sve.randomElement(), "Karijera_Trac_\(Int.random(in: 1...brojSlika))") }
}

/// Priprema pre runde: odbrojavanje 4, 3, 2, 1, ilustracija kolega i trač ili istina iz kancelarije u oblačiću.
struct PripremaRunde: View {
    static let sekundi = 4
    let broj: Int
    let stavka: Zanimljivosti.Stavka?
    let slika: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Oznaka(tekst: "Spremi se, runda počinje za", boja: .sivaTekst)
                Spacer()
                Text("\(broj)").font(.naslov(56)).foregroundStyle(Color.mastilo).contentTransition(.numericText(countsDown: true))
                    .animation(.snappy, value: broj).accessibilityLabel("Runda počinje za \(broj)")
            }
            Image(slika).resizable().scaledToFill().frame(maxWidth: .infinity).frame(height: 210).clipped()
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.mastilo, lineWidth: 2))
                .accessibilityHidden(true)
            if let stavka {
                VStack(alignment: .leading, spacing: 8) {
                    Oznaka(tekst: stavka.vrsta == "trac" ? "Trač iz kancelarije" : "Istina, proveri", boja: .tinta)
                    Text(stavka.tekst).font(.tekst(17, .semibold)).foregroundStyle(Color.tinta).fixedSize(horizontal: false, vertical: true)
                }
                .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .pop(stavka.vrsta == "trac" ? .zuta : .nebo, radijus: 22)
            }
        }
        .padding(.top, 8)
    }
}
