import Link from 'next/link'
import Image from 'next/image'
import Script from 'next/script'
import { IconStar } from '@/components/icons'
import { Logo } from '@/components/Logo'
import Footer from '@/components/Footer'
import Header from '@/components/Header'
import { createClient } from '@/lib/supabase/server'

const faqSchema = {
  '@context': 'https://schema.org',
  '@type': 'FAQPage',
  mainEntity: [
    { '@type': 'Question', name: 'Šta je Librum kviz?', acceptedAnswer: { '@type': 'Answer', text: 'Librum kviz je besplatna platforma za kratke igre znanja na srpskom — PRO kviz, Trivia duel, Vešanje i Brzi kviz. Pitanja pokrivaju književnost, istoriju, geografiju, sport, kulturu, prirodu i opšte znanje.' } },
    { '@type': 'Question', name: 'Kako se igra PRO kviz?', acceptedAnswer: { '@type': 'Answer', text: 'PRO kviz je survival igra. Počinješ sa 10 života, svaki tačan odgovor donosi bodove, svaka greška skida život. Igra traje dok imaš živote.' } },
    { '@type': 'Question', name: 'Da li je Librum kviz besplatan?', acceptedAnswer: { '@type': 'Answer', text: 'Da, Librum kviz je besplatan za igranje.' } },
    { '@type': 'Question', name: 'Mogu li da igram protiv prijatelja?', acceptedAnswer: { '@type': 'Answer', text: 'Možeš. Trivia duel je igra za dva igrača — pokreneš sobu, pošalješ link prijatelju i odmerite znanje na istim pitanjima.' } },
  ],
}

const GAMES = [
  { href: '/igraj',          label: 'PRO kviz',       emoji: '🎯', desc: 'Survival, lifelines',     gradient: 'linear-gradient(135deg, #BCD9FF 0%, #609DED 100%)', accent: '#1e5fa4' },
  { href: '/book-kviz',      label: 'Book kviz',      emoji: '📚', desc: 'Književnost po žanru',     gradient: 'linear-gradient(135deg, #FFECBC 0%, #FFCB46 100%)', accent: '#9c7a13' },
  { href: '/kafanski-kviz',  label: 'Kafanski kviz',  emoji: '🎵', desc: 'Muzika i hitovi',          gradient: 'linear-gradient(135deg, #FEE2E2 0%, #E55353 100%)', accent: '#b91c1c' },
  { href: '/igraj-zajedno',  label: 'Trivia duel',    emoji: '⚔️', desc: 'Jedan na jedan',           gradient: 'linear-gradient(135deg, #FFCB46 0%, #FFECBC 100%)', accent: '#9c7a13' },
  { href: '/vesanje',        label: 'Vešanje',        emoji: '🪢', desc: 'Pogađaj slovo',            gradient: 'linear-gradient(135deg, #E8F8F0 0%, #4CAF50 100%)', accent: '#15803d' },
  { href: '/brzi-kviz',      label: 'Brzi kviz',      emoji: '⚡', desc: 'Tačno/netačno, 60s',      gradient: 'linear-gradient(135deg, #FEE2E2 0%, #b91c1c 100%)', accent: '#b91c1c' },
]

type LeaderRow = {
  user_id: string
  score: number
  questions_reached: number
  // Resolved client-side from public_profiles (we don't embed profiles
  // anymore — that table is locked down for anon).
  profile?: { first_name: string | null; nickname: string | null; avatar: string | null } | null
}

