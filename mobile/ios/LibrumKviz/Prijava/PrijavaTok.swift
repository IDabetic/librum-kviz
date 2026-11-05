import SwiftUI
import AuthenticationServices
import CryptoKit

/// Prijava iz kita (Auth): dobrodošlica, prijava, nalog, kod iz mejla,
/// zaboravljena lozinka i nova lozinka, sa svim stanjima greške.
struct PrijavaTok: View {
    @Environment(\.dismiss) private var zatvori
    @State private var put: [Korak] = []
    var pocetak: Korak? = nil
    /// Ulaz u aplikaciju traži nalog (vlasnik 03.11): nema „Igraj bez naloga” ni zatvaranja.
    var obavezna = false

    enum Korak: Hashable { case prijava, nalog, potvrda(email: String), zaboravljena, novaLozinka(email: String), gotovo }

    var body: some View {
        NavigationStack(path: $put) {
            Dobrodosli(idi: idi, gost: obavezna ? nil : { zatvori() })
                .navigationDestination(for: Korak.self) { k in
                    Group {
                        switch k {
                        case .prijava: PrijavaEkran(idi: idi, gotovo: { zatvori() })
                        case .nalog: NalogEkran(idi: idi)
                        case .potvrda(let email): PotvrdaEkran(email: email, oporavak: false, idi: idi, gotovo: { idi(.gotovo) })
                        case .zaboravljena: ZaboravljenaEkran(idi: idi)
                        case .novaLozinka(let email): NovaLozinkaEkran(email: email) { idi(.gotovo) }
                        case .gotovo: GotovoEkran { zatvori() }
                        }
                    }
                    .toolbar(.hidden, for: .navigationBar)
                }
                .toolbar(.hidden, for: .navigationBar)
        }
        // Na iPadu prijava ostaje širine telefona, na sredini, kao uvod.
        .frame(maxWidth: UvodView.najvecaSirina)
        .frame(maxWidth: .infinity)
        .background(Papir())
        .onAppear { if let pocetak, put.isEmpty { put = [pocetak] } }
    }

    private func idi(_ k: Korak) { put.append(k) }
}

// MARK: 01 Dobrodošlica

private struct Dobrodosli: View {
    let idi: (PrijavaTok.Korak) -> Void
    let gost: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                ploca(.mimi, .narandzasta, -8).offset(x: -80, y: -60)
                ploca(.bloop, .nebo, 7).offset(x: 80, y: -80)
                ploca(.zig, .ljubicasta, -5).offset(x: -70, y: 80)
                ploca(.lumi, .zuta, 6).offset(x: 80, y: 70)
            }
            .frame(maxWidth: .infinity).frame(height: 330)
            .accessibilityHidden(true)
            Label("librum kviz", systemImage: "questionmark.square.fill").font(.naslov(20)).foregroundStyle(Color.roze)
            Naslov(tekst: "Igraj, uči\ni pokaži se!", velicina: 40)
            Text("Kratki kvizovi, dueli uživo sa drugarima i rang lista koja nikad ne spava.").font(.tekst(15)).foregroundStyle(Color.sivaTekst)
            Spacer(minLength: 0)
            Button("Napravi nalog") { idi(.nalog) }.buttonStyle(.primarno)
            Button("Već imam nalog") { idi(.prijava) }.buttonStyle(.sekundarno)
            SpoljnaPrijava()
            if let gost {
                Button("Igraj bez naloga", action: gost).font(.tekst(14, .semibold)).foregroundStyle(Color.sivaTekst).frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20).padding(.bottom, 12)
        .background(Papir())
    }

    private func ploca(_ m: Maskota, _ boja: Color, _ ugao: Double) -> some View {
        MaskotaSlika(maskota: m, velicina: 110).frame(width: 140, height: 140)
            .pop(boja, radijus: 30).rotationEffect(.degrees(ugao))
    }
}

// MARK: 02 Prijava

private struct PrijavaEkran: View {
    @Environment(Sesija.self) private var sesija
    @Environment(Mreza.self) private var mreza
    let idi: (PrijavaTok.Korak) -> Void
    let gotovo: () -> Void

