import { createClient } from '@/lib/supabase/server'
import Header from '@/components/Header'
import Link from 'next/link'
import LeaderboardTabs from './LeaderboardTabs'

export default async function LeaderboardPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  // Solo: aggregate score_points and level_reached per player
  const { data: results } = await supabase
    .from('quiz_results')
    .select('user_id, score_points, level_reached, profiles(first_name, last_name)')
    .gt('level_reached', 0)  // only count games where at least 1 level was completed
    .order('score_points', { ascending: false })
    .limit(200)

  const soloMap: Record<string, { name: string; totalPoints: number; bestLevel: number; plays: number }> = {}
  ;(results || []).forEach(r => {
    const uid = r.user_id
    const prof = Array.isArray(r.profiles) ? r.profiles[0] : r.profiles as { first_name: string; last_name: string } | null
    const name = prof ? `${prof.first_name} ${prof.last_name}` : 'Igrač'
    if (!soloMap[uid]) soloMap[uid] = { name, totalPoints: 0, bestLevel: 0, plays: 0 }
    soloMap[uid].totalPoints += r.score_points ?? 0
    soloMap[uid].bestLevel = Math.max(soloMap[uid].bestLevel, r.level_reached ?? 0)
    soloMap[uid].plays++
  })

  const soloAggregated = Object.values(soloMap)
    .sort((a, b) => b.totalPoints - a.totalPoints || b.bestLevel - a.bestLevel)
    .slice(0, 10)

  // Duet: from finished game_rooms
  const { data: finishedGames } = await supabase
    .from('game_rooms')
    .select('host_id, guest_id, host_score, guest_score')
    .eq('status', 'finished')
    .limit(100)

  const userIds = [...new Set(
    (finishedGames || []).flatMap(g => [g.host_id, g.guest_id]).filter(Boolean)
  )] as string[]

  const profileMap: Record<string, string> = {}
  if (userIds.length > 0) {
    const { data: profileData } = await supabase
      .from('profiles').select('id, first_name, last_name').in('id', userIds)
    ;(profileData || []).forEach((p: { id: string; first_name: string; last_name: string }) => {
      profileMap[p.id] = `${p.first_name} ${p.last_name}`
    })
  }

  const duetMap: Record<string, { name: string; wins: number; losses: number; draws: number; plays: number }> = {}
  function addDuet(uid: string, myScore: number, opScore: number) {
    const name = profileMap[uid] || 'Igrač'
    if (!duetMap[uid]) duetMap[uid] = { name, wins: 0, losses: 0, draws: 0, plays: 0 }
    duetMap[uid].plays++
    if (myScore > opScore) duetMap[uid].wins++
    else if (myScore < opScore) duetMap[uid].losses++
    else duetMap[uid].draws++
  }
  ;(finishedGames || []).forEach(g => {
    if (g.host_id) addDuet(g.host_id, g.host_score, g.guest_score)
    if (g.guest_id) addDuet(g.guest_id, g.guest_score, g.host_score)
  })

  const duetAggregated = Object.values(duetMap)
    .sort((a, b) => b.wins - a.wins || a.losses - b.losses)
    .slice(0, 10)

  return (
    <div className="min-h-screen bg-[#FAF4EC]">
      {user && <Header />}
      {!user && (
        <nav className="bg-white border-b border-gray-100 px-6 py-4 flex items-center justify-between max-w-6xl mx-auto">
          <Link href="/" className="font-bold text-xl" style={{ color: '#2C2D81' }}>Librum kviz</Link>
          <Link href="/auth/prijava" className="text-sm font-medium px-4 py-2 rounded-lg text-white"
            style={{ background: '#2C2D81' }}>Prijava</Link>
        </nav>
      )}
      <main className="max-w-3xl mx-auto px-4 py-10">
        <div className="text-center mb-10">
          <h1 className="text-4xl font-bold mb-2" style={{ color: '#2C2D81' }}>🏆 Rang lista</h1>
          <p className="text-gray-500">Najbolji igrači Librum kviz platforme</p>
        </div>
        <LeaderboardTabs soloData={soloAggregated} duetData={duetAggregated} user={!!user} />
      </main>
    </div>
  )
}
