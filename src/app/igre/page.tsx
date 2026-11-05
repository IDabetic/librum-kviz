import type { Metadata } from 'next'
import { createClient } from '@/lib/supabase/server'
import Header from '@/components/Header'
import Footer from '@/components/Footer'
import { IGRE } from '@/lib/igre-katalog'
import { KarticaIgre } from '@/components/KarticaIgre'

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
    <div className="min-h-screen flex flex-col">
      <Header />
      <main className="flex-1 max-w-6xl mx-auto px-4 sm:px-6 py-10 sm:py-14 w-full">
        <h1 className="mb-8" style={{ fontSize: 'clamp(44px, 9vw, 88px)' }}>Igre</h1>
        <div className="grid grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-5 [&>*:first-child]:col-span-2 lg:[&>*:first-child]:col-span-3">
          {IGRE.map((g, i) => (
            <KarticaIgre key={g.href} igra={g} velika={i === 0} href={user || g.href === '/osvajanje' ? g.href : `/auth/prijava?redirect=${g.href}`} />
          ))}
        </div>
      </main>
      <Footer />
    </div>
  )
}
