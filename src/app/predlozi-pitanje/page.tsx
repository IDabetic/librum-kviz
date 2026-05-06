'use client'

import { useState } from 'react'
import Header from '@/components/Header'
import Link from 'next/link'
import { IconBack, IconHint, IconCheck } from '@/components/icons'

export default function PredloziPitanjePage() {
  const [question, setQuestion] = useState('')
  const [answer, setAnswer] = useState('')
  const [sending, setSending] = useState(false)
  const [done, setDone] = useState(false)
  const [error, setError] = useState('')

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!question.trim() || !answer.trim()) return
    setSending(true)
    setError('')

    try {
      const res = await fetch('/api/predlozi-pitanje', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ question: question.trim(), answer: answer.trim() }),
      })
      if (!res.ok) throw new Error('Greška')
      setDone(true)
    } catch {
      setError('Nešto nije u redu. Pokušaj ponovo.')
    } finally {
      setSending(false)
    }
  }

  return (
    <div className="min-h-screen" style={{ background: '#FAFAFA' }}>
      <Header />

      <main className="max-w-2xl mx-auto px-4 sm:px-6 py-10 sm:py-14">
        <Link href="/kvizovi"
          className="inline-flex items-center gap-1.5 text-[13px] font-medium mb-6 transition-opacity hover:opacity-70"
          style={{ color: '#609DED' }}>
          <IconBack size={16} strokeWidth={2.2} />
          Kvizovi
        </Link>

        <div className="text-center mb-10">
          <div className="w-14 h-14 rounded-2xl flex items-center justify-center mx-auto mb-5"
            style={{ background: '#FFECBC' }}>
            <IconHint size={26} className="text-[#9c7a13]" strokeWidth={2.2} />
          </div>
          <h1 className="font-black tracking-tight mb-2 leading-[1.1]" style={{ color: '#343434', fontSize: 'clamp(28px, 5vw, 40px)' }}>
            Predloži pitanje
          </h1>
          <p className="text-[14px] sm:text-[15px]" style={{ color: '#9C9C9C' }}>
            Imaš dobro pitanje? Pošalji nam ga i možda se nađe u kvizu.
          </p>
        </div>

        {done ? (
          <div className="card-soft p-10 text-center">
            <div className="w-14 h-14 rounded-2xl flex items-center justify-center mx-auto mb-5" style={{ background: '#E8F8F0' }}>
              <IconCheck size={32} className="text-[#4CAF50]" />
            </div>
            <h2 className="font-black tracking-tight mb-2" style={{ color: '#343434', fontSize: '24px' }}>Hvala!</h2>
            <p className="text-[14px] mb-7" style={{ color: '#9C9C9C' }}>
              Tvoje pitanje je uspešno poslato. Pregledaćemo ga i dodati u kviz.
            </p>
            <div className="flex gap-3 justify-center flex-wrap">
              <button
                onClick={() => { setDone(false); setQuestion(''); setAnswer('') }}
                className="btn btn-secondary btn-md">
                Pošalji još jedno
              </button>
              <Link href="/kvizovi" className="btn btn-primary btn-md">
                Na kvizove
              </Link>
            </div>
          </div>
        ) : (
          <div className="card-soft p-7 sm:p-8">
            <form onSubmit={handleSubmit} className="flex flex-col gap-5">
              <div>
                <label className="block text-[13px] font-bold mb-2 tracking-tight" style={{ color: '#343434' }}>
                  Pitanje
                </label>
                <textarea
                  value={question}
                  onChange={e => setQuestion(e.target.value)}
                  placeholder="Upiši svoje pitanje ovde…"
                  rows={4}
                  required
                  className="input resize-none"
                />
              </div>

              <div>
                <label className="block text-[13px] font-bold mb-2 tracking-tight" style={{ color: '#343434' }}>
                  Tačan odgovor
                </label>
                <textarea
                  value={answer}
                  onChange={e => setAnswer(e.target.value)}
                  placeholder="Koji je tačan odgovor?"
                  rows={2}
                  required
                  className="input resize-none"
                />
              </div>

              {error && (
                <div className="rounded-2xl px-4 py-3 text-[13px] font-medium" style={{ background: '#FEE2E2', color: '#b91c1c' }}>
                  {error}
                </div>
              )}

              <button type="submit" disabled={sending || !question.trim() || !answer.trim()}
                className="btn btn-primary btn-lg w-full">
                {sending ? 'Šaljemo…' : 'Pošalji pitanje'}
              </button>

              <p className="text-[11px] text-center" style={{ color: '#9C9C9C' }}>
                Sva predložena pitanja prolaze kroz uredničku proveru pre objavljivanja.
              </p>
            </form>
          </div>
        )}
      </main>
    </div>
  )
}
