import { createClient } from '@/lib/supabase/server'
import ZajednicaList, { type RedPrijave } from './ZajednicaList'

export const dynamic = 'force-dynamic'

/** Moderacija društvene mreže iz aplikacije (objave i komentari): RPC admin_prijave_sadrzaja traži is_admin_user(). */
export default async function ZajednicaPage() {
  const supabase = await createClient()
  const { data, error } = await supabase.rpc('admin_prijave_sadrzaja')
  const redovi = (data ?? []) as RedPrijave[]
  const sakrivenih = redovi.filter(r => r.sakriveno).length

  return (
    <div className="space-y-5">
      <div>
        <h1 className="font-black tracking-tight" style={{ color: '#151515', fontSize: 'clamp(22px, 4vw, 28px)' }}>
          Prijave iz zajednice
        </h1>
        <p className="text-[13px] mt-1" style={{ color: '#6F6C66' }}>
          {redovi.length} prijavljeno · {sakrivenih} sakriveno (tri prijave sakrivaju odmah) · pregled u roku od 24 h
        </p>
      </div>
      {error ? (
        <div className="card-soft p-5 text-[14px]" style={{ color: '#C8102E' }}>Prijave nisu učitane: {error.message}</div>
      ) : (
        <ZajednicaList redovi={redovi} />
      )}
    </div>
  )
}
