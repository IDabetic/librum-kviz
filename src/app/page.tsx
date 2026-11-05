import Image from 'next/image'
import Link from 'next/link'
import Script from 'next/script'
import Footer from '@/components/Footer'
import Header from '@/components/Header'
import { createClient } from '@/lib/supabase/server'
import { OsvajanjeVideo } from '@/components/OsvajanjeVideo'
import { KarijeraVideo } from '@/components/KarijeraVideo'
import { Prodavnice } from '@/components/Prodavnice'

const faqSchema = {
  '@context': 'https://schema.org',
  '@type': 'FAQPage',
  mainEntity: [
    { '@type': 'Question', name: 'Šta je Librum kviz?', acceptedAnswer: { '@type': 'Answer', text: 'Librum kviz je besplatna aplikacija sa igrama znanja na srpskom, za iPhone i Android. Glavna igra je Osvajanje sveta, a tu je još šest igara: PRO kviz, Book kviz, Trivia duel, Slikari, Vešanje i Brzi kviz.' } },
    { '@type': 'Question', name: 'Kako se igra Osvajanje sveta?', acceptedAnswer: { '@type': 'Answer', text: 'Mapa ima 171 državu. Na početku poteza odgovaraš na pitanje i dobijaš vojske, pa napadaš susedne države; svaka bitka je jedno pitanje. Preko mora se ide samo morskim putevima. Ceo region donosi bonus vojske, a pobeđuje ko na kraju ima najviše poena.' } },
    { '@type': 'Question', name: 'Da li je Librum kviz besplatan?', acceptedAnswer: { '@type': 'Answer', text: 'Jeste — aplikacija i sve igre su besplatne. Nalog ti treba samo da bi se rezultati upisivali na rang listu; isti nalog važi i na sajtu.' } },
    { '@type': 'Question', name: 'Kako se igra PRO kviz?', acceptedAnswer: { '@type': 'Answer', text: 'PRO kviz je survival igra. Počinješ sa 10 života, svaki tačan odgovor donosi bodove i gradi kombo niz, a svaka greška skida jedan život. Igra traje dok imaš života.' } },
    { '@type': 'Question', name: 'Mogu li da igram protiv prijatelja?', acceptedAnswer: { '@type': 'Answer', text: 'Možeš. U aplikaciji: Trivia duel je igra za dva igrača — pokreneš sobu, pošalješ kod prijatelju i odmerite znanje na istim pitanjima u realnom vremenu.' } },
    { '@type': 'Question', name: 'Koje teme pokrivaju pitanja?', acceptedAnswer: { '@type': 'Answer', text: 'Opšte znanje, istorija, geografija, sport, nauka, film, muzika i književnost. Book kviz je posvećen isključivo književnosti i žanrovima.' } },
  ],
}

type RedRanga = { mesto: number; user_id: string; nadimak: string | null; avatar: string | null; poeni: number; partija: number }
type BrojeviPitanja = { kviz: number; knjige: number; kafana: number }

/** Ista rang lista kao u aplikaciji (RPC rang_lista_igre): Osvajanje sveta ove nedelje. */
const MESTA_NA_LISTI = 10

