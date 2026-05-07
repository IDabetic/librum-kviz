import { createClient } from '@/lib/supabase/server'
import Link from 'next/link'
import Image from 'next/image'
import { notFound } from 'next/navigation'
import { IconBack } from '@/components/icons'
import RoleEditor from './RoleEditor'

export const dynamic = 'force-dynamic'

export default async function UserProfile({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const supabase = await createClient()
  const { data: u } = await supabase.from('profiles')
    .select('id, first_name, last_name, nickname, avatar, email, city, role, created_at')
    .eq('id', id).single()
  if (!u) notFound()

  // Aggregate stats — pull all sessions for this user across all 4 games + answer log
  const [survivor, hangman, quick, duelHost, duelGuest, answerLog] = await Promise.all([
    supabase.from('survivor_sessions')
      .select('score, questions_reached, best_combo, total_time_seconds, accuracy, correct_answers, wrong_answers, created_at')
      .eq('user_id', id).order('created_at', { ascending: false }).limit(50),
    supabase.from('hangman_sessions').select('won, score, time_seconds, category, created_at')
      .eq('user_id', id).order('created_at', { ascending: false }).limit(50),
    supabase.from('quick_sessions').select('score, correct_count, wrong_count, total_answered, accuracy, duration_seconds, created_at')
      .eq('user_id', id).order('created_at', { ascending: false }).limit(50),
    supabase.from('game_rooms')
      .select('id, status, host_score, guest_score, host_finished, guest_finished, created_at')
      .eq('host_id', id).eq('status', 'finished').order('created_at', { ascending: false }).limit(50),
    supabase.from('game_rooms')
      .select('id, status, host_score, guest_score, host_finished, guest_finished, created_at')
      .eq('guest_id', id).eq('status', 'finished').order('created_at', { ascending: false }).limit(50),
    supabase.from('question_answer_log')
      .select('question_id, was_correct, time_ms, created_at')
      .eq('user_id', id)
      .order('created_at', { ascending: false }),
  ])

  const survivorRows = survivor.data || []
  const hangmanRows = hangman.data || []
  const quickRows = quick.data || []

  const sBest = survivorRows.length ? Math.max(...survivorRows.map(s => s.score)) : 0
  const sTotal = survivorRows.length
  const hWins = hangmanRows.filter(h => h.won).length
  const hTotal = hangmanRows.length
  const qBest = quickRows.length ? Math.max(...quickRows.map(q => q.score)) : 0
  const qTotal = quickRows.length

  // Trivia duel: combine host + guest games, count wins
  const duels = [
    ...(duelHost.data || []).map(r => ({ ...r, mine: r.host_score, theirs: r.guest_score })),
    ...(duelGuest.data || []).map(r => ({ ...r, mine: r.guest_score, theirs: r.host_score })),
  ]
  const duelTotal = duels.length
  const duelWins = duels.filter(d => (d.mine ?? 0) > (d.theirs ?? 0)).length
  const duelLosses = duels.filter(d => (d.mine ?? 0) < (d.theirs ?? 0)).length
  const duelTies = duels.filter(d => (d.mine ?? 0) === (d.theirs ?? 0)).length
  const duelWinPct = duelTotal > 0 ? Math.round((duelWins / duelTotal) * 100) : null

  // Last activity = most recent timestamp across any session
  const allDates = [
    ...survivorRows.map(s => s.created_at),
    ...hangmanRows.map(h => h.created_at),
    ...quickRows.map(q => q.created_at),
    ...duels.map(d => d.created_at),
  ].filter(Boolean)
  const lastActivity = allDates.length ? new Date(Math.max(...allDates.map(d => new Date(d).getTime()))) : null

  // Aggregate from per-answer log (more precise than session-level avg)
  const logRows = answerLog.data || []
  const logTotal = logRows.length
  const logCorrect = logRows.filter(l => l.was_correct).length
  const logAccuracy = logTotal > 0 ? Math.round((logCorrect / logTotal) * 100) : null
  const logAvgMs = logTotal > 0
    ? logRows.reduce((s, l) => s + l.time_ms, 0) / logTotal
    : null
  const logMinMs = logTotal > 0 ? Math.min(...logRows.map(l => l.time_ms)) : null
  const logMaxMs = logTotal > 0 ? Math.max(...logRows.map(l => l.time_ms)) : null

  // Last 10 answers with the actual question text
  const last10 = logRows.slice(0, 10)
  const last10Ids = Array.from(new Set(last10.map(l => l.question_id).filter((v): v is string => !!v)))
  const { data: last10Questions } = last10Ids.length
    ? await supabase.from('questions').select('id, question_text').in('id', last10Ids)
    : { data: [] as { id: string; question_text: string }[] }
  const questionMap = new Map((last10Questions || []).map(q => [q.id, q.question_text]))

  // Avg time per question (PRO + Brzi). Hangman is per-letter so we skip.
  const proPerQ = survivorRows.reduce((acc, s) => {
    if (s.questions_reached > 0) { acc.sum += s.total_time_seconds / s.questions_reached; acc.n += 1 }
    return acc
  }, { sum: 0, n: 0 })
  const proAvgSecPerQ = proPerQ.n ? proPerQ.sum / proPerQ.n : null

  const quickPerQ = quickRows.reduce((acc, q) => {
    if (q.total_answered > 0) { acc.sum += q.duration_seconds / q.total_answered; acc.n += 1 }
    return acc
  }, { sum: 0, n: 0 })
  const quickAvgSecPerQ = quickPerQ.n ? quickPerQ.sum / quickPerQ.n : null

  function fmtSec(v: number | null): string {
    if (v == null) return '—'
    return `${v.toFixed(1)}s`
  }
  function fmtMs(v: number | null): string {
    if (v == null) return '—'
    return `${(v / 1000).toFixed(1)}s`
  }
  function fmtAgo(d: Date): string {
    const diffMs = Date.now() - d.getTime()
    const mins = Math.floor(diffMs / 60000)
    if (mins < 1) return 'upravo'
    if (mins < 60) return `pre ${mins} min`
    const hours = Math.floor(mins / 60)
    if (hours < 24) return `pre ${hours}h`
    const days = Math.floor(hours / 24)
    if (days < 7) return `pre ${days} dan${days > 1 ? 'a' : ''}`
    return d.toLocaleDateString('sr')
  }

  const name = u.nickname || `${u.first_name || ''} ${u.last_name || ''}`.trim() || 'Igrač'

  return (
    <div className="max-w-3xl space-y-5">

      <Link href="/majmun/korisnici" className="inline-flex items-center gap-1.5 text-[13px] font-medium transition-opacity hover:opacity-70" style={{ color: '#609DED' }}>
        <IconBack size={16} strokeWidth={2.2} /> Svi korisnici
      </Link>

      <div className="card-soft p-6">
        <div className="flex items-center gap-4 mb-5">
          <div className="w-16 h-16 rounded-2xl overflow-hidden flex-shrink-0 bg-[#F2F2F2]">
            {u.avatar
              ? <Image src={`/avatars/${u.avatar}`} alt={name} width={64} height={64} className="w-full h-full object-cover" />
              : <div className="w-full h-full flex items-center justify-center font-bold text-[20px] text-white" style={{ background: '#609DED' }}>{name[0]}</div>}
          </div>
          <div className="min-w-0 flex-1">
            <h1 className="font-black tracking-tight truncate" style={{ color: '#343434', fontSize: 'clamp(20px, 4vw, 26px)' }}>{name}</h1>
            <p className="text-[13px] truncate" style={{ color: '#9C9C9C' }}>{u.email}{u.city ? ` · ${u.city}` : ''}</p>
            <p className="text-[11px] mt-0.5" style={{ color: '#9C9C9C' }}>
              ID: {u.id.substring(0, 8)}… · Pridružio se {new Date(u.created_at).toLocaleDateString('sr')}
              {lastActivity && ` · Poslednja aktivnost ${fmtAgo(lastActivity)}`}
            </p>
          </div>
        </div>

        <RoleEditor userId={u.id} currentRole={u.role} />
      </div>

      {/* Per-answer log overview (most precise time data) */}
      {logTotal > 0 && (
        <div className="card-soft p-5">
          <p className="text-[11px] font-bold uppercase tracking-widest mb-3" style={{ color: '#9C9C9C' }}>
            Pojedinačni odgovori (PRO + Brzi)
          </p>
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
            <Stat label="Ukupno odgovora" value={logTotal} />
            <Stat label="Tačnost" value={`${logAccuracy}%`} tone={logAccuracy != null && logAccuracy > 90 ? 'warn' : undefined} />
            <Stat label="Prosečno vreme" value={fmtMs(logAvgMs)} tone={logAvgMs != null && logAvgMs < 3000 ? 'bad' : undefined} />
            <Stat label="Najbrže" value={fmtMs(logMinMs)} />
            <Stat label="Najsporije" value={fmtMs(logMaxMs)} />
          </div>
        </div>
      )}

      {/* Last 10 individual answers — text + time + correct/wrong */}
      {last10.length > 0 && (
        <div className="card-soft p-5">
          <p className="text-[11px] font-bold uppercase tracking-widest mb-3" style={{ color: '#9C9C9C' }}>
            Poslednjih {last10.length} odgovora
          </p>
          <div className="space-y-1">
            {last10.map((l, i) => {
              const text = l.question_id ? questionMap.get(l.question_id) : null
              const sec = (l.time_ms / 1000).toFixed(1)
              const fast = l.time_ms < 3000
              return (
                <div key={i} className="flex items-start gap-3 py-2.5 border-b last:border-0" style={{ borderColor: '#F2F2F2' }}>
                  <div className="w-6 h-6 rounded-full flex items-center justify-center flex-shrink-0 text-[12px] font-bold"
                    style={{
                      background: l.was_correct ? '#E8F8F0' : '#FEE2E2',
                      color: l.was_correct ? '#15803d' : '#b91c1c',
                    }}>
                    {l.was_correct ? '✓' : '✗'}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-[13px] leading-snug line-clamp-2" style={{ color: '#343434' }}>
                      {text || <span style={{ color: '#9C9C9C' }}>(pitanje obrisano)</span>}
                    </p>
                    <p className="text-[11px] mt-0.5" style={{ color: '#9C9C9C' }}>
                      {new Date(l.created_at).toLocaleString('sr', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' })}
                    </p>
                  </div>
                  <div className="font-bold text-[13px] flex-shrink-0 tabular-nums"
                    style={{ color: fast ? '#E55353' : '#343434' }}>
                    {sec}s
                  </div>
                </div>
              )
            })}
          </div>
        </div>
      )}

      <div className="grid sm:grid-cols-2 gap-3">
        <StatCard label="PRO kviz" total={sTotal} primary={sBest} primaryLabel="Rekord" accent="#609DED" bg="#BCD9FF"
          extra={proAvgSecPerQ != null ? `Prosek ${fmtSec(proAvgSecPerQ)} po pitanju` : undefined} />
        <StatCard label="Trivia duel" total={duelTotal}
          primary={duelWinPct != null ? `${duelWinPct}%` : '—'}
          primaryLabel={`${duelWins}W · ${duelLosses}L · ${duelTies}T`}
          accent="#9c7a13" bg="#FFECBC" />
        <StatCard label="Vešanje" total={hTotal} primary={hWins} primaryLabel="Pobeda" accent="#15803d" bg="#E8F8F0" />
        <StatCard label="Brzi kviz" total={qTotal} primary={qBest} primaryLabel="Rekord" accent="#b91c1c" bg="#FEE2E2"
          extra={quickAvgSecPerQ != null ? `Prosek ${fmtSec(quickAvgSecPerQ)} po pitanju` : undefined} />
      </div>

      {/* Recent PRO sessions */}
      {survivorRows.length > 0 && (
        <div className="card-soft p-5">
          <p className="text-[11px] font-bold uppercase tracking-widest mb-3" style={{ color: '#9C9C9C' }}>Skorašnje PRO partije</p>
          <div className="space-y-1">
            {survivorRows.slice(0, 8).map((s, i) => {
              const secPerQ = s.questions_reached > 0 ? s.total_time_seconds / s.questions_reached : null
              const fast = secPerQ != null && secPerQ < 5
              return (
                <div key={i} className="flex items-center justify-between gap-3 py-2 border-b last:border-0" style={{ borderColor: '#F2F2F2' }}>
                  <div className="text-[13px] flex-1 min-w-0" style={{ color: '#343434' }}>
                    {s.questions_reached} pitanja · niz {s.best_combo} · {Number(s.accuracy).toFixed(0)}% tačnih
                  </div>
                  <div className="text-[12px] flex-shrink-0" style={{ color: fast ? '#E55353' : '#9C9C9C' }}>
                    {secPerQ != null ? `${secPerQ.toFixed(1)}s/pit` : '—'}
                  </div>
                  <div className="font-bold text-[14px] w-12 text-right" style={{ color: '#609DED' }}>{s.score}</div>
                </div>
              )
            })}
          </div>
        </div>
      )}

      {/* Recent duels */}
      {duels.length > 0 && (
        <div className="card-soft p-5">
          <p className="text-[11px] font-bold uppercase tracking-widest mb-3" style={{ color: '#9C9C9C' }}>Skorašnji dueli</p>
          <div className="space-y-1">
            {duels.slice(0, 8).map((d, i) => {
              const result = (d.mine ?? 0) > (d.theirs ?? 0) ? { l: 'Pobeda', c: '#15803d' }
                          : (d.mine ?? 0) < (d.theirs ?? 0) ? { l: 'Poraz',  c: '#b91c1c' }
                          : { l: 'Nereš.', c: '#9C9C9C' }
              return (
                <div key={d.id || i} className="flex items-center justify-between gap-3 py-2 border-b last:border-0" style={{ borderColor: '#F2F2F2' }}>
                  <div className="text-[13px] flex-1 min-w-0" style={{ color: '#343434' }}>
                    {new Date(d.created_at!).toLocaleDateString('sr')}
                  </div>
                  <div className="text-[12px] flex-shrink-0 font-semibold" style={{ color: result.c }}>{result.l}</div>
                  <div className="font-bold text-[14px] w-20 text-right" style={{ color: '#343434' }}>{d.mine ?? 0} : {d.theirs ?? 0}</div>
                </div>
              )
            })}
          </div>
        </div>
      )}
    </div>
  )
}

function Stat({ label, value, tone }: {
  label: string; value: number | string; tone?: 'ok' | 'warn' | 'bad'
}) {
  const color =
    tone === 'ok'   ? '#15803d' :
    tone === 'warn' ? '#9c7a13' :
    tone === 'bad'  ? '#b91c1c' :
                      '#343434'
  return (
    <div className="rounded-2xl p-3 text-center" style={{ background: '#F2F2F2' }}>
      <div className="font-black text-[16px] tracking-tight" style={{ color }}>{value}</div>
      <div className="text-[10px] mt-0.5" style={{ color: '#9C9C9C' }}>{label}</div>
    </div>
  )
}

function StatCard({ label, total, primary, primaryLabel, accent, bg, extra }: {
  label: string; total: number; primary: number | string; primaryLabel: string; accent: string; bg: string; extra?: string
}) {
  return (
    <div className="card-soft p-5">
      <div className="flex items-center gap-2 mb-3">
        <div className="w-2 h-2 rounded-full" style={{ background: accent }} />
        <p className="font-bold text-[13px] tracking-tight" style={{ color: '#343434' }}>{label}</p>
      </div>
      <p className="font-black tracking-tight leading-none" style={{ color: accent, fontSize: 'clamp(22px, 4vw, 28px)' }}>{primary}</p>
      <p className="text-[11px] mt-1" style={{ color: '#9C9C9C' }}>{primaryLabel} · {total} sesija</p>
      {extra && <p className="text-[11px] mt-0.5" style={{ color: '#9C9C9C' }}>{extra}</p>}
      <div className="mt-3 h-1 rounded-full" style={{ background: bg }} />
    </div>
  )
}
