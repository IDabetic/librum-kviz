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
  Drama:      { bg: '#DFF3EE', fg: '#0E6F61' },
  Fantastika: { bg: '#DFF3EE', fg: '#0E6F61' },
  Ljubavni:   { bg: '#FFE3EA', fg: '#C42B4F' },
  Istorijski: { bg: '#FFF3C4', fg: '#8A6A12' },
  Krimi:      { bg: '#E7E1D0', fg: '#151515' },
  Triler:     { bg: '#FFD84D', fg: '#151515' },
  Domaći:     { bg: '#DFF3EE', fg: '#0E6F61' },
  Horor:      { bg: '#FFE3EA', fg: '#C42B4F' },
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
        <p className="font-bold text-[16px] mb-2" style={{ color: '#151515' }}>Nema rezultata</p>
        <p className="text-[13px]" style={{ color: '#6F6C66' }}>Pokušaj sa drugim filterima.</p>
      </div>
    )
  }

  return (
    <div className="card-soft overflow-hidden">
      <div className="divide-y" style={{ borderColor: '#E7E1D0' }}>
        {rows.map(r => {
          const accuracy = r.times_shown > 0 ? Math.round((r.times_correct / r.times_shown) * 100) : null
          const gs = GENRE_COLOR[r.genre] || { bg: '#E7E1D0', fg: '#6F6C66' }
          return (
            <div key={r.id} className="px-5 py-4 hover:bg-[#E7E1D0] transition-colors flex items-start gap-3">
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 mb-1.5 flex-wrap">
                  <span className="chip" style={{ background: gs.bg, color: gs.fg }}>{r.genre}</span>
                  {!r.is_active && (
                    <span className="chip" style={{ background: '#E7E1D0', color: '#6F6C66' }}>Neaktivno</span>
                  )}
                  {r.times_shown > 0 && (
                    <span className="text-[11px]" style={{ color: '#6F6C66' }}>
                      {r.times_shown} prikaza · {accuracy}% tačnih
                    </span>
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
                <Link href={`/majmun/book-kviz/${r.id}`} className="btn btn-secondary btn-sm" style={{ minWidth: 90 }}>
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
