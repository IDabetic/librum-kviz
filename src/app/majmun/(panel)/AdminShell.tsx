'use client'

import Link from 'next/link'
import Image from 'next/image'
import { usePathname, useRouter } from 'next/navigation'
import { useState } from 'react'
import { Logo } from '@/components/Logo'
import { createClient } from '@/lib/supabase/client'
import {
  IconHome, IconDiscover, IconSwords, IconHint, IconTime, IconTrophy,
  IconUsers, IconSettings, IconLogout, IconMenu, IconClose, IconStar,
} from '@/components/icons'

type Profile = {
  id: string
  first_name: string | null
  last_name: string | null
  nickname: string | null
  avatar: string | null
  role: string
}

const NAV = [
  { label: 'Dashboard',   href: '/majmun',                Icon: IconHome },
  { label: 'PRO pitanja', href: '/majmun/pitanja',        Icon: IconDiscover },
  { label: 'Book kviz',   href: '/majmun/book-kviz',      Icon: IconStar },
  { label: 'Brzi kviz',   href: '/majmun/brzi-kviz',      Icon: IconTime },
  { label: 'Vešanje',     href: '/majmun/vesanje',        Icon: IconHint },
  { label: 'Predlozi',    href: '/majmun/predlozi',       Icon: IconUsers },
  { label: 'Korisnici',   href: '/majmun/korisnici',      Icon: IconUsers },
  { label: 'Rang lista',  href: '/majmun/rang-lista',     Icon: IconTrophy },
  { label: 'Trivia duel', href: '/majmun/trivia-duel',    Icon: IconSwords },
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
    <div className="min-h-screen flex" style={{ background: '#FAFAFA' }}>

      {/* ── Mobile top bar ───────────────────────────────────────────── */}
      <div className="lg:hidden fixed top-0 inset-x-0 z-40 backdrop-blur-xl flex items-center justify-between px-4 py-3"
        style={{ background: 'rgba(252,252,252,0.92)', borderBottom: '1px solid rgba(52,52,52,0.06)' }}>
        <Logo height={24} />
        <button onClick={() => setOpen(o => !o)}
          className="w-9 h-9 rounded-full flex items-center justify-center"
          style={{ background: open ? '#343434' : 'rgba(52,52,52,0.06)', color: open ? 'white' : '#343434' }}>
          {open ? <IconClose size={18} strokeWidth={2.2} /> : <IconMenu size={18} strokeWidth={2.2} />}
        </button>
      </div>

      {/* ── Sidebar ──────────────────────────────────────────────────── */}
      <aside className={`fixed lg:sticky top-0 z-50 lg:z-auto h-screen w-72 flex-shrink-0 transition-transform lg:transition-none ${open ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'}`}
        style={{ background: '#FCFCFC', borderRight: '1px solid rgba(52,52,52,0.06)' }}>
        <div className="flex flex-col h-full">

          {/* Logo block */}
          <div className="px-6 pt-7 pb-6">
            <Logo height={28} href={null} />
            <p className="text-[10px] font-bold uppercase tracking-widest mt-1.5" style={{ color: '#9C9C9C' }}>
              Admin panel
            </p>
          </div>

          {/* User card */}
          <div className="mx-4 mb-5 p-3 rounded-2xl flex items-center gap-3" style={{ background: '#F2F2F2' }}>
            <div className="w-10 h-10 rounded-xl overflow-hidden flex-shrink-0 bg-white">
              {profile.avatar
                ? <Image src={`/avatars/${profile.avatar}`} alt={displayName} width={40} height={40} className="w-full h-full object-cover" />
                : <div className="w-full h-full flex items-center justify-center text-sm font-bold" style={{ background: '#609DED', color: 'white' }}>{displayName[0]}</div>}
            </div>
            <div className="min-w-0 flex-1">
              <p className="font-bold text-[13px] truncate" style={{ color: '#343434' }}>{displayName}</p>
              <p className="text-[10px] uppercase tracking-wider font-bold" style={{ color: '#9C9C9C' }}>
                {profile.role.replace('_', ' ')}
              </p>
            </div>
          </div>

          {/* Nav */}
          <nav className="flex-1 px-4 space-y-1 overflow-y-auto">
            {NAV.map(({ label, href, Icon }) => {
              const active = isActive(href)
              return (
                <Link key={href} href={href} onClick={() => setOpen(false)}
                  className="flex items-center gap-3 px-4 py-2.5 rounded-2xl text-[14px] font-semibold transition-all"
                  style={active
                    ? { background: '#343434', color: '#FCFCFC' }
                    : { color: '#343434' }}
                  onMouseEnter={e => { if (!active) (e.currentTarget as HTMLAnchorElement).style.background = '#F2F2F2' }}
                  onMouseLeave={e => { if (!active) (e.currentTarget as HTMLAnchorElement).style.background = 'transparent' }}>
                  <Icon size={16} strokeWidth={2.2} />
                  {label}
                </Link>
              )
            })}
          </nav>

          {/* Bottom actions */}
          <div className="p-4 mt-3 border-t space-y-1" style={{ borderColor: '#F2F2F2' }}>
            <Link href="/majmun/podesavanja" onClick={() => setOpen(false)}
              className="flex items-center gap-3 px-4 py-2.5 rounded-2xl text-[14px] font-semibold transition-colors"
              style={{ color: '#343434' }}
              onMouseEnter={e => (e.currentTarget as HTMLAnchorElement).style.background = '#F2F2F2'}
              onMouseLeave={e => (e.currentTarget as HTMLAnchorElement).style.background = 'transparent'}>
              <IconSettings size={16} strokeWidth={2.2} />
              Podešavanja
            </Link>
            <button type="button" onClick={handleLogout}
              className="w-full flex items-center gap-3 px-4 py-2.5 rounded-2xl text-[14px] font-semibold transition-colors"
              style={{ color: '#E55353' }}
              onMouseEnter={e => (e.currentTarget as HTMLButtonElement).style.background = '#FEE2E2'}
              onMouseLeave={e => (e.currentTarget as HTMLButtonElement).style.background = 'transparent'}>
              <IconLogout size={16} strokeWidth={2.2} />
              Odjava
            </button>
            <Link href="/" className="block text-center text-[11px] mt-3 transition-opacity hover:opacity-70" style={{ color: '#9C9C9C' }}>
              ← Nazad na sajt
            </Link>
          </div>
        </div>
      </aside>

      {/* Backdrop on mobile when open */}
      {open && (
        <div onClick={() => setOpen(false)} className="lg:hidden fixed inset-0 z-40" style={{ background: 'rgba(52,52,52,0.40)' }} />
      )}

      {/* ── Main ────────────────────────────────────────────────────── */}
      <main className="flex-1 min-w-0 lg:p-8 p-4 pt-20 lg:pt-8">
        {children}
      </main>
    </div>
  )
}
