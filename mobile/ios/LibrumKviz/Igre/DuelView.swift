import SwiftUI

/// Duel iz kita (Battles): arena, brzi meč, privatna soba, izazov prijatelju,
/// traženje rivala, VS ekran, pitanja sa rezultatom uživo, ishod runde i kraj meča.
struct DuelView: View {
    /// Izazov sa profila: napravi sobu i pošalji izazov ovom igraču.
    var izazovi: (id: String, ime: String)? = nil
    /// Prihvaćen izazov: uđi u sobu ovim kodom.
    var kodSobe: String? = nil
    @Environment(Sesija.self) private var sesija
    @Environment(Napredak.self) private var napredak
    @Environment(\.dismiss) private var zatvori
    @State private var model: DuelModel?
    @State private var potvrdaIzlaska = false
    @State private var prijava = false

    var body: some View {
        ZStack {
            Papir()
            if !sesija.prijavljen {
                StanjeEkrana(maskota: .zig, naslov: "Duel traži nalog", tekst: "Rival mora da zna protiv koga igra. Prijava traje pola minuta.",
                             dugme: "Prijavi se") { prijava = true }
                    .padding(20).pop().padding(20)
                    .overlay(alignment: .topLeading) { KrugDugme(ikonica: "chevron.left", opis: "Nazad") { zatvori() }.padding(16) }
                    .frame(maxHeight: .infinity, alignment: .top)
            } else if let model {
                sadrzaj(model)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .fullScreenCover(isPresented: $prijava) { PrijavaTok() }
        .onAppear { if model == nil { model = DuelModel(sesija: sesija) } }
        .task(id: model == nil) {
            guard let m = model, sesija.prijavljen else { return }
            if let kod = kodSobe, m.faza == .lobi {
                m.kod = kod
                await m.pridruzi()
            } else if let cilj = izazovi, m.faza == .lobi {
                // Izazov bez čekanja: igram odmah, rival kad stigne (vidi DuelModel.izazovi).
                await m.izazovi(cilj.id, ime: cilj.ime)
            }
        }
        .onChange(of: model?.faza) { _, f in if f == .kraj { model?.zabelezi(napredak) } }
        .overlay {
            if potvrdaIzlaska {
                Dijalog(naslov: "Predaješ meč?", tekst: "Rival dobija 50 poena i pobedu.",
                        potvrda: "Predaj", odustani: "Ostani", opasno: true) {
                    Task { await model?.napusti(); zatvori() }
                } zatvori: { potvrdaIzlaska = false }
            }
        }
    }

    @ViewBuilder private func sadrzaj(_ m: DuelModel) -> some View {
        switch m.faza {
        case .lobi: DuelArena(model: m, zatvori: { zatvori() })
        case .trazenje: DuelTrazenje(model: m)
        case .pronadjen: DuelVS(model: m, ime: sesija.nadimak ?? "Ti", nivo: napredak.nivo)
        case .cekanje: DuelSoba(model: m, zatvori: { zatvori() })
        case .igra: DuelIgra(model: m, ime: sesija.nadimak ?? "Ti") { potvrdaIzlaska = true }
        case .kraj: DuelKraj(model: m, novi: { model = DuelModel(sesija: sesija) }, zatvori: { zatvori() })
        }
    }
}

// MARK: 01 Arena

private struct DuelArena: View {
    @Environment(Napredak.self) private var napredak
    @Environment(Mreza.self) private var mreza
    @Bindable var model: DuelModel
    let zatvori: () -> Void
    @State private var privatna = false
    @State private var izazov = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    KrugDugme(ikonica: "chevron.left", opis: "Nazad", radnja: zatvori)
                    Spacer()
                }
                Naslov(tekst: "Arena", velicina: 36)
                if !mreza.povezan { OfflineTraka() }
                brziMec
                Text("Još načina").font(.tekst(15, .bold)).padding(.top, 4)
                HStack(spacing: 12) {
                    plocica("Izazovi\nprijatelja", "person.2", .roze) { izazov = true }
                    plocica("Privatna\nsoba", "key", .nebo) { withAnimation { privatna.toggle() } }
                }
                if privatna { soba }
                MojiIzazovi(model: model)
                if let g = model.greska {
                    Label(g, systemImage: "exclamationmark.triangle").font(.tekst(14, .semibold)).foregroundStyle(Color.crvena)
                }
                Label("\(napredak.s.pobedaDuel) pobeda u duelima", systemImage: "trophy").font(.tekst(13, .semibold)).foregroundStyle(Color.sivaTekst)
                    .frame(maxWidth: .infinity)
            }
            .padding(16)
        }
        .navigationDestination(isPresented: $izazov) { DuelIzazov(model: model) }
    }

    private var brziMec: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle().fill(.white.opacity(0.14)).frame(width: 220).offset(x: 60, y: 40)
            MaskotaSlika(maskota: .zig, velicina: 110).offset(x: 8, y: 6)
            VStack(alignment: .leading, spacing: 8) {
                Label("1 na 1 uživo", systemImage: "circle.fill").font(.tekst(12, .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5).background(Color.roze, in: RoundedRectangle(cornerRadius: 9))
                Text("Brzi meč").font(.naslov(36)).foregroundStyle(.white)
                Text("Nasumičan rival · \(DuelModel.brzihPitanja) pitanja").font(.tekst(14, .semibold)).foregroundStyle(.white.opacity(0.9))
                Button { Task { await model.brziMec() } } label: {
                    Label("Nađi rivala", systemImage: "bolt").font(.tekst(15, .bold)).foregroundStyle(Color.tinta)
                        .padding(.horizontal, 16).frame(height: 44)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.tinta, lineWidth: 2))
                }
                .disabled(model.radi || !mreza.povezan)
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .pop(.ljubicasta, radijus: 28)
    }

    private func plocica(_ naslov: String, _ ikonica: String, _ boja: Color, radnja: @escaping () -> Void) -> some View {
        Button(action: radnja) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: ikonica).font(.system(size: 18, weight: .bold)).foregroundStyle(Color.tinta)
                    .frame(width: 44, height: 44).background(Color.white, in: Circle()).overlay(Circle().stroke(Color.tinta, lineWidth: 2))
                Text(naslov).font(.naslov(20)).foregroundStyle(Color.tinta).multilineTextAlignment(.leading)
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading).frame(height: 140)
            .pop(boja, radijus: 22)
        }
        .buttonStyle(.plain)
    }

    private var soba: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Napravi sobu").font(.tekst(15, .bold))
            HStack(spacing: 8) {
                ForEach(DuelModel.formati, id: \.0) { f in
                    Button("\(f.0) pitanja") { Task { await model.napravi(brojPitanja: f.0) } }
                        .font(.tekst(14, .bold)).foregroundStyle(Color.mastilo).frame(maxWidth: .infinity).frame(height: 44)
                        .background(Color.kartica, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mastilo, lineWidth: 1.5))
                        .disabled(model.radi)
                }
            }
            Text("ili uđi kodom").font(.tekst(13, .semibold)).foregroundStyle(Color.sivaTekst)
            HStack(spacing: 8) {
                TextField("KOD", text: $model.kod).font(.naslov(22)).textInputAutocapitalization(.characters).autocorrectionDisabled()
                    .padding(.horizontal, 14).frame(height: 54)
                    .background(model.greska == nil ? Color.kartica : Color.crvenaSvetla, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(model.greska == nil ? Color.mastilo : Color.crvena, lineWidth: 2))
                    .onChange(of: model.kod) { model.ocistiGresku() }
                Button { Task { await model.pridruzi() } } label: { Image(systemName: "arrow.right") }
                    .buttonStyle(.primarno).frame(width: 64).disabled(model.radi || model.kod.isEmpty).accessibilityLabel("Uđi u sobu")
            }
        }
        .padding(16).mirna()
        .transition(.opacity)
    }
}

