'use client'

export const dynamic = 'force-dynamic'

import Link from 'next/link'
import { useState, Suspense } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { IconBack, IconEmail, IconLock, IconEye, IconEyeOff, IconCheck } from '@/components/icons'
import { Logo } from '@/components/Logo'
import { sendCustomPasswordResetEmail } from '@/lib/password-reset'

function PrijavaForm() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const redirect = searchParams.get('redirect') || '/profil'

  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
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
    if (error) setError('Pogrešan email ili lozinka.')
    else { router.push(redirect); router.refresh() }
    setLoading(false)
  }

  async function handleForgot(e: React.FormEvent) {
    e.preventDefault()
    setResetLoading(true)
    await sendCustomPasswordResetEmail(resetEmail)
    setResetSent(true)
    setResetLoading(false)
  }

  if (forgotMode) {
    return (
      <div>
        <button
          onClick={() => { setForgotMode(false); setResetSent(false) }}
          className="flex items-center gap-1.5 text-[13px] font-medium mb-6 transition-colors hover:opacity-70"
          style={{ color: '#23845C' }}
        >
          <IconBack size={16} strokeWidth={2.2} />
          Nazad na prijavu
        </button>

        {resetSent ? (
          <div className="text-center py-4">
            <div className="w-14 h-14 rounded-full flex items-center justify-center mx-auto mb-4"
              style={{ background: '#FFF5E0' }}>
              <IconCheck size={28} className="text-[#FDC361]" />
            </div>
            <h3 className="font-bold text-[17px] mb-2" style={{ color: '#1A1B3A' }}>Email je poslat!</h3>
            <p className="text-[14px] leading-relaxed" style={{ color: '#4F5170' }}>
              Proveri inbox (i spam) na <span className="font-semibold" style={{ color: '#1A1B3A' }}>{resetEmail}</span>.
            </p>
          </div>
        ) : (
          <form onSubmit={handleForgot} className="space-y-4">
            <p className="text-[13px] mb-1" style={{ color: '#4F5170' }}>
              Poslaćemo ti link za novu lozinku.
            </p>
            <InputWithIcon
              Icon={IconEmail}
              type="email"
              required
              value={resetEmail}
              onChange={e => setResetEmail(e.target.value)}
              placeholder="vas@email.com"
            />
            <button type="submit" disabled={resetLoading} className="btn btn-primary btn-lg w-full">
              {resetLoading ? 'Slanje...' : 'Pošalji link'}
            </button>
          </form>
        )}
      </div>
    )
  }

  const potvrdjeno = searchParams.get('potvrdjeno') === '1'
  const greskaParam = searchParams.get('greska')

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      {potvrdjeno && (
        <div className="rounded-2xl px-4 py-3 text-[13px] font-medium" style={{ background: '#E8F6EF', color: '#0A4C35' }}>
          ✓ Email potvrđen — prijavi se ispod.
        </div>
      )}
      {greskaParam === 'potvrda' && (
        <div className="rounded-2xl px-4 py-3 text-[13px] font-medium" style={{ background: '#FFE3EA', color: '#C42B4F' }}>
          Link za potvrdu je istekao. Pokušaj ponovo da se registruješ.
        </div>
      )}
      {error && (
        <div className="rounded-2xl px-4 py-3 text-[13px] font-medium" style={{ background: '#FFE3EA', color: '#C42B4F' }}>
          {error}
        </div>
      )}

      <InputWithIcon
        Icon={IconEmail}
        type="email"
        required
        value={email}
        onChange={e => setEmail(e.target.value)}
        placeholder="Email adresa"
      />

      <div>
        <InputWithIcon
          Icon={IconLock}
          rightIcon={showPassword ? IconEyeOff : IconEye}
          onRightIconClick={() => setShowPassword(s => !s)}
          type={showPassword ? 'text' : 'password'}
          required
          value={password}
          onChange={e => setPassword(e.target.value)}
          placeholder="Lozinka"
        />
        <div className="flex justify-end mt-2">
          <button type="button" onClick={() => { setForgotMode(true); setResetEmail(email) }}
            className="text-[12px] font-semibold transition-opacity hover:opacity-70" style={{ color: '#23845C' }}>
            Zaboravljena lozinka?
          </button>
        </div>
      </div>

      <button type="submit" disabled={loading} className="btn btn-primary btn-lg w-full mt-2">
        {loading ? 'Prijava…' : 'Prijavi se'}
      </button>
    </form>
  )
}

// Reusable input with leading icon (and optional trailing button)
function InputWithIcon({
  Icon, rightIcon: RightIcon, onRightIconClick, ...props
}: {
  Icon: React.ComponentType<{ size?: number; strokeWidth?: number; className?: string }>
  rightIcon?: React.ComponentType<{ size?: number; strokeWidth?: number; className?: string }>
  onRightIconClick?: () => void
} & React.InputHTMLAttributes<HTMLInputElement>) {
  return (
    <div className="relative">
      <div className="absolute left-4 top-1/2 -translate-y-1/2 pointer-events-none" style={{ color: '#4F5170' }}>
        <Icon size={18} strokeWidth={2} />
      </div>
      <input {...props} className="input pl-11 pr-11" />
      {RightIcon && (
        <button type="button" onClick={onRightIconClick}
          className="absolute right-3 top-1/2 -translate-y-1/2 p-1 rounded-md transition-opacity hover:opacity-70"
          style={{ color: '#4F5170' }}>
          <RightIcon size={18} strokeWidth={2} />
        </button>
      )}
    </div>
  )
}

export default function PrijavaPage() {
  return (
    <div className="min-h-screen flex flex-col">
      <nav className="sticky top-0 z-40" style={{ background: '#F6F1E7' }}>
        <div className="h-[3px]" style={{ background: 'linear-gradient(90deg, #23845C 0%, #3766B0 50%, #23845C 100%)' }} />
        <div className="max-w-6xl mx-auto px-4 sm:px-6 h-[72px] flex items-center justify-between" style={{ borderBottom: '1px solid #1A1B3A' }}>
          <Logo height={32} />
          <Link href="/auth/registracija" className="btn btn-primary btn-sm">Registracija</Link>
        </div>
      </nav>

      <main className="flex-1 flex items-center justify-center px-4 py-12 sm:py-20">
        <div className="w-full max-w-md">
          <div className="mb-8">
            <h1 className="leading-[0.95] mb-3" style={{ color: '#1A1B3A', fontSize: 'clamp(40px, 8vw, 64px)', fontWeight: 500 }}>
              Prijava.
            </h1>
            <p className="text-[15px]" style={{ color: '#4F5170' }}>Istom nalogom igraš sve kvizove.</p>
          </div>

          <div className="card-soft p-7 sm:p-8">
            <Suspense>
              <PrijavaForm />
            </Suspense>
          </div>

          <p className="text-center mt-6 text-[14px]" style={{ color: '#4F5170' }}>
            Nemaš nalog?{' '}
            <Link href="/auth/registracija" className="font-semibold underline" style={{ color: '#1A1B3A' }}>
              Registruj se
            </Link>
          </p>
        </div>
      </main>
    </div>
  )
}
