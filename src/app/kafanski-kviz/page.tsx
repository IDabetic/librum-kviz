import type { Metadata } from 'next'
import { createClient } from '@/lib/supabase/server'
import Header from '@/components/Header'
import Link from 'next/link'
import { IconTime, IconTrophy, IconSwords } from '@/components/icons'

export const metadata: Metadata = {
  title: 'Kafanski kviz – pitanja o muzici i kafanskim hitovima',
  description: 'Igraj Kafanski kviz – pitanja o domaćoj muzici, narodnjacima, pop i rock klasicima. 15 sekundi po pitanju, bez pomoći.',
  alternates: { canonical: '/kafanski-kviz' },
  openGraph: {
    title: 'Kafanski kviz | Librum Kviz',
    description: 'Hiljada pitanja o muzici. Koliko poznaješ kafanske hitove?',
    url: 'https://kviz.librum.club/kafanski-kviz',
    type: 'website',
    images: ['/og-share.jpg?v=6'],
  },
}

export default async function KafanskiKvizLanding() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  const { data: best } = user
    ? await supabase
        .from('kafana_sessions')
        .select('score, questions_reached, accuracy')
        .eq('user_id', user.id)
        .order('score', { ascending: false })
        .limit(1)
        .maybeSingle()
    : { data: null as { score: number; questions_reached: number; accuracy: number } | null }

  return (
    <div className="min-h-screen" style={{ background: '#FAFAFA' }}>
      <Header />
      <main className="max-w-2xl mx-auto px-4 sm:px-6 py-10 sm:py-14">

        <div className="text-center mb-8">
          <p className="text-[13px] font-bold uppercase tracking-widest mb-2" style={{ color: '#b91c1c' }}>
            Muzika · narodnjaci · klasici
          </p>
          <h1 className="font-black tracking-tight leading-[1.05] mb-3"
            style={{ color: '#343434', fontSize: 'clamp(40px, 8vw, 64px)' }}>
            Kafanski kviz.
          </h1>
          <p className="text-[15px] sm:text-[17px] leading-relaxed" style={{ color: '#9C9C9C' }}>
            Pitanja o muzici i hitovima.<br />15 sekundi po pitanju, bez pomoći.
          </p>
        </div>

        {best && best.score > 0 && (
          <div className="card-soft p-5 mb-4">
            <div className="flex items-center gap-3 mb-3">
              <div className="w-10 h-10 rounded-2xl flex items-center justify-center flex-shrink-0" style={{ background: '#FEE2E2' }}>
                <IconTrophy size={20} className="text-[#b91c1c]" strokeWidth={2.2} />
              </div>
              <p className="font-bold text-[15px] tracking-tight" style={{ color: '#343434' }}>Tvoj najbolji rezultat</p>
            </div>
            <div className="grid grid-cols-3 gap-2">
              <div className="rounded-xl p-2.5 text-center" style={{ background: '#F2F2F2' }}>
                <div className="font-black text-[15px] tracking-tight" style={{ color: '#343434' }}>{best.score}</div>
                <div className="text-[10px] mt-0.5" style={{ color: '#9C9C9C' }}>Bodovi</div>
              </div>
              <div className="rounded-xl p-2.5 text-center" style={{ background: '#F2F2F2' }}>
                <div className="font-black text-[15px] tracking-tight" style={{ color: '#343434' }}>{best.questions_reached}</div>
                <div className="text-[10px] mt-0.5" style={{ color: '#9C9C9C' }}>Pitanja</div>
              </div>
              <div className="rounded-xl p-2.5 text-center" style={{ background: '#F2F2F2' }}>
                <div className="font-black text-[15px] tracking-tight" style={{ color: '#343434' }}>{Math.round(best.accuracy)}%</div>
                <div className="text-[10px] mt-0.5" style={{ color: '#9C9C9C' }}>Tačnost</div>
              </div>
            </div>
          </div>
        )}

        {/* Rules */}
        <div className="card-soft p-6 mb-5 space-y-3">
          <Rule icon={<IconTime size={18} className="text-[#b91c1c]" strokeWidth={2.2} />}
            title="15 sekundi po pitanju"
            sub="Brzo razmisli, brže odgovori." />
          <Rule icon={<span className="text-[18px]">🎵</span>}
            title="Samo muzika"
            sub="Narodnjaci, pop, rock, klasici — sve što se peva u kafani." />
          <Rule icon={<span className="text-[18px]">❌</span>}
            title="Bez pomoći"
            sub="Nema pola-pola, nema preskakanja. Sam protiv pitanja." />
        </div>

        <Link href={user ? '/kafanski-kviz/start' : '/auth/prijava?redirect=/kafanski-kviz/start'}
          className="btn btn-primary btn-lg w-full mb-2"
          style={{ background: '#b91c1c' }}>
          Pokreni kviz
        </Link>
        <Link href="/igraj-zajedno?type=kafana"
          className="btn btn-md w-full mb-2"
          style={{ background: '#FEE2E2', color: '#b91c1c' }}>
          <IconSwords size={16} strokeWidth={2.2} />
          Pozovi prijatelja na duel
        </Link>
      </main>
    </div>
  )
}

function Rule({ icon, title, sub }: { icon: React.ReactNode; title: string; sub: string }) {
  return (
    <div className="flex items-start gap-3">
      <div className="w-8 h-8 rounded-xl flex items-center justify-center flex-shrink-0" style={{ background: '#F2F2F2' }}>
        {icon}
      </div>
      <div className="flex-1 min-w-0">
        <p className="font-semibold text-[14px]" style={{ color: '#343434' }}>{title}</p>
        <p className="text-[12px]" style={{ color: '#9C9C9C' }}>{sub}</p>
      </div>
    </div>
  )
}
