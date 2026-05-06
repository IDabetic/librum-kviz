'use client'

import Link from 'next/link'
import Image from 'next/image'
import { useRouter, usePathname } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { useEffect, useState, useRef } from 'react'
import { IconHome, IconDiscover, IconTrophy, IconSwords, IconHint, IconUsers, IconMenu, IconClose, IconLogout } from './icons'

type RecentUser = { id: string; first_name: string; last_name: string; nickname: string; avatar: string; created_at: string }

const NAV_LINKS = [
  { href: '/kvizovi',          label: 'Kvizovi',          Icon: IconDiscover },
  { href: '/leaderboard',      label: 'Rang lista',       Icon: IconTrophy },
  { href: '/igraj-zajedno',    label: 'Igraj zajedno',    Icon: IconSwords },
  { href: '/predlozi-pitanje', label: 'Predloži pitanje', Icon: IconHint },
]

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
      if (!user) return
      supabase.from('profiles').select('first_name, avatar').eq('id', user.id).single()
        .then(({ data }) => {
          if (data) {
            setUserName(data.first_name)
            setUserAvatar(data.avatar || null)
          }
        })
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

  useEffect(() => { setMobileOpen(false) }, [pathname])

  async function handleLogout() {
    await createClient().auth.signOut()
    router.push('/')
    router.refresh()
  }

  return (
    <>
      <header className="sticky top-0 z-50 backdrop-blur-xl"
        style={{ background: 'rgba(252,252,252,0.78)', borderBottom: '1px solid rgba(52,52,52,0.06)' }}>
        <div className="max-w-6xl mx-auto px-4 sm:px-6 h-16 flex items-center justify-between gap-4">
          {/* Logo */}
          <Link href="/" className="flex-shrink-0 flex items-center gap-2">
            <span className="font-extrabold text-[18px] tracking-tight" style={{ color: '#343434' }}>
              Librum<span style={{ color: '#609DED' }}>.</span>
            </span>
          </Link>

          {/* Desktop nav */}
          <nav className="hidden md:flex items-center gap-1 flex-1 justify-center">
            {NAV_LINKS.map(({ href, label, Icon }) => {
              const active = pathname.startsWith(href)
              return (
                <Link
                  key={href}
                  href={href}
                  className="flex items-center gap-2 px-3.5 py-2 rounded-full text-[13px] font-medium transition-all"
                  style={active
                    ? { background: '#609DED', color: 'white' }
                    : { color: '#343434' }
                  }
                  onMouseEnter={e => { if (!active) (e.currentTarget as HTMLAnchorElement).style.background = 'rgba(52,52,52,0.06)' }}
                  onMouseLeave={e => { if (!active) (e.currentTarget as HTMLAnchorElement).style.background = 'transparent' }}
                >
                  <Icon size={16} strokeWidth={2.2} />
                  {label}
                </Link>
              )
            })}
          </nav>

          {/* Right side */}
          <div className="flex items-center gap-2">
            {/* Recent members dropdown */}
            {recentUsers.length > 0 && (
              <div ref={recentRef} className="relative hidden md:block">
                <button
                  onClick={() => setShowRecent(o => !o)}
                  className="flex items-center justify-center w-10 h-10 rounded-full transition-all"
                  style={showRecent
                    ? { background: '#609DED', color: 'white' }
                    : { background: 'rgba(52,52,52,0.06)', color: '#343434' }}
                  aria-label="Novi članovi"
                >
                  <IconUsers size={18} strokeWidth={2.2} />
                </button>
                {showRecent && (
                  <div className="absolute right-0 top-full mt-2 w-80 card-soft overflow-hidden z-50 animate-pop-in">
                    <div className="px-5 py-4 border-b border-[#F2F2F2]">
                      <p className="font-bold text-[15px]" style={{ color: '#343434' }}>Novi članovi</p>
                      <p className="text-[12px] mt-0.5" style={{ color: '#9C9C9C' }}>Poslednji koji su se pridružili</p>
                    </div>
                    <div className="max-h-96 overflow-y-auto">
                      {recentUsers.map(u => {
                        const name = u.nickname || `${u.first_name} ${u.last_name}`.trim() || 'Igrač'
                        return (
                          <Link key={u.id} href={`/profil/${u.id}`} onClick={() => setShowRecent(false)}
                            className="flex items-center gap-3 px-5 py-3 hover:bg-[#F2F2F2] transition-colors">
                            <div className="w-10 h-10 rounded-full overflow-hidden flex-shrink-0 bg-[#F2F2F2]">
                              {u.avatar
                                ? <Image src={`/avatars/${u.avatar}`} alt={name} width={40} height={40} className="w-full h-full object-cover" />
                                : <div className="w-full h-full flex items-center justify-center text-sm font-bold" style={{ background: '#609DED', color: 'white' }}>{name[0]}</div>
                              }
                            </div>
                            <div className="flex-1 min-w-0">
                              <p className="font-semibold text-[14px] truncate" style={{ color: '#343434' }}>{name}</p>
                              <p className="text-[12px]" style={{ color: '#9C9C9C' }}>{timeAgo(u.created_at)}</p>
                            </div>
                          </Link>
                        )
                      })}
                    </div>
                  </div>
                )}
              </div>
            )}

            {/* User avatar (clickable → /profil) */}
            {userName && (
              <Link href="/profil" className="hidden md:flex items-center gap-2.5 pl-1 pr-3 py-1 rounded-full transition-all hover:bg-[#F2F2F2]">
                <div className="w-9 h-9 rounded-full overflow-hidden flex-shrink-0 bg-[#F2F2F2]">
                  {userAvatar
                    ? <Image src={`/avatars/${userAvatar}`} alt={userName} width={36} height={36} className="w-full h-full object-cover" />
                    : <div className="w-full h-full flex items-center justify-center text-sm font-bold" style={{ background: '#FFCB46', color: '#343434' }}>{userName[0].toUpperCase()}</div>
                  }
                </div>
                <span className="text-[13px] font-semibold" style={{ color: '#343434' }}>{userName}</span>
              </Link>
            )}

            {/* Logout (desktop) */}
            {userName && (
              <button
                onClick={handleLogout}
                className="hidden md:flex items-center justify-center w-10 h-10 rounded-full transition-all"
                style={{ color: '#9C9C9C' }}
                onMouseEnter={e => {
                  (e.currentTarget as HTMLButtonElement).style.background = 'rgba(229,83,83,0.10)'
                  ;(e.currentTarget as HTMLButtonElement).style.color = '#E55353'
                }}
                onMouseLeave={e => {
                  (e.currentTarget as HTMLButtonElement).style.background = 'transparent'
                  ;(e.currentTarget as HTMLButtonElement).style.color = '#9C9C9C'
                }}
                aria-label="Odjava"
              >
                <IconLogout size={18} strokeWidth={2.2} />
              </button>
            )}

            {/* Mobile hamburger */}
            <button
              onClick={() => setMobileOpen(o => !o)}
              className="md:hidden flex items-center justify-center w-10 h-10 rounded-full transition-all"
              style={{ background: mobileOpen ? '#343434' : 'rgba(52,52,52,0.06)', color: mobileOpen ? 'white' : '#343434' }}
              aria-label="Meni"
            >
              {mobileOpen ? <IconClose size={20} strokeWidth={2.2} /> : <IconMenu size={20} strokeWidth={2.2} />}
            </button>
          </div>
        </div>

        {/* Mobile drawer */}
        {mobileOpen && (
          <div className="md:hidden border-t border-[#F2F2F2] animate-fade-in">
            <div className="max-w-6xl mx-auto px-4 py-3 space-y-1">
              {/* User card */}
              {userName && (
                <Link href="/profil" className="flex items-center gap-3 p-3 rounded-2xl mb-2"
                  style={{ background: '#F2F2F2' }}>
                  <div className="w-11 h-11 rounded-full overflow-hidden flex-shrink-0 bg-white">
                    {userAvatar
                      ? <Image src={`/avatars/${userAvatar}`} alt={userName} width={44} height={44} className="w-full h-full object-cover" />
                      : <div className="w-full h-full flex items-center justify-center text-sm font-bold" style={{ background: '#FFCB46', color: '#343434' }}>{userName[0].toUpperCase()}</div>
                    }
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-[14px] font-bold truncate" style={{ color: '#343434' }}>{userName}</p>
                    <p className="text-[12px]" style={{ color: '#9C9C9C' }}>Otvori profil →</p>
                  </div>
                </Link>
              )}

              {NAV_LINKS.map(({ href, label, Icon }) => {
                const active = pathname.startsWith(href)
                return (
                  <Link key={href} href={href}
                    className="flex items-center gap-3 px-4 py-3 rounded-2xl text-[14px] font-medium transition-all"
                    style={active
                      ? { background: '#609DED', color: 'white' }
                      : { color: '#343434' }
                    }>
                    <Icon size={18} strokeWidth={2.2} />
                    {label}
                  </Link>
                )
              })}

              {recentUsers.length > 0 && (
                <div className="pt-3 mt-3 border-t border-[#F2F2F2]">
                  <p className="px-4 mb-2 text-[11px] font-bold uppercase tracking-wider" style={{ color: '#9C9C9C' }}>Novi članovi</p>
                  {recentUsers.slice(0, 5).map(u => {
                    const name = u.nickname || `${u.first_name} ${u.last_name}`.trim() || 'Igrač'
                    return (
                      <Link key={u.id} href={`/profil/${u.id}`}
                        className="flex items-center gap-3 px-4 py-2.5 rounded-2xl">
                        <div className="w-8 h-8 rounded-full overflow-hidden flex-shrink-0 bg-[#F2F2F2]">
                          {u.avatar
                            ? <Image src={`/avatars/${u.avatar}`} alt={name} width={32} height={32} className="w-full h-full object-cover" />
                            : <div className="w-full h-full flex items-center justify-center text-xs font-bold" style={{ background: '#609DED', color: 'white' }}>{name[0]}</div>
                          }
                        </div>
                        <div className="flex-1 min-w-0">
                          <span className="text-[13px] font-semibold truncate block" style={{ color: '#343434' }}>{name}</span>
                          <span className="text-[11px]" style={{ color: '#9C9C9C' }}>{timeAgo(u.created_at)}</span>
                        </div>
                      </Link>
                    )
                  })}
                </div>
              )}

              {userName && (
                <button onClick={handleLogout}
                  className="w-full flex items-center gap-3 px-4 py-3 rounded-2xl text-[14px] font-medium transition-colors mt-3 border-t border-[#F2F2F2] pt-4"
                  style={{ color: '#E55353' }}>
                  <IconLogout size={18} strokeWidth={2.2} />
                  Odjava
                </button>
              )}
            </div>
          </div>
        )}
      </header>
    </>
  )
}

export function LibrumIcon({ size = 32 }: { size?: number; dark?: boolean }) {
  return (
    <span className="font-extrabold tracking-tight" style={{ color: '#343434', fontSize: size * 0.6 }}>
      Librum<span style={{ color: '#609DED' }}>.</span>
    </span>
  )
}
