import SwiftUI

/// Brzi kviz: 60 sekundi, za svaku izjavu „tačno” ili „netačno”.
struct BrziKvizView: View {
    @Environment(Sesija.self) private var sesija
    @Environment(Napredak.self) private var napredak
    @Environment(\.dismiss) private var zatvori

    @State private var igra = BrziKviz()
    @State private var pitanja: [Pitanje] = []
    @State private var indeks = 0
    @State private var izjava: BrziKviz.Izjava?
    @State private var pocetak = Date()
    @State private var pocetakIzjave = Date()
    @State private var otkriveno: Bool?
    @State private var kraj = false
    @State private var pomocIskoriscena = false
    /// „Štit”: sledeći promašaj se ne računa (u tačno/netačno 50/50 nema smisla).
    @State private var stit = false
    @State private var nagovestaj: String?
    @State private var zbirMs = 0
    @State private var greska: String?
    @State private var sacuvano = false

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
            } else if kraj {
                krajEkran
            } else if let izjava {
                igraEkran(izjava)
            } else {
                ProgressView().controlSize(.large).tint(.mastilo)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task { await ucitaj() }
    }

    private func igraEkran(_ iz: BrziKviz.Izjava) -> some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { kontekst in
            let ostaloRunda = max(0, Double(BrziKviz.sekundiRunde) - kontekst.date.timeIntervalSince(pocetak))
            let ostaloIzjava = max(0, Double(BrziKviz.sekundiPoIzjavi) - kontekst.date.timeIntervalSince(pocetakIzjave))
            VStack(spacing: 16) {
                HStack(spacing: 10) {
                    KrugDugme(ikonica: "xmark", opis: "Prekini") { Task { await sacuvaj(); zatvori() } }
                    pokazatelj("Vreme", "\(Int(ostaloRunda.rounded(.up)))", ostaloRunda < 10 ? .crvenaSvetla : .kartica)
                    pokazatelj("Poeni", "\(igra.poeni)", .zuta)
                    pokazatelj("Tačnih", "\(igra.tacnih)", .tealSvetla)
                }
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Oznaka(tekst: "Tačno ili netačno?", boja: .mastilo)
                        Spacer()
                        Text("\(Int(ostaloIzjava.rounded(.up)))").font(.naslov(22)).monospacedDigit()
                    }
                    Naslov(tekst: iz.pitanje, velicina: 22)
                    Text(iz.prikazano).font(.naslov(30)).foregroundStyle(Color.teal)
                        .frame(maxWidth: .infinity).padding(.vertical, 22)
                        .background(Color.kartica, in: RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.mastilo, lineWidth: 2))
                    if let otkriveno {
                        Text(otkriveno ? "Tačno!" : "Ne. Tačan odgovor: \(iz.tacanOdgovor)")
                            .font(.tekst(16, .bold)).foregroundStyle(otkriveno ? Color.teal : Color.crvena)
                    }
                }
                .padding(20).pop(.zuta)
                HStack(spacing: 12) {
                    Button { odgovori(false) } label: { Label("Netačno", systemImage: "xmark").labelStyle(.titleAndIcon) }
                        .buttonStyle(DugmeStil(vrsta: .sekundarno))
                    Button { odgovori(true) } label: { Label("Tačno", systemImage: "checkmark").labelStyle(.titleAndIcon) }
                        .buttonStyle(.tealDugme)
                }
                .disabled(otkriveno != nil)
                if let nagovestaj, otkriveno == nil {
                    Label(nagovestaj, systemImage: "lightbulb").font(.tekst(14, .semibold)).foregroundStyle(Color.mastilo)
                }
                // Vreme pomera početak runde, pa sat dobija 10 sekundi.
                PomociTraka(iskoriscena: $pomocIskoriscena,
                            polaPola: otkriveno == nil ? { stit = true } : nil,
                            nagovestaj: otkriveno == nil ? { nagovestaj = "Tačan odgovor počinje na „\(iz.tacanOdgovor.prefix(1).uppercased())”." } : nil,
                            vreme: { pocetak = pocetak.addingTimeInterval(10) },
                            preskok: otkriveno == nil ? { sledeca() } : nil,
                            polaPolaNaziv: "Štit")
                Spacer()
            }
            .padding(16)
            .onChange(of: Int(ostaloRunda)) { _, s in if s <= 0 { zavrsi() } }
            .onChange(of: Int(ostaloIzjava)) { _, s in if s <= 0 && otkriveno == nil { odgovori(nil) } }
        }
    }

    private var krajEkran: some View {
        VStack(spacing: 16) {
            MaskotaSlika(maskota: .zig, velicina: 120)
            Text("Vreme je isteklo").font(.naslov(32))
            Text("\(igra.poeni)").font(.naslov(64)).monospacedDigit()
            Text("\(igra.tacnih) tačnih · \(igra.netacnih) netačnih").font(.tekst(15, .semibold)).foregroundStyle(Color.sivaTekst)
            if !sesija.prijavljen { Text("Prijavi se da rezultat ode na rang listu.").font(.tekst(14)).foregroundStyle(Color.sivaTekst) }
            Button("Igraj ponovo") { Task { await ucitaj() } }.buttonStyle(.zuto)
            Button("Nazad") { zatvori() }.buttonStyle(.sekundarno)
        }
        .padding(24).pop(.kartica).padding(20)
        .task { await sacuvaj() }
    }

    private func pokazatelj(_ naziv: String, _ vrednost: String, _ boja: Color) -> some View {
        VStack(spacing: 0) {
            Text(vrednost).font(.naslov(20)).monospacedDigit()
            Oznaka(tekst: naziv)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
        .modifier(SvetlaTema(ukljuceno: boja != .kartica))
        .background(boja, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mastilo, lineWidth: 1.5))
        .accessibilityElement(children: .combine)
    }

    private func ucitaj() async {
        do {
            pitanja = try await PaketPitanja.deljeni.ucitaj(.opste)
            igra = BrziKviz(); indeks = 0; kraj = false; sacuvano = false; otkriveno = nil; pomocIskoriscena = false; stit = false; zbirMs = 0
            pocetak = Date()
            sledeca()
        } catch { greska = error.localizedDescription }
    }

    private func sledeca() {
        guard !pitanja.isEmpty else { return }
        izjava = BrziKviz.Izjava(pitanja[indeks % pitanja.count])
        indeks += 1
        otkriveno = nil
        nagovestaj = nil
        pocetakIzjave = Date()
    }

    private func odgovori(_ kaze: Bool?) {
        guard let iz = izjava, otkriveno == nil, !kraj else { return }
        if kaze != nil { zbirMs += Int(Date().timeIntervalSince(pocetakIzjave) * 1000) }
        let pre = igra
        otkriveno = igra.odgovor(iz, kaze: kaze)
        if stit, otkriveno == false {
            igra = pre
            stit = false
        }
        // Brzi kviz ima mnogo odgovora: tiše nego u ostalim igrama.
        Zvuk.pusti(otkriveno == true ? .tacno : kaze == nil ? .isteklo : .netacno, jacina: 0.3)
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            if !kraj { sledeca() }
        }
    }

    private func zavrsi() { if !kraj { kraj = true; Zvuk.pusti(.kraj, jacina: 0.45) } }

    private func sacuvaj() async {
        guard !sacuvano, igra.tacnih + igra.netacnih > 0 else { return }
        sacuvano = true
        zavrsiPartiju(napredak, sesija, igra: "brzi", poeni: igra.poeni, tacnih: igra.tacnih, netacnih: igra.netacnih,
                      kategorija: "Opšte znanje", prosekMs: prosek(zbirMs, igra.tacnih + igra.netacnih))
        guard let id = sesija.korisnikId, let token = try? await sesija.vazeciToken() else { return }
        try? await Supabase.deljeni.upisi("quick_sessions", igra.red(korisnik: id, sekundi: Int(Date().timeIntervalSince(pocetak))), token: token)
    }
}
