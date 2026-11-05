'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import UvodjenjeDvostruke, { Poruka } from '../../zastita/UvodjenjeDvostruke'
import { promeniMejl } from './akcije'

export type Uredjaj = { id: string; naziv: string; dodat: string }

/**
 * Mejl za prijavu i uređaji za dvostruku verifikaciju admina. Poslednji uređaj se ne briše:
 * bez njega bi admin ostao bez drugog koraka (a panel ga traži).
 *
 * @example <BezbednostNaloga mejl="ivan@librum.club" uredjaji={[{ id, naziv, dodat }]} />
 */
export default function BezbednostNaloga({ mejl, uredjaji }: { mejl: string; uredjaji: Uredjaj[] }) {
  const router = useRouter()
  const [noviMejl, setNoviMejl] = useState('')
  const [mejlIshod, setMejlIshod] = useState<{ tekst: string; uspeh: boolean } | null>(null)
  const [radi, setRadi] = useState(false)
  const [dodaje, setDodaje] = useState(false)
  const [uredjajGreska, setUredjajGreska] = useState('')

  async function sacuvajMejl(e: React.FormEvent) {
    e.preventDefault()
    setRadi(true); setMejlIshod(null)
    const ishod = await promeniMejl(noviMejl)
    setRadi(false)
    setMejlIshod(ishod.ok ? { tekst: ishod.poruka, uspeh: true } : { tekst: ishod.greska, uspeh: false })
    if (ishod.ok) setNoviMejl('')
  }

  async function ukloni(id: string) {
    setUredjajGreska('')
    if (uredjaji.length <= 1) { setUredjajGreska('Ostaje bar jedan uređaj: prvo dodaj novi, pa ukloni stari.'); return }
    if (!window.confirm('Ukloniti ovaj uređaj? Kodovi sa njega više neće otvarati admin.')) return
    const { error } = await createClient().auth.mfa.unenroll({ factorId: id })
    if (error) { setUredjajGreska(error.message); return }
    router.refresh()
  }

  return (
    <>
      <div className="card-soft p-6">
        <h2 className="font-bold text-[15px] mb-1 tracking-tight" style={{ color: '#151515' }}>Mejl za prijavu</h2>
        <p className="text-[12px] mb-4" style={{ color: '#6F6C66' }}>Sada: <strong>{mejl}</strong>. Potvrda stiže na staru i na novu adresu.</p>
        <form onSubmit={sacuvajMejl} className="space-y-3">
          <input type="email" value={noviMejl} onChange={e => setNoviMejl(e.target.value)} className="input" placeholder="Novi mejl" aria-label="Novi mejl" autoComplete="email" />
          {mejlIshod && <Poruka tekst={mejlIshod.tekst} uspeh={mejlIshod.uspeh} />}
          <button type="submit" disabled={radi || !noviMejl} className="w-full rounded-xl px-4 py-3 font-bold text-[14px]"
            style={{ background: '#12907E', color: '#FFFFFF', opacity: noviMejl ? 1 : 0.6 }}>
            {radi ? 'Šaljem potvrdu…' : 'Promeni mejl'}
          </button>
        </form>
      </div>

      <div className="card-soft p-6">
        <h2 className="font-bold text-[15px] mb-1 tracking-tight" style={{ color: '#151515' }}>Dvostruka verifikacija</h2>
        <p className="text-[12px] mb-4" style={{ color: '#6F6C66' }}>
          Uključena. Admin se otvara samo uz kod iz aplikacije za autentifikaciju na ovim uređajima.
        </p>
        <ul className="divide-y mb-4" style={{ borderColor: '#E7E1D0' }}>
          {uredjaji.map(u => (
            <li key={u.id} className="flex items-center gap-3 py-3" style={{ borderColor: '#E7E1D0' }}>
              <div className="flex-1 min-w-0">
                <p className="font-semibold text-[14px] truncate" style={{ color: '#151515' }}>{u.naziv}</p>
                <p className="text-[12px]" style={{ color: '#6F6C66' }}>Dodat {new Date(u.dodat).toLocaleString('sr-RS', { dateStyle: 'medium', timeStyle: 'short' })}</p>
              </div>
              <button type="button" onClick={() => ukloni(u.id)} className="text-[13px] font-semibold underline underline-offset-4" style={{ color: '#C42B4F' }}>
                Ukloni
              </button>
            </li>
          ))}
        </ul>
        {uredjajGreska && <div className="mb-3"><Poruka tekst={uredjajGreska} /></div>}
        {dodaje
          ? <UvodjenjeDvostruke naUspeh={() => { setDodaje(false); router.refresh() }} />
          : (
            <button type="button" onClick={() => setDodaje(true)} className="w-full rounded-xl px-4 py-3 font-bold text-[14px]"
              style={{ background: '#FFFFFF', color: '#151515', border: '1.5px solid #151515' }}>
              Dodaj uređaj
            </button>
          )}
      </div>
    </>
  )
}
