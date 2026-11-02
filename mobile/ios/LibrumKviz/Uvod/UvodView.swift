import SwiftUI
import UserNotifications

/// Upoznavanje iz kita (Onboarding): tri slajda, interesovanja, drugar, dnevni cilj,
/// obaveštenja, probno zagrevanje i „Spreman si”. Na kraju upisuje izbore u Napredak.
struct UvodView: View {
    @Environment(Napredak.self) private var napredak

    enum Korak: Int, CaseIterable { case slajdovi, interesovanja, drugar, cilj, obavestenja, zagrevanje, priprema, gotovo }
    @State private var korak: Korak = .slajdovi
    @State private var interesovanja: Set<String> = []
    @State private var maskota: Maskota = .mimi
    @State private var cilj = 3
    @State private var podsetnik = true

    var body: some View {
        VStack(spacing: 0) {
            if ![.slajdovi, .priprema, .gotovo].contains(korak) {
                HStack {
                    KrugDugme(ikonica: "chevron.left", opis: "Nazad") { nazad() }
                    Spacer()
                    CrticeKoraka(ukupno: 5, trenutni: korak.rawValue - 1)
                    Spacer()
                    preskoci
                }
                .padding(.horizontal, 20).padding(.top, 8)
            }
            Group {
                switch korak {
                case .slajdovi: UvodSlajdovi(preskoci: zavrsi) { idi(.interesovanja) }
                case .interesovanja: UvodInteresovanja(izabrano: $interesovanja) { idi(.drugar) }
                case .drugar: UvodDrugar(maskota: $maskota) { idi(.cilj) }
                case .cilj: UvodCilj(cilj: $cilj, podsetnik: $podsetnik) { idi(.obavestenja) }
                case .obavestenja: UvodObavestenja(maskota: maskota) { idi(.zagrevanje) }
                case .zagrevanje: UvodZagrevanje(maskota: maskota) { idi(.priprema) }
                case .priprema: UvodPriprema(interesovanja: Array(interesovanja)) { zavrsiIzbore(); idi(.gotovo) }
                case .gotovo: UvodGotovo(maskota: maskota) { napredak.podesi { $0.uvodZavrsen = true } }
                }
            }
            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))
        }
        .background(Papir())
    }

    private var preskoci: some View {
        Button("Preskoči", action: zavrsi).font(.tekst(14, .semibold)).foregroundStyle(Color.sivaTekst)
    }

    private func idi(_ k: Korak) { withAnimation(.spring(duration: 0.4)) { korak = k } }
    private func nazad() { if let pre = Korak(rawValue: korak.rawValue - 1) { withAnimation(.spring(duration: 0.4)) { korak = pre } } }

    private func zavrsiIzbore() {
        napredak.podesi {
            $0.interesovanja = Array(interesovanja)
            $0.maskota = maskota.rawValue
            $0.cilj = cilj
            $0.podsetnik = podsetnik
        }
        Task { await napredak.zakaziPodsetnik() }
    }

    /// „Preskoči” zadržava podrazumevane izbore i odmah otvara aplikaciju.
    private func zavrsi() { zavrsiIzbore(); napredak.podesi { $0.uvodZavrsen = true } }
}

// MARK: 01 Uvodni slajdovi

private struct UvodSlajdovi: View {
    let preskoci: () -> Void
    let dalje: () -> Void
    @State private var strana = 0

    private let slajdovi: [(String, String, String, Color, Maskota)] = [
        ("Kviz o svemu,\nkad god!", "Opšte znanje, knjige, geografija i svet. Nova pitanja stižu svaki dan.", "6.700+\npitanja", .narandzasta, .bloop),
        ("Izazovi društvo\nuživo!", "Duel jedan na jedan u realnom vremenu. Vidi ko stvarno zna.", "Duel sa\ndrugarima", .ljubicasta, .zig),
        ("Skupljaj novčiće,\npenji se!", "Zaradi novčiće, otključaj bedževe i popni se na nedeljnu rang listu.", "Popni se\nna vrh", .zuta, .lumi),
    ]

