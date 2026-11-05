import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { vremeKratko } from '../igre-nazivi'

export const dynamic = 'force-dynamic'

type Pad = { id: number; created_at: string; platforma: string; verzija: string | null; izvestaj: { stek?: string; uredjaj?: string; [k: string]: unknown } | null }

/** Izveštaji o padu aplikacije (iOS i Android šalju ih sami pri sledećem pokretanju); najnoviji prvi. */
export default async function PadoviPage({ searchParams }: { searchParams: Promise<{ pre?: string }> }) {
  const { pre } = await searchParams
  const supabase = await createClient()
  let upit = supabase.from('izvestaji_o_padu').select('id, created_at, platforma, verzija, izvestaj').order('id', { ascending: false }).limit(30)
  const preId = Number(pre)
  if (Number.isInteger(preId) && preId > 0) upit = upit.lt('id', preId)
  const { data, error } = await upit
  const padovi = (data ?? []) as Pad[]

  return (
    <div className="space-y-5">
      <div>
        <h1 className="font-black tracking-tight" style={{ color: '#151515', fontSize: 'clamp(22px, 4vw, 28px)' }}>Padovi aplikacije</h1>
        <p className="text-[13px] mt-1" style={{ color: '#6F6C66' }}>
          Telefon pošalje izveštaj pri sledećem otvaranju aplikacije. Prva linija posle naziva greške kaže šta je puklo.
        </p>
      </div>

      {error ? (
        <div className="card-soft p-5 text-[14px]" style={{ color: '#C42B4F' }}>Padovi nisu učitani: {error.message}</div>
      ) : padovi.length === 0 ? (
        <div className="card-soft p-8 text-center text-[14px]" style={{ color: '#6F6C66' }}>Nema prijavljenih padova.</div>
      ) : (
        <div className="space-y-3">
          {padovi.map(p => {
            const stek = String(p.izvestaj?.stek ?? JSON.stringify(p.izvestaj ?? {}, null, 2))
            const greska = stek.split('\n').find(l => /Exception|Error|Fatal|signal|SIG/i.test(l)) ?? stek.split('\n')[0]
            return (
              <details key={p.id} className="card-soft p-5">
                <summary className="cursor-pointer list-none">
                  <p className="text-[12px] font-bold uppercase tracking-wider" style={{ color: '#6F6C66' }}>
                    {vremeKratko(p.created_at)} · {p.platforma} · {p.verzija ?? 'bez verzije'}{p.izvestaj?.uredjaj ? ` · ${p.izvestaj.uredjaj}` : ''}
                  </p>
                  <p className="text-[14px] font-semibold mt-1 break-words" style={{ color: '#C42B4F' }}>{greska.slice(0, 300)}</p>
                </summary>
                <pre className="mt-3 text-[11px] leading-relaxed overflow-x-auto whitespace-pre-wrap break-all p-3 rounded-xl" style={{ background: '#F3F0E6', color: '#151515' }}>
                  {stek}
                </pre>
              </details>
            )
          })}
        </div>
      )}

      {padovi.length === 30 && (
        <div className="flex justify-end">
          <Link href={`/majmun/padovi?pre=${padovi[padovi.length - 1].id}`} className="btn btn-secondary btn-sm">Stariji padovi</Link>
        </div>
      )}
    </div>
  )
}
