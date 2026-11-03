import SwiftUI

// MARK: 01 Profil

/// Profil iz kita: avatar, nivo i XP, tri broja, statistika, pomoći, bedževi, sanduče.
/// Stanja: gost (bez naloga), učitavanje nadimka.
struct ProfilView: View {
    @Environment(Sesija.self) private var sesija
    @Environment(Napredak.self) private var napredak
    @State private var prijava = false
    @State private var serverski: ProfilIgracaView.Profil?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    ShareLink(item: "Igram Librum kviz, nivo \(napredak.nivo), niz \(napredak.s.nizDana) dana. https://kviz.librum.club") {
                        krug("square.and.arrow.up")
                    }
                    .accessibilityLabel("Podeli profil")
                    Spacer()
                    NavigationLink { SanduceView() } label: {
                        krug("tray").overlay(alignment: .topTrailing) {
                            if napredak.neprocitanih > 0 { Circle().fill(Color.roze).frame(width: 12, height: 12).overlay(Circle().stroke(Color.krem, lineWidth: 2)) }
                        }
                    }
                    .accessibilityLabel("Sanduče, \(napredak.neprocitanih) novih")
                    NavigationLink { PodesavanjaView() } label: { krug("gearshape") }.accessibilityLabel("Podešavanja")
                }
                if sesija.prijavljen, let p = serverski {
                    // Moj profil izgleda kao što ga vide drugi (Instagram, Librum eBook), plus Uredi profil.
                    ProfilZaglavlje(profil: p, nivo: napredak.nivo) {
                        HStack(spacing: 10) {
                            NavigationLink { IzmenaProfilaView() } label: { Text("Uredi profil") }.buttonStyle(.sekundarno)
                            ShareLink(item: "Igram Librum kviz: \(p.nadimak), nivo \(napredak.nivo). Zaprati me: librumkviz://igrac/\(sesija.korisnikId ?? "")") {
                                Image(systemName: "square.and.arrow.up").font(.system(size: 17, weight: .bold)).foregroundStyle(Color.mastilo)
                                    .frame(width: 54, height: 54).background(Color.kartica, in: RoundedRectangle(cornerRadius: 16))
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.mastilo, lineWidth: 2))
                            }
                            .accessibilityLabel("Podeli profil")
                        }
                        // Samo na mom profilu: predlog pitanja ili reči za vešanje.
                        HStack(spacing: 10) {
                            NavigationLink { DodajPitanjeView() } label: { Label("Dodaj pitanje", systemImage: "plus.bubble") }.buttonStyle(.sekundarno)
                            NavigationLink { DodajPitanjeView(pocetnaVrsta: .vesanje) } label: { Label("Dodaj reč", systemImage: "textformat.abc") }.buttonStyle(.sekundarno)
                        }
                    }
                    nivo
                    ProfilStatistike(profil: p)
                } else {
                glava
                nivo
                HStack(spacing: 10) {
                    Plocica(ikonica: "gamecontroller", vrednost: "\(napredak.s.igara)", naziv: "Kvizova")
                    Plocica(ikonica: "checkmark.circle", vrednost: tacnost, naziv: "Tačnost", boja: .roze)
                    Plocica(ikonica: "flame", vrednost: "\(napredak.s.najduziNiz)", naziv: "Najduži niz", boja: .narandzasta)
                }
                if sesija.prijavljen {
                    Skelet(visina: 160)
                } else {
                    if let b = napredak.prosecnaBrzina {
                        Label(String(format: "Prosečno %.1f s po odgovoru · pomoć u %d od %d partija", b, napredak.s.partijaSaPomoci, napredak.s.igara), systemImage: "bolt")
                            .font(.tekst(13, .semibold)).foregroundStyle(Color.sivaTekst).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    PomocUpotreba(poVrsti: napredak.s.pomociPoVrsti)
                }
                }
                NavigationLink { BedzeviView() } label: { bedzevi }.buttonStyle(.plain)
                VStack(spacing: 0) {
                    RedListe(ikonica: "lifepreserver", naziv: "Pomoć danas", vrednost: "\(napredak.pomociOstalo()) od \(Napredak.pomociDnevno)", strelica: false)
                    Divider().overlay(Color.kremTamnija)
                    NavigationLink { IgraciView() } label: { RedListe(ikonica: "person.2", naziv: "Igrači i praćenje") }
                    Divider().overlay(Color.kremTamnija)
                    NavigationLink { StatistikaView() } label: { RedListe(ikonica: "chart.bar", naziv: "Statistika") }
                    Divider().overlay(Color.kremTamnija)
                    NavigationLink { PravilaIgaraView() } label: { RedListe(ikonica: "book.pages", naziv: "Pravila igara") }
                    Divider().overlay(Color.kremTamnija)
                    NavigationLink { SanduceView() } label: { RedListe(ikonica: "tray", naziv: "Sanduče", vrednost: napredak.neprocitanih > 0 ? "\(napredak.neprocitanih) novo" : nil) }
                }
                .mirna()
                if !sesija.prijavljen {
                    NavigationLink { IzmenaProfilaView() } label: { Text("Izaberi avatar") }.buttonStyle(.sekundarno)
                    Button("Napravi nalog ili se prijavi") { prijava = true }.buttonStyle(.primarno)
                }
            }
            .padding(16)
        }
        .background(Papir())
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $prijava) { PrijavaTok() }
        .task(id: sesija.korisnikId) {
            guard let id = sesija.korisnikId else { serverski = nil; return }
            serverski = try? await Supabase.deljeni.rpc("profil_igraca", ["p_id": id], token: try? await sesija.vazeciToken())
        }
    }

    private var tacnost: String {
        let ukupno = napredak.s.tacnih + napredak.s.netacnih
        return ukupno == 0 ? "–" : "\(napredak.s.tacnih * 100 / ukupno)%"
    }

    private func krug(_ ikonica: String) -> some View {
        Image(systemName: ikonica).font(.system(size: 17, weight: .bold)).foregroundStyle(Color.mastilo)
            .frame(width: 44, height: 44).background(Color.kartica, in: Circle()).overlay(Circle().stroke(Color.kremTamnija, lineWidth: 1.5))
    }

    private var glava: some View {
        let m = Maskota(rawValue: napredak.s.maskota) ?? .mimi
        return VStack(spacing: 6) {
            AvatarSlika(avatar: sesija.avatar ?? napredak.s.avatar, velicina: 120, maskota: m)
                .overlay(alignment: .bottom) {
                    Text("NV \(napredak.nivo)").font(.tekst(12, .bold)).foregroundStyle(Color.naMastilu).padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.mastilo, in: RoundedRectangle(cornerRadius: 9)).offset(y: 10)
                }
            Group {
                if sesija.prijavljen && sesija.nadimak == nil {
                    Skelet(visina: 30, radijus: 8).frame(width: 160)
                } else {
                    Text(sesija.prijavljen ? sesija.nadimak ?? "Igrač" : "Gost").font(.naslov(30))
                }
            }
            .padding(.top, 10)
            Text(sesija.prijavljen ? (sesija.email ?? "") : "Napredak se čuva samo na ovom telefonu").font(.tekst(13)).foregroundStyle(Color.sivaTekst)
        }
    }

    private var nivo: some View {
        let x = napredak.xpUNivou
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Nivo \(napredak.nivo) → \(napredak.nivo + 1)").font(.tekst(15, .bold))
                Spacer()
                Text("\(x.imam.formatted()) / \(x.treba.formatted()) XP").font(.tekst(13, .semibold)).monospacedDigit()
            }
            GeometryReader { g in
                RoundedRectangle(cornerRadius: 6).fill(Color.white).overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.tinta, lineWidth: 2))
                    .overlay(alignment: .leading) { RoundedRectangle(cornerRadius: 6).fill(Color.teal).frame(width: max(8, g.size.width * Double(x.imam) / Double(x.treba))) }
            }
            .frame(height: 14)
        }
        .foregroundStyle(Color.tinta).padding(16).pop(.zuta, radijus: 20)
        .accessibilityElement(children: .combine)
    }

    private var bedzevi: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Bedževi").font(.naslov(22))
                Spacer()
                Text("\(napredak.s.bedzevi.count) / \(Napredak.sviBedzevi.count) · Svi").font(.tekst(13, .semibold)).foregroundStyle(Color.sivaTekst)
            }
            HStack(spacing: 10) {
                ForEach(Napredak.sviBedzevi.prefix(5)) { b in BedzKrug(bedz: b, otkljucan: napredak.s.bedzevi[b.id] != nil, velicina: 52) }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12).mirna()
        }
    }
}

