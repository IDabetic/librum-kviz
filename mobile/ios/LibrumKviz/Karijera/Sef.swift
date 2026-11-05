import SwiftUI

/// Šef (docs/KARIJERA-PRAVILA.md 1.3): komentariše svaki odgovor kad igrač radi kod drugog (Korporacija, NPC ili tuđa firma).
/// Parodija na kancelariju, bez psovki i ličnih uvreda. Ista rečenica se ne ponavlja dok se banka ne potroši.
enum Sef {
    enum Povod { case tacno, netacno, isteklo }

    // Rečenice sa {muški|ženski} oblikom biraju oblik po polu igrača (Sef.recenica(_:zensko:)).
    static let tacno = [
        "Bravo! Ovo nisam [očekivao|očekivala] od tebe, ali bravo.",
        "E, to je već nešto. Posle jučerašnjeg, pravo čudo.",
        "Dobro. Ne navikavaj se na pohvale.",
        "Tačno. Vidiš da možeš kad hoćeš.",
        "Hm. Slučajno, pretpostavljam.",
        "Odlično! Ovo ide u kvartalni izveštaj.",
        "Konačno neko ko čita mejlove.",
        "Tačno. Zaslužena kafa. Iz automata, ne preteruj.",
        "Vidi {ti njega. Pametnjaković|ti nju. Pametnica}.",
        "To! Tako se radi u ovoj firmi.",
        "Dobro je. Ali brže, klijent ne čeka tvoje misli.",
        "Tačno. Neka ti bude, za danas.",
        "Lepo. Javiću upravi. Možda.",
        "Eto, znaš nešto. Gde to kriješ ostatak dana?",
        "Tačno, a pitam za svaki slučaj.",
        "Super. Sad uradi još devet ovako.",
        "Bravo, bravo. Nemoj da se uobraziš.",
        "Vidim napredak. Mali, ali vidim.",
        "Tačno! Možda i dobiješ povišicu. Šalim se.",
        "Tako. Ovo je nivo koji očekujem.",
        "Pa ti {si čitao|si čitala} uputstvo!",
        "Dobro odgovoreno. Sledeće.",
        "Ovo je odgovor za sastanak u devet.",
        "Odlično. Upiši to i u zapisnik.",
        "Tačno. Neka ostali uče od tebe.",
        "Gle, gle. Neko je danas {došao naspavan|došla naspavana}.",
        "To je taj duh! Timski, sinergijski, proaktivni.",
        "Tvoja slika ide na zid. Pored aparata za vodu.",
        "Pa ti si mali genije. Mali, ali genije.",
        "Opa! Ovo ću da kažem da je bila moja ideja.",
        "Bravo. Ovo zaslužuje lajk na internom portalu.",
        "Tačno. Klijent bi bio oduševljen. Da ga imamo.",
        "Dobro, dobro. Ne gledaj me tako, [pohvalio|pohvalila] sam te.",
        "Odgovor vredan bonusa. Koji nećeš dobiti, naravno.",
        "E, tako. Sad si za stepenicu bliže mom kabinetu.",
        "Tačno! Jedva čekam da to prisvojim na prezentaciji.",
        "Ti si ovde najbolji. Posle mene, naravno.",
        "Odlično. Uprava je oduševljena. Uprava sam ja.",
        "To je bio težak. Ili lak. Svejedno, bravo.",
        "Tačno. Hajde, još jednom, da vidim da nije slučajno.",
        "Vidi ti to. Kao da {imaš|imaš} diplomu.",
        "Majstorski. Ovo ide u priručnik za nove.",
        "Bravo. Pauza od 30 sekundi ti je odobrena.",
        "Tačno. Moj šef bi bio ponosan na mene što te imam.",
        "Ovo je KPI koji volim da vidim.",
        "Pa gde si do sada? Ovakvi su nam trebali.",
        "Tačno. Ostavi malo pameti i za ostale.",
        "Bravo. Javiću HR-u da te ne otpušta ove nedelje.",
        "Odličan odgovor. Proveriću ga ipak na Guglu.",
        "Ovo je bilo brže od mog interneta.",
        "Tačno! Napisaću ti preporuku. Kratku, ali napisaću.",
        "Eto, a svi su govorili da ništa ne znaš.",
        "Vrhunski. Kao kafa u devet ujutru.",
        "Tačno. Kolege u kuhinji pričaju samo o tebi.",
        "Nastavi ovako i dobićeš stolicu sa točkićima.",
        "Tačno. Ovo ide pravo u tvoj dosije. U dobrom smislu.",
        "To! Sad mi je dan malo manje loš.",
        "Bravo. [Ponosan|Ponosna] sam. Malo. Nemoj nikom da kažeš.",
        "Tačno. Strategija, vizija, fokus. Tako se to radi.",
        "Ovo je bio odgovor jednog direktora.",
        "Tačno! A ja [mislio|mislila] da si tu samo zbog kafe.",
        "Fino. Kao da te je neko obučio. Možda ja.",
        "{Bravo, kolega|Bravo, koleginice}. Tako se radi.",
        "Ovaj odgovor bih [potpisao|potpisala].",
        "Tačno. Bilo bi šteta da te izgubimo. Sigurno.",
        "Odlično. {Zaradio|Zaradila} si kapital. Mali, ali kapital.",
        "To je to! Zapamti ovaj osećaj, retko se ponavlja.",
        "Tačno. Ovim tempom ćeš imati sopstveni office.",
        "Bravo! Gde si {naučio|naučila}? Ne govori, ne zanima me.",
        "Ovo bih [stavio|stavila] u godišnji izveštaj, na prvu stranu.",
        "Precizno kao Excel tabela. Dobro složena.",
        "Tačno. Daj pet. Virtuelno. Imam sastanak.",
        "Bravo. Konkurencija se trese.",
        "Dobar. Baš dobar. Previše dobar. Gledam te.",
        "Tačno. Sledeće pitanje je teže, da znaš.",
        "Ovaj odgovor miriše na unapređenje.",
        "E vidiš, nisi {samo lep nego i pametan|samo lepa nego i pametna}.",
        "Tačno. Šta si {doručkovao|doručkovala}? Hoću isto.",
        "Bravo! Ovo pričam na sledećem tim-bildingu.",
        "Pa ti si {rođen|rođena} za ovaj posao.",
        "Tačno. Uprava odobrava. Klimam glavom, ne vidiš.",
        "Odlično. Kao da si {pročitao|pročitala} misli tvorca pitanja.",
        "Opa, opa. Neko je kod kuće učio.",
        "Bravo. Imaš budućnost. Ne kod nas, ali imaš.",
        "Tačno! [Dao|Dala] bih ti i za prevoz. Ali neću.",
        "Taaako se odgovara! Uživaj, ovde se to retko viđa.",
        "Tačno. Ovo bi i moj mentor znao. Ali ti si brži.",
        "Lepo, lepo. Sledeći put bez pomoći.",
        "Tačno. Već vidim tvoju sliku na poslovnoj mreži.",
        "Ovo je odgovor za naslovnu stranu biltena firme.",
        "Bravo. Treba mi neko kao ti. Bar do petka.",
        "Tačno. Neka se zna ko radi u ovoj firmi.",
        "Dobar odgovor, dobra firma. I [dobar šef|dobra šefica].",
        "Fantastično. Zvuči kao da znaš o čemu pričaš.",
        "Tačno. Ovo ću da forvardujem celoj firmi.",
        "Bravo. Ovo zaslužuje aplauz. Tihi, imamo susede.",
        "Odlično. Dodajem ti plus u tabelu. Plus je dobar.",
        "To je odgovor! Bez muljanja, bez izgovora.",
        "Tačno. Sad ćeš i da me pitaš za povišicu, a?",
        "{Majstore|Majstorice}! Bravo!",
        "Tačno. Ali nisam [zaboravio|zaboravila] prošlo pitanje.",
        "Tačno. Za to te i plaćamo, ne čekaj aplauz.",
        "Dobro je. Prvi put ove nedelje bez crvene olovke.",
        "Vidiš kako ide kad se potrudiš? Što ne češće?",
        "Tačno. Prva lepa stvar u tvom dosijeu. Zapisujem.",
        "Tačno. Ali brzina ti je kao opštinski šalter petkom.",
        "Tačno. Bez ponosa, ovo je minimum, ne podvig.",
        "Dobro što te nisam [otpustio|otpustila] prošlog meseca.",
        "Tačno. Sledeće je teže. Videćemo, sreća ili znanje.",
        "Tačno. Javiću kad stignem da se oduševim.",
    ]

