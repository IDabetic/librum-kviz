import type { Metadata } from 'next'
import { createClient } from '@/lib/supabase/server'
import Header from '@/components/Header'
import Link from 'next/link'
import { IconTime, IconStar, IconTrophy, IconDiscover } from '@/components/icons'

import Footer from '@/components/Footer'

export const metadata: Metadata = {
  title: 'Book kviz – kviz iz književnosti, kviz o knjigama i piscima',
  description: 'Book kviz – online kviz iz književnosti na srpskom. Pitanja o knjigama, piscima, romanima i književnim žanrovima. Saznaj koji književni žanr najbolje poznaješ — kviz za ljubitelje knjiga i čitaoce.',
  keywords: [
    'Book kviz', 'književni kviz', 'kviz iz književnosti', 'književnost kviz',
    'kviz o knjigama', 'kviz o piscima', 'kviz o romanima',
    'kviz o književnim likovima', 'kviz o žanrovima',
    'proveri znanje iz književnosti', 'koji književni žanr najbolje poznaješ',
    'test znanja iz književnosti', 'ljubitelji knjiga kviz', 'kviz za čitaoce',
    'Librum kviz',
  ],
  alternates: { canonical: '/book-kviz' },
  openGraph: {
    title: 'Book kviz – kviz iz književnosti | Librum Kviz',
    description: 'Pitanja iz svih književnih žanrova. Saznaj koji žanr najbolje poznaješ.',
    url: 'https://kviz.librum.club/book-kviz',
    type: 'website',
    images: ['/og-share.jpg?v=6'],
  },
}

export default async function BookKvizLanding() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  const { data: profile } = user
    ? await supabase.from('profiles').select('first_name').eq('id', user.id).single()
    : { data: null as { first_name: string | null } | null }

  const { data: best } = user
    ? await supabase
        .from('book_sessions')
        .select('score, questions_reached, top_genre, top_genre_pct')
        .eq('user_id', user.id)
        .order('score', { ascending: false })
        .limit(1)
        .maybeSingle()
    : { data: null as { score: number; questions_reached: number; top_genre: string | null; top_genre_pct: number | null } | null }

  return (
    <div className="min-h-screen" style={{ background: '#FAFAFA' }}>
      <Header />
      <main className="max-w-2xl mx-auto px-4 sm:px-6 py-10 sm:py-14">

        <div className="text-center mb-8">
          <p className="text-[13px] font-bold uppercase tracking-widest mb-2" style={{ color: '#9c7a13' }}>
            Književnost
          </p>
          <h1 className="font-black tracking-tight leading-[1.05] mb-3"
            style={{ color: '#343434', fontSize: 'clamp(40px, 8vw, 64px)' }}>
            Book kviz.
          </h1>
          <p className="text-[15px] sm:text-[17px] leading-relaxed" style={{ color: '#9C9C9C' }}>
            Pitanja samo iz književnosti.<br />Na kraju saznaš u kom žanru si najjači.
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
                <div className="font-black text-[12px] tracking-tight" style={{ color: '#343434' }}>{best.top_genre || '—'}</div>
                <div className="text-[10px] mt-0.5" style={{ color: '#9C9C9C' }}>Najjači žanr</div>
              </div>
            </div>
          </div>
        ) : (
          <div className="card-soft p-5 mb-4 flex items-center gap-3">
            <div className="w-10 h-10 rounded-2xl flex items-center justify-center flex-shrink-0" style={{ background: '#FFECBC' }}>
              <IconStar size={20} className="text-[#9c7a13]" strokeWidth={2.2} />
            </div>
            <p className="text-[14px]" style={{ color: '#343434' }}>
              Još nemaš rezultat. <strong>Vreme je za prvi pokušaj.</strong>
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
            <Rule color="#E8F8F0" fg="#15803d" Icon={IconDiscover}>
              <strong>Pitanja iz 8 žanrova:</strong> Drama, Fantastika, Ljubavni, Istorijski, Krimi, Triler, Domaći, Horor.
            </Rule>
            <Rule color="#F2F2F2" fg="#343434" Icon={IconTrophy}>
              <strong>Igra traje dok imaš živote.</strong> Na kraju saznaš u kom žanru si najjači.
            </Rule>
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
          </div>
        </div>

        {user ? (
          <Link href="/book-kviz/start" className="btn btn-primary btn-lg w-full">
            Kreni — imaš 10 života
          </Link>
        ) : (
          <Link href="/auth/prijava?redirect=/book-kviz" className="btn btn-primary btn-lg w-full">
            Prijavi se da igraš
          </Link>
        )}

        <p className="text-center text-[11px] mt-5" style={{ color: '#9C9C9C' }}>
          {profile?.first_name ? `Spreman/na, ${profile.first_name}?` : 'Spreman/na?'}
        </p>
      </main>
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
      <p className="text-[14px] leading-relaxed pt-1" style={{ color: '#343434' }}>
        {children}
      </p>
    </div>
  )
}
