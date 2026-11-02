import SwiftUI

/// Postavka partije iz čekaonice (docs/OSVAJANJE-VISE-IGRACA.md).
struct OsvajanjePostavka: Identifiable {
    enum Nacin: String, CaseIterable, Identifiable {
        case jedanNaJedan, timovi, svakoZaSebe
        var id: String { rawValue }
        var naziv: String { switch self { case .jedanNaJedan: "Jedan na jedan"; case .timovi: "Timovi po dvoje"; case .svakoZaSebe: "Svako za sebe" } }
        var opis: String {
            switch self {
            case .jedanNaJedan: "Ti protiv jednog rivala."
            case .timovi: "Dva do šest timova; saigrači dele države i misiju."
            case .svakoZaSebe: "Tri do šest igrača, bez saveza."
            }
        }
        var brojevi: [Int] { switch self { case .jedanNaJedan: [2]; case .timovi: [4, 6, 8, 10, 12]; case .svakoZaSebe: [3, 4, 5, 6] } }
    }
    let id = UUID()
    var nacin: Nacin
    var igraca: Int
    var krugova: Int
    var tezina: Tezina
    var igraci: [NoviIgrac]
    var pocetak: [String: String] = [:]

    static let boje: [UInt32] = [0x12907E, 0xFF5FA2, 0x6D4BC9, 0xF4A33C, 0x6EC3F2, 0xE5385C]
    static let imenaBotova = ["Mimi", "Zig", "Bloop", "Lumi", "Luna", "Max", "Sara", "Đole", "Ana", "Pera", "Mila"]

    /// Mesta za stolom: timovi se smenjuju (A1, B1, C1, A2, B2, C2), čovek je prvi u timu A.
    /// U timu sa botom kapiten je čovek (bot nema profil sa tačnim odgovorima).
    static func mesta(_ nacin: Nacin, _ igraca: Int, ime: String) -> [NoviIgrac] {
        let timova = nacin == .timovi ? igraca / 2 : igraca
        let poTimu = nacin == .timovi ? 2 : 1
        var l: [NoviIgrac] = []
        var bot = 0
        for clan in 0..<poTimu {
            for t in 0..<timova {
                let tim = String(UnicodeScalar(65 + t)!)
                let covek = t == 0 && clan == 0
                let ime = covek ? ime : imenaBotova[bot % imenaBotova.count]
                if !covek { bot += 1 }
                l.append(NoviIgrac(id: covek ? "ti" : "bot\(bot)", ime: ime, boja: boje[t % boje.count], covek: covek, tim: tim, kapiten: clan == 0))
            }
        }
        return l
    }
}