    static let netacno = [
        "Jaoo, ništa ne znaš! Kako si {prošao|prošla} intervju?",
        "Je l' moguće da to nisi {znao|znala}?",
        "Pa šta ti radiš ovde ceo dan?",
        "Netačno. Opet. Ti to radiš namerno, da me nerviraš.",
        "Ovo ću da zapamtim. Do ocene rada, sigurno.",
        "Jesi li ti {završio|završila} onu školu ili samo upisao?",
        "Ne, ne i ne. Da ti napišem na monitor?",
        "Kolega iz konkurencije bi ovo znao.",
        "Nisi ni u istoj zgradi sa tačnim odgovorom.",
        "Ajde, molim te, saberi se.",
        "Ovo zna i portir! A on je tu dve nedelje, noću.",
        "Hoćeš da ti pošaljem u mejlu tačan odgovor?",
        "Imaš li ti uopšte internet kod kuće?",
        "Ovim tempom ostaješ ovde do penzije.",
        "Netačno. Idi popij kafu, pa se vrati.",
        "Nisam [ljut|ljuta]. Samo sam [razočaran|razočarana].",
        "Probni rad, rekoh? Probni.",
        "Ovo ide pravo u tvoj dosije.",
        "Ne mogu da verujem šta čujem.",
        "Sledeći put misli pre nego što klikneš.",
        "[Tražio|Tražila] sam pojačanje, a ti si glavobolja.",
        "Da li ti je neko rekao da je ovo kviz za decu?",
        "Ovo je bilo na prošlom sastanku!",
        "Netačno, kao i obično. Bar si {dosledan|dosledna}.",
        "Moja baka bi ovo znala. A ona je u penziji od 1998.",
        "Tako je, a ne. Ne nije tako.",
        "Ovo nije odgovor, ovo je krik u pomoć.",
        "Pa jesi li ti uopšte {otvorio|otvorila} uputstvo?",
        "Netačno. Šaljem te na obuku. Plaćaš je sam.",
        "Brate mili, ovo je bilo lako.",
        "Platili smo ti kurs, a ti i dalje bacaš novčić.",
        "Netačno. Upravo si mi {pokvario|pokvarila} prosek.",
        "Ovo ću da ispričam na kafi. Svima.",
        "Da li ovo radiš namerno, da me iznerviraš?",
        "Odgovor je bio pred tobom. Bukvalno pred tobom.",
        "Netačno. Sledeći tim-bilding ide bez tebe.",
        "Kao da je mačka hodala po tastaturi.",
        "Pa jesi li ti {siguran|sigurna} da radiš u pravoj firmi?",
        "Netačno. Javljam računovodstvu da ti skine bod.",
        "Ne znam da li da plačem ili da se smejem.",
        "Ovo je hrabro. Pogrešno, ali hrabro.",
        "Nulta tolerancija. Za ovakve odgovore.",
        "Netačno. Idi pa se odmori. Ali ne predugo.",
        "Ovo nije kviz za početnike. Mada i tamo bi {pao|pala}.",
        "[Siguran|Sigurna] sam da si se samo {zbunio|zbunila}. Svaki put.",
        "Netačno. Sad ću morati da tražim zamenu.",
        "Ovo je bilo toliko pogrešno da je skoro umetnost.",
        "Pa da li si ti na pauzi ili radiš?",
        "Netačno. A ja te [hvalio|hvalila] pred upravom.",
        "Gospode, daj mi strpljenja.",
        "Ovo ću da stavim kao primer na obuci. Šta ne raditi.",
        "Netačno. Odluka je doneta. Kafa ti je ukinuta.",
        "Ne odgovaraj kao da je petak popodne.",
        "Ima li ovde odrasle osobe?",
        "Netačno. Sledeći put pitaj kolegu. Bilo kog.",
        "A ja [mislio|mislila] da si {najbolji|najbolja} u timu.",
        "Ovo nije bio odgovor, ovo je bilo nagađanje.",
        "Pišem u izveštaj: ne zna, ali se trudi. Ne trudi se.",
        "Pa jesi li ti {spavao|spavala} na sastanku?",
        "Netačno. Sad mi je jasno zašto smo u minusu.",
        "Kao da si odgovor {izvukao|izvukla} iz šešira.",
        "Ne mogu ja ovo više da gledam. Moram. Plaćen sam.",
        "Netačno. Danas radiš prekovremeno. Ne plaćeno.",
        "Zovite HR! Ne, nemojte, oni su na odmoru.",
        "Netačno. Biće ovo dug dan.",
        "Je l' ti ovo prvi dan na poslu? Tako izgleda.",
        "Pa ovo zna i stažista. Stažista koga nemamo.",
        "Netačno. Da nisi u pogrešnoj sobi?",
        "Ovaj odgovor je uvreda za celu struku.",
        "Netačno. Neću ni da komentarišem. Evo, komentarišem.",
        "Probaj sledeći put sa tačnim odgovorom. Za promenu.",
        "Netačno. Ali bar si {brz|brza} u greškama.",
        "Jao, jao, jao. Tri puta jao.",
        "Ovo bi i automat za kafu bolje odgovorio.",
        "Netačno. Danas nema kolača za tebe.",
        "Hajde da se pravimo da ovo nisam [video|videla].",
        "Netačno. Zapisujem. Crvenom bojom.",
        "Jesi li ti ovo stvarno {mislio|mislila} ili si samo {kliknuo|kliknula}?",
        "To je odgovor koji ide u arhivu sramote.",
        "Netačno. Hvala bogu što klijent ovo ne vidi.",
        "Moraš da učiš. Mnogo. Od danas.",
        "Netačno. I ne govori da je pitanje bilo nejasno.",
        "Uvek me iznenadiš. Nikad prijatno.",
        "Netačno. Sad idi i razmisli o svom životu.",
        "A ja te [preporučio|preporučila]! Sramota.",
        "Netačno. Moraću da ti oduzmem pristup štampaču.",
        "Pa ti nisi za ovo, ti si za stalno.",
        "Netačno. Ovo ćemo rešavati na sastanku od dva sata.",
        "Šta da kažem upravi? Da ništa ne znaš? Reći ću.",
        "Ne žuri. Ili žuri. Svejedno, opet pogrešiš.",
        "Pitam koliko je sati, a ti kažeš: utorak.",
        "Netačno. Od sutra sediš pored fotokopir aparata.",
        "Bravo! Šalim se. Netačno. Videla se nada, hehe.",
        "Ovo bih [razumeo|razumela] da je ponedeljak. Ali nije.",
        "Netačno. Moj pas bi ovo znao. Nemam psa.",
        "Kad si poslednji put {pročitao|pročitala} nešto osim jelovnika?",
        "Netačno. Napravićemo od tebe stručnjaka. Za greške.",
        "Ovo nije Korporacija za neznalice. Mada, liči.",
        "Gledaj me u oči i reci da nisi {nagađao|nagađala}.",
        "Pa dobro, ko te je zaposlio? A, ja. Moja greška.",
        "Netačno. Šta ti uopšte radiš ovde ceo dan?",
        "Pogrešno. Razmisli što si danas {došao|došla} na posao.",
        "Ovaj odgovor kačim iznad kafe, kao opomenu svima.",
        "Ne gledaj me tako. Ti si {kliknuo|kliknula}, ne ja.",
        "Pogrešno. Kolega je ovo znao još na probnom radu.",
        "Da si {ćutao|ćutala}, [mislio|mislila] bih da znaš.",
        "Ne. Negde u računovodstvu neko upravo plače.",
        "Za ovo se nekad pisala opomena. Srećom, nekad.",
        "Netačno. Ti biraš odgovore po boji dugmeta?",
        "Ti više ne pogađaš, ja se ne nerviram. Dogovor?",
        "Čestitam, upravo si {izgubio|izgubila} klijenta.",
        "Ovo ide u tvoj dosije. Onaj debeli, u fioci.",
        "U CV-u piše „{snalažljiv|snalažljiva}”. Gde je to sad?",
        "Pogrešno. Zato te više i ne zovemo na sastanke.",
        "Sad mi je jasna preporuka tvog bivšeg šefa.",
        "Ti si za firmu ulaganje ili trošak? Danas trošak.",
        "Idi objasni klijentu. Meni je neprijatno.",
        "Znaš šta mi se sviđa u ovom odgovoru? Ništa.",
        "Ovo bi znala i moja baka, a ona nema internet.",
        "Tvoja stolica radi više od tebe. Bar te drži.",
    ]

