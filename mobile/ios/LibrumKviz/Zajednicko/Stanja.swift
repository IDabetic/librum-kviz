import SwiftUI

// Zajednički delovi za stanja iz kita: učitavanje, prazno, greška, offline,
// maskota koja govori, podvučeni izbor, polja unosa i donji list.

/// Siva površina koja diše dok se sadržaj učitava.
struct Skelet: View {
    var visina: CGFloat = 56
    var radijus: CGFloat = 16
    @State private var svetlo = false
    var body: some View {
        RoundedRectangle(cornerRadius: radijus, style: .continuous)
            .fill(Color.skelet)
            .frame(height: visina)
            .opacity(svetlo ? 0.55 : 1)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: svetlo)
            .onAppear { svetlo = true }
            .accessibilityHidden(true)
    }
}

/// Stanje celog ekrana: maskota, naslov, objašnjenje i jedna radnja.
struct StanjeEkrana: View {
    let maskota: Maskota
    let naslov: String
    let tekst: String
    var dugme: String? = nil
    var radnja: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            MaskotaSlika(maskota: maskota, velicina: 110)
                .frame(width: 140, height: 140)
                .background(Color.kartica, in: Circle())
                .overlay(Circle().stroke(Color.mastilo, lineWidth: 2.5))
            Naslov(tekst: naslov, velicina: 26).multilineTextAlignment(.center)
            Text(tekst).font(.tekst(15)).foregroundStyle(Color.sivaTekst).multilineTextAlignment(.center)
            if let dugme, let radnja {
                Button(dugme, action: radnja).buttonStyle(.sekundarno).padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

/// Stanja jednog učitavanja.
enum Ucitano<T> {
    case ucitava
    case greska(String)
    case gotovo(T)
}

/// Traka na vrhu kad nema interneta.
struct OfflineTraka: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.slash").font(.system(size: 15, weight: .bold))
            Text("Nema interneta. Igraš iz sačuvanih pitanja.").font(.tekst(14, .semibold))
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color.tinta)
        .padding(12)
        .pop(.zuta, radijus: 14)
        .accessibilityElement(children: .combine)
    }
}

/// Maskota sa oblačićem, kao „Mimi kaže” u kitu.
struct MaskotaKaze: View {
    let maskota: Maskota
    let tekst: String
    var boja: Color = .roze

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            MaskotaSlika(maskota: maskota, velicina: 54)
            VStack(alignment: .leading, spacing: 3) {
                Oznaka(tekst: "\(maskota.rawValue) kaže", boja: boja)
                Text(tekst).font(.tekst(14, .semibold)).foregroundStyle(Color.mastilo).fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.kartica, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.mastilo, lineWidth: 2))
        }
        .accessibilityElement(children: .combine)
    }
}

/// Izbor sa podvlakom umesto kapsula (pravilo: bez pilula).
struct PodvuceniIzbor<T: Hashable>: View {
    @Binding var izbor: T
    let opcije: [(T, String)]

