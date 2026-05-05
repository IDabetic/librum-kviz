import { createClient } from '@/lib/supabase/server'
import Header from '@/components/Header'
import { redirect } from 'next/navigation'

export default async function ProfilPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) redirect('/auth/prijava')

  const { data: profile } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', user.id)
    .single()

  const { data: results } = await supabase
    .from('quiz_results')
    .select('score, total, time_taken, completed_at, quizzes(title)')
    .eq('user_id', user.id)
    .order('completed_at', { ascending: false })
    .limit(10)

  const totalPlayed = results?.length || 0
  const avgScore = results && results.length > 0
    ? Math.round(results.reduce((s, r) => s + (r.score / r.total) * 100, 0) / results.length)
    : 0
  const bestScore = results && results.length > 0
    ? Math.max(...results.map(r => Math.round((r.score / r.total) * 100)))
    : 0

  return (
    <div className="min-h-screen bg-[#F5F6FA]">
      <Header />

      <main className="max-w-3xl mx-auto px-4 py-10">
        {/* Profile card */}
        <div className="bg-white rounded-2xl p-8 shadow-sm mb-6">
          <div className="flex items-center gap-5 mb-6">
            <div
              className="w-16 h-16 rounded-2xl flex items-center justify-center text-2xl font-bold text-white flex-shrink-0"
              style={{ background: 'linear-gradient(135deg, #2C2D81, #3766B0)' }}
            >
              {profile?.first_name?.[0]?.toUpperCase()}{profile?.last_name?.[0]?.toUpperCase()}
            </div>
            <div>
              <h1 className="text-2xl font-bold" style={{ color: '#2C2D81' }}>
                {profile?.first_name} {profile?.last_name}
              </h1>
              <p className="text-gray-400 text-sm">{profile?.email}</p>
              {profile?.phone && <p className="text-gray-400 text-sm">{profile.phone}</p>}
            </div>
          </div>

          <div className="grid grid-cols-3 gap-4">
            {[
              { label: 'Odigranih kvizova', value: totalPlayed, color: '#2C2D81', bg: '#EEF0FF' },
              { label: 'Prosečan skor', value: `${avgScore}%`, color: '#5DBF94', bg: '#E8F8F0' },
              { label: 'Najbolji skor', value: `${bestScore}%`, color: '#FDC361', bg: '#FFF8EC' },
            ].map(({ label, value, color, bg }) => (
              <div key={label} className="rounded-xl p-4 text-center" style={{ background: bg }}>
                <div className="text-2xl font-bold mb-0.5" style={{ color }}>{value}</div>
                <div className="text-xs text-gray-500">{label}</div>
              </div>
            ))}
          </div>
        </div>

        {/* History */}
        {results && results.length > 0 && (
          <div className="bg-white rounded-2xl p-6 shadow-sm">
            <h2 className="font-bold text-lg mb-4" style={{ color: '#2C2D81' }}>Istorija igranja</h2>
            <div className="space-y-3">
              {results.map((r, i) => {
                const pct = Math.round((r.score / r.total) * 100)
                return (
                  <div key={i} className="flex items-center gap-4 py-3 border-b border-gray-50 last:border-0">
                    <div
                      className="w-10 h-10 rounded-xl flex items-center justify-center text-sm font-bold text-white flex-shrink-0"
                      style={{ background: pct >= 80 ? '#5DBF94' : pct >= 60 ? '#FDC361' : '#e05252' }}
                    >
                      {pct}%
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="font-medium text-sm text-gray-700 truncate">
                        {(Array.isArray(r.quizzes) ? (r.quizzes as { title: string }[])[0] : r.quizzes as { title: string } | null)?.title || 'Kviz'}
                      </p>
                      <p className="text-xs text-gray-400">
                        {r.score}/{r.total} tačnih · {new Date(r.completed_at).toLocaleDateString('sr')}
                      </p>
                    </div>
                    {r.time_taken && (
                      <span className="text-xs text-gray-400 flex-shrink-0">{r.time_taken}s</span>
                    )}
                  </div>
                )
              })}
            </div>
          </div>
        )}
      </main>
    </div>
  )
}
