import Link from 'next/link'
import { Logo } from './Logo'

export default function Footer() {
  const year = new Date().getFullYear()
  const categories = [
    'književnosti', 'istorije', 'geografije', 'sporta', 'kulture', 'prirode', 'opšteg znanja',
  ]
  return (
    <footer className="mt-10" style={{ background: '#151515' }}>
      <div className="h-1.5" style={{ background: 'linear-gradient(90deg, #12907E 0%, #3B78E0 50%, #12907E 100%)' }} />
      <div className="max-w-6xl mx-auto px-4 sm:px-6 py-10">
        <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-8 mb-8">
          <div>
            <p className="font-display text-[22px] font-semibold tracking-tight" style={{ color: '#FFFFFF' }}>
              Librum kviz
            </p>
            <p className="text-[12px] mt-3 leading-relaxed" style={{ color: '#8F8A80' }}>
              Kviz platforma Librum kluba.<br />
              Igraj, dodaj pitanje, penji se rang-listom.
            </p>
          </div>

          <div>
            <p className="text-[11px] font-bold uppercase tracking-widest mb-3" style={{ color: '#12907E' }}>
              Igre
            </p>
            <ul className="space-y-2 text-[13px]">
              <li><Link href="/pro-kviz" className="hover:opacity-70" style={{ color: '#FFFFFF' }}>PRO kviz</Link></li>
              <li><Link href="/book-kviz" className="hover:opacity-70" style={{ color: '#FFFFFF' }}>Book kviz</Link></li>
              <li><Link href="/kafanski-kviz" className="hover:opacity-70" style={{ color: '#FFFFFF' }}>Kafanski kviz</Link></li>
              <li><Link href="/igraj-zajedno" className="hover:opacity-70" style={{ color: '#FFFFFF' }}>Trivia duel</Link></li>
              <li><Link href="/vesanje" className="hover:opacity-70" style={{ color: '#FFFFFF' }}>Vešanje</Link></li>
              <li><Link href="/brzi-kviz" className="hover:opacity-70" style={{ color: '#FFFFFF' }}>Brzi kviz</Link></li>
              <li><Link href="/ranglista" className="hover:opacity-70" style={{ color: '#FFFFFF' }}>Rang lista</Link></li>
            </ul>
          </div>

          <div>
            <p className="text-[11px] font-bold uppercase tracking-widest mb-3" style={{ color: '#12907E' }}>
              Oblasti znanja
            </p>
            <ul className="space-y-2 text-[13px]" style={{ color: '#8F8A80' }}>
              {categories.map(c => (
                <li key={c}>Kviz iz {c}</li>
              ))}
            </ul>
          </div>

          <div>
            <p className="text-[11px] font-bold uppercase tracking-widest mb-3" style={{ color: '#12907E' }}>
              Kontakt
            </p>
            <ul className="space-y-2 text-[13px]">
              <li>
                <a href="mailto:info@librum.club" className="font-semibold hover:opacity-70" style={{ color: '#DFF3EE' }}>
                  info@librum.club
                </a>
              </li>
              <li>
                <Link href="/dodaj-pitanja" className="hover:opacity-70" style={{ color: '#FFFFFF' }}>
                  Dodaj pitanje
                </Link>
              </li>
              <li>
                <a href="https://www.librum.club" rel="noopener noreferrer" className="hover:opacity-70" style={{ color: '#8F8A80' }}>
                  librum.club ↗
                </a>
              </li>
            </ul>
          </div>
        </div>

        <div className="pt-6 flex flex-col sm:flex-row items-center justify-between gap-3 text-[12px] border-t" style={{ borderColor: 'rgba(255,253,249,0.10)', color: '#8F8A80' }}>
          <span>© {year} Librum Kviz</span>
          <div className="flex items-center gap-4 flex-wrap justify-center">
            <Link href="/politika-privatnosti" className="hover:opacity-70" style={{ color: '#8F8A80' }}>
              Politika privatnosti
            </Link>
            <Link href="/uslovi-koriscenja" className="hover:opacity-70" style={{ color: '#8F8A80' }}>
              Uslovi korišćenja
            </Link>
            <span className="text-[11px]">kviz.librum.club</span>
          </div>
        </div>
      </div>
    </footer>
  )
}
