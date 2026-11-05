import type { Metadata } from 'next'
import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import AdminShell from './AdminShell'
import { ADMIN_ULOGE, jeDvostrukoPotvrdjen } from '@/lib/admin-pristup'

export const dynamic = 'force-dynamic'

export const metadata: Metadata = {
  title: 'Admin panel',
  robots: { index: false, follow: false, nocache: true },
}

export default async function PanelLayout({ children }: { children: React.ReactNode }) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/auth/prijava?redirect=/majmun')

  const { data: profile } = await supabase
    .from('profiles')
    .select('id, first_name, last_name, nickname, avatar, role')
    .eq('id', user.id)
    .single()

  if (!profile || !(ADMIN_ULOGE as readonly string[]).includes(profile.role)) {
    redirect('/')
  }
  // Bez koda iz aplikacije za autentifikaciju nema panela (uvođenje ili unos koda je na /majmun/zastita).
  if (!(await jeDvostrukoPotvrdjen(supabase))) redirect('/majmun/zastita')

  return <AdminShell profile={profile}>{children}</AdminShell>
}
