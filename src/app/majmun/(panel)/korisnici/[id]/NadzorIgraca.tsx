import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { NAZIVI_IGARA, vremeKratko, brojSr } from '../../igre-nazivi'

type Osoba = { id: string; nadimak: string; kad?: string }
type Detalji = {
  prati: Osoba[]; pratioci: Osoba[]; blokirao: Osoba[]; blokiran_od: number
  po_igri: { igra: string; partija: number; prosek_ms: number | null; tacnost: number | null; najbolji: number; poslednja: string }[]
  karijera: { runde: number; trajanje_ms: number | null; prosek_ms: number | null; sumnjivih: number; tacnost: number | null } | null
  mreza: { ip: string; uredjaj: string | null; prvi: string; poslednji: string; broj: number; drugi: Osoba[] | null }[]
  sumnje: { razlog: string; detalj: string; jacina: number; kad: string | null }[]
}

const NASLOV = 'text-[11px] font-bold uppercase tracking-widest mb-3'
const sek = (ms: number | null | undefined) => (ms == null ? '—' : `${(ms / 1000).toFixed(1)} s`)

/** Nadzor jednog igrača (admin_igrac_detalji): sumnje, vreme po igri, Karijera, praćenja, blokade, mreža i povezani nalozi. */
export default async function NadzorIgraca({ id }: { id: string }) {
  const supabase = await createClient()
  const { data, error } = await supabase.rpc('admin_igrac_detalji', { p_id: id })
  if (error) return <div className="card-soft p-5 text-[14px]" style={{ color: '#C42B4F' }}>Nadzor nije učitan: {error.message}</div>
  const d = data as Detalji
  const povezani = new Map<string, string>()
  for (const m of d.mreza) for (const o of m.drugi ?? []) povezani.set(o.id, o.nadimak)

  return (
    <section id="nadzor" className="space-y-4">
      <h2 className="font-black tracking-tight text-[20px]" style={{ color: '#151515' }}>Nadzor</h2>

      <div className="card-soft p-5">
        <p className={NASLOV} style={{ color: d.sumnje.length ? '#C42B4F' : '#6F6C66' }}>Sumnje (90 dana)</p>
        {d.sumnje.length === 0 ? <p className="text-[13px]" style={{ color: '#6F6C66' }}>Nema.</p> : (
          <ul className="space-y-1.5 text-[13px]" style={{ color: '#151515' }}>
            {d.sumnje.map((s, i) => <li key={i}><strong>{s.razlog}</strong> · {s.detalj} <span style={{ color: '#6F6C66' }}>· {vremeKratko(s.kad)}</span></li>)}
          </ul>
        )}
      </div>

      <div className="card-soft p-5 overflow-x-auto">
        <p className={NASLOV} style={{ color: '#6F6C66' }}>Vreme i tačnost po igri (aplikacija)</p>
        {d.po_igri.length === 0 && !d.karijera?.runde ? <p className="text-[13px]" style={{ color: '#6F6C66' }}>Nije igrao u aplikaciji.</p> : (
          <table className="w-full text-[13px]">
            <thead>
              <tr className="text-left text-[11px] uppercase tracking-wider" style={{ color: '#6F6C66' }}>
                <th className="py-2 pr-3 font-bold">Igra</th><th className="py-2 pr-3 font-bold text-right">Partija</th>
                <th className="py-2 pr-3 font-bold text-right">Prosek odgovora</th><th className="py-2 pr-3 font-bold text-right">Tačnih</th>
                <th className="py-2 pr-3 font-bold text-right">Najbolji</th><th className="py-2 font-bold">Poslednja</th>
              </tr>
            </thead>
            <tbody>
              {d.po_igri.map(g => (
                <tr key={g.igra} className="border-t" style={{ borderColor: '#E7E1D0' }}>
                  <td className="py-2 pr-3 font-semibold">{NAZIVI_IGARA[g.igra] ?? g.igra}</td>
                  <td className="py-2 pr-3 text-right">{g.partija}</td>
                  <td className="py-2 pr-3 text-right" style={{ color: g.prosek_ms != null && g.prosek_ms < 1500 ? '#C42B4F' : undefined }}>{sek(g.prosek_ms)}</td>
                  <td className="py-2 pr-3 text-right">{g.tacnost == null ? '—' : `${g.tacnost}%`}</td>
                  <td className="py-2 pr-3 text-right">{brojSr(g.najbolji)}</td>
                  <td className="py-2" style={{ color: '#6F6C66' }}>{vremeKratko(g.poslednja)}</td>
                </tr>
              ))}
              {!!d.karijera?.runde && (
                <tr className="border-t" style={{ borderColor: '#E7E1D0' }}>
                  <td className="py-2 pr-3 font-semibold">Karijera</td>
                  <td className="py-2 pr-3 text-right">{d.karijera.runde}</td>
                  <td className="py-2 pr-3 text-right">{sek(d.karijera.prosek_ms)}</td>
                  <td className="py-2 pr-3 text-right">{d.karijera.tacnost == null ? '—' : `${d.karijera.tacnost}%`}</td>
                  <td className="py-2 pr-3 text-right" colSpan={2} style={{ color: d.karijera.sumnjivih ? '#C42B4F' : '#6F6C66' }}>
                    runda prosečno {sek(d.karijera.trajanje_ms)}{d.karijera.sumnjivih ? ` · ${d.karijera.sumnjivih} sumnjivih` : ''}
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        )}
      </div>

      <div className="grid sm:grid-cols-3 gap-4">
        <SpisakOsoba naslov={`Prati (${d.prati.length})`} osobe={d.prati} />
        <SpisakOsoba naslov={`Pratioci (${d.pratioci.length})`} osobe={d.pratioci} />
        <SpisakOsoba naslov={`Blokirao (${d.blokirao.length}) · blokiran od ${d.blokiran_od}`} osobe={d.blokirao} />
      </div>

      <div className="card-soft p-5">
        <p className={NASLOV} style={{ color: '#6F6C66' }}>Mreža (IP i uređaj, čuva se 90 dana)</p>
        {d.mreza.length === 0 ? <p className="text-[13px]" style={{ color: '#6F6C66' }}>Još nema zapisa (beleži se od 05.11.2026, pri svakoj partiji).</p> : (
          <ul className="space-y-2 text-[13px]" style={{ color: '#151515' }}>
            {d.mreza.map(m => (
              <li key={m.ip}>
                <strong>{m.ip}</strong> <span style={{ color: '#6F6C66' }}>· {m.broj}× · {vremeKratko(m.prvi)} do {vremeKratko(m.poslednji)}{m.uredjaj ? ` · ${m.uredjaj}` : ''}</span>
                {m.drugi?.length ? (
                  <span className="block mt-0.5" style={{ color: '#C42B4F' }}>
                    Isti IP: {m.drugi.map((o, i) => <span key={o.id}>{i > 0 && ', '}<Link href={`/majmun/korisnici/${o.id}#nadzor`} className="underline">{o.nadimak}</Link></span>)}
                  </span>
                ) : null}
              </li>
            ))}
          </ul>
        )}
        {povezani.size > 0 && <p className="text-[12px] mt-3 font-semibold" style={{ color: '#C42B4F' }}>Povezanih naloga: {povezani.size}</p>}
      </div>
    </section>
  )
}

function SpisakOsoba({ naslov, osobe }: { naslov: string; osobe: Osoba[] }) {
  return (
    <div className="card-soft p-5">
      <p className={NASLOV} style={{ color: '#6F6C66' }}>{naslov}</p>
      {osobe.length === 0 ? <p className="text-[13px]" style={{ color: '#6F6C66' }}>Niko.</p> : (
        <ul className="space-y-1 text-[13px]">
          {osobe.map(o => (
            <li key={o.id}>
              <Link href={`/majmun/korisnici/${o.id}#nadzor`} className="hover:underline font-semibold" style={{ color: '#151515' }}>{o.nadimak}</Link>
              {o.kad && <span style={{ color: '#6F6C66' }}> · {vremeKratko(o.kad)}</span>}
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}
