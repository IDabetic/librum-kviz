import { createClient } from '@/lib/supabase/server'
import PrijaveList from './PrijaveList'

export const dynamic = 'force-dynamic'

const SOURCE_TO_EDIT_PATH: Record<string, string | null> = {
  questions: '/majmun/pitanja',
  book_questions: '/majmun/book-kviz',
  kafana_questions: '/majmun/kafana',
  hangman_words: '/majmun/vesanje',
}
const SOURCE_LABEL: Record<string, string> = {
  questions: 'PRO/Brzi/Duel',
  book_questions: 'Book kviz',
  kafana_questions: 'Kafanski kviz',
  hangman_words: 'Vešanje',
}

type SP = { status?: string }

export default async function PrijavePage({ searchParams }: { searchParams: Promise<SP> }) {
  const sp = await searchParams
  const supabase = await createClient()

  let q = supabase
    .from('question_reports')
    .select('id, source, question_id, question_text, reason, status, created_at, resolved_at, profiles!user_id(first_name, nickname)')
    .order('created_at', { ascending: false })
    .limit(500)
  const filter = sp.status ?? 'pending'
  if (filter !== 'all') q = q.eq('status', filter)

  const { data, count } = await q

  // Counts per status for the filter pills.
  const { data: counts } = await supabase
    .from('question_reports')
    .select('status', { count: 'exact', head: false })
  const statusCounts: Record<string, number> = {}
  for (const r of counts ?? []) statusCounts[r.status] = (statusCounts[r.status] ?? 0) + 1

  const rows = (data ?? []).map(r => ({
    id: r.id as string,
    source: r.source as string,
    sourceLabel: SOURCE_LABEL[r.source as string] ?? (r.source as string),
    editPath: SOURCE_TO_EDIT_PATH[r.source as string] ?? null,
    questionId: r.question_id as string,
    questionText: (r.question_text as string) ?? '',
    reason: (r.reason as string) ?? '',
    status: (r.status as string) ?? 'pending',
    createdAt: r.created_at as string,
    resolvedAt: (r.resolved_at as string) ?? null,
    reporterName: (() => {
      const p = Array.isArray(r.profiles) ? r.profiles[0] : r.profiles
      const pp = p as { first_name?: string; nickname?: string } | null
      return pp?.nickname || pp?.first_name || 'Anoniman'
    })(),
  }))

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h1 className="font-black tracking-tight" style={{ color: '#343434', fontSize: 'clamp(22px, 4vw, 28px)' }}>
            Prijavljena pitanja
          </h1>
          <p className="text-[13px] mt-1" style={{ color: '#9C9C9C' }}>
            {count ?? rows.length} ukupno · prikaz: {filter === 'all' ? 'sve' : filter}
          </p>
        </div>
      </div>

      <div className="flex p-1 rounded-full max-w-md" style={{ background: '#F2F2F2' }}>
        {[
          { id: 'pending',  label: `Na čekanju (${statusCounts.pending ?? 0})` },
          { id: 'reviewed', label: `Pregledano (${statusCounts.reviewed ?? 0})` },
          { id: 'resolved', label: `Rešeno (${statusCounts.resolved ?? 0})` },
          { id: 'all',      label: 'Sve' },
        ].map(t => (
          <a key={t.id} href={`/majmun/prijave?status=${t.id}`}
            className="flex-1 py-2 px-3 rounded-full text-[12px] font-semibold transition-all whitespace-nowrap text-center"
            style={filter === t.id
              ? { background: '#FCFCFC', color: '#343434', boxShadow: '0 2px 8px rgba(52,52,52,0.06)' }
              : { color: '#9C9C9C' }}>
            {t.label}
          </a>
        ))}
      </div>

      <PrijaveList rows={rows} />
    </div>
  )
}
