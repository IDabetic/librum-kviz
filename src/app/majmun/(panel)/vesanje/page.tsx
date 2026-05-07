import { createClient } from '@/lib/supabase/server'
import Link from 'next/link'
import { IconSearch } from '@/components/icons'
import VesanjeList from './VesanjeList'

export const dynamic = 'force-dynamic'

type SP = { q?: string; cat?: string; status?: string; page?: string; per?: string }
const CATS = ['Sport', 'Geografija', 'Istorija', 'Kultura', 'Priroda', 'Predmeti']
const PER_OPTIONS = [25, 50, 100]

export default async function VesanjeAdminPage({ searchParams }: { searchParams: Promise<SP> }) {
  const sp = await searchParams
  const supabase = await createClient()
  const PER = PER_OPTIONS.includes(parseInt(sp.per || '50', 10)) ? parseInt(sp.per!, 10) : 50
  const page = Math.max(0, parseInt(sp.page || '0', 10))

  let query = supabase.from('hangman_words').select('*', { count: 'exact' })
    .order('created_at', { ascending: false }).range(page * PER, page * PER + PER - 1)
  if (sp.q) query = query.ilike('word', `%${sp.q}%`)
  if (sp.cat) query = query.eq('category', sp.cat)
  if (sp.status === 'active') query = query.eq('is_active', true)
  if (sp.status === 'inactive') query = query.eq('is_active', false)

  const { data, count } = await query
  const totalPages = Math.ceil((count ?? 0) / PER)

  function buildQS(override: Partial<SP>): string {
    const params = new URLSearchParams()
    const merged = { q: sp.q, cat: sp.cat, status: sp.status, per: String(PER), ...override }
    for (const [k, v] of Object.entries(merged)) {
      if (v !== undefined && v !== '' && v !== null) params.set(k, String(v))
    }
    return params.toString()
  }

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h1 className="font-black tracking-tight" style={{ color: '#343434', fontSize: 'clamp(22px, 4vw, 28px)' }}>Vešanje pojmovi</h1>
          <p className="text-[13px] mt-1" style={{ color: '#9C9C9C' }}>{count ?? 0} ukupno</p>
        </div>
        <Link href="/majmun/vesanje/novo" className="btn btn-primary btn-md">+ Novi pojam</Link>
      </div>

      <form className="card-soft p-4 flex items-center gap-2 flex-wrap" action="/majmun/vesanje">
        <div className="relative flex-1 min-w-[200px]">
          <div className="absolute left-4 top-1/2 -translate-y-1/2" style={{ color: '#9C9C9C' }}><IconSearch size={16} strokeWidth={2.2} /></div>
          <input name="q" defaultValue={sp.q || ''} className="input pl-11" placeholder="Pretraga reči…" />
        </div>
        <select name="cat" defaultValue={sp.cat || ''} className="input flex-shrink-0" style={{ width: 'auto', minWidth: 130 }}>
          <option value="">Sve kategorije</option>
          {CATS.map(c => <option key={c} value={c}>{c}</option>)}
        </select>
        <select name="status" defaultValue={sp.status || ''} className="input flex-shrink-0" style={{ width: 'auto', minWidth: 130 }}>
          <option value="">Svi statusi</option>
          <option value="active">Aktivno</option>
          <option value="inactive">Neaktivno</option>
        </select>
        <select name="per" defaultValue={String(PER)} className="input flex-shrink-0" style={{ width: 'auto', minWidth: 90 }}>
          {PER_OPTIONS.map(n => <option key={n} value={n}>{n}/str.</option>)}
        </select>
        <button type="submit" className="btn btn-primary btn-md">Pretraži</button>
      </form>

      <VesanjeList rows={data || []} />

      {totalPages > 1 && (
        <div className="flex items-center justify-between pt-2">
          <p className="text-[12px]" style={{ color: '#9C9C9C' }}>Strana {page + 1} od {totalPages}</p>
          <div className="flex gap-2">
            {page > 0 && <Link href={`/majmun/vesanje?${buildQS({ page: String(page - 1) })}`} className="btn btn-secondary btn-sm">← Prethodna</Link>}
            {page < totalPages - 1 && <Link href={`/majmun/vesanje?${buildQS({ page: String(page + 1) })}`} className="btn btn-primary btn-sm">Sledeća →</Link>}
          </div>
        </div>
      )}
    </div>
  )
}
