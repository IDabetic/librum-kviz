import SwiftUI

// MARK: 04 Detalji kviza

/// Detalji kviza iz kita: naslovna kartica, tri podatka, najbolji rezultat i start.
/// Stanja: zaključano (nivo), nije moglo da počne, pokreće se.
struct KvizDetaljiView: View {
    @Environment(Napredak.self) private var napredak
    let stavka: KvizStavka

    enum Start: Equatable { case miruje, pokrece, greska(String) }
    @State private var start: Start = .miruje
    @State private var pitanja: [Pitanje] = []
    @State private var igra = false
    @State private var omiljen = false

    private var zakljucano: Bool { napredak.nivo < stavka.nivo }

    var body: some View {
        VStack(spacing: 14) {
            GornjaTraka {
                HStack(spacing: 8) {
                    KrugDugme(ikonica: omiljen ? "heart.fill" : "heart", opis: "Omiljeno") { omiljen.toggle() }
                    ShareLink(item: URL(string: "https://kviz.librum.club")!, message: Text("Igraj „\(stavka.naslov)” u Librum kvizu")) {
                        Image(systemName: "square.and.arrow.up").font(.system(size: 17, weight: .bold)).foregroundStyle(Color.mastilo)
                            .frame(width: 44, height: 44).background(Color.kartica, in: Circle()).overlay(Circle().stroke(Color.kremTamnija, lineWidth: 1.5))
                    }
                    .accessibilityLabel("Podeli")
                }
            }
            ScrollView {
                VStack(spacing: 14) {
                    naslovna
                    HStack(spacing: 10) {
                        Plocica(ikonica: "list.number", vrednost: "\(stavka.brojPitanja)", naziv: "Pitanja")
                        Plocica(ikonica: "clock", vrednost: "\(stavka.brojPitanja * stavka.sekundi / 60) min", naziv: "Trajanje")
                        Plocica(ikonica: "bolt", vrednost: stavka.tezina, naziv: "Težina")
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Kako se igra").font(.tekst(15, .bold))
                        ForEach(stavka.pravila, id: \.self) { t in
                            Label(t, systemImage: "checkmark.circle").font(.tekst(14)).foregroundStyle(Color.mastilo)
                        }
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading).mirna()
                    if zakljucano {
                        obavestenje("lock.fill", "Otključava se na nivou \(stavka.nivo)",
                                    "Ti si na nivou \(napredak.nivo). Još \(napredak.xpUNivou.treba - napredak.xpUNivou.imam) XP do sledećeg.", .udubljeno)
                    } else if let naj = napredak.s.najbolje[stavka.id] {
                        obavestenje("trophy", "Tvoj najbolji: \(naj)/10", naj == 10 ? "Savršeno. Možeš li opet?" : "Nadmaši ga i uzmi +50 novčića za 10/10.", .zuta)
                    }
                    if case .greska(let poruka) = start {
                        obavestenje("exclamationmark.triangle", "Kviz nije mogao da počne", poruka, .crvenaSvetla)
                    }
                }
                .padding(.bottom, 8)
            }
            Button { Task { await pokreni() } } label: {
                if start == .pokrece {
                    HStack(spacing: 10) { ProgressView().tint(Color.naMastilu); Text("Pokrećem…") }
                } else {
                    Text(zakljucano ? "Zaključano" : start == .miruje ? "Igraj kviz" : "Pokušaj ponovo")
                }
            }
            .buttonStyle(.primarno)
            .disabled(zakljucano || start == .pokrece)
        }
        .padding(.horizontal, 16).padding(.bottom, 12)
        .background(Papir())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .fullScreenCover(isPresented: $igra) { KvizIgraView(stavka: stavka, pitanja: pitanja) }
    }

