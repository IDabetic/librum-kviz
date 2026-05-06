'use client'

import { useState } from 'react'
import Header from '@/components/Header'
import Link from 'next/link'

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
    <div className="min-h-screen bg-[#FAF4EC]">
      <Header />

      <main className="max-w-2xl mx-auto px-4 py-10">
        <div className="mb-8">
          <Link href="/kvizovi" className="text-sm text-gray-400 hover:text-[#2C2D81] transition-colors">
            ← Nazad na kvizove
          </Link>
        </div>

        <div className="text-center mb-10">
          <div className="text-5xl mb-4">💡</div>
          <h1 className="text-3xl font-bold mb-2" style={{ color: '#2C2D81' }}>Predloži pitanje</h1>
          <p className="text-gray-500">Imaš dobro pitanje? Pošalji nam ga i možda se nađe u kvizu!</p>
        </div>

        {done ? (
          <div className="bg-white rounded-3xl shadow-sm p-10 text-center">
            <div className="text-6xl mb-4">🎉</div>
            <h2 className="text-2xl font-bold text-gray-800 mb-2">Hvala!</h2>
            <p className="text-gray-500 mb-6">Tvoje pitanje je uspešno poslato. Pregledaćemo ga i dodati u kviz.</p>
            <div className="flex gap-3 justify-center">
              <button
                onClick={() => { setDone(false); setQuestion(''); setAnswer('') }}
                className="px-6 py-3 rounded-xl border border-gray-200 font-semibold text-gray-600 hover:bg-gray-50 transition-colors"
              >
                Pošalji još jedno
              </button>
              <Link
                href="/kvizovi"
                className="px-6 py-3 rounded-xl font-semibold text-white transition-colors"
                style={{ background: '#2C2D81' }}
              >
                Na kvizove
              </Link>
            </div>
          </div>
        ) : (
          <div className="bg-white rounded-3xl shadow-sm overflow-hidden">
            <div className="h-1.5" style={{ background: 'linear-gradient(90deg, #2C2D81, #5DBF94)' }} />
            <form onSubmit={handleSubmit} className="p-8 flex flex-col gap-6">
              <div>
                <label className="block text-sm font-semibold text-gray-700 mb-2">
                  Pitanje *
                </label>
                <textarea
                  value={question}
                  onChange={e => setQuestion(e.target.value)}
                  placeholder="Upiši svoje pitanje ovde..."
                  rows={4}
                  required
                  className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:border-[#2C2D81] focus:ring-2 focus:ring-[#2C2D81]/10 outline-none transition text-gray-800 resize-none text-sm"
                />
              </div>

              <div>
                <label className="block text-sm font-semibold text-gray-700 mb-2">
                  Tačan odgovor *
                </label>
                <textarea
                  value={answer}
                  onChange={e => setAnswer(e.target.value)}
                  placeholder="Koji je tačan odgovor?"
                  rows={2}
                  required
                  className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:border-[#2C2D81] focus:ring-2 focus:ring-[#2C2D81]/10 outline-none transition text-gray-800 resize-none text-sm"
                />
              </div>

              {error && (
                <div className="bg-red-50 text-red-600 rounded-xl px-4 py-3 text-sm">
                  {error}
                </div>
              )}

              <button
                type="submit"
                disabled={sending || !question.trim() || !answer.trim()}
                className="w-full py-4 rounded-xl font-bold text-white text-base transition-all disabled:opacity-50 disabled:cursor-not-allowed hover:opacity-90 active:scale-[0.98]"
                style={{ background: 'linear-gradient(135deg, #2C2D81, #3766B0)' }}
              >
                {sending ? 'Šaljemo...' : 'Pošalji pitanje'}
              </button>

              <p className="text-xs text-gray-400 text-center">
                Sva predložena pitanja prolaze kroz uredničku proveru pre objavljivanja.
              </p>
            </form>
          </div>
        )}
      </main>
    </div>
  )
}
