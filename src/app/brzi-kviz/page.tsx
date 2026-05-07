import type { Metadata } from 'next'
import { createClient } from '@/lib/supabase/server'
import Header from '@/components/Header'
import Link from 'next/link'
import { redirect } from 'next/navigation'
import { IconStar, IconTime, IconCheck, IconWrong, IconTrophy } from '@/components/icons'

export const metadata: Metadata = {
  title: 'Brzi kviz – tačno ili netačno za 60 sekundi',
  description: 'Igraj Brzi kviz i odgovaraj na tvrdnje sa tačno ili netačno. Imaš 60 sekundi da osvojiš što više bodova i proveriš brzinu znanja.',
  alternates: { canonical: '/brzi-kviz' },
  openGraph: {
    title: 'Brzi kviz – tačno ili netačno | Librum Kviz',
    description: 'Tvrdnje, 60 sekundi, koliko stigneš.',
    url: 'https://kviz.librum.club/brzi-kviz',
    type: 'website',
    images: ['/api/og?v=3'],
  },
}

export default async function BrziKvizLanding() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/auth/prijava?redirect=/brzi-kviz')

  const { data: profile } = await supabase
    .from('profiles').select('first_name').eq('id', user.id).single()

  const { data: best } = await supabase
    .from('quick_sessions')
    .select('score, correct_count, wrong_count, accuracy, total_answered')
    .eq('user_id', user.id)
    .order('score', { ascending: false })
    .limit(1)
    .maybeSingle()

  // today's top
  const startOfDay = new Date()
  startOfDay.setHours(0, 0, 0, 0)
  const { data: todayBest } = await supabase
    .from('quick_sessions')
    .select('score, profiles(first_name, nickname)')
    .gte('created_at', startOfDay.toISOString())
    .order('score', { ascending: false })
    .limit(1)
    .maybeSingle()

  const todayBestName = todayBest
    ? (() => {
        const p = Array.isArray(todayBest.profiles) ? todayBest.profiles[0] : todayBest.profiles as { first_name: string; nickname: string } | null
        return p?.nickname || p?.first_name || 'Igrač'
      })()
    : null

  return (
    <div className="min-h-screen" style={{ background: '#FAFAFA' }}>
      <Header />
      <main className="max-w-2xl mx-auto px-4 sm:px-6 py-10 sm:py-14">

        <div className="text-center mb-8">
          <p className="text-[13px] font-bold uppercase tracking-widest mb-2" style={{ color: '#609DED' }}>
            Brzi kviz
          </p>
          <h1 className="font-black tracking-tight leading-[1.05] mb-3"
            style={{ color: '#343434', fontSize: 'clamp(40px, 8vw, 64px)' }}>
            60 sekundi.
          </h1>
          <p className="text-[15px] sm:text-[17px] leading-relaxed" style={{ color: '#9C9C9C' }}>
            Tačno ili netačno? Brzo razmišljaj —<br />za jedan minut osvoji što više bodova.
          </p>
        </div>

        {/* Personal best */}
        {best && best.score > 0 ? (
          <div className="card-soft p-5 mb-4">
            <div className="flex items-center gap-3 mb-3">
              <div className="w-10 h-10 rounded-2xl flex items-center justify-center flex-shrink-0" style={{ background: '#FFECBC' }}>
                <IconTrophy size={20} className="text-[#9c7a13]" strokeWidth={2.2} />
              </div>
              <p className="font-bold text-[15px] tracking-tight" style={{ color: '#343434' }}>Tvoj rekord</p>
            </div>
            <div className="grid grid-cols-4 gap-2">
              {[
                { label: 'Bodovi',  value: best.score },
                { label: 'Tačno',   value: best.correct_count },
                { label: 'Pogr.',   value: best.wrong_count },
                { label: 'Tačnost', value: `${Math.round(Number(best.accuracy))}%` },
              ].map(({ label, value }) => (
                <div key={label} className="rounded-xl p-2.5 text-center" style={{ background: '#F2F2F2' }}>
                  <div className="font-black text-[15px] tracking-tight" style={{ color: '#343434' }}>{value}</div>
                  <div className="text-[10px] mt-0.5" style={{ color: '#9C9C9C' }}>{label}</div>
                </div>
              ))}
            </div>
          </div>
        ) : (
          <div className="card-soft p-5 mb-4 flex items-center gap-3">
            <div className="w-10 h-10 rounded-2xl flex items-center justify-center flex-shrink-0" style={{ background: '#BCD9FF' }}>
              <IconStar size={20} className="text-[#1e5fa4]" strokeWidth={2.2} />
            </div>
            <p className="text-[14px]" style={{ color: '#343434' }}>
              Još nemaš rezultat. <strong>Imaš 60 sekundi.</strong>
            </p>
          </div>
        )}

        {/* Today top */}
        {todayBest && todayBest.score > 0 && todayBestName && (
          <div className="card-soft p-4 mb-5 text-center" style={{ background: '#FFECBC', borderColor: 'rgba(255,203,70,0.4)' }}>
            <p className="text-[13px] font-medium" style={{ color: '#9c7a13' }}>
              ⚡ Danas u vrhu: <strong>{todayBestName}</strong> sa <strong>{todayBest.score} bodova</strong>. Možeš li bolje?
            </p>
          </div>
        )}

        {/* Rules */}
        <div className="card-soft p-7 sm:p-8 mb-5">
          <h2 className="font-bold text-[16px] mb-5 tracking-tight" style={{ color: '#343434' }}>
            Pravila
          </h2>
          <div className="space-y-3.5">
            <Rule color="#BCD9FF" fg="#1e5fa4" Icon={IconTime}>
              Imaš <strong>60 sekundi</strong>. Svaka tvrdnja mora da se reši u <strong>10 sekundi</strong> ili kraće.
            </Rule>
            <Rule color="#E8F8F0" fg="#15803d" Icon={IconCheck}>
              Tačno → <strong>+10 bodova</strong>. Brzo razmišljanje = više pitanja.
            </Rule>
            <Rule color="#FEE2E2" fg="#b91c1c" Icon={IconWrong}>
              Pogrešno ili istek vremena → <strong>-5 bodova</strong>. Bodovi ne idu ispod nule.
            </Rule>
          </div>
        </div>

        <Link href="/brzi-kviz/start" className="btn btn-primary btn-lg w-full">
          Kreni — 60 sekundi
        </Link>

        <p className="text-center text-[11px] mt-5" style={{ color: '#9C9C9C' }}>
          {profile?.first_name ? `Spreman/na, ${profile.first_name}?` : 'Spreman/na?'}
        </p>
      </main>
    </div>
  )
}

function Rule({ color, fg, Icon, children }: {
  color: string; fg: string
  Icon: React.ComponentType<{ size?: number; strokeWidth?: number; className?: string }>
  children: React.ReactNode
}) {
  return (
    <div className="flex items-start gap-3">
      <div className="w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0" style={{ background: color }}>
        <Icon size={16} className={`text-[${fg}]`} strokeWidth={2.2} />
      </div>
      <p className="text-[14px] leading-relaxed pt-1" style={{ color: '#343434' }}>{children}</p>
    </div>
  )
}
