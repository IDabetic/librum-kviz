'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import UvodjenjeDvostruke, { Poruka } from './UvodjenjeDvostruke'

/**
 * Drugi korak prijave u admin: kod iz aplikacije za autentifikaciju, ili prvo uvođenje ako ga admin još nema.
 *
 * @example <DvostrukaProvera faktorId={null} />
 */
export default function DvostrukaProvera({ faktorId }: { faktorId: string | null }) {
  const router = useRouter()
  const [kod, setKod] = useState('')
  const [radi, setRadi] = useState(false)
  const [greska, setGreska] = useState('')

  function uPanel() { router.replace('/majmun'); router.refresh() }

  async function potvrdi(e: React.FormEvent) {
    e.preventDefault()
    if (!faktorId || kod.length !== 6) return
    setGreska(''); setRadi(true)
    const { error } = await createClient().auth.mfa.challengeAndVerify({ factorId: faktorId, code: kod })
    setRadi(false)
    if (error) { setGreska('Kod nije tačan ili je istekao. Upiši novi iz aplikacije.'); setKod(''); return }
    uPanel()
  }

  async function odjava() {
    await createClient().auth.signOut()
    router.replace('/')
  }

  return (
    <div className="w-full max-w-md card-soft p-6 sm:p-8 space-y-5">
      <div>
        <p className="text-[10px] font-bold uppercase tracking-widest" style={{ color: '#6F6C66' }}>Admin panel</p>
        <h1 className="font-black tracking-tight mt-1" style={{ color: '#151515', fontSize: 26 }}>
          {faktorId ? 'Drugi korak prijave' : 'Zaštiti admin nalog'}
        </h1>
        <p className="text-[13px] mt-2" style={{ color: '#6F6C66' }}>
          {faktorId
            ? 'Upiši šestocifreni kod iz aplikacije za autentifikaciju.'
            : 'Admin se otvara samo uz kod sa tvog telefona. Uključi dvostruku verifikaciju jednom i od tada je traži svaka prijava.'}
        </p>
      </div>

      {faktorId ? (
        <form onSubmit={potvrdi} className="space-y-4">
          <input value={kod} onChange={e => setKod(e.target.value.replace(/\D/g, '').slice(0, 6))} inputMode="numeric" autoComplete="one-time-code"
            aria-label="Kod iz aplikacije" className="input tracking-[0.4em] text-center text-[22px] font-bold" placeholder="000000" autoFocus />
          {greska && <Poruka tekst={greska} />}
          <button type="submit" disabled={radi || kod.length !== 6} className="w-full rounded-xl px-4 py-3 font-bold text-[14px]"
            style={{ background: '#151515', color: '#FFFFFF', opacity: kod.length === 6 ? 1 : 0.6 }}>
            {radi ? 'Proveravam…' : 'Uđi u admin'}
          </button>
        </form>
      ) : (
        <UvodjenjeDvostruke naUspeh={uPanel} />
      )}

      <button type="button" onClick={odjava} className="text-[13px] font-semibold underline underline-offset-4" style={{ color: '#6F6C66' }}>
        Odjavi se
      </button>
    </div>
  )
}
