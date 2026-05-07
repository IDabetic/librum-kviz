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
] as const

type Row = {
  id: string
  question_text: string
  options: string[]
  correct_answer: number
  difficulty: string
  is_active: boolean
}

export default function EditKafanaForm({ row }: { row: Row }) {
  const router = useRouter()
  const [text, setText] = useState(row.question_text)
  const [options, setOptions] = useState<string[]>(row.options)
  const [correctIdx, setCorrectIdx] = useState(row.correct_answer)
  const [difficulty, setDifficulty] = useState<typeof DIFFICULTIES[number]['id']>(
    (DIFFICULTIES.find(d => d.id === row.difficulty)?.id) ?? 'medium'
  )
  const [active, setActive] = useState(row.is_active)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState(false)

  function setOpt(i: number, v: string) {
    setOptions(prev => prev.map((o, idx) => idx === i ? v : o))
  }

  async function save() {
    setError('')
    if (!text.trim()) { setError('Tekst pitanja je obavezan.'); return }
    if (options.some(o => !o.trim())) { setError('Sva 4 odgovora moraju biti popunjena.'); return }
    const opts = options.map(o => o.trim())
    if (new Set(opts).size !== 4) { setError('Odgovori ne smeju biti identični.'); return }

    setBusy(true)
    const correct = opts[correctIdx]
    const wrongs = opts.filter((_, i) => i !== correctIdx)
    const finalOpts = [correct, ...wrongs]

    const { error: e } = await createClient()
      .from('kafana_questions')
      .update({
        question_text: text.trim(),
        options: finalOpts,
        correct_answer: 0,
        difficulty,
        is_active: active,
      })
      .eq('id', row.id)

    setBusy(false)
    if (e) { setError(e.message); return }
    setSuccess(true); setTimeout(() => setSuccess(false), 2000)
    router.refresh()
  }

  async function remove() {
    if (!confirm('Sigurno obriši ovo pitanje?')) return
    setBusy(true)
    await createClient().from('kafana_questions').delete().eq('id', row.id)
    setBusy(false)
    router.push('/majmun/kafana')
  }

  return (
    <div className="max-w-3xl">
      <Link href="/majmun/kafana"
        className="inline-flex items-center gap-1.5 text-[13px] font-medium mb-6 transition-opacity hover:opacity-70"
        style={{ color: '#b91c1c' }}>
        <IconBack size={16} strokeWidth={2.2} />
        Sva Kafanska pitanja
      </Link>

      <h1 className="font-black tracking-tight mb-6" style={{ color: '#343434', fontSize: 'clamp(22px, 4vw, 28px)' }}>
        Izmena pitanja
      </h1>

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

        <label className="block">
          <span className="text-[12px] font-bold uppercase tracking-wider" style={{ color: '#9C9C9C' }}>Tekst pitanja</span>
          <textarea value={text} onChange={e => setText(e.target.value)} rows={3} className="input w-full mt-1.5" />
        </label>

        <div>
          <span className="text-[12px] font-bold uppercase tracking-wider mb-2 block" style={{ color: '#9C9C9C' }}>Odgovori (radio = tačan)</span>
          <div className="space-y-2">
            {options.map((o, i) => (
              <label key={i} className="flex items-center gap-3 p-3 rounded-2xl cursor-pointer"
                style={{ background: correctIdx === i ? '#E8F8F0' : '#F2F2F2' }}>
                <input type="radio" name="correct" checked={correctIdx === i}
                  onChange={() => setCorrectIdx(i)} className="w-4 h-4 flex-shrink-0" />
                <input value={o} onChange={e => setOpt(i, e.target.value)}
                  className="input flex-1" style={{ background: 'white' }} />
              </label>
            ))}
          </div>
        </div>

        <label className="block">
          <span className="text-[12px] font-bold uppercase tracking-wider" style={{ color: '#9C9C9C' }}>Težina</span>
          <select value={difficulty} onChange={e => setDifficulty(e.target.value as typeof DIFFICULTIES[number]['id'])}
            className="input w-full mt-1.5">
            {DIFFICULTIES.map(d => <option key={d.id} value={d.id}>{d.label}</option>)}
          </select>
        </label>

        <label className="flex items-center gap-2 cursor-pointer">
          <input type="checkbox" checked={active} onChange={e => setActive(e.target.checked)} className="w-4 h-4" />
          <span className="text-[13px]" style={{ color: '#343434' }}>Aktivno</span>
        </label>

        <div className="flex gap-3 pt-2">
          <button onClick={save} disabled={busy} className="btn btn-primary btn-md flex-1">
            {busy ? 'Čuvam…' : 'Sačuvaj izmene'}
          </button>
          <button onClick={remove} disabled={busy} className="btn btn-md"
            style={{ background: '#FEE2E2', color: '#b91c1c' }}>
            Obriši
          </button>
        </div>
      </div>
    </div>
  )
}
