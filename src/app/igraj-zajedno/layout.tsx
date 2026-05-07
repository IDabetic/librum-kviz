import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Trivia duel – izazovi prijatelja u kvizu znanja',
  description: 'Pokreni trivia duel, izazovi prijatelja i odmeri znanje kroz brzu kviz partiju. Igrajte ista pitanja i proverite ko ima bolji rezultat.',
  alternates: { canonical: '/igraj-zajedno' },
  openGraph: {
    title: 'Trivia duel – odmeri znanje sa protivnikom | Librum Kviz',
    description: 'Igra za dva igrača, ista pitanja, brzi rezultat.',
    url: 'https://kviz.librum.club/igraj-zajedno',
    type: 'website',
    images: ['/api/og?v=3'],
  },
}

export default function Layout({ children }: { children: React.ReactNode }) {
  return children
}
