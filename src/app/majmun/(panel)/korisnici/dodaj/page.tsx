import Link from 'next/link'
import { IconBack } from '@/components/icons'
import AddAdminForm from './AddAdminForm'

export const dynamic = 'force-dynamic'

export default function DodajAdminaPage() {
  return (
    <div className="max-w-2xl space-y-5">
      <Link href="/majmun/korisnici"
        className="inline-flex items-center gap-1.5 text-[13px] font-medium transition-opacity hover:opacity-70"
        style={{ color: '#3A36A0' }}>
        <IconBack size={16} strokeWidth={2.2} /> Korisnici
      </Link>

      <div>
        <h1 className="font-black tracking-tight" style={{ color: '#1A1A1E', fontSize: 'clamp(22px, 4vw, 28px)' }}>
          Dodaj administratora
        </h1>
        <p className="text-[13px] mt-1" style={{ color: '#6B6760' }}>
          Korisnik mora već biti registrovan na sajtu. Upiši njegov email i postavi mu novu ulogu.
        </p>
      </div>

      <AddAdminForm />
    </div>
  )
}