    enum Stanje: Equatable { case unos, radi, losEmail, pogresno, zakljucano, offline, greska(String) }
    @State private var email = ""
    @State private var lozinka = ""
    @State private var stanje: Stanje = .unos

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GornjaTraka()
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Naslov(tekst: "Dobro došao\nnazad!", velicina: 36)
                        Text("Prijavi se i čuvaj niz.").font(.tekst(15)).foregroundStyle(Color.sivaTekst)
                    }
                    Spacer()
                    MaskotaSlika(maskota: .zig, velicina: 80).rotationEffect(.degrees(8))
                }
                if let poruka = baner { baner(poruka.0, poruka.1) }
                PoljeUnosa(naziv: "Email", tekst: $email, stanje: stanje == .losEmail ? .greska("Ovaj email ne izgleda ispravno.") : .obicno,
                           sadrzaj: .emailAddress, tastatura: .emailAddress)
                PoljeUnosa(naziv: "Lozinka", tekst: $lozinka, stanje: stanje == .pogresno ? .greska("Pogrešna lozinka. Pokušaj ponovo.") : .obicno,
                           sakriveno: true, sadrzaj: .password)
                HStack { Spacer(); Button("Zaboravljena lozinka?") { idi(.zaboravljena) }.font(.tekst(14, .bold)).foregroundStyle(Color.teal) }
                Button { Task { await prijavi() } } label: {
                    if stanje == .radi { HStack(spacing: 10) { ProgressView().tint(Color.naMastilu); Text("Prijavljujem…") } } else { Text("Prijavi se") }
                }
                .buttonStyle(.primarno)
                .disabled(email.isEmpty || lozinka.isEmpty || stanje == .radi || stanje == .zakljucano)
                HStack(spacing: 4) {
                    Text("Nov si ovde?").foregroundStyle(Color.sivaTekst)
                    Button("Napravi nalog") { idi(.nalog) }.foregroundStyle(Color.mastilo).bold()
                }
                .font(.tekst(14)).frame(maxWidth: .infinity).padding(.top, 8)
            }
            .padding(.horizontal, 20).padding(.bottom, 20)
        }
        .background(Papir())
        .onChange(of: email) { if stanje != .radi { stanje = .unos } }
        .onChange(of: lozinka) { if stanje == .pogresno { stanje = .unos } }
    }

    private var baner: (String, Color)? {
        switch stanje {
        case .zakljucano: ("Previše pogrešnih pokušaja. Nalog je zaključan na nekoliko minuta, ili promeni lozinku.", .crvenaSvetla)
        case .offline: ("Nema interneta. Poveži se pa pokušaj ponovo.", .zuta)
        case .greska(let p): ("Nešto nije u redu: \(p)", .crvenaSvetla)
        default: mreza.povezan ? nil : ("Nema interneta. Prijava čeka vezu.", .zuta)
        }
    }

    private func baner(_ tekst: String, _ boja: Color) -> some View {
        Label(tekst, systemImage: boja == .zuta ? "wifi.slash" : "exclamationmark.triangle").font(.tekst(14, .semibold))
            .foregroundStyle(boja == .zuta ? Color.tinta : Color.mastilo)
            .padding(12).frame(maxWidth: .infinity, alignment: .leading).pop(boja, radijus: 16)
    }

    private func prijavi() async {
        guard NalogEkran.ispravanEmail(email) else { stanje = .losEmail; return }
        stanje = .radi
        do {
            try await sesija.prijava(email: email, lozinka: lozinka)
            gotovo()
        } catch let g as Supabase.Greska {
            switch g.vrsta {
            case .pogresno: stanje = .pogresno
            case .zakljucano: stanje = .zakljucano
            case .mreza: stanje = .offline
            case .nepotvrdjen: stanje = .unos; idi(.potvrda(email: email))
            default: stanje = .greska(g.poruka)
            }
        } catch {
            stanje = .greska(error.localizedDescription)
        }
    }
}

// MARK: 03 Napravi nalog

private struct NalogEkran: View {
    @Environment(Sesija.self) private var sesija
    let idi: (PrijavaTok.Korak) -> Void

    enum Stanje: Equatable { case unos, radi, greske, postoji, offline, greska(String) }
    @State private var ime = ""
    @State private var nadimak = ""
    @State private var email = ""
    @State private var lozinka = ""
    @State private var uslovi = false
    @State private var stanje: Stanje = .unos

