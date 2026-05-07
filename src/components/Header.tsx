'use client'

import Link from 'next/link'
import Image from 'next/image'
import { useRouter, usePathname } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { useEffect, useState, useRef } from 'react'
import {
  IconHome, IconTrophy, IconSwords, IconHint, IconUsers,
  IconMenu, IconClose, IconLogout, IconTime, IconStar,
} from './icons'
import { Logo } from './Logo'

type RecentUser = { id: string; first_name: string; last_name: string; nickname: string; avatar: string; created_at: string }

// Six game modes. Each gets its own colored card in the "Igre" dropdown.
const GAMES = [
  { href: '/igraj',           label: 'PRO kviz',       Icon: IconHome,   accent: '#609DED', tint: 'rgba(96,157,237,0.12)',  desc: 'Klasični kviz, lifelines i niz' },
  { href: '/book-kviz',       label: 'Book kviz',      Icon: IconStar,   accent: '#9c7a13', tint: 'rgba(255,203,70,0.18)',  desc: 'Pitanja iz književnosti, top žanr' },
  { href: '/kafanski-kviz',   label: 'Kafanski kviz',  Icon: IconStar,   accent: '#b91c1c', tint: 'rgba(229,83,83,0.12)',   desc: 'Muzika i kafanski hitovi' },
  { href: '/igraj-zajedno',   label: 'Trivia duel',    Icon: IconSwords, accent: '#E55353', tint: 'rgba(229,83,83,0.10)',   desc: 'Jedan na jedan, isti pitanja' },
  { href: '/vesanje',         label: 'Vešanje',        Icon: IconHint,   accent: '#15803d', tint: 'rgba(76,175,80,0.12)',   desc: 'Pogađanje slova po kategorijama' },
  { href: '/brzi-kviz',       label: 'Brzi kviz',      Icon: IconTime,   accent: '#b91c1c', tint: 'rgba(229,83,83,0.08)',   desc: 'Tačno/netačno, 60 sekundi' },
]

const TOP_LINKS = [
  { href: '/leaderboard',     label: 'Rang lista',     Icon: IconTrophy, accent: '#9c7a13', tint: 'rgba(255,203,70,0.18)' },
]

