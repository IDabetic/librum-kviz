import type { Metadata } from 'next'
import PravniDokument from '@/components/PravniDokument'

export const metadata: Metadata = {
  title: 'Uslovi korišćenja',
  description: 'Uslovi korišćenja aplikacije Librum kviz i sajta kviz.librum.club, uključujući pravila zajednice.',
  alternates: { canonical: '/uslovi-koriscenja' },
}

export default function UsloviKoriscenja() {
  return <PravniDokument vrsta="uslovi" />
}