    var body: some View {
        HStack(spacing: 22) {
            ForEach(opcije, id: \.0) { vrednost, naziv in
                let aktivan = vrednost == izbor
                Button { izbor = vrednost } label: {
                    Text(naziv).font(.tekst(15, .bold)).foregroundStyle(aktivan ? Color.mastilo : .sivaTekst)
                        .padding(.vertical, 8)
                        .overlay(alignment: .bottom) { Rectangle().fill(aktivan ? Color.mastilo : .clear).frame(height: 3) }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(aktivan ? .isSelected : [])
            }
            Spacer(minLength: 0)
        }
    }
}

/// Polje iz kita: oznaka iznad, debela ivica u fokusu, crvena kod greške, zelena kad je u redu.
struct PoljeUnosa: View {
    enum Stanje: Equatable { case obicno, greska(String), uRedu(String) }
    let naziv: String
    @Binding var tekst: String
    var stanje: Stanje = .obicno
    var sakriveno = false
    var sadrzaj: UITextContentType? = nil
    var tastatura: UIKeyboardType = .default
    var onemoguceno = false
    @FocusState private var fokus: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(naziv).font(.tekst(13, .bold)).foregroundStyle(Color.mastilo)
            Group {
                if sakriveno { SecureField("", text: $tekst) } else { TextField("", text: $tekst) }
            }
            .textContentType(sadrzaj).keyboardType(tastatura)
            .textInputAutocapitalization(tastatura == .emailAddress || sakriveno ? .never : .sentences)
            .autocorrectionDisabled()
            .focused($fokus)
            .disabled(onemoguceno)
            .font(.tekst(16)).foregroundStyle(onemoguceno ? Color.sivaTekst : Color.mastilo)
            .padding(.horizontal, 16).frame(height: 54)
            .background(pozadina, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(ivica, lineWidth: fokus || stanje != .obicno ? 2.5 : 1.5))
            .accessibilityLabel(naziv)
            switch stanje {
            case .greska(let poruka):
                Label(poruka, systemImage: "exclamationmark.circle").font(.tekst(13, .semibold)).foregroundStyle(Color.crvena)
            case .uRedu(let poruka):
                Label(poruka, systemImage: "checkmark.circle").font(.tekst(13, .semibold)).foregroundStyle(Color.teal)
            case .obicno: EmptyView()
            }
        }
    }

    private var ivica: Color {
        switch stanje {
        case .greska: .crvena
        case .uRedu: .teal
        case .obicno: fokus ? .mastilo : .kremTamnija
        }
    }
    private var pozadina: Color {
        if onemoguceno { return .udubljeno }
        switch stanje {
        case .greska: return .crvenaSvetla
        case .uRedu: return .tealSvetla
        case .obicno: return .kartica
        }
    }
}

/// Crtice napretka kroz korake (uvod, upoznavanje).
struct CrticeKoraka: View {
    let ukupno: Int
    let trenutni: Int
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<ukupno, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i == trenutni ? Color.roze : i < trenutni ? Color.mastilo : Color.kremTamnija)
                    .frame(width: i == trenutni ? 26 : 16, height: 5)
            }
        }
        .animation(.spring(duration: 0.3), value: trenutni)
        .accessibilityLabel("Korak \(trenutni + 1) od \(ukupno)")
    }
}

/// Donji list u stilu kita (umesto sistemskog sheet-a).
struct DonjiList<Sadrzaj: View>: View {
    let zatvori: () -> Void
    @ViewBuilder let sadrzaj: Sadrzaj

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.senka.opacity(0.55).ignoresSafeArea().onTapGesture(perform: zatvori)
            VStack(spacing: 14) {
                Capsule().fill(Color.kremTamnija).frame(width: 44, height: 5).accessibilityHidden(true)
                sadrzaj
            }
            .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 28)
            .frame(maxWidth: .infinity)
            .background(Color.krem, in: UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32, style: .continuous))
            .overlay(UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32, style: .continuous).stroke(Color.mastilo, lineWidth: 2.5))
            .transition(.move(edge: .bottom))
            .accessibilityAddTraits(.isModal)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

/// Red liste podešavanja ili profila: ikonica, naziv, vrednost, strelica.
struct RedListe: View {
    let ikonica: String
    let naziv: String
    var vrednost: String? = nil
    var boja: Color = .mastilo
    var strelica = true
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: ikonica).font(.system(size: 17, weight: .semibold)).frame(width: 24).foregroundStyle(boja)
            Text(naziv).font(.tekst(15, .semibold)).foregroundStyle(boja)
            Spacer()
            if let vrednost { Text(vrednost).font(.tekst(14)).foregroundStyle(Color.sivaTekst).lineLimit(1) }
            if strelica { Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(Color.sivaTekst) }
        }
        .padding(.horizontal, 16).frame(minHeight: 54)
        .contentShape(Rectangle())
    }
}

