import type { Metadata } from 'next'
import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { ADMIN_ULOGE, jeDvostrukoPotvrdjen } from '@/lib/admin-pristup'
import DvostrukaProvera from './DvostrukaProvera'

export const dynamic = 'force-dynamic'

export const metadata: Metadata = {
  title: 'Zaštita admina',
  robots: { index: false, follow: false, nocache: true },
}

/** Ulaz u admin posle obične prijave: kod iz aplikacije za autentifikaciju (ili prvo uvođenje). Van (panel) da ne bi bilo kruga. */
export default async function ZastitaAdmina() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/auth/prijava?redirect=/majmun')

  const { data: profil } = await supabase.from('profiles').select('role').eq('id', user.id).single()
  if (!profil || !(ADMIN_ULOGE as readonly string[]).includes(profil.role)) redirect('/')
  if (await jeDvostrukoPotvrdjen(supabase)) redirect('/majmun')

  const { data: faktori } = await supabase.auth.mfa.listFactors()
  const potvrdjen = faktori?.totp?.find(f => f.status === 'verified') ?? null

  return (
    <main className="min-h-screen grid place-items-center px-4 py-10" style={{ background: '#F3F0E6' }}>
      <DvostrukaProvera faktorId={potvrdjen?.id ?? null} />
    </main>
  )
}
