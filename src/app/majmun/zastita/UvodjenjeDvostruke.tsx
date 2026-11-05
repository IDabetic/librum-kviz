'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'

const KOD = /^\d{6}$/

/**
 * Uvođenje dvostruke verifikacije: QR kod za aplikaciju za autentifikaciju (Google Authenticator,
 * 1Password, Authy...) pa potvrda prvim kodom. Isti tok za prvi uređaj (/majmun/zastita) i dodatni (Podešavanja).
 *
 * @example <UvodjenjeDvostruke naUspeh={() => router.replace('/majmun')} />
 */
export default function UvodjenjeDvostruke({ naUspeh }: { naUspeh: () => void }) {
  const [faktor, setFaktor] = useState<{ id: string; qr: string; tajna: string } | null>(null)
  const [kod, setKod] = useState('')
  const [radi, setRadi] = useState(false)
  const [greska, setGreska] = useState('')

  async function pocni() {
    setGreska(''); setRadi(true)
    const supabase = createClient()
    // Nedovršeno ranije uvođenje (zatvoren prozor pre koda) bi blokiralo novo.
    const { data: postojeci } = await supabase.auth.mfa.listFactors()
    for (const f of postojeci?.all ?? []) {
      if (f.status === 'unverified') await supabase.auth.mfa.unenroll({ factorId: f.id })
    }
    const { data, error } = await supabase.auth.mfa.enroll({ factorType: 'totp', friendlyName: `Librum admin ${new Date().toISOString().slice(0, 16)}` })
    setRadi(false)
    if (error) { setGreska(error.message); return }
    setFaktor({ id: data.id, qr: data.totp.qr_code, tajna: data.totp.secret })
  }

  async function potvrdi() {
    if (!faktor) return
    if (!KOD.test(kod)) { setGreska('Upiši šestocifreni kod iz aplikacije.'); return }
    setGreska(''); setRadi(true)
    const { error } = await createClient().auth.mfa.challengeAndVerify({ factorId: faktor.id, code: kod })
    setRadi(false)
    if (error) { setGreska('Kod nije tačan ili je istekao. Upiši novi iz aplikacije.'); return }
    naUspeh()
  }

  if (!faktor) {
    return (
      <div className="space-y-3">
        {greska && <Poruka tekst={greska} />}
        <button type="button" onClick={pocni} disabled={radi} className="w-full rounded-xl px-4 py-3 font-bold text-[14px]"
          style={{ background: '#151515', color: '#FFFFFF' }}>
          {radi ? 'Pripremam…' : 'Uključi dvostruku verifikaciju'}
        </button>
      </div>
    )
  }

  return (
    <div className="space-y-4">
      <ol className="text-[13px] space-y-1 list-decimal pl-5" style={{ color: '#3A3833' }}>
        <li>Otvori aplikaciju za autentifikaciju na telefonu (Google Authenticator, 1Password, Authy).</li>
        <li>Skeniraj QR kod ili ručno upiši ključ.</li>
        <li>Upiši šestocifreni kod koji aplikacija prikaže.</li>
      </ol>
      <div className="flex flex-col sm:flex-row gap-4 items-center">
        {/* eslint-disable-next-line @next/next/no-img-element -- QR stiže kao data: URL od Supabase-a */}
        <img src={faktor.qr} alt="QR kod za aplikaciju za autentifikaciju" width={180} height={180} className="rounded-xl bg-white p-2" style={{ border: '1.5px solid #E7E1D0' }} />
        <div className="min-w-0 text-[12px]" style={{ color: '#6F6C66' }}>
          <p className="font-bold uppercase tracking-wider text-[10px] mb-1">Ključ za ručni unos</p>
          <code className="block break-all text-[13px] font-mono" style={{ color: '#151515' }}>{faktor.tajna}</code>
        </div>
      </div>
      <label className="block">
        <span className="text-[11px] font-bold uppercase tracking-widest" style={{ color: '#6F6C66' }}>Kod iz aplikacije</span>
        <input value={kod} onChange={e => setKod(e.target.value.replace(/\D/g, '').slice(0, 6))} inputMode="numeric" autoComplete="one-time-code"
          className="input mt-1 tracking-[0.4em] text-center text-[20px] font-bold" placeholder="000000" autoFocus />
      </label>
      {greska && <Poruka tekst={greska} />}
      <button type="button" onClick={potvrdi} disabled={radi || kod.length !== 6} className="w-full rounded-xl px-4 py-3 font-bold text-[14px]"
        style={{ background: '#12907E', color: '#FFFFFF', opacity: kod.length === 6 ? 1 : 0.6 }}>
        {radi ? 'Proveravam…' : 'Potvrdi i uključi'}
      </button>
    </div>
  )
}

export function Poruka({ tekst, uspeh = false }: { tekst: string; uspeh?: boolean }) {
  return (
    <div role={uspeh ? 'status' : 'alert'} className="rounded-xl px-4 py-3 text-[13px] font-medium"
      style={uspeh ? { background: '#DFF3EE', color: '#0E6F61' } : { background: '#FFE3EA', color: '#C42B4F' }}>
      {tekst}
    </div>
  )
}
