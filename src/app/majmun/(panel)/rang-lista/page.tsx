import { createClient } from '@/lib/supabase/server'
import RangListaTabs from './RangListaTabs'

export const dynamic = 'force-dynamic'

type SP = { period?: string }

// Map UI period → since-instant (UTC). Belgrade timezone is close
// enough to UTC for admin-side filtering; we don't need the
// DST-aware helper that the public leaderboard uses.
function sinceFor(period: string | undefined): Date | null {
  const now = new Date()
  if (period === 'today') {
    const d = new Date(now); d.setUTCHours(0, 0, 0, 0); return d
  }
  if (period === '7d') {
    const d = new Date(now); d.setUTCDate(d.getUTCDate() - 7); return d
  }
  if (period === '30d') {
    const d = new Date(now); d.setUTCDate(d.getUTCDate() - 30); return d
  }
  return null  // 'all'
}

export default async function RangListaAdmin({ searchParams }: { searchParams: Promise<SP> }) {
  const sp = await searchParams
  const period = sp.period ?? 'all'
  const since = sinceFor(period)

  const supabase = await createClient()

  // ── Pull each game's top sessions in parallel ────────────────────
  const survQ = supabase.from('survivor_sessions')
    .select('id, score, questions_reached, accuracy, total_time_seconds, created_at, user_id')
    .order('score', { ascending: false }).limit(100)
  const bookQ = supabase.from('book_sessions')
    .select('id, score, questions_reached, accuracy, top_genre, created_at, user_id')
    .order('score', { ascending: false }).limit(100)
  const kafQ = supabase.from('kafana_sessions')
    .select('id, score, questions_reached, accuracy, best_combo, created_at, user_id')
    .order('score', { ascending: false }).limit(100)
  const hangQ = supabase.from('hangman_sessions')
    .select('id, won, score, word, category, created_at, user_id')
    .order('created_at', { ascending: false }).limit(100)
  const quickQ = supabase.from('quick_sessions')
    .select('id, score, correct_count, accuracy, created_at, user_id')
    .order('score', { ascending: false }).limit(100)
  const duelQ = supabase.from('game_rooms')
    .select('id, host_id, guest_id, host_score, guest_score, host_finished, guest_finished, status, quiz_type, created_at')
    .not('guest_id', 'is', null)
    .order('created_at', { ascending: false }).limit(100)

  if (since) {
    const iso = since.toISOString()
    survQ.gte('created_at', iso)
    bookQ.gte('created_at', iso)
    kafQ.gte('created_at', iso)
    hangQ.gte('created_at', iso)
    quickQ.gte('created_at', iso)
    duelQ.gte('created_at', iso)
  }

  const [survivor, book, kafana, hangman, quick, duels] = await Promise.all([
    survQ, bookQ, kafQ, hangQ, quickQ, duelQ,
  ])

  // Resolve names in a single round-trip via the safe view.
  const userIds = [...new Set([
    ...(survivor.data || []).map(r => r.user_id),
    ...(book.data || []).map(r => r.user_id),
    ...(kafana.data || []).map(r => r.user_id),
    ...(hangman.data || []).map(r => r.user_id),
    ...(quick.data || []).map(r => r.user_id),
    ...(duels.data || []).flatMap(r => [r.host_id, r.guest_id]),
  ].filter((x): x is string => !!x))]

  type ProfRow = { id: string; first_name: string | null; nickname: string | null }
  const { data: profs } = userIds.length
    ? await supabase
        .from('public_profiles')
        .select('id, first_name, nickname')
        .in('id', userIds)
    : { data: [] as ProfRow[] }
  const profMap = new Map<string, ProfRow>(
    ((profs ?? []) as ProfRow[]).map(p => [p.id, p])
  )
  function name(uid: string | null | undefined): string {
    if (!uid) return 'Igrač'
    const p = profMap.get(uid)
    return p?.nickname || p?.first_name || 'Igrač'
  }

  // ── Build "Sumnjive partije" feed — sessions that smell like cheating
  // (sub-2s avg per question OR perfect 100% across 20+ questions).
  type Suspicious = {
    id: string; game: string; user: string; score: number;
    reason: string; created_at: string; table: string;
  }
  const suspicious: Suspicious[] = []
  for (const r of survivor.data || []) {
    const avgSec = r.questions_reached > 0 ? r.total_time_seconds / r.questions_reached : null
    if (avgSec !== null && avgSec < 2 && r.questions_reached >= 5) {
      suspicious.push({
        id: r.id, game: 'PRO', user: name(r.user_id), score: r.score,
        reason: `${avgSec.toFixed(1)}s po pitanju · ${r.questions_reached} pitanja`,
        created_at: r.created_at, table: 'survivor_sessions',
      })
    } else if (Number(r.accuracy) === 100 && r.questions_reached >= 20) {
      suspicious.push({
        id: r.id, game: 'PRO', user: name(r.user_id), score: r.score,
        reason: `100% tačnost preko ${r.questions_reached} pitanja`,
        created_at: r.created_at, table: 'survivor_sessions',
      })
    }
  }
  for (const r of book.data || []) {
    if (Number(r.accuracy) === 100 && r.questions_reached >= 20) {
      suspicious.push({
        id: r.id, game: 'Book', user: name(r.user_id), score: r.score,
        reason: `100% tačnost preko ${r.questions_reached} pitanja`,
        created_at: r.created_at, table: 'book_sessions',
      })
    }
  }
  for (const r of kafana.data || []) {
    if (Number(r.accuracy) === 100 && r.questions_reached >= 20) {
      suspicious.push({
        id: r.id, game: 'Kafanski', user: name(r.user_id), score: r.score,
        reason: `100% tačnost preko ${r.questions_reached} pitanja`,
        created_at: r.created_at, table: 'kafana_sessions',
      })
    }
  }
  suspicious.sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())

  // ── Decorate rows with resolved names ────────────────────────────
  const survivorRows = (survivor.data || []).map(r => ({ ...r, name: name(r.user_id) }))
  const bookRows = (book.data || []).map(r => ({ ...r, name: name(r.user_id) }))
  const kafanaRows = (kafana.data || []).map(r => ({ ...r, name: name(r.user_id) }))
  const hangmanRows = (hangman.data || []).map(r => ({ ...r, name: name(r.user_id) }))
  const quickRows = (quick.data || []).map(r => ({ ...r, name: name(r.user_id) }))
  const duelRows = (duels.data || []).map(r => ({
    ...r,
    host_name: name(r.host_id),
    guest_name: name(r.guest_id),
  }))

  // Period pill links — keep the picked tab when switching period.
  const periods = [
    { id: 'today', label: 'Danas' },
    { id: '7d',    label: '7 dana' },
    { id: '30d',   label: '30 dana' },
    { id: 'all',   label: 'Sve' },
  ]

  return (
    <div className="space-y-5">
      <div>
        <h1 className="font-black tracking-tight" style={{ color: '#343434', fontSize: 'clamp(22px, 4vw, 28px)' }}>Rang liste</h1>
        <p className="text-[13px] mt-1" style={{ color: '#9C9C9C' }}>
          Pregled i moderacija sesija. Sumnjive partije se mogu obrisati.
        </p>
      </div>

      {/* Period filter — server-rendered pills (no client state needed). */}
      <div className="flex p-1 rounded-full max-w-md" style={{ background: '#F2F2F2' }}>
        {periods.map(p => (
          <a key={p.id} href={`/majmun/rang-lista?period=${p.id}`}
            className="flex-1 py-2 px-3 rounded-full text-[12px] font-semibold text-center transition-all"
            style={period === p.id
              ? { background: '#FCFCFC', color: '#343434', boxShadow: '0 2px 8px rgba(52,52,52,0.06)' }
              : { color: '#9C9C9C' }}>
            {p.label}
          </a>
        ))}
      </div>

      <RangListaTabs
        survivor={survivorRows}
        book={bookRows}
        kafana={kafanaRows}
        hangman={hangmanRows}
        quick={quickRows}
        duels={duelRows}
        suspicious={suspicious}
      />
    </div>
  )
}