    static func ispravanEmail(_ e: String) -> Bool {
        e.trimmingCharacters(in: .whitespaces).range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]{2,}$"#, options: .regularExpression) != nil
    }
    static func ispravanNadimak(_ n: String) -> Bool { NalogEkranPravila.ispravanNadimak(n) }

    /// Jačina lozinke 0–4: dužina, mala i velika slova, cifra, znak.
    static func jacina(_ l: String) -> Int {
        guard l.count >= 6 else { return l.isEmpty ? 0 : 1 }
        var j = 1
        if l.count >= 10 { j += 1 }
        if l.rangeOfCharacter(from: .decimalDigits) != nil { j += 1 }
        if l.rangeOfCharacter(from: .uppercaseLetters) != nil && l.rangeOfCharacter(from: .lowercaseLetters) != nil { j += 1 }
        return min(4, j)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GornjaTraka()
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Naslov(tekst: "Pridruži se\nkviz žurki!", velicina: 36)
                        Text("Besplatan nalog za par sekundi.").font(.tekst(15)).foregroundStyle(Color.sivaTekst)
                    }
                    Spacer()
                    MaskotaSlika(maskota: .mimi, velicina: 80).rotationEffect(.degrees(-8))
                }
                switch stanje {
                case .offline: Label("Nema interneta. Nalog se pravi kad se veza vrati.", systemImage: "wifi.slash").font(.tekst(14, .semibold))
                    .foregroundStyle(Color.tinta).padding(12).frame(maxWidth: .infinity, alignment: .leading).pop(.zuta, radijus: 16)
                case .greska(let p): Label(p, systemImage: "exclamationmark.triangle").font(.tekst(14, .semibold))
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading).pop(.crvenaSvetla, radijus: 16)
                case .postoji:
                    VStack(alignment: .leading, spacing: 10) {
                        Label("\(email) već ima nalog, zato nije stigao novi mejl. Prijavi se, ili postavi novu lozinku ako si je zaboravio.",
                              systemImage: "person.crop.circle.badge.checkmark").font(.tekst(14, .semibold)).foregroundStyle(Color.mastilo)
                        HStack(spacing: 16) {
                            Button("Prijavi se") { idi(.prijava) }.bold()
                            Button("Nova lozinka") { idi(.zaboravljena) }.bold()
                        }
                        .font(.tekst(14)).foregroundStyle(Color.teal)
                    }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading).pop(.zuta, radijus: 16)
                default: EmptyView()
                }
                PoljeUnosa(naziv: "Ime", tekst: $ime, stanje: stanje == .greske && ime.trimmingCharacters(in: .whitespaces).isEmpty ? .greska("Upiši ime.") : .obicno, sadrzaj: .givenName)
                PoljeUnosa(naziv: "Nadimak", tekst: $nadimak, stanje: nadimakStanje, sadrzaj: .nickname)
                PoljeUnosa(naziv: "Email", tekst: $email, stanje: emailStanje, sadrzaj: .emailAddress, tastatura: .emailAddress)
                PoljeUnosa(naziv: "Lozinka", tekst: $lozinka, stanje: stanje == .greske && lozinka.count < 6 ? .greska("Najmanje 6 karaktera.") : .obicno,
                           sakriveno: true, sadrzaj: .newPassword)
                jacinaLozinke
                Button { uslovi.toggle() } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: uslovi ? "checkmark.square.fill" : "square").font(.system(size: 22))
                            .foregroundStyle(stanje == .greske && !uslovi ? Color.crvena : Color.mastilo)
                        Text("Prihvatam uslove korišćenja i politiku privatnosti").font(.tekst(14)).foregroundStyle(Color.mastilo).multilineTextAlignment(.leading)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(uslovi ? .isSelected : [])
                Button { Task { await napravi() } } label: {
                    if stanje == .radi { HStack(spacing: 10) { ProgressView().tint(Color.naMastilu); Text("Pravim nalog…") } } else { Text("Napravi nalog") }
                }
                .buttonStyle(.primarno).disabled(stanje == .radi)
                HStack(spacing: 4) {
                    Text("Već igraš?").foregroundStyle(Color.sivaTekst)
                    Button("Prijavi se") { idi(.prijava) }.foregroundStyle(Color.mastilo).bold()
                }
                .font(.tekst(14)).frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20).padding(.bottom, 20)
        }
        .background(Papir())
    }

    private var nadimakStanje: PoljeUnosa.Stanje {
        if stanje == .greske && !Self.ispravanNadimak(nadimak) { return .greska("3–20 slova, cifara, tačka ili crtica.") }
        return .obicno
    }
    private var emailStanje: PoljeUnosa.Stanje {
        if stanje == .postoji { return .greska("Ovaj email već ima nalog. Prijavi se.") }
        if stanje == .greske && !Self.ispravanEmail(email) { return .greska("Ovaj email ne izgleda ispravno.") }
        return .obicno
    }

    private var jacinaLozinke: some View {
        let j = Self.jacina(lozinka)
        return HStack(spacing: 6) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2).fill(i < j ? [Color.crvena, .narandzasta, .teal, .teal][j - 1] : Color.kremTamnija).frame(height: 5)
            }
            Text(["", "Slaba", "Srednja", "Dobra", "Jaka"][j]).font(.tekst(12, .bold)).foregroundStyle(j >= 3 ? Color.teal : .sivaTekst).frame(width: 56, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Jačina lozinke: \(["nema", "slaba", "srednja", "dobra", "jaka"][j])")
    }

    private func napravi() async {
        guard !ime.trimmingCharacters(in: .whitespaces).isEmpty, Self.ispravanNadimak(nadimak), Self.ispravanEmail(email), lozinka.count >= 6, uslovi else {
            stanje = .greske; return
        }
        stanje = .radi
        do {
            try await sesija.registracija(email: email, lozinka: lozinka, ime: ime, prezime: "", nadimak: nadimak)
            stanje = .unos
            idi(.potvrda(email: email))
        } catch let g as Supabase.Greska {
            stanje = g.vrsta == .postoji ? .postoji : g.vrsta == .mreza ? .offline : .greska(g.poruka)
        } catch {
            stanje = .greska(error.localizedDescription)
        }
    }
}

