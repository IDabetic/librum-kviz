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

const SITE_URL = 'https://kviz.librum.club'
const SITE_NAME = 'Librum Kviz'
const DEFAULT_TITLE = 'Librum kviz – besplatne igre znanja, književnosti, istorije i geografije'
const DEFAULT_DESC = 'Igraj Librum kviz besplatno. Proveri znanje iz književnosti, istorije, geografije, sporta, kulture i prirode kroz PRO kviz, trivia duel, vešanje i brzi kviz.'

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: {
    default: DEFAULT_TITLE,
    template: '%s | Librum Kviz',
  },
  description: DEFAULT_DESC,
  applicationName: SITE_NAME,
  keywords: [
    'kviz', 'kviz na srpskom', 'igre znanja', 'opšte znanje', 'književnost',
    'istorija', 'geografija', 'sport', 'kultura', 'priroda',
    'PRO kviz', 'trivia duel', 'vešanje', 'brzi kviz', 'rang lista',
    'Librum', 'Librum kviz',
  ],
  authors: [{ name: 'Librum', url: 'https://www.librum.club' }],
  publisher: 'Librum',
  alternates: { canonical: '/' },
  verification: {
    google: '50PGHmNccA_FvcvkxDlb57G1FrqBAlbZtnHSV7CnUc4',
  },
  openGraph: {
    title: DEFAULT_TITLE,
    description: DEFAULT_DESC,
    url: SITE_URL,
    siteName: SITE_NAME,
    images: [{ url: '/api/og?v=3', width: 1200, height: 628, alt: 'Librum Kviz' }],
    locale: 'sr_RS',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: DEFAULT_TITLE,
    description: DEFAULT_DESC,
    images: ['/api/og?v=3'],
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      'max-image-preview': 'large',
      'max-snippet': -1,
      'max-video-preview': -1,
    },
  },
  icons: { icon: '/icon' },
}

const websiteSchema = {
  '@context': 'https://schema.org',
  '@type': 'WebSite',
  name: SITE_NAME,
  url: SITE_URL,
  description: DEFAULT_DESC,
  inLanguage: 'sr-RS',
  publisher: {
    '@type': 'Organization',
    name: 'Librum',
    url: 'https://www.librum.club',
  },
}

const organizationSchema = {
  '@context': 'https://schema.org',
  '@type': 'Organization',
  name: 'Librum',
  url: 'https://www.librum.club',
  logo: `${SITE_URL}/icon`,
  email: 'info@librum.club',
  sameAs: ['https://www.librum.club'],
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="sr" className={`${poppins.variable} h-full`}>
      <body className="min-h-full antialiased font-sans">
        {children}
        <Script id="ld-website" type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(websiteSchema) }} />
        <Script id="ld-organization" type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(organizationSchema) }} />
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
