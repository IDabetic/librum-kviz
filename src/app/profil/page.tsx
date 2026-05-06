import { createClient } from '@/lib/supabase/server'
import Header from '@/components/Header'
import Link from 'next/link'
import Image from 'next/image'
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
    .select('score, total, time_taken, completed_at, score_points, level_reached, quizzes(title)')
    .eq('user_id', user.id)
    .order('completed_at', { ascending: false })
    .limit(20)

  const totalPlayed = results?.length || 0
  const totalPoints = results?.reduce((s, r) => s + (r.score_points ?? 0), 0) || 0
  const bestPoints = results && results.length > 0
    ? Math.max(...results.map(r => r.score_points ?? 0))
    : 0
  const bestLevel = results && results.length > 0
    ? Math.max(...results.map(r => r.level_reached ?? 0))
    : 0

  const displayName = profile?.nickname || `${profile?.first_name || ''} ${profile?.last_name || ''}`.trim() || 'Igrač'
  const initials = (profile?.first_name?.[0] || '') + (profile?.last_name?.[0] || '') || displayName[0]

  return (
    <div className="min-h-screen bg-[#FAF4EC]">
      <Header />
      <main className="max-w-3xl mx-auto px-4 py-10">

        {/* Profile card */}
        <div className="bg-white rounded-2xl p-8 shadow-sm mb-6">
          <div className="flex items-center justify-between mb-6">
            <div className="flex items-center gap-5">
              <div className="w-16 h-16 rounded-2xl overflow-hidden flex-shrink-0 shadow-sm">
                {profile?.avatar
                  ? <Image src={`/avatars/${profile.avatar}`} alt="Avatar" width={64} height={64} className="w-full h-full object-cover" />
                  : <div className="w-full h-full flex items-center justify-center text-2xl font-bold text-white" style={{ background: 'linear-gradient(135deg, #2C2D81, #3766B0)' }}>{initials.toUpperCase()}</div>
                }
              </div>
              <div>
                <h1 className="text-2xl font-bold" style={{ color: '#2C2D81' }}>{displayName}</h1>
                {profile?.nickname && (
                  <p className="text-gray-500 text-sm">{profile.first_name} {profile.last_name}</p>
                )}
                <p className="text-gray-400 text-sm">{profile?.email}</p>
                {profile?.city && <p className="text-gray-400 text-sm">📍 {profile.city}</p>}
              </div>
            </div>
            <Link href="/profil/podesavanja"
              className="flex items-center gap-1.5 px-4 py-2 rounded-xl text-sm font-semibold transition-all hover:scale-[1.02]"
              style={{ background: '#EEF0FF', color: '#2C2D81' }}>
              <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round">
                <circle cx="7" cy="7" r="2.5" />
                <path d="M7 1v1.5M7 11.5V13M1 7h1.5M11.5 7H13M2.6 2.6l1 1M10.4 10.4l1 1M10.4 2.6l1-1M2.6 11.4l-1 1" />
              </svg>
              Podešavanja
            </Link>
          </div>

          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
            {[
              { label: 'Odigrano', value: totalPlayed, color: '#2C2D81', bg: '#EEF0FF', suffix: '' },
              { label: 'Ukupno bod.', value: totalPoints, color: '#3766B0', bg: '#EEF5FF', suffix: '' },
              { label: 'Rekord', value: bestPoints, color: '#FDC361', bg: '#FFF9EC', suffix: ' bod' },
              { label: 'Max nivo', value: bestLevel, color: '#5DBF94', bg: '#E8F8F0', suffix: '' },
            ].map(({ label, value, color, bg, suffix }) => (
              <div key={label} className="rounded-xl p-4 text-center" style={{ background: bg }}>
                <div className="text-2xl font-black mb-0.5" style={{ color }}>{value}{suffix}</div>
                <div className="text-xs text-gray-500">{label}</div>
              </div>
            ))}
          </div>
        </div>

        {/* History */}
        {results && results.length > 0 && (
          <div className="bg-white rounded-2xl p-6 shadow-sm">
            <h2 className="font-bold text-lg mb-4" style={{ color: '#2C2D81' }}>Istorija igranja</h2>
            <div className="space-y-2">
              {results.map((r, i) => {
                const pts = r.score_points ?? 0
                const lvl = r.level_reached ?? 0
                const quizTitle = (Array.isArray(r.quizzes) ? (r.quizzes as { title: string }[])[0] : r.quizzes as { title: string } | null)?.title || 'Kviz'
                return (
                  <div key={i} className="flex items-center gap-4 py-3 border-b border-gray-50 last:border-0">
                    <div className="w-11 h-11 rounded-xl flex items-center justify-center text-sm font-bold text-white flex-shrink-0"
                      style={{ background: pts >= 100 ? 'linear-gradient(135deg, #5DBF94, #3ea87a)' : pts >= 50 ? 'linear-gradient(135deg, #FDC361, #e8a800)' : 'linear-gradient(135deg, #3766B0, #2C2D81)' }}>
                      {pts > 0 ? `+${pts}` : pts}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="font-semibold text-sm text-gray-700 truncate">{quizTitle}</p>
                      <p className="text-xs text-gray-400">
                        Nivo {lvl} · {r.score}/{r.total} tačnih · {new Date(r.completed_at).toLocaleDateString('sr')}
                      </p>
                    </div>
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