const IGRE = [
  { ime: 'PRO kviz', opis: 'Deset života, kombo nizovi, Risk i nedeljna rang lista.', boja: '#6D4BC9', tekst: '#FFFFFF', slika: 'pro' },
  { ime: 'Book kviz', opis: 'Pisci, dela i likovi; 168 klasika sa svojim pitanjima.', boja: '#F4A33C', tekst: '#151515', slika: 'book' },
  { ime: 'Duel', opis: 'Jedan na jedan uživo ili izazov prijatelju sa profila.', boja: '#151515', tekst: '#FFFFFF', slika: 'duel' },
  { ime: 'Slikari', opis: 'Ko je naslikao ovo delo? 1.167 dela, od Leonarda do Pikasa.', boja: '#FF5FA2', tekst: '#151515', slika: 'slikari' },
  { ime: 'Brzi kviz', opis: 'Tačno ili netačno, 60 sekundi, niz množi poene.', boja: '#FFD84D', tekst: '#151515', slika: 'brzi' },
  { ime: 'Vešanje', opis: 'Pogodi reč slovo po slovo, sa našom azbukom.', boja: '#6EC3F2', tekst: '#151515', slika: 'vesanje' },
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
        {/* Osvajanje sveta: snimak prave partije preko celog ekrana, natpis i zvuk */}
        <section id="osvajanje" style={{ background: 'radial-gradient(120% 90% at 70% 0%, #1B5E54 0%, #0E3B34 45%, #12110F 100%)', color: '#F3F0E6' }}>
          <div className="max-w-6xl mx-auto px-4 sm:px-6 pt-10 sm:pt-14 pb-16">
            <div className="grid lg:grid-cols-[1.2fr_0.8fr] gap-8 items-end">
              <div>
                <p className="chip mb-5" style={{ color: '#FFD84D', background: 'rgba(255,255,255,.08)' }}>
                  <span className="w-2 h-2 rounded-full animate-pulse" style={{ background: '#2FD27A' }} />
                  {pitanja > 0 ? `${pitanja.toLocaleString('sr-RS')} pitanja u igri` : 'Aplikacija za iPhone i Android'}
                </p>
                <h1 style={{ fontSize: 'clamp(46px, 8vw, 96px)', color: '#F3F0E6' }}>Osvoji svet <span style={{ color: '#FFD84D' }}>znanjem.</span></h1>
              </div>
              <div>
                <p className="text-[17px] leading-relaxed opacity-90">
                  Strategija u kojoj svaka bitka pada na pitanju. Vojske, ratne karte, savezi i izdaje na pravoj mapi sveta,
                  protiv računara ili prijatelja, do 12 igrača.
                </p>
                <div className="mt-6"><Prodavnice tamno /></div>
              </div>
            </div>
            <div className="mt-10"><OsvajanjeVideo /></div>
            <dl className="mt-8 grid grid-cols-2 sm:grid-cols-4 gap-3">
              {[
                [pitanja > 0 ? pitanja.toLocaleString('sr-RS') : '150.000+', 'pitanja u bazi'],
                ['171', 'država na mapi'],
                ['7', 'igara znanja'],
                ['2–12', 'igrača u partiji'],
              ].map(([v, n]) => (
                <div key={n} className="rounded-2xl px-5 py-4" style={{ background: 'rgba(255,255,255,.06)', border: '1.5px solid rgba(255,255,255,.14)' }}>
                  <dt className="sr-only">{n}</dt>
                  <dd className="naslov text-[28px] tabular-nums" style={{ color: '#FFD84D' }}>{v}</dd>
                  <dd className="text-[13px] font-semibold opacity-80">{n}</dd>
                </div>
              ))}
            </dl>
          </div>
        </section>

        {/* Šta sve može Osvajanje */}
        <section className="max-w-6xl mx-auto px-4 sm:px-6 pt-16">
          <h2 style={{ fontSize: 'clamp(30px, 5vw, 46px)' }}>Šta sve ima u Osvajanju</h2>
          <ul className="mt-7 grid sm:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-5">
            {MOGUCNOSTI.map(([n, t]) => (
              <li key={n} className="card-soft p-6">
                <h3 className="text-[22px]">{n}</h3>
                <p className="mt-2 text-[15px]" style={{ color: '#6F6C66' }}>{t}</p>
              </li>
            ))}
          </ul>
        </section>

        {/* Karijerista: snimak prave runde sa telefona, natpis i muzika */}
        <section id="karijerista" className="mt-16 scroll-mt-28" style={{ background: 'radial-gradient(120% 90% at 30% 0%, #2F5FD0 0%, #1B3C8F 50%, #12110F 100%)', color: '#F3F0E6' }}>
          <div className="max-w-6xl mx-auto px-4 sm:px-6 py-14 sm:py-16">
            <p className="text-[12px] font-bold uppercase tracking-widest mb-3" style={{ color: '#FFD84D' }}>Nova igra</p>
            <h2 style={{ fontSize: 'clamp(40px, 7vw, 80px)', color: '#F3F0E6' }}>Karijerista</h2>
            <p className="mt-3 text-[17px] leading-relaxed opacity-90 max-w-2xl">
              Od probnog rada u Korporaciji do svog nebodera. Zaposli se u firmi drugog igrača, vodi svoju i čuvaj rekord, sve na pitanjima.
            </p>
            <div className="mt-10"><KarijeraVideo /></div>
            <div className="mt-10"><Prodavnice tamno /></div>
          </div>
        </section>

        {/* Ostale igre */}
        <section id="igre" className="max-w-6xl mx-auto px-4 sm:px-6 pt-16 scroll-mt-28">
          <h2 style={{ fontSize: 'clamp(30px, 5vw, 46px)' }}>I još šest igara</h2>
          <p className="mt-2 text-[16px]" style={{ color: '#6F6C66' }}>Svaka se igra sama ili sa drugima: do 8 igrača ili timovi, protiv računara ili prijatelja.</p>
          <div className="mt-7 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-5">
            {IGRE.map(g => (
              <div key={g.ime} className="card-pop relative overflow-hidden min-h-[170px] p-5 flex flex-col justify-end" style={{ background: g.boja, color: g.tekst }}>
                <Image src={`/ilustracije/${g.slika}.png`} alt="" width={92} height={92} aria-hidden className="absolute right-3 top-3" />
                <h3 className="text-[26px] relative">{g.ime}</h3>
                <p className="relative mt-1 text-[14px] font-semibold opacity-85 max-w-[85%]">{g.opis}</p>
              </div>
            ))}
          </div>
        </section>

        {/* Rang lista: ista kao u aplikaciji */}
        <section className="max-w-6xl mx-auto px-4 sm:px-6 pt-16">
          <div className="flex items-baseline justify-between mb-4 gap-4">
            <h2 style={{ fontSize: 'clamp(30px, 5vw, 46px)' }}>Osvajači ove nedelje</h2>
            <Link href="/ranglista" className="text-[15px] font-bold underline underline-offset-4 shrink-0">Cela rang lista</Link>
          </div>
          {lista.length > 0 ? (
            <ol className="card-soft divide-y divide-[#E7E1D0]">
              {lista.map(r => (
                <li key={r.user_id} className="flex items-center gap-4 px-5 py-3.5">
                  <span className="w-9 h-9 grid place-items-center rounded-xl font-bold tabular-nums"
                    style={{ background: r.mesto === 1 ? '#FFD84D' : '#F3F0E6', border: r.mesto === 1 ? '2px solid #151515' : 'none', color: '#151515' }}>
                    {r.mesto}
                  </span>
                  <span className="flex-1 font-semibold truncate">{r.nadimak || 'Igrač'}</span>
                  <span className="text-[13px] hidden sm:inline" style={{ color: '#6F6C66' }}>{r.partija} partija</span>
                  <span className="naslov text-[20px] tabular-nums">{r.poeni.toLocaleString('sr-RS')}</span>
                </li>
              ))}
            </ol>
          ) : (
            <div className="card-soft p-8 flex items-center gap-5">
              <Image src="/maskote/Lumi.png" alt="" width={80} height={80} aria-hidden />
              <p className="text-[16px]" style={{ color: '#6F6C66' }}>Rang lista se puni čim prve partije ove nedelje stignu iz aplikacije.</p>
            </div>
          )}
        </section>

        {/* Poziv na kraju */}
        <section className="px-4 sm:px-6 pt-16 pb-6">
          <div className="max-w-6xl mx-auto card-pop p-8 sm:p-12 relative overflow-hidden" style={{ background: '#151515', color: '#F3F0E6' }}>
            <Image src="/maskote/Zig.png" alt="" width={150} height={150} aria-hidden className="absolute right-4 bottom-0 hidden sm:block" />
            <h2 style={{ fontSize: 'clamp(32px, 5vw, 52px)' }}>Preuzmi i kreni u osvajanje.</h2>
            <p className="mt-3 text-[16px] opacity-80 max-w-xl">Besplatno, bez reklama u toku igre. Jedan nalog za sve igre i rang listu.</p>
            <div className="mt-7"><Prodavnice tamno /></div>
          </div>
        </section>

        <section className="max-w-3xl mx-auto px-4 sm:px-6 py-16 text-[15px] leading-[1.7] space-y-5" style={{ color: '#6F6C66' }}>
          <h2 className="mb-2" style={{ color: '#151515', fontSize: 'clamp(26px, 4vw, 34px)' }}>Pitanja</h2>
          {faqSchema.mainEntity.map(item => (
            <div key={item.name} className="py-5" style={{ borderTop: '1.5px solid #E7E1D0' }}>
              <h3 className="text-[19px] mb-2" style={{ color: '#151515' }}>{item.name}</h3>
              <p>{item.acceptedAnswer.text}</p>
            </div>
          ))}
        </section>
      </main>

      <Footer />

      <Script id="ld-faq" type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(faqSchema) }} />
    </div>
  )
}
