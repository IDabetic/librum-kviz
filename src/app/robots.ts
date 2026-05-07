import type { MetadataRoute } from 'next'

const BASE = 'https://kviz.librum.club'

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      {
        userAgent: '*',
        allow: '/',
        disallow: [
          '/majmun/',
          '/majmun',
          '/auth/',
          '/api/',
          '/profil/podesavanja',
          '/igraj/start',
          '/igraj/kraj',
          '/brzi-kviz/start',
          '/vesanje/dvoje',
          '/igraj-zajedno/sobu',
        ],
      },
    ],
    sitemap: `${BASE}/sitemap.xml`,
    host: BASE,
  }
}