struct BedzKrug: View {
    let bedz: Bedz
    let otkljucan: Bool
    var velicina: CGFloat = 64
    var body: some View {
        Image(systemName: otkljucan ? bedz.ikonica : "lock.fill").font(.system(size: velicina * 0.38, weight: .semibold))
            .foregroundStyle(otkljucan ? Color.tinta : Color.sivaTekst)
            .frame(width: velicina, height: velicina)
            .background(otkljucan ? Color(hex: bedz.boja) : Color.udubljeno, in: Circle())
            .overlay(Circle().stroke(otkljucan ? Color.mastilo : Color.kremTamnija, lineWidth: 2.5))
            .accessibilityLabel("\(bedz.naziv), \(otkljucan ? "otključan" : "zaključan")")
    }
}

// MARK: 02 Statistika

struct StatistikaView: View {
    @Environment(Napredak.self) private var napredak
    enum Period: Hashable { case nedelja, mesec, sveVreme }
    @State private var period: Period = .nedelja
    static let minimumKvizova = 3

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GornjaTraka()
                Naslov(tekst: "Tvoja statistika", velicina: 34)
                PodvuceniIzbor(izbor: $period, opcije: [(.nedelja, "Nedelja"), (.mesec, "Mesec"), (.sveVreme, "Sve vreme")])
                let od: Date? = switch period {
                case .nedelja: Date().addingTimeInterval(-6 * 86_400)
                case .mesec: Date().addingTimeInterval(-29 * 86_400)
                case .sveVreme: nil
                }
                if let t = napredak.tacnost(od: od), t.igara >= Self.minimumKvizova {
                    grafikon(t.tacnost)
                } else {
                    StanjeEkrana(maskota: .zig, naslov: "Još nema statistike", tekst: "Odigraj bar \(Self.minimumKvizova) kviza u ovom periodu da se pojave grafikoni.")
                        .padding(.horizontal, 12).pop(radijus: 24)
                }
                Text("Po temama").font(.naslov(22)).padding(.top, 6)
                if napredak.s.kategorije.isEmpty {
                    ForEach(KvizKatalog.kategorije.prefix(4), id: \.naziv) { k in tema(k.naziv, k.ikonica, k.boja, nil) }
                } else {
                    ForEach(napredak.s.kategorije.sorted { $0.value[1] > $1.value[1] }, id: \.key) { naziv, v in
                        let k = KvizKatalog.kategorije.first { naziv.hasPrefix($0.naziv) }
                        tema(naziv, k?.ikonica ?? "book", k?.boja ?? 0x12907E, v[1] > 0 ? Double(v[0]) / Double(v[1]) : nil)
                    }
                }
            }
            .padding(16)
        }
        .background(Papir())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }

    private func grafikon(_ tacnost: Double) -> some View {
        let dani = napredak.tacnostPoDanima(7)
        let f = DateFormatter(); f.locale = Locale(identifier: "sr_Latn"); f.dateFormat = "EEEEE"
        return VStack(alignment: .leading, spacing: 12) {
            Oznaka(tekst: "Tačnost", boja: .white)
            Text("\(Int(tacnost * 100))%").font(.naslov(46)).foregroundStyle(.white)
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(dani.enumerated()), id: \.offset) { i, d in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 8).fill(i == dani.count - 1 ? Color.zuta : Color(hex: 0xDFF3EE))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.tinta, lineWidth: 2))
                            .frame(height: max(10, 110 * (d.tacnost ?? 0)))
                            .opacity(d.tacnost == nil ? 0.35 : 1)
                        Text(f.string(from: d.dan).uppercased()).font(.tekst(11, .bold)).foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 140, alignment: .bottom)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Tačnost po danima: " + dani.map { $0.tacnost.map { "\(Int($0 * 100))%" } ?? "nije igrano" }.joined(separator: ", "))
        }
        .padding(18).pop(.teal, radijus: 24)
    }

    private func tema(_ naziv: String, _ ikonica: String, _ boja: UInt32, _ deo: Double?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: ikonica).font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.tinta)
                .frame(width: 40, height: 40).background(Color(hex: boja), in: Circle()).overlay(Circle().stroke(Color.mastilo, lineWidth: 2))
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(naziv).font(.tekst(15, .bold))
                    Spacer()
                    Text(deo.map { "\(Int($0 * 100))%" } ?? "–").font(.tekst(14, .bold)).monospacedDigit()
                }
                GeometryReader { g in
                    RoundedRectangle(cornerRadius: 4).fill(Color.udubljeno)
                        .overlay(alignment: .leading) { RoundedRectangle(cornerRadius: 4).fill(Color(hex: boja)).frame(width: g.size.width * (deo ?? 0)) }
                }
                .frame(height: 8)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: 03 Bedževi

