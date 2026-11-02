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
  easy:       { bg: '#DFF3EE', fg: '#0E6F61' },
  medium:     { bg: '#DFF3EE', fg: '#0E6F61' },
  hard:       { bg: '#FFF3C4', fg: '#8A6A12' },
  impossible: { bg: '#FFE3EA', fg: '#C42B4F' },
}

export default function KafanaList({ rows }: { rows: Row[] }) {
  const router = useRouter()
  const [busy, setBusy] = useState<string | null>(null)

  async function toggleActive(id: string, currentActive: boolean) {
    setBusy(id)
    await createClient().from('kafana_questions').update({ is_active: !currentActive }).eq('id', id)
    setBusy(null)
    router.refresh()
  }

  if (rows.length === 0) {
    return (
      <div className="card-soft py-16 text-center">
        <p className="font-bold text-[16px] mb-2" style={{ color: '#151515' }}>Nema rezultata</p>
        <p className="text-[13px]" style={{ color: '#6F6C66' }}>Pokušaj sa drugim filterom ili dodaj prvo pitanje.</p>
      </div>
    )
  }

  return (
    <div className="card-soft overflow-hidden">
      <div className="divide-y" style={{ borderColor: '#E7E1D0' }}>
        {rows.map(r => {
          const ds = DIFF_COLOR[r.difficulty] || { bg: '#E7E1D0', fg: '#6F6C66' }
          return (
            <div key={r.id} className="px-5 py-4 hover:bg-[#E7E1D0] transition-colors flex items-start gap-3">
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 mb-1.5 flex-wrap">
                  <span className="chip" style={{ background: ds.bg, color: ds.fg }}>
                    {DIFF_LABEL[r.difficulty] || r.difficulty}
                  </span>
                  {!r.is_active && (
                    <span className="chip" style={{ background: '#E7E1D0', color: '#6F6C66' }}>Neaktivno</span>
                  )}
                </div>
                <p className="text-[14px] font-semibold leading-snug mb-1" style={{ color: '#151515' }}>
                  {r.question_text}
                </p>
                <p className="text-[12px]" style={{ color: '#6F6C66' }}>
                  ✓ {r.options[r.correct_answer]}
                </p>
              </div>
              <div className="flex flex-col gap-1.5 flex-shrink-0">
                <Link href={`/majmun/kafana/${r.id}`} className="btn btn-secondary btn-sm" style={{ minWidth: 90 }}>
                  Izmeni
                </Link>
                <button onClick={() => toggleActive(r.id, r.is_active)} disabled={busy === r.id}
                  className="btn btn-sm" style={{
                    background: r.is_active ? '#FFE3EA' : '#DFF3EE',
                    color: r.is_active ? '#C42B4F' : '#0E6F61',
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
