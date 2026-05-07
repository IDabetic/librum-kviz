import Link from 'next/link'
import Script from 'next/script'
import { IconDiscover, IconSwords, IconTrophy, IconStar } from '@/components/icons'
import { Logo } from '@/components/Logo'
import Footer from '@/components/Footer'

const faqSchema = {
  '@context': 'https://schema.org',
  '@type': 'FAQPage',
  mainEntity: [
    {
      '@type': 'Question',
      name: 'Šta je Librum kviz?',
      acceptedAnswer: {
        '@type': 'Answer',
        text: 'Librum kviz je besplatna platforma za kratke igre znanja na srpskom — PRO kviz, Trivia duel, Vešanje i Brzi kviz. Pitanja pokrivaju književnost, istoriju, geografiju, sport, kulturu, prirodu i opšte znanje.',
      },
    },
    {
      '@type': 'Question',
      name: 'Kako se igra PRO kviz?',
      acceptedAnswer: {
        '@type': 'Answer',
        text: 'PRO kviz je survival igra. Počinješ sa 10 života, svaki tačan odgovor donosi bodove, svaka greška skida život. Igra traje dok imaš živote.',
      },
    },
    {
      '@type': 'Question',
      name: 'Da li je Librum kviz besplatan?',
      acceptedAnswer: { '@type': 'Answer', text: 'Da, Librum kviz je besplatan za igranje.' },
    },
    {
      '@type': 'Question',
      name: 'Mogu li da igram protiv prijatelja?',
      acceptedAnswer: {
        '@type': 'Answer',
        text: 'Možeš. Trivia duel je igra za dva igrača — pokreneš sobu, pošalješ link prijatelju i odmerite znanje na istim pitanjima.',
      },
    },
  ],
}

const features = [
  { Icon: IconDiscover, title: 'Bogata baza pitanja',  desc: 'Hiljade pitanja iz svih oblasti — od književnosti do sporta.' },
  { Icon: IconSwords,   title: 'Igraj sa prijateljem', desc: 'Izazovi prijatelja u realnom vremenu i vidi ko zna više.' },
  { Icon: IconTrophy,   title: 'Penji se na vrh',      desc: 'Skupljaj poene i postani prvak rang liste.' },
]

