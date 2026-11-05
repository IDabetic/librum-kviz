import Foundation

/// 18 pomoći Karijere (vlasnik 04.11): moći iz Osvajača, preimenovane za kancelariju, sa istom suštinom.
/// Igrač bira 4 pre talenata; svaka važi jednom po rundi. Server zna samo ime (karijera_pomoci_spisak):
/// odgovor sa pomoći vredi ×0,7 (Insajder ×0,4) i ne donosi ugled ni ekspertizu.
struct KarijeraPomoc: Identifiable, Hashable {
    enum Efekat: Hashable {
        /// Sklanja n netačnih, posle `kasnjenje` sekundi.
        case ukloni(Int, kasnjenje: Double = 0)
        case vreme(Int)
        case satStoji
        case otkrij
        /// Predlog odgovora: tačan sa verovatnoćom `p`.
        case savet(Double, kasnjenje: Double = 0)
        /// Raspodela „glasova” kolega; tačan dobija najviše sa verovatnoćom `p`.
        case anketa(Double)
        case prvoSlovo
    }

    let id: String
    let naziv: String
    /// Moć iz Osvajača od koje potiče (za opis i dosledan osećaj obe igre).
    let poreklo: String
    let opis: String
    let ikonica: String
    let efekti: [Efekat]

    static let sve: [KarijeraPomoc] = [
        .init(id: "pola_stola", naziv: "Pola stola", poreklo: "Pola-pola", opis: "Sklanja dva netačna odgovora.", ikonica: "circle.lefthalf.filled", efekti: [.ukloni(2)]),
        .init(id: "crvena_olovka", naziv: "Crvena olovka", poreklo: "Jedan manje", opis: "Precrta jedan netačan odgovor.", ikonica: "pencil.line", efekti: [.ukloni(1)]),
        .init(id: "insajder", naziv: "Insajder", poreklo: "Tačan odgovor", opis: "Pokaže tačan odgovor, ali odgovor vredi manje.", ikonica: "checkmark.seal.fill", efekti: [.otkrij]),
        .init(id: "mentor", naziv: "Mentor", poreklo: "Savet mudraca", opis: "Mentor predloži odgovor; u pravu je tri od četiri puta.", ikonica: "brain.head.profile", efekti: [.savet(0.75)]),
        .init(id: "prvo_slovo", naziv: "Prvo slovo", poreklo: "Nagoveštaj", opis: "Otkrije prvo slovo tačnog odgovora.", ikonica: "character.cursor.ibeam", efekti: [.prvoSlovo]),
        .init(id: "produzen_rok", naziv: "Produžen rok", poreklo: "+10 sekundi", opis: "+10 sekundi za ovo pitanje.", ikonica: "timer", efekti: [.vreme(10)]),
        .init(id: "pauza_kafa", naziv: "Pauza za kafu", poreklo: "Vreme stoji", opis: "Sat stoji dok ne odgovoriš.", ikonica: "cup.and.saucer.fill", efekti: [.satStoji]),
        .init(id: "prekovremeno", naziv: "Prekovremeno", poreklo: "Juriš", opis: "+20 sekundi za ovo pitanje.", ikonica: "moon.stars.fill", efekti: [.vreme(20)]),
        .init(id: "ekspres", naziv: "Ekspres", poreklo: "Munja", opis: "Skloni jedan netačan i doda 5 sekundi.", ikonica: "bolt.fill", efekti: [.ukloni(1), .vreme(5)]),
        .init(id: "hodnik", naziv: "Hodnik priča", poreklo: "Špijun", opis: "Anketa kolega: kako bi oni odgovorili.", ikonica: "person.3.fill", efekti: [.anketa(0.7)]),
        .init(id: "caskanje", naziv: "Ćaskanje na kafi", poreklo: "Prisluškivanje", opis: "Kolega šapne odgovor; u pravu je u 60% slučajeva.", ikonica: "ear.fill", efekti: [.savet(0.6)]),
        .init(id: "mreza", naziv: "Mreža kontakata", poreklo: "Špijunska mreža", opis: "Posle 8 sekundi stigne odgovor; tačan u 90% slučajeva.", ikonica: "network", efekti: [.savet(0.9, kasnjenje: 8)]),
        .init(id: "ceo_tim", naziv: "Ceo tim", poreklo: "Pojačanje", opis: "Anketa celog tima, pouzdanija od hodnika.", ikonica: "person.3.sequence.fill", efekti: [.anketa(0.85)]),
        .init(id: "zamrznut_sat", naziv: "Zaključan sat", poreklo: "Zamrzni granicu", opis: "Sat stoji i jedan netačan nestaje.", ikonica: "lock.fill", efekti: [.satStoji, .ukloni(1)]),
        .init(id: "sigurna_odluka", naziv: "Sigurna odluka", poreklo: "Bedem", opis: "Posle 5 sekundi nestanu dva netačna.", ikonica: "shield.fill", efekti: [.ukloni(2, kasnjenje: 5)]),
        .init(id: "brainstorming", naziv: "Brainstorming", poreklo: "Radionica", opis: "Prvo slovo tačnog i jedan netačan manje.", ikonica: "lightbulb.fill", efekti: [.prvoSlovo, .ukloni(1)]),
        .init(id: "dvostruka_provera", naziv: "Dvostruka provera", poreklo: "Siguran udar", opis: "Jedan netačan manje i predlog sa 70% tačnosti.", ikonica: "checkmark.circle", efekti: [.ukloni(1), .savet(0.7)]),
        .init(id: "sabotaza", naziv: "Sabotaža konkurencije", poreklo: "Sabotaža", opis: "Dva netačna manje i 5 sekundi više.", ikonica: "bolt.slash.fill", efekti: [.ukloni(2), .vreme(5)]),
    ]

    static func po(_ id: String) -> KarijeraPomoc? { sve.first { $0.id == id } }
}