    private var naslovna: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color(hex: stavka.boja))
            Circle().fill(.white.opacity(0.22)).frame(width: 220).offset(x: 150, y: 70)
            MaskotaSlika(maskota: stavka.maskota, velicina: 150).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(12)
            VStack(alignment: .leading, spacing: 6) {
                Text(stavka.naslov).font(.naslov(30)).foregroundStyle(Color.tinta).lineLimit(2).minimumScaleFactor(0.7)
                Label(stavka.kategorija, systemImage: stavka.ikonica).font(.tekst(13, .bold)).foregroundStyle(Color.tinta.opacity(0.7))
            }
            .padding(14)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.tinta, lineWidth: 2.5))
            .rotationEffect(.degrees(-3)).padding(18).frame(maxWidth: 240, alignment: .leading)
            Text(stavka.opis).font(.tekst(14, .semibold)).foregroundStyle(stavka.tekstBoja)
                .frame(maxWidth: 190, alignment: .leading).frame(maxHeight: .infinity, alignment: .bottomLeading).padding(18)
        }
        .frame(height: 290)
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.mastilo, lineWidth: 2.5))
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color.senka).offset(y: 5))
    }

    private func obavestenje(_ ikonica: String, _ naslov: String, _ tekst: String, _ boja: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: ikonica).font(.system(size: 18, weight: .bold)).frame(width: 40, height: 40)
                .background(Color.kartica, in: Circle()).overlay(Circle().stroke(Color.mastilo, lineWidth: 2))
            VStack(alignment: .leading, spacing: 2) {
                Text(naslov).font(.tekst(15, .bold))
                Text(tekst).font(.tekst(13)).opacity(0.75)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(boja == .zuta ? Color.tinta : Color.mastilo)
        .padding(12).pop(boja, radijus: 18)
        .accessibilityElement(children: .combine)
    }

    private func pokreni() async {
        guard case .tema(let fond, let zanr, let tesko) = stavka.vrsta else { return }
        start = .pokrece
        do {
            pitanja = try await PaketPitanja.deljeni.kviz(Fond(rawValue: fond) ?? .opste, zanr: zanr, tesko: tesko, broj: stavka.brojPitanja)
            start = .miruje
            igra = true
        } catch {
            start = .greska(error.localizedDescription)
        }
    }
}

// MARK: 05–09 Igra

/// Ceo tok jedne partije: spremi se → pitanja → rezultati → pregled.
struct KvizIgraView: View {
    @Environment(\.dismiss) private var zatvori
    @Environment(Napredak.self) private var napredak
    @Environment(Sesija.self) private var sesija
    let stavka: KvizStavka
    let pitanja: [Pitanje]

    enum Faza { case spremiSe, pitanje, rezultati, pregled }
    @State private var faza: Faza = .spremiSe
    @State private var kviz = KlasicniKviz()
    @State private var prikazi: [Prikaz] = []
    @State private var pocetak = Date()
    @State private var ishod: Napredak.Ishod?
    @State private var prethodniNajbolji: Int?

    var body: some View {
        ZStack {
            switch faza {
            case .spremiSe:
                SpremiSeView(stavka: stavka, spremno: !prikazi.isEmpty) { pocetak = Date(); withAnimation { faza = .pitanje } }
            case .pitanje:
                KvizPitanjaView(stavka: stavka, prikazi: prikazi, kviz: $kviz, prekini: { zatvori() }) { zavrsi() }
            case .rezultati:
                KvizRezultatiView(stavka: stavka, kviz: kviz, sekundi: Int(Date().timeIntervalSince(pocetak)), ishod: ishod, prethodniNajbolji: prethodniNajbolji,
                                  pregled: { withAnimation { faza = .pregled } }, ponovo: { ponovo() }, zatvori: { zatvori() })
            case .pregled:
                KvizPregledView(kviz: kviz) { withAnimation { faza = .rezultati } }
            }
        }
        .task { prikazi = pitanja.map(Prikaz.init) }
    }

    private func zavrsi() {
        prethodniNajbolji = napredak.s.najbolje[stavka.id]
        let kat = stavka.kategorija == "Knjige" ? "Knjige · \(stavka.naslov)" : stavka.kategorija
        let mereni = kviz.zapisi.filter { !$0.preskoceno }
        let rezultat = zavrsiPartiju(napredak, sesija, igra: stavka.id.hasPrefix("slikari") ? "slikari" : "tema", kviz: stavka.id, poeni: kviz.poeni,
                                     tacnih: kviz.tacnih, netacnih: kviz.netacnih, kategorija: kat, brzih: kviz.brzih,
                                     prosekMs: prosek(mereni.reduce(0) { $0 + $1.ms }, mereni.count))
        ishod = rezultat
        withAnimation { faza = .rezultati }
    }

    private func ponovo() {
        kviz = KlasicniKviz()
        prikazi = pitanja.shuffled().map(Prikaz.init)
        ishod = nil
        withAnimation { faza = .spremiSe }
    }
}

// MARK: 05 Spremi se

