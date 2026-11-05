import SwiftUI

/// Jačine šefa, smeh i ometanja (vlasnik 05.11, docs/KARIJERA-PRAVILA.md §14).
/// Srednje = banke u Sef.swift. Jako je oštro, ali bez psovki i ličnih uvreda: kritikuje se posao, ne čovek.
extension Sef {
    /// Šef se smeje i podbada posle tačnog (smeh uključen u firmi); duge rečenice, vlasnik 05.11.
    static let smehTacno = [
        "Hahaha! {Pogodio|Pogodila} si? Idem da kažem spratu!",
        "Hahaha! Tačno? Ti? Ovo ide u dnevnik firme.",
        "Ohoho! Pogodiš ti nekad. Jednom u kvartalu.",
        "Hahaha! Kladim se da si {kliknuo|kliknula} zažmuren.",
        "Hehe. Uprava će misliti da sam te ja [naučio|naučila].",
        "Hahaha! Bravo! Sad ovako i kad te ne gledam.",
        "Aha! Ima nečeg u toj glavi. Već sam [sumnjao|sumnjala].",
        "Hahaha, tačno! Ovo ide na oglasnu tablu.",
        "Opa! Častim kafom. Iz automata, nismo banka.",
        "Hahaha! Vidi {ti njega|ti nju}! Skoro da me ubediš.",
        "Mhm, tačno. Ne smeškaj se, i moj pas bi pogodio.",
        "Hahaha! Tačno i brzo? Ko te je zamenio?",
        "Ha! Znaš! A ostala pitanja si {promašio|promašila}?",
        "Hahaha! Tačno! Pozovi mamu, pohvali se.",
        "Ooo! Tačno! Ovo pričam na kolegijumu.",
        "Hahaha, dobro! Sledeće je teže. Već se znojiš.",
        "Uuu, tačno! Prvo je proradila klima, sad i ti.",
        "Hehe, tačno. Kadrovska te ne dira do petka.",
        "Hahaha! A gde si {bio|bila} prošlih šest meseci?",
        "Tako! Vidiš da možeš kad plata visi o koncu.",
    ]

    /// Šef se smeje i grdi posle netačnog ili isteklog vremena.
    static let smehNetacno = [
        "Hahahaha! Ovo puštam na novogodišnjoj žurci!",
        "Hahaha... ne. Ozbiljno? Umreću od smeha.",
        "Ccc, hahaha! Ni praktikant prvog dana ovako.",
        "Hahaha! Čitam ovo naglas na sastanku.",
        "Pfff, hahaha! Ovo zna i čistačica. Utorkom.",
        "Hahaha! Ne mogu da dišem. Sklonite {ga|je}!",
        "Joj, hahaha! Ti si na naslovnoj „Grešaka godine”.",
        "Hahaha, ups! Tačan je bio predaleko od kafe?",
        "Hahaha! Aplauz! {Izmislio|Izmislila} si novu nauku.",
        "Ajoj, hahaha! Ovo pričam [ženi|mužu] za večerom.",
        "Hahaha! Ozbiljno? Reci da se šališ, molim te.",
        "Hmmm... hahaha! Idi umij se i probudi se.",
        "Hahaha! Za ovo ti oduzimam karticu za ulaz.",
        "Hahaha! Ti i tačan odgovor? Nikad zajedno.",
        "Hahaha! Ijuu! Od ovoga mi se kafa ohladila.",
        "Hahaha! Zovem računovodstvo da vide šta plaćamo.",
        "Hahaha! Uprava će te poslati u podrum, kod arhive.",
        "Hahaha, uf! Ostavi, ne pogađaj više, sramota.",
        "Hahaha! Lepo što se trudiš. Ružno što ne pomaže.",
        "Hahahaha! Hvala, upravo si mi {ulepšao|ulepšala} dan.",
    ]

