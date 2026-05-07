'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'

type Profile = { first_name: string; nickname: string }
type SurvivorRow = { id: string; score: number; questions_reached: number; accuracy: number; total_time_seconds: number; created_at: string; profiles: Profile | Profile[] | null }
type HangmanRow = { id: string; won: boolean; score: number; word: string; category: string | null; created_at: string; profiles: Profile | Profile[] | null }
type QuickRow = { id: string; score: number; correct_count: number; accuracy: number; created_at: string; profiles: Profile | Profile[] | null }

const TABS = [
  { id: 'survivor', label: 'PRO kviz' },
  { id: 'hangman', label: 'Vešanje' },
  { id: 'quick', label: 'Brzi kviz' },
] as const
type TabId = typeof TABS[number]['id']

function getName(p: Profile | Profile[] | null): string {
  const prof = Array.isArray(p) ? p[0] : p
  return prof?.nickname || prof?.first_name || 'Igrač'
}

export default function RangListaTabs({ survivor, hangman, quick }: {
  survivor: SurvivorRow[]; hangman: HangmanRow[]; quick: QuickRow[]
}) {
  const [tab, setTab] = useState<TabId>('survivor')
  const router = useRouter()
  const [busy, setBusy] = useState<string | null>(null)

  async function deleteSession(table: string, id: string) {
    if (!confirm('Stvarno obrisati ovu sesiju? Ne može se poništiti.')) return
    setBusy(id)
    await createClient().from(table).delete().eq('id', id)
    setBusy(null); router.refresh()
  }

  return (
    <>
      <div className="flex p-1 rounded-full mb-6 max-w-md" style={{ background: '#F2F2F2' }}>
        {TABS.map(t => (
          <button key={t.id} onClick={() => setTab(t.id)}
            className="flex-1 py-2.5 px-3 rounded-full text-[13px] font-semibold transition-all"
            style={tab === t.id
              ? { background: '#FCFCFC', color: '#343434', boxShadow: '0 2px 8px rgba(52,52,52,0.06)' }
              : { color: '#9C9C9C' }}>
            {t.label}
          </button>
        ))}
      </div>

      {tab === 'survivor' && (
        <div className="card-soft overflow-hidden">
          <div className="divide-y" style={{ borderColor: '#F2F2F2' }}>
            {survivor.map(r => (
              <div key={r.id} className="px-5 py-3 flex items-center gap-3">
                <div className="flex-1 min-w-0">
                  <p className="font-semibold text-[14px]" style={{ color: '#343434' }}>{getName(r.profiles)}</p>
                  <p className="text-[11px]" style={{ color: '#9C9C9C' }}>
                    {r.questions_reached} pit. · {Math.round(Number(r.accuracy))}% · {new Date(r.created_at).toLocaleString('sr', { dateStyle: 'short', timeStyle: 'short' })}
                  </p>
                </div>
                <div className="font-black text-[16px]" style={{ color: '#609DED' }}>{r.score}</div>
                <button onClick={() => deleteSession('survivor_sessions', r.id)} disabled={busy === r.id}
                  className="btn btn-sm" style={{ background: '#FEE2E2', color: '#b91c1c' }}>
                  {busy === r.id ? '...' : 'Obriši'}
                </button>
              </div>
            ))}
          </div>
        </div>
      )}

      {tab === 'hangman' && (
        <div className="card-soft overflow-hidden">
          <div className="divide-y" style={{ borderColor: '#F2F2F2' }}>
            {hangman.map(r => (
              <div key={r.id} className="px-5 py-3 flex items-center gap-3">
                <div className="flex-1 min-w-0">
                  <p className="font-semibold text-[14px]" style={{ color: '#343434' }}>{getName(r.profiles)}</p>
                  <p className="text-[11px]" style={{ color: '#9C9C9C' }}>
                    {r.word.toUpperCase()} · {r.category || 'Custom'} · {r.won ? 'pobeda' : 'poraz'}
                  </p>
                </div>
                <div className="font-black text-[16px]" style={{ color: r.won ? '#4CAF50' : '#E55353' }}>{r.score}</div>
                <button onClick={() => deleteSession('hangman_sessions', r.id)} disabled={busy === r.id}
                  className="btn btn-sm" style={{ background: '#FEE2E2', color: '#b91c1c' }}>
                  {busy === r.id ? '...' : 'Obriši'}
                </button>
              </div>
            ))}
          </div>
        </div>
      )}

      {tab === 'quick' && (
        <div className="card-soft overflow-hidden">
          <div className="divide-y" style={{ borderColor: '#F2F2F2' }}>
            {quick.map(r => (
              <div key={r.id} className="px-5 py-3 flex items-center gap-3">
                <div className="flex-1 min-w-0">
                  <p className="font-semibold text-[14px]" style={{ color: '#343434' }}>{getName(r.profiles)}</p>
                  <p className="text-[11px]" style={{ color: '#9C9C9C' }}>
                    {r.correct_count} tačnih · {Math.round(Number(r.accuracy))}% · {new Date(r.created_at).toLocaleString('sr', { dateStyle: 'short', timeStyle: 'short' })}
                  </p>
                </div>
                <div className="font-black text-[16px]" style={{ color: '#FFCB46' }}>{r.score}</div>
                <button onClick={() => deleteSession('quick_sessions', r.id)} disabled={busy === r.id}
                  className="btn btn-sm" style={{ background: '#FEE2E2', color: '#b91c1c' }}>
                  {busy === r.id ? '...' : 'Obriši'}
                </button>
              </div>
            ))}
          </div>
        </div>
      )}
    </>
  )
}