struct BedzeviView: View {
    @Environment(Napredak.self) private var napredak
    @State private var detalj: Bedz?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                GornjaTraka()
                Naslov(tekst: "Bedževi", velicina: 36)
                Text("\(napredak.s.bedzevi.count) od \(Napredak.sviBedzevi.count) otključano").font(.tekst(14, .semibold)).foregroundStyle(Color.sivaTekst)
                GeometryReader { g in
                    RoundedRectangle(cornerRadius: 5).fill(Color.kartica).overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.mastilo, lineWidth: 1.5))
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 5).fill(Color.roze).frame(width: g.size.width * Double(napredak.s.bedzevi.count) / Double(Napredak.sviBedzevi.count))
                        }
                }
                .frame(height: 10)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(Napredak.sviBedzevi) { b in
                        let otkljucan = napredak.s.bedzevi[b.id] != nil
                        Button { detalj = b } label: {
                            VStack(spacing: 8) {
                                BedzKrug(bedz: b, otkljucan: otkljucan)
                                Text(b.naziv).font(.tekst(13, .bold)).foregroundStyle(otkljucan ? Color.mastilo : .sivaTekst).lineLimit(1).minimumScaleFactor(0.8)
                                Text(otkljucan ? "Otključan" : b.opis).font(.tekst(11)).foregroundStyle(Color.sivaTekst).lineLimit(2).multilineTextAlignment(.center)
                            }
                            .padding(10).frame(maxWidth: .infinity).frame(height: 160)
                            .background(otkljucan ? Color.kartica : Color.kartica.opacity(0.5), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(otkljucan ? Color.mastilo : Color.kremTamnija, lineWidth: otkljucan ? 2.5 : 1.5))
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
        .overlay {
            if let b = detalj {
                if napredak.s.bedzevi[b.id] != nil {
                    BedzOtkljucanView(bedz: b, datum: napredak.s.bedzevi[b.id]) { withAnimation { detalj = nil } }
                } else {
                    DonjiList(zatvori: { detalj = nil }) {
                        BedzKrug(bedz: b, otkljucan: false, velicina: 90)
                        Naslov(tekst: b.naziv, velicina: 28)
                        Text(b.opis).font(.tekst(15)).foregroundStyle(Color.sivaTekst).multilineTextAlignment(.center)
                        Button("Važi") { detalj = nil }.buttonStyle(.primarno)
                    }
                }
            }
        }
    }
}

