'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { vremeKratko } from '../igre-nazivi'

export type Obavestenje = {
  id: number; naslov: string; tekst: string; ukljuceno: boolean; od: string | null; do_kad: string | null
  platforma: 'sve' | 'ios' | 'android'; poslat_push: string | null; created_at: string
}

type Forma = { id: number | null; naslov: string; tekst: string; ukljuceno: boolean; od: string; doKad: string; platforma: Obavestenje['platforma'] }
const PRAZNA: Forma = { id: null, naslov: '', tekst: '', ukljuceno: true, od: '', doKad: '', platforma: 'sve' }
const PLATFORME: [Obavestenje['platforma'], string][] = [['sve', 'Svi telefoni'], ['ios', 'Samo iPhone'], ['android', 'Samo Android']]

/** ISO iz baze → vrednost za <input type="datetime-local"> u lokalnom vremenu. */
function zaPolje(iso: string | null): string {
  if (!iso) return ''
  const d = new Date(iso)
  return new Date(d.getTime() - d.getTimezoneOffset() * 60_000).toISOString().slice(0, 16)
}

/** Spisak obaveštenja i forma za novo/izmenu; uključivanje, brisanje i slanje na telefone. */
export default function ObavestenjaUredjivanje({ lista }: { lista: Obavestenje[] }) {
  const router = useRouter()
  const [forma, setForma] = useState<Forma>(PRAZNA)
  const [radi, setRadi] = useState(false)
  const [poruka, setPoruka] = useState<{ tekst: string; greska: boolean } | null>(null)

  async function rpc(ime: string, args: Record<string, unknown>, uspeh: string) {
    setRadi(true); setPoruka(null)
    const { error } = await createClient().rpc(ime, args)
    setRadi(false)
    if (error) { setPoruka({ tekst: error.message, greska: true }); return false }
    setPoruka({ tekst: uspeh, greska: false })
    router.refresh()
    return true
  }

  async function sacuvaj(e: React.FormEvent) {
    e.preventDefault()
    if (!forma.naslov.trim() || !forma.tekst.trim()) { setPoruka({ tekst: 'Upiši naslov i tekst.', greska: true }); return }
    const ok = await rpc('admin_obavestenje_sacuvaj', {
      p_id: forma.id, p_naslov: forma.naslov, p_tekst: forma.tekst, p_ukljuceno: forma.ukljuceno,
      p_od: forma.od ? new Date(forma.od).toISOString() : null, p_do: forma.doKad ? new Date(forma.doKad).toISOString() : null,
      p_platforma: forma.platforma,
    }, forma.id ? 'Obaveštenje je izmenjeno.' : 'Obaveštenje je dodato.')
    if (ok) setForma(PRAZNA)
  }

  function izmeni(o: Obavestenje) {
    setForma({ id: o.id, naslov: o.naslov, tekst: o.tekst, ukljuceno: o.ukljuceno, od: zaPolje(o.od), doKad: zaPolje(o.do_kad), platforma: o.platforma })
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  function prekidac(o: Obavestenje) {
    rpc('admin_obavestenje_sacuvaj', { p_id: o.id, p_naslov: o.naslov, p_tekst: o.tekst, p_ukljuceno: !o.ukljuceno, p_od: o.od, p_do: o.do_kad, p_platforma: o.platforma },
      o.ukljuceno ? 'Isključeno.' : 'Uključeno.')
  }

  function obrisi(o: Obavestenje) {
    if (!confirm(`Obrisati obaveštenje „${o.naslov}”?`)) return
    rpc('admin_obavestenje_obrisi', { p_id: o.id }, 'Obrisano.')
  }

  function posalji(o: Obavestenje) {
    if (!confirm(`Poslati „${o.naslov}” kao obaveštenje na telefone (${PLATFORME.find(p => p[0] === o.platforma)?.[1].toLowerCase()})? Šalje se jednom i ne može da se povuče.`)) return
    rpc('admin_obavestenje_push', { p_id: o.id }, 'Poslato na telefone.')
  }

  const polje = 'w-full rounded-xl px-3 py-2.5 text-[14px] border bg-white'
  return (
    <>
      <form onSubmit={sacuvaj} className="card-soft p-5 space-y-3">
        <h2 className="font-bold text-[15px]" style={{ color: '#151515' }}>{forma.id ? 'Izmena obaveštenja' : 'Novo obaveštenje'}</h2>
        <label className="block text-[12px] font-semibold" style={{ color: '#6F6C66' }}>Naslov
          <input value={forma.naslov} onChange={e => setForma({ ...forma, naslov: e.target.value })} maxLength={80} className={polje} style={{ borderColor: '#E7E1D0' }} />
        </label>
        <label className="block text-[12px] font-semibold" style={{ color: '#6F6C66' }}>Tekst ({forma.tekst.length}/500)
          <textarea value={forma.tekst} onChange={e => setForma({ ...forma, tekst: e.target.value })} maxLength={500} rows={4} className={polje} style={{ borderColor: '#E7E1D0' }} />
        </label>
        <div className="grid sm:grid-cols-3 gap-3">
          <label className="block text-[12px] font-semibold" style={{ color: '#6F6C66' }}>Važi od (prazno = odmah)
            <input type="datetime-local" value={forma.od} onChange={e => setForma({ ...forma, od: e.target.value })} className={polje} style={{ borderColor: '#E7E1D0' }} />
          </label>
          <label className="block text-[12px] font-semibold" style={{ color: '#6F6C66' }}>Važi do (prazno = bez kraja)
            <input type="datetime-local" value={forma.doKad} onChange={e => setForma({ ...forma, doKad: e.target.value })} className={polje} style={{ borderColor: '#E7E1D0' }} />
          </label>
          <label className="block text-[12px] font-semibold" style={{ color: '#6F6C66' }}>Kome
            <select value={forma.platforma} onChange={e => setForma({ ...forma, platforma: e.target.value as Forma['platforma'] })} className={polje} style={{ borderColor: '#E7E1D0' }}>
              {PLATFORME.map(([v, n]) => <option key={v} value={v}>{n}</option>)}
            </select>
          </label>
        </div>
        <label className="flex items-center gap-2 text-[14px] font-semibold" style={{ color: '#151515' }}>
          <input type="checkbox" checked={forma.ukljuceno} onChange={e => setForma({ ...forma, ukljuceno: e.target.checked })} /> Uključeno (prikazuje se u aplikaciji)
        </label>
        {poruka && <p role={poruka.greska ? 'alert' : 'status'} className="text-[13px] font-semibold" style={{ color: poruka.greska ? '#C42B4F' : '#12907E' }}>{poruka.tekst}</p>}
        <div className="flex gap-3">
          <button type="submit" disabled={radi} className="rounded-xl px-4 py-2.5 font-bold text-[14px]" style={{ background: '#151515', color: '#FFFFFF' }}>
            {forma.id ? 'Sačuvaj izmene' : 'Dodaj obaveštenje'}
          </button>
          {forma.id && <button type="button" onClick={() => setForma(PRAZNA)} className="text-[14px] font-semibold underline underline-offset-4" style={{ color: '#6F6C66' }}>Odustani</button>}
        </div>
      </form>

      {lista.length === 0
        ? <div className="card-soft p-8 text-center text-[14px]" style={{ color: '#6F6C66' }}>Još nema obaveštenja.</div>
        : (
          <ul className="card-soft divide-y" style={{ borderColor: '#E7E1D0' }}>
            {lista.map(o => (
              <li key={o.id} className="p-5 space-y-2" style={{ borderColor: '#E7E1D0' }}>
                <div className="flex items-start gap-3">
                  <div className="flex-1 min-w-0">
                    <p className="font-bold text-[15px]" style={{ color: '#151515' }}>{o.naslov}</p>
                    <p className="text-[14px] mt-1 whitespace-pre-line" style={{ color: '#3A3833' }}>{o.tekst}</p>
                    <p className="text-[12px] mt-2" style={{ color: '#6F6C66' }}>
                      {o.ukljuceno ? 'Uključeno' : 'Isključeno'} · {PLATFORME.find(p => p[0] === o.platforma)?.[1]}
                      {o.od && ` · od ${vremeKratko(o.od)}`}{o.do_kad && ` · do ${vremeKratko(o.do_kad)}`}
                      {o.poslat_push && ` · poslato na telefone ${vremeKratko(o.poslat_push)}`}
                    </p>
                  </div>
                  <label className="flex items-center gap-2 text-[13px] font-semibold shrink-0" style={{ color: '#151515' }}>
                    <input type="checkbox" checked={o.ukljuceno} disabled={radi} onChange={() => prekidac(o)} aria-label={`Uključeno: ${o.naslov}`} /> Uključeno
                  </label>
                </div>
                <div className="flex flex-wrap gap-4 text-[13px] font-semibold">
                  <button type="button" onClick={() => izmeni(o)} className="hover:underline" style={{ color: '#12907E' }}>Izmeni</button>
                  {!o.poslat_push && <button type="button" disabled={radi} onClick={() => posalji(o)} className="hover:underline" style={{ color: '#151515' }}>Pošalji na telefone</button>}
                  <button type="button" disabled={radi} onClick={() => obrisi(o)} className="hover:underline" style={{ color: '#C42B4F' }}>Obriši</button>
                </div>
              </li>
            ))}
          </ul>
        )}
    </>
  )
}
