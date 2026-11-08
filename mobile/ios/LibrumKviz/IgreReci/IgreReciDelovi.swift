import SwiftUI

/// Stanje jedne pločice slova (boja kao u celom kvizu: teal tačno, žuto na drugom mestu, sivo nema).
enum StanjePloce: Int, Codable {
    case prazno, uneto, nema, mesto, tacno, izabrano, istaknuto

    /// Bolje stanje pobeđuje na tastaturi (slovo koje je jednom bilo tačno ostaje zeleno).
    var jacina: Int { switch self { case .tacno: 3; case .mesto: 2; case .nema: 1; default: 0 } }
}

/// Pločica slova sa debelom ivicom; broj u uglu za Šifru i Ukrštenicu.
struct Ploca: View {
    let slovo: String
    var stanje: StanjePloce = .uneto
    var velicina: CGFloat = 52
    var broj: Int? = nil

    private var boje: (pozadina: Color, tekst: Color, ivica: Color, debljina: CGFloat) {
        switch stanje {
        case .prazno: (.kartica, .mastilo, .kremTamnija, 2)
        case .uneto: (.kartica, .mastilo, .mastilo, 2.5)
        case .nema: (.skelet, .sivaTekst, .clear, 0)
        case .mesto: (.zuta, .tinta, .mastilo, 2)
        case .tacno: (.teal, .white, .mastilo, 2)
        case .izabrano: (.zuta, .tinta, .mastilo, 3)
        case .istaknuto: (.tealSvetla, .mastilo, .teal, 2)
        }
    }

    var body: some View {
        let b = boje
        let radijus = velicina * 0.2
        Text(slovo)
            .font(.system(size: velicina * 0.48, weight: .heavy, design: .rounded))
            .foregroundStyle(b.tekst)
            .frame(width: velicina, height: velicina)
            .background(b.pozadina, in: RoundedRectangle(cornerRadius: radijus, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radijus, style: .continuous).stroke(b.ivica, lineWidth: b.debljina))
            .overlay(alignment: .topLeading) {
                if let broj {
                    Text("\(broj)").font(.system(size: max(8, velicina * 0.24), weight: .bold, design: .rounded))
                        .foregroundStyle(stanje == .tacno ? Color.white.opacity(0.85) : Color.sivaTekst).padding(.leading, 3).padding(.top, 2)
                }
            }
            .animation(.spring(duration: 0.25), value: stanje)
    }
}

/// Unos tastaturom telefona (vlasnik 08.11: ne tastatura u igri). Vidljivo polje vezano za tekst igre: kuca se reč,
/// „Gotovo” potvrđuje, fokus ostaje. `duzina` seče višak, dozvoljena su samo slova azbuke; velika slova pravi igra.
struct PoljeUnosaReci: View {
    @Binding var tekst: String
    let duzina: Int
    var natpis = "Kucaj reč"
    var brisi: (() -> Void)? = nil
    var potvrdi: (() -> Void)? = nil
    @FocusState private var fokus: Bool

    var body: some View {
        HStack(spacing: 8) {
            TextField(natpis, text: $tekst)
                .focused($fokus)
                .font(.tekst(18, .bold))
                .textInputAutocapitalization(.characters).autocorrectionDisabled().keyboardType(.default)
                .submitLabel(.done)
                .onSubmit { potvrdi?(); fokus = true }
                .onChange(of: tekst) { _, novo in
                    // polje se prepisuje samo kad ima višak ili nedozvoljen znak: svako prepisivanje usred kucanja gubi slova
                    let cisto = String(novo.filter { AzbukaReci.dozvoljena.contains(String($0).uppercased()) }.prefix(duzina))
                    if cisto != novo { tekst = cisto }
                }
                .padding(.horizontal, 14).frame(height: 48)
                .background(Color.kartica, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(fokus ? Color.mastilo : Color.kremTamnija, lineWidth: 2))
            if let brisi {
                Button(action: brisi) {
                    Image(systemName: "delete.left").font(.system(size: 18, weight: .bold)).frame(width: 52, height: 48)
                }
                .buttonStyle(.sekundarno).controlSize(.small).frame(width: 60).accessibilityLabel("Obriši")
            }
            if let potvrdi {
                Button(action: { potvrdi(); fokus = true }) {
                    Image(systemName: "checkmark").font(.system(size: 18, weight: .heavy)).frame(width: 52, height: 48)
                }
                .buttonStyle(.primarno).controlSize(.small).frame(width: 60).accessibilityLabel("Potvrdi")
            }
        }
        .onAppear { fokus = true }
    }
}

