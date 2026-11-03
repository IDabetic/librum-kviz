import SwiftUI

/// Partija: igrači gore, mapa u sredini, radnje dole, pitanje preko svega.
struct OsvajanjeIgraView: View {
    @State var model: OsvajanjeModel
    @Environment(\.dismiss) private var zatvori
    @Environment(Napredak.self) private var napredak
    @Environment(Sesija.self) private var sesija
    @State private var dodatno = 0
    @State private var eliminisani: Set<Int> = []
    @State private var potvrdaIzlaska = false
    @State private var misija = false
    @State private var odbranaZa: Kontinent?
    @State private var videoMisiju = false

    private let maskota: [String: Maskota] = ["ti": .bloop, "mimi": .mimi, "zig": .zig]
    private func maskotaZa(_ p: Igrac) -> Maskota {
        maskota[p.id] ?? [Maskota.mimi, .zig, .bloop, .lumi][p.id.unicodeScalars.reduce(0) { $0 + Int($1.value) } % 4]
    }

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
        .task(id: ObjectIdentifier(model)) { await model.slusaj() }
        .overlay { pitanje }
        .overlay { if let b = model.bitka { BitkaView(model: model, bitka: b) } }
        .overlay { kraj }
        .onChange(of: model.stanje.faza == .kraj) { _, gotovo in
            guard gotovo, let covek = model.stanje.igraci.first(where: \.covek) else { return }
            let pobedio = (model.stanje.pobednik ?? model.stanje.poredak.first?.igrac.tim) == covek.tim
            Zvuk.pusti(pobedio ? .pobeda : .kraj, jacina: 0.5)
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

            ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.stanje.igraci, id: \.id) { p in
                    let naPotezu = p.id == model.stanje.trenutni.id && model.stanje.faza != .kraj
                    HStack(spacing: 8) {
                        MaskotaSlika(maskota: maskotaZa(p), velicina: 30)
                            .frame(width: 36, height: 36)
                            .background(Color(hex: p.boja), in: RoundedRectangle(cornerRadius: 10))
                            .overlay(alignment: .topTrailing) {
                                if p.kapiten && model.postavka?.nacin == .timovi { Image(systemName: "crown.fill").font(.system(size: 11)).foregroundStyle(Color.zuta).offset(x: 4, y: -4) }
                            }
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
                    .frame(minWidth: 110)
                }
            }
            .padding(.horizontal, 16)
            }
            if let t = model.mojTim, model.stanje.misije[t] != nil {
                Button { misija = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "flag.checkered").font(.system(size: 15, weight: .bold))
                        Text(Misije.tekst(model.stanje.misije[t])).font(.tekst(13, .semibold)).lineLimit(1)
                        Spacer()
                        Text("\(Int(model.stanje.napredakMisije(t) * 100))%").font(.tekst(13, .bold)).monospacedDigit()
                    }
                    .foregroundStyle(Color.tinta).padding(.horizontal, 12).padding(.vertical, 8).pop(.zuta, radijus: 14)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .accessibilityLabel("Tajna misija")
            }
            if let k = model.kontinentiBezOdbrane.first {
                Button { odbranaZa = k } label: {
                    Label("Držiš \(k.ime): izaberi odbranu", systemImage: "shield.lefthalf.filled").font(.tekst(14, .bold))
                        .foregroundStyle(.white).frame(maxWidth: .infinity).padding(10).background(Color.teal, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mastilo, lineWidth: 2))
                }
                .buttonStyle(.plain).padding(.horizontal, 16)
            }

            MapaView(stanje: model.stanje, izabrana: model.izabrana, mete: model.mete, meta: model.meta, izvori: model.izvori,
                     fokus: model.otvoreno?.kuda ?? model.izabrana ?? model.stanje.igraci.first(where: \.covek)?.prestonica) { model.dodir($0) }
                .padding(.horizontal, 12)

            VStack(spacing: 10) {
                Text(model.uputstvo).font(.tekst(15, .semibold)).frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.updatesFrequently)
                if let p = model.postavljanje {
                    HStack(spacing: 10) {
                        Button("Ispočetka") { model.ponistiPostavljanje() }.buttonStyle(.sekundarno).disabled(p.drzave.isEmpty)
                        if p.drzave.count == Pravila.pocetnihDrzava && model.zaPostavljanje > 0 {
                            Button("Rasporedi sam") { model.rasporediPostavljanjeSam() }.buttonStyle(.sekundarno)
                        } else {
                            Button("Kreni") { model.zavrsiPostavljanje() }.buttonStyle(.primarno)
                                .disabled(p.drzave.count < Pravila.pocetnihDrzava || model.zaPostavljanje > 0)
                        }
                    }
                }
                if model.meta == nil && model.covekNaPotezu && model.stanje.faza == .raspored {
                    Button("Rasporedi sam") { model.rasporediSam() }.buttonStyle(.sekundarno)
                }
                if model.meta == nil && model.covekNaPotezu && model.stanje.faza == .napad {
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
        // Dodir mete otvara list: ime, vlasnik, zanimljivost, uslov bitke, pa Odustani ili Napadni.
        .overlay {
            if let izvor = model.izabrana, let meta = model.meta {
                DonjiList(zatvori: { withAnimation { model.odustaniOdMete() } }) { panelNapada(izvor, meta) }
            }
        }
        .animation(.easeOut(duration: 0.25), value: model.meta)
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
        .overlay { if misija, let t = model.mojTim { misijaList(t) } }
        .overlay { if let k = odbranaZa { odbranaList(k) } }
        .onChange(of: model.spremno, initial: true) { _, da in
            guard da, model.postavka != nil, !videoMisiju else { return }
            videoMisiju = true
            // Na jednom kontinentu nema tajne misije: cilj je ceo kontinent, partija kreće odmah.
            if model.postavka?.teren == nil { misija = true } else { model.pocniPostavljanje(); model.javi("Cilj: osvoji ceo kontinent") }
        }
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
                Color.senka.opacity(0.6).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 12) {
                        PitanjeKartica(
                            oznaka: oznaka(o),
                            prikaz: o.prikaz,
                            sekundi: Pravila.sekundiPoPitanju + dodatno,
                            dodatak: o.rival.map { "Rival je odgovorio \($0.tacan ? "tačno" : "netačno") za \(String(format: "%.1f", Double($0.ms) / 1000)) s" },
                            eliminisani: eliminisani
                        ) { izabran, ms in eliminisani = []; dodatno = 0; model.odgovoreno(izabran, ms: ms) }
                        .id(o.id)
                        PomociTraka(iskoriscena: Binding(get: { model.pomocIskoriscena }, set: { model.pomocIskoriscena = $0 }),
                                    polaPola: { eliminisani = Set((0..<4).filter { $0 != o.prikaz.tacan }.shuffled().prefix(2)) },
                                    nagovestaj: { if let i = (0..<4).filter({ $0 != o.prikaz.tacan && !eliminisani.contains($0) }).randomElement() { eliminisani.insert(i) } },
                                    vreme: { dodatno += 10 },
                                    preskok: { eliminisani = []; dodatno = 0; model.zameniPitanje() },
                                    tamno: true, napomena: false)
                        Text(model.pomocIskoriscena ? "Pomoć je iskorišćena u ovoj partiji." : "Jedna pomoć po partiji, iz dnevnog fonda.")
                            .font(.tekst(13, .semibold)).foregroundStyle(.white)
                    }
                    .padding(16)
                    .padding(.top, 40)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }

    /// Pre bitke: iz koje države, šta (prazno polje ili igrač), pod kojim uslovom i šta se rizikuje.
    private func panelNapada(_ izvor: String, _ meta: String) -> some View {
        let s = model.stanje
        let mojaVojska = s.oblasti[izvor]?.vojske ?? 0
        let cilj = s.oblasti[meta]
        let vlasnik = s.igraci.first { $0.tim == cilj?.vlasnik }
        let uslov = s.uslovBitke(meta)
        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Oznaka(tekst: vlasnik.map { "Drži \($0.ime)" } ?? "Prazno polje", boja: vlasnik.map { Color(hex: $0.boja) } ?? .sivaTekst)
                Text(Mapa.oblast(meta).ime).font(.naslov(34)).foregroundStyle(Color.mastilo)
            }
            // Dve zanimljivosti; glavni grad je najmanje zanimljiv, pa ide poslednji.
            ForEach((Cinjenice.sve[meta] ?? []).sorted { !$0.hasPrefix("Glavni grad") && $1.hasPrefix("Glavni grad") }.prefix(2), id: \.self) { c in
                Label(c, systemImage: "lightbulb").font(.tekst(14)).foregroundStyle(Color.mastilo)
            }
            redDrzave("Napadaš iz", Mapa.oblast(izvor).ime, vojski(mojaVojska), boja: s.igraci.first { $0.tim == s.trenutni.tim }.map { Color(hex: $0.boja) } ?? .teal)
            redDrzave("Brani", vlasnik?.ime ?? "Niko (prazno polje)", vojski(cilj?.vojske ?? 0),
                      boja: vlasnik.map { Color(hex: $0.boja) } ?? Color.kremTamnija)
            if let o = s.odbranaMete(meta) {
                Label("Odbrana: \(o.naziv)", systemImage: o.ikonica).font(.tekst(13, .bold)).foregroundStyle(Color.crvena)
            }
            Label(vlasnik == nil
                  ? "\(uslov.pitanja == 1 ? "Jedno pitanje" : "\(uslov.pitanja) pitanja"), \(uslov.sekundi) s. Ako pogrešiš, gubiš vojsku, a država ostaje prazna."
                  : "\(uslov.pitanja) pitanja po \(uslov.sekundi) s protiv igrača \(vlasnik!.ime). Ako izgubiš, \(vlasnik!.ime) uzima \(Mapa.oblast(izvor).ime).",
                  systemImage: vlasnik == nil ? "flag" : "exclamationmark.triangle")
                .font(.tekst(13, .semibold)).foregroundStyle(vlasnik == nil ? Color.sivaTekst : Color.crvena)
            HStack(spacing: 10) {
                Button("Odustani") { model.odustaniOdMete() }.buttonStyle(.sekundarno)
                Button("Napadni") { model.napadni() }.buttonStyle(.primarno)
            }
        }
    }

    /// 1 vojska, 2–4 vojske, 5+ vojski (i 21 vojska, 22 vojske…).
    private func vojski(_ n: Int) -> String {
        let (d, s) = (n % 10, n % 100)
        return "\(n) " + (d == 1 && s != 11 ? "vojska" : (2...4).contains(d) && !(12...14).contains(s) ? "vojske" : "vojski")
    }

    private func redDrzave(_ oznaka: String, _ ime: String, _ opis: String, boja: Color) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 4).fill(boja).frame(width: 14, height: 14).overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.mastilo, lineWidth: 1.5))
            VStack(alignment: .leading, spacing: 1) {
                Oznaka(tekst: oznaka)
                Text(ime).font(.tekst(16, .bold))
            }
            Spacer()
            Text(opis).font(.tekst(13, .semibold)).foregroundStyle(Color.sivaTekst)
        }
        .accessibilityElement(children: .combine)
    }

    private func oznaka(_ o: OsvajanjeModel.Otvoreno) -> String { "Snabdevanje" }

    @ViewBuilder private var kraj: some View {
        if model.stanje.faza == .kraj {
            let poredak = model.stanje.poredak
            let pobednik = model.stanje.pobednik.flatMap { t in model.stanje.igraci.first { $0.tim == t } } ?? poredak[0].igrac
            ZStack {
                Color.senka.opacity(0.6).ignoresSafeArea()
                VStack(spacing: 14) {
                    MaskotaSlika(maskota: maskotaZa(pobednik), velicina: 120)
                    let timPobednik = model.stanje.pobednik
                    if let tp = timPobednik { Text("Misija ispunjena: \(Misije.tekst(model.stanje.misije[tp]))").font(.tekst(14, .bold)).multilineTextAlignment(.center) }
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
                    Button("Nova partija") {
                        model = model.postavka.map { OsvajanjeModel(postavka: $0) } ?? OsvajanjeModel(krugova: model.stanje.ukupnoKrugova, tezina: tezina, ime: model.stanje.igraci[0].ime)
                    }
                        .buttonStyle(.zuto)
                    Button("Nazad") { zatvori() }.buttonStyle(.sekundarno)
                    if let ja = model.stanje.igraci.first(where: \.covek) {
                        PodeliRezultat(igra: "Osvajanje sveta", naslov: pobednik.covek ? "Svet je moj!" : "Osvajanje sveta",
                                       veliko: "\(model.stanje.oblastiIgraca(ja.id).count) država", detalji: ["\(model.stanje.poeni(ja.id)) poena"],
                                       ilustracija: "Igra_osvajanje", boja: .teal, objava: ("osvajanje", model.stanje.poeni(ja.id)))
                    }
                }
                .padding(22)
                .pop(pobednik.covek ? .teal : .kartica)
                .padding(20)
            }
        }
    }

    private func misijaList(_ tim: String) -> some View {
        DonjiList(zatvori: { misija = false; model.pocniPostavljanje() }) {
            VStack(alignment: .leading, spacing: 12) {
                Oznaka(tekst: "Tajna misija · vidi je samo tvoj tim", boja: .roze)
                Naslov(tekst: Misije.tekst(model.stanje.misije[tim]), velicina: 26)
                if let meta = model.stanje.metaMisije[tim], let ime = model.stanje.igraci.first(where: { $0.tim == meta })?.ime {
                    Text("Meta: \(ime)").font(.tekst(15, .bold))
                }
                let n = model.stanje.napredakMisije(tim)
                GeometryReader { g in
                    RoundedRectangle(cornerRadius: 6).fill(Color.udubljeno)
                        .overlay(alignment: .leading) { RoundedRectangle(cornerRadius: 6).fill(Color.teal).frame(width: g.size.width * n) }
                }
                .frame(height: 12)
                Text("Ispunjeno \(Int(n * 100))%. Prva ispunjena misija odmah pobeđuje; inače posle poslednjeg kruga pobeđuje najviše poena.")
                    .font(.tekst(14)).foregroundStyle(Color.sivaTekst)
                Text("Kontinenti").font(.tekst(15, .bold)).padding(.top, 4)
                ForEach(Kontinenti.svi, id: \.id) { k in
                    let drzi = model.stanje.igraci.first { model.stanje.drziKontinent($0.tim, k.id) }
                    HStack {
                        Text(k.ime).font(.tekst(14, .semibold))
                        Spacer()
                        if let d = drzi {
                            Text(d.ime).font(.tekst(13, .bold)).foregroundStyle(Color(hex: d.boja))
                            if let o = model.stanje.odbrane[k.id] { Image(systemName: o.ikonica).accessibilityLabel(o.naziv) }
                        } else {
                            Text("niko ceo").font(.tekst(13)).foregroundStyle(Color.sivaTekst)
                        }
                    }
                }
                Button("Važi") { misija = false; model.pocniPostavljanje() }.buttonStyle(.primarno)
            }
        }
    }

    private func odbranaList(_ k: Kontinent) -> some View {
        DonjiList(zatvori: { odbranaZa = nil }) {
            VStack(alignment: .leading, spacing: 10) {
                Naslov(tekst: "Odbrana: \(k.ime)", velicina: 26)
                Text("Važi dok držiš ceo kontinent. Menja se najviše jednom po krugu, na tvom potezu. Cena se plaća vojskama iz pojačanja svakog kruga.")
                    .font(.tekst(13)).foregroundStyle(Color.sivaTekst)
                ForEach(Odbrana.allCases) { o in
                    Button { model.postaviOdbranu(k.id, o); odbranaZa = nil } label: {
                        HStack(spacing: 12) {
                            Image(systemName: o.ikonica).font(.system(size: 17, weight: .bold)).frame(width: 40, height: 40)
                                .background(Color.udubljeno, in: RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(o.naziv).font(.tekst(15, .bold))
                                Text(o.opis).font(.tekst(12)).foregroundStyle(Color.sivaTekst)
                            }
                            Spacer()
                            Text(o.cena == 0 ? "besplatno" : "\(o.cena) vojske/krug").font(.tekst(12, .bold))
                        }
                        .foregroundStyle(Color.mastilo).padding(10)
                        .background(Color.kartica, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.kremTamnija, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var tezina: Tezina {
        Tezina.allCases.first { $0.tacnost == model.stanje.tacnostBota } ?? .normalno
    }
}
