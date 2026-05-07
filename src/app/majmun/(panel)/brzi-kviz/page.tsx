import { createClient } from '@/lib/supabase/server'
import Link from 'next/link'
import { IconSearch } from '@/components/icons'
import BrziList from './BrziList'

export const dynamic = 'force-dynamic'

type SP = { q?: string; status?: string; ans?: string; page?: string; per?: string }

const PER_OPTIONS = [25, 50, 100]

export default async function BrziAdminPage({ searchParams }: { searchParams: Promise<SP> }) {
  const sp = await searchParams
  const supabase = await createClient()
  const PER_PAGE = PER_OPTIONS.includes(parseInt(sp.per || '50', 10))
    ? parseInt(sp.per!, 10)
    : 50
  const page = Math.max(0, parseInt(sp.page || '0', 10))

  function buildQS(override: Partial<SP>): string {
    const params = new URLSearchParams()
    const merged = { q: sp.q, status: sp.status, ans: sp.ans, per: String(PER_PAGE), ...override }
    for (const [k, v] of Object.entries(merged)) {
      if (v !== undefined && v !== '' && v !== null) params.set(k, String(v))
    }
    return params.toString()
  }

  let query = supabase
    .from('quick_statements')
    .select('*', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(page * PER_PAGE, page * PER_PAGE + PER_PAGE - 1)

  if (sp.q) query = query.ilike('statement', `%${sp.q}%`)
  if (sp.status === 'active') query = query.eq('is_active', true)
  if (sp.status === 'inactive') query = query.eq('is_active', false)
  if (sp.ans === 'true') query = query.eq('correct_answer', true)
  if (sp.ans === 'false') query = query.eq('correct_answer', false)

  const { data, count } = await query
  const totalPages = Math.ceil((count ?? 0) / PER_PAGE)

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h1 className="font-black tracking-tight" style={{ color: '#343434', fontSize: 'clamp(22px, 4vw, 28px)' }}>
            Brzi kviz tvrdnje
          </h1>
          <p className="text-[13px] mt-1" style={{ color: '#9C9C9C' }}>{count ?? 0} ukupno</p>
        </div>
        <Link href="/majmun/brzi-kviz/novo" className="btn btn-primary btn-md">+ Nova tvrdnja</Link>
      </div>

      <form className="card-soft p-4 flex items-center gap-2 flex-wrap" action="/majmun/brzi-kviz">
        <div className="relative flex-1 min-w-[200px]">
          <div className="absolute left-4 top-1/2 -translate-y-1/2" style={{ color: '#9C9C9C' }}>
            <IconSearch size={16} strokeWidth={2.2} />
          </div>
          <input name="q" defaultValue={sp.q || ''} className="input pl-11" placeholder="Pretraga…" />
        </div>
        <select name="ans" defaultValue={sp.ans || ''} className="input flex-shrink-0" style={{ width: 'auto', minWidth: 130 }}>
          <option value="">Svi odgovori</option>
          <option value="true">Tačno</option>
          <option value="false">Netačno</option>
        </select>
        <select name="status" defaultValue={sp.status || ''} className="input flex-shrink-0" style={{ width: 'auto', minWidth: 130 }}>
          <option value="">Svi statusi</option>
          <option value="active">Aktivno</option>
          <option value="inactive">Neaktivno</option>
        </select>
        <select name="per" defaultValue={String(PER_PAGE)} className="input flex-shrink-0" style={{ width: 'auto', minWidth: 90 }}>
          {PER_OPTIONS.map(n => <option key={n} value={n}>{n}/str.</option>)}
        </select>
        <button type="submit" className="btn btn-primary btn-md">Pretraži</button>
      </form>

      <BrziList rows={data || []} />

      {totalPages > 1 && (
        <div className="flex items-center justify-between pt-2">
          <p className="text-[12px]" style={{ color: '#9C9C9C' }}>Strana {page + 1} od {totalPages}</p>
          <div className="flex gap-2">
            {page > 0 && <Link href={`/majmun/brzi-kviz?${buildQS({ page: String(page - 1) })}`} className="btn btn-secondary btn-sm">← Prethodna</Link>}
            {page < totalPages - 1 && <Link href={`/majmun/brzi-kviz?${buildQS({ page: String(page + 1) })}`} className="btn btn-primary btn-sm">Sledeća →</Link>}
          </div>
        </div>
      )}
    </div>
  )
}
