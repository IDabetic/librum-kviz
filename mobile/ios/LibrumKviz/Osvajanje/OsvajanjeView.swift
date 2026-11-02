import SwiftUI

/// Uvod: izbor jačine i dužine partije, pravila.
struct OsvajanjeUvodView: View {
    @Environment(Sesija.self) private var sesija
    @Environment(Napredak.self) private var napredak
    @State private var partija: Partija?

    struct Partija: Identifiable, Hashable { let id = UUID(); let tezina: Tezina; let krugova: Int }

    private let pravila: [(String, String)] = [
        ("Snabdevanje", "Na početku poteza jedno pitanje. Tačno donosi pune vojske, netačno pola."),
        ("Napad", "Iz oblasti sa bar 2 vojske napadaš susednu. Protiv rivala odgovarate oboje, a izjednačenje rešava brzina."),
        ("Proboj", "Posle osvajanja cepaš dalje iz nove oblasti. Svako treće osvajanje u nizu donosi +2 vojske."),
        ("Regioni", "Svet je podeljen na 17 regiona. Ceo region donosi bonus vojske svakog poteza."),
        ("Prestonica", "Počinješ sa prestonicom i pet susednih država. Tuđa prestonica nosi +5 vojski plena."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ZStack(alignment: .bottomTrailing) {
                    Circle().fill(.white.opacity(0.14)).frame(width: 220).offset(x: 70, y: 60)
                    MaskotaSlika(maskota: .mimi, velicina: 110).offset(x: 10, y: 14)
                    VStack(alignment: .leading, spacing: 10) {
                        Oznaka(tekst: "Glavna igra · 3 igrača", boja: .zuta)
                        Text("Osvajanje\nsveta").font(.naslov(42)).foregroundStyle(.white)
                        Text("171 država, 17 regiona i dva rivala. Svaku državu osvajaš pitanjem.")
                            .font(.tekst(15, .semibold)).foregroundStyle(.white.opacity(0.9))
                            .padding(.trailing, 100)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(22)
                .clipped()
                .pop(.teal)

                VStack(alignment: .leading, spacing: 0) {
                    Naslov(tekst: "Nova partija", velicina: 26).padding(.bottom, 8)
                    ForEach(Tezina.allCases) { t in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(t.ime).font(.tekst(17, .bold))
                            Text(t.opis).font(.tekst(13)).foregroundStyle(Color.sivaTekst)
                            HStack(spacing: 10) {
                                Button("8 krugova") { partija = Partija(tezina: t, krugova: 8) }.buttonStyle(.sekundarno)
                                Button("12 krugova") { partija = Partija(tezina: t, krugova: 12) }.buttonStyle(.primarno)
                            }
                        }
                        .padding(.vertical, 14)
                        if t != .tesko { Divider().overlay(Color.kremTamnija) }
                    }
                }
                .padding(20)
                .mirna()

                VStack(alignment: .leading, spacing: 12) {
                    Naslov(tekst: "Pravila", velicina: 26)
                    ForEach(Array(pravila.enumerated()), id: \.offset) { i, p in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(i + 1)").font(.tekst(13, .bold)).frame(width: 28, height: 28)
                                .background(Color.zuta, in: RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.mastilo, lineWidth: 1.5))
                            (Text(p.0 + ". ").font(.tekst(14, .bold)) + Text(p.1).font(.tekst(14)))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(20)
                .mirna()
            }
            .padding(16)
        }
        .background(Papir())
        .navigationTitle("Osvajanje")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $partija) { p in
            OsvajanjeIgraView(model: OsvajanjeModel(krugova: p.krugova, tezina: p.tezina, ime: sesija.nadimak))
        }
    }
}

/// Partija: igrači gore, mapa u sredini, radnje dole, pitanje preko svega.
struct OsvajanjeIgraView: View {
    @State var model: OsvajanjeModel
    @Environment(\.dismiss) private var zatvori
    @Environment(Napredak.self) private var napredak
    @Environment(Sesija.self) private var sesija
    @State private var pomocIskoriscena = false
    @State private var eliminisani: Set<Int> = []
    @State private var potvrdaIzlaska = false

    private let maskota: [String: Maskota] = ["ti": .bloop, "mimi": .mimi, "zig": .zig]

