'use client'

export const dynamic = 'force-dynamic'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import { createClient } from '@/lib/supabase/client'
import Header from '@/components/Header'

export default function PodesavanjaPage() {
  const router = useRouter()

  const [form, setForm] = useState({ first_name: '', last_name: '', nickname: '', city: '' })
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
      }
      setLoading(false)
    }
    load()
  }, [])

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
      await supabase.auth.resetPasswordForEmail(user.email, {
        redirectTo: `${window.location.origin}/auth/nova-lozinka`,
      })
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
      <div className="min-h-screen bg-[#FAF4EC]">
        <Header />
        <div className="flex items-center justify-center py-32">
          <div className="w-8 h-8 rounded-full border-2 border-[#2C2D81] border-t-transparent animate-spin" />
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-[#FAF4EC]">
      <Header />
      <main className="max-w-2xl mx-auto px-4 py-10">

        <div className="flex items-center gap-3 mb-8">
          <Link href="/profil" className="w-9 h-9 rounded-xl flex items-center justify-center hover:bg-gray-200 transition-colors"
            style={{ background: 'rgba(44,45,129,0.08)' }}>
            <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="#2C2D81" strokeWidth="2" strokeLinecap="round">
              <polyline points="10,4 6,8 10,12" />
            </svg>
          </Link>
          <h1 className="text-2xl font-bold" style={{ color: '#2C2D81' }}>Podešavanja profila</h1>
        </div>

        {/* Edit profile */}
        <div className="bg-white rounded-2xl p-6 shadow-sm mb-4">
          <h2 className="font-bold text-gray-800 mb-5">Lični podaci</h2>
          <form onSubmit={handleSave} className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-semibold text-gray-500 mb-1.5">Ime</label>
                <input value={form.first_name} onChange={e => setForm(f => ({ ...f, first_name: e.target.value }))}
                  className="w-full px-4 py-2.5 rounded-xl border-2 border-gray-100 focus:border-[#2C2D81] outline-none text-sm font-medium transition-colors"
                  placeholder="Ime" />
              </div>
              <div>
                <label className="block text-xs font-semibold text-gray-500 mb-1.5">Prezime</label>
                <input value={form.last_name} onChange={e => setForm(f => ({ ...f, last_name: e.target.value }))}
                  className="w-full px-4 py-2.5 rounded-xl border-2 border-gray-100 focus:border-[#2C2D81] outline-none text-sm font-medium transition-colors"
                  placeholder="Prezime" />
              </div>
            </div>
            <div>
              <label className="block text-xs font-semibold text-gray-500 mb-1.5">
                Nadimak <span className="font-normal text-gray-400">(prikazuje se na rang listi)</span>
              </label>
              <input value={form.nickname} onChange={e => setForm(f => ({ ...f, nickname: e.target.value }))}
                className="w-full px-4 py-2.5 rounded-xl border-2 border-gray-100 focus:border-[#2C2D81] outline-none text-sm font-medium transition-colors"
                placeholder="npr. KnjigaLover23" />
            </div>
            <div>
              <label className="block text-xs font-semibold text-gray-500 mb-1.5">Grad</label>
              <input value={form.city} onChange={e => setForm(f => ({ ...f, city: e.target.value }))}
                className="w-full px-4 py-2.5 rounded-xl border-2 border-gray-100 focus:border-[#2C2D81] outline-none text-sm font-medium transition-colors"
                placeholder="npr. Beograd" />
            </div>
            {error && <p className="text-sm text-red-500">{error}</p>}
            <button type="submit" disabled={saving}
              className="w-full py-3 rounded-xl font-bold text-white transition-all hover:scale-[1.01] disabled:opacity-70"
              style={{ background: saved ? '#5DBF94' : 'linear-gradient(135deg, #2C2D81, #3766B0)' }}>
              {saved ? '✓ Sačuvano!' : saving ? 'Čuvanje...' : 'Sačuvaj izmene'}
            </button>
          </form>
        </div>

        {/* Reset password */}
        <div className="bg-white rounded-2xl p-6 shadow-sm mb-4">
          <h2 className="font-bold text-gray-800 mb-1">Lozinka</h2>
          <p className="text-sm text-gray-400 mb-5">Poslaćemo ti link za resetovanje lozinke na email.</p>
          {emailSent ? (
            <div className="py-3 px-4 rounded-xl text-sm font-medium" style={{ background: '#E8F8F0', color: '#0A4C35' }}>
              ✓ Email je poslat! Proveri inbox (i spam).
            </div>
          ) : (
            <button onClick={handleResetPassword} disabled={sendingReset}
              className="w-full py-3 rounded-xl font-semibold text-sm border-2 border-gray-100 hover:border-[#2C2D81] hover:text-[#2C2D81] transition-colors disabled:opacity-50"
              style={{ color: '#6b7280' }}>
              {sendingReset ? 'Slanje...' : '🔑 Pošalji link za novu lozinku'}
            </button>
          )}
        </div>

        {/* Delete account */}
        <div className="bg-white rounded-2xl p-6 shadow-sm border-2 border-red-50">
          <h2 className="font-bold text-red-500 mb-1">Brisanje naloga</h2>
          <p className="text-sm text-gray-400 mb-5">
            Ova akcija je nepovratna. Svi tvoji podaci i rezultati biće trajno obrisani.
          </p>
          {!showDeleteConfirm ? (
            <button onClick={() => setShowDeleteConfirm(true)}
              className="w-full py-3 rounded-xl font-semibold text-sm border-2 border-red-200 text-red-400 hover:bg-red-50 transition-colors">
              Obriši nalog
            </button>
          ) : (
            <div className="space-y-3">
              <p className="text-sm font-medium text-gray-700">
                Ukucaj <span className="font-black text-red-500">OBRISI</span> da potvrdiš:
              </p>
              <input value={deleteConfirmText} onChange={e => setDeleteConfirmText(e.target.value)}
                className="w-full px-4 py-2.5 rounded-xl border-2 border-red-200 focus:border-red-400 outline-none text-sm font-medium"
                placeholder="OBRISI" />
              <div className="flex gap-3">
                <button onClick={() => { setShowDeleteConfirm(false); setDeleteConfirmText('') }}
                  className="flex-1 py-3 rounded-xl border-2 border-gray-200 font-semibold text-gray-600 text-sm hover:bg-gray-50">
                  Odustani
                </button>
                <button onClick={handleDeleteAccount} disabled={deleteConfirmText !== 'OBRISI' || deleting}
                  className="flex-1 py-3 rounded-xl font-bold text-white text-sm disabled:opacity-40 transition-all"
                  style={{ background: '#e05252' }}>
                  {deleting ? 'Brisanje...' : 'Trajno obriši'}
                </button>
              </div>
            </div>
          )}
        </div>
      </main>
    </div>
  )
}
