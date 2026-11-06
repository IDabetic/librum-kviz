import { createClient } from '@/lib/supabase/server'
import ObavestenjaUredjivanje, { type Obavestenje } from './ObavestenjaUredjivanje'

export const dynamic = 'force-dynamic'

/** Obaveštenja koja admin šalje u aplikaciju: kartica na početnoj i, po želji, push na telefone. */
export default async function ObavestenjaPage() {
  const supabase = await createClient()
  const { data, error } = await supabase.rpc('admin_obavestenja')
  return (
    <div className="max-w-3xl space-y-5">
      <div>
        <h1 className="font-black tracking-tight" style={{ color: '#151515', fontSize: 'clamp(22px, 4vw, 28px)' }}>Obaveštenja u aplikaciji</h1>
        <p className="text-[13px] mt-1" style={{ color: '#6F6C66' }}>
          Uključeno obaveštenje se prikazuje kao kartica na početnoj strani aplikacije (igrač je zatvara jednom).
          „Pošalji na telefone” isti tekst šalje kao push svima koji su dozvolili obaveštenja, jednom po obaveštenju.
        </p>
      </div>
      {error
        ? <div className="card-soft p-5 text-[14px]" style={{ color: '#C42B4F' }}>Obaveštenja se nisu učitala: {error.message}</div>
        : <ObavestenjaUredjivanje lista={(data ?? []) as Obavestenje[]} />}
    </div>
  )
}