struct SpremiSeView: View {
    let stavka: KvizStavka
    let spremno: Bool
    let kreni: () -> Void
    @Environment(\.dismiss) private var zatvori
    @State private var broj = 3

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Button { zatvori() } label: {
                    Image(systemName: "xmark").font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 44, height: 44).overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 2))
                }
                .accessibilityLabel("Zatvori")
                Spacer()
                Text(stavka.naslov).font(.tekst(14, .bold)).foregroundStyle(.white)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            Spacer()
            ZStack {
                Circle().fill(Color.white).frame(width: 220, height: 220).overlay(Circle().stroke(Color.tinta, lineWidth: 4))
                    .background(Circle().fill(Color.tinta).offset(y: 7))
                if spremno {
                    Text(broj > 0 ? "\(broj)" : "Kreni!").font(.naslov(broj > 0 ? 120 : 52)).foregroundStyle(Color.tinta)
                        .contentTransition(.numericText(countsDown: true))
                } else {
                    VStack(spacing: 10) { ProgressView().tint(Color.tinta).scaleEffect(1.4); Text("Povezujem…").font(.tekst(15, .bold)).foregroundStyle(Color.tinta) }
                }
            }
            .accessibilityElement(children: .combine)
            Text(broj > 0 ? "Spremi se!" : "Idemo!").font(.naslov(40)).foregroundStyle(.white)
            Text("\(stavka.brojPitanja) pitanja · \(stavka.sekundi) sekundi po pitanju").font(.tekst(15, .semibold)).foregroundStyle(.white.opacity(0.9))
            Label("Brži odgovor = više poena", systemImage: "bolt").font(.tekst(13, .bold)).foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 8).background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
            Spacer()
            MaskotaSlika(maskota: stavka.maskota, velicina: 150)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.teal.ignoresSafeArea())
        .sensoryFeedback(.impact(weight: .medium), trigger: broj)
        .task(id: spremno) {
            guard spremno else { return }
            Zvuk.pusti(.odbrojavanje, jacina: 0.45)
            for b in [2, 1, 0] { try? await Task.sleep(for: .milliseconds(800)); withAnimation { broj = b } }
            try? await Task.sleep(for: .milliseconds(500))
            kreni()
        }
    }
}

// MARK: 06–07 Pitanje i odgovor

struct KvizPitanjaView: View {
    @Environment(Napredak.self) private var napredak
    @Environment(Mreza.self) private var mreza
    let stavka: KvizStavka
    let prikazi: [Prikaz]
    @Binding var kviz: KlasicniKviz
    let prekini: () -> Void
    let gotovo: () -> Void

    @State private var redni = 0
    @State private var ostalo: Double = 15
    @State private var ukupnoVreme: Double = 15
    @State private var izabran: Int?
    @State private var otkriveno = false
    @State private var isteklo = false
    @State private var pauza = false
    @State private var prekid = false
    @State private var sklonjeni: Set<Int> = []
    @State private var nagovestaj: String?
    @State private var poslednji: (ukupno: Int, brzina: Int, niz: Int) = (0, 0, 0)
    @State private var pocetakPitanja = Date()
    /// Sat ne teče dok slika ne stigne (Picture Round), da spora mreža ne krade vreme.
    @State private var slikaSpremna = false
    /// Jedna pomoć po partiji (vlasnikovo pravilo), iz dnevnog fonda za sve igre.
    @State private var pomocIskoriscena = false

    private static let najvecaVisinaSlike: CGFloat = 300
    private let otkucaj = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    private var p: Prikaz { prikazi[redni] }
    private var zuri: Bool { ostalo <= 5 && !otkriveno }

