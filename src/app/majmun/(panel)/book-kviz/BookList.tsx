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
  genre: string
  is_active: boolean
  times_shown: number
  times_correct: number
  created_at: string
}

const GENRE_COLOR: Record<string, { bg: string; fg: string }> = {
  Drama:      { bg: '#D4D2F5', fg: '#2C2980' },
  Fantastika: { bg: '#D4F3E7', fg: '#1F8A62' },
  Ljubavni:   { bg: '#FEE2E2', fg: '#b91c1c' },
  Istorijski: { bg: '#F5E6B8', fg: '#8A6A12' },
  Krimi:      { bg: '#EBE8E1', fg: '#1A1A1E' },
  Triler:     { bg: '#E2B93A', fg: '#1A1A1E' },
  Domaći:     { bg: '#D4F3E7', fg: '#1F8A62' },
  Horor:      { bg: '#FEE2E2', fg: '#b91c1c' },
}

export default function BookList({ rows }: { rows: Row[] }) {
  const router = useRouter()
  const [busy, setBusy] = useState<string | null>(null)

  async function toggleActive(id: string, currentActive: boolean) {
    setBusy(id)
    await createClient().from('book_questions').update({ is_active: !currentActive }).eq('id', id)
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
          const accuracy = r.times_shown > 0 ? Math.round((r.times_correct / r.times_shown) * 100) : null
          const gs = GENRE_COLOR[r.genre] || { bg: '#EBE8E1', fg: '#6B6760' }
          return (
            <div key={r.id} className="px-5 py-4 hover:bg-[#EBE8E1] transition-colors flex items-start gap-3">
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 mb-1.5 flex-wrap">
                  <span className="chip" style={{ background: gs.bg, color: gs.fg }}>{r.genre}</span>
                  {!r.is_active && (
                    <span className="chip" style={{ background: '#EBE8E1', color: '#6B6760' }}>Neaktivno</span>
                  )}
                  {r.times_shown > 0 && (
                    <span className="text-[11px]" style={{ color: '#6B6760' }}>
                      {r.times_shown} prikaza · {accuracy}% tačnih
                    </span>
                  )}
                </div>
                <p className="text-[14px] font-semibold leading-snug mb-1" style={{ color: '#1A1A1E' }}>
                  {r.question_text}
                </p>
                <p className="text-[12px]" style={{ color: '#6B6760' }}>
                  ✓ {r.options[r.correct_answer]}
                </p>
              </div>
              <div className="flex flex-col gap-1.5 flex-shrink-0">
                <Link href={`/majmun/book-kviz/${r.id}`} className="btn btn-secondary btn-sm" style={{ minWidth: 90 }}>
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
