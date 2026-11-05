import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Dodaj pitanja u Librum kviz',
  description: 'Prijavljeni korisnici mogu da dodaju pitanja i odgovore u Librum kviz — jedno po jedno ili grupno preko XML šablona, za PRO kviz, Book kviz ili Kafanski kviz.',
  alternates: { canonical: '/dodaj-pitanja' },
  openGraph: {
    title: 'Dodaj pitanja | Librum Kviz',
    description: 'Pošalji svoja pitanja sa ponuđenim odgovorima, pojedinačno ili XML fajlom.',
    url: 'https://kviz.librum.club/dodaj-pitanja',
    type: 'website',
    images: ['/og-share.jpg?v=6'],
  },
}

export default function Layout({ children }: { children: React.ReactNode }) {
  return children
}