    var body: some View {
        VStack(spacing: 14) {
            gornja
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    kartica
                    if let nagovestaj, !otkriveno { MaskotaKaze(maskota: Maskota(rawValue: napredak.s.maskota) ?? .mimi, tekst: nagovestaj) }
                    if !otkriveno { pomoci }
                    if kviz.niz >= 2 && !otkriveno {
                        Label("\(kviz.niz) zaredom · čuvaj niz!", systemImage: "flame").font(.tekst(13, .bold)).frame(maxWidth: .infinity)
                    }
                }
                .padding(.bottom, otkriveno ? 220 : 12)
            }
        }
        .padding(.horizontal, 16)
        .background(Papir())
        .overlay(alignment: .bottom) { if otkriveno { listOdgovora.transition(.move(edge: .bottom)) } }
        .overlay { if pauza { pauzaSloj } }
        .overlay {
            if prekid {
                Dijalog(naslov: "Prekinuti kviz?", tekst: "Odgovori iz ovog kviza se ne čuvaju.",
                        potvrda: "Prekini", odustani: "Nastavi", opasno: true) { prekini() } zatvori: { prekid = false; pauza = false }
            }
        }
        .onReceive(otkucaj) { _ in
            guard !otkriveno, !pauza, !prekid, p.slika == nil || slikaSpremna else { return }
            ostalo = max(0, ostalo - 0.1)
            if ostalo == 0 { odgovori(nil) }
        }
        .sensoryFeedback(.warning, trigger: zuri) { _, novo in novo }
        .onChange(of: zuri) { _, z in if z { Zvuk.pusti(.tikanje, jacina: 0.25, ponavljaj: true) } else { Zvuk.stani(.tikanje) } }
        .onChange(of: pauza) { _, p in if p { Zvuk.stani(.tikanje) } }
        .onDisappear { Zvuk.stani(.tikanje) }
        .sensoryFeedback(trigger: otkriveno) { _, novo in novo ? (izabran == p.tacan ? .success : .error) : nil }
        .animation(.spring(duration: 0.35), value: otkriveno)
    }

    private var gornja: some View {
        HStack(spacing: 12) {
            KrugDugme(ikonica: "xmark", opis: "Prekini kviz") { pauza = true; prekid = true }
            VStack(alignment: .leading, spacing: 5) {
                Text("Pitanje \(redni + 1) od \(prikazi.count)").font(.tekst(12, .bold)).foregroundStyle(Color.sivaTekst)
                GeometryReader { g in
                    RoundedRectangle(cornerRadius: 4).fill(Color.kartica).overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.mastilo, lineWidth: 1.5))
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4).fill(Color.teal).frame(width: g.size.width * Double(redni + (otkriveno ? 1 : 0)) / Double(prikazi.count))
                        }
                }
                .frame(height: 10)
            }
            KrugDugme(ikonica: "pause", opis: "Pauza") { pauza = true }
            Text(kviz.poeni.formatted()).font(.tekst(15, .bold)).monospacedDigit().foregroundStyle(Color.naMastilu)
                .padding(.horizontal, 12).frame(height: 40).background(Color.mastilo, in: RoundedRectangle(cornerRadius: 14))
                .contentTransition(.numericText()).accessibilityLabel("\(kviz.poeni) poena")
        }
        .padding(.top, 8)
    }

    private var kartica: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(p.zanr ?? stavka.kategorija, systemImage: stavka.ikonica).font(.tekst(12, .bold)).foregroundStyle(Color.tinta)
                    .padding(.horizontal, 10).padding(.vertical, 5).overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.tinta, lineWidth: 1.5))
                Spacer()
                Label(String(format: "0:%02d", Int(ostalo.rounded(.up))), systemImage: "timer").font(.tekst(13, .bold)).monospacedDigit()
                    .foregroundStyle(.white).padding(.horizontal, 10).padding(.vertical, 5)
                    .background(zuri ? Color.crvena : Color.tinta, in: RoundedRectangle(cornerRadius: 9))
                    .accessibilityLabel("\(Int(ostalo)) sekundi")
            }
            GeometryReader { g in
                RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.6))
                    .overlay(alignment: .leading) { RoundedRectangle(cornerRadius: 3).fill(zuri ? Color.crvena : Color.tinta).frame(width: g.size.width * ostalo / ukupnoVreme) }
            }
            .frame(height: 6)
            if let url = p.slika { slika(url) }
            Text(p.tekst).font(.naslov(p.slika == nil ? 22 : 19)).foregroundStyle(Color.tinta).fixedSize(horizontal: false, vertical: true)
            if !sklonjeni.isEmpty && !otkriveno {
                Label("Sklonjeno \(sklonjeni.count) netačna", systemImage: "circle.lefthalf.filled").font(.tekst(13, .bold)).foregroundStyle(Color.tinta)
            }
            ForEach(p.opcije.indices, id: \.self) { i in
                OdgovorDugme(slovo: ["A", "B", "C", "D"][i], tekst: p.opcije[i], stanje: stanje(i)) { odgovori(i) }
                    .disabled(otkriveno || sklonjeni.contains(i))
                    .opacity(sklonjeni.contains(i) && !otkriveno ? 0.25 : 1)
            }
        }
        .padding(16)
        .pop(.zuta)
        .scaleEffect(zuri ? 1.01 : 1)
        .animation(zuri ? .easeInOut(duration: 0.4).repeatForever() : .default, value: zuri)
    }

    private func slika(_ url: URL) -> some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeIn(duration: 0.2))) { faza in
            switch faza {
            case .success(let s):
                // Okvir prati oblik slike (cela slika, bez sečenja); kad uska uspravna slika
                // udari u najveću visinu, ivice puni zamućena kopija iste slike umesto belog.
                s.resizable().scaledToFit()
                    .frame(maxHeight: Self.najvecaVisinaSlike)
                    .frame(maxWidth: .infinity)
                    .background { s.resizable().scaledToFill().blur(radius: 22).overlay(Color.black.opacity(0.12)) }
                    .clipped()
                    .onAppear { slikaSpremna = true }
            case .failure:
                Label("Slika nije stigla. Pogađaj po nazivu dela.", systemImage: "photo.badge.exclamationmark")
                    .font(.tekst(13, .bold)).foregroundStyle(Color.tinta).frame(maxWidth: .infinity, minHeight: 120)
                    .onAppear { slikaSpremna = true }
            default:
                Skelet(visina: 230, radijus: 14)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.tinta, lineWidth: 2))
        .accessibilityLabel("Slika dela")
    }

    private var pomoci: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                pomoc(.polaPola) {
                    let netacni = p.opcije.indices.filter { $0 != p.tacan && !sklonjeni.contains($0) }
                    sklonjeni.formUnion(netacni.shuffled().prefix(2))
                }
                pomoc(.nagovestaj) {
                    if let i = p.opcije.indices.filter({ $0 != p.tacan && !sklonjeni.contains($0) }).randomElement() {
                        sklonjeni.insert(i)
                        nagovestaj = "Sigurno nije „\(p.opcije[i])”. Ostalo je \(p.opcije.count - sklonjeni.count)."
                    }
                }
                pomoc(.vreme) { ostalo += 10; ukupnoVreme += 10 }
                pomoc(.preskok) { kviz.preskok(p); sledece() }
            }
            PomocNapomena(iskoriscenaUPartiji: pomocIskoriscena)
        }
        .padding(.horizontal, 6).padding(.top, 8)
    }

    private func pomoc(_ vrsta: Napredak.Pomoc, radnja: @escaping () -> Void) -> some View {
        PomocDugme(vrsta: vrsta.rawValue, ikonica: vrsta.ikonica, naziv: vrsta.naziv, iskoriscenaUPartiji: $pomocIskoriscena, radnja: radnja)
    }

    private var listOdgovora: some View {
        let tacno = izabran == p.tacan
        let boja: Color = tacno ? .teal : isteklo ? .narandzasta : .crvena
        let tekstBoja: Color = isteklo && !tacno ? .tinta : .white
        return VStack(alignment: .leading, spacing: 10) {
            Text(tacno ? ["Bravo!", "Pogodak!", "Tako je!"][redni % 3] : isteklo ? "Vreme je isteklo" : "Promašaj")
                .font(.naslov(32)).foregroundStyle(tekstBoja)
            if tacno {
                Text(["+\(poslednji.ukupno) poena", kviz.niz >= 2 ? "\(kviz.niz) zaredom" : nil, poslednji.brzina > 0 ? "brzina +\(poslednji.brzina)" : nil]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.tekst(14, .bold)).foregroundStyle(tekstBoja)
            }
            Text(tacno ? "Odgovor: \(p.opcije[p.tacan])." : "Tačan odgovor je \(p.opcije[p.tacan]).")
                .font(.tekst(15, .semibold)).foregroundStyle(tekstBoja.opacity(0.92))
            if let opis = p.opis { Text(opis).font(.tekst(13)).foregroundStyle(tekstBoja.opacity(0.85)) }
            if !mreza.povezan {
                Label("Veza je prekinuta. Igra ide dalje, rezultat čuvamo kad se veza vrati.", systemImage: "wifi.slash")
                    .font(.tekst(13, .semibold)).foregroundStyle(tekstBoja)
            }
            Button(redni + 1 < prikazi.count ? "Sledeće pitanje" : "Vidi rezultat") { sledece() }.buttonStyle(.sekundarno).padding(.top, 4)
        }
        .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 34)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            // Negativan razmak spušta pozadinu ispod donje ivice ekrana (kućni indikator).
            UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32, style: .continuous).fill(boja)
                .overlay(UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32, style: .continuous).stroke(Color.mastilo, lineWidth: 2.5))
                .padding(.bottom, -80).padding(.horizontal, -2)
        }
        .accessibilityElement(children: .contain)
    }

    private var pauzaSloj: some View {
        ZStack {
            Color.senka.opacity(0.6).ignoresSafeArea()
            if !prekid {
                VStack(spacing: 14) {
                    MaskotaSlika(maskota: .bloop, velicina: 100)
                    Naslov(tekst: "Pauza", velicina: 34)
                    Text("Vreme stoji. Pitanje \(redni + 1) od \(prikazi.count), \(kviz.poeni) poena.").font(.tekst(15)).foregroundStyle(Color.sivaTekst)
                        .multilineTextAlignment(.center)
                    Button("Nastavi") { pauza = false }.buttonStyle(.primarno)
                    Button("Prekini kviz") { prekid = true }.buttonStyle(.sekundarno)
                }
                .padding(24).pop().padding(24)
                .accessibilityAddTraits(.isModal)
            }
        }
    }

    private func stanje(_ i: Int) -> OdgovorDugme.Stanje {
        guard otkriveno else { return .obicno }
        if i == p.tacan { return .tacno }
        return i == izabran ? .netacno : .bledo
    }

    private func odgovori(_ i: Int?) {
        guard !otkriveno else { return }
        izabran = i
        isteklo = i == nil
        poslednji = kviz.odgovor(p, izabran: i, ostaloSekundi: ostalo, ms: Int(Date().timeIntervalSince(pocetakPitanja) * 1000))
        otkriveno = true
        Zvuk.stani(.tikanje)
        Zvuk.pusti(i == nil ? .isteklo : i == p.tacan ? .tacno : .netacno, jacina: 0.5)
    }

    private func sledece() {
        guard redni + 1 < prikazi.count else { gotovo(); return }
        redni += 1
        izabran = nil; otkriveno = false; isteklo = false; sklonjeni = []; nagovestaj = nil
        ostalo = Double(stavka.sekundi); ukupnoVreme = ostalo; pocetakPitanja = Date(); slikaSpremna = false
    }
}