// MARK: 02 Traženje rivala

private struct DuelTrazenje: View {
    let model: DuelModel
    @Environment(Mreza.self) private var mreza
    @State private var ugao = 0.0

    private var nemaRivala: Bool { model.trazimSekundi >= DuelModel.bezRivala }
    private var dugo: Bool { model.trazimSekundi >= DuelModel.dugoTrazenje }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button { Task { await model.otkaziTrazenje() } } label: {
                    Image(systemName: "xmark").font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 44, height: 44).overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 2))
                }
                .accessibilityLabel("Otkaži")
                Spacer()
                Label("Brzi meč · \(DuelModel.brzihPitanja) pitanja", systemImage: "bolt").font(.tekst(13, .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6).background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
                Spacer()
                Color.clear.frame(width: 44)
            }
            Spacer()
            ZStack {
                ForEach([120.0, 190, 260], id: \.self) { r in Circle().stroke(.white.opacity(0.18), lineWidth: 1.5).frame(width: r, height: r) }
                if !nemaRivala && mreza.povezan {
                    ForEach(0..<3, id: \.self) { i in
                        MaskotaSlika(maskota: [Maskota.bloop, .lumi, .zig][i], velicina: 34).frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.9), in: Circle())
                            .offset(x: 130).rotationEffect(.degrees(ugao + Double(i) * 120))
                    }
                }
                MaskotaSlika(maskota: .mimi, velicina: 70).frame(width: 96, height: 96).background(Color.white, in: Circle())
                    .overlay(Circle().stroke(Color.tinta, lineWidth: 3))
            }
            .frame(height: 280)
            .accessibilityHidden(true)
            Text(!mreza.povezan ? "Nema veze" : nemaRivala ? "Nema rivala" : dugo ? "Još tražimo…" : "Tražimo rivala…").font(.naslov(34)).foregroundStyle(.white)
            Text(!mreza.povezan ? "Poveži se na internet da nađemo rivala." : nemaRivala ? "Trenutno niko ne igra brzi meč. Izazovi prijatelja kodom ili probaj kasnije."
                    : dugo ? "Malo je igrača u ovom trenutku." : "Spajamo te sa igračem koji takođe traži meč.")
                .font(.tekst(15, .semibold)).foregroundStyle(.white.opacity(0.9)).multilineTextAlignment(.center)
            if !nemaRivala && mreza.povezan {
                Label(String(format: "0:%02d%@", model.trazimSekundi, dugo ? " · duže nego obično" : ""), systemImage: "clock").font(.tekst(13, .bold)).monospacedDigit()
                    .foregroundStyle(dugo ? Color.tinta : .white).padding(.horizontal, 14).padding(.vertical, 8)
                    .background(dugo ? Color.zuta : Color.tinta, in: RoundedRectangle(cornerRadius: 12))
            }
            Spacer()
            if nemaRivala || !mreza.povezan {
                Button("Nazad u arenu") { Task { await model.otkaziTrazenje() } }.buttonStyle(.sekundarno)
            } else {
                Button("Otkaži") { Task { await model.otkaziTrazenje() } }.buttonStyle(.sekundarno)
            }
        }
        .padding(20)
        .background(Color.ljubicasta.ignoresSafeArea())
        .onAppear {
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) { ugao = 360 }
            Zvuk.pusti(.cekanje, jacina: 0.25, ponavljaj: true)
        }
        .onDisappear { Zvuk.stani(.cekanje) }
    }
}

