'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'

// Admin moderation panel — block / approve email / send password reset
// / resend signup confirmation / set password directly.
//
// Each button POSTs to /api/admin/user-actions which re-checks the
// caller's role server-side. The client component never sees the
// service-role key.

type Props = {
  userId: string
  email: string | null
  isBlocked: boolean
}

type ActionId = 'block' | 'unblock' | 'approve_email' | 'send_reset' | 'resend_invite' | 'set_password'

export default function UserActions({ userId, email, isBlocked }: Props) {
  const router = useRouter()
  const [busy, setBusy] = useState<ActionId | null>(null)
  const [msg, setMsg] = useState<{ kind: 'ok' | 'err'; text: string } | null>(null)
  const [showPwdModal, setShowPwdModal] = useState(false)
  const [newPwd, setNewPwd] = useState('')

  async function run(action: ActionId, extra: Record<string, unknown> = {}) {
    setBusy(action)
    setMsg(null)
    try {
      const res = await fetch('/api/admin/user-actions', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action, user_id: userId, ...extra }),
      })
      const json = await res.json()
      if (!res.ok || !json.ok) {
        setMsg({ kind: 'err', text: `Greška: ${json.error || res.status}` })
        return
      }
      setMsg({ kind: 'ok', text: SUCCESS_LABEL[action] })
      router.refresh()
    } catch {
      setMsg({ kind: 'err', text: 'Mreža nije odgovorila.' })
    } finally {
      setBusy(null)
    }
  }

  async function submitNewPassword() {
    if (newPwd.length < 8) {
      setMsg({ kind: 'err', text: 'Lozinka mora imati barem 8 karaktera.' })
      return
    }
    await run('set_password', { password: newPwd })
    setNewPwd('')
    setShowPwdModal(false)
  }

  const disabled = busy !== null

  return (
    <div className="card-soft p-5">
      <p className="text-[11px] font-bold uppercase tracking-widest mb-3" style={{ color: '#9C9C9C' }}>
        Admin akcije
      </p>

      {isBlocked && (
        <div className="rounded-2xl px-3 py-2 mb-3 text-[12px] font-medium"
          style={{ background: '#FEE2E2', color: '#b91c1c' }}>
          🚫 Korisnik je blokiran. Ne može da se uloguje.
        </div>
      )}

      <div className="flex flex-wrap gap-2">
        {isBlocked ? (
          <Button kind="primary" onClick={() => run('unblock')} disabled={disabled} busy={busy === 'unblock'}>
            ✓ Otključaj korisnika
          </Button>
        ) : (
          <Button kind="danger" onClick={() => {
            if (confirm('Stvarno blokirati ovog korisnika? Neće moći da se uloguje dok ga ne otključaš.')) run('block')
          }} disabled={disabled} busy={busy === 'block'}>
            🚫 Blokiraj
          </Button>
        )}

        <Button kind="secondary" onClick={() => run('approve_email')} disabled={disabled || !email} busy={busy === 'approve_email'}
          title={email ? 'Odobri ulazak bez slanja maila' : 'Korisnik nema email'}>
          ✓ Odobri ulazak
        </Button>

        <Button kind="secondary" onClick={() => run('send_reset')} disabled={disabled || !email} busy={busy === 'send_reset'}
          title={email ? `Pošalji reset lozinke na ${email}` : 'Korisnik nema email'}>
          ✉ Pošalji reset lozinke
        </Button>

        <Button kind="secondary" onClick={() => run('resend_invite')} disabled={disabled || !email} busy={busy === 'resend_invite'}
          title={email ? `Pošalji potvrdu na ${email}` : 'Korisnik nema email'}>
          ✉ Ponovo pošalji potvrdu
        </Button>

        <Button kind="secondary" onClick={() => setShowPwdModal(true)} disabled={disabled} busy={busy === 'set_password'}>
          🔑 Postavi lozinku ručno
        </Button>
      </div>

      {msg && (
        <p className="mt-3 text-[12px] font-medium"
          style={{ color: msg.kind === 'ok' ? '#15803d' : '#b91c1c' }}>
          {msg.text}
        </p>
      )}

      {/* ── Set-password modal ───────────────────────────────────── */}
      {showPwdModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center px-4 backdrop-blur-sm"
          style={{ background: 'rgba(52,52,52,0.40)' }}>
          <div className="card-soft p-6 max-w-sm w-full">
            <h3 className="font-black text-[18px] tracking-tight mb-2" style={{ color: '#343434' }}>
              Postavi novu lozinku
            </h3>
            <p className="text-[12px] mb-4" style={{ color: '#9C9C9C' }}>
              Korisnik će moći da se uloguje sa ovom lozinkom. Pošalji mu je usmeno ili šifrovanim kanalom — nemoj preko običnog maila.
            </p>
            <input
              type="text"
              autoFocus
              value={newPwd}
              onChange={e => setNewPwd(e.target.value)}
              placeholder="Min. 8 karaktera"
              className="input mb-4"
            />
            <div className="flex gap-2 justify-end">
              <button className="btn btn-secondary btn-sm" onClick={() => { setShowPwdModal(false); setNewPwd('') }}>
                Otkaži
              </button>
              <button className="btn btn-primary btn-sm" onClick={submitNewPassword}
                disabled={newPwd.length < 8 || busy === 'set_password'}>
                {busy === 'set_password' ? 'Postavljam…' : 'Postavi'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

const SUCCESS_LABEL: Record<ActionId, string> = {
  block: '🚫 Korisnik blokiran',
  unblock: '✓ Korisnik otključan',
  approve_email: '✓ Email odobren — može da se uloguje',
  send_reset: '✉ Email za reset poslat',
  resend_invite: '✉ Potvrda ponovo poslata',
  set_password: '🔑 Nova lozinka postavljena',
}

function Button({ children, kind, onClick, disabled, busy, title }: {
  children: React.ReactNode
  kind: 'primary' | 'secondary' | 'danger'
  onClick: () => void
  disabled?: boolean
  busy?: boolean
  title?: string
}) {
  const colors = {
    primary: { bg: '#609DED', fg: 'white' },
    secondary: { bg: '#F2F2F2', fg: '#343434' },
    danger: { bg: '#E55353', fg: 'white' },
  }[kind]
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      title={title}
      className="px-3 py-2 rounded-full text-[12px] font-bold transition-opacity hover:opacity-80 disabled:opacity-40 disabled:cursor-not-allowed"
      style={{ background: colors.bg, color: colors.fg }}
    >
      {busy ? 'Radim…' : children}
    </button>
  )
}
