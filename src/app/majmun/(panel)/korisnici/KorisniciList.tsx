'use client'

import { useMemo, useState, useTransition } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'

type Row = {
  id: string
  first_name: string | null
  last_name: string | null
  nickname: string | null
  avatar: string | null
  email: string | null
  city: string | null
  role: string
  created_at: string
  is_blocked?: boolean | null
  pro_games: number
  pro_best: number
  pro_avg_sec_per_q: number | null
}

type Props = {
  rows: Row[]
  myId: string
}

const ADMIN_ROLES = ['urednik', 'moderator', 'super_admin']

export default function KorisniciList({ rows, myId }: Props) {
  const router = useRouter()
  const [pending, startTransition] = useTransition()
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const [error, setError] = useState('')

  const selectableIds = useMemo(
    () => rows.filter(r => r.id !== myId).map(r => r.id),
    [rows, myId]
  )

  const allSelected =
    selectableIds.length > 0 && selectableIds.every(id => selected.has(id))

  // "Novo" chip threshold — pin the timestamp ONCE on mount instead of
  // calling Date.now() on every render. Hook-purity rule trips on the
  // inline call, and per-render churn would make chips flicker as the
  // 24h boundary crosses anyway. Computed once is right.
  const [nowMs] = useState(() => Date.now())

  function toggleAll() {
    if (allSelected) setSelected(new Set())
    else setSelected(new Set(selectableIds))
  }

  function toggleOne(id: string) {
    setSelected(prev => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }

  async function bulkDelete() {
    if (selected.size === 0) return
    const count = selected.size
    if (!window.confirm(
      `Da li si siguran da želiš da TRAJNO obrišeš ${count} korisnik${count === 1 ? 'a' : 'a'}?\n\n` +
      `Brišu se: nalog (auth.users), profil i sve igre/rezultati. Ovo se ne može poništiti.`
    )) return

    setError('')
    const supabase = createClient()
    const { data, error: rpcErr } = await supabase
      .rpc('admin_delete_users', { p_ids: Array.from(selected) })
    if (rpcErr) { setError(rpcErr.message); return }
    const result = data as { ok: boolean; error?: string; deleted?: number }
    if (!result?.ok) { setError(result?.error || 'Brisanje nije uspelo.'); return }

    setSelected(new Set())
    startTransition(() => router.refresh())
  }

  return (
    <>
      {error && (
        <div className="rounded-2xl px-4 py-3 text-[13px] font-medium" style={{ background: '#FFE3EA', color: '#C42B4F' }}>
          {error}
        </div>
      )}

      {selected.size > 0 && (
        <div className="card-soft p-3 flex items-center justify-between gap-3 sticky top-2 z-30"
          style={{ background: '#FFF3C4' }}>
          <p className="text-[13px] font-semibold" style={{ color: '#8A6A12' }}>
            Odabrano: <strong>{selected.size}</strong>
          </p>
          <div className="flex gap-2">
            <button onClick={() => setSelected(new Set())}
              className="btn btn-secondary btn-sm">Poništi</button>
            <button onClick={bulkDelete} disabled={pending}
              className="btn btn-sm"
              style={{ background: '#E5385C', color: 'white' }}>
              {pending ? 'Brisanje…' : `Obriši ${selected.size}`}
            </button>
          </div>
        </div>
      )}

      <div className="card-soft overflow-hidden">
        <div className="px-5 py-3 border-b flex items-center gap-3" style={{ borderColor: '#E7E1D0' }}>
          <input type="checkbox" checked={allSelected} onChange={toggleAll}
            className="w-4 h-4 cursor-pointer" />
          <span className="text-[11px] font-bold uppercase tracking-widest" style={{ color: '#6F6C66' }}>
            Označi sve na strani
          </span>
        </div>

        <div className="divide-y" style={{ borderColor: '#E7E1D0' }}>
          {rows.map(u => {
            const name = u.nickname || `${u.first_name || ''} ${u.last_name || ''}`.trim() || 'Igrač'
            const isAdmin = ADMIN_ROLES.includes(u.role)
            const isSelf = u.id === myId
            const checked = selected.has(u.id)
            const avgSec = u.pro_avg_sec_per_q != null ? u.pro_avg_sec_per_q.toFixed(1) : null
            // Surface fresh signups visually — the list is already
            // sorted by created_at desc, but a "Novo" chip makes the
            // recency obvious at a glance instead of decoding the
            // sidebar date.
            const ageMs = nowMs - new Date(u.created_at).getTime()
            const isFresh = ageMs < 24 * 60 * 60 * 1000  // 24h

            return (
              <div key={u.id}
                className="px-5 py-4 hover:bg-[#E7E1D0] transition-colors flex items-center gap-3"
                style={checked ? { background: 'rgba(18,144,126,0.08)' } : undefined}>
                <input type="checkbox" checked={checked} disabled={isSelf}
                  onChange={() => toggleOne(u.id)}
                  className="w-4 h-4 flex-shrink-0 cursor-pointer disabled:opacity-30 disabled:cursor-not-allowed" />

                <Link href={`/majmun/korisnici/${u.id}`}
                  className="flex items-center gap-3 flex-1 min-w-0">
                  <div className="w-10 h-10 rounded-2xl overflow-hidden flex-shrink-0 bg-[#E7E1D0]">
                    {u.avatar
                      ? <Image src={`/avatars/${u.avatar}`} alt={name} width={40} height={40} className="w-full h-full object-cover" />
                      : <div className="w-full h-full flex items-center justify-center text-[13px] font-bold text-white" style={{ background: '#12907E' }}>{name[0]}</div>}
                  </div>

                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 flex-wrap">
                      <p className="font-semibold text-[14px] truncate tracking-tight" style={{ color: '#151515' }}>{name}</p>
                      {isAdmin && (
                        <span className="chip" style={{ background: '#FFD84D', color: '#151515' }}>{u.role.replace('_', ' ')}</span>
                      )}
                      {isSelf && (
                        <span className="chip" style={{ background: '#DFF3EE', color: '#0E6F61' }}>ti</span>
                      )}
                      {isFresh && (
                        <span className="chip" style={{ background: '#DFF3EE', color: '#0E6F61' }}>✨ Novo</span>
                      )}
                      {u.is_blocked && (
                        <span className="chip" style={{ background: '#FFE3EA', color: '#C42B4F' }}>🚫 blokiran</span>
                      )}
                    </div>
                    <p className="text-[12px]" style={{ color: '#6F6C66' }}>
                      {u.email}{u.city ? ` · ${u.city}` : ''}
                    </p>
                  </div>

                  <div className="hidden sm:flex flex-shrink-0 items-center gap-3 text-[11px]" style={{ color: '#6F6C66' }}>
                    {u.pro_games > 0 && (
                      <div className="text-right">
                        <p className="font-bold text-[13px]" style={{ color: '#151515' }}>{u.pro_best}</p>
                        <p>rekord · {u.pro_games} {u.pro_games === 1 ? 'igra' : u.pro_games < 5 ? 'igre' : 'igara'}</p>
                      </div>
                    )}
                    {avgSec != null && (
                      <div className="text-right" title="Prosečno vreme po pitanju u PRO kvizu">
                        <p className="font-bold text-[13px]" style={{ color: parseFloat(avgSec) < 5 ? '#E5385C' : '#151515' }}>
                          {avgSec}s
                        </p>
                        <p>po pitanju</p>
                      </div>
                    )}
                    <div className="text-right">
                      {new Date(u.created_at).toLocaleDateString('sr')}
                    </div>
                  </div>
                </Link>
              </div>
            )
          })}
        </div>
      </div>
    </>
  )
}
