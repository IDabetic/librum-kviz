import { createClient } from '@/lib/supabase/server'
import Header from '@/components/Header'
import Link from 'next/link'
import Image from 'next/image'
import { redirect } from 'next/navigation'
import { IconSettings, IconHome, IconSwords, IconHint, IconTime, IconStar, IconTrophy } from '@/components/icons'

function fmtTime(s: number): string {
  const m = Math.floor(s / 60)
  const sec = s % 60
  return `${String(m).padStart(2, '0')}:${String(sec).padStart(2, '0')}`
}

export default async function ProfilPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/auth/prijava')

  const { data: profile } = await supabase
    .from('profiles').select('*').eq('id', user.id).single()

  // Pull stats for all 4 games in parallel
  const [survivor, hangman, quick, duelGames] = await Promise.all([
    supabase.from('survivor_sessions')
      .select('score, questions_reached, correct_answers, wrong_answers, best_combo, total_time_seconds, created_at')
      .eq('user_id', user.id).order('created_at', { ascending: false }).limit(20),
    supabase.from('hangman_sessions')
      .select('won, score, word, category, wrong_guesses, created_at')
      .eq('user_id', user.id).order('created_at', { ascending: false }).limit(20),
    supabase.from('quick_sessions')
      .select('score, correct_count, wrong_count, accuracy, total_answered, created_at')
      .eq('user_id', user.id).order('created_at', { ascending: false }).limit(20),
    supabase.from('game_rooms')
      .select('host_id, guest_id, host_score, guest_score, host_finished, guest_finished, created_at')
      .or(`host_id.eq.${user.id},guest_id.eq.${user.id}`)
      .or('host_finished.eq.true,guest_finished.eq.true')
      .not('guest_id', 'is', null)
      .order('created_at', { ascending: false }).limit(50),
  ])

  // Survivor stats
  const sSessions = survivor.data || []
  const sTotal = sSessions.length
  const sBest = sTotal ? Math.max(...sSessions.map(s => s.score)) : 0
  const sBestQ = sTotal ? Math.max(...sSessions.map(s => s.questions_reached)) : 0
  const sBestCombo = sTotal ? Math.max(...sSessions.map(s => s.best_combo)) : 0

  // Hangman stats
  const hSessions = hangman.data || []
  const hTotal = hSessions.length
  const hWins = hSessions.filter(s => s.won).length
  const hWinRate = hTotal ? Math.round((hWins / hTotal) * 100) : 0
  const hScore = hSessions.reduce((s, r) => s + (r.score ?? 0), 0)

  // Quick stats
  const qSessions = quick.data || []
  const qTotal = qSessions.length
  const qBest = qTotal ? Math.max(...qSessions.map(s => s.score)) : 0
  const qCorrect = qSessions.reduce((s, r) => s + (r.correct_count ?? 0), 0)
  const qAccuracy = qTotal ? Math.round((qSessions.reduce((s, r) => s + Number(r.accuracy), 0) / qTotal)) : 0

  // Duel stats
  const dGames = duelGames.data || []
  let dWins = 0, dLosses = 0, dDraws = 0
  dGames.forEach(g => {
    if (!g.host_finished || !g.guest_finished) return
    const isHost = g.host_id === user.id
    const my = isHost ? (g.host_score ?? 0) : (g.guest_score ?? 0)
    const op = isHost ? (g.guest_score ?? 0) : (g.host_score ?? 0)
    if (my > op) dWins++
    else if (my < op) dLosses++
    else dDraws++
  })
  const dTotal = dWins + dLosses + dDraws

  const displayName = profile?.nickname || `${profile?.first_name || ''} ${profile?.last_name || ''}`.trim() || 'Igrač'
  const initials = (profile?.first_name?.[0] || '') + (profile?.last_name?.[0] || '') || displayName[0]

  return (
    <div className="min-h-screen" style={{ background: '#FAFAFA' }}>
      <Header />
      <main className="max-w-3xl mx-auto px-4 sm:px-6 py-10 sm:py-14">

        {/* ─ Profile card ────────────────────────────────────────────── */}
        <div className="card-soft p-6 sm:p-8 mb-6">
          <div className="flex items-start sm:items-center justify-between gap-4 flex-wrap">
            <div className="flex items-center gap-4 sm:gap-5 flex-1 min-w-0">
              <div className="w-16 h-16 sm:w-20 sm:h-20 rounded-2xl overflow-hidden flex-shrink-0 bg-[#F2F2F2]">
                {profile?.avatar
                  ? <Image src={`/avatars/${profile.avatar}`} alt="Avatar" width={80} height={80} className="w-full h-full object-cover" />
                  : <div className="w-full h-full flex items-center justify-center font-black text-[24px]" style={{ background: '#609DED', color: 'white' }}>{initials.toUpperCase()}</div>}
              </div>
              <div className="min-w-0 flex-1">
                <h1 className="font-black tracking-tight truncate" style={{ color: '#343434', fontSize: 'clamp(22px, 4vw, 30px)' }}>
                  {displayName}
                </h1>
                {profile?.nickname && (
                  <p className="text-[13px] truncate" style={{ color: '#9C9C9C' }}>{profile.first_name} {profile.last_name}</p>
                )}
                <p className="text-[12px] truncate" style={{ color: '#9C9C9C' }}>{profile?.email}</p>
                {profile?.city && <p className="text-[12px] truncate" style={{ color: '#9C9C9C' }}>📍 {profile.city}</p>}
              </div>
            </div>
            <Link href="/profil/podesavanja" className="btn btn-secondary btn-sm flex-shrink-0">
              <IconSettings size={14} strokeWidth={2.2} />
              Podešavanja
            </Link>
          </div>
        </div>

        {/* ─ Game stats — 4 cards ────────────────────────────────────── */}
        <div className="grid sm:grid-cols-2 gap-3 mb-6">
          {/* PRO kviz */}
          <GameCard
            Icon={IconHome} label="PRO kviz" accent="#609DED" bg="#BCD9FF"
            primary={{ value: sBest, label: 'Rekord bodova' }}
            secondary={[
              { value: sTotal, label: 'Igara' },
              { value: sBestQ, label: 'Max pitanja' },
              { value: sBestCombo, label: 'Najduži niz' },
            ]}
            href="/igraj"
          />
          {/* Trivia duel */}
          <GameCard
            Icon={IconSwords} label="Trivia duel" accent="#9c7a13" bg="#FFECBC"
            primary={{ value: dWins, label: 'Pobeda' }}
            secondary={[
              { value: dTotal, label: 'Duela' },
              { value: dLosses, label: 'Poraza' },
              { value: dDraws, label: 'Nerešeno' },
            ]}
            href="/igraj-zajedno"
          />
          {/* Vešanje */}
          <GameCard
            Icon={IconHint} label="Vešanje" accent="#15803d" bg="#E8F8F0"
            primary={{ value: hWins, label: 'Pobeda' }}
            secondary={[
              { value: hTotal, label: 'Igara' },
              { value: `${hWinRate}%`, label: 'Uspeh' },
              { value: hScore, label: 'Bodovi' },
            ]}
            href="/vesanje"
          />
          {/* Brzi kviz */}
          <GameCard
            Icon={IconTime} label="Brzi kviz" accent="#b91c1c" bg="#FEE2E2"
            primary={{ value: qBest, label: 'Rekord bodova' }}
            secondary={[
              { value: qTotal, label: 'Rundi' },
              { value: qCorrect, label: 'Tačnih' },
              { value: `${qAccuracy}%`, label: 'Tačnost' },
            ]}
            href="/brzi-kviz"
          />
        </div>

        {/* ─ Recent activity (mixed) ────────────────────────────────── */}
        {(sTotal + hTotal + qTotal) > 0 && (
          <div className="card-soft p-6 sm:p-7">
            <h2 className="font-bold text-[16px] mb-5 tracking-tight" style={{ color: '#343434' }}>
              Skorašnja aktivnost
            </h2>
            <div className="space-y-1">
              {recentMix(sSessions, hSessions, qSessions).map((entry, i) => (
                <ActivityRow key={i} entry={entry} />
              ))}
            </div>
          </div>
        )}

        {(sTotal + hTotal + qTotal + dTotal) === 0 && (
          <div className="card-soft p-10 text-center">
            <p className="font-bold text-[17px] mb-2" style={{ color: '#343434' }}>Još nisi igrao</p>
            <p className="text-[14px] mb-6" style={{ color: '#9C9C9C' }}>Izaberi mod i kreni.</p>
            <div className="flex flex-wrap gap-2 justify-center">
              <Link href="/igraj" className="btn btn-primary btn-md">PRO kviz</Link>
              <Link href="/vesanje" className="btn btn-secondary btn-md">Vešanje</Link>
              <Link href="/brzi-kviz" className="btn btn-secondary btn-md">Brzi kviz</Link>
            </div>
          </div>
        )}
      </main>
    </div>
  )
}

