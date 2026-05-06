'use client'

import Link from 'next/link'
import Image from 'next/image'
import { useRouter, usePathname } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { useEffect, useState, useRef } from 'react'

type RecentUser = { id: string; first_name: string; last_name: string; nickname: string; avatar: string; created_at: string }

function timeAgo(dateStr: string): string {
  const diff = Date.now() - new Date(dateStr).getTime()
  const mins = Math.floor(diff / 60000)
  if (mins < 1) return 'upravo'
  if (mins < 60) return `pre ${mins} min`
  const hours = Math.floor(mins / 60)
  if (hours < 24) return `pre ${hours} h`
  const days = Math.floor(hours / 24)
  if (days < 7) return `pre ${days} dan${days > 1 ? 'a' : ''}`
  const weeks = Math.floor(days / 7)
  return `pre ${weeks} ned${weeks > 1 ? 'elje' : 'elju'}`
}

const NAV_LINKS = [
  { href: '/kvizovi',          label: 'Kvizovi',          icon: '📚' },
  { href: '/leaderboard',      label: 'Rang lista',       icon: '🏆' },
  { href: '/igraj-zajedno',    label: 'Igraj zajedno',    icon: '⚔️' },
  { href: '/predlozi-pitanje', label: 'Predloži pitanje', icon: '💡' },
]

