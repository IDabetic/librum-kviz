import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  images: {
    // Avatars + game art are local; OG image is dynamic. We don't pull
    // images from third parties, so no remote pattern allowlist needed.
    formats: ['image/avif', 'image/webp'],
  },
  // Tree-shake heavy packages so we ship less JS to the client.
  experimental: {
    optimizePackageImports: ['@supabase/supabase-js', '@supabase/ssr'],
  },
  // Static assets get long-lived caching; HTML pages stay dynamic via
  // the per-route `dynamic = 'force-dynamic'` flag.
  async headers() {
    return [
      {
        source: '/avatars/:path*',
        headers: [{ key: 'Cache-Control', value: 'public, max-age=31536000, immutable' }],
      },
      {
        source: '/og-logo.png',
        headers: [{ key: 'Cache-Control', value: 'public, max-age=31536000, immutable' }],
      },
      {
        // The static share card. URL is versioned (?v=N) in metadata, so
        // immutable cache is safe — bump the param when you re-render.
        source: '/og-share.jpg',
        headers: [{ key: 'Cache-Control', value: 'public, max-age=31536000, immutable' }],
      },
      {
        source: '/api/og',
        headers: [{ key: 'Cache-Control', value: 'public, max-age=86400, s-maxage=604800' }],
      },
    ]
  },
}

export default nextConfig
