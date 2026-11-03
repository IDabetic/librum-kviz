'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'

/** Redosled odgovora se sam meša svakog ponedeljka u 04:00; urednik može i odmah (RPC admin_promesaj_odgovore). */
export default function MesanjeOdgovora({ poslednje }: { poslednje: { kad: string; pitanja: number } | null }) {
  const [stanje, setStanje] = useState(poslednje)
  const [radi, setRadi] = useState(false)
  const [greska, setGreska] = useState<string | null>(null)

  async function promesaj() {
    if (!confirm('Promešati redosled odgovora u svim pitanjima sada?')) return
    setRadi(true); setGreska(null)
    const { data, error } = await createClient().rpc('admin_promesaj_odgovore')
    setRadi(false)
    if (error) { setGreska(error.message); return }
    setStanje({ kad: new Date().toISOString(), pitanja: data as number })
  }

  return (
    <div className="card-soft p-5 space-y-3">
      <h2 className="font-bold text-[16px]" style={{ color: '#151515' }}>Redosled odgovora</h2>
      <p className="text-[13px]" style={{ color: '#6F6C66' }}>
        Igrači pamte da je tačan odgovor bio „pod A”, pa se redosled sam meša svakog ponedeljka u 04:00.
        {stanje ? ` Poslednje mešanje: ${new Date(stanje.kad).toLocaleString('sr')} (${stanje.pitanja.toLocaleString('sr')} pitanja).` : ' Još nije mešano.'}
      </p>
      {greska && <p className="text-[13px] font-semibold" style={{ color: '#C8102E' }}>{greska}</p>}
      <button onClick={promesaj} disabled={radi} className="text-[14px] font-bold" style={{ color: '#12907E' }}>
        {radi ? 'Mešam…' : 'Promešaj sada'}
      </button>
    </div>
  )
}