export default function Home() {
  return (
    <div className="min-h-screen flex flex-col" style={{ background: '#FAFAFA' }}>
      {/* ── Top bar ──────────────────────────────────────────────── */}
      <nav className="sticky top-0 z-40 backdrop-blur-xl"
        style={{ background: 'rgba(252,252,252,0.78)', borderBottom: '1px solid rgba(52,52,52,0.06)' }}>
        <div className="max-w-6xl mx-auto px-4 sm:px-6 h-16 flex items-center justify-between">
          <Logo height={28} priority />
          <div className="flex items-center gap-2">
            <Link href="/auth/prijava" className="btn btn-ghost btn-sm">Prijava</Link>
            <Link href="/auth/registracija" className="btn btn-primary btn-sm">Registracija</Link>
          </div>
        </div>
      </nav>

      {/* ── Hero ─────────────────────────────────────────────────── */}
      <section className="relative pt-20 pb-24 sm:pt-32 sm:pb-32 px-4 sm:px-6 overflow-hidden">
        {/* Subtle ambient blobs */}
        <div className="absolute inset-0 pointer-events-none">
          <div className="absolute top-20 -right-20 w-[420px] h-[420px] rounded-full opacity-40"
            style={{ background: 'radial-gradient(circle, #BCD9FF 0%, transparent 70%)' }} />
          <div className="absolute -bottom-20 -left-20 w-[420px] h-[420px] rounded-full opacity-35"
            style={{ background: 'radial-gradient(circle, #FFECBC 0%, transparent 70%)' }} />
        </div>

        <div className="relative max-w-4xl mx-auto text-center">
          <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full mb-7"
            style={{ background: '#FFECBC', color: '#9c7a13' }}>
            <IconStar size={14} strokeWidth={2.5} />
            <span className="text-[12px] font-semibold tracking-tight">Kviz platforma za radoznale</span>
          </div>

          <h1 className="font-black tracking-tight leading-[1.05] mb-6"
            style={{ color: '#343434', fontSize: 'clamp(40px, 8vw, 88px)' }}>
            Testiraj svoje<br />
            <span style={{ color: '#609DED' }}>znanje.</span>
          </h1>

          <p className="text-[16px] sm:text-[18px] max-w-xl mx-auto mb-10 leading-relaxed"
            style={{ color: '#9C9C9C' }}>
            Hiljade pitanja iz književnosti, istorije, sporta i kulture.
            Igraj sam ili izazovi prijatelja.
          </p>

          <div className="flex flex-col sm:flex-row gap-3 justify-center items-center">
            <Link href="/auth/registracija" className="btn btn-primary btn-lg w-full sm:w-auto sm:min-w-[200px]">
              Počni besplatno
            </Link>
            <Link href="/auth/prijava" className="btn btn-secondary btn-lg w-full sm:w-auto sm:min-w-[200px]">
              Prijavi se
            </Link>
          </div>
        </div>
      </section>

      {/* ── Stats strip ──────────────────────────────────────────── */}
      <section className="py-10 px-4 sm:px-6">
        <div className="max-w-4xl mx-auto card-soft px-6 sm:px-12 py-8">
          <div className="grid grid-cols-3 gap-4 text-center">
            {[
              { num: '25k+', label: 'Pitanja' },
              { num: '7',    label: 'Kategorija' },
              { num: '∞',    label: 'Radoznalosti' },
            ].map(({ num, label }) => (
              <div key={label}>
                <div className="font-black tracking-tight mb-1" style={{ color: '#343434', fontSize: 'clamp(28px, 5vw, 40px)' }}>
                  {num}
                </div>
                <div className="text-[12px] sm:text-[13px] font-medium" style={{ color: '#9C9C9C' }}>{label}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ── Features ─────────────────────────────────────────────── */}
      <section className="py-16 sm:py-24 px-4 sm:px-6">
        <div className="max-w-5xl mx-auto">
          <div className="text-center mb-14">
            <p className="text-[13px] font-bold uppercase tracking-widest mb-3" style={{ color: '#609DED' }}>
              Zašto Librum
            </p>
            <h2 className="font-black tracking-tight mb-4 leading-[1.1]"
              style={{ color: '#343434', fontSize: 'clamp(30px, 5vw, 48px)' }}>
              Sve što ti treba<br />za testiranje znanja.
            </h2>
          </div>

          <div className="grid md:grid-cols-3 gap-4">
            {features.map(({ Icon, title, desc }) => (
              <div key={title} className="card-soft p-7 transition-all hover:-translate-y-1">
                <div className="w-12 h-12 rounded-2xl flex items-center justify-center mb-5"
                  style={{ background: '#BCD9FF', color: '#343434' }}>
                  <Icon size={22} strokeWidth={2.2} />
                </div>
                <h3 className="font-bold text-[17px] mb-2 tracking-tight" style={{ color: '#343434' }}>
                  {title}
                </h3>
                <p className="text-[14px] leading-relaxed" style={{ color: '#9C9C9C' }}>
                  {desc}
                </p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ── How it works ─────────────────────────────────────────── */}
      <section className="py-16 sm:py-24 px-4 sm:px-6" style={{ background: '#F2F2F2' }}>
        <div className="max-w-5xl mx-auto">
          <div className="text-center mb-14">
            <p className="text-[13px] font-bold uppercase tracking-widest mb-3" style={{ color: '#609DED' }}>
              Tri koraka
            </p>
            <h2 className="font-black tracking-tight" style={{ color: '#343434', fontSize: 'clamp(30px, 5vw, 48px)' }}>
              Jednostavno i brzo.
            </h2>
          </div>

          <div className="grid md:grid-cols-3 gap-6">
            {[
              { n: '01', t: 'Registruj se',     d: 'Napravi nalog za 10 sekundi. Ime, email, lozinka.' },
              { n: '02', t: 'Odaberi kviz',      d: 'Sport, istorija, geografija ili miks svega.' },
              { n: '03', t: 'Skupljaj poene',    d: 'Igraj nivoe, pobedi prijatelje, idi na vrh liste.' },
            ].map(({ n, t, d }) => (
              <div key={n} className="relative">
                <div className="font-black mb-4 leading-none tracking-tight" style={{ color: '#BCD9FF', fontSize: '64px' }}>
                  {n}
                </div>
                <h3 className="font-bold text-[18px] mb-2 tracking-tight" style={{ color: '#343434' }}>{t}</h3>
                <p className="text-[14px] leading-relaxed" style={{ color: '#9C9C9C' }}>{d}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ── CTA ──────────────────────────────────────────────────── */}
      <section className="py-20 px-4 sm:px-6">
        <div className="max-w-3xl mx-auto card-soft px-8 sm:px-16 py-14 text-center relative overflow-hidden"
          style={{ background: '#343434', borderColor: '#343434' }}>
          <div className="absolute -top-16 -right-16 w-64 h-64 rounded-full opacity-20"
            style={{ background: '#FFCB46' }} />
          <div className="relative">
            <h2 className="font-black tracking-tight mb-4 leading-[1.1]"
              style={{ color: '#FCFCFC', fontSize: 'clamp(28px, 5vw, 44px)' }}>
              Spreman za izazov?
            </h2>
            <p className="mb-8 text-[15px] sm:text-[17px] max-w-md mx-auto" style={{ color: 'rgba(252,252,252,0.65)' }}>
              Registruj se besplatno i odmah igraj prvi kviz.
            </p>
            <Link href="/auth/registracija" className="btn btn-yellow btn-lg">
              Kreni odmah
            </Link>
          </div>
        </div>
      </section>

      {/* SEO intro paragraph */}
      <section className="py-12 px-4 sm:px-6">
        <div className="max-w-3xl mx-auto">
          <h2 className="font-bold text-[18px] mb-4 tracking-tight" style={{ color: '#343434' }}>
            Igre znanja iz svih oblasti
          </h2>
          <div className="space-y-3 text-[14px] leading-relaxed" style={{ color: '#9C9C9C' }}>
            <p>
              Librum kviz je besplatna platforma za kratke igre znanja na srpskom jeziku. Namenjen je svima koji vole
              književnost, istoriju, geografiju, sport, kulturu, prirodu i opšte znanje.
            </p>
            <p>
              Možeš da igraš <strong>PRO kviz</strong> i proveriš koliko daleko možeš da doguraš sa 10 života, da
              izazoveš prijatelja u <strong>Trivia duelu</strong>, da pogađaš skrivene reči u igri <strong>Vešanje</strong> ili
              da testiraš brzinu kroz <strong>Brzi kviz</strong> sa tvrdnjama tačno/netačno.
            </p>
            <p>
              Svaka runda traje kratko, ali svako pitanje donosi priliku da naučiš nešto novo. Rezultati se beleže na
              zajedničkoj <Link href="/leaderboard" style={{ color: '#609DED' }}>rang-listi</Link>, a ako imaš zanimljivo
              pitanje — možeš ga <Link href="/predlozi-pitanje" style={{ color: '#609DED' }}>predložiti</Link> i postati
              deo baze.
            </p>
          </div>
        </div>
      </section>

      <Footer />

      <Script id="ld-faq" type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(faqSchema) }} />
    </div>
  )
}
