import type { Metadata } from 'next'
import { Geist } from 'next/font/google'
import './globals.css'

const geist = Geist({ subsets: ['latin'], variable: '--font-geist-sans' })

export const metadata: Metadata = {
  title: 'Librum Kviz',
  description: 'Kvizovi iz književnosti, istorije i kulture. Testiraj znanje, takmiči se sa prijateljima i penjaj se na rang listu!',
  openGraph: {
    title: 'Librum Kviz — Testiraj svoje znanje!',
    description: 'Kvizovi iz književnosti, istorije i kulture. Besplatno!',
    images: [{ url: 'https://kviz.librum.club/api/og', width: 1200, height: 628 }],
    locale: 'sr_RS',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Librum Kviz — Testiraj svoje znanje!',
    description: 'Kvizovi iz književnosti, istorije i kulture. Besplatno!',
    images: ['https://kviz.librum.club/api/og'],
  },
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="sr" className={`${geist.variable} h-full`}>
      <body className="min-h-full antialiased">{children}</body>
    </html>
  )
}
