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
    /// Id kontinenta kad se igra samo na njemu (1 na 1 ili protiv računara); nil = ceo svet.
    var teren: String? = nil
    /// Pravi igrači se traže preko servera (sobe); inače su prazna mesta botovi odmah.
    var traziIgrace = false

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
    /// nil = ceo svet (čekaju se igrači), inače kontinent za 1 na 1 ili igru protiv računara.
    @State private var teren: String?
    @State private var protivRacunara = true
    @State private var krugova = 12
    @State private var tezina: Tezina = .normalno
    @State private var cekaonica: OsvajanjePostavka?
    /// Kontinent protiv računara kreće odmah, bez čekaonice.
    @State private var odmah: OsvajanjePostavka?
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

                Text("Gde se igra").font(.tekst(15, .bold))
                PodvuceniIzbor(izbor: Binding(get: { teren == nil }, set: { svet in
                    teren = svet ? nil : (teren ?? "evr")
                    if svet { nacin = .svakoZaSebe; igraca = 3 }
                }), opcije: [(true, "Ceo svet"), (false, "Jedan kontinent")])
                if let izabran = teren {
                    Text("Kontinent").font(.tekst(15, .bold))
                    VStack(spacing: 8) {
                        ForEach(Kontinenti.svi, id: \.id) { k in
                            izborReda(ikonica: "globe.europe.africa", naslov: k.ime,
                                      opis: "\(Kontinenti.oblasti(k.id).count) država", izabrano: izabran == k.id) { teren = k.id }
                        }
                    }
                    Text("Protivnik").font(.tekst(15, .bold))
                    VStack(spacing: 8) {
                        izborReda(ikonica: "cpu", naslov: "Protiv računara", opis: "Odmah, bez čekanja.", izabrano: protivRacunara) { protivRacunara = true }
                        izborReda(ikonica: "person.fill", naslov: "Jedan na jedan", opis: "Pravi rival na istom kontinentu.", izabrano: !protivRacunara) { protivRacunara = false }
                    }
                } else {
                    Text("Način igre").font(.tekst(15, .bold))
                    VStack(spacing: 8) {
                        ForEach(OsvajanjePostavka.Nacin.allCases) { n in
                            izborReda(ikonica: n == .timovi ? "person.2.fill" : n == .jedanNaJedan ? "person.fill" : "person.3.fill",
                                      naslov: n.naziv, opis: n.opis, izabrano: nacin == n) { nacin = n; igraca = n.brojevi[0] }
                        }
                    }
                    if nacin.brojevi.count > 1 {
                        Text("Igrača").font(.tekst(15, .bold))
                        PodvuceniIzbor(izbor: $igraca, opcije: nacin.brojevi.map { ($0, "\($0)") })
                    }
                }
                Text("Dužina").font(.tekst(15, .bold))
                PodvuceniIzbor(izbor: $krugova, opcije: [(8, "8 krugova"), (12, "12 krugova")])
                Text(teren != nil && protivRacunara ? "Jačina računara" : "Jačina botova na praznim mestima").font(.tekst(15, .bold))
                PodvuceniIzbor(izbor: $tezina, opcije: Tezina.allCases.map { ($0, $0.ime) })
                Button("Igraj") {
                    let n: OsvajanjePostavka.Nacin = teren == nil ? nacin : .jedanNaJedan
                    let broj = teren == nil ? igraca : 2
                    let p = OsvajanjePostavka(nacin: n, igraca: broj, krugova: krugova, tezina: tezina,
                                              igraci: OsvajanjePostavka.mesta(n, broj, ime: sesija.nadimak ?? "Ti"),
                                              teren: teren, traziIgrace: !(teren != nil && protivRacunara))
                    if p.traziIgrace { cekaonica = p } else { odmah = p }
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
        .fullScreenCover(item: $odmah) { p in OsvajanjeIgraView(model: OsvajanjeModel(postavka: p)) }
    }

    private func izborReda(ikonica: String, naslov: String, opis: String, izabrano: Bool, radnja: @escaping () -> Void) -> some View {
        Button(action: radnja) {
            HStack(spacing: 12) {
                Image(systemName: ikonica).font(.system(size: 18, weight: .bold)).frame(width: 44, height: 44)
                    .background(izabrano ? Color.zuta : Color.udubljeno, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(Color.tinta)
                VStack(alignment: .leading, spacing: 2) {
                    Text(naslov).font(.tekst(16, .bold))
                    Text(opis).font(.tekst(13)).foregroundStyle(Color.sivaTekst)
                }
                Spacer()
            }
            .foregroundStyle(Color.mastilo).padding(12)
            .background(Color.kartica, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(izabrano ? Color.mastilo : Color.kremTamnija, lineWidth: izabrano ? 2.5 : 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(izabrano ? .isSelected : [])
    }
}

/// Čekaonica: mesta i timovi, kapiten (kruna), pa izbor kontinenata „zmijom” i start.
struct CekaonicaView: View {
    @Environment(\.dismiss) private var zatvori
    @Environment(Sesija.self) private var sesija
    @State var postavka: OsvajanjePostavka
    @State private var soba: Soba?
    @State private var greskaSobe: String?
    @State private var cekamOd = Date()

    /// Soba sa servera (scripts/2026-11-02_osvajanje-sobe.sql).
    struct Soba: Decodable, Equatable {
        struct Mesto: Decodable, Equatable { let user_id: String; let mesto: Int; let nadimak: String; let avatar: String? }
        let id: String
        let velicina: Int
        let status: String
        let mesta: [Mesto]
    }
    /// Kratko čekanje: ko stigne u tih 10 s igra zajedno, ostalo su botovi; sledeći igrač dobija novu sobu.
    private static let cekanjePreBotova: TimeInterval = 10
    private var cekaIgrace: Bool { postavka.traziIgrace && soba?.status != "pocela" }
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
        .task { if postavka.traziIgrace { await traziSobu() } }
        .onAppear { Zvuk.pusti(.cekanje, jacina: 0.2, ponavljaj: true) }
        .onDisappear { Zvuk.stani(.cekanje) }
        .onChange(of: igra == nil) { _, nema in if nema { Zvuk.pusti(.cekanje, jacina: 0.2, ponavljaj: true) } else { Zvuk.stani(.cekanje) } }
    }

    private var mesta: some View {
        VStack(alignment: .leading, spacing: 14) {
            Naslov(tekst: cekaIgrace ? "Spajamo te sa igračima" : "Čekaonica", velicina: 34)
            Text(opisPartije).font(.tekst(14, .semibold)).foregroundStyle(Color.sivaTekst)
            if cekaIgrace {
                serverskaMesta
            } else {
                ForEach(timovi, id: \.self) { t in
                    VStack(alignment: .leading, spacing: 8) {
                        if postavka.nacin == .timovi { Oznaka(tekst: t == mojTim ? "Tvoj tim" : "Tim \(t)") }
                        ForEach(postavka.igraci.filter { ($0.tim ?? $0.id) == t }, id: \.id) { p in
                            HStack(spacing: 12) {
                                Circle().fill(Color(hex: p.boja)).frame(width: 14, height: 14).overlay(Circle().stroke(Color.mastilo, lineWidth: 1.5))
                                Text(p.ime).font(.tekst(16, .semibold))
                                if p.kapiten && postavka.nacin == .timovi { Image(systemName: "crown.fill").foregroundStyle(Color.zuta).accessibilityLabel("Kapiten") }
                                Spacer()
                                Image(systemName: p.covek ? "person.fill" : pravi(p) ? "person.wave.2" : "cpu").foregroundStyle(Color.sivaTekst)
                                    .accessibilityLabel(p.covek ? "ti" : pravi(p) ? "igrač" : "bot")
                            }
                            .padding(12).mirna()
                        }
                    }
                }
                if postavka.nacin == .timovi {
                    Label("Kapiten bira odbranu osvojenog kontinenta. Kapiten je član sa više tačnih odgovora na profilu.", systemImage: "crown")
                        .font(.tekst(13, .semibold)).foregroundStyle(Color.sivaTekst)
                }
                Button(postavka.teren == nil ? "Kreni: izbor kontinenata" : "Počni partiju") {
                    if postavka.teren != nil { igra = postavka; return }
                    redIzbora = Stanje.redosledIzbora(timovi.shuffled())
                    withAnimation { korak = .kontinenti }
                    Task { await botoviBiraju() }
                }
                .buttonStyle(.primarno)
            }
        }
    }

    private var opisPartije: String {
        let gde = postavka.teren.map { k in Kontinenti.svi.first { $0.id == k }?.ime ?? k } ?? "Ceo svet"
        return "\(gde) · \(postavka.nacin.naziv) · \(postavka.igraca) igrača · \(postavka.krugova) krugova"
    }

    private func pravi(_ p: NoviIgrac) -> Bool { p.id.hasPrefix("igrac") }

    /// Čekanje na igrače: server sam raspoređuje (igrač ne vidi sobe), ovde samo koliko ih je već tu.
    /// Posle 10 s čekanja partija sama kreće, a prazna mesta popunjavaju botovi.
    private var serverskaMesta: some View {
        TimelineView(.periodic(from: .now, by: 1)) { kontekst in
            let proslo = kontekst.date.timeIntervalSince(cekamOd)
            VStack(spacing: 16) {
                if let greskaSobe {
                    Label(greskaSobe, systemImage: "wifi.exclamationmark").font(.tekst(14, .semibold)).foregroundStyle(Color.crvena)
                    Button("Igraj sa botovima") { postavka.traziIgrace = false }.buttonStyle(.primarno)
                } else {
                    let ima = soba?.mesta.count ?? 1
                    MaskotaSlika(maskota: .zig, velicina: 120).padding(.top, 20)
                    Text("\(ima) od \(postavka.igraca) igrača").font(.naslov(30)).monospacedDigit()
                    HStack(spacing: -10) {
                        ForEach(soba?.mesta ?? [], id: \.user_id) { m in AvatarSlika(avatar: m.avatar, velicina: 40) }
                    }
                    Text(proslo < Self.cekanjePreBotova
                         ? "Partija kreće čim se skupe igrači, najkasnije za \(Int(Self.cekanjePreBotova - proslo)) s."
                         : "Krećemo, prazna mesta preuzimaju botovi…")
                        .font(.tekst(14, .semibold)).foregroundStyle(Color.sivaTekst).multilineTextAlignment(.center).monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Server

    private func traziSobu() async {
        guard let token = try? await sesija.vazeciToken() else { greskaSobe = "Prijavi se da bi igrao sa drugim igračima."; return }
        cekamOd = Date()
        do {
            let s: Soba = try await Supabase.deljeni.rpc("osvajanje_trazi_sobu",
                ["p_nacin": postavka.nacin.rawValue, "p_velicina": postavka.igraca, "p_teren": postavka.teren as Any? ?? NSNull()], token: token)
            primi(s)
            while !Task.isCancelled, soba?.status == "ceka" {
                try await Task.sleep(for: .seconds(2))
                // Posle 10 s čekanja traži se start sa botovima; server ga dozvoljava tek kad soba čeka toliko.
                let funkcija = Date().timeIntervalSince(cekamOd) > Self.cekanjePreBotova ? "osvajanje_pokreni" : "osvajanje_soba"
                if let nova: Soba = try? await Supabase.deljeni.rpc(funkcija, ["p_soba": s.id], token: token) { primi(nova) }
            }
            // Zatvorena čekaonica pre početka: mesto se oslobađa za druge.
            if Task.isCancelled, let id = soba?.id, soba?.status == "ceka" {
                let _: String? = try? await Supabase.deljeni.rpc("osvajanje_napusti", ["p_soba": id], token: token)
            }
        } catch is CancellationError {
            if let id = soba?.id, soba?.status == "ceka" { let _: String? = try? await Supabase.deljeni.rpc("osvajanje_napusti", ["p_soba": id], token: token) }
        } catch {
            greskaSobe = "Server za sobe se ne javlja. Probaj ponovo ili igraj sa botovima."
        }
    }

    /// Pravi igrači sedaju na mesta botova redom; čovek (ti) ostaje prvi u svom timu.
    /// shortcut: potezi drugih igrača se još ne šalju preko servera, pa ih u partiji vodi bot sa njihovim imenom; sledeći korak je sinhronizacija poteza.
    private func primi(_ s: Soba) {
        soba = s
        guard s.status == "pocela" else { return }
        let drugi = s.mesta.filter { $0.user_id != sesija.korisnikId }
        var i = 0
        postavka.igraci = postavka.igraci.map { p in
            guard !p.covek, i < drugi.count else { return p }
            defer { i += 1 }
            return NoviIgrac(id: "igrac\(i)", ime: drugi[i].nadimak, boja: p.boja, covek: false, tim: p.tim, kapiten: p.kapiten)
        }
        Zvuk.pusti(.bedz, jacina: 0.4)
        // Igrači su na okupu: kontinent se igra odmah, ceo svet ide na izbor kontinenata.
        if postavka.teren != nil { igra = postavka; return }
        redIzbora = Stanje.redosledIzbora(timovi.shuffled())
        withAnimation { korak = .kontinenti }
        Task { await botoviBiraju() }
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
