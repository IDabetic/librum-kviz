'use client'

import { useState } from 'react'

type Result = { ok: boolean; total?: number; inserted?: number; skipped?: number; failed?: number; error?: string }

export default function SyncBookCard() {
  const [busy, setBusy] = useState(false)
  const [result, setResult] = useState<Result | null>(null)

  async function run() {
    setBusy(true)
    setResult(null)
    try {
      const res = await fetch('/api/admin/sync-book-to-questions', { method: 'POST' })
      const json = (await res.json()) as Result
      setResult(json)
    } catch {
      setResult({ ok: false, error: 'Greška u mreži.' })
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="card-soft p-6">
      <div className="flex items-center gap-3 mb-2">
        <div className="w-10 h-10 rounded-2xl flex items-center justify-center" style={{ background: '#FFECBC' }}>
          <span className="text-[18px]">📚</span>
        </div>
        <div>
          <p className="font-bold text-[14px]" style={{ color: '#343434' }}>Književnost u PRO pool</p>
          <p className="text-[12px]" style={{ color: '#9C9C9C' }}>
            Kopiraj sva aktivna pitanja iz Book kviza u PRO pool. Idempotentno — duplikati po tekstu se preskaču.
          </p>
        </div>
      </div>

      <button
        onClick={run}
        disabled={busy}
        className="btn btn-primary btn-md w-full mt-3"
        style={busy ? { opacity: 0.7, cursor: 'not-allowed' } : undefined}>
        {busy ? 'Sinhronizujem…' : 'Pokreni sinhronizaciju'}
      </button>

      {result && (
        <div className="mt-3 rounded-2xl px-4 py-3 text-[13px]"
          style={result.ok
            ? { background: '#E8F8F0', color: '#15803d' }
            : { background: '#FEE2E2', color: '#b91c1c' }}>
          {result.ok ? (
            <>
              <strong>Gotovo.</strong>
              {' '}Pregledano {result.total ?? 0}, upisano <strong>{result.inserted ?? 0}</strong>,
              preskočeno (već postoji) {result.skipped ?? 0}
              {(result.failed ?? 0) > 0 && <>, nije uspelo {result.failed}</>}.
            </>
          ) : (
            <>
              <strong>Greška:</strong> {result.error || 'nepoznata'}
            </>
          )}
        </div>
      )}
    </div>
  )
}
