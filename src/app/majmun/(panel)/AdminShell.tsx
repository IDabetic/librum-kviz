'use client'

import Link from 'next/link'
import Image from 'next/image'
import { usePathname, useRouter } from 'next/navigation'
import { useState } from 'react'
import { Logo } from '@/components/Logo'
import { jeAvatarSajta } from './igre-nazivi'
import { createClient } from '@/lib/supabase/client'
import {
  IconHome, IconDiscover, IconSwords, IconHint, IconTrophy, IconTime,
  IconUsers, IconSettings, IconLogout, IconMenu, IconClose, IconStar, IconWrong, IconEye,
} from '@/components/icons'

type Profile = {
  id: string
  first_name: string | null
  last_name: string | null
  nickname: string | null
  avatar: string | null
  role: string
}

// PRO kviz, Brzi kviz and Trivia duel all read from the same `questions`
// pool. "Pitanja" is the shared CRUD; "Brzi kviz" is a convenience
// shortcut that lands on the same pool. Book kviz and Kafanski kviz each
// have their own dedicated pool tables.
const NAV = [
  { label: 'Dashboard',      href: '/majmun',                Icon: IconHome },
  { label: 'Aktivnost',      href: '/majmun/aktivnost',      Icon: IconTime,     hint: 'sve partije' },
  { label: 'Karijerista',       href: '/majmun/karijera',       Icon: IconTrophy,   hint: 'firme • pitanja' },
  { label: 'Osvajač',      href: '/majmun/osvajanje',      Icon: IconSwords,   hint: 'sobe' },
  { label: 'Sumnjivo',       href: '/majmun/sumnjivo',       Icon: IconEye,      hint: 'varanje' },
  { label: 'Pitanja',        href: '/majmun/pitanja',        Icon: IconDiscover, hint: 'PRO • Brzi • Duel' },
  { label: 'Brzi kviz',      href: '/majmun/brzi-kviz',      Icon: IconTime,     hint: 'isti pool kao PRO' },
  { label: 'Book kviz',      href: '/majmun/book-kviz',      Icon: IconStar },
  { label: 'Kafanski kviz',  href: '/majmun/kafana',         Icon: IconStar,     hint: 'muzika' },
  { label: 'Vešanje',        href: '/majmun/vesanje',        Icon: IconHint },
  { label: 'Predlozi',       href: '/majmun/predlozi',       Icon: IconUsers,    hint: 'nova pitanja' },
  { label: 'Prijave',        href: '/majmun/prijave',        Icon: IconUsers,    hint: 'greške u pitanjima' },
  { label: 'Zajednica',      href: '/majmun/zajednica',      Icon: IconUsers,    hint: 'objave i komentari' },
  { label: 'Korisnici',      href: '/majmun/korisnici',      Icon: IconUsers },
  { label: 'Rang lista',     href: '/majmun/rang-lista',     Icon: IconTrophy },
  { label: 'Trivia duel',    href: '/majmun/trivia-duel',    Icon: IconSwords,   hint: 'analitika' },
  { label: 'Padovi',         href: '/majmun/padovi',         Icon: IconWrong,    hint: 'aplikacija' },
]