    static let blagoTacno = [
        "Lepo, svaka čast.",
        "Tačno. Dobro ti ide.",
        "Odlično, samo tako nastavi.",
        "Bravo, to je to.",
        "Vidi se da znaš posao.",
        "Tačno. Hvala ti.",
        "Super, lepo razmišljaš.",
        "Tako je. Dobar posao.",
        "Ovo mi se dopada.",
        "Bravo, pravi potez.",
        "Tačno! Lep dan za firmu.",
        "Sjajno, ide ti od ruke.",
        "Tačno. Polako, ali sigurno.",
        "Da, upravo tako.",
        "Dobro je. [Ponosan|Ponosna] sam na tim.",
        "Tačno! Ovo zaslužuje kafu.",
        "Lepo uočeno.",
        "Bravo, i to brzo.",
        "Tako se radi.",
        "Tačno, baš lepo.",
        "Vidiš da ide.",
        "Odlično. Tim je jači s tobom.",
        "Tačno! Zabeleženo.",
        "Svaka čast na znanju.",
        "Dobar odgovor, mirno i tačno.",
        "Tačno. Tako i treba.",
        "Lepo. Nastavi istim tempom.",
        "Tačno! Vredelo je čekati.",
        "Bravo, {siguran|sigurna} si u sebe.",
        "Dobar posao, kolega.",
        "Tačno. Učiš brzo.",
        "Ovo je bilo lepo.",
        "Bravo! Klijent je zadovoljan.",
        "Tačno, i bez muke.",
        "Dobro je, sve po planu.",
        "Tačno! Sviđa mi se ovaj tempo.",
        "Lepo, ovo ide u dobar izveštaj.",
        "Super, baš tako.",
        "Tačno. Drago mi je.",
        "Bravo, lepo napredujemo.",
    ]

    static let blagoNetacno = [
        "Nije tačno, ali ništa strašno.",
        "Promašaj. Sledeće će biti bolje.",
        "Nije to. Probaj opet sledeće.",
        "Netačno, ali bilo je blizu.",
        "Ne brini, dešava se.",
        "Nije to, ali dobro razmišljaš.",
        "Hm, ne. Idemo dalje.",
        "Netačno. Biće prilike.",
        "Ovo je bilo teško, priznajem.",
        "Nije, ali ne odustaj.",
        "Mala greška, veliki tim.",
        "Netačno. Ništa, učimo.",
        "Ne ovaj put.",
        "Nije to. Udahni pa sledeće.",
        "Greška, ali bez stresa.",
        "Nije tačno. I meni se to desi.",
        "Netačno, ali hrabro.",
        "Skoro! Sledeće je tvoje.",
        "Nije to, ali vidim trud.",
        "Ne, ali dobro je što si {probao|probala}.",
        "Netačno. Važno je da nastaviš.",
        "Promašeno, ništa za brigu.",
        "Nije, ali ide se dalje.",
        "Ovo se uči. Sad znaš.",
        "Netačno. Polako, imamo vremena.",
        "Ne baš, ali ok.",
        "Nije to. Kafa pa nastavljamo?",
        "Greška se računa kao lekcija.",
        "Netačno, ali sigurno će sledeće.",
        "Hm, nije. Ne sekiraj se.",
        "Ovo i nije bilo lako.",
        "Nije, ali rundu možeš da izvučeš.",
        "Netačno. Sve u redu.",
        "Ne ovo, ali blizu si {bio|bila}.",
        "Nije to. Nema veze.",
        "Promašaj, ali smireno dalje.",
        "Netačno. Sutra ćeš ovo znati.",
        "Ne, ali dobar pokušaj.",
        "Nije to, idemo na sledeće.",
        "Netačno. Verujem u tebe.",
    ]

