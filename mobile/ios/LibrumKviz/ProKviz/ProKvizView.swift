import SwiftUI

/// Survival igre sa 10 života: PRO kviz (opšti fond, Risk) i Book kviz (književnost).
enum Survival {
    case pro, book
    var naslov: String { self == .pro ? "PRO kviz" : "Book kviz" }
    var fond: Fond { self == .pro ? .opste : .book }
    var tabela: String { self == .pro ? "survivor_sessions" : "book_sessions" }
    var imaRisk: Bool { self == .pro }
    var maskota: Maskota { self == .pro ? .lumi : .zig }
}

/// PRO i Book kviz: 10 života, survival, rezultat ide na rang listu za prijavljene.
struct ProKvizView: View {
    var vrsta: Survival = .pro
    @Environment(Sesija.self) private var sesija
    @Environment(Napredak.self) private var napredak
    @Environment(\.dismiss) private var zatvori

    @State private var igra = ProKviz()
    @State private var spil: Spil?
    @State private var pitanje: Prikaz?
    @State private var kljuc = UUID()
    @State private var sekundi = ProKviz.sekundi
    @State private var eliminisani: Set<Int> = []
    @State private var poruka: String?
    @State private var greska: String?
    @State private var pocetak = Date()
    @State private var sacuvano = false
    @State private var potvrdaIzlaska = false

