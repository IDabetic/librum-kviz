import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import { cookies } from 'next/headers'
import { verifyUnlockToken } from '@/lib/admin-auth'
import AdminShell from './AdminShell'

export const dynamic = 'force-dynamic'

export default async function PanelLayout({ children }: { children: React.ReactNode }) {
  // 1. Must be authenticated
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/majmun/prijava')

  // 2. Must have admin role
  const { data: profile } = await supabase
    .from('profiles')
    .select('id, first_name, last_name, nickname, avatar, role')
    .eq('id', user.id)
    .single()

  if (!profile || !['urednik', 'moderator', 'super_admin'].includes(profile.role)) {
    redirect('/')
  }

  // 3. Must have valid unlock cookie (the second factor)
  const cookieStore = await cookies()
  const token = cookieStore.get('majmun_unlock')?.value
  const valid = token ? verifyUnlockToken(token, user.id) : false
  if (!valid) redirect('/majmun/prijava')

  return <AdminShell profile={profile}>{children}</AdminShell>
}
