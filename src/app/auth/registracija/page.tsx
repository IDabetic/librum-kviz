'use client'

export const dynamic = 'force-dynamic'

import Link from 'next/link'
import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { IconEmail, IconLock, IconEye, IconEyeOff, IconProfile, IconCheck } from '@/components/icons'
import { Logo } from '@/components/Logo'

export default function RegistracijaPage() {
  const [form, setForm] = useState({ ime: '', prezime: '', nadimak: '', grad: '', email: '', password: '', password2: '' })
  const [showPw, setShowPw] = useState(false)
  const [showPw2, setShowPw2] = useState(false)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const [success, setSuccess] = useState(false)

  function set(field: string, value: string) {
    setForm(f => ({ ...f, [field]: value }))
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError('')

    if (form.password !== form.password2) { setError('Lozinke se ne poklapaju.'); return }
    if (form.password.length < 6) { setError('Lozinka mora imati najmanje 6 karaktera.'); return }

    setLoading(true)
    const supabase = createClient()
    const { error } = await supabase.auth.signUp({
      email: form.email,
      password: form.password,
      options: {
        emailRedirectTo: `${window.location.origin}/auth/callback`,
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
      <div className="min-h-screen flex items-center justify-center px-4 py-10">
        <div className="w-full max-w-md card-soft p-8 text-center">
          <div className="w-16 h-16 rounded-full flex items-center justify-center mx-auto mb-5"
            style={{ background: 'var(--warn-50)' }}>
            <IconCheck size={36} className="text-[#FDC361]" />
          </div>
          <h1 className="font-black tracking-tight mb-2" style={{ color: 'var(--ink)', fontSize: '28px' }}>
            Proveri email!
          </h1>
          <p className="text-[14px] mb-1" style={{ color: 'var(--ink-2)' }}>Poslali smo link za potvrdu na:</p>
          <p className="font-semibold text-[14px] mb-5" style={{ color: 'var(--ink)' }}>{form.email}</p>

          <p className="text-[13px] mb-5" style={{ color: 'var(--ink-2)' }}>
            Klikni na link u mejlu i odmah ulaziš u igru — bez ponovne prijave.
          </p>

          <div className="rounded-2xl px-4 py-3 mb-5 text-left text-[13px]" style={{ background: 'var(--warn-50)' }}>
            <p className="font-bold mb-0.5" style={{ color: 'var(--warn-t)' }}>📬 Nije stigao mejl?</p>
            <p style={{ color: 'var(--warn-t)' }}>Proveri <strong>SPAM / Junk</strong> folder.</p>
          </div>

          <Link href="/" className="block text-center text-[13px] font-medium" style={{ color: 'var(--ink-2)' }}>
            ← Nazad na sajt
          </Link>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen flex flex-col">
      <nav className="sticky top-0 z-40" style={{ background: 'var(--bg)' }}>
        <div className="h-[3px]" style={{ background: 'linear-gradient(90deg, #23845C 0%, #3766B0 50%, #23845C 100%)' }} />
        <div className="max-w-6xl mx-auto px-4 sm:px-6 h-[72px] flex items-center justify-between" style={{ borderBottom: '1px solid var(--ink)' }}>
          <Logo height={32} />
          <Link href="/auth/prijava" className="btn btn-primary btn-sm">Prijava</Link>
        </div>
      </nav>

      <main className="flex-1 flex items-center justify-center px-4 py-10 sm:py-16">
        <div className="w-full max-w-md">
          <div className="mb-8">
            <h1 className="leading-[0.95] mb-3" style={{ color: 'var(--ink)', fontSize: 'clamp(40px, 8vw, 64px)', fontWeight: 500 }}>
              Pridruži nam se.
            </h1>
            <p className="text-[15px]" style={{ color: 'var(--ink-2)' }}>Kreiraj besplatan nalog za 30 sekundi.</p>
          </div>

          <div className="card-soft p-7 sm:p-8">
            <form onSubmit={handleSubmit} className="space-y-3.5">
              {error && (
                <div className="rounded-2xl px-4 py-3 text-[13px] font-medium" style={{ background: 'var(--bad-50)', color: 'var(--bad-t)' }}>
                  {error}
                </div>
              )}

              <div className="grid grid-cols-2 gap-3">
                <input type="text" required value={form.ime} onChange={e => set('ime', e.target.value)}
                  className="input" placeholder="Ime" />
                <input type="text" required value={form.prezime} onChange={e => set('prezime', e.target.value)}
                  className="input" placeholder="Prezime" />
              </div>

              <div className="relative">
                <div className="absolute left-4 top-1/2 -translate-y-1/2 pointer-events-none" style={{ color: 'var(--ink-2)' }}>
                  <IconProfile size={18} strokeWidth={2} />
                </div>
                <input type="text" value={form.nadimak} onChange={e => set('nadimak', e.target.value)}
                  className="input pl-11" placeholder="Nadimak (na rang listi)" />
              </div>

              <input type="text" value={form.grad} onChange={e => set('grad', e.target.value)}
                className="input" placeholder="Grad" />

              <div className="relative">
                <div className="absolute left-4 top-1/2 -translate-y-1/2 pointer-events-none" style={{ color: 'var(--ink-2)' }}>
                  <IconEmail size={18} strokeWidth={2} />
                </div>
                <input type="email" required value={form.email} onChange={e => set('email', e.target.value)}
                  className="input pl-11" placeholder="Email adresa" />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div className="relative">
                  <div className="absolute left-4 top-1/2 -translate-y-1/2 pointer-events-none" style={{ color: 'var(--ink-2)' }}>
                    <IconLock size={18} strokeWidth={2} />
                  </div>
                  <input type={showPw ? 'text' : 'password'} required value={form.password} onChange={e => set('password', e.target.value)}
                    className="input pl-11 pr-10" placeholder="Lozinka" />
                  <button type="button" onClick={() => setShowPw(s => !s)}
                    className="absolute right-3 top-1/2 -translate-y-1/2" style={{ color: 'var(--ink-2)' }}>
                    {showPw ? <IconEyeOff size={18} strokeWidth={2} /> : <IconEye size={18} strokeWidth={2} />}
                  </button>
                </div>
                <div className="relative">
                  <div className="absolute left-4 top-1/2 -translate-y-1/2 pointer-events-none" style={{ color: 'var(--ink-2)' }}>
                    <IconLock size={18} strokeWidth={2} />
                  </div>
                  <input type={showPw2 ? 'text' : 'password'} required value={form.password2} onChange={e => set('password2', e.target.value)}
                    className="input pl-11 pr-10" placeholder="Ponovi" />
                  <button type="button" onClick={() => setShowPw2(s => !s)}
                    className="absolute right-3 top-1/2 -translate-y-1/2" style={{ color: 'var(--ink-2)' }}>
                    {showPw2 ? <IconEyeOff size={18} strokeWidth={2} /> : <IconEye size={18} strokeWidth={2} />}
                  </button>
                </div>
              </div>

              <button type="submit" disabled={loading} className="btn btn-primary btn-lg w-full mt-2">
                {loading ? 'Registracija…' : 'Registruj se'}
              </button>
            </form>
          </div>

          <p className="text-center mt-6 text-[14px]" style={{ color: 'var(--ink-2)' }}>
            Već imaš nalog?{' '}
            <Link href="/auth/prijava" className="font-semibold transition-opacity hover:opacity-70" style={{ color: 'var(--ok)' }}>
              Prijavi se
            </Link>
          </p>
        </div>
      </main>
    </div>
  )
}
