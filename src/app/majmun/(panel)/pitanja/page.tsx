import { createClient } from '@/lib/supabase/server'
import Link from 'next/link'
import { IconSearch } from '@/components/icons'
import PitanjaList, { type Row as PitanjeRow } from './PitanjaList'

export const dynamic = 'force-dynamic'

type SP = { q?: string; diff?: string; status?: string; flag?: string; sort?: string; page?: string; per?: string }

const PER_OPTIONS = [25, 50, 100]

export default async function PitanjaPage({ searchParams }: { searchParams: Promise<SP> }) {
  const sp = await searchParams
  const supabase = await createClient()
  const PER_PAGE = PER_OPTIONS.includes(parseInt(sp.per || '50', 10))
    ? parseInt(sp.per!, 10)
    : 50
  const page = Math.max(0, parseInt(sp.page || '0', 10))
  const sort = sp.sort || 'created'

  function buildQS(override: Partial<SP>): string {
    const params = new URLSearchParams()
    const merged: Partial<SP> = { q: sp.q, diff: sp.diff, status: sp.status, flag: sp.flag, sort: sp.sort, per: String(PER_PAGE), ...override }
    for (const [k, v] of Object.entries(merged)) {
      if (v !== undefined && v !== '' && v !== null) params.set(k, String(v))
    }
    return params.toString()
  }

  // Build query
  let query = supabase
    .from('questions')
    .select('id, question_text, options, correct_answer, difficulty, is_active, times_shown, times_correct, created_at', { count: 'exact' })
    .range(page * PER_PAGE, page * PER_PAGE + PER_PAGE - 1)

  if (sp.q) query = query.ilike('question_text', `%${sp.q}%`)
  if (sp.diff) query = query.eq('difficulty', sp.diff)
  if (sp.status === 'active') query = query.eq('is_active', true)
  if (sp.status === 'inactive') query = query.eq('is_active', false)

  switch (sort) {
    case 'shown_desc': query = query.order('times_shown', { ascending: false }); break
    case 'shown_asc':  query = query.order('times_shown', { ascending: true });  break
    case 'created':
    default:           query = query.order('created_at', { ascending: false }); break
  }

  const { data: questions, count } = await query

  // Pull aggregated answer-log stats for this page's questions
  const ids = (questions || []).map(q => q.id)
  const { data: stats } = ids.length
    ? await supabase.from('question_stats')
        .select('question_id, log_count, avg_time_ms, log_correct, log_wrong, log_accuracy_pct')
        .in('question_id', ids)
    : { data: [] as { question_id: string; log_count: number; avg_time_ms: number | null; log_correct: number; log_wrong: number; log_accuracy_pct: number | null }[] }

  const statMap = new Map((stats || []).map(s => [s.question_id, s]))

  let rows: PitanjeRow[] = (questions || []).map(q => {
    const s = statMap.get(q.id)
    const tShown = q.times_shown || 0
    const accuracy = s?.log_accuracy_pct ?? (tShown > 0 ? Math.round((q.times_correct / tShown) * 100) : null)
    const total = s?.log_count ?? tShown
    const flags: PitanjeRow['flags'] = []
    if (total >= 10 && accuracy !== null) {
      if (accuracy > 90) flags.push('prelako')
      else if (accuracy < 20) flags.push('preteško')
    }
    if (s?.avg_time_ms != null && s.avg_time_ms > 12000) flags.push('sporo')
    return {
      id: q.id,
      question_text: q.question_text,
      options: q.options,
      correct_answer: q.correct_answer,
      difficulty: q.difficulty,
      is_active: q.is_active,
      times_shown: q.times_shown,
      times_correct: q.times_correct,
      created_at: q.created_at,
      log_count: s?.log_count ?? 0,
      avg_time_ms: s?.avg_time_ms ?? null,
      accuracy_pct: accuracy,
      flags,
    }
  })

  // Client-side filter on flags + alternate sorts that need stats
  if (sp.flag) {
    rows = rows.filter(r => r.flags.includes(sp.flag as PitanjeRow['flags'][number]))
  }
  if (sort === 'time_desc') rows.sort((a, b) => (b.avg_time_ms || 0) - (a.avg_time_ms || 0))
  else if (sort === 'time_asc') rows.sort((a, b) => (a.avg_time_ms || Infinity) - (b.avg_time_ms || Infinity))
  else if (sort === 'acc_asc') rows.sort((a, b) => (a.accuracy_pct ?? 100) - (b.accuracy_pct ?? 100))
  else if (sort === 'acc_desc') rows.sort((a, b) => (b.accuracy_pct ?? -1) - (a.accuracy_pct ?? -1))

  const totalPages = Math.ceil((count ?? 0) / PER_PAGE)

  return (
    <div className="space-y-5">

      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h1 className="font-black tracking-tight" style={{ color: '#343434', fontSize: 'clamp(22px, 4vw, 28px)' }}>
            PRO pitanja
          </h1>
          <p className="text-[13px] mt-1" style={{ color: '#9C9C9C' }}>
            {fmtN(count ?? 0)} ukupno · {sp.q ? `pretraga "${sp.q}"` : 'svi rezultati'}
          </p>
        </div>
        <Link href="/majmun/pitanja/novo" className="btn btn-primary btn-md">
          + Novo pitanje
        </Link>
      </div>

      {/* Filters */}
      <form className="card-soft p-4 flex items-center gap-2 flex-wrap" action="/majmun/pitanja">
        <div className="relative flex-1 min-w-[200px]">
          <div className="absolute left-4 top-1/2 -translate-y-1/2" style={{ color: '#9C9C9C' }}>
            <IconSearch size={16} strokeWidth={2.2} />
          </div>
          <input name="q" defaultValue={sp.q || ''} className="input pl-11" placeholder="Pretraga po tekstu pitanja…" />
        </div>
        <select name="diff" defaultValue={sp.diff || ''}
          className="input flex-shrink-0" style={{ width: 'auto', minWidth: 130 }}>
          <option value="">Sve težine</option>
          <option value="easy">Lako</option>
          <option value="medium">Srednje</option>
          <option value="hard">Teško</option>
          <option value="impossible">Nemoguće</option>
        </select>
        <select name="status" defaultValue={sp.status || ''}
          className="input flex-shrink-0" style={{ width: 'auto', minWidth: 130 }}>
          <option value="">Svi statusi</option>
          <option value="active">Aktivno</option>
          <option value="inactive">Neaktivno</option>
        </select>
        <select name="flag" defaultValue={sp.flag || ''}
          className="input flex-shrink-0" style={{ width: 'auto', minWidth: 140 }}>
          <option value="">Svi flagovi</option>
          <option value="prelako">⚠ Prelako (&gt;90% tačnih)</option>
          <option value="preteško">⚠ Preteško (&lt;20% tačnih)</option>
          <option value="sporo">⏱ Sporo (avg &gt;12s)</option>
        </select>
        <select name="sort" defaultValue={sort}
          className="input flex-shrink-0" style={{ width: 'auto', minWidth: 140 }}>
          <option value="created">Novija prvo</option>
          <option value="shown_desc">Najprikazivanija</option>
          <option value="shown_asc">Najmanje prikazano</option>
          <option value="acc_asc">Najteža (najmanje tačno)</option>
          <option value="acc_desc">Najlakša (najviše tačno)</option>
          <option value="time_desc">Najsporija</option>
          <option value="time_asc">Najbrža</option>
        </select>
        <select name="per" defaultValue={String(PER_PAGE)}
          className="input flex-shrink-0" style={{ width: 'auto', minWidth: 90 }}>
          {PER_OPTIONS.map(n => <option key={n} value={n}>{n}/str.</option>)}
        </select>
        <button type="submit" className="btn btn-primary btn-md">Pretraži</button>
      </form>

      <PitanjaList rows={rows} />

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="flex items-center justify-between pt-2">
          <p className="text-[12px]" style={{ color: '#9C9C9C' }}>
            Strana {page + 1} od {totalPages}
          </p>
          <div className="flex gap-2">
            {page > 0 && (
              <Link href={`/majmun/pitanja?${buildQS({ page: String(page - 1) })}`}
                className="btn btn-secondary btn-sm">← Prethodna</Link>
            )}
            {page < totalPages - 1 && (
              <Link href={`/majmun/pitanja?${buildQS({ page: String(page + 1) })}`}
                className="btn btn-primary btn-sm">Sledeća →</Link>
            )}
          </div>
        </div>
      )}
    </div>
  )
}

function fmtN(n: number): string {
  return new Intl.NumberFormat('sr').format(n)
}
