import SwiftUI

/// Početna iz kita (Home · Pick a Quiz): vrteška izdvojenih kvizova, igre, teme
/// i nedeljni vrh. Stanja: offline traka, dnevna nagrada, učitavanje i greška vrha.
struct PocetnaView: View {
    @Environment(Sesija.self) private var sesija
    @Environment(Napredak.self) private var napredak
    @Environment(Mreza.self) private var mreza

    @State private var izdvojeni = 0
    @State private var nagrada = false
    @State private var vrh: Ucitano<[RangListaView.Red]> = .ucitava

    private let istaknuti = ["osvajanje", "slikari", "opste", "knjige"].compactMap(KvizKatalog.stavka)
    /// Šest igara pored Osvajanja sveta.
    private let igre = ["pro", "book", "duel", "slikari", "brzi", "vesanje"].compactMap(KvizKatalog.stavka)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                zaglavlje
                if !mreza.povezan { OfflineTraka() }
                if napredak.dnevnaNagradaSpremna { nagradaBaner }
                vrteska
                Text("Igre").font(.naslov(24))
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                    ForEach(igre) { s in
                        NavigationLink { KvizOdrediste(stavka: s) } label: {
                            KarticaIgre(naslov: s.naslov, opis: s.opis, boja: Color(hex: s.boja), tekst: s.tekstBoja, maskota: s.maskota, velika: false)
                        }
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
        .task { await ucitajVrh() }
        .refreshable { await ucitajVrh() }
        .task {
            napredak.osveziSanduce()
            if napredak.dnevnaNagradaSpremna { try? await Task.sleep(for: .milliseconds(500)); withAnimation { nagrada = true } }
        }
        .overlay { if nagrada { DnevnaNagradaView { withAnimation { nagrada = false } } } }
    }