    var body: some View {
        VStack(spacing: 18) {
            HStack { Spacer(); Button("Preskoči", action: preskoci).font(.tekst(14, .semibold)).foregroundStyle(Color.sivaTekst) }
                .padding(.horizontal, 20).padding(.top, 8)
            TabView(selection: $strana) {
                ForEach(slajdovi.indices, id: \.self) { i in
                    let s = slajdovi[i]
                    VStack(spacing: 20) {
                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 32, style: .continuous).fill(s.3)
                            Circle().fill(.white.opacity(0.25)).frame(width: 240).offset(x: 60, y: 140)
                            MaskotaSlika(maskota: s.4, velicina: 210).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom).padding(.bottom, 16)
                            Text(s.2).font(.naslov(26)).foregroundStyle(Color.tinta).multilineTextAlignment(.center)
                                .padding(.horizontal, 18).padding(.vertical, 10)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.tinta, lineWidth: 2.5))
                                .rotationEffect(.degrees(-4)).padding(26)
                        }
                        .frame(height: 380)
                        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).stroke(Color.mastilo, lineWidth: 3))
                        .background(RoundedRectangle(cornerRadius: 32, style: .continuous).fill(Color.senka).offset(y: 7))
                        .rotationEffect(.degrees(i == 1 ? 3 : -3))
                        .padding(.horizontal, 36)
                        .accessibilityHidden(true)
                        Naslov(tekst: s.0, velicina: 34).multilineTextAlignment(.center)
                        Text(s.1).font(.tekst(15)).foregroundStyle(Color.sivaTekst).multilineTextAlignment(.center).padding(.horizontal, 30)
                    }
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            CrticeKoraka(ukupno: 3, trenutni: strana)
            Button(strana < 2 ? "Dalje" : "Krenimo") {
                if strana < 2 { withAnimation { strana += 1 } } else { dalje() }
            }
            .buttonStyle(.primarno).padding(.horizontal, 20).padding(.bottom, 12)
        }
    }
}

// MARK: 02 Interesovanja

private struct UvodInteresovanja: View {
    @Binding var izabrano: Set<String>
    let dalje: () -> Void
    @State private var teme: Ucitano<[Tema]> = .ucitava

