import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import AdminShell from './AdminShell'

export const dynamic = 'force-dynamic'

export default async function MajmunLayout({ children }: { children: React.ReactNode }) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/auth/prijava?redirect=/majmun')

  const { data: profile } = await supabase
    .from('profiles')
    .select('id, first_name, last_name, nickname, avatar, role')
    .eq('id', user.id)
    .single()

  if (!profile || !['urednik', 'moderator', 'super_admin'].includes(profile.role)) {
    redirect('/')
  }

  return <AdminShell profile={profile}>{children}</AdminShell>
}
