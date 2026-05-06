import { ImageResponse } from 'next/og'

export const runtime = 'edge'
export const size = { width: 64, height: 64 }
export const contentType = 'image/png'

export default function Icon() {
  return new ImageResponse(
    (
      <div style={{ width: 64, height: 64, display: 'flex', position: 'relative' }}>
        {/* Bookmark body */}
        <svg width="64" height="64" viewBox="0 0 64 64" fill="none">
          {/* Gold bookmark shape */}
          <path d="M8 4 H56 V52 L32 62 L8 52 Z" fill="#FDC361"/>
          {/* Highlight */}
          <path d="M14 10 H50 V49 L32 58 L14 49 Z" fill="#fdd580" opacity="0.35"/>
          {/* Navy hat bar */}
          <rect x="22" y="2" width="20" height="6" rx="3" fill="#1A1C4E"/>
          {/* Eyes */}
          <circle cx="24" cy="30" r="6" fill="white"/>
          <circle cx="40" cy="30" r="6" fill="white"/>
          <circle cx="25" cy="30" r="3" fill="#1A1C4E"/>
          <circle cx="41" cy="30" r="3" fill="#1A1C4E"/>
          <circle cx="26" cy="29" r="1" fill="white"/>
          <circle cx="42" cy="29" r="1" fill="white"/>
          {/* Smile */}
          <path d="M22 42 Q32 50 42 42" stroke="#1A1C4E" strokeWidth="2.5" strokeLinecap="round" fill="none"/>
          {/* Cheeks */}
          <circle cx="16" cy="38" r="5" fill="#e8944a" opacity="0.4"/>
          <circle cx="48" cy="38" r="5" fill="#e8944a" opacity="0.4"/>
        </svg>
      </div>
    ),
    { ...size }
  )
}
