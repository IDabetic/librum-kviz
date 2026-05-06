import { createClient } from '@/lib/supabase/server'
import Header from '@/components/Header'
import Link from 'next/link'
import LeaderboardTabs from './LeaderboardTabs'
import { Logo } from '@/components/Logo'

export const dynamic = 'force-dynamic'

export type SurvivorRow = {
  userId: string
  name: string
  avatar: string | null
  score: number
  questionsReached: number
  correctAnswers: number
  wrongAnswers: number
  accuracy: number
  bestCombo: number
  totalTime: number
  createdAt: string
}

async function loadRows(supabase: Awaited<ReturnType<typeof createClient>>, since: Date | null): Promise<SurvivorRow[]> {
  let q = supabase
    .from('survivor_sessions')
    .select('user_id, score, questions_reached, correct_answers, wrong_answers, accuracy, best_combo, total_time_seconds, created_at, profiles(first_name, last_name, nickname, avatar)')
    .gt('questions_reached', 0)
    .order('score', { ascending: false })
    .order('correct_answers', { ascending: false })
    .order('total_time_seconds', { ascending: true })
    .limit(500)
  if (since) q = q.gte('created_at', since.toISOString())
  const { data } = await q
  // Keep only best run per user (highest score)
  const seen = new Set<string>()
  const rows: SurvivorRow[] = []
  for (const r of (data || [])) {
    if (!r.user_id || seen.has(r.user_id)) continue
    seen.add(r.user_id)
    const prof = Array.isArray(r.profiles) ? r.profiles[0] : r.profiles as { first_name: string; last_name: string; nickname: string; avatar: string } | null
    const name = prof?.nickname || (prof ? `${prof.first_name} ${prof.last_name}`.trim() : 'Igrač')
    rows.push({
      userId: r.user_id,
      name: name || 'Igrač',
      avatar: prof?.avatar || null,
      score: r.score,
      questionsReached: r.questions_reached,
      correctAnswers: r.correct_answers,
      wrongAnswers: r.wrong_answers,
      accuracy: Number(r.accuracy),
      bestCombo: r.best_combo,
      totalTime: r.total_time_seconds,
      createdAt: r.created_at,
    })
    if (rows.length >= 200) break
  }
  return rows
}

export default async function LeaderboardPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  const now = new Date()
  const startOfDay = new Date(now); startOfDay.setHours(0, 0, 0, 0)
  const startOfWeek = new Date(now); startOfWeek.setDate(now.getDate() - 7)
  const startOfMonth = new Date(now); startOfMonth.setDate(now.getDate() - 30)

  const [today, week, month, all] = await Promise.all([
    loadRows(supabase, startOfDay),
    loadRows(supabase, startOfWeek),
    loadRows(supabase, startOfMonth),
    loadRows(supabase, null),
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
            Survivor rang lista
          </p>
          <h1 className="font-black tracking-tight leading-[1.1]" style={{ color: '#343434', fontSize: 'clamp(32px, 5vw, 48px)' }}>
            Najbolji igrači
          </h1>
        </div>
        <LeaderboardTabs today={today} week={week} month={month} all={all} user={!!user} />
      </main>
    </div>
  )
}
