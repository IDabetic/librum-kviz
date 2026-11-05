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
            case .svakoZaSebe: "Tri do šest igrača, svako svoja boja; saveznik po izboru."
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
    /// Partija sa pravim igračima: soba, moj nalog i da li sam domaćin (mesto 0, vodi botove).
    var soba: String? = nil
    var korisnik: String? = nil
    var domacin = false

    static let boje: [UInt32] = [0x12907E, 0xFF5FA2, 0x6D4BC9, 0xF4A33C, 0x6EC3F2, 0xE5385C]
    static let imenaBotova = ["Mimi", "Zig", "Bloop", "Lumi", "Luna", "Max", "Sara", "Đole", "Ana", "Pera", "Mila"]

    /// Mesta za stolom: timovi se smenjuju (A1, B1, C1, A2, B2, C2), čovek je prvi u timu A.
    /// U timu sa botom kapiten je čovek (bot nema profil sa tačnim odgovorima).
    /// Savez (vlasnik 04.11): isti tim postaje strana, a svaki igrač dobija svoj tim, boju i vojsku (kapiten je svako za sebe).
    static func uSavez(_ igraci: [NoviIgrac]) -> [NoviIgrac] {
        igraci.enumerated().map { i, p in
            var p = p
            p.strana = p.tim ?? "A"
            p.tim = String(UnicodeScalar(65 + i)!)
            p.boja = boje[i % boje.count]
            p.kapiten = true
            return p
        }
    }

    /// Ima li tim sa dvoje ili više (tada se bira savez ili zajedno).
    static func imaZajednickihTimova(_ timovi: [String]) -> Bool { Set(timovi).count < timovi.count }

    /// Posle promene timova: boja po timu, kapiten je prvi čovek u timu (inače prvi član).
    static func sredi(_ igraci: [NoviIgrac]) -> [NoviIgrac] {
        igraci.map { p in
            var p = p
            let tim = p.tim ?? "A"
            let clanovi = igraci.filter { ($0.tim ?? "A") == tim }
            p.boja = boje[(Int(tim.unicodeScalars.first!.value) - 65) % boje.count]
            p.kapiten = (clanovi.first(where: \.covek) ?? clanovi.first)?.id == p.id
            return p
        }
    }

    static func mesta(_ nacin: Nacin, _ igraca: Int, ime: String, vojska: VrstaVojske? = nil) -> [NoviIgrac] {
        let timova = nacin == .timovi ? igraca / 2 : igraca
        let poTimu = nacin == .timovi ? 2 : 1
        var l: [NoviIgrac] = []
        var bot = 0
        // Imena botova se mešaju svake partije (Mimi nije uvek prvi rival).
        let imenaBotova = imenaBotova.shuffled()
        for clan in 0..<poTimu {
            for t in 0..<timova {
                let tim = String(UnicodeScalar(65 + t)!)
                let covek = t == 0 && clan == 0
                let ime = covek ? ime : imenaBotova[bot % imenaBotova.count]
                if !covek { bot += 1 }
                l.append(NoviIgrac(id: covek ? "ti" : "bot\(bot)", ime: ime, boja: boje[t % boje.count], covek: covek, tim: tim, kapiten: clan == 0,
                                   vojska: covek ? vojska : nil))
            }
        }
        return l
    }
}

