'use client'

import { useState } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { IconBack, IconCheck } from '@/components/icons'

const CATS = ['Sport', 'Geografija', 'Istorija', 'Kultura', 'Priroda', 'Predmeti']

type Row = {
  id: string
  word: string
  word_length: number
  hint: string
  category: string
  is_active: boolean
  times_used: number
  times_guessed: number
  created_at: string
}

export default function EditPojam({ row }: { row: Row }) {
  const router = useRouter()
  const [word, setWord] = useState(row.word)
  const [hint, setHint] = useState(row.hint)
  const [category, setCategory] = useState(row.category)
  const [active, setActive] = useState(row.is_active)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState(false)

  const wordTrim = word.trim().toLowerCase()
  const letterCount = wordTrim.replace(/[^\p{L}]/gu, '').length

  async function save() {
    setError('')
    if (letterCount < 4 || letterCount > 18) { setError('Reč 4-18 slova.'); return }
    if (!hint.trim()) { setError('Hint je obavezan.'); return }
    setBusy(true)
    const { error: e } = await createClient().from('hangman_words').update({
      word: wordTrim, word_length: letterCount, hint: hint.trim(), category, is_active: active,
    }).eq('id', row.id)
    setBusy(false)
    if (e) { setError(e.message); return }
    setSuccess(true); setTimeout(() => setSuccess(false), 2000)
    router.refresh()
  }

  async function deleteRow() {
    if (!confirm('Stvarno obrisati pojam?')) return
    setBusy(true)
    await createClient().from('hangman_words').delete().eq('id', row.id)
    router.push('/majmun/vesanje')
  }

  const guessRate = row.times_used > 0 ? Math.round((row.times_guessed / row.times_used) * 100) : null

  return (
    <div className="max-w-3xl">
      <Link href="/majmun/vesanje" className="inline-flex items-center gap-1.5 text-[13px] font-medium mb-6 transition-opacity hover:opacity-70" style={{ color: '#12907E' }}>
        <IconBack size={16} strokeWidth={2.2} /> Svi pojmovi
      </Link>

      <h1 className="font-black tracking-tight mb-2" style={{ color: '#151515', fontSize: 'clamp(22px, 4vw, 28px)' }}>Izmeni pojam</h1>

      {row.times_used > 0 && (
        <div className="card-soft p-4 mb-5">
          <p className="text-[11px] font-bold uppercase tracking-widest mb-3" style={{ color: '#6F6C66' }}>Statistika</p>
          <div className="grid grid-cols-3 gap-3">
            <div className="rounded-2xl p-3 text-center" style={{ background: '#E7E1D0' }}>
              <div className="font-black text-[18px]" style={{ color: '#151515' }}>{row.times_used}</div>
              <div className="text-[11px]" style={{ color: '#6F6C66' }}>Igara</div>
            </div>
            <div className="rounded-2xl p-3 text-center" style={{ background: '#E7E1D0' }}>
              <div className="font-black text-[18px]" style={{ color: '#12907E' }}>{row.times_guessed}</div>
              <div className="text-[11px]" style={{ color: '#6F6C66' }}>Pogođeno</div>
            </div>
            <div className="rounded-2xl p-3 text-center" style={{ background: '#E7E1D0' }}>
              <div className="font-black text-[18px]" style={{ color: '#12907E' }}>{guessRate}%</div>
              <div className="text-[11px]" style={{ color: '#6F6C66' }}>Uspeh</div>
            </div>
          </div>
        </div>
      )}

      <div className="card-soft p-6 sm:p-8">
        {success && (
          <div className="rounded-2xl px-4 py-3 mb-5 text-[13px] font-medium flex items-center gap-2" style={{ background: '#DFF3EE', color: '#0E6F61' }}>
            <IconCheck size={16} className="text-[#0E6F61]" /> Sačuvano.
          </div>
        )}
        {error && <div className="rounded-2xl px-4 py-3 mb-5 text-[13px] font-medium" style={{ background: '#FFE3EA', color: '#C42B4F' }}>{error}</div>}

        <div className="mb-5">
          <label className="block text-[13px] font-bold mb-2 tracking-tight" style={{ color: '#151515' }}>Reč</label>
          <input value={word} onChange={e => setWord(e.target.value)} className="input uppercase font-bold tracking-wider" />
          <p className="text-[11px] mt-2 font-bold" style={{ color: letterCount < 4 || letterCount > 18 ? '#E5385C' : '#12907E' }}>
            {letterCount} slova
          </p>
        </div>

        <div className="mb-5">
          <label className="block text-[13px] font-bold mb-2 tracking-tight" style={{ color: '#151515' }}>Hint</label>
          <textarea value={hint} onChange={e => setHint(e.target.value)} className="input resize-none" rows={3} maxLength={200} />
          <p className="text-[11px] mt-2 text-right" style={{ color: '#6F6C66' }}>{hint.length}/200</p>
        </div>

        <div className="mb-5">
          <label className="block text-[13px] font-bold mb-2 tracking-tight" style={{ color: '#151515' }}>Kategorija</label>
          <div className="grid grid-cols-3 gap-1.5">
            {CATS.map(c => (
              <button key={c} type="button" onClick={() => setCategory(c)} className="py-2 rounded-xl text-[12px] font-bold transition-all"
                style={category === c ? { background: '#12907E', color: 'white' } : { background: '#E7E1D0', color: '#6F6C66' }}>
                {c}
              </button>
            ))}
          </div>
        </div>

        <label className="flex items-center gap-3 mb-6 cursor-pointer">
          <button type="button" onClick={() => setActive(a => !a)} className="w-5 h-5 rounded-md border-2 flex items-center justify-center flex-shrink-0"
            style={active ? { borderColor: '#12907E', background: '#12907E' } : { borderColor: 'rgba(21,21,21,0.20)', background: 'white' }}>
            {active && <span className="text-white font-black text-[10px]">✓</span>}
          </button>
          <span className="text-[13px] font-medium" style={{ color: '#151515' }}>Aktivno</span>
        </label>

        <div className="flex flex-col sm:flex-row gap-2">
          <button onClick={save} disabled={busy} className="btn btn-primary btn-md flex-1">{busy ? 'Čuvanje…' : 'Sačuvaj'}</button>
          <button onClick={deleteRow} disabled={busy} className="btn btn-md flex-1" style={{ background: '#FFE3EA', color: '#C42B4F' }}>Obriši</button>
        </div>
      </div>
    </div>
  )
}
