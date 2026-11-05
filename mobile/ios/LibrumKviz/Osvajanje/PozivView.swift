import SwiftUI

/// Partija na poziv (vlasnik 03.11.2026): domaćin pravi privatnu sobu sa kodom, poziva prijatelje porukom ili linkom
/// (librumkviz://osvajanje/KOD), svi čekaju u čekaonici, a partija kreće kad domaćin pritisne „Počni” (prazna mesta su botovi).
/// Server: scripts/2026-11-03_osvajanje-privatne-sobe.sql.
struct PozivView: View {
    /// Domaćin dolazi sa postavkom (način, broj igrača, krugovi); gost samo sa kodom.
    let postavka: OsvajanjePostavka?
    let kod: String?
    @Environment(\.dismiss) private var zatvori
    @Environment(Sesija.self) private var sesija
    @State private var soba: CekaonicaView.Soba?
    @State private var greska: String?
    @State private var prijatelji: [Prijatelj] = []
    @State private var pozvani: Set<String> = []
    @State private var igra: OsvajanjePostavka?
    @State private var krece = false
    /// Moja vojska; ide na server, jer početno stanje pravi domaćinov telefon (bag 04.11: gost nije mogao da bira).
    @AppStorage("osvajanje.vojska") private var vojska: VrstaVojske = .legija
    /// Domaćin raspoređuje mesta po timovima (vlasnik 04.11: „ja i Nikolina protiv botova”, „ja i bot protiv Nikoline i bota”).
    @State private var timovi: [String] = []

    struct Prijatelj: Decodable, Identifiable { let id: String; let nadimak: String; let avatar: String? }