export default function Header() {
  const router = useRouter()
  const pathname = usePathname()
  const [userName, setUserName] = useState<string | null>(null)
  const [userAvatar, setUserAvatar] = useState<string | null>(null)
  const [mobileOpen, setMobileOpen] = useState(false)
  const [recentUsers, setRecentUsers] = useState<RecentUser[]>([])
  const [showRecent, setShowRecent] = useState(false)
  const recentRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const supabase = createClient()
    supabase.auth.getUser().then(({ data: { user } }) => {
      if (user) {
        supabase
          .from('profiles')
          .select('first_name, avatar')
          .eq('id', user.id)
          .single()
          .then(({ data }) => {
            if (data) {
              setUserName(data.first_name)
              setUserAvatar(data.avatar || null)
            }
          })
      }
    })
  }, [])

  useEffect(() => {
    const supabase = createClient()
    supabase.from('profiles')
      .select('id, first_name, last_name, nickname, avatar, created_at')
      .order('created_at', { ascending: false })
      .limit(15)
      .then(({ data }) => { if (data) setRecentUsers(data as RecentUser[]) })
  }, [])

  useEffect(() => {
    if (!showRecent) return
    function handleClick(e: MouseEvent) {
      if (recentRef.current && !recentRef.current.contains(e.target as Node)) setShowRecent(false)
    }
    document.addEventListener('mousedown', handleClick)
    return () => document.removeEventListener('mousedown', handleClick)
  }, [showRecent])

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

            {/* Recent members dropdown */}
            {recentUsers.length > 0 && (
              <div ref={recentRef} className="relative ml-1">
                <button
                  onClick={() => setShowRecent(o => !o)}
                  className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-sm font-semibold transition-all"
                  style={showRecent
                    ? { background: '#FDC361', color: '#1A1C4E', border: '1px solid #FDC361' }
                    : { background: 'rgba(253,195,97,0.15)', color: '#FDC361', border: '1px solid rgba(253,195,97,0.4)' }}
                >
                  👥 <span className="text-xs">Novi</span>
                </button>
                {showRecent && (
                  <div className="absolute right-0 top-full mt-2 w-72 bg-white rounded-2xl shadow-2xl border border-gray-100 overflow-hidden z-50">
                    <div className="px-4 py-3 border-b border-gray-50">
                      <p className="font-bold text-sm" style={{ color: '#2C2D81' }}>Novi članovi</p>
                    </div>
                    <div className="max-h-80 overflow-y-auto">
                      {recentUsers.map(u => {
                        const name = u.nickname || `${u.first_name} ${u.last_name}`.trim() || 'Igrač'
                        return (
                          <Link key={u.id} href={`/profil/${u.id}`} onClick={() => setShowRecent(false)}
                            className="flex items-center gap-3 px-4 py-3 border-b border-gray-50 last:border-0 hover:bg-gray-50 transition-colors">
                            <div className="w-9 h-9 rounded-xl overflow-hidden flex-shrink-0">
                              {u.avatar
                                ? <Image src={`/avatars/${u.avatar}`} alt={name} width={36} height={36} className="w-full h-full object-cover" />
                                : <div className="w-full h-full flex items-center justify-center text-sm font-bold text-white" style={{ background: 'linear-gradient(135deg, #2C2D81, #3766B0)' }}>{name[0]}</div>
                              }
                            </div>
                            <div className="flex-1 min-w-0">
                              <p className="font-semibold text-sm text-gray-800 truncate">{name}</p>
                              <p className="text-xs text-gray-400">{timeAgo(u.created_at)}</p>
                            </div>
                          </Link>
                        )
                      })}
                    </div>
                  </div>
                )}
              </div>
            )}
          </nav>

          {/* Right: avatar + logout (desktop) + hamburger (mobile) */}
          <div className="flex items-center gap-3">
            {userName && (
              <Link href="/profil" className="hidden md:flex items-center gap-2 rounded-xl px-2 py-1 transition-all hover:bg-white/10">
                <div className="w-8 h-8 rounded-full overflow-hidden flex-shrink-0 border-2 border-[#FDC361]">
                  {userAvatar
                    ? <Image src={`/avatars/${userAvatar}`} alt={userName} width={32} height={32} className="w-full h-full object-cover" />
                    : <div className="w-full h-full flex items-center justify-center text-sm font-bold" style={{ background: '#FDC361', color: '#1A1C4E' }}>{userName[0].toUpperCase()}</div>
                  }
                </div>
                <span className="text-sm font-medium" style={{ color: 'rgba(255,255,255,0.85)' }}>
                  {userName}
                </span>
              </Link>
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
              <Link href="/profil" className="flex items-center gap-2 pb-3 mb-1" style={{ borderBottom: '1px solid rgba(255,255,255,0.1)' }}>
                <div className="w-8 h-8 rounded-full overflow-hidden flex-shrink-0 border-2 border-[#FDC361]">
                  {userAvatar
                    ? <Image src={`/avatars/${userAvatar}`} alt={userName} width={32} height={32} className="w-full h-full object-cover" />
                    : <div className="w-full h-full flex items-center justify-center text-sm font-bold" style={{ background: '#FDC361', color: '#1A1C4E' }}>{userName[0].toUpperCase()}</div>
                  }
                </div>
                <span className="text-sm font-medium" style={{ color: 'rgba(255,255,255,0.85)' }}>
                  {userName}
                </span>
              </Link>
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
            {recentUsers.length > 0 && (
              <div>
                <p className="px-3 pt-3 pb-1 text-xs font-semibold uppercase tracking-wide" style={{ color: 'rgba(255,255,255,0.35)' }}>Novi članovi</p>
                {recentUsers.slice(0, 5).map(u => {
                  const name = u.nickname || `${u.first_name} ${u.last_name}`.trim() || 'Igrač'
                  return (
                    <Link key={u.id} href={`/profil/${u.id}`}
                      className="flex items-center gap-2.5 px-3 py-2 rounded-xl transition-all"
                      style={{ color: 'rgba(255,255,255,0.7)' }}>
                      <div className="w-7 h-7 rounded-lg overflow-hidden flex-shrink-0">
                        {u.avatar
                          ? <Image src={`/avatars/${u.avatar}`} alt={name} width={28} height={28} className="w-full h-full object-cover" />
                          : <div className="w-full h-full flex items-center justify-center text-xs font-bold text-white" style={{ background: 'linear-gradient(135deg, #2C2D81, #3766B0)' }}>{name[0]}</div>
                        }
                      </div>
                      <div className="flex-1 min-w-0">
                        <span className="text-sm font-medium truncate block">{name}</span>
                      </div>
                      <span className="text-xs" style={{ color: 'rgba(255,255,255,0.3)' }}>{timeAgo(u.created_at)}</span>
                    </Link>
                  )
                })}
              </div>
            )}
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
