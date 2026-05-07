import { createClient } from '@/lib/supabase/server'
import Header from '@/components/Header'
import Image from 'next/image'
import Link from 'next/link'
import { notFound } from 'next/navigation'
import { IconBack, IconHome, IconSwords, IconHint, IconTime, IconStar } from '@/components/icons'

import Footer from '@/components/Footer'

export default async function PublicProfilPage({ params }: { params: Promise<{ userId: string }> }) {
  const { userId } = await params
  const supabase = await createClient()

  const { data: profile } = await supabase
    .from('profiles').select('*').eq('id', userId).single()

  if (!profile) notFound()

  // Pull all session rows so play counts, max scores AND avg-time stats
  // are accurate. Bumped from 50 → 5000: a user with 200 sessions used
  // to show "50 igara" because the cap was the limit, not their actual
  // play count. Avg time per correct question = sum(total_time) / sum(correct).
  const [survivor, book, kafana, hangman, quick, duelGames] = await Promise.all([
    supabase.from('survivor_sessions')
      .select('score, questions_reached, best_combo, accuracy, correct_answers, total_time_seconds')
      .eq('user_id', userId).order('created_at', { ascending: false }).limit(5000),
    supabase.from('book_sessions')
      .select('score, questions_reached, top_genre, top_genre_pct, correct_answers, total_time_seconds')
      .eq('user_id', userId).order('created_at', { ascending: false }).limit(5000),
    supabase.from('kafana_sessions')
      .select('score, questions_reached, accuracy, best_combo, correct_answers, total_time_seconds')
      .eq('user_id', userId).order('created_at', { ascending: false }).limit(5000),
    supabase.from('hangman_sessions').select('won, score').eq('user_id', userId).limit(5000),
    supabase.from('quick_sessions')
      .select('score, correct_count, accuracy, total_answered, duration_seconds')
      .eq('user_id', userId).limit(5000),
    supabase.from('game_rooms')
      .select('host_id, guest_id, host_score, guest_score, host_finished, guest_finished, status')
      .or(`host_id.eq.${userId},guest_id.eq.${userId}`)
      .not('guest_id', 'is', null)
      .limit(2000),
  ])

  // ── Helper: average time per correct answer (seconds, 1 decimal) ─
  // Sum of total_time across all sessions divided by sum of correct
  // answers. Per-correct gives a fairness signal — a player with 2000
  // bodova in 1 game with avg 0.3s/correct is suspect. Returns null
  // when there's no data so we don't render "0.0s".
  function avgTimePerCorrect(rows: { total_time_seconds?: number | null; correct_answers?: number | null }[]): string | null {
    let totT = 0, totC = 0
    for (const r of rows) {
      totT += Number(r.total_time_seconds ?? 0)
      totC += Number(r.correct_answers ?? 0)
    }
    if (totC <= 0) return null
    return `${(totT / totC).toFixed(1)}s`
  }

  const sSessions = survivor.data || []
  const sBest = sSessions.length ? Math.max(...sSessions.map(s => s.score)) : 0
  const sBestQ = sSessions.length ? Math.max(...sSessions.map(s => s.questions_reached)) : 0
  const sAvgT = avgTimePerCorrect(sSessions)

  const bSessions = book.data || []
  const bBest = bSessions.length ? Math.max(...bSessions.map(s => s.score)) : 0
  const bAvgT = avgTimePerCorrect(bSessions)
  // Top genre across this user's book sessions: count appearances of top_genre, pick most frequent
  const genreTally: Record<string, number> = {}
  for (const r of bSessions) {
    if (r.top_genre) genreTally[r.top_genre] = (genreTally[r.top_genre] || 0) + 1
  }
  const bTopGenre = Object.entries(genreTally).sort((a, b) => b[1] - a[1])[0]?.[0] || null

  const hSessions = hangman.data || []
  const hWins = hSessions.filter(s => s.won).length
  const hWinRate = hSessions.length ? Math.round((hWins / hSessions.length) * 100) : 0

  const qSessions = quick.data || []
  const qBest = qSessions.length ? Math.max(...qSessions.map(s => s.score)) : 0
  // Brzi kviz tracks duration_seconds + correct_count (not the same
  // shape as the rest), so compute avg-per-correct inline.
  const qAvgT: string | null = (() => {
    let totT = 0, totC = 0
    for (const r of qSessions) {
      totT += Number(r.duration_seconds ?? 0)
      totC += Number(r.correct_count ?? 0)
    }
    if (totC <= 0) return null
    return `${(totT / totC).toFixed(1)}s`
  })()

  const kSessions = kafana.data || []
  const kBest = kSessions.length ? Math.max(...kSessions.map(s => s.score)) : 0
  const kBestQ = kSessions.length ? Math.max(...kSessions.map(s => s.questions_reached)) : 0
  const kAvgT = avgTimePerCorrect(kSessions)

  let dWins = 0, dLosses = 0, dDraws = 0, dPlays = 0
  ;(duelGames.data || []).forEach(g => {
    const isFinished = g.status === 'finished' || (g.host_finished && g.guest_finished)
    if (!isFinished) return
    dPlays++
    const isHost = g.host_id === userId
    const my = isHost ? (g.host_score ?? 0) : (g.guest_score ?? 0)
    const op = isHost ? (g.guest_score ?? 0) : (g.host_score ?? 0)
    if (my > op) dWins++
    else if (my < op) dLosses++
    else dDraws++
  })

  const displayName = profile.nickname || `${profile.first_name || ''} ${profile.last_name || ''}`.trim() || 'Igrač'
  const initials = (profile.first_name?.[0] || '') + (profile.last_name?.[0] || '') || displayName[0]

  return (
    <div className="min-h-screen" style={{ background: '#FAFAFA' }}>
      <Header />
      <main className="max-w-3xl mx-auto px-4 sm:px-6 py-10 sm:py-14">

        <Link href="/leaderboard"
          className="inline-flex items-center gap-1.5 text-[13px] font-medium mb-6 transition-opacity hover:opacity-70"
          style={{ color: '#609DED' }}>
          <IconBack size={16} strokeWidth={2.2} />
          Rang lista
        </Link>

        <div className="card-soft p-6 sm:p-8 mb-6">
          <div className="flex items-center gap-4 sm:gap-5">
            <div className="w-20 h-20 rounded-2xl overflow-hidden flex-shrink-0 bg-[#F2F2F2]">
              {profile.avatar
                ? <Image src={`/avatars/${profile.avatar}`} alt={displayName} width={80} height={80} className="w-full h-full object-cover" />
                : <div className="w-full h-full flex items-center justify-center font-black text-[24px]" style={{ background: '#609DED', color: 'white' }}>{initials.toUpperCase()}</div>}
            </div>
            <div className="min-w-0 flex-1">
              <h1 className="font-black tracking-tight truncate" style={{ color: '#343434', fontSize: 'clamp(22px, 4vw, 30px)' }}>
                {displayName}
              </h1>
              {profile.nickname && (
                <p className="text-[13px] truncate" style={{ color: '#9C9C9C' }}>{profile.first_name} {profile.last_name}</p>
              )}
              {profile.city && <p className="text-[12px] truncate mt-0.5" style={{ color: '#9C9C9C' }}>📍 {profile.city}</p>}
            </div>
          </div>
        </div>

        <div className="grid sm:grid-cols-2 gap-3 mb-6">
          <GameCard Icon={IconHome}   label="PRO kviz"    accent="#609DED" bg="#BCD9FF"
            primary={{ value: sBest, label: 'Rekord bodova' }}
            secondary={[
              { value: sSessions.length, label: 'Partija' },
              { value: sBestQ, label: 'Max pitanja' },
              ...(sAvgT ? [{ value: sAvgT, label: 'Vreme/tačno' }] : []),
            ]} />
          <GameCard Icon={IconStar}   label="Book kviz"   accent="#9c7a13" bg="#FFECBC"
            primary={{ value: bBest, label: 'Rekord bodova' }}
            secondary={[
              { value: bSessions.length, label: 'Partija' },
              ...(bTopGenre ? [{ value: bTopGenre, label: 'Najjači žanr' }] : []),
              ...(bAvgT ? [{ value: bAvgT, label: 'Vreme/tačno' }] : []),
            ]} />
          <GameCard Icon={IconStar}   label="Kafanski kviz" accent="#b91c1c" bg="#FEE2E2"
            primary={{ value: kBest, label: 'Rekord bodova' }}
            secondary={[
              { value: kSessions.length, label: 'Partija' },
              { value: kBestQ, label: 'Max pitanja' },
              ...(kAvgT ? [{ value: kAvgT, label: 'Vreme/tačno' }] : []),
            ]} />
          <GameCard Icon={IconSwords} label="Trivia duel" accent="#9c7a13" bg="#FFECBC"
            primary={{ value: dWins, label: 'Pobeda' }}
            secondary={[
              { value: dPlays, label: 'Duela' },
              { value: dLosses, label: 'Poraza' },
              { value: dDraws, label: 'Nerešeno' },
            ]} />
          <GameCard Icon={IconHint}   label="Vešanje"     accent="#15803d" bg="#E8F8F0"
            primary={{ value: hWins, label: 'Pobeda' }}
            secondary={[
              { value: hSessions.length, label: 'Partija' },
              { value: `${hWinRate}%`, label: 'Uspeh' },
            ]} />
          <GameCard Icon={IconTime}   label="Brzi kviz"   accent="#b91c1c" bg="#FEE2E2"
            primary={{ value: qBest, label: 'Rekord bodova' }}
            secondary={[
              { value: qSessions.length, label: 'Rundi' },
              ...(qAvgT ? [{ value: qAvgT, label: 'Vreme/tačno' }] : []),
            ]} />
        </div>

        {(sSessions.length + bSessions.length + kSessions.length + hSessions.length + qSessions.length) === 0 && (
          <div className="card-soft py-16 text-center">
            <div className="text-5xl mb-4">🎮</div>
            <p className="font-bold text-[17px]" style={{ color: '#343434' }}>Još nije igrao</p>
          </div>
        )}
      </main>
      <Footer />
    </div>
  )
}

