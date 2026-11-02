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

type Row = {
  id: string
  question_text: string
  options: string[]
  correct_answer: number
  difficulty: string
  info: string | null
  tags: string[] | null
  is_active: boolean
  times_shown: number
  times_correct: number
  times_wrong: number
  created_at: string
}

export default function EditPitanjeForm({ row }: { row: Row }) {
  const router = useRouter()
  const [text, setText] = useState(row.question_text)
  const [options, setOptions] = useState<string[]>(row.options)
  const [correctIdx, setCorrectIdx] = useState(row.correct_answer)
  const [info, setInfo] = useState(row.info || '')
  const [difficulty, setDifficulty] = useState<typeof DIFFICULTIES[number]['id']>(row.difficulty as typeof DIFFICULTIES[number]['id'])
  const [tags, setTags] = useState((row.tags || []).join(', '))
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
    const supabase = createClient()
    const tagArr = tags.split(',').map(t => t.trim()).filter(Boolean)
    const { error: e } = await supabase.from('questions').update({
      question_text: text.trim(),
      options: opts,
      correct_answer: correctIdx,
      difficulty,
      is_active: active,
      info: info.trim() || null,
      tags: tagArr.length > 0 ? tagArr : null,
    }).eq('id', row.id)
    setBusy(false)
    if (e) { setError(e.message); return }
    setSuccess(true)
    setTimeout(() => setSuccess(false), 2000)
    router.refresh()
  }

  async function deletePitanje() {
    if (!confirm('Stvarno obrisati pitanje? Bolje je deaktivirati.')) return
    setBusy(true)
    const supabase = createClient()
    await supabase.from('questions').delete().eq('id', row.id)
    setBusy(false)
    router.push('/majmun/pitanja')
  }

  const accuracy = row.times_shown > 0 ? Math.round((row.times_correct / row.times_shown) * 100) : null

  return (
    <div className="max-w-3xl">

      <Link href="/majmun/pitanja"
        className="inline-flex items-center gap-1.5 text-[13px] font-medium mb-6 transition-opacity hover:opacity-70"
        style={{ color: '#3A36A0' }}>
        <IconBack size={16} strokeWidth={2.2} />
        Sva pitanja
      </Link>

      <h1 className="font-black tracking-tight mb-2" style={{ color: '#1A1A1E', fontSize: 'clamp(22px, 4vw, 28px)' }}>
        Izmeni pitanje
      </h1>
      <p className="text-[12px] mb-5" style={{ color: '#6B6760' }}>
        ID: {row.id} · Kreirano: {new Date(row.created_at).toLocaleString('sr')}
      </p>

      {/* Stats */}
      {row.times_shown > 0 && (
        <div className="card-soft p-4 mb-5">
          <p className="text-[11px] font-bold uppercase tracking-widest mb-3" style={{ color: '#6B6760' }}>Statistika</p>
          <div className="grid grid-cols-3 gap-3">
            <Stat value={row.times_shown} label="Prikazivanja" />
            <Stat value={row.times_correct} label="Tačnih" accent="#2FBF8A" />
            <Stat value={`${accuracy}%`} label="Tačnost" accent="#3A36A0" />
          </div>
        </div>
      )}

      <div className="card-soft p-6 sm:p-8">

        {success && (
          <div className="rounded-2xl px-4 py-3 mb-5 text-[13px] font-medium flex items-center gap-2" style={{ background: '#D4F3E7', color: '#1F8A62' }}>
            <IconCheck size={16} className="text-[#1F8A62]" />
            Sačuvano.
          </div>
        )}

        {error && (
          <div className="rounded-2xl px-4 py-3 mb-5 text-[13px] font-medium" style={{ background: '#FEE2E2', color: '#b91c1c' }}>
            {error}
          </div>
        )}

        <div className="mb-5">
          <label className="block text-[13px] font-bold mb-2 tracking-tight" style={{ color: '#1A1A1E' }}>
            Tekst pitanja
          </label>
          <textarea value={text} onChange={e => setText(e.target.value)}
            className="input resize-none" rows={3} />
        </div>

        <div className="mb-5">
          <label className="block text-[13px] font-bold mb-2 tracking-tight" style={{ color: '#1A1A1E' }}>
            Odgovori (klikni radio za tačan)
          </label>
          <div className="space-y-2">
            {options.map((o, i) => (
              <div key={i} className="flex items-center gap-3">
                <button type="button" onClick={() => setCorrectIdx(i)}
                  className="w-5 h-5 rounded-full border-2 flex items-center justify-center flex-shrink-0 transition-all"
                  style={correctIdx === i
                    ? { borderColor: '#2FBF8A', background: '#2FBF8A' }
                    : { borderColor: 'rgba(26,26,30,0.20)', background: 'white' }}>
                  {correctIdx === i && <div className="w-2 h-2 rounded-full bg-white" />}
                </button>
                <input value={o} onChange={e => setOpt(i, e.target.value)}
                  className="input flex-1" placeholder={`Odgovor ${['A','B','C','D'][i]}`} />
              </div>
            ))}
          </div>
        </div>

        <div className="mb-5">
          <label className="block text-[13px] font-bold mb-2 tracking-tight" style={{ color: '#1A1A1E' }}>
            Objašnjenje
          </label>
          <textarea value={info} onChange={e => setInfo(e.target.value)}
            className="input resize-none" rows={2} />
        </div>

        <div className="grid sm:grid-cols-2 gap-4 mb-5">
          <div>
            <label className="block text-[13px] font-bold mb-2 tracking-tight" style={{ color: '#1A1A1E' }}>Težina</label>
            <div className="grid grid-cols-2 gap-1.5">
              {DIFFICULTIES.map(d => (
                <button key={d.id} type="button" onClick={() => setDifficulty(d.id)}
                  className="py-2 rounded-xl text-[12px] font-bold transition-all"
                  style={difficulty === d.id
                    ? { background: '#3A36A0', color: 'white' }
                    : { background: '#EBE8E1', color: '#6B6760' }}>
                  {d.label}
                </button>
              ))}
            </div>
          </div>
          <div>
            <label className="block text-[13px] font-bold mb-2 tracking-tight" style={{ color: '#1A1A1E' }}>Tagovi</label>
            <input value={tags} onChange={e => setTags(e.target.value)} className="input" placeholder="književnost, ruska" />
          </div>
        </div>

        <label className="flex items-center gap-3 mb-6 cursor-pointer">
          <button type="button" onClick={() => setActive(a => !a)}
            className="w-5 h-5 rounded-md border-2 flex items-center justify-center flex-shrink-0"
            style={active
              ? { borderColor: '#2FBF8A', background: '#2FBF8A' }
              : { borderColor: 'rgba(26,26,30,0.20)', background: 'white' }}>
            {active && <span className="text-white font-black text-[10px]">✓</span>}
          </button>
          <span className="text-[13px] font-medium" style={{ color: '#1A1A1E' }}>
            Aktivno (vidljivo u igri)
          </span>
        </label>

        <div className="flex flex-col sm:flex-row gap-2">
          <button onClick={save} disabled={busy} className="btn btn-primary btn-md flex-1">
            {busy ? 'Čuvanje…' : 'Sačuvaj izmene'}
          </button>
          <button onClick={deletePitanje} disabled={busy}
            className="btn btn-md flex-1"
            style={{ background: '#FEE2E2', color: '#b91c1c' }}>
            Trajno obriši
          </button>
        </div>
      </div>
    </div>
  )
}

function Stat({ value, label, accent }: { value: number | string; label: string; accent?: string }) {
  return (
    <div className="rounded-2xl p-3 text-center" style={{ background: '#EBE8E1' }}>
      <div className="font-black text-[18px] tracking-tight" style={{ color: accent || '#1A1A1E' }}>{value}</div>
      <div className="text-[11px] mt-0.5" style={{ color: '#6B6760' }}>{label}</div>
    </div>
  )
}
