'use client'

import Link from 'next/link'
import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'

type Row = {
  id: string
  question_text: string
  options: string[]
  correct_answer: number
  difficulty: string
  is_active: boolean
  created_at: string
}

const DIFF_LABEL: Record<string, string> = {
  easy: 'Lako', medium: 'Srednje', hard: 'Teško', impossible: 'Nemoguće',
}
const DIFF_COLOR: Record<string, { bg: string; fg: string }> = {
  easy:       { bg: '#E8F8F0', fg: '#15803d' },
  medium:     { bg: '#BCD9FF', fg: '#1e5fa4' },
  hard:       { bg: '#FFECBC', fg: '#9c7a13' },
  impossible: { bg: '#FEE2E2', fg: '#b91c1c' },
}

export default function BrziList({ rows }: { rows: Row[] }) {
  const router = useRouter()
  const [busy, setBusy] = useState<string | null>(null)

  async function toggleActive(id: string, currentActive: boolean) {
    setBusy(id)
    await createClient().from('questions').update({ is_active: !currentActive }).eq('id', id)
    setBusy(null)
    router.refresh()
  }

  if (rows.length === 0) {
    return (
      <div className="card-soft py-16 text-center">
        <p className="font-bold text-[16px] mb-2" style={{ color: '#343434' }}>Još nema Brzi-only pitanja</p>
        <p className="text-[13px] mb-5" style={{ color: '#9C9C9C' }}>
          Klikni <strong>+ Novo Brzi pitanje</strong> da dodaš prvo.
        </p>
      </div>
    )
  }

  return (
    <div className="card-soft overflow-hidden">
      <div className="divide-y" style={{ borderColor: '#F2F2F2' }}>
        {rows.map(r => {
          const diffStyle = DIFF_COLOR[r.difficulty] || { bg: '#F2F2F2', fg: '#9C9C9C' }
          return (
            <div key={r.id} className="px-5 py-4 hover:bg-[#F2F2F2] transition-colors flex items-start gap-3">
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 mb-1.5 flex-wrap">
                  <span className="chip" style={{ background: diffStyle.bg, color: diffStyle.fg }}>
                    {DIFF_LABEL[r.difficulty] || r.difficulty}
                  </span>
                  {!r.is_active && (
                    <span className="chip" style={{ background: '#F2F2F2', color: '#9C9C9C' }}>Neaktivno</span>
                  )}
                </div>
                <p className="text-[14px] font-semibold leading-snug mb-1" style={{ color: '#343434' }}>
                  {r.question_text}
                </p>
                <p className="text-[12px]" style={{ color: '#9C9C9C' }}>
                  ✓ {r.options[r.correct_answer]}
                </p>
              </div>
              <div className="flex flex-col gap-1.5 flex-shrink-0">
                <Link href={`/majmun/brzi-kviz/${r.id}`} className="btn btn-secondary btn-sm" style={{ minWidth: 90 }}>
                  Izmeni
                </Link>
                <button onClick={() => toggleActive(r.id, r.is_active)} disabled={busy === r.id}
                  className="btn btn-sm" style={{
                    background: r.is_active ? '#FEE2E2' : '#E8F8F0',
                    color: r.is_active ? '#b91c1c' : '#15803d',
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
