'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'

const ROLES = [
  { id: 'user', label: 'Korisnik' },
  { id: 'urednik', label: 'Urednik' },
  { id: 'moderator', label: 'Moderator' },
  { id: 'super_admin', label: 'Super admin' },
] as const

export default function RoleEditor({ userId, currentRole }: { userId: string; currentRole: string }) {
  const router = useRouter()
  const [role, setRole] = useState(currentRole)
  const [busy, setBusy] = useState(false)
  const [saved, setSaved] = useState(false)

  async function save() {
    if (role === currentRole) return
    setBusy(true)
    await createClient().from('profiles').update({ role }).eq('id', userId)
    setBusy(false); setSaved(true)
    setTimeout(() => setSaved(false), 2000)
    router.refresh()
  }

  return (
    <div>
      <p className="text-[11px] font-bold uppercase tracking-widest mb-2" style={{ color: '#9C9C9C' }}>Uloga</p>
      <div className="flex flex-wrap gap-1.5">
        {ROLES.map(r => (
          <button key={r.id} onClick={() => setRole(r.id)}
            className="px-3 py-1.5 rounded-full text-[12px] font-bold transition-all"
            style={role === r.id
              ? { background: '#343434', color: '#FCFCFC' }
              : { background: '#F2F2F2', color: '#9C9C9C' }}>
            {r.label}
          </button>
        ))}
      </div>
      {role !== currentRole && (
        <div className="mt-3 flex gap-2 items-center">
          <button onClick={save} disabled={busy} className="btn btn-primary btn-sm">
            {busy ? 'Čuvanje…' : `Postavi ${ROLES.find(r => r.id === role)?.label}`}
          </button>
          {saved && <span className="text-[12px] font-medium" style={{ color: '#4CAF50' }}>✓ Sačuvano</span>}
        </div>
      )}
    </div>
  )
}