    static let jakoTacno = [
        "Tačno. Konačno! Ceo dan čekam.",
        "Tačno. Neću da slavim, statistika je protiv tebe.",
        "Gle, radi! Zovite upravu, ovo se retko viđa.",
        "Tačno. Ne znam ko ti je šapnuo, ali hvala mu.",
        "Dobro. Jednom i zec ulovi lovca.",
        "Tačno. I pokvaren sat je tačan dvaput dnevno.",
        "Bravo. Ovo uokvirujem, neće se ponoviti.",
        "Tačno. Pre ovoga nisam [verovao|verovala] da je moguće.",
        "Hm. Sumnjivo dobro. Proveriću.",
        "Tačno. Sad ne stani, jedna lasta ne čini proleće.",
        "Eto, kad se hoće! A hoće se retko.",
        "Tačno. Ovo ide u izveštaj kao incident.",
        "Konačno nešto za šta te plaćam.",
        "Tačno. Molim te, ponovi ovo još devet puta.",
        "Ovo je bilo dobro. Ne navikavaj me.",
        "Tačno! Šta si {pio|pila} jutros? Hoću i ja.",
        "Tačno. Moram da sednem. Mesecima čekam ovo.",
        "Bravo. Rok je bio juče, ali bravo.",
        "Tačno. Pošteno, nisam se [nadao|nadala].",
        "Pazi ti! Ima nade za ovu firmu.",
        "Tačno. Neka se zna da sam [bio prisutan|bila prisutna].",
        "Dobro je. Zapiši datum, sledeće tek za Novu godinu.",
        "Tačno. Ovo slikam za oglasnu tablu.",
        "Ne verujem. Tačno je. Ne verujem.",
        "Tačno. Neka ti bude, ali ne olabavi.",
        "Vidi, vidi. Ko bi rekao. U firmi sigurno niko.",
        "Tačno. Ovo je minimum, ali dobar minimum.",
        "Tačno. Sad i ostale tako, bez izgovora.",
        "Bravo. Uprava će misliti da sam ja [kriv|kriva].",
        "Tačno. Zadržavam aplauz za kraj runde.",
        "Dobro. Ali brže, ovo nije muzej.",
        "Tačno. Sigurno sreća. Dokaži suprotno.",
        "Tačno! Ovo bih i ja [znao|znala], ali dobro.",
        "Hm, tačno. Ne smej se, gledam te.",
        "Konačno! Već sam [pisao|pisala] oglas za tvoje mesto.",
        "Tačno. Ovo mi je popravilo kvartal.",
        "Dobro. Nemoj da mi ovo bude jedino danas.",
        "Tačno. Kafa je i dalje iz automata.",
        "Bravo. Polako se vraćaš na platni spisak.",
        "Tačno. Zapisujem datum i sat.",
    ]