// MARK: 03 Rival pronađen

private struct DuelVS: View {
    let model: DuelModel
    let ime: String
    let nivo: Int

    var body: some View {
        ZStack {
            GeometryReader { g in
                Path { p in p.move(to: .zero); p.addLine(to: CGPoint(x: g.size.width, y: 0)); p.addLine(to: CGPoint(x: g.size.width, y: g.size.height * 0.4)); p.addLine(to: CGPoint(x: 0, y: g.size.height * 0.6)) }
                    .fill(Color.teal)
                Path { p in p.move(to: CGPoint(x: 0, y: g.size.height * 0.6)); p.addLine(to: CGPoint(x: g.size.width, y: g.size.height * 0.4)); p.addLine(to: CGPoint(x: g.size.width, y: g.size.height)); p.addLine(to: CGPoint(x: 0, y: g.size.height)) }
                    .fill(Color.roze)
            }
            .ignoresSafeArea()
            VStack {
                Label("\(DuelModel.brzihPitanja) pitanja · ko zna više", systemImage: "bolt").font(.tekst(14, .bold)).foregroundStyle(Color.tinta)
                    .padding(.horizontal, 14).padding(.vertical, 8).background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.tinta, lineWidth: 2))
                igrac(ime, "Nivo \(nivo) · ti", .mimi, levo: true)
                Spacer()
                Text("VS").font(.naslov(44)).foregroundStyle(Color.tinta).frame(width: 100, height: 100).background(Color.zuta, in: Circle())
                    .overlay(Circle().stroke(Color.tinta, lineWidth: 4))
                Spacer()
                igrac(model.rivalIme, "Rival", .zig, levo: false)
                Text(model.rivalOtisao ? "Rival je otišao" : "Počinje za tren…").font(.tekst(15, .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 10).background(Color.tinta, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(20)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(ime) protiv \(model.rivalIme)")
    }

    private func igrac(_ ime: String, _ opis: String, _ m: Maskota, levo: Bool) -> some View {
        VStack(alignment: levo ? .leading : .trailing, spacing: 4) {
            MaskotaSlika(maskota: m, velicina: 110).frame(width: 140, height: 140).background(Color.white, in: Circle()).overlay(Circle().stroke(Color.tinta, lineWidth: 3))
            Text(ime).font(.naslov(30)).foregroundStyle(Color.tinta)
            Oznaka(tekst: opis, boja: .tinta)
        }
        .frame(maxWidth: .infinity, alignment: levo ? .leading : .trailing)
    }
}

// MARK: Privatna soba i izazov

private struct DuelSoba: View {
    let model: DuelModel
    let zatvori: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            MaskotaSlika(maskota: .bloop, velicina: 110)
            Oznaka(tekst: "Kod sobe")
            Text(model.soba?.room_code ?? "").font(.naslov(54)).tracking(4).textSelection(.enabled)
            if model.jaSamDomacin {
                if model.soba?.guest_id == nil {
                    Text("Pošalji kod prijatelju. Čekamo da uđe…").font(.tekst(16)).foregroundStyle(Color.sivaTekst).multilineTextAlignment(.center)
                    ShareLink(item: "Igrajmo duel u Librum kvizu. Kod sobe: \(model.soba?.room_code ?? "") · librumkviz://duel/\(model.soba?.room_code ?? "")") {
                        Label("Pošalji kod", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.sekundarno)
                } else {
                    Text("\(model.rivalIme) je u sobi!").font(.tekst(17, .bold)).foregroundStyle(Color.teal)
                    Button("Počni duel") { Task { await model.zapocni() } }.buttonStyle(.zuto)
                }
            } else {
                Text("U sobi si. Čekamo da domaćin pokrene duel…").font(.tekst(16)).foregroundStyle(Color.sivaTekst).multilineTextAlignment(.center)
            }
            Button("Odustani") { Task { await model.napusti(); zatvori() } }.buttonStyle(.sekundarno)
        }
        .padding(24).pop().padding(20)
    }
}

/// Izazovi prijatelja: lista prijatelja još ne postoji (nema tabele), pa kit stanje
/// „Još nemaš prijatelje” i poziv linkom sa kodom privatne sobe.
private struct DuelIzazov: View {
    let model: DuelModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GornjaTraka()
            Naslov(tekst: "Izazovi\nprijatelja", velicina: 36)
            StanjeEkrana(maskota: .zig, naslov: "Još nemaš prijatelje", tekst: "Napravi sobu i pošalji kod. Ko uđe, igra protiv tebe uživo.")
            Spacer()
            Button { Task { await model.napravi(brojPitanja: 10) } } label: {
                HStack(spacing: 12) {
                    Image(systemName: "link").font(.system(size: 18, weight: .bold)).frame(width: 44, height: 44).background(Color.white, in: Circle())
                        .overlay(Circle().stroke(Color.tinta, lineWidth: 2))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pozovi kodom sobe").font(.tekst(15, .bold))
                        Text("10 pitanja · kod deliš porukom").font(.tekst(13))
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(Color.tinta).padding(14).pop(.zuta, radijus: 20)
            }
            .buttonStyle(.plain)
            .disabled(model.radi)
        }
        .padding(16)
        .background(Papir())
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: 04–05 Pitanje i ishod runde

private struct DuelIgra: View {
    let model: DuelModel
    let ime: String
    let predaj: () -> Void
    @State private var pomocIskoriscena = false
    @State private var eliminisani: Set<Int> = []

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    KrugDugme(ikonica: "flag", opis: "Predaj meč", radnja: predaj)
                    Spacer()
                }
                TimelineView(.periodic(from: .now, by: 1)) { _ in tabla }
                if model.slabaVeza {
                    Label("Slaba veza. Odgovori se čuvaju čim se veza vrati.", systemImage: "wifi.exclamationmark").font(.tekst(13, .bold))
                        .foregroundStyle(Color.tinta).padding(10).frame(maxWidth: .infinity, alignment: .leading).pop(.zuta, radijus: 14)
                }
                if let p = model.prikaz {
                    DuelPitanje(model: model, prikaz: p, eliminisani: eliminisani).id(model.tekuce)
                    if !model.odgovorioSam {
                        PomociTraka(iskoriscena: $pomocIskoriscena,
                                    polaPola: { eliminisani = Set((0..<4).filter { $0 != p.tacan }.shuffled().prefix(2)) },
                                    nagovestaj: { if let i = (0..<4).filter({ $0 != p.tacan && !eliminisani.contains($0) }).randomElement() { eliminisani.insert(i) } },
                                    vreme: { model.dodatnoSekundi += 10 },
                                    preskok: { Task { await model.odgovori(nil, preskok: true) } })
                    }
                } else {
                    Skelet(visina: 360, radijus: 24)
                }
                if model.odgovorioSam && !model.otkriveno {
                    Label(model.rivalNeOdgovara ? "\(model.rivalIme) ne odgovara. Možda je izgubio vezu…" : "\(model.rivalIme) razmišlja…",
                          systemImage: model.rivalNeOdgovara ? "wifi.slash" : "ellipsis.bubble")
                        .font(.tekst(14, .bold)).padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Color.kartica, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mastilo, lineWidth: 2))
                } else if !model.odgovorioSam && model.odgovorioJe && !model.otkriveno {
                    Label("\(model.rivalIme) je već odgovorio", systemImage: "bolt").font(.tekst(14, .bold))
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Color.kartica, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mastilo, lineWidth: 2))
                }
                if let r = model.runda { ishodRunde(r) }
            }
            .padding(16)
        }
        .onChange(of: model.tekuce) { eliminisani = [] }
    }

    private var tabla: some View {
        let ukupno = max(1, model.mojiPoeni + model.njegoviPoeni)
        return VStack(spacing: 8) {
            HStack(spacing: 10) {
                MaskotaSlika(maskota: .mimi, velicina: 36).frame(width: 44, height: 44).background(Color.teal, in: Circle())
                VStack(alignment: .leading, spacing: 0) {
                    Text(ime).font(.tekst(12, .bold)).foregroundStyle(.white.opacity(0.8)).lineLimit(1)
                    Text("\(model.mojiPoeni)").font(.naslov(24)).foregroundStyle(.white).monospacedDigit().contentTransition(.numericText())
                }
                Spacer()
                VStack(spacing: 4) {
                    Text(model.zlatno ? "ZLATNO" : "RUNDA \(model.tekuce + 1)/\(model.ukupno)").font(.tekst(10, .bold)).foregroundStyle(.white.opacity(0.8))
                    RoundedRectangle(cornerRadius: 8).fill(Color.zuta).frame(width: 64, height: 22)
                        .overlay(Text("\(model.ostaloSekundi)").font(.tekst(12, .bold)).foregroundStyle(Color.tinta).monospacedDigit())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(model.rivalIme).font(.tekst(12, .bold)).foregroundStyle(.white.opacity(0.8)).lineLimit(1)
                    Text("\(model.njegoviPoeni)").font(.naslov(24)).foregroundStyle(.white).monospacedDigit().contentTransition(.numericText())
                }
                MaskotaSlika(maskota: .zig, velicina: 36).frame(width: 44, height: 44).background(Color.roze, in: Circle())
            }
            .padding(12).background(Color.tinta, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            GeometryReader { g in
                HStack(spacing: 0) {
                    Rectangle().fill(Color.teal).frame(width: g.size.width * (model.mojiPoeni + model.njegoviPoeni == 0 ? 0.5 : Double(model.mojiPoeni) / Double(ukupno)))
                    Rectangle().fill(Color.roze)
                }
                .clipShape(RoundedRectangle(cornerRadius: 5)).overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.mastilo, lineWidth: 1.5))
            }
            .frame(height: 10)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ti \(model.mojiPoeni), \(model.rivalIme) \(model.njegoviPoeni)")
    }

    private func ishodRunde(_ r: DuelModel.Runda) -> some View {
        let (naslov, boja): (String, Color) = switch r {
        case .meni: ("Runda je tvoja!", .teal)
        case .rivalu: ("Runda za \(model.rivalIme)", .roze)
        case .oboje: ("Oboje tačno!", .ljubicasta)
        case .niko: ("Niko ne boduje", .narandzasta)
        }
        let p = model.prikaz
        return VStack(alignment: .leading, spacing: 6) {
            Text(naslov).font(.naslov(26)).foregroundStyle(boja == .narandzasta ? Color.tinta : .white)
            if let p { Text("Tačno je: \(p.opcije[p.tacan])").font(.tekst(14, .semibold)).foregroundStyle(boja == .narandzasta ? Color.tinta : .white) }
            Text(model.tekuce + 1 < model.ukupno ? "Runda \(model.tekuce + 2) za tren…" : "Kraj meča za tren…").font(.tekst(13, .bold))
                .foregroundStyle(.white).padding(.horizontal, 12).padding(.vertical, 6).background(Color.tinta, in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .trailing) { MaskotaSlika(maskota: r == .meni ? .bloop : .zig, velicina: 80).padding(.trailing, 8) }
        .pop(boja, radijus: 22)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

/// Jedno pitanje duela: tajmer, ponude, posle otkrivanja i rivalov izbor.
private struct DuelPitanje: View {
    let model: DuelModel
    let prikaz: Prikaz
    var eliminisani: Set<Int> = []
    @State private var pocetak = Date()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { kontekst in
            let ostalo = max(0, DuelModel.sekundi - Int(kontekst.date.timeIntervalSince(pocetak)))
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Oznaka(tekst: model.zlatno ? "Zlatno pitanje" : "Pitanje \(model.tekuce + 1) od \(model.ukupno)", boja: .tinta)
                    Spacer()
                    Text("\(ostalo)").font(.naslov(22)).monospacedDigit().foregroundStyle(ostalo <= 5 ? Color.crvena : Color.tinta)
                        .onChange(of: ostalo) { _, s in if s == 0 { Task { await model.istekloVreme() } } }
                }
                Text(prikaz.tekst).font(.naslov(22)).foregroundStyle(Color.tinta).fixedSize(horizontal: false, vertical: true)
                ForEach(Array(prikaz.opcije.enumerated()), id: \.offset) { i, o in
                    OdgovorDugme(slovo: ["A", "B", "C", "D"][i], tekst: o, stanje: stanje(i)) { Task { await model.odgovori(i) } }
                        .disabled(model.odgovorioSam || eliminisani.contains(i))
                        .opacity(eliminisani.contains(i) && !model.otkriveno ? 0.25 : 1)
                        .overlay(alignment: .topTrailing) {
                            HStack(spacing: 4) {
                                if model.otkriveno, model.tekuce < model.moji.count, model.moji[model.tekuce] == i { znacka("Ti", .teal) }
                                if model.otkriveno, model.tekuce < model.njegovi.count, model.njegovi[model.tekuce] == i { znacka(model.rivalIme, .roze) }
                            }
                            .offset(x: -8, y: -10)
                        }
                }
            }
            .padding(20).pop(model.zlatno ? .narandzasta : .zuta)
        }
    }

    private func znacka(_ tekst: String, _ boja: Color) -> some View {
        Text(tekst).font(.tekst(11, .bold)).foregroundStyle(.white).lineLimit(1).padding(.horizontal, 8).padding(.vertical, 3)
            .background(boja, in: RoundedRectangle(cornerRadius: 7)).overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.tinta, lineWidth: 1.5))
    }

    private func stanje(_ i: Int) -> OdgovorDugme.Stanje {
        let moj = model.tekuce < model.moji.count ? model.moji[model.tekuce] : nil
        guard model.otkriveno else { return model.odgovorioSam && moj != i ? .bledo : .obicno }
        if i == prikaz.tacan { return .tacno }
        if moj == i { return .netacno }
        return .bledo
    }
}

