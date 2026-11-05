'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'

type Pitanje = { id: string; question_text: string; options: string[]; correct_answer: number; is_active: boolean }
type Prijava = { id: string; reason: string | null; status: string; created_at: string }

const SLOVA = ['A', 'B', 'C', 'D']

/** Izmena (zamena) pitanja struke: tekst, 4 odgovora, tačan, aktivno; čuvanje rešava prijave na čekanju. */
export default function IzmenaPitanjaStruke({ pitanje, prijave }: { pitanje: Pitanje; prijave: Prijava[] }) {
  const router = useRouter()
  const [tekst, setTekst] = useState(pitanje.question_text)
  const [odgovori, setOdgovori] = useState<string[]>(pitanje.options)
  const [tacan, setTacan] = useState(pitanje.correct_answer)
  const [aktivno, setAktivno] = useState(pitanje.is_active)
  const [radi, setRadi] = useState(false)
  const [poruka, setPoruka] = useState<{ ok: boolean; tekst: string } | null>(null)
  const naCekanju = prijave.filter(p => p.status === 'pending')

  async function sacuvaj() {
    const ociscen = odgovori.map(o => o.trim())
    if (new Set(ociscen.map(o => o.toLowerCase())).size !== ociscen.length) { setPoruka({ ok: false, tekst: 'Odgovori ne smeju biti isti.' }); return }
    setRadi(true); setPoruka(null)
    const supabase = createClient()
    const { error } = await supabase.rpc('admin_karijera_pitanje_sacuvaj', {
      p_id: pitanje.id, p_tekst: tekst, p_opcije: ociscen, p_tacan: tacan, p_aktivno: aktivno,
    })
    if (!error && naCekanju.length > 0) {
      // Ispravljeno pitanje zatvara prijave igrača, isto kao „Reši” u delu Prijave.
      await supabase.from('question_reports').update({ status: 'resolved', resolved_at: new Date().toISOString() }).in('id', naCekanju.map(p => p.id))
    }
    setRadi(false)
    if (error) { setPoruka({ ok: false, tekst: error.message }); return }
    setPoruka({ ok: true, tekst: naCekanju.length ? 'Sačuvano, prijave su rešene.' : 'Sačuvano.' })
    router.refresh()
  }

  return (
    <div className="space-y-5">
      {naCekanju.length > 0 && (
        <div className="card-soft p-5">
          <p className="text-[11px] font-bold uppercase tracking-widest mb-2" style={{ color: '#C42B4F' }}>Prijave igrača ({naCekanju.length})</p>
          <ul className="space-y-1.5 text-[13px]" style={{ color: '#151515' }}>
            {naCekanju.map(p => <li key={p.id}>„{p.reason ?? 'bez razloga'}”</li>)}
          </ul>
        </div>
      )}

      <div className="card-soft p-6 space-y-5">
        <div>
          <label htmlFor="tekst" className="block text-[13px] font-bold mb-2" style={{ color: '#151515' }}>Tekst pitanja</label>
          <textarea id="tekst" value={tekst} onChange={e => setTekst(e.target.value)} className="input resize-none" rows={3} />
        </div>

        <fieldset>
          <legend className="block text-[13px] font-bold mb-2" style={{ color: '#151515' }}>Odgovori (izaberi tačan)</legend>
          <div className="space-y-2">
            {odgovori.map((o, i) => (
              <div key={i} className="flex items-center gap-3">
                <input type="radio" name="tacan" checked={tacan === i} onChange={() => setTacan(i)} aria-label={`Tačan je odgovor ${SLOVA[i]}`}
                  className="w-5 h-5 flex-shrink-0 accent-[#12907E]" />
                <input value={o} onChange={e => setOdgovori(prev => prev.map((x, j) => j === i ? e.target.value : x))}
                  className="input flex-1" aria-label={`Odgovor ${SLOVA[i]}`} />
              </div>
            ))}
          </div>
        </fieldset>

        <label className="flex items-center gap-3 cursor-pointer text-[13px] font-medium" style={{ color: '#151515' }}>
          <input type="checkbox" checked={aktivno} onChange={e => setAktivno(e.target.checked)} className="w-5 h-5 accent-[#12907E]" />
          Aktivno (igra ga daje u Karijeristi)
        </label>

        {poruka && <p className="text-[13px] font-semibold" role="status" style={{ color: poruka.ok ? '#0E6F61' : '#C42B4F' }}>{poruka.tekst}</p>}

        <button type="button" onClick={sacuvaj} disabled={radi} className="btn btn-primary btn-md w-full">
          {radi ? 'Čuvam…' : 'Sačuvaj izmene'}
        </button>
      </div>
    </div>
  )
}
