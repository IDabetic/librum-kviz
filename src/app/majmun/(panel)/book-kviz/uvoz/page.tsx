import Link from 'next/link'
import { IconBack } from '@/components/icons'
import UvozTools from '../../pitanja/uvoz/UvozTools'

export const dynamic = 'force-dynamic'

export default function BookUvozPage() {
  return (
    <div className="max-w-2xl space-y-5">
      <Link href="/majmun/book-kviz"
        className="inline-flex items-center gap-1.5 text-[13px] font-medium transition-opacity hover:opacity-70"
        style={{ color: '#3A36A0' }}>
        <IconBack size={16} strokeWidth={2.2} /> Sva Book pitanja
      </Link>

      <div>
        <h1 className="font-black tracking-tight" style={{ color: '#1A1A1E', fontSize: 'clamp(22px, 4vw, 28px)' }}>
          📥 Uvoz Book pitanja
        </h1>
        <p className="text-[13px] mt-1" style={{ color: '#6B6760' }}>
          Masovni unos pitanja iz Excel-a u <strong>book_questions</strong> (Book kviz).
          Kolona <strong>Žanr</strong> je obavezna. Za mešanje koristi{' '}
          <Link href="/majmun/book-kviz/mesanje" className="underline" style={{ color: '#3A36A0' }}>🔀 Mešanje</Link>.
        </p>
      </div>

      <UvozTools pool="book" />
    </div>
  )
}
