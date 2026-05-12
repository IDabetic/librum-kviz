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
    // ─── Security headers ────────────────────────────────────────
    // Applied to every route. Picked conservatively so we don't
    // break Supabase (REST + realtime via wss), Google Tag Manager
    // analytics, the Next.js inline runtime, or Vercel previews.
    //
    // CSP notes:
    //  - 'self' is the deployed origin
    //  - script-src needs 'unsafe-inline' for Next bootstrap + GTM
    //  - connect-src must include *.supabase.co (REST/auth) and
    //    wss://*.supabase.co (realtime)
    //  - img-src includes data: for inline svgs we serve as data URIs
    //  - frame-ancestors 'none' is the modern equivalent of
    //    X-Frame-Options: DENY (clickjacking defense)
    const csp = [
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://www.googletagmanager.com https://www.google-analytics.com https://va.vercel-scripts.com",
      "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
      "img-src 'self' data: blob: https://*.supabase.co https://www.googletagmanager.com https://www.google-analytics.com",
      "font-src 'self' data: https://fonts.gstatic.com",
      "connect-src 'self' https://*.supabase.co wss://*.supabase.co https://www.google-analytics.com https://*.vercel-insights.com",
      "frame-ancestors 'none'",
      "base-uri 'self'",
      "form-action 'self'",
      "object-src 'none'",
      "upgrade-insecure-requests",
    ].join('; ')

    const securityHeaders = [
      { key: 'Content-Security-Policy', value: csp },
      { key: 'X-Frame-Options',         value: 'DENY' },
      { key: 'X-Content-Type-Options',  value: 'nosniff' },
      { key: 'Referrer-Policy',         value: 'strict-origin-when-cross-origin' },
      // Lock down browser feature APIs we don't use. Tightens the
      // blast radius if anything injects script.
      { key: 'Permissions-Policy',      value: 'camera=(), microphone=(), geolocation=(), interest-cohort=(), payment=(), usb=()' },
      // HSTS is already set by Vercel at the edge but doesn't hurt
      // to declare it explicitly here too.
      { key: 'Strict-Transport-Security', value: 'max-age=63072000; includeSubDomains; preload' },
    ]

    return [
      // Apply security headers to every route.
      { source: '/:path*', headers: securityHeaders },

      // Long-lived caching for static assets (specific paths win).
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
