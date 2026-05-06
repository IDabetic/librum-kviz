'use client'

import Link from 'next/link'
import Image from 'next/image'
import { useRouter, usePathname } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { useEffect, useState } from 'react'

const NAV_LINKS = [
  { href: '/kvizovi',          label: 'Kvizovi',          icon: '📚' },
  { href: '/leaderboard',      label: 'Rang lista',       icon: '🏆' },
  { href: '/igraj-zajedno',    label: 'Igraj zajedno',    icon: '⚔️' },
  { href: '/predlozi-pitanje', label: 'Predloži pitanje', icon: '💡' },
  { href: '/profil',           label: 'Profil',           icon: '👤' },
]

export default function Header() {
  const router = useRouter()
  const pathname = usePathname()
  const [userName, setUserName] = useState<string | null>(null)
  const [mobileOpen, setMobileOpen] = useState(false)

  useEffect(() => {
    const supabase = createClient()
    supabase.auth.getUser().then(({ data: { user } }) => {
      if (user) {
        supabase
          .from('profiles')
          .select('first_name')
          .eq('id', user.id)
          .single()
          .then(({ data }) => {
            if (data) setUserName(data.first_name)
          })
      }
    })
  }, [])

  useEffect(() => {
    setMobileOpen(false)
  }, [pathname])

  async function handleLogout() {
    await createClient().auth.signOut()
    router.push('/')
    router.refresh()
  }

  return (
    <>
      <header
        className="sticky top-0 z-50"
        style={{
          background: 'linear-gradient(135deg, #1A1C4E 0%, #2C2D81 60%, #3766B0 100%)',
          borderBottom: '2px solid #FDC361',
          boxShadow: '0 4px 20px rgba(26,28,78,0.25)',
        }}
      >
        <div className="max-w-6xl mx-auto px-4 h-16 flex items-center justify-between">
          {/* Logo */}
          <a href="https://www.librum.club" rel="noopener noreferrer" className="flex-shrink-0">
            <Image
              src="/logo-dark.png"
              alt="Librum club"
              height={36}
              width={160}
              style={{ objectFit: 'contain', objectPosition: 'left' }}
            />
          </a>

          {/* Desktop nav */}
          <nav className="hidden md:flex items-center gap-1">
            {NAV_LINKS.map(({ href, label, icon }) => {
              const active = pathname.startsWith(href)
              return (
                <Link
                  key={href}
                  href={href}
                  className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-sm font-medium transition-all"
                  style={active
                    ? { background: 'rgba(253,195,97,0.2)', color: '#FDC361', border: '1px solid rgba(253,195,97,0.35)' }
                    : { color: 'rgba(255,255,255,0.75)', border: '1px solid transparent' }
                  }
                  onMouseEnter={e => { if (!active) (e.currentTarget as HTMLAnchorElement).style.color = '#fff' }}
                  onMouseLeave={e => { if (!active) (e.currentTarget as HTMLAnchorElement).style.color = 'rgba(255,255,255,0.75)' }}
                >
                  <span className="text-base leading-none">{icon}</span>
                  {label}
                </Link>
              )
            })}
            <a
              href="https://www.librum.club"
              rel="noopener noreferrer"
              className="ml-2 flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-sm font-medium transition-all"
              style={{ color: 'rgba(255,255,255,0.55)', border: '1px solid transparent' }}
              onMouseEnter={e => { (e.currentTarget as HTMLAnchorElement).style.color = '#fff' }}
              onMouseLeave={e => { (e.currentTarget as HTMLAnchorElement).style.color = 'rgba(255,255,255,0.55)' }}
            >
              ← Klub
            </a>
          </nav>

          {/* Right: avatar + logout (desktop) + hamburger (mobile) */}
          <div className="flex items-center gap-3">
            {userName && (
              <div className="hidden md:flex items-center gap-2">
                <div
                  className="w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold"
                  style={{ background: '#FDC361', color: '#1A1C4E' }}
                >
                  {userName[0].toUpperCase()}
                </div>
                <span className="text-sm font-medium" style={{ color: 'rgba(255,255,255,0.85)' }}>
                  {userName}
                </span>
              </div>
            )}
            <button
              onClick={handleLogout}
              className="text-sm px-3 py-1.5 rounded-xl font-medium transition-all hidden md:block"
              style={{ color: 'rgba(255,255,255,0.6)', border: '1px solid rgba(255,255,255,0.2)' }}
              onMouseEnter={e => {
                (e.currentTarget as HTMLButtonElement).style.color = '#fff'
                ;(e.currentTarget as HTMLButtonElement).style.borderColor = 'rgba(255,255,255,0.5)'
              }}
              onMouseLeave={e => {
                (e.currentTarget as HTMLButtonElement).style.color = 'rgba(255,255,255,0.6)'
                ;(e.currentTarget as HTMLButtonElement).style.borderColor = 'rgba(255,255,255,0.2)'
              }}
            >
              Odjava
            </button>

            {/* Hamburger — mobile only */}
            <button
              onClick={() => setMobileOpen(o => !o)}
              className="md:hidden flex flex-col justify-center items-center w-10 h-10 rounded-xl gap-1.5 transition-all"
              style={{ border: '1px solid rgba(255,255,255,0.2)' }}
              aria-label="Meni"
            >
              <span
                className="block w-5 h-0.5 transition-transform duration-200"
                style={{ background: '#FDC361', transform: mobileOpen ? 'rotate(45deg) translate(2px, 2px)' : '' }}
              />
              <span
                className="block w-5 h-0.5 transition-opacity duration-200"
                style={{ background: '#FDC361', opacity: mobileOpen ? 0 : 1 }}
              />
              <span
                className="block w-5 h-0.5 transition-transform duration-200"
                style={{ background: '#FDC361', transform: mobileOpen ? 'rotate(-45deg) translate(2px, -2px)' : '' }}
              />
            </button>
          </div>
        </div>

        {/* Mobile drawer */}
        {mobileOpen && (
          <div
            className="md:hidden px-4 py-4 flex flex-col gap-1"
            style={{ borderTop: '1px solid rgba(255,255,255,0.1)', background: 'rgba(26,28,78,0.97)' }}
          >
            {userName && (
              <div className="flex items-center gap-2 pb-3 mb-1" style={{ borderBottom: '1px solid rgba(255,255,255,0.1)' }}>
                <div
                  className="w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold flex-shrink-0"
                  style={{ background: '#FDC361', color: '#1A1C4E' }}
                >
                  {userName[0].toUpperCase()}
                </div>
                <span className="text-sm font-medium" style={{ color: 'rgba(255,255,255,0.85)' }}>
                  {userName}
                </span>
              </div>
            )}
            {NAV_LINKS.map(({ href, label, icon }) => {
              const active = pathname.startsWith(href)
              return (
                <Link
                  key={href}
                  href={href}
                  className="flex items-center gap-2.5 px-3 py-2.5 rounded-xl text-sm font-medium transition-all"
                  style={active
                    ? { background: 'rgba(253,195,97,0.15)', color: '#FDC361' }
                    : { color: 'rgba(255,255,255,0.7)' }
                  }
                >
                  <span className="text-base">{icon}</span>
                  {label}
                </Link>
              )
            })}
            <a
              href="https://www.librum.club"
              rel="noopener noreferrer"
              className="flex items-center gap-2.5 px-3 py-2.5 rounded-xl text-sm font-medium"
              style={{ color: 'rgba(255,255,255,0.45)' }}
            >
              ← Nazad u Klub
            </a>
            <div className="pt-3 mt-1" style={{ borderTop: '1px solid rgba(255,255,255,0.1)' }}>
              <button
                onClick={handleLogout}
                className="w-full text-left px-3 py-2.5 rounded-xl text-sm font-medium"
                style={{ color: '#f87171' }}
              >
                Odjava
              </button>
            </div>
          </div>
        )}
      </header>
    </>
  )
}

function NavLink({ href, current, children }: { href: string; current: string; children: React.ReactNode }) {
  const active = current.startsWith(href)
  return (
    <Link
      href={href}
      className={`text-sm font-medium transition-colors ${
        active ? 'text-[#FDC361]' : 'text-white/70 hover:text-white'
      }`}
    >
      {children}
    </Link>
  )
}

export function LibrumIcon({ size = 32, dark = false }: { size?: number; dark?: boolean }) {
  return (
    <Image
      src={dark ? '/logo-dark.png' : '/logo-light.png'}
      alt="Librum club"
      height={size}
      width={size * 4}
      style={{ objectFit: 'contain', objectPosition: 'left' }}
    />
  )
}
