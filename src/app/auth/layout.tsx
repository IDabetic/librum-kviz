import type { Metadata } from 'next'

// Auth pages — not indexable
export const metadata: Metadata = {
  title: 'Prijava',
  robots: { index: false, follow: false, nocache: true },
}

export default function Layout({ children }: { children: React.ReactNode }) {
  return children
}