    static let isteklo = [
        "Spavaš na poslu? Da ti donesem jastuče?",
        "Vreme je novac. Tvoje je isteklo.",
        "Halo! Ima li koga? Kucam, a tamo ugašen mozak.",
        "Čekamo te, imamo ceo dan. Šalim se, nemamo.",
        "Ćutanje nije odgovor. Ni kad te uprava pita.",
        "Tik-tak. Sat je radio. Samo ti nisi {radio|radila}.",
        "Jesi li {zaspao|zaspala} nad tastaturom?",
        "[Mislio|Mislila] sam da si {otišao|otišla} na pauzu.",
        "Sledeći put brže, molim lepo.",
        "Ovo ide kao kašnjenje. I skida se sa plate.",
        "Kafa je bila preča? Uživaj, možda ti je poslednja.",
        "Rok je istekao. Kao i moje strpljenje.",
        "Da li ti treba pomoć da pritisneš dugme?",
        "Hajde, nije ovo razmišljanje o smislu života.",
        "Vreme! A odgovor? Nigde. Kao i tvoj izveštaj.",
        "Ovo se vodi kao neopravdano odsustvo.",
        "Klijent je čekao i otišao. Hvala ti.",
        "Jesi li {zalutao|zalutala} na putu do odgovora?",
        "Dvadeset sekundi! Ja za to vreme pošaljem tri mejla.",
        "Ni odgovor ni izgovor. Bar nešto izmisli.",
        "Gledaš u pitanje kao u ponedeljak ujutru.",
        "Halo, Zemlja zove. Ovde se plaća po učinku.",
        "Isteklo. I nemoj da kažeš da je internet kriv.",
        "U ovoj firmi se odgovara. Bar pogrešno.",
        "Tajmer je pobedio. Da zaposlim njega umesto tebe?",
        "Dok ti čekaš, drugi uzimaju unapređenje.",
        "Vreme je isteklo, a ti još razmišljaš? Lepo.",
        "Ovo ide pravo u izveštaj o produktivnosti.",
        "Jesi li {zaboravio|zaboravila} lozinku za mozak?",
        "Rok, rok, rok! Šta je rok? Prošao je.",
        "Zaledilo se? Tebi, ne računaru.",
        "Sledeći put klikni bilo šta. Bar ćeš imati šansu.",
        "Isteklo vreme. A ja te [čekao|čekala] kao autobus.",
        "Ne mogu da ti platim za razmišljanje bez rezultata.",
        "Ćutiš kao da si na sastanku sa direktorom.",
        "Vreme! Ili si {mislio|mislila} da imamo ceo dan?",
        "Neodlučnost je skupa. Plaćaš je ti.",
        "Isteklo. Da li i tvoj ugovor ističe? Videćemo.",
        "Polako, polako... previše polako.",
        "Odgovor je na čekanju. Kao i tvoja povišica.",
        "Isteklo. Ekran ti neće sam reći odgovor.",
        "Isteklo! Niko u firmi nije ovako {spor|spora}.",
        "Dok si {razmišljao|razmišljala}, konkurencija je pobedila.",
        "Treba ti vremena? Uzmi godišnji. I ne žuri nazad.",
        "Ne plaćam te da razmišljaš o životu. Odgovaraj.",
        "Isteklo. A ti još nisi ni {pročitao|pročitala} pitanje.",
        "Vreme! Sporije od opštine. To je pravi uspeh.",
        "Isteklo. Ja ću odgovarati, a ti samo klimaj glavom.",
        "Vreme je prošlo. Kao i tvoj bonus ovog meseca.",
        "Da te čekam u restoranu, već bih [otišao|otišla].",
    ]

