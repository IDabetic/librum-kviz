import { ImageResponse } from 'next/og'

export const runtime = 'edge'
export const size = { width: 64, height: 64 }
export const contentType = 'image/png'

// Simple favicon: rounded blue square with bold white "L"
export default function Icon() {
  return new ImageResponse(
    (
      <div style={{
        width: 64,
        height: 64,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: '#3A36A0',
        borderRadius: 14,
        color: '#FFFDF9',
        fontSize: 44,
        fontWeight: 900,
        fontFamily: 'system-ui, -apple-system, sans-serif',
        letterSpacing: -2,
        lineHeight: 1,
      }}>
        L
      </div>
    ),
    { ...size }
  )
}
