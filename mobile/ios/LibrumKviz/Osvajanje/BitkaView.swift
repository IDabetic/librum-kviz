import SwiftUI

/// Činjenice o državama (Wikidata, alati/cinjenice-drzava.mjs) za uvod u bitku.
enum Cinjenice {
    static let sve: [String: [String]] = {
        guard let url = Bundle.main.url(forResource: "cinjenice", withExtension: "json"),
              let d = try? Data(contentsOf: url), let s = try? JSONDecoder().decode([String: [String]].self, from: d) else { return [:] }
        return s
    }()
}

/// Bitka za državu: uvod (koju državu napadaš ili braniš, ko je drži, odbrana i činjenice,
/// odbrojavanje), pa pitanja (5 za državu koju drži igrač, 1 za neutralnu), pa rezultat.
struct BitkaView: View {
    let model: OsvajanjeModel
    let bitka: OsvajanjeModel.Bitka
    @State private var odbrojavanje = 4
    /// Pomoći vojske na tekućem pitanju: sklonjeni netačni odgovori i dodatne sekunde.
    @State private var sklonjeni: Set<Int> = []
    @State private var dodatno = 0
    /// Nagoveštaj (prvo slovo) i Savet mudraca (označen odgovor) na tekućem pitanju.
    @State private var slovo: String?
    @State private var oznacen: Int?
    /// Uvod „VS”: dva heroja uleću sa strana.
    @State private var vsUlaz = false
    @Environment(\.accessibilityReduceMotion) private var manjeKretanja

    private var drzava: Oblast { Mapa.oblast(bitka.kuda) }

    var body: some View {
        ZStack {
            Color.senka.opacity(0.96).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    switch bitka.korak {
                    case .uvod: uvod.transition(.opacity)
                    case .pitanja: pitanja.transition(.move(edge: .trailing).combined(with: .opacity))
                    case .rezultat: rezultat.transition(.scale(scale: 0.85).combined(with: .opacity))
                    }
                }
                .animation(.spring(duration: 0.35), value: bitka.korak)
                .padding(16).padding(.top, 30)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .transition(.opacity)
    }

    // MARK: Uvod

    /// Tvoj heroj levo, rivalov desno (okrenut ka tebi); prazno polje brani zamak.
    private var vs: some View {
        let ja = model.mojaVojska
        let rivalTim = bitka.napadam ? model.stanje.oblasti[bitka.kuda]?.vlasnik : model.stanje.trenutni.tim
        let rival = rivalTim.flatMap { model.stanje.vojskaTima($0) }
        let ulaz = vsUlaz || manjeKretanja
        return HStack(alignment: .bottom, spacing: 0) {
            heroj(ja?.heroj, ime: "Ti", vojska: ja?.naziv).offset(x: ulaz ? 0 : -240)
            Text("VS").font(.naslov(34)).foregroundStyle(Color.roze)
                .scaleEffect(ulaz ? 1 : 0.2).opacity(ulaz ? 1 : 0).padding(.bottom, 44)
            heroj(rival?.heroj ?? "Osvajanje_zamak", ime: bitka.rivalIme, vojska: rival?.naziv ?? "prazno polje", obrni: rival != nil)
                .offset(x: ulaz ? 0 : 240)
        }
        .frame(maxWidth: .infinity).frame(height: 150)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ti\(ja.map { ", \($0.naziv)" } ?? "") protiv \(bitka.rivalIme)\(rival.map { ", \($0.naziv)" } ?? "")")
        .onAppear { withAnimation(.spring(duration: 0.55, bounce: 0.35)) { vsUlaz = true } }
    }

    private func heroj(_ slika: String?, ime: String, vojska: String?, obrni: Bool = false) -> some View {
        VStack(spacing: 2) {
            if let slika { Image(slika).resizable().scaledToFit().scaleEffect(x: obrni ? -1 : 1).frame(height: 108) }
            Text(ime).font(.tekst(13, .bold)).foregroundStyle(Color.mastilo).lineLimit(1)
            if let vojska { Text(vojska).font(.tekst(11, .semibold)).foregroundStyle(Color.sivaTekst).lineLimit(1) }
        }
        .frame(maxWidth: .infinity)
    }

