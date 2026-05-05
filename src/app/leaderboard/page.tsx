import { createClient } from '@/lib/supabase/server'
import Header from '@/components/Header'
import Link from 'next/link'

export default async function LeaderboardPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  const { data: quizzes } = await supabase
    .from('quizzes')
    .select('id, title')
    .order('plays', { ascending: false })

  const firstQuizId = quizzes?.[0]?.id

  const { data: topPlayers } = await supabase
    .from('quiz_results')
    .select('user_id, score, total, time_taken, profiles(first_name, last_name)')
    .order('score', { ascending: false })
    .order('time_taken', { ascending: true })
    .limit(20)

  const aggregated = topPlayers
    ? Object.values(
        topPlayers.reduce((acc: Record<string, { name: string; wins: number; total: number; time: number; plays: number }>, r) => {
          const uid = r.user_id
          const prof = Array.isArray(r.profiles) ? r.profiles[0] : r.profiles as { first_name: string; last_name: string } | null
          const name = prof ? `${prof.first_name} ${prof.last_name}` : 'Igrač'
          if (!acc[uid]) acc[uid] = { name, wins: 0, total: 0, time: 0, plays: 0 }
          acc[uid].wins += r.score
          acc[uid].total += r.total
          acc[uid].time += r.time_taken || 0
          acc[uid].plays++
          return acc
        }, {})
      )
        .map(p => ({ ...p, pct: Math.round((p.wins / p.total) * 100) }))
        .sort((a, b) => b.pct - a.pct || a.time - b.time)
        .slice(0, 10)
    : []

  const MEDALS = ['🥇', '🥈', '🥉']

  return (
    <div className="min-h-screen bg-[#F5F6FA]">
      {user && <Header />}
      {!user && (
        <nav className="bg-white border-b border-gray-100 px-6 py-4 flex items-center justify-between max-w-6xl mx-auto">
          <Link href="/" className="font-bold text-xl" style={{ color: '#2C2D81' }}>Librum kviz</Link>
          <Link href="/auth/prijava" className="text-sm font-medium px-4 py-2 rounded-lg text-white" style={{ background: '#2C2D81' }}>Prijava</Link>
        </nav>
      )}

      <main className="max-w-3xl mx-auto px-4 py-10">
        <div className="text-center mb-10">
          <h1 className="text-4xl font-bold mb-2" style={{ color: '#2C2D81' }}>🏆 Rang lista</h1>
          <p className="text-gray-500">Najbolji igrači Librum kviz platforme</p>
        </div>

        {aggregated.length === 0 ? (
          <div className="text-center py-20 bg-white rounded-2xl shadow-sm">
            <div className="text-5xl mb-4">🏆</div>
            <p className="text-lg font-medium text-gray-600">Rang lista je prazna</p>
            <p className="text-sm text-gray-400 mt-1 mb-6">Budite prvi koji će igrati!</p>
            {user ? (
              <Link href="/kvizovi" className="inline-flex px-6 py-3 rounded-xl font-bold text-white" style={{ background: '#2C2D81' }}>
                Idi na kvizove
              </Link>
            ) : (
              <Link href="/auth/registracija" className="inline-flex px-6 py-3 rounded-xl font-bold text-white" style={{ background: '#5DBF94' }}>
                Registruj se besplatno
              </Link>
            )}
          </div>
        ) : (
          <div className="bg-white rounded-2xl shadow-sm overflow-hidden">
            {/* Top 3 podium */}
            {aggregated.length >= 3 && (
              <div className="p-6 border-b border-gray-50" style={{ background: 'linear-gradient(135deg, #2C2D81 0%, #3766B0 100%)' }}>
                <div className="flex items-end justify-center gap-4">
                  {[1, 0, 2].map((i) => {
                    const p = aggregated[i]
                    if (!p) return null
                    const heights = [24, 32, 20]
                    return (
                      <div key={i} className="text-center flex-1 max-w-[120px]">
                        <div className="text-2xl mb-1">{MEDALS[i]}</div>
                        <div className="text-white font-bold text-sm truncate">{p.name.split(' ')[0]}</div>
                        <div className="text-white/70 text-xs mb-2">{p.pct}%</div>
                        <div
                          className="rounded-t-xl flex items-end justify-center pb-2"
                          style={{ height: heights[i] * 3, background: 'rgba(255,255,255,0.15)' }}
                        >
                          <span className="text-white font-black text-xl">{i + 1}</span>
                        </div>
                      </div>
                    )
                  })}
                </div>
              </div>
            )}

            {/* Full list */}
            <div className="divide-y divide-gray-50">
              {aggregated.map((p, i) => (
                <div key={i} className="flex items-center gap-4 px-6 py-4">
                  <span className="w-8 text-center text-lg">
                    {i < 3 ? MEDALS[i] : <span className="text-sm font-bold text-gray-400">{i + 1}</span>}
                  </span>
                  <div
                    className="w-9 h-9 rounded-xl flex items-center justify-center text-sm font-bold text-white flex-shrink-0"
                    style={{ background: 'linear-gradient(135deg, #2C2D81, #3766B0)' }}
                  >
                    {p.name[0]}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="font-semibold text-sm text-gray-800">{p.name}</p>
                    <p className="text-xs text-gray-400">{p.plays} {p.plays === 1 ? 'kviz' : 'kvizova'}</p>
                  </div>
                  <div className="text-right">
                    <div className="font-bold text-lg" style={{ color: i === 0 ? '#FDC361' : i === 1 ? '#3766B0' : i === 2 ? '#c08a4a' : '#5DBF94' }}>
                      {p.pct}%
                    </div>
                    <div className="text-xs text-gray-400">{p.wins}/{p.total}</div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}
      </main>
    </div>
  )
}
