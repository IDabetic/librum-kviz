import Link from 'next/link'
import { IconBack } from '@/components/icons'
import MesanjeTools from '../../pitanja/mesanje/MesanjeTools'

export const dynamic = 'force-dynamic'

export default function KafanaMesanjePage() {
  return (
    <div className="max-w-2xl space-y-5">
      <Link href="/majmun/kafana"
        className="inline-flex items-center gap-1.5 text-[13px] font-medium transition-opacity hover:opacity-70"
        style={{ color: '#609DED' }}>
        <IconBack size={16} strokeWidth={2.2} /> Sva Kafanska pitanja
      </Link>

      <div>
        <h1 className="font-black tracking-tight" style={{ color: '#343434', fontSize: 'clamp(22px, 4vw, 28px)' }}>
          🔀 Mešanje — Kafanski kviz
        </h1>
        <p className="text-[13px] mt-1" style={{ color: '#9C9C9C' }}>
          Dve nezavisne opcije za <strong>kafana_questions</strong> pool.
        </p>
      </div>

      <MesanjeTools pool="kafana" />
    </div>
  )
}
