import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { vremeKratko } from '../igre-nazivi'

export const dynamic = 'force-dynamic'

type Soba = {
  id: string; nacin: string; velicina: number; teren: string; status: string; napravljena: string; pocela: string | null
  privatna: boolean; savez: boolean; igraci: string | null; poteza: number
}

const STATUS: Record<string, { naziv: string; boja: string }> = {
  ceka: { naziv: 'čeka igrače', boja: '#8A6A12' },
  pocela: { naziv: 'počela', boja: '#0E6F61' },
}
const NACIN: Record<string, string> = { svakoZaSebe: 'Svako za sebe', timovi: 'Timovi', jedanNaJedan: 'Jedan na jedan' }

/** Osvajanje sveta: sobe za igru preko mreže (ko igra, koliko poteza); partije protiv računara su u Aktivnosti. */
export default async function OsvajanjePage({ searchParams }: { searchParams: Promise<{ pre?: string }> }) {
  const { pre } = await searchParams
  const supabase = await createClient()
  const { data, error } = await supabase.rpc('admin_osvajanje_sobe', { p_pre: pre && !Number.isNaN(Date.parse(pre)) ? pre : null, p_broj: 50 })
  const sobe = (data ?? []) as Soba[]

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h1 className="font-black tracking-tight" style={{ color: '#151515', fontSize: 'clamp(22px, 4vw, 28px)' }}>Osvajanje sveta</h1>
          <p className="text-[13px] mt-1" style={{ color: '#6F6C66' }}>Sobe za igru sa drugim igračima, najnovije prve.</p>
        </div>
        <Link href="/majmun/aktivnost?igra=osvajanje" className="btn btn-secondary btn-md">Sve partije</Link>
      </div>

      {error ? (
        <div className="card-soft p-5 text-[14px]" style={{ color: '#C42B4F' }}>Sobe nisu učitane: {error.message}</div>
      ) : sobe.length === 0 ? (
        <div className="card-soft p-8 text-center text-[14px]" style={{ color: '#6F6C66' }}>Još nema soba.</div>
      ) : (
        <div className="card-soft overflow-x-auto">
          <table className="w-full text-[13px]">
            <thead>
              <tr className="text-left text-[11px] uppercase tracking-wider" style={{ color: '#6F6C66' }}>
                <th className="px-4 py-3 font-bold">Napravljena</th>
                <th className="px-4 py-3 font-bold">Stanje</th>
                <th className="px-4 py-3 font-bold">Način</th>
                <th className="px-4 py-3 font-bold">Igrači</th>
                <th className="px-4 py-3 font-bold text-right">Poteza</th>
              </tr>
            </thead>
            <tbody>
              {sobe.map(s => {
                const st = STATUS[s.status] ?? { naziv: s.status, boja: '#6F6C66' }
                return (
                  <tr key={s.id} className="border-t" style={{ borderColor: '#E7E1D0' }}>
                    <td className="px-4 py-2.5 whitespace-nowrap" style={{ color: '#6F6C66' }}>{vremeKratko(s.napravljena)}</td>
                    <td className="px-4 py-2.5 font-semibold" style={{ color: st.boja }}>{st.naziv}</td>
                    <td className="px-4 py-2.5">
                      {[NACIN[s.nacin] ?? s.nacin, `${s.velicina} igrača`, s.teren, s.savez && 'savez', s.privatna && 'privatna'].filter(Boolean).join(' · ')}
                    </td>
                    <td className="px-4 py-2.5">{s.igraci ?? '—'}</td>
                    <td className="px-4 py-2.5 text-right">{s.poteza}</td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      )}

      {sobe.length === 50 && (
        <div className="flex justify-end">
          <Link href={`/majmun/osvajanje?pre=${encodeURIComponent(sobe[sobe.length - 1].napravljena)}`} className="btn btn-secondary btn-sm">Starije sobe</Link>
        </div>
      )}
    </div>
  )
}
