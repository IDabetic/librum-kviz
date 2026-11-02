import SwiftUI

/// Početna iz kita (Home · Pick a Quiz): vrteška izdvojenih kvizova, igre, teme
/// i nedeljni vrh. Stanja: offline traka, učitavanje i greška vrha.
struct PocetnaView: View {
    @Environment(Sesija.self) private var sesija
    @Environment(Napredak.self) private var napredak
    @Environment(Mreza.self) private var mreza

    @State private var izdvojeni = 0
    @State private var vrh: Ucitano<[RangListaView.Red]> = .ucitava
    @State private var pravila: KvizStavka?

    private let istaknuti = ["osvajanje", "slikari", "opste", "knjige"].compactMap(KvizKatalog.stavka)
    /// Šest igara pored Osvajanja sveta.
    private let igre = ["pro", "book", "duel", "slikari", "brzi", "vesanje"].compactMap(KvizKatalog.stavka)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                zaglavlje
                if !mreza.povezan { OfflineTraka() }
                vrteska
                Text("Igre").font(.naslov(24))
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                    ForEach(igre) { s in
                        NavigationLink { KvizOdrediste(stavka: s) } label: {
                            KarticaIgre(naslov: s.naslov, opis: s.opis, boja: Color(hex: s.boja), tekst: s.tekstBoja, maskota: s.maskota, velika: false, ilustracija: s.ilustracija)
                        }
                        .overlay(alignment: .topLeading) { infoDugme(s).padding(10) }
                    }
                }
                HStack {
                    Text("Teme").font(.naslov(24))
                    Spacer()
                    NavigationLink("Sve") { IstraziView() }.font(.tekst(14, .bold)).foregroundStyle(Color.teal)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(KvizKatalog.sve.filter { $0.id.hasPrefix("zanr-") }) { s in
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
        .task { await ucitajVrh() }
        .refreshable { await ucitajVrh() }
        .task {
        }
    }

    private var zaglavlje: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label("\(napredak.s.nizDana)", systemImage: "flame.fill").font(.tekst(15, .bold)).foregroundStyle(Color.roze)
                    .accessibilityLabel("Niz od \(napredak.s.nizDana) dana")
                Text("Nivo \(napredak.nivo)").font(.tekst(14, .bold)).foregroundStyle(Color.sivaTekst)
                Spacer()
                Label("\(napredak.pomociOstalo()) pomoći", systemImage: "lifepreserver").font(.tekst(14, .bold)).foregroundStyle(Color.sivaTekst)
                    .accessibilityLabel("Danas još \(napredak.pomociOstalo()) pomoći")
            }
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    if let ime = sesija.nadimak { Oznaka(tekst: "Zdravo, \(ime)", boja: .teal) }
                    Text("Izaberi kviz\ni igraj").font(.naslov(38)).tracking(-0.5)
                }
                Spacer()
            }
        }
        .padding(.top, 6)
    }

    private func infoDugme(_ s: KvizStavka) -> some View {
        Button { withAnimation { pravila = s } } label: {
            Image(systemName: "info").font(.system(size: 13, weight: .black)).foregroundStyle(s.tekstBoja)
                .frame(width: 30, height: 30).overlay(Circle().stroke(s.tekstBoja, lineWidth: 2))
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .accessibilityLabel("Pravila: \(s.naslov)")
    }

    private var vrteska: some View {
        VStack(spacing: 10) {
            TabView(selection: $izdvojeni) {
                ForEach(Array(istaknuti.enumerated()), id: \.offset) { i, s in
                    NavigationLink { KvizOdrediste(stavka: s) } label: { izdvojena(s) }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 4).padding(.bottom, 8)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 330)
            CrticeKoraka(ukupno: istaknuti.count, trenutni: izdvojeni)
        }
    }

    private func izdvojena(_ s: KvizStavka) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Color(hex: s.boja))
            Circle().fill(.white.opacity(0.2)).frame(width: 260).offset(x: 120, y: 110)
            Group {
                if let ilu = s.ilustracija { Image(ilu).resizable().scaledToFit().frame(width: 170, height: 170).rotationEffect(.degrees(6)) }
                else { MaskotaSlika(maskota: s.maskota, velicina: 190) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(16)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(s.naslov).font(.naslov(28)).foregroundStyle(Color.tinta).lineLimit(2).minimumScaleFactor(0.7)
                Text(s.tezina).font(.tekst(13, .bold)).foregroundStyle(Color.tinta.opacity(0.7))
            }
            .padding(14).background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.tinta, lineWidth: 2.5))
            .rotationEffect(.degrees(-3)).padding(18).frame(maxWidth: 230, alignment: .leading)
            Text("Igraj").font(.tekst(16, .bold)).foregroundStyle(.white)
                .padding(.horizontal, 22).frame(height: 48).background(Color.tinta, in: RoundedRectangle(cornerRadius: 16))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading).padding(18)
        }
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(Color.mastilo, lineWidth: 2.5))
        .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Color.senka).offset(y: 6))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(s.naslov). \(s.opis)")
        .accessibilityAddTraits(.isButton)
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
            Text("Osvajanje: vrh nedelje").font(.naslov(24))
            Spacer()
        }
        switch vrh {
        case .ucitava:
            VStack(spacing: 8) { ForEach(0..<3, id: \.self) { _ in Skelet(visina: 52) } }
        case .greska(let poruka):
            StanjeEkrana(maskota: .lumi, naslov: "Lista se nije učitala", tekst: poruka, dugme: "Pokušaj ponovo") { Task { await ucitajVrh() } }
                .mirna()
        case .gotovo(let redovi) where redovi.isEmpty:
            StanjeEkrana(maskota: .bloop, naslov: "Još niko ove nedelje", tekst: "Odigraj Osvajanje sveta i budi prvi na listi.").mirna()
        case .gotovo(let redovi):
            VStack(spacing: 0) {
                ForEach(Array(redovi.prefix(3).enumerated()), id: \.element.id) { i, r in
                    HStack(spacing: 12) {
                        Text("\(i + 1)").font(.naslov(18)).frame(width: 34, height: 34)
                            .background([Color.zuta, .nebo, .roze][i], in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(Color.tinta)
                        Text(r.nadimak).font(.tekst(15, .semibold)).lineLimit(1)
                        Spacer()
                        Text(r.poeni.formatted()).font(.naslov(18)).monospacedDigit()
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
        do { vrh = .gotovo(try await RangListaView.ucitajVrh()) } catch { vrh = .greska(error.localizedDescription) }
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
                if let ilustracija { Image(ilustracija).resizable().scaledToFit().frame(width: velika ? 150 : 76, height: velika ? 150 : 76).rotationEffect(.degrees(8)).padding(.top, 10).padding(.trailing, 6) }
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

/// „Kako se igra” u donjem listu (pravila sa starog sajta, po pravilima aplikacije).
struct PravilaList: View {
    let stavka: KvizStavka
    let zatvori: () -> Void
    var body: some View {
        DonjiList(zatvori: zatvori) {
            VStack(alignment: .leading, spacing: 12) {
                Naslov(tekst: "Kako se igra \(stavka.naslov)", velicina: 26)
                ForEach(Array(stavka.pravila.enumerated()), id: \.offset) { i, t in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(i + 1)").font(.tekst(13, .bold)).foregroundStyle(Color.tinta).frame(width: 26, height: 26)
                            .background(Color(hex: stavka.boja), in: Circle()).overlay(Circle().stroke(Color.mastilo, lineWidth: 1.5))
                        Text(t).font(.tekst(15)).foregroundStyle(Color.mastilo).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Button("Važi", action: zatvori).buttonStyle(.primarno).padding(.top, 6)
            }
        }
    }
}
