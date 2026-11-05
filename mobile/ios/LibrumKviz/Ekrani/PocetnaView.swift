import SwiftUI

/// Početna iz kita (Home · Pick a Quiz): igre (Osvajanje sveta prvo), teme
/// i nedeljni vrh. Stanja: offline traka, učitavanje i greška vrha.
struct PocetnaView: View {
    @Environment(Sesija.self) private var sesija
    @Environment(Napredak.self) private var napredak
    @Environment(Mreza.self) private var mreza

    @State private var vrh: Ucitano<[RangListaView.Red]> = Kes.ucitano("vrh-pocetna")
    @State private var pravila: KvizStavka?
    @State private var objasnjenje: Objasnjenje?
    /// Sačuvana partija Osvajanja (na ovom telefonu): „Nastavi partiju” iznad kartice.
    @State private var sacuvana: OsvajanjeModel.Nastavak?
    @State private var nastavak: OsvajanjeModel.Nastavak?
    /// Aktivna pitanja na serveru (kviz + knjige + kafana); nil dok ne stigne prvi odgovor.
    @State private var pitanjaUIgri: Int?
    private static let osvezavanjePitanja: Double = 30

    /// Vlasnik 03.11: Osvajanje sveta je jedna velika kartica, ispod šest igara u dva reda po tri.
    private let osvajanje = KvizKatalog.stavka("osvajanje")
    private let igre = ["pro", "book", "duel", "slikari", "brzi", "vesanje"].compactMap(KvizKatalog.stavka)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                zaglavlje
                if !mreza.povezan { OfflineTraka() }
                if let n = sacuvana {
                    Button { nastavak = n } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "play.fill").font(.system(size: 16, weight: .bold)).frame(width: 40, height: 40)
                                .background(Color.zuta, in: RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Nastavi partiju").font(.tekst(16, .bold))
                                Text("Osvajač · krug \(min(n.stanje.krug, n.stanje.ukupnoKrugova)) od \(n.stanje.ukupnoKrugova)")
                                    .font(.tekst(13)).foregroundStyle(Color.sivaTekst)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(Color.sivaTekst)
                        }
                        .foregroundStyle(Color.mastilo).padding(12).mirna()
                    }
                    .buttonStyle(.plain)
                }
                if let s = osvajanje {
                    NavigationLink { KvizOdrediste(stavka: s) } label: {
                        KarticaIgre(naslov: s.naslov, opis: s.opis, boja: Color(hex: s.boja), tekst: s.tekstBoja, maskota: s.maskota, velika: true, ilustracija: s.ilustracija)
                    }
                    .overlay(alignment: .topLeading) { infoDugme(s).padding(12) }
                }
                // Druga glavna igra (docs/KARIJERA-PRAVILA.md): od Korporacije do svog nebodera.
                NavigationLink { KarijeraView() } label: { KarijeraKartica() }
                .buttonStyle(.plain)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                    ForEach(igre) { s in
                        NavigationLink { KvizOdrediste(stavka: s) } label: { MalaIgra(stavka: s) }
                            .buttonStyle(.plain)
                            .contextMenu { Button("Kako se igra") { withAnimation { pravila = s } } }
                    }
                }
                // Vlasnik 03.11: svih pet igara za 2–8 igrača ili timove, protiv računara ili pravih igrača.
                NavigationLink { TakmicenjeView() } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.3.fill").font(.system(size: 20, weight: .bold)).foregroundStyle(Color.tinta)
                            .frame(width: 48, height: 48).background(Color.zuta, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mastilo, lineWidth: 2))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Igraj sa drugima").font(.tekst(16, .bold))
                            Text("2–8 igrača, timovi, računar").font(.tekst(13)).foregroundStyle(Color.sivaTekst).lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(Color.sivaTekst)
                    }
                    .foregroundStyle(Color.mastilo).padding(12).pop(radijus: 20)
                }
                .buttonStyle(.plain)
                HStack {
                    Text("Teme").font(.naslov(24))
                    Spacer()
                    NavigationLink("Sve") { IstraziView() }.font(.tekst(14, .bold)).foregroundStyle(Color.teal)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(KvizKatalog.sve.filter { $0.id == "dnevni" || $0.id.hasPrefix("tema-") || $0.id.hasPrefix("zanr-") }) { s in
                            NavigationLink { KvizOdrediste(stavka: s) } label: { tema(s) }
                        }
                    }
                    .padding(.vertical, 6).padding(.horizontal, 2)
                }
                nedeljniVrh
            }
            .padding(16)
        }
        .background(Papir())
        .toolbar(.hidden, for: .navigationBar)
        .overlay { if let pravila { PravilaList(stavka: pravila) { self.pravila = nil } } }
        .overlay { if let objasnjenje { ObjasnjenjeList(vrsta: objasnjenje) { self.objasnjenje = nil } } }
        .task { await ucitajVrh() }
        .onAppear { sacuvana = OsvajanjeModel.sacuvana() }
        .fullScreenCover(item: $nastavak, onDismiss: { sacuvana = OsvajanjeModel.sacuvana() }) { OsvajanjeIgraView(model: OsvajanjeModel(nastavak: $0)) }
        .refreshable { await ucitajVrh() }
        .task { await pratiPitanjaUIgri() }
    }

    /// Vlasnik 03.11: na ulazu piše koliko je pitanja u igri, uživo. `.task` se gasi kad početna nestane.
    private func pratiPitanjaUIgri() async {
        struct Brojevi: Decodable { let kviz, knjige, kafana: Int }
        while !Task.isCancelled {
            if let b: Brojevi = try? await Supabase.deljeni.rpc("pitanja_u_igri", [:]) {
                withAnimation { pitanjaUIgri = b.kviz + b.knjige + b.kafana }
            }
            try? await Task.sleep(for: .seconds(PocetnaView.osvezavanjePitanja))
        }
    }

    private var zaglavlje: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Button { objasnjenje = .niz } label: {
                    Label("\(napredak.s.nizDana)", systemImage: "flame.fill").font(.tekst(15, .bold)).foregroundStyle(Color.roze)
                }
                .accessibilityLabel("Niz od \(napredak.s.nizDana) dana, objašnjenje")
                Button { objasnjenje = .nivo } label: {
                    Text("Nivo \(napredak.nivo) · \(napredak.titula)").font(.tekst(14, .bold)).foregroundStyle(Color.sivaTekst)
                }
                .accessibilityLabel("Nivo \(napredak.nivo), \(napredak.titula), objašnjenje")
                Spacer()
                Button { objasnjenje = .pomoci } label: {
                    Label("\(napredak.pomociOstalo())/\(napredak.fondPomoci)", systemImage: "lifepreserver").font(.tekst(14, .bold)).foregroundStyle(Color.sivaTekst)
                }
                .accessibilityLabel("Danas još \(napredak.pomociOstalo()) od \(napredak.fondPomoci) pomoći, objašnjenje")
            }
            .buttonStyle(.plain)
            // Vlasnik 03.11: kratak naslov u jednom redu, igre odmah ispod (bez posebnog naslova „Igre”).
            Text(sesija.nadimak.map { "Zdravo, \($0)!" } ?? "Izaberi i igraj").font(.naslov(26)).tracking(-0.5).lineLimit(1).minimumScaleFactor(0.7)
            if let pitanjaUIgri {
                HStack(spacing: 6) {
                    Circle().fill(Color.teal).frame(width: 7, height: 7)
                    Text("\(pitanjaUIgri.formatted(.number.locale(.srpski))) pitanja u igri")
                        .font(.tekst(13, .bold)).monospacedDigit().contentTransition(.numericText())
                }
                .foregroundStyle(Color.sivaTekst)
                .accessibilityElement(children: .combine)
                .padding(.top, -6)
            }
        }
        .padding(.top, 2)
    }

    private func infoDugme(_ s: KvizStavka) -> some View {
        Button { withAnimation { pravila = s } } label: {
            Image(systemName: "info").font(.system(size: 13, weight: .black)).foregroundStyle(s.tekstBoja)
                .frame(width: 30, height: 30).overlay(Circle().stroke(s.tekstBoja, lineWidth: 2))
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .accessibilityLabel("Pravila: \(s.naslov)")
    }

    private func tema(_ s: KvizStavka) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: s.ikonica).font(.system(size: 18, weight: .semibold)).foregroundStyle(s.tekstBoja)
                .frame(width: 38, height: 38).overlay(Circle().stroke(s.tekstBoja, lineWidth: 1.5))
            Spacer()
            Text(s.naslov).font(.naslov(18)).foregroundStyle(s.tekstBoja)
            Text(napredak.s.najbolje[s.id].map { "najbolje \($0)/10" } ?? "10 pitanja").font(.tekst(12, .semibold)).foregroundStyle(s.tekstBoja.opacity(0.85))
        }
        .padding(14).frame(width: 150, height: 130, alignment: .leading)
        .pop(Color(hex: s.boja), radijus: 20)
    }

    @ViewBuilder private var nedeljniVrh: some View {
        HStack {
            Text("Osvajač: vrh nedelje").font(.naslov(24))
            Spacer()
        }
        switch vrh {
        case .ucitava:
            VStack(spacing: 8) { ForEach(0..<3, id: \.self) { _ in Skelet(visina: 52) } }
        case .greska(let poruka):
            StanjeEkrana(maskota: .lumi, naslov: "Lista se nije učitala", tekst: poruka, dugme: "Pokušaj ponovo") { Task { await ucitajVrh() } }
                .mirna()
        case .gotovo(let redovi) where redovi.isEmpty:
            StanjeEkrana(maskota: .bloop, naslov: "Još niko ove nedelje", tekst: "Odigraj Osvajača i budi prvi na listi.").mirna()
        case .gotovo(let redovi):
            VStack(spacing: 0) {
                ForEach(Array(redovi.prefix(3).enumerated()), id: \.element.id) { i, r in
                    HStack(spacing: 12) {
                        Text("\(i + 1)").font(.naslov(18)).frame(width: 34, height: 34)
                            .background([Color.zuta, .nebo, .roze][i], in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(Color.tinta)
                        Text(r.nadimak).font(.tekst(15, .semibold)).lineLimit(1)
                        Spacer()
                        Text(r.poeni.formatted(.number.locale(.srpski))).font(.naslov(18)).monospacedDigit()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    if i < min(redovi.count, 3) - 1 { Divider().overlay(Color.kremTamnija) }
                }
            }
            .mirna()
        }
    }

    private func ucitajVrh() async {
        if case .gotovo = vrh {} else { vrh = .ucitava }
        do {
            let v = try await RangListaView.ucitajVrh()
            vrh = .gotovo(v)
            Kes.sacuvaj(v, "vrh-pocetna")
        } catch { if case .gotovo = vrh {} else { vrh = .greska(error.localizedDescription) } }
    }
}

struct KarticaIgre: View {
    let naslov: String
    let opis: String
    let boja: Color
    let tekst: Color
    let maskota: Maskota
    let velika: Bool
    /// Ilustracija igre (Freepik, mobile/ILUSTRACIJE.md); bez nje ostaje maskota.
    var ilustracija: String? = nil

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Circle().fill(.white.opacity(0.22)).frame(width: velika ? 230 : 150)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: velika ? 40 : 36, y: velika ? -30 : -34)
            Group {
                if let ilustracija { Image(ilustracija).resizable().scaledToFit().frame(width: velika ? 128 : 76, height: velika ? 128 : 76).rotationEffect(.degrees(8)).padding(.top, 12).padding(.trailing, 12) }
                else { MaskotaSlika(maskota: maskota, velicina: velika ? 160 : 84) }
            }
            .accessibilityHidden(true)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: velika ? 0 : 8, y: velika ? 4 : -8)
            VStack(alignment: .leading, spacing: 4) {
                Text(naslov).font(.naslov(velika ? 36 : 22)).foregroundStyle(tekst).lineLimit(1).minimumScaleFactor(0.7)
                Text(opis).font(.tekst(13, .semibold)).foregroundStyle(tekst.opacity(0.85))
                    .multilineTextAlignment(.leading).lineLimit(2)
                    .frame(maxWidth: 240, alignment: .leading)
            }
            .padding(velika ? 22 : 16)
        }
        .frame(height: velika ? 250 : 160)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .pop(boja)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// Šta znače vatrica, nivo i pomoći (docs/NAPREDAK.md), sa tvojim brojkama.
