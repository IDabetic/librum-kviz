import { createClient } from '@/lib/supabase/server'
import Header from '@/components/Header'
import Link from 'next/link'
import { redirect } from 'next/navigation'
import { IconHint, IconTime, IconStar, IconTrophy } from '@/components/icons'

export default async function IgrajLandingPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/auth/prijava?redirect=/igraj')

  const { data: profile } = await supabase
    .from('profiles').select('first_name').eq('id', user.id).single()

  // user's best survivor session for greeting
  const { data: best } = await supabase
    .from('survivor_sessions')
    .select('score, questions_reached, best_combo')
    .eq('user_id', user.id)
    .order('score', { ascending: false })
    .limit(1)
    .maybeSingle()

  return (
    <div className="min-h-screen" style={{ background: '#FAFAFA' }}>
      <Header />
      <main className="max-w-2xl mx-auto px-4 sm:px-6 py-10 sm:py-14">

        <div className="text-center mb-8">
          <p className="text-[13px] font-bold uppercase tracking-widest mb-2" style={{ color: '#609DED' }}>
            Survivor mod
          </p>
          <h1 className="font-black tracking-tight leading-[1.05] mb-3"
            style={{ color: '#343434', fontSize: 'clamp(40px, 8vw, 64px)' }}>
            10 života.
          </h1>
          <p className="text-[15px] sm:text-[17px]" style={{ color: '#9C9C9C' }}>
            Koliko daleko možeš da doguraš?
          </p>
        </div>

        {/* Personal best */}
        {best && best.score > 0 && (
          <div className="card-soft p-5 mb-5 flex items-center gap-4">
            <div className="w-12 h-12 rounded-2xl flex items-center justify-center flex-shrink-0" style={{ background: '#FFECBC' }}>
              <IconTrophy size={22} className="text-[#9c7a13]" strokeWidth={2.2} />
            </div>
            <div className="flex-1">
              <p className="text-[12px] font-medium" style={{ color: '#9C9C9C' }}>Tvoj rekord</p>
              <p className="font-black text-[20px] tracking-tight" style={{ color: '#343434' }}>
                {best.score} bodova
              </p>
              <p className="text-[12px]" style={{ color: '#9C9C9C' }}>
                {best.questions_reached} pitanja · niz {best.best_combo}
              </p>
            </div>
          </div>
        )}

        {/* Rules */}
        <div className="card-soft p-7 sm:p-8 mb-5">
          <h2 className="font-bold text-[16px] mb-5 tracking-tight" style={{ color: '#343434' }}>
            Pravila igre
          </h2>
          <div className="space-y-3.5">
            <Rule color="#FFECBC" fg="#9c7a13" Icon={IconStar}>
              Počneš sa <strong>10 života</strong>. Tačan odgovor donosi <strong>+10 bodova</strong>, pogrešan ti uzima <strong>1 život</strong> i <strong>5 bodova</strong>.
            </Rule>
            <Rule color="#BCD9FF" fg="#1e5fa4" Icon={IconTime}>
              Imaš <strong>15 sekundi</strong> po pitanju. Ako vreme istekne, broji se kao pogrešan odgovor.
            </Rule>
            <Rule color="#E8F8F0" fg="#15803d" Icon={IconHint}>
              Na svakih <strong>100 preživljenih pitanja</strong> dobijaš <strong>+10 novih života</strong> i bonus pomoć.
            </Rule>
          </div>

          <div className="mt-6 pt-6 border-t" style={{ borderColor: '#F2F2F2' }}>
            <p className="text-[13px] mb-3 font-bold tracking-tight" style={{ color: '#343434' }}>
              Combo bonusi
            </p>
            <div className="grid grid-cols-2 sm:grid-cols-5 gap-2 text-center">
              {[
                { n: 5,   bonus: 10 },
                { n: 10,  bonus: 25 },
                { n: 20,  bonus: 60 },
                { n: 50,  bonus: 150 },
                { n: 100, bonus: 400 },
              ].map(({ n, bonus }) => (
                <div key={n} className="rounded-2xl p-3" style={{ background: '#F2F2F2' }}>
                  <div className="font-black text-[16px] tracking-tight" style={{ color: '#343434' }}>{n}×</div>
                  <div className="text-[11px] font-bold" style={{ color: '#609DED' }}>+{bonus}</div>
                </div>
              ))}
            </div>
          </div>

          <div className="mt-6 pt-6 border-t" style={{ borderColor: '#F2F2F2' }}>
            <p className="text-[13px] mb-3 font-bold tracking-tight" style={{ color: '#343434' }}>
              Pomoći (1×)
            </p>
            <div className="grid grid-cols-3 gap-2">
              {[
                { label: 'Pola-pola',    desc: 'Skida 2 pogrešna' },
                { label: 'Preskoči',     desc: 'Bez gubitka života' },
                { label: '+15 sekundi',  desc: 'Dodaj vreme' },
              ].map(({ label, desc }) => (
                <div key={label} className="rounded-2xl p-3 text-center" style={{ background: '#F2F2F2' }}>
                  <div className="font-bold text-[12px] tracking-tight" style={{ color: '#343434' }}>{label}</div>
                  <div className="text-[10px] mt-0.5" style={{ color: '#9C9C9C' }}>{desc}</div>
                </div>
              ))}
            </div>
          </div>
        </div>

        <Link href="/igraj/start" className="btn btn-primary btn-lg w-full">
          Kreni — 10 života
        </Link>

        <p className="text-center text-[12px] mt-5" style={{ color: '#9C9C9C' }}>
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
      <p className="text-[14px] leading-relaxed pt-1" style={{ color: '#343434' }}>
        {children}
      </p>
    </div>
  )
}
