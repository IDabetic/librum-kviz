import { createClient } from '@/lib/supabase/server'
import Header from '@/components/Header'
import Link from 'next/link'
import Image from 'next/image'
import { redirect } from 'next/navigation'
import { IconSettings, IconTrophy, IconStar, IconTime, IconDiscover } from '@/components/icons'

function fmtTime(s: number): string {
  const m = Math.floor(s / 60)
  const sec = s % 60
  return `${String(m).padStart(2, '0')}:${String(sec).padStart(2, '0')}`
}

export default async function ProfilPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/auth/prijava')

  const { data: profile } = await supabase
    .from('profiles').select('*').eq('id', user.id).single()

  const { data: sessions } = await supabase
    .from('survivor_sessions')
    .select('score, questions_reached, correct_answers, wrong_answers, best_combo, total_time_seconds, created_at')
    .eq('user_id', user.id)
    .order('created_at', { ascending: false })
    .limit(20)

  const totalGames = sessions?.length || 0
  const bestScore = totalGames > 0 ? Math.max(...sessions!.map(s => s.score)) : 0
  const bestQuestions = totalGames > 0 ? Math.max(...sessions!.map(s => s.questions_reached)) : 0
  const bestCombo = totalGames > 0 ? Math.max(...sessions!.map(s => s.best_combo)) : 0

  const displayName = profile?.nickname || `${profile?.first_name || ''} ${profile?.last_name || ''}`.trim() || 'Igrač'
  const initials = (profile?.first_name?.[0] || '') + (profile?.last_name?.[0] || '') || displayName[0]

  return (
    <div className="min-h-screen" style={{ background: '#FAFAFA' }}>
      <Header />
      <main className="max-w-3xl mx-auto px-4 sm:px-6 py-10 sm:py-14">

        <div className="card-soft p-6 sm:p-8 mb-6">
          <div className="flex items-start sm:items-center justify-between gap-4 mb-7 flex-wrap">
            <div className="flex items-center gap-4 sm:gap-5 flex-1 min-w-0">
              <div className="w-16 h-16 sm:w-20 sm:h-20 rounded-2xl overflow-hidden flex-shrink-0 bg-[#F2F2F2]">
                {profile?.avatar
                  ? <Image src={`/avatars/${profile.avatar}`} alt="Avatar" width={80} height={80} className="w-full h-full object-cover" />
                  : <div className="w-full h-full flex items-center justify-center font-black text-[24px]" style={{ background: '#609DED', color: 'white' }}>{initials.toUpperCase()}</div>}
              </div>
              <div className="min-w-0 flex-1">
                <h1 className="font-black tracking-tight truncate" style={{ color: '#343434', fontSize: 'clamp(22px, 4vw, 30px)' }}>
                  {displayName}
                </h1>
                {profile?.nickname && (
                  <p className="text-[13px] truncate" style={{ color: '#9C9C9C' }}>{profile.first_name} {profile.last_name}</p>
                )}
                <p className="text-[12px] truncate" style={{ color: '#9C9C9C' }}>{profile?.email}</p>
                {profile?.city && <p className="text-[12px] truncate" style={{ color: '#9C9C9C' }}>📍 {profile.city}</p>}
              </div>
            </div>
            <Link href="/profil/podesavanja" className="btn btn-secondary btn-sm flex-shrink-0">
              <IconSettings size={14} strokeWidth={2.2} />
              Podešavanja
            </Link>
          </div>

          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
            {[
              { Icon: IconDiscover, label: 'Igara',          value: totalGames,    bg: '#BCD9FF', fg: '#1e5fa4' },
              { Icon: IconStar,     label: 'Rekord bodova',  value: bestScore,     bg: '#FFECBC', fg: '#9c7a13' },
              { Icon: IconTrophy,   label: 'Rekord pitanja', value: bestQuestions, bg: '#E8F8F0', fg: '#15803d' },
              { Icon: IconTime,     label: 'Najduži niz',    value: bestCombo,     bg: '#F2F2F2', fg: '#343434' },
            ].map(({ Icon, label, value, bg, fg }) => (
              <div key={label} className="rounded-2xl p-4" style={{ background: bg }}>
                <Icon size={16} className="mb-2" strokeWidth={2.2} style={{ color: fg, opacity: 0.7 }} />
                <div className="font-black tracking-tight" style={{ color: fg, fontSize: 'clamp(20px, 3.5vw, 26px)' }}>{value}</div>
                <div className="text-[11px] font-medium mt-0.5" style={{ color: fg, opacity: 0.7 }}>{label}</div>
              </div>
            ))}
          </div>
        </div>

        {sessions && sessions.length > 0 ? (
          <div className="card-soft p-6 sm:p-8">
            <h2 className="font-bold text-[18px] mb-5 tracking-tight" style={{ color: '#343434' }}>
              Istorija igranja
            </h2>
            <div className="space-y-1">
              {sessions.map((r, i) => {
                const accent = r.score >= 1000 ? '#4CAF50' : r.score >= 500 ? '#FFCB46' : '#609DED'
                return (
                  <div key={i} className="flex items-center gap-3 py-3 border-b last:border-0" style={{ borderColor: '#F2F2F2' }}>
                    <div className="w-11 h-11 rounded-2xl flex items-center justify-center font-black text-[12px] flex-shrink-0"
                      style={{ background: accent, color: 'white' }}>
                      {r.score}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="font-semibold text-[14px] tracking-tight" style={{ color: '#343434' }}>
                        {r.questions_reached} pitanja
                      </p>
                      <p className="text-[12px]" style={{ color: '#9C9C9C' }}>
                        {r.correct_answers}/{r.correct_answers + r.wrong_answers} tačnih · niz {r.best_combo} · {fmtTime(r.total_time_seconds)} · {new Date(r.created_at).toLocaleDateString('sr')}
                      </p>
                    </div>
                  </div>
                )
              })}
            </div>
          </div>
        ) : (
          <div className="card-soft p-10 text-center">
            <p className="font-bold text-[17px] mb-2" style={{ color: '#343434' }}>Još nisi igrao</p>
            <p className="text-[14px] mb-6" style={{ color: '#9C9C9C' }}>Kreni odmah — 10 života te čeka.</p>
            <Link href="/igraj" className="btn btn-primary btn-md">Igraj</Link>
          </div>
        )}
      </main>
    </div>
  )
}
