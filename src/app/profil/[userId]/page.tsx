import { createClient } from '@/lib/supabase/server'
import Header from '@/components/Header'
import Image from 'next/image'
import Link from 'next/link'
import { notFound } from 'next/navigation'
import { IconBack, IconTrophy, IconStar, IconDiscover, IconSwords } from '@/components/icons'

const CATEGORY_COLORS = ['#609DED', '#FFCB46', '#4CAF50', '#E55353', '#BCD9FF']

export default async function PublicProfilPage({ params }: { params: Promise<{ userId: string }> }) {
  const { userId } = await params
  const supabase = await createClient()

  const { data: profile } = await supabase
    .from('profiles').select('*').eq('id', userId).single()

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

  const totalSolo = results?.length || 0
  const totalPoints = results?.reduce((s, r) => s + (r.score_points ?? 0), 0) || 0
  const bestLevel = totalSolo > 0 ? Math.max(...results!.map(r => r.level_reached ?? 0)) : 0

  const categoryMap: Record<string, { count: number; points: number }> = {}
  ;(results || []).forEach(r => {
    const q = Array.isArray(r.quizzes) ? r.quizzes[0] : r.quizzes as { title: string; category?: string } | null
    const cat = q?.category || 'Ostalo'
    if (!categoryMap[cat]) categoryMap[cat] = { count: 0, points: 0 }
    categoryMap[cat].count++
    categoryMap[cat].points += r.score_points ?? 0
  })
  const topCategories = Object.entries(categoryMap).sort((a, b) => b[1].count - a[1].count).slice(0, 5)
  const maxCatCount = topCategories[0]?.[1].count || 1

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
    <div className="min-h-screen" style={{ background: '#FAFAFA' }}>
      <Header />
      <main className="max-w-3xl mx-auto px-4 sm:px-6 py-10 sm:py-14">

        <Link href="/leaderboard"
          className="inline-flex items-center gap-1.5 text-[13px] font-medium mb-6 transition-opacity hover:opacity-70"
          style={{ color: '#609DED' }}>
          <IconBack size={16} strokeWidth={2.2} />
          Rang lista
        </Link>

        {/* Profile card */}
        <div className="card-soft p-6 sm:p-8 mb-6">
          <div className="flex items-center gap-4 sm:gap-5 mb-6">
            <div className="w-20 h-20 rounded-2xl overflow-hidden flex-shrink-0 bg-[#F2F2F2]">
              {profile.avatar
                ? <Image src={`/avatars/${profile.avatar}`} alt={displayName} width={80} height={80} className="w-full h-full object-cover" />
                : <div className="w-full h-full flex items-center justify-center font-black text-[24px]" style={{ background: '#609DED', color: 'white' }}>{initials.toUpperCase()}</div>
              }
            </div>
            <div className="min-w-0 flex-1">
              <h1 className="font-black tracking-tight truncate" style={{ color: '#343434', fontSize: 'clamp(22px, 4vw, 30px)' }}>
                {displayName}
              </h1>
              {profile.nickname && (
                <p className="text-[13px] truncate" style={{ color: '#9C9C9C' }}>{profile.first_name} {profile.last_name}</p>
              )}
              {profile.city && <p className="text-[12px] truncate mt-0.5" style={{ color: '#9C9C9C' }}>📍 {profile.city}</p>}
            </div>
          </div>

          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
            {[
              { Icon: IconDiscover, label: 'Solo igara', value: totalSolo,    bg: '#BCD9FF', fg: '#1e5fa4' },
              { Icon: IconSwords,   label: 'Duet igara', value: totalDuet,    bg: '#FFECBC', fg: '#9c7a13' },
              { Icon: IconStar,     label: 'Bodova',     value: totalPoints,  bg: '#E8F8F0', fg: '#15803d' },
              { Icon: IconTrophy,   label: 'Max nivo',   value: bestLevel,    bg: '#F2F2F2', fg: '#343434' },
            ].map(({ Icon, label, value, bg, fg }) => (
              <div key={label} className="rounded-2xl p-4" style={{ background: bg }}>
                <Icon size={16} strokeWidth={2.2} style={{ color: fg, opacity: 0.7 }} />
                <div className="font-black tracking-tight mt-2" style={{ color: fg, fontSize: 'clamp(20px, 3.5vw, 26px)' }}>{value}</div>
                <div className="text-[11px] font-medium mt-0.5" style={{ color: fg, opacity: 0.7 }}>{label}</div>
              </div>
            ))}
          </div>
        </div>

        <div className="grid sm:grid-cols-2 gap-4 mb-6">
          {/* Categories */}
          {topCategories.length > 0 && (
            <div className="card-soft p-6">
              <h2 className="font-bold text-[15px] mb-4 tracking-tight" style={{ color: '#343434' }}>
                Omiljene kategorije
              </h2>
              <div className="space-y-3">
                {topCategories.map(([cat, data], idx) => (
                  <div key={cat}>
                    <div className="flex justify-between text-[13px] mb-1.5">
                      <span className="font-semibold truncate" style={{ color: '#343434' }}>{cat}</span>
                      <span className="ml-2 flex-shrink-0" style={{ color: '#9C9C9C' }}>{data.count}×</span>
                    </div>
                    <div className="h-2 rounded-full overflow-hidden" style={{ background: '#F2F2F2' }}>
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
            <div className="card-soft p-6">
              <h2 className="font-bold text-[15px] mb-4 tracking-tight" style={{ color: '#343434' }}>
                Solo vs Duet
              </h2>
              <div className="grid grid-cols-2 gap-3 mb-4">
                <div className="text-center p-3 rounded-2xl" style={{ background: '#BCD9FF' }}>
                  <div className="font-black text-[24px]" style={{ color: '#1e5fa4' }}>{totalSolo}</div>
                  <div className="text-[11px] font-medium mt-0.5" style={{ color: '#1e5fa4', opacity: 0.7 }}>Solo</div>
                </div>
                <div className="text-center p-3 rounded-2xl" style={{ background: '#FFECBC' }}>
                  <div className="font-black text-[24px]" style={{ color: '#9c7a13' }}>{totalDuet}</div>
                  <div className="text-[11px] font-medium mt-0.5" style={{ color: '#9c7a13', opacity: 0.7 }}>Duet</div>
                  {totalDuet > 0 && (
                    <div className="text-[10px] mt-1" style={{ color: '#9c7a13', opacity: 0.8 }}>
                      {duetWins}W·{duetDraws}D·{duetLosses}L
                    </div>
                  )}
                </div>
              </div>
              {(totalSolo > 0 && totalDuet > 0) && (
                <>
                  <div className="h-2 rounded-full overflow-hidden flex" style={{ background: '#F2F2F2' }}>
                    <div className="h-full" style={{ width: `${(totalSolo / (totalSolo + totalDuet)) * 100}%`, background: '#609DED' }} />
                    <div className="h-full flex-1" style={{ background: '#FFCB46' }} />
                  </div>
                  <div className="flex justify-between text-[10px] mt-1.5 font-medium" style={{ color: '#9C9C9C' }}>
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
          <div className="card-soft p-6 sm:p-8">
            <h2 className="font-bold text-[18px] mb-5 tracking-tight" style={{ color: '#343434' }}>
              Poslednje igre
            </h2>
            <div className="space-y-1">
              {results.slice(0, 10).map((r, i) => {
                const pts = r.score_points ?? 0
                const lvl = r.level_reached ?? 0
                const q = Array.isArray(r.quizzes) ? r.quizzes[0] : r.quizzes as { title: string } | null
                const accent = pts >= 100 ? '#4CAF50' : pts >= 50 ? '#FFCB46' : '#609DED'
                return (
                  <div key={i} className="flex items-center gap-3 py-3 border-b last:border-0" style={{ borderColor: '#F2F2F2' }}>
                    <div className="w-11 h-11 rounded-2xl flex items-center justify-center font-black text-[13px] flex-shrink-0"
                      style={{ background: accent, color: 'white' }}>
                      {pts > 0 ? `+${pts}` : pts}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="font-semibold text-[14px] truncate tracking-tight" style={{ color: '#343434' }}>{q?.title || 'Kviz'}</p>
                      <p className="text-[12px]" style={{ color: '#9C9C9C' }}>
                        Nivo {lvl} · {r.score}/{r.total} tačnih · {new Date(r.completed_at).toLocaleDateString('sr')}
                      </p>
                    </div>
                  </div>
                )
              })}
            </div>
          </div>
        )}

        {totalSolo === 0 && totalDuet === 0 && (
          <div className="card-soft py-16 text-center">
            <div className="text-5xl mb-4">🎮</div>
            <p className="font-bold text-[17px]" style={{ color: '#343434' }}>Ovaj igrač još nije igrao</p>
          </div>
        )}
      </main>
    </div>
  )
}