    /// Podešavanje šefa u firmi (0 isključeno, 1 blago, 2 srednje, 3 jako). Korporacija i NPC: srednje, ometanja ponekad.
    struct Nivo: Hashable {
        var tacno = 2, netacno = 2, ometanja = 2
        var smeh = true
        var lik = "korporacija"
        /// Mirni režim igrača: najviše blago, bez ometanja i smeha.
        func mirno(_ da: Bool) -> Nivo { da ? Nivo(tacno: min(tacno, 1), netacno: min(netacno, 1), ometanja: 0, smeh: false, lik: lik) : self }
        func jacina(_ povod: Povod) -> Int { povod == .tacno ? tacno : netacno }
    }

    private static var iskorisceno: [String: Set<Int>] = [:]

    /// Bira oblik iz {muški|ženski} po polu igrača. Jačina 1 blago, 2 srednje, 3 jako; smeh ponekad (1 od 4) zameni rečenicu.
    /// Primer: `Sef.recenica(.netacno, jacina: 3, zensko: true)`
    static func recenica(_ povod: Povod, jacina: Int = 2, smeh: Bool = false, zensko: Bool, sefZensko: Bool = false) -> String {
        oblik(recenica(povod, jacina: jacina, smeh: smeh), zensko: zensko, sefZensko: sefZensko)
    }