// MARK: 06 Kraj meča

private struct DuelKraj: View {
    let model: DuelModel
    let novi: () -> Void
    let zatvori: () -> Void

    private var pobeda: Bool { model.mojiPoeni > model.njegoviPoeni && !model.cekaRivala }
    private var nereseno: Bool { model.mojiPoeni == model.njegoviPoeni }

    var body: some View {
        if model.cekaRivala { cekaRivala } else { ishod }
    }

    /// Izazivač je odigrao: rezultat stoji, ishod stiže kad rival odigra (Sanduče i lista izazova u Areni).
    private var cekaRivala: some View {
        VStack(spacing: 14) {
            HStack { KrugDugme(ikonica: "xmark", opis: "Zatvori", radnja: zatvori); Spacer() }
            Spacer()
            MaskotaSlika(maskota: .lumi, velicina: 130).frame(width: 170, height: 170)
                .background(Color.zuta, in: Circle()).overlay(Circle().stroke(Color.tinta, lineWidth: 3))
            Text("Izazov je poslat").font(.naslov(38)).foregroundStyle(.white)
            Text("\(model.rivalIme) igra ista pitanja kad stigne, do 24 h. Ishod stiže u Sanduče.")
                .font(.tekst(15, .semibold)).foregroundStyle(.white.opacity(0.9)).multilineTextAlignment(.center)
            Text("\(model.mojiPoeni) poena").font(.naslov(40)).foregroundStyle(Color.tinta).monospacedDigit()
                .frame(maxWidth: .infinity).padding(.vertical, 16).background(Color.white, in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.tinta, lineWidth: 2.5))
            Spacer()
            Button("Nazad", action: zatvori).buttonStyle(.primarno)
        }
        .padding(20)
        .background(Color.ljubicasta.ignoresSafeArea())
        .onAppear { Zvuk.pusti(.kraj, jacina: 0.5) }
    }

    private var ishod: some View {
        let boja: Color = nereseno ? .nebo : pobeda ? .teal : .roze
        return VStack(spacing: 14) {
            HStack {
                KrugDugme(ikonica: "xmark", opis: "Zatvori", radnja: zatvori)
                Spacer()
                PodeliRezultat(igra: "Duel", naslov: pobeda ? "Pobeda!" : nereseno ? "Nerešeno" : "Revanš?", veliko: "\(model.mojiPoeni)–\(model.njegoviPoeni)",
                               detalji: ["protiv \(model.rivalIme)"], ilustracija: "Igra_duel", boja: pobeda ? .teal : .nebo, objava: ("duel", model.mojiPoeni))
            }
            Spacer()
            MaskotaSlika(maskota: pobeda ? .bloop : nereseno ? .lumi : .zig, velicina: 130).frame(width: 170, height: 170)
                .background(Color.zuta, in: Circle()).overlay(Circle().stroke(Color.tinta, lineWidth: 3))
            Text(nereseno ? "Nerešeno!" : pobeda ? (model.rivalOtisao ? "Pobeda predajom" : "Pobeda!") : "Poraz").font(.naslov(42)).foregroundStyle(.white)
            Text(model.rivalOtisao && pobeda ? "\(model.rivalIme) je napustio meč. Dobijaš +\(DuelModel.bonusNapustanja) poena." :
                    nereseno ? "Isto znanje. Revanš?" : pobeda ? "Nadigrao si \(model.rivalIme)." : "\(model.rivalIme) je ovog puta bio brži.")
                .font(.tekst(15, .semibold)).foregroundStyle(.white.opacity(0.9)).multilineTextAlignment(.center)
            HStack {
                Text("\(model.mojiPoeni) – \(model.njegoviPoeni)").font(.naslov(40)).foregroundStyle(Color.tinta).monospacedDigit()
            }
            .frame(maxWidth: .infinity).padding(.vertical, 16).background(Color.white, in: RoundedRectangle(cornerRadius: 22)).overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.tinta, lineWidth: 2.5))
            HStack(spacing: 10) {
                statistika("\(model.moji.count)", "Odgovora")
                statistika("+\(model.moji.count + 5)", "XP")
            }
            Spacer()
            Button("Novi meč", action: novi).buttonStyle(.sekundarno)
            Button("Nazad", action: zatvori).buttonStyle(.primarno)
        }
        .padding(20)
        .background(boja.ignoresSafeArea())
        .overlay { if pobeda { Konfete() } }
        .onAppear { Zvuk.pusti(pobeda ? .pobeda : nereseno ? .kraj : .netacno, jacina: 0.5) }
    }

    private func statistika(_ vrednost: String, _ naziv: String) -> some View {
        VStack(spacing: 2) {
            Text(vrednost).font(.naslov(22)).foregroundStyle(.white)
            Text(naziv).font(.tekst(12, .semibold)).foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12).background(Color.tinta, in: RoundedRectangle(cornerRadius: 18))
    }
}


