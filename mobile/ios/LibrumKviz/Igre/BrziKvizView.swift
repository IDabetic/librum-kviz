import SwiftUI

/// Brzi kviz: 60 sekundi, za svaku izjavu „tačno” ili „netačno”.
struct BrziKvizView: View {
    @Environment(Sesija.self) private var sesija
    @Environment(\.dismiss) private var zatvori

    @State private var igra = BrziKviz()
    @State private var pitanja: [Pitanje] = []
    @State private var indeks = 0
    @State private var izjava: BrziKviz.Izjava?
    @State private var pocetak = Date()
    @State private var pocetakIzjave = Date()
    @State private var otkriveno: Bool?
    @State private var kraj = false
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
                    pokazatelj("Vreme", "\(Int(ostaloRunda.rounded(.up)))", ostaloRunda < 10 ? .crvenaSvetla : .white)
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
                        .background(.white, in: RoundedRectangle(cornerRadius: 18))
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
        .padding(24).pop(.white).padding(20)
        .task { await sacuvaj() }
    }

    private func pokazatelj(_ naziv: String, _ vrednost: String, _ boja: Color) -> some View {
        VStack(spacing: 0) {
            Text(vrednost).font(.naslov(20)).monospacedDigit()
            Oznaka(tekst: naziv)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
        .background(boja, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mastilo, lineWidth: 1.5))
        .accessibilityElement(children: .combine)
    }

    private func ucitaj() async {
        do {
            pitanja = try await PaketPitanja.deljeni.ucitaj(.opste)
            igra = BrziKviz(); indeks = 0; kraj = false; sacuvano = false; otkriveno = nil
            pocetak = Date()
            sledeca()
        } catch { greska = error.localizedDescription }
    }

    private func sledeca() {
        guard !pitanja.isEmpty else { return }
        izjava = BrziKviz.Izjava(pitanja[indeks % pitanja.count])
        indeks += 1
        otkriveno = nil
        pocetakIzjave = Date()
    }

    private func odgovori(_ kaze: Bool?) {
        guard let iz = izjava, otkriveno == nil, !kraj else { return }
        otkriveno = igra.odgovor(iz, kaze: kaze)
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            if !kraj { sledeca() }
        }
    }

    private func zavrsi() { if !kraj { kraj = true } }

    private func sacuvaj() async {
        guard !sacuvano, igra.tacnih + igra.netacnih > 0, let id = sesija.korisnikId, let token = try? await sesija.vazeciToken() else { return }
        sacuvano = true
        try? await Supabase.deljeni.upisi("quick_sessions", igra.red(korisnik: id, sekundi: Int(Date().timeIntervalSince(pocetak))), token: token)
    }
}
