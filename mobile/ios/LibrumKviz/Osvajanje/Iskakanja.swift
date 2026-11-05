import SwiftUI

/// Nova ratna karta (vlasnik 04.11.2026): karta uleti na sredinu ekrana, okrene se, pokaže šta radi, pa sama ode.
struct NovaKartaView: View {
    let karta: Karta
    let zatvori: () -> Void
    @State private var okrenuta = false
    @State private var ulaz = false
    @Environment(\.accessibilityReduceMotion) private var manjeKretanja

    var body: some View {
        ZStack {
            Color.senka.opacity(ulaz ? 0.55 : 0).ignoresSafeArea().onTapGesture(perform: zatvori)
            VStack(spacing: 12) {
                Oznaka(tekst: "Nova ratna karta", boja: .zuta)
                VStack(spacing: 10) {
                    Image(systemName: karta.ikonica).font(.system(size: 44, weight: .bold)).foregroundStyle(Color.tinta)
                        .frame(width: 84, height: 84).background(Color.zuta, in: Circle())
                        .overlay(Circle().stroke(Color.tinta, lineWidth: 3))
                    Text(karta.naziv).font(.naslov(28)).foregroundStyle(Color.mastilo)
                    Text(karta.opis).font(.tekst(15, .semibold)).foregroundStyle(Color.sivaTekst).multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(karta.naMapi ? "Igraš je na mapi, iz dugmeta Karte." : "Igraš je u bitki.").font(.tekst(12, .bold)).foregroundStyle(Color.teal)
                }
                .padding(22).frame(width: 260)
                .background(Color.kartica, in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.tinta, lineWidth: 3))
                .rotation3DEffect(.degrees(okrenuta || manjeKretanja ? 0 : 90), axis: (x: 0, y: 1, z: 0))
            }
            .scaleEffect(ulaz ? 1 : 0.3)
            .offset(y: ulaz ? 0 : 300)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Nova ratna karta: \(karta.naziv). \(karta.opis)")
        .task {
            withAnimation(.spring(duration: 0.45, bounce: 0.35)) { ulaz = true }
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(.spring(duration: 0.4)) { okrenuta = true }
            try? await Task.sleep(for: .seconds(2.6))
            withAnimation(.easeIn(duration: 0.25)) { ulaz = false }
            try? await Task.sleep(for: .milliseconds(250))
            zatvori()
        }
        .sensoryFeedback(.success, trigger: okrenuta)
    }
}

/// Saveznik je poslao vojsku: kartica pri vrhu sa imenom, koliko i gde; dodir vodi kameru na tu državu.
struct PrimljenaPomocView: View {
    let pomoc: OsvajanjeModel.PrimljenaPomoc
    let pokazi: () -> Void
    let zatvori: () -> Void

    var body: some View {
        Button(action: pokazi) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.right.circle.fill").font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 36, height: 36).background(Color(hex: pomoc.boja), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 1) {
                    Oznaka(tekst: "Pomoć saveznika", boja: .teal)
                    Text("\(pomoc.od): +\(Pravila.vojskiPomociSavezniku) vojske u \(Mapa.oblast(pomoc.u).ime)").font(.tekst(15, .bold)).foregroundStyle(Color.mastilo)
                    Text("iz \(Mapa.oblast(pomoc.iz).ime) · dodirni da vidiš").font(.tekst(12)).foregroundStyle(Color.sivaTekst)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(Color.kartica, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: pomoc.boja), lineWidth: 2.5))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12).padding(.top, 118)
        .transition(.move(edge: .top).combined(with: .opacity))
        .task { try? await Task.sleep(for: .seconds(6)); zatvori() }
        .accessibilityHint("Pokazuje državu na mapi")
    }
}

/// Ruka ratnih karata: svaka sa opisom; karte za mapu se odavde i igraju.
struct KarteList: View {
    let model: OsvajanjeModel
    let zatvori: () -> Void

