'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { Logo } from './Logo'
import { RangTraka } from './RangTraka'
import { ProdavniceIkonice } from './Prodavnice'

/**
 * Zaglavlje novog sajta (vlasnik 03.11.2026): logo, tri veze i preuzimanje aplikacije.
 * Sajt je izlog aplikacije: bez prijave i registracije; rang lista uživo je traka na vrhu.
 *
 * @example <Header />
 */
const VEZE = [
  { href: '/#osvajanje', label: 'Osvajač' },
  { href: '/#igre', label: 'Igre' },
  { href: '/ranglista', label: 'Rang lista' },
]

export default function Header() {
  const putanja = usePathname()
  return (
    <header className="sticky top-0 z-50" style={{ background: '#F3F0E6', color: '#12110F' }}>
      <RangTraka />
      <div className="max-w-6xl mx-auto px-4 sm:px-6 h-[72px] flex items-center gap-6" style={{ borderBottom: '1.5px solid #E7E1D0' }}>
        {/* Originalni Librum club logo, netaknut (vlasnik 03.11: logotip se ne dira). */}
        <Logo height={32} priority />
        <nav className="hidden md:flex items-center gap-6 flex-1" aria-label="Glavna navigacija">
          {VEZE.map(v => {
            const aktivna = v.href === '/ranglista' && putanja.startsWith('/ranglista')
            return (
              <Link key={v.href} href={v.href} className="text-[14px] font-semibold py-1"
                style={{ color: '#12110F', borderBottom: aktivna ? '2px solid #151515' : '2px solid transparent' }}>
                {v.label}
              </Link>
            )
          })}
        </nav>
        <div className="ml-auto flex items-center gap-3">
          <Link href="/ranglista" className="md:hidden text-[14px] font-semibold">Rang lista</Link>
          <ProdavniceIkonice />
        </div>
      </div>
    </header>
  )
}
