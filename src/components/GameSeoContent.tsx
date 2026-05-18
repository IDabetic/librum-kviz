import Link from 'next/link'

// Server-rendered SEO content block appended to every game landing
// page. The game landings were nearly empty for anonymous crawlers
// (some redirected Googlebot straight to /auth/prijava), so they
// couldn't rank for their target keywords. This adds ~450–550 words
// of indexable, genuinely useful copy per page with proper H2/H3
// structure, an internal-link cluster, and a per-game FAQ that
// mirrors the JSON-LD emitted alongside it.
//
// All content is static and server-rendered — it's in the initial
// HTML regardless of auth state, which is the whole point.

type GameKey = 'pro' | 'book' | 'kafana' | 'duel' | 'vesanje' | 'brzi'

type FaqItem = { q: string; a: string }
type GameCopy = {
  h2: string
  intro: string
  how: { title: string; body: string }
  topics: { title: string; body: string }
  why: { title: string; body: string }
  faq: FaqItem[]
}

const COPY: Record<GameKey, GameCopy> = {
  pro: {
    h2: 'PRO kviz — najteži online kviz znanja na srpskom',
    intro:
      'PRO kviz je survival kviz znanja: počinješ sa 10 života i igraš dokle god ti život traje. ' +
      'Svaki tačan odgovor donosi bodove i gradi kombo niz koji množi nagradu, dok te svaka greška ' +
      'košta jednog života. To je najteži kviz opšteg znanja na Librum platformi i pravi izazov za ' +
      'sve koji vole da provere koliko zaista znaju i da se takmiče na rang-listi.',
    how: {
      title: 'Kako se igra PRO kviz',
      body:
        'Na svako pitanje imaš četiri ponuđena odgovora i ograničeno vreme. Tačan odgovor čuva ' +
        'život i dodaje bodove; više tačnih zaredom diže kombo množilac. Kada potrošiš svih 10 ' +
        'života, partija se završava i rezultat se upisuje na rang-listu i tvoj profil. Dostupne ' +
        'su i pomoći (lifelines) za teške trenutke. Cilj je da odgovoriš na što više pitanja i ' +
        'osvojiš što viši skor.',
    },
    topics: {
      title: 'Oblasti pitanja',
      body:
        'Pitanja pokrivaju opšte znanje, istoriju, geografiju, sport, nauku, film, muziku i ' +
        'književnost. Baza se stalno proširuje novim pitanjima, a igrači mogu i sami da predlože ' +
        'pitanja koja, ako prođu pregled, ulaze u igru.',
    },
    why: {
      title: 'Zašto igrati PRO kviz',
      body:
        'Ako tražiš ozbiljan online kviz znanja na srpskom sa rang-listom i takmičenjem, PRO kviz ' +
        'je pravi izbor. Kratke partije, jasan sistem bodovanja i rang-lista po danu, nedelji, ' +
        'mesecu i sveukupno čine ga idealnim i za brzu pauzu i za dugoročno nadmetanje.',
    },
    faq: [
      { q: 'Koliko traje jedna partija PRO kviza?', a: 'Dok ne potrošiš svih 10 života — partija može trajati od minut do više od pola sata, zavisno od toga koliko tačnih odgovora nanižeš.' },
      { q: 'Da li je PRO kviz besplatan?', a: 'Jeste, potpuno je besplatan. Potreban je samo nalog da bi se rezultat upisao na rang-listu.' },
      { q: 'Kako se računaju bodovi?', a: 'Svaki tačan odgovor nosi bodove, a uzastopni tačni odgovori grade kombo množilac koji povećava nagradu.' },
    ],
  },
  book: {
    h2: 'Book kviz — kviz iz književnosti za ljubitelje knjiga',
    intro:
      'Book kviz je kviz iz književnosti namenjen čitaocima. Pitanja se tiču pisaca, romana, ' +
      'književnih likova i žanrova — od drame i ljubavnog romana do krimića, trilera i ' +
      'fantastike. Na kraju partije saznaš koji književni žanr najbolje poznaješ, što ga čini ' +
      'i zabavnim testom znanja iz književnosti i podsticajem da otkriješ novo štivo.',
    how: {
      title: 'Kako se igra Book kviz',
      body:
        'Igra ima survival format sa životima, kao PRO kviz, ali su sva pitanja iz sveta ' +
        'književnosti. Odgovaraš na pitanja iz različitih žanrova, a sistem prati u kom žanru ' +
        'si najuspešniji i na kraju ti pokaže rezultat po žanru.',
    },
    topics: {
      title: 'Žanrovi i teme',
      body:
        'Drama, ljubavni roman, krimi, triler, fantastika, istorijski roman, domaća književnost ' +
        'i svetski klasici. Pitanja se kreću od poznatih dela i pisaca do književnih likova i ' +
        'citata.',
    },
    why: {
      title: 'Zašto igrati Book kviz',
      body:
        'Ako voliš knjige, ovo je najbrži način da proveriš znanje iz književnosti i otkriješ ' +
        'gde su ti rupe. Idealan je za čitalačke klubove i ljubitelje knjiga koji žele zabavan ' +
        'književni kviz na srpskom.',
    },
    faq: [
      { q: 'Da li Book kviz pokriva domaću književnost?', a: 'Da — pored svetskih klasika, pitanja obuhvataju i domaće pisce, dela i likove.' },
      { q: 'Šta znači „najjači žanr” na kraju?', a: 'Sistem broji tačne odgovore po žanru i na kraju ti pokazuje u kom žanru imaš najbolji procenat tačnosti.' },
      { q: 'Da li je Book kviz besplatan?', a: 'Jeste, kao i sve igre na Librum kvizu.' },
    ],
  },
  kafana: {
    h2: 'Kafanski kviz — muzički pub kviz za društvo',
    intro:
      'Kafanski kviz je muzički pub kviz sa preko 1000 pitanja o domaćoj i ex YU muzici — ' +
      'pevačima, grupama, kultnim pesmama i hitovima koje svi znamo. To je idealan kviz za ' +
      'društvo, za kafanu i za kućno druženje: pustiš ga na telefonu ili laptopu i ekipa pogađa.',
    how: {
      title: 'Kako se igra Kafanski kviz',
      body:
        'Dobijaš pitanje o pesmi, izvođaču ili stihu i četiri ponuđena odgovora, sa 15 sekundi ' +
        'po pitanju i bez pomoći. Tačni odgovori nose bodove i grade niz. Možeš igrati sam radi ' +
        'rekorda na rang-listi ili u duelu protiv prijatelja.',
    },
    topics: {
      title: 'Šta pokrivaju pitanja',
      body:
        'Domaća estrada, ex YU rok i pop, narodna i zabavna muzika, kultni hitovi i ' +
        'prepoznatljivi stihovi. Ako tražiš gotova pitanja za pub kviz na srpskom, ovo je ' +
        'najbrži način da napraviš muzičko veče bez ikakve pripreme.',
    },
    why: {
      title: 'Zašto igrati Kafanski kviz',
      body:
        'Spaja nostalgiju i takmičenje — savršen je za ekipu, rođendane i kafanska druženja, ' +
        'ali i za solo igru kada želiš da provetriš koliko stvarno poznaješ domaću muziku.',
    },
    faq: [
      { q: 'Koliko pitanja ima Kafanski kviz?', a: 'Preko 1000 pitanja o domaćoj i ex YU muzici, i baza se stalno dopunjuje.' },
      { q: 'Može li da se igra u društvu?', a: 'Da — pustiš ga na jednom ekranu i ekipa zajedno pogađa, ili svako igra svoju partiju i poredite rezultate.' },
      { q: 'Postoji li duel mod?', a: 'Postoji — Kafanski duel je igra jedan na jedan na istim muzičkim pitanjima.' },
    ],
  },
  duel: {
    h2: 'Trivia duel — kviz protiv prijatelja u realnom vremenu',
    intro:
      'Trivia duel je multiplayer kviz za dva igrača koji se igra uživo. Napraviš sobu, ' +
      'pošalješ kod ili link prijatelju, on se pridruži i oboje dobijate ista pitanja u isto ' +
      'vreme. Pobednik je onaj sa više bodova — a revanš je na jedan klik.',
    how: {
      title: 'Kako se igra Trivia duel',
      body:
        'Domaćin bira dužinu duela (10, 25 ili 50 pitanja) i tip (opšte znanje ili kafanska ' +
        'muzika), zatim deli kod. Kada se drugi igrač pridruži, partija počinje za oboje ' +
        'istovremeno. Svako pitanje ima vremensko ograničenje; više bodova na kraju nosi pobedu.',
    },
    topics: {
      title: 'Tipovi duela',
      body:
        'PRO duel koristi pitanja opšteg znanja iz istorije, geografije, sporta, nauke i kulture. ' +
        'Kafanski duel koristi pitanja o domaćoj i ex YU muzici. Biraš tip pre nego što kreneš.',
    },
    why: {
      title: 'Zašto igrati Trivia duel',
      body:
        'Najbolji način da rešiš ko više zna — bez dogovaranja oko pitanja i bez varanja, jer ' +
        'oba igrača dobijaju identičan set. Idealan za prijatelje, parove i kolege.',
    },
    faq: [
      { q: 'Treba li prijatelju nalog da bi igrao duel?', a: 'Da, oba igrača treba da budu prijavljena kako bi se rezultati ispravno upisali.' },
      { q: 'Mogu li da igram revanš?', a: 'Možeš — posle partije oba igrača na jedan klik pokreću novi duel iste dužine.' },
      { q: 'Da li su pitanja ista za oba igrača?', a: 'Jesu — to je suština duela; oboje dobijate identičan set pitanja u istom redosledu.' },
    ],
  },
  vesanje: {
    h2: 'Vešanje — online igra pogađanja reči po kategorijama',
    intro:
      'Vešanje je klasična online igra pogađanja reči, prilagođena srpskom jeziku i pismu. ' +
      'Biraš kategoriju, dobijaš hint i pogađaš skrivenu reč slovo po slovo — ili se usudiš da ' +
      'pogodiš celu reč odjednom za veći bonus. Imaš 6 života pre nego što izgubiš.',
    how: {
      title: 'Kako se igra Vešanje',
      body:
        'Izabereš kategoriju i pred tobom je niz praznih polja i kratak hint. Klikćeš slova; ' +
        'tačno slovo se otkriva na svim mestima, netačno troši jedan život. Pogađanje cele reči ' +
        'donosi dodatne bodove. Postoji i mod za dvoje, gde jedan igrač zadaje a drugi pogađa.',
    },
    topics: {
      title: 'Kategorije reči',
      body:
        'Sport, geografija, istorija, kultura, priroda i predmeti. Svaka kategorija ima svoj set ' +
        'reči i hintova prilagođenih i deci i odraslima.',
    },
    why: {
      title: 'Zašto igrati Vešanje',
      body:
        'Brza, opuštajuća igra reči koja istovremeno širi rečnik i opšte znanje. Odlična je za ' +
        'pauzu, za decu i za porodičnu zabavu, a mod za dvoje je idealan za druženje.',
    },
    faq: [
      { q: 'Koliko grešaka smem da napravim?', a: 'Imaš 6 života — svako netačno slovo troši jedan, a kada potrošiš sve, partija se završava.' },
      { q: 'Postoji li igra vešanja za dvoje?', a: 'Postoji — jedan igrač zadaje sobu, drugi se pridruži kodom i pogađa reč.' },
      { q: 'Da li je primereno za decu?', a: 'Jeste — kategorije i hintovi su tako birani da igra bude zabavna i deci i odraslima.' },
    ],
  },
  brzi: {
    h2: 'Brzi kviz — tačno ili netačno za 60 sekundi',
    intro:
      'Brzi kviz je tačno-netačno kviz koji traje tačno 60 sekundi. Niže ti se tvrdnje iz svih ' +
      'oblasti, a ti za svaku biraš tačno ili netačno što brže možeš. Cilj je da za jedan minut ' +
      'sakupiš što više tačnih odgovora — savršeno za pauzu na poslu ili u prevozu.',
    how: {
      title: 'Kako se igra Brzi kviz',
      body:
        'Čim počne, tajmer od 60 sekundi kreće. Za svaku tvrdnju imaš dva dugmeta — tačno ili ' +
        'netačno. Tačan odgovor nosi bodove, netačan ih oduzima, a tempo je sve. Kada vreme ' +
        'istekne, rezultat ide na rang-listu.',
    },
    topics: {
      title: 'Oblasti tvrdnji',
      body:
        'Opšte znanje, istorija, geografija, sport, nauka, film i kultura — iste teme kao PRO ' +
        'kviz, samo u brzom tačno/netačno formatu.',
    },
    why: {
      title: 'Zašto igrati Brzi kviz',
      body:
        'Najkraći način da provetriš mozak: jedan minut, bez razmišljanja predugo, čista brzina ' +
        'i refleks znanja. Idealan kada nemaš vremena za punu partiju.',
    },
    faq: [
      { q: 'Koliko traje Brzi kviz?', a: 'Tačno 60 sekundi po rundi — koliko tvrdnji stigneš, toliko bodova možeš da osvojiš.' },
      { q: 'Da li netačan odgovor oduzima bodove?', a: 'Da — zato se isplati biti i brz i precizan, a ne nasumično kliktati.' },
      { q: 'Odakle dolaze tvrdnje?', a: 'Iz istog pula opšteg znanja kao PRO kviz, pretvorenog u tačno/netačno format.' },
    ],
  },
}