// MARK: 04 Kod iz mejla

private struct PotvrdaEkran: View {
    @Environment(Sesija.self) private var sesija
    let email: String
    let oporavak: Bool
    let idi: (PrijavaTok.Korak) -> Void
    let gotovo: () -> Void

    static let duzina = 6
    static let maksPokusaja = 5
    static let cekanje = 60

    enum Stanje: Equatable { case unos, proverava, pogresan, previse, istekao, poslatPonovo, potvrdjen }
    @State private var kod = ""
    @State private var stanje: Stanje = .unos
    @State private var pokusaja = 0
    @State private var ponovoZa = cekanje
    @FocusState private var fokus: Bool
    private let sat = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 16) {
            GornjaTraka()
            MaskotaSlika(maskota: .bloop, velicina: 130).frame(width: 170, height: 170).background(Color.kartica, in: Circle())
                .overlay(Circle().stroke(Color.mastilo, lineWidth: 3))
                .overlay(alignment: .topTrailing) {
                    Image(systemName: stanje == .potvrdjen ? "checkmark" : "envelope").font(.system(size: 20, weight: .bold)).foregroundStyle(Color.tinta)
                        .frame(width: 50, height: 50).background(stanje == .potvrdjen ? Color.teal : Color.white, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.tinta, lineWidth: 2.5)).rotationEffect(.degrees(10))
                }
            Naslov(tekst: stanje == .potvrdjen ? "Potvrđeno!" : "Proveri\nsanduče!", velicina: 34).multilineTextAlignment(.center)
            Text("Poslali smo \(Self.duzina)-cifreni kod na\n\(email)").font(.tekst(15)).foregroundStyle(Color.sivaTekst).multilineTextAlignment(.center)
            polja
            poruka
            Spacer()
            Button { Task { await proveri() } } label: {
                if stanje == .proverava { HStack(spacing: 10) { ProgressView().tint(Color.naMastilu); Text("Proveravam…") } } else { Text("Potvrdi") }
            }
            .buttonStyle(.primarno)
            .disabled(kod.count < Self.duzina || [.proverava, .previse, .potvrdjen].contains(stanje))
            HStack(spacing: 4) {
                Text("Pogrešan email?").foregroundStyle(Color.sivaTekst)
                Button("Promeni ga") { idi(oporavak ? .zaboravljena : .nalog) }.foregroundStyle(Color.mastilo).bold()
            }
            .font(.tekst(14))
        }
        .padding(.horizontal, 20).padding(.bottom, 12)
        .background(Papir())
        .onAppear { fokus = true }
        .onReceive(sat) { _ in if ponovoZa > 0 { ponovoZa -= 1 } }
        .onChange(of: kod) { _, novo in
            kod = String(novo.filter(\.isNumber).prefix(Self.duzina))
            if [.pogresan, .poslatPonovo].contains(stanje) { stanje = .unos }
            if kod.count == Self.duzina && stanje == .unos { Task { await proveri() } }
        }
        .sensoryFeedback(trigger: stanje) { _, s in s == .pogresan ? .error : s == .potvrdjen ? .success : nil }
    }

    private var polja: some View {
        ZStack {
            TextField("", text: $kod).keyboardType(.numberPad).textContentType(.oneTimeCode).focused($fokus)
                .opacity(0.02).frame(height: 64).accessibilityLabel("Kod iz mejla")
            HStack(spacing: 8) {
                ForEach(0..<Self.duzina, id: \.self) { i in
                    let cifra = i < kod.count ? String(kod[kod.index(kod.startIndex, offsetBy: i)]) : ""
                    let aktivno = i == kod.count && fokus
                    Text(cifra).font(.naslov(28)).frame(maxWidth: .infinity).frame(height: 64)
                        .background(stanje == .pogresan ? Color.crvenaSvetla : stanje == .potvrdjen ? Color.tealSvetla : Color.kartica,
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(stanje == .pogresan ? Color.crvena : stanje == .potvrdjen ? Color.teal : aktivno || !cifra.isEmpty ? Color.mastilo : Color.kremTamnija,
                                    lineWidth: aktivno || !cifra.isEmpty ? 2.5 : 1.5))
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .onTapGesture { fokus = true }
    }

    @ViewBuilder private var poruka: some View {
        switch stanje {
        case .pogresan: Label("Kod nije tačan. Ostalo pokušaja: \(Self.maksPokusaja - pokusaja).", systemImage: "xmark.circle").foregroundStyle(Color.crvena)
        case .previse: Label("Previše pokušaja. Zatraži novi kod.", systemImage: "lock").foregroundStyle(Color.crvena)
        case .istekao: VStack(spacing: 6) { Label("Kod je istekao.", systemImage: "clock.badge.exclamationmark").foregroundStyle(Color.crvena); ponovo }
        case .poslatPonovo: Label("Novi kod je poslat.", systemImage: "checkmark.circle").foregroundStyle(Color.teal)
        case .potvrdjen: Label("Email je potvrđen.", systemImage: "checkmark.seal").foregroundStyle(Color.teal)
        default: ponovo
        }
    }

    private var ponovo: some View {
        Group {
            if ponovoZa > 0 {
                Text("Nije stigao? Ponovo za 0:\(String(format: "%02d", ponovoZa))").foregroundStyle(Color.sivaTekst)
            } else {
                Button("Pošalji kod ponovo") { Task { await posaljiPonovo() } }.foregroundStyle(Color.teal).bold()
            }
        }
    }

    private func proveri() async {
        guard pokusaja < Self.maksPokusaja else { stanje = .previse; return }
        stanje = .proverava
        do {
            try await sesija.potvrdiKod(email: email, kod: kod, oporavak: oporavak)
            stanje = .potvrdjen
            try? await Task.sleep(for: .milliseconds(900))
            gotovo()
        } catch let g as Supabase.Greska {
            pokusaja += 1
            stanje = g.vrsta == .zakljucano || pokusaja >= Self.maksPokusaja ? .previse : g.vrsta == .istekao && kod.count == Self.duzina && pokusaja == 1 ? .istekao : .pogresan
            kod = ""
        } catch {
            stanje = .pogresan
        }
    }

    private func posaljiPonovo() async {
        do {
            if oporavak { try await sesija.zaboravljenaLozinka(email: email) } else { try await sesija.posaljiKodPonovo(email: email) }
            pokusaja = 0; kod = ""; ponovoZa = Self.cekanje; stanje = .poslatPonovo
        } catch {
            stanje = .previse
        }
    }
}

// MARK: 05 Zaboravljena lozinka

private struct ZaboravljenaEkran: View {
    @Environment(Sesija.self) private var sesija
    let idi: (PrijavaTok.Korak) -> Void
    enum Stanje: Equatable { case unos, losEmail, salje, poslato, greska(String) }
    @State private var email = ""
    @State private var stanje: Stanje = .unos

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GornjaTraka()
            HStack { Spacer(); MaskotaSlika(maskota: .lumi, velicina: 130); Spacer() }
            Naslov(tekst: stanje == .poslato ? "Kod je na putu!" : "Zablokirao si?", velicina: 32).frame(maxWidth: .infinity)
            Text(stanje == .poslato ? "Ako postoji nalog za \(email), stigao je kod za novu lozinku. Proveri i neželjenu poštu."
                    : "Dešava se i najboljima. Upiši email i poslaćemo ti kod za novu lozinku.")
                .font(.tekst(15)).foregroundStyle(Color.sivaTekst).multilineTextAlignment(.center).frame(maxWidth: .infinity)
            if stanje != .poslato {
                PoljeUnosa(naziv: "Email", tekst: $email, stanje: emailStanje, sadrzaj: .emailAddress, tastatura: .emailAddress)
            }
            Spacer()
            if stanje == .poslato {
                Button("Unesi kod") { idi(.novaLozinka(email: email)) }.buttonStyle(.primarno)
                Button("Pošalji ponovo") { Task { await posalji() } }.buttonStyle(.sekundarno)
            } else {
                Button { Task { await posalji() } } label: {
                    if stanje == .salje { HStack(spacing: 10) { ProgressView().tint(Color.naMastilu); Text("Šaljem…") } } else { Text("Pošalji kod") }
                }
                .buttonStyle(.primarno).disabled(email.isEmpty || stanje == .salje)
            }
            HStack(spacing: 4) {
                Text("Setio si se?").foregroundStyle(Color.sivaTekst)
                Button("Prijavi se") { idi(.prijava) }.foregroundStyle(Color.mastilo).bold()
            }
            .font(.tekst(14)).frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20).padding(.bottom, 12)
        .background(Papir())
        .onChange(of: email) { if stanje != .salje { stanje = .unos } }
    }

    private var emailStanje: PoljeUnosa.Stanje {
        switch stanje {
        case .losEmail: .greska("Hmm, ovaj email ne izgleda ispravno.")
        case .greska(let p): .greska(p)
        default: .obicno
        }
    }

    /// GoTrue ne otkriva da li nalog postoji (zaštita od nabrajanja naloga), pa i poruka to ne tvrdi.
    private func posalji() async {
        guard NalogEkran.ispravanEmail(email) else { stanje = .losEmail; return }
        stanje = .salje
        do { try await sesija.zaboravljenaLozinka(email: email); stanje = .poslato } catch { stanje = .greska(error.localizedDescription) }
    }
}

