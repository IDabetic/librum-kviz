import SwiftUI

/// Trivia duel: napravi sobu ili uđi kodom, pa ista pitanja jedan na jedan.
struct DuelView: View {
    @Environment(Sesija.self) private var sesija
    @Environment(\.dismiss) private var zatvori
    @State private var model: DuelModel?
    @State private var potvrdaIzlaska = false

    var body: some View {
        ZStack {
            Papir()
            if !sesija.prijavljen {
                VStack(spacing: 14) {
                    MaskotaSlika(maskota: .bloop, velicina: 110)
                    Naslov(tekst: "Duel traži nalog", velicina: 26)
                    Text("Prijavi se u kartici Profil, da bi rival znao protiv koga igra.").font(.tekst(15)).foregroundStyle(Color.sivaTekst).multilineTextAlignment(.center)
                    Button("Nazad") { zatvori() }.buttonStyle(.primarno)
                }
                .padding(24).mirna().padding(24)
            } else if let model {
                sadrzaj(model)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear { if model == nil { model = DuelModel(sesija: sesija) } }
        .overlay {
            if potvrdaIzlaska {
                Dijalog(naslov: "Napuštaš duel?", tekst: "Rival dobija 50 poena i pobedu.", potvrda: "Izađi", odustani: "Ostani") {
                    Task { await model?.napusti(); zatvori() }
                } zatvori: { potvrdaIzlaska = false }
            }
        }
    }

    @ViewBuilder private func sadrzaj(_ m: DuelModel) -> some View {
        switch m.faza {
        case .lobi: lobi(m)
        case .cekanje: cekanje(m)
        case .igra: igra(m)
        case .kraj: kraj(m)
        }
    }

    private func lobi(_ m: DuelModel) -> some View {
        @Bindable var m = m
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    KrugDugme(ikonica: "chevron.left", opis: "Nazad") { zatvori() }
                    Spacer()
                }
                ZStack(alignment: .bottomTrailing) {
                    MaskotaSlika(maskota: .bloop, velicina: 100).offset(x: 6, y: 10)
                    VStack(alignment: .leading, spacing: 8) {
                        Oznaka(tekst: "Jedan na jedan", boja: .zuta)
                        Text("Trivia duel").font(.naslov(40)).foregroundStyle(.white)
                        Text("Ista pitanja za oboje. Tačno +10, netačno −5. Nerešeno ide na zlatno pitanje.")
                            .font(.tekst(15, .semibold)).foregroundStyle(.white.opacity(0.9)).padding(.trailing, 90)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(22).clipped().pop(.mastilo)

                VStack(alignment: .leading, spacing: 12) {
                    Naslov(tekst: "Napravi sobu", velicina: 24)
                    ForEach(DuelModel.formati, id: \.0) { f in
                        Button { Task { await m.napravi(brojPitanja: f.0) } } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(f.0) pitanja").font(.tekst(17, .bold))
                                    Text(f.1).font(.tekst(13)).foregroundStyle(Color.sivaTekst)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 15, weight: .bold))
                            }
                            .foregroundStyle(Color.mastilo).padding(14)
                            .background(.white, in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.mastilo, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain).disabled(m.radi)
                    }
                }
                .padding(20).mirna()

                VStack(alignment: .leading, spacing: 12) {
                    Naslov(tekst: "Uđi kodom", velicina: 24)
                    TextField("KOD SOBE", text: $m.kod).font(.naslov(24)).textInputAutocapitalization(.characters).autocorrectionDisabled()
                        .padding(14).background(.white, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.mastilo, lineWidth: 1.5))
                    Button("Uđi u sobu") { Task { await m.pridruzi() } }.buttonStyle(.primarno).disabled(m.radi || m.kod.isEmpty)
                }
                .padding(20).mirna()

