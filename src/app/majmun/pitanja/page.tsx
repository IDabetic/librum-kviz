import { createClient } from '@/lib/supabase/server'
import Link from 'next/link'
import { IconSearch } from '@/components/icons'
import PitanjaList from './PitanjaList'

export const dynamic = 'force-dynamic'

type SP = { q?: string; diff?: string; status?: string; page?: string }

export default async function PitanjaPage({ searchParams }: { searchParams: Promise<SP> }) {
  const sp = await searchParams
  const supabase = await createClient()
  const PER_PAGE = 30
  const page = Math.max(0, parseInt(sp.page || '0', 10))

  // Build query
  let query = supabase
    .from('questions')
    .select('id, question_text, options, correct_answer, difficulty, is_active, times_shown, times_correct, created_at', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(page * PER_PAGE, page * PER_PAGE + PER_PAGE - 1)

  if (sp.q) query = query.ilike('question_text', `%${sp.q}%`)
  if (sp.diff) query = query.eq('difficulty', sp.diff)
  if (sp.status === 'active') query = query.eq('is_active', true)
  if (sp.status === 'inactive') query = query.eq('is_active', false)

  const { data, count } = await query

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
        <button type="submit" className="btn btn-primary btn-md">Pretraži</button>
      </form>

      <PitanjaList rows={data || []} />

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="flex items-center justify-between pt-2">
          <p className="text-[12px]" style={{ color: '#9C9C9C' }}>
            Strana {page + 1} od {totalPages}
          </p>
          <div className="flex gap-2">
            {page > 0 && (
              <Link href={`/majmun/pitanja?page=${page - 1}${sp.q ? `&q=${sp.q}` : ''}${sp.diff ? `&diff=${sp.diff}` : ''}${sp.status ? `&status=${sp.status}` : ''}`}
                className="btn btn-secondary btn-sm">← Prethodna</Link>
            )}
            {page < totalPages - 1 && (
              <Link href={`/majmun/pitanja?page=${page + 1}${sp.q ? `&q=${sp.q}` : ''}${sp.diff ? `&diff=${sp.diff}` : ''}${sp.status ? `&status=${sp.status}` : ''}`}
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
