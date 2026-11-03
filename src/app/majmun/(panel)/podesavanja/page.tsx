import { createClient } from '@/lib/supabase/server'
import SettingsForm from './SettingsForm'
import MesanjeOdgovora from './MesanjeOdgovora'

export const dynamic = 'force-dynamic'

export default async function AdminSettingsPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  const { data: profile } = await supabase
    .from('profiles')
    .select('id, first_name, last_name, nickname, city, avatar, role, email')
    .eq('id', user!.id)
    .single()
  const { data: mesanje } = await supabase.rpc('admin_poslednje_mesanje')
  const poslednjeMesanje = (mesanje as { kad: string; pitanja: number }[] | null)?.[0] ?? null

  return (
    <div className="max-w-2xl space-y-5">
      <div>
        <h1 className="font-black tracking-tight" style={{ color: '#343434', fontSize: 'clamp(22px, 4vw, 28px)' }}>
          Podešavanja administratora
        </h1>
        <p className="text-[13px] mt-1" style={{ color: '#9C9C9C' }}>
          Tvoj profil i lozinka.
        </p>
      </div>

      <SettingsForm profile={profile!} email={user!.email || ''} />

      <MesanjeOdgovora poslednje={poslednjeMesanje} />
    </div>
  )
}