                if let g = m.greska { Text(g).font(.tekst(15, .semibold)).foregroundStyle(Color.crvena) }
            }
            .padding(16)
        }
    }

    private func cekanje(_ m: DuelModel) -> some View {
        VStack(spacing: 16) {
            MaskotaSlika(maskota: .bloop, velicina: 110).maskotaLebdi()
            Oznaka(tekst: "Kod sobe")
            Text(m.soba?.room_code ?? "").font(.naslov(54)).tracking(4).textSelection(.enabled)
            if m.jaSamDomacin {
                if m.soba?.guest_id == nil {
                    Text("Pošalji kod prijatelju. Čekamo da uđe…").font(.tekst(16)).foregroundStyle(Color.sivaTekst).multilineTextAlignment(.center)
                    ShareLink(item: "Igrajmo Trivia duel u Librum kvizu. Kod sobe: \(m.soba?.room_code ?? "")") {
                        Label("Pošalji kod", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.sekundarno)
                } else {
                    Text("Rival je u sobi!").font(.tekst(17, .bold)).foregroundStyle(Color.teal)
                    Button("Počni duel") { Task { await m.zapocni() } }.buttonStyle(.zuto)
                }
            } else {
                Text("U sobi si. Čekamo da domaćin pokrene duel…").font(.tekst(16)).foregroundStyle(Color.sivaTekst).multilineTextAlignment(.center)
            }
            Button("Odustani") { Task { await m.napusti(); zatvori() } }.buttonStyle(.sekundarno)
        }
        .padding(24).pop(.white).padding(20)
    }

    private func igra(_ m: DuelModel) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    KrugDugme(ikonica: "xmark", opis: "Napusti duel") { potvrdaIzlaska = true }
                    rezultat("Ti", m.mojiPoeni, .teal)
                    rezultat("Rival", m.njegoviPoeni, .roze)
                }
                if let p = m.prikaz {
                    DuelPitanje(model: m, prikaz: p).id(m.tekuce)
                } else {
                    ProgressView().tint(.mastilo)
                }
            }
            .padding(16)
        }
    }

    private func rezultat(_ ko: String, _ poeni: Int, _ boja: Color) -> some View {
        VStack(spacing: 0) {
            Text("\(poeni)").font(.naslov(22)).foregroundStyle(.white).monospacedDigit()
            Text(ko.uppercased()).font(.tekst(11, .bold)).tracking(1.2).foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
        .background(boja, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mastilo, lineWidth: 1.5))
        .accessibilityElement(children: .combine)
    }

    private func kraj(_ m: DuelModel) -> some View {
        let pobeda = m.mojiPoeni > m.njegoviPoeni
        let nereseno = m.mojiPoeni == m.njegoviPoeni
        return VStack(spacing: 14) {
            MaskotaSlika(maskota: pobeda ? .bloop : .zig, velicina: 120)
            Text(nereseno ? "Nerešeno!" : pobeda ? "Pobeda!" : "Poraz").font(.naslov(40))
            if m.rivalOtisao { Text("Rival je napustio duel.").font(.tekst(15)).foregroundStyle(Color.sivaTekst) }
            HStack(spacing: 10) {
                rezultat("Ti", m.mojiPoeni, .teal)
                rezultat("Rival", m.njegoviPoeni, .roze)
            }
            Button("Novi duel") { model = DuelModel(sesija: sesija) }.buttonStyle(.zuto)
            Button("Nazad") { zatvori() }.buttonStyle(.sekundarno)
        }
        .padding(24).pop(.white).padding(20)
    }
}

/// Jedno pitanje duela: tajmer, ponude, posle otkrivanja i rivalov izbor.
private struct DuelPitanje: View {
    let model: DuelModel
    let prikaz: Prikaz
    @State private var pocetak = Date()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { kontekst in
            let ostalo = max(0, DuelModel.sekundi - Int(kontekst.date.timeIntervalSince(pocetak)))
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Oznaka(tekst: model.zlatno ? "Zlatno pitanje" : "Pitanje \(model.tekuce + 1) od \(model.ukupno)", boja: .mastilo)
                    Spacer()
                    Text("\(ostalo)").font(.naslov(22)).monospacedDigit()
                        .onChange(of: ostalo) { _, s in if s == 0 { Task { await model.istekloVreme() } } }
                }
                Naslov(tekst: prikaz.tekst, velicina: 23)
                ForEach(Array(prikaz.opcije.enumerated()), id: \.offset) { i, o in
                    OdgovorDugme(slovo: ["A", "B", "C", "D"][i], tekst: o, stanje: stanje(i)) { Task { await model.odgovori(i) } }
                        .disabled(model.odgovorioSam)
                        .overlay(alignment: .trailing) {
                            if model.otkriveno, model.tekuce < model.njegovi.count, model.njegovi[model.tekuce] == i {
                                Text("Rival").font(.tekst(12, .bold)).foregroundStyle(.white).padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Color.roze, in: RoundedRectangle(cornerRadius: 8)).padding(.trailing, 12)
                            }
                        }
                }
                if model.odgovorioSam && !model.otkriveno {
                    Text("Čekamo rivala…").font(.tekst(15, .semibold)).foregroundStyle(Color.sivaTekst)
                }
            }
            .padding(20).pop(model.zlatno ? .narandzasta : .zuta)
        }
    }

    private func stanje(_ i: Int) -> OdgovorDugme.Stanje {
        let moj = model.tekuce < model.moji.count ? model.moji[model.tekuce] : nil
        guard model.otkriveno else { return model.odgovorioSam && moj != i ? .bledo : .obicno }
        if i == prikaz.tacan { return .tacno }
        if moj == i { return .netacno }
        return .bledo
    }
}

private extension View {
    func maskotaLebdi() -> some View { modifier(Lebdenje()) }
}

private struct Lebdenje: ViewModifier {
    @State private var gore = false
    func body(content: Content) -> some View {
        content.offset(y: gore ? -6 : 6)
            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: gore)
            .onAppear { gore = true }
    }
}