// MARK: 08 Rezultati

struct KvizRezultatiView: View {
    @Environment(Sesija.self) private var sesija
    @Environment(Napredak.self) private var napredak
    let stavka: KvizStavka
    let kviz: KlasicniKviz
    let sekundi: Int
    let ishod: Napredak.Ishod?
    let prethodniNajbolji: Int?
    let pregled: () -> Void
    let ponovo: () -> Void
    let zatvori: () -> Void

    enum Cuvanje: Equatable { case cuva, sacuvano, lokalno, greska(String) }
    @State private var cuvanje: Cuvanje = .cuva
    @State private var bedz: Bedz?

    private var ukupno: Int { kviz.zapisi.count }
    private var zvezdice: Int { KlasicniKviz.zvezdice(tacnih: kviz.tacnih, od: ukupno) }
    private var savrseno: Bool { ukupno > 0 && kviz.tacnih == ukupno }
    private var slabo: Bool { Double(kviz.tacnih) / Double(max(1, ukupno)) < 0.4 }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                KrugDugme(ikonica: "xmark", opis: "Zatvori", radnja: zatvori)
                Spacer()
                ShareLink(item: "Odgovorio sam \(kviz.tacnih)/\(ukupno) u kvizu „\(stavka.naslov)” (\(kviz.poeni) poena). Librum kviz: https://kviz.librum.club") {
                    Image(systemName: "square.and.arrow.up").font(.system(size: 17, weight: .bold)).foregroundStyle(Color.mastilo)
                        .frame(width: 44, height: 44).background(Color.kartica, in: Circle()).overlay(Circle().stroke(Color.kremTamnija, lineWidth: 1.5))
                }
                .accessibilityLabel("Podeli rezultat")
            }
            ScrollView {
                VStack(spacing: 14) {
                    Naslov(tekst: savrseno ? "Savršeno!" : slabo ? "Biće bolje!" : "Kviz završen!", velicina: 32)
                    glavna
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        Plocica(ikonica: "star", vrednost: kviz.poeni.formatted(), naziv: "Poeni", boja: .narandzasta)
                        Plocica(ikonica: "sparkles", vrednost: "+\(ishod?.xp ?? 0)", naziv: "XP", boja: .narandzasta)
                        Plocica(ikonica: "checkmark.circle", vrednost: "\(Int(Double(kviz.tacnih) / Double(max(1, ukupno)) * 100))%", naziv: "Tačnost")
                        Plocica(ikonica: "clock", vrednost: String(format: "%d:%02d", sekundi / 60, sekundi % 60), naziv: "Ukupno vreme", boja: .nebo)
                    }
                    statusCuvanja
                }
            }
            Button("Pregled odgovora", action: pregled).buttonStyle(.primarno)
            Button("Igraj ponovo", action: ponovo).buttonStyle(.sekundarno)
        }
        .padding(.horizontal, 16).padding(.bottom, 12)
        .background(Papir())
        .overlay { if let bedz { BedzOtkljucanView(bedz: bedz) { withAnimation { self.bedz = nil } } } }
        .task {
            if let prvi = ishod?.noviBedzevi.first { try? await Task.sleep(for: .milliseconds(600)); withAnimation { bedz = prvi } }
        }
        .task { await sacuvaj() }
        .onAppear { Zvuk.pusti(savrseno ? .pobeda : .kraj, jacina: savrseno ? 0.55 : 0.45) }
    }

    private var glavna: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: i < zvezdice ? "star.fill" : "star").font(.system(size: 26, weight: .bold))
                        .foregroundStyle(i < zvezdice ? Color.tinta : Color.tinta.opacity(0.3))
                }
            }
            .accessibilityLabel("\(zvezdice) od 3 zvezdice")
            Text("\(kviz.tacnih)/\(ukupno)").font(.naslov(72)).foregroundStyle(Color.tinta).monospacedDigit()
            Text(savrseno ? "Svih \(ukupno), \(sesija.nadimak ?? "šampione")!" : slabo ? "Svaki šampion je jednom počeo." : "Odlično, \(sesija.nadimak ?? "drugar")!")
                .font(.tekst(17, .bold)).foregroundStyle(Color.tinta)
            if let naj = prethodniNajbolji {
                Text(naj >= kviz.tacnih ? "Tvoj najbolji je \(naj)/10" : "Novi lični rekord za ovaj kviz").font(.tekst(13, .semibold)).foregroundStyle(Color.tinta.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 22)
        .background(alignment: .bottomLeading) { MaskotaSlika(maskota: .bloop, velicina: 70).offset(x: -6, y: 14) }
        .background(alignment: .bottomTrailing) { MaskotaSlika(maskota: slabo ? .lumi : .zig, velicina: 60).offset(x: 6, y: 10) }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .pop(savrseno ? .teal : slabo ? .nebo : .zuta, radijus: 28)
        .overlay { if savrseno { Konfete() } }
    }

    @ViewBuilder private var statusCuvanja: some View {
        switch cuvanje {
        case .cuva:
            Label("Čuvam rezultat…", systemImage: "arrow.triangle.2.circlepath").font(.tekst(13, .semibold)).foregroundStyle(Color.sivaTekst)
        case .sacuvano:
            Label("Sačuvano na nalogu", systemImage: "checkmark.icloud").font(.tekst(13, .semibold)).foregroundStyle(Color.teal)
        case .lokalno:
            Label("Sačuvano na ovom telefonu. Prijavi se u Profilu da ide i na nalog.", systemImage: "iphone").font(.tekst(13, .semibold))
                .foregroundStyle(Color.sivaTekst).multilineTextAlignment(.center)
        case .greska(let poruka):
            VStack(spacing: 8) {
                Label("Rezultat nije sačuvan na nalogu: \(poruka)", systemImage: "exclamationmark.icloud").font(.tekst(13, .semibold)).foregroundStyle(Color.crvena)
                    .multilineTextAlignment(.center)
                Button("Pokušaj ponovo") { Task { await sacuvaj() } }.font(.tekst(14, .bold)).foregroundStyle(Color.mastilo)
            }
        }
    }

    /// Upis u quiz_results (RLS: samo svoj red). Bez naloga ostaje na telefonu.
    private func sacuvaj() async {
        guard let quizId = stavka.quizId, let id = sesija.korisnikId, let token = try? await sesija.vazeciToken() else { cuvanje = .lokalno; return }
        cuvanje = .cuva
        do {
            try await Supabase.deljeni.upisi("quiz_results", [
                "user_id": id, "quiz_id": quizId, "score": kviz.tacnih, "total": ukupno, "time_taken": sekundi, "score_points": kviz.poeni,
            ], token: token)
            cuvanje = .sacuvano
        } catch {
            cuvanje = .greska(error.localizedDescription)
        }
    }
}