    /// Bira oblike: {muški|ženski} po polu igrača, [muški|ženski] po polu šefa (šef govori o sebi).
    /// Primer: `Sef.oblik("{bio|bila} si, [rekao|rekla] sam", zensko: true, sefZensko: false)` → „bila si, rekao sam”
    static func oblik(_ tekst: String, zensko: Bool, sefZensko: Bool = false) -> String {
        var r = tekst
        for (otvori, zatvori, z) in [("{", "}", zensko), ("[", "]", sefZensko)] {
            while let o = r.range(of: otvori), let k = r.range(of: zatvori, range: o.upperBound..<r.endIndex) {
                let delovi = r[o.upperBound..<k.lowerBound].split(separator: "|", omittingEmptySubsequences: false)
                r.replaceSubrange(o.lowerBound..<k.upperBound, with: String(delovi[z && delovi.count > 1 ? 1 : 0]))
            }
        }
        return r
    }

    /// Izgled šefa (vlasnik 05.11): Korporacija ima svog; vlasnik bira jedan od 6 (server `karijera_lik_sefa`).
    struct Lik: Identifiable, Hashable {
        let id: String
        let naziv: String
        let zensko: Bool
    }

    static let likovi: [Lik] = [
        .init(id: "korporacija", naziv: "Šef Korporacije", zensko: false),
        .init(id: "m_mladi", naziv: "Mladi šef", zensko: false),
        .init(id: "m_srednji", naziv: "Šef u najboljim godinama", zensko: false),
        .init(id: "m_stari", naziv: "Stari šef", zensko: false),
        .init(id: "z_mlada", naziv: "Mlada šefica", zensko: true),
        .init(id: "z_srednja", naziv: "Šefica u najboljim godinama", zensko: true),
        .init(id: "z_starija", naziv: "Iskusna šefica", zensko: true),
    ]

