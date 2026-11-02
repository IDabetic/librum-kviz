import SwiftUI

/// Činjenice o državama (Wikidata, alati/cinjenice-drzava.mjs) za uvod u bitku.
enum Cinjenice {
    static let sve: [String: [String]] = {
        guard let url = Bundle.main.url(forResource: "cinjenice", withExtension: "json"),
              let d = try? Data(contentsOf: url), let s = try? JSONDecoder().decode([String: [String]].self, from: d) else { return [:] }
        return s
    }()
}

/// Bitka za državu: uvod (koju državu napadaš ili braniš, ko je drži, odbrana i činjenice,
/// odbrojavanje), pa pitanja (5 za državu koju drži igrač, 1 za neutralnu), pa rezultat.
struct BitkaView: View {
    let model: OsvajanjeModel
    let bitka: OsvajanjeModel.Bitka
    @State private var odbrojavanje = 4
    @State private var pomocIskoriscena = false
    @State private var eliminisani: Set<Int> = []

    private var drzava: Oblast { Mapa.oblast(bitka.kuda) }

    var body: some View {
        ZStack {
            Color.senka.opacity(0.65).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    switch bitka.korak {
                    case .uvod: uvod
                    case .pitanja: pitanja
                    case .rezultat: rezultat
                    }
                }
                .padding(16).padding(.top, 30)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .transition(.opacity)
    }

    // MARK: Uvod

