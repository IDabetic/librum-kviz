'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'

export type RedPrijave = {
  vrsta: 'objava' | 'komentar'
  id: number
  objava: number
  tekst: string
  autor: string
  nadimak: string
  prijava: number
  razlozi: string | null
  sakriveno: boolean
  poslednja: string | null
}

function datum(s: string | null): string {
  return s ? new Date(s).toLocaleString('sr', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' }) : ''
}

/** „Vrati” briše prijave i vraća sadržaj; „Obriši” uklanja sadržaj za sve (komentari ispod objave idu sa njom). */
export default function ZajednicaList({ redovi }: { redovi: RedPrijave[] }) {
  const router = useRouter()
  const [radi, setRadi] = useState<string | null>(null)
  const [greska, setGreska] = useState<string | null>(null)

  async function moderisi(r: RedPrijave, radnja: 'vrati' | 'obrisi') {
    if (radnja === 'obrisi' && !confirm(r.vrsta === 'objava' ? 'Obrisati objavu i sve komentare ispod nje?' : 'Obrisati komentar?')) return
    const kljuc = `${r.vrsta}-${r.id}`
    setRadi(kljuc); setGreska(null)
    const { error } = await createClient().rpc('admin_moderisi', { p_vrsta: r.vrsta, p_id: r.id, p_radnja: radnja })
    setRadi(null)
    if (error) { setGreska(error.message); return }
    router.refresh()
  }

  if (redovi.length === 0) {
    return (
      <div className="card-soft py-16 text-center">
        <p className="font-bold text-[16px]" style={{ color: '#151515' }}>Nema prijavljenih objava ni komentara</p>
      </div>
    )
  }

  return (
    <div className="space-y-3">
      {greska && <p className="text-[13px] font-semibold" style={{ color: '#C8102E' }}>{greska}</p>}
      {redovi.map(r => {
        const kljuc = `${r.vrsta}-${r.id}`
        return (
          <div key={kljuc} className="card-soft p-4 space-y-2">
            <div className="flex items-center gap-2 text-[12px] font-semibold" style={{ color: '#6F6C66' }}>
              <span style={{ color: '#151515' }}>{r.vrsta === 'objava' ? 'Objava' : 'Komentar'}</span>
              <span>· {r.nadimak}</span>
              <span>· {r.prijava} {r.prijava === 1 ? 'prijava' : 'prijave'}{r.razlozi ? ` (${r.razlozi})` : ''}</span>
              <span>· {datum(r.poslednja)}</span>
              {r.sakriveno && <span style={{ color: '#C8102E' }}>· sakriveno</span>}
            </div>
            <p className="text-[15px] whitespace-pre-wrap" style={{ color: '#151515' }}>{r.tekst || '(bez teksta)'}</p>
            <div className="flex gap-4 text-[13px] font-bold">
              <button disabled={radi === kljuc} onClick={() => moderisi(r, 'vrati')} style={{ color: '#12907E' }}>
                U redu je, vrati
              </button>
              <button disabled={radi === kljuc} onClick={() => moderisi(r, 'obrisi')} style={{ color: '#C8102E' }}>
                Obriši
              </button>
            </div>
          </div>
        )
      })}
    </div>
  )
}