    private var jaDomacin: Bool { soba?.mesta.first { $0.mesto == 0 }?.user_id == sesija.korisnikId }
    private var nacin: OsvajanjePostavka.Nacin { soba.flatMap { OsvajanjePostavka.Nacin(rawValue: $0.nacin) } ?? postavka?.nacin ?? .svakoZaSebe }
    private var link: String { "librumkviz://osvajanje/\(soba?.kod ?? "")" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GornjaTraka(ikonica: "xmark")
                Naslov(tekst: "Partija sa prijateljima", velicina: 32)
                if let greska {
                    Label(greska, systemImage: "exclamationmark.triangle").font(.tekst(15, .semibold)).foregroundStyle(Color.crvena)
                    Button("Nazad") { zatvori() }.buttonStyle(.sekundarno)
                } else if let s = soba {
                    sadrzaj(s)
                } else {
                    ProgressView().tint(Color.mastilo).frame(maxWidth: .infinity).padding(.top, 40)
                }
            }
            .padding(16)
        }
        .background(Papir())
        .fullScreenCover(item: $igra) { p in OsvajanjeIgraView(model: OsvajanjeModel(postavka: p)) }
        .task { await vodi() }
        .onReceive(NotificationCenter.default.publisher(for: .novaPartijaOsvajanja)) { _ in zatvori() }
        .onChange(of: vojska) { Task { await posaljiVojsku() } }
        .onAppear { Zvuk.pusti(.cekanje, jacina: 0.2, ponavljaj: true) }
        .onDisappear { Zvuk.stani(.cekanje) }
    }

    @ViewBuilder private func sadrzaj(_ s: CekaonicaView.Soba) -> some View {
        Text("\(nacin.naziv) · \(s.velicina) igrača · \(s.teren.flatMap { t in Kontinenti.svi.first { $0.id == t }?.ime } ?? "ceo svet")")
            .font(.tekst(14, .semibold)).foregroundStyle(Color.sivaTekst)
        // Kod sobe: prijatelj ga ukuca u „Imam kod” ili otvori link.
        VStack(spacing: 6) {
            Text("Kod sobe").font(.tekst(13, .bold)).foregroundStyle(Color.tinta)
            Text(s.kod ?? "").font(.system(size: 40, weight: .heavy, design: .monospaced)).tracking(6).foregroundStyle(Color.tinta)
                .textSelection(.enabled)
            ShareLink(item: "Igrajmo Osvajača u Librum kvizu! Kod sobe: \(s.kod ?? "") · \(link)") {
                Label("Pošalji poziv", systemImage: "square.and.arrow.up").font(.tekst(15, .bold)).foregroundStyle(Color.naMastilu)
                    .padding(.horizontal, 18).frame(height: 46).background(Color.mastilo, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .frame(maxWidth: .infinity).padding(16).pop(.zuta, radijus: 20)

        // Za stolom: svako mesto sa vojskom i timom; domaćin dodirom menja tim mesta.
        Text("Za stolom \(s.mesta.count) od \(s.velicina)").font(.tekst(16, .bold))
        if jaDomacin && s.velicina > 2 {
            Text("Dodirni tim pored mesta da sastaviš strane: npr. ti i prijatelj u istom timu protiv botova. Prazna mesta igraju botovi.")
                .font(.tekst(13)).foregroundStyle(Color.sivaTekst)
        }
        VStack(spacing: 8) {
            ForEach(0..<s.velicina, id: \.self) { i in
                let m = s.mesta.first { $0.mesto == i }
                let tim = timMesta(i, s)
                HStack(spacing: 10) {
                    if let m { AvatarSlika(avatar: m.avatar, velicina: 40) } else {
                        Image(systemName: "cpu").font(.system(size: 16, weight: .bold)).foregroundStyle(Color.sivaTekst).frame(width: 40, height: 40)
                            .background(Color.udubljeno, in: Circle())
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(m?.nadimak ?? "Bot (slobodno mesto)").font(.tekst(15, .bold)).lineLimit(1).foregroundStyle(m == nil ? Color.sivaTekst : Color.mastilo)
                        Text((i == 0 ? "domaćin · " : "") + (m?.vojska.flatMap(VrstaVojske.init(rawValue:))?.naziv ?? (m == nil ? "vojska po naravi" : "bira vojsku…")))
                            .font(.tekst(12, .semibold)).foregroundStyle(Color.sivaTekst)
                    }
                    Spacer(minLength: 0)
                    if s.velicina > 2 {
                        Button { promeniTim(i, s) } label: {
                            Text("Tim \(tim)").font(.tekst(14, .heavy)).foregroundStyle(Color.tinta)
                                .padding(.horizontal, 12).frame(height: 36)
                                .background(Color(hex: OsvajanjePostavka.boje[Int(tim.unicodeScalars.first!.value) - 65]).opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.mastilo, lineWidth: jaDomacin ? 1.5 : 0))
                        }
                        .buttonStyle(.plain).disabled(!jaDomacin)
                        .accessibilityLabel("Tim \(tim)" + (jaDomacin ? ", dodirni da promeniš" : ""))
                    }
                }
                .padding(10).mirna()
            }
        }
        if OsvajanjePostavka.imaZajednickihTimova((0..<s.velicina).map { timMesta($0, s) }) {
            IzborSaveza(savez: Binding(get: { s.savez ?? false }, set: { novi in promeniSavez(novi, s) }), menja: jaDomacin)
        }
        Text("Tvoja vojska").font(.tekst(16, .bold)).padding(.top, 4)
        IzborVojske(vojska: $vojska)
        if jaDomacin {
            if !prijatelji.isEmpty {
                Text("Pozovi iz aplikacije").font(.tekst(16, .bold)).padding(.top, 4)
                ForEach(prijatelji.filter { p in !s.mesta.contains { $0.user_id == p.id } }) { p in
                    HStack(spacing: 10) {
                        AvatarSlika(avatar: p.avatar, velicina: 36)
                        Text(p.nadimak).font(.tekst(15, .semibold))
                        Spacer()
                        Button(pozvani.contains(p.id) ? "Pozvan" : "Pozovi") { Task { await pozovi(p) } }
                            .font(.tekst(14, .bold)).foregroundStyle(pozvani.contains(p.id) ? Color.sivaTekst : Color.teal)
                            .disabled(pozvani.contains(p.id))
                    }
                    .padding(10).mirna()
                }
            }
            Text(s.mesta.count < 2 ? "Čeka se bar jedan prijatelj." : "Prazna mesta preuzimaju botovi.")
                .font(.tekst(13)).foregroundStyle(Color.sivaTekst)
            if Set((0..<s.velicina).map { timMesta($0, s) }).count < 2 {
                Label("Potrebna su bar dva tima.", systemImage: "exclamationmark.triangle").font(.tekst(13, .semibold)).foregroundStyle(Color.crvena)
            }
            Button(krece ? "Pokrećem…" : "Počni partiju") { Task { await pokreni() } }
                .buttonStyle(.primarno).disabled(s.mesta.count < 2 || krece || Set((0..<s.velicina).map { timMesta($0, s) }).count < 2)
        } else {
            Label("Čeka se da domaćin pokrene partiju.", systemImage: "hourglass").font(.tekst(15, .semibold)).foregroundStyle(Color.sivaTekst)
        }
    }

    /// Tim mesta: izbor domaćina sa servera, inače podrazumevano (timovi po dvoje se smenjuju A, B, C, A, B, C; svako za sebe = svoje slovo).
    static func podrazumevaniTim(_ i: Int, _ nacin: OsvajanjePostavka.Nacin, _ velicina: Int) -> String {
        let timova = nacin == .timovi ? max(2, velicina / 2) : velicina
        return String(UnicodeScalar(65 + i % min(timova, 6))!)
    }

    private func timMesta(_ i: Int, _ s: CekaonicaView.Soba) -> String {
        if !timovi.isEmpty, i < timovi.count { return timovi[i] }
        if let t = s.timovi, i < t.count { return t[i] }
        return Self.podrazumevaniTim(i, nacin, s.velicina)
    }

    /// Domaćin dodirom vrti tim mesta kroz A…(najviše F); raspored ide na server da ga vide svi za stolom.
    private func promeniTim(_ i: Int, _ s: CekaonicaView.Soba) {
        guard jaDomacin else { return }
        var t = (0..<s.velicina).map { timMesta($0, s) }
        let slova = min(s.velicina, 6)
        let sad = Int(t[i].unicodeScalars.first!.value) - 65
        t[i] = String(UnicodeScalar(65 + (sad + 1) % slova)!)
        timovi = t
        Task {
            guard let token = try? await sesija.vazeciToken() else { return }
            if let nova: CekaonicaView.Soba = try? await Supabase.deljeni.rpc("osvajanje_postavi_timove", ["p_soba": s.id, "p_timovi": t], token: token) { soba = nova }
        }
    }

    private func promeniSavez(_ novi: Bool, _ s: CekaonicaView.Soba) {
        guard jaDomacin else { return }
        Task {
            guard let token = try? await sesija.vazeciToken() else { return }
            if let nova: CekaonicaView.Soba = try? await Supabase.deljeni.rpc("osvajanje_postavi_savez", ["p_soba": s.id, "p_savez": novi], token: token) { soba = nova }
        }
    }

    private func posaljiVojsku() async {
        guard let s = soba, let token = try? await sesija.vazeciToken() else { return }
        if let nova: CekaonicaView.Soba = try? await Supabase.deljeni.rpc("osvajanje_izaberi_vojsku", ["p_soba": s.id, "p_vojska": vojska.rawValue], token: token) { soba = nova }
    }

    // MARK: Server

    private func vodi() async {
        guard let token = try? await sesija.vazeciToken() else { greska = "Prijavi se da bi igrao sa prijateljima."; return }
        do {
            if let kod {
                soba = try await Supabase.deljeni.rpc("osvajanje_udji_kodom", ["p_kod": kod], token: token)
            } else if let p = postavka {
                soba = try await Supabase.deljeni.rpc("osvajanje_napravi_sobu",
                    ["p_nacin": p.nacin.rawValue, "p_velicina": p.igraca, "p_teren": p.teren as Any? ?? NSNull()], token: token)
                prijatelji = (try? await Supabase.deljeni.rpc("osvajanje_za_poziv", [:], token: token)) ?? []
            }
            await posaljiVojsku()
            while !Task.isCancelled, let s = soba, s.status == "ceka" {
                try await Task.sleep(for: .seconds(2))
                if let nova: CekaonicaView.Soba = try? await Supabase.deljeni.rpc("osvajanje_soba", ["p_soba": s.id], token: token) {
                    if nova.mesta.count > (soba?.mesta.count ?? 0) { Zvuk.pusti(.protivnikUsao, jacina: 0.45) }
                    soba = nova
                    if !jaDomacin { timovi = [] }
                }
            }
            if let s = soba, s.status == "pocela" { pocni(s) }
        } catch is CancellationError {
            await napusti(token)
        } catch let g as Supabase.Greska {
            greska = g.poruka.contains("ne postoji") ? "Soba ne postoji ili je partija već počela. Proveri kod." : g.poruka.contains("puna") ? "Soba je puna." : g.poruka
        } catch {
            greska = "Server za sobe se ne javlja. Probaj ponovo."
        }
    }

    private func napusti(_ token: String) async {
        guard let s = soba, s.status == "ceka" else { return }
        let _: String? = try? await Supabase.deljeni.rpc("osvajanje_napusti", ["p_soba": s.id], token: token)
    }

    private func pozovi(_ p: Prijatelj) async {
        guard let s = soba, let kod = s.kod else { return }
        pozvani.insert(p.id)
        try? await Zajednica.posaljiPoruku(sesija, za: p.id, tekst: "Pozivam te da igramo Osvajača! Kod sobe: \(kod) · \(link)")
    }

    private func pokreni() async {
        guard let s = soba, let token = try? await sesija.vazeciToken() else { return }
        krece = true
        if let nova: CekaonicaView.Soba = try? await Supabase.deljeni.rpc("osvajanje_pokreni_privatnu", ["p_soba": s.id], token: token) { soba = nova }
        krece = false
    }

    /// Partija kreće: mesta za stolom postaju igrači (sa istim id-jem na svakom telefonu), prazna su botovi.
    /// Mapu i misije postavlja domaćinov telefon (VezaOsvajanja), ostali čekaju njegovo prvo stanje.
    private func pocni(_ s: CekaonicaView.Soba) {
        let ja = sesija.korisnikId ?? ""
        var p = postavka ?? OsvajanjePostavka(nacin: nacin, igraca: s.velicina, krugova: 12, tezina: .normalno, igraci: [])
        p.nacin = nacin
        p.igraca = s.velicina
        p.teren = s.teren
        // Timovi po izboru domaćina; redosled poteza se smenjuje po timovima (A1, B1, A2, B2…), kapiten je prvi pravi igrač tima.
        let timoviMesta = (0..<s.velicina).map { timMesta($0, s) }
        var redTimova: [String] = []
        for t in timoviMesta where !redTimova.contains(t) { redTimova.append(t) }
        let zauzeto = Set(s.mesta.map(\.mesto))
        // U timu prvo pravi igrači (kapiten je čovek), pa botovi.
        let poTimu = redTimova.map { t in (0..<s.velicina).filter { timoviMesta[$0] == t }
            .sorted { a, b in (zauzeto.contains(a) ? 0 : 1, a) < (zauzeto.contains(b) ? 0 : 1, b) } }
        var redMesta: [Int] = []
        for k in 0..<(poTimu.map(\.count).max() ?? 0) { for l in poTimu where k < l.count { redMesta.append(l[k]) } }
        p.nacin = redTimova.count == s.velicina ? (s.velicina == 2 ? .jedanNaJedan : .svakoZaSebe) : .timovi
        p.igraci = redMesta.map { i in
            let tim = timoviMesta[i]
            let boja = OsvajanjePostavka.boje[(Int(tim.unicodeScalars.first!.value) - 65) % OsvajanjePostavka.boje.count]
            let kapiten = poTimu.first { $0.contains(i) }?.first == i
            guard let m = s.mesta.first(where: { $0.mesto == i }) else {
                return NoviIgrac(id: "bot\(i)", ime: OsvajanjePostavka.imenaBotova[i % OsvajanjePostavka.imenaBotova.count], boja: boja, covek: false, tim: tim, kapiten: kapiten)
            }
            return NoviIgrac(id: VezaOsvajanja.idIgraca(m.user_id), ime: m.nadimak, boja: boja, covek: m.user_id == ja, tim: tim, kapiten: kapiten,
                             vojska: m.user_id == ja ? vojska : m.vojska.flatMap(VrstaVojske.init(rawValue:)))
        }
        // Savez: isti tim postaje strana, svako dobija svoj tim i boju (vlasnik 04.11).
        if s.savez == true && OsvajanjePostavka.imaZajednickihTimova(timoviMesta) {
            p.igraci = OsvajanjePostavka.uSavez(p.igraci)
            p.nacin = .svakoZaSebe
        }
        p.soba = s.id
        p.korisnik = ja
        p.domacin = s.mesta.first { $0.mesto == 0 }?.user_id == ja
        p.traziIgrace = false
        Zvuk.pusti(.bedz, jacina: 0.4)
        igra = p
    }
}
