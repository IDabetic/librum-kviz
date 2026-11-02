import SwiftUI

/// Jedan kviz u katalogu: ili igra sa svojim pravilima, ili kviz po temi (tok iz kita).
struct KvizStavka: Identifiable, Hashable {
    enum Igra: String { case osvajanje, pro, book, duel, vesanje, brzi }
    enum Vrsta: Hashable { case igra(Igra), tema(fond: String, zanr: String?, tesko: Bool) }

    let id: String
    let naslov: String
    let opis: String
    let kategorija: String
    let boja: UInt32
    let maskota: Maskota
    let vrsta: Vrsta
    var nivo = 1
    var ulaz = 0
    var tezina = "Srednje"
    var ikonica = "questionmark"
    /// Red u tabeli quizzes za upis rezultata (quiz_results); nil = samo lokalno.
    var quizId: String? = nil

    var brojPitanja: Int { 10 }
    var sekundi: Int { 15 }
    var tekstBoja: Color { [0xFFD84D, 0xF4A33C, 0x6EC3F2, 0xFF5FA2].contains(boja) ? .tinta : .white }
}

enum KvizKatalog {
    static let kategorije: [(naziv: String, ikonica: String, boja: UInt32)] = [
        ("Igre", "gamecontroller", 0x6D4BC9), ("Opšte znanje", "lightbulb", 0xF4A33C),
        ("Knjige", "book", 0x12907E), ("Geografija", "globe.europe.africa", 0x6EC3F2), ("Umetnost", "paintpalette", 0xFF5FA2),
    ]

    /// Žanrovi stvarnog Book fonda (book_questions.genre), bez „Razno”.
    static let zanrovi = ["Domaći", "Drama", "Fantastika", "Horor", "Istorijski", "Krimi", "Ljubavni", "Triler"]

    static func ikonica(zanra z: String) -> String {
        switch z {
        case "Domaći": "house"
        case "Drama": "theatermasks"
        case "Fantastika": "wand.and.stars"
        case "Horor": "moon.stars"
        case "Istorijski": "building.columns"
        case "Krimi": "magnifyingglass"
        case "Ljubavni": "heart"
        case "Triler": "bolt.heart"
        default: "book"
        }
    }

    static let knjizevnost = "e4b739dc-67f6-4b2c-bf9d-def4e18b0d45"
    static let opsteZnanje = "3cc90acb-9803-429d-9163-7c2245d9e4f7"
    static let kulturaUmetnost = "a09d3d69-e529-4788-95ae-5d181123c347"

