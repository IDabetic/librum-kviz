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
    var tezina = "Srednje"
    var ikonica = "questionmark"
    /// Red u tabeli quizzes za upis rezultata (quiz_results); nil = samo lokalno.
    var quizId: String? = nil

    var brojPitanja: Int { 10 }

    /// „Kako se igra”, po starom sajtu (GameSeoContent) i pravilima aplikacije.
    var pravila: [String] {
        let pomoc = "Pomoć: jedna po partiji, iz dnevnog fonda od \(Napredak.pomociDnevno) za sve igre."
        switch vrsta {
        case .igra(.osvajanje): return [
            "Igra se na pravoj mapi: ceo svet (171 država, 17 regiona) ili jedan kontinent; protiv računara, jednog rivala ili do 12 igrača.",
            "Partija na poziv: „Pozovi prijatelje” pravi sobu sa kodom (timovi po dvoje ili svako za sebe, do 12 igrača). Prijatelji ulaze kodom, linkom ili porukom iz aplikacije, a partija kreće kad domaćin pritisne „Počni”; prazna mesta preuzimaju botovi.",
            "Pre partije biraš vojsku: Legija (+1 tačan u napadu), Garda (+1 tačan u odbrani), Graditelji (+1 vojska po celom regionu), Izvidnica (više karata), Konjica (2 napada više) ili Mudraci (+5 s po pitanju).",
            "Svaka vojska ima jednu svoju moć u pitanjima bitke i dve iste za sve (Promena pitanja, +10 sekundi), svaku jednom po krugu: Legija Siguran udar (svaki odgovor je tačan, pogodak vredi dva), Garda Štit (greška se briše uz novo pitanje), Graditelji Vreme stoji, Izvidnica Pola-pola, Konjica Juriš (sledeći tačan vredi dva), Mudraci Tačan odgovor.",
            "Pre prvog kruga sam biraš 6 država na svom kontinentu (prva je prestonica) i raspoređuješ 15 vojski; svaka država ima bar jednu.",
            "Na početku poteza stižu pojačanja: polovina tvojih država (najmanje 3) plus bonus za svaki ceo region. Sam ih raspoređuješ dodirom po svojim državama (ili „Rasporedi sam”); kad istekne vreme, ostatak ide na granice.",
            "Napadaš samo susede (preko mora idu isprekidani morski putevi), iz države sa bar 2 vojske, do 5 napada po potezu.",
            "Prazna država je jedno pitanje: tačno je osvajaš, a sa 3 ili više vojske u napadu greška ne košta vojsku. Država igrača je 5 pitanja po 20 sekundi: više tačnih pobeđuje, kod istog broja brži.",
            "Vojska vredi: svaka vojska više od protivnika daje +1 tačan, najviše +2. Kad napadaš sa 4 vojske na 1, protivniku trebaju 3 tačna više.",
            "Ratne karte umesto dnevnih pomoći: Špijun, Pojačanje, Zamrzni granicu, Drugi pokušaj i Sabotaža. Dobijaš ih za pobedu nad igračem, ceo region i proboj; u ruci najviše 5.",
            "Dodirni igrača za brzu poruku ili savez. Savez traje do kraja sledećeg kruga i saveznici se ne napadaju. Botovi se bore sa svima, i međusobno.",
            "Svaka 4 kruga jedan kontinent dobija događaj na 2 kruga: Zima u Evropi, Zlatno doba Afrike, Monsun u Aziji, Zlatna groznica, Karneval ili Cunami.",
            "Teren: planine (Alpi, Himalaji, Andi, Kavkaz) daju braniocu +1 tačan, napad preko mora traži tačan više, a poraz u pustinji košta vojsku više.",
            "Linije snabdevanja: država odsečena od prestonice ne dobija pojačanja i gubi jednu vojsku po krugu.",
            "Čuda sveta, jedno po kontinentu: Piramide (+2 vojske), Kineski zid (odbrana u Aziji +1), Akropolj (karta svakog kruga), Maču Pikču (bez magle), Kip slobode (napad više), Sidnejska opera (+5 s po pitanju).",
            "Magla rata: kod dalekih država vidiš samo procenu vojske (≤2, 3–5, 6+). Svoje, saveznikove i susedne vidiš tačno.",
            "U napadu biraš temu pitanja od tri ponuđene. U bitki od 5 pitanja posle drugog odgovora možeš da se povučeš: vojska ostaje, potez je gotov. Ulog (+1 ili +2) duplira dobitak i gubitak.",
            "Marš: jednom po potezu vojska ide do svoje države udaljene do 3 koraka. Pohod: tajno najaviš region; ako ga držiš na početku sledećeg poteza, +3 vojske i karta.",
            "Diplomatija: izdaja saveznika odnosi sve karte i oznaku izdajnika, sa saveznikom menjaš karte, a slabijem susedu šalješ ultimatum (preda državu ili ga napadaš sa +1 tačnim).",
            "Izgubljena bitka protiv igrača odnosi i državu iz koje si napao. Svako treće osvajanje zaredom daje +2 vojske i kartu, pala prestonica +5.",
            "Na potezu imaš 30 sekundi, svaki dodir ih vraća na početak. Tri poteza zaredom bez napada znače ispadanje.",
            "Ceo svet: pobeđuje ko prvi ispuni tajnu misiju (30 različitih, iste ne dolaze ponovo iste nedelje), inače ko ima najviše poena posle 12, 20 ili 30 krugova (više igrača, duža partija). Sa više igrača misije traže srazmerno manje država i regiona. Kontinent: ko ga ceo osvoji.",
            "Na kraju je tabela i XP po mestu (1. +150, 2. +80, 3. +40, ostali +20, pobeda još +50). Partija protiv računara se čuva: nastavljaš je sa početne."]
        case .igra(.pro): return [
            "Na svako pitanje imaš četiri ponuđena odgovora i 20 sekundi.",
            "Tačan odgovor +10, netačan −5 i jedan život. Imaš 10 života.",
            "Više tačnih zaredom donosi kombo bonuse: 5 zaredom +10, 10 +25, 20 +60, 50 +150, 100 +400.",
            "Na svakih 50 pitanja dobijaš 5 života i dodatnu pomoć. Risk jednom u 10 pitanja: duplo dobijaš, duplo gubiš.",
            "Kad potrošiš sve živote, rezultat ide na rang listu i tvoj profil.", pomoc]
        case .igra(.book): return [
            "Isti format kao PRO kviz, sa 10 života, ali su sva pitanja iz sveta književnosti.",
            "Pitanja su iz različitih žanrova, a profil pamti u kom žanru si najjači.", pomoc]
        case .igra(.duel): return [
            "Jedan na jedan, ista pitanja u isto vreme. Brzi meč ima 5 pitanja sa nasumičnim rivalom, a privatna soba 10, 25 ili 50 pitanja uz kod koji deliš.",
            "Tačno +10, netačno ili isteklo vreme −5. Nerešeno ide na zlatno pitanje.",
            "Izazov bez čekanja: ti odigraš 10 pitanja odmah, rival ima 24 sata; ishod stiže u Sanduče.",
            "Ko napusti meč predaje ga: rival dobija +50.", pomoc + " Ovde je pomoć 50/50."]
        case .igra(.vesanje): return [
            "Pred tobom su prazna polja i kratak opis reči. Biraš slova: tačno se otkriva na svim mestima, netačno troši jedan od 6 života.",
            "Slovo +5 po pojavljivanju, promašaj −2. Cela reč donosi +20, a bez greške još +30.",
            "Pogrešna cela reč odnosi 2 života.", pomoc + " Ovde pomoć otkriva jedno slovo."]
        case .igra(.brzi): return [
            "Tajmer od 60 sekundi kreće odmah. Za svaku tvrdnju biraš tačno ili netačno, 10 sekundi po tvrdnji.",
            "Tačan odgovor +10, netačan −5. Tempo je sve.", pomoc + " Ovde pomoć dodaje 10 sekundi."]
        case .tema(fond: "dnevni", _, _): return [
            "Svakog dana u ponoć stiže novih 10 pitanja, ista za sve igrače.",
            "Na rang listu dana ulazi samo prvi pokušaj; možeš da igraš opet, ali za vežbu.",
            "Brzina se računa: ko odgovori tačno i brže, ide više.", pomoc,
        ]
        case .tema(fond: "slikari", _, _): return [
            "Na svakoj slici je jedno delo. Biraš ko ga je naslikao, od četiri ponuđena slikara.",
            "Deset slika, 20 sekundi po slici; sat ne teče dok se slika ne učita.",
            "Tačno 100 poena, plus 2 za svaku preostalu sekundu i 20 od trećeg tačnog zaredom.",
            "Slike su sa Wikimedia Commons, uz naziv dela, godinu i muzej posle odgovora.", pomoc]
        default: return [
            "Deset pitanja, 20 sekundi po pitanju, četiri ponuđena odgovora.",
            "Tačno 100 poena, plus 2 za svaku preostalu sekundu i 20 od trećeg tačnog zaredom.",
            "Na kraju vidiš pregled svih odgovora i tačna rešenja.", pomoc]
        }
    }
    /// Vreme po pitanju u kvizovima sa ponuđenim odgovorima (vlasnik 03.11: 20 s podrazumevano).
    var sekundi: Int { 20 }
    /// Ilustracija iz Assets (Igra_osvajanje…); teme po žanru je nemaju.
    var ilustracija: String? {
        let kljuc: String? = switch vrsta {
        case .igra(let i): i.rawValue
        case .tema(fond: "slikari", _, _): "slikari"
        case .tema(fond: "dnevni", _, _): "brzi"
        default: nil
        }
        return kljuc.map { "Igra_\($0)" }
    }
    var tekstBoja: Color { [0xFFD84D, 0xF4A33C, 0x6EC3F2, 0xFF5FA2].contains(boja) ? .tinta : .white }
}

