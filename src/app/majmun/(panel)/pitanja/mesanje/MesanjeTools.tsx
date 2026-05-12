'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'

// Two independent shuffle operations on the questions pool:
//   1) `order` — randomize `order_num`. Doesn't change gameplay (each
//      match already picks questions in random order via Fisher–Yates
//      in the game pages), but admin lists / exports sorted by
//      `order_num` are now in a fresh order.
//   2) `answers` — randomize the A/B/C/D position of the correct
//      answer inside each row. Belt-and-suspenders over the
//      per-render shuffle the games already do.

type Mode = 'order' | 'answers'
type Stats = { total: number; updated: number; failed?: number; candidates_for_update?: number }

export default function MesanjeTools() {
  const router = useRouter()
  const [busy, setBusy] = useState<Mode | null>(null)
  const [result, setResult] = useState<{ mode: Mode; ok: boolean; error?: string; stats?: Stats } | null>(null)

  async function run(mode: Mode, confirmMsg: string) {
    if (busy) return
    if (!confirm(confirmMsg)) return
    setBusy(mode)
    setResult(null)
    try {
      const url = mode === 'order'
        ? '/api/admin/questions-shuffle-order'
        : '/api/admin/questions-shuffle-answers'
      const res = await fetch(url, { method: 'POST' })
      const json = await res.json()
      setResult({ mode, ok: json.ok, error: json.error, stats: json.stats })
      if (json.ok) router.refresh()
    } catch {
      setResult({ mode, ok: false, error: 'network' })
    } finally {
      setBusy(null)
    }
  }

  return (
    <div className="space-y-4">

      {/* ── 1. Promešaj redosled pitanja ─────────────────────── */}
      <section className="card-soft p-6">
        <h2 className="font-bold text-[16px] mb-2 tracking-tight" style={{ color: '#343434' }}>
          🔢 Promešaj redosled pitanja
        </h2>
        <p className="text-[13px] mb-4 leading-relaxed" style={{ color: '#9C9C9C' }}>
          Svakom pitanju u bazi dodeljuje novi nasumični{' '}
          <code className="font-mono text-[12px] px-1 rounded" style={{ background: '#F2F2F2' }}>order_num</code>.
          Igre već biraju pitanja nasumično za svaku partiju, ali ovo menja redosled u admin listi i u eksportima.
        </p>

        <button
          onClick={() => run('order', 'Promešati redosled SVIH pitanja u bazi? Ovo prepisuje order_num za svaki red.')}
          disabled={busy !== null}
          className="btn btn-md" style={{ background: '#BCD9FF', color: '#1e5fa4' }}>
          {busy === 'order' ? 'Mešam redosled…' : '🔢 Promešaj redosled pitanja'}
        </button>

        {result && result.mode === 'order' && <ResultLine result={result} />}
      </section>

      {/* ── 2. Promešaj redosled tačnog odgovora ───────────── */}
      <section className="card-soft p-6">
        <h2 className="font-bold text-[16px] mb-2 tracking-tight" style={{ color: '#343434' }}>
          🅰 Promešaj redosled tačnog odgovora u pitanjima
        </h2>
        <p className="text-[13px] mb-4 leading-relaxed" style={{ color: '#9C9C9C' }}>
          Za svako pitanje nasumično razmesti pozicije sva 4 odgovora i ažurira{' '}
          <code className="font-mono text-[12px] px-1 rounded" style={{ background: '#F2F2F2' }}>correct_answer</code>{' '}
          indeks. Ako neko zapamti da je „pod A” tačan odgovor za pitanje X, posle ovoga to neće biti tako u bazi.
        </p>

        <button
          onClick={() => run('answers', 'Promešati redosled odgovora u SVIM pitanjima? Pozicija tačnog odgovora se nasumično menja u bazi.')}
          disabled={busy !== null}
          className="btn btn-md" style={{ background: '#FFCB46', color: '#343434' }}>
          {busy === 'answers' ? 'Mešam odgovore… (može potrajati do 30s)' : '🅰 Promešaj redosled odgovora'}
        </button>

        {result && result.mode === 'answers' && <ResultLine result={result} />}
      </section>
    </div>
  )
}

function ResultLine({ result }: { result: { ok: boolean; error?: string; stats?: Stats } }) {
  if (!result.ok) {
    return (
      <div className="mt-4 rounded-2xl px-4 py-3 text-[13px]"
        style={{ background: '#FEE2E2', color: '#b91c1c' }}>
        ✗ Greška: {result.error || 'nepoznata'}
      </div>
    )
  }
  const s = result.stats
  return (
    <div className="mt-4 rounded-2xl px-4 py-3 text-[13px]"
      style={{ background: '#E8F8F0', color: '#15803d' }}>
      ✓ Promešano <strong>{s?.updated ?? 0}</strong> od {s?.total ?? 0} pitanja.
      {s?.failed && s.failed > 0 ? ` ${s.failed} neuspelih.` : ''}
    </div>
  )
}
