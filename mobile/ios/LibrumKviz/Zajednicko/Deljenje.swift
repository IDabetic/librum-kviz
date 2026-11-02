import SwiftUI

/// Kartica rezultata za Instagram story (9:16) ili objavu (4:5), crta se u sliku i deli.
struct KarticaRezultata: View {
    enum Format { case story, objava }
    let format: Format
    let igra: String
    let naslov: String
    let veliko: String
    let detalji: [String]
    let ilustracija: String?
    let ime: String?
    let avatar: String?
    var boja: Color = .zuta

    var body: some View {
        let story = format == .story
        VStack(spacing: story ? 60 : 36) {
            HStack(spacing: 18) {
                Image(systemName: "questionmark.square.fill").font(.system(size: 54, weight: .black)).foregroundStyle(Color(hex: 0xFF5FA2))
                Text("librum kviz").font(.naslov(54)).foregroundStyle(Color.tinta)
                Spacer()
            }
            Spacer(minLength: 0)
            VStack(spacing: 28) {
                if let ilustracija { Image(ilustracija).resizable().scaledToFit().frame(height: story ? 300 : 220) }
                Text(igra.uppercased()).font(.tekst(40, .bold)).tracking(6).foregroundStyle(Color.tinta.opacity(0.7))
                Text(naslov).font(.naslov(story ? 92 : 78)).foregroundStyle(Color.tinta).multilineTextAlignment(.center).minimumScaleFactor(0.6)
                Text(veliko).font(.naslov(story ? 210 : 170)).foregroundStyle(Color.tinta).monospacedDigit().minimumScaleFactor(0.5).lineLimit(1)
                HStack(spacing: 18) {
                    ForEach(detalji, id: \.self) { d in
                        Text(d).font(.tekst(34, .bold)).foregroundStyle(Color.tinta)
                            .padding(.horizontal, 26).padding(.vertical, 16)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 22))
                            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.tinta, lineWidth: 5))
                    }
                }
            }
            .padding(story ? 64 : 48)
            .frame(maxWidth: .infinity)
            .background(boja, in: RoundedRectangle(cornerRadius: 64))
            .overlay(RoundedRectangle(cornerRadius: 64).stroke(Color.tinta, lineWidth: 8))
            .background(RoundedRectangle(cornerRadius: 64).fill(Color.tinta).offset(y: 16))
            Spacer(minLength: 0)
            HStack(spacing: 20) {
                if ime != nil { AvatarSlika(avatar: avatar, velicina: 90).environment(\.colorScheme, .light) }
                Text(ime.map { "\($0) te izaziva. Možeš li bolje?" } ?? "Možeš li bolje?").font(.tekst(40, .bold)).foregroundStyle(Color.tinta)
                Spacer()
            }
            Text("kviz.librum.club").font(.tekst(36, .bold)).foregroundStyle(Color.tinta.opacity(0.6))
        }
        .padding(story ? 80 : 64)
        .frame(width: 1080, height: story ? 1920 : 1350)
        .background(Color(hex: 0xF3F0E6))
        .environment(\.colorScheme, .light)
    }
}

/// Dugme „Podeli”: pravi sliku za story ili objavu i otvara sistemsko deljenje (Instagram, poruke…).
struct PodeliRezultat: View {
    let igra: String
    let naslov: String
    let veliko: String
    let detalji: [String]
    var ilustracija: String? = nil
    var boja: Color = .zuta
    @Environment(Sesija.self) private var sesija
    @Environment(Napredak.self) private var napredak
    @State private var izbor = false

    var body: some View {
        Button { izbor = true } label: {
            Image(systemName: "square.and.arrow.up").font(.system(size: 17, weight: .bold)).foregroundStyle(Color.mastilo)
                .frame(width: 44, height: 44).background(Color.kartica, in: Circle()).overlay(Circle().stroke(Color.kremTamnija, lineWidth: 1.5))
        }
        .accessibilityLabel("Podeli rezultat")
        .sheet(isPresented: $izbor) {
            VStack(spacing: 16) {
                Text("Podeli rezultat").font(.naslov(26))
                HStack(spacing: 14) {
                    ForEach([KarticaRezultata.Format.story, .objava], id: \.self) { f in
                        if let slika = slika(f) {
                            ShareLink(item: Image(uiImage: slika), preview: SharePreview("Librum kviz", image: Image(uiImage: slika))) {
                                VStack(spacing: 8) {
                                    Image(uiImage: slika).resizable().scaledToFit().frame(height: 220)
                                        .clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.mastilo, lineWidth: 2))
                                    Text(f == .story ? "Story" : "Objava").font(.tekst(15, .bold)).foregroundStyle(Color.mastilo)
                                }
                            }
                        }
                    }
                }
                Text("Izaberi format, pa Instagram ili gde god želiš.").font(.tekst(13)).foregroundStyle(Color.sivaTekst)
            }
            .padding(20)
            .presentationDetents([.medium])
        }
    }

    @MainActor private func slika(_ f: KarticaRezultata.Format) -> UIImage? {
        let r = ImageRenderer(content: KarticaRezultata(format: f, igra: igra, naslov: naslov, veliko: veliko, detalji: detalji, ilustracija: ilustracija,
                                                        ime: sesija.nadimak, avatar: sesija.avatar ?? napredak.s.avatar, boja: boja))
        r.scale = 1
        return r.uiImage
    }
}

extension KarticaRezultata.Format: Hashable {}