    struct Tema: Hashable { let naziv: String; let ikonica: String; let boja: Color }
    static let minimum = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Naslov(tekst: "Šta te\nzanima?", velicina: 36).padding(.top, 18)
            Text("Izaberi bar tri. Prema tome slažemo kvizove.").font(.tekst(15)).foregroundStyle(Color.sivaTekst)
            ScrollView {
                switch teme {
                case .ucitava:
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                        ForEach(0..<9, id: \.self) { _ in Skelet(visina: 104, radijus: 20) }
                    }
                    .padding(.vertical, 14)
                case .greska(let poruka):
                    StanjeEkrana(maskota: .lumi, naslov: "Teme nisu stigle", tekst: poruka, dugme: "Pokušaj ponovo") { Task { await ucitaj() } }
                case .gotovo(let lista):
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                        ForEach(lista, id: \.self) { t in plocica(t) }
                    }
                    .padding(.vertical, 14)
                }
            }
            HStack {
                Spacer()
                Label(poruka, systemImage: izabrano.count >= Self.minimum ? "checkmark.circle" : "sparkles")
                    .font(.tekst(14, .bold)).foregroundStyle(Color.mastilo)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.mastilo, lineWidth: 2))
                Spacer()
            }
            Button("Nastavi", action: dalje).buttonStyle(.primarno).disabled(izabrano.count < Self.minimum).padding(.bottom, 12)
        }
        .padding(.horizontal, 20)
        .task { await ucitaj() }
    }

    private var poruka: String {
        switch izabrano.count {
        case 0: "Izaberi \(Self.minimum) za nastavak"
        case 1..<Self.minimum: "Još \(Self.minimum - izabrano.count) do kraja"
        default: "\(izabrano.count) izabrano · odličan ukus!"
        }
    }

    private func plocica(_ t: Tema) -> some View {
        let da = izabrano.contains(t.naziv)
        return Button {
            if da { izabrano.remove(t.naziv) } else { izabrano.insert(t.naziv) }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: t.ikonica).font(.system(size: 24, weight: .semibold)).foregroundStyle(da ? Color.tinta : t.boja)
                Text(t.naziv).font(.tekst(13, .bold)).foregroundStyle(da ? Color.tinta : Color.mastilo)
                    .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity).frame(height: 104).padding(.horizontal, 6)
            .background(da ? Color.zuta : Color.kartica, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(da ? Color.mastilo : Color.kremTamnija, lineWidth: da ? 2.5 : 1.5))
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(da ? Color.senka : .clear).offset(y: 4))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(da ? .isSelected : [])
    }

    /// Teme su žanrovi iz stvarnog fonda Book pitanja, plus opšte znanje i geografija.
    private func ucitaj() async {
        teme = .ucitava
        do {
            // Paket se učitava da bi prvi kviz radio i bez mreže; spisak žanrova je stalan.
            _ = try await PaketPitanja.deljeni.ucitaj(.book)
            let zanrovi = KvizKatalog.zanrovi
            let boje: [Color] = [.roze, .ljubicasta, .narandzasta, .nebo, .teal, .crvena]
            teme = .gotovo([Tema(naziv: "Opšte znanje", ikonica: "lightbulb", boja: .narandzasta),
                            Tema(naziv: "Geografija", ikonica: "globe.europe.africa", boja: .nebo),
                            Tema(naziv: "Knjige", ikonica: "book", boja: .teal)]
                + zanrovi.enumerated().map { i, z in Tema(naziv: z, ikonica: KvizKatalog.ikonica(zanra: z), boja: boje[i % boje.count]) })
        } catch {
            teme = .greska("Police sa kvizovima su se zaljuljale. Proveri internet i pokušaj ponovo.")
        }
    }
}

// MARK: 03 Drugar

private struct UvodDrugar: View {
    @Binding var maskota: Maskota
    let dalje: () -> Void

    static let opisi: [(Maskota, String, String, Color)] = [
        (.mimi, "Kraljica nagoveštaja", "Pričljiva, radoznala i uvek ima trag u rukavu.", .roze),
        (.zig, "Demon brzine", "Brz, neustrašiv i voli igru na vreme. Nikad ne preskače izazov.", .ljubicasta),
        (.bloop, "Navijač", "Uvek raspoložen, nikad ne osuđuje. Slavi svaki tačan odgovor.", .nebo),
        (.lumi, "Mudrica", "Mirna i pametna. Objasni zašto je odgovor tačan.", .zuta),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Naslov(tekst: "Izaberi svog\ndrugara", velicina: 36).padding(.top, 18)
            Text("Navija za tebe i šapuće nagoveštaje.").font(.tekst(15)).foregroundStyle(Color.sivaTekst)
            TabView(selection: $maskota) {
                ForEach(Self.opisi, id: \.0) { m, uloga, opis, boja in
                    ZStack(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: 30, style: .continuous).fill(boja)
                        Circle().fill(.white.opacity(0.25)).frame(width: 220).offset(x: 40, y: -60)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        MaskotaSlika(maskota: m, velicina: 190).frame(maxWidth: .infinity, maxHeight: .infinity).offset(y: -30)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(m.rawValue).font(.naslov(34)).foregroundStyle(boja == .zuta ? Color.tinta : .white)
                            Text(opis).font(.tekst(14, .semibold)).foregroundStyle((boja == .zuta ? Color.tinta : .white).opacity(0.9))
                        }
                        .padding(20)
                        Oznaka(tekst: uloga, boja: .tinta).padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(16)
                    }
                    .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(Color.mastilo, lineWidth: 3))
                    .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Color.senka).offset(y: 6))
                    .padding(.horizontal, 30).padding(.vertical, 16)
                    .tag(m)
                    .accessibilityElement(children: .combine)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            HStack { Spacer(); CrticeKoraka(ukupno: 4, trenutni: Self.opisi.firstIndex { $0.0 == maskota } ?? 0); Spacer() }
            Button("Biram \(maskota.rawValue)", action: dalje).buttonStyle(.primarno).padding(.bottom, 12)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: 04 Dnevni cilj