function GameCard({ Icon, label, accent, bg, primary, secondary }: {
  Icon: React.ComponentType<{ size?: number; strokeWidth?: number; className?: string }>
  label: string; accent: string; bg: string
  primary: { value: number | string; label: string }
  secondary: { value: number | string; label: string }[]
}) {
  return (
    <div className="card-soft p-5 sm:p-6">
      <div className="flex items-center gap-3 mb-4">
        <div className="w-10 h-10 rounded-2xl flex items-center justify-center flex-shrink-0" style={{ background: bg }}>
          <Icon size={18} className={`text-[${accent}]`} strokeWidth={2.2} />
        </div>
        <p className="font-bold text-[14px] tracking-tight" style={{ color: '#343434' }}>{label}</p>
      </div>
      <div className="font-black tracking-tight leading-none mb-1" style={{ color: accent, fontSize: 'clamp(28px, 5vw, 36px)' }}>
        {primary.value}
      </div>
      <p className="text-[11px] font-medium mb-4" style={{ color: '#9C9C9C' }}>{primary.label}</p>
      <div className="grid gap-2 pt-3 border-t" style={{ borderColor: '#F2F2F2', gridTemplateColumns: `repeat(${secondary.length}, 1fr)` }}>
        {secondary.map((s, i) => (
          <div key={i}>
            <div className="font-bold text-[14px] tracking-tight" style={{ color: '#343434' }}>{s.value}</div>
            <div className="text-[10px]" style={{ color: '#9C9C9C' }}>{s.label}</div>
          </div>
        ))}
      </div>
    </div>
  )
}
