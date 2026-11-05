'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'

/** Moderacija imena firme: „Skini ime” (vlasnik dobija obaveštenje) i „Odbaci prijave” (ime ostaje). */
export default function FirmaRadnje({ id, imaIme, prijava }: { id: string; imaIme: boolean; prijava: number }) {
  const router = useRouter()
  const [radi, setRadi] = useState(false)
  const [greska, setGreska] = useState<string | null>(null)

  async function uradi(radnja: 'skini_ime' | 'odbaci_prijave') {
    if (radnja === 'skini_ime' && !confirm('Skinuti ime firme? Vlasnik će morati da izabere novo.')) return
    setRadi(true); setGreska(null)
    const { error } = await createClient().rpc('admin_karijera_firma', { p_id: id, p_radnja: radnja })
    setRadi(false)
    if (error) { setGreska(error.message); return }
    router.refresh()
  }

  if (!imaIme && prijava === 0) return <span style={{ color: '#6F6C66' }}>podrazumevano</span>

  return (
    <div className="space-y-1">
      {prijava > 0 && <p className="text-[12px] font-bold" style={{ color: '#C42B4F' }}>{prijava} {prijava === 1 ? 'prijava' : 'prijave'}</p>}
      <div className="flex gap-3 text-[12px] font-semibold">
        {imaIme && (
          <button type="button" disabled={radi} onClick={() => uradi('skini_ime')} className="hover:underline" style={{ color: '#C42B4F' }}>
            Skini ime
          </button>
        )}
        {prijava > 0 && (
          <button type="button" disabled={radi} onClick={() => uradi('odbaci_prijave')} className="hover:underline" style={{ color: '#12907E' }}>
            Odbaci prijave
          </button>
        )}
      </div>
      {greska && <p className="text-[12px]" style={{ color: '#C42B4F' }}>{greska}</p>}
    </div>
  )
}
