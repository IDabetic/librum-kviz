import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { vremeKratko, brojSr } from '../igre-nazivi'
import FirmaRadnje from './FirmaRadnje'

export const dynamic = 'force-dynamic'

type Firma = {
  id: string; ime: string; ime_dato: string | null; vlasnik: string | null; vlasnik_nadimak: string | null
  korporacija: boolean; pozicija: string; nivo: number; kasa: number; zaposlenih: number; prijava: number
  rekord: number | null; osnovana: string; poslednji_ulazak: string | null; zatvorena: boolean
}
type Igrac = {
  user_id: string; nadimak: string; pozicija: string | null; kapital: number; ugled: number; firma: string | null
  vlasnik: boolean | null; rundi: number; poslednja: string | null; napravljen: string
}

const NASLOV = { color: '#151515', fontSize: 'clamp(22px, 4vw, 28px)' }

/** Karijera: firme (vlasnik, nivo, kasa, prijave imena) i igrači; pitanja struka su na posebnoj strani. */
export default async function KarijeraPage({ searchParams }: { searchParams: Promise<{ tab?: string }> }) {
  const { tab = 'firme' } = await searchParams
  const supabase = await createClient()
  const [firmeOdg, igraciOdg, rundeOdg, pozicijeOdg] = await Promise.all([
    supabase.rpc('admin_karijera_firme'),
    supabase.rpc('admin_karijera_igraci'),
    supabase.rpc('admin_aktivnost', { p_igra: 'karijera', p_broj: 200 }),
    supabase.from('karijera_pozicije').select('id, naziv'),
  ])
  const struka = new Map((pozicijeOdg.data ?? []).map(p => [p.id as string, p.naziv as string]))
  const firme = (firmeOdg.data ?? []) as Firma[]
  const igraci = (igraciOdg.data ?? []) as Igrac[]
  const otvorene = firme.filter(f => !f.zatvorena)
  const prijavljenih = firme.filter(f => f.prijava > 0).length
  const danas = new Date().toLocaleDateString('sv', { timeZone: 'Europe/Belgrade' })
  const rundiDanas = ((rundeOdg.data ?? []) as { kad: string }[])
    .filter(r => new Date(r.kad).toLocaleDateString('sv', { timeZone: 'Europe/Belgrade' }) === danas).length
  const greska = firmeOdg.error ?? igraciOdg.error

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h1 className="font-black tracking-tight" style={NASLOV}>Karijera</h1>
          <p className="text-[13px] mt-1" style={{ color: '#6F6C66' }}>
            {otvorene.length} otvorenih firmi · {otvorene.filter(f => f.vlasnik).length} u vlasništvu igrača · {igraci.length} igrača · {rundiDanas} rundi danas
            {prijavljenih > 0 && <strong style={{ color: '#C42B4F' }}> · {prijavljenih} prijavljenih imena</strong>}
          </p>
        </div>
        <div className="flex gap-2 flex-wrap">
          <Link href="/majmun/karijera/pitanja" className="btn btn-primary btn-md">Pitanja struka</Link>
          <Link href="/majmun/aktivnost?igra=karijera" className="btn btn-secondary btn-md">Sve runde</Link>
        </div>
      </div>

      <nav className="flex gap-6 border-b" style={{ borderColor: '#E7E1D0' }} aria-label="Delovi Karijere">
        {[{ id: 'firme', naziv: `Firme (${firme.length})` }, { id: 'igraci', naziv: `Igrači (${igraci.length})` }].map(t => (
          <Link key={t.id} href={`/majmun/karijera?tab=${t.id}`}
            className="pb-2.5 text-[14px] font-bold -mb-px border-b-2"
            style={tab === t.id ? { color: '#151515', borderColor: '#12907E' } : { color: '#6F6C66', borderColor: 'transparent' }}>
            {t.naziv}
          </Link>
        ))}
      </nav>

      {greska ? (
        <div className="card-soft p-5 text-[14px]" style={{ color: '#C42B4F' }}>Karijera nije učitana: {greska.message}</div>
      ) : tab === 'igraci' ? (
        igraci.length === 0 ? (
          <div className="card-soft p-8 text-center text-[14px]" style={{ color: '#6F6C66' }}>Još niko nije počeo Karijeru.</div>
        ) : (
          <div className="card-soft overflow-x-auto">
            <table className="w-full text-[13px]">
              <thead>
                <tr className="text-left text-[11px] uppercase tracking-wider" style={{ color: '#6F6C66' }}>
                  <th className="px-4 py-3 font-bold">Igrač</th>
                  <th className="px-4 py-3 font-bold">Pozicija</th>
                  <th className="px-4 py-3 font-bold">Firma</th>
                  <th className="px-4 py-3 font-bold text-right">Kapital</th>
                  <th className="px-4 py-3 font-bold text-right">Ugled</th>
                  <th className="px-4 py-3 font-bold text-right">Rundi</th>
                  <th className="px-4 py-3 font-bold">Poslednja runda</th>
                </tr>
              </thead>
              <tbody>
                {igraci.map(i => (
                  <tr key={i.user_id} className="border-t" style={{ borderColor: '#E7E1D0' }}>
                    <td className="px-4 py-2.5 font-semibold">
                      <Link href={`/majmun/aktivnost?igrac=${i.user_id}&igra=karijera`} className="hover:underline" style={{ color: '#151515' }}>{i.nadimak}</Link>
                    </td>
                    <td className="px-4 py-2.5">{i.pozicija ? struka.get(i.pozicija) ?? i.pozicija : '—'}</td>
                    <td className="px-4 py-2.5">{i.firma ?? '—'}{i.vlasnik && <span style={{ color: '#12907E' }}> · vlasnik</span>}</td>
                    <td className="px-4 py-2.5 text-right">{brojSr(i.kapital)}</td>
                    <td className="px-4 py-2.5 text-right">{i.ugled}</td>
                    <td className="px-4 py-2.5 text-right">{i.rundi}</td>
                    <td className="px-4 py-2.5 whitespace-nowrap" style={{ color: '#6F6C66' }}>{vremeKratko(i.poslednja)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )
      ) : firme.length === 0 ? (
        <div className="card-soft p-8 text-center text-[14px]" style={{ color: '#6F6C66' }}>Nema firmi.</div>
      ) : (
        <div className="card-soft overflow-x-auto">
          <table className="w-full text-[13px]">
            <thead>
              <tr className="text-left text-[11px] uppercase tracking-wider" style={{ color: '#6F6C66' }}>
                <th className="px-4 py-3 font-bold">Firma</th>
                <th className="px-4 py-3 font-bold">Vlasnik</th>
                <th className="px-4 py-3 font-bold">Struka</th>
                <th className="px-4 py-3 font-bold text-right">Nivo</th>
                <th className="px-4 py-3 font-bold text-right">Kasa</th>
                <th className="px-4 py-3 font-bold text-right">Zaposleni</th>
                <th className="px-4 py-3 font-bold">Ime</th>
              </tr>
            </thead>
            <tbody>
              {firme.map(f => (
                <tr key={f.id} className="border-t align-top" style={{ borderColor: '#E7E1D0', opacity: f.zatvorena ? 0.55 : 1 }}>
                  <td className="px-4 py-2.5">
                    <p className="font-semibold" style={{ color: '#151515' }}>{f.ime}</p>
                    <p className="text-[11px]" style={{ color: '#6F6C66' }}>
                      {f.korporacija ? 'Korporacija' : 'Firma'} · osnovana {vremeKratko(f.osnovana)}{f.zatvorena ? ' · zatvorena' : ''}
                    </p>
                  </td>
                  <td className="px-4 py-2.5">
                    {f.vlasnik
                      ? <Link href={`/majmun/korisnici/${f.vlasnik}`} className="hover:underline" style={{ color: '#151515' }}>{f.vlasnik_nadimak ?? 'Igrač'}</Link>
                      : <span style={{ color: '#6F6C66' }}>bot</span>}
                  </td>
                  <td className="px-4 py-2.5">{struka.get(f.pozicija) ?? f.pozicija}</td>
                  <td className="px-4 py-2.5 text-right">{f.nivo}</td>
                  <td className="px-4 py-2.5 text-right">{brojSr(f.kasa)}</td>
                  <td className="px-4 py-2.5 text-right">{f.zaposlenih}</td>
                  <td className="px-4 py-2.5">
                    <FirmaRadnje id={f.id} imaIme={!!f.ime_dato} prijava={f.prijava} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