/// Zajednički okvir igre: zatvaranje, naslov, sat, pomoć i pravilo u jednom redu.
struct OkvirIgreReci<Sadrzaj: View>: View {
    let igra: IgraReci
    @Binding var sekundi: Int
    let gotovo: Bool
    var podnaslov: String? = nil
    /// U sobi „Igraj sa drugima”: rok u sekundama; sat odbrojava, a izlaz je na ekranu sobe.
    var rok: Int? = nil
    var pomoc: (() -> Void)? = nil
    @ViewBuilder var sadrzaj: Sadrzaj
    @Environment(\.dismiss) private var zatvori
    @Environment(\.scenePhase) private var faza

    var body: some View {
        ZStack {
            Papir()
            VStack(spacing: 12) {
                HStack(alignment: .center) {
                    if rok == nil {
                        KrugDugme(ikonica: "xmark", opis: "Izađi") { zatvori() }
                    } else {
                        Color.clear.frame(width: 44, height: 44)
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text(podnaslov ?? (rok == nil ? "Igra dana" : "Igra sa drugima")).font(.tekst(12, .semibold)).foregroundStyle(Color.sivaTekst).lineLimit(1)
                        Text(igra.naslov).font(.naslov(20)).foregroundStyle(Color.mastilo)
                        HStack(spacing: 4) {
                            Image(systemName: "timer").font(.system(size: 12, weight: .bold))
                            Text(AzbukaReci.vreme(rok.map { max(0, $0 - sekundi) } ?? sekundi)).font(.tekst(13, .bold)).monospacedDigit()
                        }
                        .foregroundStyle(Color.sivaTekst)
                        .accessibilityElement(children: .combine).accessibilityLabel("Vreme \(sekundi / 60) minuta \(sekundi % 60) sekundi")
                    }
                    Spacer()
                    if let pomoc, !gotovo {
                        KrugDugme(ikonica: "lightbulb", opis: "Pomoć, oduzima 5 poena", radnja: pomoc)
                    } else {
                        Color.clear.frame(width: 44, height: 44)
                    }
                }
                if !gotovo {
                    Text(igra.pravilo).font(.tekst(13)).foregroundStyle(Color.sivaTekst)
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                }
                sadrzaj
            }
            .padding(.horizontal, 16).padding(.top, 8)
            // skrol posle poteza (Lanac ide na dno) ne sme da zatvori tastaturu telefona
            .scrollDismissesKeyboard(.never)
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task(id: gotovo) {
            // sat ide samo dok je igra otvorena i nije završena
            while !gotovo && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if !gotovo && faza == .active && !Task.isCancelled { sekundi += 1 }
            }
        }
    }
}

/// Kraj partije: ishod, rešenje, mesto i rang lista dana.
struct KrajIgreReci: View {
    let igra: IgraReci
    let resio: Bool
    let resenje: String
    let sekundi: Int
    let ishod: Ucitano<IshodReci?>
    @Environment(Sesija.self) private var sesija
    @Environment(\.dismiss) private var zatvori
    @State private var rang: [RedRangaReci] = []

