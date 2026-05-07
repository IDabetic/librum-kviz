'use client'

import { useState } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { IconBack, IconCheck } from '@/components/icons'

const CATS = ['Sport', 'Geografija', 'Istorija', 'Kultura', 'Priroda', 'Predmeti']

export default function NoviPojamPage() {
  const router = useRouter()
  const [word, setWord] = useState('')
  const [hint, setHint] = useState('')
  const [category, setCategory] = useState('Geografija')
  const [active, setActive] = useState(true)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState(false)

  const wordTrim = word.trim().toLowerCase()
  const letterCount = wordTrim.replace(/[^\p{L}]/gu, '').length

  function reset() { setWord(''); setHint(''); setActive(true) }

  async function save(addAnother: boolean) {
    setError('')
    if (letterCount < 4) { setError('Reč mora imati najmanje 4 slova.'); return }
    if (letterCount > 18) { setError('Maksimum 18 slova.'); return }
    if (!hint.trim()) { setError('Hint je obavezan.'); return }
    if (hint.length > 200) { setError('Hint do 200 karaktera.'); return }
    if (hint.toLowerCase().includes(wordTrim)) {
      setError('Hint ne sme da sadrži tačnu reč.'); return
    }
    setBusy(true)
    const { data: { user } } = await createClient().auth.getUser()
    const { error: e } = await createClient().from('hangman_words').insert({
      word: wordTrim,
      word_length: letterCount,
      hint: hint.trim(),
      category,
      is_active: active,
      created_by: user?.id ?? null,
    })
    setBusy(false)
    if (e) {
      if (e.code === '23505') setError('Reč već postoji u bazi.')
      else setError(e.message)
      return
    }
    setSuccess(true); setTimeout(() => setSuccess(false), 2000)
    if (addAnother) reset(); else router.push('/majmun/vesanje')
  }

  return (
    <div className="max-w-3xl">
      <Link href="/majmun/vesanje" className="inline-flex items-center gap-1.5 text-[13px] font-medium mb-6 transition-opacity hover:opacity-70" style={{ color: '#609DED' }}>
        <IconBack size={16} strokeWidth={2.2} /> Svi pojmovi
      </Link>

      <h1 className="font-black tracking-tight mb-6" style={{ color: '#343434', fontSize: 'clamp(22px, 4vw, 28px)' }}>Novi pojam</h1>

      <div className="card-soft p-6 sm:p-8">
        {success && (
          <div className="rounded-2xl px-4 py-3 mb-5 text-[13px] font-medium flex items-center gap-2" style={{ background: '#E8F8F0', color: '#15803d' }}>
            <IconCheck size={16} className="text-[#15803d]" /> Sačuvano.
          </div>
        )}
        {error && <div className="rounded-2xl px-4 py-3 mb-5 text-[13px] font-medium" style={{ background: '#FEE2E2', color: '#b91c1c' }}>{error}</div>}

        <div className="mb-5">
          <label className="block text-[13px] font-bold mb-2 tracking-tight" style={{ color: '#343434' }}>Reč *</label>
          <input value={word} onChange={e => setWord(e.target.value)} className="input uppercase font-bold tracking-wider" maxLength={30} />
          <div className="flex justify-between mt-2">
            <p className="text-[11px]" style={{ color: '#9C9C9C' }}>4-18 slova · srpska latinica</p>
            <p className="text-[11px] font-bold" style={{ color: letterCount < 4 || letterCount > 18 ? '#E55353' : '#4CAF50' }}>
              {letterCount} {letterCount === 1 ? 'slovo' : 'slova'}
            </p>
          </div>
        </div>

        <div className="mb-5">
          <label className="block text-[13px] font-bold mb-2 tracking-tight" style={{ color: '#343434' }}>Hint *</label>
          <textarea value={hint} onChange={e => setHint(e.target.value)} className="input resize-none" rows={3} maxLength={200}
            placeholder="Opisni nagoveštaj — bez direktnog otkrivanja reči." />
          <div className="flex justify-between mt-2">
            <p className="text-[11px]" style={{ color: '#9C9C9C' }}>Pomaže ali ne otkriva</p>
            <p className="text-[11px] font-bold" style={{ color: '#9C9C9C' }}>{hint.length}/200</p>
          </div>
        </div>

        <div className="mb-5">
          <label className="block text-[13px] font-bold mb-2 tracking-tight" style={{ color: '#343434' }}>Kategorija</label>
          <div className="grid grid-cols-3 gap-1.5">
            {CATS.map(c => (
              <button key={c} type="button" onClick={() => setCategory(c)}
                className="py-2 rounded-xl text-[12px] font-bold transition-all"
                style={category === c ? { background: '#609DED', color: 'white' } : { background: '#F2F2F2', color: '#9C9C9C' }}>
                {c}
              </button>
            ))}
          </div>
        </div>

        <label className="flex items-center gap-3 mb-6 cursor-pointer">
          <button type="button" onClick={() => setActive(a => !a)} className="w-5 h-5 rounded-md border-2 flex items-center justify-center flex-shrink-0"
            style={active ? { borderColor: '#4CAF50', background: '#4CAF50' } : { borderColor: 'rgba(52,52,52,0.20)', background: 'white' }}>
            {active && <span className="text-white font-black text-[10px]">✓</span>}
          </button>
          <span className="text-[13px] font-medium" style={{ color: '#343434' }}>Aktivno</span>
        </label>

        <div className="flex flex-col sm:flex-row gap-2">
          <button onClick={() => save(false)} disabled={busy} className="btn btn-primary btn-md flex-1">{busy ? 'Čuvanje…' : 'Sačuvaj'}</button>
          <button onClick={() => save(true)} disabled={busy} className="btn btn-secondary btn-md flex-1">Sačuvaj i dodaj novi</button>
        </div>
      </div>
    </div>
  )
}