/// Gornja traka ekrana: nazad levo, proizvoljan sadržaj desno.
struct GornjaTraka<Desno: View>: View {
    @Environment(\.dismiss) private var nazad
    var ikonica = "chevron.left"
    @ViewBuilder var desno: Desno
    var body: some View {
        HStack {
            KrugDugme(ikonica: ikonica, opis: ikonica == "xmark" ? "Zatvori" : "Nazad") { nazad() }
            Spacer()
            desno
        }
    }
}

extension GornjaTraka where Desno == EmptyView {
    init(ikonica: String = "chevron.left") { self.ikonica = ikonica; self.desno = EmptyView() }
}

/// Ravnomerna mreža sa dve kolone za statistike i bedževe.
struct Plocica: View {
    let ikonica: String
    let vrednost: String
    let naziv: String
    var boja: Color = .teal
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: ikonica).font(.system(size: 18, weight: .semibold)).foregroundStyle(boja)
            Text(vrednost).font(.naslov(22)).foregroundStyle(Color.mastilo).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
            Text(naziv).font(.tekst(12)).foregroundStyle(Color.sivaTekst).lineLimit(1)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .mirna()
        .accessibilityElement(children: .combine)
    }
}

/// Dugme pomoći: troši iz dnevnog fonda (7 za sve igre), najviše jednom po partiji.
/// Broj u uglu je koliko je pomoći ostalo danas.
struct PomocDugme: View {
    @Environment(Napredak.self) private var napredak
    /// Ključ vrste za statistiku: polaPola, nagovestaj, vreme, preskok, slovo.
    var vrsta = "polaPola"
    let ikonica: String
    let naziv: String
    @Binding var iskoriscenaUPartiji: Bool
    var dostupno = true
    var tamno = false
    let radnja: () -> Void

    var body: some View {
        let ostalo = napredak.pomociOstalo()
        let moze = !iskoriscenaUPartiji && ostalo > 0 && dostupno
        Button {
            guard moze, napredak.iskoristiPomoc(vrsta) else { return }
            iskoriscenaUPartiji = true
            withAnimation { radnja() }
        } label: {
            Image(systemName: ikonica).font(.system(size: 20, weight: .semibold)).foregroundStyle(tamno ? Color.tinta : Color.mastilo)
                .frame(maxWidth: .infinity).frame(height: 54)
                .background(tamno ? Color.white : Color.kartica, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(tamno ? Color.tinta : Color.mastilo, lineWidth: 2))
                .overlay(alignment: .topTrailing) {
                    Text("\(ostalo)").font(.tekst(11, .bold)).foregroundStyle(Color.naMastilu).frame(minWidth: 20, minHeight: 20)
                        .background(Color.mastilo, in: Circle()).offset(x: 6, y: -6)
                }
        }
        .buttonStyle(BezPrigusenja())
        .disabled(!moze)
        .opacity(moze ? 1 : 0.35)
        .accessibilityLabel(naziv)
        .accessibilityValue(iskoriscenaUPartiji ? "Iskorišćeno u ovoj partiji" : "\(ostalo) pomoći danas")
    }
}

/// Jedan red ispod pomoći: pravilo i kada stiže novi fond.
struct PomocNapomena: View {
    @Environment(Napredak.self) private var napredak
    let iskoriscenaUPartiji: Bool
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { k in
            let ostalo = napredak.pomociOstalo(sada: k.date)
            let tekst: String = if iskoriscenaUPartiji {
                "Pomoć je iskorišćena u ovoj partiji."
            } else if ostalo == 0, let novi = napredak.sledeciFondPomoci(sada: k.date) {
                "Danas nema više pomoći. Novih \(Napredak.pomociDnevno) za \(Self.za(novi, od: k.date))."
            } else {
                "Jedna pomoć po partiji · danas još \(ostalo) od \(Napredak.pomociDnevno) za sve igre"
            }
            Text(tekst).font(.tekst(12, .semibold)).foregroundStyle(Color.sivaTekst).frame(maxWidth: .infinity)
        }
    }

    static func za(_ d: Date, od: Date) -> String {
        let s = max(0, Int(d.timeIntervalSince(od)))
        return s >= 3600 ? "\(s / 3600) h \(s % 3600 / 60) min" : "\(max(1, s / 60)) min"
    }
}