    private var zaglavlje: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label("\(napredak.s.nizDana)", systemImage: "flame.fill").font(.tekst(15, .bold)).foregroundStyle(Color.roze)
                    .accessibilityLabel("Niz od \(napredak.s.nizDana) dana")
                Text("Nivo \(napredak.nivo)").font(.tekst(14, .bold)).foregroundStyle(Color.sivaTekst)
                Spacer()
                NavigationLink { ProdavnicaView() } label: { Novcanik(iznos: napredak.s.novcici) }
            }
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    if let ime = sesija.nadimak { Oznaka(tekst: "Zdravo, \(ime)", boja: .teal) }
                    Text("Izaberi kviz\ni igraj").font(.naslov(38)).tracking(-0.5)
                }
                Spacer()
                NavigationLink { ProdavnicaView() } label: { ikonica("cart", "Prodavnica") }
            }
        }
        .padding(.top, 6)
    }

    private func ikonica(_ ime: String, _ opis: String) -> some View {
        Image(systemName: ime).font(.system(size: 17, weight: .bold)).foregroundStyle(Color.mastilo)
            .frame(width: 44, height: 44).background(Color.kartica, in: Circle()).overlay(Circle().stroke(Color.kremTamnija, lineWidth: 1.5))
            .accessibilityLabel(opis)
    }

    private var nagradaBaner: some View {
        Button { withAnimation { nagrada = true } } label: {
            HStack(spacing: 12) {
                Image(systemName: "gift.fill").font(.system(size: 20)).foregroundStyle(Color.tinta)
                    .frame(width: 44, height: 44).background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.tinta, lineWidth: 2))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dnevna nagrada čeka").font(.tekst(15, .bold))
                    Text("Dan \(napredak.s.danaNagrade + (napredak.s.poslednjaNagrada == nil ? 1 : 2)) · \(napredak.sledecaNagrada) novčića").font(.tekst(13))
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(Color.tinta).padding(12).pop(.zuta, radijus: 18)
        }
        .buttonStyle(.plain)
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
            MaskotaSlika(maskota: s.maskota, velicina: 190).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(10)
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
            Text("Vrh ove nedelje").font(.naslov(24))
            Spacer()
        }
        switch vrh {
        case .ucitava:
            VStack(spacing: 8) { ForEach(0..<3, id: \.self) { _ in Skelet(visina: 52) } }
        case .greska(let poruka):
            StanjeEkrana(maskota: .lumi, naslov: "Lista se nije učitala", tekst: poruka, dugme: "Pokušaj ponovo") { Task { await ucitajVrh() } }
                .mirna()
        case .gotovo(let redovi) where redovi.isEmpty:
            StanjeEkrana(maskota: .bloop, naslov: "Još niko ove nedelje", tekst: "Odigraj PRO kviz i budi prvi na listi.").mirna()
        case .gotovo(let redovi):
            VStack(spacing: 0) {
                ForEach(Array(redovi.prefix(3).enumerated()), id: \.element.id) { i, r in
                    HStack(spacing: 12) {
                        Text("\(i + 1)").font(.naslov(18)).frame(width: 34, height: 34)
                            .background([Color.zuta, .nebo, .roze][i], in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(Color.tinta)
                        Text(r.ime).font(.tekst(15, .semibold)).lineLimit(1)
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
        do { vrh = .gotovo(try await RangListaView.ucitaj(nedelja: true, limit: 3)) } catch { vrh = .greska(error.localizedDescription) }
    }
}

/// Dnevna nagrada iz kita (Home · Daily Reward): sedam dana niza, pokupi danas.
struct DnevnaNagradaView: View {
    @Environment(Napredak.self) private var napredak
    let zatvori: () -> Void
    @State private var pokupljeno: Int?

    var body: some View {
        DonjiList(zatvori: zatvori) {
            VStack(spacing: 14) {
                Image(systemName: "gift.fill").font(.system(size: 34)).foregroundStyle(Color.tinta)
                    .frame(width: 84, height: 84).background(Color.zuta, in: Circle()).overlay(Circle().stroke(Color.mastilo, lineWidth: 2.5))
                Naslov(tekst: pokupljeno == nil ? "Dnevna nagrada" : "+\(pokupljeno!) novčića!", velicina: 30)
                Text(pokupljeno == nil ? "Vrati se svaki dan. Sedmi dan donosi 100 novčića." : "Vidimo se sutra. Niz nagrada raste.")
                    .font(.tekst(14)).foregroundStyle(Color.sivaTekst).multilineTextAlignment(.center)
                HStack(spacing: 6) {
                    ForEach(Napredak.nagradeNiza.indices, id: \.self) { i in
                        let danas = (pokupljeno == nil ? napredak.s.danaNagrade + (napredak.s.poslednjaNagrada == nil ? 0 : 1) : napredak.s.danaNagrade) % 7
                        VStack(spacing: 4) {
                            Text("\(i + 1).").font(.tekst(11, .bold))
                            Text("\(Napredak.nagradeNiza[i])").font(.tekst(13, .bold)).monospacedDigit()
                        }
                        .foregroundStyle(i == danas ? Color.tinta : Color.mastilo)
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background(i == danas ? Color.zuta : i < danas ? Color.tealSvetla : Color.kartica, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(i == danas ? Color.mastilo : Color.kremTamnija, lineWidth: i == danas ? 2 : 1))
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Sedam dana nagrada, od 10 do 100 novčića")
                if pokupljeno == nil {
                    Button("Pokupi \(napredak.sledecaNagrada) novčića") { withAnimation { pokupljeno = napredak.pokupiDnevnuNagradu() } }.buttonStyle(.zuto)
                } else {
                    Button("Super", action: zatvori).buttonStyle(.primarno)
                }
            }
        }
        .sensoryFeedback(.success, trigger: pokupljeno)
    }
}

struct KarticaIgre: View {
    let naslov: String
    let opis: String
    let boja: Color
    let tekst: Color
    let maskota: Maskota
    let velika: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Circle().fill(.white.opacity(0.22)).frame(width: velika ? 230 : 150)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: velika ? 40 : 36, y: velika ? -30 : -34)
            MaskotaSlika(maskota: maskota, velicina: velika ? 160 : 84)
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
