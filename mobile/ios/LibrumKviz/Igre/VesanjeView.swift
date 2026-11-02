import SwiftUI

/// Vešanje: pogodi pojam slovo po slovo, uz opis i kategoriju.
struct VesanjeView: View {
    @Environment(Sesija.self) private var sesija
    @Environment(Napredak.self) private var napredak
    @Environment(\.dismiss) private var zatvori

    @State private var reci: [Rec] = []
    @State private var indeks = 0
    @State private var rec: Rec?
    @State private var igra = Vesanje(rec: "")
    @State private var pocetak = Date()
    @State private var greska: String?
    @State private var pokusajReci = ""
    @State private var celaRec = false
    @State private var pomocIskoriscena = false
    @State private var sacuvano = false

    private let kolone = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        ZStack {
            Papir()
            if let greska {
                VStack(spacing: 14) {
                    Naslov(tekst: "Reči nisu stigle", velicina: 26)
                    Text(greska).font(.tekst(15)).foregroundStyle(Color.sivaTekst).multilineTextAlignment(.center)
                    Button("Nazad") { zatvori() }.buttonStyle(.primarno)
                }
                .padding(24).mirna().padding(24)
            } else if let rec {
                ScrollView { sadrzaj(rec).padding(16) }
            } else {
                ProgressView().controlSize(.large).tint(.mastilo)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task { await ucitaj() }
        .onChange(of: igra.status) { _, s in if s != .igra { Task { await sacuvaj() } } }
    }

    private func sadrzaj(_ r: Rec) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                KrugDugme(ikonica: "xmark", opis: "Izađi") { zatvori() }
                Spacer()
                HStack(spacing: 4) {
                    ForEach(0..<Vesanje.pocetniZivoti, id: \.self) { i in
                        Image(systemName: i < igra.zivoti ? "heart.fill" : "heart").foregroundStyle(i < igra.zivoti ? Color.crvena : Color.kremTamnija)
                    }
                }
                .accessibilityElement(children: .ignore).accessibilityLabel("\(igra.zivoti) života")
                Text("\(igra.poeni)").font(.naslov(22)).monospacedDigit().padding(.leading, 8)
            }
            VStack(alignment: .leading, spacing: 12) {
                if let k = r.category { Oznaka(tekst: k, boja: .mastilo) }
                if let h = r.hint { Text(h).font(.tekst(17, .semibold)) }
                FlowReci(znakovi: igra.prikaz)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .accessibilityLabel(igra.prikaz.map { $0 == "_" ? "prazno" : $0 }.joined(separator: " "))
            }
            .padding(20).pop(.zuta)

            if igra.status == .igra {
                LazyVGrid(columns: kolone, spacing: 6) {
                    ForEach(Vesanje.azbuka, id: \.self) { s in
                        let iskorisceno = igra.iskorisceno(s)
                        Button { igra.pogodi(s) } label: {
                            Text(s).font(.tekst(17, .bold)).frame(maxWidth: .infinity, minHeight: 46)
                                .foregroundStyle(iskorisceno ? Color.sivaTekst : Color.mastilo)
                                .background(iskorisceno ? Color.kremTamnija : Color.kartica, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(iskorisceno ? Color.clear : Color.mastilo, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain).disabled(iskorisceno)
                    }
                }
                if celaRec {
                    HStack(spacing: 10) {
                        TextField("Cela reč", text: $pokusajReci).font(.tekst(16)).padding(14)
                            .background(Color.kartica, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mastilo, lineWidth: 1.5))
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                        Button("Pogodi") { igra.pogodiRec(pokusajReci); pokusajReci = ""; celaRec = false }.buttonStyle(.primarno).frame(width: 110)
                    }
                    Text("Pogrešna cela reč odnosi 2 života.").font(.tekst(13)).foregroundStyle(Color.sivaTekst)
                } else {
                    HStack(spacing: 10) {
                        Button("Pogodi celu reč") { celaRec = true }.buttonStyle(.sekundarno)
                        PomocDugme(vrsta: "slovo", ikonica: "character.cursor.ibeam", naziv: "Otkrij slovo", iskoriscenaUPartiji: $pomocIskoriscena) { igra.otkrijSlovo() }
                            .frame(width: 70)
                    }
                    PomocNapomena(iskoriscenaUPartiji: pomocIskoriscena)
                }
            } else {
                VStack(spacing: 12) {
                    Text(igra.status == .pobeda ? "Bravo!" : "Kraj igre").font(.naslov(30))
                    Text(igra.status == .pobeda ? "Pogodio/la si: \(r.word.uppercased())" : "Reč je bila: \(r.word.uppercased())").font(.tekst(16, .semibold))
                    if !sesija.prijavljen { Text("Prijavi se da rezultat ode na rang listu.").font(.tekst(14)).foregroundStyle(Color.sivaTekst) }
                    Button("Sledeća reč") { sledeca() }.buttonStyle(.zuto)
                }
                .padding(20).pop(igra.status == .pobeda ? .tealSvetla : .crvenaSvetla)
            }
        }
    }

    private func ucitaj() async {
        do { reci = try await PaketPitanja.deljeni.reci(); sledeca() } catch { greska = error.localizedDescription }
    }

    private func sledeca() {
        guard !reci.isEmpty else { return }
        let r = reci[indeks % reci.count]
        indeks += 1
        rec = r
        igra = Vesanje(rec: r.word)
        pocetak = Date()
        sacuvano = false
        celaRec = false
        pomocIskoriscena = false
    }

    private func sacuvaj() async {
        guard !sacuvano, let r = rec else { return }
        sacuvano = true
        zavrsiPartiju(napredak, sesija, igra: "vesanje", poeni: igra.poeni, tacnih: igra.status == .pobeda ? 1 : 0, netacnih: igra.status == .pobeda ? 0 : 1)
        guard let id = sesija.korisnikId, let token = try? await sesija.vazeciToken() else { return }
        try? await Supabase.deljeni.upisi("hangman_sessions",
            igra.red(korisnik: id, recId: r.id, hint: r.hint, kategorija: r.category, sekundi: Int(Date().timeIntervalSince(pocetak))), token: token)
    }
}

/// Polja reči u redovima koji se prelamaju između reči višečlanog pojma.
private struct FlowReci: View {
    let znakovi: [String]
    var body: some View {
        let reci = znakovi.split(separator: " ", omittingEmptySubsequences: false).map(Array.init)
        VStack(spacing: 10) {
            ForEach(Array(reci.enumerated()), id: \.offset) { _, rec in
                HStack(spacing: 5) {
                    ForEach(Array(rec.enumerated()), id: \.offset) { _, z in
                        Text(z == "_" ? " " : z).font(.naslov(22))
                            .frame(width: 26, height: 36)
                            .overlay(alignment: .bottom) { Rectangle().fill(Color.mastilo).frame(height: 3) }
                    }
                }
            }
        }
    }
}
