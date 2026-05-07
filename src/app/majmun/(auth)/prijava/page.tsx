'use client'

import { useState, useActionState } from 'react'
import Link from 'next/link'
import { Logo } from '@/components/Logo'
import { IconEmail, IconLock, IconEye, IconEyeOff } from '@/components/icons'
import { adminLoginAction } from './actions'

export default function MajmunPrijavaPage() {
  const [state, action, pending] = useActionState(adminLoginAction, undefined)
  const [showPw, setShowPw] = useState(false)
  const [showCode, setShowCode] = useState(false)

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
            Prijava administratora
          </h1>
          <p className="text-[13px] text-center mb-6" style={{ color: '#9C9C9C' }}>
            Email + lozinka + admin kod (dvostruka verifikacija).
          </p>

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

          <p className="text-[11px] text-center mt-5" style={{ color: '#9C9C9C' }}>
            Sesija ističe nakon 8h. Ako pogrešiš bilo koji od 3 podatka, sistem ne otkriva koji.
          </p>
        </div>

        <Link href="/" className="block text-center mt-6 text-[13px] font-medium transition-opacity hover:opacity-70"
          style={{ color: '#9C9C9C' }}>
          ← Nazad na sajt
        </Link>
      </div>
    </div>
  )
}
