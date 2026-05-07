'use client'

import { useState } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { IconBack, IconCheck } from '@/components/icons'

const DIFFICULTIES = [
  { id: 'easy', label: 'Lako' },
  { id: 'medium', label: 'Srednje' },
  { id: 'hard', label: 'Teško' },
  { id: 'impossible', label: 'Nemoguće' },
] as const

// Auto-tag every question created here so PRO/Duel filters skip it.
const BRZI_ONLY_TAG = 'brzi-only'

export default function NovoBrziPitanjePage() {
  const router = useRouter()
  const [text, setText] = useState('')
  const [options, setOptions] = useState(['', '', '', ''])
  const [correctIdx, setCorrectIdx] = useState(0)
  const [difficulty, setDifficulty] = useState<typeof DIFFICULTIES[number]['id']>('medium')
  const [extraTags, setExtraTags] = useState('')
  const [active, setActive] = useState(true)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState(false)

  function setOpt(i: number, v: string) {
    setOptions(prev => prev.map((o, idx) => idx === i ? v : o))
  }

  function reset() {
    setText(''); setOptions(['', '', '', '']); setCorrectIdx(0)
    setExtraTags(''); setActive(true)
  }

  async function save(addAnother: boolean) {
    setError('')
    if (!text.trim()) { setError('Tekst pitanja je obavezan.'); return }
    if (options.some(o => !o.trim())) { setError('Sva 4 odgovora moraju biti popunjena.'); return }
    const opts = options.map(o => o.trim())
    if (new Set(opts).size !== 4) { setError('Odgovori ne smeju biti identični.'); return }

    setBusy(true)
    const supabase = createClient()
    const correct = opts[correctIdx]
    const wrongs = opts.filter((_, i) => i !== correctIdx)
    const finalOpts = [correct, ...wrongs]

    // brzi-only is always first; admin can add more tags after a comma.
    const userTags = extraTags.split(',').map(t => t.trim()).filter(Boolean).filter(t => t !== BRZI_ONLY_TAG)
    const tags = [BRZI_ONLY_TAG, ...userTags]

    const { error: e } = await supabase.from('questions').insert({
      question_text: text.trim(),
      options: finalOpts,
      correct_answer: 0,
      difficulty,
      is_active: active,
      info: null,
      tags,
    })

    setBusy(false)

    if (e) {
      if (e.code === '23505') setError('Pitanje sa ovim tekstom već postoji.')
      else setError(e.message)
      return
    }

    setSuccess(true)
    setTimeout(() => setSuccess(false), 2000)

    if (addAnother) reset()
    else router.push('/majmun/brzi-kviz')
  }

  return (
    <div className="max-w-3xl">

      <Link href="/majmun/brzi-kviz"
        className="inline-flex items-center gap-1.5 text-[13px] font-medium mb-6 transition-opacity hover:opacity-70"
        style={{ color: '#609DED' }}>
        <IconBack size={16} strokeWidth={2.2} />
        Sva Brzi pitanja
      </Link>

      <h1 className="font-black tracking-tight mb-6" style={{ color: '#343434', fontSize: 'clamp(22px, 4vw, 28px)' }}>
        Novo Brzi pitanje
      </h1>

      <div className="rounded-2xl px-4 py-3 mb-5 text-[12px] font-medium flex items-start gap-2"
        style={{ background: '#FFECBC', color: '#9c7a13' }}>
        <span className="text-[14px] leading-none mt-px">⚡</span>
        <span>Ovo pitanje će se videti <strong>samo u Brzom kvizu</strong>. Igra prikazuje samo jedan od 4 odgovora i pita „Tačno ili netačno?“.</span>
      </div>

      <div className="card-soft p-6 sm:p-8 space-y-5">

        {success && (
          <div className="rounded-2xl px-4 py-3 text-[13px] font-medium flex items-center gap-2" style={{ background: '#E8F8F0', color: '#15803d' }}>
            <IconCheck size={16} className="text-[#15803d]" />
            Sačuvano.
          </div>
        )}
        {error && (
          <div className="rounded-2xl px-4 py-3 text-[13px] font-medium" style={{ background: '#FEE2E2', color: '#b91c1c' }}>
            {error}
          </div>
        )}

        {/* Question text */}
        <label className="block">
          <span className="text-[12px] font-bold uppercase tracking-wider" style={{ color: '#9C9C9C' }}>Tekst pitanja</span>
          <textarea value={text} onChange={e => setText(e.target.value)} rows={3}
            placeholder="Npr. Koji je glavni grad Australije?"
            className="input w-full mt-1.5" />
        </label>

        {/* Answers */}
        <div>
          <span className="text-[12px] font-bold uppercase tracking-wider mb-2 block" style={{ color: '#9C9C9C' }}>
            Odgovori (izaberi tačan klikom na radio)
          </span>
          <div className="space-y-2">
            {options.map((o, i) => (
              <label key={i} className="flex items-center gap-3 p-3 rounded-2xl transition-colors cursor-pointer"
                style={{ background: correctIdx === i ? '#E8F8F0' : '#F2F2F2' }}>
                <input type="radio" name="correct" checked={correctIdx === i}
                  onChange={() => setCorrectIdx(i)}
                  className="w-4 h-4 flex-shrink-0" />
                <input value={o} onChange={e => setOpt(i, e.target.value)}
                  placeholder={`Odgovor ${i + 1}${correctIdx === i ? ' (tačan)' : ''}`}
                  className="input flex-1" style={{ background: 'white' }} />
              </label>
            ))}
          </div>
        </div>

        {/* Difficulty + extra tags */}
        <div className="grid sm:grid-cols-2 gap-4">
          <label className="block">
            <span className="text-[12px] font-bold uppercase tracking-wider" style={{ color: '#9C9C9C' }}>Težina</span>
            <select value={difficulty} onChange={e => setDifficulty(e.target.value as typeof DIFFICULTIES[number]['id'])}
              className="input w-full mt-1.5">
              {DIFFICULTIES.map(d => <option key={d.id} value={d.id}>{d.label}</option>)}
            </select>
          </label>
          <label className="block">
            <span className="text-[12px] font-bold uppercase tracking-wider" style={{ color: '#9C9C9C' }}>
              Dodatni tagovi (opciono, zarez razdvaja)
            </span>
            <input value={extraTags} onChange={e => setExtraTags(e.target.value)}
              placeholder="npr. geografija, sport"
              className="input w-full mt-1.5" />
          </label>
        </div>

        {/* Active toggle */}
        <label className="flex items-center gap-2 cursor-pointer">
          <input type="checkbox" checked={active} onChange={e => setActive(e.target.checked)}
            className="w-4 h-4" />
          <span className="text-[13px]" style={{ color: '#343434' }}>Aktivno (vidljivo igračima odmah)</span>
        </label>

        {/* Actions */}
        <div className="flex gap-3 pt-2">
          <button onClick={() => save(false)} disabled={busy}
            className="btn btn-primary btn-md flex-1">
            {busy ? 'Čuvam…' : 'Sačuvaj'}
          </button>
          <button onClick={() => save(true)} disabled={busy}
            className="btn btn-secondary btn-md">
            {busy ? '…' : 'Sačuvaj i dodaj još'}
          </button>
        </div>
      </div>
    </div>
  )
}
