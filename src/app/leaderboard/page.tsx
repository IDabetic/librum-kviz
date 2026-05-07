import { createClient } from '@/lib/supabase/server'
import Header from '@/components/Header'
import Link from 'next/link'
import LeaderboardTabs from './LeaderboardTabs'
import { Logo } from '@/components/Logo'

export const dynamic = 'force-dynamic'

export type SurvivorRow = {
  userId: string; name: string; avatar: string | null
  score: number; questionsReached: number; correctAnswers: number
  accuracy: number; bestCombo: number; totalTime: number
}
export type DuelRow = {
  userId: string; name: string; avatar: string | null
  wins: number; losses: number; draws: number; plays: number
}
export type HangmanRow = {
  userId: string; name: string; avatar: string | null
  total: number; wins: number; winRate: number; bestScore: number; totalScore: number
}
export type QuickRow = {
  userId: string; name: string; avatar: string | null
  score: number; correct: number; wrong: number; accuracy: number; totalAnswered: number
}

type Period = 'today' | 'week' | 'month' | 'all'
type SB = Awaited<ReturnType<typeof createClient>>

function startOf(period: Period): Date | null {
  const now = new Date()
  if (period === 'all') return null
  const d = new Date(now)
  if (period === 'today') d.setHours(0, 0, 0, 0)
  if (period === 'week') d.setDate(now.getDate() - 7)
  if (period === 'month') d.setDate(now.getDate() - 30)
  return d
}

function pickName(prof: { first_name?: string; last_name?: string; nickname?: string } | null): string {
  if (!prof) return 'Igrač'
  return prof.nickname || `${prof.first_name || ''} ${prof.last_name || ''}`.trim() || 'Igrač'
}

// ── SURVIVOR ─────────────────────────────────────────────────────────────
async function loadSurvivor(supabase: SB, since: Date | null): Promise<SurvivorRow[]> {
  let q = supabase
    .from('survivor_sessions')
    .select('user_id, score, questions_reached, correct_answers, accuracy, best_combo, total_time_seconds, profiles(first_name, last_name, nickname, avatar)')
    .order('score', { ascending: false })
    .limit(500)
  if (since) q = q.gte('created_at', since.toISOString())
  const { data } = await q
  const seen = new Set<string>()
  const rows: SurvivorRow[] = []
  for (const r of (data || [])) {
    if (!r.user_id || seen.has(r.user_id)) continue
    seen.add(r.user_id)
    const prof = Array.isArray(r.profiles) ? r.profiles[0] : r.profiles as { first_name: string; last_name: string; nickname: string; avatar: string } | null
    rows.push({
      userId: r.user_id, name: pickName(prof), avatar: prof?.avatar || null,
      score: r.score, questionsReached: r.questions_reached,
      correctAnswers: r.correct_answers, accuracy: Number(r.accuracy),
      bestCombo: r.best_combo, totalTime: r.total_time_seconds,
    })
    if (rows.length >= 200) break
  }
  return rows
}

// ── DUEL ─────────────────────────────────────────────────────────────────
async function loadDuel(supabase: SB, since: Date | null): Promise<DuelRow[]> {
  let q = supabase
    .from('game_rooms')
    .select('host_id, guest_id, host_score, guest_score, host_finished, guest_finished, game_format')
    .or('status.eq.finished,host_finished.eq.true,guest_finished.eq.true')
    .not('guest_id', 'is', null)
    .limit(1000)
  if (since) q = q.gte('created_at', since.toISOString())
  const { data: games } = await q

  const userIds = [...new Set((games || []).flatMap(g => [g.host_id, g.guest_id]).filter(Boolean))] as string[]
  if (userIds.length === 0) return []
  const { data: profData } = await supabase
    .from('profiles').select('id, first_name, last_name, nickname, avatar').in('id', userIds)
  const profMap: Record<string, { name: string; avatar: string | null }> = {}
  ;(profData || []).forEach((p: { id: string; first_name: string; last_name: string; nickname: string; avatar: string }) => {
    profMap[p.id] = { name: pickName(p), avatar: p.avatar || null }
  })

  const map: Record<string, DuelRow> = {}
  function record(uid: string, my: number, op: number) {
    if (!map[uid]) map[uid] = {
      userId: uid, name: profMap[uid]?.name || 'Igrač', avatar: profMap[uid]?.avatar || null,
      wins: 0, losses: 0, draws: 0, plays: 0,
    }
    map[uid].plays++
    if (my > op) map[uid].wins++
    else if (my < op) map[uid].losses++
    else map[uid].draws++
  }
  ;(games || []).forEach(g => {
    if (!g.host_id || !g.guest_id) return
    if (!g.host_finished || !g.guest_finished) return
    record(g.host_id, g.host_score ?? 0, g.guest_score ?? 0)
    record(g.guest_id, g.guest_score ?? 0, g.host_score ?? 0)
  })

  return Object.values(map)
    .sort((a, b) => b.wins - a.wins || a.losses - b.losses)
    .slice(0, 200)
}

