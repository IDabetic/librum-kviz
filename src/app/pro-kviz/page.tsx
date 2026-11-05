import type { Metadata } from 'next'
import { createClient } from '@/lib/supabase/server'
import Header from '@/components/Header'
import Link from 'next/link'
import { IconHint, IconTime, IconStar, IconTrophy, IconSwords } from '@/components/icons'

import Footer from '@/components/Footer'
import GameSeoContent from '@/components/GameSeoContent'

export const metadata: Metadata = {
  title: 'PRO kviz – survival kviz znanja sa rang-listom',
  description: 'Igraj PRO kviz – survival kviz znanja sa 10 života. Najteži kviz opšteg znanja na srpskom, pitanja iz književnosti, istorije, geografije i sporta. Penji se rang-listom i takmiči se sa drugima.',
  keywords: [
    'PRO kviz', 'survival kviz', 'kviz sa životima', 'najteži kviz znanja',
    'kviz opšteg znanja', 'online kviz znanja', 'kviz sa rang-listom',
    'kviz za takmičenje', 'kviz izazov', 'kviz za pametne',
    'besplatan online kviz', 'kviz znanja na srpskom', 'Librum kviz',
  ],
  alternates: { canonical: '/pro-kviz' },
  openGraph: {
    title: 'PRO kviz – survival igra znanja | Librum Kviz',
    description: '10 života, kombo bonus i rang-lista. Najteži kviz opšteg znanja na srpskom.',
    url: 'https://kviz.librum.club/pro-kviz',
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
    .select('score, user_id')
    .gte('created_at', startOfDay.toISOString())
    .order('score', { ascending: false })
    .limit(1)
    .maybeSingle()

  // Look up name from public_profiles — embedded selects on `profiles`
  // are locked out for anon, so we resolve display info separately.
  const todayBestName = todayBest?.user_id
    ? await (async () => {
        const { data: p } = await supabase
          .from('public_profiles')
          .select('first_name, nickname')
          .eq('id', todayBest.user_id)
          .maybeSingle()
        return p?.nickname || p?.first_name || 'Igrač'
      })()
    : null

  return (
    <div className="min-h-screen">
      <Header />
      <main className="max-w-2xl mx-auto px-4 sm:px-6 py-14 sm:py-20">

        <p className="text-[11px] font-semibold uppercase tracking-[0.28em] mb-5" style={{ color: '#2C2D81' }}>
          01 · Survivor
        </p>
        <h1 className="leading-[0.9] mb-5"
          style={{ color: '#1A1B3A', fontSize: 'clamp(52px, 12vw, 96px)', fontWeight: 500 }}>
          10 života.
        </h1>
        <p className="text-[17px] leading-snug mb-10 max-w-md" style={{ color: '#4F5170' }}>
          Preživi što više pitanja. Svaka greška skida život. Rang-lista ne laže.
        </p>

        {/* Personal best */}
        {best && best.score > 0 ? (
          <div className="card-soft p-5 mb-4">
            <div className="flex items-center gap-3 mb-3">
              <div className="w-10 h-10 rounded-2xl flex items-center justify-center flex-shrink-0" style={{ background: '#FFF5E0' }}>
                <IconTrophy size={20} className="text-[#8A6A12]" strokeWidth={2.2} />
              </div>
              <p className="font-bold text-[15px] tracking-tight" style={{ color: '#1A1B3A' }}>Tvoj najbolji rezultat</p>
            </div>
            <div className="grid grid-cols-4 gap-2">
              {[
                { label: 'Bodovi',  value: best.score },
                { label: 'Najdalje', value: best.questions_reached },
                { label: 'Najduži niz', value: best.best_combo },
                { label: 'Tačnost', value: `${Math.round(Number(best.accuracy))}%` },
              ].map(({ label, value }) => (
                <div key={label} className="rounded-xl p-2.5 text-center" style={{ background: '#EDE5D5' }}>
                  <div className="font-black text-[15px] tracking-tight" style={{ color: '#1A1B3A' }}>{value}</div>
                  <div className="text-[10px] mt-0.5" style={{ color: '#4F5170' }}>{label}</div>
                </div>
              ))}
            </div>
          </div>
        ) : (
          <div className="card-soft p-5 mb-4 flex items-center gap-3">
            <div className="w-10 h-10 rounded-2xl flex items-center justify-center flex-shrink-0" style={{ background: '#E8F6EF' }}>
              <IconStar size={20} className="text-[#0A4C35]" strokeWidth={2.2} />
            </div>
            <p className="text-[14px]" style={{ color: '#1A1B3A' }}>
              Još nemaš rezultat. <strong>Vreme je za prvi pokušaj.</strong>
            </p>
          </div>
        )}

        {/* Today's top */}
        {todayBest && todayBest.score > 0 && todayBestName && (
          <div className="card-soft p-4 mb-5 text-center" style={{ background: '#FFF5E0', borderColor: 'rgba(255,216,77,0.4)' }}>
            <p className="text-[13px] font-medium" style={{ color: '#8A6A12' }}>
              ⚡ Danas u vrhu: <strong>{todayBestName}</strong> sa <strong>{todayBest.score} bodova</strong>. Možeš li bolje?
            </p>
          </div>
        )}

        {/* Rules */}
        <div className="card-soft p-7 sm:p-8 mb-5">
          <h2 className="font-bold text-[16px] mb-5 tracking-tight" style={{ color: '#1A1B3A' }}>
            Pravila igre
          </h2>
          <div className="space-y-3.5">
            <Rule color="#FFF5E0" fg="#8A6A12" Icon={IconStar}>
              <strong>Počinješ sa 10 života.</strong> Tačan odgovor donosi <strong>+10 bodova</strong>, a pogrešan odgovor skida <strong>1 život i 5 bodova</strong>.
            </Rule>
            <Rule color="#E8F6EF" fg="#0A4C35" Icon={IconTime}>
              <strong>15 sekundi po pitanju.</strong> Ako vreme istekne, odgovor se računa kao pogrešan.
            </Rule>
            <Rule color="#E8F6EF" fg="#0A4C35" Icon={IconHint}>
              Na svakih <strong>50 preživljenih pitanja</strong> dobijaš <strong>+5 novih života</strong> i bonus pomoć. Ako preživiš dotle.
            </Rule>
            <Rule color="#EDE5D5" fg="#1A1B3A" Icon={IconTrophy}>
              <strong>Igra traje dok imaš živote.</strong> Kada ostaneš bez života, rezultat ide na rang-listu.
            </Rule>
          </div>

          <div className="mt-6 pt-6 border-t" style={{ borderColor: '#EDE5D5' }}>
            <p className="text-[13px] mb-3 font-bold tracking-tight" style={{ color: '#1A1B3A' }}>
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
                <div key={n} className="rounded-2xl p-3" style={{ background: '#EDE5D5' }}>
                  <div className="font-black text-[16px] tracking-tight" style={{ color: '#1A1B3A' }}>{n}×</div>
                  <div className="text-[11px] font-bold" style={{ color: '#23845C' }}>+{bonus}</div>
                </div>
              ))}
            </div>
          </div>

          <div className="mt-6 pt-6 border-t" style={{ borderColor: '#EDE5D5' }}>
            <p className="text-[13px] mb-3 font-bold tracking-tight" style={{ color: '#1A1B3A' }}>
              Pomoći (1×)
            </p>
            <div className="grid grid-cols-3 gap-2 mb-3">
              {[
                { label: 'Pola-pola',    desc: 'Skida 2 pogrešna' },
                { label: 'Preskoči',     desc: 'Bez gubitka života' },
                { label: '+15 sekundi',  desc: 'Dodaj vreme' },
              ].map(({ label, desc }) => (
                <div key={label} className="rounded-2xl p-3 text-center" style={{ background: '#EDE5D5' }}>
                  <div className="font-bold text-[12px] tracking-tight" style={{ color: '#1A1B3A' }}>{label}</div>
                  <div className="text-[10px] mt-0.5" style={{ color: '#4F5170' }}>{desc}</div>
                </div>
              ))}
            </div>
            <p className="text-[11px] leading-relaxed" style={{ color: '#4F5170' }}>
              Pomoći koristiš jednom po igri. Na svakih <strong>50 pitanja</strong> dobijaš novu bonus pomoć.
            </p>
          </div>

          <p className="text-[11px] text-center mt-6 pt-5 border-t leading-relaxed" style={{ color: '#4F5170', borderColor: '#EDE5D5' }}>
            Kategorije se ne biraju — pitanja dolaze iz velike zajedničke baze.
          </p>
        </div>

        {/* Goal + CTA */}
        <p className="text-center text-[13px] font-medium mb-3" style={{ color: '#23845C' }}>
          Tvoj cilj: preživi <strong>50 pitanja</strong> i osvoji novih <strong>5 života</strong>.
        </p>

        {user ? (
          <Link href="/pro-kviz/start" className="btn btn-primary btn-lg w-full">
            Kreni — imaš 10 života
          </Link>
        ) : (
          <Link href="/auth/prijava?redirect=/pro-kviz" className="btn btn-primary btn-lg w-full">
            Prijavi se da igraš
          </Link>
        )}

        {/* Duel CTA */}
        <Link href="/igraj-zajedno" className="mt-5 flex items-center justify-center gap-2 text-[13px] font-semibold transition-opacity hover:opacity-70"
          style={{ color: '#4F5170' }}>
          <IconSwords size={14} strokeWidth={2.2} />
          Želiš protiv nekoga? Pokreni duel →
        </Link>

        <p className="text-center text-[11px] mt-5" style={{ color: '#4F5170' }}>
          {profile?.first_name ? `Spreman/na, ${profile.first_name}?` : 'Spreman/na?'}
        </p>
      </main>
      <GameSeoContent game="pro" />
      <Footer />
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
      <p className="text-[14px] leading-relaxed pt-1" style={{ color: '#1A1B3A' }}>
        {children}
      </p>
    </div>
  )
}
