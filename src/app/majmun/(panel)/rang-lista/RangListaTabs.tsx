'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'

type SurvivorRow = { id: string; name: string; score: number; questions_reached: number; accuracy: number | string; total_time_seconds: number; created_at: string }
type BookRow     = { id: string; name: string; score: number; questions_reached: number; accuracy: number | string; top_genre: string | null; created_at: string }
type KafanaRow   = { id: string; name: string; score: number; questions_reached: number; accuracy: number | string; best_combo: number; created_at: string }
type HangmanRow  = { id: string; name: string; won: boolean; score: number; word: string; category: string | null; created_at: string }
type QuickRow    = { id: string; name: string; score: number; correct_count: number; accuracy: number | string; created_at: string }
type DuelRow     = {
  id: string; host_id: string; guest_id: string | null
  host_name: string; guest_name: string
  host_score: number; guest_score: number
  host_finished: boolean | null; guest_finished: boolean | null
  status: string; quiz_type: string | null; created_at: string
}
type Suspicious = {
  id: string; game: string; user: string; score: number;
  reason: string; created_at: string; table: string;
}

const TABS = [
  { id: 'suspicious', label: '🚨 Sumnjive' },
  { id: 'survivor',   label: 'PRO kviz' },
  { id: 'book',       label: 'Book kviz' },
  { id: 'kafana',     label: 'Kafanski' },
  { id: 'duel',       label: 'Trivia duel' },
  { id: 'hangman',    label: 'Vešanje' },
  { id: 'quick',      label: 'Brzi kviz' },
] as const
type TabId = typeof TABS[number]['id']

