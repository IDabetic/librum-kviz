import type { Metadata } from 'next'
import { createClient } from '@/lib/supabase/server'
import Header from '@/components/Header'
import Link from 'next/link'

import Footer from '@/components/Footer'

export const metadata: Metadata = {
  title: 'Igre znanja – izaberi kviz, online kviz na srpskom',
  description: 'Sve igre znanja u jednom mestu — PRO kviz, Book kviz, Kafanski kviz, Trivia duel, Vešanje i Brzi kviz. Besplatan online kviz na srpskom za društvo, kafanu i pauzu.',
  keywords: [
    'igre znanja', 'online igre znanja', 'igre znanja online',
    'besplatne igre znanja', 'edukativne igre online', 'igre za mozak',
    'kviz', 'online kviz', 'kviz online', 'kviz na srpskom',
    'PRO kviz', 'Book kviz', 'kafanski kviz', 'trivia duel',
    'igra vešanja', 'brzi kviz', 'Librum kviz',
  ],
  alternates: { canonical: '/igre' },
}

// Each card has its own visual identity: gradient header + emoji,
// then a clean white body with the title, blurb and play CTA.
const GAMES = [
  {
    href: '/pro-kviz',
    label: 'PRO kviz',
    emoji: '🎯',
    desc: '10 života, kombo bonus, lifelines. Provera koliko daleko stižeš.',
    cta: 'Pokreni PRO',
    gradient: 'linear-gradient(135deg, #BCD9FF 0%, #609DED 100%)',
    accent: '#1e5fa4',
  },
  {
    href: '/book-kviz',
    label: 'Book kviz',
    emoji: '📚',
    desc: 'Pitanja iz svih književnih žanrova. Na kraju saznaš u kom si najbolji.',
    cta: 'Pokreni Book',
    gradient: 'linear-gradient(135deg, #FFECBC 0%, #FFCB46 100%)',
    accent: '#9c7a13',
  },
  {
    href: '/kafanski-kviz',
    label: 'Kafanski kviz',
    emoji: '🎵',
    desc: 'Muzika i kafanski hitovi — narodnjaci, pop, rock klasici. Bez pomoći.',
    cta: 'Pokreni Kafanski',
    gradient: 'linear-gradient(135deg, #FEE2E2 0%, #E55353 100%)',
    accent: '#b91c1c',
  },
  {
    href: '/igraj-zajedno',
    label: 'Trivia duel',
    emoji: '⚔️',
    desc: 'Jedan na jedan. Ista pitanja, isto vreme, ko zna više pobedi.',
    cta: 'Izazovi prijatelja',
    gradient: 'linear-gradient(135deg, #FFCB46 0%, #FFECBC 100%)',
    accent: '#9c7a13',
  },
  {
    href: '/vesanje',
    label: 'Vešanje',
    emoji: '🪢',
    desc: 'Pogađaj slovo po slovo. Kategorije: sport, geografija, istorija…',
    cta: 'Pokreni Vešanje',
    gradient: 'linear-gradient(135deg, #E8F8F0 0%, #4CAF50 100%)',
    accent: '#15803d',
  },
  {
    href: '/brzi-kviz',
    label: 'Brzi kviz',
    emoji: '⚡',
    desc: 'Tačno ili netačno? 60 sekundi po rundi, brza odluka.',
    cta: 'Pokreni Brzi',
    gradient: 'linear-gradient(135deg, #FEE2E2 0%, #b91c1c 100%)',
    accent: '#b91c1c',
  },
]

export default async function IgrePage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  return (
    <div className="min-h-screen" style={{ background: '#FAFAFA' }}>
      <Header />
      <main className="max-w-6xl mx-auto px-4 sm:px-6 py-10 sm:py-14">

        <div className="text-center mb-10 sm:mb-12">
          <p className="text-[13px] font-bold uppercase tracking-widest mb-2" style={{ color: '#609DED' }}>
            Izaberi kviz
          </p>
          <h1 className="font-black tracking-tight leading-[1.05]" style={{ color: '#343434', fontSize: 'clamp(36px, 7vw, 56px)' }}>
            Igre.
          </h1>
          <p className="text-[15px] sm:text-[17px] mt-3" style={{ color: '#9C9C9C' }}>
            Šest različitih kvizova, svaki sa svojim ritmom.
          </p>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-5">
          {GAMES.map(g => (
            <Link key={g.href} href={user ? g.href : `/auth/prijava?redirect=${g.href}`}
              className="card-soft overflow-hidden group transition-transform hover:scale-[1.02]">
              {/* Gradient illustration panel */}
              <div className="relative h-40 sm:h-44 flex items-center justify-center"
                style={{ background: g.gradient }}>
                <span className="text-[80px] sm:text-[88px] leading-none" aria-hidden>{g.emoji}</span>
                {/* soft white veil for legibility on bright gradients */}
                <div className="absolute inset-0 pointer-events-none"
                  style={{ background: 'radial-gradient(ellipse at center, rgba(252,252,252,0.20) 0%, transparent 70%)' }} />
              </div>
              {/* Body */}
              <div className="p-5 sm:p-6">
                <h2 className="font-black tracking-tight mb-2" style={{ color: g.accent, fontSize: 'clamp(20px, 3vw, 24px)' }}>
                  {g.label}
                </h2>
                <p className="text-[13px] leading-relaxed mb-4" style={{ color: '#343434', opacity: 0.7 }}>
                  {g.desc}
                </p>
                <div className="inline-flex items-center gap-1.5 text-[13px] font-bold" style={{ color: g.accent }}>
                  {g.cta}
                  <span className="transition-transform group-hover:translate-x-1">→</span>
                </div>
              </div>
            </Link>
          ))}
        </div>
      </main>
      <Footer />
    </div>
  )
}