/// Otključan bedž (Badges · Unlocked!): ljubičasta kartica sa konfetama.
struct BedzOtkljucanView: View {
    let bedz: Bedz
    var datum: Date? = nil
    let zatvori: () -> Void

    var body: some View {
        ZStack {
            Color.senka.opacity(0.6).ignoresSafeArea().onTapGesture(perform: zatvori)
            VStack(spacing: 12) {
                BedzKrug(bedz: bedz, otkljucan: true, velicina: 96)
                Oznaka(tekst: datum == nil ? "Novi bedž" : "Otključan \(datum!.formatted(date: .abbreviated, time: .omitted))", boja: .tinta)
                    .padding(.horizontal, 10).padding(.vertical, 5).background(Color.zuta, in: RoundedRectangle(cornerRadius: 8))
                Text(bedz.naziv).font(.naslov(34)).foregroundStyle(.white)
                Text(bedz.opis).font(.tekst(15, .semibold)).foregroundStyle(.white.opacity(0.9)).multilineTextAlignment(.center)
                Button("Super!", action: zatvori).buttonStyle(.sekundarno).padding(.top, 6)
            }
            .padding(24).frame(maxWidth: .infinity)
            .background(Konfete())
            .pop(.ljubicasta, radijus: 30).padding(24)
            .accessibilityAddTraits(.isModal)
        }
        .sensoryFeedback(.success, trigger: bedz.id)
        .onAppear { if datum == nil { Zvuk.pusti(.bedz, jacina: 0.5) } }
    }
}

// MARK: 05 Sanduče

struct SanduceView: View {
    @Environment(Napredak.self) private var napredak
    enum Filter: Hashable { case sve, izazovi, bedzevi }
    @State private var filter: Filter = .sve
    @State private var ucitava = true