private struct UvodCilj: View {
    @Binding var cilj: Int
    @Binding var podsetnik: Bool
    let dalje: () -> Void

    static let nivoi: [(Int, String, String, Color)] = [
        (1, "Opušteno", "~3 min", .nebo), (3, "Redovno", "~10 min", .teal), (5, "Ozbiljno", "~15 min", .narandzasta), (10, "Kviz zver", "~30 min", .roze),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Naslov(tekst: "Postavi dnevni\ncilj", velicina: 36).padding(.top, 18)
            Text("Mali nizovi donose velike pobede. Možeš da promeniš kad hoćeš.").font(.tekst(15)).foregroundStyle(Color.sivaTekst)
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Self.nivoi, id: \.0) { broj, naziv, trajanje, boja in
                        let da = cilj == broj
                        Button { cilj = broj } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "bolt").font(.system(size: 18, weight: .bold)).foregroundStyle(Color.tinta)
                                    .frame(width: 44, height: 44).background(boja, in: RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.tinta, lineWidth: 2))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(naziv).font(.tekst(16, .bold))
                                    Text(broj == 1 ? "1 kviz dnevno" : "\(broj) kvizova dnevno").font(.tekst(13)).opacity(0.7)
                                }
                                Spacer()
                                Text(trajanje).font(.tekst(13, da ? .bold : .medium))
                            }
                            .foregroundStyle(da ? Color.tinta : Color.mastilo)
                            .padding(14)
                            .background(da ? Color.zuta : Color.kartica, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(da ? Color.mastilo : Color.kremTamnija, lineWidth: da ? 2.5 : 1.5))
                            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(da ? Color.senka : .clear).offset(y: 4))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(da ? .isSelected : [])
                    }
                    HStack(spacing: 14) {
                        Image(systemName: podsetnik ? "bell" : "bell.slash").font(.system(size: 18, weight: .semibold)).frame(width: 44, height: 44)
                            .background(Color.udubljeno, in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Dnevni podsetnik").font(.tekst(16, .bold))
                            Text(podsetnik ? "19:30 · svaki dan" : "Isključen · nećemo te budžiti").font(.tekst(13)).foregroundStyle(Color.sivaTekst)
                        }
                        Spacer()
                        Prekidac(ukljuceno: $podsetnik, naziv: "Dnevni podsetnik")
                    }
                    .padding(14).mirna()
                }
                .padding(.vertical, 12)
            }
            Button("Nastavi", action: dalje).buttonStyle(.primarno).padding(.bottom, 12)
        }
        .padding(.horizontal, 20)
    }
}

/// Prekidač u bojama kita (teal kad je uključen).
struct Prekidac: View {
    @Binding var ukljuceno: Bool
    let naziv: String
    var body: some View {
        Button { withAnimation(.spring(duration: 0.25)) { ukljuceno.toggle() } } label: {
            ZStack(alignment: ukljuceno ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: 16).fill(ukljuceno ? Color.teal : Color.udubljeno).frame(width: 54, height: 32)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.mastilo, lineWidth: 2))
                Circle().fill(Color.white).frame(width: 22, height: 22).overlay(Circle().stroke(Color.tinta, lineWidth: 1.5)).padding(5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(naziv)
        .accessibilityValue(ukljuceno ? "Uključeno" : "Isključeno")
        .accessibilityAddTraits(.isToggle)
    }
}

