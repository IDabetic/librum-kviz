import { createClient } from '@/lib/supabase/server'
import SettingsForm from './SettingsForm'
import PredloziPodesavanja, { type Vrednosti } from './PredloziPodesavanja'

export const dynamic = 'force-dynamic'

export default async function AdminSettingsPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  const { data: profile } = await supabase
    .from('profiles')
    .select('id, first_name, last_name, nickname, city, avatar, role, email')
    .eq('id', user!.id)
    .single()

  // admin_settings je po RLS-u dostupan samo super_admin nalogu, pa se
  // kartica i ne prikazuje ostalima: inače bi videli polja koja ne mogu
  // da sačuvaju.
  const superAdmin = profile?.role === 'super_admin'
  const { data: podesavanja } = superAdmin
    ? await supabase.from('admin_settings').select('key, value')
    : { data: [] as { key: string; value: string }[] }
  const pocetne: Vrednosti = Object.fromEntries((podesavanja ?? []).map(r => [r.key, r.value]))

  return (
    <div className="max-w-2xl space-y-5">
      <div>
        <h1 className="font-black tracking-tight" style={{ color: '#1A1A1E', fontSize: 'clamp(22px, 4vw, 28px)' }}>
          Podešavanja administratora
        </h1>
        <p className="text-[13px] mt-1" style={{ color: '#6B6760' }}>
          Tvoj profil i lozinka.
        </p>
      </div>

      <SettingsForm profile={profile!} email={user!.email || ''} />

      {superAdmin && <PredloziPodesavanja pocetne={pocetne} />}
    </div>
  )
}
