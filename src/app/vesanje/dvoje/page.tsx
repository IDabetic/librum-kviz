'use client'

export const dynamic = 'force-dynamic'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import Header from '@/components/Header'
import { IconBack, IconUsers, IconHint } from '@/components/icons'

const CATEGORIES = ['Sport', 'Geografija', 'Istorija', 'Kultura', 'Priroda', 'Predmeti', 'Drugo']

export default function VesanjeDvojePage() {
  const router = useRouter()
  const [step, setStep] = useState<'enter' | 'handoff'>('enter')
  const [category, setCategory] = useState('Drugo')
  const [word, setWord] = useState('')
  const [hint, setHint] = useState('')
  const [error, setError] = useState('')

  const wordTrim = word.trim()
  const hintTrim = hint.trim()
  const letterCount = wordTrim.replace(/[^\p{L}]/gu, '').length

  function next() {
    setError('')
    if (letterCount < 4) { setError('Reč mora imati najmanje 4 slova.'); return }
    if (letterCount > 18) { setError('Maksimum 18 slova.'); return }
    if (hintTrim.length === 0) { setError('Hint je obavezan.'); return }
    if (hintTrim.length > 200) { setError('Hint može da ima najviše 200 karaktera.'); return }
    sessionStorage.setItem('vesanje-custom', JSON.stringify({
      word: wordTrim,
      hint: hintTrim,
      category,
    }))
    setStep('handoff')
  }

  if (step === 'handoff') {
    return (
      <div className="min-h-screen flex items-center justify-center px-4" style={{ background: '#FAFAFA' }}>
        <div className="card-soft p-8 max-w-sm text-center">
          <div className="w-14 h-14 rounded-2xl flex items-center justify-center mx-auto mb-5" style={{ background: '#FFCB46' }}>
            <IconUsers size={28} className="text-[#343434]" strokeWidth={2.2} />
          </div>
          <h1 className="font-black text-[24px] mb-2 tracking-tight" style={{ color: '#343434' }}>
            Predaj telefon Igraču 2
          </h1>
          <p className="text-[14px] mb-7" style={{ color: '#9C9C9C' }}>
            Reč je sakrivena. Igrač 2 može da krene sa pogađanjem.
          </p>
          <button onClick={() => router.push('/vesanje/start?mode=custom')}
            className="btn btn-primary btn-lg w-full">
            Spreman/na sam — kreni
          </button>
          <button onClick={() => setStep('enter')}
            className="block w-full mt-4 text-[13px] font-medium transition-opacity hover:opacity-70"
            style={{ color: '#9C9C9C' }}>
            ← Promeni reč
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen" style={{ background: '#FAFAFA' }}>
      <Header />
      <main className="max-w-xl mx-auto px-4 sm:px-6 py-10 sm:py-14">

        <Link href="/vesanje"
          className="inline-flex items-center gap-1.5 text-[13px] font-medium mb-6 transition-opacity hover:opacity-70"
          style={{ color: '#609DED' }}>
          <IconBack size={16} strokeWidth={2.2} />
          Nazad
        </Link>

        <div className="text-center mb-8">
          <p className="text-[13px] font-bold uppercase tracking-widest mb-2" style={{ color: '#609DED' }}>
            Igra za dvoje
          </p>
          <h1 className="font-black tracking-tight leading-[1.1] mb-3"
            style={{ color: '#343434', fontSize: 'clamp(28px, 5vw, 40px)' }}>
            Smisli reč
          </h1>
          <p className="text-[14px]" style={{ color: '#9C9C9C' }}>
            Dodaj reč i hint, predaj telefon igraču 2, on pogađa.
          </p>
        </div>

        <div className="card-soft p-6 sm:p-7">
          <div className="mb-4">
            <label className="block text-[13px] font-bold mb-2 tracking-tight" style={{ color: '#343434' }}>
              Kategorija
            </label>
            <div className="grid grid-cols-3 sm:grid-cols-4 gap-1.5">
              {CATEGORIES.map(c => (
                <button key={c} onClick={() => setCategory(c)}
                  className="py-2 rounded-xl text-[12px] font-bold transition-all"
                  style={category === c
                    ? { background: '#609DED', color: 'white' }
                    : { background: '#F2F2F2', color: '#9C9C9C' }}>
                  {c}
                </button>
              ))}
            </div>
          </div>

          <div className="mb-4">
            <label className="block text-[13px] font-bold mb-2 tracking-tight" style={{ color: '#343434' }}>
              Reč
            </label>
            <input value={word} onChange={e => setWord(e.target.value)}
              className="input uppercase font-bold tracking-wider"
              placeholder="Tačna reč…"
              maxLength={30}
              autoFocus />
            <div className="flex items-center justify-between mt-2">
              <p className="text-[11px]" style={{ color: '#9C9C9C' }}>
                Samo na srpskom · 4-18 slova
              </p>
              <p className="text-[11px] font-bold" style={{ color: letterCount < 4 || letterCount > 18 ? '#E55353' : '#4CAF50' }}>
                {letterCount} {letterCount === 1 ? 'slovo' : 'slova'}
              </p>
            </div>
          </div>

          <div className="mb-4">
            <label className="block text-[13px] font-bold mb-2 tracking-tight" style={{ color: '#343434' }}>
              <IconHint size={14} className="inline mr-1 text-[#FFCB46]" strokeWidth={2.2} />
              Hint
            </label>
            <textarea value={hint} onChange={e => setHint(e.target.value)}
              className="input resize-none"
              rows={3}
              placeholder="Opisni nagoveštaj — bez direktnog otkrivanja reči."
              maxLength={200} />
            <div className="flex items-center justify-between mt-2">
              <p className="text-[11px]" style={{ color: '#9C9C9C' }}>
                Pomaže, ali ne otkriva direktno
              </p>
              <p className="text-[11px] font-bold" style={{ color: hintTrim.length > 200 ? '#E55353' : '#9C9C9C' }}>
                {hintTrim.length}/200
              </p>
            </div>
          </div>

          {error && (
            <div className="rounded-2xl px-4 py-3 text-[13px] font-medium mb-4" style={{ background: '#FEE2E2', color: '#b91c1c' }}>
              {error}
            </div>
          )}

          <button onClick={next} className="btn btn-primary btn-lg w-full">
            Dalje
          </button>
        </div>
      </main>
    </div>
  )
}