    static let jakoNetacno = [
        "Netačno! Ovo je znao i portir.",
        "Pogrešno. Kao i jučerašnji izveštaj.",
        "Ne! Gde ti je pažnja, na odmoru?",
        "Netačno. Zbog ovakvih odgovora postoje sastanci.",
        "Pogrešno. Klijent je upravo otkazao ugovor.",
        "Ne, ne i ne! Pročitaj pitanje do kraja.",
        "Netačno. Ovo ide u godišnju ocenu.",
        "Promašaj! Ovo nije lutrija, ovo je posao.",
        "Pogrešno. Uprava gleda, da znaš.",
        "Netačno. I kafemat bi pogodio.",
        "Ne! Zašto uvek biraš onaj pogrešan?",
        "Pogrešno. Sad mi objasni kako.",
        "Netačno. Ovo me košta živaca i budžeta.",
        "Ne! Jesi li {čitao|čitala} uputstvo? Ne izgleda.",
        "Pogrešno. Ovako se gube klijenti.",
        "Netačno. Javi mi kad se probudiš.",
        "Ne. Sledeći put pogodi bar slučajno.",
        "Pogrešno! Zašto mi to radiš u ponedeljak?",
        "Netačno. Ovo nećemo pominjati na sastanku.",
        "Ne! Ovo je bilo na prvoj strani priručnika.",
        "Pogrešno. Dodajem ti obuku. Subotom.",
        "Netačno. Moj prethodni asistent je ovo znao.",
        "Ne! Od četiri, uzmeš onaj koji bi i dete preskočilo?",
        "Pogrešno. Kvartal nam se ruši pred očima.",
        "Netačno. Probni rad je i dalje opcija.",
        "Ne. Sad shvatam zašto kasnimo sa rokovima.",
        "Pogrešno. Ovo je bio lak, da znaš.",
        "Netačno! Ko te je zaposlio? A, ja.",
        "Ne. Brže razmišljaj, a ne brže klikći.",
        "Pogrešno. Uzimam ti olovku na sat vremena.",
        "Netačno. Ovaj odgovor ne bih ni [predao|predala].",
        "Ne! Pa ovo smo prošli prošle nedelje.",
        "Pogrešno. Investitori su upravo uzdahnuli.",
        "Netačno. Prekovremeno te ne spašava od ovoga.",
        "Ne. Ovo mi zvuči kao nagađanje.",
        "Pogrešno. I to sa puno samopouzdanja.",
        "Netačno! Hoću bolji rezultat do kraja runde.",
        "Ne. Ovo je ispod nivoa ove firme.",
        "Pogrešno. Tvoja povišica upravo odlazi.",
        "Netačno. Zapiši ovo i nauči do sutra.",
        "Netačno! Za ovo je vanredni sastanak u šest ujutru.",
        "Pogrešno! Da se smejem ili da tražim novog? Oba.",
        "Ne! Za ovo bi ti trebalo da platiš firmi.",
        "Da je neznanje posao, {bio bi direktor|bila bi direktorka}.",
        "Pogrešno! Pišem upravi „Hitno”. I nije pohvala.",
        "Ne! Napiši tačan odgovor sto puta. Ozbiljno.",
        "Netačno! Svaki promašaj je kafa. {Popio|Popila} si magacin.",
        "[Mislio|Mislila] sam da je dno. A ti si {kopao|kopala}.",
        "Ne! Objasni mi kako si {došao|došla} do ovoga. Čekam.",
        "Ovo objašnjavaš upravi. Obuci se lepo, biće dugo.",
        "Pogrešno! Od danas sediš pored fotokopir aparata.",
        "Ne! Ja gradim firmu, a ti je rušiš jednim klikom.",
        "Netačno! Produktivnost ti je ravna linija.",
        "Pogrešno! Ovo ide u priručnik „Kako ne treba”.",
        "Ne! Ni otpušteni stažista nije ovako promašivao.",
        "Netačno! Sutra sat ranije na obuku. I kafa za tim.",
        "Pitanje za zagrevanje, a ti si se {povredio|povredila}.",
        "Ne! Ovako se gubi poverenje celog odeljenja.",
        "Skidaj taj osmeh. Sledeći put idem kod direktora.",
        "Ovako nastaviš i karijera ti je bila kratka.",
    ]

    enum Vrsta { case upad, zadatak, haos }

    /// Ometanje usred pitanja. Upad sam nestaje za 1,5 s; zadatak čeka dugme „Odmah, šefe”; haos trese ili zamagli karticu.
    struct Ometanje: Hashable {
        let vrsta: Vrsta
        let tekst: String
        /// Za haos: true trese karticu, false je zamagli.
        var trese = false
    }

