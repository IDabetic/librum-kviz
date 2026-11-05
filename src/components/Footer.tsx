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
    <footer className="mt-16" style={{ background: '#12110F', color: '#F3F0E6' }}>
      <div className="max-w-6xl mx-auto px-4 sm:px-6 py-12 grid md:grid-cols-[1.4fr_1fr] gap-10 items-start">
        <div>
          <p className="naslov text-[30px]">Librum kviz</p>
          <p className="mt-2 text-[14px] opacity-75 max-w-md">Osvajač i još šest igara znanja na srpskom. Besplatno za iPhone i Android.</p>
          <div className="mt-6"><Prodavnice tamno /></div>
        </div>
        <ul className="grid grid-cols-2 gap-3 text-[14px] font-semibold">
          <li><Link href="/#osvajanje" className="hover:opacity-70">Osvajač</Link></li>
          <li><Link href="/#igre" className="hover:opacity-70">Igre</Link></li>
          <li><Link href="/ranglista" className="hover:opacity-70">Rang lista</Link></li>
          <li><a href="mailto:info@librum.club" className="hover:opacity-70">info@librum.club</a></li>
          <li><Link href="/politika-privatnosti" className="hover:opacity-70">Privatnost</Link></li>
          <li><Link href="/uslovi-koriscenja" className="hover:opacity-70">Uslovi korišćenja</Link></li>
          <li><Link href="/licence-i-izvori" className="hover:opacity-70">Licence i izvori</Link></li>
          <li><Link href="/brisanje-naloga" className="hover:opacity-70">Brisanje naloga</Link></li>
        </ul>
      </div>
      <p className="max-w-6xl mx-auto px-4 sm:px-6 pb-8 text-[12px] opacity-60">© {godina} Librum club</p>
    </footer>
  )
}