enum KvizKatalog {
    static let kategorije: [(naziv: String, ikonica: String, boja: UInt32)] = [
        ("Igre", "gamecontroller", 0x6D4BC9), ("Opšte znanje", "lightbulb", 0xF4A33C),
        ("Knjige", "book", 0x12907E), ("Geografija", "globe.europe.africa", 0x6EC3F2), ("Umetnost", "paintpalette", 0xFF5FA2),
        ("Teme", "square.grid.2x2", 0xE5385C),
    ]

    /// Kategorije opšteg fonda (questions.tags, uvoz 03.11): naslov, tag u bazi, ikonica, opis.
    static let teme: [(naslov: String, tag: String, ikonica: String, opis: String)] = [
        ("Film i TV", "film i tv", "film", "Filmovi, serije, glumci i reditelji."),
        ("Muzika", "muzika", "music.note", "Pevači, bendovi, albumi i hitovi."),
        ("Sport", "sport", "sportscourt", "Fudbal, košarka, olimpijske igre i rekordi."),
        ("Geografija", "geografija", "map", "Države, prestonice, reke i planine."),
        ("Istorija", "istorija", "building.columns", "Vladari, bitke i velike godine."),
        ("Ličnosti", "ličnosti", "person.crop.square", "Poznati Srbi kroz vekove."),
        ("Jezik", "jezik", "textformat", "Reči, izrazi, poreklo i pravopis."),
        ("Nauka", "nauka", "atom", "Fizika, hemija, biologija i svemir."),
        ("Priroda", "priroda", "leaf", "Životinje, biljke i pojave."),
        // „Klasici” (Librum eBook, 3.357 pitanja) čekaju vlasnikovu doradu; pitanja su isključena u bazi.
        ("Kultura i tradicija", "kultura", "theatermasks", "Običaji, praznici, umetnost Srbije."),
        ("Religija i mitologija", "religija i mitologija", "sparkles", "Bogovi, mitovi i sveti spisi."),
        ("Hrana i piće", "hrana i piće", "fork.knife", "Kuhinje sveta i domaća jela."),
        ("Tehnika", "tehnika", "cpu", "Računari, izumi i mašine."),
    ]