/// Konfete za savršen rezultat i otključan bedž.
struct Konfete: View {
    @State private var pada = false
    private let boje: [Color] = [.roze, .zuta, .nebo, .teal, .ljubicasta, .narandzasta]
    var body: some View {
        GeometryReader { g in
            ForEach(0..<26, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2).fill(boje[i % boje.count]).frame(width: 7, height: 14)
                    .rotationEffect(.degrees(Double(i * 37)))
                    .position(x: CGFloat((i * 53) % Int(max(1, g.size.width))), y: pada ? g.size.height + 40 : -20 - CGFloat(i * 9))
                    .animation(.easeIn(duration: 1.8 + Double(i % 5) * 0.2).delay(Double(i % 7) * 0.08), value: pada)
            }
        }
        .clipped()
        .allowsHitTesting(false)
        .onAppear { pada = true }
        .accessibilityHidden(true)
    }
}

// MARK: 09 Pregled odgovora

struct KvizPregledView: View {
    let kviz: KlasicniKviz
    let nazad: () -> Void
    enum Filter: Hashable { case sve, tacno, netacno }
    @State private var filter: Filter = .sve
    @State private var otvoren: UUID?

    private var lista: [KlasicniKviz.Zapis] {
        switch filter {
        case .sve: kviz.zapisi
        case .tacno: kviz.zapisi.filter(\.tacno)
        case .netacno: kviz.zapisi.filter { !$0.tacno }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            KrugDugme(ikonica: "chevron.left", opis: "Nazad", radnja: nazad)
            Naslov(tekst: "Pregled", velicina: 36)
            Text("\(kviz.tacnih) od \(kviz.zapisi.count) tačno · tapni pitanje za detalje").font(.tekst(14)).foregroundStyle(Color.sivaTekst)
            PodvuceniIzbor(izbor: $filter, opcije: [(.sve, "Sve · \(kviz.zapisi.count)"), (.tacno, "Tačno · \(kviz.tacnih)"),
                                                    (.netacno, "Netačno · \(kviz.zapisi.count - kviz.tacnih)")])
            ScrollView {
                VStack(spacing: 10) {
                    if lista.isEmpty {
                        StanjeEkrana(maskota: .bloop, naslov: filter == .netacno ? "Bez ijedne greške!" : "Nijedan tačan",
                                     tekst: filter == .netacno ? "Sve si pogodio. Ovaj spisak je prazan s razlogom." : "Sledeći put će biti bolje.")
                    }
                    ForEach(lista) { z in red(z) }
                }
                .padding(.vertical, 6)
            }
        }
        .padding(.horizontal, 16)
        .background(Papir())
    }

