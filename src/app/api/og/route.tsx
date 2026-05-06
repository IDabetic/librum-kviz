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
        {/* Background glow circles */}
        <div style={{
          position: 'absolute', top: -180, right: 200,
          width: 500, height: 500, borderRadius: '50%',
          backgroundImage: 'radial-gradient(circle, rgba(253,195,97,0.1) 0%, transparent 70%)',
          display: 'flex',
        }} />
        <div style={{
          position: 'absolute', bottom: -120, left: -80,
          width: 400, height: 400, borderRadius: '50%',
          backgroundImage: 'radial-gradient(circle, rgba(93,191,148,0.08) 0%, transparent 70%)',
          display: 'flex',
        }} />

        {/* Left content */}
        <div style={{
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'space-between',
          padding: '56px 60px',
          width: '620px',
          position: 'relative',
          zIndex: 2,
        }}>
          {/* Brand badge */}
          <div style={{
            display: 'flex', alignItems: 'center', gap: 10,
            background: 'rgba(253,195,97,0.12)',
            border: '1.5px solid rgba(253,195,97,0.3)',
            borderRadius: 100, padding: '10px 22px',
            width: 'fit-content',
          }}>
            <span style={{ fontSize: 22 }}>📚</span>
            <span style={{ color: '#FDC361', fontSize: 22, fontWeight: 700 }}>Librum Kviz</span>
          </div>

          {/* Main text */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {hasScore ? (
              <>
                <div style={{ color: 'rgba(255,255,255,0.5)', fontSize: 18, fontWeight: 600, letterSpacing: 2 }}>
                  MOJ REZULTAT
                </div>
                <div style={{ display: 'flex', alignItems: 'flex-end', gap: 24 }}>
                  <div style={{ display: 'flex', flexDirection: 'column' }}>
                    <span style={{ color: '#FDC361', fontSize: 110, fontWeight: 900, lineHeight: 1, letterSpacing: -2 }}>
                      {score}
                    </span>
                    <span style={{ color: 'rgba(255,255,255,0.6)', fontSize: 26, fontWeight: 600 }}>
                      bodova
                    </span>
                  </div>
                  <div style={{
                    display: 'flex', flexDirection: 'column',
                    padding: '16px 24px', marginBottom: 12,
                    background: 'rgba(93,191,148,0.15)',
                    border: '1.5px solid rgba(93,191,148,0.35)',
                    borderRadius: 18,
                  }}>
                    <span style={{ color: '#5DBF94', fontSize: 42, fontWeight: 900, lineHeight: 1 }}>
                      Nivo {level}
                    </span>
                    <span style={{ color: 'rgba(255,255,255,0.4)', fontSize: 17, marginTop: 4 }}>
                      dostignut
                    </span>
                  </div>
                </div>
                <div style={{ color: 'rgba(255,255,255,0.5)', fontSize: 20, fontWeight: 500 }}>
                  Možeš li bolje? Probaj na kviz.librum.club
                </div>
              </>
            ) : (
              <>
                <div style={{ color: 'white', fontSize: 82, fontWeight: 900, lineHeight: 1.05, letterSpacing: -2 }}>
                  Testiraj
                </div>
                <div style={{ color: '#FDC361', fontSize: 82, fontWeight: 900, lineHeight: 1.05, letterSpacing: -2 }}>
                  svoje znanje!
                </div>
                <div style={{ color: 'rgba(255,255,255,0.5)', fontSize: 22, marginTop: 8, fontWeight: 500 }}>
                  Kvizovi iz književnosti, istorije i kulture
                </div>
              </>
            )}
          </div>

          <div style={{ color: 'rgba(255,255,255,0.3)', fontSize: 18, fontWeight: 500 }}>
            kviz.librum.club
          </div>
        </div>

        {/* Right: Mascots */}
        <div style={{
          position: 'absolute',
          right: 0,
          bottom: 0,
          width: '560px',
          height: '628px',
          display: 'flex',
          alignItems: 'flex-end',
          justifyContent: 'flex-end',
          gap: 0,
          zIndex: 2,
        }}>
          {/* Bookmark mascot */}
          <div style={{
            display: 'flex',
            transform: 'rotate(-8deg) translateY(-20px) translateX(20px)',
          }}>
            <svg width="210" height="350" viewBox="0 0 120 200" fill="none">
              <defs>
                <linearGradient id="bmg" x1="15" y1="10" x2="105" y2="190" gradientUnits="userSpaceOnUse">
                  <stop offset="0%" stopColor="#FDC361"/>
                  <stop offset="100%" stopColor="#f0a832"/>
                </linearGradient>
              </defs>
              {/* Body */}
              <path d="M15 10 H105 V165 L60 190 L15 165 Z" fill="url(#bmg)"/>
              <path d="M25 20 H95 V158 L60 181 L25 158 Z" fill="#fdd07a" opacity="0.35"/>
              {/* Eyes */}
              <circle cx="44" cy="90" r="11" fill="white"/>
              <circle cx="76" cy="90" r="11" fill="white"/>
              <circle cx="46" cy="90" r="5.5" fill="#1A1C4E"/>
              <circle cx="78" cy="90" r="5.5" fill="#1A1C4E"/>
              <circle cx="48" cy="88" r="2" fill="white"/>
              <circle cx="80" cy="88" r="2" fill="white"/>
              {/* Eyebrows */}
              <path d="M36 76 Q44 71 52 76" stroke="#1A1C4E" strokeWidth="2.5" strokeLinecap="round" fill="none"/>
              <path d="M68 76 Q76 71 84 76" stroke="#1A1C4E" strokeWidth="2.5" strokeLinecap="round" fill="none"/>
              {/* Smile */}
              <path d="M42 112 Q60 128 78 112" stroke="#1A1C4E" strokeWidth="3" strokeLinecap="round" fill="none"/>
              {/* Cheeks */}
              <circle cx="33" cy="106" r="8" fill="#e8944a" opacity="0.4"/>
              <circle cx="87" cy="106" r="8" fill="#e8944a" opacity="0.4"/>
              {/* Hat */}
              <rect x="42" y="4" width="36" height="10" rx="5" fill="#2C2D81"/>
              <circle cx="60" cy="9" r="5" fill="#3766B0"/>
            </svg>
          </div>

          {/* Book mascot */}
          <div style={{
            display: 'flex',
            transform: 'rotate(5deg) translateY(0px)',
          }}>
            <svg width="290" height="340" viewBox="0 0 180 200" fill="none">
              {/* Cover */}
              <rect x="20" y="30" width="140" height="155" rx="12" fill="#1A1C4E"/>
              <rect x="20" y="30" width="12" height="155" rx="6" fill="#0f1033"/>
              {/* Pages */}
              <rect x="36" y="42" width="112" height="131" rx="6" fill="#FAF4EC"/>
              <line x1="92" y1="42" x2="92" y2="173" stroke="#e0d8ce" strokeWidth="2"/>
              {/* Text lines */}
              <rect x="44" y="62" width="40" height="5" rx="2.5" fill="#c8c0b4"/>
              <rect x="44" y="74" width="36" height="5" rx="2.5" fill="#c8c0b4"/>
              <rect x="44" y="86" width="40" height="5" rx="2.5" fill="#c8c0b4"/>
              <rect x="100" y="62" width="40" height="5" rx="2.5" fill="#c8c0b4"/>
              <rect x="100" y="74" width="36" height="5" rx="2.5" fill="#c8c0b4"/>
              <rect x="100" y="86" width="40" height="5" rx="2.5" fill="#c8c0b4"/>
              {/* Eyes */}
              <circle cx="68" cy="128" r="10" fill="white"/>
              <circle cx="112" cy="128" r="10" fill="white"/>
              <circle cx="70" cy="128" r="5" fill="#1A1C4E"/>
              <circle cx="114" cy="128" r="5" fill="#1A1C4E"/>
              <circle cx="72" cy="126" r="2" fill="white"/>
              <circle cx="116" cy="126" r="2" fill="white"/>
              {/* Smile */}
              <path d="M74 148 Q90 162 106 148" stroke="#1A1C4E" strokeWidth="3" strokeLinecap="round" fill="none"/>
              {/* Cheeks */}
              <circle cx="58" cy="143" r="7" fill="#FDC361" opacity="0.5"/>
              <circle cx="122" cy="143" r="7" fill="#FDC361" opacity="0.5"/>
              {/* Arms */}
              <path d="M20 95 Q4 105 8 120" stroke="#1A1C4E" strokeWidth="8" strokeLinecap="round"/>
              <circle cx="8" cy="122" r="6" fill="#1A1C4E"/>
              <path d="M160 95 Q176 105 172 120" stroke="#1A1C4E" strokeWidth="8" strokeLinecap="round"/>
              <circle cx="172" cy="122" r="6" fill="#1A1C4E"/>
            </svg>
          </div>
        </div>

        {/* Bottom gold line */}
        <div style={{
          position: 'absolute', bottom: 0, left: 0, right: 0, height: 5,
          backgroundImage: 'linear-gradient(90deg, #FDC361 0%, rgba(253,195,97,0.3) 50%, transparent 100%)',
          display: 'flex',
        }} />
      </div>
    ),
    { width: 1200, height: 628 }
  )
}
