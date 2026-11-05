import type { Metadata } from 'next'
import PravniDokument from '@/components/PravniDokument'

export const metadata: Metadata = {
  title: 'Licence i izvori',
  description: 'Ilustracije, muzika, fontovi i slike drugih autora u Librum kvizu i licence pod kojima se koriste.',
  alternates: { canonical: '/licence-i-izvori' },
}

export default function LicenceIIzvori() {
  return <PravniDokument vrsta="licence" />
}