/// Uvod u Osvajanje (preuređeno 04.11.2026): prvo protiv koga igraš, pa samo ono što taj izbor traži;
/// dugme za start stoji uvek dole, pa se ne traži skrolovanjem.
struct OsvajanjeUvodView: View {
    @Environment(Sesija.self) private var sesija
    enum Protivnik: String, CaseIterable { case racunar, prijatelji, mreza }
    @AppStorage("osvajanje.protivnik") private var protivnik: Protivnik = .racunar
    @State private var nacin: OsvajanjePostavka.Nacin = .svakoZaSebe
    @State private var igraca = 3
    /// nil = ceo svet, inače kontinent (uvek jedan na jedan).
    @State private var teren: String?
    @State private var krugova = 12
    @State private var tezina: Tezina = .normalno
    @State private var cekaonica: OsvajanjePostavka?
    /// Kontinent protiv računara kreće odmah, bez čekaonice.
    @State private var odmah: OsvajanjePostavka?
    @State private var pravila = false
    /// Partija na poziv: domaćin pravi sobu, gost ulazi kodom.
    @State private var poziv: OsvajanjePostavka?
    @State private var kodUlaz: KodSobe?
    @State private var kodTekst = ""
    struct KodSobe: Identifiable { let id: String }
    /// Vrsta vojske (strategija) za ovu partiju; pamti se do sledeće.
    @AppStorage("osvajanje.vojska") private var vojska: VrstaVojske = .legija
    /// Vlasnik 04.11 uveče: sam, u savezu ili zajedno i sa botovima, izbor odmah na podešavanju (ranije skriven iza timova u čekaonici).
    enum Saveznik: String, CaseIterable { case bez, savez, zajedno }
    @AppStorage("osvajanje.saveznik") private var saveznik: Saveznik = .bez

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GornjaTraka {
                    KrugDugme(ikonica: "questionmark", opis: "Kako se igra") { pravila = true }
                }
                zaglavlje
                sekcija("Protiv koga") {
                    VStack(spacing: 8) {
                        izborReda(ikonica: "cpu", naslov: "Protiv računara", opis: "Odmah, ti i botovi.", izabrano: protivnik == .racunar) { protivnik = .racunar }
                        izborReda(ikonica: "person.2.fill", naslov: "Sa prijateljima", opis: "Pozovi ih kodom; sami birate timove.", izabrano: protivnik == .prijatelji) { protivnik = .prijatelji }
                        izborReda(ikonica: "globe", naslov: "Sa igračima sa mreže", opis: "Spajamo te sa drugima, prazna mesta su botovi.", izabrano: protivnik == .mreza) { protivnik = .mreza }
                    }
                    if protivnik == .prijatelji { unosKoda }
                }
                sekcija("Gde se igra") {
                    PodvuceniIzbor(izbor: Binding(get: { teren == nil }, set: { svet in teren = svet ? nil : (teren ?? "evr") }),
                                   opcije: [(true, "Ceo svet"), (false, "Jedan kontinent")])
                    if let izabran = teren {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                            ForEach(Kontinenti.svi, id: \.id) { k in
                                Button { teren = k.id } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(k.ime).font(.tekst(15, .bold)).lineLimit(1).minimumScaleFactor(0.8)
                                        Text("\(Kontinenti.oblasti(k.id).count) država").font(.tekst(12)).foregroundStyle(Color.sivaTekst)
                                    }
                                    .foregroundStyle(Color.mastilo).padding(12).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.kartica, in: RoundedRectangle(cornerRadius: 14))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(izabran == k.id ? Color.mastilo : Color.kremTamnija, lineWidth: izabran == k.id ? 2.5 : 1.5))
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(izabran == k.id ? .isSelected : [])
                            }
                        }
                        Text("Na jednom kontinentu igra se jedan na jedan: pobeđuje ko ga ceo osvoji.").font(.tekst(13)).foregroundStyle(Color.sivaTekst)
                    }
                }
                if teren == nil {
                    sekcija("Način igre") {
                        VStack(spacing: 8) {
                            ForEach(OsvajanjePostavka.Nacin.allCases) { n in
                                izborReda(ikonica: n == .timovi ? "person.2.fill" : n == .jedanNaJedan ? "person.fill" : "person.3.fill",
                                          naslov: n.naziv, opis: n.opis, izabrano: nacin == n) { nacin = n; igraca = n.brojevi[0] }
                            }
                        }
                        if nacin.brojevi.count > 1 {
                            Text("Igrača").font(.tekst(14, .bold)).padding(.top, 4)
                            PodvuceniIzbor(izbor: $igraca, opcije: nacin.brojevi.map { ($0, "\($0)") })
                        }
                    }
                    if protivnik == .racunar && nacin != .jedanNaJedan { izborSaveznika }
                }
                sekcija("Tvoja vojska") {
                    Text("Svaka vojska igra drugačije. Rivali biraju svoju prema naravi.").font(.tekst(13)).foregroundStyle(Color.sivaTekst)
                    IzborVojske(vojska: $vojska)
                }
                sekcija("Dužina") {
                    // Vlasnik 03.11: sa šestoro 12 krugova nije dovoljno za misiju; dužina prati broj igrača, a može se promeniti.
                    PodvuceniIzbor(izbor: $krugova, opcije: [(12, "12 krugova"), (20, "20"), (30, "30")])
                    Text(krugova >= 30 ? "Duga partija: ima vremena za misiju i sa šestoro." : krugova >= 20 ? "Srednja partija." : "Kratka partija: misije su teško dostižne sa više od troje.")
                        .font(.tekst(13)).foregroundStyle(Color.sivaTekst)
                }
                sekcija(protivnik == .racunar ? "Jačina računara" : "Jačina botova na praznim mestima") {
                    PodvuceniIzbor(izbor: $tezina, opcije: Tezina.allCases.map { ($0, $0.ime) })
                }
            }
            .padding(16)
        }
        .safeAreaInset(edge: .bottom) {
            Button(nazivDugmeta) { igraj() }
                .buttonStyle(.primarno)
                .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 6)
                .background(Papir().ignoresSafeArea(edges: .bottom))
        }
        .background(Papir())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .overlay { if pravila, let s = KvizKatalog.stavka("osvajanje") { PravilaList(stavka: s) { pravila = false } } }
        .fullScreenCover(item: $cekaonica) { p in CekaonicaView(postavka: p) }
        .fullScreenCover(item: $odmah) { p in OsvajanjeIgraView(model: OsvajanjeModel(postavka: p)) }
        .fullScreenCover(item: $poziv) { p in PozivView(postavka: p, kod: nil) }
        .onChange(of: brojIgraca, initial: true) { _, n in krugova = Self.preporucenoKrugova(n) }
        .fullScreenCover(item: $kodUlaz) { k in PozivView(postavka: nil, kod: k.id) }
    }

    /// Sam (saveznika biraš u igri), savez od starta (svako svoja boja) ili zajedno (jedna boja, deljene države).
    private var izborSaveznika: some View {
        sekcija(nacin == .timovi ? "Kako igra tim" : "Tvoj saveznik") {
            VStack(spacing: 8) {
                if nacin != .timovi {
                    izborReda(ikonica: "person.fill", naslov: "Sam, saveznika biram u igri",
                              opis: "Svako za sebe. U igri dodirni dugme Savez gore i predloži savez jednom rivalu.",
                              izabrano: saveznik == .bez) { saveznik = .bez }
                }
                izborReda(ikonica: "link", naslov: nacin == .timovi ? "Saveznici" : "Saveznik od prvog kruga",
                          opis: "Ti i bot, svako svoja boja, vojska, moći i misija. Ne napadate se, šaljete pomoć i pobeđujete zajedno. Savez može da se raskine ili izda.",
                          izabrano: saveznik == .savez) { saveznik = .savez }
                izborReda(ikonica: "person.2.fill", naslov: "Zajedno",
                          opis: "Ti i bot ste jedan tim: jedna boja, jedna vojska, deljene države i zajednička misija.",
                          izabrano: saveznik == .zajedno || (nacin == .timovi && saveznik == .bez)) { saveznik = .zajedno }
            }
        }
    }

    /// Primeni izbor saveznika na mesta za stolom (samo protiv računara).
    static func primeniSaveznika(_ s: Saveznik, _ p: inout OsvajanjePostavka) {
        guard p.nacin != .jedanNaJedan, p.igraci.count >= 3 else { return }
        if p.nacin == .svakoZaSebe {
            guard s != .bez, let bot = p.igraci.firstIndex(where: { !$0.covek }) else { return }
            p.igraci[bot].tim = "A"
            // Preostali timovi idu redom (B, C…), da ne ostane rupa posle tima koji je otišao.
            var slovo = 1
            for i in p.igraci.indices where p.igraci[i].tim != "A" { p.igraci[i].tim = String(UnicodeScalar(65 + slovo)!); slovo += 1 }
            p.igraci = OsvajanjePostavka.sredi(p.igraci)
            p.nacin = .timovi
        }
        if s == .savez {
            p.igraci = OsvajanjePostavka.uSavez(p.igraci)
            p.nacin = .svakoZaSebe
        }
    }

    private var zaglavlje: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                Oznaka(tekst: "Glavna igra · 2 do 12 igrača", boja: .zuta)
                Text("Osvajač").font(.naslov(32)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
                Text("Biraš države, vučeš tajnu misiju i osvajaš svet pitanjem po pitanjem.")
                    .font(.tekst(14, .semibold)).foregroundStyle(.white.opacity(0.9))
            }
            Spacer(minLength: 0)
            MaskotaSlika(maskota: .mimi, velicina: 64).accessibilityHidden(true)
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading).pop(.teal)
    }

    private var unosKoda: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Imaš kod od prijatelja? Uđi u njegovu sobu.").font(.tekst(13, .semibold)).foregroundStyle(Color.sivaTekst)
            HStack(spacing: 10) {
                TextField("KOD SOBE", text: $kodTekst)
                    .textInputAutocapitalization(.characters).autocorrectionDisabled()
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 14).frame(height: 52)
                    .background(Color.kartica, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.kremTamnija, lineWidth: 1.5))
                Button("Uđi") { kodUlaz = KodSobe(id: kodTekst.trimmingCharacters(in: .whitespaces).uppercased()) }
                    .font(.tekst(16, .bold)).foregroundStyle(Color.naMastilu).padding(.horizontal, 20).frame(height: 52)
                    .background(Color.mastilo, in: RoundedRectangle(cornerRadius: 16))
                    .disabled(kodTekst.trimmingCharacters(in: .whitespaces).count < 6)
            }
        }
        .padding(.top, 4)
    }

    private func sekcija<S: View>(_ naslov: String, @ViewBuilder _ sadrzaj: () -> S) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(naslov).font(.tekst(17, .bold)).foregroundStyle(Color.mastilo)
            sadrzaj()
        }
    }

    private var nazivDugmeta: String {
        switch protivnik {
        case .racunar: "Igraj"
        case .prijatelji: "Napravi sobu i pozovi"
        case .mreza: "Traži igrače"
        }
    }

    private func igraj() {
        let n: OsvajanjePostavka.Nacin = teren == nil ? nacin : .jedanNaJedan
        let broj = brojIgraca
        if protivnik == .prijatelji {
            poziv = OsvajanjePostavka(nacin: n, igraca: broj, krugova: krugova, tezina: tezina, igraci: [], teren: teren)
            return
        }
        var p = OsvajanjePostavka(nacin: n, igraca: broj, krugova: krugova, tezina: tezina,
                                  igraci: OsvajanjePostavka.mesta(n, broj, ime: sesija.nadimak ?? "Ti", vojska: vojska),
                                  teren: teren, traziIgrace: protivnik == .mreza)
        if protivnik == .racunar && teren == nil { Self.primeniSaveznika(saveznik, &p) }
        // Kontinent protiv računara kreće odmah; ceo svet ide u čekaonicu (izbor kontinenata), mreža traži sobu.
        if teren != nil && protivnik == .racunar { odmah = p } else { cekaonica = p }
    }

    private var brojIgraca: Int { teren == nil ? igraca : 2 }

    /// Preporučena dužina: misija mora biti dostižna; više strana deli mapu na manje delove i duže traje.
    static func preporucenoKrugova(_ igraca: Int) -> Int { igraca >= 5 ? 30 : igraca == 4 ? 20 : 12 }

    private func izborReda(ikonica: String, naslov: String, opis: String, izabrano: Bool, radnja: @escaping () -> Void) -> some View {
        Button(action: radnja) {
            HStack(spacing: 12) {
                Image(systemName: ikonica).font(.system(size: 18, weight: .bold)).frame(width: 44, height: 44)
                    .background(izabrano ? Color.zuta : Color.udubljeno, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(Color.tinta)
                VStack(alignment: .leading, spacing: 2) {
                    Text(naslov).font(.tekst(16, .bold))
                    Text(opis).font(.tekst(13)).foregroundStyle(Color.sivaTekst).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if izabrano { Image(systemName: "checkmark").font(.system(size: 15, weight: .heavy)).foregroundStyle(Color.mastilo) }
            }
            .foregroundStyle(Color.mastilo).padding(12)
            .background(Color.kartica, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(izabrano ? Color.mastilo : Color.kremTamnija, lineWidth: izabrano ? 2.5 : 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(izabrano ? .isSelected : [])
    }
}

/// Izbor vrste vojske (Uvod i partija na poziv): dve kolone kartica sa herojem, strategijom i moći.
struct IzborVojske: View {
    @Binding var vojska: VrstaVojske

    var body: some View {
        ScrollViewReader { skrol in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(VrstaVojske.allCases) { v in
                        Button { withAnimation { vojska = v } } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Image(v.heroj).resizable().scaledToFit().frame(height: 74).frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(vojska == v ? Color.zuta : Color.udubljeno, in: RoundedRectangle(cornerRadius: 12))
                                    .accessibilityHidden(true)
                                Text(v.naziv).font(.tekst(16, .bold))
                                Text(v.strategija).font(.tekst(12)).foregroundStyle(Color.sivaTekst).fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                                Label(v.moc.naziv, systemImage: v.moc.ikonica).font(.tekst(12, .bold)).foregroundStyle(Color.teal).lineLimit(1)
                                    .accessibilityLabel("Moć u bitki: \(v.moc.naziv). \(v.moc.opis)")
                            }
                            .foregroundStyle(Color.mastilo).padding(10).frame(width: 164, height: 214, alignment: .topLeading)
                            .background(Color.kartica, in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(vojska == v ? Color.mastilo : Color.kremTamnija, lineWidth: vojska == v ? 2.5 : 1.5))
                        }
                        .buttonStyle(.plain)
                        .id(v)
                        .accessibilityAddTraits(vojska == v ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.horizontal, -16)
            .onAppear { skrol.scrollTo(vojska, anchor: .center) }
        }
        // Vlasnik 04.11: dodir na vojsku ispisuje sve njene prednosti i moći.
        MociVojske(vojska: vojska)
    }
}

/// Isti tim igra zajedno (jedna boja i vojska, deljene države) ili u savezu (svako svoja boja, vojska i države, ne napadaju se).
struct IzborSaveza: View {
    @Binding var savez: Bool
    var menja = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Kako igra isti tim").font(.tekst(15, .bold))
            ForEach([false, true], id: \.self) { s in
                Button { if menja { savez = s } } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: s ? "person.2.wave.2.fill" : "person.2.fill").font(.system(size: 17, weight: .bold))
                            .frame(width: 40, height: 40)
                            .background(savez == s ? Color.zuta : Color.udubljeno, in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(Color.tinta)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s ? "Saveznici od prvog kruga" : "Zajedno").font(.tekst(16, .bold))
                            Text(s ? "Svako ima svoju boju, vojsku, moći i misiju. Savez može da se raskine ili izda. Bez ovoga saveznika biraš u igri."
                                   : "Jedna boja, jedna vojska, iste moći i zajednička misija: delite države.")
                                .font(.tekst(13)).foregroundStyle(Color.sivaTekst).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        if savez == s { Image(systemName: "checkmark").font(.system(size: 15, weight: .heavy)) }
                    }
                    .foregroundStyle(Color.mastilo).padding(12)
                    .background(Color.kartica, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(savez == s ? Color.mastilo : Color.kremTamnija, lineWidth: savez == s ? 2.5 : 1.5))
                }
                .buttonStyle(.plain)
                .disabled(!menja)
                .accessibilityAddTraits(savez == s ? .isSelected : [])
            }
        }
    }
}

