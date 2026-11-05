import type { MetadataRoute } from 'next'

const BASE = 'https://kviz.librum.club'

// Igre od 02.11.2026 žive samo u aplikaciji (adrese vode 307 na /), pa nisu u mapi sajta.
export default function sitemap(): MetadataRoute.Sitemap {
  const now = new Date()
  const pages: { path: string; priority: number; changeFrequency: 'daily' | 'weekly' | 'monthly' }[] = [
    { path: '/',                       priority: 1.0, changeFrequency: 'weekly'  },
    { path: '/ranglista',            priority: 0.7, changeFrequency: 'daily'   },
    { path: '/nagrade',                priority: 0.6, changeFrequency: 'monthly' },
    { path: '/dodaj-pitanja',          priority: 0.7, changeFrequency: 'weekly'  },
    { path: '/autori-pitanja',         priority: 0.5, changeFrequency: 'weekly'  },
    { path: '/politika-privatnosti',   priority: 0.3, changeFrequency: 'monthly' },
    { path: '/uslovi-koriscenja',      priority: 0.3, changeFrequency: 'monthly' },
    { path: '/licence-i-izvori',       priority: 0.2, changeFrequency: 'monthly' },
    { path: '/brisanje-naloga',        priority: 0.3, changeFrequency: 'monthly' },
  ]
  return pages.map(p => ({
    url: `${BASE}${p.path}`,
    lastModified: now,
    changeFrequency: p.changeFrequency,
    priority: p.priority,
  }))
}