    private func red(_ z: KlasicniKviz.Zapis) -> some View {
        let broj = (kviz.zapisi.firstIndex { $0.id == z.id } ?? 0) + 1
        let otvoreno = otvoren == z.id || !z.tacno
        return Button { withAnimation { otvoren = otvoren == z.id ? nil : z.id } } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Oznaka(tekst: "Pitanje \(broj)")
                    Spacer()
                    Label(z.tacno ? "Tačno" : z.preskoceno ? "Preskočeno" : "Netačno", systemImage: z.tacno ? "checkmark.circle" : "xmark.circle")
                        .font(.tekst(12, .bold)).foregroundStyle(z.tacno ? Color.teal : Color.crvena)
                }
                Text(z.prikaz.tekst).font(.tekst(16, .bold)).foregroundStyle(Color.mastilo).multilineTextAlignment(.leading)
                if let i = z.izabran {
                    (Text("Tvoj odgovor: ").foregroundStyle(Color.sivaTekst) + Text(z.prikaz.opcije[i]).foregroundStyle(z.tacno ? Color.teal : Color.crvena))
                        .font(.tekst(14, .semibold))
                } else {
                    Text(z.preskoceno ? "Preskočeno" : "Bez odgovora, vreme je isteklo").font(.tekst(14, .semibold)).foregroundStyle(Color.sivaTekst)
                }
                if otvoreno && !z.tacno {
                    Label("Tačan odgovor: \(z.prikaz.opcije[z.prikaz.tacan])", systemImage: "checkmark.circle").font(.tekst(14, .bold))
                        .foregroundStyle(Color.teal).padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.tealSvetla, in: RoundedRectangle(cornerRadius: 12))
                }
                if otvoreno && z.tacno {
                    Text("Odgovoreno za \(String(format: "%.1f", Double(z.ms) / 1000)) s · +\(z.poeni) poena").font(.tekst(13)).foregroundStyle(Color.sivaTekst)
                }
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.kartica, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(otvoreno ? Color.mastilo : Color.kremTamnija, lineWidth: otvoreno ? 2.5 : 1.5))
        }
        .buttonStyle(.plain)
    }
}
