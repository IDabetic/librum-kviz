'use client'

import { useState, useActionState } from 'react'
import Link from 'next/link'
import { Logo } from '@/components/Logo'
import { createClient } from '@/lib/supabase/client'
import { IconEmail, IconLock, IconEye, IconEyeOff, IconCheck } from '@/components/icons'
import { adminLoginAction } from './actions'

export default function MajmunPrijavaPage() {
  const [state, action, pending] = useActionState(adminLoginAction, undefined)
  const [showPw, setShowPw] = useState(false)
  const [showCode, setShowCode] = useState(false)
  const [forgotMode, setForgotMode] = useState(false)
  const [resetEmail, setResetEmail] = useState('')
  const [resetSent, setResetSent] = useState(false)
  const [resetBusy, setResetBusy] = useState(false)
  const [resetError, setResetError] = useState('')

  async function sendReset(e: React.FormEvent) {
    e.preventDefault()
    setResetError('')
    if (!resetEmail.trim()) { setResetError('Upiši email.'); return }
    setResetBusy(true)
    const { error } = await createClient().auth.resetPasswordForEmail(resetEmail.trim(), {
      redirectTo: `${window.location.origin}/auth/nova-lozinka`,
    })
    setResetBusy(false)
    if (error) { setResetError(error.message); return }
    setResetSent(true)
  }

  return (
    <div className="min-h-screen flex items-center justify-center px-4 py-10" style={{ background: '#FAFAFA' }}>
      <div className="w-full max-w-md">

        <div className="text-center mb-8">
          <Logo height={28} />
          <p className="text-[11px] font-bold uppercase tracking-widest mt-3" style={{ color: '#9C9C9C' }}>
            Admin panel
          </p>
        </div>

        <div className="card-soft p-7 sm:p-8">
          <h1 className="font-black tracking-tight mb-2 text-center" style={{ color: '#343434', fontSize: 'clamp(22px, 4vw, 28px)' }}>
            {forgotMode ? 'Resetuj lozinku' : 'Prijava administratora'}
          </h1>
          <p className="text-[13px] text-center mb-6" style={{ color: '#9C9C9C' }}>
            {forgotMode
              ? 'Poslaćemo ti link za novu lozinku na email.'
              : 'Email + lozinka + admin kod (dvostruka verifikacija).'}
          </p>

          {/* Forgot password flow */}
          {forgotMode && (
            <>
              {resetSent ? (
                <div className="text-center py-3">
                  <div className="w-12 h-12 rounded-full flex items-center justify-center mx-auto mb-3" style={{ background: '#E8F8F0' }}>
                    <IconCheck size={24} className="text-[#15803d]" />
                  </div>
                  <p className="font-bold text-[15px] mb-1" style={{ color: '#15803d' }}>Email je poslat!</p>
                  <p className="text-[12px] mb-5" style={{ color: '#9C9C9C' }}>
                    Proveri inbox (i spam) na <strong style={{ color: '#343434' }}>{resetEmail}</strong>.
                  </p>
                  <button onClick={() => { setForgotMode(false); setResetSent(false); setResetEmail('') }}
                    className="btn btn-secondary btn-md w-full">
                    ← Nazad na prijavu
                  </button>
                </div>
              ) : (
                <form onSubmit={sendReset} className="space-y-3">
                  <div className="relative">
                    <div className="absolute left-4 top-1/2 -translate-y-1/2 pointer-events-none" style={{ color: '#9C9C9C' }}>
                      <IconEmail size={18} strokeWidth={2} />
                    </div>
                    <input type="email" required value={resetEmail} onChange={e => setResetEmail(e.target.value)}
                      className="input pl-11" placeholder="Email adresa" />
                  </div>
                  {resetError && (
                    <div className="rounded-2xl px-4 py-3 text-[13px] font-medium" style={{ background: '#FEE2E2', color: '#b91c1c' }}>
                      {resetError}
                    </div>
                  )}
                  <button type="submit" disabled={resetBusy} className="btn btn-primary btn-lg w-full">
                    {resetBusy ? 'Slanje…' : 'Pošalji link'}
                  </button>
                  <button type="button" onClick={() => setForgotMode(false)}
                    className="block w-full text-center text-[13px] font-medium transition-opacity hover:opacity-70 mt-2"
                    style={{ color: '#9C9C9C' }}>
                    ← Nazad na prijavu
                  </button>
                </form>
              )}
            </>
          )}

          {/* Login flow */}
          {!forgotMode && (
            <>
          {state?.error && (
            <div className="rounded-2xl px-4 py-3 mb-4 text-[13px] font-medium" style={{ background: '#FEE2E2', color: '#b91c1c' }}>
              {state.error}
            </div>
          )}

          <form action={action} className="space-y-3">
            <div className="relative">
              <div className="absolute left-4 top-1/2 -translate-y-1/2 pointer-events-none" style={{ color: '#9C9C9C' }}>
                <IconEmail size={18} strokeWidth={2} />
              </div>
              <input name="email" type="email" required className="input pl-11" placeholder="Email adresa" />
            </div>

            <div className="relative">
              <div className="absolute left-4 top-1/2 -translate-y-1/2 pointer-events-none" style={{ color: '#9C9C9C' }}>
                <IconLock size={18} strokeWidth={2} />
              </div>
              <input name="password" type={showPw ? 'text' : 'password'} required className="input pl-11 pr-10" placeholder="Lozinka" />
              <button type="button" onClick={() => setShowPw(s => !s)}
                className="absolute right-3 top-1/2 -translate-y-1/2 p-1" style={{ color: '#9C9C9C' }}>
                {showPw ? <IconEyeOff size={18} strokeWidth={2} /> : <IconEye size={18} strokeWidth={2} />}
              </button>
            </div>

            <div className="relative">
              <div className="absolute left-4 top-1/2 -translate-y-1/2 pointer-events-none text-[16px]" style={{ color: '#9C9C9C' }}>
                🔐
              </div>
              <input name="code" type={showCode ? 'text' : 'password'} required className="input pl-11 pr-10" placeholder="Admin kod" />
              <button type="button" onClick={() => setShowCode(s => !s)}
                className="absolute right-3 top-1/2 -translate-y-1/2 p-1" style={{ color: '#9C9C9C' }}>
                {showCode ? <IconEyeOff size={18} strokeWidth={2} /> : <IconEye size={18} strokeWidth={2} />}
              </button>
            </div>

            <button type="submit" disabled={pending} className="btn btn-primary btn-lg w-full mt-4">
              {pending ? 'Prijava…' : 'Otključaj admin panel'}
            </button>
          </form>

          <button onClick={() => setForgotMode(true)}
            className="block w-full text-center text-[12px] font-medium transition-opacity hover:opacity-70 mt-4"
            style={{ color: '#609DED' }}>
            Zaboravljena lozinka? Pošalji link
          </button>

          <p className="text-[11px] text-center mt-5" style={{ color: '#9C9C9C' }}>
            Sesija ističe nakon 8h. Ako pogrešiš bilo koji od 3 podatka, sistem ne otkriva koji.
          </p>
            </>
          )}
        </div>

        <Link href="/" className="block text-center mt-6 text-[13px] font-medium transition-opacity hover:opacity-70"
          style={{ color: '#9C9C9C' }}>
          ← Nazad na sajt
        </Link>
      </div>
    </div>
  )
}