export default async function Home() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  // Top 5 PRO scores in the last 7 days — gives anonymous visitors a
  // taste of what's waiting after registration. Falls back to all-time
  // top 5 if nobody played this week. Server component runs once per
  // request, so Date.now() here is safe — purity rule fires defensively.
  // eslint-disable-next-line react-hooks/purity
  const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString()
  let { data: top } = await supabase
    .from('survivor_sessions')
    .select('user_id, score, questions_reached')
    .gte('created_at', sevenDaysAgo)
    .order('score', { ascending: false })
    .limit(20)
  if (!top || top.length === 0) {
    const fallback = await supabase
      .from('survivor_sessions')
      .select('user_id, score, questions_reached')
      .order('score', { ascending: false })
      .limit(20)
    top = fallback.data ?? []
  }
  // Dedupe by user (each player's best entry only) and take top 5.
  const seenUsers = new Set<string>()
  const dedup: LeaderRow[] = []
  for (const r of (top ?? []) as LeaderRow[]) {
    if (!r.user_id || seenUsers.has(r.user_id)) continue
    seenUsers.add(r.user_id)
    dedup.push(r)
    if (dedup.length >= 5) break
  }
  // Resolve display info from public_profiles (safe view — no email,
  // no role). Anon visitors hit this code path too.
  const topIds = dedup.map(r => r.user_id)
  const { data: profs } = topIds.length
    ? await supabase
        .from('public_profiles')
        .select('id, first_name, nickname, avatar')
        .in('id', topIds)
    : { data: [] as { id: string; first_name: string | null; nickname: string | null; avatar: string | null }[] }
  const profMap = new Map((profs ?? []).map(p => [p.id, p]))
  const leaderboard: LeaderRow[] = dedup.map(r => ({
    ...r,
    profile: profMap.get(r.user_id)
      ? { first_name: profMap.get(r.user_id)!.first_name, nickname: profMap.get(r.user_id)!.nickname, avatar: profMap.get(r.user_id)!.avatar }
      : null,
  }))

  return (
    <div className="min-h-screen flex flex-col" style={{ background: '#FAFAFA' }}>
      {user ? (
        <Header />
      ) : (
        <nav className="sticky top-0 z-40 backdrop-blur-xl"
          style={{ background: 'rgba(252,252,252,0.78)', borderBottom: '1px solid rgba(52,52,52,0.06)' }}>
          <div className="max-w-6xl mx-auto px-4 sm:px-6 h-16 flex items-center justify-between">
            <Logo height={36} priority />
            <div className="flex items-center gap-2">
              <Link href="/auth/prijava" className="btn btn-ghost btn-sm">Prijava</Link>
              <Link href="/auth/registracija" className="btn btn-primary btn-sm">Registracija</Link>
            </div>
          </div>
        </nav>
      )}

      {/* ── Hero ─────────────────────────────────────────────────── */}
      <section className="relative pt-16 pb-20 sm:pt-24 sm:pb-28 px-4 sm:px-6 overflow-hidden">
        {/* Bigger, brighter ambient blobs for that playful first impression */}
        <div className="absolute inset-0 pointer-events-none">
          <div className="absolute top-10 -right-32 w-[480px] h-[480px] rounded-full opacity-50"
            style={{ background: 'radial-gradient(circle, #BCD9FF 0%, transparent 70%)' }} />
          <div className="absolute -bottom-32 -left-32 w-[520px] h-[520px] rounded-full opacity-50"
            style={{ background: 'radial-gradient(circle, #FFECBC 0%, transparent 70%)' }} />
          <div className="absolute top-1/2 left-1/3 w-[300px] h-[300px] rounded-full opacity-30"
            style={{ background: 'radial-gradient(circle, #FEE2E2 0%, transparent 70%)' }} />
        </div>

        <div className="relative max-w-4xl mx-auto text-center">
          <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full mb-7"
            style={{ background: '#FFECBC', color: '#9c7a13' }}>
            <IconStar size={14} strokeWidth={2.5} />
            <span className="text-[12px] font-semibold tracking-tight">6 igara · hiljade pitanja · besplatno</span>
          </div>

          <h1 className="font-black tracking-tight leading-[1.02] mb-6"
            style={{ color: '#343434', fontSize: 'clamp(44px, 9vw, 96px)' }}>
            Igraj. Saznaj.<br />
            <span style={{ color: '#609DED' }}>Pobeđuj.</span>
          </h1>

          <p className="text-[16px] sm:text-[19px] max-w-xl mx-auto mb-10 leading-relaxed"
            style={{ color: '#343434', opacity: 0.7 }}>
            Hiljade pitanja iz književnosti, istorije, muzike, sporta i kulture.<br className="hidden sm:block" />
            Sam protiv vremena ili izazovi prijatelja u realnom vremenu.
          </p>

          <div className="flex flex-col sm:flex-row gap-3 justify-center items-center">
            {user ? (
              <>
                <Link href="/igre" className="btn btn-primary btn-lg w-full sm:w-auto sm:min-w-[200px]">
                  Igraj sada
                </Link>
                <Link href="/leaderboard" className="btn btn-secondary btn-lg w-full sm:w-auto sm:min-w-[200px]">
                  Rang lista
                </Link>
              </>
            ) : (
              <>
                <Link href="/auth/registracija" className="btn btn-primary btn-lg w-full sm:w-auto sm:min-w-[200px]">
                  Počni besplatno
                </Link>
                <Link href="/auth/prijava" className="btn btn-secondary btn-lg w-full sm:w-auto sm:min-w-[200px]">
                  Imam nalog
                </Link>
              </>
            )}
          </div>
        </div>
      </section>

      {/* ── Games showcase ──────────────────────────────────────── */}
      <section className="py-12 sm:py-16 px-4 sm:px-6">
        <div className="max-w-6xl mx-auto">
          <div className="text-center mb-10">
            <p className="text-[13px] font-bold uppercase tracking-widest mb-2" style={{ color: '#609DED' }}>
              Šest igara, šest izazova
            </p>
            <h2 className="font-black tracking-tight leading-[1.05]"
              style={{ color: '#343434', fontSize: 'clamp(30px, 5vw, 44px)' }}>
              Izaberi svoj kviz.
            </h2>
          </div>

          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3 sm:gap-4">
            {GAMES.map(g => (
              <Link key={g.href}
                href={user ? g.href : `/auth/registracija?redirect=${g.href}`}
                className="card-soft overflow-hidden group transition-transform hover:scale-[1.03]">
                <div className="h-24 sm:h-28 flex items-center justify-center" style={{ background: g.gradient }}>
                  <span className="text-[42px] sm:text-[48px] leading-none" aria-hidden>{g.emoji}</span>
                </div>
                <div className="p-3 sm:p-4 text-center">
                  <p className="font-black tracking-tight text-[13px] sm:text-[14px]" style={{ color: g.accent }}>
                    {g.label}
                  </p>
                  <p className="text-[10px] sm:text-[11px] mt-0.5" style={{ color: '#9C9C9C' }}>{g.desc}</p>
                </div>
              </Link>
            ))}
          </div>
        </div>
      </section>

      {/* ── Mini leaderboard ────────────────────────────────────── */}
      <section className="py-12 sm:py-16 px-4 sm:px-6" style={{ background: '#F2F2F2' }}>
        <div className="max-w-3xl mx-auto">
          <div className="text-center mb-8">
            <p className="text-[13px] font-bold uppercase tracking-widest mb-2" style={{ color: '#9c7a13' }}>
              Najbolji ove nedelje
            </p>
            <h2 className="font-black tracking-tight leading-[1.05]"
              style={{ color: '#343434', fontSize: 'clamp(28px, 5vw, 40px)' }}>
              {user ? 'Penji se ka vrhu.' : 'Možeš li da ih sustigneš?'}
            </h2>
          </div>

          {leaderboard.length === 0 ? (
            <div className="card-soft p-10 text-center">
              <div className="text-5xl mb-4">🎯</div>
              <p className="font-bold text-[16px] mb-2" style={{ color: '#343434' }}>Rang lista čeka prvog igrača</p>
              <p className="text-[13px] mb-5" style={{ color: '#9C9C9C' }}>Budi prvi koji će postaviti rekord.</p>
              <Link href={user ? '/igraj' : '/auth/registracija'} className="btn btn-primary btn-md">
                {user ? 'Igraj PRO' : 'Registruj se'}
              </Link>
            </div>
          ) : (
            <>
              <div className="card-soft overflow-hidden">
                <div className="divide-y" style={{ borderColor: '#F2F2F2' }}>
                  {leaderboard.map((r, i) => {
                    const prof = r.profile
                    const name = prof?.nickname || prof?.first_name || 'Igrač'
                    const medals = ['🥇', '🥈', '🥉']
                    return (
                      <div key={r.user_id} className="flex items-center gap-3 px-5 py-3.5">
                        <span className="w-8 text-center flex-shrink-0">
                          {i < 3
                            ? <span className="text-lg">{medals[i]}</span>
                            : <span className="text-[14px] font-bold" style={{ color: '#9C9C9C' }}>{i + 1}</span>}
                        </span>
                        <div className="w-10 h-10 rounded-2xl overflow-hidden flex-shrink-0 flex items-center justify-center font-bold text-white"
                          style={{ background: '#609DED' }}>
                          {prof?.avatar
                            ? <Image src={`/avatars/${prof.avatar}`} alt={name} width={40} height={40} className="w-full h-full object-cover" />
                            : <span className="text-[14px]">{name[0]?.toUpperCase()}</span>}
                        </div>
                        <div className="flex-1 min-w-0">
                          <p className="font-semibold text-[14px] truncate" style={{ color: '#343434' }}>{name}</p>
                          <p className="text-[12px]" style={{ color: '#9C9C9C' }}>
                            {r.questions_reached} pitanja
                          </p>
                        </div>
                        <div className="text-right flex-shrink-0">
                          <div className="font-black text-[18px] tracking-tight" style={{ color: '#343434' }}>{r.score}</div>
                          <div className="text-[11px]" style={{ color: '#9C9C9C' }}>bodova</div>
                        </div>
                      </div>
                    )
                  })}
                </div>
              </div>

              <div className="mt-5 text-center">
                {user ? (
                  <Link href="/leaderboard" className="btn btn-secondary btn-md">
                    Cela rang lista →
                  </Link>
                ) : (
                  <Link href="/auth/registracija" className="btn btn-primary btn-md">
                    Pridruži se i bori za vrh
                  </Link>
                )}
              </div>
            </>
          )}
        </div>
      </section>

      {/* ── Stats strip ──────────────────────────────────────────── */}
      <section className="py-12 px-4 sm:px-6">
        <div className="max-w-4xl mx-auto card-soft px-6 sm:px-12 py-10"
          style={{ background: 'linear-gradient(135deg, #FFECBC 0%, #FCFCFC 50%, #BCD9FF 100%)' }}>
          <div className="grid grid-cols-3 gap-4 text-center">
            {[
              { num: '5k+',  label: 'Pitanja u bazi' },
              { num: '6',    label: 'Različitih igara' },
              { num: '100%', label: 'Besplatno' },
            ].map(({ num, label }) => (
              <div key={label}>
                <div className="font-black tracking-tight mb-1" style={{ color: '#343434', fontSize: 'clamp(28px, 5vw, 44px)' }}>
                  {num}
                </div>
                <div className="text-[12px] sm:text-[13px] font-medium" style={{ color: '#343434', opacity: 0.65 }}>{label}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ── How it works ─────────────────────────────────────────── */}
      <section className="py-16 sm:py-20 px-4 sm:px-6" style={{ background: '#F2F2F2' }}>
        <div className="max-w-5xl mx-auto">
          <div className="text-center mb-12">
            <p className="text-[13px] font-bold uppercase tracking-widest mb-3" style={{ color: '#609DED' }}>
              Tri koraka
            </p>
            <h2 className="font-black tracking-tight" style={{ color: '#343434', fontSize: 'clamp(28px, 5vw, 44px)' }}>
              Jednostavno i brzo.
            </h2>
          </div>

          <div className="grid md:grid-cols-3 gap-6">
            {[
              { n: '01', emoji: '✍️', t: 'Registruj se',  d: 'Ime, email, lozinka. 10 sekundi.' },
              { n: '02', emoji: '🎮', t: 'Odaberi igru',  d: 'Šest različitih kvizova — sam ili sa prijateljem.' },
              { n: '03', emoji: '🏆', t: 'Skupljaj poene', d: 'Penji se rang listom i uskoro nagrade.' },
            ].map(({ n, emoji, t, d }) => (
              <div key={n} className="card-soft p-7 text-center transition-transform hover:-translate-y-1">
                <div className="text-5xl mb-4">{emoji}</div>
                <p className="font-black tracking-tight mb-2 text-[12px] uppercase tracking-widest" style={{ color: '#609DED' }}>
                  Korak {n}
                </p>
                <h3 className="font-bold text-[18px] mb-2 tracking-tight" style={{ color: '#343434' }}>{t}</h3>
                <p className="text-[14px] leading-relaxed" style={{ color: '#9C9C9C' }}>{d}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ── CTA ──────────────────────────────────────────────────── */}
      {!user && (
        <section className="py-20 px-4 sm:px-6">
          <div className="max-w-3xl mx-auto card-soft px-8 sm:px-16 py-14 text-center relative overflow-hidden"
            style={{ background: 'linear-gradient(135deg, #343434 0%, #1e5fa4 100%)', borderColor: '#343434' }}>
            <div className="absolute -top-16 -right-16 w-64 h-64 rounded-full opacity-25"
              style={{ background: '#FFCB46' }} />
            <div className="absolute -bottom-20 -left-20 w-72 h-72 rounded-full opacity-20"
              style={{ background: '#E55353' }} />
            <div className="relative">
              <h2 className="font-black tracking-tight mb-4 leading-[1.05]"
                style={{ color: '#FCFCFC', fontSize: 'clamp(28px, 5vw, 48px)' }}>
                Spreman za izazov?
              </h2>
              <p className="mb-8 text-[15px] sm:text-[17px] max-w-md mx-auto" style={{ color: 'rgba(252,252,252,0.75)' }}>
                Registracija je besplatna — odmah igraš prvi kviz.
              </p>
              <Link href="/auth/registracija" className="btn btn-yellow btn-lg">
                Kreni odmah →
              </Link>
            </div>
          </div>
        </section>
      )}

      {/* SEO content — multiple paragraphs covering core keyword clusters
          (online kviz, kafanski kviz, kviz iz književnosti, trivia duel,
          igra vešanja). Plain text + internal links so search engines
          have something substantial to index per landing visit. */}
      <section className="py-14 px-4 sm:px-6">
        <div className="max-w-3xl mx-auto text-[14px] leading-relaxed space-y-5" style={{ color: '#5a5a5a' }}>
          <h2 className="font-black tracking-tight text-center mb-2" style={{ color: '#343434', fontSize: 'clamp(22px, 4vw, 30px)' }}>
            Besplatan online kviz znanja na srpskom
          </h2>
          <p>
            <strong>Librum kviz</strong> je besplatna platforma za igre znanja na srpskom — online kviz koji
            spaja kviz opšte kulture, muzički kviz, kviz iz književnosti i klasičnu igru pogađanja
            reči na jednom mestu. Bez instalacije, bez reklama u igri — otvoriš sajt, registruješ se za
            10 sekundi i kreneš da igraš.
          </p>
          <p>
            <Link href="/igraj" className="font-semibold underline" style={{ color: '#609DED' }}>PRO kviz</Link>{' '}
            je naš survival kviz znanja sa 10 života i rang-listom — najteži kviz opšteg znanja i najbolji
            izazov za one koji žele da se takmiče.{' '}
            <Link href="/book-kviz" className="font-semibold underline" style={{ color: '#9c7a13' }}>Book kviz</Link>{' '}
            je kviz iz književnosti za ljubitelje knjiga: pitanja o piscima, romanima i žanrovima, a na
            kraju saznaš koji književni žanr najbolje poznaješ.
          </p>
          <p>
            <Link href="/kafanski-kviz" className="font-semibold underline" style={{ color: '#b91c1c' }}>Kafanski kviz</Link>{' '}
            je naš pub kviz i muzički kviz — preko 1000 pitanja o domaćoj i ex YU muzici, pevačima i
            pesmama. Idealan kviz za društvo, kafanu i kućno druženje.{' '}
            <Link href="/igraj-zajedno" className="font-semibold underline" style={{ color: '#9c7a13' }}>Trivia duel</Link>{' '}
            je multiplayer kviz protiv prijatelja u realnom vremenu — pošalji kod, pridruži se i odmerite
            znanje na istim pitanjima.
          </p>
          <p>
            <Link href="/vesanje" className="font-semibold underline" style={{ color: '#15803d' }}>Igra vešanja</Link>{' '}
            je klasična online igra pogađanja reči po kategorijama — sport, geografija, istorija,
            kultura, priroda i predmeti, sa hintom za teže reči.{' '}
            <Link href="/brzi-kviz" className="font-semibold underline" style={{ color: '#b91c1c' }}>Brzi kviz</Link>{' '}
            je tačno-netačno kviz od 60 sekundi — kratki kviz za pauzu, brzinski test znanja iz svih
            oblasti.
          </p>
          <p>
            Sve igre koriste isti sistem rang-liste, profila i bodova. Imaš zanimljivo pitanje? Pošalji
            ga preko{' '}
            <Link href="/predlozi-pitanje" className="underline" style={{ color: '#609DED' }}>predloga pitanja</Link>{' '}
            — ako prođe pregled, ulazi u sledeći kviz.
          </p>
        </div>
      </section>

      <Footer />

      <Script id="ld-faq" type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(faqSchema) }} />
    </div>
  )
}
