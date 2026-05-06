import type { Metadata } from 'next'
import { Poppins } from 'next/font/google'
import Script from 'next/script'
import './globals.css'

const poppins = Poppins({
  subsets: ['latin', 'latin-ext'],
  weight: ['100', '200', '300', '400', '500', '600', '700', '800', '900'],
  variable: '--font-poppins',
  display: 'swap',
})

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
    <html lang="sr" className={`${poppins.variable} h-full`}>
      <body className="min-h-full antialiased font-sans">
        {children}
        <Script
          src="https://www.googletagmanager.com/gtag/js?id=G-LS594VEPZ3"
          strategy="afterInteractive"
        />
        <Script id="google-analytics" strategy="afterInteractive">
          {`
            window.dataLayer = window.dataLayer || [];
            function gtag(){dataLayer.push(arguments);}
            gtag('js', new Date());
            gtag('config', 'G-LS594VEPZ3');
          `}
        </Script>
      </body>
    </html>
  )
}