// ── Game stat card ──────────────────────────────────────────────────────
function GameCard({ Icon, label, accent, bg, primary, secondary, href }: {
  Icon: React.ComponentType<{ size?: number; strokeWidth?: number; className?: string }>
  label: string; accent: string; bg: string
  primary: { value: number | string; label: string }
  secondary: { value: number | string; label: string }[]
  href: string
}) {
  return (
    <Link href={href} className="card-soft p-5 sm:p-6 transition-all hover:-translate-y-0.5">
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
      <div className="grid grid-cols-3 gap-2 pt-3 border-t" style={{ borderColor: '#F2F2F2' }}>
        {secondary.map((s, i) => (
          <div key={i}>
            <div className="font-bold text-[14px] tracking-tight" style={{ color: '#343434' }}>{s.value}</div>
            <div className="text-[10px]" style={{ color: '#9C9C9C' }}>{s.label}</div>
          </div>
        ))}
      </div>
    </Link>
  )
}

// ── Activity row ────────────────────────────────────────────────────────
type Activity = {
  type: 'survivor' | 'hangman' | 'quick'
  title: string
  detail: string
  score: number | string
  scoreColor: string
  date: Date
}

function recentMix(survivor: SurvivorSession[], hangman: HangmanSession[], quick: QuickSession[]): Activity[] {
  const mix: Activity[] = []
  survivor.forEach(s => {
    const accent = s.score >= 1000 ? '#4CAF50' : s.score >= 500 ? '#FFCB46' : '#609DED'
    mix.push({
      type: 'survivor',
      title: 'PRO kviz',
      detail: `${s.questions_reached} pit. · niz ${s.best_combo} · ${fmtTime(s.total_time_seconds)}`,
      score: s.score,
      scoreColor: accent,
      date: new Date(s.created_at),
    })
  })
  hangman.forEach(h => {
    mix.push({
      type: 'hangman',
      title: 'Vešanje',
      detail: `${h.category || 'Custom'} · ${h.won ? 'pobeda' : 'poraz'} · ${h.wrong_guesses} grešaka`,
      score: h.won ? `+${h.score}` : `${h.score}`,
      scoreColor: h.won ? '#4CAF50' : '#E55353',
      date: new Date(h.created_at),
    })
  })
  quick.forEach(q => {
    mix.push({
      type: 'quick',
      title: 'Brzi kviz',
      detail: `${q.correct_count} tačnih · ${Math.round(Number(q.accuracy))}%`,
      score: q.score,
      scoreColor: q.score >= 100 ? '#4CAF50' : q.score >= 50 ? '#FFCB46' : '#E55353',
      date: new Date(q.created_at),
    })
  })
  return mix.sort((a, b) => b.date.getTime() - a.date.getTime()).slice(0, 12)
}

type SurvivorSession = { score: number; questions_reached: number; correct_answers: number; wrong_answers: number; best_combo: number; total_time_seconds: number; created_at: string }
type HangmanSession = { won: boolean; score: number; word: string; category: string | null; wrong_guesses: number; created_at: string }
type QuickSession = { score: number; correct_count: number; wrong_count: number; accuracy: number | string; total_answered: number; created_at: string }

function ActivityRow({ entry }: { entry: Activity }) {
  return (
    <div className="flex items-center gap-3 py-3 border-b last:border-0" style={{ borderColor: '#F2F2F2' }}>
      <div className="w-12 h-12 rounded-2xl flex items-center justify-center font-black text-[12px] flex-shrink-0"
        style={{ background: entry.scoreColor, color: 'white' }}>
        {entry.score}
      </div>
      <div className="flex-1 min-w-0">
        <p className="font-semibold text-[14px] tracking-tight" style={{ color: '#343434' }}>
          {entry.title}
        </p>
        <p className="text-[12px]" style={{ color: '#9C9C9C' }}>
          {entry.detail} · {entry.date.toLocaleDateString('sr')}
        </p>
      </div>
    </div>
  )
}
