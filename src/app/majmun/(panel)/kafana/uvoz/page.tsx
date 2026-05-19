import Link from 'next/link'
import { IconBack } from '@/components/icons'
import UvozTools from '../../pitanja/uvoz/UvozTools'

export const dynamic = 'force-dynamic'

export default function KafanaUvozPage() {
  return (
    <div className="max-w-2xl space-y-5">
      <Link href="/majmun/kafana"
        className="inline-flex items-center gap-1.5 text-[13px] font-medium transition-opacity hover:opacity-70"
        style={{ color: '#609DED' }}>
        <IconBack size={16} strokeWidth={2.2} /> Sva Kafanska pitanja
      </Link>

      <div>
        <h1 className="font-black tracking-tight" style={{ color: '#343434', fontSize: 'clamp(22px, 4vw, 28px)' }}>
          📥 Uvoz Kafanskih pitanja
        </h1>
        <p className="text-[13px] mt-1" style={{ color: '#9C9C9C' }}>
          Masovni unos pitanja iz Excel-a u <strong>kafana_questions</strong> (Kafanski kviz).
          Za mešanje koristi{' '}
          <Link href="/majmun/kafana/mesanje" className="underline" style={{ color: '#609DED' }}>🔀 Mešanje</Link>.
        </p>
      </div>

      <UvozTools pool="kafana" />
    </div>
  )
}
