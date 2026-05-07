'use client'

import { useState } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { IconBack, IconCheck } from '@/components/icons'

const GENRES = ['Drama', 'Fantastika', 'Ljubavni', 'Istorijski', 'Krimi', 'Triler', 'Domaći', 'Horor'] as const
type Genre = typeof GENRES[number]

type Row = {
  id: string
  genre: string
  question_text: string
  options: string[]
  correct_answer: number
  is_active: boolean
  times_shown: number
  times_correct: number
  times_wrong: number
  created_at: string
}

export default function EditBookForm({ row }: { row: Row }) {
  const router = useRouter()
  const [text, setText] = useState(row.question_text)
  const [options, setOptions] = useState<string[]>([...row.options])
  const [correctIdx, setCorrectIdx] = useState(row.correct_answer)
  const [genre, setGenre] = useState<Genre>((GENRES as readonly string[]).includes(row.genre) ? row.genre as Genre : 'Drama')
  const [active, setActive] = useState(row.is_active)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [saved, setSaved] = useState(false)
  const [confirmDelete, setConfirmDelete] = useState(false)
  const [deleting, setDeleting] = useState(false)

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
    const correct = opts[correctIdx]
    const wrongs = opts.filter((_, i) => i !== correctIdx)
    const finalOpts = [correct, ...wrongs]

    const { error: e } = await supabase.from('book_questions').update({
      genre,
      question_text: text.trim(),
      options: finalOpts,
      correct_answer: 0,
      is_active: active,
    }).eq('id', row.id)

    setBusy(false)
    if (e) { setError(e.message); return }

    setSaved(true)
    setTimeout(() => setSaved(false), 2000)
    router.refresh()
  }

  async function doDelete() {
    setDeleting(true)
    const { error: e } = await createClient().from('book_questions').delete().eq('id', row.id)
    if (e) { setDeleting(false); setError(e.message); return }
    router.push('/majmun/book-kviz')
  }

  const accuracy = row.times_shown > 0 ? Math.round((row.times_correct / row.times_shown) * 100) : null

  return (
    <div className="max-w-3xl space-y-5">
      <Link href="/majmun/book-kviz"
        className="inline-flex items-center gap-1.5 text-[13px] font-medium transition-opacity hover:opacity-70"
        style={{ color: '#609DED' }}>
        <IconBack size={16} strokeWidth={2.2} /> Sva Book pitanja
      </Link>

      <div className="flex items-center justify-between flex-wrap gap-3">
        <h1 className="font-black tracking-tight" style={{ color: '#343434', fontSize: 'clamp(22px, 4vw, 28px)' }}>
          Izmena Book pitanja
        </h1>
        {row.times_shown > 0 && (
          <p className="text-[12px]" style={{ color: '#9C9C9C' }}>
            {row.times_shown} prikaza · {accuracy}% tačnih
          </p>
        )}
      </div>

      <div className="card-soft p-6 sm:p-8">
        {saved && (
          <div className="rounded-2xl px-4 py-3 mb-5 text-[13px] font-medium flex items-center gap-2" style={{ background: '#E8F8F0', color: '#15803d' }}>
            <IconCheck size={16} className="text-[#15803d]" /> Sačuvano.
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
            className="input resize-none" rows={3} />
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
          <button onClick={save} disabled={busy} className="btn btn-primary btn-md flex-1">
            {busy ? 'Čuvanje…' : 'Sačuvaj izmene'}
          </button>
        </div>
      </div>

      {/* Danger zone */}
      <div className="card-soft p-6" style={{ borderColor: 'rgba(229,83,83,0.20)' }}>
        <h3 className="font-bold text-[14px] mb-2" style={{ color: '#E55353' }}>Brisanje pitanja</h3>
        <p className="text-[12px] mb-4" style={{ color: '#9C9C9C' }}>
          Trajno ukloni iz baze. Ne može se vratiti.
        </p>
        {!confirmDelete ? (
          <button onClick={() => setConfirmDelete(true)} className="btn btn-md"
            style={{ border: '1.5px solid rgba(229,83,83,0.30)', color: '#E55353', background: 'transparent' }}>
            Obriši pitanje
          </button>
        ) : (
          <div className="flex gap-2">
            <button onClick={() => setConfirmDelete(false)} className="btn btn-secondary btn-md flex-1">Odustani</button>
            <button onClick={doDelete} disabled={deleting} className="btn btn-md flex-1"
              style={{ background: '#E55353', color: 'white' }}>
              {deleting ? 'Brisanje…' : 'Trajno obriši'}
            </button>
          </div>
        )}
      </div>
    </div>
  )
}