const MOBILE_EXTRA_LINKS = [
  { href: '/predlozi-pitanje', label: 'Predloži pitanje', Icon: IconUsers, accent: '#609DED', tint: 'rgba(96,157,237,0.10)' },
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
  const [showGames, setShowGames] = useState(false)
  const recentRef = useRef<HTMLDivElement>(null)
  const gamesRef = useRef<HTMLDivElement>(null)

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

  // Defer recent-users fetch until the dropdown actually opens or the
  // mobile drawer is opened. Saves ~5-15kb on first paint.
  const recentLoadedRef = useRef(false)
  useEffect(() => {
    if (!showRecent && !mobileOpen) return
    if (recentLoadedRef.current) return
    recentLoadedRef.current = true
    createClient().from('profiles')
      .select('id, first_name, last_name, nickname, avatar, created_at')
      .order('created_at', { ascending: false })
      .limit(15)
      .then(({ data }) => { if (data) setRecentUsers(data as RecentUser[]) })
  }, [showRecent, mobileOpen])

  // Outside-click for both dropdowns. Single listener handles both.
  useEffect(() => {
    if (!showRecent && !showGames) return
    function handleClick(e: MouseEvent) {
      if (showRecent && recentRef.current && !recentRef.current.contains(e.target as Node)) setShowRecent(false)
      if (showGames && gamesRef.current && !gamesRef.current.contains(e.target as Node)) setShowGames(false)
    }
    document.addEventListener('mousedown', handleClick)
    return () => document.removeEventListener('mousedown', handleClick)
  }, [showRecent, showGames])

  // Close everything when route changes — pathname comes from the router
  // (external system), so this is a sync-from-router effect.
  useEffect(() => {
    setMobileOpen(false) // eslint-disable-line react-hooks/set-state-in-effect
    setShowGames(false)
    setShowRecent(false)
  }, [pathname])

  async function handleLogout() {
    await createClient().auth.signOut()
    router.push('/')
    router.refresh()
  }

  // Active when current path matches any game route (so the "Igre"
  // trigger pill highlights when the user is inside any game).
  const inGame = GAMES.some(g => pathname === g.href || pathname.startsWith(g.href + '/'))

  return (
    <>
      <header className="sticky top-0 z-50 backdrop-blur-xl"
        style={{ background: 'rgba(252,252,252,0.78)', borderBottom: '1px solid rgba(52,52,52,0.06)' }}>
        <div className="max-w-6xl mx-auto px-4 sm:px-6 h-16 flex items-center justify-between gap-4">
          {/* Logo */}
          <Logo height={28} priority />

          {/* Desktop nav — Igre dropdown + Rang lista */}
          <nav className="hidden md:flex items-center gap-1 flex-1 justify-center">
            {/* Igre trigger */}
            <div ref={gamesRef} className="relative">
              <button onClick={() => setShowGames(o => !o)}
                className="flex items-center gap-2 px-3.5 py-2 rounded-full text-[13px] font-semibold transition-all"
                style={inGame || showGames
                  ? { background: '#343434', color: 'white' }
                  : { color: '#343434' }}
                onMouseEnter={e => { if (!(inGame || showGames)) (e.currentTarget as HTMLButtonElement).style.background = 'rgba(52,52,52,0.06)' }}
                onMouseLeave={e => { if (!(inGame || showGames)) (e.currentTarget as HTMLButtonElement).style.background = 'transparent' }}>
                <span>Igre</span>
                <svg width="10" height="6" viewBox="0 0 10 6" fill="none" style={{ transform: showGames ? 'rotate(180deg)' : 'rotate(0)', transition: 'transform 0.15s' }}>
                  <path d="M1 1l4 4 4-4" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
              </button>

              {showGames && (
                <div className="absolute left-1/2 -translate-x-1/2 top-full mt-2 w-[min(680px,90vw)] card-soft overflow-hidden z-50 animate-pop-in p-3">
                  <p className="px-3 pt-1 pb-3 text-[11px] font-bold uppercase tracking-widest" style={{ color: '#9C9C9C' }}>
                    Izaberi igru
                  </p>
                  <div className="grid grid-cols-2 lg:grid-cols-3 gap-2">
                    {GAMES.map(g => {
                      const active = pathname === g.href || pathname.startsWith(g.href + '/')
                      return (
                        <Link key={g.href} href={g.href} onClick={() => setShowGames(false)}
                          className="flex items-start gap-3 p-3 rounded-2xl transition-all hover:scale-[1.02]"
                          style={{ background: g.tint, border: active ? `2px solid ${g.accent}` : '2px solid transparent' }}>
                          <div className="w-10 h-10 rounded-2xl flex items-center justify-center flex-shrink-0"
                            style={{ background: g.accent, color: 'white' }}>
                            <g.Icon size={18} strokeWidth={2.2} />
                          </div>
                          <div className="flex-1 min-w-0">
                            <p className="font-bold text-[14px] truncate" style={{ color: g.accent }}>{g.label}</p>
                            <p className="text-[11px] leading-snug mt-0.5" style={{ color: '#343434', opacity: 0.7 }}>{g.desc}</p>
                          </div>
                        </Link>
                      )
                    })}
                  </div>
                </div>
              )}
            </div>

            {/* Top-level links beside Igre */}
            {TOP_LINKS.map(({ href, label, Icon, accent, tint }) => {
              const active = pathname === href || pathname.startsWith(href + '/')
              return (
                <Link key={href} href={href} title={label}
                  className="flex items-center gap-2 px-3.5 py-2 rounded-full text-[13px] font-semibold transition-all"
                  style={active ? { background: accent, color: 'white' } : { color: '#343434' }}
                  onMouseEnter={e => { if (!active) (e.currentTarget as HTMLAnchorElement).style.background = tint }}
                  onMouseLeave={e => { if (!active) (e.currentTarget as HTMLAnchorElement).style.background = 'transparent' }}>
                  <Icon size={16} strokeWidth={2.2} style={active ? undefined : { color: accent }} />
                  <span>{label}</span>
                </Link>
              )
            })}
          </nav>

          {/* Right side */}
          <div className="flex items-center gap-2">
            {/* Recent members dropdown */}
            <div ref={recentRef} className="relative hidden md:block">
              <button onClick={() => setShowRecent(o => !o)}
                className="flex items-center justify-center w-10 h-10 rounded-full transition-all"
                style={showRecent
                  ? { background: '#609DED', color: 'white' }
                  : { background: 'rgba(52,52,52,0.06)', color: '#343434' }}
                aria-label="Novi članovi">
                <IconUsers size={18} strokeWidth={2.2} />
              </button>
              {showRecent && (
                <div className="absolute right-0 top-full mt-2 w-80 card-soft overflow-hidden z-50 animate-pop-in">
                  <div className="px-5 py-4 border-b border-[#F2F2F2]">
                    <p className="font-bold text-[15px]" style={{ color: '#343434' }}>Novi članovi</p>
                    <p className="text-[12px] mt-0.5" style={{ color: '#9C9C9C' }}>Poslednji koji su se pridružili</p>
                  </div>
                  <div className="max-h-96 overflow-y-auto">
                    {recentUsers.length === 0 && (
                      <p className="px-5 py-4 text-[13px]" style={{ color: '#9C9C9C' }}>Učitavanje…</p>
                    )}
                    {recentUsers.map(u => {
                      const name = u.nickname || `${u.first_name} ${u.last_name}`.trim() || 'Igrač'
                      return (
                        <Link key={u.id} href={`/profil/${u.id}`} onClick={() => setShowRecent(false)}
                          className="flex items-center gap-3 px-5 py-3 hover:bg-[#F2F2F2] transition-colors">
                          <div className="w-10 h-10 rounded-full overflow-hidden flex-shrink-0 bg-[#F2F2F2]">
                            {u.avatar
                              ? <Image src={`/avatars/${u.avatar}`} alt={name} width={40} height={40} className="w-full h-full object-cover" />
                              : <div className="w-full h-full flex items-center justify-center text-sm font-bold" style={{ background: '#609DED', color: 'white' }}>{name[0]}</div>}
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

            {/* User avatar */}
            {userName && (
              <Link href="/profil" className="hidden md:flex items-center gap-2.5 pl-1 pr-3 py-1 rounded-full transition-all hover:bg-[#F2F2F2]">
                <div className="w-9 h-9 rounded-full overflow-hidden flex-shrink-0 bg-[#F2F2F2]">
                  {userAvatar
                    ? <Image src={`/avatars/${userAvatar}`} alt={userName} width={36} height={36} className="w-full h-full object-cover" />
                    : <div className="w-full h-full flex items-center justify-center text-sm font-bold" style={{ background: '#FFCB46', color: '#343434' }}>{userName[0].toUpperCase()}</div>}
                </div>
                <span className="text-[13px] font-semibold" style={{ color: '#343434' }}>{userName}</span>
              </Link>
            )}

            {/* Logout (desktop) */}
            {userName && (
              <button onClick={handleLogout}
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
                aria-label="Odjava">
                <IconLogout size={18} strokeWidth={2.2} />
              </button>
            )}

            {/* Mobile hamburger */}
            <button onClick={() => setMobileOpen(o => !o)}
              className="md:hidden flex items-center justify-center w-10 h-10 rounded-full transition-all"
              style={{ background: mobileOpen ? '#343434' : 'rgba(52,52,52,0.06)', color: mobileOpen ? 'white' : '#343434' }}
              aria-label="Meni">
              {mobileOpen ? <IconClose size={20} strokeWidth={2.2} /> : <IconMenu size={20} strokeWidth={2.2} />}
            </button>
          </div>
        </div>

        {/* Mobile drawer */}
        {mobileOpen && (
          <div className="md:hidden border-t border-[#F2F2F2] animate-fade-in">
            <div className="max-w-6xl mx-auto px-4 py-3 space-y-3">
              {/* User card */}
              {userName && (
                <Link href="/profil" className="flex items-center gap-3 p-3 rounded-2xl"
                  style={{ background: '#F2F2F2' }}>
                  <div className="w-11 h-11 rounded-full overflow-hidden flex-shrink-0 bg-white">
                    {userAvatar
                      ? <Image src={`/avatars/${userAvatar}`} alt={userName} width={44} height={44} className="w-full h-full object-cover" />
                      : <div className="w-full h-full flex items-center justify-center text-sm font-bold" style={{ background: '#FFCB46', color: '#343434' }}>{userName[0].toUpperCase()}</div>}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-[14px] font-bold truncate" style={{ color: '#343434' }}>{userName}</p>
                    <p className="text-[12px]" style={{ color: '#9C9C9C' }}>Otvori profil →</p>
                  </div>
                </Link>
              )}

              {/* Igre cards — same grid as desktop dropdown */}
              <div>
                <p className="px-1 mb-2 text-[11px] font-bold uppercase tracking-widest" style={{ color: '#9C9C9C' }}>
                  Igre
                </p>
                <div className="grid grid-cols-2 gap-2">
                  {GAMES.map(g => {
                    const active = pathname === g.href || pathname.startsWith(g.href + '/')
                    return (
                      <Link key={g.href} href={g.href}
                        className="flex flex-col gap-1.5 p-3 rounded-2xl transition-all"
                        style={{ background: g.tint, border: active ? `2px solid ${g.accent}` : '2px solid transparent' }}>
                        <div className="w-9 h-9 rounded-2xl flex items-center justify-center"
                          style={{ background: g.accent, color: 'white' }}>
                          <g.Icon size={16} strokeWidth={2.2} />
                        </div>
                        <p className="font-bold text-[13px] tracking-tight" style={{ color: g.accent }}>{g.label}</p>
                      </Link>
                    )
                  })}
                </div>
              </div>

              {/* Top links + extras */}
              <div className="space-y-1 pt-2 border-t border-[#F2F2F2]">
                {[...TOP_LINKS, ...MOBILE_EXTRA_LINKS].map(({ href, label, Icon, accent, tint }) => {
                  const active = pathname === href || pathname.startsWith(href + '/')
                  return (
                    <Link key={href} href={href}
                      className="flex items-center gap-3 px-4 py-3 rounded-2xl text-[14px] font-medium transition-all"
                      style={active
                        ? { background: accent, color: 'white' }
                        : { color: '#343434', background: tint }}>
                      <Icon size={18} strokeWidth={2.2} style={active ? undefined : { color: accent }} />
                      {label}
                    </Link>
                  )
                })}
              </div>

              {/* Recent users */}
              {recentUsers.length > 0 && (
                <div className="pt-3 mt-3 border-t border-[#F2F2F2]">
                  <p className="px-1 mb-2 text-[11px] font-bold uppercase tracking-wider" style={{ color: '#9C9C9C' }}>Novi članovi</p>
                  {recentUsers.slice(0, 5).map(u => {
                    const name = u.nickname || `${u.first_name} ${u.last_name}`.trim() || 'Igrač'
                    return (
                      <Link key={u.id} href={`/profil/${u.id}`}
                        className="flex items-center gap-3 px-2 py-2.5 rounded-2xl">
                        <div className="w-8 h-8 rounded-full overflow-hidden flex-shrink-0 bg-[#F2F2F2]">
                          {u.avatar
                            ? <Image src={`/avatars/${u.avatar}`} alt={name} width={32} height={32} className="w-full h-full object-cover" />
                            : <div className="w-full h-full flex items-center justify-center text-xs font-bold" style={{ background: '#609DED', color: 'white' }}>{name[0]}</div>}
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
  return <Logo height={size * 0.85} href={null} />
}