    var body: some View {
        ZStack {
            Papir()
            if let greska {
                VStack(spacing: 14) {
                    Naslov(tekst: "Pitanja nisu stigla", velicina: 26)
                    Text(greska).font(.tekst(15)).foregroundStyle(Color.sivaTekst).multilineTextAlignment(.center)
                    Button("Nazad") { zatvori() }.buttonStyle(.primarno)
                }
                .padding(24).mirna().padding(24)
            } else if igra.gotovo {
                kraj
            } else if let pitanje {
                ScrollView {
                    VStack(spacing: 14) {
                        zaglavlje
                        if igra.riskAktivan {
                            Text("Risk aktivan: duplo dobit, duplo gubitak").font(.tekst(14, .bold))
                                .frame(maxWidth: .infinity).padding(12).pop(.zuta, radijus: 14)
                        }
                        PitanjeKartica(oznaka: pitanje.zanr.map { "Pitanje \(igra.stigao + 1) · \($0)" } ?? "Pitanje \(igra.stigao + 1)", prikaz: pitanje, sekundi: sekundi, eliminisani: eliminisani) { izabran, _ in
                            odgovori(izabran == pitanje.tacan)
                        }
                        .id(kljuc)
                        pomoci(pitanje)
                    }
                    .padding(16)
                }
            } else {
                ProgressView().controlSize(.large).tint(.mastilo)
            }
        }
        .overlay(alignment: .top) {
            if let poruka {
                Text(poruka).font(.tekst(15, .bold)).multilineTextAlignment(.center)
                    .padding(.horizontal, 18).padding(.vertical, 12).pop(.zuta, radijus: 16).padding(.top, 70).padding(.horizontal, 24)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay {
            if potvrdaIzlaska {
                Dijalog(naslov: "Prekidaš partiju?", tekst: sesija.prijavljen ? "Rezultat do sada se upisuje na rang listu." : "Rezultat se ne čuva bez naloga.",
                        potvrda: "Prekini", odustani: "Nastavi") {
                    Task { await sacuvaj(); zatvori() }
                } zatvori: { potvrdaIzlaska = false }
            }
        }
        .animation(.spring(duration: 0.3), value: poruka)
        .task { await ucitaj() }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }

    private var zaglavlje: some View {
        HStack(spacing: 10) {
            KrugDugme(ikonica: "xmark", opis: "Prekini") { potvrdaIzlaska = true }
            pokazatelj("Životi", "\(igra.zivoti)", igra.zivoti <= 3 ? .crvenaSvetla : .kartica)
            pokazatelj("Poeni", "\(igra.poeni)", .zuta)
            pokazatelj("Niz", "\(igra.kombo)", .tealSvetla)
        }
    }

    private func pokazatelj(_ naziv: String, _ vrednost: String, _ boja: Color) -> some View {
        VStack(spacing: 0) {
            Text(vrednost).font(.naslov(20)).monospacedDigit().contentTransition(.numericText())
            Oznaka(tekst: naziv)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
        .background(boja, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mastilo, lineWidth: 1.5))
        .accessibilityElement(children: .combine)
    }

    private func pomoci(_ p: Prikaz) -> some View {
        HStack(spacing: 8) {
            pomoc("50/50", "\(igra.polaPola)×", aktivno: igra.polaPola > 0 && eliminisani.isEmpty) {
                igra.polaPola -= 1; igra.iskorisceno.polaPola += 1
                eliminisani = Set((0..<4).filter { $0 != p.tacan }.shuffled().prefix(2))
            }
            pomoc("Preskoči", "\(igra.preskoci)×", aktivno: igra.preskoci > 0) {
                if igra.iskoristiPreskok() { sledece() }
            }
            pomoc("+15 s", "\(igra.dodatnoVreme)×", aktivno: igra.dodatnoVreme > 0 && sekundi == ProKviz.sekundi) {
                igra.dodatnoVreme -= 1; igra.iskorisceno.dodatnoVreme += 1; sekundi += 15
            }
            if vrsta.imaRisk { pomoc("Risk", "×2", aktivno: igra.riskDostupan) { igra.aktivirajRisk() } }
        }
    }

    private func pomoc(_ naziv: String, _ ostalo: String, aktivno: Bool, radnja: @escaping () -> Void) -> some View {
        Button(action: radnja) {
            VStack(spacing: 2) {
                Text(naziv).font(.tekst(13, .bold))
                Text(ostalo).font(.tekst(11)).foregroundStyle(Color.sivaTekst)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(aktivno ? Color.kartica : Color.udubljeno, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(aktivno ? Color.mastilo : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .disabled(!aktivno)
        .foregroundStyle(Color.mastilo)
    }

    private var kraj: some View {
        VStack(spacing: 16) {
            MaskotaSlika(maskota: vrsta.maskota, velicina: 120)
            Text("Kraj igre").font(.naslov(36))
            Text("\(igra.poeni)").font(.naslov(64)).monospacedDigit()
            Text("\(igra.stigao) pitanja · \(igra.tacnih) tačnih · najbolji niz \(igra.najboljiKombo)")
                .font(.tekst(15, .semibold)).foregroundStyle(Color.sivaTekst)
            if !sesija.prijavljen {
                Text("Prijavi se da rezultat ode na rang listu.").font(.tekst(14)).foregroundStyle(Color.sivaTekst)
            }
            Button("Igraj ponovo") { Task { await ucitaj(ponovo: true) } }.buttonStyle(.zuto)
            Button("Nazad") { zatvori() }.buttonStyle(.sekundarno)
        }
        .padding(24).pop(.kartica).padding(20)
        .task { await sacuvaj() }
    }

    private func ucitaj(ponovo: Bool = false) async {
        do {
            if spil == nil || ponovo { spil = Spil(try await PaketPitanja.deljeni.ucitaj(vrsta.fond)) }
            if ponovo { igra = ProKviz(); sacuvano = false; pocetak = Date() }
            if vrsta == .book { igra.porukaZa50 = "Književni majstor!" }
            sledece()
        } catch {
            greska = error.localizedDescription
        }
    }

    private func odgovori(_ tacan: Bool) {
        if let p = igra.odgovor(tacan: tacan) { javi(p) }
        if !igra.gotovo { sledece() }
    }

    private func sledece() {
        eliminisani = []
        sekundi = ProKviz.sekundi
        pitanje = spil?.sledece()
        kljuc = UUID()
    }

    private func javi(_ tekst: String) {
        poruka = tekst
        Task { try? await Task.sleep(for: .seconds(2.5)); if poruka == tekst { poruka = nil } }
    }

    /// Upis u survivor_sessions; samo jednom i samo ako je bar jedno pitanje odgovoreno.
    private func sacuvaj() async {
        guard !sacuvano, igra.stigao > 0 else { return }
        sacuvano = true
        napredak.zabeleziIgru(kviz: vrsta == .pro ? "pro" : "book", tacnih: igra.tacnih, netacnih: igra.netacnih, kategorija: vrsta == .pro ? "Opšte znanje" : "Knjige")
        guard let id = sesija.korisnikId, let token = try? await sesija.vazeciToken() else { return }
        let sekundi = Int(Date().timeIntervalSince(pocetak))
        let red = vrsta == .pro ? igra.red(korisnik: id, sekundi: sekundi) : igra.redBook(korisnik: id, sekundi: sekundi)
        try? await Supabase.deljeni.upisi(vrsta.tabela, red, token: token)
    }
}
