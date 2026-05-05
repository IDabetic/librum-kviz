'use client'

import Link from 'next/link'
import { useRouter, usePathname } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { useEffect, useState } from 'react'

export default function Header() {
  const router = useRouter()
  const pathname = usePathname()
  const supabase = createClient()
  const [userName, setUserName] = useState<string | null>(null)

  useEffect(() => {
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

  async function handleLogout() {
    await supabase.auth.signOut()
    router.push('/')
    router.refresh()
  }

  return (
    <header className="bg-white border-b border-gray-100 sticky top-0 z-50 shadow-sm">
      <div className="max-w-6xl mx-auto px-4 h-16 flex items-center justify-between">
        <Link href="/kvizovi" className="flex items-center gap-2">
          <LibrumIcon />
          <span className="font-bold text-xl" style={{ color: '#2C2D81' }}>
            Librum <span className="font-normal text-gray-400">kviz</span>
          </span>
        </Link>

        <nav className="hidden md:flex items-center gap-6">
          <NavLink href="/kvizovi" current={pathname}>Kvizovi</NavLink>
          <NavLink href="/leaderboard" current={pathname}>Rang lista</NavLink>
          <NavLink href="/profil" current={pathname}>Profil</NavLink>
        </nav>

        <div className="flex items-center gap-3">
          {userName && (
            <span className="text-sm text-gray-500 hidden sm:block">
              Zdravo, <span className="font-medium text-gray-700">{userName}</span>
            </span>
          )}
          <button
            onClick={handleLogout}
            className="text-sm px-4 py-2 rounded-lg border border-gray-200 hover:bg-gray-50 transition-colors text-gray-600"
          >
            Odjava
          </button>
        </div>
      </div>
    </header>
  )
}

function NavLink({ href, current, children }: { href: string; current: string; children: React.ReactNode }) {
  const active = current.startsWith(href)
  return (
    <Link
      href={href}
      className={`text-sm font-medium transition-colors ${
        active ? 'text-[#2C2D81]' : 'text-gray-500 hover:text-[#2C2D81]'
      }`}
    >
      {children}
    </Link>
  )
}

export function LibrumIcon({ size = 32 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 40 40" fill="none" xmlns="http://www.w3.org/2000/svg">
      <rect x="6" y="8" width="9" height="24" rx="2" transform="rotate(-8 6 8)" fill="#2C2D81" />
      <rect x="17" y="6" width="9" height="26" rx="2" fill="#3766B0" />
      <rect x="28" y="8" width="8" height="24" rx="2" fill="#5DBF94" />
    </svg>
  )
}
