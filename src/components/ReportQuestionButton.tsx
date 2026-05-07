'use client'

import { useState } from 'react'

// One-click "🚩 Prijavi pitanje" — POSTs immediately, shows a brief
// confirmation, then resets so the player can keep going. Admins do
// the actual review in /majmun/prijave (no need for the player to
// type a reason — they're mid-game and we trust the click).

type Source = 'questions' | 'book_questions' | 'kafana_questions' | 'hangman_words'

export default function ReportQuestionButton({
  source, questionId, questionText, accent = '#9C9C9C',
}: {
  source: Source
  questionId: string
  questionText: string
  accent?: string
}) {
  const [busy, setBusy] = useState(false)
  const [done, setDone] = useState(false)
  const [error, setError] = useState('')

  async function submit() {
    if (busy || done) return
    setBusy(true)
    setError('')
    try {
      const res = await fetch('/api/report-question', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          source,
          question_id: questionId,
          question_text: questionText,
          // No comment from the player — we send a sentinel so admins
          // can tell at a glance these are "blind" reports.
          reason: 'Prijavljeno tokom igre',
        }),
      })
      const json = await res.json()
      if (!res.ok || !json.ok) {
        setError(json.error === 'unauth' ? 'Prijava traži ulogovanog igrača.' : 'Slanje nije uspelo.')
        setBusy(false)
        return
      }
      setDone(true)
      setBusy(false)
      // Reset after a moment so the same player could report again on
      // a different question without a full page reload.
      setTimeout(() => { setDone(false); setError('') }, 2200)
    } catch {
      setError('Slanje nije uspelo.')
      setBusy(false)
    }
  }

  return (
    <button
      type="button"
      onClick={submit}
      disabled={busy || done}
      className="inline-flex items-center gap-1 px-2 py-1 rounded-full text-[11px] font-medium transition-opacity hover:opacity-100"
      style={{
        color: done ? '#15803d' : (error ? '#b91c1c' : accent),
        opacity: done || error ? 1 : 0.7,
      }}
      title={done ? 'Hvala — admin će pogledati' : error || 'Prijavi grešku u pitanju'}
    >
      <span aria-hidden>{done ? '✓' : error ? '⚠' : '🚩'}</span>
      <span>{busy ? 'Šaljem…' : done ? 'Prijavljeno' : error ? 'Greška' : 'Prijavi pitanje'}</span>
    </button>
  )
}