    var body: some View {
        DonjiList(zatvori: zatvori) {
            VStack(alignment: .leading, spacing: 12) {
                Naslov(tekst: "Ratne karte", velicina: 28)
                Text("Dobijaš ih za pobedu nad igračem, ceo region, \(Pravila.osvajanjaZaKartu) osvojene države u potezu, proboj i \(Pravila.pobedaZaKartu) dobijene bitke zaredom. U ruci najviše \(Pravila.najviseKarata).")
                    .font(.tekst(13)).foregroundStyle(Color.sivaTekst).fixedSize(horizontal: false, vertical: true)
                let ruka = model.mojeKarte
                if ruka.isEmpty {
                    Text("Još nemaš nijednu kartu.").font(.tekst(15, .semibold)).foregroundStyle(Color.sivaTekst).padding(.vertical, 8)
                }
                ForEach(Karta.allCases) { k in
                    let broj = ruka.filter { $0 == k }.count
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: k.ikonica).font(.system(size: 18, weight: .bold)).foregroundStyle(Color.tinta)
                            .frame(width: 42, height: 42).background(broj > 0 ? Color.zuta : Color.udubljeno, in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(broj > 0 ? "\(k.naziv) · \(broj)" : k.naziv).font(.tekst(15, .bold))
                            Text(k.opis).font(.tekst(13)).foregroundStyle(Color.sivaTekst).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        if k.naMapi && broj > 0 && model.covekNaPotezu && model.stanje.faza == .napad {
                            Button("Igraj") { model.igrajKartuNaMapi(k); zatvori() }
                                .font(.tekst(14, .bold)).foregroundStyle(Color.naMastilu).padding(.horizontal, 14).frame(height: 38)
                                .background(Color.mastilo, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .foregroundStyle(Color.mastilo)
                    .opacity(broj > 0 ? 1 : 0.55)
                }
            }
        }
    }
}

/// Legenda mape (vlasnik 04.11: novi igrači ne znaju šta su zvezdice, krune i linije).
struct LegendaList: View {
    let stanje: Stanje
    var vodic: (() -> Void)? = nil
    let zatvori: () -> Void

    var body: some View {
        DonjiList(zatvori: zatvori) {
            // Spisak je viši od ekrana: skrol u 3/4 visine, da X i vrh lista ostanu ispod statusne trake.
            ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Naslov(tekst: "Šta je šta na mapi", velicina: 28)
                if let vodic {
                    Button(action: vodic) {
                        Label("Ponovi vodič kroz igru", systemImage: "figure.wave").font(.tekst(15, .bold)).foregroundStyle(Color.tinta)
                            .frame(maxWidth: .infinity).frame(height: 46).background(Color.zuta, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.tinta, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
                red("crown.fill", .zuta, "Kruna", "Prestonica. Ko je osvoji, dobija +\(Pravila.plenPrestonice) vojski plena.")
                red("star.fill", .zuta, "Zvezdica", "Čudo sveta: država sa posebnim bonusom (spisak ispod).")
                red("circle.dashed", .sivaTekst, "Isprekidan krug", "Malo ostrvo ili mala država, da se lakše vidi i dodirne.")
                red("point.topleft.down.to.point.bottomright.curvepath", .sivaTekst, "Isprekidana linija preko mora", "Morska veza: ove dve države su susedi. Napad preko mora traži jedan tačan više.")
                red("square.dashed", .crvena, "Crvena isprekidana ivica", "Tvoja država je odsečena od prestonice: ne stižu joj pojačanja i gubi vojsku.")
                red("square", .zuta, "Žuta ivica", "Odatle možeš da napadneš u ovom potezu.")
                red("number.square", .mastilo, "≤2, 3–5…", "Magla rata: tačan broj tuđih vojski ne vidiš dok nisi pored.")
                Text("Čuda sveta").font(.tekst(16, .bold)).padding(.top, 6)
                ForEach(Cudo.sva.filter { stanje.oblasti[$0.oblast] != nil }, id: \.oblast) { c in
                    let drzi = stanje.igraci.first { $0.tim == stanje.oblasti[c.oblast]?.vlasnik }
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "star.fill").font(.system(size: 13)).foregroundStyle(Color.zuta)
                            .frame(width: 26, height: 26).background(Color.tinta, in: Circle())
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(c.naziv) · \(Mapa.oblast(c.oblast).ime)").font(.tekst(14, .bold))
                            Text(c.opis).font(.tekst(13)).foregroundStyle(Color.sivaTekst).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Text(drzi?.ime ?? "slobodno").font(.tekst(12, .bold)).foregroundStyle(drzi.map { Color(hex: $0.boja) } ?? Color.sivaTekst)
                    }
                }
            }
            .foregroundStyle(Color.mastilo)
            .padding(.top, 30)
            }
            .scrollBounceBehavior(.basedOnSize)
            .containerRelativeFrame(.vertical) { h, _ in h * 0.75 }
        }
    }

    private func red(_ ikonica: String, _ boja: Color, _ naslov: String, _ opis: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: ikonica).font(.system(size: 16, weight: .bold)).foregroundStyle(boja)
                .frame(width: 38, height: 38).background(Color.udubljeno, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 1) {
                Text(naslov).font(.tekst(15, .bold))
                Text(opis).font(.tekst(13)).foregroundStyle(Color.sivaTekst).fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Efekat preko ekrana: kombo, ceo region, pala prestonica, tvoj potez; sam nestaje.
struct EfekatView: View {
    let efekat: OsvajanjeModel.Efekat
    let gotovo: () -> Void
    @State private var ulaz = false
    @Environment(\.accessibilityReduceMotion) private var manjeKretanja

    private var tekst: (naslov: String, pod: String?, boja: Color, konfete: Bool) {
        switch efekat.vrsta {
        case .kombo(let n): ("Kombo ×\(n)!", n >= Pravila.probojSvakih ? "Proboj: +\(Pravila.probojBonus) vojske i karta" : "Osvajaj dalje!", .roze, n >= 3)
        case .region(let r): ("Ceo region!", r, .teal, true)
        case .prestonica: ("Prestonica pala!", "+\(Pravila.plenPrestonice) vojski plena", .narandzasta, true)
        case .izgubio: ("Izgubio si državu", nil, .crvena, false)
        case .tvojPotez: ("Tvoj potez!", nil, .zuta, false)
        case .pobeda: ("Pobeda!", nil, .teal, true)
        }
    }

    var body: some View {
        let t = tekst
        ZStack {
            if t.konfete && !manjeKretanja { Konfete() }
            VStack(spacing: 4) {
                Text(t.naslov).font(.naslov(efekat.vrsta == .tvojPotez ? 30 : 40)).foregroundStyle(t.boja == .zuta ? Color.tinta : .white)
                if let p = t.pod { Text(p).font(.tekst(16, .bold)).foregroundStyle(t.boja == .zuta ? Color.tinta : .white.opacity(0.9)) }
            }
            .padding(.horizontal, 26).padding(.vertical, 14)
            .background(t.boja, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.tinta, lineWidth: 3))
            .rotationEffect(.degrees(ulaz ? -3 : -18))
            .scaleEffect(ulaz ? 1 : 0.2)
            .opacity(ulaz ? 1 : 0)
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(t.naslov + (t.pod.map { ", \($0)" } ?? ""))
        .sensoryFeedback(.impact(weight: .heavy), trigger: ulaz)
        .task {
            withAnimation(.spring(duration: 0.4, bounce: 0.5)) { ulaz = true }
            try? await Task.sleep(for: .seconds(efekat.vrsta == .tvojPotez ? 1.1 : 1.6))
            withAnimation(.easeIn(duration: 0.25)) { ulaz = false }
            try? await Task.sleep(for: .milliseconds(260))
            gotovo()
        }
    }
}

/// Kratko tresenje ekrana kad igrač izgubi državu.
struct Tresenje: ViewModifier {
    let udarac: Int
    @State private var pomak: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var manjeKretanja

    func body(content: Content) -> some View {
        content.offset(x: pomak)
            .onChange(of: udarac) { _, _ in
                guard !manjeKretanja else { return }
                Task {
                    for x in [10.0, -8, 6, -4, 2, 0] {
                        withAnimation(.linear(duration: 0.05)) { pomak = x }
                        try? await Task.sleep(for: .milliseconds(50))
                    }
                }
            }
            .sensoryFeedback(.error, trigger: udarac)
    }
}
