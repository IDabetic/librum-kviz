import { createClient } from '@/lib/supabase/server'
import Header from '@/components/Header'
import Image from 'next/image'
import Link from 'next/link'
import { notFound } from 'next/navigation'

const CATEGORY_COLORS = ['#2C2D81', '#3766B0', '#5DBF94', '#FDC361', '#e05252']

export default async function PublicProfilPage({ params }: { params: Promise<{ userId: string }> }) {
  const { userId } = await params
  const supabase = await createClient()

  const { data: profile } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', userId)
    .single()

  if (!profile) notFound()

  const { data: results } = await supabase
    .from('quiz_results')
    .select('score_points, level_reached, completed_at, score, total, quizzes(title, category)')
    .eq('user_id', userId)
    .gt('level_reached', 0)
    .order('completed_at', { ascending: false })
    .limit(50)

  const { data: duetGames } = await supabase
    .from('game_rooms')
    .select('host_id, guest_id, host_score, guest_score, host_finished, guest_finished, host_level_scores, guest_level_scores, game_format')
    .or(`host_id.eq.${userId},guest_id.eq.${userId}`)
    .or('host_finished.eq.true,guest_finished.eq.true')
    .not('guest_id', 'is', null)

  // Solo stats
  const totalSolo = results?.length || 0
  const totalPoints = results?.reduce((s, r) => s + (r.score_points ?? 0), 0) || 0
  const bestLevel = totalSolo > 0 ? Math.max(...results!.map(r => r.level_reached ?? 0)) : 0

  // Category breakdown
  const categoryMap: Record<string, { count: number; points: number }> = {}
  ;(results || []).forEach(r => {
    const q = Array.isArray(r.quizzes) ? r.quizzes[0] : r.quizzes as { title: string; category?: string } | null
    const cat = q?.category || 'Ostalo'
    if (!categoryMap[cat]) categoryMap[cat] = { count: 0, points: 0 }
    categoryMap[cat].count++
    categoryMap[cat].points += r.score_points ?? 0
  })
  const topCategories = Object.entries(categoryMap)
    .sort((a, b) => b[1].count - a[1].count)
    .slice(0, 5)
  const maxCatCount = topCategories[0]?.[1].count || 1

  // Duet stats
  const totalDuet = (duetGames || []).length
  let duetWins = 0, duetLosses = 0, duetDraws = 0
  ;(duetGames || []).forEach(g => {
    const isHost = g.host_id === userId
    const isTimed = (g.game_format ?? '').startsWith('time_')
    if (isTimed) {
      if (!g.host_finished || !g.guest_finished) return
      const my = isHost ? (g.host_score ?? 0) : (g.guest_score ?? 0)
      const op = isHost ? (g.guest_score ?? 0) : (g.host_score ?? 0)
      if (my > op) duetWins++
      else if (my < op) duetLosses++
      else duetDraws++
    } else {
      const hLvl: number[] = (g.host_level_scores as number[]) ?? []
      const gLvl: number[] = (g.guest_level_scores as number[]) ?? []
      const myLvl = isHost ? hLvl : gLvl
      const opLvl = isHost ? gLvl : hLvl
      const both = Math.min(myLvl.length, opLvl.length)
      let myW = 0, opW = 0
      for (let i = 0; i < both; i++) {
        if (myLvl[i] > opLvl[i]) myW++
        else if (opLvl[i] > myLvl[i]) opW++
      }
      if (isHost && g.host_finished) myW += Math.max(0, myLvl.length - both)
      if (!isHost && g.guest_finished) myW += Math.max(0, myLvl.length - both)
      if (myW === 0 && opW === 0 && both === 0) return
      if (myW > opW) duetWins++
      else if (myW < opW) duetLosses++
      else duetDraws++
    }
  })

  const displayName = profile.nickname || `${profile.first_name || ''} ${profile.last_name || ''}`.trim() || 'Igrač'
  const initials = (profile.first_name?.[0] || '') + (profile.last_name?.[0] || '') || displayName[0]

  return (
    <div className="min-h-screen bg-[#FAF4EC]">
      <Header />
      <main className="max-w-3xl mx-auto px-4 py-10">

        <div className="flex items-center gap-2 mb-6">
          <Link href="/leaderboard" className="flex items-center gap-1.5 text-sm font-medium px-3 py-1.5 rounded-xl transition-colors hover:bg-white"
            style={{ color: '#6b7280' }}>
            ← Rang lista
          </Link>
        </div>

        {/* Profile card */}
        <div className="bg-white rounded-2xl p-8 shadow-sm mb-6">
          <div className="flex items-center gap-5 mb-6">
            <div className="w-20 h-20 rounded-2xl overflow-hidden flex-shrink-0 shadow-sm">
              {profile.avatar
                ? <Image src={`/avatars/${profile.avatar}`} alt={displayName} width={80} height={80} className="w-full h-full object-cover" />
                : <div className="w-full h-full flex items-center justify-center text-2xl font-bold text-white" style={{ background: 'linear-gradient(135deg, #2C2D81, #3766B0)' }}>{initials.toUpperCase()}</div>
              }
            </div>
            <div>
              <h1 className="text-2xl font-bold" style={{ color: '#2C2D81' }}>{displayName}</h1>
              {profile.nickname && (
                <p className="text-gray-500 text-sm">{profile.first_name} {profile.last_name}</p>
              )}
              {profile.city && <p className="text-gray-400 text-sm mt-0.5">📍 {profile.city}</p>}
            </div>
          </div>

          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
            {[
              { label: 'Solo igara', value: totalSolo, color: '#2C2D81', bg: '#EEF0FF' },
              { label: 'Duet igara', value: totalDuet, color: '#3766B0', bg: '#EEF5FF' },
              { label: 'Ukupno bod.', value: totalPoints, color: '#FDC361', bg: '#FFF9EC' },
              { label: 'Max nivo', value: bestLevel, color: '#5DBF94', bg: '#E8F8F0' },
            ].map(({ label, value, color, bg }) => (
              <div key={label} className="rounded-xl p-4 text-center" style={{ background: bg }}>
                <div className="text-2xl font-black mb-0.5" style={{ color }}>{value}</div>
                <div className="text-xs text-gray-500">{label}</div>
              </div>
            ))}
          </div>
        </div>

        <div className="grid sm:grid-cols-2 gap-6 mb-6">
          {/* Category breakdown */}
          {topCategories.length > 0 && (
            <div className="bg-white rounded-2xl p-6 shadow-sm">
              <h2 className="font-bold text-base mb-4" style={{ color: '#2C2D81' }}>📂 Omiljene kategorije</h2>
              <div className="space-y-3">
                {topCategories.map(([cat, data], idx) => (
                  <div key={cat}>
                    <div className="flex justify-between text-sm mb-1">
                      <span className="font-medium text-gray-700 truncate">{cat}</span>
                      <span className="text-gray-400 ml-2 flex-shrink-0">{data.count}×</span>
                    </div>
                    <div className="h-2 rounded-full bg-gray-100 overflow-hidden">
                      <div className="h-full rounded-full transition-all"
                        style={{ width: `${(data.count / maxCatCount) * 100}%`, background: CATEGORY_COLORS[idx % CATEGORY_COLORS.length] }} />
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Solo vs Duet */}
          {(totalSolo > 0 || totalDuet > 0) && (
            <div className="bg-white rounded-2xl p-6 shadow-sm">
              <h2 className="font-bold text-base mb-4" style={{ color: '#2C2D81' }}>🎯 Solo vs ⚔️ Duet</h2>
              <div className="grid grid-cols-2 gap-3 mb-4">
                <div className="text-center p-3 rounded-xl" style={{ background: '#EEF0FF' }}>
                  <div className="text-2xl font-black" style={{ color: '#2C2D81' }}>{totalSolo}</div>
                  <div className="text-xs text-gray-500 mt-0.5">Solo igara</div>
                </div>
                <div className="text-center p-3 rounded-xl" style={{ background: '#E8F8F0' }}>
                  <div className="text-2xl font-black" style={{ color: '#5DBF94' }}>{totalDuet}</div>
                  <div className="text-xs text-gray-500 mt-0.5">Duet igara</div>
                  {totalDuet > 0 && (
                    <div className="text-xs mt-0.5" style={{ color: '#5DBF94' }}>{duetWins}W · {duetDraws}D · {duetLosses}L</div>
                  )}
                </div>
              </div>
              {(totalSolo > 0 && totalDuet > 0) && (
                <>
                  <div className="h-2.5 rounded-full overflow-hidden flex">
                    <div className="h-full" style={{ width: `${(totalSolo / (totalSolo + totalDuet)) * 100}%`, background: '#2C2D81' }} />
                    <div className="h-full flex-1" style={{ background: '#5DBF94' }} />
                  </div>
                  <div className="flex justify-between text-xs text-gray-400 mt-1">
                    <span>Solo {Math.round((totalSolo / (totalSolo + totalDuet)) * 100)}%</span>
                    <span>Duet {Math.round((totalDuet / (totalSolo + totalDuet)) * 100)}%</span>
                  </div>
                </>
              )}
            </div>
          )}
        </div>

        {/* Recent games */}
        {results && results.length > 0 && (
          <div className="bg-white rounded-2xl p-6 shadow-sm">
            <h2 className="font-bold text-base mb-4" style={{ color: '#2C2D81' }}>Poslednje igre</h2>
            <div className="space-y-1">
              {results.slice(0, 10).map((r, i) => {
                const pts = r.score_points ?? 0
                const lvl = r.level_reached ?? 0
                const q = Array.isArray(r.quizzes) ? r.quizzes[0] : r.quizzes as { title: string } | null
                return (
                  <div key={i} className="flex items-center gap-3 py-3 border-b border-gray-50 last:border-0">
                    <div className="w-10 h-10 rounded-xl flex items-center justify-center text-xs font-bold text-white flex-shrink-0"
                      style={{ background: pts >= 100 ? 'linear-gradient(135deg, #5DBF94, #3ea87a)' : pts >= 50 ? 'linear-gradient(135deg, #FDC361, #e8a800)' : 'linear-gradient(135deg, #3766B0, #2C2D81)' }}>
                      {pts > 0 ? `+${pts}` : pts}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="font-semibold text-sm text-gray-700 truncate">{q?.title || 'Kviz'}</p>
                      <p className="text-xs text-gray-400">Nivo {lvl} · {r.score}/{r.total} tačnih · {new Date(r.completed_at).toLocaleDateString('sr')}</p>
                    </div>
                  </div>
                )
              })}
            </div>
          </div>
        )}

        {totalSolo === 0 && totalDuet === 0 && (
          <div className="text-center py-16 bg-white rounded-2xl shadow-sm">
            <div className="text-5xl mb-4">🎮</div>
            <p className="text-lg font-medium text-gray-600">Ovaj igrač još nije igrao</p>
          </div>
        )}
      </main>
    </div>
  )
}
