import { createClient } from '@/lib/supabase/server'
import Link from 'next/link'
import { IconSearch } from '@/components/icons'
import KafanaList from './KafanaList'

export const dynamic = 'force-dynamic'

const PER_OPTIONS = [25, 50, 100]

type SP = { q?: string; status?: string; page?: string; per?: string }

export default async function KafanskiKvizAdminPage({ searchParams }: { searchParams: Promise<SP> }) {
  const sp = await searchParams
  const supabase = await createClient()
  const parsedPer = parseInt(sp.per || '50', 10)
  const PER_PAGE = PER_OPTIONS.includes(parsedPer) ? parsedPer : 50
  const page = Math.max(0, parseInt(sp.page || '0', 10))

  function buildQS(override: Partial<SP>): string {
    const params = new URLSearchParams()
    const merged: Partial<SP> = { q: sp.q, status: sp.status, per: String(PER_PAGE), ...override }
    for (const [k, v] of Object.entries(merged)) {
      if (v !== undefined && v !== '' && v !== null) params.set(k, String(v))
    }
    return params.toString()
  }

  let query = supabase
    .from('kafana_questions')
    .select('id, question_text, options, correct_answer, difficulty, is_active, created_at', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(page * PER_PAGE, page * PER_PAGE + PER_PAGE - 1)
  if (sp.q) query = query.ilike('question_text', `%${sp.q}%`)
  if (sp.status === 'active') query = query.eq('is_active', true)
  if (sp.status === 'inactive') query = query.eq('is_active', false)

  const { data, count } = await query
  const totalPages = Math.ceil((count ?? 0) / PER_PAGE)

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h1 className="font-black tracking-tight" style={{ color: '#343434', fontSize: 'clamp(22px, 4vw, 28px)' }}>
            Kafanski kviz pitanja
          </h1>
          <p className="text-[13px] mt-1" style={{ color: '#9C9C9C' }}>
            {count ?? 0} ukupno · {sp.q ? `pretraga "${sp.q}"` : 'svi rezultati'}
          </p>
        </div>
        <div className="flex gap-2 flex-wrap">
          <Link href="/majmun/kafana/uvoz" className="btn btn-secondary btn-md">📥 Excel uvoz</Link>
          <Link href="/majmun/kafana/mesanje" className="btn btn-secondary btn-md">🔀 Mešanje</Link>
          <Link href="/majmun/kafana/novo" className="btn btn-primary btn-md">+ Novo pitanje</Link>
        </div>
      </div>

      <div className="rounded-2xl px-4 py-3 text-[12px] font-medium flex items-start gap-2"
        style={{ background: '#FEE2E2', color: '#b91c1c' }}>
        <span className="text-[14px] leading-none mt-px">🎵</span>
        <span>
          Pitanja koja ovde dodaješ <strong>vide se samo u Kafanskom kvizu</strong> (solo i duel). Ne ulaze u PRO ni Brzi kviz.
        </span>
      </div>

      <form className="card-soft p-4 flex items-center gap-2 flex-wrap" action="/majmun/kafana">
        <div className="relative flex-1 min-w-[200px]">
          <div className="absolute left-4 top-1/2 -translate-y-1/2" style={{ color: '#9C9C9C' }}>
            <IconSearch size={16} strokeWidth={2.2} />
          </div>
          <input name="q" defaultValue={sp.q || ''} className="input pl-11" placeholder="Pretraga po tekstu pitanja…" />
        </div>
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

      <KafanaList rows={data || []} />

      {totalPages > 1 && (
        <div className="flex items-center justify-between pt-2">
          <p className="text-[12px]" style={{ color: '#9C9C9C' }}>Strana {page + 1} od {totalPages}</p>
          <div className="flex gap-2">
            {page > 0 && <Link href={`/majmun/kafana?${buildQS({ page: String(page - 1) })}`} className="btn btn-secondary btn-sm">← Prethodna</Link>}
            {page < totalPages - 1 && <Link href={`/majmun/kafana?${buildQS({ page: String(page + 1) })}`} className="btn btn-primary btn-sm">Sledeća →</Link>}
          </div>
        </div>
      )}
    </div>
  )
}