    static func lik(_ id: String) -> Lik { likovi.first { $0.id == id } ?? likovi[0] }

    static func jeSmeh(_ tekst: String) -> Bool { smehTacno.contains(tekst) || smehNetacno.contains(tekst) }

    /// Banka za povod i jačinu; isteklo vreme na blagom i jakom koristi banku netačnih te jačine.
    static func banka(_ povod: Povod, jacina: Int) -> (kljuc: String, recenice: [String]) {
        switch (povod, jacina) {
        case (.tacno, ...1): ("tb", blagoTacno)
        case (.tacno, 3...): ("tj", jakoTacno)
        case (.tacno, _): ("ts", tacno)
        case (_, ...1): ("nb", blagoNetacno)
        case (_, 3...): ("nj", jakoNetacno)
        case (.isteklo, _): ("is", isteklo)
        default: ("ns", netacno)
        }
    }

    private static func recenica(_ povod: Povod, jacina: Int, smeh: Bool) -> String {
        let (kljuc, banka) = smeh && Int.random(in: 0..<4) == 0
            ? (povod == .tacno ? ("st", smehTacno) : ("sn", smehNetacno))
            : banka(povod, jacina: jacina)
        var bilo = iskorisceno[kljuc, default: []]
        if bilo.count >= banka.count { bilo = [] }
        let i = banka.indices.filter { !bilo.contains($0) }.randomElement() ?? 0
        bilo.insert(i); iskorisceno[kljuc] = bilo
        return banka[i]
    }