/// Uvod u Osvajanje: način igre, broj igrača, dužina i jačina rivala, pa čekaonica.
struct OsvajanjeUvodView: View {
    @Environment(Sesija.self) private var sesija
    @State private var nacin: OsvajanjePostavka.Nacin = .svakoZaSebe
    @State private var igraca = 3
    @State private var krugova = 12
    @State private var tezina: Tezina = .normalno
    @State private var cekaonica: OsvajanjePostavka?
    @State private var pravila = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZStack(alignment: .bottomTrailing) {
                    Circle().fill(.white.opacity(0.14)).frame(width: 220).offset(x: 70, y: 60)
                    MaskotaSlika(maskota: .mimi, velicina: 110).offset(x: 10, y: 14)
                    VStack(alignment: .leading, spacing: 10) {
                        Oznaka(tekst: "Glavna igra · 2 do 12 igrača", boja: .zuta)
                        Text("Osvajanje\nsveta").font(.naslov(42)).foregroundStyle(.white)
                        Text("Biraš kontinent, dobijaš tajnu misiju i osvajaš svet pitanjem po pitanjem.")
                            .font(.tekst(15, .semibold)).foregroundStyle(.white.opacity(0.9)).padding(.trailing, 100)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(22).clipped().pop(.teal)

                Text("Način igre").font(.tekst(15, .bold))
                VStack(spacing: 10) {
                    ForEach(OsvajanjePostavka.Nacin.allCases) { n in
                        Button { nacin = n; igraca = n.brojevi[0] } label: {
                            HStack(spacing: 12) {
                                Image(systemName: n == .timovi ? "person.2.fill" : n == .jedanNaJedan ? "person.fill" : "person.3.fill")
                                    .font(.system(size: 18, weight: .bold)).frame(width: 44, height: 44)
                                    .background(nacin == n ? Color.zuta : Color.udubljeno, in: RoundedRectangle(cornerRadius: 12))
                                    .foregroundStyle(Color.tinta)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(n.naziv).font(.tekst(16, .bold))
                                    Text(n.opis).font(.tekst(13)).foregroundStyle(Color.sivaTekst)
                                }
                                Spacer()
                            }
                            .foregroundStyle(Color.mastilo).padding(12)
                            .background(Color.kartica, in: RoundedRectangle(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(nacin == n ? Color.mastilo : Color.kremTamnija, lineWidth: nacin == n ? 2.5 : 1.5))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(nacin == n ? .isSelected : [])
                    }
                }
                if nacin.brojevi.count > 1 {
                    Text("Igrača").font(.tekst(15, .bold))
                    PodvuceniIzbor(izbor: $igraca, opcije: nacin.brojevi.map { ($0, "\($0)") })
                }
                Text("Dužina").font(.tekst(15, .bold))
                PodvuceniIzbor(izbor: $krugova, opcije: [(8, "8 krugova"), (12, "12 krugova")])
                Text("Jačina botova na praznim mestima").font(.tekst(15, .bold))
                PodvuceniIzbor(izbor: $tezina, opcije: Tezina.allCases.map { ($0, $0.ime) })
                Button("Otvori čekaonicu") {
                    cekaonica = OsvajanjePostavka(nacin: nacin, igraca: igraca, krugova: krugova, tezina: tezina,
                                                  igraci: OsvajanjePostavka.mesta(nacin, igraca, ime: sesija.nadimak ?? "Ti"))
                }
                .buttonStyle(.primarno)
                Button("Kako se igra") { pravila = true }.buttonStyle(.sekundarno)
            }
            .padding(16)
        }
        .background(Papir())
        .navigationTitle("Osvajanje")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .overlay { if pravila, let s = KvizKatalog.stavka("osvajanje") { PravilaList(stavka: s) { pravila = false } } }
        .fullScreenCover(item: $cekaonica) { p in CekaonicaView(postavka: p) }
    }
}

/// Čekaonica: mesta i timovi, kapiten (kruna), pa izbor kontinenata „zmijom” i start.
struct CekaonicaView: View {
    @Environment(\.dismiss) private var zatvori
    @State var postavka: OsvajanjePostavka
    @State private var korak: Korak = .mesta
    @State private var redIzbora: [String] = []
    @State private var igra: OsvajanjePostavka?

    enum Korak { case mesta, kontinenti }