// MARK: 05-E Nova lozinka

private struct NovaLozinkaEkran: View {
    @Environment(Sesija.self) private var sesija
    let email: String
    let gotovo: () -> Void
    enum Stanje: Equatable { case unos, neSlazuSe, kratka, cuva, istekao, greska(String) }
    @State private var kod = ""
    @State private var lozinka = ""
    @State private var ponovo = ""
    @State private var stanje: Stanje = .unos

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GornjaTraka()
                Naslov(tekst: "Nova lozinka", velicina: 34)
                Text("Kod iz mejla i nova lozinka, dva puta.").font(.tekst(15)).foregroundStyle(Color.sivaTekst)
                if stanje == .istekao {
                    Label("Kod je istekao ili nije tačan. Vrati se i zatraži novi.", systemImage: "clock.badge.exclamationmark").font(.tekst(14, .semibold))
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading).pop(.crvenaSvetla, radijus: 16)
                }
                PoljeUnosa(naziv: "Kod iz mejla", tekst: $kod, sadrzaj: .oneTimeCode, tastatura: .numberPad)
                PoljeUnosa(naziv: "Nova lozinka", tekst: $lozinka, stanje: stanje == .kratka ? .greska("Najmanje 6 karaktera.") : .obicno, sakriveno: true, sadrzaj: .newPassword)
                PoljeUnosa(naziv: "Ponovi lozinku", tekst: $ponovo,
                           stanje: stanje == .neSlazuSe ? .greska("Lozinke se ne slažu.") : (!ponovo.isEmpty && ponovo == lozinka ? .uRedu("Lozinke se slažu.") : .obicno),
                           sakriveno: true, sadrzaj: .newPassword)
                if case .greska(let p) = stanje { Text(p).font(.tekst(14, .semibold)).foregroundStyle(Color.crvena) }
                Button { Task { await sacuvaj() } } label: {
                    if stanje == .cuva { HStack(spacing: 10) { ProgressView().tint(Color.naMastilu); Text("Čuvam…") } } else { Text("Sačuvaj lozinku") }
                }
                .buttonStyle(.primarno).disabled(kod.count < 6 || stanje == .cuva).padding(.top, 8)
            }
            .padding(.horizontal, 20).padding(.bottom, 20)
        }
        .background(Papir())
    }

    private func sacuvaj() async {
        guard lozinka.count >= 6 else { stanje = .kratka; return }
        guard lozinka == ponovo else { stanje = .neSlazuSe; return }
        stanje = .cuva
        do {
            try await sesija.potvrdiKod(email: email, kod: kod, oporavak: true)
            try await sesija.postaviLozinku(lozinka)
            gotovo()
        } catch let g as Supabase.Greska {
            stanje = g.vrsta == .istekao ? .istekao : .greska(g.poruka)
        } catch {
            stanje = .greska(error.localizedDescription)
        }
    }
}

