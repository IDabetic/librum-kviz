import type { Metadata } from 'next'
import PravniDokument from '@/components/PravniDokument'

export const metadata: Metadata = {
  title: 'Politika privatnosti',
  description: 'Koje podatke Librum kviz (aplikacija i sajt) prikuplja, gde se čuvaju i kako se brišu.',
  alternates: { canonical: '/politika-privatnosti' },
}

export default function PolitikaPrivatnosti() {
  return <PravniDokument vrsta="privatnost" />
}
