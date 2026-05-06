'use client'

export const dynamic = 'force-dynamic'

import Link from 'next/link'
import Image from 'next/image'
import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'

export default function RegistracijaPage() {
  const [form, setForm] = useState({ ime: '', prezime: '', nadimak: '', grad: '', email: '', password: '', password2: '' })
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
          nickname: form.nadimak,
          city: form.grad,
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
      <div className="min-h-screen flex items-center justify-center px-4" style={{ background: 'linear-gradient(135deg, #1A1C4E 0%, #2C2D81 60%, #3766B0 100%)' }}>
        <div className="w-full max-w-md">
          <div className="bg-white rounded-2xl shadow-2xl overflow-hidden">
            <div className="h-1.5" style={{ background: 'linear-gradient(90deg, #FDC361, #5DBF94)' }} />
            <div className="p-8 text-center">
              <div className="w-16 h-16 rounded-full flex items-center justify-center mx-auto mb-5" style={{ background: '#E8F8F0' }}>
                <svg width="32" height="32" viewBox="0 0 32 32" fill="none">
                  <path d="M6 16l6 6 14-14" stroke="#5DBF94" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </div>
              <h2 className="text-2xl font-bold mb-2" style={{ color: '#2C2D81' }}>Proverite email!</h2>
              <p className="text-gray-500 mb-1 text-sm">Poslali smo vam link za potvrdu na:</p>
              <p className="font-semibold text-gray-700 mb-5">{form.email}</p>
              <p className="text-xs text-gray-400 mb-6">Kliknite na link u emailu da aktivirate nalog. Proverite i spam folder.</p>
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
      </div>
    )
  }

  return (
    <div className="min-h-screen flex flex-col" style={{ background: 'linear-gradient(135deg, #1A1C4E 0%, #2C2D81 60%, #3766B0 100%)' }}>
      <div className="fixed inset-0 pointer-events-none overflow-hidden">
        <div className="absolute -top-32 -right-32 w-96 h-96 rounded-full opacity-10" style={{ background: '#FDC361' }} />
        <div className="absolute -bottom-20 -left-20 w-80 h-80 rounded-full opacity-10" style={{ background: '#5DBF94' }} />
      </div>

      <div className="relative flex-1 flex flex-col items-center justify-center px-4 py-12">
        <div className="mb-8 text-center">
          <a href="https://www.librum.club" rel="noopener noreferrer" className="inline-block mb-4">
            <Image src="/logo-dark.png" alt="Librum club" height={36} width={160} style={{ objectFit: 'contain' }} />
          </a>
          <p className="text-sm" style={{ color: 'rgba(255,255,255,0.55)' }}>Kreirajte besplatan nalog</p>
        </div>

        <div className="w-full max-w-md bg-white rounded-2xl shadow-2xl overflow-hidden">
          <div className="h-1.5" style={{ background: 'linear-gradient(90deg, #FDC361, #5DBF94)' }} />
          <div className="p-8">
            <h2 className="text-xl font-bold mb-6" style={{ color: '#1A1C4E' }}>Registracija</h2>

            <form onSubmit={handleSubmit} className="space-y-4">
              {error && (
                <div className="bg-red-50 border border-red-200 text-red-700 rounded-xl px-4 py-3 text-sm">
                  {error}
                </div>
              )}

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wide">Ime</label>
                  <input type="text" required value={form.ime} onChange={e => set('ime', e.target.value)}
                    className="w-full px-3 py-2.5 rounded-xl border border-gray-200 focus:outline-none focus:ring-2 focus:border-[#2C2D81] transition-colors text-sm"
                    placeholder="Marko" />
                </div>
                <div>
                  <label className="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wide">Prezime</label>
                  <input type="text" required value={form.prezime} onChange={e => set('prezime', e.target.value)}
                    className="w-full px-3 py-2.5 rounded-xl border border-gray-200 focus:outline-none focus:ring-2 focus:border-[#2C2D81] transition-colors text-sm"
                    placeholder="Marković" />
                </div>
              </div>

              <div>
                <label className="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wide">
                  Nadimak <span className="font-normal normal-case text-gray-400">(rang lista)</span>
                </label>
                <input type="text" value={form.nadimak} onChange={e => set('nadimak', e.target.value)}
                  className="w-full px-3 py-2.5 rounded-xl border border-gray-200 focus:outline-none focus:ring-2 focus:border-[#2C2D81] transition-colors text-sm"
                  placeholder="npr. KnjigaLover23" />
              </div>

              <div>
                <label className="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wide">Grad</label>
                <input type="text" value={form.grad} onChange={e => set('grad', e.target.value)}
                  className="w-full px-3 py-2.5 rounded-xl border border-gray-200 focus:outline-none focus:ring-2 focus:border-[#2C2D81] transition-colors text-sm"
                  placeholder="npr. Beograd" />
              </div>

              <div>
                <label className="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wide">Email adresa</label>
                <input type="email" required value={form.email} onChange={e => set('email', e.target.value)}
                  className="w-full px-3 py-2.5 rounded-xl border border-gray-200 focus:outline-none focus:ring-2 focus:border-[#2C2D81] transition-colors text-sm"
                  placeholder="vas@email.com" />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wide">Lozinka</label>
                  <input type="password" required value={form.password} onChange={e => set('password', e.target.value)}
                    className="w-full px-3 py-2.5 rounded-xl border border-gray-200 focus:outline-none focus:ring-2 focus:border-[#2C2D81] transition-colors text-sm"
                    placeholder="Min. 6 karaktera" />
                </div>
                <div>
                  <label className="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wide">Ponovite</label>
                  <input type="password" required value={form.password2} onChange={e => set('password2', e.target.value)}
                    className="w-full px-3 py-2.5 rounded-xl border border-gray-200 focus:outline-none focus:ring-2 focus:border-[#2C2D81] transition-colors text-sm"
                    placeholder="••••••••" />
                </div>
              </div>

              <button type="submit" disabled={loading}
                className="w-full py-3.5 rounded-xl font-bold text-white transition-all hover:scale-[1.02] disabled:opacity-60 disabled:scale-100 mt-2"
                style={{ background: 'linear-gradient(135deg, #2C2D81, #3766B0)' }}>
                {loading ? 'Registracija...' : 'Registrujte se besplatno'}
              </button>
            </form>

            <div className="mt-6 pt-6 border-t border-gray-100 text-center text-sm text-gray-500">
              Već imate nalog?{' '}
              <Link href="/auth/prijava" className="font-semibold hover:underline" style={{ color: '#2C2D81' }}>
                Prijavite se
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
