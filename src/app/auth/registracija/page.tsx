'use client'

export const dynamic = 'force-dynamic'

import Link from 'next/link'
import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { LibrumIcon } from '@/components/Header'

export default function RegistracijaPage() {
  const router = useRouter()

  const [form, setForm] = useState({ ime: '', prezime: '', email: '', telefon: '', password: '', password2: '' })
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const [success, setSuccess] = useState(false)

  function set(field: string, value: string) {
    setForm(f => ({ ...f, [field]: value }))
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError('')

    if (form.password !== form.password2) {
      setError('Lozinke se ne poklapaju.')
      return
    }
    if (form.password.length < 6) {
      setError('Lozinka mora imati najmanje 6 karaktera.')
      return
    }

    setLoading(true)
    const supabase = createClient()
    const { error } = await supabase.auth.signUp({
      email: form.email,
      password: form.password,
      options: {
        data: {
          first_name: form.ime,
          last_name: form.prezime,
          phone: form.telefon,
        },
      },
    })

    if (error) {
      setError(error.message === 'User already registered' ? 'Ovaj email je već registrovan.' : error.message)
    } else {
      setSuccess(true)
    }
    setLoading(false)
  }

  if (success) {
    return (
      <div className="min-h-screen flex items-center justify-center px-4" style={{ background: 'linear-gradient(135deg, #2C2D81 0%, #3766B0 100%)' }}>
        <div className="w-full max-w-md animate-pop-in">
          <div className="bg-white rounded-2xl p-8 shadow-2xl text-center">
            <div className="w-16 h-16 rounded-full flex items-center justify-center mx-auto mb-5" style={{ background: '#E8F8F0' }}>
              <svg width="32" height="32" viewBox="0 0 32 32" fill="none">
                <path d="M6 8h20M6 8v16a2 2 0 002 2h12a2 2 0 002-2V8M6 8l2-3h16l2 3M13 14l2 2 4-4" stroke="#5DBF94" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </div>
            <h2 className="text-2xl font-bold mb-2" style={{ color: '#2C2D81' }}>Proverite email!</h2>
            <p className="text-gray-500 mb-2">
              Poslali smo vam link za potvrdu na:
            </p>
            <p className="font-semibold text-gray-700 mb-6">{form.email}</p>
            <p className="text-sm text-gray-400 mb-6">
              Kliknite na link u emailu da aktivirate nalog. Proverite i spam folder.
            </p>
            <Link
              href="/auth/prijava"
              className="inline-flex items-center justify-center w-full py-3.5 rounded-xl font-bold text-white transition-all hover:scale-[1.02]"
              style={{ background: 'linear-gradient(135deg, #2C2D81, #3766B0)' }}
            >
              Idite na prijavu
            </Link>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen flex items-center justify-center px-4 py-12" style={{ background: 'linear-gradient(135deg, #2C2D81 0%, #3766B0 100%)' }}>
      <div className="w-full max-w-md animate-fade-in">
        <div className="text-center mb-8">
          <div className="flex justify-center mb-3">
            <LibrumIcon size={48} />
          </div>
          <h1 className="text-2xl font-bold text-white">Librum Kviz</h1>
          <p className="text-white/60 text-sm mt-1">Kreirajte besplatan nalog</p>
        </div>

        <div className="bg-white rounded-2xl p-8 shadow-2xl">
          <h2 className="text-xl font-bold text-gray-800 mb-6">Registracija</h2>

          <form onSubmit={handleSubmit} className="space-y-4">
            {error && (
              <div className="bg-red-50 border border-red-200 text-red-700 rounded-xl px-4 py-3 text-sm">
                {error}
              </div>
            )}

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1.5">Ime</label>
                <input
                  type="text" required value={form.ime} onChange={e => set('ime', e.target.value)}
                  className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:outline-none focus:ring-2 focus:ring-[#2C2D81]/20 focus:border-[#2C2D81] transition-colors text-sm"
                  placeholder="Marko"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1.5">Prezime</label>
                <input
                  type="text" required value={form.prezime} onChange={e => set('prezime', e.target.value)}
                  className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:outline-none focus:ring-2 focus:ring-[#2C2D81]/20 focus:border-[#2C2D81] transition-colors text-sm"
                  placeholder="Marković"
                />
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1.5">Email adresa</label>
              <input
                type="email" required value={form.email} onChange={e => set('email', e.target.value)}
                className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:outline-none focus:ring-2 focus:ring-[#2C2D81]/20 focus:border-[#2C2D81] transition-colors text-sm"
                placeholder="vas@email.com"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1.5">Broj telefona</label>
              <input
                type="tel" value={form.telefon} onChange={e => set('telefon', e.target.value)}
                className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:outline-none focus:ring-2 focus:ring-[#2C2D81]/20 focus:border-[#2C2D81] transition-colors text-sm"
                placeholder="+381 6X XXX XXXX"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1.5">Lozinka</label>
              <input
                type="password" required value={form.password} onChange={e => set('password', e.target.value)}
                className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:outline-none focus:ring-2 focus:ring-[#2C2D81]/20 focus:border-[#2C2D81] transition-colors text-sm"
                placeholder="Minimum 6 karaktera"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1.5">Ponovite lozinku</label>
              <input
                type="password" required value={form.password2} onChange={e => set('password2', e.target.value)}
                className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:outline-none focus:ring-2 focus:ring-[#2C2D81]/20 focus:border-[#2C2D81] transition-colors text-sm"
                placeholder="••••••••"
              />
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full py-3.5 rounded-xl font-bold text-white transition-all hover:scale-[1.02] disabled:opacity-60 disabled:scale-100 mt-2"
              style={{ background: 'linear-gradient(135deg, #2C2D81, #3766B0)' }}
            >
              {loading ? 'Registracija...' : 'Registrujte se'}
            </button>
          </form>

          <p className="text-center text-sm text-gray-500 mt-6">
            Već imate nalog?{' '}
            <Link href="/auth/prijava" className="font-semibold hover:underline" style={{ color: '#2C2D81' }}>
              Prijavite se
            </Link>
          </p>
        </div>
      </div>
    </div>
  )
}