// MARK: 03-F / 06 Gotovo

private struct GotovoEkran: View {
    @Environment(Napredak.self) private var napredak
    @Environment(Sesija.self) private var sesija
    let dalje: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                ForEach(0..<10, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 6).fill(Color.zuta.opacity(0.7)).frame(width: 20, height: 150).offset(y: -100).rotationEffect(.degrees(Double(i) * 36))
                }
                MaskotaSlika(maskota: .zig, velicina: 130).frame(width: 170, height: 170).pop(.ljubicasta, radijus: 36).rotationEffect(.degrees(-6))
            }
            .frame(height: 260)
            .accessibilityHidden(true)
            Naslov(tekst: "Ti si u igri,\n\(sesija.nadimak ?? "šampione")!", velicina: 34).multilineTextAlignment(.center)
            Text("Nalog je spreman. Tvoj niz i napredak su sačuvani.").font(.tekst(15)).foregroundStyle(Color.sivaTekst).multilineTextAlignment(.center)
            HStack(spacing: 16) {
                Label("Niz \(napredak.s.nizDana) d", systemImage: "flame")
                Label("Nivo \(napredak.nivo)", systemImage: "star")
            }
            .font(.tekst(14, .bold))
            Spacer()
            Button("Nastavi", action: dalje).buttonStyle(.primarno)
        }
        .padding(.horizontal, 20).padding(.bottom, 12)
        .background(Papir())
    }
}


