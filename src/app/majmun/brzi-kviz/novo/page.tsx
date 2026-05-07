'use client'

import { useState } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { IconBack, IconCheck } from '@/components/icons'

const CATEGORIES = ['', 'književnost', 'istorija', 'geografija', 'sport', 'kultura', 'priroda', 'nauka', 'film', 'muzika', 'opšte znanje']
const DIFFICULTIES = [
  { id: 'easy', label: 'Lako' },
  { id: 'medium', label: 'Srednje' },
  { id: 'hard', label: 'Teško' },
] as const

export default function NovaTvrdnjaPage() {
  const router = useRouter()
  const [statement, setStatement] = useState('')
  const [correct, setCorrect] = useState<boolean>(true)
  const [explanation, setExplanation] = useState('')
  const [category, setCategory] = useState('opšte znanje')
  const [difficulty, setDifficulty] = useState<typeof DIFFICULTIES[number]['id']>('medium')
  const [active, setActive] = useState(true)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState(false)

  function reset() {
    setStatement(''); setCorrect(true); setExplanation('')
    setActive(true)
  }

  async function save(addAnother: boolean) {
    setError('')
    if (!statement.trim()) { setError('Tvrdnja je obavezna.'); return }
    if (!explanation.trim()) { setError('Objašnjenje je obavezno.'); return }
    setBusy(true)
    const { error: e } = await createClient().from('quick_statements').insert({
      statement: statement.trim(),
      correct_answer: correct,
      explanation: explanation.trim(),
      category: category || null,
      difficulty,
      is_active: active,
    })
    setBusy(false)
    if (e) {
      if (e.code === '23505') setError('Tvrdnja sa istim tekstom već postoji.')
      else setError(e.message)
      return
    }
    setSuccess(true); setTimeout(() => setSuccess(false), 2000)
    if (addAnother) reset(); else router.push('/majmun/brzi-kviz')
  }

  return (
    <div className="max-w-3xl">
      <Link href="/majmun/brzi-kviz" className="inline-flex items-center gap-1.5 text-[13px] font-medium mb-6 transition-opacity hover:opacity-70" style={{ color: '#609DED' }}>
        <IconBack size={16} strokeWidth={2.2} /> Sve tvrdnje
      </Link>

      <h1 className="font-black tracking-tight mb-6" style={{ color: '#343434', fontSize: 'clamp(22px, 4vw, 28px)' }}>
        Nova tvrdnja
      </h1>

      <div className="card-soft p-6 sm:p-8">
        {success && (
          <div className="rounded-2xl px-4 py-3 mb-5 text-[13px] font-medium flex items-center gap-2" style={{ background: '#E8F8F0', color: '#15803d' }}>
            <IconCheck size={16} className="text-[#15803d]" /> Sačuvano.
          </div>
        )}
        {error && <div className="rounded-2xl px-4 py-3 mb-5 text-[13px] font-medium" style={{ background: '#FEE2E2', color: '#b91c1c' }}>{error}</div>}

        <div className="mb-5">
          <label className="block text-[13px] font-bold mb-2 tracking-tight" style={{ color: '#343434' }}>Tvrdnja *</label>
          <textarea value={statement} onChange={e => setStatement(e.target.value)} className="input resize-none" rows={3}
            placeholder='Npr. „Rokada je pojam iz šaha."' />
        </div>

        <div className="mb-5">
          <label className="block text-[13px] font-bold mb-2 tracking-tight" style={{ color: '#343434' }}>Tačan odgovor *</label>
          <div className="grid grid-cols-2 gap-2">
            <button type="button" onClick={() => setCorrect(true)}
              className="py-3 rounded-2xl font-bold text-[14px] transition-all"
              style={correct ? { background: '#4CAF50', color: 'white' } : { background: '#F2F2F2', color: '#9C9C9C' }}>
              ✓ Tačno
            </button>
            <button type="button" onClick={() => setCorrect(false)}
              className="py-3 rounded-2xl font-bold text-[14px] transition-all"
              style={!correct ? { background: '#E55353', color: 'white' } : { background: '#F2F2F2', color: '#9C9C9C' }}>
              ✗ Netačno
            </button>
          </div>
        </div>

        <div className="mb-5">
          <label className="block text-[13px] font-bold mb-2 tracking-tight" style={{ color: '#343434' }}>Objašnjenje *</label>
          <textarea value={explanation} onChange={e => setExplanation(e.target.value)} className="input resize-none" rows={2}
            placeholder="Kratak komentar koji se prikaže posle odgovora." />
        </div>

        <div className="grid sm:grid-cols-2 gap-4 mb-5">
          <div>
            <label className="block text-[13px] font-bold mb-2 tracking-tight" style={{ color: '#343434' }}>Kategorija</label>
            <select value={category} onChange={e => setCategory(e.target.value)} className="input">
              {CATEGORIES.map(c => <option key={c} value={c}>{c || '— bez kategorije —'}</option>)}
            </select>
          </div>
          <div>
            <label className="block text-[13px] font-bold mb-2 tracking-tight" style={{ color: '#343434' }}>Težina</label>
            <div className="grid grid-cols-3 gap-1.5">
              {DIFFICULTIES.map(d => (
                <button key={d.id} type="button" onClick={() => setDifficulty(d.id)}
                  className="py-2 rounded-xl text-[12px] font-bold transition-all"
                  style={difficulty === d.id ? { background: '#609DED', color: 'white' } : { background: '#F2F2F2', color: '#9C9C9C' }}>
                  {d.label}
                </button>
              ))}
            </div>
          </div>
        </div>

        <label className="flex items-center gap-3 mb-6 cursor-pointer">
          <button type="button" onClick={() => setActive(a => !a)}
            className="w-5 h-5 rounded-md border-2 flex items-center justify-center flex-shrink-0"
            style={active ? { borderColor: '#4CAF50', background: '#4CAF50' } : { borderColor: 'rgba(52,52,52,0.20)', background: 'white' }}>
            {active && <span className="text-white font-black text-[10px]">✓</span>}
          </button>
          <span className="text-[13px] font-medium" style={{ color: '#343434' }}>Aktivno</span>
        </label>

        <div className="flex flex-col sm:flex-row gap-2">
          <button onClick={() => save(false)} disabled={busy} className="btn btn-primary btn-md flex-1">
            {busy ? 'Čuvanje…' : 'Sačuvaj i nazad'}
          </button>
          <button onClick={() => save(true)} disabled={busy} className="btn btn-secondary btn-md flex-1">
            Sačuvaj i dodaj novu
          </button>
        </div>
      </div>
    </div>
  )
}
