import Link from 'next/link'
import { Logo } from './Logo'

export default function Footer() {
  const year = new Date().getFullYear()
  const categories = [
    'književnosti', 'istorije', 'geografije', 'sporta', 'kulture', 'prirode', 'opšteg znanja',
  ]
  return (
    <footer className="border-t mt-10" style={{ background: '#FCFCFC', borderColor: 'rgba(52,52,52,0.06)' }}>
      <div className="max-w-6xl mx-auto px-4 sm:px-6 py-10">
        <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-8 mb-8">
          {/* Brand */}
          <div>
            <Logo height={26} />
            <p className="text-[12px] mt-3 leading-relaxed" style={{ color: '#9C9C9C' }}>
              Kviz platforma za radoznale.<br />
              PRO kviz, Trivia duel, Vešanje, Brzi kviz.
            </p>
          </div>

          {/* Games */}
          <div>
            <p className="text-[11px] font-bold uppercase tracking-widest mb-3" style={{ color: '#343434' }}>
              Igre
            </p>
            <ul className="space-y-2 text-[13px]">
              <li><Link href="/igraj" className="transition-opacity hover:opacity-70" style={{ color: '#343434' }}>PRO kviz</Link></li>
              <li><Link href="/book-kviz" className="transition-opacity hover:opacity-70" style={{ color: '#343434' }}>Book kviz</Link></li>
              <li><Link href="/kafanski-kviz" className="transition-opacity hover:opacity-70" style={{ color: '#343434' }}>Kafanski kviz</Link></li>
              <li><Link href="/igraj-zajedno" className="transition-opacity hover:opacity-70" style={{ color: '#343434' }}>Trivia duel</Link></li>
              <li><Link href="/vesanje" className="transition-opacity hover:opacity-70" style={{ color: '#343434' }}>Vešanje</Link></li>
              <li><Link href="/brzi-kviz" className="transition-opacity hover:opacity-70" style={{ color: '#343434' }}>Brzi kviz</Link></li>
              <li><Link href="/leaderboard" className="transition-opacity hover:opacity-70" style={{ color: '#343434' }}>Rang lista</Link></li>
            </ul>
          </div>

          {/* Categories */}
          <div>
            <p className="text-[11px] font-bold uppercase tracking-widest mb-3" style={{ color: '#343434' }}>
              Oblasti znanja
            </p>
            <ul className="space-y-2 text-[13px]" style={{ color: '#9C9C9C' }}>
              {categories.map(c => (
                <li key={c}>Kviz iz {c}</li>
              ))}
            </ul>
          </div>

          {/* Contact */}
          <div>
            <p className="text-[11px] font-bold uppercase tracking-widest mb-3" style={{ color: '#343434' }}>
              Kontakt
            </p>
            <ul className="space-y-2 text-[13px]">
              <li>
                <a href="mailto:info@librum.club" className="font-semibold transition-opacity hover:opacity-70" style={{ color: '#609DED' }}>
                  info@librum.club
                </a>
              </li>
              <li>
                <Link href="/predlozi-pitanje" className="transition-opacity hover:opacity-70" style={{ color: '#343434' }}>
                  Predloži pitanje
                </Link>
              </li>
              <li>
                <a href="https://www.librum.club" rel="noopener noreferrer" className="transition-opacity hover:opacity-70" style={{ color: '#9C9C9C' }}>
                  librum.club ↗
                </a>
              </li>
            </ul>
          </div>
        </div>

        <div className="pt-6 flex flex-col sm:flex-row items-center justify-between gap-3 text-[12px] border-t" style={{ borderColor: 'rgba(52,52,52,0.06)', color: '#9C9C9C' }}>
          <span>© {year} Librum Kviz</span>
          <div className="flex items-center gap-4 flex-wrap justify-center">
            <Link href="/politika-privatnosti" className="transition-opacity hover:opacity-70" style={{ color: '#9C9C9C' }}>
              Politika privatnosti
            </Link>
            <Link href="/uslovi-koriscenja" className="transition-opacity hover:opacity-70" style={{ color: '#9C9C9C' }}>
              Uslovi korišćenja
            </Link>
            <span className="text-[11px]">kviz.librum.club</span>
          </div>
        </div>
      </div>
    </footer>
  )
}