/// Prvi ulaz preko Apple ili Google naloga (vlasnik 03.11): nalog postoji, ali ime, prezime, nadimak i grad su obavezni
/// pre igre, kao kod registracije mejlom. Nadimak se čuva poslednji, pa nedovršen unos opet otvara ovaj ekran.
struct DopunaProfila: View {
    @Environment(Sesija.self) private var sesija
    enum Stanje: Equatable { case unos, greske, radi, zauzet, greska(String) }
    @State private var licni = Sesija.LicniPodaci()
    @State private var nadimak = ""
    @State private var stanje: Stanje = .unos

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Naslov(tekst: "Još malo\no tebi", velicina: 36)
                        Text("Nadimak vide drugi igrači i rang lista.").font(.tekst(15)).foregroundStyle(Color.sivaTekst)
                    }
                    Spacer()
                    MaskotaSlika(maskota: .lumi, velicina: 80).rotationEffect(.degrees(-6))
                }
                PoljeUnosa(naziv: "Ime", tekst: polje(\.first_name), stanje: obavezno(licni.first_name, "Upiši ime."), sadrzaj: .givenName)
                PoljeUnosa(naziv: "Prezime", tekst: polje(\.last_name), stanje: obavezno(licni.last_name, "Upiši prezime."), sadrzaj: .familyName)
                PoljeUnosa(naziv: "Nadimak", tekst: $nadimak, stanje: nadimakStanje, sadrzaj: .nickname)
                PoljeUnosa(naziv: "Grad", tekst: polje(\.city), stanje: obavezno(licni.city, "Upiši grad."), sadrzaj: .addressCity)
                if case .greska(let poruka) = stanje { Text(poruka).font(.tekst(13, .semibold)).foregroundStyle(Color.crvena) }
                Button { Task { await sacuvaj() } } label: {
                    if stanje == .radi { HStack(spacing: 10) { ProgressView().tint(Color.naMastilu); Text("Čuvam…") } } else { Text("Nastavi") }
                }
                .buttonStyle(.primarno)
                .disabled(stanje == .radi)
                Button("Odjavi se") { Task { await sesija.odjava() } }
                    .font(.tekst(14, .semibold)).foregroundStyle(Color.sivaTekst).frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20).padding(.top, 24)
        }
        .background(Papir())
        .task {
            // Ime i prezime stižu iz Google naloga (okidač na serveru); Apple ih ne šalje.
            if let l = try? await sesija.licniPodaci() { licni = l }
        }
        .onChange(of: nadimak) { if stanje == .zauzet { stanje = .unos } }
    }

    private func polje(_ k: WritableKeyPath<Sesija.LicniPodaci, String?>) -> Binding<String> {
        Binding(get: { licni[keyPath: k] ?? "" }, set: { licni[keyPath: k] = $0 })
    }

    private func prazno(_ s: String?) -> Bool { (s ?? "").trimmingCharacters(in: .whitespaces).isEmpty }

    private func obavezno(_ s: String?, _ poruka: String) -> PoljeUnosa.Stanje {
        stanje == .greske && prazno(s) ? .greska(poruka) : .obicno
    }

    private var nadimakStanje: PoljeUnosa.Stanje {
        if stanje == .zauzet { return .greska("Nadimak „\(nadimak)” je zauzet. Probaj drugi.") }
        if stanje == .greske && nadimak.isEmpty { return .greska("Izaberi nadimak.") }
        return nadimak.isEmpty || NalogEkranPravila.ispravanNadimak(nadimak) ? .obicno : .greska("3–20 slova, cifara, tačka ili crtica.")
    }

    private func sacuvaj() async {
        guard !prazno(licni.first_name), !prazno(licni.last_name), !prazno(licni.city), NalogEkranPravila.ispravanNadimak(nadimak) else {
            stanje = .greske; return
        }
        stanje = .radi
        do {
            try await sesija.sacuvajLicnePodatke(licni)
            try await sesija.sacuvajNadimak(nadimak)
        }
        catch let g as Supabase.Greska { stanje = g.vrsta == .postoji ? .zauzet : .greska(g.poruka) }
        catch { stanje = .greska(error.localizedDescription) }
    }
}

/// Apple i Google prijava (ujedno i registracija: prvi ulaz pravi nalog). Dugme se vidi samo kad je provajder
/// uključen u Supabase, pa aplikacija radi i pre podešavanja.
struct SpoljnaPrijava: View {
    @Environment(Sesija.self) private var sesija
    @State private var provajderi: Set<String> = []
    @State private var nonce = ""
    @State private var greska: String?
    @State private var pravni: PravniTekstView.Vrsta?

    @Environment(\.authorizationController) private var autorizacija
    @Environment(\.webAuthenticationSession) private var webPrijava

    private static let googleKlijent = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_IOS_CLIENT_ID") as? String ?? ""

