import SwiftUI

/// Profil: prijava i registracija kad nisi prijavljen, inače nalog, odjava i brisanje.
struct ProfilView: View {
    @Environment(Sesija.self) private var sesija
    @State private var potvrdaBrisanja = false
    @State private var greska: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if sesija.prijavljen {
                    nalog
                } else {
                    PrijavaForma()
                }
                VStack(alignment: .leading, spacing: 0) {
                    veza("Politika privatnosti", "https://kviz.librum.club/politika-privatnosti")
                    Divider().overlay(Color.kremTamnija)
                    veza("Uslovi korišćenja", "https://kviz.librum.club/uslovi-koriscenja")
                    Divider().overlay(Color.kremTamnija)
                    veza("Pošalji pitanje za kviz", "https://kviz.librum.club/dodaj-pitanja")
                }
                .mirna()
                Text("Librum kviz \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                    .font(.tekst(12)).foregroundStyle(Color.sivaTekst).frame(maxWidth: .infinity)
            }
            .padding(16)
        }
        .background(Papir())
        .toolbar(.hidden, for: .navigationBar)
        .overlay {
            if potvrdaBrisanja {
                Dijalog(naslov: "Obrisati nalog?", tekst: "Nalog, profil i svi rezultati se trajno brišu. Ovo ne može da se vrati.",
                        potvrda: "Obriši", odustani: "Odustani", opasno: true) {
                    potvrdaBrisanja = false
                    Task {
                        do { try await sesija.obrisiNalog() } catch { greska = error.localizedDescription }
                    }
                } zatvori: { potvrdaBrisanja = false }
            }
        }
    }

    private var nalog: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                MaskotaSlika(maskota: .bloop, velicina: 70)
                    .frame(width: 84, height: 84).background(Color.teal, in: Circle())
                    .overlay(Circle().stroke(Color.mastilo, lineWidth: 2.5))
                VStack(alignment: .leading, spacing: 4) {
                    Text(sesija.nadimak ?? "Igrač").font(.naslov(28))
                    Text(sesija.email ?? "").font(.tekst(14)).foregroundStyle(Color.sivaTekst)
                }
            }
            if let greska { Text(greska).font(.tekst(14, .semibold)).foregroundStyle(Color.crvena) }
            Button("Odjavi se") { Task { await sesija.odjava() } }.buttonStyle(.sekundarno)
            Button { potvrdaBrisanja = true } label: {
                Text("Obriši nalog").font(.tekst(15, .bold)).foregroundStyle(Color.crvena)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
        }
        .padding(20).pop()
    }

    private func veza(_ naziv: String, _ adresa: String) -> some View {
        Link(destination: URL(string: adresa)!) {
            HStack {
                Text(naziv).font(.tekst(15, .semibold)).foregroundStyle(Color.mastilo)
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 13, weight: .bold)).foregroundStyle(Color.sivaTekst)
            }
            .padding(16)
        }
    }
}

/// Prijava i registracija u jednoj kartici, sa podvučenim izborom.
struct PrijavaForma: View {
    @Environment(Sesija.self) private var sesija
    @State private var registracija = false
    @State private var email = ""
    @State private var lozinka = ""
    @State private var ime = ""
    @State private var prezime = ""
    @State private var nadimak = ""
    @State private var radi = false
    @State private var greska: String?
    @State private var poslato = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom) {
                Text(registracija ? "Napravi nalog" : "Prijava").font(.naslov(34))
                Spacer()
                MaskotaSlika(maskota: .zig, velicina: 70)
            }
            Text("Nalog služi da rezultati odu na rang listu. Isti nalog važi i na kviz.librum.club.")
                .font(.tekst(14)).foregroundStyle(Color.sivaTekst)
            HStack(spacing: 22) {
                izbor("Prijava", !registracija) { registracija = false }
                izbor("Registracija", registracija) { registracija = true }
            }
            if poslato {
                Text("Poslali smo ti email. Potvrdi adresu preko linka, pa se prijavi.")
                    .font(.tekst(15, .semibold)).padding(14).pop(.tealSvetla, radijus: 16)
            }
            if registracija {
                polje("Ime", $ime, .givenName)
                polje("Prezime", $prezime, .familyName)
                polje("Nadimak", $nadimak, .nickname)
            }
            polje("Email", $email, .emailAddress, tastatura: .emailAddress)
            SecureField("Lozinka", text: $lozinka).textContentType(registracija ? .newPassword : .password)
                .font(.tekst(16)).padding(16)
                .background(.white, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.kremTamnija, lineWidth: 1.5))
            if let greska { Text(greska).font(.tekst(14, .semibold)).foregroundStyle(Color.crvena) }
            Button {
                Task { await posalji() }
            } label: {
                if radi { ProgressView().tint(.white) } else { Text(registracija ? "Napravi nalog" : "Prijavi se") }
            }
            .buttonStyle(.primarno)
            .disabled(radi)
        }
        .padding(20)
        .pop()
    }

    private func izbor(_ naziv: String, _ aktivan: Bool, radnja: @escaping () -> Void) -> some View {
        Button(action: { greska = nil; radnja() }) {
            Text(naziv).font(.tekst(15, .bold)).foregroundStyle(aktivan ? Color.mastilo : .sivaTekst)
                .padding(.vertical, 6)
                .overlay(alignment: .bottom) { Rectangle().fill(aktivan ? Color.mastilo : .clear).frame(height: 3) }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(aktivan ? .isSelected : [])
    }

    private func polje(_ naziv: String, _ vrednost: Binding<String>, _ sadrzaj: UITextContentType, tastatura: UIKeyboardType = .default) -> some View {
        TextField(naziv, text: vrednost)
            .textContentType(sadrzaj).keyboardType(tastatura)
            .textInputAutocapitalization(tastatura == .emailAddress ? .never : .words)
            .autocorrectionDisabled()
            .font(.tekst(16)).padding(16)
            .background(.white, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.kremTamnija, lineWidth: 1.5))
    }

    private func posalji() async {
        greska = nil
        guard email.contains("@"), email.contains(".") else { greska = "Upiši ispravan email."; return }
        guard lozinka.count >= 6 else { greska = "Lozinka mora imati najmanje 6 karaktera."; return }
        if registracija && (ime.isEmpty || nadimak.isEmpty) { greska = "Upiši ime i nadimak."; return }
        radi = true
        defer { radi = false }
        do {
            if registracija {
                try await sesija.registracija(email: email, lozinka: lozinka, ime: ime, prezime: prezime, nadimak: nadimak)
                poslato = true
                registracija = false
            } else {
                try await sesija.prijava(email: email, lozinka: lozinka)
            }
        } catch {
            greska = error.localizedDescription
        }
    }
}