export default function RangListaTabs({
  survivor, book, kafana, hangman, quick, duels, suspicious,
}: {
  survivor: SurvivorRow[]; book: BookRow[]; kafana: KafanaRow[]
  hangman: HangmanRow[]; quick: QuickRow[]; duels: DuelRow[]
  suspicious: Suspicious[]
}) {
  // Default to the Sumnjive tab if there's anything flagged — that's
  // the highest-signal info an admin opens this page for. Otherwise
  // fall through to PRO.
  const [tab, setTab] = useState<TabId>(suspicious.length > 0 ? 'suspicious' : 'survivor')
  const router = useRouter()
  const [busy, setBusy] = useState<string | null>(null)

  async function deleteSession(table: string, id: string) {
    if (!confirm('Stvarno obrisati ovu sesiju? Ne može se poništiti.')) return
    setBusy(id)
    await createClient().from(table).delete().eq('id', id)
    setBusy(null); router.refresh()
  }

  function fmtTime(s: string): string {
    return new Date(s).toLocaleString('sr', { dateStyle: 'short', timeStyle: 'short' })
  }

  return (
    <>
      <div className="flex p-1 rounded-full mb-6 overflow-x-auto" style={{ background: '#F2F2F2' }}>
        {TABS.map(t => (
          <button key={t.id} onClick={() => setTab(t.id)}
            className="flex-shrink-0 py-2.5 px-4 rounded-full text-[12px] font-semibold transition-all whitespace-nowrap"
            style={tab === t.id
              ? { background: '#FCFCFC', color: '#343434', boxShadow: '0 2px 8px rgba(52,52,52,0.06)' }
              : { color: '#9C9C9C' }}>
            {t.label}
            {t.id === 'suspicious' && suspicious.length > 0 && (
              <span className="ml-1.5 inline-flex items-center justify-center text-[10px] font-black px-1.5 py-0.5 rounded-full"
                style={{ background: '#FEE2E2', color: '#b91c1c' }}>
                {suspicious.length}
              </span>
            )}
          </button>
        ))}
      </div>

      {/* ── Sumnjive partije ───────────────────────────────────── */}
      {tab === 'suspicious' && (
        <div className="card-soft overflow-hidden">
          {suspicious.length === 0 ? (
            <p className="px-5 py-10 text-center text-[14px]" style={{ color: '#9C9C9C' }}>
              Nema sumnjivih partija u izabranom periodu. 🎉
            </p>
          ) : (
            <div className="divide-y" style={{ borderColor: '#F2F2F2' }}>
              {suspicious.map(r => (
                <div key={r.id} className="px-5 py-3 flex items-center gap-3">
                  <div className="flex-1 min-w-0">
                    <p className="font-semibold text-[14px]" style={{ color: '#343434' }}>
                      <span className="chip mr-2" style={{ background: '#FEE2E2', color: '#b91c1c' }}>{r.game}</span>
                      {r.user}
                    </p>
                    <p className="text-[11px] mt-0.5" style={{ color: '#b91c1c' }}>
                      ⚠ {r.reason}
                    </p>
                    <p className="text-[10px] mt-0.5" style={{ color: '#9C9C9C' }}>
                      {fmtTime(r.created_at)}
                    </p>
                  </div>
                  <div className="font-black text-[16px]" style={{ color: '#b91c1c' }}>{r.score}</div>
                  <button onClick={() => deleteSession(r.table, r.id)} disabled={busy === r.id}
                    className="btn btn-sm" style={{ background: '#FEE2E2', color: '#b91c1c' }}>
                    {busy === r.id ? '...' : 'Obriši'}
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* ── PRO kviz ──────────────────────────────────────────── */}
      {tab === 'survivor' && (
        <SessionList rows={survivor} accent="#609DED" busy={busy} onDelete={id => deleteSession('survivor_sessions', id)}
          detail={r => `${r.questions_reached} pit. · ${Math.round(Number(r.accuracy))}% · ${fmtTime(r.created_at)}`} />
      )}

      {/* ── Book kviz ─────────────────────────────────────────── */}
      {tab === 'book' && (
        <SessionList rows={book} accent="#9c7a13" busy={busy} onDelete={id => deleteSession('book_sessions', id)}
          detail={r => `${r.questions_reached} pit. · ${Math.round(Number(r.accuracy))}%${r.top_genre ? ` · ${r.top_genre}` : ''} · ${fmtTime(r.created_at)}`} />
      )}

      {/* ── Kafanski kviz ─────────────────────────────────────── */}
      {tab === 'kafana' && (
        <SessionList rows={kafana} accent="#b91c1c" busy={busy} onDelete={id => deleteSession('kafana_sessions', id)}
          detail={r => `${r.questions_reached} pit. · ${Math.round(Number(r.accuracy))}% · niz ${r.best_combo} · ${fmtTime(r.created_at)}`} />
      )}

      {/* ── Trivia duel ───────────────────────────────────────── */}
      {tab === 'duel' && (
        <div className="card-soft overflow-hidden">
          <div className="divide-y" style={{ borderColor: '#F2F2F2' }}>
            {duels.map(r => {
              const finished = r.status === 'finished' || (r.host_finished && r.guest_finished)
              return (
                <div key={r.id} className="px-5 py-3 flex items-center gap-3">
                  <div className="flex-1 min-w-0">
                    <p className="font-semibold text-[14px]" style={{ color: '#343434' }}>
                      {r.host_name} <span style={{ color: '#9C9C9C' }}>vs</span> {r.guest_name}
                    </p>
                    <p className="text-[11px]" style={{ color: '#9C9C9C' }}>
                      {r.quiz_type === 'kafana' ? 'Kafanski' : 'PRO'} · {finished ? 'završen' : r.status} · {fmtTime(r.created_at)}
                    </p>
                  </div>
                  <div className="font-black text-[16px] tabular-nums" style={{ color: '#9c7a13' }}>
                    {r.host_score}:{r.guest_score}
                  </div>
                  <button onClick={() => deleteSession('game_rooms', r.id)} disabled={busy === r.id}
                    className="btn btn-sm" style={{ background: '#FEE2E2', color: '#b91c1c' }}>
                    {busy === r.id ? '...' : 'Obriši'}
                  </button>
                </div>
              )
            })}
          </div>
        </div>
      )}

      {/* ── Vešanje ───────────────────────────────────────────── */}
      {tab === 'hangman' && (
        <div className="card-soft overflow-hidden">
          <div className="divide-y" style={{ borderColor: '#F2F2F2' }}>
            {hangman.map(r => (
              <div key={r.id} className="px-5 py-3 flex items-center gap-3">
                <div className="flex-1 min-w-0">
                  <p className="font-semibold text-[14px]" style={{ color: '#343434' }}>{r.name}</p>
                  <p className="text-[11px]" style={{ color: '#9C9C9C' }}>
                    {r.word.toUpperCase()} · {r.category || 'Custom'} · {r.won ? 'pobeda' : 'poraz'} · {fmtTime(r.created_at)}
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

      {/* ── Brzi kviz ─────────────────────────────────────────── */}
      {tab === 'quick' && (
        <SessionList rows={quick} accent="#b91c1c" busy={busy} onDelete={id => deleteSession('quick_sessions', id)}
          detail={r => `${r.correct_count} tačnih · ${Math.round(Number(r.accuracy))}% · ${fmtTime(r.created_at)}`} />
      )}
    </>
  )
}

// Shared row layout for the modes where the row schema is identical
// (name + detail line + score chip + delete button). Saves ~40 lines.
function SessionList<T extends { id: string; name: string; score: number }>({
  rows, accent, busy, onDelete, detail,
}: {
  rows: T[]
  accent: string
  busy: string | null
  onDelete: (id: string) => void
  detail: (r: T) => string
}) {
  return (
    <div className="card-soft overflow-hidden">
      <div className="divide-y" style={{ borderColor: '#F2F2F2' }}>
        {rows.map(r => (
          <div key={r.id} className="px-5 py-3 flex items-center gap-3">
            <div className="flex-1 min-w-0">
              <p className="font-semibold text-[14px]" style={{ color: '#343434' }}>{r.name}</p>
              <p className="text-[11px]" style={{ color: '#9C9C9C' }}>{detail(r)}</p>
            </div>
            <div className="font-black text-[16px]" style={{ color: accent }}>{r.score}</div>
            <button onClick={() => onDelete(r.id)} disabled={busy === r.id}
              className="btn btn-sm" style={{ background: '#FEE2E2', color: '#b91c1c' }}>
              {busy === r.id ? '...' : 'Obriši'}
            </button>
          </div>
        ))}
      </div>
    </div>
  )
}
