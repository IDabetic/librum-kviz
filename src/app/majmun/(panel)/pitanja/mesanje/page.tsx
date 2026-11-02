import Link from 'next/link'
import { IconBack } from '@/components/icons'
import MesanjeTools from './MesanjeTools'

export const dynamic = 'force-dynamic'

export default function MesanjePitanjaPage() {
  return (
    <div className="max-w-2xl space-y-5">
      <Link href="/majmun/pitanja"
        className="inline-flex items-center gap-1.5 text-[13px] font-medium transition-opacity hover:opacity-70"
        style={{ color: '#12907E' }}>
        <IconBack size={16} strokeWidth={2.2} /> Sva pitanja
      </Link>

      <div>
        <h1 className="font-black tracking-tight" style={{ color: '#151515', fontSize: 'clamp(22px, 4vw, 28px)' }}>
          🔀 Mešanje
        </h1>
        <p className="text-[13px] mt-1" style={{ color: '#6F6C66' }}>
          Dve nezavisne opcije za <strong>questions</strong> pool (PRO kviz, Brzi kviz, Trivia duel).
          Svaka se primenjuje na sve aktivne i neaktivne redove.
        </p>
      </div>

      <MesanjeTools />
    </div>
  )
}
