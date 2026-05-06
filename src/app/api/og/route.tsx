import { ImageResponse } from 'next/og'
import { NextRequest } from 'next/server'

export const runtime = 'edge'

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url)
  const score = searchParams.get('score')
  const level = searchParams.get('level')
  const hasScore = score !== null && level !== null && score !== '0'

  return new ImageResponse(
    (
      <div
        style={{
          width: '1200px',
          height: '628px',
          display: 'flex',
          position: 'relative',
          backgroundImage: 'linear-gradient(135deg, #1A1C4E 0%, #2C2D81 55%, #3766B0 100%)',
          fontFamily: 'system-ui, sans-serif',
          overflow: 'hidden',
        }}
      >
        {/* Decorative glow circles */}
        <div style={{
          position: 'absolute', top: -150, right: 260,
          width: 550, height: 550, borderRadius: '50%',
          backgroundImage: 'radial-gradient(circle, rgba(253,195,97,0.08) 0%, transparent 70%)',
          display: 'flex',
        }} />
        <div style={{
          position: 'absolute', bottom: -120, left: -80,
          width: 400, height: 400, borderRadius: '50%',
          backgroundImage: 'radial-gradient(circle, rgba(93,191,148,0.07) 0%, transparent 70%)',
          display: 'flex',
        }} />

        {/* Left content column */}
        <div style={{
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'space-between',
          padding: '56px 60px',
          width: '640px',
          position: 'relative',
          zIndex: 2,
        }}>
          {/* Brand badge */}
          <div style={{
            display: 'flex', alignItems: 'center', gap: 10,
            backgroundImage: 'linear-gradient(135deg, rgba(253,195,97,0.15), rgba(253,195,97,0.08))',
            border: '1.5px solid rgba(253,195,97,0.3)',
            borderRadius: 100, padding: '10px 22px',
          }}>
            <span style={{ fontSize: 20 }}>📚</span>
            <span style={{ color: '#FDC361', fontSize: 20, fontWeight: 700, letterSpacing: 0.5 }}>Librum Kviz</span>
          </div>

          {/* Main content */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            {hasScore ? (
              <>
                <div style={{ color: 'rgba(255,255,255,0.55)', fontSize: 20, fontWeight: 600, letterSpacing: 1 }}>
                  MOJ REZULTAT
                </div>
                <div style={{ display: 'flex', alignItems: 'flex-end', gap: 28 }}>
                  <div style={{ display: 'flex', flexDirection: 'column' }}>
                    <span style={{ color: '#FDC361', fontSize: 108, fontWeight: 900, lineHeight: 1, letterSpacing: -2 }}>
                      {score}
                    </span>
                    <span style={{ color: 'rgba(255,255,255,0.65)', fontSize: 26, fontWeight: 600 }}>
                      bodova
                    </span>
                  </div>
                  <div style={{
                    display: 'flex', flexDirection: 'column',
                    padding: '18px 28px', marginBottom: 10,
                    backgroundImage: 'linear-gradient(135deg, rgba(93,191,148,0.2), rgba(93,191,148,0.1))',
                    border: '1.5px solid rgba(93,191,148,0.35)',
                    borderRadius: 18,
                  }}>
                    <span style={{ color: '#5DBF94', fontSize: 44, fontWeight: 900, lineHeight: 1 }}>
                      Nivo {level}
                    </span>
                    <span style={{ color: 'rgba(255,255,255,0.45)', fontSize: 18, marginTop: 4 }}>
                      dostignut
                    </span>
                  </div>
                </div>
              </>
            ) : (
              <>
                <div style={{ color: 'white', fontSize: 76, fontWeight: 900, lineHeight: 1.05, letterSpacing: -1 }}>
                  Proveri
                </div>
                <div style={{ color: '#FDC361', fontSize: 76, fontWeight: 900, lineHeight: 1.05, letterSpacing: -1 }}>
                  svoje znanje!
                </div>
                <div style={{ color: 'rgba(255,255,255,0.55)', fontSize: 24, marginTop: 8, fontWeight: 500 }}>
                  Testiraj literarno znanje na Librum Kvizt
                </div>
              </>
            )}
          </div>

          {/* Footer */}
          <div style={{ color: 'rgba(255,255,255,0.35)', fontSize: 18, fontWeight: 500, letterSpacing: 0.5 }}>
            librum.club
          </div>
        </div>

        {/* Right: Book illustration */}
        <div style={{
          position: 'absolute', right: 60, bottom: 0,
          display: 'flex', alignItems: 'flex-end', gap: 12,
          zIndex: 2,
        }}>
          {/* Book 1 — tilted left */}
          <div style={{
            width: 72, height: 270,
            backgroundImage: 'linear-gradient(180deg, #3040a0 0%, #1A1C4E 100%)',
            borderRadius: '8px 8px 4px 4px',
            border: '2px solid rgba(255,255,255,0.08)',
            transform: 'rotate(-7deg) translateY(30px)',
            display: 'flex', justifyContent: 'center', alignItems: 'center',
          }}>
            <div style={{ width: 2, height: '55%', background: 'rgba(255,255,255,0.12)', display: 'flex' }} />
          </div>

          {/* Book 2 — tall center with bookmark */}
          <div style={{
            position: 'relative', width: 88, height: 350,
            backgroundImage: 'linear-gradient(180deg, #4070C0 0%, #2C2D81 100%)',
            borderRadius: '8px 8px 4px 4px',
            border: '2px solid rgba(255,255,255,0.1)',
            display: 'flex', justifyContent: 'center', alignItems: 'center',
          }}>
            <div style={{ width: 2, height: '55%', background: 'rgba(255,255,255,0.15)', display: 'flex' }} />
            {/* Bookmark ribbon */}
            <div style={{
              position: 'absolute', top: -2, left: 20,
              width: 26, height: 75,
              background: '#FDC361',
              borderRadius: '0 0 6px 6px',
              display: 'flex',
            }} />
          </div>

          {/* Book 3 — tilted right */}
          <div style={{
            width: 62, height: 210,
            backgroundImage: 'linear-gradient(180deg, #6DCFA4 0%, #3ea87a 100%)',
            borderRadius: '8px 8px 4px 4px',
            border: '2px solid rgba(255,255,255,0.1)',
            transform: 'rotate(6deg) translateY(15px)',
            display: 'flex', justifyContent: 'center', alignItems: 'center',
          }}>
            <div style={{ width: 2, height: '50%', background: 'rgba(255,255,255,0.2)', display: 'flex' }} />
          </div>
        </div>

        {/* Gold accent bottom line */}
        <div style={{
          position: 'absolute', bottom: 0, left: 0, right: 0, height: 4,
          backgroundImage: 'linear-gradient(90deg, #FDC361 0%, rgba(253,195,97,0.2) 60%, transparent 100%)',
          display: 'flex',
        }} />
      </div>
    ),
    { width: 1200, height: 628 }
  )
}
