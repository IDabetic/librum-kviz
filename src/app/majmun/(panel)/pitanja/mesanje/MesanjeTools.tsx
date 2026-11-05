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
type Pool = 'pro' | 'book' | 'kafana'
type Stats = { total: number; updated: number; failed?: number; candidates_for_update?: number }

export default function MesanjeTools({ pool = 'pro' }: { pool?: Pool }) {
  const router = useRouter()
  const [busy, setBusy] = useState<Mode | null>(null)
  const [result, setResult] = useState<{ mode: Mode; ok: boolean; error?: string; stats?: Stats } | null>(null)

  async function run(mode: Mode, confirmMsg: string) {
    if (busy) return
    if (!confirm(confirmMsg)) return
    setBusy(mode)
    setResult(null)
    try {
      const base = mode === 'order'
        ? '/api/admin/questions-shuffle-order'
        : '/api/admin/questions-shuffle-answers'
      const res = await fetch(`${base}?pool=${pool}`, { method: 'POST' })
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
        <h2 className="font-bold text-[16px] mb-2 tracking-tight" style={{ color: '#151515' }}>
          🔢 Promešaj redosled pitanja
        </h2>
        <p className="text-[13px] mb-4 leading-relaxed" style={{ color: '#6F6C66' }}>
          Svakom pitanju u bazi dodeljuje novi nasumični{' '}
          <code className="font-mono text-[12px] px-1 rounded" style={{ background: '#E7E1D0' }}>order_num</code>.
          Igre već biraju pitanja nasumično za svaku partiju, ali ovo menja redosled u admin listi i u eksportima.
        </p>

        <button
          onClick={() => run('order', 'Promešati redosled SVIH pitanja u bazi? Ovo prepisuje order_num za svaki red.')}
          disabled={busy !== null}
          className="btn btn-md" style={{ background: '#DFF3EE', color: '#0E6F61' }}>
          {busy === 'order' ? 'Mešam redosled…' : '🔢 Promešaj redosled pitanja'}
        </button>

        {result && result.mode === 'order' && <ResultLine result={result} />}
      </section>

      {/* ── 2. Promešaj redosled tačnog odgovora ───────────── */}
      <section className="card-soft p-6">
        <h2 className="font-bold text-[16px] mb-2 tracking-tight" style={{ color: '#151515' }}>
          🅰 Promešaj redosled tačnog odgovora u pitanjima
        </h2>
        <p className="text-[13px] mb-4 leading-relaxed" style={{ color: '#6F6C66' }}>
          Za svako pitanje nasumično razmesti pozicije sva 4 odgovora i ažurira{' '}
          <code className="font-mono text-[12px] px-1 rounded" style={{ background: '#E7E1D0' }}>correct_answer</code>{' '}
          indeks. Ako neko zapamti da je „pod A” tačan odgovor za pitanje X, posle ovoga to neće biti tako u bazi.
        </p>

        <button
          onClick={() => run('answers', 'Promešati redosled odgovora u SVIM pitanjima? Pozicija tačnog odgovora se nasumično menja u bazi.')}
          disabled={busy !== null}
          className="btn btn-md" style={{ background: '#FFD84D', color: '#151515' }}>
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
        style={{ background: '#FFE3EA', color: '#C42B4F' }}>
        ✗ Greška: {result.error || 'nepoznata'}
      </div>
    )
  }
  const s = result.stats
  return (
    <div className="mt-4 rounded-2xl px-4 py-3 text-[13px]"
      style={{ background: '#DFF3EE', color: '#0E6F61' }}>
      ✓ Promešano <strong>{s?.updated ?? 0}</strong> od {s?.total ?? 0} pitanja.
      {s?.failed && s.failed > 0 ? ` ${s.failed} neuspelih.` : ''}
    </div>
  )
}
