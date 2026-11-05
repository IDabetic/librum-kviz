import Image from 'next/image'
import Link from 'next/link'
import Footer from '@/components/Footer'
import Header from '@/components/Header'
import { createClient } from '@/lib/supabase/server'
import { OsvajanjeVideo } from '@/components/OsvajanjeVideo'
import { KarijeraVideo } from '@/components/KarijeraVideo'
import { Prodavnice } from '@/components/Prodavnice'
import { Telefon } from '@/components/Telefon'

const faqSchema = {
  '@context': 'https://schema.org',
  '@type': 'FAQPage',
  mainEntity: [
    { '@type': 'Question', name: 'Šta je Librum kviz?', acceptedAnswer: { '@type': 'Answer', text: 'Librum kviz je besplatna aplikacija sa igrama znanja na srpskom, za iPhone i Android. Glavna igra je Osvajač, a tu je još šest igara: PRO kviz, Book kviz, Trivia duel, Slikari, Vešanje i Brzi kviz.' } },
    { '@type': 'Question', name: 'Kako se igra Osvajač?', acceptedAnswer: { '@type': 'Answer', text: 'Mapa ima 171 državu. Na početku poteza odgovaraš na pitanje i dobijaš vojske, pa napadaš susedne države; svaka bitka je jedno pitanje. Preko mora se ide samo morskim putevima. Ceo region donosi bonus vojske, a pobeđuje ko na kraju ima najviše poena.' } },
    { '@type': 'Question', name: 'Da li je Librum kviz besplatan?', acceptedAnswer: { '@type': 'Answer', text: 'Jeste — aplikacija i sve igre su besplatne. Nalog ti treba samo da bi se rezultati upisivali na rang listu; isti nalog važi i na sajtu.' } },
    { '@type': 'Question', name: 'Kako se igra PRO kviz?', acceptedAnswer: { '@type': 'Answer', text: 'PRO kviz je survival igra. Počinješ sa 10 života, svaki tačan odgovor donosi bodove i gradi kombo niz, a svaka greška skida jedan život. Igra traje dok imaš života.' } },
    { '@type': 'Question', name: 'Mogu li da igram protiv prijatelja?', acceptedAnswer: { '@type': 'Answer', text: 'Možeš. U aplikaciji: Trivia duel je igra za dva igrača — pokreneš sobu, pošalješ kod prijatelju i odmerite znanje na istim pitanjima u realnom vremenu.' } },
    { '@type': 'Question', name: 'Koje teme pokrivaju pitanja?', acceptedAnswer: { '@type': 'Answer', text: 'Opšte znanje, istorija, geografija, sport, nauka, film, muzika i književnost. Book kviz je posvećen isključivo književnosti i žanrovima.' } },
  ],
}

type RedRanga = { mesto: number; user_id: string; nadimak: string | null; avatar: string | null; poeni: number; partija: number }
type BrojeviPitanja = { kviz: number; knjige: number; kafana: number }

/** Ista rang lista kao u aplikaciji (RPC rang_lista_igre): Osvajač ove nedelje. */
const MESTA_NA_LISTI = 10

const IGRE = [
  { ime: 'PRO kviz', opis: 'Deset života, kombo nizovi, Risk i nedeljna rang lista.', boja: '#2C2D81', tekst: '#FFFFFF', slika: 'pro' },
  { ime: 'Book kviz', opis: 'Pisci, dela i likovi; 168 klasika sa svojim pitanjima.', boja: '#5DBF94', tekst: '#1A1B3A', slika: 'book' },
  { ime: 'Duel', opis: 'Jedan na jedan uživo ili izazov prijatelju sa profila.', boja: '#1A1B3A', tekst: '#FFFFFF', slika: 'duel' },
  { ime: 'Slikari', opis: 'Ko je naslikao ovo delo? 1.167 dela, od Leonarda do Pikasa.', boja: '#F8C7D6', tekst: '#1A1B3A', slika: 'slikari' },
  { ime: 'Brzi kviz', opis: 'Tačno ili netačno, 60 sekundi, niz množi poene.', boja: '#FDC361', tekst: '#1A1B3A', slika: 'brzi' },
  { ime: 'Vešanje', opis: 'Pogodi reč slovo po slovo, sa našom azbukom.', boja: '#3766B0', tekst: '#FFFFFF', slika: 'vesanje' },
]