    // Samo okrugle ikonice, kao na sajtu (vlasnik: bez tekstualnog „Continue with Apple”).
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                if provajderi.contains("apple") {
                    ikonica(opis: "Prijava preko Apple naloga") { await apple() } slika: {
                        Image(systemName: "apple.logo").font(.system(size: 24, weight: .semibold)).foregroundStyle(.black)
                    }
                }
                if provajderi.contains("google"), !Self.googleKlijent.isEmpty {
                    ikonica(opis: "Prijava preko Google naloga") { await google() } slika: {
                        Text("G").font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(Color(hex: 0x4285F4))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            if !provajderi.isDisjoint(with: ["apple", "google"]) {
                // Registracija mejlom ima kvačicu za uslove; ovde je prihvatanje ovim redom (Apple 1.2).
                Text("Preko Apple ili Google naloga prihvataš [uslove](librumkviz://uslovi) i [privatnost](librumkviz://privatnost).")
                    .font(.tekst(12)).foregroundStyle(Color.sivaTekst).tint(Color.teal).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity)
                    .environment(\.openURL, OpenURLAction { url in pravni = url.host == "privatnost" ? .privatnost : .uslovi; return .handled })
            }
            if let greska { Text(greska).font(.tekst(13, .semibold)).foregroundStyle(Color.crvena) }
        }
        .task { provajderi = await Supabase.deljeni.ukljuceniProvajderi() }
        .sheet(item: $pravni) { v in NavigationStack { PravniTekstView(vrsta: v) } }
    }

    private func ikonica(opis: String, radnja: @escaping () async -> Void, @ViewBuilder slika: () -> some View) -> some View {
        Button { Task { await radnja() } } label: {
            slika().frame(width: 56, height: 56).background(.white, in: Circle())
                .overlay(Circle().stroke(Color.kremTamnija, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(opis)
    }

    /// Google bez SDK-a: sistemski prozor za prijavu (PKCE, iOS klijent nema tajnu), pa id_token ide u Supabase.
    private func google() async {
        greska = nil
        let klijent = Self.googleKlijent
        // Povratna šema iOS klijenta je obrnut Client ID (Google je sam dozvoljava za taj klijent).
        let sema = klijent.split(separator: ".").reversed().joined(separator: ".")
        let povratak = "\(sema):/oauth2redirect"
        let proveravac = Self.nasumicno()
        nonce = Self.nasumicno()
        let stanje = Self.nasumicno()
        var adresa = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        adresa.queryItems = [
            .init(name: "client_id", value: klijent), .init(name: "redirect_uri", value: povratak),
            .init(name: "response_type", value: "code"), .init(name: "scope", value: "openid email profile"),
            .init(name: "code_challenge", value: Self.base64url(SHA256.hash(data: Data(proveravac.utf8)))),
            .init(name: "code_challenge_method", value: "S256"), .init(name: "nonce", value: Self.sha256(nonce)),
            .init(name: "state", value: stanje), .init(name: "prompt", value: "select_account"),
        ]
        do {
            let odgovor = try await webPrijava.authenticate(using: adresa.url!, callbackURLScheme: sema, preferredBrowserSession: .ephemeral)
            let upit = URLComponents(url: odgovor, resolvingAgainstBaseURL: false)?.queryItems ?? []
            guard upit.first(where: { $0.name == "state" })?.value == stanje,
                  let kod = upit.first(where: { $0.name == "code" })?.value else { greska = "Google prijava nije uspela."; return }
            let idToken = try await Self.googleToken(kod: kod, klijent: klijent, povratak: povratak, proveravac: proveravac)
            try await sesija.prijavaTokenom(provajder: "google", idToken: idToken, nonce: nonce)
        } catch let e as ASWebAuthenticationSessionError where e.code == .canceledLogin {
            return
        } catch {
            greska = error.localizedDescription
        }
    }

    private static func googleToken(kod: String, klijent: String, povratak: String, proveravac: String) async throws -> String {
        var z = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        z.httpMethod = "POST"
        z.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var telo = URLComponents()
        telo.queryItems = [.init(name: "code", value: kod), .init(name: "client_id", value: klijent),
                           .init(name: "redirect_uri", value: povratak), .init(name: "code_verifier", value: proveravac),
                           .init(name: "grant_type", value: "authorization_code")]
        z.httpBody = telo.percentEncodedQuery?.data(using: .utf8)
        struct Odgovor: Decodable { let id_token: String }
        let (d, _) = try await URLSession.shared.data(for: z)
        guard let o = try? JSONDecoder().decode(Odgovor.self, from: d) else { throw URLError(.userAuthenticationRequired) }
        return o.id_token
    }

    private static func base64url(_ h: SHA256.Digest) -> String {
        Data(h).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    private func apple() async {
        greska = nil
        nonce = Self.nasumicno()
        let zahtev = ASAuthorizationAppleIDProvider().createRequest()
        zahtev.requestedScopes = [.email, .fullName]
        zahtev.nonce = Self.sha256(nonce)
        do {
            guard case .appleID(let c) = try await autorizacija.performRequest(zahtev),
                  let t = c.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else { return }
            try await sesija.prijavaTokenom(provajder: "apple", idToken: t, nonce: nonce)
        } catch let e as ASAuthorizationError where e.code == .canceled {
            return
        } catch {
            greska = error.localizedDescription
        }
    }

    private static func nasumicno() -> String {
        var b = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, b.count, &b)
        return b.map { String(format: "%02x", $0) }.joined()
    }

    private static func sha256(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
