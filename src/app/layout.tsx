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
// Title kept under ~580px and with no repeated word ("kviz" once, as
// the brand). Description trimmed to ~150 chars so it doesn't get cut
// in SERPs (Seobility flagged the old one as 199px over the limit).
const DEFAULT_TITLE = 'Librum kviz – besplatne online igre znanja na srpskom'
const DEFAULT_DESC = 'Besplatne igre znanja na srpskom: PRO i kafanski kviz, trivia duel, vešanje i brzi kviz. Hiljade pitanja — igraj sam ili sa prijateljima.'

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: {
    default: DEFAULT_TITLE,
    template: '%s | Librum Kviz',
  },
  description: DEFAULT_DESC,
  applicationName: SITE_NAME,
  keywords: [
    // Brand + core
    'Librum kviz', 'Librum', 'online kviz', 'kviz online', 'besplatan online kviz',
    'kviz znanja', 'igre znanja', 'kvizoman', 'pub kviz', 'trivia kviz',
    // Modes
    'PRO kviz', 'survival kviz', 'kviz sa životima', 'najteži kviz znanja',
    'kviz opšteg znanja', 'online kviz znanja', 'kviz sa rang-listom', 'kviz izazov',
    'Book kviz', 'književni kviz', 'kviz iz književnosti', 'književnost kviz',
    'kviz o knjigama', 'kviz o piscima', 'kviz o žanrovima', 'kviz za čitaoce',
    'kafanski kviz', 'pub quiz Srbija', 'kviz za društvo', 'kviz za kafanu',
    'muzički kviz', 'kviz o muzici', 'domaća muzika kviz', 'ex yu muzika kviz',
    'pitanja za pub kviz', 'brzi kviz', 'kviz 60 sekundi', 'tačno netačno kviz',
    'trivia duel', 'duel kviz', 'kviz protiv prijatelja', 'multiplayer kviz',
    'kviz za dvoje', 'kviz takmičenje online',
    'igra vešanja', 'vešanje online', 'pogađanje reči', 'igra pogađanja reči',
    'online igra vešanja', 'igra reči online',
    // Locale + intent
    'kviz Srbija', 'kviz na srpskom', 'kviz pitanja', 'kviz pitanja i odgovori',
    'kviz za zabavu', 'kviz za telefon', 'kviz za odrasle',
    'edukativne igre online', 'igre za mozak', 'igre znanja online',
    'besplatne igre znanja', 'kviz opšte kulture',
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
    images: [{ url: '/og-share.jpg?v=6', width: 1200, height: 628, alt: 'Librum Kviz', type: 'image/jpeg' }],
    locale: 'sr_RS',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: DEFAULT_TITLE,
    description: DEFAULT_DESC,
    images: ['/og-share.jpg?v=6'],
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
  icons: {
    icon: '/icon',
    // Seobility flagged the missing Apple touch icon. Reuse the
    // square logo asset — iOS scales it for the home-screen shortcut.
    apple: '/og-logo.png',
  },
  appleWebApp: {
    capable: true,
    title: 'Librum kviz',
    statusBarStyle: 'default',
  },
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
