import Link from 'next/link'
import Script from 'next/script'
import Footer from '@/components/Footer'
import Header from '@/components/Header'
import { createClient } from '@/lib/supabase/server'
import { IGRE } from '@/lib/igre-katalog'

const faqSchema = {
  '@context': 'https://schema.org',
  '@type': 'FAQPage',
  mainEntity: [
    { '@type': 'Question', name: 'Šta je Librum kviz?', acceptedAnswer: { '@type': 'Answer', text: 'Librum kviz je besplatna platforma za kratke igre znanja na srpskom — PRO kviz, Book kviz, Kafanski kviz, Trivia duel, Vešanje i Brzi kviz. Pitanja pokrivaju književnost, istoriju, geografiju, sport, muziku, kulturu, prirodu i opšte znanje.' } },
    { '@type': 'Question', name: 'Da li je Librum kviz besplatan?', acceptedAnswer: { '@type': 'Answer', text: 'Jeste — sve igre su potpuno besplatne. Potrebno je samo da napraviš nalog kako bi se rezultati upisivali na rang-listu i čuvali na tvom profilu.' } },
    { '@type': 'Question', name: 'Kako se igra PRO kviz?', acceptedAnswer: { '@type': 'Answer', text: 'PRO kviz je survival igra. Počinješ sa 10 života, svaki tačan odgovor donosi bodove i gradi kombo niz, a svaka greška skida jedan život. Igra traje dok imaš života.' } },
    { '@type': 'Question', name: 'Mogu li da igram protiv prijatelja?', acceptedAnswer: { '@type': 'Answer', text: 'Možeš. Trivia duel je igra za dva igrača — pokreneš sobu, pošalješ kod ili link prijatelju i odmerite znanje na istim pitanjima u realnom vremenu. Vešanje takođe ima mod za dvoje.' } },
    { '@type': 'Question', name: 'Koje teme pokrivaju pitanja?', acceptedAnswer: { '@type': 'Answer', text: 'Opšte znanje, istorija, geografija, sport, nauka, film, muzika i književnost. Kafanski kviz je posvećen domaćoj i ex YU muzici, a Book kviz isključivo književnosti i žanrovima.' } },
  ],
}

const CREAM = '#F4EFE6'
const MUTED = '#A39E95'

type LeaderRow = {
  user_id: string
  score: number
  questions_reached: number
  // Resolved client-side from public_profiles (we don't embed profiles
  // anymore — that table is locked down for anon).
  profile?: { first_name: string | null; nickname: string | null; avatar: string | null } | null
}

// Round a question count down to its nearest thousand and add "k+".
// 7534 → "7k+", 9056 → "9k+", 1200 → "1k+", anything below 1000 falls
// back to the raw number with a "+" so the badge still reads natural.
function formatQuestionCount(n: number): string {
  if (n >= 1000) return `${Math.floor(n / 1000)}k+`
  if (n > 0) return `${n}+`
  return '—'
}

// Koliko pitanja fali do sledeće okrugle stotine/hiljade. Poziv na
// doprinos radi bolje sa konkretnim brojem („još 43”) nego sa opštim
// „pošalji pitanje”, a broj se sam obnavlja kako baza raste.
function doOkruglog(n: number): { cilj: number; fali: number } | null {
  if (n <= 0) return null
  // Korak je namerno sitan: „još 58 do 9100” je poziv na koji neko može da
  // odgovori danas, „još 958 do 10000” nije. Korak raste tek kad bi sitan
  // postao besmislen.
  const korak = n >= 50000 ? 1000 : n >= 10000 ? 500 : 100
  const cilj = Math.floor(n / korak) * korak + korak
  return { cilj, fali: cilj - n }
}

