import SwiftUI

/// Vodič kroz Karijeru (vlasnik 05.11): pet kratkih strana priče koje se smenjuju sa izborima pri prvom ulasku,
/// i iste strane plus saveti u lobiju („Pravila i saveti”). Brojevi prate docs/KARIJERA-PRAVILA.md §1–6, §14.
enum KarijeraVodic {
    struct Strana: Identifiable {
        let id: Int
        let naslov: String
        let slika: String
        let pasusi: [String]
    }

    /// Strane 0–1 idu pre izbora pola, pa nemaju {muški|ženski} oblike.
    static let strane: [Strana] = [
        .init(id: 0, naslov: "Šta je Karijera", slika: "Karijera_Korporacija_1", pasusi: [
            "Karijera je igra znanja i strategije u kojoj igraš protiv pravih ljudi, ne protiv računara. Počinješ kao junior u Korporaciji, a cilj je tvoja firma: od garaže do nebodera.",
            "Svaka runda je 10 pitanja po 20 sekundi. Tačni odgovori donose novac, ugled i stručnost.",
            "Novac kupuje firmu i asistente, ugled donosi titulu (junior, senior, menadžer, direktor), a stručnost pokazuje u čemu si najjači. Sve to drugi igrači vide u tvom CV-u.",
        ]),
        .init(id: 1, naslov: "Probni rad", slika: "Karijera_Sef_korporacija_zadovoljan", pasusi: [
            "Prvo te čeka probni rad (praksa): 10 rundi u Korporaciji, može i u jednom danu, uz šefa koji komentariše svaki odgovor.",
            "Kad položiš probni rad, dobijaš mogućnost da otvoriš svoju firmu. Od 100 pitanja: 90 i više tačnih daje firmu i 2 asistenta, 75 i više firmu i jednog asistenta, 60 i više firmu bez asistenata.",
            "Ispod 60 tačnih ostaješ u Korporaciji i posle 3 dana pokušavaš ponovo. Do tada možeš da radiš i u firmama drugih igrača.",
            "6 od 10 pitanja je iz tvoje struke. Brzina se plaća: odgovor do 5 sekundi vredi ×1,5, a niz od 5 tačnih zaredom podiže vrednost svakog sledećeg.",
        ]),
        .init(id: 2, naslov: "Pomoći i asistenti", slika: "Karijera_Asistent_3", pasusi: [
            "Imaš 4 pomoći koje biraš na početku. U svakoj rundi svaku koristiš jednom.",
            "Odgovor uz pomoć donosi platu, ali vredi manje i ne donosi ugled ni stručnost. Pomoć je za nevolju, ne za svako pitanje.",
            "Asistenti su botovi koje zapošljavaš u svojoj firmi. Svaki pomaže svima u firmi na 5 pitanja dnevno, ali samo u svojoj temi. Botovi ne mogu da ti preuzmu firmu, to mogu samo pravi igrači.",
        ]),
        .init(id: 3, naslov: "Tvoja firma", slika: "Karijera_Zgrada_2_1", pasusi: [
            "Kad otvoriš firmu, ti {si vlasnik|si vlasnica}. Biraš ime, izgled zgrade, 3 ključne oblasti (tačan odgovor u njima vredi duplo) i platu zaposlenih: 50, 65 ili 80%.",
            "Tvoja firma se pojavljuje na berzi poslova. Pravi igrači, ljudi kao ti, mogu da dođu i zaposle se kod tebe. Svaka njihova runda puni tvoju kasu.",
            "Iz kase plaćaš održavanje, asistente i nadogradnju: garaža, kancelarija, sprat, poslovna zgrada, neboder. Svaki dan možeš da podigneš 10% kase za sebe.",
            "Odigraj bar jednu rundu dnevno u svojoj firmi. Dan pauze košta jednog asistenta, tri dana zatvaraju firmu.",
            "Biraš i do 3 slobodna dana u nedelji: tada ne moraš da dolaziš i niko ne može da te izazove na duel. Ko ipak igra na slobodan dan, radi prekovremeno: plata i kasa +10%. U Korporaciji su slobodne subota i nedelja.",
            "Kao {vlasnik|vlasnica} podešavaš i šefa svoje firme i mešavinu pitanja. Strožiji šef plaća zaposlenima dodatak za stres, iz tvoje kase.",
            "Talenti koje biraš na početku važe celu igru; na svakih 200 tačnih možeš da zameniš jedan.",
        ]),
        .init(id: 4, naslov: "Rivali i duel", slika: "Karijera_Zgrada_4_2", pasusi: [
            "Firma nije zauvek tvoja. Pravi igrači koji se zaposle kod tebe mogu da ti je preotmu: kad neko radi kod tebe bar 3 dana i obori rekord tvoje firme, može da te izazove na duel.",
            "Duel su 3 runde po 10 pitanja. Prvu i treću temu biraš ti, drugu izazivač. Pobeđuje više tačnih, pa brže vreme. Pobednik dobija zgradu, kasu i asistente.",
            "Odbrana je strategija: drži rekord visoko, obuči asistente u svojim temama i plati zaposlene tako da im se isplati da ostanu. Posle odbranjene firme imaš 5 dana mira.",
            "I ti možeš da napadaš: zaposli se u firmi drugog igrača ili u firmi koju vodi računar, obori njen rekord i izazovi vlasnika. Tako dolaziš do veće zgrade bez gradnje od nule.",
        ]),
    ]

