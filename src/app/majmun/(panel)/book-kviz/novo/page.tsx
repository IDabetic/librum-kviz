'use client'

import { useState } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { IconBack, IconCheck } from '@/components/icons'

const GENRES = ['Drama', 'Fantastika', 'Ljubavni', 'Istorijski', 'Krimi', 'Triler', 'Domaći', 'Horor'] as const
type Genre = typeof GENRES[number]

export default function NovoBookPitanjePage() {
  const router = useRouter()
  const [text, setText] = useState('')
  const [options, setOptions] = useState(['', '', '', ''])
  const [correctIdx, setCorrectIdx] = useState(0)
  const [genre, setGenre] = useState<Genre>('Drama')
  const [active, setActive] = useState(true)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState(false)

  function setOpt(i: number, v: string) {
    setOptions(prev => prev.map((o, idx) => idx === i ? v : o))
  }
  function reset() {
    setText(''); setOptions(['', '', '', '']); setCorrectIdx(0); setActive(true)
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

    const { error: e } = await supabase.from('book_questions').insert({
      genre,
      question_text: text.trim(),
      options: finalOpts,
      correct_answer: 0,
      is_active: active,
    })

    setBusy(false)
    if (e) { setError(e.message); return }

    setSuccess(true)
    setTimeout(() => setSuccess(false), 2000)
    if (addAnother) reset()
    else router.push('/majmun/book-kviz')
  }

  return (
    <div className="max-w-3xl">
      <Link href="/majmun/book-kviz"
        className="inline-flex items-center gap-1.5 text-[13px] font-medium mb-6 transition-opacity hover:opacity-70"
        style={{ color: '#609DED' }}>
        <IconBack size={16} strokeWidth={2.2} /> Sva Book pitanja
      </Link>

      <h1 className="font-black tracking-tight mb-6" style={{ color: '#343434', fontSize: 'clamp(22px, 4vw, 28px)' }}>
        Novo Book kviz pitanje
      </h1>

      <div className="card-soft p-6 sm:p-8">
        {success && (
          <div className="rounded-2xl px-4 py-3 mb-5 text-[13px] font-medium flex items-center gap-2" style={{ background: '#E8F8F0', color: '#15803d' }}>
            <IconCheck size={16} className="text-[#15803d]" /> Pitanje sačuvano.
          </div>
        )}
        {error && (
          <div className="rounded-2xl px-4 py-3 mb-5 text-[13px] font-medium" style={{ background: '#FEE2E2', color: '#b91c1c' }}>{error}</div>
        )}

        {/* Genre */}
        <div className="mb-5">
          <label className="block text-[13px] font-bold mb-2 tracking-tight" style={{ color: '#343434' }}>Žanr</label>
          <div className="flex flex-wrap gap-1.5">
            {GENRES.map(g => (
              <button key={g} type="button" onClick={() => setGenre(g)}
                className="px-3 py-1.5 rounded-full text-[12px] font-bold transition-all"
                style={genre === g
                  ? { background: '#9c7a13', color: 'white' }
                  : { background: '#FFECBC', color: '#9c7a13' }}>
                {g}
              </button>
            ))}
          </div>
        </div>

        {/* Question */}
        <div className="mb-5">
          <label className="block text-[13px] font-bold mb-2 tracking-tight" style={{ color: '#343434' }}>Tekst pitanja *</label>
          <textarea value={text} onChange={e => setText(e.target.value)}
            className="input resize-none" rows={3}
            placeholder="Npr. Koji roman prati ljubav Elizabet Benet i gospodina Darsija?" />
        </div>

        {/* Options */}
        <div className="mb-5">
          <label className="block text-[13px] font-bold mb-2 tracking-tight" style={{ color: '#343434' }}>
            Odgovori * (klikni radio dugme za tačan)
          </label>
          <div className="space-y-2">
            {options.map((o, i) => (
              <div key={i} className="flex items-center gap-3">
                <button type="button" onClick={() => setCorrectIdx(i)}
                  className="w-5 h-5 rounded-full border-2 flex items-center justify-center flex-shrink-0 transition-all"
                  style={correctIdx === i
                    ? { borderColor: '#4CAF50', background: '#4CAF50' }
                    : { borderColor: 'rgba(52,52,52,0.20)', background: 'white' }}>
                  {correctIdx === i && <div className="w-2 h-2 rounded-full bg-white" />}
                </button>
                <input value={o} onChange={e => setOpt(i, e.target.value)}
                  className="input flex-1"
                  placeholder={`Odgovor ${['A','B','C','D'][i]}`} />
              </div>
            ))}
          </div>
          <p className="text-[11px] mt-2" style={{ color: '#9C9C9C' }}>
            Tačan: <strong style={{ color: '#4CAF50' }}>{['A','B','C','D'][correctIdx]}</strong>
            {options[correctIdx].trim() && <> — {options[correctIdx]}</>}
          </p>
        </div>

        {/* Active */}
        <label className="flex items-center gap-3 mb-6 cursor-pointer">
          <button type="button" onClick={() => setActive(a => !a)}
            className="w-5 h-5 rounded-md border-2 flex items-center justify-center flex-shrink-0"
            style={active
              ? { borderColor: '#4CAF50', background: '#4CAF50' }
              : { borderColor: 'rgba(52,52,52,0.20)', background: 'white' }}>
            {active && <span className="text-white font-black text-[10px]">✓</span>}
          </button>
          <span className="text-[13px] font-medium" style={{ color: '#343434' }}>
            Aktivno (vidljivo u igri)
          </span>
        </label>

        <div className="flex flex-col sm:flex-row gap-2">
          <button onClick={() => save(false)} disabled={busy} className="btn btn-primary btn-md flex-1">
            {busy ? 'Čuvanje…' : 'Sačuvaj i nazad'}
          </button>
          <button onClick={() => save(true)} disabled={busy} className="btn btn-secondary btn-md flex-1">
            Sačuvaj i dodaj novo
          </button>
        </div>
      </div>
    </div>
  )
}