/// Izazovi bez čekanja u Areni: koji čekaju mene (igraj), koje sam poslao (čeka se rival) i završeni (ishod).
private struct MojiIzazovi: View {
    let model: DuelModel
    @State private var izazovi: [DuelModel.MojIzazov] = []
    @State private var igraj: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !izazovi.isEmpty {
                Text("Izazovi").font(.tekst(15, .bold)).padding(.top, 4)
                VStack(spacing: 0) {
                    ForEach(Array(izazovi.enumerated()), id: \.element.id) { i, z in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(z.rivalIme).font(.tekst(16, .bold))
                                Text(z.naMeni ? "Izazvao te je · \(z.on) poena" : z.zavrsen ? "\(z.ja) – \(z.on)" : "Čeka se da odigra · ti \(z.ja)")
                                    .font(.tekst(13)).foregroundStyle(Color.sivaTekst)
                            }
                            Spacer()
                            if z.naMeni {
                                Button("Igraj") { igraj = z.soba.room_code }.buttonStyle(.zuto).frame(width: 110)
                            } else if z.zavrsen {
                                Text(z.ja > z.on ? "Pobeda" : z.ja < z.on ? "Poraz" : "Nerešeno").font(.tekst(14, .bold))
                                    .foregroundStyle(z.ja > z.on ? Color.teal : z.ja < z.on ? Color.crvena : Color.sivaTekst)
                            } else {
                                Image(systemName: "hourglass").foregroundStyle(Color.sivaTekst).accessibilityLabel("Čeka se")
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        if i < izazovi.count - 1 { Divider().overlay(Color.kremTamnija) }
                    }
                }
                .mirna()
            }
        }
        .task { izazovi = await model.mojiIzazovi() }
        .navigationDestination(item: $igraj) { kod in DuelView(kodSobe: kod) }
    }
}