enum Objasnjenje { case niz, nivo, pomoci }

struct ObjasnjenjeList: View {
    @Environment(Napredak.self) private var napredak
    let vrsta: Objasnjenje
    let zatvori: () -> Void

    var body: some View {
        DonjiList(zatvori: zatvori) {
            VStack(alignment: .leading, spacing: 12) {
                switch vrsta {
                case .niz:
                    Naslov(tekst: "Niz: \(napredak.s.nizDana) \(napredak.s.nizDana == 1 ? "dan" : "dana")", velicina: 26)
                    stavke([
                        "Svaki dan u kom odigraš bar jednu partiju produžava niz. Preskočen dan ga vraća na 1.",
                        "3 dana zaredom: +1 pomoć dnevno. 7 dana: +2 pomoći dnevno.",
                        "Svaki dan niza dodaje 5% XP-a, najviše +50%.",
                        "Najduži niz: \(napredak.s.najduziNiz) dana.",
                    ])
                case .nivo:
                    let x = napredak.xpUNivou
                    Naslov(tekst: "Nivo \(napredak.nivo) · \(napredak.titula)", velicina: 26)
                    ProgressView(value: Double(x.imam), total: Double(max(1, x.treba))).tint(Color.teal)
                    Text("\(x.imam) / \(x.treba) XP do nivoa \(napredak.nivo + 1)").font(.tekst(13, .semibold)).foregroundStyle(Color.sivaTekst)
                    stavke([
                        "XP: 10 po tačnom odgovoru, 20 za završenu partiju, 50 za pobedu, plus bonus niza.",
                        "Titule: Početnik (1), Znalac (5), Erudita (10), Mudrac (20), Legenda (35).",
                        "Nivo 2 otključava Slikare: majstori, nivo 3 Nemoguća pitanja.",
                        "Na svakih 5 nivoa dobijaš +1 pomoć dnevno (najviše +3).",
                    ])
                case .pomoci:
                    Naslov(tekst: "Pomoći: \(napredak.pomociOstalo()) od \(napredak.fondPomoci)", velicina: 26)
                    stavke([
                        "Jedna pomoć po partiji: 50/50, nagoveštaj, dodatno vreme ili preskok.",
                        "Dnevni fond je 7, +1 na svakih 5 nivoa i +1 ili +2 za niz dana (najviše 12).",
                        "Fond se puni 24 sata posle prve iskorišćene pomoći.",
                    ])
                }
                Button("Važi", action: zatvori).buttonStyle(.primarno).padding(.top, 6)
            }
        }
    }

