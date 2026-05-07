'use client'

export const dynamic = 'force-dynamic'

import { useState, Suspense } from 'react'
import Link from 'next/link'
import { useRouter, useSearchParams } from 'next/navigation'
import { Logo } from '@/components/Logo'
import { IconLock, IconEye, IconEyeOff, IconCheck } from '@/components/icons'
import { redeemPasswordResetToken } from '@/lib/password-reset'

type Phase = 'loading' | 'ready' | 'invalid' | 'success'

function NovaLozinkaInner() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const token = searchParams.get('reset')

  const [pw, setPw] = useState('')
  const [pw2, setPw2] = useState('')
  const [show, setShow] = useState(false)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  // Phase derives directly from the URL token — no need for state + effect.
  const [phase, setPhase] = useState<Phase>(token ? 'ready' : 'invalid')

  async function submit(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    if (!token) { setPhase('invalid'); return }
    if (pw.length < 6) { setError('Lozinka mora imati najmanje 6 karaktera.'); return }
    if (pw !== pw2) { setError('Lozinke se ne poklapaju.'); return }

    setBusy(true)
    const res = await redeemPasswordResetToken(token, pw)
    setBusy(false)
    if (!res.ok) { setError(res.error); return }
    setPhase('success')
    setTimeout(() => router.push('/auth/prijava?potvrdjeno=1'), 2500)
  }

  return (
    <div className="min-h-screen flex items-center justify-center px-4 py-10" style={{ background: '#FAFAFA' }}>
      <div className="w-full max-w-md">

        <div className="text-center mb-8">
          <Logo height={28} />
        </div>

        <div className="card-soft p-7 sm:p-8">
          <h1 className="font-black tracking-tight mb-2 text-center" style={{ color: '#343434', fontSize: 'clamp(22px, 4vw, 28px)' }}>
            Nova lozinka
          </h1>
          <p className="text-[13px] text-center mb-6" style={{ color: '#9C9C9C' }}>
            Postavi novu lozinku za svoj nalog.
          </p>

          {phase === 'loading' && (
            <div className="text-center py-6">
              <div className="w-8 h-8 rounded-full border-2 animate-spin mx-auto"
                style={{ borderColor: '#609DED', borderTopColor: 'transparent' }} />
            </div>
          )}

          {phase === 'success' && (
            <div className="text-center py-4">
              <div className="w-14 h-14 rounded-full flex items-center justify-center mx-auto mb-4" style={{ background: '#E8F8F0' }}>
                <IconCheck size={28} className="text-[#15803d]" />
              </div>
              <p className="font-bold text-[16px] mb-1" style={{ color: '#15803d' }}>Lozinka je promenjena!</p>
              <p className="text-[13px]" style={{ color: '#9C9C9C' }}>Preusmeravam na prijavu…</p>
            </div>
          )}

          {phase === 'invalid' && (
            <div>
              <div className="rounded-2xl px-4 py-3 text-[13px] font-medium mb-4" style={{ background: '#FEE2E2', color: '#b91c1c' }}>
                Link je istekao, već je iskorišćen ili je nevalidan. Zatraži novi sa stranice za prijavu.
              </div>
              <Link href="/auth/prijava" className="btn btn-primary btn-md w-full">Idi na prijavu</Link>
            </div>
          )}

          {phase === 'ready' && (
            <form onSubmit={submit} className="space-y-3">
              <div className="relative">
                <div className="absolute left-4 top-1/2 -translate-y-1/2 pointer-events-none" style={{ color: '#9C9C9C' }}>
                  <IconLock size={18} strokeWidth={2} />
                </div>
                <input type={show ? 'text' : 'password'} required value={pw} onChange={e => setPw(e.target.value)}
                  className="input pl-11 pr-10" placeholder="Nova lozinka" autoFocus />
                <button type="button" onClick={() => setShow(s => !s)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 p-1" style={{ color: '#9C9C9C' }}>
                  {show ? <IconEyeOff size={18} strokeWidth={2} /> : <IconEye size={18} strokeWidth={2} />}
                </button>
              </div>

              <div className="relative">
                <div className="absolute left-4 top-1/2 -translate-y-1/2 pointer-events-none" style={{ color: '#9C9C9C' }}>
                  <IconLock size={18} strokeWidth={2} />
                </div>
                <input type={show ? 'text' : 'password'} required value={pw2} onChange={e => setPw2(e.target.value)}
                  className="input pl-11" placeholder="Ponovi lozinku" />
              </div>

              {error && (
                <div className="rounded-2xl px-4 py-3 text-[13px] font-medium" style={{ background: '#FEE2E2', color: '#b91c1c' }}>
                  {error}
                </div>
              )}

              <button type="submit" disabled={busy} className="btn btn-primary btn-lg w-full mt-4">
                {busy ? 'Čuvanje…' : 'Postavi novu lozinku'}
              </button>
            </form>
          )}
        </div>
      </div>
    </div>
  )
}

export default function NovaLozinkaPage() {
  return (
    <Suspense>
      <NovaLozinkaInner />
    </Suspense>
  )
}
