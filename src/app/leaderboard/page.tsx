import { createClient } from '@/lib/supabase/server'
import Header from '@/components/Header'
import Link from 'next/link'
import LeaderboardTabs from './LeaderboardTabs'
import { Logo } from '@/components/Logo'

export default async function LeaderboardPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  // Solo: aggregate score_points and level_reached per player
  const { data: results } = await supabase
    .from('quiz_results')
    .select('user_id, score_points, level_reached, profiles(first_name, last_name, avatar)')
    .gt('level_reached', 0)  // only count games where at least 1 level was completed
    .order('score_points', { ascending: false })
    .limit(2000)

  const soloMap: Record<string, { name: string; userId: string; totalPoints: number; bestLevel: number; plays: number; avatar?: string }> = {}
  ;(results || []).forEach(r => {
    const uid = r.user_id
    const prof = Array.isArray(r.profiles) ? r.profiles[0] : r.profiles as { first_name: string; last_name: string; avatar?: string } | null
    const name = prof ? `${prof.first_name} ${prof.last_name}` : 'Igrač'
    if (!soloMap[uid]) soloMap[uid] = { name, userId: uid, totalPoints: 0, bestLevel: 0, plays: 0, avatar: prof?.avatar || undefined }
    soloMap[uid].totalPoints += r.score_points ?? 0
    soloMap[uid].bestLevel = Math.max(soloMap[uid].bestLevel, r.level_reached ?? 0)
    soloMap[uid].plays++
  })

  const soloAggregated = Object.values(soloMap)
    .sort((a, b) => b.totalPoints - a.totalPoints || b.bestLevel - a.bestLevel)
    .slice(0, 200)

  // Duet: fetch any game where at least one player submitted results.
  // status='finished' may never be set if one player leaves before the other finishes
  // (it's triggered client-side via realtime), so we also check host_finished / guest_finished.
  const { data: duetGames } = await supabase
    .from('game_rooms')
    .select('host_id, guest_id, host_score, guest_score, host_finished, guest_finished, host_level_scores, guest_level_scores, game_format')
    .or('status.eq.finished,host_finished.eq.true,guest_finished.eq.true')
    .not('guest_id', 'is', null)
    .limit(1000)

  const userIds = [...new Set(
    (duetGames || []).flatMap(g => [g.host_id, g.guest_id]).filter(Boolean)
  )] as string[]

  const profileMap: Record<string, string> = {}
  const avatarMap: Record<string, string> = {}
  if (userIds.length > 0) {
    const { data: profileData } = await supabase
      .from('profiles').select('id, first_name, last_name, avatar').in('id', userIds)
    ;(profileData || []).forEach((p: { id: string; first_name: string; last_name: string; avatar?: string }) => {
      profileMap[p.id] = `${p.first_name} ${p.last_name}`
      if (p.avatar) avatarMap[p.id] = p.avatar
    })
  }

  const duetMap: Record<string, { name: string; userId: string; wins: number; losses: number; draws: number; plays: number; avatar?: string }> = {}

  function recordDuet(uid: string, myMetric: number, opMetric: number) {
    const name = profileMap[uid] || 'Igrač'
    if (!duetMap[uid]) duetMap[uid] = { name, userId: uid, wins: 0, losses: 0, draws: 0, plays: 0, avatar: avatarMap[uid] }
    duetMap[uid].plays++
    if (myMetric > opMetric) duetMap[uid].wins++
    else if (myMetric < opMetric) duetMap[uid].losses++
    else duetMap[uid].draws++
  }

  ;(duetGames || []).forEach(g => {
    if (!g.host_id || !g.guest_id) return

    const isTimed = (g.game_format ?? '').startsWith('time_')
    const hLvl: number[] = (g.host_level_scores as number[]) ?? []
    const gLvl: number[] = (g.guest_level_scores as number[]) ?? []

    if (isTimed) {
      // Timed games: both must have finished — compare total scores
      // Level scores are saved after every 10 questions, so data is always fresh
      if (!g.host_finished || !g.guest_finished) return
      recordDuet(g.host_id, g.host_score ?? 0, g.guest_score ?? 0)
      recordDuet(g.guest_id, g.guest_score ?? 0, g.host_score ?? 0)
    } else {
      // Wins-based (best_of_3/5/11): count level wins
      // Levels where both players competed
      const both = Math.min(hLvl.length, gLvl.length)
      let hW = 0, gW = 0
      for (let i = 0; i < both; i++) {
        if (hLvl[i] > gLvl[i]) hW++
        else if (gLvl[i] > hLvl[i]) gW++
      }
      // Extra levels completed only by the player who stayed (other quit)
      if (g.host_finished) hW += Math.max(0, hLvl.length - both)
      if (g.guest_finished) gW += Math.max(0, gLvl.length - both)

      // Skip if no countable levels at all
      if (hW === 0 && gW === 0 && both === 0) return

      recordDuet(g.host_id, hW, gW)
      recordDuet(g.guest_id, gW, hW)
    }
  })

  const duetAggregated = Object.values(duetMap)
    .sort((a, b) => b.wins - a.wins || a.losses - b.losses)
    .slice(0, 200)

  return (
    <div className="min-h-screen" style={{ background: '#FAFAFA' }}>
      {user && <Header />}
      {!user && (
        <nav className="sticky top-0 z-40 backdrop-blur-xl"
          style={{ background: 'rgba(252,252,252,0.78)', borderBottom: '1px solid rgba(52,52,52,0.06)' }}>
          <div className="max-w-6xl mx-auto px-4 sm:px-6 h-16 flex items-center justify-between">
            <Logo height={28} />
            <Link href="/auth/prijava" className="btn btn-primary btn-sm">Prijava</Link>
          </div>
        </nav>
      )}
      <main className="max-w-3xl mx-auto px-4 sm:px-6 py-10 sm:py-14">
        <div className="text-center mb-10">
          <p className="text-[13px] font-bold uppercase tracking-widest mb-2" style={{ color: '#609DED' }}>
            Najbolji igrači
          </p>
          <h1 className="font-black tracking-tight leading-[1.1]" style={{ color: '#343434', fontSize: 'clamp(32px, 5vw, 48px)' }}>
            Rang lista
          </h1>
        </div>
        <LeaderboardTabs soloData={soloAggregated} duetData={duetAggregated} user={!!user} />
      </main>
    </div>
  )
}
