'use client'

import Link from 'next/link'
import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'

type Red = { mesto: number; user_id: string; nadimak: string | null; poeni: number }

/** Koliko često traka u zaglavlju osvežava rang listu (ista RPC kao aplikacija, rang_lista_igre). */
const OSVEZAVANJE_MS = 60_000
const BROJ = 5

/**
 * Rang lista uživo u zaglavlju: Osvajanje sveta ove nedelje, isti redosled kao u aplikaciji.
 *
 * @example <RangTraka />
 */
export function RangTraka() {
  const [redovi, setRedovi] = useState<Red[] | null>(null)

  useEffect(() => {
    const sb = createClient()
    let ziv = true
    async function ucitaj() {
      const { data, error } = await sb.rpc('rang_lista_igre', { p_igra: 'osvajanje', p_period: 'nedelja', p_broj: BROJ })
      if (!ziv) return
      // Greška ne briše poslednju listu: traka samo ostane na onome što je već prikazala.
      if (error) { console.warn('rang traka:', error.message); return }
      setRedovi((data ?? []) as Red[])
    }
    void ucitaj()
    const sat = setInterval(ucitaj, OSVEZAVANJE_MS)
    return () => { ziv = false; clearInterval(sat) }
  }, [])

  if (redovi && redovi.length === 0) return null
  return (
    <div style={{ background: '#151515', color: '#F3F0E6' }}>
      <Link href="/ranglista" className="max-w-6xl mx-auto px-4 sm:px-6 h-9 flex items-center gap-4 overflow-x-auto whitespace-nowrap text-[13px]"
        aria-label="Rang lista Osvajanja sveta ove nedelje, otvori celu listu">
        <span className="flex items-center gap-2 font-bold shrink-0" style={{ color: '#FFD84D' }}>
          <span className="w-2 h-2 rounded-full animate-pulse" style={{ background: '#2FD27A' }} aria-hidden />
          Rang uživo · Osvajanje
        </span>
        {(redovi ?? []).map(r => (
          <span key={r.user_id} className="flex items-center gap-1.5 shrink-0">
            <span className="font-bold" style={{ color: r.mesto === 1 ? '#FFD84D' : '#A9A49A' }}>{r.mesto}.</span>
            <span className="font-semibold">{r.nadimak || 'Igrač'}</span>
            <span className="tabular-nums" style={{ color: '#A9A49A' }}>{r.poeni.toLocaleString('sr-RS')}</span>
          </span>
        ))}
        {!redovi && <span style={{ color: '#A9A49A' }}>Učitavam…</span>}
        <span className="ml-auto font-bold underline underline-offset-4 shrink-0">Cela lista</span>
      </Link>
    </div>
  )
}
