'use client'

export const dynamic = 'force-dynamic'

import Link from 'next/link'
import { useState } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { LibrumIcon } from '@/components/Header'
import { Suspense } from 'react'

function PrijavaForm() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const redirect = searchParams.get('redirect') || '/kvizovi'

  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

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
          className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:outline-none focus:ring-2 focus:ring-[#2C2D81]/20 focus:border-[#2C2D81] transition-colors text-sm"
          placeholder="vas@email.com"
        />
      </div>
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-1.5">Lozinka</label>
        <input
          type="password"
          required
          value={password}
          onChange={e => setPassword(e.target.value)}
          className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:outline-none focus:ring-2 focus:ring-[#2C2D81]/20 focus:border-[#2C2D81] transition-colors text-sm"
          placeholder="••••••••"
        />
      </div>
      <button
        type="submit"
        disabled={loading}
        className="w-full py-3.5 rounded-xl font-bold text-white transition-all hover:scale-[1.02] disabled:opacity-60 disabled:scale-100"
        style={{ background: 'linear-gradient(135deg, #2C2D81, #3766B0)' }}
      >
        {loading ? 'Prijava...' : 'Prijavite se'}
      </button>
    </form>
  )
}

export default function PrijavaPage() {
  return (
    <div className="min-h-screen flex items-center justify-center px-4" style={{ background: 'linear-gradient(135deg, #2C2D81 0%, #3766B0 100%)' }}>
      <div className="w-full max-w-md animate-fade-in">
        <div className="text-center mb-8">
          <div className="flex justify-center mb-3">
            <LibrumIcon size={48} />
          </div>
          <h1 className="text-2xl font-bold text-white">Librum Kviz</h1>
          <p className="text-white/60 text-sm mt-1">Prijavite se na vaš nalog</p>
        </div>

        <div className="bg-white rounded-2xl p-8 shadow-2xl">
          <h2 className="text-xl font-bold text-gray-800 mb-6">Prijava</h2>
          <Suspense>
            <PrijavaForm />
          </Suspense>
          <p className="text-center text-sm text-gray-500 mt-6">
            Nemate nalog?{' '}
            <Link href="/auth/registracija" className="font-semibold hover:underline" style={{ color: '#2C2D81' }}>
              Registrujte se
            </Link>
          </p>
        </div>
      </div>
    </div>
  )
}
