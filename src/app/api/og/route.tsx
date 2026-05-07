import { ImageResponse } from 'next/og'

export const runtime = 'edge'

// 1200×628 share card. Full-bleed gradient using the brand palette,
// wordmark + tagline + URL strip. No mascots, no decorative characters.
export async function GET() {
  return new ImageResponse(
    (
      <div
        style={{
          width: '1200px',
          height: '628px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          position: 'relative',
          // Bold diagonal gradient blending the four brand pastels
          background: 'linear-gradient(135deg, #BCD9FF 0%, #E8F8F0 35%, #FFECBC 70%, #FFCB46 100%)',
          fontFamily: 'system-ui, -apple-system, sans-serif',
          overflow: 'hidden',
        }}
      >
        {/* Soft white veil to keep text legible over the gradient */}
        <div style={{
          position: 'absolute', inset: 0,
          background: 'radial-gradient(ellipse at center, rgba(252,252,252,0.55) 0%, rgba(252,252,252,0) 70%)',
          display: 'flex',
        }} />

        {/* Centered content */}
        <div style={{
          position: 'relative',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          textAlign: 'center',
          padding: '0 80px',
          zIndex: 2,
        }}>
          {/* Brand logo (Librum club) */}
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src="https://kviz.librum.club/og-logo.png"
            alt="Librum club"
            width={420}
            height={120}
            style={{ marginBottom: 56, objectFit: 'contain' }}
          />

          {/* Headline */}
          <div style={{
            color: '#343434',
            fontSize: 84,
            fontWeight: 900,
            letterSpacing: -3,
            lineHeight: 1.05,
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
          }}>
            <span>Usudi se da budeš</span>
            <span style={{ color: '#609DED' }}>bolji od drugih.</span>
          </div>

          {/* Sub */}
          <div style={{
            color: '#343434',
            fontSize: 26,
            fontWeight: 600,
            marginTop: 36,
            letterSpacing: -0.3,
            display: 'flex',
            opacity: 0.7,
          }}>
            10 života. Hiljade pitanja. Jedna rang lista.
          </div>
        </div>

        {/* Bottom URL strip */}
        <div style={{
          position: 'absolute',
          bottom: 36,
          left: 0,
          right: 0,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 10,
        }}>
          <div style={{ width: 8, height: 8, borderRadius: 4, background: '#FFCB46', display: 'flex' }} />
          <span style={{
            color: '#343434',
            fontSize: 20,
            fontWeight: 700,
            letterSpacing: 3,
            textTransform: 'uppercase',
          }}>
            kviz.librum.club
          </span>
        </div>
      </div>
    ),
    {
      width: 1200,
      height: 628,
      // The URL is versioned (?v=N) so the rendered bytes never change for a
      // given URL — cache aggressively at every layer (browser, CDN, social
      // platform crawlers). Bump the ?v= param in metadata when the design
      // changes; that's the cache bust.
      headers: {
        'Cache-Control': 'public, max-age=31536000, s-maxage=31536000, immutable',
      },
    }
  )
}