    var body: some View {
        VStack(spacing: 14) {
            Text(resio ? "Rešeno!" : "Kraj igre").font(.naslov(30)).foregroundStyle(Color.mastilo)
            Text(resenje).font(.tekst(16, .semibold)).multilineTextAlignment(.center).foregroundStyle(Color.mastilo)
            HStack(spacing: 10) {
                Plocica(ikonica: "timer", vrednost: AzbukaReci.vreme(sekundi), naziv: "Vreme")
                switch ishod {
                case .gotovo(let i?):
                    Plocica(ikonica: "star.fill", vrednost: "\(i.poeni)", naziv: "Poeni", boja: .narandzasta)
                    if i.ukupno > 0 {
                        Plocica(ikonica: "trophy.fill", vrednost: "\(i.mesto). / \(i.ukupno)", naziv: "Mesto danas", boja: .ljubicasta)
                    }
                default: EmptyView()
                }
            }
            switch ishod {
            case .ucitava: ProgressView().tint(Color.mastilo)
            case .greska(let g): Text(g).font(.tekst(14)).foregroundStyle(Color.crvena).multilineTextAlignment(.center)
            case .gotovo(nil) where !sesija.prijavljen:
                Text("Prijavi se da rezultat ode na rang listu.")
                    .font(.tekst(14)).foregroundStyle(Color.sivaTekst).multilineTextAlignment(.center)
            case .gotovo: EmptyView()
            }
            if !rang.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Oznaka(tekst: "Najbolji danas")
                    ForEach(rang.prefix(10)) { r in
                        HStack(spacing: 10) {
                            Text("\(r.mesto).").font(.tekst(14, .bold)).monospacedDigit().frame(width: 28, alignment: .leading)
                            AvatarSlika(avatar: r.avatar, velicina: 28)
                            Text(r.ime).font(.tekst(14, .semibold)).lineLimit(1)
                            Spacer()
                            if r.resio { Text("\(r.poeni)").font(.tekst(14, .bold)).monospacedDigit() }
                            Text(AzbukaReci.vreme(r.sekundi)).font(.tekst(13)).foregroundStyle(Color.sivaTekst).monospacedDigit()
                        }
                        .foregroundStyle(r.id == sesija.korisnikId ? Color.teal : Color.mastilo)
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(14).mirna()
            }
            Text("Nova zagonetka stiže sutra.").font(.tekst(13)).foregroundStyle(Color.sivaTekst)
            Button("Nazad na igre") { zatvori() }.buttonStyle(.zuto)
        }
        .padding(20).pop(resio ? .tealSvetla : .kartica)
        .task(id: ishod.gotovoKljuc) { rang = await IgreReci.deljeno.rang(igra) }
    }
}

extension Ucitano {
    /// Menja se kad učitavanje završi, za ponovno povlačenje rang liste.
    var gotovoKljuc: Int { switch self { case .ucitava: 0; case .greska: 1; case .gotovo: 2 } }
}

/// Kratko drmanje za pogrešan unos.
struct Drmanje: GeometryEffect {
    var korak: CGFloat
    var animatableData: CGFloat { get { korak } set { korak = newValue } }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(korak * .pi * 4), y: 0))
    }
}

/// Poruka ispod igre (nema reči, već nađeno...) koja se sama skloni.
struct PorukaReci: View {
    let tekst: String?
    var body: some View {
        Text(tekst ?? " ").font(.tekst(14, .semibold)).foregroundStyle(Color.mastilo)
            .frame(height: 20).opacity(tekst == nil ? 0 : 1)
            .animation(.easeInOut(duration: 0.2), value: tekst)
            .accessibilityHidden(tekst == nil)
    }
}

/// Zajedničko slanje rezultata: poziva server jednom i vraća stanje za KrajIgreReci.
@MainActor
func posaljiRezultatReci(_ igra: IgraReci, odgovor: [String: Any], resio: Bool, sekundi: Int, pomoci: Int,
                         sesija: Sesija, napredak: Napredak) async -> Ucitano<IshodReci?> {
    do {
        let i = try await IgreReci.deljeno.zavrsi(igra, odgovor: odgovor, resio: resio, sekundi: sekundi, pomoci: pomoci, sesija: sesija, napredak: napredak)
        Zvuk.pusti(resio ? .osvojeno : .netacno, jacina: 0.5)
        return .gotovo(i)
    } catch {
        return .greska(error.localizedDescription)
    }
}

/// Igra u sobi „Igraj sa drugima” (Igre/TakmicenjeView): rok, bodovanje brzine i javljanje rezultata tabeli uživo.
struct UTakmicenju {
    let rok: Int
    let javi: (MojRezultat) -> Void

    /// Brzina donosi do rok/6 poena. Primer: rok 240, rešeno za 60 s → 30.
    func bonus(_ sekundi: Int) -> Int { max(0, rok - sekundi) / 6 }

    /// Rok po igri: Premetaljka je najkraća, ukrštenice najduže.
    static func rok(_ igra: IgraReci) -> Int {
        switch igra {
        case .premetaljka: 180
        case .petSlova, .lanac: 240
        case .zmija: 300
        case .sifra, .ukrstenica: 360
        }
    }
}