export default async function Home() {
  const supabase = await createClient()

  // ⚠ 14.09.2026: ova tri poziva su ranije išla JEDAN ZA DRUGIM, iako nijedan
  // ne zavisi od druga dva. Uz funkciju koja je do danas radila u `iad1`, a
  // bazu u Frankfurtu, svaki je prelazio Atlantik i vraćao se, pa je naslovna
  // umela da traje 16 s i probije Kulin prag od 20 s. Funkcija je premeštena u
  // `fra1` (vercel.json), a ovde se ono što je nezavisno traži odjednom.
  const [
    { data: { user } },
    { data: brojPitanja },
    { data: topSedamDana },
  ] = await Promise.all([
    supabase.auth.getUser(),
    supabase.rpc('broj_pitanja'),
    (async () => {
      // Server komponenta se izvršava jednom po zahtevu, pa je Date.now() ovde
      // bezbedan; pravilo čistoće se pali odbrambeno.
      // eslint-disable-next-line react-hooks/purity
      const odSedamDana = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString()
      return supabase
        .from('survivor_sessions')
        .select('user_id, score, questions_reached')
        .gte('created_at', odSedamDana)
        .order('score', { ascending: false })
        .limit(20)
    })(),
  ])

  // Live count of multiple-choice questions across the three pools that
  // power PRO, Brzi, Trivia duel, Book and Kafanski kviz. We deliberately
  // skip hangman_words — those are guess-a-word entries, not "pitanja".
  //
  // Ide kroz RPC `broj_pitanja()` a ne kroz tri odvojena brojanja: RLS na
  // `kafana_questions` dozvoljava čitanje samo prijavljenima, pa je
  // neprijavljen posetilac video 7k+ umesto 9k+.
  const totalQuestions = Number(brojPitanja) || 0
  const questionsBadge = formatQuestionCount(totalQuestions)
  const okrugli = doOkruglog(totalQuestions)

  // Top 5 PRO scores in the last 7 days — gives anonymous visitors a
  // taste of what's waiting after registration. Falls back to all-time
  // top 5 if nobody played this week. Server component runs once per
  // request, so Date.now() here is safe — purity rule fires defensively.
  let top = topSedamDana
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
    <div className="page-ink min-h-screen flex flex-col">
      <Header />

      <section className="relative overflow-hidden">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 pt-14 sm:pt-20 pb-16 sm:pb-24">
          <div className="grid lg:grid-cols-[1.15fr_0.85fr] gap-12 lg:gap-16 items-end">
            <div>
              <p className="text-[11px] font-semibold uppercase tracking-[0.28em] mb-6" style={{ color: MUTED }}>
                Librum klub · {questionsBadge} pitanja
              </p>
              <h1 className="leading-[0.88] mb-8" style={{ color: CREAM, fontSize: 'clamp(64px, 14vw, 148px)', fontWeight: 500 }}>
                Kviz.
              </h1>
              <p className="text-[18px] sm:text-[20px] max-w-md leading-snug mb-8" style={{ color: CREAM, opacity: 0.78 }}>
                Igre znanja na srpskom. Sam, u dvoje ili protiv cele rang-liste.
              </p>
              <div className="flex flex-wrap gap-3">
                <Link href={user ? '/igre' : '/auth/registracija'} className="btn btn-yellow btn-lg">
                  {user ? 'Izaberi igru' : 'Počni besplatno'}
                </Link>
                <Link href="/dodaj-pitanja" className="btn btn-secondary btn-lg">
                  {okrugli ? `Dodaj pitanje · još ${okrugli.fali}` : 'Dodaj pitanje'}
                </Link>
              </div>
            </div>

            <ol className="divide-y" style={{ borderColor: 'rgba(244,239,230,0.12)' }}>
              {IGRE.map(g => (
                <li key={g.href}>
                  <Link href={g.href}
                    className="group flex items-baseline gap-4 py-3.5 transition-opacity hover:opacity-80">
                    <span className="text-[11px] font-semibold tabular-nums w-8 shrink-0" style={{ color: g.accent }}>
                      {g.n}
                    </span>
                    <span className="flex-1 text-[22px] sm:text-[26px] leading-none" style={{ color: CREAM, fontFamily: 'var(--font-fraunces), Fraunces, serif' }}>
                      {g.kratko}
                    </span>
                    <span className="hidden sm:block text-[13px] flex-1 truncate" style={{ color: MUTED }}>
                      {g.desc}
                    </span>
                    <span className="text-[13px] shrink-0" style={{ color: g.accent }}>→</span>
                  </Link>
                </li>
              ))}
            </ol>
          </div>
        </div>
      </section>

      {leaderboard.length > 0 && (
        <section style={{ borderTop: '1px solid rgba(244,239,230,0.12)', borderBottom: '1px solid rgba(244,239,230,0.12)' }}>
          <div className="max-w-6xl mx-auto px-4 sm:px-6 py-5 flex flex-wrap items-baseline gap-x-6 gap-y-2">
            <p className="text-[11px] font-semibold uppercase tracking-[0.22em] shrink-0" style={{ color: MUTED }}>
              Ove nedelje
            </p>
            {leaderboard.map((r, i) => {
              const name = r.profile?.nickname || r.profile?.first_name || 'Igrač'
              return (
                <span key={r.user_id} className="text-[14px]" style={{ color: CREAM }}>
                  <span style={{ color: MUTED }}>{i + 1}.</span> {name}
                  <span className="ml-2 tabular-nums" style={{ color: '#E2B93A' }}>{r.score}</span>
                </span>
              )
            })}
            <Link href="/ranglista" className="text-[13px] ml-auto" style={{ color: MUTED }}>
              Rang lista →
            </Link>
          </div>
        </section>
      )}

      <section className="px-4 sm:px-6 py-16 sm:py-24">
        <div className="max-w-3xl mx-auto text-[15px] leading-[1.7] space-y-5" style={{ color: MUTED }}>
          <h2 className="mb-6" style={{ color: CREAM, fontSize: 'clamp(28px, 5vw, 42px)' }}>
            Besplatan online kviz znanja na srpskom
          </h2>
          <p>
            <strong style={{ color: CREAM }}>Librum kviz</strong> je platforma za igre znanja na srpskom — kviz opšte kulture, muzički kviz, kviz iz književnosti i igra pogađanja reči. Bez instalacije i bez reklama u toku igre.
          </p>
          <p>
            <Link href="/pro-kviz" className="underline" style={{ color: CREAM }}>PRO kviz</Link> je survival sa 10 života.{' '}
            <Link href="/book-kviz" className="underline" style={{ color: CREAM }}>Book kviz</Link> je isključivo književnost.{' '}
            <Link href="/kafanski-kviz" className="underline" style={{ color: CREAM }}>Kafanski kviz</Link> je pub kviz o domaćoj i ex YU muzici.{' '}
            <Link href="/igraj-zajedno" className="underline" style={{ color: CREAM }}>Trivia duel</Link> je jedan na jedan u realnom vremenu.{' '}
            <Link href="/vesanje" className="underline" style={{ color: CREAM }}>Vešanje</Link> pogađa reč po slovima.{' '}
            <Link href="/brzi-kviz" className="underline" style={{ color: CREAM }}>Brzi kviz</Link> je tačno-netačno za 60 sekundi.
          </p>
          <p>
            Imaš pitanje? Pošalji ga preko{' '}
            <Link href="/dodaj-pitanja" className="underline" style={{ color: CREAM }}>forme za pitanja</Link>.
            Dva igrača mogu da prijave netačno pitanje — tada se autor suspenduje tri dana, a sva njegova pitanja se povlače.
          </p>

          <h2 className="pt-10 mb-6" style={{ color: CREAM, fontSize: 'clamp(28px, 5vw, 42px)' }}>
            Pitanja
          </h2>
          {faqSchema.mainEntity.map(item => (
            <div key={item.name} className="py-5" style={{ borderTop: '1px solid rgba(244,239,230,0.12)' }}>
              <h3 className="text-[17px] mb-2" style={{ color: CREAM }}>{item.name}</h3>
              <p>{item.acceptedAnswer.text}</p>
            </div>
          ))}
        </div>
      </section>

      <Footer />

      <Script id="ld-faq" type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(faqSchema) }} />
    </div>
  )
}
