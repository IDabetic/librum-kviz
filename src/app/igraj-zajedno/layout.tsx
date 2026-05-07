import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Trivia duel – kviz protiv prijatelja, multiplayer kviz online',
  description: 'Trivia duel – online kviz protiv prijatelja u realnom vremenu. Kviz za dvoje, multiplayer kviz na srpskom. Izazovi prijatelje preko koda i odmerite znanje kroz ista pitanja u live duelu.',
  keywords: [
    'trivia duel', 'duel kviz', 'kviz protiv prijatelja',
    'online kviz sa prijateljem', 'kviz za dvoje', 'izazovi prijatelja kviz',
    'multiplayer kviz', 'kviz takmičenje online', 'online trivia igra',
    'kviz duel', 'igraj kviz protiv prijatelja', 'Librum kviz',
  ],
  alternates: { canonical: '/igraj-zajedno' },
  openGraph: {
    title: 'Trivia duel – kviz protiv prijatelja | Librum Kviz',
    description: 'Multiplayer kviz uživo. Pozovi prijatelja kodom i odmerite znanje.',
    url: 'https://kviz.librum.club/igraj-zajedno',
    type: 'website',
    images: ['/og-share.jpg?v=6'],
  },
}

export default function Layout({ children }: { children: React.ReactNode }) {
  return children
}
