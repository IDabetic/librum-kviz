import Link from 'next/link'
import { Prodavnice } from './Prodavnice'

/**
 * Podnožje novog sajta: preuzimanje aplikacije, rang lista i pravni tekstovi (bez prijave, vlasnik 03.11.2026).
 *
 * @example <Footer />
 */
export default function Footer() {
  const godina = new Date().getFullYear()
  return (
    <footer className="mt-20" style={{ background: 'var(--bg-2)', color: 'var(--ink)', borderTop: '1px solid var(--line)' }}>
      <div className="max-w-6xl mx-auto px-4 sm:px-6 py-12 grid md:grid-cols-[1.4fr_1fr] gap-10 items-start">
        <div>
          <p className="naslov text-[26px]">Librum kviz</p>
          <p className="mt-2 text-[14px] max-w-md" style={{ color: 'var(--ink-2)' }}>Osvajač i još šest igara znanja na srpskom. Besplatno za iPhone i Android.</p>
          <div className="mt-6"><Prodavnice /></div>
        </div>
        <ul className="grid grid-cols-2 gap-3 text-[14px]" style={{ color: 'var(--ink-2)' }}>
          <li><Link href="/#osvajanje" className="hover:text-[var(--ink)]">Osvajač</Link></li>
          <li><Link href="/#igre" className="hover:text-[var(--ink)]">Igre</Link></li>
          <li><Link href="/ranglista" className="hover:text-[var(--ink)]">Rang lista</Link></li>
          <li><a href="mailto:info@librum.club" className="hover:text-[var(--ink)]">info@librum.club</a></li>
          <li><Link href="/politika-privatnosti" className="hover:text-[var(--ink)]">Privatnost</Link></li>
          <li><Link href="/uslovi-koriscenja" className="hover:text-[var(--ink)]">Uslovi korišćenja</Link></li>
          <li><Link href="/licence-i-izvori" className="hover:text-[var(--ink)]">Licence i izvori</Link></li>
          <li><Link href="/brisanje-naloga" className="hover:text-[var(--ink)]">Brisanje naloga</Link></li>
        </ul>
      </div>
      <p className="max-w-6xl mx-auto px-4 sm:px-6 pb-8 text-[12px]" style={{ color: 'var(--ink-3)' }}>© {godina} Librum club</p>
    </footer>
  )
}
