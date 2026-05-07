'use client'

export const dynamic = 'force-dynamic'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import Image from 'next/image'
import { createClient } from '@/lib/supabase/client'
import Header from '@/components/Header'
import { IconBack, IconCheck, IconLock } from '@/components/icons'

const TOTAL_AVATARS = 50
const AVATAR_LIST = Array.from({ length: TOTAL_AVATARS }, (_, i) =>
  `animal_${String(i + 1).padStart(2, '0')}.png`
)
const DEFAULT_AVATAR = 'animal_01.png'

export default function PodesavanjaPage() {
  const router = useRouter()

  const [form, setForm] = useState({ first_name: '', last_name: '', nickname: '', city: '' })
  const [avatar, setAvatar] = useState<string>('')
  const [avatarSaved, setAvatarSaved] = useState(false)
  const [savingAvatar, setSavingAvatar] = useState(false)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [saved, setSaved] = useState(false)
  const [error, setError] = useState('')

  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false)
  const [deleteConfirmText, setDeleteConfirmText] = useState('')
  const [deleting, setDeleting] = useState(false)

  const [emailSent, setEmailSent] = useState(false)
  const [sendingReset, setSendingReset] = useState(false)

  useEffect(() => {
    async function load() {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) { router.push('/auth/prijava'); return }
      const { data: profile } = await supabase.from('profiles').select('*').eq('id', user.id).single()
      if (profile) {
        setForm({
          first_name: profile.first_name || '',
          last_name: profile.last_name || '',
          nickname: profile.nickname || '',
          city: profile.city || '',
        })
        setAvatar(profile.avatar || DEFAULT_AVATAR)
      }
      setLoading(false)
    }
    load()
  }, [router])

  async function handleSaveAvatar() {
    setSavingAvatar(true)
    const supabase = createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return
    await supabase.from('profiles').update({ avatar }).eq('id', user.id)
    setAvatarSaved(true)
    setTimeout(() => setAvatarSaved(false), 2500)
    setSavingAvatar(false)
  }

  async function handleSave(e: React.FormEvent) {
    e.preventDefault()
    setSaving(true)
    setError('')
    const supabase = createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return
    const { error: err } = await supabase.from('profiles').update({
      first_name: form.first_name,
      last_name: form.last_name,
      nickname: form.nickname,
      city: form.city,
    }).eq('id', user.id)
    if (err) setError('Greška pri čuvanju. Pokušaj ponovo.')
    else { setSaved(true); setTimeout(() => setSaved(false), 2500) }
    setSaving(false)
  }

  async function handleResetPassword() {
    setSendingReset(true)
    const supabase = createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (user?.email) {
      const { sendCustomPasswordResetEmail } = await import('@/lib/password-reset')
      await sendCustomPasswordResetEmail(user.email)
      setEmailSent(true)
    }
    setSendingReset(false)
  }

  async function handleDeleteAccount() {
    if (deleteConfirmText !== 'OBRISI') return
    setDeleting(true)
    const supabase = createClient()
    await supabase.auth.signOut()
    router.push('/')
  }

  if (loading) {
    return (
      <div className="min-h-screen" style={{ background: '#FAFAFA' }}>
        <Header />
        <div className="flex items-center justify-center py-32">
          <div className="w-8 h-8 rounded-full border-2 animate-spin"
            style={{ borderColor: '#609DED', borderTopColor: 'transparent' }} />
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen" style={{ background: '#FAFAFA' }}>
      <Header />
      <main className="max-w-2xl mx-auto px-4 sm:px-6 py-10 sm:py-14">

        <Link href="/profil"
          className="inline-flex items-center gap-1.5 text-[13px] font-medium mb-6 transition-opacity hover:opacity-70"
          style={{ color: '#609DED' }}>
          <IconBack size={16} strokeWidth={2.2} />
          Profil
        </Link>

        <h1 className="font-black tracking-tight mb-8 leading-[1.1]" style={{ color: '#343434', fontSize: 'clamp(28px, 5vw, 40px)' }}>
          Podešavanja
        </h1>

        {/* ─ Avatar picker ───────────────────────────────────────── */}
        <section className="card-soft p-6 sm:p-7 mb-4">
          <h2 className="font-bold text-[16px] mb-4 tracking-tight" style={{ color: '#343434' }}>Avatar</h2>
          <div className="flex items-center gap-4 mb-5">
            <div className="w-16 h-16 rounded-2xl overflow-hidden flex-shrink-0 ring-4" style={{ ['--tw-ring-color' as string]: '#609DED' }}>
              <Image src={`/avatars/${avatar}`} alt="Trenutni avatar" width={64} height={64} className="w-full h-full object-cover" />
            </div>
            <div>
              <p className="font-semibold text-[14px]" style={{ color: '#343434' }}>Tvoj trenutni avatar</p>
              <p className="text-[12px]" style={{ color: '#9C9C9C' }}>Odaberi novi iz liste ispod</p>
            </div>
          </div>
          <div className="grid grid-cols-6 sm:grid-cols-9 gap-2 mb-5">
            {AVATAR_LIST.map(av => (
              <button key={av} onClick={() => setAvatar(av)}
                className="relative rounded-2xl overflow-hidden aspect-square transition-all hover:scale-110"
                style={{
                  outline: avatar === av ? '3px solid #609DED' : '2px solid transparent',
                  outlineOffset: 2,
                }}>
                <Image src={`/avatars/${av}`} alt={av} width={56} height={56} className="w-full h-full object-cover" />
                {avatar === av && (
                  <div className="absolute inset-0 flex items-center justify-center" style={{ background: 'rgba(96,157,237,0.35)' }}>
                    <span className="text-white text-xs font-black">✓</span>
                  </div>
                )}
              </button>
            ))}
          </div>
          <button onClick={handleSaveAvatar} disabled={savingAvatar}
            className="btn btn-md w-full"
            style={avatarSaved
              ? { background: '#4CAF50', color: 'white', boxShadow: '0 4px 14px rgba(76,175,80,0.35)' }
              : { background: '#609DED', color: 'white', boxShadow: '0 4px 14px rgba(96,157,237,0.30)' }
            }>
            {avatarSaved ? '✓ Avatar sačuvan' : savingAvatar ? 'Čuvanje…' : 'Sačuvaj avatar'}
          </button>
        </section>

        {/* ─ Personal info ───────────────────────────────────────── */}
        <section className="card-soft p-6 sm:p-7 mb-4">
          <h2 className="font-bold text-[16px] mb-5 tracking-tight" style={{ color: '#343434' }}>Lični podaci</h2>
          <form onSubmit={handleSave} className="space-y-3.5">
            <div className="grid grid-cols-2 gap-3">
              <input value={form.first_name} onChange={e => setForm(f => ({ ...f, first_name: e.target.value }))}
                className="input" placeholder="Ime" />
              <input value={form.last_name} onChange={e => setForm(f => ({ ...f, last_name: e.target.value }))}
                className="input" placeholder="Prezime" />
            </div>
            <div>
              <input value={form.nickname} onChange={e => setForm(f => ({ ...f, nickname: e.target.value }))}
                className="input" placeholder="Nadimak (na rang listi)" />
              <p className="text-[11px] mt-1.5 ml-1" style={{ color: '#9C9C9C' }}>Prikazuje se umesto imena na rang listi</p>
            </div>
            <input value={form.city} onChange={e => setForm(f => ({ ...f, city: e.target.value }))}
              className="input" placeholder="Grad" />

            {error && (
              <div className="rounded-2xl px-4 py-3 text-[13px] font-medium" style={{ background: '#FEE2E2', color: '#b91c1c' }}>
                {error}
              </div>
            )}

            <button type="submit" disabled={saving}
              className="btn btn-md w-full"
              style={saved
                ? { background: '#4CAF50', color: 'white', boxShadow: '0 4px 14px rgba(76,175,80,0.35)' }
                : { background: '#609DED', color: 'white', boxShadow: '0 4px 14px rgba(96,157,237,0.30)' }
              }>
              {saved ? '✓ Sačuvano' : saving ? 'Čuvanje…' : 'Sačuvaj izmene'}
            </button>
          </form>
        </section>

        {/* ─ Reset password ──────────────────────────────────────── */}
        <section className="card-soft p-6 sm:p-7 mb-4">
          <h2 className="font-bold text-[16px] mb-1 tracking-tight" style={{ color: '#343434' }}>Lozinka</h2>
          <p className="text-[13px] mb-5" style={{ color: '#9C9C9C' }}>Poslaćemo ti link za novu lozinku na email.</p>
          {emailSent ? (
            <div className="rounded-2xl px-4 py-3 text-[13px] font-medium flex items-center gap-2"
              style={{ background: '#E8F8F0', color: '#15803d' }}>
              <IconCheck size={16} className="text-[#15803d]" />
              Email je poslat — proveri inbox (i spam).
            </div>
          ) : (
            <button onClick={handleResetPassword} disabled={sendingReset}
              className="btn btn-secondary btn-md w-full">
              <IconLock size={16} strokeWidth={2.2} />
              {sendingReset ? 'Slanje…' : 'Pošalji link za novu lozinku'}
            </button>
          )}
        </section>

        {/* ─ Delete account ──────────────────────────────────────── */}
        <section className="card-flat p-6 sm:p-7" style={{ borderColor: 'rgba(229,83,83,0.15)' }}>
          <h2 className="font-bold text-[16px] mb-1 tracking-tight" style={{ color: '#E55353' }}>Brisanje naloga</h2>
          <p className="text-[13px] mb-5" style={{ color: '#9C9C9C' }}>
            Ova akcija je nepovratna. Svi tvoji podaci i rezultati biće trajno obrisani.
          </p>
          {!showDeleteConfirm ? (
            <button onClick={() => setShowDeleteConfirm(true)}
              className="btn btn-md w-full"
              style={{ border: '1.5px solid rgba(229,83,83,0.30)', color: '#E55353', background: 'transparent' }}>
              Obriši nalog
            </button>
          ) : (
            <div className="space-y-3">
              <p className="text-[13px] font-medium" style={{ color: '#343434' }}>
                Ukucaj <span className="font-black" style={{ color: '#E55353' }}>OBRISI</span> da potvrdiš:
              </p>
              <input value={deleteConfirmText} onChange={e => setDeleteConfirmText(e.target.value)}
                className="input" placeholder="OBRISI"
                style={{ borderColor: 'rgba(229,83,83,0.30)' }} />
              <div className="flex gap-3">
                <button onClick={() => { setShowDeleteConfirm(false); setDeleteConfirmText('') }}
                  className="btn btn-secondary btn-md flex-1">
                  Odustani
                </button>
                <button onClick={handleDeleteAccount} disabled={deleteConfirmText !== 'OBRISI' || deleting}
                  className="btn btn-md flex-1"
                  style={{ background: '#E55353', color: 'white', boxShadow: '0 4px 14px rgba(229,83,83,0.30)' }}>
                  {deleting ? 'Brisanje…' : 'Trajno obriši'}
                </button>
              </div>
            </div>
          )}
        </section>
      </main>
    </div>
  )
}
