import type { Metadata } from 'next'

// Private user pages — never index
export const metadata: Metadata = {
  title: 'Moj profil',
  robots: { index: false, follow: false, nocache: true },
}

export default function Layout({ children }: { children: React.ReactNode }) {
  return children
}
