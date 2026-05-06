import { ImageResponse } from 'next/og'

export const runtime = 'edge'

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
          backgroundImage: 'linear-gradient(135deg, #1A1C4E 0%, #2C2D81 55%, #3766B0 100%)',
          fontFamily: 'system-ui, sans-serif',
          overflow: 'hidden',
        }}
      >
        {/* Title */}
        <div style={{
          position: 'absolute',
          top: '50%',
          left: '50%',
          transform: 'translate(-50%, -50%)',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          zIndex: 3,
        }}>
          <span style={{ color: 'white', fontSize: 96, fontWeight: 900, lineHeight: 1, letterSpacing: -3 }}>
            Librum
          </span>
          <span style={{ color: '#FDC361', fontSize: 96, fontWeight: 900, lineHeight: 1, letterSpacing: -3 }}>
            Kviz
          </span>
        </div>

        {/* Left: Bookmark mascot */}
        <div style={{
          position: 'absolute',
          left: 60,
          bottom: 0,
          display: 'flex',
          transform: 'rotate(-6deg)',
          zIndex: 2,
        }}>
          <svg width="240" height="400" viewBox="0 0 120 200" fill="none">
            <defs>
              <linearGradient id="bmg" x1="15" y1="10" x2="105" y2="190" gradientUnits="userSpaceOnUse">
                <stop offset="0%" stopColor="#FDC361"/>
                <stop offset="100%" stopColor="#f0a832"/>
              </linearGradient>
            </defs>
            <path d="M15 10 H105 V165 L60 190 L15 165 Z" fill="url(#bmg)"/>
            <path d="M25 20 H95 V158 L60 181 L25 158 Z" fill="#fdd07a" opacity="0.35"/>
            <circle cx="44" cy="90" r="11" fill="white"/>
            <circle cx="76" cy="90" r="11" fill="white"/>
            <circle cx="46" cy="90" r="5.5" fill="#1A1C4E"/>
            <circle cx="78" cy="90" r="5.5" fill="#1A1C4E"/>
            <circle cx="48" cy="88" r="2" fill="white"/>
            <circle cx="80" cy="88" r="2" fill="white"/>
            <path d="M36 76 Q44 71 52 76" stroke="#1A1C4E" strokeWidth="2.5" strokeLinecap="round" fill="none"/>
            <path d="M68 76 Q76 71 84 76" stroke="#1A1C4E" strokeWidth="2.5" strokeLinecap="round" fill="none"/>
            <path d="M42 112 Q60 128 78 112" stroke="#1A1C4E" strokeWidth="3" strokeLinecap="round" fill="none"/>
            <circle cx="33" cy="106" r="8" fill="#e8944a" opacity="0.4"/>
            <circle cx="87" cy="106" r="8" fill="#e8944a" opacity="0.4"/>
            <rect x="42" y="4" width="36" height="10" rx="5" fill="#2C2D81"/>
            <circle cx="60" cy="9" r="5" fill="#3766B0"/>
          </svg>
        </div>

        {/* Right: Book mascot */}
        <div style={{
          position: 'absolute',
          right: 60,
          bottom: 0,
          display: 'flex',
          transform: 'rotate(6deg)',
          zIndex: 2,
        }}>
          <svg width="320" height="380" viewBox="0 0 180 200" fill="none">
            <rect x="20" y="30" width="140" height="155" rx="12" fill="#1A1C4E"/>
            <rect x="20" y="30" width="12" height="155" rx="6" fill="#0f1033"/>
            <rect x="36" y="42" width="112" height="131" rx="6" fill="#FAF4EC"/>
            <line x1="92" y1="42" x2="92" y2="173" stroke="#e0d8ce" strokeWidth="2"/>
            <rect x="44" y="62" width="40" height="5" rx="2.5" fill="#c8c0b4"/>
            <rect x="44" y="74" width="36" height="5" rx="2.5" fill="#c8c0b4"/>
            <rect x="44" y="86" width="40" height="5" rx="2.5" fill="#c8c0b4"/>
            <rect x="100" y="62" width="40" height="5" rx="2.5" fill="#c8c0b4"/>
            <rect x="100" y="74" width="36" height="5" rx="2.5" fill="#c8c0b4"/>
            <rect x="100" y="86" width="40" height="5" rx="2.5" fill="#c8c0b4"/>
            <circle cx="68" cy="128" r="10" fill="white"/>
            <circle cx="112" cy="128" r="10" fill="white"/>
            <circle cx="70" cy="128" r="5" fill="#1A1C4E"/>
            <circle cx="114" cy="128" r="5" fill="#1A1C4E"/>
            <circle cx="72" cy="126" r="2" fill="white"/>
            <circle cx="116" cy="126" r="2" fill="white"/>
            <path d="M74 148 Q90 162 106 148" stroke="#1A1C4E" strokeWidth="3" strokeLinecap="round" fill="none"/>
            <circle cx="58" cy="143" r="7" fill="#FDC361" opacity="0.5"/>
            <circle cx="122" cy="143" r="7" fill="#FDC361" opacity="0.5"/>
            <path d="M20 95 Q4 105 8 120" stroke="#1A1C4E" strokeWidth="8" strokeLinecap="round"/>
            <circle cx="8" cy="122" r="6" fill="#1A1C4E"/>
            <path d="M160 95 Q176 105 172 120" stroke="#1A1C4E" strokeWidth="8" strokeLinecap="round"/>
            <circle cx="172" cy="122" r="6" fill="#1A1C4E"/>
          </svg>
        </div>

        {/* Bottom gold line */}
        <div style={{
          position: 'absolute', bottom: 0, left: 0, right: 0, height: 5,
          backgroundImage: 'linear-gradient(90deg, #FDC361, rgba(253,195,97,0.3), transparent)',
          display: 'flex',
        }} />
      </div>
    ),
    { width: 1200, height: 628 }
  )
}
