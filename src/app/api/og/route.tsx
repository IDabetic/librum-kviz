import { ImageResponse } from 'next/og'

export const runtime = 'edge'

// 1200×628 pastel-minimal share card.
// "Usudi se da budeš bolji od drugih." headline, Librum club logo wordmark.
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
          background: '#FAFAFA',
          fontFamily: 'system-ui, -apple-system, sans-serif',
          overflow: 'hidden',
        }}
      >
        {/* Pastel ambient blobs */}
        <div style={{
          position: 'absolute', top: -180, right: -200, width: 600, height: 600,
          borderRadius: '50%',
          background: 'radial-gradient(circle, #BCD9FF 0%, rgba(188,217,255,0) 70%)',
          display: 'flex',
        }} />
        <div style={{
          position: 'absolute', bottom: -200, left: -200, width: 600, height: 600,
          borderRadius: '50%',
          background: 'radial-gradient(circle, #FFECBC 0%, rgba(255,236,188,0) 70%)',
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
          {/* Logo wordmark */}
          <div style={{ display: 'flex', alignItems: 'baseline', marginBottom: 60 }}>
            <span style={{
              color: '#343434',
              fontSize: 56,
              fontWeight: 900,
              letterSpacing: -2,
              lineHeight: 1,
            }}>
              Librum
            </span>
            <span style={{
              color: '#609DED',
              fontSize: 56,
              fontWeight: 900,
              lineHeight: 1,
            }}>
              .
            </span>
            <span style={{
              color: '#9C9C9C',
              fontSize: 22,
              fontWeight: 600,
              marginLeft: 14,
              letterSpacing: 4,
              textTransform: 'uppercase',
            }}>
              kviz
            </span>
          </div>

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
            color: '#9C9C9C',
            fontSize: 24,
            fontWeight: 500,
            marginTop: 32,
            letterSpacing: -0.3,
            display: 'flex',
          }}>
            10 života. Hiljade pitanja. Jedna rang lista.
          </div>
        </div>

        {/* Bottom URL strip */}
        <div style={{
          position: 'absolute',
          bottom: 32,
          left: 0,
          right: 0,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 8,
        }}>
          <div style={{ width: 6, height: 6, borderRadius: 3, background: '#FFCB46', display: 'flex' }} />
          <span style={{
            color: '#9C9C9C',
            fontSize: 18,
            fontWeight: 600,
            letterSpacing: 2,
            textTransform: 'uppercase',
          }}>
            kviz.librum.club
          </span>
        </div>
      </div>
    ),
    { width: 1200, height: 628 }
  )
}
