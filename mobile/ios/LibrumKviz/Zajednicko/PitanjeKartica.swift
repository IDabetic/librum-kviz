import SwiftUI

/// Žuta kartica pitanja iz kita sa tajmerom. Javlja odgovor (indeks ili nil
/// na istek) i proteklo vreme; posle otkrivanja čeka `trajanjeOtkrivanja`.
struct PitanjeKartica: View {
    let oznaka: String
    let prikaz: Prikaz
    var sekundi = Pravila.sekundiPoPitanju
    var dodatak: String? = nil
    var eliminisani: Set<Int> = []
    /// Pomoć „Vreme stoji”: sat se zaustavlja, pitanje ne ističe.
    var stoji = false
    /// Pomoć „Siguran udar”: koji god odgovor da izabere, računa se kao tačan (pa se i prikazuje zeleno).
    var sigurno = false
    /// Pomoć „Štit”: pogrešan odgovor se ne vidi kao poraz, nego kao obrisana greška.
    var stit = false
    /// Boja kartice: žuta u svim igrama, plava u Karijeri (vlasnik 04.11).
    var boja: Color = .zuta
    /// Javlja čim je odgovor izabran (pre otkrivanja tačnog), npr. da Karijera skloni ometanje.
    var izabrano: (() -> Void)? = nil
    let gotovo: (_ izabran: Int?, _ ms: Int) -> Void

    @State private var pocetak = Date()
    @State private var izabran: Int?
    @State private var otkriveno = false
    @State private var preostalo: Double = 1
    /// Siguran udar: posle pola sekunde pogrešan izbor pozeleni („priznato”).
    @State private var priznato = false

    private let trajanjeOtkrivanja: Duration = .milliseconds(3000)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Oznaka(tekst: oznaka, boja: .mastilo)
                Spacer()
                PrijaviPitanjeDugme(prikaz: prikaz)
                if stoji {
                    Image(systemName: "pause.circle.fill").font(.system(size: 22, weight: .bold)).foregroundStyle(Color.teal)
                        .accessibilityLabel("Sat stoji")
                } else { TimelineView(.periodic(from: .now, by: 0.25)) { kontekst in
                    let ostalo = max(0, Double(sekundi) - kontekst.date.timeIntervalSince(pocetak))
                    let zuri = ostalo <= 5 && !otkriveno
                    Text("\(Int(ostalo.rounded(.up)))").font(.naslov(22)).monospacedDigit()
                        .foregroundStyle(zuri ? Color.crvena : Color.mastilo)
                        .scaleEffect(zuri ? 1 + 0.12 * (ostalo.truncatingRemainder(dividingBy: 1)) : 1)
                        .onChange(of: Int(ostalo)) { _, sec in
                            if sec == 0 && !otkriveno { izaberi(nil) }
                            // Tihi sat samo u poslednjih 5 sekundi.
                            if sec == 5 && !otkriveno { Zvuk.pusti(.petSekundi, jacina: 1.0); Zvuk.pusti(.tikanje, jacina: 0.25, ponavljaj: true) }
                        }
                        .accessibilityLabel("\(Int(ostalo)) sekundi")
                } }
            }
            TimelineView(.animation(paused: otkriveno || stoji)) { kontekst in
                let deo = max(0, 1 - kontekst.date.timeIntervalSince(pocetak) / Double(sekundi))
                GeometryReader { g in
                    Capsule().fill(.white.opacity(0.6))
                        .overlay(alignment: .leading) {
                            Capsule().fill(deo < 0.34 ? Color.crvena : Color.mastilo).frame(width: g.size.width * deo)
                        }
                }
                .frame(height: 8)
            }
            Naslov(tekst: prikaz.tekst, velicina: 23)
                .padding(.bottom, 4)
            ForEach(Array(prikaz.opcije.enumerated()), id: \.offset) { i, opcija in
                OdgovorDugme(slovo: ["A", "B", "C", "D"][i], tekst: opcija, stanje: stanje(i)) { izaberi(i) }
                    .disabled(otkriveno || eliminisani.contains(i))
                    .opacity(eliminisani.contains(i) && !otkriveno ? 0.3 : 1)
            }
            if otkriveno, sigurno, priznato, izabran != nil, izabran != prikaz.tacan {
                Label("Siguran udar: računa se kao tačan.", systemImage: "scope").font(.tekst(15, .bold)).foregroundStyle(Color.mastilo)
            } else if otkriveno, stit, izabran != prikaz.tacan {
                Label("Štit je obrisao grešku: stiže novo pitanje.", systemImage: "shield.fill").font(.tekst(15, .bold)).foregroundStyle(Color.mastilo)
            }
            if otkriveno, let dodatak {
                Text(dodatak).font(.tekst(15, .bold)).foregroundStyle(Color.mastilo)
            }
        }
        .padding(20)
        .pop(boja)
        .onAppear {
            pocetak = Date()
            #if DEBUG
            // Snimak za sajt: igrač „razmisli” pa odgovori (uglavnom tačno).
            if LibrumKvizApp.demoIgrac { Task { try? await Task.sleep(for: .seconds(2.4)); izaberi(Int.random(in: 0..<10) < 8 ? prikaz.tacan : (prikaz.tacan + 1) % prikaz.opcije.count) } }
            #endif
        }
        .onDisappear { Zvuk.stani(.tikanje) }
        .onChange(of: stoji) { _, s in if s { Zvuk.stani(.tikanje) } }
        .sensoryFeedback(trigger: otkriveno) { _, _ in izabran == prikaz.tacan || (sigurno && izabran != nil) ? .success : .error }
    }

    private func stanje(_ i: Int) -> OdgovorDugme.Stanje {
        guard otkriveno else { return .obicno }
        if i == prikaz.tacan { return .tacno }
        if i == izabran { return sigurno && priznato ? .tacno : .netacno }
        return .bledo
    }

    private func izaberi(_ i: Int?) {
        guard !otkriveno else { return }
        izabran = i
        otkriveno = true
        izabrano?()
        Zvuk.stani(.tikanje)
        let uspeh = i != nil && (i == prikaz.tacan || sigurno)
        // Siguran udar sa pogrešnim izborom: prvo zvuk greške, pa „priznato” (gore).
        Zvuk.pusti(i == nil && !sigurno ? .isteklo : (uspeh && !(sigurno && i != prikaz.tacan)) ? .tacno : stit ? .pomocVojske : .netacno, jacina: 0.5)
        let ms = Int(Date().timeIntervalSince(pocetak) * 1000)
        if sigurno, i != nil, i != prikaz.tacan {
            Task { try? await Task.sleep(for: .milliseconds(700)); withAnimation(.spring(duration: 0.4)) { priznato = true }; Zvuk.pusti(.pomocVojske, jacina: 0.45) }
        }
        Task {
            try? await Task.sleep(for: trajanjeOtkrivanja)
            gotovo(i, ms)
        }
    }
}