    var body: some View {
        ZStack {
            Papir()
            if let greska = model.greska {
                VStack(spacing: 14) {
                    MaskotaSlika(maskota: .zig, velicina: 110)
                    Naslov(tekst: "Pitanja nisu stigla", velicina: 26)
                    Text(greska).font(.tekst(15)).foregroundStyle(Color.sivaTekst).multilineTextAlignment(.center)
                    Button("Nazad") { zatvori() }.buttonStyle(.primarno)
                }
                .padding(24).mirna().padding(24)
            } else if !model.spremno {
                ProgressView().tint(.mastilo).controlSize(.large).accessibilityLabel("Učitavanje pitanja")
            } else {
                igra
            }
        }
        .task(id: ObjectIdentifier(model)) { await model.pokreni() }
        .overlay { pitanje }
        .overlay { kraj }
        .onChange(of: model.stanje.faza == .kraj) { _, gotovo in
            guard gotovo, let covek = model.stanje.igraci.first(where: \.covek) else { return }
            zavrsiPartiju(napredak, sesija, igra: "osvajanje", poeni: model.stanje.poeni(covek.id), tacnih: model.tacnih, netacnih: model.netacnih,
                          kategorija: "Geografija", prosekMs: prosek(model.zbirMs, model.tacnih + model.netacnih))
        }
    }