/// Avatar igrača. Novi izbor su likovi sa Knjigopolisa (oznaka „s3:2:4”, fajl avatari/s3_2_4.jpg);
/// stari profili sa veba imaju životinje („animal_07.png”), pa i one moraju da se prikažu.
struct AvatarSlika: View {
    let avatar: String?
    var velicina: CGFloat = 44
    var maskota: Maskota = .mimi

    /// Svih 332 lika za izbor, redom kao na Knjigopolisu.
    static let svi: [String] = {
        guard let url = Bundle.main.url(forResource: "spisak", withExtension: "json", subdirectory: "avatari"),
              let d = try? Data(contentsOf: url), let l = try? JSONDecoder().decode([String].self, from: d) else { return [] }
        return l
    }()

    static func slika(_ avatar: String?) -> UIImage? {
        guard let a = avatar, !a.isEmpty else { return nil }
        if a.hasPrefix("animal_") { return UIImage(named: a.replacingOccurrences(of: ".png", with: "")) }
        let ime = a.replacingOccurrences(of: ":", with: "_")
        return Bundle.main.path(forResource: ime, ofType: "jpg", inDirectory: "avatari").flatMap(UIImage.init(contentsOfFile:))
    }

    var body: some View {
        Group {
            if let ui = Self.slika(avatar) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                MaskotaSlika(maskota: maskota, velicina: velicina * 0.8).frame(width: velicina, height: velicina).background(Color.roze)
            }
        }
        .frame(width: velicina, height: velicina)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.mastilo, lineWidth: velicina > 60 ? 3 : 2))
        .accessibilityHidden(true)
    }
}

/// Četiri pomoći koje ima svaka igra (vlasnik 02.11): 50/50, nagoveštaj, vreme, preskok.
/// Jedna po partiji, iz dnevnog fonda (7 za sve igre). Radnja nil = ta pomoć sada ne važi.
struct PomociTraka: View {
    @Binding var iskoriscena: Bool
    var polaPola: (() -> Void)?
    var nagovestaj: (() -> Void)?
    var vreme: (() -> Void)?
    var preskok: (() -> Void)?
    /// Vešanje nema sat: umesto vremena dobija se život.
    var vremeJeZivot = false
    /// Gde 50/50 nema smisla (tačno/netačno), ista pomoć se zove drugačije, npr. „Štit”.
    var polaPolaNaziv = "50/50"
    var tamno = false
    var napomena = true

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                dugme("polaPola", "circle.lefthalf.filled", polaPolaNaziv, polaPola)
                dugme("nagovestaj", "lightbulb", "Nagoveštaj", nagovestaj)
                dugme(vremeJeZivot ? "zivot" : "vreme", vremeJeZivot ? "heart" : "timer", vremeJeZivot ? "Još jedan život" : "Dodatno vreme", vreme)
                dugme("preskok", "forward.end", "Preskok", preskok)
            }
            if napomena { PomocNapomena(iskoriscenaUPartiji: iskoriscena) }
        }
    }

    private func dugme(_ vrsta: String, _ ikonica: String, _ naziv: String, _ radnja: (() -> Void)?) -> some View {
        PomocDugme(vrsta: vrsta, ikonica: ikonica, naziv: naziv, iskoriscenaUPartiji: $iskoriscena, dostupno: radnja != nil, tamno: tamno) { radnja?() }
    }
}