// MARK: 05 Obaveštenja

private struct UvodObavestenja: View {
    let maskota: Maskota
    let dalje: () -> Void
    @State private var odbijeno = false

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            ZStack(alignment: .topTrailing) {
                MaskotaSlika(maskota: maskota, velicina: 150).frame(width: 190, height: 190)
                    .background(Color.kartica, in: Circle()).overlay(Circle().stroke(Color.mastilo, lineWidth: 3))
                Image(systemName: odbijeno ? "bell.slash" : "bell").font(.system(size: 22, weight: .bold)).foregroundStyle(Color.tinta)
                    .frame(width: 56, height: 56).background(Color.zuta, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.tinta, lineWidth: 2.5)).rotationEffect(.degrees(12)).offset(x: 14, y: -6)
            }
            Naslov(tekst: odbijeno ? "Bez obaveštenja,\nbez problema" : "Ne propusti\nnijedan duel!", velicina: 32).multilineTextAlignment(.center)
            Text(odbijeno ? "Obaveštenja možeš da uključiš kad hoćeš u Podešavanjima. Tvom nizu ćeš nedostajati." :
                    "Javimo ti kad te drug izazove, kad je niz u opasnosti ili stigne novi kviz.")
                .font(.tekst(15)).foregroundStyle(Color.sivaTekst).multilineTextAlignment(.center).padding(.horizontal, 10)
            if !odbijeno {
                HStack(spacing: 12) {
                    Image(systemName: "questionmark").font(.system(size: 16, weight: .black)).foregroundStyle(.white)
                        .frame(width: 38, height: 38).background(Color.roze, in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        Oznaka(tekst: "Librum kviz")
                        Text("Ana te izaziva na duel iz geografije!").font(.tekst(14, .bold))
                    }
                    Spacer()
                    Text("sada").font(.tekst(12)).foregroundStyle(Color.sivaTekst)
                }
                .padding(12).pop(radijus: 18).padding(.top, 8)
                .accessibilityLabel("Primer obaveštenja")
            }
            Spacer()
            if odbijeno {
                Button("Nastavi", action: dalje).buttonStyle(.primarno)
            } else {
                Button("Uključi obaveštenja") { Task { await trazi() } }.buttonStyle(.primarno)
                Button("Možda kasnije") { withAnimation { odbijeno = true } }.buttonStyle(.sekundarno)
            }
        }
        .padding(.horizontal, 20).padding(.bottom, 12)
    }

    private func trazi() async {
        let dozvoljeno = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        if dozvoljeno { dalje() } else { withAnimation { odbijeno = true } }
    }
}

// MARK: 06 Zagrevanje

private struct UvodZagrevanje: View {
    let maskota: Maskota
    let dalje: () -> Void

    static let pitanja: [(String, [String], Int, String)] = [
        ("Koja planeta se zove Crvena planeta?", ["Venera", "Mars", "Jupiter", "Merkur"], 1, "Mars je crven zbog gvožđe-oksida, odnosno rđe na površini."),
        ("Ko je napisao roman „Na Drini ćuprija”?", ["Meša Selimović", "Miloš Crnjanski", "Ivo Andrić", "Branko Ćopić"], 2, "Ivo Andrić je 1961. dobio Nobelovu nagradu za književnost."),
        ("Koji je glavni grad Australije?", ["Sidnej", "Melburn", "Pert", "Kanbera"], 3, "Kanbera je građena kao kompromis između Sidneja i Melburna."),
    ]
    static let sekundi = 12

    @State private var redni = 0
    @State private var izabran: Int?
    @State private var isteklo = false
    @State private var sklonjeni: Set<Int> = []
    @State private var nagovestaj = false
    @State private var pocetak = Date()
    @State private var zamrznuto: Date?

