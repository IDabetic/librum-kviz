import type { Metadata } from 'next'
import { createClient } from '@/lib/supabase/server'
import Header from '@/components/Header'
import Link from 'next/link'
import { IconHint, IconTime, IconStar, IconTrophy, IconSwords } from '@/components/icons'

export const metadata: Metadata = {
  title: 'PRO kviz – survival igra znanja sa 10 života',
  description: 'Igraj PRO kviz i proveri koliko daleko možeš da doguraš. Dobijaš 10 života, odgovaraš na pitanja iz različitih oblasti i osvajaš bodove za rang-listu.',
  alternates: { canonical: '/igraj' },
  openGraph: {
    title: 'PRO kviz – survival igra znanja | Librum Kviz',
    description: 'Odgovaraj na pitanja, čuvaj živote i pokušaj da doguraš što dalje.',
    url: 'https://kviz.librum.club/igraj',
    type: 'website',
    images: ['/og-share.jpg?v=6'],
  },
}

export default async function IgrajLandingPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  const { data: profile } = user
    ? await supabase.from('profiles').select('first_name').eq('id', user.id).single()
    : { data: null as { first_name: string | null } | null }

  // user's best survivor session
  const { data: best } = user
    ? await supabase
        .from('survivor_sessions')
        .select('score, questions_reached, best_combo, accuracy')
        .eq('user_id', user.id)
        .order('score', { ascending: false })
        .limit(1)
        .maybeSingle()
    : { data: null as { score: number; questions_reached: number; best_combo: number; accuracy: number } | null }

  // today's top score (across all users)
  const startOfDay = new Date()
  startOfDay.setHours(0, 0, 0, 0)
  const { data: todayBest } = await supabase
    .from('survivor_sessions')
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
            Survivor mod
          </p>
          <h1 className="font-black tracking-tight leading-[1.05] mb-3"
            style={{ color: '#343434', fontSize: 'clamp(40px, 8vw, 64px)' }}>
            10 života.
          </h1>
          <p className="text-[15px] sm:text-[17px] leading-relaxed" style={{ color: '#9C9C9C' }}>
            Preživi što više pitanja, osvoji što više bodova<br />i popni se na rang-listi.
          </p>
        </div>

        {/* Personal best */}
        {best && best.score > 0 ? (
          <div className="card-soft p-5 mb-4">
            <div className="flex items-center gap-3 mb-3">
              <div className="w-10 h-10 rounded-2xl flex items-center justify-center flex-shrink-0" style={{ background: '#FFECBC' }}>
                <IconTrophy size={20} className="text-[#9c7a13]" strokeWidth={2.2} />
              </div>
              <p className="font-bold text-[15px] tracking-tight" style={{ color: '#343434' }}>Tvoj najbolji rezultat</p>
            </div>
            <div className="grid grid-cols-4 gap-2">
              {[
                { label: 'Bodovi',  value: best.score },
                { label: 'Najdalje', value: best.questions_reached },
                { label: 'Najduži niz', value: best.best_combo },
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
              Još nemaš rezultat. <strong>Vreme je za prvi pokušaj.</strong>
            </p>
          </div>
        )}

        {/* Today's top */}
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
            Pravila igre
          </h2>
          <div className="space-y-3.5">
            <Rule color="#FFECBC" fg="#9c7a13" Icon={IconStar}>
              <strong>Počinješ sa 10 života.</strong> Tačan odgovor donosi <strong>+10 bodova</strong>, a pogrešan odgovor skida <strong>1 život i 5 bodova</strong>.
            </Rule>
            <Rule color="#BCD9FF" fg="#1e5fa4" Icon={IconTime}>
              <strong>15 sekundi po pitanju.</strong> Ako vreme istekne, odgovor se računa kao pogrešan.
            </Rule>
            <Rule color="#E8F8F0" fg="#15803d" Icon={IconHint}>
              Na svakih <strong>50 preživljenih pitanja</strong> dobijaš <strong>+5 novih života</strong> i bonus pomoć. Ako preživiš dotle.
            </Rule>
            <Rule color="#F2F2F2" fg="#343434" Icon={IconTrophy}>
              <strong>Igra traje dok imaš živote.</strong> Kada ostaneš bez života, rezultat ide na rang-listu.
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
            <div className="grid grid-cols-3 gap-2 mb-3">
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
            <p className="text-[11px] leading-relaxed" style={{ color: '#9C9C9C' }}>
              Pomoći koristiš jednom po igri. Na svakih <strong>50 pitanja</strong> dobijaš novu bonus pomoć.
            </p>
          </div>

          <p className="text-[11px] text-center mt-6 pt-5 border-t leading-relaxed" style={{ color: '#9C9C9C', borderColor: '#F2F2F2' }}>
            Kategorije se ne biraju — pitanja dolaze iz velike zajedničke baze.
          </p>
        </div>

        {/* Goal + CTA */}
        <p className="text-center text-[13px] font-medium mb-3" style={{ color: '#609DED' }}>
          Tvoj cilj: preživi <strong>50 pitanja</strong> i osvoji novih <strong>5 života</strong>.
        </p>

        {user ? (
          <Link href="/igraj/start" className="btn btn-primary btn-lg w-full">
            Kreni — imaš 10 života
          </Link>
        ) : (
          <Link href="/auth/prijava?redirect=/igraj" className="btn btn-primary btn-lg w-full">
            Prijavi se da igraš
          </Link>
        )}

        {/* Duel CTA */}
        <Link href="/igraj-zajedno" className="mt-5 flex items-center justify-center gap-2 text-[13px] font-semibold transition-opacity hover:opacity-70"
          style={{ color: '#9C9C9C' }}>
          <IconSwords size={14} strokeWidth={2.2} />
          Želiš protiv nekoga? Pokreni duel →
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
      <p className="text-[14px] leading-relaxed pt-1" style={{ color: '#343434' }}>
        {children}
      </p>
    </div>
  )
}