    private var timovi: [String] {
        var l: [String] = []
        for p in postavka.igraci where !l.contains(p.tim ?? p.id) { l.append(p.tim ?? p.id) }
        return l
    }
    private var mojTim: String { postavka.igraci.first(where: \.covek)?.tim ?? "A" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GornjaTraka(ikonica: "xmark")
                switch korak {
                case .mesta: mesta
                case .kontinenti: kontinenti
                }
            }
            .padding(16)
        }
        .background(Papir())
        .fullScreenCover(item: $igra) { p in OsvajanjeIgraView(model: OsvajanjeModel(postavka: p)) }
    }

    private var mesta: some View {
        VStack(alignment: .leading, spacing: 14) {
            Naslov(tekst: "Čekaonica", velicina: 34)
            Text("\(postavka.nacin.naziv) · \(postavka.igraca) igrača · \(postavka.krugova) krugova").font(.tekst(14, .semibold)).foregroundStyle(Color.sivaTekst)
            ForEach(timovi, id: \.self) { t in
                VStack(alignment: .leading, spacing: 8) {
                    if postavka.nacin == .timovi { Oznaka(tekst: t == mojTim ? "Tvoj tim" : "Tim \(t)") }
                    ForEach(postavka.igraci.filter { ($0.tim ?? $0.id) == t }, id: \.id) { p in
                        HStack(spacing: 12) {
                            Circle().fill(Color(hex: p.boja)).frame(width: 14, height: 14).overlay(Circle().stroke(Color.mastilo, lineWidth: 1.5))
                            Text(p.ime).font(.tekst(16, .semibold))
                            if p.kapiten && postavka.nacin == .timovi { Image(systemName: "crown.fill").foregroundStyle(Color.zuta).accessibilityLabel("Kapiten") }
                            Spacer()
                            Text(p.covek ? "ti" : "bot").font(.tekst(12, .bold)).foregroundStyle(Color.sivaTekst)
                        }
                        .padding(12).mirna()
                    }
                }
            }
            if postavka.nacin == .timovi {
                Label("Kapiten bira odbranu osvojenog kontinenta. Kapiten je član sa više tačnih odgovora na profilu.", systemImage: "crown")
                    .font(.tekst(13, .semibold)).foregroundStyle(Color.sivaTekst)
            }
            Label("Prazna mesta su popunjena botovima. Pozivanje pravih igrača kodom stiže sa serverom za igru više igrača.", systemImage: "info.circle")
                .font(.tekst(13, .semibold)).foregroundStyle(Color.sivaTekst)
            Button("Kreni: izbor kontinenata") {
                redIzbora = Stanje.redosledIzbora(timovi.shuffled())
                withAnimation { korak = .kontinenti }
                Task { await botoviBiraju() }
            }
            .buttonStyle(.primarno)
        }
    }

    private var kontinenti: some View {
        let naRedu = redIzbora.first { postavka.pocetak[$0] == nil }
        return VStack(alignment: .leading, spacing: 12) {
            Naslov(tekst: "Izbor kontinenta", velicina: 30)
            Text(naRedu == nil ? "Svi su izabrali." : naRedu == mojTim ? "Ti biraš. Na njemu je tvoja prestonica i prvih 6 država." : "Bira \(imeTima(naRedu!))…")
                .font(.tekst(15, .semibold)).foregroundStyle(naRedu == mojTim ? Color.mastilo : Color.sivaTekst)
            Text("Redosled: " + redIzbora.map(imeTima).joined(separator: " → ")).font(.tekst(12)).foregroundStyle(Color.sivaTekst)
            ForEach(Kontinenti.svi, id: \.id) { k in
                let zauzeo = postavka.pocetak.first { $0.value == k.id }?.key
                Button {
                    guard naRedu == mojTim, zauzeo == nil else { return }
                    postavka.pocetak[mojTim] = k.id
                    Task { await botoviBiraju() }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "globe.europe.africa").font(.system(size: 18, weight: .semibold)).frame(width: 40, height: 40)
                            .background(zauzeo.map { t in Color(hex: boja(t)) } ?? Color.udubljeno, in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(k.ime).font(.tekst(16, .bold))
                            Text("\(Kontinenti.oblasti(k.id).count) država · \(k.regioni.count) \(k.regioni.count == 1 ? "region" : "regiona")").font(.tekst(12)).foregroundStyle(Color.sivaTekst)
                        }
                        Spacer()
                        if let z = zauzeo { Text(imeTima(z)).font(.tekst(13, .bold)) }
                    }
                    .foregroundStyle(Color.mastilo).padding(12)
                    .background(Color.kartica, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.kremTamnija, lineWidth: 1.5))
                    .opacity(zauzeo != nil ? 0.6 : 1)
                }
                .buttonStyle(.plain)
                .disabled(naRedu != mojTim || zauzeo != nil)
            }
            if naRedu == nil {
                Button("Počni partiju") { igra = postavka }.buttonStyle(.primarno)
            }
        }
    }

    private func imeTima(_ t: String) -> String {
        if t == mojTim { return postavka.nacin == .timovi ? "tvoj tim" : "ti" }
        let clanovi = postavka.igraci.filter { ($0.tim ?? $0.id) == t }.map(\.ime)
        return postavka.nacin == .timovi ? "tim \(t)" : clanovi.first ?? t
    }
    private func boja(_ t: String) -> UInt32 { postavka.igraci.first { ($0.tim ?? $0.id) == t }?.boja ?? 0xDDD6C6 }

    /// Botovi biraju redom dok ne dođe red na čoveka (nasumično od slobodnih, uz kratku pauzu).
    private func botoviBiraju() async {
        while let t = redIzbora.first(where: { postavka.pocetak[$0] == nil }), t != mojTim {
            try? await Task.sleep(for: .milliseconds(700))
            let slobodni = Kontinenti.svi.map(\.id).filter { k in !postavka.pocetak.values.contains(k) }
            guard let k = slobodni.randomElement() else { return }
            withAnimation { postavka.pocetak[t] = k }
        }
    }
}
