'use client'

import Link from 'next/link'
import Image from 'next/image'
import { useRouter, usePathname } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { useEffect, useState, useRef } from 'react'
import {
  IconHome, IconTrophy, IconUsers, IconQuestion,
  IconMenu, IconClose, IconLogout, IconStar,
} from './icons'
import { Logo } from './Logo'
import { jeAutorPitanja, PRAG_PODRAZUMEVANO } from '@/lib/bedzevi'

type RecentUser = { id: string; first_name: string; last_name: string; nickname: string; avatar: string; created_at: string }
type Contributor = { id: string; first_name: string | null; last_name: string | null; nickname: string | null; avatar: string | null; reports: number; submissions: number; total_contributions: number; accepted: number }

// Top-level nav. Igre su samo u aplikaciji; "Aplikacija" vodi na landing,
// the header itself stays a slim row of plain links — no dropdown.
const NAV_LINKS = [
  { href: '/',                 label: 'Aplikacija',       Icon: IconHome,    accent: '#12907E', tint: 'rgba(18,144,126,0.12)' },
  { href: '/ranglista',      label: 'Rang lista',       Icon: IconTrophy,  accent: '#8A6A12', tint: 'rgba(255,216,77,0.18)' },
  { href: '/nagrade',       label: 'Nagrade',       Icon: IconStar,     accent: '#FFD84D', tint: 'rgba(255,216,77,0.18)' },
  { href: '/dodaj-pitanja', label: 'Dodaj pitanja', Icon: IconQuestion, accent: '#0E6F61', tint: 'rgba(18,144,126,0.12)' },
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
  const [authKnown, setAuthKnown] = useState(false)
  const [mobileOpen, setMobileOpen] = useState(false)
  const [recentUsers, setRecentUsers] = useState<RecentUser[]>([])
  const [showRecent, setShowRecent] = useState(false)
  const recentRef = useRef<HTMLDivElement>(null)
  const [contributors, setContributors] = useState<Contributor[]>([])
  const [pragBedza, setPragBedza] = useState(PRAG_PODRAZUMEVANO)
  const [showContributors, setShowContributors] = useState(false)
  const contribRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const supabase = createClient()
    supabase.auth.getUser().then(({ data: { user } }) => {
      if (!user) {
        setAuthKnown(true)
        return
      }
      supabase.from('profiles').select('first_name, avatar').eq('id', user.id).single()
        .then(({ data }) => {
          if (data) {
            setUserName(data.first_name)
            setUserAvatar(data.avatar || null)
          }
          setAuthKnown(true)
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
    // Recent-members list is public — read from the safe view so we
    // don't depend on profiles RLS allowing cross-row reads.
    createClient().from('public_profiles')
      .select('id, first_name, last_name, nickname, avatar, created_at')
      .order('created_at', { ascending: false })
      .limit(15)
      .then(({ data }) => { if (data) setRecentUsers(data as RecentUser[]) })
  }, [showRecent, mobileOpen])

  // Same lazy-load pattern for contributors. The data comes from a
  // SECURITY-DEFINER view (public_contributors) that aggregates reports
  // + submissions per user, so anon can read it without touching the
  // underlying admin-only tables.
  // Triggers on either the desktop dropdown opening OR the mobile drawer
  // opening — the mobile drawer renders the same data inline.
  const contribLoadedRef = useRef(false)
  useEffect(() => {
    if (!showContributors && !mobileOpen) return
    if (contribLoadedRef.current) return
    contribLoadedRef.current = true
    const sb = createClient()
    sb.from('public_contributors')
      .select('id, first_name, last_name, nickname, avatar, reports, submissions, total_contributions, accepted')
      .order('total_contributions', { ascending: false })
      .limit(15)
      .then(({ data }) => { if (data) setContributors(data as Contributor[]) })
    // Prag bedža je podesiv u adminu, pa se čita zajedno sa listom.
    sb.rpc('prag_bedza').then(({ data }) => {
      const n = Number(data)
      if (Number.isFinite(n) && n > 0) setPragBedza(n)
    })
  }, [showContributors, mobileOpen])

  // Outside-click for the recent-members dropdown.
  useEffect(() => {
    if (!showRecent) return
    function handleClick(e: MouseEvent) {
      if (recentRef.current && !recentRef.current.contains(e.target as Node)) setShowRecent(false)
    }
    document.addEventListener('mousedown', handleClick)
    return () => document.removeEventListener('mousedown', handleClick)
  }, [showRecent])

  // Outside-click for the contributors dropdown.
  useEffect(() => {
    if (!showContributors) return
    function handleClick(e: MouseEvent) {
      if (contribRef.current && !contribRef.current.contains(e.target as Node)) setShowContributors(false)
    }
    document.addEventListener('mousedown', handleClick)
    return () => document.removeEventListener('mousedown', handleClick)
  }, [showContributors])

  // Close mobile drawer + dropdowns when route changes — pathname
  // comes from the router (external system), so this is a sync effect.
  useEffect(() => {
    setMobileOpen(false) // eslint-disable-line react-hooks/set-state-in-effect
    setShowRecent(false)
    setShowContributors(false)
  }, [pathname])

  async function handleLogout() {
    await createClient().auth.signOut()
    router.push('/')
    router.refresh()
  }


  return (
    <>
      <header className="sticky top-0 z-50" style={{ background: '#F3F0E6' }}>
        <div className="max-w-6xl mx-auto px-4 sm:px-6 h-[72px] flex items-center justify-between gap-4"
          style={{ borderBottom: '1.5px solid #E7E1D0' }}>
          <div className="flex items-center gap-3 min-w-0">
            <Logo height={32} priority />
            <span className="hidden sm:block text-[10px] font-semibold uppercase tracking-[0.22em]"
              style={{ color: '#6F6C66' }}>
              Klub · kviz
            </span>
          </div>

          <nav className="hidden md:flex items-center gap-7 flex-1 justify-center">
            {NAV_LINKS.map(({ href, label }) => {
              const active =
                pathname === href ||
                pathname.startsWith(href + '/') ||
                (href === '/' && pathname === '/')
              return (
                <Link key={href} href={href}
                  className="relative text-[13px] font-semibold tracking-wide py-1"
                  style={{ color: '#12110F' }}>
                  {label}
                  {active && (
                    <span className="absolute left-0 right-0 -bottom-[23px] h-[3px]" style={{ background: '#151515' }} />
                  )}
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
                  ? { background: '#12907E', color: 'white' }
                  : { background: 'rgba(21,21,21,0.06)', color: '#151515' }}
                aria-label="Novi članovi">
                <IconUsers size={18} strokeWidth={2.2} />
              </button>
              {showRecent && (
                <div className="absolute right-0 top-full mt-2 w-80 card-soft overflow-hidden z-50 animate-pop-in">
                  <div className="px-5 py-4 border-b border-[#E7E1D0]">
                    <p className="font-bold text-[15px]" style={{ color: '#151515' }}>Novi članovi</p>
                    <p className="text-[12px] mt-0.5" style={{ color: '#6F6C66' }}>Poslednji koji su se pridružili</p>
                  </div>
                  <div className="max-h-96 overflow-y-auto">
                    {recentUsers.length === 0 && (
                      <p className="px-5 py-4 text-[13px]" style={{ color: '#6F6C66' }}>Učitavanje…</p>
                    )}
                    {recentUsers.map(u => {
                      const name = u.nickname || `${u.first_name} ${u.last_name}`.trim() || 'Igrač'
                      return (
                        <Link key={u.id} href={`/profil/${u.id}`} onClick={() => setShowRecent(false)}
                          className="flex items-center gap-3 px-5 py-3 hover:bg-[#E7E1D0] transition-colors">
                          <div className="w-10 h-10 rounded-full overflow-hidden flex-shrink-0 bg-[#E7E1D0]">
                            {u.avatar
                              ? <Image src={`/avatars/${u.avatar}`} alt={name} width={40} height={40} className="w-full h-full object-cover" />
                              : <div className="w-full h-full flex items-center justify-center text-sm font-bold" style={{ background: '#12907E', color: 'white' }}>{name[0]}</div>}
                          </div>
                          <div className="flex-1 min-w-0">
                            <p className="font-semibold text-[14px] truncate" style={{ color: '#151515' }}>{name}</p>
                            <p className="text-[12px]" style={{ color: '#6F6C66' }}>{timeAgo(u.created_at)}</p>
                          </div>
                        </Link>
                      )
                    })}
                  </div>
                </div>
              )}
            </div>

            {/* Contributors dropdown — sits next to Recent Members.
                Highlights users who actively help curate the quiz by
                submitting questions and reporting bad ones. */}
            <div ref={contribRef} className="relative hidden md:block">
              <button onClick={() => setShowContributors(o => !o)}
                className="flex items-center justify-center w-10 h-10 rounded-full transition-all"
                style={showContributors
                  ? { background: '#FFD84D', color: '#151515' }
                  : { background: 'rgba(21,21,21,0.06)', color: '#151515' }}
                aria-label="Korisnici koji doprinose kvizu">
                <IconStar size={18} strokeWidth={2.2} />
              </button>
              {showContributors && (
                <div className="absolute right-0 top-full mt-2 w-80 card-soft overflow-hidden z-50 animate-pop-in">
                  <div className="px-5 py-4 border-b border-[#E7E1D0]">
                    <p className="font-bold text-[15px]" style={{ color: '#151515' }}>Doprinos kvizu</p>
                    <p className="text-[12px] mt-0.5" style={{ color: '#6F6C66' }}>
                      Šalju nova pitanja i prijavljuju greške
                    </p>
                    <Link href="/autori-pitanja" onClick={() => setShowContributors(false)}
                      className="text-[12px] font-semibold underline" style={{ color: '#12907E' }}>
                      Rang lista autora pitanja →
                    </Link>
                  </div>
                  <div className="max-h-96 overflow-y-auto">
                    {contributors.length === 0 && (
                      <p className="px-5 py-4 text-[13px]" style={{ color: '#6F6C66' }}>
                        Niko još nije dao doprinos. Budi prvi —{' '}
                        <Link href="/dodaj-pitanja" onClick={() => setShowContributors(false)}
                          className="underline" style={{ color: '#12907E' }}>dodaj pitanje</Link>.
                      </p>
                    )}
                    {contributors.map(c => {
                      const name = c.nickname || `${c.first_name ?? ''} ${c.last_name ?? ''}`.trim() || 'Igrač'
                      // Build a tiny "X pitanja · Y prijava" subtitle. We
                      // only show counts that are actually > 0 to keep
                      // the line short and readable.
                      const parts: string[] = []
                      if (c.submissions > 0) parts.push(`${c.submissions} ${c.submissions === 1 ? 'pitanje' : 'pitanja'}`)
                      if (c.accepted > 0)    parts.push(`${c.accepted} u kvizu`)
                      if (c.reports > 0)     parts.push(`${c.reports} ${c.reports === 1 ? 'prijava' : 'prijava'}`)
                      return (
                        <Link key={c.id} href={`/profil/${c.id}`} onClick={() => setShowContributors(false)}
                          className="flex items-center gap-3 px-5 py-3 hover:bg-[#E7E1D0] transition-colors">
                          <div className="w-10 h-10 rounded-full overflow-hidden flex-shrink-0 bg-[#E7E1D0]">
                            {c.avatar
                              ? <Image src={`/avatars/${c.avatar}`} alt={name} width={40} height={40} className="w-full h-full object-cover" />
                              : <div className="w-full h-full flex items-center justify-center text-sm font-bold" style={{ background: '#FFD84D', color: '#151515' }}>{name[0]}</div>}
                          </div>
                          <div className="flex-1 min-w-0">
                            <p className="font-semibold text-[14px] truncate" style={{ color: '#151515' }}>
                              {jeAutorPitanja(c.accepted, pragBedza) && <span title="Autor pitanja" className="inline-block w-2 h-2 rounded-full mr-1.5 align-middle" style={{ background: '#FFD84D', outline: '1.5px solid #151515' }} />}
                              {name}
                            </p>
                            <p className="text-[12px]" style={{ color: '#6F6C66' }}>{parts.join(' · ')}</p>
                          </div>
                          <span className="chip flex-shrink-0" style={{ background: '#FFF3C4', color: '#8A6A12' }}>
                            {c.total_contributions}
                          </span>
                        </Link>
                      )
                    })}
                  </div>
                </div>
              )}
            </div>

            {authKnown && !userName && (
              <div className="hidden md:flex items-center gap-4">
                <Link href="/auth/prijava" className="text-[13px] font-semibold" style={{ color: '#12110F' }}>
                  Prijava
                </Link>
                <Link href="/auth/registracija" className="btn btn-primary btn-sm">
                  Registracija
                </Link>
              </div>
            )}

            {/* User avatar */}
            {userName && (
              <Link href="/profil" className="hidden md:flex items-center gap-2.5 pl-1 pr-3 py-1 rounded-full transition-all hover:bg-[#E7E1D0]">
                <div className="w-9 h-9 rounded-full overflow-hidden flex-shrink-0 bg-[#E7E1D0]">
                  {userAvatar
                    ? <Image src={`/avatars/${userAvatar}`} alt={userName} width={36} height={36} className="w-full h-full object-cover" />
                    : <div className="w-full h-full flex items-center justify-center text-sm font-bold" style={{ background: '#FFD84D', color: '#151515' }}>{userName[0].toUpperCase()}</div>}
                </div>
                <span className="text-[13px] font-semibold" style={{ color: '#151515' }}>{userName}</span>
              </Link>
            )}

            {/* Logout (desktop) */}
            {userName && (
              <button onClick={handleLogout}
                className="hidden md:flex items-center justify-center w-10 h-10 rounded-full transition-all"
                style={{ color: '#6F6C66' }}
                onMouseEnter={e => {
                  (e.currentTarget as HTMLButtonElement).style.background = 'rgba(229,83,83,0.10)'
                  ;(e.currentTarget as HTMLButtonElement).style.color = '#E5385C'
                }}
                onMouseLeave={e => {
                  (e.currentTarget as HTMLButtonElement).style.background = 'transparent'
                  ;(e.currentTarget as HTMLButtonElement).style.color = '#6F6C66'
                }}
                aria-label="Odjava">
                <IconLogout size={18} strokeWidth={2.2} />
              </button>
            )}

            {/* Mobile hamburger */}
            <button onClick={() => setMobileOpen(o => !o)}
              className="md:hidden flex items-center justify-center w-10 h-10 rounded-full transition-all"
              style={{ background: mobileOpen ? '#151515' : 'rgba(21,21,21,0.06)', color: mobileOpen ? 'white' : '#151515' }}
              aria-label="Meni">
              {mobileOpen ? <IconClose size={20} strokeWidth={2.2} /> : <IconMenu size={20} strokeWidth={2.2} />}
            </button>
          </div>
        </div>

        {/* Mobile drawer */}
        {mobileOpen && (
          <div className="md:hidden border-t border-[#E7E1D0] animate-fade-in">
            <div className="max-w-6xl mx-auto px-4 py-3 space-y-3">
              {/* User card */}
              {userName && (
                <Link href="/profil" className="flex items-center gap-3 p-3 rounded-2xl"
                  style={{ background: '#E7E1D0' }}>
                  <div className="w-11 h-11 rounded-full overflow-hidden flex-shrink-0 bg-white">
                    {userAvatar
                      ? <Image src={`/avatars/${userAvatar}`} alt={userName} width={44} height={44} className="w-full h-full object-cover" />
                      : <div className="w-full h-full flex items-center justify-center text-sm font-bold" style={{ background: '#FFD84D', color: '#151515' }}>{userName[0].toUpperCase()}</div>}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-[14px] font-bold truncate" style={{ color: '#151515' }}>{userName}</p>
                    <p className="text-[12px]" style={{ color: '#6F6C66' }}>Otvori profil →</p>
                  </div>
                </Link>
              )}

              {/* Same flat link list as desktop nav. "Igre" leads to the
                  /igre hub page where the colored cards live. */}
              <div className="space-y-1">
                {NAV_LINKS.map(({ href, label, Icon, accent, tint }) => {
                  const active =
                    pathname === href ||
                    pathname.startsWith(href + '/') ||
                    (href === '/' && pathname === '/')
                  return (
                    <Link key={href} href={href}
                      className="flex items-center gap-3 px-4 py-3 rounded-2xl text-[14px] font-medium transition-all"
                      style={active
                        ? { background: accent, color: 'white' }
                        : { color: '#151515', background: tint }}>
                      <Icon size={18} strokeWidth={2.2} style={active ? undefined : { color: accent }} />
                      {label}
                    </Link>
                  )
                })}
              </div>

              {/* Recent users */}
              {recentUsers.length > 0 && (
                <div className="pt-3 mt-3 border-t border-[#E7E1D0]">
                  <p className="px-1 mb-2 text-[11px] font-bold uppercase tracking-wider" style={{ color: '#6F6C66' }}>Novi članovi</p>
                  {recentUsers.slice(0, 5).map(u => {
                    const name = u.nickname || `${u.first_name} ${u.last_name}`.trim() || 'Igrač'
                    return (
                      <Link key={u.id} href={`/profil/${u.id}`}
                        className="flex items-center gap-3 px-2 py-2.5 rounded-2xl">
                        <div className="w-8 h-8 rounded-full overflow-hidden flex-shrink-0 bg-[#E7E1D0]">
                          {u.avatar
                            ? <Image src={`/avatars/${u.avatar}`} alt={name} width={32} height={32} className="w-full h-full object-cover" />
                            : <div className="w-full h-full flex items-center justify-center text-xs font-bold" style={{ background: '#12907E', color: 'white' }}>{name[0]}</div>}
                        </div>
                        <div className="flex-1 min-w-0">
                          <span className="text-[13px] font-semibold truncate block" style={{ color: '#151515' }}>{name}</span>
                          <span className="text-[11px]" style={{ color: '#6F6C66' }}>{timeAgo(u.created_at)}</span>
                        </div>
                      </Link>
                    )
                  })}
                </div>
              )}

              {/* Contributors (mobile) — same lazy-loaded data as the
                  desktop dropdown, condensed for the drawer. */}
              {contributors.length > 0 && (
                <div className="pt-3 mt-3 border-t border-[#E7E1D0]">
                  <p className="px-1 mb-2 text-[11px] font-bold uppercase tracking-wider" style={{ color: '#6F6C66' }}>Doprinos kvizu</p>
                  {contributors.slice(0, 5).map(c => {
                    const name = c.nickname || `${c.first_name ?? ''} ${c.last_name ?? ''}`.trim() || 'Igrač'
                    const parts: string[] = []
                    if (c.submissions > 0) parts.push(`${c.submissions} ${c.submissions === 1 ? 'pitanje' : 'pitanja'}`)
                    if (c.reports > 0)     parts.push(`${c.reports} ${c.reports === 1 ? 'prijava' : 'prijava'}`)
                    return (
                      <Link key={c.id} href={`/profil/${c.id}`}
                        className="flex items-center gap-3 px-2 py-2.5 rounded-2xl">
                        <div className="w-8 h-8 rounded-full overflow-hidden flex-shrink-0 bg-[#E7E1D0]">
                          {c.avatar
                            ? <Image src={`/avatars/${c.avatar}`} alt={name} width={32} height={32} className="w-full h-full object-cover" />
                            : <div className="w-full h-full flex items-center justify-center text-xs font-bold" style={{ background: '#FFD84D', color: '#151515' }}>{name[0]}</div>}
                        </div>
                        <div className="flex-1 min-w-0">
                          <span className="text-[13px] font-semibold truncate block" style={{ color: '#151515' }}>{name}</span>
                          <span className="text-[11px]" style={{ color: '#6F6C66' }}>{parts.join(' · ')}</span>
                        </div>
                        <span className="chip flex-shrink-0" style={{ background: '#FFF3C4', color: '#8A6A12' }}>
                          {c.total_contributions}
                        </span>
                      </Link>
                    )
                  })}
                </div>
              )}

              {userName && (
                <button onClick={handleLogout}
                  className="w-full flex items-center gap-3 px-4 py-3 rounded-2xl text-[14px] font-medium transition-colors mt-3 border-t border-[#E7E1D0] pt-4"
                  style={{ color: '#E5385C' }}>
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
