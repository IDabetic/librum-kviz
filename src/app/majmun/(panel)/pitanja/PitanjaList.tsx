'use client'

import Link from 'next/link'
import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'

export type Row = {
  id: string
  question_text: string
  options: string[]
  correct_answer: number
  difficulty: string
  is_active: boolean
  times_shown: number
  times_correct: number
  created_at: string
  log_count: number
  avg_time_ms: number | null
  accuracy_pct: number | null
  flags: ('prelako' | 'preteško' | 'sporo' | 'problematično')[]
}

const DIFF_LABEL: Record<string, string> = {
  easy: 'Lako', medium: 'Srednje', hard: 'Teško', impossible: 'Nemoguće',
}
const DIFF_COLOR: Record<string, { bg: string; fg: string }> = {
  easy:       { bg: '#D4F3E7', fg: '#1F8A62' },
  medium:     { bg: '#D4D2F5', fg: '#2C2980' },
  hard:       { bg: '#F5E6B8', fg: '#8A6A12' },
  impossible: { bg: '#FEE2E2', fg: '#b91c1c' },
}
const FLAG_STYLE: Record<string, { label: string; bg: string; fg: string }> = {
  'prelako':       { label: '⚠ Prelako',     bg: '#F5E6B8', fg: '#8A6A12' },
  'preteško':      { label: '⚠ Preteško',    bg: '#FEE2E2', fg: '#b91c1c' },
  'sporo':         { label: '⏱ Sporo',       bg: '#D4D2F5', fg: '#2C2980' },
  'problematično': { label: '🚩 Problemat.', bg: '#FEE2E2', fg: '#b91c1c' },
}

export default function PitanjaList({ rows }: { rows: Row[] }) {
  const router = useRouter()
  const [busy, setBusy] = useState<string | null>(null)

  async function toggleActive(id: string, currentActive: boolean) {
    setBusy(id)
    const supabase = createClient()
    await supabase.from('questions').update({ is_active: !currentActive }).eq('id', id)
    setBusy(null)
    router.refresh()
  }

  if (rows.length === 0) {
    return (
      <div className="card-soft py-16 text-center">
        <p className="font-bold text-[16px] mb-2" style={{ color: '#1A1A1E' }}>Nema rezultata</p>
        <p className="text-[13px]" style={{ color: '#6B6760' }}>Pokušaj sa drugim filterima.</p>
      </div>
    )
  }

  return (
    <div className="card-soft overflow-hidden">
      <div className="divide-y" style={{ borderColor: '#EBE8E1' }}>
        {rows.map(r => {
          const diffStyle = DIFF_COLOR[r.difficulty] || { bg: '#EBE8E1', fg: '#6B6760' }
          const avgSec = r.avg_time_ms != null ? (r.avg_time_ms / 1000).toFixed(1) : null
          return (
            <div key={r.id} className="px-5 py-4 hover:bg-[#EBE8E1] transition-colors flex items-start gap-3">
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 mb-1.5 flex-wrap">
                  <span className="chip" style={{ background: diffStyle.bg, color: diffStyle.fg }}>
                    {DIFF_LABEL[r.difficulty] || r.difficulty}
                  </span>
                  {!r.is_active && (
                    <span className="chip" style={{ background: '#EBE8E1', color: '#6B6760' }}>
                      Neaktivno
                    </span>
                  )}
                  {r.flags.map(f => {
                    const fs = FLAG_STYLE[f]
                    return <span key={f} className="chip" style={{ background: fs.bg, color: fs.fg }}>{fs.label}</span>
                  })}
                  {r.log_count > 0 ? (
                    <span className="text-[11px]" style={{ color: '#6B6760' }}>
                      {r.log_count} odgovora
                      {r.accuracy_pct !== null && ` · ${r.accuracy_pct}% tačnih`}
                      {avgSec && ` · prosek ${avgSec}s`}
                    </span>
                  ) : r.times_shown > 0 ? (
                    <span className="text-[11px]" style={{ color: '#6B6760' }}>
                      {r.times_shown} prikaza · {r.accuracy_pct}% tačnih
                    </span>
                  ) : null}
                </div>
                <p className="text-[14px] font-semibold leading-snug mb-1" style={{ color: '#1A1A1E' }}>
                  {r.question_text}
                </p>
                <p className="text-[12px]" style={{ color: '#6B6760' }}>
                  ✓ {r.options[r.correct_answer]}
                </p>
              </div>
              <div className="flex flex-col gap-1.5 flex-shrink-0">
                <Link href={`/majmun/pitanja/${r.id}`} className="btn btn-secondary btn-sm" style={{ minWidth: 90 }}>
                  Izmeni
                </Link>
                <button onClick={() => toggleActive(r.id, r.is_active)} disabled={busy === r.id}
                  className="btn btn-sm" style={{
                    background: r.is_active ? '#FEE2E2' : '#D4F3E7',
                    color: r.is_active ? '#b91c1c' : '#1F8A62',
                    minWidth: 90,
                  }}>
                  {busy === r.id ? '...' : r.is_active ? 'Deakt.' : 'Aktiviraj'}
                </button>
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}