const EKRANI_KARIJERE = [
  { slika: 'karijera-lobi', naslov: 'Tvoja karijera', opis: 'Pozicija, kapital, ugled i probni rad na jednom mestu.', alt: 'Karijerista: pozicija Junior Programer, kapital, ugled i probni rad' },
  { slika: 'karijera-grad', naslov: 'Grad firmi', opis: 'Svaka zgrada je firma pravog igrača; dodirni i vidi ko je vodi.', alt: 'Karijerista: izometrijski grad sa firmama igrača' },
  { slika: 'karijera-firma', naslov: 'Firma', opis: 'Rekord, plata, šef i asistenti; zaposli se ili preuzmi vlasništvo.', alt: 'Karijerista: firma Hrast Soft studio sa rekordom i platom' },
  { slika: 'karijera-runda', naslov: 'Runda', opis: 'Deset pitanja iz struke na sat, uz pomoć kad zapne.', alt: 'Karijerista: pitanje iz književnosti sa četiri ponuđena odgovora' },
]

const MOGUCNOSTI = [
  ['171 država', 'Prava mapa sveta sa 17 regiona; preko mora idu morski putevi.'],
  ['Šest vojski', 'Legija, Garda, Graditelji, Izvidnica, Konjica i Mudraci, svaka sa svojom moći u bitki: siguran udar, štit, zaustavljen sat, pola-pola, juriš ili tačan odgovor.'],
  ['Ratne karte', 'Špijun vidi odgovor, Pojačanje, Zamrzni granicu, Drugi pokušaj, Sabotaža.'],
  ['Savezi i izdaje', 'Brze poruke, savez do kraja kruga, ultimatum slabijem susedu.'],
  ['Teren i čuda', 'Planine brane, pustinja kažnjava; Piramide, Kineski zid, Akropolj…'],
  ['Do 12 igrača', 'Protiv računara, prijatelja ili mešano; timovi po dvoje.'],
]