    private func stavke(_ l: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(l, id: \.self) { t in
                HStack(alignment: .top, spacing: 10) {
                    Circle().fill(Color.zuta).overlay(Circle().stroke(Color.mastilo, lineWidth: 1.5)).frame(width: 10, height: 10).padding(.top, 6)
                    Text(t).font(.tekst(15)).foregroundStyle(Color.mastilo).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// Mala kartica igre (tri u redu): ilustracija i naslov; pravila su na dugom pritisku i u lobiju.
struct MalaIgra: View {
    let stavka: KvizStavka
    var body: some View {
        VStack(spacing: 6) {
            Group {
                if let ilu = stavka.ilustracija { Image(ilu).resizable().scaledToFit() }
                else { MaskotaSlika(maskota: stavka.maskota, velicina: 64) }
            }
            .frame(width: 64, height: 64)
            .accessibilityHidden(true)
            Text(stavka.naslov).font(.naslov(15)).foregroundStyle(stavka.tekstBoja)
                .lineLimit(2).minimumScaleFactor(0.8).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).frame(height: 128)
        .padding(.horizontal, 6)
        .pop(Color(hex: stavka.boja))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// „Kako se igra” u donjem listu (pravila sa starog sajta, po pravilima aplikacije).
struct PravilaList: View {
    let stavka: KvizStavka
    let zatvori: () -> Void
    var body: some View {
        DonjiList(zatvori: zatvori) {
            VStack(alignment: .leading, spacing: 12) {
                // Osvajanje ima 20+ pravila: kad ne staju, skroluju se, a „Važi” ostaje vidljivo ispod.
                ViewThatFits(in: .vertical) {
                    spisak
                    ScrollView { spisak }.scrollIndicators(.visible)
                }
                Button("Važi", action: zatvori).buttonStyle(.primarno).padding(.top, 6)
            }
        }
    }

    private var spisak: some View {
        VStack(alignment: .leading, spacing: 12) {
            Naslov(tekst: "Kako se igra \(stavka.naslov)", velicina: 26)
            ForEach(Array(stavka.pravila.enumerated()), id: \.offset) { i, t in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(i + 1)").font(.tekst(13, .bold)).foregroundStyle(Color.tinta).frame(width: 26, height: 26)
                        .background(Color(hex: stavka.boja), in: Circle()).overlay(Circle().stroke(Color.mastilo, lineWidth: 1.5))
                    Text(t).font(.tekst(15)).foregroundStyle(Color.mastilo).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
