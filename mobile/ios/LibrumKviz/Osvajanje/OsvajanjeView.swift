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
    /// Igrač kome se šalje brza poruka ili predlaže savez.
    @State private var porukaZa: Igrac?
    @State private var reprodukcija = false
    @State private var zaradjenoXp: Int?
    /// Traka „Krug N od M” koja preleti ekran na početku kruga.
    @State private var banerKruga: Int?
    /// Vodič za prvu partiju (vlasnik 04.11): korak po korak dok igrač ne odigra prvi krug ili ga ne preskoči.
    /// Vlasnik 04.11 uveče: vodič se vraća u svakoj partiji (prvi krug), X ga skriva samo za ovu partiju.
    @State private var vodicGotov = false
    @State private var karte = false
    @State private var legenda = false
    @State private var savezList = false
    /// Obilazak sa strelicama na početku nove partije; X ili „Kreni” ga gase, ponovo se pokreće iz legende.
    @AppStorage("osvajanje.obilazakGotov") private var obilazakGotov = false
    @State private var obilazak: Int?

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
                UcitavanjeMaskota(maskota: .mimi, tekst: "Spremam bojno polje…")
            } else {
                igra
            }
        }
        .task(id: ObjectIdentifier(model)) { await model.pokreni() }
        // Ekran ne sme da se ugasi usred poteza (gašenje je izbacivalo iz partije).
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false; model.napusti() }
        .task(id: ObjectIdentifier(model)) { await model.slusaj() }
        .overlay { pitanje }
        .overlay { baner }
        .onChange(of: model.stanje.krug) { stari, novi in
            guard novi > stari, model.stanje.faza != .kraj else { return }
            withAnimation(.spring(duration: 0.45, bounce: 0.25)) { banerKruga = novi }
            Task {
                try? await Task.sleep(for: .seconds(1.4))
                withAnimation(.easeIn(duration: 0.3)) { banerKruga = nil }
            }
        }
        .overlay { if let b = model.bitka { BitkaView(model: model, bitka: b) } }
        .overlay { kraj }
        .onChange(of: model.stanje.faza == .kraj) { _, gotovo in
            guard gotovo, let covek = model.stanje.igraci.first(where: \.covek) else { return }
            // Stalni savez pobeđuje zajedno: pobeda je i kad pobedi saveznik.
            let pobedio = (model.stanje.pobednik ?? model.stanje.poredak.first?.igrac.tim).map { model.stanje.strana($0) } == model.stanje.strana(covek.tim)
            Zvuk.pusti(pobedio ? .pobeda : .kraj, jacina: 0.5)
            // XP po mestu: 1. +150, 2. +80, 3. +40, ostali +20, pobeda još +50 (pobeda se ne broji kao duel).
            let timovi = model.stanje.poredak.map(\.igrac.tim).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
            let mesto = pobedio ? 0 : timovi.firstIndex(of: covek.tim) ?? 3
            let ishod = zavrsiPartiju(napredak, sesija, igra: "osvajanje", poeni: model.stanje.poeni(covek.id), tacnih: model.tacnih, netacnih: model.netacnih,
                                      kategorija: "Geografija", prosekMs: prosek(model.zbirMs, model.tacnih + model.netacnih),
                                      dodatniXp: (mesto < 3 ? [150, 80, 40][mesto] : 20) + (pobedio ? 50 : 0), nacin: model.nacinZaProfil,
                                      izdaja: model.stanje.izdaje?[covek.tim] ?? 0)
            zaradjenoXp = ishod.xp
            OsvajanjeModel.obrisiSacuvanu()
        }
    }

    private var igra: some View {
        // Vlasnik 03.11: bez debelih okvira i kartica; tanke trake gore i dole, mapa od ivice do ivice.
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Button { potvrdaIzlaska = true } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Color.mastilo)
                        .frame(width: 30, height: 30).background(Color.kartica, in: Circle())
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .accessibilityLabel("Izađi")
                .ciljObilaska(.izlaz)
                if model.veza == nil {
                    Button { model.pauziraj() } label: {
                        Image(systemName: "pause.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(Color.mastilo)
                            .frame(width: 30, height: 30).background(Color.kartica, in: Circle())
                            .frame(width: 44, height: 44).contentShape(Rectangle())
                    }
                    .disabled(!model.mozePauzu)
                    .accessibilityLabel("Pauza")
                    .ciljObilaska(.pauza)
                }
                Button { legenda = true } label: {
                    Image(systemName: "questionmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Color.mastilo)
                        .frame(width: 30, height: 30).background(Color.kartica, in: Circle())
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .accessibilityLabel("Legenda mape: čuda, prestonice, morske veze")
                .ciljObilaska(.legenda)
                if model.stanje.mozeSavez || mojSaveznik != nil {
                    Button { if let p = mojSaveznik { porukaZa = p } else { savezList = true } } label: {
                        Image(systemName: mojSaveznik == nil ? "link.badge.plus" : "link").font(.system(size: 13, weight: .bold))
                            .foregroundStyle(mojSaveznik == nil ? Color.mastilo : Color.tinta)
                            .frame(width: 30, height: 30).background(mojSaveznik == nil ? Color.kartica : Color.zuta, in: Circle())
                            .frame(width: 44, height: 44).contentShape(Rectangle())
                    }
                    .accessibilityLabel(mojSaveznik.map { "Savez sa \($0.ime)" } ?? "Savez: predloži saveznika")
                    .ciljObilaska(.savez)
                }
                Text("Krug \(min(model.stanje.krug, model.stanje.ukupnoKrugova))/\(model.stanje.ukupnoKrugova)").font(.tekst(12, .bold)).monospacedDigit()
                    .foregroundStyle(Color.sivaTekst)
                GeometryReader { g in
                    Capsule().fill(Color.kartica)
                        .overlay(alignment: .leading) {
                            Capsule().fill(Color.teal)
                                .frame(width: g.size.width * Double(min(model.stanje.krug, model.stanje.ukupnoKrugova)) / Double(model.stanje.ukupnoKrugova))
                        }
                }
                .frame(height: 4)
                .ciljObilaska(.krug)
            }
            .padding(.horizontal, 10)

            ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.stanje.igraci, id: \.id) { p in
                    let naPotezu = p.id == model.stanje.trenutni.id && model.stanje.faza != .kraj
                    let saveznik = model.mojTim.map { model.stanje.uSavezu($0, p.tim) } ?? false
                    HStack(spacing: 8) {
                        MaskotaSlika(maskota: maskotaZa(p), velicina: 24)
                            .frame(width: 30, height: 30)
                            .background(Color(hex: p.boja), in: RoundedRectangle(cornerRadius: 9))
                            .overlay(alignment: .topTrailing) {
                                if p.kapiten && model.postavka?.nacin == .timovi { Image(systemName: "crown.fill").font(.system(size: 11)).foregroundStyle(Color.zuta).offset(x: 4, y: -4) }
                            }
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 3) {
                                Text(p.ime).font(.tekst(12, .bold)).lineLimit(1)
                                if let v = p.vojska { Image(systemName: v.ikonica).font(.system(size: 10, weight: .bold)).accessibilityLabel(v.naziv) }
                                if saveznik { Image(systemName: "link").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.teal).accessibilityLabel("Saveznik") }
                                if model.stanje.jeIzdajnik(p.tim) { Image(systemName: "hand.raised.slash.fill").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.crvena).accessibilityLabel("Izdajnik") }
                            }
                            // Brza poruka 6 s stoji umesto poena (oblačić), pa se poeni vraćaju.
                            TimelineView(.periodic(from: .now, by: 1)) { k in
                                if let t = model.stanje.svezaPoruka(p.id, sad: k.date) {
                                    Text(t).font(.tekst(11, .bold)).foregroundStyle(Color.tinta).lineLimit(1).fixedSize()
                                        .padding(.horizontal, 6).padding(.vertical, 2).background(Color.zuta, in: RoundedRectangle(cornerRadius: 8))
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.tinta, lineWidth: 1.2))
                                } else {
                                    Text("\(model.stanje.poeni(p.id))").font(.naslov(14)).monospacedDigit()
                                        .contentTransition(.numericText())
                                        .animation(.spring(duration: 0.4, bounce: 0.4), value: model.stanje.poeni(p.id))
                                }
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { if !p.covek { porukaZa = p } }
                    .padding(.vertical, 4).padding(.horizontal, 6)
                    // Na potezu: tanka linija u boji igrača ispod, umesto debelog okvira.
                    .background(naPotezu ? Color.kartica : .clear, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(alignment: .bottom) { if naPotezu { Capsule().fill(Color(hex: p.boja)).frame(height: 3).padding(.horizontal, 8) } }
                    .opacity(p.ispao ? 0.4 : 1)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(p.ime), \(model.stanje.poeni(p.id)) poena\(naPotezu ? ", na potezu" : "")\(saveznik ? ", saveznik" : "")")
                    .accessibilityHint(p.covek ? "" : "Poruka ili savez")
                    .frame(minWidth: 92)
                }
            }
            .padding(.horizontal, 10)
            }
            .ciljObilaska(.igraci)
            if let d = model.stanje.dogadjaj, model.stanje.aktivanDogadjaj(d.kontinent) {
                HStack(spacing: 10) {
                    Image(systemName: d.ikonica).font(.system(size: 16, weight: .bold))
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(d.naziv) · do kraja \(d.doKruga). kruga").font(.tekst(13, .bold))
                        Text(d.tekst).font(.tekst(12)).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                .foregroundStyle(.white).padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.ljubicasta, in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 10)
                .accessibilityElement(children: .combine)
            }
            // Misija se ne vidi dok je moj tim ne izvuče (inače bi se videla domaćinova dodela pre karata).
            if let t = model.mojTim, model.stanje.misije[t] != nil, model.ponudaMisija == nil,
               !(model.stanje.cekaPostavku ?? []).contains(where: { id in model.stanje.igraci.first { $0.id == id }?.tim == t }) {
                Button { misija = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "flag.checkered").font(.system(size: 12, weight: .bold)).foregroundStyle(Color.zuta)
                        Text(model.stanje.tekstMisije(model.stanje.misije[t])).font(.tekst(12, .semibold)).lineLimit(1)
                        Spacer()
                        Text("\(Int(model.stanje.napredakMisije(t) * 100))%").font(.tekst(12, .bold)).monospacedDigit()
                    }
                    .foregroundStyle(Color.mastilo)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .accessibilityLabel("Tajna misija")
                .ciljObilaska(.misija)
            }
            // Misija ispunjena: moj tim je drži do svog sledećeg poteza; rival sa ispunjenom misijom mora da se zaustavi.
            if let t = model.mojTim, model.stanje.misijaOd?[t] != nil {
                Label("Misija ispunjena! Drži je do svog sledećeg poteza i pobeđuješ.", systemImage: "flag.checkered")
                    .font(.tekst(13, .bold)).foregroundStyle(Color.tinta).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8).background(Color.zuta, in: RoundedRectangle(cornerRadius: 10)).padding(.horizontal, 10)
                    .transition(.scale.combined(with: .opacity))
            }
            ForEach(model.stanje.igraci.filter { p in p.tim != model.mojTim && p.kapiten && model.stanje.misijaOd?[p.tim] != nil }, id: \.id) { p in
                Label("\(p.ime) je ispunio tajnu misiju! Zaustavi ga pre njegovog poteza.", systemImage: "exclamationmark.triangle.fill")
                    .font(.tekst(13, .bold)).foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8).background(Color.crvena, in: RoundedRectangle(cornerRadius: 10)).padding(.horizontal, 10)
                    .transition(.scale.combined(with: .opacity))
            }
            if let k = model.kontinentiBezOdbrane.first {
                Button { odbranaZa = k } label: {
                    Label("Držiš \(k.ime): izaberi odbranu", systemImage: "shield.lefthalf.filled").font(.tekst(14, .bold))
                        .foregroundStyle(.white).frame(maxWidth: .infinity).padding(8).background(Color.teal, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain).padding(.horizontal, 10)
            }

            // Strelica saveta se crta dok igrač još ništa nije izabrao; posle ide njegov izbor.
            let savetna = model.izabrana == nil ? model.aktivanPredlog : nil
            MapaView(stanje: model.stanje, izabrana: model.izabrana ?? (savetna?.kuda != nil ? savetna?.odakle : nil), mete: model.mete,
                     meta: model.meta ?? savetna?.kuda, izvori: model.izvori,
                     // Kamera prati bitke i poteze botova, ali ne igračev dodir (inače mapa skače pri maršu).
                     fokus: model.pokazana ?? model.otvoreno?.kuda ?? (model.covekNaPotezu ? nil : model.izabrana), prviKadar: model.stanje.igraci.first(where: \.covek)?.prestonica,
                     efekti: .init(udar: model.udar, iskoci: model.iskoci, zatvoreni: model.zatvoreni),
                     magla: model.magla, odsecene: model.mojTim.map { model.stanje.odsecene($0) } ?? [], bezOkvira: true,
                     mojPotez: model.mojPotez, moje: model.mojId.map { model.stanje.oblastiIgraca($0) } ?? []) { model.dodir($0) }
                .ciljObilaska(.mapa)

            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(model.uputstvo).font(.tekst(14, .semibold)).frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.updatesFrequently)
                    if let rok = model.rokPoteza {
                        // Odbrojavanje poteza: poslednjih 10 sekundi crveno.
                        TimelineView(.periodic(from: .now, by: 1)) { kontekst in
                            let ostalo = max(0, Int(rok.timeIntervalSince(kontekst.date).rounded(.up)))
                            Text("\(ostalo) s").font(.naslov(16)).monospacedDigit()
                                .onChange(of: ostalo) { _, s in if s == 5 && model.bitka == nil { Zvuk.pusti(.petSekundi, jacina: 1.0) } }
                                .foregroundStyle(ostalo <= 10 ? Color.crvena : Color.sivaTekst)
                                .accessibilityLabel("Još \(ostalo) sekundi za potez")
                        }
                    }
                }
                .ciljObilaska(.uputstvo)
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
                    HStack(spacing: 10) {
                        ikonicaRadnje("lightbulb", aktivna: false, opis: "Šta da radim? Savet za raspored") { model.savet() }
                            .disabled(!model.mozeSavet).opacity(model.mozeSavet ? 1 : 0.4)
                        Button("Rasporedi sam") { model.rasporediSam() }.buttonStyle(.sekundarno)
                    }
                }
                if model.meta == nil && model.covekNaPotezu && model.stanje.faza == .napad {
                    let mapske = [Karta]()
                    if !mapske.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(mapske) { k in
                                Button { model.igrajKartuNaMapi(k) } label: {
                                    Label("\(k.naziv) · \(model.mojeKarte.filter { $0 == k }.count)", systemImage: k.ikonica)
                                        .font(.tekst(13, .bold)).foregroundStyle(Color.tinta).lineLimit(1).minimumScaleFactor(0.8)
                                        .frame(maxWidth: .infinity).frame(height: 44)
                                        .background(Color.zuta, in: RoundedRectangle(cornerRadius: 14))
                                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.tinta, lineWidth: 2))
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint(k.opis + " Prvo izaberi svoju državu.")
                            }
                        }
                    }
                    if let r = model.mojPohod {
                        Label("Pohod: \(Mapa.regioni.first { $0.id == r }?.ime ?? r)", systemImage: "scope").font(.tekst(13, .bold)).foregroundStyle(Color.teal)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    // Preuređeno 04.11: sporedne radnje su ikonice (natpis u pristupačnosti), glavna je „Kraj poteza”.
                    HStack(spacing: 8) {
                        if !model.stanje.utvrdjeno {
                            ikonicaRadnje(model.utvrdjivanje ? "xmark" : "arrow.left.arrow.right", aktivna: model.utvrdjivanje,
                                          opis: model.utvrdjivanje ? "Odustani od marša" : "Marš: prebaci vojsku do 3 koraka") { model.prekidacUtvrdjivanja() }
                        }
                        if model.mojPohod == nil {
                            ikonicaRadnje(model.biraPohod ? "xmark" : "scope", aktivna: model.biraPohod,
                                          opis: model.biraPohod ? "Odustani od pohoda" : "Pohod: najavi region koji osvajaš") { model.prekidacPohoda() }
                        }
                        if let t = model.mojTim, model.stanje.misije[t] != nil {
                            ikonicaRadnje("flag.checkered", aktivna: false, opis: "Tajna misija i kontinenti") { misija = true }
                        }
                        ikonicaRadnje("rectangle.portrait.on.rectangle.portrait", aktivna: false, opis: "Ratne karte: \(model.mojeKarte.count)") { karte = true }
                            .overlay(alignment: .topTrailing) {
                                if !model.mojeKarte.isEmpty {
                                    Text("\(model.mojeKarte.count)").font(.tekst(12, .heavy)).foregroundStyle(Color.tinta)
                                        .frame(width: 22, height: 22).background(Color.zuta, in: Circle()).overlay(Circle().stroke(Color.tinta, lineWidth: 1.5))
                                        .offset(x: 6, y: -6)
                                }
                            }
                        ikonicaRadnje("lightbulb", aktivna: false, opis: "Šta da radim? Predlog najboljeg napada, jednom po potezu") { model.savet() }
                            .disabled(!model.mozeSavet).opacity(model.mozeSavet ? 1 : 0.4)
                        Button { model.krajPoteza() } label: {
                            Text("Kraj poteza").font(.tekst(15, .bold)).lineLimit(1).minimumScaleFactor(0.8)
                                .foregroundStyle(Color.naMastilu).frame(maxWidth: .infinity).frame(height: 50)
                                .background(Color.mastilo, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .layoutPriority(1)
                    }
                }
            }
            .padding(.horizontal, 14).padding(.top, 2).padding(.bottom, 6)
            .controlSize(.small)
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
        .overlay { if let o = model.obavestenjeMisije, model.bitka == nil { obavestenjeMisije(o) } }
        .overlay { if let ponuda = model.ponudaMisija { KarteMisijaView(model: model, ponuda: ponuda) } }
        .overlay(alignment: .top) { porukaRivala }
        .overlay(alignment: .top) { savetTraka }
        .overlay(alignment: .top) {
            if let p = model.primljenaPomoc {
                PrimljenaPomocView(pomoc: p, pokazi: { model.pokaziDrzavu(p.u); model.primljenaPomoc = nil }, zatvori: { if model.primljenaPomoc == p { model.primljenaPomoc = nil } })
            }
        }
        .animation(.spring(duration: 0.35), value: model.primljenaPomoc)
        .overlay { if let e = model.efekat, model.bitka == nil { EfekatView(efekat: e) { if model.efekat == e { model.efekat = nil } }.id(e.id) } }
        .modifier(Tresenje(udarac: model.udarac))
        .overlay { if let k = model.novaKarta, model.bitka == nil { NovaKartaView(karta: k.karta) { model.novaKarta = nil }.id(k.id) } }
        .overlay { if karte { KarteList(model: model) { karte = false } } }
        .overlay { if legenda { LegendaList(stanje: model.stanje, vodic: { legenda = false; obilazak = 0 }) { legenda = false } } }
        .overlay { if savezList { savezPredlog } }
        .overlay(alignment: .top) { tudjiOdgovor }
        .overlay(alignment: .bottom) { vodic }
        .overlay { if model.pauza { pauzaList } }
        .overlay { if let k = odbranaZa { odbranaList(k) } }
        .overlay { if let p = porukaZa { porukaList(p) } }
        .overlay {
            if let id = model.izdajaZa {
                Dijalog(naslov: "Izdaja?", tekst: "\(Mapa.oblast(id).ime) drži tvoj saveznik. Napad prekida savez: gubiš sve karte, dva kruga nemaš moći vojske ni pomoć saveznika, svi vide oznaku izdajnika, a izdaja ostaje na tvom profilu.",
                        potvrda: "Izdaj", odustani: "Ostani veran", opasno: true) { model.potvrdiIzdaju() } zatvori: { model.odustaniOdIzdaje() }
            }
        }
        .onChange(of: model.spremno, initial: true) { _, da in
            guard da, model.postavka != nil, !videoMisiju else { return }
            videoMisiju = true
            if LibrumKvizApp.demo { return } // snimak za sajt: bez postavke
            // Vlasnik 04.11: prvo biraš države, pa vučeš tajnu misiju (na jednom kontinentu misije nema: cilj je ceo kontinent).
            model.otvori()
            if !obilazakGotov && !model.nastavljena { obilazak = 0 }
            if model.postavka?.teren != nil && !model.nastavljena { model.javi("Cilj: osvoji ceo kontinent") }
        }
        .overlay {
            if potvrdaIzlaska {
                Dijalog(naslov: "Napuštaš partiju?", tekst: model.veza == nil ? "Partija se čuva: nastavi je sa početne." : "Partija sa igračima se ne čuva.",
                        potvrda: "Izađi", odustani: "Ostani",
                        potvrdi: { model.napusti(); zatvori() }, zatvori: { potvrdaIzlaska = false })
            }
        }
        .overlayPreferenceValue(CiljeviObilaska.self) { a in
            GeometryReader { g in
                if let o = obilazak {
                    ObilazakView(korak: o, okviri: a.mapValues { g[$0] },
                                 dalje: { withAnimation(.easeOut(duration: 0.2)) { if o + 1 < KorakObilaska.svi.count { obilazak = o + 1 } else { zavrsiObilazak() } } },
                                 nazad: { withAnimation(.easeOut(duration: 0.2)) { obilazak = max(0, o - 1) } },
                                 ugasi: { withAnimation { zavrsiObilazak() } })
                }
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
                            dodatak: o.rival.map { "Rival je odgovorio \($0.tacan ? "tačno" : "netačno") za \(String(format: "%.1f", locale: .srpski, Double($0.ms) / 1000)) s" },
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
            if vlasnik != nil, case let p = s.pomakBitke(odakle: izvor, kuda: meta), p != 0 {
                Label(p > 0 ? "Prednost: +\(p) \(p == 1 ? "tačan" : "tačna") za tebe" : "\(vlasnik!.ime) ima prednost: +\(-p) \(p == -1 ? "tačan" : "tačna")",
                      systemImage: "scalemass").font(.tekst(13, .bold)).foregroundStyle(p > 0 ? Color.teal : Color.crvena)
            } else if vlasnik == nil, mojaVojska - 1 >= Pravila.vojskiBezGubitkaNaNeutralnoj {
                Label("Jaka vojska: greška ti ne odnosi vojsku.", systemImage: "scalemass").font(.tekst(13, .bold)).foregroundStyle(Color.teal)
            }
            Label(vlasnik == nil
                  ? "\(uslov.pitanja == 1 ? "Jedno pitanje" : "\(uslov.pitanja) pitanja"), \(uslov.sekundi) s. Ako pogrešiš, gubiš vojsku, a država ostaje prazna."
                  : "\(uslov.pitanja) pitanja po \(uslov.sekundi) s protiv igrača \(vlasnik!.ime). Ako izgubiš, \(vlasnik!.ime) uzima \(Mapa.oblast(izvor).ime).",
                  systemImage: vlasnik == nil ? "flag" : "exclamationmark.triangle")
                .font(.tekst(13, .semibold)).foregroundStyle(vlasnik == nil ? Color.sivaTekst : Color.crvena)
            if let t = Teren.opis(odakle: izvor, kuda: meta) {
                Label(t, systemImage: "mountain.2").font(.tekst(13, .semibold)).foregroundStyle(Color.mastilo)
            }
            if let c = Cudo.za(meta) {
                Label("Čudo sveta: \(c.naziv). \(c.opis)", systemImage: "star.fill").font(.tekst(13, .bold)).foregroundStyle(Color.mastilo)
            }
            if let v = vlasnik {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ulog").font(.tekst(13, .bold))
                    PodvuceniIzbor(izbor: Binding(get: { model.ulog }, set: { model.ulog = $0 }), opcije: [(0, "Bez uloga"), (1, "+1"), (2, "+2")])
                    if model.ulog > 0 {
                        Text("Pobeda: \(v.ime) gubi još \(model.ulog), osvojena država dobija \(model.ulog). Poraz: ti gubiš još \(model.ulog).")
                            .font(.tekst(12)).foregroundStyle(Color.sivaTekst)
                    }
                }
                if !v.covek && !v.id.hasPrefix("u:") && s.ultimatumKrug?[s.trenutni.tim] != s.krug && s.snaga(v.tim) < s.snaga(s.trenutni.tim) {
                    Button("Ultimatum: predaj \(Mapa.oblast(meta).ime)") { model.ultimatum(meta) }.buttonStyle(.sekundarno)
                }
            }
            HStack(spacing: 10) {
                Button("Odustani") { model.odustaniOdMete() }.buttonStyle(.sekundarno)
                Button("Napadni") { model.napadni() }.buttonStyle(.primarno)
            }
        }
    }

    private func ikonicaRadnje(_ ikonica: String, aktivna: Bool, opis: String, radnja: @escaping () -> Void) -> some View {
        Button(action: radnja) {
            Image(systemName: ikonica).font(.system(size: 17, weight: .bold)).foregroundStyle(aktivna ? Color.tinta : Color.mastilo)
                .frame(width: 46, height: 50)
                .background(aktivna ? Color.zuta : Color.kartica, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.mastilo, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(opis)
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

    /// Tekst vodiča za trenutni trenutak partije; nil kad nema šta da se objasni (bitka i karte imaju svoja uputstva).
    private var korakVodica: (ikonica: String, tekst: String)? {
        guard !vodicGotov, obilazak == nil, model.stanje.krug == 1, model.bitka == nil, model.ponudaMisija == nil,
              !legenda, !karte, !misija, porukaZa == nil, model.meta == nil, model.aktivanPredlog == nil,
              !model.pauza, model.stanje.faza != .kraj else { return nil }
        if let p = model.postavljanje {
            if p.drzave.count < Pravila.pocetnihDrzava { return ("hand.tap", "Dodirni \(Pravila.pocetnihDrzava) slobodnih država na kontinentu \(p.kontinent.ime). Prva koju dodirneš je tvoja prestonica.") }
            if model.zaPostavljanje > 0 { return ("plus.circle", "Dodiruj svoje države da im dodaš vojsku. Jače granice teže padaju.") }
            return ("checkmark.circle", "Spremno! Pritisni Kreni, pa izvuci tajnu misiju.")
        }
        guard model.covekNaPotezu else { return ("cpu", "Sada igraju rivali. Kad napadnu tvoju državu, i ti odgovaraš na pitanja.") }
        switch model.stanje.faza {
        case .raspored: return ("plus.circle", "Stigla su pojačanja. Dodiruj svoje države ili pritisni Rasporedi sam.")
        case .napad:
            if model.meta != nil { return ("scalemass", "Ovde vidiš ko brani, koliko vojske ima i tvoju prednost. Pritisni Napadni.") }
            if model.izabrana != nil { return ("scope", "Dodirni susednu državu sa isprekidanom ivicom: nju napadaš.") }
            if model.stanje.bitaka == 0 { return ("hand.tap", "Dodirni svoju državu sa žutom ivicom: odatle napadaš. Sijalica dole daje savet.") }
            return ("flag.checkered", "Napadaj dalje iz osvojene države ili pritisni Kraj poteza.")
        default: return nil
        }
    }

    private var vodic: some View {
        Group {
            if let k = korakVodica {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: k.ikonica).font(.system(size: 16, weight: .bold)).foregroundStyle(Color.tinta)
                        .frame(width: 34, height: 34).background(Color.zuta, in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        Oznaka(tekst: "Vodič", boja: .teal)
                        Text(k.tekst).font(.tekst(14, .semibold)).foregroundStyle(Color.mastilo).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Button { vodicGotov = true } label: {
                        Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Color.sivaTekst).frame(width: 32, height: 32)
                    }
                    .accessibilityLabel("Preskoči vodič")
                }
                .padding(12)
                .background(Color.kartica, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.teal, lineWidth: 2))
                .padding(.horizontal, 12).padding(.bottom, 132)
                .transition(.opacity)
                .animation(.easeOut(duration: 0.2), value: k.tekst)
            }
        }
    }

    /// Savet sa sijalice: samo kaže šta (tekst + strelica na mapi); igrač dodiruje i igra sam.
    @ViewBuilder private var savetTraka: some View {
        if let p = model.aktivanPredlog, model.meta == nil {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lightbulb.fill").font(.system(size: 16, weight: .bold)).foregroundStyle(Color.tinta)
                    .frame(width: 34, height: 34).background(Color.zuta, in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 1) {
                    Oznaka(tekst: "Savet", boja: .teal)
                    Text(p.tekst).font(.tekst(14, .bold)).foregroundStyle(Color.mastilo).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button { model.predlog = nil } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Color.sivaTekst).frame(width: 36, height: 36)
                }
                .accessibilityLabel("Zatvori savet")
            }
            .padding(10)
            .background(Color.kartica, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.zuta, lineWidth: 2.5))
            .padding(.horizontal, 12).padding(.top, 118)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityElement(children: .combine)
        }
    }

    /// Pauza (samo sa botovima): sve stoji, sat poteza i botovi čekaju.
    private var pauzaList: some View {
        ZStack {
            Color.senka.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "pause.circle.fill").font(.system(size: 54, weight: .bold)).foregroundStyle(Color.zuta)
                Naslov(tekst: "Pauza", velicina: 34)
                Text("Krug \(model.stanje.krug) od \(model.stanje.ukupnoKrugova). Botovi i sat čekaju dok ne nastaviš.")
                    .font(.tekst(15, .semibold)).foregroundStyle(Color.sivaTekst).multilineTextAlignment(.center)
                Button("Nastavi") { model.nastaviPartiju() }.buttonStyle(.primarno)
                Button("Izađi, partija se čuva") { zatvori() }.buttonStyle(.sekundarno)
            }
            .padding(24).frame(maxWidth: 420).pop(radijus: 26).padding(20)
        }
        .transition(.opacity)
    }

    /// Pitanje i odgovor drugog pravog igrača u bitki (bez pomoći koje je koristio), 6 s.
    private var tudjiOdgovor: some View {
        TimelineView(.periodic(from: .now, by: 1)) { k in
            if let o = model.tudjiOdgovor, k.date.timeIntervalSince(o.kad) < 6, model.bitka == nil {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 4).fill(Color(hex: o.boja)).frame(width: 12, height: 12)
                        Text("\(o.ime) odgovara").font(.tekst(12, .bold)).foregroundStyle(Color.sivaTekst)
                        Spacer()
                        Image(systemName: o.tacno ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(o.tacno ? Color.teal : Color.crvena).font(.system(size: 18, weight: .bold))
                    }
                    Text(o.pitanje).font(.tekst(14, .semibold)).foregroundStyle(Color.mastilo).lineLimit(3)
                    Text(o.odgovor).font(.tekst(15, .heavy)).foregroundStyle(o.tacno ? Color.teal : Color.crvena)
                }
                .padding(12)
                .background(Color.kartica, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: o.boja), lineWidth: 2.5))
                .padding(.horizontal, 16).padding(.top, 120)
                .allowsHitTesting(false)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(o.ime): \(o.pitanje). Odgovor \(o.odgovor), \(o.tacno ? "tačno" : "netačno")")
            }
        }
    }

    /// Poruka drugog igrača (čovek ili bot): oblačić sa njegovom bojom na vrhu ekrana, 6 s.
    private var porukaRivala: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            if let (p, tekst) = model.svezaPorukaRivala {
                HStack(spacing: 10) {
                    MaskotaSlika(maskota: maskotaZa(p), velicina: 26).frame(width: 34, height: 34)
                        .background(Color(hex: p.boja), in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(p.ime).font(.tekst(12, .bold)).foregroundStyle(Color.sivaTekst)
                        Text(tekst).font(.tekst(18, .heavy)).foregroundStyle(Color.mastilo)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.kartica, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: p.boja), lineWidth: 2.5))
                .padding(.horizontal, 16).padding(.top, 54)
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(p.ime) poručuje: \(tekst)")
                .allowsHitTesting(false)
            }
        }
        .animation(.spring(duration: 0.3), value: model.svezaPorukaRivala?.tekst)
    }

    @ViewBuilder private var baner: some View {
        if let krug = banerKruga {
            VStack(spacing: 2) {
                Text("Krug \(krug)").font(.naslov(40)).foregroundStyle(Color.tinta)
                Text("od \(model.stanje.ukupnoKrugova)").font(.tekst(15, .bold)).foregroundStyle(Color.tinta.opacity(0.7))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(Color.zuta)
            .overlay(alignment: .top) { Rectangle().fill(Color.tinta).frame(height: 3) }
            .overlay(alignment: .bottom) { Rectangle().fill(Color.tinta).frame(height: 3) }
            .rotationEffect(.degrees(-3))
            .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
            .allowsHitTesting(false)
            .accessibilityLabel("Krug \(krug) od \(model.stanje.ukupnoKrugova)")
        }
    }

    @ViewBuilder private var kraj: some View {
        if model.stanje.faza == .kraj {
            let st = model.stanje
            let poredak = st.poredak
            let pobednik = st.pobednik.flatMap { t in st.igraci.first { $0.tim == t } } ?? poredak[0].igrac
            ZStack {
                Color.senka.opacity(0.6).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        // Pobednička vojska ispred zamka; bez vojske (stara partija) ostaje maskota.
                        if let v = pobednik.vojska {
                            ZStack(alignment: .bottom) {
                                Image("Osvajanje_zamak").resizable().scaledToFit().frame(height: 96).opacity(0.9).offset(y: -18)
                                Image(v.heroj).resizable().scaledToFit().frame(height: 120)
                            }
                            .frame(height: 140)
                            .accessibilityLabel("\(v.naziv) osvaja svet")
                        } else {
                            MaskotaSlika(maskota: maskotaZa(pobednik), velicina: 100)
                        }
                        if let tp = st.pobednik { Text("Misija ispunjena: \(st.tekstMisije(st.misije[tp]))").font(.tekst(14, .bold)).multilineTextAlignment(.center) }
                        Text(pobednik.covek ? "Svet je tvoj!" : "Pobeđuje \(pobednik.ime)").font(.naslov(34))
                            .foregroundStyle(pobednik.covek ? .white : .mastilo).multilineTextAlignment(.center)
                        if let xp = zaradjenoXp {
                            Label("+\(xp) XP", systemImage: "sparkles").font(.tekst(16, .bold)).foregroundStyle(pobednik.covek ? .white : .mastilo)
                        }
                        // Tabela: mesto, igrač i vojska, države, vojske, tačni, dobijene bitke, poeni.
                        VStack(spacing: 0) {
                            HStack(spacing: 6) {
                                Text("").frame(width: 22)
                                Text("Igrač").frame(maxWidth: .infinity, alignment: .leading)
                                ForEach(["Drž.", "Voj.", "Tač.", "Bit.", "Poeni"], id: \.self) { Text($0).frame(width: $0 == "Poeni" ? 46 : 34, alignment: .trailing) }
                            }
                            .font(.tekst(11, .bold)).foregroundStyle(Color.sivaTekst).padding(.horizontal, 10).padding(.vertical, 8)
                            ForEach(Array(poredak.enumerated()), id: \.offset) { i, red in
                                let drzave = st.oblastiIgraca(red.igrac.id)
                                let vojske = drzave.reduce(0) { $0 + (st.oblasti[$1]?.vojske ?? 0) }
                                HStack(spacing: 6) {
                                    Text("\(i + 1).").font(.tekst(14, .bold)).frame(width: 22, alignment: .leading)
                                    HStack(spacing: 6) {
                                        RoundedRectangle(cornerRadius: 4).fill(Color(hex: red.igrac.boja)).frame(width: 12, height: 12)
                                        Text(red.igrac.ime).font(.tekst(14, .semibold)).lineLimit(1)
                                        if let v = red.igrac.vojska { Image(systemName: v.ikonica).font(.system(size: 11)).accessibilityLabel(v.naziv) }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    Text("\(drzave.count)").frame(width: 34, alignment: .trailing)
                                    Text("\(vojske)").frame(width: 34, alignment: .trailing)
                                    Text("\(st.tacnih[red.igrac.tim] ?? 0)").frame(width: 34, alignment: .trailing)
                                    Text("\(st.pobedaBitaka?[red.igrac.tim] ?? 0)").frame(width: 34, alignment: .trailing)
                                    Text("\(red.poeni)").font(.naslov(16)).frame(width: 46, alignment: .trailing)
                                }
                                .font(.tekst(13, .semibold)).monospacedDigit()
                                .padding(.horizontal, 10).padding(.vertical, 9)
                                .background(red.igrac.covek ? Color.zuta.opacity(0.35) : .clear)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("\(i + 1). \(red.igrac.ime): \(drzave.count) država, \(vojske) vojski, \(st.tacnih[red.igrac.tim] ?? 0) tačnih, \(red.poeni) poena")
                                if i < poredak.count - 1 { Divider().overlay(Color.kremTamnija) }
                            }
                        }
                        .foregroundStyle(Color.mastilo)
                        .background(Color.kartica, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.mastilo, lineWidth: 2))
                        Text("XP po mestu: 1. +150 · 2. +80 · 3. +40 · ostali +20").font(.tekst(12, .semibold))
                            .foregroundStyle(pobednik.covek ? .white : Color.sivaTekst)
                        if model.istorija.count > 2 {
                            Button("Pogledaj kako se svet menjao") { reprodukcija = true }.buttonStyle(.sekundarno)
                        }
                        // Vlasnik 04.11: nova partija počinje podešavanjem (uvod), ne istom igrom.
                        Button("Nova partija") {
                            zaradjenoXp = nil
                            zatvori()
                            NotificationCenter.default.post(name: .novaPartijaOsvajanja, object: nil)
                        }
                        .buttonStyle(.zuto)
                        // Vlasnik 03.11: posle partije igrač ide na početak, ne korak nazad (u čekaonicu).
                        Button("Početak") { zatvori(); NotificationCenter.default.post(name: .naPocetak, object: nil) }.buttonStyle(.sekundarno)
                        if let ja = st.igraci.first(where: \.covek) {
                            PodeliRezultat(igra: "Osvajač", naslov: pobednik.covek ? "Svet je moj!" : "Osvajač",
                                           veliko: "\(st.oblastiIgraca(ja.id).count) država", detalji: ["\(st.poeni(ja.id)) poena"],
                                           ilustracija: "Igra_osvajanje", boja: .teal, objava: ("osvajanje", st.poeni(ja.id)))
                        }
                    }
                    .padding(20)
                    .pop(pobednik.covek ? .teal : .kartica)
                    .padding(16)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .overlay { if pobednik.covek || st.strana(pobednik.tim) == model.mojTim.map({ st.strana($0) }) { Konfete().ignoresSafeArea() } }
            .overlay { if reprodukcija { ReprodukcijaView(istorija: model.istorija, stanje: st) { reprodukcija = false } } }
        }
    }

    /// Misija ispunjena (moja ili rivalova): jasno, na sredini, igra stoji dok igrač ne pritisne „Razumem”.
    private func obavestenjeMisije(_ o: OsvajanjeModel.ObavestenjeMisije) -> some View {
        ZStack {
            Color.senka.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: o.moja ? "flag.checkered" : "exclamationmark.triangle.fill")
                    .font(.system(size: 34, weight: .bold)).foregroundStyle(o.moja ? Color.tinta : .white)
                    .frame(width: 72, height: 72).background(o.moja ? Color.zuta : Color.crvena, in: Circle())
                Naslov(tekst: o.moja ? "Misija ispunjena!" : "\(o.ime) je ispunio misiju!", velicina: 26).multilineTextAlignment(.center)
                Text(o.tekst).font(.tekst(15, .semibold)).foregroundStyle(Color.sivaTekst).multilineTextAlignment(.center)
                Text(o.moja
                     ? "Pobeda nije još gotova: zadrži ove države dok tvoj tim ponovo ne dođe na red. Rivali će sada pokušati da ti ih preotmu."
                     : "Ako zadrži ove države do svog sledećeg poteza, pobeđuje. Napadni njegove države i pokvari mu misiju.")
                    .font(.tekst(16, .semibold)).foregroundStyle(Color.mastilo).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                Button("Razumem") { withAnimation { model.zatvoriObavestenjeMisije() } }.buttonStyle(.primarno)
            }
            .padding(22).frame(maxWidth: 380)
            .background(Color.kartica, in: RoundedRectangle(cornerRadius: 26))
            .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.mastilo, lineWidth: 2.5))
            .padding(24)
            .accessibilityElement(children: .contain).accessibilityAddTraits(.isModal)
        }
        .transition(.opacity)
    }

    /// Brza poruka igraču i predlog saveza (bot odgovara odmah).
    private func porukaList(_ p: Igrac) -> some View {
        DonjiList(zatvori: { porukaZa = nil }) {
            VStack(alignment: .leading, spacing: 12) {
                Oznaka(tekst: p.vojska?.naziv ?? "Rival", boja: Color(hex: p.boja))
                Naslov(tekst: p.ime, velicina: 28)
                if let v = p.vojska { MociVojske(vojska: v) }
                if let t = model.mojTim, model.stanje.uSavezu(t, p.tim), !model.mojeKarte.isEmpty {
                    Text("Razmeni kartu: daješ jednu, \(p.ime) vraća jednu koju nemaš.").font(.tekst(13)).foregroundStyle(Color.sivaTekst)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(Set(model.mojeKarte)).sorted { $0.rawValue < $1.rawValue }) { k in
                                Button { model.razmeniKartu(k, sa: p); porukaZa = nil } label: {
                                    Label("Daj \(k.naziv)", systemImage: k.ikonica).font(.tekst(13, .bold)).foregroundStyle(Color.tinta)
                                        .padding(.horizontal, 12).frame(height: 40).background(Color.zuta, in: RoundedRectangle(cornerRadius: 12))
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.tinta, lineWidth: 1.5))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                if model.stanje.jeIzdajnik(p.tim) {
                    Label("\(p.ime) je izdao saveznika.", systemImage: "hand.raised.slash.fill").font(.tekst(13, .bold)).foregroundStyle(Color.crvena)
                }
                if let t = model.mojTim, model.stanje.uSavezu(t, p.tim) {
                    Button { model.posaljiPomoc(za: p); porukaZa = nil } label: {
                        Label("Pošalji \(Pravila.vojskiPomociSavezniku) vojske na granicu", systemImage: "arrow.right.circle.fill")
                            .font(.tekst(15, .bold)).foregroundStyle(Color.tinta).frame(maxWidth: .infinity).frame(height: 48)
                            .background(Color.zuta, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.tinta, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .disabled(model.stanje.putPomoci(od: t, za: p.tim) == nil || !model.covekNaPotezu)
                    .accessibilityHint("Jednom po krugu, sa tvoje države sa bar tri vojske")
                }
                if let t = model.mojTim, model.stanje.uSavezu(t, p.tim) {
                    let kraj = model.stanje.savezi?[Stanje.kljucSaveza(t, p.tim)] ?? 0
                    Label(kraj >= Stanje.savezDoKraja ? "Saveznici ste: ne napadate se, pomažete jedan drugom i pobeđujete zajedno."
                                                       : "Savez je raskinut i važi do kraja ovog kruga.",
                          systemImage: "link").font(.tekst(14, .bold)).foregroundStyle(Color.teal)
                    savezRadnje(t, p, doKraja: kraj >= Stanje.savezDoKraja)
                } else if model.stanje.mozeSavez {
                    Text("Jedan saveznik, do kraja igre: ne napadate se i pobeđujete zajedno. Savez može da se raskine ili izda (izdaja: bez karata i bez moći dva kruga).")
                        .font(.tekst(13)).foregroundStyle(Color.sivaTekst).fixedSize(horizontal: false, vertical: true)
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    // Savez ima smisla tek sa bar tri strane; u dvoje bi niko nikog ne bi napadao.
                    ForEach(BrzaPoruka.ponuda.filter { $0 != "Savez?" || model.stanje.mozeSavez }, id: \.self) { t in
                        Button { model.posaljiPoruku(t, za: p); porukaZa = nil } label: {
                            Text(t).font(.tekst(15, .bold)).foregroundStyle(t == "Savez?" ? Color.tinta : Color.mastilo).frame(maxWidth: .infinity).frame(height: 48)
                                .background(t == "Savez?" ? Color.zuta : Color.kartica, in: RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mastilo, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func zavrsiObilazak() { obilazak = nil; obilazakGotov = true }

    /// Moj saveznik (jedan, do kraja igre), ako ga imam.
    private var mojSaveznik: Igrac? {
        guard let t = model.mojTim else { return nil }
        return model.stanje.igraci.first { $0.kapiten && !$0.ispao && model.stanje.uSavezu(t, $0.tim) }
    }

    /// Dugme Savez gore: pravila saveza i predlog svakom rivalu (bot odgovara odmah).
    private var savezPredlog: some View {
        DonjiList(zatvori: { savezList = false }) {
            VStack(alignment: .leading, spacing: 12) {
                Naslov(tekst: "Savez", velicina: 28)
                VStack(alignment: .leading, spacing: 6) {
                    Label("Jedan saveznik do kraja igre: ne napadate se i pobeđujete zajedno.", systemImage: "link")
                    Label("Šaljete jedan drugom vojsku, tražite pomoć i do \(Pravila.zamenaMisijaDoKruga). kruga menjate misije.", systemImage: "arrow.left.arrow.right")
                    Label("Savez možeš diplomatski da raskineš na svom potezu.", systemImage: "hand.wave")
                    Label("Napad na saveznika je izdaja: gubiš sve karte, dva kruga nemaš moći ni pomoć, i to ostaje na profilu.", systemImage: "hand.raised.slash.fill")
                }
                .font(.tekst(13, .semibold)).foregroundStyle(Color.mastilo).fixedSize(horizontal: false, vertical: true)
                Text("Kome predlažeš savez?").font(.tekst(15, .bold)).padding(.top, 4)
                ForEach(model.stanje.igraci.filter { !$0.covek && $0.kapiten && !$0.ispao && $0.tim != model.mojTim }, id: \.id) { p in
                    Button { model.posaljiPoruku("Savez?", za: p); savezList = false } label: {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 6).fill(Color(hex: p.boja)).frame(width: 22, height: 22)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.mastilo, lineWidth: 1.5))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(p.ime).font(.tekst(16, .bold))
                                Text("\(model.stanje.oblastiIgraca(p.id).count) država\(model.stanje.jeIzdajnik(p.tim) ? " · izdajnik" : "")")
                                    .font(.tekst(12)).foregroundStyle(model.stanje.jeIzdajnik(p.tim) ? Color.crvena : Color.sivaTekst)
                            }
                            Spacer()
                            Image(systemName: "link.badge.plus").font(.system(size: 16, weight: .bold))
                        }
                        .foregroundStyle(Color.mastilo).padding(12)
                        .background(Color.kartica, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mastilo, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Predloži savez: \(p.ime)")
                }
            }
        }
    }

    /// Radnje sa saveznikom: pomoć (tražim), zamena misije (do 5. kruga), diplomatski raskid.
    @ViewBuilder private func savezRadnje(_ t: String, _ p: Igrac, doKraja: Bool) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                dugmeSaveza("Traži pomoć", "hand.raised.fill") { model.traziPomoc(od: p); porukaZa = nil }
                if model.stanje.krug <= Pravila.zamenaMisijaDoKruga, model.stanje.misije[t] != nil {
                    dugmeSaveza("Zameni misiju", "arrow.left.arrow.right") { model.zameniMisiju(sa: p); porukaZa = nil }
                }
            }
            if doKraja {
                dugmeSaveza("Raskini savez", "link.badge.plus", opasno: true) { model.raskiniSavez(); porukaZa = nil }
            }
            if model.stanje.podKaznom(t) {
                Label("Kazna za izdaju: bez moći vojske i pomoći do kraja \(model.stanje.kaznaIzdaje?[t] ?? 0). kruga.", systemImage: "hand.raised.slash.fill")
                    .font(.tekst(13, .bold)).foregroundStyle(Color.crvena)
            }
        }
    }

    private func dugmeSaveza(_ naziv: String, _ ikonica: String, opasno: Bool = false, radnja: @escaping () -> Void) -> some View {
        Button(action: radnja) {
            Label(naziv, systemImage: ikonica).font(.tekst(14, .bold)).foregroundStyle(opasno ? Color.crvena : Color.mastilo)
                .frame(maxWidth: .infinity).frame(height: 46)
                .background(Color.kartica, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(opasno ? Color.crvena : Color.mastilo, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private func misijaList(_ tim: String) -> some View {
        DonjiList(zatvori: { misija = false }) {
            VStack(alignment: .leading, spacing: 12) {
                Oznaka(tekst: "Tajna misija · vidi je samo tvoj tim", boja: .roze)
                Naslov(tekst: model.stanje.tekstMisije(model.stanje.misije[tim]), velicina: 26)
                if let meta = model.stanje.metaMisije[tim], let ime = model.stanje.igraci.first(where: { $0.tim == meta })?.ime {
                    Text("Meta: \(ime)").font(.tekst(15, .bold))
                }
                let n = model.stanje.napredakMisije(tim)
                GeometryReader { g in
                    RoundedRectangle(cornerRadius: 6).fill(Color.udubljeno)
                        .overlay(alignment: .leading) { RoundedRectangle(cornerRadius: 6).fill(Color.teal).frame(width: g.size.width * n) }
                }
                .frame(height: 12)
                Text("Ispunjeno \(Int(n * 100))%. Ispuni misiju i drži je do svog sledećeg poteza: pobeđuješ; inače posle poslednjeg kruga pobeđuje najviše poena.")
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
                Text("Čuda sveta").font(.tekst(15, .bold)).padding(.top, 4)
                ForEach(Cudo.sva.filter { model.stanje.oblasti[$0.oblast] != nil }, id: \.oblast) { c in
                    let drzi = model.stanje.igraci.first { $0.tim == model.stanje.oblasti[c.oblast]?.vlasnik }
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "star.fill").font(.system(size: 12)).foregroundStyle(Color.zuta).padding(.top, 2)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(c.naziv) · \(Mapa.oblast(c.oblast).ime)").font(.tekst(14, .semibold))
                            Text(c.opis).font(.tekst(12)).foregroundStyle(Color.sivaTekst)
                        }
                        Spacer()
                        Text(drzi?.ime ?? "slobodno").font(.tekst(13, .bold)).foregroundStyle(drzi.map { Color(hex: $0.boja) } ?? Color.sivaTekst)
                    }
                }
                Button("Važi") { misija = false }.buttonStyle(.primarno)
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