    private var poruke: [Napredak.Poruka] {
        napredak.s.poruke.filter {
            switch filter {
            case .sve: true
            case .izazovi: $0.vrsta == .izazov
            case .bedzevi: $0.vrsta == .bedz
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GornjaTraka {
                Button { napredak.procitajSve() } label: {
                    Image(systemName: "checkmark.circle").font(.system(size: 17, weight: .bold)).foregroundStyle(Color.mastilo)
                        .frame(width: 44, height: 44).background(Color.kartica, in: Circle()).overlay(Circle().stroke(Color.kremTamnija, lineWidth: 1.5))
                }
                .disabled(napredak.neprocitanih == 0).opacity(napredak.neprocitanih == 0 ? 0.4 : 1)
                .accessibilityLabel("Označi sve kao pročitano")
            }
            Naslov(tekst: "Sanduče", velicina: 36)
            let sve = napredak.s.poruke
            PodvuceniIzbor(izbor: $filter, opcije: [(.sve, "Sve · \(sve.count)"), (.izazovi, "Izazovi · \(sve.filter { $0.vrsta == .izazov }.count)"),
                                                    (.bedzevi, "Bedževi · \(sve.filter { $0.vrsta == .bedz }.count)")])
            ScrollView {
                VStack(spacing: 10) {
                    if filter != .bedzevi { DolazniIzazovi() }
                    if filter == .sve { ServerskaObavestenja() }
                    if ucitava {
                        ForEach(0..<4, id: \.self) { _ in Skelet(visina: 84, radijus: 20) }
                    } else if poruke.isEmpty {
                        StanjeEkrana(maskota: .lumi, naslov: "Sve je pročitano!", tekst: "Nema novih izazova ni bedževa. Javićemo kad se nešto zabavno desi.")
                    } else {
                        ForEach(poruke) { p in poruka(p) }
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .padding(.horizontal, 16)
        .background(Papir())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task { try? await Task.sleep(for: .milliseconds(250)); ucitava = false }
    }

    private func poruka(_ p: Napredak.Poruka) -> some View {
        let (ikonica, boja): (String, Color) = switch p.vrsta {
        case .pratilac: ("person.badge.plus", .zuta)
        case .bedz: ("medal", .ljubicasta)
        case .izazov: ("person.2", .roze)
        case .rezultat: ("trophy", .teal)
        }
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: ikonica).font(.system(size: 18, weight: .semibold)).foregroundStyle(boja == .zuta ? Color.tinta : .white)
                .frame(width: 44, height: 44).background(boja, in: Circle()).overlay(Circle().stroke(Color.mastilo, lineWidth: 2))
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    Text(p.naslov).font(.tekst(15, .bold))
                    Spacer()
                    Text(p.vreme.formatted(.relative(presentation: .numeric))).font(.tekst(11)).foregroundStyle(Color.sivaTekst)
                }
                Text(p.tekst).font(.tekst(13)).foregroundStyle(Color.sivaTekst)
            }
            if !p.procitano { Circle().fill(Color.roze).frame(width: 10, height: 10).accessibilityLabel("Novo") }
        }
        .padding(14)
        .background(Color.kartica, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(p.procitano ? Color.kremTamnija : Color.mastilo, lineWidth: p.procitano ? 1.5 : 2.5))
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Obriši") { napredak.obrisiPoruku(p.id) }
    }
}

// MARK: 06 Podešavanja

struct PodesavanjaView: View {
    @Environment(Sesija.self) private var sesija
    @Environment(Napredak.self) private var napredak
    @AppStorage("tema") private var tema = "sistem"
    @State private var odjava = false
    @State private var brisanje = false
    @State private var prijava = false
    @State private var greska: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                GornjaTraka()
                Naslov(tekst: "Podešavanja", velicina: 36)
                Oznaka(tekst: "Nalog").padding(.top, 6)
                VStack(spacing: 0) {
                    if sesija.prijavljen {
                        NavigationLink { IzmenaProfilaView() } label: { RedListe(ikonica: "person", naziv: "Izmeni profil") }
                        Divider().overlay(Color.kremTamnija)
                        RedListe(ikonica: "envelope", naziv: "Email", vrednost: sesija.email, strelica: false)
                        Divider().overlay(Color.kremTamnija)
                        Button { prijava = true } label: { RedListe(ikonica: "lock", naziv: "Lozinka", vrednost: "Promeni") }.buttonStyle(.plain)
                    } else {
                        Button { prijava = true } label: { RedListe(ikonica: "person.badge.plus", naziv: "Prijava ili nov nalog") }.buttonStyle(.plain)
                    }
                }
                .mirna()
                Oznaka(tekst: "Igra").padding(.top, 8)
                VStack(spacing: 0) {
                    prekidac("speaker.wave.2", "Zvučni efekti", \.zvuk)
                    Divider().overlay(Color.kremTamnija)
                    prekidac("bell", "Dnevni podsetnik u 19:30", \.podsetnik)
                    Divider().overlay(Color.kremTamnija)
                    HStack(spacing: 14) {
                        Image(systemName: "circle.lefthalf.filled").font(.system(size: 17, weight: .semibold)).frame(width: 24)
                        Text("Izgled").font(.tekst(15, .semibold))
                        Spacer()
                        PodvuceniIzbor(izbor: $tema, opcije: [("sistem", "Auto"), ("svetla", "Svetla"), ("tamna", "Tamna")]).fixedSize()
                    }
                    .padding(.horizontal, 16).frame(minHeight: 54)
                }
                .mirna()
                Oznaka(tekst: "Podrška").padding(.top, 8)
                VStack(spacing: 0) {
                    Link(destination: URL(string: "mailto:podrska@librum.rs?subject=Librum%20kviz")!) { RedListe(ikonica: "bubble.left", naziv: "Pomoć i utisci") }
                    Divider().overlay(Color.kremTamnija)
                    NavigationLink { DodajPitanjeView() } label: { RedListe(ikonica: "plus.bubble", naziv: "Pošalji pitanje") }
                    if sesija.prijavljen {
                        Divider().overlay(Color.kremTamnija)
                        NavigationLink { BlokiraniView() } label: { RedListe(ikonica: "hand.raised.slash", naziv: "Blokirani igrači") }
                    }
                    Divider().overlay(Color.kremTamnija)
                    NavigationLink { PravilaIgaraView() } label: { RedListe(ikonica: "book.pages", naziv: "Pravila igara") }
                    Divider().overlay(Color.kremTamnija)
                    NavigationLink { PravniTekstView(vrsta: .privatnost) } label: { RedListe(ikonica: "hand.raised", naziv: "Politika privatnosti") }
                    Divider().overlay(Color.kremTamnija)
                    NavigationLink { PravniTekstView(vrsta: .uslovi) } label: { RedListe(ikonica: "doc.text", naziv: "Uslovi korišćenja") }
                }
                .mirna()
                if let greska { Text(greska).font(.tekst(14, .semibold)).foregroundStyle(Color.crvena) }
                if sesija.prijavljen {
                    Button { odjava = true } label: { RedListe(ikonica: "rectangle.portrait.and.arrow.right", naziv: "Odjavi se", boja: .crvena) }
                        .buttonStyle(.plain).mirna().padding(.top, 8)
                }
                HStack(spacing: 4) {
                    Text("Librum kviz \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                    if sesija.prijavljen { Text("·"); Button("Obriši nalog") { brisanje = true }.foregroundStyle(Color.crvena) }
                }
                .font(.tekst(12)).foregroundStyle(Color.sivaTekst).frame(maxWidth: .infinity).padding(.top, 10)
            }
            .padding(16)
        }
        .background(Papir())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .fullScreenCover(isPresented: $prijava) { PrijavaTok(pocetak: sesija.prijavljen ? .zaboravljena : nil) }
        .overlay {
            if odjava {
                Dijalog(naslov: "Odjaviti se?", tekst: "Niz i napredak ostaju na ovom telefonu. Prijavi se ponovo kad hoćeš.",
                        potvrda: "Odjavi se", odustani: "Ostani") { odjava = false; Task { await sesija.odjava() } } zatvori: { odjava = false }
            }
            if brisanje {
                Dijalog(naslov: "Obrisati nalog?", tekst: "Nalog, profil i svi rezultati na serveru se trajno brišu, zajedno sa napretkom na ovom telefonu. Ovo ne može da se vrati.",
                        potvrda: "Obriši zauvek", odustani: "Odustani", opasno: true) {
                    brisanje = false
                    Task {
                        do { try await sesija.obrisiNalog(); napredak.resetuj() } catch { greska = error.localizedDescription }
                    }
                } zatvori: { brisanje = false }
            }
        }
    }

    private func prekidac(_ ikonica: String, _ naziv: String, _ kljuc: WritableKeyPath<Napredak.Stanje, Bool>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: ikonica).font(.system(size: 17, weight: .semibold)).frame(width: 24)
            Text(naziv).font(.tekst(15, .semibold))
            Spacer()
            Prekidac(ukljuceno: Binding(get: { napredak.s[keyPath: kljuc] }, set: { v in
                napredak.podesi { $0[keyPath: kljuc] = v }
                if kljuc == \.podsetnik { Task { await napredak.zakaziPodsetnik() } }
            }), naziv: naziv)
        }
        .padding(.horizontal, 16).frame(minHeight: 58)
    }
}