    static let saveti = [
        "Struku biraj po onome što zaista znaš: 6 od 10 pitanja je iz nje, a i duel se dobija u temama.",
        "Brzina se plaća. Ako znaš, klikni odmah: do 5 sekundi odgovor vredi ×1,5.",
        "Pomoći čuvaj za teška pitanja. Odgovor sa pomoći ne donosi ugled, a ugled donosi titulu i množilac plate.",
        "Plaćeno je 10 rundi dnevno. Igraj ih tamo gde ti ključne oblasti nose ×2 i gde je plata najveća.",
        "Na berzi poslova uporedi firme: plata, ključne oblasti, asistenti i šef. Jak šef plaća dodatak za stres.",
        "Rekord firme računa jedan dan. Ako ciljaš preuzimanje, odigraj sve plaćene runde istog dana u toj firmi.",
        "Kao vlasnik biraj ključne oblasti u kojima si najjači: iste teme biraš i u duelu.",
        "Asistenti pomažu i tebi u odbrani duela. Obuka do 90% je skupa, ali čuva firmu.",
        "Izdašna plata puni kasu sporije, ali zaposleni ostaju i dižu tvoju firmu na sledeći nivo.",
        "Ne propuštaj dan u svojoj firmi. Za redovne pauze izaberi slobodne dane, a za put prijavi godišnji odmor unapred.",
        "Slobodan dan nije izgubljen dan: runda tada nosi +10% (prekovremeno), a firma je zaštićena od izazova.",
        "Ne voliš šefa? U Podešavanjima uključi Mirnog šefa: blag je i ne ometa, ali nema dodatka za stres.",
    ]

    /// Strana sa izabranim rodom ({muški|ženski}).
    static func tekst(_ s: String, zensko: Bool) -> String { Sef.oblik(s, zensko: zensko) }
}

/// Jedna strana priče pri prvom ulasku: slika na nebu Korporacije, naslov, pasusi koji se pojavljuju redom i „Dalje”.
struct VodicStranaView: View {
    let strana: KarijeraVodic.Strana
    let zensko: Bool
    let dalje: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .bottom) {
                Nebo(mesto: "korporacija")
                Image(strana.slika).resizable().scaledToFit().frame(height: 190).padding(.top, 20)
                if strana.slika.contains("Zgrada") || strana.slika.contains("Korporacija") { Ulica(mesto: "korporacija") }
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.mastilo, lineWidth: 2))
            .accessibilityHidden(true)
            Naslov(tekst: strana.naslov, velicina: 30)
            ForEach(Array(strana.pasusi.enumerated()), id: \.offset) { i, t in
                UvodPasus(tekst: KarijeraVodic.tekst(t, zensko: zensko), kasnjenje: Double(i) * 0.4)
            }
            Button("Dalje", action: dalje).buttonStyle(.primarno).padding(.top, 4)
        }
        .id(strana.id)
    }
}

/// Lobi → „Pravila i saveti”: iste strane kao u prvom ulasku i kratki saveti.
struct KarijeraPravilaView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GornjaTraka()
                Naslov(tekst: "Pravila i saveti", velicina: 30)
                ForEach(KarijeraVodic.strane) { s in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(s.naslov).font(.naslov(22))
                        ForEach(Array(s.pasusi.enumerated()), id: \.offset) { _, t in
                            Text(KarijeraVodic.tekst(t, zensko: Karijera.mojPol == "z")).font(.tekst(15)).foregroundStyle(Color.mastilo)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading).mirna()
                }
                Text("Saveti").font(.naslov(22)).padding(.top, 4)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(KarijeraVodic.saveti.enumerated()), id: \.offset) { _, t in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: "lightbulb.fill").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.narandzasta)
                                .accessibilityHidden(true)
                            Text(t).font(.tekst(15)).foregroundStyle(Color.mastilo).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading).mirna()
            }
            .padding(16)
        }
        .background(Papir())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }
}
