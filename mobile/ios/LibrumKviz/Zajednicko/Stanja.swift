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

/// Novčanik iz kita: iznos i novčić.
struct Novcanik: View {
    let iznos: Int
    var body: some View {
        HStack(spacing: 6) {
            Text(iznos.formatted()).font(.tekst(15, .bold)).monospacedDigit()
            Image(systemName: "dollarsign.circle.fill").font(.system(size: 20)).foregroundStyle(Color.narandzasta)
        }
        .foregroundStyle(Color.mastilo)
        .padding(.horizontal, 12).frame(height: 40)
        .background(Color.kartica, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.kremTamnija, lineWidth: 1.5))
        .accessibilityLabel("\(iznos) novčića")
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
