import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { NAZIVI_IGARA, vremeKratko, brojSr } from '../igre-nazivi'

export const dynamic = 'force-dynamic'

type SP = { igra?: string; igrac?: string; pre?: string }
type Red = { kad: string; user_id: string | null; nadimak: string; igra: string; poeni: number | null; tacnih: number | null; netacnih: number | null; opis: string | null }

const PO_STRANI = 50

/** Sve partije svih igara (aplikacija, Karijera, stare veb igre) od najnovije; filter po igri i igraču, keyset „Starije”. */
export default async function AktivnostPage({ searchParams }: { searchParams: Promise<SP> }) {
  const sp = await searchParams
  const supabase = await createClient()
  const igra = sp.igra && NAZIVI_IGARA[sp.igra] ? sp.igra : null
  const igrac = sp.igrac && /^[0-9a-f-]{36}$/i.test(sp.igrac) ? sp.igrac : null
  const pre = sp.pre && !Number.isNaN(Date.parse(sp.pre)) ? sp.pre : null

  const { data, error } = await supabase.rpc('admin_aktivnost', { p_igra: igra, p_korisnik: igrac, p_pre: pre, p_broj: PO_STRANI })
  const redovi = (data ?? []) as Red[]
  const imeIgraca = igrac ? redovi[0]?.nadimak : null

  function adresa(promena: Partial<SP>): string {
    const p = new URLSearchParams()
    const s = { igra: igra ?? undefined, igrac: igrac ?? undefined, ...promena }
    for (const [k, v] of Object.entries(s)) if (v) p.set(k, v)
    const q = p.toString()
    return q ? `/majmun/aktivnost?${q}` : '/majmun/aktivnost'
  }

  return (
    <div className="space-y-5">
      <div>
        <h1 className="font-black tracking-tight" style={{ color: '#151515', fontSize: 'clamp(22px, 4vw, 28px)' }}>
          Aktivnost igrača
        </h1>
        <p className="text-[13px] mt-1" style={{ color: '#6F6C66' }}>
          Sve odigrane partije, najnovije prve{imeIgraca ? ` · igrač ${imeIgraca}` : ''}{pre ? ' · starije strane' : ''}
        </p>
      </div>

      <form className="card-soft p-4 flex items-center gap-2 flex-wrap" action="/majmun/aktivnost">
        {igrac && <input type="hidden" name="igrac" value={igrac} />}
        <label className="sr-only" htmlFor="igra">Igra</label>
        <select id="igra" name="igra" defaultValue={igra ?? ''} className="input flex-shrink-0" style={{ width: 'auto', minWidth: 200 }}>
          <option value="">Sve igre</option>
          {Object.entries(NAZIVI_IGARA).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
        </select>
        <button type="submit" className="btn btn-primary btn-md">Prikaži</button>
        {(igra || igrac || pre) && <Link href="/majmun/aktivnost" className="btn btn-secondary btn-md">Poništi filtere</Link>}
      </form>

      {error ? (
        <div className="card-soft p-5 text-[14px]" style={{ color: '#C42B4F' }}>Aktivnost nije učitana: {error.message}</div>
      ) : redovi.length === 0 ? (
        <div className="card-soft p-8 text-center text-[14px]" style={{ color: '#6F6C66' }}>Nema partija za ovaj izbor.</div>
      ) : (
        <div className="card-soft overflow-x-auto">
          <table className="w-full text-[13px]">
            <thead>
              <tr className="text-left text-[11px] uppercase tracking-wider" style={{ color: '#6F6C66' }}>
                <th className="px-4 py-3 font-bold">Vreme</th>
                <th className="px-4 py-3 font-bold">Igrač</th>
                <th className="px-4 py-3 font-bold">Igra</th>
                <th className="px-4 py-3 font-bold text-right">Poeni</th>
                <th className="px-4 py-3 font-bold text-right">Tačno / netačno</th>
                <th className="px-4 py-3 font-bold">Detalj</th>
              </tr>
            </thead>
            <tbody>
              {redovi.map((r, i) => (
                <tr key={`${r.kad}-${i}`} className="border-t" style={{ borderColor: '#E7E1D0' }}>
                  <td className="px-4 py-2.5 whitespace-nowrap" style={{ color: '#6F6C66' }}>{vremeKratko(r.kad)}</td>
                  <td className="px-4 py-2.5 font-semibold">
                    {r.user_id ? (
                      <span className="flex items-center gap-3">
                        <Link href={adresa({ igrac: r.user_id, pre: undefined })} style={{ color: '#151515' }} className="hover:underline">{r.nadimak}</Link>
                        <Link href={`/majmun/korisnici/${r.user_id}`} className="text-[11px] font-medium hover:underline" style={{ color: '#12907E' }}>profil</Link>
                      </span>
                    ) : 'Gost'}
                  </td>
                  <td className="px-4 py-2.5">
                    <Link href={adresa({ igra: r.igra, pre: undefined })} className="hover:underline" style={{ color: '#151515' }}>
                      {NAZIVI_IGARA[r.igra] ?? r.igra}
                    </Link>
                  </td>
                  <td className="px-4 py-2.5 text-right font-black" style={{ color: '#12907E' }}>{brojSr(r.poeni)}</td>
                  <td className="px-4 py-2.5 text-right whitespace-nowrap">{r.tacnih ?? '—'} / {r.netacnih ?? '—'}</td>
                  <td className="px-4 py-2.5" style={{ color: '#6F6C66' }}>{r.opis ?? ''}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {redovi.length === PO_STRANI && (
        <div className="flex justify-end">
          <Link href={adresa({ pre: redovi[redovi.length - 1].kad })} className="btn btn-secondary btn-sm">Starije partije</Link>
        </div>
      )}
    </div>
  )
}
