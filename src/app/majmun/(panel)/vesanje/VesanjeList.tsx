'use client'

import Link from 'next/link'
import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'

type Row = {
  id: string
  word: string
  category: string
  word_length: number
  hint: string
  is_active: boolean
  times_used: number
  times_guessed: number
}

export default function VesanjeList({ rows }: { rows: Row[] }) {
  const router = useRouter()
  const [busy, setBusy] = useState<string | null>(null)

  async function toggle(id: string, active: boolean) {
    setBusy(id)
    await createClient().from('hangman_words').update({ is_active: !active }).eq('id', id)
    setBusy(null); router.refresh()
  }

  if (rows.length === 0) {
    return <div className="card-soft py-16 text-center"><p className="font-bold text-[16px]" style={{ color: '#343434' }}>Nema rezultata</p></div>
  }

  return (
    <div className="card-soft overflow-hidden">
      <div className="divide-y" style={{ borderColor: '#F2F2F2' }}>
        {rows.map(r => {
          const guessRate = r.times_used > 0 ? Math.round((r.times_guessed / r.times_used) * 100) : null
          return (
            <div key={r.id} className="px-5 py-4 hover:bg-[#F2F2F2] transition-colors flex items-start gap-3">
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 mb-1.5 flex-wrap">
                  <span className="chip" style={{ background: '#BCD9FF', color: '#1e5fa4' }}>{r.category}</span>
                  <span className="chip" style={{ background: '#F2F2F2', color: '#9C9C9C' }}>{r.word_length} slova</span>
                  {!r.is_active && <span className="chip" style={{ background: '#F2F2F2', color: '#9C9C9C' }}>Neaktivno</span>}
                  {r.times_used > 0 && (
                    <span className="text-[11px]" style={{ color: '#9C9C9C' }}>
                      {r.times_used} igara · {guessRate}% pogođeno
                    </span>
                  )}
                </div>
                <p className="font-black text-[16px] uppercase tracking-wider mb-1" style={{ color: '#343434' }}>{r.word}</p>
                <p className="text-[12px]" style={{ color: '#9C9C9C' }}>{r.hint}</p>
              </div>
              <div className="flex flex-col gap-1.5 flex-shrink-0">
                <Link href={`/majmun/vesanje/${r.id}`} className="btn btn-secondary btn-sm" style={{ minWidth: 90 }}>Izmeni</Link>
                <button onClick={() => toggle(r.id, r.is_active)} disabled={busy === r.id}
                  className="btn btn-sm" style={{
                    background: r.is_active ? '#FEE2E2' : '#E8F8F0',
                    color: r.is_active ? '#b91c1c' : '#15803d', minWidth: 90,
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
