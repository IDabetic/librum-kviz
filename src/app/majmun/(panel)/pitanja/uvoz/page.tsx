import Link from 'next/link'
import { IconBack } from '@/components/icons'
import UvozTools from './UvozTools'

export const dynamic = 'force-dynamic'

export default function UvozPitanjaPage() {
  return (
    <div className="max-w-2xl space-y-5">
      <Link href="/majmun/pitanja"
        className="inline-flex items-center gap-1.5 text-[13px] font-medium transition-opacity hover:opacity-70"
        style={{ color: '#12907E' }}>
        <IconBack size={16} strokeWidth={2.2} /> Sva pitanja
      </Link>

      <div>
        <h1 className="font-black tracking-tight" style={{ color: '#151515', fontSize: 'clamp(22px, 4vw, 28px)' }}>
          📥 Uvoz pitanja
        </h1>
        <p className="text-[13px] mt-1" style={{ color: '#6F6C66' }}>
          Masovni unos pitanja iz Excel-a u zajednički <strong>questions</strong> pool koji
          koriste PRO kviz, Brzi kviz i Trivia duel.
          Za mešanje koristi posebnu stranicu{' '}
          <Link href="/majmun/pitanja/mesanje" className="underline" style={{ color: '#12907E' }}>🔀 Mešanje</Link>.
        </p>
      </div>

      <UvozTools />
    </div>
  )
}