const FAQ_ANCHOR_LINKS: { href: string; label: string }[] = [
  { href: '/igraj', label: 'PRO kviz' },
  { href: '/book-kviz', label: 'Book kviz' },
  { href: '/kafanski-kviz', label: 'Kafanski kviz' },
  { href: '/igraj-zajedno', label: 'Trivia duel' },
  { href: '/vesanje', label: 'Vešanje' },
  { href: '/brzi-kviz', label: 'Brzi kviz' },
]

export default function GameSeoContent({ game }: { game: GameKey }) {
  const c = COPY[game]
  const faqLd = {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: c.faq.map(f => ({
      '@type': 'Question',
      name: f.q,
      acceptedAnswer: { '@type': 'Answer', text: f.a },
    })),
  }

  return (
    <section className="max-w-2xl mx-auto px-4 sm:px-6 py-12 sm:py-16">
      <div className="text-[14px] leading-relaxed space-y-5" style={{ color: '#5a5a5a' }}>
        <h2 className="font-black tracking-tight" style={{ color: '#343434', fontSize: 'clamp(20px, 4vw, 28px)' }}>
          {c.h2}
        </h2>
        <p>{c.intro}</p>

        <h3 className="font-bold text-[16px] pt-2" style={{ color: '#343434' }}>{c.how.title}</h3>
        <p>{c.how.body}</p>

        <h3 className="font-bold text-[16px] pt-2" style={{ color: '#343434' }}>{c.topics.title}</h3>
        <p>{c.topics.body}</p>

        <h3 className="font-bold text-[16px] pt-2" style={{ color: '#343434' }}>{c.why.title}</h3>
        <p>{c.why.body}</p>

        <h3 className="font-bold text-[16px] pt-2" style={{ color: '#343434' }}>Često postavljana pitanja</h3>
        <div className="space-y-3">
          {c.faq.map((f, i) => (
            <div key={i}>
              <p className="font-semibold" style={{ color: '#343434' }}>{f.q}</p>
              <p>{f.a}</p>
            </div>
          ))}
        </div>

        <h3 className="font-bold text-[16px] pt-2" style={{ color: '#343434' }}>Ostale igre na Librum kvizu</h3>
        <p>
          Probaj i druge besplatne igre znanja:{' '}
          {FAQ_ANCHOR_LINKS.filter(l => COPY_KEY_FOR_HREF[l.href] !== game).map((l, i, arr) => (
            <span key={l.href}>
              <Link href={l.href} className="underline font-medium" style={{ color: '#609DED' }}>{l.label}</Link>
              {i < arr.length - 1 ? ', ' : '.'}
            </span>
          ))}{' '}
          Sve dele istu{' '}
          <Link href="/leaderboard" className="underline font-medium" style={{ color: '#609DED' }}>rang-listu</Link>{' '}
          i sistem bodova.
        </p>
      </div>

      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(faqLd) }}
      />
    </section>
  )
}

// Map landing href → game key so we can exclude the current game from
// the internal-link cluster (no self-link).
const COPY_KEY_FOR_HREF: Record<string, GameKey> = {
  '/igraj': 'pro',
  '/book-kviz': 'book',
  '/kafanski-kviz': 'kafana',
  '/igraj-zajedno': 'duel',
  '/vesanje': 'vesanje',
  '/brzi-kviz': 'brzi',
}