// ── HANGMAN ──────────────────────────────────────────────────────────────
async function loadHangman(supabase: SB, since: Date | null): Promise<HangmanRow[]> {
  let q = supabase
    .from('hangman_sessions')
    .select('user_id, won, score, profiles(first_name, last_name, nickname, avatar)')
    .limit(2000)
  if (since) q = q.gte('created_at', since.toISOString())
  const { data } = await q

  const map: Record<string, HangmanRow> = {}
  ;(data || []).forEach(r => {
    if (!r.user_id) return
    const prof = Array.isArray(r.profiles) ? r.profiles[0] : r.profiles as { first_name: string; last_name: string; nickname: string; avatar: string } | null
    if (!map[r.user_id]) map[r.user_id] = {
      userId: r.user_id, name: pickName(prof), avatar: prof?.avatar || null,
      total: 0, wins: 0, winRate: 0, bestScore: 0, totalScore: 0,
    }
    map[r.user_id].total++
    if (r.won) map[r.user_id].wins++
    map[r.user_id].totalScore += r.score ?? 0
    map[r.user_id].bestScore = Math.max(map[r.user_id].bestScore, r.score ?? 0)
  })
  Object.values(map).forEach(r => { r.winRate = r.total > 0 ? Math.round((r.wins / r.total) * 100) : 0 })
  return Object.values(map)
    .sort((a, b) => b.wins - a.wins || b.totalScore - a.totalScore)
    .slice(0, 200)
}

// ── BRZI KVIZ ────────────────────────────────────────────────────────────
async function loadQuick(supabase: SB, since: Date | null): Promise<QuickRow[]> {
  let q = supabase
    .from('quick_sessions')
    .select('user_id, score, correct_count, wrong_count, accuracy, total_answered, profiles(first_name, last_name, nickname, avatar)')
    .order('score', { ascending: false })
    .limit(500)
  if (since) q = q.gte('created_at', since.toISOString())
  const { data } = await q

  const seen = new Set<string>()
  const rows: QuickRow[] = []
  for (const r of (data || [])) {
    if (!r.user_id || seen.has(r.user_id)) continue
    seen.add(r.user_id)
    const prof = Array.isArray(r.profiles) ? r.profiles[0] : r.profiles as { first_name: string; last_name: string; nickname: string; avatar: string } | null
    rows.push({
      userId: r.user_id, name: pickName(prof), avatar: prof?.avatar || null,
      score: r.score, correct: r.correct_count, wrong: r.wrong_count,
      accuracy: Number(r.accuracy), totalAnswered: r.total_answered,
    })
    if (rows.length >= 200) break
  }
  return rows
}

export type AllPeriods<T> = { today: T[]; week: T[]; month: T[]; all: T[] }

async function loadAllPeriods<T>(loader: (sb: SB, since: Date | null) => Promise<T[]>, sb: SB): Promise<AllPeriods<T>> {
  const [today, week, month, all] = await Promise.all([
    loader(sb, startOf('today')),
    loader(sb, startOf('week')),
    loader(sb, startOf('month')),
    loader(sb, null),
  ])
  return { today, week, month, all }
}

export default async function LeaderboardPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  const [survivor, duel, hangman, quick] = await Promise.all([
    loadAllPeriods(loadSurvivor, supabase),
    loadAllPeriods(loadDuel, supabase),
    loadAllPeriods(loadHangman, supabase),
    loadAllPeriods(loadQuick, supabase),
  ])

  return (
    <div className="min-h-screen" style={{ background: '#FAFAFA' }}>
      {user && <Header />}
      {!user && (
        <nav className="sticky top-0 z-40 backdrop-blur-xl"
          style={{ background: 'rgba(252,252,252,0.78)', borderBottom: '1px solid rgba(52,52,52,0.06)' }}>
          <div className="max-w-6xl mx-auto px-4 sm:px-6 h-16 flex items-center justify-between">
            <Logo height={28} />
            <Link href="/auth/prijava" className="btn btn-primary btn-sm">Prijava</Link>
          </div>
        </nav>
      )}
      <main className="max-w-3xl mx-auto px-4 sm:px-6 py-10 sm:py-14">
        <div className="text-center mb-10">
          <p className="text-[13px] font-bold uppercase tracking-widest mb-2" style={{ color: '#609DED' }}>
            Najbolji igrači
          </p>
          <h1 className="font-black tracking-tight leading-[1.1]" style={{ color: '#343434', fontSize: 'clamp(32px, 5vw, 48px)' }}>
            Rang lista
          </h1>
        </div>
        <LeaderboardTabs survivor={survivor} duel={duel} hangman={hangman} quick={quick} user={!!user} />
      </main>
    </div>
  )
}