export default async function Home() {
  const supabase = await createClient()
  // Nezavisni pozivi idu odjednom (funkcija je u fra1, baza u Frankfurtu; vidi vercel.json).
  const [{ data: brojevi }, { data: rang }] = await Promise.all([
    supabase.rpc('pitanja_u_igri'),
    supabase.rpc('rang_lista_igre', { p_igra: 'osvajanje', p_period: 'nedelja', p_broj: MESTA_NA_LISTI }),
  ])
  const b = (brojevi ?? null) as BrojeviPitanja | null
  const pitanja = b ? b.kviz + b.knjige + b.kafana : 0
  const lista = (rang ?? []) as RedRanga[]

  return (
    <div className="min-h-screen flex flex-col">
      <Header />

      <main className="flex-1">
        {/* Osvajač: naslov, prodavnice i snimak prave partije */}
        <section id="osvajanje" className="max-w-6xl mx-auto px-4 sm:px-6 pt-12 sm:pt-20 scroll-mt-24">
          <div className="grid lg:grid-cols-[1.25fr_0.75fr] gap-8 lg:gap-12 items-end">
            <div>
              <p className="chip mb-5" style={{ color: 'var(--ink-2)' }}>
                <span className="w-2 h-2 rounded-full animate-pulse" style={{ background: '#5DBF94' }} />
                {pitanja > 0 ? `${pitanja.toLocaleString('sr-RS')} pitanja u igri` : 'Aplikacija za iPhone i Android'}
              </p>
              <h1 style={{ fontSize: 'clamp(48px, 8vw, 104px)' }}>Osvoji svet <em>znanjem.</em></h1>
            </div>
            <div>
              <p className="text-[17px] leading-relaxed" style={{ color: 'var(--ink-2)' }}>
                Strategija u kojoj svaka bitka pada na pitanju. Vojske, ratne karte, savezi i izdaje na pravoj mapi sveta,
                protiv računara ili prijatelja, do 12 igrača.
              </p>
              <div className="mt-6"><Prodavnice /></div>
            </div>
          </div>
          <div className="mt-12"><OsvajanjeVideo /></div>
          <dl className="mt-10 grid grid-cols-2 sm:grid-cols-4">
            {[
              [pitanja > 0 ? pitanja.toLocaleString('sr-RS') : '150.000+', 'pitanja u bazi'],
              ['171', 'država na mapi'],
              ['8', 'igara znanja'],
              ['2–12', 'igrača u partiji'],
            ].map(([v, n], i) => (
              <div key={n} className={`py-4 sm:px-6 ${i > 0 ? 'sm:border-l' : ''} ${i % 2 ? 'pl-5 border-l sm:pl-6' : ''}`} style={{ borderColor: 'var(--line)' }}>
                <dt className="sr-only">{n}</dt>
                <dd className="naslov text-[32px] tabular-nums">{v}</dd>
                <dd className="text-[14px]" style={{ color: 'var(--ink-2)' }}>{n}</dd>
              </div>
            ))}
          </dl>
        </section>

        {/* Šta sve može Osvajač */}
        <section className="max-w-6xl mx-auto px-4 sm:px-6 pt-20 sm:pt-28">
          <p className="nadnaslov">Osvajač</p>
          <h2 className="mt-2" style={{ fontSize: 'clamp(32px, 5vw, 52px)' }}>Šta sve ima u igri</h2>
          <ul className="mt-10 grid sm:grid-cols-2 lg:grid-cols-3 gap-x-10">
            {MOGUCNOSTI.map(([n, t], i) => (
              <li key={n} className="py-6" style={{ borderTop: '1px solid var(--line)' }}>
                <p className="text-[13px] font-semibold tabular-nums" style={{ color: 'var(--ink-3)' }}>{String(i + 1).padStart(2, '0')}</p>
                <h3 className="mt-2 text-[22px]">{n}</h3>
                <p className="mt-2 text-[15px] leading-relaxed" style={{ color: 'var(--ink-2)' }}>{t}</p>
              </li>
            ))}
          </ul>
        </section>

        {/* Karijerista: snimak runde i ekrani iz aplikacije u telefonima */}
        <section id="karijerista" className="mt-20 sm:mt-28 scroll-mt-24" style={{ background: 'var(--bg-2)', borderTop: '1px solid var(--line)', borderBottom: '1px solid var(--line)' }}>
          <div className="max-w-6xl mx-auto px-4 sm:px-6 py-16 sm:py-24">
            <p className="nadnaslov">Nova igra</p>
            <h2 className="mt-2" style={{ fontSize: 'clamp(40px, 7vw, 84px)' }}>Karijerista</h2>
            <p className="mt-4 text-[17px] leading-relaxed max-w-2xl" style={{ color: 'var(--ink-2)' }}>
              Od probnog rada u Korporaciji do svog nebodera. Zaposli se u firmi drugog igrača, vodi svoju i čuvaj rekord, sve na pitanjima.
            </p>
            <div className="mt-12"><KarijeraVideo /></div>

            <h3 className="mt-20 text-[26px] sm:text-[30px]">Ekrani iz aplikacije</h3>
            <ul className="mt-8 -mx-4 px-4 sm:mx-0 sm:px-0 flex sm:grid sm:grid-cols-4 gap-5 sm:gap-6 overflow-x-auto snap-x snap-mandatory scroll-pl-4 sm:scroll-pl-0 pb-2 [scrollbar-width:none]" aria-label="Ekrani Karijeriste">
              {EKRANI_KARIJERE.map(e => (
                <li key={e.slika} className="snap-start shrink-0 w-[62vw] max-w-[260px] sm:w-auto sm:max-w-none">
                  <Telefon src={`/aplikacija/${e.slika}.jpg`} alt={e.alt} />
                  <p className="mt-4 font-semibold text-[16px]">{e.naslov}</p>
                  <p className="mt-1 text-[14px] leading-snug" style={{ color: 'var(--ink-2)' }}>{e.opis}</p>
                </li>
              ))}
            </ul>
            <div className="mt-10"><Prodavnice /></div>
          </div>
        </section>

        {/* Ostale igre */}
        <section id="igre" className="max-w-6xl mx-auto px-4 sm:px-6 pt-20 sm:pt-28 scroll-mt-24">
          <p className="nadnaslov">Igre</p>
          <h2 className="mt-2" style={{ fontSize: 'clamp(32px, 5vw, 52px)' }}>I još šest igara</h2>
          <p className="mt-3 text-[16px]" style={{ color: 'var(--ink-2)' }}>Svaka se igra sama ili sa drugima: do 8 igrača ili timovi, protiv računara ili prijatelja.</p>
          <div className="mt-10 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-5">
            {IGRE.map(g => (
              <div key={g.ime} className="card-soft p-6 flex items-start gap-5">
                <span className="shrink-0 w-[72px] h-[72px] rounded-2xl grid place-items-center" style={{ background: g.boja }}>
                  <Image src={`/ilustracije/${g.slika}.png`} alt="" width={56} height={56} aria-hidden style={{ width: 56, height: 'auto' }} />
                </span>
                <div>
                  <h3 className="text-[22px]">{g.ime}</h3>
                  <p className="mt-1.5 text-[15px] leading-snug" style={{ color: 'var(--ink-2)' }}>{g.opis}</p>
                </div>
              </div>
            ))}
          </div>
        </section>

        {/* Rang lista: ista kao u aplikaciji */}
        <section className="max-w-6xl mx-auto px-4 sm:px-6 pt-20 sm:pt-28">
          <div className="flex items-end justify-between mb-8 gap-4">
            <div>
              <p className="nadnaslov">Rang lista</p>
              <h2 className="mt-2" style={{ fontSize: 'clamp(32px, 5vw, 52px)' }}>Osvajači ove nedelje</h2>
            </div>
            <Link href="/ranglista" className="text-[15px] font-semibold shrink-0" style={{ color: 'var(--brand)' }}>Cela lista →</Link>
          </div>
          {lista.length > 0 ? (
            <ol className="card-soft divide-y divide-[var(--line)] overflow-hidden">
              {lista.map(r => (
                <li key={r.user_id} className="flex items-center gap-4 px-5 py-3.5">
                  <span className="w-9 h-9 grid place-items-center rounded-xl font-semibold tabular-nums"
                    style={r.mesto === 1 ? { background: '#FDC361', color: '#14152B' } : { background: 'var(--bg-2)', color: 'var(--ink-2)' }}>
                    {r.mesto}
                  </span>
                  <span className="flex-1 font-medium truncate">{r.nadimak || 'Igrač'}</span>
                  <span className="text-[13px] hidden sm:inline" style={{ color: 'var(--ink-3)' }}>{r.partija} partija</span>
                  <span className="naslov text-[20px] tabular-nums">{r.poeni.toLocaleString('sr-RS')}</span>
                </li>
              ))}
            </ol>
          ) : (
            <div className="card-soft p-8 flex items-center gap-5">
              <Image src="/maskote/Lumi.png" alt="" width={80} height={80} aria-hidden />
              <p className="text-[16px]" style={{ color: 'var(--ink-2)' }}>Rang lista se puni čim prve partije ove nedelje stignu iz aplikacije.</p>
            </div>
          )}
        </section>

        {/* Poziv na kraju */}
        <section className="px-4 sm:px-6 pt-20 sm:pt-28">
          <div className="max-w-6xl mx-auto rounded-[28px] p-8 sm:p-14 relative overflow-hidden" style={{ background: 'var(--istaknuto)', color: '#F2F2FA' }}>
            <Image src="/maskote/Zig.png" alt="" width={150} height={150} aria-hidden className="absolute right-6 bottom-0 hidden sm:block" />
            <h2 style={{ fontSize: 'clamp(32px, 5vw, 56px)' }}>Preuzmi i kreni u osvajanje.</h2>
            <p className="mt-3 text-[16px] max-w-xl" style={{ color: 'rgba(242,242,250,.75)' }}>Besplatno, bez reklama u toku igre. Jedan nalog za sve igre i rang listu.</p>
            <div className="mt-8"><Prodavnice tamno /></div>
          </div>
        </section>

        <section className="max-w-3xl mx-auto px-4 sm:px-6 pt-20 sm:pt-28 text-[15px] leading-[1.7]" style={{ color: 'var(--ink-2)' }}>
          <p className="nadnaslov">Česta pitanja</p>
          <h2 className="mt-2 mb-8" style={{ color: 'var(--ink)', fontSize: 'clamp(30px, 4vw, 40px)' }}>Pitanja</h2>
          {faqSchema.mainEntity.map(item => (
            <div key={item.name} className="py-6" style={{ borderTop: '1px solid var(--line)' }}>
              <h3 className="text-[19px] mb-2" style={{ color: 'var(--ink)' }}>{item.name}</h3>
              <p>{item.acceptedAnswer.text}</p>
            </div>
          ))}
        </section>
      </main>

      <Footer />

      <script id="ld-faq" type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(faqSchema) }} />
    </div>
  )
}
