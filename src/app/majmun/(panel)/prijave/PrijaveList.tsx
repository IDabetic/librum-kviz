'use client'

import { useState } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'

type Row = {
  id: string
  source: string
  sourceLabel: string
  editPath: string | null
  questionId: string
  questionText: string
  reason: string
  status: string
  createdAt: string
  resolvedAt: string | null
  reporterName: string
}

const STATUS_COLOR: Record<string, { bg: string; fg: string; label: string }> = {
  pending:  { bg: '#F5E6B8', fg: '#8A6A12', label: 'Na čekanju' },
  reviewed: { bg: '#D4D2F5', fg: '#2C2980', label: 'Pregledano' },
  resolved: { bg: '#D4F3E7', fg: '#1F8A62', label: 'Rešeno' },
}

function fmtDate(s: string): string {
  return new Date(s).toLocaleString('sr', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' })
}

export default function PrijaveList({ rows }: { rows: Row[] }) {
  const router = useRouter()
  const [busy, setBusy] = useState<string | null>(null)

  async function setStatus(id: string, status: string) {
    setBusy(id)
    const update: { status: string; resolved_at: string | null } = {
      status,
      resolved_at: status === 'resolved' ? new Date().toISOString() : null,
    }
    await createClient().from('question_reports').update(update).eq('id', id)
    setBusy(null)
    router.refresh()
  }

  async function remove(id: string) {
    if (!confirm('Obriši ovu prijavu?')) return
    setBusy(id)
    await createClient().from('question_reports').delete().eq('id', id)
    setBusy(null)
    router.refresh()
  }

  if (rows.length === 0) {
    return (
      <div className="card-soft py-16 text-center">
        <p className="font-bold text-[16px] mb-2" style={{ color: '#1A1A1E' }}>Nema prijava u ovoj kategoriji</p>
      </div>
    )
  }

  return (
    <div className="card-soft overflow-hidden">
      <div className="divide-y" style={{ borderColor: '#EBE8E1' }}>
        {rows.map(r => {
          const ss = STATUS_COLOR[r.status] || STATUS_COLOR.pending
          return (
            <div key={r.id} className="px-5 py-4">
              <div className="flex items-center gap-2 mb-2 flex-wrap">
                <span className="chip" style={{ background: ss.bg, color: ss.fg }}>{ss.label}</span>
                <span className="chip" style={{ background: '#EBE8E1', color: '#1A1A1E' }}>{r.sourceLabel}</span>
                <span className="text-[11px]" style={{ color: '#6B6760' }}>
                  {r.reporterName} · {fmtDate(r.createdAt)}
                </span>
              </div>

              {r.questionText && (
                <p className="text-[14px] font-semibold leading-snug mb-2" style={{ color: '#1A1A1E' }}>
                  {r.questionText}
                </p>
              )}

              <div className="rounded-2xl px-4 py-3 mb-3 text-[13px]" style={{ background: '#FEE2E2', color: '#b91c1c' }}>
                <span className="font-bold">Razlog:</span> {r.reason}
              </div>

              <div className="flex flex-wrap gap-2">
                {r.editPath && (
                  <Link href={`${r.editPath}/${r.questionId}`} className="btn btn-secondary btn-sm">
                    Otvori pitanje
                  </Link>
                )}
                {r.status !== 'reviewed' && (
                  <button onClick={() => setStatus(r.id, 'reviewed')} disabled={busy === r.id}
                    className="btn btn-sm" style={{ background: '#D4D2F5', color: '#2C2980' }}>
                    Označi „Pregledano“
                  </button>
                )}
                {r.status !== 'resolved' && (
                  <button onClick={() => setStatus(r.id, 'resolved')} disabled={busy === r.id}
                    className="btn btn-sm" style={{ background: '#D4F3E7', color: '#1F8A62' }}>
                    Reši
                  </button>
                )}
                {r.status !== 'pending' && (
                  <button onClick={() => setStatus(r.id, 'pending')} disabled={busy === r.id}
                    className="btn btn-sm" style={{ background: '#F5E6B8', color: '#8A6A12' }}>
                    Vrati na čekanje
                  </button>
                )}
                <button onClick={() => remove(r.id)} disabled={busy === r.id}
                  className="btn btn-sm" style={{ background: '#FEE2E2', color: '#b91c1c' }}>
                  Obriši
                </button>
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}