    static let ometanja: [Ometanje] = [
        // Upad (25)
        .init(vrsta: .upad, tekst: "Jesi li {video|videla} mejl?"),
        .init(vrsta: .upad, tekst: "Sastanak u tri, ne zaboravi!"),
        .init(vrsta: .upad, tekst: "Ko je ostavio šolju u sali?"),
        .init(vrsta: .upad, tekst: "Kvartalni izveštaj, gde je?"),
        .init(vrsta: .upad, tekst: "Samo da pitam, kako napreduje?"),
        .init(vrsta: .upad, tekst: "Zove klijent, reci da nisi tu."),
        .init(vrsta: .upad, tekst: "Ko je pomerio moju stolicu?"),
        .init(vrsta: .upad, tekst: "Ne zaboravi tabelu za petak!"),
        .init(vrsta: .upad, tekst: "Lift opet ne radi!"),
        .init(vrsta: .upad, tekst: "Je l' neko video punjač?"),
        .init(vrsta: .upad, tekst: "Danas je rođendan u marketingu!"),
        .init(vrsta: .upad, tekst: "Štampač opet guta papir!"),
        .init(vrsta: .upad, tekst: "Imamo novog praktikanta, pozdravi!"),
        .init(vrsta: .upad, tekst: "Je l' stigla faktura?"),
        .init(vrsta: .upad, tekst: "Prezentacija je u četiri, ne u pet!"),
        .init(vrsta: .upad, tekst: "Ko je naručio picu na moje ime?"),
        .init(vrsta: .upad, tekst: "Lozinka za Wi-Fi je promenjena!"),
        .init(vrsta: .upad, tekst: "Sutra dolazi revizija!"),
        .init(vrsta: .upad, tekst: "Klima je opet na šesnaest!"),
        .init(vrsta: .upad, tekst: "Je l' ovo tvoj kišobran?"),
        .init(vrsta: .upad, tekst: "Direktor je u zgradi!"),
        .init(vrsta: .upad, tekst: "Šta ima za ručak?"),
        .init(vrsta: .upad, tekst: "Pošalji mi to u Excelu!"),
        .init(vrsta: .upad, tekst: "Ko je ugasio server?"),
        .init(vrsta: .upad, tekst: "Kafe nema do ponedeljka!"),
        // Zadatak (25): dugme „Odmah, šefe”, sat teče
        .init(vrsta: .zadatak, tekst: "Donesi mi kafu! Bez šećera."),
        .init(vrsta: .zadatak, tekst: "Prekidaj to, idi pomozi Draganu!"),
        .init(vrsta: .zadatak, tekst: "Jesi li {uradio|uradila} kvartalni? Pošalji odmah!"),
        .init(vrsta: .zadatak, tekst: "Hajde, brainstorm u sali, sad!"),
        .init(vrsta: .zadatak, tekst: "Odštampaj mi ugovor, hitno!"),
        .init(vrsta: .zadatak, tekst: "Javi se na telefon, zvoni pet minuta!"),
        .init(vrsta: .zadatak, tekst: "Zakaži sastanak sa investitorima!"),
        .init(vrsta: .zadatak, tekst: "Odnesi ovo u računovodstvo!"),
        .init(vrsta: .zadatak, tekst: "Napravi mi tabelu do podneva!"),
        .init(vrsta: .zadatak, tekst: "Proveri da li je stigla pošiljka!"),
        .init(vrsta: .zadatak, tekst: "Napiši zapisnik sa sastanka!"),
        .init(vrsta: .zadatak, tekst: "Zalij cveće, vene od ponedeljka!"),
        .init(vrsta: .zadatak, tekst: "Pozovi klijenta i izvini se!"),
        .init(vrsta: .zadatak, tekst: "Spremi salu za prezentaciju!"),
        .init(vrsta: .zadatak, tekst: "Pošalji ponudu pre ručka!"),
        .init(vrsta: .zadatak, tekst: "Nađi mi onaj fajl od prošle godine!"),
        .init(vrsta: .zadatak, tekst: "Sačekaj kurira na ulazu!"),
        .init(vrsta: .zadatak, tekst: "Popravi projektor, ti se razumeš!"),
        .init(vrsta: .zadatak, tekst: "Prevedi mi ovaj mejl, brzo!"),
        .init(vrsta: .zadatak, tekst: "Dočekaj goste na recepciji!"),
        .init(vrsta: .zadatak, tekst: "Skeniraj mi ovih dvadeset strana!"),
        .init(vrsta: .zadatak, tekst: "Smisli slogan za kampanju!"),
        .init(vrsta: .zadatak, tekst: "Odgovori na reklamaciju!"),
        .init(vrsta: .zadatak, tekst: "Naruči nove olovke, sve su nestale!"),
        .init(vrsta: .zadatak, tekst: "Uključi se na video poziv, čekaju te!"),
        // Haos (10): samo na jakom
        .init(vrsta: .haos, tekst: "Požarna vežba! Svi napolje!", trese: true),
        .init(vrsta: .haos, tekst: "Bušilica u susednoj kancelariji!", trese: true),
        .init(vrsta: .haos, tekst: "Neko je prosuo kafu po tastaturi!", trese: false),
        .init(vrsta: .haos, tekst: "Selidba! Nose ti sto!", trese: true),
        .init(vrsta: .haos, tekst: "Nestalo je struje na sekund!", trese: false),
        .init(vrsta: .haos, tekst: "Mašina za maglu iz marketinga!", trese: false),
        .init(vrsta: .haos, tekst: "Kolega vežba bubanj za proslavu!", trese: true),
        .init(vrsta: .haos, tekst: "Prozor otvoren, papiri lete!", trese: true),
        .init(vrsta: .haos, tekst: "Konfete! Neko je dobio unapređenje!", trese: false),
        .init(vrsta: .haos, tekst: "Alarm automobila ispred zgrade!", trese: true),
    ]