    private var igra: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                KrugDugme(ikonica: "xmark", opis: "Izađi") { potvrdaIzlaska = true }
                VStack(alignment: .leading, spacing: 6) {
                    Oznaka(tekst: "Krug \(min(model.stanje.krug, model.stanje.ukupnoKrugova)) od \(model.stanje.ukupnoKrugova)")
                    GeometryReader { g in
                        RoundedRectangle(cornerRadius: 5).fill(Color.kartica)
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 5).fill(Color.teal)
                                    .frame(width: g.size.width * Double(min(model.stanje.krug, model.stanje.ukupnoKrugova)) / Double(model.stanje.ukupnoKrugova))
                            }
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.mastilo, lineWidth: 1.5))
                    }
                    .frame(height: 10)
                }
            }
            .padding(.horizontal, 16)

            HStack(spacing: 8) {
                ForEach(model.stanje.igraci, id: \.id) { p in
                    let naPotezu = p.id == model.stanje.trenutni.id && model.stanje.faza != .kraj
                    HStack(spacing: 8) {
                        MaskotaSlika(maskota: maskota[p.id] ?? .bloop, velicina: 30)
                            .frame(width: 36, height: 36)
                            .background(Color(hex: p.boja), in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 0) {
                            Text(p.ime).font(.tekst(12, .bold)).lineLimit(1)
                            Text("\(model.stanje.poeni(p.id))").font(.naslov(16)).monospacedDigit()
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(6)
                    .background(Color.kartica, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(naPotezu ? Color.mastilo : Color.kremTamnija, lineWidth: naPotezu ? 2.5 : 1.5))
                    .opacity(p.ispao ? 0.4 : 1)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(p.ime), \(model.stanje.poeni(p.id)) poena\(naPotezu ? ", na potezu" : "")")
                }
            }
            .padding(.horizontal, 16)

            MapaView(stanje: model.stanje, izabrana: model.izabrana, mete: model.mete,
                     fokus: model.otvoreno?.kuda ?? model.izabrana ?? model.stanje.igraci.first(where: \.covek)?.prestonica) { model.dodir($0) }
                .padding(.horizontal, 12)

            VStack(spacing: 10) {
                Text(model.uputstvo).font(.tekst(15, .semibold)).frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.updatesFrequently)
                if model.covekNaPotezu && model.stanje.faza == .raspored {
                    Button("Rasporedi sam") { model.rasporediSam() }.buttonStyle(.sekundarno)
                }
                if model.covekNaPotezu && model.stanje.faza == .napad {
                    HStack(spacing: 10) {
                        if !model.stanje.utvrdjeno {
                            Button(model.utvrdjivanje ? "Odustani" : "Utvrdi") { model.prekidacUtvrdjivanja() }.buttonStyle(.sekundarno)
                        }
                        Button("Kraj poteza") { model.krajPoteza() }.buttonStyle(.primarno)
                    }
                }
            }
            .padding(14)
            .mirna()
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .overlay(alignment: .top) {
            if let poruka = model.poruka {
                Text(poruka).font(.tekst(15, .bold)).padding(.horizontal, 18).padding(.vertical, 12)
                    .pop(.zuta, radijus: 16)
                    .padding(.top, 120)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .animation(.spring(duration: 0.3), value: model.poruka)
        .overlay {
            if potvrdaIzlaska {
                Dijalog(naslov: "Napuštaš partiju?", tekst: "Partija se ne čuva.", potvrda: "Izađi", odustani: "Ostani",
                        potvrdi: { zatvori() }, zatvori: { potvrdaIzlaska = false })
            }
        }
    }

    @ViewBuilder private var pitanje: some View {
        if let o = model.otvoreno {
            ZStack {
                Color.mastilo.opacity(0.6).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 12) {
                        PitanjeKartica(
                            oznaka: oznaka(o),
                            prikaz: o.prikaz,
                            dodatak: o.rival.map { "Rival je odgovorio \($0.tacan ? "tačno" : "netačno") za \(String(format: "%.1f", Double($0.ms) / 1000)) s" },
                            eliminisani: eliminisani
                        ) { izabran, ms in eliminisani = []; model.odgovoreno(izabran, ms: ms) }
                        .id(o.id)
                        HStack {
                            PomocDugme(ikonica: "circle.lefthalf.filled", naziv: "50/50", iskoriscenaUPartiji: $pomocIskoriscena, tamno: true) {
                                eliminisani = Set((0..<4).filter { $0 != o.prikaz.tacan }.shuffled().prefix(2))
                            }
                            .frame(width: 80)
                            Text(pomocIskoriscena ? "Pomoć je iskorišćena u ovoj partiji." : "Jedna pomoć po partiji, iz dnevnog fonda.")
                                .font(.tekst(13, .semibold)).foregroundStyle(.white)
                        }
                    }
                    .padding(16)
                    .padding(.top, 40)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }

    private func oznaka(_ o: OsvajanjeModel.Otvoreno) -> String {
        switch o.vrsta {
        case .snabdevanje: "Snabdevanje"
        case .napad: "Napad · \(Mapa.oblast(o.kuda ?? "").ime)"
        case .odbrana: "Odbrana · \(Mapa.oblast(o.kuda ?? "").ime)"
        }
    }

    @ViewBuilder private var kraj: some View {
        if model.stanje.faza == .kraj {
            let poredak = model.stanje.poredak
            let pobednik = poredak[0].igrac
            ZStack {
                Color.mastilo.opacity(0.6).ignoresSafeArea()
                VStack(spacing: 14) {
                    MaskotaSlika(maskota: maskota[pobednik.id] ?? .bloop, velicina: 120)
                    Text(pobednik.covek ? "Svet je tvoj!" : "Pobeđuje \(pobednik.ime)").font(.naslov(34))
                        .foregroundStyle(pobednik.covek ? .white : .mastilo).multilineTextAlignment(.center)
                    ForEach(Array(poredak.enumerated()), id: \.offset) { i, red in
                        HStack(spacing: 10) {
                            Text("\(i + 1).").font(.tekst(15, .bold)).frame(width: 24)
                            RoundedRectangle(cornerRadius: 4).fill(Color(hex: red.igrac.boja)).frame(width: 16, height: 16)
                            Text(red.igrac.ime).font(.tekst(16, .semibold))
                            Spacer()
                            Text("\(red.poeni)").font(.naslov(20)).monospacedDigit()
                        }
                        .padding(12).pop(.kartica, radijus: 16)
                    }
                    Button("Nova partija") { model = OsvajanjeModel(krugova: model.stanje.ukupnoKrugova, tezina: tezina, ime: model.stanje.igraci[0].ime) }
                        .buttonStyle(.zuto)
                    Button("Nazad") { zatvori() }.buttonStyle(.sekundarno)
                }
                .padding(22)
                .pop(pobednik.covek ? .teal : .kartica)
                .padding(20)
            }
        }
    }

    private var tezina: Tezina {
        Tezina.allCases.first { $0.tacnost == model.stanje.tacnostBota } ?? .normalno
    }
}