    private var p: (String, [String], Int, String) { Self.pitanja[redni] }
    private var otkriveno: Bool { izabran != nil || isteklo }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Naslov(tekst: "Kratko zagrevanje", velicina: 32).padding(.top, 18)
            Text("Tapni odgovor pre nego što istekne vreme.").font(.tekst(15)).foregroundStyle(Color.sivaTekst)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Pitanje \(redni + 1) od 3").font(.tekst(12, .bold)).foregroundStyle(Color.tinta)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.tinta, lineWidth: 1.5))
                    Spacer()
                    TimelineView(.periodic(from: .now, by: 0.25)) { k in
                        let ostalo = max(0, Self.sekundi - Int((zamrznuto ?? k.date).timeIntervalSince(pocetak)))
                        Label(String(format: "0:%02d", ostalo), systemImage: "timer").font(.tekst(13, .bold)).monospacedDigit()
                            .foregroundStyle(.white).padding(.horizontal, 10).padding(.vertical, 5)
                            .background(ostalo <= 3 || isteklo ? Color.crvena : Color.tinta, in: RoundedRectangle(cornerRadius: 9))
                            .onChange(of: ostalo) { _, o in if o == 0 && !otkriveno { zamrznuto = Date(); withAnimation { isteklo = true } } }
                    }
                }
                Text(p.0).font(.naslov(21)).foregroundStyle(Color.tinta).fixedSize(horizontal: false, vertical: true)
                if nagovestaj && !otkriveno {
                    Label("Dva netačna odgovora su sklonjena", systemImage: "lightbulb").font(.tekst(13, .bold)).foregroundStyle(Color.tinta)
                        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.tinta, lineWidth: 2))
                }
                ForEach(p.1.indices, id: \.self) { i in
                    OdgovorDugme(slovo: ["A", "B", "C", "D"][i], tekst: p.1[i], stanje: stanje(i)) { odgovori(i) }
                        .disabled(otkriveno || sklonjeni.contains(i))
                        .opacity(sklonjeni.contains(i) && !otkriveno ? 0.3 : 1)
                }
            }
            .padding(16)
            .pop(pozadina)
            .animation(.easeInOut(duration: 0.25), value: otkriveno)
            Spacer(minLength: 0)
            if otkriveno {
                MaskotaKaze(maskota: maskota, tekst: komentar)
                Button(redni < 2 ? "Sledeće pitanje" : "Završi zagrevanje") { sledece() }.buttonStyle(.primarno)
            } else {
                MaskotaKaze(maskota: maskota, tekst: nagovestaj ? "Dva netačna su sklonjena. Ostala su dva, biraj pametno." :
                                "Zapelo? Tapni sijalicu za nagoveštaj. Inače košta 20 novčića, sada je besplatno.")
                Button { withAnimation { iskoristiNagovestaj() } } label: { Image(systemName: "lightbulb") }
                    .buttonStyle(.zuto).disabled(nagovestaj).accessibilityLabel("Nagoveštaj")
            }
        }
        .padding(.horizontal, 20).padding(.bottom, 12)
        .sensoryFeedback(trigger: otkriveno) { _, novo in novo ? (izabran == p.2 ? .success : .error) : nil }
    }

    private var pozadina: Color {
        guard otkriveno else { return .zuta }
        if isteklo && izabran == nil { return Color(hex: 0xFFE7C2) }
        return izabran == p.2 ? Color(hex: 0xBFE8D5) : Color(hex: 0xFFC6D6)
    }

    private var komentar: String {
        if isteklo && izabran == nil { return "Bez brige, sat pobedi svakoga ponekad. Tačno je: \(p.1[p.2]). \(p.3)" }
        return izabran == p.2 ? "Bravo! \(p.3)" : "Blizu! Tačno je \(p.1[p.2]). \(p.3)"
    }

    private func stanje(_ i: Int) -> OdgovorDugme.Stanje {
        guard otkriveno else { return .obicno }
        if i == p.2 { return .tacno }
        return i == izabran ? .netacno : .bledo
    }

    private func odgovori(_ i: Int) { zamrznuto = Date(); withAnimation { izabran = i } }

    private func iskoristiNagovestaj() {
        nagovestaj = true
        sklonjeni = Set(p.1.indices.filter { $0 != p.2 }.shuffled().prefix(2))
    }

    private func sledece() {
        guard redni < 2 else { dalje(); return }
        withAnimation {
            redni += 1; izabran = nil; isteklo = false; sklonjeni = []; nagovestaj = false; pocetak = Date(); zamrznuto = nil
        }
    }
}

