import { createClient } from '@/lib/supabase/server'
import Link from 'next/link'
import { IconSearch } from '@/components/icons'
import KorisniciList from './KorisniciList'

export const dynamic = 'force-dynamic'

type SP = { q?: string; role?: string; page?: string; per?: string }

const PER_OPTIONS = [25, 50, 100]

export default async function KorisniciPage({ searchParams }: { searchParams: Promise<SP> }) {
  const sp = await searchParams
  const supabase = await createClient()

  const per = PER_OPTIONS.includes(parseInt(sp.per || '50', 10))
    ? parseInt(sp.per!, 10)
    : 50
  const page = Math.max(0, parseInt(sp.page || '0', 10))

  let query = supabase.from('profiles')
    .select('id, first_name, last_name, nickname, avatar, email, city, role, created_at', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(page * per, page * per + per - 1)
  if (sp.q) query = query.or(`first_name.ilike.%${sp.q}%,last_name.ilike.%${sp.q}%,nickname.ilike.%${sp.q}%,email.ilike.%${sp.q}%`)
  if (sp.role && sp.role !== 'all') query = query.eq('role', sp.role)

  const { data: profiles, count } = await query
  const totalPages = Math.ceil((count ?? 0) / per)

  // PRO sessions for the visible users — aggregate avg sec/question + games + best
  const userIds = (profiles || []).map(p => p.id)
  const { data: sessions } = userIds.length
    ? await supabase.from('survivor_sessions')
        .select('user_id, score, total_time_seconds, questions_reached')
        .in('user_id', userIds)
    : { data: [] as { user_id: string; score: number; total_time_seconds: number; questions_reached: number }[] }

  type Stat = { games: number; bestScore: number; secSum: number; secCount: number }
  const statMap = new Map<string, Stat>()
  for (const id of userIds) statMap.set(id, { games: 0, bestScore: 0, secSum: 0, secCount: 0 })
  for (const s of sessions || []) {
    const stat = statMap.get(s.user_id)
    if (!stat) continue
    stat.games += 1
    if (s.score > stat.bestScore) stat.bestScore = s.score
    if (s.questions_reached > 0) {
      stat.secSum += s.total_time_seconds / s.questions_reached
      stat.secCount += 1
    }
  }

  const rows = (profiles || []).map(p => {
    const stat = statMap.get(p.id)!
    return {
      ...p,
      pro_games: stat.games,
      pro_best: stat.bestScore,
      pro_avg_sec_per_q: stat.secCount ? stat.secSum / stat.secCount : null,
    }
  })

  // Currently signed-in admin (so they can't bulk-delete themselves accidentally)
  const { data: { user } } = await supabase.auth.getUser()
  const myId = user?.id || ''

  const baseQuery = (override: Partial<SP>) => {
    const params = new URLSearchParams()
    const merged = { q: sp.q, role: sp.role, per: String(per), ...override }
    for (const [k, v] of Object.entries(merged)) {
      if (v !== undefined && v !== '' && v !== null) params.set(k, String(v))
    }
    return params.toString()
  }

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h1 className="font-black tracking-tight" style={{ color: '#343434', fontSize: 'clamp(22px, 4vw, 28px)' }}>Korisnici</h1>
          <p className="text-[13px] mt-1" style={{ color: '#9C9C9C' }}>{count ?? 0} ukupno</p>
        </div>
        <Link href="/majmun/korisnici/dodaj" className="btn btn-primary btn-md">+ Dodaj admina</Link>
      </div>

      <form className="card-soft p-4 flex items-center gap-2 flex-wrap" action="/majmun/korisnici">
        <div className="relative flex-1 min-w-[200px]">
          <div className="absolute left-4 top-1/2 -translate-y-1/2" style={{ color: '#9C9C9C' }}><IconSearch size={16} strokeWidth={2.2} /></div>
          <input name="q" defaultValue={sp.q || ''} className="input pl-11" placeholder="Pretraga po imenu ili email-u…" />
        </div>
        <select name="role" defaultValue={sp.role || 'all'} className="input flex-shrink-0" style={{ width: 'auto', minWidth: 130 }}>
          <option value="all">Sve uloge</option>
          <option value="user">Korisnik</option>
          <option value="urednik">Urednik</option>
          <option value="moderator">Moderator</option>
          <option value="super_admin">Super admin</option>
        </select>
        <select name="per" defaultValue={String(per)} className="input flex-shrink-0" style={{ width: 'auto', minWidth: 90 }}>
          {PER_OPTIONS.map(n => <option key={n} value={n}>{n}/str.</option>)}
        </select>
        <button type="submit" className="btn btn-primary btn-md">Pretraži</button>
      </form>

      <KorisniciList rows={rows} myId={myId} />

      {totalPages > 1 && (
        <div className="flex items-center justify-between pt-2">
          <p className="text-[12px]" style={{ color: '#9C9C9C' }}>Strana {page + 1} od {totalPages}</p>
          <div className="flex gap-2">
            {page > 0 && <Link href={`/majmun/korisnici?${baseQuery({ page: String(page - 1) })}`} className="btn btn-secondary btn-sm">← Prethodna</Link>}
            {page < totalPages - 1 && <Link href={`/majmun/korisnici?${baseQuery({ page: String(page + 1) })}`} className="btn btn-primary btn-sm">Sledeća →</Link>}
          </div>
        </div>
      )}
    </div>
  )
}
