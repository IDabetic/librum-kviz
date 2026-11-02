import Image from 'next/image'
import Link from 'next/link'
import Script from 'next/script'
import Footer from '@/components/Footer'
import Header from '@/components/Header'
import { createClient } from '@/lib/supabase/server'
import { IGRE } from '@/lib/igre-katalog'
import { KarticaIgre } from '@/components/KarticaIgre'

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

  const [prva, ...ostale] = IGRE

  return (
    <div className="min-h-screen flex flex-col">
      <Header />

      <main className="flex-1 max-w-6xl w-full mx-auto px-4 sm:px-6 pt-10 sm:pt-14 pb-16">
        <div className="flex items-end justify-between gap-6 mb-8">
          <div>
            <p className="chip mb-3" style={{ color: '#12907E' }}>
              <span className="w-2 h-2 rounded-full" style={{ background: '#2FD27A' }} />
              {questionsBadge} pitanja u bazi
            </p>
            <h1 style={{ fontSize: 'clamp(44px, 9vw, 96px)' }}>
              Izaberi kviz<br />i igraj.
            </h1>
          </div>
          <Image src="/maskote/Bloop.png" alt="" width={150} height={150}
            className="hidden sm:block maskota-lebdi shrink-0" aria-hidden priority />
        </div>

        <div className="grid gap-4 sm:gap-5 md:grid-cols-[1.3fr_1fr]">
          <KarticaIgre igra={prva} href={user ? prva.href : `/auth/prijava?redirect=${prva.href}`} velika />
          <div className="grid grid-cols-2 gap-4 sm:gap-5">
            {ostale.slice(0, 2).map(g => (
              <KarticaIgre key={g.href} igra={g} href={user ? g.href : `/auth/prijava?redirect=${g.href}`} />
            ))}
            <div className="col-span-2 card-soft p-5 flex flex-col justify-between">
              <p className="text-[15px] font-semibold leading-snug">
                Igre znanja na srpskom. Sam, u dvoje ili protiv cele rang liste.
              </p>
              <div className="flex flex-wrap gap-3 mt-4">
                <Link href={user ? '/igre' : '/auth/registracija'} className="btn btn-primary btn-md">
                  {user ? 'Sve igre' : 'Počni besplatno'}
                </Link>
                <Link href="/dodaj-pitanja" className="btn btn-secondary btn-md">
                  {okrugli ? `Dodaj pitanje · još ${okrugli.fali}` : 'Dodaj pitanje'}
                </Link>
              </div>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-2 md:grid-cols-3 gap-4 sm:gap-5 mt-4 sm:mt-5">
          {ostale.slice(2).map(g => (
            <KarticaIgre key={g.href} igra={g} href={user ? g.href : `/auth/prijava?redirect=${g.href}`} />
          ))}
        </div>

        {leaderboard.length > 0 && (
          <section className="mt-12">
            <div className="flex items-baseline justify-between mb-4">
              <h2 style={{ fontSize: 'clamp(26px, 4vw, 34px)' }}>Ove nedelje</h2>
              <Link href="/ranglista" className="text-[14px] font-bold underline underline-offset-4">Rang lista</Link>
            </div>
            <ol className="card-soft divide-y divide-[#E7E1D0]">
              {leaderboard.map((r, i) => {
                const name = r.profile?.nickname || r.profile?.first_name || 'Igrač'
                return (
                  <li key={r.user_id} className="flex items-center gap-4 px-5 py-3.5">
                    <span className="w-9 h-9 grid place-items-center rounded-xl font-bold tabular-nums"
                      style={{ background: i === 0 ? '#FFD84D' : '#F3F0E6', border: i === 0 ? '2px solid #151515' : 'none' }}>
                      {i + 1}
                    </span>
                    <span className="flex-1 font-semibold truncate">{name}</span>
                    <span className="naslov text-[20px] tabular-nums">{r.score}</span>
                  </li>
                )
              })}
            </ol>
          </section>
        )}

        <section className="mt-16 max-w-3xl text-[15px] leading-[1.7] space-y-5" style={{ color: '#6F6C66' }}>
          <h2 className="mb-6" style={{ color: '#151515', fontSize: 'clamp(28px, 5vw, 40px)' }}>
            Besplatan online kviz znanja na srpskom
          </h2>
          <p>
            <strong style={{ color: '#151515' }}>Librum kviz</strong> je platforma za igre znanja na srpskom — kviz opšte kulture, muzički kviz, kviz iz književnosti i igra pogađanja reči. Bez instalacije i bez reklama u toku igre.
          </p>
          <p>
            <Link href="/pro-kviz" className="underline" style={{ color: '#151515' }}>PRO kviz</Link> je survival sa 10 života.{' '}
            <Link href="/book-kviz" className="underline" style={{ color: '#151515' }}>Book kviz</Link> je isključivo književnost.{' '}
            <Link href="/kafanski-kviz" className="underline" style={{ color: '#151515' }}>Kafanski kviz</Link> je pub kviz o domaćoj i ex YU muzici.{' '}
            <Link href="/igraj-zajedno" className="underline" style={{ color: '#151515' }}>Trivia duel</Link> je jedan na jedan u realnom vremenu.{' '}
            <Link href="/vesanje" className="underline" style={{ color: '#151515' }}>Vešanje</Link> pogađa reč po slovima.{' '}
            <Link href="/brzi-kviz" className="underline" style={{ color: '#151515' }}>Brzi kviz</Link> je tačno-netačno za 60 sekundi.
          </p>
          <p>
            Imaš pitanje? Pošalji ga preko{' '}
            <Link href="/dodaj-pitanja" className="underline" style={{ color: '#151515' }}>forme za pitanja</Link>.
            Dva igrača mogu da prijave netačno pitanje — tada se autor suspenduje tri dana, a sva njegova pitanja se povlače.
          </p>

          <h2 className="pt-10 mb-2" style={{ color: '#151515', fontSize: 'clamp(28px, 5vw, 40px)' }}>
            Pitanja
          </h2>
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
