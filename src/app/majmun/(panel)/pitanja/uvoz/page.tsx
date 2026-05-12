import Link from 'next/link'
import { IconBack } from '@/components/icons'
import UvozTools from './UvozTools'

export const dynamic = 'force-dynamic'

export default function UvozPitanjaPage() {
  return (
    <div className="max-w-2xl space-y-5">
      <Link href="/majmun/pitanja"
        className="inline-flex items-center gap-1.5 text-[13px] font-medium transition-opacity hover:opacity-70"
        style={{ color: '#609DED' }}>
        <IconBack size={16} strokeWidth={2.2} /> Sva pitanja
      </Link>

      <div>
        <h1 className="font-black tracking-tight" style={{ color: '#343434', fontSize: 'clamp(22px, 4vw, 28px)' }}>
          Alati za pitanja
        </h1>
        <p className="text-[13px] mt-1" style={{ color: '#9C9C9C' }}>
          Masovni unos pitanja iz Excel-a i nasumično mešanje redosleda odgovora u bazi.
          Sve se primenjuje na zajednički <strong>questions</strong> pool koji koriste PRO kviz,
          Brzi kviz i Trivia duel.
        </p>
      </div>

      <UvozTools />
    </div>
  )
}
