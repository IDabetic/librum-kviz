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
    /// Slova se kucaju tastaturom telefona (vlasnik 03.11), ne dugmićima na ekranu.
    @State private var unos = ""
    @FocusState private var tastatura: Bool


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
                UcitavanjeMaskota(maskota: .bloop, tekst: "Biram reč…")
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task { await ucitaj() }
        .onChange(of: igra.status) { _, s in
            if s != .igra { Task { await sacuvaj() } }
            if s == .pobeda { Zvuk.pusti(.osvojeno, jacina: 0.5) } else if s == .poraz { Zvuk.pusti(.netacno, jacina: 0.5) }
        }
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
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        if let k = r.category { Oznaka(tekst: k, boja: .mastilo) }
                        if let h = r.hint { Text(h).font(.tekst(17, .semibold)).fixedSize(horizontal: false, vertical: true) }
                    }
                    Spacer(minLength: 0)
                    VesalaCrtez(greske: Vesanje.pocetniZivoti - igra.zivoti, kraj: igra.status == .poraz)
                        .frame(width: 96, height: 116)
                }
                FlowReci(znakovi: igra.prikaz)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .accessibilityLabel(igra.prikaz.map { $0 == "_" ? "prazno" : $0 }.joined(separator: " "))
            }
            .padding(20).pop(.zuta)
            .contentShape(Rectangle())
            .onTapGesture { tastatura = false }

            if igra.status == .igra {
                if !celaRec {
                    // Skriveno polje drži tastaturu telefona; svako otkucano slovo je pokušaj.
                    TextField("", text: $unos)
                        .focused($tastatura)
                        .textInputAutocapitalization(.characters).autocorrectionDisabled().keyboardType(.default)
                        .frame(width: 1, height: 1).opacity(0.01)
                        .accessibilityLabel("Otkucaj slovo")
                        .onChange(of: unos) { staro, novo in
                            // Obrađuju se samo novododata slova; polje se ne briše dok se kuca (brisanje gubi slova u letu).
                            guard novo.count > staro.count, novo.hasPrefix(staro) else { return }
                            for z in novo.dropFirst(staro.count) where igra.status == .igra {
                                let slovo = String(z).uppercased()
                                if Vesanje.azbuka.contains(slovo) && !igra.iskorisceno(slovo) { igra.pogodi(slovo); Zvuk.pusti(igra.rec.uppercased().contains(slovo) ? .slovoDa : .slovoNe, jacina: 0.4) }
                            }
                        }
                    // Vlasnik 03.11: tastatura sa našim slovima (Č, Ć, Đ, Š, Ž) koja boji iskorišćena; sistemska ostaje za brzo kucanje.
                    AzbukaTastatura(igra: igra) { slovo in
                        igra.pogodi(slovo)
                        Zvuk.pusti(igra.rec.uppercased().contains(slovo) ? .slovoDa : .slovoNe, jacina: 0.4)
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
                    Button("Pogodi celu reč") { tastatura = false; celaRec = true }.buttonStyle(.sekundarno)
                    // 50/50 gasi pola suvišnih slova, nagoveštaj otkriva slovo, umesto vremena vraća se život.
                    PomociTraka(iskoriscena: $pomocIskoriscena,
                                polaPola: { igra.skloniPolovinuSlova() },
                                nagovestaj: { igra.otkrijSlovo() },
                                vreme: igra.zivoti < Vesanje.pocetniZivoti ? { igra.dodajZivot() } : nil,
                                preskok: { sledeca() },
                                vremeJeZivot: true)
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
        unos = ""
        tastatura = false
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


/// Vešala: konstrukcija stoji od početka, a svaki promašaj dodaje deo čoveka (glava, telo, ruke, noge).
struct VesalaCrtez: View {
    let greske: Int
    var kraj = false

    var body: some View {
        Canvas { ctx, v in
            let w = v.width, h = v.height
            let debelo = StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
            var konstr = Path()
            konstr.move(to: CGPoint(x: w * 0.08, y: h * 0.96)); konstr.addLine(to: CGPoint(x: w * 0.62, y: h * 0.96))
            konstr.move(to: CGPoint(x: w * 0.22, y: h * 0.96)); konstr.addLine(to: CGPoint(x: w * 0.22, y: h * 0.05))
            konstr.addLine(to: CGPoint(x: w * 0.72, y: h * 0.05))
            konstr.move(to: CGPoint(x: w * 0.22, y: h * 0.22)); konstr.addLine(to: CGPoint(x: w * 0.38, y: h * 0.05))
            konstr.move(to: CGPoint(x: w * 0.72, y: h * 0.05)); konstr.addLine(to: CGPoint(x: w * 0.72, y: h * 0.17))
            ctx.stroke(konstr, with: .color(.tinta), style: debelo)
            let boja: Color = kraj ? .crvena : .tinta
            let cx = w * 0.72, glava = h * 0.09
            if greske >= 1 { ctx.stroke(Path(ellipseIn: CGRect(x: cx - glava, y: h * 0.17, width: glava * 2, height: glava * 2)), with: .color(boja), style: debelo) }
            var telo = Path()
            let vrat = h * 0.17 + glava * 2, kuk = h * 0.62
            if greske >= 2 { telo.move(to: CGPoint(x: cx, y: vrat)); telo.addLine(to: CGPoint(x: cx, y: kuk)) }
            if greske >= 3 { telo.move(to: CGPoint(x: cx, y: vrat + h * 0.06)); telo.addLine(to: CGPoint(x: cx - w * 0.16, y: vrat + h * 0.2)) }
            if greske >= 4 { telo.move(to: CGPoint(x: cx, y: vrat + h * 0.06)); telo.addLine(to: CGPoint(x: cx + w * 0.16, y: vrat + h * 0.2)) }
            if greske >= 5 { telo.move(to: CGPoint(x: cx, y: kuk)); telo.addLine(to: CGPoint(x: cx - w * 0.14, y: h * 0.86)) }
            if greske >= 6 { telo.move(to: CGPoint(x: cx, y: kuk)); telo.addLine(to: CGPoint(x: cx + w * 0.14, y: h * 0.86)) }
            ctx.stroke(telo, with: .color(boja), style: debelo)
        }
        .animation(.spring(duration: 0.35), value: greske)
        .sensoryFeedback(.error, trigger: greske)
        .accessibilityElement()
        .accessibilityLabel(greske == 0 ? "Vešala, još nijedan promašaj" : "Vešala, \(greske) od \(Vesanje.pocetniZivoti) delova")
    }
}

/// Tastatura azbuke u tri reda: zeleno pogođeno, crveno promašeno, bledo ugašeno (50/50); dodir = pokušaj.
struct AzbukaTastatura: View {
    let igra: Vesanje
    let pogodi: (String) -> Void
    private static let redovi = [["A", "B", "C", "Č", "Ć", "D", "Đ", "E", "F"], ["G", "H", "I", "J", "K", "L", "M", "N", "O"], ["P", "R", "S", "Š", "T", "U", "V", "Z", "Ž"]]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Self.redovi, id: \.self) { red in
                HStack(spacing: 5) {
                    ForEach(red, id: \.self) { slovo in
                        let iskorisceno = igra.iskorisceno(slovo)
                        let pogodjeno = iskorisceno && igra.rec.uppercased().contains(slovo)
                        Button { pogodi(slovo) } label: {
                            Text(slovo).font(.tekst(18, .bold))
                                .foregroundStyle(iskorisceno ? Color.white : Color.mastilo)
                                .frame(maxWidth: .infinity).frame(height: 46)
                                .background(iskorisceno ? (pogodjeno ? Color.teal : Color.crvena.opacity(0.75)) : Color.kartica,
                                            in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.mastilo, lineWidth: iskorisceno ? 0 : 1.5))
                        }
                        .buttonStyle(BezPrigusenja())
                        .disabled(iskorisceno)
                        .accessibilityLabel(slovo + (iskorisceno ? (pogodjeno ? ", pogođeno" : ", promašeno") : ""))
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: igra.prikaz)
    }
}
