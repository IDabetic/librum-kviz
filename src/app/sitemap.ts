import type { MetadataRoute } from 'next'

const BASE = 'https://kviz.librum.club'

export default function sitemap(): MetadataRoute.Sitemap {
  const now = new Date()
  const pages: { path: string; priority: number; changeFrequency: 'daily' | 'weekly' | 'monthly' }[] = [
    { path: '/',                       priority: 1.0, changeFrequency: 'weekly'  },
    { path: '/igre',                   priority: 0.9, changeFrequency: 'weekly'  },
    { path: '/pro-kviz',                  priority: 0.9, changeFrequency: 'daily'   },
    { path: '/book-kviz',              priority: 0.9, changeFrequency: 'weekly'  },
    { path: '/kafanski-kviz',          priority: 0.9, changeFrequency: 'weekly'  },
    { path: '/igraj-zajedno',          priority: 0.8, changeFrequency: 'weekly'  },
    { path: '/vesanje',                priority: 0.8, changeFrequency: 'weekly'  },
    { path: '/brzi-kviz',              priority: 0.8, changeFrequency: 'weekly'  },
    { path: '/leaderboard',            priority: 0.7, changeFrequency: 'daily'   },
    { path: '/nagrade',                priority: 0.6, changeFrequency: 'monthly' },
    { path: '/predlozi-pitanje',       priority: 0.5, changeFrequency: 'monthly' },
    { path: '/politika-privatnosti',   priority: 0.3, changeFrequency: 'monthly' },
    { path: '/uslovi-koriscenja',      priority: 0.3, changeFrequency: 'monthly' },
  ]
  return pages.map(p => ({
    url: `${BASE}${p.path}`,
    lastModified: now,
    changeFrequency: p.changeFrequency,
    priority: p.priority,
  }))
}
