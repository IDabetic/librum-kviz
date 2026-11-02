import Image from 'next/image'
import Link from 'next/link'
import Script from 'next/script'
import Footer from '@/components/Footer'
import Header from '@/components/Header'
import { createClient } from '@/lib/supabase/server'
import { Telefon } from '@/components/Telefon'
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

export default async function Home() {
  const supabase = await createClient()

  // ⚠ 14.09.2026: ovi pozivi su ranije išla JEDAN ZA DRUGIM, iako nijedan
  // ne zavisi od druga dva. Uz funkciju koja je do danas radila u `iad1`, a
  // bazu u Frankfurtu, svaki je prelazio Atlantik i vraćao se, pa je naslovna
  // umela da traje 16 s i probije Kulin prag od 20 s. Funkcija je premeštena u
  // `fra1` (vercel.json), a ovde se ono što je nezavisno traži odjednom.
  const [
    { data: brojPitanja },
    { data: topSedamDana },
  ] = await Promise.all([
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
  // power PRO, Brzi, Trivia duel and Book kviz. We deliberately
  // skip hangman_words — those are guess-a-word entries, not "pitanja".
  //
  // Ide kroz RPC `broj_pitanja()` a ne kroz tri odvojena brojanja: RLS na
  // `kafana_questions` dozvoljava čitanje samo prijavljenima, pa je
  // neprijavljen posetilac video 7k+ umesto 9k+.
  const totalQuestions = Number(brojPitanja) || 0
  const questionsBadge = formatQuestionCount(totalQuestions)

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

  const IGRE_U_APLIKACIJI = [
    { ime: 'PRO kviz', opis: 'Deset života, kombo nizovi i rang lista.', boja: '#6D4BC9', tekst: '#FFFFFF', maskota: 'Lumi' },
    { ime: 'Book kviz', opis: 'Pisci, dela i žanrovi.', boja: '#F4A33C', tekst: '#151515', maskota: 'Zig' },
    { ime: 'Trivia duel', opis: 'Ista pitanja, jedan na jedan.', boja: '#151515', tekst: '#FFFFFF', maskota: 'Bloop' },
    { ime: 'Slikari', opis: 'Ko je naslikao ovo delo? 1.439 dela, od Leonarda do Pikasa.', boja: '#FF5FA2', tekst: '#151515', maskota: 'Mimi' },
    { ime: 'Vešanje', opis: 'Pogodi reč, slovo po slovo.', boja: '#6EC3F2', tekst: '#151515', maskota: 'Lumi' },
    { ime: 'Brzi kviz', opis: 'Tačno ili netačno, 60 sekundi.', boja: '#FFD84D', tekst: '#151515', maskota: 'Zig' },
  ]
  const KORACI = [
    ['Preuzmi aplikaciju', 'Za iPhone i Android, besplatno. Bez reklama u toku igre.'],
    ['Napravi nalog', 'Isti nalog važi i ovde na sajtu, za rang listu i profil.'],
    ['Osvoji svet', 'Svako pitanje je bitka. Rezultati stižu na rang listu.'],
  ]

  return (
    <div className="min-h-screen flex flex-col">
      <Header />

      <main className="flex-1">
        {/* Uvod: aplikacija sa snimcima ekrana */}
        <section className="max-w-6xl mx-auto px-4 sm:px-6 pt-10 sm:pt-16 pb-14 grid lg:grid-cols-[1.05fr_0.95fr] gap-12 items-center">
          <div>
            <p className="chip mb-4" style={{ color: '#12907E' }}>
              <span className="w-2 h-2 rounded-full" style={{ background: '#2FD27A' }} />
              Aplikacija za iPhone i Android{totalQuestions > 0 ? ` · ${questionsBadge} pitanja` : ''}
            </p>
            <h1 style={{ fontSize: 'clamp(46px, 8.5vw, 92px)' }}>Osvoji svet<br />znanjem.</h1>
            <p className="mt-5 text-[18px] leading-relaxed max-w-lg" style={{ color: '#3B3832' }}>
              Librum kviz je aplikacija u kojoj svaka država sveta pada pitanjem. Osvajanje sveta i još šest igara
              znanja na srpskom, protiv rivala, prijatelja i cele rang liste.
            </p>
            <div className="mt-8"><Prodavnice /></div>
            <p className="mt-4 text-[14px]" style={{ color: '#6F6C66' }}>
              Već igraš? <Link href="/ranglista" className="font-bold underline underline-offset-4" style={{ color: '#151515' }}>Pogledaj rang listu</Link>
            </p>
          </div>
          {/* Visina prati telefone (odnos ekrana 1206×2622), da ne upadnu u sledeću sekciju. */}
          <div className="relative mx-auto w-full max-w-[440px] aspect-[5/6]">
            <div className="absolute left-0 top-[9%] w-[45%]"><Telefon src="/aplikacija/pocetna.jpg" alt="Početni ekran aplikacije sa igrama" nagib={-6} prioritet /></div>
            <div className="absolute right-0 top-0 w-[50%] z-[1]"><Telefon src="/aplikacija/mapa.jpg" alt="Mapa sveta u igri Osvajanje sveta" nagib={4} prioritet /></div>
            <Image src="/maskote/Bloop.png" alt="" width={90} height={90} aria-hidden className="absolute -left-3 -top-6 z-10 maskota-lebdi" />
          </div>
        </section>

        {/* Glavna igra */}
        <section className="px-4 sm:px-6">
          <div className="max-w-6xl mx-auto card-pop overflow-hidden grid md:grid-cols-[1.1fr_0.9fr]" style={{ background: '#12907E', color: '#FFFFFF' }}>
            <div className="p-7 sm:p-10">
              <p className="chip" style={{ color: '#FFD84D' }}>Glavna igra</p>
              <h2 className="mt-3" style={{ fontSize: 'clamp(36px, 6vw, 60px)' }}>Osvajanje sveta</h2>
              <ul className="mt-6 space-y-4 text-[16px]">
                {[
                  ['171 država', 'Prava mapa sveta. Napadaš samo susede, a preko mora idu morski putevi: iz Brazila u Afriku, iz Španije u Maroko.'],
                  ['Vojske i regioni', 'Ceo region donosi bonus vojske svakog poteza, kao kontinenti u Risku.'],
                  ['Bitka je pitanje', 'Tačan odgovor ruši branioca. Kad oboje znate, pobeđuje brži.'],
                  ['Cepaj dalje', 'Posle osvajanja napadaš iz nove države; svako treće osvajanje u nizu donosi +2 vojske.'],
                ].map(([n, t]) => (
                  <li key={n} className="flex gap-3">
                    <span className="mt-1 w-2.5 h-2.5 shrink-0 rounded-full" style={{ background: '#FFD84D', outline: '2px solid #151515' }} />
                    <span><strong>{n}.</strong> <span className="opacity-90">{t}</span></span>
                  </li>
                ))}
              </ul>
            </div>
            <div className="relative min-h-[360px] bg-[#0E6F61]">
              <div className="absolute left-1/2 top-8 w-[62%] max-w-[260px] -translate-x-1/2"><Telefon src="/aplikacija/pitanje.jpg" alt="Pitanje u bici za državu" /></div>
            </div>
          </div>
        </section>

        {/* Sve igre u aplikaciji */}
        <section className="max-w-6xl mx-auto px-4 sm:px-6 pt-16">
          <h2 style={{ fontSize: 'clamp(30px, 5vw, 46px)' }}>I još šest igara</h2>
          <div className="mt-7 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-5">
            {IGRE_U_APLIKACIJI.map(g => (
              <div key={g.ime} className="card-pop relative overflow-hidden min-h-[150px] p-5 flex flex-col justify-end" style={{ background: g.boja, color: g.tekst }}>
                <Image src={`/maskote/${g.maskota}.png`} alt="" width={96} height={96} aria-hidden className="absolute -right-2 -top-2" />
                <h3 className="text-[26px] relative">{g.ime}</h3>
                <p className="relative mt-1 text-[14px] font-semibold opacity-85 max-w-[80%]">{g.opis}</p>
              </div>
            ))}
          </div>
        </section>

        {/* Kako počinješ */}
        <section className="max-w-6xl mx-auto px-4 sm:px-6 pt-16">
          <h2 style={{ fontSize: 'clamp(30px, 5vw, 46px)' }}>Kako počinješ</h2>
          <ol className="mt-7 grid md:grid-cols-3 gap-4 sm:gap-5">
            {KORACI.map(([n, t], i) => (
              <li key={n} className="card-soft p-6">
                <span className="w-10 h-10 grid place-items-center rounded-xl text-[17px] font-bold" style={{ background: '#FFD84D', border: '2px solid #151515' }}>{i + 1}</span>
                <h3 className="mt-4 text-[22px]">{n}</h3>
                <p className="mt-2 text-[15px]" style={{ color: '#6F6C66' }}>{t}</p>
              </li>
            ))}
          </ol>
        </section>

        {/* Rang lista ove nedelje */}
        <section className="max-w-6xl mx-auto px-4 sm:px-6 pt-16">
          <div className="flex items-baseline justify-between mb-4 gap-4">
            <h2 style={{ fontSize: 'clamp(30px, 5vw, 46px)' }}>Najbolji ove nedelje</h2>
            <Link href="/ranglista" className="text-[15px] font-bold underline underline-offset-4 shrink-0">Cela rang lista</Link>
          </div>
          {leaderboard.length > 0 ? (
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
          ) : (
            <div className="card-soft p-8 flex items-center gap-5">
              <Image src="/maskote/Lumi.png" alt="" width={80} height={80} aria-hidden />
              <p className="text-[16px]" style={{ color: '#6F6C66' }}>Rang lista se puni čim prve partije stignu iz aplikacije.</p>
            </div>
          )}
        </section>

        {/* Poziv na kraju */}
        <section className="px-4 sm:px-6 pt-16 pb-6">
          <div className="max-w-6xl mx-auto card-pop p-8 sm:p-12 relative overflow-hidden" style={{ background: '#151515', color: '#F3F0E6' }}>
            <Image src="/maskote/Zig.png" alt="" width={150} height={150} aria-hidden className="absolute right-4 bottom-0 hidden sm:block" />
            <h2 style={{ fontSize: 'clamp(32px, 5vw, 52px)' }}>Preuzmi i kreni u osvajanje.</h2>
            <p className="mt-3 text-[16px] opacity-80 max-w-xl">Imaš dobro pitanje? <Link href="/dodaj-pitanja" className="underline font-bold">Pošalji ga</Link> i uđi u kviz kao autor.</p>
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
