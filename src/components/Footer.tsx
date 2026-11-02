import Link from 'next/link'
import { Logo } from './Logo'

export default function Footer() {
  const year = new Date().getFullYear()
  const categories = [
    'književnosti', 'istorije', 'geografije', 'sporta', 'kulture', 'prirode', 'opšteg znanja',
  ]
  return (
    <footer className="mt-10" style={{ background: '#1A1A1E' }}>
      <div className="h-1.5" style={{ background: 'linear-gradient(90deg, #3A36A0 0%, #3B78E0 50%, #2FBF8A 100%)' }} />
      <div className="max-w-6xl mx-auto px-4 sm:px-6 py-10">
        <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-8 mb-8">
          <div>
            <p className="font-display text-[22px] font-semibold tracking-tight" style={{ color: '#FFFDF9' }}>
              Librum kviz
            </p>
            <p className="text-[12px] mt-3 leading-relaxed" style={{ color: '#A39E95' }}>
              Kviz platforma Librum kluba.<br />
              Igraj, dodaj pitanje, penji se rang-listom.
            </p>
          </div>

          <div>
            <p className="text-[11px] font-bold uppercase tracking-widest mb-3" style={{ color: '#2FBF8A' }}>
              Igre
            </p>
            <ul className="space-y-2 text-[13px]">
              <li><Link href="/pro-kviz" className="hover:opacity-70" style={{ color: '#FFFDF9' }}>PRO kviz</Link></li>
              <li><Link href="/book-kviz" className="hover:opacity-70" style={{ color: '#FFFDF9' }}>Book kviz</Link></li>
              <li><Link href="/kafanski-kviz" className="hover:opacity-70" style={{ color: '#FFFDF9' }}>Kafanski kviz</Link></li>
              <li><Link href="/igraj-zajedno" className="hover:opacity-70" style={{ color: '#FFFDF9' }}>Trivia duel</Link></li>
              <li><Link href="/vesanje" className="hover:opacity-70" style={{ color: '#FFFDF9' }}>Vešanje</Link></li>
              <li><Link href="/brzi-kviz" className="hover:opacity-70" style={{ color: '#FFFDF9' }}>Brzi kviz</Link></li>
              <li><Link href="/ranglista" className="hover:opacity-70" style={{ color: '#FFFDF9' }}>Rang lista</Link></li>
            </ul>
          </div>

          <div>
            <p className="text-[11px] font-bold uppercase tracking-widest mb-3" style={{ color: '#2FBF8A' }}>
              Oblasti znanja
            </p>
            <ul className="space-y-2 text-[13px]" style={{ color: '#A39E95' }}>
              {categories.map(c => (
                <li key={c}>Kviz iz {c}</li>
              ))}
            </ul>
          </div>

          <div>
            <p className="text-[11px] font-bold uppercase tracking-widest mb-3" style={{ color: '#2FBF8A' }}>
              Kontakt
            </p>
            <ul className="space-y-2 text-[13px]">
              <li>
                <a href="mailto:info@librum.club" className="font-semibold hover:opacity-70" style={{ color: '#D4D2F5' }}>
                  info@librum.club
                </a>
              </li>
              <li>
                <Link href="/dodaj-pitanja" className="hover:opacity-70" style={{ color: '#FFFDF9' }}>
                  Dodaj pitanje
                </Link>
              </li>
              <li>
                <a href="https://www.librum.club" rel="noopener noreferrer" className="hover:opacity-70" style={{ color: '#A39E95' }}>
                  librum.club ↗
                </a>
              </li>
            </ul>
          </div>
        </div>

        <div className="pt-6 flex flex-col sm:flex-row items-center justify-between gap-3 text-[12px] border-t" style={{ borderColor: 'rgba(255,253,249,0.10)', color: '#A39E95' }}>
          <span>© {year} Librum Kviz</span>
          <div className="flex items-center gap-4 flex-wrap justify-center">
            <Link href="/politika-privatnosti" className="hover:opacity-70" style={{ color: '#A39E95' }}>
              Politika privatnosti
            </Link>
            <Link href="/uslovi-koriscenja" className="hover:opacity-70" style={{ color: '#A39E95' }}>
              Uslovi korišćenja
            </Link>
            <span className="text-[11px]">kviz.librum.club</span>
          </div>
        </div>
      </div>
    </footer>
  )
}
