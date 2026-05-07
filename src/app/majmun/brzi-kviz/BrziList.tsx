'use client'

import Link from 'next/link'
import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'

type Row = {
  id: string
  statement: string
  correct_answer: boolean
  explanation: string | null
  category: string | null
  difficulty: string
  is_active: boolean
}

export default function BrziList({ rows }: { rows: Row[] }) {
  const router = useRouter()
  const [busy, setBusy] = useState<string | null>(null)

  async function toggleActive(id: string, currentActive: boolean) {
    setBusy(id)
    await createClient().from('quick_statements').update({ is_active: !currentActive }).eq('id', id)
    setBusy(null)
    router.refresh()
  }

  if (rows.length === 0) {
    return (
      <div className="card-soft py-16 text-center">
        <p className="font-bold text-[16px] mb-2" style={{ color: '#343434' }}>Nema rezultata</p>
      </div>
    )
  }

  return (
    <div className="card-soft overflow-hidden">
      <div className="divide-y" style={{ borderColor: '#F2F2F2' }}>
        {rows.map(r => (
          <div key={r.id} className="px-5 py-4 hover:bg-[#F2F2F2] transition-colors flex items-start gap-3">
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2 mb-1.5 flex-wrap">
                <span className="chip" style={{ background: r.correct_answer ? '#E8F8F0' : '#FEE2E2', color: r.correct_answer ? '#15803d' : '#b91c1c' }}>
                  {r.correct_answer ? '✓ Tačno' : '✗ Netačno'}
                </span>
                {r.category && <span className="chip" style={{ background: '#BCD9FF', color: '#1e5fa4' }}>{r.category}</span>}
                {!r.is_active && <span className="chip" style={{ background: '#F2F2F2', color: '#9C9C9C' }}>Neaktivno</span>}
              </div>
              <p className="text-[14px] font-semibold leading-snug mb-1" style={{ color: '#343434' }}>{r.statement}</p>
              {r.explanation && <p className="text-[12px] mt-1" style={{ color: '#9C9C9C' }}>{r.explanation}</p>}
            </div>
            <div className="flex flex-col gap-1.5 flex-shrink-0">
              <Link href={`/majmun/brzi-kviz/${r.id}`} className="btn btn-secondary btn-sm" style={{ minWidth: 90 }}>Izmeni</Link>
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
        ))}
      </div>
    </div>
  )
}
