'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import { IconCheck, IconEmail } from '@/components/icons'
import { lookupUserByEmail, assignRole } from './actions'

const ROLE_LABELS: Record<string, string> = {
  user: 'Korisnik',
  urednik: 'Urednik',
  moderator: 'Moderator',
  super_admin: 'Super admin',
}

const ASSIGNABLE_ROLES = [
  { id: 'urednik',     label: 'Urednik',     desc: 'Dodaje pitanja, ne menja podešavanja' },
  { id: 'moderator',   label: 'Moderator',   desc: 'Sve osim brisanja korisnika i menjanja uloga' },
  { id: 'super_admin', label: 'Super admin', desc: 'Pun pristup svemu' },
] as const

type Found = { userId: string; name: string; currentRole: string }

export default function AddAdminForm() {
  const router = useRouter()
  const [email, setEmail] = useState('')
  const [found, setFound] = useState<Found | null>(null)
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)
  const [selectedRole, setSelectedRole] = useState<string>('moderator')
  const [success, setSuccess] = useState<string>('')

  async function handleLookup(e: React.FormEvent) {
    e.preventDefault()
    setError(''); setSuccess(''); setFound(null)
    if (!email.trim()) return
    setBusy(true)
    const res = await lookupUserByEmail(email)
    setBusy(false)
    if (!res.ok) { setError(res.error); return }
    setFound({ userId: res.userId, name: res.name, currentRole: res.currentRole })
  }

  async function handleAssign() {
    if (!found) return
    setError('')
    setBusy(true)
    const res = await assignRole(found.userId, selectedRole)
    setBusy(false)
    if (!res.ok) { setError(res.error); return }
    setSuccess(`${found.name} je sada ${ROLE_LABELS[selectedRole]}.`)
    setFound({ ...found, currentRole: selectedRole })
    router.refresh()
  }

  return (
    <div className="card-soft p-6 sm:p-7">
      {/* Step 1: lookup */}
      <form onSubmit={handleLookup}>
        <label className="block text-[13px] font-bold mb-2 tracking-tight" style={{ color: '#343434' }}>
          Email korisnika
        </label>
        <div className="flex gap-2">
          <div className="relative flex-1">
            <div className="absolute left-4 top-1/2 -translate-y-1/2 pointer-events-none" style={{ color: '#9C9C9C' }}>
              <IconEmail size={16} strokeWidth={2} />
            </div>
            <input value={email} onChange={e => setEmail(e.target.value)} type="email"
              className="input pl-11" placeholder="korisnik@primer.com" />
          </div>
          <button type="submit" disabled={busy} className="btn btn-primary btn-md flex-shrink-0">
            {busy ? '...' : 'Pronađi'}
          </button>
        </div>
        <p className="text-[11px] mt-2" style={{ color: '#9C9C9C' }}>
          Korisnik mora već biti registrovan. Ako nije, podeli mu link za registraciju i probaj kasnije.
        </p>
      </form>

      {error && (
        <div className="rounded-2xl px-4 py-3 mt-4 text-[13px] font-medium" style={{ background: '#FEE2E2', color: '#b91c1c' }}>
          {error}
        </div>
      )}

      {success && (
        <div className="rounded-2xl px-4 py-3 mt-4 text-[13px] font-medium flex items-center gap-2" style={{ background: '#E8F8F0', color: '#15803d' }}>
          <IconCheck size={16} className="text-[#15803d]" /> {success}
        </div>
      )}

      {/* Step 2: assign role */}
      {found && (
        <div className="mt-6 pt-6 border-t" style={{ borderColor: '#F2F2F2' }}>
          <p className="text-[11px] font-bold uppercase tracking-widest mb-2" style={{ color: '#9C9C9C' }}>Pronađen korisnik</p>
          <div className="rounded-2xl p-4 mb-5" style={{ background: '#F2F2F2' }}>
            <p className="font-bold text-[15px]" style={{ color: '#343434' }}>{found.name}</p>
            <p className="text-[12px] mt-1" style={{ color: '#9C9C9C' }}>
              Trenutna uloga: <strong>{ROLE_LABELS[found.currentRole]}</strong>
            </p>
          </div>

          <p className="text-[13px] font-bold mb-3 tracking-tight" style={{ color: '#343434' }}>Postavi novu ulogu</p>
          <div className="space-y-2 mb-5">
            {ASSIGNABLE_ROLES.map(r => (
              <button key={r.id} type="button" onClick={() => setSelectedRole(r.id)}
                className="w-full flex items-start gap-3 px-4 py-3 rounded-2xl text-left transition-all"
                style={selectedRole === r.id
                  ? { background: '#BCD9FF', border: '1.5px solid #609DED' }
                  : { background: '#F2F2F2', border: '1.5px solid transparent' }}>
                <div className="w-5 h-5 rounded-full border-2 flex items-center justify-center flex-shrink-0 mt-0.5"
                  style={selectedRole === r.id
                    ? { borderColor: '#609DED', background: '#609DED' }
                    : { borderColor: 'rgba(52,52,52,0.20)', background: 'white' }}>
                  {selectedRole === r.id && <div className="w-2 h-2 rounded-full bg-white" />}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="font-bold text-[14px] tracking-tight" style={{ color: '#343434' }}>{r.label}</div>
                  <div className="text-[12px] mt-0.5" style={{ color: '#9C9C9C' }}>{r.desc}</div>
                </div>
              </button>
            ))}
          </div>

          {/* Demote option */}
          <button type="button" onClick={() => setSelectedRole('user')}
            className="w-full text-[12px] font-medium mb-4 transition-opacity hover:opacity-70 underline"
            style={{ color: '#E55353' }}>
            ← Vrati u običnog korisnika (ukloni admin prava)
          </button>

          <div className="flex gap-2">
            <Link href="/majmun/korisnici" className="btn btn-secondary btn-md flex-1">Odustani</Link>
            <button onClick={handleAssign} disabled={busy || selectedRole === found.currentRole}
              className="btn btn-primary btn-md flex-1">
              {busy ? 'Čuvanje…' : selectedRole === found.currentRole ? 'Već je u toj ulozi' : `Postavi: ${ROLE_LABELS[selectedRole]}`}
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