export default function AdminShell({ profile, children }: { profile: Profile; children: React.ReactNode }) {
  const pathname = usePathname()
  const router = useRouter()
  const [open, setOpen] = useState(false)

  function isActive(href: string): boolean {
    if (href === '/majmun') return pathname === '/majmun'
    return pathname.startsWith(href)
  }

  async function handleLogout() {
    await createClient().auth.signOut()
    router.push('/')
    router.refresh()
  }

  const displayName = profile.nickname || `${profile.first_name || ''} ${profile.last_name || ''}`.trim() || 'Admin'

  return (
    <div className="min-h-screen flex" style={{ background: '#F3F0E6' }}>

      {/* ── Mobile top bar ───────────────────────────────────────────── */}
      <div className="lg:hidden fixed top-0 inset-x-0 z-40 backdrop-blur-xl flex items-center justify-between px-4 py-3"
        style={{ background: 'rgba(252,252,252,0.92)', borderBottom: '1px solid rgba(21,21,21,0.06)' }}>
        <Logo height={24} />
        <button onClick={() => setOpen(o => !o)}
          className="w-9 h-9 rounded-full flex items-center justify-center"
          style={{ background: open ? '#151515' : 'rgba(21,21,21,0.06)', color: open ? 'white' : '#151515' }}>
          {open ? <IconClose size={18} strokeWidth={2.2} /> : <IconMenu size={18} strokeWidth={2.2} />}
        </button>
      </div>

      {/* ── Sidebar ──────────────────────────────────────────────────── */}
      {/* Na računaru meni nema svoj skrol: pruža se naniže koliko treba i skroluje sa stranom (vlasnik 05.11). */}
      <aside className={`fixed lg:static top-0 z-50 lg:z-auto h-screen lg:h-auto lg:min-h-screen w-72 flex-shrink-0 overflow-y-auto lg:overflow-visible transition-transform lg:transition-none ${open ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'}`}
        style={{ background: '#FFFFFF', borderRight: '1px solid rgba(21,21,21,0.06)' }}>
        <div className="flex flex-col min-h-full">

          {/* Logo block */}
          <div className="px-6 pt-7 pb-6">
            <Logo height={36} href={null} />
            <p className="text-[10px] font-bold uppercase tracking-widest mt-1.5" style={{ color: '#6F6C66' }}>
              Admin panel
            </p>
          </div>

          {/* User card */}
          <div className="mx-4 mb-5 p-3 rounded-2xl flex items-center gap-3" style={{ background: '#E7E1D0' }}>
            <div className="w-10 h-10 rounded-xl overflow-hidden flex-shrink-0 bg-white">
              {jeAvatarSajta(profile.avatar)
                ? <Image src={`/avatars/${profile.avatar}`} alt={displayName} width={40} height={40} className="w-full h-full object-cover" />
                : <div className="w-full h-full flex items-center justify-center text-sm font-bold" style={{ background: '#12907E', color: 'white' }}>{displayName[0]}</div>}
            </div>
            <div className="min-w-0 flex-1">
              <p className="font-bold text-[13px] truncate" style={{ color: '#151515' }}>{displayName}</p>
              <p className="text-[10px] uppercase tracking-wider font-bold" style={{ color: '#6F6C66' }}>
                {profile.role.replace('_', ' ')}
              </p>
            </div>
          </div>

          {/* Nav */}
          <nav className="flex-1 px-4 space-y-1">
            {NAV.map(item => {
              const { label, href, Icon } = item
              const hint = 'hint' in item ? item.hint : undefined
              const active = isActive(href)
              return (
                <Link key={href} href={href} onClick={() => setOpen(false)}
                  className="flex items-center gap-3 px-4 py-2.5 rounded-2xl text-[14px] font-semibold transition-all"
                  style={active
                    ? { background: '#151515', color: '#FFFFFF' }
                    : { color: '#151515' }}
                  onMouseEnter={e => { if (!active) (e.currentTarget as HTMLAnchorElement).style.background = '#E7E1D0' }}
                  onMouseLeave={e => { if (!active) (e.currentTarget as HTMLAnchorElement).style.background = 'transparent' }}>
                  <Icon size={16} strokeWidth={2.2} />
                  <span className="flex-1">{label}</span>
                  {hint && (
                    <span className="text-[10px] font-medium uppercase tracking-wider"
                      style={{ color: active ? 'rgba(252,252,252,0.55)' : '#6F6C66' }}>
                      {hint}
                    </span>
                  )}
                </Link>
              )
            })}
          </nav>

          {/* Bottom actions */}
          <div className="p-4 mt-3 border-t space-y-1" style={{ borderColor: '#E7E1D0' }}>
            <Link href="/majmun/podesavanja" onClick={() => setOpen(false)}
              className="flex items-center gap-3 px-4 py-2.5 rounded-2xl text-[14px] font-semibold transition-colors"
              style={{ color: '#151515' }}
              onMouseEnter={e => (e.currentTarget as HTMLAnchorElement).style.background = '#E7E1D0'}
              onMouseLeave={e => (e.currentTarget as HTMLAnchorElement).style.background = 'transparent'}>
              <IconSettings size={16} strokeWidth={2.2} />
              Podešavanja
            </Link>
            <button type="button" onClick={handleLogout}
              className="w-full flex items-center gap-3 px-4 py-2.5 rounded-2xl text-[14px] font-semibold transition-colors"
              style={{ color: '#E5385C' }}
              onMouseEnter={e => (e.currentTarget as HTMLButtonElement).style.background = '#FFE3EA'}
              onMouseLeave={e => (e.currentTarget as HTMLButtonElement).style.background = 'transparent'}>
              <IconLogout size={16} strokeWidth={2.2} />
              Odjava
            </button>
            <Link href="/" className="block text-center text-[11px] mt-3 transition-opacity hover:opacity-70" style={{ color: '#6F6C66' }}>
              ← Nazad na sajt
            </Link>
          </div>
        </div>
      </aside>

      {/* Backdrop on mobile when open */}
      {open && (
        <div onClick={() => setOpen(false)} className="lg:hidden fixed inset-0 z-40" style={{ background: 'rgba(21,21,21,0.40)' }} />
      )}

      {/* ── Main ────────────────────────────────────────────────────── */}
      <main className="flex-1 min-w-0 lg:p-8 p-4 pt-20 lg:pt-8">
        {children}
      </main>
    </div>
  )
}
