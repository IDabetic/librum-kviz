'use client'

import { useState } from 'react'
import Image from 'next/image'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { IconCheck, IconLock, IconEye, IconEyeOff } from '@/components/icons'
import { changeUnlockCode } from './actions'

const TOTAL_AVATARS = 26
const AVATAR_LIST = Array.from({ length: TOTAL_AVATARS }, (_, i) =>
  `avatar_${String(i + 1).padStart(2, '0')}.jpg`
)

type Profile = {
  id: string
  first_name: string | null
  last_name: string | null
  nickname: string | null
  city: string | null
  avatar: string | null
  role: string
}

export default function SettingsForm({ profile, email }: { profile: Profile; email: string }) {
  const router = useRouter()

  // Profile fields
  const [form, setForm] = useState({
    first_name: profile.first_name || '',
    last_name: profile.last_name || '',
    nickname: profile.nickname || '',
    city: profile.city || '',
  })
  const [avatar, setAvatar] = useState(profile.avatar || 'avatar_01.jpg')
  const [savingProfile, setSavingProfile] = useState(false)
  const [profileSaved, setProfileSaved] = useState(false)
  const [profileError, setProfileError] = useState('')

  // Password change
  const [newPw, setNewPw] = useState('')
  const [newPw2, setNewPw2] = useState('')
  const [savingPw, setSavingPw] = useState(false)
  const [pwSaved, setPwSaved] = useState(false)
  const [pwError, setPwError] = useState('')

  // Reset via email (for OAuth users)
  const [sendingReset, setSendingReset] = useState(false)
  const [resetSent, setResetSent] = useState(false)

  // Admin unlock code (super_admin only)
  const [unlockCode, setUnlockCode] = useState('')
  const [unlockCode2, setUnlockCode2] = useState('')
  const [showCode, setShowCode] = useState(false)
  const [savingCode, setSavingCode] = useState(false)
  const [codeSaved, setCodeSaved] = useState(false)
  const [codeError, setCodeError] = useState('')

  async function saveProfile() {
    setProfileError('')
    setSavingProfile(true)
    const supabase = createClient()
    const { error } = await supabase.from('profiles').update({
      first_name: form.first_name,
      last_name: form.last_name,
      nickname: form.nickname,
      city: form.city,
      avatar,
    }).eq('id', profile.id)
    setSavingProfile(false)
    if (error) { setProfileError(error.message); return }
    setProfileSaved(true)
    setTimeout(() => setProfileSaved(false), 2500)
    router.refresh()
  }

  async function changePassword() {
    setPwError('')
    if (newPw.length < 6) { setPwError('Lozinka mora imati najmanje 6 karaktera.'); return }
    if (newPw !== newPw2) { setPwError('Lozinke se ne poklapaju.'); return }

    setSavingPw(true)
    const supabase = createClient()
    const { error } = await supabase.auth.updateUser({ password: newPw })
    setSavingPw(false)
    if (error) { setPwError(error.message); return }
    setPwSaved(true)
    setNewPw(''); setNewPw2('')
    setTimeout(() => setPwSaved(false), 3000)
  }

  async function sendResetEmail() {
    setSendingReset(true)
    await createClient().auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/auth/callback?next=/auth/nova-lozinka`,
    })
    setSendingReset(false)
    setResetSent(true)
    setTimeout(() => setResetSent(false), 5000)
  }

  async function saveUnlockCode() {
    setCodeError('')
    if (unlockCode.length < 6) { setCodeError('Kod mora imati najmanje 6 karaktera.'); return }
    if (unlockCode !== unlockCode2) { setCodeError('Kodovi se ne poklapaju.'); return }
    setSavingCode(true)
    const res = await changeUnlockCode(unlockCode)
    setSavingCode(false)
    if (!res.ok) { setCodeError(res.error); return }
    setCodeSaved(true)
    setUnlockCode(''); setUnlockCode2('')
    setTimeout(() => setCodeSaved(false), 3000)
  }

  return (
    <>
      {/* Identity */}
      <div className="card-soft p-6">
        <h2 className="font-bold text-[15px] mb-1 tracking-tight" style={{ color: '#343434' }}>Identitet</h2>
        <p className="text-[12px] mb-5" style={{ color: '#9C9C9C' }}>
          Email: <strong>{email}</strong> · Uloga: <strong style={{ color: '#FFCB46' }}>{profile.role.replace('_', ' ')}</strong>
        </p>

        {/* Avatar picker */}
        <p className="text-[11px] font-bold uppercase tracking-widest mb-2" style={{ color: '#9C9C9C' }}>Avatar</p>
        <div className="flex items-center gap-4 mb-4">
          <div className="w-14 h-14 rounded-2xl overflow-hidden flex-shrink-0 ring-2" style={{ ['--tw-ring-color' as string]: '#609DED' }}>
            <Image src={`/avatars/${avatar}`} alt="Avatar" width={56} height={56} className="w-full h-full object-cover" />
          </div>
          <div className="text-[12px]" style={{ color: '#9C9C9C' }}>Trenutni avatar</div>
        </div>
        <div className="grid grid-cols-9 sm:grid-cols-13 gap-1.5 mb-5">
          {AVATAR_LIST.map(av => (
            <button key={av} onClick={() => setAvatar(av)}
              className="relative rounded-xl overflow-hidden aspect-square transition-all hover:scale-110"
              style={{
                outline: avatar === av ? '3px solid #609DED' : '1px solid transparent',
                outlineOffset: 2,
              }}>
              <Image src={`/avatars/${av}`} alt={av} width={48} height={48} className="w-full h-full object-cover" />
            </button>
          ))}
        </div>

        <div className="grid sm:grid-cols-2 gap-3 mb-3">
          <input value={form.first_name} onChange={e => setForm(f => ({ ...f, first_name: e.target.value }))} className="input" placeholder="Ime" />
          <input value={form.last_name} onChange={e => setForm(f => ({ ...f, last_name: e.target.value }))} className="input" placeholder="Prezime" />
        </div>
        <div className="grid sm:grid-cols-2 gap-3 mb-4">
          <input value={form.nickname} onChange={e => setForm(f => ({ ...f, nickname: e.target.value }))} className="input" placeholder="Nadimak" />
          <input value={form.city} onChange={e => setForm(f => ({ ...f, city: e.target.value }))} className="input" placeholder="Grad" />
        </div>

        {profileError && (
          <div className="rounded-2xl px-4 py-3 mb-3 text-[13px] font-medium" style={{ background: '#FEE2E2', color: '#b91c1c' }}>{profileError}</div>
        )}

        <button onClick={saveProfile} disabled={savingProfile}
          className="btn btn-md w-full"
          style={profileSaved
            ? { background: '#4CAF50', color: 'white' }
            : { background: '#609DED', color: 'white' }}>
          {profileSaved ? '✓ Sačuvano' : savingProfile ? 'Čuvanje…' : 'Sačuvaj profil'}
        </button>
      </div>

      {/* Password */}
      <div className="card-soft p-6">
        <h2 className="font-bold text-[15px] mb-1 tracking-tight flex items-center gap-2" style={{ color: '#343434' }}>
          <IconLock size={16} strokeWidth={2.2} className="text-[#9C9C9C]" />
          Promena lozinke
        </h2>
        <p className="text-[12px] mb-5" style={{ color: '#9C9C9C' }}>
          Postavi novu lozinku za prijavu. Najmanje 6 karaktera.
        </p>

        <div className="space-y-3 mb-4">
          <input type="password" value={newPw} onChange={e => setNewPw(e.target.value)}
            className="input" placeholder="Nova lozinka" />
          <input type="password" value={newPw2} onChange={e => setNewPw2(e.target.value)}
            className="input" placeholder="Ponovi novu lozinku" />
        </div>

        {pwError && (
          <div className="rounded-2xl px-4 py-3 mb-3 text-[13px] font-medium" style={{ background: '#FEE2E2', color: '#b91c1c' }}>{pwError}</div>
        )}

        {pwSaved && (
          <div className="rounded-2xl px-4 py-3 mb-3 text-[13px] font-medium flex items-center gap-2" style={{ background: '#E8F8F0', color: '#15803d' }}>
            <IconCheck size={16} className="text-[#15803d]" /> Lozinka je promenjena.
          </div>
        )}

        <button onClick={changePassword} disabled={savingPw || !newPw || !newPw2}
          className="btn btn-md w-full mb-4"
          style={pwSaved
            ? { background: '#4CAF50', color: 'white' }
            : { background: '#609DED', color: 'white' }}>
          {savingPw ? 'Čuvanje…' : 'Promeni lozinku'}
        </button>

        {/* Email reset (works for OAuth-only users without a password) */}
        <div className="pt-4 border-t" style={{ borderColor: '#F2F2F2' }}>
          <p className="text-[12px] mb-3" style={{ color: '#9C9C9C' }}>
            Loguješ se preko GitHub-a i nemaš lozinku? Pošalji link na email i postavi prvu lozinku iz mejla.
          </p>
          {resetSent ? (
            <div className="rounded-2xl px-4 py-3 text-[13px] font-medium flex items-center gap-2" style={{ background: '#E8F8F0', color: '#15803d' }}>
              <IconCheck size={16} className="text-[#15803d]" /> Email poslat — proveri inbox.
            </div>
          ) : (
            <button onClick={sendResetEmail} disabled={sendingReset} className="btn btn-secondary btn-md w-full">
              {sendingReset ? 'Slanje…' : 'Pošalji link na email'}
            </button>
          )}
        </div>
      </div>

      {/* Admin unlock code (super_admin only) */}
      {profile.role === 'super_admin' && (
        <div className="card-soft p-6">
          <h2 className="font-bold text-[15px] mb-1 tracking-tight" style={{ color: '#343434' }}>🔐 Admin kod</h2>
          <p className="text-[12px] mb-5" style={{ color: '#9C9C9C' }}>
            Drugi faktor verifikacije za <code className="font-mono">/majmun/prijava</code>.
            Postojeće admin sesije se nastavljaju, ali sledeća prijava traži novi kod.
          </p>

          <div className="space-y-3 mb-4">
            <div className="relative">
              <input type={showCode ? 'text' : 'password'} value={unlockCode} onChange={e => setUnlockCode(e.target.value)}
                className="input pr-10" placeholder="Novi admin kod (min. 6 karaktera)" />
              <button type="button" onClick={() => setShowCode(s => !s)}
                className="absolute right-3 top-1/2 -translate-y-1/2 p-1" style={{ color: '#9C9C9C' }}>
                {showCode ? <IconEyeOff size={18} strokeWidth={2} /> : <IconEye size={18} strokeWidth={2} />}
              </button>
            </div>
            <input type={showCode ? 'text' : 'password'} value={unlockCode2} onChange={e => setUnlockCode2(e.target.value)}
              className="input" placeholder="Ponovi novi admin kod" />
          </div>

          {codeError && (
            <div className="rounded-2xl px-4 py-3 mb-3 text-[13px] font-medium" style={{ background: '#FEE2E2', color: '#b91c1c' }}>{codeError}</div>
          )}

          {codeSaved && (
            <div className="rounded-2xl px-4 py-3 mb-3 text-[13px] font-medium flex items-center gap-2" style={{ background: '#E8F8F0', color: '#15803d' }}>
              <IconCheck size={16} className="text-[#15803d]" /> Admin kod je promenjen.
            </div>
          )}

          <button onClick={saveUnlockCode} disabled={savingCode || !unlockCode || !unlockCode2}
            className="btn btn-md w-full"
            style={codeSaved
              ? { background: '#4CAF50', color: 'white' }
              : { background: '#609DED', color: 'white' }}>
            {savingCode ? 'Čuvanje…' : 'Promeni admin kod'}
          </button>

          <p className="text-[11px] mt-3" style={{ color: '#9C9C9C' }}>
            Trenutni kod nije prikazan — samo se može zameniti novim. Čuva se u bazi (RLS-zaštićeno, samo super_admin čita).
          </p>
        </div>
      )}
    </>
  )
}
