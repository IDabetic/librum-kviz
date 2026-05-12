import type { Metadata } from 'next'
import { createClient } from '@/lib/supabase/server'
import Header from '@/components/Header'
import Link from 'next/link'
import LeaderboardTabs from './LeaderboardTabs'
import { Logo } from '@/components/Logo'

import Footer from '@/components/Footer'

export const dynamic = 'force-dynamic'

export const metadata: Metadata = {
  title: 'Rang lista – kviz sa rang listom, najbolji igrači Librum kviza',
  description: 'Rang lista Librum kviza – najbolji igrači u PRO kvizu, kafanskom kvizu, Book kvizu, trivia duelu, vešanju i Brzom kvizu. Kviz sa rang listom za takmičenje na srpskom.',
  keywords: [
    'rang lista', 'kviz sa rang listom', 'kviz za takmičenje',
    'kviz takmičenje online', 'najbolji igrači kviz', 'top igrači',
    'kviz pobednici', 'Librum kviz', 'kviz Srbija', 'kviz na srpskom',
  ],
  alternates: { canonical: '/leaderboard' },
  openGraph: {
    title: 'Rang lista – Librum Kviz',
    description: 'Najbolji rezultati u svim igrama Librum kviza.',
    url: 'https://kviz.librum.club/leaderboard',
    type: 'website',
    images: ['/og-share.jpg?v=6'],
  },
}

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
export type BookRow = {
  userId: string; name: string; avatar: string | null
  score: number; questionsReached: number; accuracy: number
  topGenre: string | null; topGenrePct: number | null
}
export type KafanaRow = {
  userId: string; name: string; avatar: string | null
  score: number; questionsReached: number; accuracy: number; bestCombo: number
}

type Period = 'today' | 'week' | 'month' | 'all'
type SB = Awaited<ReturnType<typeof createClient>>

// "Danas" must mean midnight in the user's timezone (Belgrade). Vercel
// runs the server in UTC, so a naive setHours(0,0,0,0) would cut the
// day at UTC midnight (01:00 or 02:00 Belgrade depending on DST). This
// helper formats today's calendar date in Belgrade, computes the
// running offset (handles DST automatically), and returns the UTC
// instant that corresponds to 00:00 in Belgrade.
const TZ = 'Europe/Belgrade'

function startOfTodayInTZ(): Date {
  const now = new Date()
  const day = new Intl.DateTimeFormat('en-CA', {
    timeZone: TZ, year: 'numeric', month: '2-digit', day: '2-digit',
  }).format(now)
  const beoHour = parseInt(new Intl.DateTimeFormat('en-US', {
    timeZone: TZ, hour: '2-digit', hour12: false,
  }).format(now), 10)
  let offsetH = beoHour - now.getUTCHours()
  if (offsetH > 12) offsetH -= 24
  if (offsetH < -12) offsetH += 24
  const sign = offsetH >= 0 ? '+' : '-'
  const offsetStr = `${sign}${String(Math.abs(offsetH)).padStart(2, '0')}:00`
  return new Date(`${day}T00:00:00${offsetStr}`)
}

function startOf(period: Period): Date | null {
  if (period === 'all') return null
  if (period === 'today') return startOfTodayInTZ()
  // Rolling 7- / 30-day windows from now (UTC arithmetic is fine here —
  // the comparison is against created_at as an instant, no calendar
  // boundary).
  const d = new Date()
  if (period === 'week') d.setUTCDate(d.getUTCDate() - 7)
  if (period === 'month') d.setUTCDate(d.getUTCDate() - 30)
  return d
}

function pickName(prof: { first_name?: string; last_name?: string; nickname?: string } | null): string {
  if (!prof) return 'Igrač'
  return prof.nickname || `${prof.first_name || ''} ${prof.last_name || ''}`.trim() || 'Igrač'
}

// Resolve display info for a batch of user_ids via public_profiles
// (a SECURITY-DEFINER view exposing only first_name/last_name/nickname/
// avatar). We never embed `profiles(...)` anymore — that would hit the
// locked-down profiles table and return nothing to anon.
type ProfMap = Record<string, { name: string; avatar: string | null }>
async function loadProfileMap(supabase: SB, userIds: string[]): Promise<ProfMap> {
  const ids = [...new Set(userIds.filter(Boolean))]
  if (ids.length === 0) return {}
  const { data } = await supabase
    .from('public_profiles')
    .select('id, first_name, last_name, nickname, avatar')
    .in('id', ids)
  const map: ProfMap = {}
  for (const p of (data || []) as { id: string; first_name: string; last_name: string; nickname: string; avatar: string | null }[]) {
    map[p.id] = { name: pickName(p), avatar: p.avatar || null }
  }
  return map
}

