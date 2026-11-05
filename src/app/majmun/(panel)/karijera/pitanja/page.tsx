import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { IconSearch } from '@/components/icons'

export const dynamic = 'force-dynamic'

type SP = { q?: string; struka?: string; posle?: string }
type Pitanje = { id: string; pozicija: string; question_text: string; options: string[]; correct_answer: number; is_active: boolean; prijava: number }

const PO_STRANI = 50

/** Pitanja struka (karijera_pitanja): pretraga po tekstu, filter po struci, izmena i zamena na strani pitanja. */
export default async function PitanjaStrukaPage({ searchParams }: { searchParams: Promise<SP> }) {
  const sp = await searchParams
  const supabase = await createClient()
  const [{ data, error }, { data: pozicije }] = await Promise.all([
    supabase.rpc('admin_karijera_pitanja', {
      p_trazi: sp.q?.trim() || null, p_pozicija: sp.struka || null,
      p_posle: sp.posle && /^[0-9a-f-]{36}$/i.test(sp.posle) ? sp.posle : null, p_broj: PO_STRANI,
    }),
    supabase.from('karijera_pozicije').select('id, naziv').order('redosled'),
  ])
  const pitanja = (data ?? []) as Pitanje[]
  const nazivStruke = new Map((pozicije ?? []).map(p => [p.id as string, p.naziv as string]))

  function dalje(): string {
    const p = new URLSearchParams()
    if (sp.q) p.set('q', sp.q)
    if (sp.struka) p.set('struka', sp.struka)
    p.set('posle', pitanja[pitanja.length - 1].id)
    return `/majmun/karijera/pitanja?${p}`
  }

  return (
    <div className="space-y-5">
      <div>
        <Link href="/majmun/karijera" className="text-[13px] font-medium hover:underline" style={{ color: '#12907E' }}>← Karijerista</Link>
        <h1 className="font-black tracking-tight mt-2" style={{ color: '#151515', fontSize: 'clamp(22px, 4vw, 28px)' }}>Pitanja struka</h1>
        <p className="text-[13px] mt-1" style={{ color: '#6F6C66' }}>
          Pitanja koja Karijerista daje po struci. Opšta pitanja koja Karijerista takođe koristi menjaju se u delu Pitanja.
        </p>
      </div>

      <form className="card-soft p-4 flex items-center gap-2 flex-wrap" action="/majmun/karijera/pitanja">
        <div className="relative flex-1 min-w-[200px]">
          <div className="absolute left-4 top-1/2 -translate-y-1/2" style={{ color: '#6F6C66' }}><IconSearch size={16} strokeWidth={2.2} /></div>
          <label className="sr-only" htmlFor="q">Pretraga</label>
          <input id="q" name="q" defaultValue={sp.q || ''} className="input pl-11" placeholder="Pretraga po tekstu pitanja…" />
        </div>
        <label className="sr-only" htmlFor="struka">Struka</label>
        <select id="struka" name="struka" defaultValue={sp.struka || ''} className="input flex-shrink-0" style={{ width: 'auto', minWidth: 180 }}>
          <option value="">Sve struke</option>
          {(pozicije ?? []).map(p => <option key={p.id as string} value={p.id as string}>{p.naziv as string}</option>)}
        </select>
        <button type="submit" className="btn btn-primary btn-md">Pretraži</button>
      </form>

      {error ? (
        <div className="card-soft p-5 text-[14px]" style={{ color: '#C42B4F' }}>Pitanja nisu učitana: {error.message}</div>
      ) : pitanja.length === 0 ? (
        <div className="card-soft p-8 text-center text-[14px]" style={{ color: '#6F6C66' }}>Nema pitanja za ovu pretragu.</div>
      ) : (
        <div className="card-soft divide-y divide-[#E7E1D0]">
          {pitanja.map(q => (
            <Link key={q.id} href={`/majmun/karijera/pitanja/${q.id}`} className="block px-5 py-3.5 hover:bg-[#F7F4EC] transition-colors">
              <p className="text-[14px] font-semibold" style={{ color: q.is_active ? '#151515' : '#6F6C66' }}>{q.question_text}</p>
              <p className="text-[12px] mt-1" style={{ color: '#6F6C66' }}>
                {nazivStruke.get(q.pozicija) ?? q.pozicija} · tačno: <span style={{ color: '#12907E' }}>{q.options[q.correct_answer]}</span>
                {!q.is_active && <span style={{ color: '#C42B4F' }}> · ugašeno</span>}
                {q.prijava > 0 && <strong style={{ color: '#C42B4F' }}> · {q.prijava} prijava</strong>}
              </p>
            </Link>
          ))}
        </div>
      )}

      {pitanja.length === PO_STRANI && (
        <div className="flex justify-end"><Link href={dalje()} className="btn btn-secondary btn-sm">Sledećih {PO_STRANI}</Link></div>
      )}
    </div>
  )
}
