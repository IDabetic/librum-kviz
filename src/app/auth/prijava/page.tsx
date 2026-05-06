'use client'

export const dynamic = 'force-dynamic'

import Link from 'next/link'
import Image from 'next/image'
import { useState } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { Suspense } from 'react'

function PrijavaForm() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const redirect = searchParams.get('redirect') || '/kvizovi'

  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  const [forgotMode, setForgotMode] = useState(false)
  const [resetEmail, setResetEmail] = useState('')
  const [resetSent, setResetSent] = useState(false)
  const [resetLoading, setResetLoading] = useState(false)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    setLoading(true)
    const supabase = createClient()
    const { error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) {
      setError('Pogrešan email ili lozinka.')
    } else {
      router.push(redirect)
      router.refresh()
    }
    setLoading(false)
  }

  async function handleForgot(e: React.FormEvent) {
    e.preventDefault()
    setResetLoading(true)
    const supabase = createClient()
    await supabase.auth.resetPasswordForEmail(resetEmail, {
      redirectTo: `${window.location.origin}/auth/nova-lozinka`,
    })
    setResetSent(true)
    setResetLoading(false)
  }

  if (forgotMode) {
    return (
      <div>
        <button
          onClick={() => { setForgotMode(false); setResetSent(false) }}
          className="flex items-center gap-1.5 text-sm mb-5 transition-colors"
          style={{ color: '#2C2D81' }}
        >
          <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><polyline points="10,4 6,8 10,12"/></svg>
          Nazad na prijavu
        </button>

        {resetSent ? (
          <div className="text-center py-4">
            <div className="w-14 h-14 rounded-full flex items-center justify-center mx-auto mb-4" style={{ background: '#E8F8F0' }}>
              <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="#5DBF94" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                <path d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7"/><path d="M12 17v4"/><path d="M8 21h8"/><polyline points="4 13 12 17 20 13"/>
              </svg>
            </div>
            <h3 className="font-bold text-gray-800 mb-2">Email je poslat!</h3>
            <p className="text-sm text-gray-500">Proverite inbox (i spam) na adresi <span className="font-medium text-gray-700">{resetEmail}</span> za link za resetovanje lozinke.</p>
          </div>
        ) : (
          <form onSubmit={handleForgot} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1.5">Vaša email adresa</label>
              <input
                type="email"
                required
                value={resetEmail}
                onChange={e => setResetEmail(e.target.value)}
                className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:outline-none focus:ring-2 focus:border-[#2C2D81] transition-colors text-sm"
                style={{ ['--tw-ring-color' as string]: 'rgba(44,45,129,0.2)' }}
                placeholder="vas@email.com"
              />
            </div>
            <button
              type="submit"
              disabled={resetLoading}
              className="w-full py-3.5 rounded-xl font-bold text-white transition-all hover:scale-[1.02] disabled:opacity-60 disabled:scale-100"
              style={{ background: 'linear-gradient(135deg, #2C2D81, #3766B0)' }}
            >
              {resetLoading ? 'Slanje...' : 'Pošalji link za novu lozinku'}
            </button>
          </form>
        )}
      </div>
    )
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      {error && (
        <div className="bg-red-50 border border-red-200 text-red-700 rounded-xl px-4 py-3 text-sm">
          {error}
        </div>
      )}
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-1.5">Email adresa</label>
        <input
          type="email"
          required
          value={email}
          onChange={e => setEmail(e.target.value)}
          className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:outline-none focus:ring-2 focus:border-[#2C2D81] transition-colors text-sm"
          placeholder="vas@email.com"
        />
      </div>
      <div>
        <div className="flex items-center justify-between mb-1.5">
          <label className="text-sm font-medium text-gray-700">Lozinka</label>
          <button
            type="button"
            onClick={() => { setForgotMode(true); setResetEmail(email) }}
            className="text-xs font-medium transition-colors hover:underline"
            style={{ color: '#3766B0' }}
          >
            Zaboravili ste lozinku?
          </button>
        </div>
        <input
          type="password"
          required
          value={password}
          onChange={e => setPassword(e.target.value)}
          className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:outline-none focus:ring-2 focus:border-[#2C2D81] transition-colors text-sm"
          placeholder="••••••••"
        />
      </div>
      <button
        type="submit"
        disabled={loading}
        className="w-full py-3.5 rounded-xl font-bold text-white transition-all hover:scale-[1.02] disabled:opacity-60 disabled:scale-100 mt-2"
        style={{ background: 'linear-gradient(135deg, #2C2D81, #3766B0)' }}
      >
        {loading ? 'Prijava...' : 'Prijavite se'}
      </button>
    </form>
  )
}

export default function PrijavaPage() {
  return (
    <div className="min-h-screen flex flex-col" style={{ background: 'linear-gradient(135deg, #1A1C4E 0%, #2C2D81 60%, #3766B0 100%)' }}>
      {/* Decorative circles */}
      <div className="fixed inset-0 pointer-events-none overflow-hidden">
        <div className="absolute -top-32 -right-32 w-96 h-96 rounded-full opacity-10" style={{ background: '#FDC361' }} />
        <div className="absolute -bottom-20 -left-20 w-80 h-80 rounded-full opacity-10" style={{ background: '#5DBF94' }} />
      </div>

      <div className="relative flex-1 flex flex-col items-center justify-center px-4 py-12">
        {/* Logo */}
        <div className="mb-8 text-center">
          <a href="https://www.librum.club" rel="noopener noreferrer" className="inline-block mb-4">
            <Image src="/logo-dark.png" alt="Librum club" height={36} width={160} style={{ objectFit: 'contain' }} />
          </a>
          <p className="text-sm" style={{ color: 'rgba(255,255,255,0.55)' }}>Prijavite se na vaš nalog</p>
        </div>

        {/* Card */}
        <div className="w-full max-w-md bg-white rounded-2xl shadow-2xl overflow-hidden">
          {/* Card header strip */}
          <div className="h-1.5" style={{ background: 'linear-gradient(90deg, #FDC361, #5DBF94)' }} />
          <div className="p-8">
            <h2 className="text-xl font-bold mb-6" style={{ color: '#1A1C4E' }}>Prijava</h2>
            <Suspense>
              <PrijavaForm />
            </Suspense>
            <div className="mt-6 pt-6 border-t border-gray-100 text-center text-sm text-gray-500">
              Nemate nalog?{' '}
              <Link href="/auth/registracija" className="font-semibold hover:underline" style={{ color: '#2C2D81' }}>
                Registrujte se besplatno
              </Link>
            </div>
          </div>
        </div>

        <Link href="/" className="mt-6 text-sm transition-colors" style={{ color: 'rgba(255,255,255,0.45)' }}>
          ← Nazad na početnu
        </Link>
      </div>
    </div>
  )
}