/// Prednost vojske i njene tri pomoći u bitki (svaka jednom po krugu), sa opisom.
struct MociVojske: View {
    let vojska: VrstaVojske
    var tamno = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(vojska.heroj).resizable().scaledToFit().frame(width: 34, height: 44).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(vojska.naziv).font(.tekst(17, .bold))
                    Text(vojska.strategija).font(.tekst(13)).foregroundStyle(tamno ? Color.white.opacity(0.75) : Color.sivaTekst)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Oznaka(tekst: "Moći u bitki · svaka jednom po krugu", boja: tamno ? .white.opacity(0.7) : .sivaTekst)
            ForEach(vojska.pomoci) { p in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: p.ikonica).font(.system(size: 15, weight: .bold)).foregroundStyle(Color.tinta)
                        .frame(width: 32, height: 32)
                        .background(p.svoja ? Color.zuta : Color.udubljeno, in: RoundedRectangle(cornerRadius: 9))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(p.naziv + (p.svoja ? " · glavna moć" : "")).font(.tekst(14, .bold))
                        Text(p.opis).font(.tekst(13)).foregroundStyle(tamno ? Color.white.opacity(0.75) : Color.sivaTekst)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .foregroundStyle(tamno ? Color.white : Color.mastilo)
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(tamno ? Color.white.opacity(0.08) : Color.kartica, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(tamno ? Color.white.opacity(0.2) : Color.kremTamnija, lineWidth: 1.5))
        .animation(.easeOut(duration: 0.2), value: vojska)
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
        struct Mesto: Decodable, Equatable { let user_id: String; let mesto: Int; let nadimak: String; let avatar: String?; var vojska: String? = nil }
        let id: String
        let velicina: Int
        let status: String
        let mesta: [Mesto]
        var teren: String? = nil
        var nacin: String = "svakoZaSebe"
        /// Privatna soba (partija na poziv): kod za ulazak, PozivView.
        var kod: String? = nil
        var privatna: Bool? = nil
        /// Tim po mestu za stolom (domaćin bira u partiji na poziv); nil = podrazumevano po načinu igre.
        var timovi: [String]? = nil
        /// Isti tim igra u savezu (svako svoja boja) umesto zajedno.
        var savez: Bool? = nil
    }
    /// Kratko čekanje: ko stigne u tih 10 s igra zajedno, ostalo su botovi; sledeći igrač dobija novu sobu.
    private static let cekanjePreBotova: TimeInterval = 10
    private var cekaIgrace: Bool { postavka.traziIgrace && soba?.status != "pocela" }
    @State private var korak: Korak = .mesta
    /// Isti tim: zajedno (jedna boja i vojska, deljene države) ili savez (svako svoja boja i vojska).
    @State private var savez = false
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
        .onReceive(NotificationCenter.default.publisher(for: .novaPartijaOsvajanja)) { _ in zatvori() }
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
                                if postavka.igraci.count > 2 {
                                    Button { promeniTim(p.id) } label: {
                                        Text("Tim \(p.tim ?? "A")").font(.tekst(14, .heavy)).foregroundStyle(Color.tinta)
                                            .padding(.horizontal, 12).frame(height: 36)
                                            .background(Color(hex: p.boja).opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
                                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.mastilo, lineWidth: 1.5))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Tim \(p.tim ?? "A"), dodirni da promeniš")
                                }
                            }
                            .padding(12).mirna()
                        }
                    }
                }
                if postavka.igraci.count > 2 {
                    Text("Dodirni tim pored igrača da sastaviš strane, npr. ti i bot protiv ostalih.")
                        .font(.tekst(13)).foregroundStyle(Color.sivaTekst)
                }
                if OsvajanjePostavka.imaZajednickihTimova(postavka.igraci.map { $0.tim ?? $0.id }) {
                    IzborSaveza(savez: $savez)
                }
                if postavka.nacin == .timovi {
                    Label("Kapiten bira odbranu osvojenog kontinenta. Kapiten je član sa više tačnih odgovora na profilu.", systemImage: "crown")
                        .font(.tekst(13, .semibold)).foregroundStyle(Color.sivaTekst)
                }
                if !imaRivala {
                    Label("Svi su u istom timu: potrebna su bar dva tima.", systemImage: "exclamationmark.triangle").font(.tekst(13, .semibold)).foregroundStyle(Color.crvena)
                }
                Button(postavka.teren == nil ? "Kreni: izbor kontinenata" : "Počni partiju") {
                    if savez && OsvajanjePostavka.imaZajednickihTimova(postavka.igraci.map { $0.tim ?? $0.id }) {
                        postavka.igraci = OsvajanjePostavka.uSavez(postavka.igraci)
                        postavka.nacin = .svakoZaSebe
                    }
                    if postavka.teren != nil { igra = postavka; return }
                    redIzbora = Stanje.redosledIzbora(timovi.shuffled())
                    withAnimation { korak = .kontinenti }
                    Task { await botoviBiraju() }
                }
                .buttonStyle(.primarno)
                .disabled(!imaRivala)
            }
        }
    }

    private var opisPartije: String {
        let gde = postavka.teren.map { k in Kontinenti.svi.first { $0.id == k }?.ime ?? k } ?? "Ceo svet"
        return "\(gde) · \(postavka.nacin == .timovi ? "Timovi" : postavka.nacin.naziv) · \(postavka.igraca) igrača · \(postavka.krugova) krugova"
    }

    private func pravi(_ p: NoviIgrac) -> Bool { p.id.hasPrefix("igrac") }

    /// Dodir vrti tim igrača kroz A…(najviše F); boja ide za timom, kapiten je čovek (ili prvi) u timu,
    /// a način igre postaje „timovi” čim neki tim ima dvoje (vlasnik 04.11: „ja i bot protiv drugih”).
    private func promeniTim(_ id: String) {
        guard let i = postavka.igraci.firstIndex(where: { $0.id == id }) else { return }
        if postavka.igraci.contains(where: { $0.strana != nil }) {
            savez = true
            // Savez od starta je dao svakom svoj tim; vraćaju se zajednički timovi strana pa igrač menja dalje.
            for j in postavka.igraci.indices { postavka.igraci[j].tim = postavka.igraci[j].strana; postavka.igraci[j].strana = nil }
        }
        let slova = min(postavka.igraci.count, 6)
        let sad = Int((postavka.igraci[i].tim ?? "A").unicodeScalars.first!.value) - 65
        postavka.igraci[i].tim = String(UnicodeScalar(65 + (sad + 1) % slova)!)
        postavka.igraci = OsvajanjePostavka.sredi(postavka.igraci)
        let broj = Set(postavka.igraci.compactMap(\.tim)).count
        postavka.nacin = broj == postavka.igraci.count ? (broj == 2 ? .jedanNaJedan : .svakoZaSebe) : .timovi
        postavka.pocetak = [:]
    }

    /// Bar dva tima, inače nema protiv koga.
    private var imaRivala: Bool { Set(postavka.igraci.compactMap(\.tim)).count >= 2 }

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
            // Domaćin pravi početno stanje: mora da zna vojsku svakog igrača (bag 04.11: gost je dobijao vojsku kao bot).
            if let v = postavka.igraci.first(where: \.covek)?.vojska,
               let nova: Soba = try? await Supabase.deljeni.rpc("osvajanje_izaberi_vojsku", ["p_soba": s.id, "p_vojska": v.rawValue], token: token) { primi(nova) }
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
        if let stara = soba, s.mesta.count > stara.mesta.count { Zvuk.pusti(.protivnikUsao, jacina: 0.45) }
        soba = s
        guard s.status == "pocela" else { return }
        let ja = sesija.korisnikId ?? ""
        let drugi = s.mesta.filter { $0.user_id != ja }.sorted { $0.mesto < $1.mesto }
        var i = 0
        // Isti id na svakom telefonu („u:<nalog>”): partija preko servera prepoznaje ko je ko.
        postavka.igraci = postavka.igraci.map { p in
            if p.covek { return NoviIgrac(id: VezaOsvajanja.idIgraca(ja), ime: p.ime, boja: p.boja, covek: true, tim: p.tim, kapiten: p.kapiten, vojska: p.vojska) }
            guard i < drugi.count else { return p }
            defer { i += 1 }
            return NoviIgrac(id: VezaOsvajanja.idIgraca(drugi[i].user_id), ime: drugi[i].nadimak, boja: p.boja, covek: false, tim: p.tim, kapiten: p.kapiten,
                             vojska: drugi[i].vojska.flatMap(VrstaVojske.init(rawValue:)))
        }
        if !drugi.isEmpty {
            postavka.soba = s.id
            postavka.korisnik = ja
            postavka.domacin = s.mesta.first { $0.mesto == 0 }?.user_id == ja
        }
        Zvuk.pusti(.bedz, jacina: 0.4)
        // Igrači su na okupu: kontinent se igra odmah; sa pravim igračima i ceo svet odmah
        // (početne kontinente bira domaćinov telefon, da svi imaju istu mapu), inače izbor kontinenata.
        if postavka.teren != nil || postavka.soba != nil { igra = postavka; return }
        redIzbora = Stanje.redosledIzbora(timovi.shuffled())
        withAnimation { korak = .kontinenti }
        Task { await botoviBiraju() }
    }

    /// Izbor kontinenta (preuređeno 04.11): mala mapa sveta sa kontinentima, redosled kao red imena, ispod kartice kontinenata.
    private var kontinenti: some View {
        let naRedu = redIzbora.first { postavka.pocetak[$0] == nil }
        return VStack(alignment: .leading, spacing: 14) {
            Naslov(tekst: "Izbor kontinenta", velicina: 30)
            Text(naRedu == nil ? "Svi su izabrali. Kreni!" : naRedu == mojTim ? "Ti biraš: dodirni kontinent na mapi. Na njemu su tvoja prestonica i prve države." : "Bira \(imeTima(naRedu!))…")
                .font(.tekst(15, .semibold)).foregroundStyle(naRedu == mojTim ? Color.mastilo : Color.sivaTekst)
            // Redosled: ime i boja svakog, strelica do sledećeg, istaknut onaj ko bira.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(redIzbora.enumerated()), id: \.offset) { i, t in
                        if i > 0 { Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.sivaTekst) }
                        let gotov = postavka.pocetak[t] != nil
                        HStack(spacing: 6) {
                            Circle().fill(Color(hex: boja(t))).frame(width: 12, height: 12).overlay(Circle().stroke(Color.mastilo, lineWidth: 1.2))
                            Text(imeTima(t).prefix(1).uppercased() + imeTima(t).dropFirst()).font(.tekst(14, naRedu == t ? .heavy : .semibold))
                            if gotov { Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy)) }
                        }
                        .foregroundStyle(gotov ? Color.sivaTekst : Color.mastilo)
                        .padding(.vertical, 6)
                        .overlay(alignment: .bottom) { if naRedu == t { Rectangle().fill(Color.mastilo).frame(height: 3) } }
                    }
                }
            }
            KontinentiMapa(zauzeti: Dictionary(uniqueKeysWithValues: postavka.pocetak.map { ($0.value, Color(hex: boja($0.key))) }),
                           mozeDaBira: naRedu == mojTim) { k in izaberiKontinent(k, naRedu: naRedu) }
                .frame(height: 220)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(Kontinenti.svi, id: \.id) { k in
                    let zauzeo = postavka.pocetak.first { $0.value == k.id }?.key
                    Button { izaberiKontinent(k.id, naRedu: naRedu) } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 3).fill(KontinentiMapa.boja(k.id)).frame(width: 12, height: 12)
                                Text(k.ime).font(.tekst(15, .bold)).lineLimit(1).minimumScaleFactor(0.8)
                            }
                            Text("\(Kontinenti.oblasti(k.id).count) država · \(k.regioni.count) \(k.regioni.count == 1 ? "region" : "regiona")")
                                .font(.tekst(12)).foregroundStyle(Color.sivaTekst)
                            Text(zauzeo.map { "Uzeo: \(imeTima($0))" } ?? "Slobodno").font(.tekst(12, .bold))
                                .foregroundStyle(zauzeo.map { Color(hex: boja($0)) } ?? Color.teal)
                        }
                        .foregroundStyle(Color.mastilo).padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.kartica, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(zauzeo.map { Color(hex: boja($0)) } ?? Color.kremTamnija, lineWidth: zauzeo == nil ? 1.5 : 2.5))
                        .opacity(zauzeo != nil && zauzeo != mojTim ? 0.6 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(naRedu != mojTim || zauzeo != nil)
                }
            }
            if naRedu == nil {
                Button("Počni partiju") { igra = postavka }.buttonStyle(.primarno)
            }
        }
    }

    private func izaberiKontinent(_ k: String, naRedu: String?) {
        guard naRedu == mojTim, !postavka.pocetak.values.contains(k) else { return }
        Zvuk.pusti(.izborDrzave, jacina: 0.4)
        withAnimation(.spring(duration: 0.35)) { postavka.pocetak[mojTim] = k }
        Task { await botoviBiraju() }
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


/// Mala mapa sveta za izbor kontinenta: svaki kontinent svojom bojom, zauzet bojom igrača; dodir bira kontinent.
struct KontinentiMapa: View {
    let zauzeti: [String: Color]
    let mozeDaBira: Bool
    let izbor: (String) -> Void

    static func boja(_ k: String) -> Color {
        switch k {
        case "sam": Color(hex: 0xBFE3F7); case "jam": Color(hex: 0xC9EBC2); case "evr": Color(hex: 0xFFE3A3)
        case "afr": Color(hex: 0xFFCDB8); case "azi": Color(hex: 0xE2D6FA); default: Color(hex: 0xFFD3E4)
        }
    }

    var body: some View {
        GeometryReader { g in
            let k = min(g.size.width / Mapa.sirina, g.size.height / Mapa.visina)
            let x0 = (g.size.width - Mapa.sirina * k) / 2, y0 = (g.size.height - Mapa.visina * k) / 2
            Canvas { ctx, _ in
                var m = ctx
                m.translateBy(x: x0, y: y0); m.scaleBy(x: k, y: k)
                for o in Mapa.oblasti {
                    guard let put = PutanjeMape.sve[o.id] else { continue }
                    let kont = Kontinenti.od(o.id).id
                    m.fill(put, with: .color(zauzeti[kont] ?? Self.boja(kont)))
                    m.stroke(put, with: .color(.white.opacity(0.7)), lineWidth: 0.6 / k)
                }
                for kont in Kontinenti.svi {
                    let ids = Kontinenti.oblasti(kont.id).map(Mapa.oblast)
                    guard !ids.isEmpty else { continue }
                    // Natpis na „težištu” kontinenta (prosek najvećih država, da ne padne u more).
                    let velike = ids.sorted { $0.povrsina > $1.povrsina }.prefix(6)
                    let cx = velike.map(\.x).reduce(0, +) / Double(velike.count), cy = velike.map(\.y).reduce(0, +) / Double(velike.count)
                    let tekst = Text(kont.ime).font(.tekst(11, .heavy)).foregroundStyle(Color.tinta)
                    ctx.draw(tekst, at: CGPoint(x: x0 + cx * k, y: y0 + cy * k))
                }
            }
            .contentShape(Rectangle())
            .gesture(SpatialTapGesture().onEnded { v in
                guard mozeDaBira else { return }
                let x = (v.location.x - x0) / k, y = (v.location.y - y0) / k
                if let o = Mapa.oblasti.first(where: { PutanjeMape.sve[$0.id]?.contains(CGPoint(x: x, y: y)) == true }) {
                    izbor(Kontinenti.od(o.id).id)
                }
            })
        }
        .background(Color(hex: 0xE3EDF2), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.mastilo, lineWidth: 2))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mapa kontinenata; kontinent biraš i preko kartica ispod")
    }
}