    /// Žanrovi stvarnog Book fonda (book_questions.genre), bez „Razno”.
    static let zanrovi = ["Domaći", "Drama", "Fantastika", "Horor", "Istorijski", "Krimi", "Ljubavni", "Triler"]

    static func ikonica(zanra z: String) -> String {
        switch z {
        case "Klasici": "books.vertical"
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
            KvizStavka(id: "dnevni", naslov: "Dnevni izazov", opis: "Istih 10 pitanja za sve danas. Jedan pokušaj, rang lista dana.", kategorija: "Opšte znanje",
                       boja: 0xFFD84D, maskota: .lumi, vrsta: .tema(fond: "dnevni", zanr: nil, tesko: false), tezina: "Dnevno", ikonica: "calendar"),
            KvizStavka(id: "osvajanje", naslov: "Osvajač", opis: "171 država, vojske i bitke znanja protiv rivala.", kategorija: "Geografija",
                       boja: 0x12907E, maskota: .mimi, vrsta: .igra(.osvajanje), tezina: "Strategija", ikonica: "globe.europe.africa"),
            KvizStavka(id: "opste", naslov: "Opšte znanje", opis: "Deset pitanja iz svega pomalo, 20 sekundi po pitanju.", kategorija: "Opšte znanje",
                       boja: 0xF4A33C, maskota: .bloop, vrsta: .tema(fond: "opste", zanr: nil, tesko: false), ikonica: "lightbulb", quizId: opsteZnanje),
            KvizStavka(id: "duel", naslov: "Duel", opis: "Jedan na jedan, uživo, ili izazovi drugara.", kategorija: "Igre",
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
            KvizStavka(id: "slikari", naslov: "Slikari", opis: "Ko je naslikao ovo delo? 1.167 dela, od Leonarda do Pikasa.", kategorija: "Umetnost",
                       boja: 0xFF5FA2, maskota: .lumi, vrsta: .tema(fond: "slikari", zanr: nil, tesko: false), tezina: "Mešovito",
                       ikonica: "paintpalette", quizId: kulturaUmetnost),
            KvizStavka(id: "slikari-tesko", naslov: "Slikari: majstori", opis: "Samo manje poznata dela. Za one koji idu po muzejima.", kategorija: "Umetnost",
                       boja: 0x6D4BC9, maskota: .zig, vrsta: .tema(fond: "slikari", zanr: nil, tesko: true), nivo: 2, tezina: "Teško",
                       ikonica: "building.columns", quizId: kulturaUmetnost),
            KvizStavka(id: "tesko", naslov: "Nemoguća pitanja", opis: "Samo najteža pitanja iz baze. Otključava se na nivou 3.", kategorija: "Opšte znanje",
                       boja: 0xE5385C, maskota: .lumi, vrsta: .tema(fond: "opste", zanr: nil, tesko: true), nivo: 3, tezina: "Teško",
                       ikonica: "flame", quizId: opsteZnanje),
        ]
        let boje: [UInt32] = [0xFF5FA2, 0x6D4BC9, 0x6EC3F2, 0xF4A33C, 0x12907E, 0xFFD84D]
        let maskote: [Maskota] = [.mimi, .zig, .bloop, .lumi]
        for (i, t) in teme.enumerated() {
            l.append(KvizStavka(id: "tema-\(t.tag)", naslov: t.naslov, opis: t.opis, kategorija: "Teme",
                                boja: boje[(i + 2) % boje.count], maskota: maskote[i % maskote.count],
                                vrsta: .tema(fond: "opste", zanr: t.tag, tesko: false), ikonica: t.ikonica, quizId: opsteZnanje))
        }
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
        case .igra(.pro): ProKvizView(vrsta: .pro).bezSvajpaNazad()
        case .igra(.book): ProKvizView(vrsta: .book).bezSvajpaNazad()
        case .igra(.duel): DuelView()
        case .igra(.vesanje): VesanjeView()
        case .igra(.brzi): BrziKvizView().bezSvajpaNazad()
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