    private var uvod: some View {
        VStack(alignment: .leading, spacing: 12) {
            vs
            Oznaka(tekst: bitka.napadam ? "Napadaš" : "\(bitka.rivalIme) napada tvoju državu", boja: .roze)
            Text(drzava.ime).font(.naslov(38)).foregroundStyle(Color.mastilo)
            Text("\(Kontinenti.od(bitka.kuda).ime) · \(bitka.napadam ? (model.stanje.oblasti[bitka.kuda]?.vlasnik == nil ? "prazno polje" : "drži je \(bitka.rivalIme)") : "brani je tvoj tim")")
                .font(.tekst(14, .semibold)).foregroundStyle(Color.sivaTekst)
            if biraTemu {
                izborTeme
            } else {
                uvodSaCinjenicama
            }
        }
        .padding(20).pop(radijus: 26)
        // Vlasnik 04.11: prvo tema, pa zanimljivosti o državi 7 s (bilo 10 s zajedno sa izborom teme, previše).
        .task(id: biraTemu) {
            if biraTemu {
                for b in stride(from: Self.rokTeme, through: 0, by: -1) {
                    withAnimation { odbrojavanje = b }
                    try? await Task.sleep(for: .seconds(1))
                    if Task.isCancelled { return }
                }
                withAnimation { model.bezTeme() }
                return
            }
            Zvuk.pusti(.odbrojavanje, jacina: 0.4)
            let od = (Cinjenice.sve[bitka.kuda] ?? []).isEmpty ? Self.sekundiBezCinjenica : Self.sekundiCinjenica
            for b in stride(from: od, through: 0, by: -1) {
                withAnimation { odbrojavanje = b }
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
            }
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation { model.pocniPitanja() }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: odbrojavanje)
    }

    /// Napadač bira temu: znanje postaje strategija (tema ostaje do kraja bitke).
    private var biraTemu: Bool { bitka.napadam && !bitka.teme.isEmpty && bitka.tema == nil }
    // Vlasnik 04.11 uveče: 5 s za temu i 5 s za zanimljivosti.
    private static let rokTeme = 5
    private static let sekundiCinjenica = 5
    private static let sekundiBezCinjenica = 3