struct OdgovorDugme: View {
    enum Stanje { case obicno, tacno, netacno, bledo }
    let slovo: String
    let tekst: String
    let stanje: Stanje
    let radnja: () -> Void
    @Environment(\.accessibilityReduceMotion) private var manjeKretanja
    @State private var pojavio = false

    /// Odgovori ulaze jedan za drugim (A, B, C, D), po 70 ms.
    private var kasnjenje: Double { Double(["A", "B", "C", "D"].firstIndex(of: slovo) ?? 0) * 0.07 }

    var body: some View {
        let (pozadina, ivica, slovoPozadina, slovoBoja): (Color, Color, Color, Color) = switch stanje {
        case .obicno: (.kartica, .mastilo, .tealSvetla, .teal)
        case .tacno: (.tealSvetla, .teal, .teal, .white)
        case .netacno: (.crvenaSvetla, .crvena, .crvena, .white)
        case .bledo: (Color.kartica.opacity(0.45), .clear, .tealSvetla, .teal)
        }
        Button(action: radnja) {
            HStack(spacing: 12) {
                Text(slovo).font(.tekst(15, .bold)).foregroundStyle(slovoBoja)
                    .frame(width: 36, height: 36)
                    .background(slovoPozadina, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(tekst).font(.tekst(16, .semibold)).foregroundStyle(Color.mastilo)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(minHeight: 56)
            .background(pozadina, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(ivica, lineWidth: 2))
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(ivica).offset(y: stanje == .bledo ? 0 : 4))
        }
        .buttonStyle(BezPrigusenja())
        .accessibilityLabel("\(slovo): \(tekst)")
        // Vlasnik 03.11, „kao da sam u igri”: tačan pulsira uz iskrice, pogrešan se zatrese.
        .keyframeAnimator(initialValue: Pokret(), trigger: stanje) { sadrzaj, p in
            sadrzaj.scaleEffect(p.razmera).offset(x: p.pomak)
        } keyframes: { _ in
            KeyframeTrack(\.razmera) {
                if stanje == .tacno && !manjeKretanja {
                    SpringKeyframe(1.06, duration: 0.18); SpringKeyframe(1, duration: 0.3)
                } else { LinearKeyframe(1, duration: 0.01) }
            }
            KeyframeTrack(\.pomak) {
                if stanje == .netacno && !manjeKretanja {
                    for x in [-10.0, 9, -7, 5, -3, 0] { LinearKeyframe(x, duration: 0.055) }
                } else { LinearKeyframe(0, duration: 0.01) }
            }
        }
        .overlay { if stanje == .tacno && !manjeKretanja { Iskrice().allowsHitTesting(false) } }
        .opacity(pojavio || manjeKretanja ? 1 : 0)
        .offset(y: pojavio || manjeKretanja ? 0 : 14)
        .onAppear { withAnimation(.spring(duration: 0.4, bounce: 0.3).delay(kasnjenje)) { pojavio = true } }
    }

    struct Pokret { var razmera = 1.0; var pomak = 0.0 }
}

/// Osam iskrica koje se razlete sa tačnog odgovora i nestanu (0,7 s).
struct Iskrice: View {
    @State private var pocetak = Date()
    var body: some View {
        TimelineView(.animation) { t in
            let f = min(1, t.date.timeIntervalSince(pocetak) / 0.7)
            Canvas { ctx, v in
                guard f < 1 else { return }
                let c = CGPoint(x: v.width * 0.82, y: v.height / 2)
                for i in 0..<8 {
                    let ugao = Double(i) / 8 * 2 * .pi
                    let d = 12 + 38 * (1 - pow(1 - f, 2))
                    let p = CGPoint(x: c.x + cos(ugao) * d, y: c.y + sin(ugao) * d * 0.8)
                    let r = 4.5 * (1 - f)
                    var z = Path()
                    z.move(to: CGPoint(x: p.x, y: p.y - r * 1.6)); z.addLine(to: CGPoint(x: p.x + r * 0.4, y: p.y))
                    z.addLine(to: CGPoint(x: p.x, y: p.y + r * 1.6)); z.addLine(to: CGPoint(x: p.x - r * 0.4, y: p.y)); z.closeSubpath()
                    ctx.fill(z, with: .color(i.isMultiple(of: 2) ? Color.zuta : Color.teal))
                }
            }
        }
    }
}

/// Dugme koje ne bledi kad je onemogućeno: posle otkrivanja tačan odgovor mora ostati jarko zelen.
struct BezPrigusenja: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}