// MARK: 07 Izmena profila

struct IzmenaProfilaView: View {
    @Environment(\.dismiss) private var nazad
    @Environment(Sesija.self) private var sesija
    @Environment(Napredak.self) private var napredak
    enum Stanje: Equatable { case unos, cuva, zauzet, sacuvano, greska(String) }
    @State private var nadimak = ""
    @State private var maskota: Maskota = .mimi
    @State private var avatar: String?
    @State private var stanje: Stanje = .unos
    @State private var odbaci = false
    @State private var sviAvatari = false
    @State private var licni = Sesija.LicniPodaci()
    @State private var licniPocetni = Sesija.LicniPodaci()
    private static let bioNajvise = 160

    private var trenutniAvatar: String? { sesija.avatar ?? napredak.s.avatar }
    private var izmenjeno: Bool {
        (sesija.prijavljen && nadimak != (sesija.nadimak ?? "")) || maskota.rawValue != napredak.s.maskota || avatar != trenutniAvatar || licni != licniPocetni
    }
    private func polje(_ k: WritableKeyPath<Sesija.LicniPodaci, String?>) -> Binding<String> {
        Binding(get: { licni[keyPath: k] ?? "" }, set: { licni[keyPath: k] = $0; if stanje != .cuva { stanje = .unos } })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    KrugDugme(ikonica: "chevron.left", opis: "Nazad") { if izmenjeno && stanje != .sacuvano { odbaci = true } else { nazad() } }
                    Spacer()
                    Text("Uredi profil").font(.naslov(22))
                    Spacer()
                    Color.clear.frame(width: 44)
                }
                VStack(spacing: 10) {
                    AvatarSlika(avatar: avatar, velicina: 120, maskota: maskota)
                    Text("Avatar").font(.tekst(13, .semibold)).foregroundStyle(Color.sivaTekst)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                        ForEach(sviAvatari ? AvatarSlika.svi : Array(AvatarSlika.svi.prefix(24)), id: \.self) { a in
                            Button { avatar = a } label: {
                                AvatarSlika(avatar: a, velicina: 48)
                                    .overlay(Circle().stroke(avatar == a ? Color.teal : .clear, lineWidth: 4))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Avatar \(a)").accessibilityAddTraits(avatar == a ? .isSelected : [])
                        }
                    }
                    if !sviAvatari {
                        Button("Prikaži svih \(AvatarSlika.svi.count)") { withAnimation { sviAvatari = true } }.font(.tekst(14, .bold)).foregroundStyle(Color.teal)
                    }
                    Text("Drugar koji navija u igri").font(.tekst(13, .semibold)).foregroundStyle(Color.sivaTekst).padding(.top, 8)
                    HStack(spacing: 14) {
                        ForEach([Maskota.mimi, .zig, .bloop, .lumi], id: \.self) { m in
                            Button { maskota = m } label: {
                                MaskotaSlika(maskota: m, velicina: 46).frame(width: 56, height: 56).background(Color.kartica, in: Circle())
                                    .overlay(Circle().stroke(maskota == m ? Color.teal : Color.kremTamnija, lineWidth: maskota == m ? 3 : 1.5))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(m.rawValue).accessibilityAddTraits(maskota == m ? .isSelected : [])
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                if sesija.prijavljen {
                    PoljeUnosa(naziv: "Nadimak", tekst: $nadimak, stanje: nadimakStanje, sadrzaj: .nickname)
                    HStack(spacing: 10) {
                        PoljeUnosa(naziv: "Ime", tekst: polje(\.first_name), sadrzaj: .givenName)
                        PoljeUnosa(naziv: "Prezime", tekst: polje(\.last_name), sadrzaj: .familyName)
                    }
                    PoljeUnosa(naziv: "Grad", tekst: polje(\.city), sadrzaj: .addressCity)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("O meni").font(.tekst(14, .semibold))
                        TextField("Par reči o sebi: omiljene knjige, teme, grad…", text: polje(\.bio), axis: .vertical)
                            .font(.tekst(16)).lineLimit(3...5).padding(14)
                            .background(Color.kartica, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke((licni.bio?.count ?? 0) > Self.bioNajvise ? Color.crvena : Color.kremTamnija, lineWidth: 1.5))
                        Text("\(licni.bio?.count ?? 0) / \(Self.bioNajvise)").font(.tekst(12)).monospacedDigit()
                            .foregroundStyle((licni.bio?.count ?? 0) > Self.bioNajvise ? Color.crvena : Color.sivaTekst)
                    }
                    PoljeUnosa(naziv: "Email", tekst: .constant(sesija.email ?? ""), onemoguceno: true)
                    Text("Email se menja preko podrške, da nalog ostane bezbedan.").font(.tekst(12)).foregroundStyle(Color.sivaTekst)
                } else {
                    Text("Bez naloga avatar ostaje na ovom telefonu. Sa nalogom ga vide i drugi igrači.").font(.tekst(13)).foregroundStyle(Color.sivaTekst)
                }
                if case .greska(let p) = stanje { Text(p).font(.tekst(14, .semibold)).foregroundStyle(Color.crvena) }
                Button { Task { await sacuvaj() } } label: {
                    if stanje == .cuva { HStack(spacing: 10) { ProgressView().tint(Color.naMastilu); Text("Čuvam…") } }
                    else { Text(stanje == .sacuvano ? "Sačuvano" : "Sačuvaj") }
                }
                .buttonStyle(.primarno).disabled(!izmenjeno || stanje == .cuva).padding(.top, 10)
            }
            .padding(16)
        }
        .background(Papir())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task {
            guard sesija.prijavljen, let l = try? await sesija.licniPodaci() else { return }
            licni = l; licniPocetni = l
        }
        .onAppear {
            nadimak = sesija.nadimak ?? ""
            maskota = Maskota(rawValue: napredak.s.maskota) ?? .mimi
            avatar = trenutniAvatar
        }
        .onChange(of: nadimak) { if stanje != .cuva { stanje = .unos } }
        .overlay {
            if odbaci {
                Dijalog(naslov: "Odbaciti izmene?", tekst: "Izmene koje nisi sačuvao će nestati.", potvrda: "Odbaci", odustani: "Nastavi izmenu", opasno: true) {
                    odbaci = false; nazad()
                } zatvori: { odbaci = false }
            }
        }
        .sensoryFeedback(.success, trigger: stanje == .sacuvano)
    }

