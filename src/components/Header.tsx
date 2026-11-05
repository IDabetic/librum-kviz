'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { Logo } from './Logo'
import { RangTraka } from './RangTraka'
import { ProdavniceIkonice } from './Prodavnice'
import { TemaPrekidac } from './TemaPrekidac'

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
    <header className="sticky top-0 z-50 backdrop-blur-xl" style={{ background: 'color-mix(in srgb, var(--bg) 82%, transparent)', color: 'var(--ink)' }}>
      <RangTraka />
      <div className="max-w-6xl mx-auto px-4 sm:px-6 h-16 flex items-center gap-8">
        {/* Originalni Librum club logo, netaknut (vlasnik 03.11: logotip se ne dira). */}
        <Logo height={32} priority />
        <nav className="hidden md:flex items-center gap-6 flex-1" aria-label="Glavna navigacija">
          {VEZE.map(v => {
            const aktivna = v.href === '/ranglista' && putanja.startsWith('/ranglista')
            return (
              <Link key={v.href} href={v.href} className="text-[14px] font-medium py-1 transition-colors"
                style={{ color: aktivna ? 'var(--ink)' : 'var(--ink-2)', borderBottom: aktivna ? '2px solid var(--brand)' : '2px solid transparent' }}>
                {v.label}
              </Link>
            )
          })}
        </nav>
        <div className="ml-auto flex items-center gap-3">
          <Link href="/ranglista" className="md:hidden text-[14px] font-medium">Rang lista</Link>
          <TemaPrekidac />
          <ProdavniceIkonice />
        </div>
      </div>
      <div style={{ borderBottom: '1px solid var(--line)' }} />
    </header>
  )
}