/// Zastavica na kartici pitanja: prijava netačnog pitanja (RPC prijavi_pitanje; dve prijave gase pitanje do pregleda).
struct PrijaviPitanjeDugme: View {
    let prikaz: Prikaz
    @Environment(Sesija.self) private var sesija
    @State private var otvoreno = false
    @State private var poslato = false
    @State private var greska: String?
    private static let razlozi = ["Tačan odgovor nije tačan", "Više odgovora je tačno", "Pitanje je nejasno", "Pravopis ili greška u kucanju", "Zastarelo"]

    var body: some View {
        if prikaz.id != nil && sesija.prijavljen {
            Button { otvoreno = true } label: {
                Image(systemName: poslato ? "flag.fill" : "flag").font(.system(size: 14, weight: .bold)).foregroundStyle(Color.tinta)
                    .frame(width: 34, height: 34).contentShape(Rectangle())
            }
            .buttonStyle(.plain).disabled(poslato)
            .accessibilityLabel(poslato ? "Pitanje je prijavljeno" : "Prijavi netačno pitanje")
            .sheet(isPresented: $otvoreno) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Šta nije u redu?").font(.naslov(24))
                    Text(prikaz.tekst).font(.tekst(14)).foregroundStyle(Color.sivaTekst).lineLimit(3)
                    VStack(spacing: 0) {
                        ForEach(Self.razlozi, id: \.self) { r in
                            Button { Task { await posalji(r) } } label: {
                                HStack { Text(r).font(.tekst(16, .semibold)); Spacer(); Image(systemName: "chevron.right").foregroundStyle(Color.sivaTekst) }
                                    .foregroundStyle(Color.mastilo).padding(.vertical, 13).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if let greska { Text(greska).font(.tekst(14, .semibold)).foregroundStyle(Color.crvena) }
                    Text("Kad dva igrača prijave isto pitanje, ono se sklanja dok ga urednik ne proveri.").font(.tekst(12)).foregroundStyle(Color.sivaTekst)
                }
                .padding(20)
                .presentationDetents([.medium])
            }
        }
    }

    private func posalji(_ razlog: String) async {
        guard let id = prikaz.id, let t = try? await sesija.vazeciToken() else { return }
        struct O: Decodable { let ok: Bool; let greska: String? }
        if let r: O = try? await Supabase.deljeni.rpc("prijavi_pitanje", ["p_id": id, "p_razlog": razlog], token: t) {
            if r.ok { poslato = true; otvoreno = false } else { greska = r.greska }
        } else { greska = "Prijava nije poslata. Proveri internet." }
    }
}