    /// Koja pitanja runde (0…9) dobijaju ometanje: nisko 1, srednje 2–3, visoko 4–5; nikad dva zaredom.
    /// Primer: `Sef.rasporedOmetanja(nivo: 3)` → npr. [1, 4, 6, 8]
    static func rasporedOmetanja(nivo: Int, pitanja: Int = 10) -> Set<Int> {
        let koliko = switch nivo { case ...0: 0; case 1: 1; case 2: Int.random(in: 2...3); default: Int.random(in: 4...5) }
        var izbor: Set<Int> = []
        for k in (0..<pitanja).shuffled() where izbor.count < koliko && !izbor.contains(k - 1) && !izbor.contains(k + 1) {
            izbor.insert(k)
        }
        return izbor
    }

    /// Na kom pitanju runde (od izabranih za ometanje) dolazi jedno veliko ometanje preko kartice.
    /// Vlasnik 05.11: zadatak i haos baš smetaju, pa najviše jedno u 10–20 pitanja: „često” jednom po rundi (10),
    /// „ponekad” u svakoj drugoj rundi (oko 20), „retko” nikad. Sve ostalo je upad (traka gore).
    /// Primer: `Sef.velikoPitanje(nivo: 3, raspored: [1, 4, 7])` → jedno od 1, 4, 7
    static func velikoPitanje(nivo: Int, raspored: Set<Int>) -> Int? {
        switch nivo {
        case 3: raspored.randomElement()
        case 2: Bool.random() ? raspored.randomElement() : nil
        default: nil
        }
    }

    /// Veliko ometanje: na „često” haos u 1 od 3, inače zadatak; ostalo upad.
    static func ometanje(nivo: Int, veliko: Bool) -> Ometanje {
        let vrsta: Vrsta = !veliko || nivo < 2 ? .upad : nivo >= 3 && Int.random(in: 0..<3) == 0 ? .haos : .zadatak
        return ometanja.filter { $0.vrsta == vrsta }.randomElement()!
    }
}

/// Šef upada preko kartice. Zadatak pokriva odgovore dok se ne pritisne „Odmah, šefe” (sat teče).
struct OmetanjeView: View {
    let ometanje: Sef.Ometanje
    var lik = "korporacija"
    let zatvori: () -> Void
    private var tekst: String { Sef.oblik(ometanje.tekst, zensko: Karijera.mojPol == "z") }

    var body: some View {
        if ometanje.vrsta == .zadatak {
            VStack(spacing: 14) {
                Image(Sef.slika(ometanje, lik: lik)).resizable().scaledToFit().frame(height: 90).accessibilityHidden(true)
                Text(tekst).font(.naslov(22)).multilineTextAlignment(.center).foregroundStyle(Color.mastilo)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: zatvori) { Label(Sef.lik(lik).zensko ? "Odmah, šefice" : "Odmah, šefe", systemImage: "hand.thumbsup.fill") }
                    .buttonStyle(.primarno)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.kartica.opacity(0.97), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.mastilo, lineWidth: 2))
            // Traka sa satom ostaje vidljiva: sat teče dok igrač ne odradi zadatak.
            .padding(.top, 50)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        } else {
            HStack(spacing: 10) {
                Image(Sef.slika(ometanje, lik: lik)).resizable().scaledToFit().frame(width: 48, height: 54).accessibilityHidden(true)
                Text(tekst).font(.tekst(17, .bold)).foregroundStyle(Color.mastilo).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(Color.kartica, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.mastilo, lineWidth: 2))
            .padding(.horizontal, 8).padding(.top, 8)
            .rotationEffect(.degrees(-2))
            .allowsHitTesting(false)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityLabel("\(Sef.lik(lik).zensko ? "Šefica" : "Šef"): \(tekst)")
        }
    }
}