    private var nadimakStanje: PoljeUnosa.Stanje {
        switch stanje {
        case .zauzet: .greska("Nadimak „\(nadimak)” je zauzet. Probaj drugi.")
        case .sacuvano: .uRedu("Sačuvano.")
        default: nadimak.isEmpty || NalogEkranPravila.ispravanNadimak(nadimak) ? .obicno : .greska("3–20 slova, cifara, tačka ili crtica.")
        }
    }

    private func sacuvaj() async {
        napredak.podesi { $0.maskota = maskota.rawValue; $0.avatar = avatar }
        if let avatar, avatar != sesija.avatar, sesija.prijavljen {
            do { try await sesija.sacuvajAvatar(avatar) } catch { stanje = .greska(error.localizedDescription); return }
        }
        if sesija.prijavljen, licni != licniPocetni {
            guard (licni.bio?.count ?? 0) <= Self.bioNajvise else { stanje = .greska("„O meni” može da ima najviše \(Self.bioNajvise) znakova."); return }
            do { try await sesija.sacuvajLicnePodatke(licni); licniPocetni = licni } catch { stanje = .greska(error.localizedDescription); return }
        }
        guard sesija.prijavljen, nadimak != (sesija.nadimak ?? "") else { stanje = .sacuvano; return }
        guard NalogEkranPravila.ispravanNadimak(nadimak) else { return }
        stanje = .cuva
        do { try await sesija.sacuvajNadimak(nadimak); stanje = .sacuvano }
        catch let g as Supabase.Greska { stanje = g.vrsta == .postoji ? .zauzet : .greska(g.poruka) }
        catch { stanje = .greska(error.localizedDescription) }
    }
}

/// Pravila nadimka dele registracija i izmena profila.
enum NalogEkranPravila {
    static func ispravanNadimak(_ n: String) -> Bool { n.range(of: #"^[\p{L}0-9.\-]{3,20}$"#, options: .regularExpression) != nil }
}