    private var uvod: some View {
        VStack(alignment: .leading, spacing: 12) {
            Oznaka(tekst: bitka.napadam ? "Napadaš" : "\(bitka.rivalIme) napada tvoju državu", boja: .roze)
            Text(drzava.ime).font(.naslov(38)).foregroundStyle(Color.mastilo)
            Text("\(Kontinenti.od(bitka.kuda).ime) · \(bitka.napadam ? "drži je \(bitka.rivalIme)" : "brani je tvoj tim")")
                .font(.tekst(14, .semibold)).foregroundStyle(Color.sivaTekst)
            let cinjenice = Cinjenice.sve[bitka.kuda] ?? []
            if !cinjenice.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(cinjenice.prefix(5), id: \.self) { c in
                        Label(c, systemImage: "sparkle").font(.tekst(14)).foregroundStyle(Color.mastilo)
                    }
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.udubljeno, in: RoundedRectangle(cornerRadius: 14))
            }
            if let o = model.stanje.odbranaMete(bitka.kuda) {
                Label("Odbrana: \(o.naziv). \(o.opis)", systemImage: o.ikonica).font(.tekst(14, .bold)).foregroundStyle(Color.crvena)
            }
            Text(bitka.uslov.pitanja > 1
                 ? "\(bitka.uslov.pitanja) pitanja po \(bitka.uslov.sekundi) s. Više tačnih osvaja; kad je isto, brži."
                 : "Jedno pitanje od \(bitka.uslov.sekundi) s. Tačno osvaja neutralnu državu.")
                .font(.tekst(14)).foregroundStyle(Color.sivaTekst)
            HStack {
                Spacer()
                Text(odbrojavanje > 0 ? "\(odbrojavanje)" : "Kreni!").font(.naslov(54)).foregroundStyle(Color.tinta)
                    .frame(width: 120, height: 120).background(Color.zuta, in: Circle()).overlay(Circle().stroke(Color.mastilo, lineWidth: 3))
                    .contentTransition(.numericText(countsDown: true))
                    .accessibilityLabel("Počinje za \(odbrojavanje)")
                Spacer()
            }
            .padding(.top, 6)
        }
        .padding(20).pop(radijus: 26)
        .task {
            for b in stride(from: 3, through: 0, by: -1) {
                try? await Task.sleep(for: .seconds(1))
                withAnimation { odbrojavanje = b }
            }
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation { model.pocniPitanja() }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: odbrojavanje)
    }

    // MARK: Pitanja

    private var pitanja: some View {
        let p = bitka.prikazi[bitka.redni]
        return VStack(spacing: 12) {
            HStack {
                Text(drzava.ime).font(.naslov(22)).foregroundStyle(.white)
                Spacer()
                Text("Tačno \(bitka.tacnih) od \(bitka.redni)").font(.tekst(14, .bold)).foregroundStyle(.white).monospacedDigit()
            }
            PitanjeKartica(oznaka: bitka.prikazi.count > 1 ? "Pitanje \(bitka.redni + 1) od \(bitka.prikazi.count)" : "Bitka",
                           prikaz: p, sekundi: bitka.uslov.sekundi, eliminisani: eliminisani) { izabran, ms in
                eliminisani = []
                model.odgovorUBitci(izabran, ms: ms)
            }
            .id("\(bitka.id)-\(bitka.redni)")
            if bitka.uslov.bezPomoci {
                Label("Odbrana „Bez pomoći”: ovde ne možeš da koristiš pomoć.", systemImage: "nosign").font(.tekst(13, .semibold)).foregroundStyle(.white)
            } else {
                HStack(spacing: 12) {
                    if model.bonusPomoci > 0 {
                        Button {
                            if model.iskoristiBonusPomoc() { pedesetPedeset(p) }
                        } label: {
                            Label("50/50 · \(model.bonusPomoci)", systemImage: "gift").font(.tekst(14, .bold)).foregroundStyle(Color.tinta)
                                .padding(.horizontal, 14).frame(height: 54).background(Color.zuta, in: RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.tinta, lineWidth: 2))
                        }
                        .disabled(!eliminisani.isEmpty)
                        .accessibilityLabel("Dodatna pomoć 50/50, ostalo \(model.bonusPomoci)")
                    }
                    PomocDugme(ikonica: "circle.lefthalf.filled", naziv: "50/50", iskoriscenaUPartiji: $pomocIskoriscena,
                               dostupno: eliminisani.isEmpty, tamno: true) { pedesetPedeset(p) }
                        .frame(width: 80)
                    Text(model.bonusPomoci > 0 ? "Dodatne pomoći su osvojene u bitkama." : "Jedna pomoć po partiji, iz dnevnog fonda.")
                        .font(.tekst(12, .semibold)).foregroundStyle(.white)
                }
            }
        }
    }

    private func pedesetPedeset(_ p: Prikaz) {
        eliminisani = Set((0..<4).filter { $0 != p.tacan }.shuffled().prefix(2))
    }

    // MARK: Rezultat

    @ViewBuilder private var rezultat: some View {
        if let ishod = bitka.ishod {
            let pobedio = bitka.napadam ? ishod.osvojeno : !ishod.osvojeno
            VStack(spacing: 14) {
                Text(naslovRezultata(ishod)).font(.naslov(32)).foregroundStyle(pobedio ? Color.white : Color.tinta).multilineTextAlignment(.center)
                if let rival = bitka.rival {
                    HStack(spacing: 10) {
                        skor("Ti", bitka.tacnih, bitka.ms, pobedio)
                        skor(bitka.rivalIme, rival.tacnih, rival.ms, !pobedio)
                    }
                    if pobedio { Label("+\(Pravila.bonusPomociPobedniku) dodatne pomoći za ovu partiju", systemImage: "gift").font(.tekst(14, .bold)).foregroundStyle(.white) }
                } else {
                    Text(pobedio ? "Tačno! Država je tvoja." : "Netačno. Gubiš jednu vojsku.").font(.tekst(15, .semibold)).foregroundStyle(pobedio ? Color.white : Color.tinta)
                }
                if ishod.plen { Label("Prestonica pala: +\(Pravila.plenPrestonice) vojski", systemImage: "crown").font(.tekst(14, .bold)).foregroundStyle(.white) }
                if ishod.proboj { Label("Proboj: +\(Pravila.probojBonus) vojske", systemImage: "bolt").font(.tekst(14, .bold)).foregroundStyle(.white) }
                Button("Nastavi") { withAnimation { model.zatvoriBitku() } }.buttonStyle(.sekundarno)
            }
            .padding(22).frame(maxWidth: .infinity)
            .pop(pobedio ? .teal : .narandzasta, radijus: 26)
            .sensoryFeedback(pobedio ? .success : .error, trigger: bitka.id)
        } else {
            VStack(spacing: 12) {
                ProgressView().tint(Color.mastilo)
                Text("\(bitka.rivalIme) odgovara…").font(.tekst(15, .semibold))
            }
            .padding(24).pop(radijus: 26)
        }
    }

    private func naslovRezultata(_ ishod: Ishod) -> String {
        if bitka.napadam { return ishod.osvojeno ? "Osvojio si \(drzava.ime)!" : "\(drzava.ime) se odbranila" }
        return ishod.osvojeno ? "\(bitka.rivalIme) je osvojio \(drzava.ime)" : "Odbranio si \(drzava.ime)!"
    }

    private func skor(_ ime: String, _ tacnih: Int, _ ms: Int, _ pobednik: Bool) -> some View {
        VStack(spacing: 2) {
            Text(ime).font(.tekst(13, .bold)).lineLimit(1)
            Text("\(tacnih)/\(bitka.prikazi.count)").font(.naslov(30)).monospacedDigit()
            Text(String(format: "%.1f s", Double(ms) / 1000)).font(.tekst(12, .semibold)).opacity(0.75)
        }
        .foregroundStyle(Color.tinta)
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(pobednik ? Color.zuta : Color.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.tinta, lineWidth: 2))
    }
}
