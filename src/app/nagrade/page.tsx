import type { Metadata } from 'next'
import Header from '@/components/Header'
import Link from 'next/link'

export const metadata: Metadata = {
  title: 'Nagrade – uskoro | Librum Kviz',
  description: 'Sistem nagrada za najbolje igrače stiže uskoro.',
  alternates: { canonical: '/nagrade' },
}

export default function NagradePage() {
  return (
    <div className="min-h-screen" style={{ background: '#FAFAFA' }}>
      <Header />
      <main className="max-w-2xl mx-auto px-4 sm:px-6 py-16 sm:py-24">
        <div className="card-soft overflow-hidden">
          <div className="px-7 py-12 sm:py-16 text-center"
            style={{ background: 'linear-gradient(135deg, #FFCB46 0%, #FFECBC 100%)' }}>
            <div className="text-7xl sm:text-8xl mb-4">🏆</div>
            <p className="text-[12px] font-bold uppercase tracking-widest mb-3" style={{ color: '#9c7a13', opacity: 0.7 }}>
              Sistem nagrada
            </p>
            <h1 className="font-black tracking-tight leading-[1.05]"
              style={{ color: '#343434', fontSize: 'clamp(48px, 9vw, 80px)' }}>
              USKORO!
            </h1>
          </div>

          <div className="p-7 sm:p-10 text-center">
            <p className="text-[15px] sm:text-[17px] leading-relaxed" style={{ color: '#343434' }}>
              Pripremamo nešto posebno za najbolje igrače. Bonusi, značke, mesečne nagrade — sve na jednom mestu.
            </p>
            <p className="text-[13px] mt-3" style={{ color: '#9C9C9C' }}>
              Nastavi da igraš — kad nagrade krenu, već si u trci.
            </p>

            <div className="grid grid-cols-2 gap-3 mt-8">
              <Link href="/igre" className="btn btn-primary btn-md">Idi u igre</Link>
              <Link href="/leaderboard" className="btn btn-secondary btn-md">Rang lista</Link>
            </div>
          </div>
        </div>
      </main>
    </div>
  )
}
