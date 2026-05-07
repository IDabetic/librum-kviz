import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Predloži pitanje za Librum kviz',
  description: 'Predloži pitanje za Librum kviz i pomozi nam da napravimo bolju bazu pitanja iz književnosti, istorije, geografije, sporta, kulture i drugih oblasti.',
  alternates: { canonical: '/predlozi-pitanje' },
  openGraph: {
    title: 'Predloži pitanje | Librum Kviz',
    description: 'Tvoj predlog može postati deo kviza.',
    url: 'https://kviz.librum.club/predlozi-pitanje',
    type: 'website',
  },
}

export default function Layout({ children }: { children: React.ReactNode }) {
  return children
}