// ── SURVIVOR ─────────────────────────────────────────────────────────────
async function loadSurvivor(supabase: SB, since: Date | null): Promise<SurvivorRow[]> {
  let q = supabase
    .from('survivor_sessions')
    .select('user_id, score, questions_reached, correct_answers, accuracy, best_combo, total_time_seconds')
    .order('score', { ascending: false })
    .limit(500)
  if (since) q = q.gte('created_at', since.toISOString())
  const { data } = await q
  const profMap = await loadProfileMap(supabase, (data || []).map(r => r.user_id))
  const seen = new Set<string>()
  const rows: SurvivorRow[] = []
  for (const r of (data || [])) {
    if (!r.user_id || seen.has(r.user_id)) continue
    seen.add(r.user_id)
    const p = profMap[r.user_id]
    rows.push({
      userId: r.user_id, name: p?.name || 'Igrač', avatar: p?.avatar || null,
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
  // New spec: a duel is finished when status='finished'. Older rooms may
  // only have host_finished/guest_finished — keep them for back-compat.
  let q = supabase
    .from('game_rooms')
    .select('host_id, guest_id, host_score, guest_score, host_finished, guest_finished, status')
    .not('guest_id', 'is', null)
    .limit(1000)
  if (since) q = q.gte('created_at', since.toISOString())
  const { data: games } = await q

  const userIds = [...new Set((games || []).flatMap(g => [g.host_id, g.guest_id]).filter(Boolean))] as string[]
  if (userIds.length === 0) return []
  const profMap = await loadProfileMap(supabase, userIds)

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
    // Accept either: new-flow (status=finished) OR old-flow (both finished flags)
    const isFinished = g.status === 'finished' || (g.host_finished && g.guest_finished)
    if (!isFinished) return
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
    .select('user_id, won, score')
    .limit(2000)
  if (since) q = q.gte('created_at', since.toISOString())
  const { data } = await q

  const profMap = await loadProfileMap(supabase, (data || []).map(r => r.user_id))
  const map: Record<string, HangmanRow> = {}
  ;(data || []).forEach(r => {
    if (!r.user_id) return
    const p = profMap[r.user_id]
    if (!map[r.user_id]) map[r.user_id] = {
      userId: r.user_id, name: p?.name || 'Igrač', avatar: p?.avatar || null,
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

// ── BOOK KVIZ ────────────────────────────────────────────────────────────
async function loadBook(supabase: SB, since: Date | null): Promise<BookRow[]> {
  let q = supabase
    .from('book_sessions')
    .select('user_id, score, questions_reached, accuracy, top_genre, top_genre_pct')
    .order('score', { ascending: false })
    .limit(500)
  if (since) q = q.gte('created_at', since.toISOString())
  const { data } = await q
  const profMap = await loadProfileMap(supabase, (data || []).map(r => r.user_id))
  const seen = new Set<string>()
  const rows: BookRow[] = []
  for (const r of (data || [])) {
    if (!r.user_id || seen.has(r.user_id)) continue
    seen.add(r.user_id)
    const p = profMap[r.user_id]
    rows.push({
      userId: r.user_id, name: p?.name || 'Igrač', avatar: p?.avatar || null,
      score: r.score, questionsReached: r.questions_reached, accuracy: Number(r.accuracy),
      topGenre: r.top_genre, topGenrePct: r.top_genre_pct != null ? Number(r.top_genre_pct) : null,
    })
    if (rows.length >= 200) break
  }
  return rows
}

// ── KAFANSKI KVIZ ────────────────────────────────────────────────────────
// Combined solo + duel board: a player's record on this list is the
// max score they've ever scored in any Kafana mode (solo run or
// finished duel). Duel rows contribute the player's own side's score,
// not the duel total. Solo rows still drive the secondary stats
// (questions_reached / accuracy / best_combo) since duels don't track
// those per-player.
async function loadKafana(supabase: SB, since: Date | null): Promise<KafanaRow[]> {
  let solo = supabase
    .from('kafana_sessions')
    .select('user_id, score, questions_reached, accuracy, best_combo')
    .order('score', { ascending: false })
    .limit(500)
  if (since) solo = solo.gte('created_at', since.toISOString())

  let duel = supabase
    .from('game_rooms')
    .select('host_id, guest_id, host_score, guest_score, host_finished, guest_finished, status, quiz_type')
    .eq('quiz_type', 'kafana')
    .not('guest_id', 'is', null)
    .limit(1000)
  if (since) duel = duel.gte('created_at', since.toISOString())

  const [{ data: soloData }, { data: duelData }] = await Promise.all([solo, duel])

  // Single profile lookup for everyone — solo players + duel players.
  const allUserIds = [
    ...((soloData || []).map(r => r.user_id)),
    ...((duelData || []).flatMap(g => [g.host_id, g.guest_id])),
  ].filter((x): x is string => !!x)
  const profMap = await loadProfileMap(supabase, allUserIds)

  // Walk solo first (already sorted desc by score) so a player's
  // best solo session populates secondary stats; later duel scores
  // only bump the headline score if higher.
  const map: Record<string, KafanaRow> = {}
  for (const r of (soloData || [])) {
    if (!r.user_id) continue
    const p = profMap[r.user_id]
    if (!map[r.user_id]) {
      map[r.user_id] = {
        userId: r.user_id, name: p?.name || 'Igrač', avatar: p?.avatar || null,
        score: r.score ?? 0, questionsReached: r.questions_reached ?? 0,
        accuracy: Number(r.accuracy ?? 0), bestCombo: r.best_combo ?? 0,
      }
    } else if ((r.score ?? 0) > map[r.user_id].score) {
      map[r.user_id].score = r.score ?? 0
    }
  }

  for (const g of (duelData || [])) {
    const isFinished = g.status === 'finished' || (g.host_finished && g.guest_finished)
    if (!isFinished || !g.host_id || !g.guest_id) continue
    function bump(uid: string, score: number) {
      if (!map[uid]) {
        const p = profMap[uid]
        map[uid] = {
          userId: uid, name: p?.name || 'Igrač', avatar: p?.avatar || null,
          score, questionsReached: 0, accuracy: 0, bestCombo: 0,
        }
      } else if (score > map[uid].score) {
        map[uid].score = score
      }
    }
    bump(g.host_id, g.host_score ?? 0)
    bump(g.guest_id, g.guest_score ?? 0)
  }

  return Object.values(map)
    .filter(r => r.score > 0)
    .sort((a, b) => b.score - a.score)
    .slice(0, 200)
}

// ── BRZI KVIZ ────────────────────────────────────────────────────────────
async function loadQuick(supabase: SB, since: Date | null): Promise<QuickRow[]> {
  let q = supabase
    .from('quick_sessions')
    .select('user_id, score, correct_count, wrong_count, accuracy, total_answered')
    .order('score', { ascending: false })
    .limit(500)
  if (since) q = q.gte('created_at', since.toISOString())
  const { data } = await q

  const profMap = await loadProfileMap(supabase, (data || []).map(r => r.user_id))
  const seen = new Set<string>()
  const rows: QuickRow[] = []
  for (const r of (data || [])) {
    if (!r.user_id || seen.has(r.user_id)) continue
    seen.add(r.user_id)
    const p = profMap[r.user_id]
    rows.push({
      userId: r.user_id, name: p?.name || 'Igrač', avatar: p?.avatar || null,
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

  const [survivor, duel, hangman, quick, book, kafana] = await Promise.all([
    loadAllPeriods(loadSurvivor, supabase),
    loadAllPeriods(loadDuel, supabase),
    loadAllPeriods(loadHangman, supabase),
    loadAllPeriods(loadQuick, supabase),
    loadAllPeriods(loadBook, supabase),
    loadAllPeriods(loadKafana, supabase),
  ])

  return (
    <div className="min-h-screen" style={{ background: '#FAFAFA' }}>
      {user && <Header />}
      {!user && (
        <nav className="sticky top-0 z-40 backdrop-blur-xl"
          style={{ background: 'rgba(252,252,252,0.78)', borderBottom: '1px solid rgba(52,52,52,0.06)' }}>
          <div className="max-w-6xl mx-auto px-4 sm:px-6 h-16 flex items-center justify-between">
            <Logo height={36} />
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
        <LeaderboardTabs survivor={survivor} duel={duel} hangman={hangman} quick={quick} book={book} kafana={kafana} user={!!user} />
      </main>
      <Footer />
    </div>
  )
}
