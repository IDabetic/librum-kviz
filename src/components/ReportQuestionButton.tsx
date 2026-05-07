'use client'

import { useState } from 'react'

// Tiny "🚩 Prijavi" button that opens a modal where the player describes
// what's wrong with the current question. POSTs to /api/report-question
// which writes to public.question_reports for admins to review.
//
// Drop into any in-game HUD with the current question id + the table
// it came from. We pass the question_text snapshot too so admins can
// review the report even after the source row gets edited or deleted.

type Source = 'questions' | 'book_questions' | 'kafana_questions' | 'hangman_words'

export default function ReportQuestionButton({
  source, questionId, questionText, accent = '#9C9C9C',
}: {
  source: Source
  questionId: string
  questionText: string
  accent?: string
}) {
  const [open, setOpen] = useState(false)
  const [reason, setReason] = useState('')
  const [busy, setBusy] = useState(false)
  const [done, setDone] = useState(false)
  const [error, setError] = useState('')

  function reset() {
    setReason('')
    setBusy(false)
    setDone(false)
    setError('')
  }

  async function submit() {
    setBusy(true)
    setError('')
    try {
      const res = await fetch('/api/report-question', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ source, question_id: questionId, question_text: questionText, reason }),
      })
      const json = await res.json()
      if (!res.ok || !json.ok) {
        setError(json.error === 'reason-required' ? 'Napiši kratko objašnjenje.' : 'Slanje nije uspelo.')
        setBusy(false)
        return
      }
      setDone(true)
      setBusy(false)
      setTimeout(() => { setOpen(false); reset() }, 1600)
    } catch {
      setError('Slanje nije uspelo.')
      setBusy(false)
    }
  }

  return (
    <>
      <button
        type="button"
        onClick={() => { reset(); setOpen(true) }}
        className="inline-flex items-center gap-1 px-2 py-1 rounded-full text-[11px] font-medium transition-opacity hover:opacity-100"
        style={{ color: accent, opacity: 0.7 }}
        title="Prijavi grešku u pitanju"
      >
        <span aria-hidden>🚩</span>
        <span>Prijavi pitanje</span>
      </button>

      {open && (
        <div className="fixed inset-0 z-[60] flex items-center justify-center px-4 backdrop-blur-sm"
          style={{ background: 'rgba(52,52,52,0.40)' }}
          onClick={() => !busy && setOpen(false)}>
          <div className="card-soft p-6 max-w-md w-full" onClick={e => e.stopPropagation()}>
            <h3 className="font-black text-[18px] tracking-tight mb-1" style={{ color: '#343434' }}>
              Prijavi pitanje
            </h3>
            <p className="text-[12px] mb-4" style={{ color: '#9C9C9C' }}>
              Šta nije u redu? (npr. netačan odgovor, nejasna formulacija, kucanje…)
            </p>

            <div className="rounded-2xl p-3 mb-3 text-[12px]" style={{ background: '#F2F2F2', color: '#343434' }}>
              {questionText}
            </div>

            <textarea
              value={reason}
              onChange={e => setReason(e.target.value)}
              placeholder="Tačan odgovor je drugačiji, treba glasiti…"
              rows={4}
              maxLength={1000}
              disabled={busy || done}
              className="input w-full mb-3"
            />

            {error && (
              <p className="text-[12px] font-medium mb-3" style={{ color: '#b91c1c' }}>{error}</p>
            )}
            {done && (
              <div className="rounded-2xl px-4 py-3 mb-3 text-[13px] font-medium text-center"
                style={{ background: '#E8F8F0', color: '#15803d' }}>
                Hvala — admin će pogledati.
              </div>
            )}

            <div className="flex gap-2">
              <button onClick={() => setOpen(false)} disabled={busy}
                className="btn btn-secondary btn-md flex-1">
                Otkaži
              </button>
              <button onClick={submit} disabled={busy || done || reason.trim().length < 3}
                className="btn btn-primary btn-md flex-1">
                {busy ? 'Šaljem…' : done ? '✓ Poslato' : 'Pošalji'}
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  )
}