// MARK: 07 Priprema i kraj

private struct UvodPriprema: View {
    let interesovanja: [String]
    let gotovo: () -> Void
    @State private var korak = 0

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            MaskotaSlika(maskota: .mimi, velicina: 150).frame(width: 190, height: 190).background(Color.roze, in: Circle())
                .rotationEffect(.degrees(korak % 2 == 0 ? -4 : 4)).animation(.easeInOut(duration: 0.6), value: korak)
            Naslov(tekst: "Slažemo tvoje\nkvizove…", velicina: 32).multilineTextAlignment(.center)
            Text(interesovanja.isEmpty ? "Mešamo sve teme za tebe." : "Mešamo \(interesovanja.prefix(3).joined(separator: ", ")) samo za tebe.")
                .font(.tekst(15)).foregroundStyle(Color.sivaTekst).multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 12) {
                stavka("Biramo tvoje teme", 0)
                stavka("Pogađamo tvoj nivo", 1)
                stavka("Slažemo današnje kvizove", 2)
            }
            .padding(.top, 10)
            Spacer()
        }
        .padding(.horizontal, 30)
        .task {
            for i in 1...3 { try? await Task.sleep(for: .milliseconds(700)); withAnimation { korak = i } }
            try? await Task.sleep(for: .milliseconds(400))
            gotovo()
        }
        .accessibilityElement(children: .combine)
    }

    private func stavka(_ tekst: String, _ i: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: korak > i ? "checkmark.circle.fill" : korak == i ? "circle.dotted" : "circle")
                .font(.system(size: 20)).foregroundStyle(korak > i ? Color.teal : korak == i ? Color.roze : Color.kremTamnija)
            Text(tekst).font(.tekst(15, korak == i ? .bold : .medium)).foregroundStyle(korak >= i ? Color.mastilo : .sivaTekst)
        }
    }
}

private struct UvodGotovo: View {
    @Environment(Napredak.self) private var napredak
    let maskota: Maskota
    let kreni: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                ForEach(0..<12, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 6).fill(Color.roze.opacity(0.35)).frame(width: 22, height: 160)
                        .offset(y: -110).rotationEffect(.degrees(Double(i) * 30))
                }
                MaskotaSlika(maskota: maskota, velicina: 140).frame(width: 170, height: 170)
                    .background(Color.narandzasta, in: Circle()).overlay(Circle().stroke(Color.mastilo, lineWidth: 3))
            }
            .frame(height: 280)
            .accessibilityHidden(true)
            Oznaka(tekst: "Bedž otključan", boja: .roze)
            Naslov(tekst: "Spreman si,\nnovajlijo!", velicina: 36).multilineTextAlignment(.center)
            Text("Prvi poklon je tu: \(napredak.s.novcici) novčića za pomoći. \(napredak.s.cilj) kviza dnevno čuvaju niz.")
                .font(.tekst(15)).foregroundStyle(Color.sivaTekst).multilineTextAlignment(.center)
            HStack(spacing: 10) {
                Label("\(napredak.s.novcici) novčića", systemImage: "dollarsign.circle")
                Label("Dan 1 niza", systemImage: "flame")
            }
            .font(.tekst(13, .bold))
            Spacer()
            Button("Igraj prvi kviz", action: kreni).buttonStyle(.primarno)
        }
        .padding(.horizontal, 20).padding(.bottom, 12)
    }
}
