import { createClient } from '@/lib/supabase/server'
import SettingsForm from './SettingsForm'
import PredloziPodesavanja, { type Vrednosti } from './PredloziPodesavanja'
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

  // admin_settings je po RLS-u dostupan samo super_admin nalogu, pa se
  // kartica i ne prikazuje ostalima: inače bi videli polja koja ne mogu
  // da sačuvaju.
  const superAdmin = profile?.role === 'super_admin'
  const { data: podesavanja } = superAdmin
    ? await supabase.from('admin_settings').select('key, value')
    : { data: [] as { key: string; value: string }[] }
  const pocetne: Vrednosti = Object.fromEntries((podesavanja ?? []).map(r => [r.key, r.value]))
  const { data: mesanje } = await supabase.rpc('admin_poslednje_mesanje')
  const poslednjeMesanje = (mesanje as { kad: string; pitanja: number }[] | null)?.[0] ?? null

  return (
    <div className="max-w-2xl space-y-5">
      <div>
        <h1 className="font-black tracking-tight" style={{ color: '#151515', fontSize: 'clamp(22px, 4vw, 28px)' }}>
          Podešavanja administratora
        </h1>
        <p className="text-[13px] mt-1" style={{ color: '#6F6C66' }}>
          Tvoj profil i lozinka.
        </p>
      </div>

      <SettingsForm profile={profile!} email={user!.email || ''} />

      <MesanjeOdgovora poslednje={poslednjeMesanje} />

      {superAdmin && <PredloziPodesavanja pocetne={pocetne} />}
    </div>
  )
}