    private var izborTeme: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Izaberi temu pitanja").font(.tekst(17, .bold)).foregroundStyle(Color.mastilo)
                Spacer()
                Text("\(odbrojavanje) s").font(.naslov(18)).monospacedDigit().foregroundStyle(odbrojavanje <= 3 ? Color.crvena : Color.sivaTekst)
                    .contentTransition(.numericText(countsDown: true))
                    .accessibilityLabel("Još \(odbrojavanje) sekundi za izbor teme")
            }
            ForEach(bitka.teme, id: \.self) { t in
                Button { withAnimation { model.izaberiTemu(t) } } label: {
                    HStack {
                        Text(t).font(.tekst(17, .bold)).foregroundStyle(Color.tinta).lineLimit(2).minimumScaleFactor(0.8)
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(Color.tinta)
                    }
                    .padding(.horizontal, 16).frame(maxWidth: .infinity).frame(height: 56)
                    .background(Color.zuta, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.tinta, lineWidth: 2))
                }
                .buttonStyle(.plain)
            }
            Text("Ako ne izabereš, pitanja su mešana.").font(.tekst(12)).foregroundStyle(Color.sivaTekst)
            karteBitke
        }
    }

    private var uvodSaCinjenicama: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let t = bitka.tema { Label("Tema: \(t)", systemImage: "text.book.closed").font(.tekst(15, .bold)).foregroundStyle(Color.teal) }
            let cinjenice = Cinjenice.sve[bitka.kuda] ?? []
            if !cinjenice.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(cinjenice.prefix(3), id: \.self) { c in
                        Label(c, systemImage: "sparkle").font(.tekst(14)).foregroundStyle(Color.mastilo)
                    }
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.udubljeno, in: RoundedRectangle(cornerRadius: 14))
            }
            if let o = model.stanje.odbranaMete(bitka.kuda) {
                Label("Odbrana: \(o.naziv). \(o.opis)", systemImage: o.ikonica).font(.tekst(14, .bold)).foregroundStyle(Color.crvena)
            }
            if let t = Teren.opis(odakle: bitka.odakle, kuda: bitka.kuda) {
                Label(t, systemImage: "mountain.2").font(.tekst(14, .semibold)).foregroundStyle(Color.mastilo)
            }
            if let p = prednost { Label(p.0, systemImage: "scalemass").font(.tekst(14, .bold)).foregroundStyle(p.1 ? Color.teal : Color.crvena) }
            if bitka.sabotiranSam { Label("Rival je odigrao Sabotažu: računa ti se jedan tačan manje.", systemImage: Karta.sabotaza.ikonica).font(.tekst(14, .bold)).foregroundStyle(Color.crvena) }
            if bitka.spijun {
                Label("Špijun: na prvom pitanju ti otkriva tačan odgovor.", systemImage: Karta.spijun.ikonica)
                    .font(.tekst(14, .bold)).foregroundStyle(Color.teal)
            }
            karteBitke
            Text(bitka.uslov.pitanja > 1
                 ? "\(bitka.uslov.pitanja) pitanja po \(bitka.uslov.sekundi) s. Više tačnih osvaja; kad je isto, brži."
                 : "Jedno pitanje od \(bitka.uslov.sekundi) s. Tačno osvaja neutralnu državu.")
                .font(.tekst(14)).foregroundStyle(Color.sivaTekst)
            HStack {
                Spacer()
                Text(odbrojavanje > 0 ? "\(odbrojavanje)" : "Kreni!").font(.naslov(odbrojavanje > 0 ? 54 : 28)).lineLimit(1).minimumScaleFactor(0.6)
                    .foregroundStyle(Color.tinta).padding(.horizontal, 8)
                    .frame(width: 120, height: 120).background(Color.zuta, in: Circle()).overlay(Circle().stroke(Color.mastilo, lineWidth: 3))
                    .contentTransition(.numericText(countsDown: true))
                    .accessibilityLabel("Počinje za \(odbrojavanje)")
                Spacer()
            }
            .padding(.top, 6)
        }
    }

    // MARK: Pitanja

    private var pitanja: some View {
        let p = bitka.prikazi[bitka.redni]
        return VStack(spacing: 12) {
            HStack {
                Text(drzava.ime).font(.naslov(22)).foregroundStyle(.white)
                Spacer()
                Text("Tačno \(bitka.tacnih) od \(bitka.redni)").font(.tekst(14, .bold)).foregroundStyle(.white).monospacedDigit()
            }
            // Vlasnik 03.11: Špijun služi da vidiš odgovor na prvo pitanje bitke.
            if bitka.spijun && bitka.redni == 0, p.opcije.indices.contains(p.tacan) {
                Label("Špijun: tačan odgovor je „\(p.opcije[p.tacan])”", systemImage: Karta.spijun.ikonica).font(.tekst(14, .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            PitanjeKartica(oznaka: bitka.prikazi.count > 1 ? "Pitanje \(bitka.redni + 1) od \(bitka.prikazi.count)" : "Bitka",
                           prikaz: p, sekundi: bitka.uslov.sekundi + dodatno, eliminisani: sklonjeni.union(bitka.iskljuceni), stoji: bitka.satStoji,
                           sigurno: bitka.siguran, stit: bitka.stit) { izabran, ms in
                model.odgovorUBitci(izabran, ms: ms)
            }
            .id("\(bitka.id)-\(bitka.redni)-\(bitka.zamena)")
            .onChange(of: "\(bitka.redni)-\(bitka.zamena)") { _, _ in sklonjeni = []; dodatno = 0; slovo = nil; oznacen = nil }
            if let slovo {
                Label("Nagoveštaj: tačan odgovor počinje na „\(slovo)”", systemImage: PomocVojske.nagovestaj.ikonica)
                    .font(.tekst(15, .bold)).foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading)
            }
            if let oznacen, p.opcije.indices.contains(oznacen) {
                Label("Mudraci kažu: „\(p.opcije[oznacen])” (tačno u 3 od 4 slučaja)", systemImage: PomocVojske.savetMudraca.ikonica)
                    .font(.tekst(15, .bold)).foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading)
            }
            if bitka.moci.contains(.prisluskivanje) {
                Label(bitka.rivalPoznat.map { "Prisluškivanje: \(bitka.rivalIme) ima \($0.tacnih) od \(bitka.prikazi.count) tačnih" } ?? "Prisluškivanje: \(bitka.rivalIme) još odgovara",
                      systemImage: PomocVojske.prisluskivanje.ikonica)
                    .font(.tekst(15, .bold)).foregroundStyle(Color.zuta).frame(maxWidth: .infinity, alignment: .leading)
            }
            if !bitka.iskljuceni.isEmpty {
                Label("Drugi pokušaj: biraj još jednom", systemImage: PomocVojske.drugiPokusaj.ikonica)
                    .font(.tekst(15, .bold)).foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading)
            }
            if !bitka.uslov.bezPomoci { pomociVojske(p) }
            if model.mozePovlacenje {
                Button { withAnimation { model.povuciSe() } } label: {
                    Label("Povuci se (vojska ostaje, potez je gotov)", systemImage: "arrow.uturn.left").font(.tekst(14, .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white, lineWidth: 2))
                }
                .buttonStyle(.plain)
            }
            if bitka.uslov.bezPomoci {
                Label("Odbrana „Bez pomoći”: ovde ne možeš da igraš karte.", systemImage: "nosign").font(.tekst(13, .semibold)).foregroundStyle(.white)
            } else {
                karteBitke
            }
        }
    }

    /// Tri pomoći izabrane vojske; svaka jednom po krugu (posle toga siva do sledećeg kruga).
    @ViewBuilder private func pomociVojske(_ p: Prikaz) -> some View {
        if let v = model.mojaVojska, let t = model.mojTim {
            HStack(spacing: 8) {
                ForEach(v.pomoci) { pomoc in
                    let aktivna = pomoc.svoja && aktivno(pomoc)
                    let iskorisceno = model.stanje.iskoriscenaPomoc(t, pomoc)
                    let moze = !iskorisceno && model.mozeMoc(pomoc, bitka)
                    Button { primeni(pomoc, p) } label: {
                        VStack(spacing: 2) {
                            Image(systemName: pomoc.ikonica).font(.system(size: 17, weight: .bold))
                            Text(pomoc.naziv).font(.tekst(12, .bold)).lineLimit(1).minimumScaleFactor(0.75)
                        }
                        .foregroundStyle(Color.tinta).frame(maxWidth: .infinity).frame(height: 56)
                        .background(aktivna ? Color.teal : moze ? (pomoc.svoja ? Color.zuta : Color.white) : Color.white.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.tinta, lineWidth: pomoc.svoja ? 3 : 2))
                    }
                    .buttonStyle(.plain)
                    .disabled(!moze)
                    .accessibilityLabel("\(pomoc.naziv): \(pomoc.opis)\(iskorisceno ? " Iskorišćeno u ovom krugu." : "")")
                }
            }
            Text(v.pomoci.first(where: { $0.svoja && aktivno($0) }).map { "\($0.naziv) je aktivan: \($0.opis.prefix(1).lowercased() + $0.opis.dropFirst())" }
                 ?? "\(v.moc.naziv) je moć vojske \(v.naziv); svaka pomoć jednom po krugu.")
                .font(.tekst(12, .semibold)).foregroundStyle(.white)
        }
    }

    private func primeni(_ pomoc: PomocVojske, _ p: Prikaz) {
        guard let d = model.iskoristiPomocVojske(pomoc) else { return }
        let netacni = (0..<p.opcije.count).filter { $0 != p.tacan && !sklonjeni.contains($0) }.shuffled()
        switch d {
        case .tacanOdgovor: sklonjeni.formUnion(netacni)
        case .jedanManje: sklonjeni.formUnion(netacni.prefix(1))
        case .nagovestaj: if p.opcije.indices.contains(p.tacan) { slovo = String(p.opcije[p.tacan].prefix(1)).uppercased() }
        case .savetMudraca: oznacen = Double.random(in: 0..<1) < 0.75 ? p.tacan : netacni.first ?? p.tacan
        default: break
        }
    }

    /// Moć koja čeka odgovor (Štit, Juriš, Siguran udar, Vreme stoji).
    private func aktivno(_ p: PomocVojske) -> Bool {
        switch p.dejstvo {
        case .stit: bitka.stit; case .dvostruko: bitka.dvostruko; case .siguran: bitka.siguran; case .drugiPokusaj: bitka.drugiPokusaj
        case .plen, .utvrdjenje, .temelj, .radionica, .garnizon, .spijunskaMreza, .bedem, .munja, .prisluskivanje: bitka.moci.contains(p)
        default: false
        }
    }

    /// Prednost u tačnim odgovorima (vojska, Legija, Garda, Zima) iz ugla igrača: tekst i da li je za njega.
    private var prednost: (String, Bool)? {
        guard model.stanje.oblasti[bitka.kuda]?.vlasnik != nil else {
            let jaka = (model.stanje.oblasti[bitka.odakle]?.vojske ?? 0) - 1 >= Pravila.vojskiBezGubitkaNaNeutralnoj
            return bitka.napadam && jaka ? ("Jaka vojska: greška ti ne odnosi vojsku.", true) : nil
        }
        let p = model.stanje.pomakBitke(odakle: bitka.odakle, kuda: bitka.kuda) * (bitka.napadam ? 1 : -1)
        guard p != 0 else { return nil }
        return (p > 0 ? "Prednost: +\(p) \(p == 1 ? "tačan" : "tačna") za tebe" : "Rival ima prednost: +\(-p) \(p == -1 ? "tačan" : "tačna")", p > 0)
    }

    /// Ratne karte za bitku (Špijun, Drugi pokušaj, Sabotaža); svaka se vidi samo kad može da se odigra.
    @ViewBuilder private var karteBitke: some View {
        let ruka = model.mojeKarte
        let protivIgraca = model.stanje.oblasti[bitka.kuda]?.vlasnik != nil
        let moguce: [Karta] = [
            !bitka.spijun && bitka.korak == .uvod ? .spijun : nil,
            bitka.korak == .pitanja ? .drugiPokusaj : nil,
            bitka.napadam && protivIgraca && !bitka.sabotaza ? .sabotaza : nil,
        ].compactMap { $0 }.filter(ruka.contains)
        if !moguce.isEmpty {
            HStack(spacing: 10) {
                ForEach(moguce) { k in
                    Button { withAnimation { model.igrajKartuUBitci(k) } } label: {
                        VStack(spacing: 2) {
                            Image(systemName: k.ikonica).font(.system(size: 18, weight: .bold))
                            Text("\(k.naziv) · \(ruka.filter { $0 == k }.count)").font(.tekst(12, .bold)).lineLimit(1).minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(Color.tinta).frame(maxWidth: .infinity).frame(height: 58)
                        .background(Color.zuta, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.tinta, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(k.naziv): \(k.opis)")
                }
            }
        }
        if bitka.sabotaza { Label("Sabotaža: rival gubi jedan tačan.", systemImage: Karta.sabotaza.ikonica).font(.tekst(13, .bold)).foregroundStyle(bitka.korak == .uvod ? Color.teal : .white) }
    }

    // MARK: Rezultat

    @ViewBuilder private var rezultat: some View {
        if let ishod = bitka.ishod {
            let pobedio = bitka.napadam ? ishod.osvojeno : !ishod.osvojeno
            VStack(spacing: 14) {
                Text(naslovRezultata(ishod)).font(.naslov(32)).foregroundStyle(pobedio ? Color.white : Color.tinta).multilineTextAlignment(.center)
                if let rival = bitka.rival {
                    HStack(spacing: 10) {
                        // Vlasnik 03.11: prednost se vidi uz skor („+1 prednost”), da 4/5 protiv 4/5 ne izgleda kao nepravda.
                        let moja = bitka.pomak * (bitka.napadam ? 1 : -1)
                        skor("Ti", bitka.tacnih, bitka.ms, pobedio, prednost: max(0, moja))
                        skor(bitka.rivalIme, rival.tacnih, rival.ms, !pobedio, prednost: max(0, -moja))
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    if pobedio { Label("+1 ratna karta", systemImage: "rectangle.portrait.on.rectangle.portrait").font(.tekst(14, .bold)).foregroundStyle(.white) }
                } else {
                    Text(pobedio ? "Tačno! Država je tvoja." : (ishod.gubitakNapadaca == 0 ? "Netačno, ali jaka vojska ne gubi ništa." : "Netačno. Gubiš jednu vojsku.")).font(.tekst(15, .semibold)).foregroundStyle(pobedio ? Color.white : Color.tinta)
                }
                if ishod.izgubljenaDrzava {
                    Label(bitka.napadam ? "\(bitka.rivalIme) uzima \(Mapa.oblast(bitka.odakle).ime)" : "Uzimaš \(Mapa.oblast(bitka.odakle).ime)",
                          systemImage: "flag.2.crossed").font(.tekst(15, .bold)).foregroundStyle(pobedio ? Color.white : Color.tinta)
                }
                if ishod.plen { Label("Prestonica pala: +\(Pravila.plenPrestonice) vojski", systemImage: "crown").font(.tekst(14, .bold)).foregroundStyle(.white) }
                if ishod.proboj { Label("Proboj: +\(Pravila.probojBonus) vojske", systemImage: "bolt").font(.tekst(14, .bold)).foregroundStyle(.white) }
                Button("Nastavi") { withAnimation { model.zatvoriBitku() } }.buttonStyle(.sekundarno)
                    #if DEBUG
                    .task { if LibrumKvizApp.demoIgrac { try? await Task.sleep(for: .seconds(1.5)); withAnimation { model.zatvoriBitku() } } }
                    #endif
            }
            .padding(22).frame(maxWidth: .infinity)
            .pop(pobedio ? .teal : .narandzasta, radijus: 26)
            .sensoryFeedback(pobedio ? .success : .error, trigger: bitka.id)
            .onAppear { Zvuk.pusti(ishod.plen || ishod.proboj ? .prestonicaPala : pobedio ? .osvojeno : .netacno, jacina: 0.45) }
        } else {
            UcitavanjeMaskota(maskota: .zig, tekst: "\(bitka.rivalIme) odgovara…", velicina: 64)
            .padding(24).pop(radijus: 26)
        }
    }

    private func naslovRezultata(_ ishod: Ishod) -> String {
        if bitka.napadam { return ishod.osvojeno ? "Osvojeno: \(drzava.ime)!" : "\(drzava.ime): odbrana je izdržala" }
        return ishod.osvojeno ? "\(drzava.ime) pada: \(bitka.rivalIme) osvaja" : "Odbranjeno: \(drzava.ime)!"
    }

    private func skor(_ ime: String, _ tacnih: Int, _ ms: Int, _ pobednik: Bool, prednost: Int) -> some View {
        VStack(spacing: 2) {
            Text(ime).font(.tekst(13, .bold)).lineLimit(1)
            Text("\(tacnih)/\(bitka.prikazi.count)").font(.naslov(30)).monospacedDigit()
            if prednost > 0 {
                Text("+\(prednost) prednost").font(.tekst(13, .heavy))
            }
            Text(String(format: "%.1f s", locale: .srpski, Double(ms) / 1000)).font(.tekst(12, .semibold)).opacity(0.75)
        }
        .accessibilityElement(children: .combine)
        .foregroundStyle(Color.tinta)
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(.vertical, 12)
        .background(pobednik ? Color.zuta : Color.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.tinta, lineWidth: 2))
    }
}
