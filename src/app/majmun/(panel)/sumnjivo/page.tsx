import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { vremeKratko } from '../igre-nazivi'

export const dynamic = 'force-dynamic'

type Red = { user_id: string; nadimak: string; razlog: string; detalj: string; jacina: number; kad: string | null }

const JACINA: Record<number, { naziv: string; boja: string }> = {
  3: { naziv: 'gotovo sigurno', boja: '#C42B4F' },
  2: { naziv: 'verovatno', boja: '#8A6A12' },
  1: { naziv: 'pogledati', boja: '#6F6C66' },
}
const PERIODI = [7, 30, 90]

/** Nadzor varanja: igrači sa razlogom sumnje (brzina, iskakanje, Karijera, isti IP, dueli, krug praćenja), grupisano po igraču. */
export default async function SumnjivoPage({ searchParams }: { searchParams: Promise<{ dana?: string; sve?: string }> }) {
  const sp = await searchParams
  const dana = PERIODI.includes(Number(sp.dana)) ? Number(sp.dana) : 30
  const sve = sp.sve === '1'
  const supabase = await createClient()
  const { data, error } = await supabase.rpc('admin_sumnjivo', { p_dana: dana })
  const redovi = ((data ?? []) as Red[]).filter(r => sve || r.jacina >= 2)

  // Jedan igrač, jedna kartica: najjača sumnja određuje redosled.
  const poIgracu = new Map<string, { nadimak: string; jacina: number; stavke: Red[] }>()
  for (const r of redovi) {
    const g = poIgracu.get(r.user_id) ?? { nadimak: r.nadimak, jacina: 0, stavke: [] }
    g.jacina = Math.max(g.jacina, r.jacina)
    g.stavke.push(r)
    poIgracu.set(r.user_id, g)
  }
  const igraci = [...poIgracu.entries()].sort((a, b) => b[1].jacina - a[1].jacina)
  const svihUkupno = (data ?? []).length

  function adresa(promena: { dana?: number; sve?: boolean }): string {
    const p = new URLSearchParams({ dana: String(promena.dana ?? dana) })
    if (promena.sve ?? sve) p.set('sve', '1')
    return `/majmun/sumnjivo?${p}`
  }

  return (
    <div className="space-y-5">
      <div>
        <h1 className="font-black tracking-tight" style={{ color: '#151515', fontSize: 'clamp(22px, 4vw, 28px)' }}>Sumnjivo</h1>
        <p className="text-[13px] mt-1 max-w-3xl" style={{ color: '#6F6C66' }}>
          Igrači čije partije izgledaju kao varanje. Karijeru meri server sam (pravo trajanje runde i izdata pitanja); prebrza runda
          automatski gubi dodatak za brzinu. Ostalo su znaci za pregled, ne dokaz: isti IP može biti ista kuća ili mobilna mreža.
        </p>
      </div>

      <nav className="flex flex-wrap items-center gap-x-6 gap-y-2 border-b pb-2.5" style={{ borderColor: '#E7E1D0' }} aria-label="Period i jačina">
        {PERIODI.map(d => (
          <Link key={d} href={adresa({ dana: d })} className="text-[14px] font-bold"
            style={{ color: d === dana ? '#151515' : '#6F6C66', textDecoration: d === dana ? 'underline' : 'none', textUnderlineOffset: 6 }}>
            {d} dana
          </Link>
        ))}
        <Link href={adresa({ sve: !sve })} className="text-[13px] font-semibold ml-auto" style={{ color: '#12907E' }}>
          {sve ? 'Samo jake sumnje' : `Prikaži i slabe znake (${svihUkupno})`}
        </Link>
      </nav>

      {error ? (
        <div className="card-soft p-5 text-[14px]" style={{ color: '#C42B4F' }}>Nadzor nije učitan: {error.message}</div>
      ) : igraci.length === 0 ? (
        <div className="card-soft p-8 text-center text-[14px]" style={{ color: '#6F6C66' }}>
          {sve ? 'Nema sumnjivih igrača u ovom periodu.' : 'Nema jakih sumnji u ovom periodu. Slabi znaci su iza linka gore desno.'}
        </div>
      ) : (
        <div className="space-y-3">
          {igraci.map(([id, g]) => (
            <div key={id} className="card-soft p-5">
              <div className="flex items-center justify-between gap-3 flex-wrap">
                <div className="flex items-baseline gap-3">
                  <Link href={`/majmun/korisnici/${id}`} className="text-[16px] font-black hover:underline" style={{ color: '#151515' }}>{g.nadimak}</Link>
                  <span className="text-[12px] font-bold" style={{ color: JACINA[g.jacina]?.boja }}>{JACINA[g.jacina]?.naziv}</span>
                </div>
                <div className="flex gap-4 text-[12px] font-semibold">
                  <Link href={`/majmun/korisnici/${id}#nadzor`} className="hover:underline" style={{ color: '#12907E' }}>Nadzor igrača</Link>
                  <Link href={`/majmun/aktivnost?igrac=${id}`} className="hover:underline" style={{ color: '#12907E' }}>Sve partije</Link>
                </div>
              </div>
              <ul className="mt-3 space-y-1.5">
                {g.stavke.map((s, i) => (
                  <li key={i} className="text-[13px] flex gap-2" style={{ color: '#151515' }}>
                    <span aria-hidden className="mt-[7px] w-1.5 h-1.5 rounded-full flex-shrink-0" style={{ background: JACINA[s.jacina]?.boja }} />
                    <span><strong>{s.razlog}</strong> · {s.detalj} <span style={{ color: '#6F6C66' }}>· {vremeKratko(s.kad)}</span></span>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