    static let sve: [KvizStavka] = {
        var l: [KvizStavka] = [
            KvizStavka(id: "osvajanje", naslov: "Osvajanje sveta", opis: "171 država, vojske i bitke znanja protiv dva rivala.", kategorija: "Geografija",
                       boja: 0x12907E, maskota: .mimi, vrsta: .igra(.osvajanje), tezina: "Strategija", ikonica: "globe.europe.africa"),
            KvizStavka(id: "opste", naslov: "Opšte znanje", opis: "Deset pitanja iz svega pomalo, 15 sekundi po pitanju.", kategorija: "Opšte znanje",
                       boja: 0xF4A33C, maskota: .bloop, vrsta: .tema(fond: "opste", zanr: nil, tesko: false), ikonica: "lightbulb", quizId: opsteZnanje),
            KvizStavka(id: "duel", naslov: "Duel", opis: "Jedan na jedan, uživo, sa ulogom u novčićima.", kategorija: "Igre",
                       boja: 0x151515, maskota: .zig, vrsta: .igra(.duel), tezina: "Uživo", ikonica: "person.2"),
            KvizStavka(id: "pro", naslov: "PRO kviz", opis: "Deset života, kombo bonusi i nedeljna rang lista.", kategorija: "Igre",
                       boja: 0x6D4BC9, maskota: .lumi, vrsta: .igra(.pro), tezina: "Preživljavanje", ikonica: "crown"),
            KvizStavka(id: "knjige", naslov: "Knjige", opis: "Pisci, dela i likovi iz svih žanrova.", kategorija: "Knjige",
                       boja: 0x12907E, maskota: .zig, vrsta: .tema(fond: "book", zanr: nil, tesko: false), ikonica: "book", quizId: knjizevnost),
            KvizStavka(id: "book", naslov: "Book kviz", opis: "Preživljavanje sa knjiškim pitanjima.", kategorija: "Knjige",
                       boja: 0xF4A33C, maskota: .zig, vrsta: .igra(.book), tezina: "Preživljavanje", ikonica: "books.vertical"),
            KvizStavka(id: "brzi", naslov: "Brzi kviz", opis: "Tačno ili netačno, 60 sekundi.", kategorija: "Igre",
                       boja: 0xFFD84D, maskota: .zig, vrsta: .igra(.brzi), tezina: "Brzina", ikonica: "bolt"),
            KvizStavka(id: "vesanje", naslov: "Vešanje", opis: "Pogodi reč slovo po slovo.", kategorija: "Igre",
                       boja: 0x6EC3F2, maskota: .lumi, vrsta: .igra(.vesanje), tezina: "Reči", ikonica: "textformat.abc"),
            KvizStavka(id: "slikari", naslov: "Slikari", opis: "Ko je naslikao ovo delo? 1.177 slika od Leonarda do Pikasa.", kategorija: "Umetnost",
                       boja: 0xFF5FA2, maskota: .lumi, vrsta: .tema(fond: "slikari", zanr: nil, tesko: false), tezina: "Mešovito",
                       ikonica: "paintpalette", quizId: kulturaUmetnost),
            KvizStavka(id: "slikari-tesko", naslov: "Slikari: majstori", opis: "Samo manje poznata dela. Za one koji idu po muzejima.", kategorija: "Umetnost",
                       boja: 0x6D4BC9, maskota: .zig, vrsta: .tema(fond: "slikari", zanr: nil, tesko: true), nivo: 2, tezina: "Teško",
                       ikonica: "building.columns", quizId: kulturaUmetnost),
            KvizStavka(id: "tesko", naslov: "Nemoguća pitanja", opis: "Samo najteža pitanja iz baze. Ulaz 50 novčića, novčići ×3.", kategorija: "Opšte znanje",
                       boja: 0xE5385C, maskota: .lumi, vrsta: .tema(fond: "opste", zanr: nil, tesko: true), nivo: 3, ulaz: 50, tezina: "Teško",
                       ikonica: "flame", quizId: opsteZnanje),
        ]
        let boje: [UInt32] = [0xFF5FA2, 0x6D4BC9, 0x6EC3F2, 0xF4A33C, 0x12907E, 0xFFD84D]
        let maskote: [Maskota] = [.mimi, .zig, .bloop, .lumi]
        for (i, z) in zanrovi.enumerated() {
            l.append(KvizStavka(id: "zanr-\(z)", naslov: z, opis: "Deset pitanja o knjigama žanra \(z.lowercased()).", kategorija: "Knjige",
                                boja: boje[i % boje.count], maskota: maskote[i % maskote.count],
                                vrsta: .tema(fond: "book", zanr: z, tesko: false), ikonica: ikonica(zanra: z), quizId: knjizevnost))
        }
        return l
    }()

    static func stavka(_ id: String) -> KvizStavka? { sve.first { $0.id == id } }
}

/// Odredište stavke: igre idu na svoje ekrane, teme na detalje kviza iz kita.
struct KvizOdrediste: View {
    let stavka: KvizStavka
    var body: some View {
        switch stavka.vrsta {
        case .igra(.osvajanje): OsvajanjeUvodView()
        case .igra(.pro): ProKvizView(vrsta: .pro)
        case .igra(.book): ProKvizView(vrsta: .book)
        case .igra(.duel): DuelView()
        case .igra(.vesanje): VesanjeView()
        case .igra(.brzi): BrziKvizView()
        case .tema: KvizDetaljiView(stavka: stavka)
        }
    }
}

/// Kartica kviza u spisku (kategorija, pretraga).
struct KvizRed: View {
    @Environment(Napredak.self) private var napredak
    let stavka: KvizStavka
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: stavka.ikonica).font(.system(size: 20, weight: .semibold)).foregroundStyle(stavka.tekstBoja)
                .frame(width: 52, height: 52).background(Color(hex: stavka.boja), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.mastilo, lineWidth: 2))
            VStack(alignment: .leading, spacing: 3) {
                Text(stavka.naslov).font(.tekst(16, .bold)).foregroundStyle(Color.mastilo)
                Text(podnaslov).font(.tekst(13)).foregroundStyle(Color.sivaTekst).lineLimit(1)
            }
            Spacer()
            if napredak.nivo < stavka.nivo {
                Image(systemName: "lock.fill").foregroundStyle(Color.sivaTekst).accessibilityLabel("Zaključano")
            } else {
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(Color.sivaTekst)
            }
        }
        .padding(12)
        .pop(radijus: 20)
        .accessibilityElement(children: .combine)
    }

    private var podnaslov: String {
        if case .tema = stavka.vrsta {
            let naj = napredak.s.najbolje[stavka.id].map { " · najbolje \($0)/10" } ?? " · neodigrano"
            return "\(stavka.brojPitanja) pitanja · \(stavka.tezina)\(naj)"
        }
        return "\(stavka.tezina) · \(stavka.kategorija)"
    }
}