    /// Slika šefa za odgovor: `Karijera_Sef_<lik>_<zadovoljan|ljut|nervozan|smeh>`.
    static func slika(_ povod: Povod, lik: String = "korporacija", smeh: Bool = false) -> String {
        let raspolozenje: String = switch povod { case .tacno: "zadovoljan"; case .netacno: "ljut"; case .isteklo: "nervozan" }
        return "Karijera_Sef_\(lik)_\(smeh ? "smeh" : raspolozenje)"
    }

    /// Šef Korporacije ima i pozu sa kafom (zadatak) i šokiranu (haos); ostali su nervozni.
    static func slika(_ o: Ometanje, lik: String) -> String {
        guard lik == "korporacija" else { return "Karijera_Sef_\(lik)_nervozan" }
        return switch o.vrsta { case .zadatak: "Karijera_Sef_korporacija_kafa"; case .haos: "Karijera_Sef_korporacija_sok"; case .upad: "Karijera_Sef_korporacija_nervozan" }
    }
}

/// Šef sa oblačićem: pojavi se posle odgovora u Korporaciji, dodir ga zatvara.
struct SefKaze: View {
    let povod: Sef.Povod
    let tekst: String
    var lik = "korporacija"
    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Image(Sef.slika(povod, lik: lik, smeh: Sef.jeSmeh(tekst))).resizable().scaledToFit().frame(width: 80, height: 96).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Oznaka(tekst: Sef.lik(lik).zensko ? "Šefica kaže" : "Šef kaže", boja: povod == .tacno ? .teal : .crvena)
                // Najviše dva reda (vlasnik 05.11); rečenice su ≤ 52 znaka, test `testDvaReda`.
                Text(tekst).font(.tekst(15, .bold)).foregroundStyle(Color.mastilo).lineLimit(2).minimumScaleFactor(0.85)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.kartica, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.mastilo, lineWidth: 2))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Sef.lik(lik).zensko ? "Šefica" : "Šef") kaže: \(tekst)")
    }
}
