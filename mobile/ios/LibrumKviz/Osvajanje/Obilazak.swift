import SwiftUI

/// Obilazak na početku partije (vlasnik 04.11 uveče): korak po korak, strelica pokazuje deo ekrana
/// (igrači, krug, mapa, sat, misija, legenda, savez, pauza, izlaz), a X ga uvek gasi.
enum CiljObilaska: Hashable { case izlaz, pauza, legenda, savez, krug, igraci, misija, mapa, uputstvo }

struct CiljeviObilaska: PreferenceKey {
    static var defaultValue: [CiljObilaska: Anchor<CGRect>] = [:]
    static func reduce(value: inout [CiljObilaska: Anchor<CGRect>], nextValue: () -> [CiljObilaska: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    /// Obeležava deo ekrana na koji obilazak može da pokaže strelicom.
    func ciljObilaska(_ c: CiljObilaska) -> some View {
        anchorPreference(key: CiljeviObilaska.self, value: .bounds) { [c: $0] }
    }
}

struct KorakObilaska {
    let cilj: CiljObilaska?
    let naslov: String
    let tekst: String
    var ikonice: [(String, String)] = []

    /// Redosled koraka; korak čiji deo ekrana trenutno ne postoji prikazuje se na sredini, bez strelice.
    static let svi: [KorakObilaska] = [
        .init(cilj: nil, naslov: "Dobro došao u Osvajača", tekst: "Za minut ti pokazujem šta je gde. Uvek možeš da ugasiš vodič na X."),
        .init(cilj: .igraci, naslov: "Igrači", tekst: "Ovde su svi igrači i njihovi poeni. Dodirni igrača: vidiš njegovu vojsku i moći, šalješ mu poruku ili predlažeš savez. Kruna je kapiten, lanac je saveznik, a podignuta ruka izdajnik."),
        .init(cilj: .krug, naslov: "Krugovi", tekst: "Koji je krug i koliko ih ima. Kad krugovi isteknu, pobeđuje najviše poena, osim ako neko pre toga ispuni tajnu misiju."),
        .init(cilj: .mapa, naslov: "Mapa", tekst: "Prvo dodirni \(Pravila.pocetnihDrzava) slobodnih država na svom kontinentu. Prva je tvoja prestonica (kruna). Zatim dodiruj svoje države da im dodaš vojsku. Mapa se uvećava prstima."),
        .init(cilj: .uputstvo, naslov: "Šta sad radiš i sat", tekst: "Ovde uvek piše sledeći korak. Desno je sat poteza: poslednjih 10 sekundi je crveno, a na 5 sekundi čuješ sirenu. Isto važi za pitanja u bitki."),
        .init(cilj: nil, naslov: "Tvoj potez", tekst: "Na svom potezu dobijaš pojačanja, pa napadaš susedne države. Svaka bitka su pitanja: više tačnih i brže od rivala, i država je tvoja.",
              ikonice: [("arrow.left.arrow.right", "Marš: prebaci vojsku"), ("scope", "Pohod: najavi region"), ("flag.checkered", "Tajna misija"),
                        ("rectangle.portrait.on.rectangle.portrait", "Ratne karte"), ("lightbulb", "Savet: šta da radiš")]),
        .init(cilj: .misija, naslov: "Tajna misija", tekst: "Posle izbora država vučeš okrenutu kartu misije. Ispuni je i drži do svog sledećeg poteza: pobeđuješ. Kad rival ispuni svoju, svi vide crvenu traku."),
        .init(cilj: nil, naslov: "Ratne karte", tekst: "Dve osvojene države u jednom potezu ili tri dobijene bitke zaredom donose kartu. Karte igraš u bitki: špijun, sabotaža, drugi pokušaj."),
        .init(cilj: .legenda, naslov: "Legenda", tekst: "Ne znaš šta znači zvezdica, krug oko ostrva ili linija preko mora? Ovde je objašnjeno sve sa mape."),
        .init(cilj: .savez, naslov: "Savez", tekst: "Predloži savez jednom rivalu. Saveznici se ne napadaju, šalju pomoć i pobeđuju zajedno. Izdaja košta: bez karata i bez moći dva kruga."),
        .init(cilj: .pauza, naslov: "Pauza", tekst: "Protiv računara možeš da staneš kad hoćeš: botovi i sat čekaju."),
        .init(cilj: .izlaz, naslov: "Izlaz", tekst: "Ovde izlaziš. Partija protiv računara se čuva i nastavljaš je sa početne."),
        .init(cilj: nil, naslov: "Kreni u osvajanje!", tekst: "Vodič je dole do kraja prvog kruga i kaže ti svaki sledeći korak. Ovaj obilazak ponovo pokreneš iz legende (dugme ?)."),
    ]
}

struct ObilazakView: View {
    let korak: Int
    let okviri: [CiljObilaska: CGRect]
    let dalje: () -> Void
    let nazad: () -> Void
    let ugasi: () -> Void
    @State private var puls = false
    @Environment(\.accessibilityReduceMotion) private var manjeKretanja

    private var k: KorakObilaska { KorakObilaska.svi[korak] }
    private var poslednji: Bool { korak == KorakObilaska.svi.count - 1 }

    var body: some View {
        GeometryReader { g in
            let okvir = k.cilj.flatMap { okviri[$0] }?.insetBy(dx: -6, dy: -6)
            let dole = okvir.map { $0.midY < g.size.height * 0.5 } ?? false
            ZStack(alignment: .topLeading) {
                // Zatamnjeno sve osim dela na koji se pokazuje.
                Path { p in
                    p.addRect(CGRect(origin: .zero, size: g.size).insetBy(dx: -60, dy: -120))
                    if let okvir { p.addRoundedRect(in: okvir, cornerSize: CGSize(width: 14, height: 14)) }
                }
                .fill(Color.black.opacity(0.62), style: FillStyle(eoFill: true))
                .contentShape(Rectangle())
                .onTapGesture {}
                if let okvir {
                    RoundedRectangle(cornerRadius: 14).stroke(Color.zuta, lineWidth: 3)
                        .frame(width: okvir.width, height: okvir.height)
                        .scaleEffect(puls ? 1.04 : 1)
                        .position(x: okvir.midX, y: okvir.midY)
                        .allowsHitTesting(false)
                    // Veliki deo (mapa) ne dobija strelicu: kartica bi je pokrila, a okvir je dovoljan.
                    if okvir.height < g.size.height * 0.35 {
                    Image(systemName: dole ? "arrowshape.up.fill" : "arrowshape.down.fill")
                        .font(.system(size: 34, weight: .bold)).foregroundStyle(Color.zuta)
                        .shadow(color: .black.opacity(0.4), radius: 3)
                        .offset(y: puls ? (dole ? 6 : -6) : 0)
                        .position(x: min(max(okvir.midX, 40), g.size.width - 40), y: dole ? okvir.maxY + 26 : okvir.minY - 26)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    }
                }
                kartica
                    .frame(maxWidth: 460)
                    .padding(.horizontal, 16)
                    .frame(width: g.size.width)
                    .position(x: g.size.width / 2, y: polozajKartice(okvir, dole: dole, visina: g.size.height))
            }
        }
        .onAppear { if !manjeKretanja { withAnimation(.easeInOut(duration: 0.7).repeatForever()) { puls = true } } }
        .transition(.opacity)
        .accessibilityAddTraits(.isModal)
    }

    /// Kartica ide ispod istaknutog dela ako je on gore, iznad ako je dole, inače na sredinu.
    private func polozajKartice(_ okvir: CGRect?, dole: Bool, visina: CGFloat) -> CGFloat {
        guard let okvir else { return visina * 0.45 }
        let polaKartice: CGFloat = k.ikonice.isEmpty ? 120 : 190
        if dole { return min(okvir.maxY + 60 + polaKartice, visina - polaKartice - 20) }
        return max(okvir.minY - 60 - polaKartice, polaKartice + 60)
    }

    private var kartica: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Oznaka(tekst: "Vodič · \(korak + 1) od \(KorakObilaska.svi.count)", boja: .teal)
                    Text(k.naslov).font(.naslov(24)).foregroundStyle(Color.mastilo)
                }
                Spacer(minLength: 8)
                Button(action: ugasi) {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Color.mastilo)
                        .frame(width: 32, height: 32).background(Color.udubljeno, in: Circle())
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Ugasi vodič")
            }
            Text(k.tekst).font(.tekst(15, .semibold)).foregroundStyle(Color.mastilo).fixedSize(horizontal: false, vertical: true)
            ForEach(k.ikonice, id: \.0) { ik in
                HStack(spacing: 10) {
                    Image(systemName: ik.0).font(.system(size: 14, weight: .bold)).foregroundStyle(Color.mastilo)
                        .frame(width: 34, height: 34).background(Color.kartica, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.mastilo, lineWidth: 1.5))
                    Text(ik.1).font(.tekst(14, .semibold)).foregroundStyle(Color.mastilo)
                }
            }
            HStack(spacing: 10) {
                if korak > 0 { Button("Nazad", action: nazad).buttonStyle(.sekundarno) }
                Button(poslednji ? "Kreni" : "Dalje", action: dalje).buttonStyle(.primarno)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color.krem, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.mastilo, lineWidth: 2.5))
    }
}
