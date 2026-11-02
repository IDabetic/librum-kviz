import type { Metadata } from 'next'
import { createClient } from '@/lib/supabase/server'
import Header from '@/components/Header'
import Link from 'next/link'
import Footer from '@/components/Footer'
import { IGRE } from '@/lib/igre-katalog'

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

export default async function IgrePage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  return (
    <div className="page-ink min-h-screen flex flex-col">
      <Header />
      <main className="flex-1 max-w-6xl mx-auto px-4 sm:px-6 py-14 sm:py-20 w-full">
        <p className="text-[11px] font-semibold uppercase tracking-[0.28em] mb-4" style={{ color: '#A39E95' }}>
          Sadržaj
        </p>
        <h1 className="leading-[0.9] mb-14" style={{ color: '#F4EFE6', fontSize: 'clamp(56px, 12vw, 120px)', fontWeight: 500 }}>
          Igre.
        </h1>

        <div className="grid md:grid-cols-2" style={{ borderTop: '1px solid rgba(244,239,230,0.14)' }}>
          {IGRE.map(g => (
            <Link
              key={g.href}
              href={user ? g.href : `/auth/prijava?redirect=${g.href}`}
              className="group p-6 sm:p-8 flex flex-col justify-between min-h-[200px] sm:min-h-[240px] transition-colors"
              style={{
                borderBottom: '1px solid rgba(244,239,230,0.14)',
                borderRight: '1px solid rgba(244,239,230,0.14)',
              }}
            >
              <div className="flex items-start justify-between gap-4">
                <span className="text-[11px] font-semibold tabular-nums" style={{ color: g.accent }}>{g.n}</span>
                <span className="text-[13px] font-semibold" style={{ color: g.accent }}>{g.cta} →</span>
              </div>
              <div>
                <h2 className="leading-none mb-3" style={{ color: '#F4EFE6', fontSize: 'clamp(32px, 5vw, 48px)', fontWeight: 500 }}>
                  {g.kratko}
                </h2>
                <p className="text-[15px]" style={{ color: '#A39E95' }}>{g.desc}</p>
              </div>
            </Link>
          ))}
        </div>
      </main>
      <Footer />
    </div>
  )
}
