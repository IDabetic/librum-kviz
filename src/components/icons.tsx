// Icon set matching the design system spec.
// All icons are 24×24 by default with 2px stroke, currentColor.
// Use { className } to size/color them via Tailwind.

type IconProps = {
  className?: string
  size?: number
  strokeWidth?: number
  style?: React.CSSProperties
}

const baseProps = (size = 24, sw = 2) => ({
  width: size,
  height: size,
  viewBox: '0 0 24 24',
  fill: 'none',
  stroke: 'currentColor',
  strokeWidth: sw,
  strokeLinecap: 'round' as const,
  strokeLinejoin: 'round' as const,
})

export const IconBack = ({ className, size, strokeWidth, style }: IconProps) => (
  <svg className={className} style={style} {...baseProps(size, strokeWidth)}>
    <path d="M14 6l-6 6 6 6" />
  </svg>
)

export const IconClose = ({ className, size, strokeWidth, style }: IconProps) => (
  <svg className={className} style={style} {...baseProps(size, strokeWidth)}>
    <path d="M6 6l12 12M18 6L6 18" />
  </svg>
)

export const IconEmail = ({ className, size, strokeWidth, style }: IconProps) => (
  <svg className={className} style={style} {...baseProps(size, strokeWidth)}>
    <rect x="3" y="5" width="18" height="14" rx="2.5" />
    <path d="M3 7l9 6 9-6" />
  </svg>
)

export const IconLock = ({ className, size, strokeWidth, style }: IconProps) => (
  <svg className={className} style={style} {...baseProps(size, strokeWidth)}>
    <rect x="4" y="11" width="16" height="10" rx="2.5" />
    <path d="M8 11V8a4 4 0 018 0v3" />
    <circle cx="12" cy="16" r="1" fill="currentColor" stroke="none" />
  </svg>
)

export const IconEye = ({ className, size, strokeWidth, style }: IconProps) => (
  <svg className={className} style={style} {...baseProps(size, strokeWidth)}>
    <path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z" />
    <circle cx="12" cy="12" r="3" />
  </svg>
)

export const IconEyeOff = ({ className, size, strokeWidth, style }: IconProps) => (
  <svg className={className} style={style} {...baseProps(size, strokeWidth)}>
    <path d="M3 3l18 18" />
    <path d="M10.6 6.1A10.5 10.5 0 0112 6c6.5 0 10 7 10 7a17 17 0 01-3.2 3.9M6.6 6.6A17 17 0 002 12s3.5 7 10 7c1.4 0 2.7-.3 3.9-.8" />
    <path d="M9.9 9.9a3 3 0 004.2 4.2" />
  </svg>
)

export const IconSearch = ({ className, size, strokeWidth, style }: IconProps) => (
  <svg className={className} style={style} {...baseProps(size, strokeWidth)}>
    <circle cx="11" cy="11" r="7" />
    <path d="M21 21l-4.3-4.3" />
  </svg>
)

export const IconBell = ({ className, size, strokeWidth, style }: IconProps) => (
  <svg className={className} style={style} {...baseProps(size, strokeWidth)}>
    <path d="M6 8a6 6 0 0112 0c0 7 3 8 3 8H3s3-1 3-8z" />
    <path d="M10 21a2 2 0 004 0" />
  </svg>
)

export const IconTrophy = ({ className, size, strokeWidth, style }: IconProps) => (
  <svg className={className} style={style} {...baseProps(size, strokeWidth)}>
    <path d="M8 4h8v6a4 4 0 01-8 0V4z" />
    <path d="M16 6h2.5a1.5 1.5 0 010 3H16M8 6H5.5a1.5 1.5 0 000 3H8" />
    <path d="M9 14h6l-1 4h-4l-1-4z" />
    <path d="M8 21h8" />
  </svg>
)

export const IconQuestion = ({ className, size, strokeWidth, style }: IconProps) => (
  <svg className={className} style={style} {...baseProps(size, strokeWidth)}>
    <rect x="4" y="3" width="16" height="18" rx="2.5" />
    <path d="M9 9a3 3 0 116 0c0 1.5-1.5 2-2 2.5s-1 1-1 2" />
    <circle cx="12" cy="17" r="1" fill="currentColor" stroke="none" />
  </svg>
)

export const IconMore = ({ className, size, strokeWidth, style }: IconProps) => (
  <svg className={className} style={style} {...baseProps(size, strokeWidth)}>
    <circle cx="6" cy="12" r="1.5" fill="currentColor" stroke="none" />
    <circle cx="12" cy="12" r="1.5" fill="currentColor" stroke="none" />
    <circle cx="18" cy="12" r="1.5" fill="currentColor" stroke="none" />
  </svg>
)

export const IconFilter = ({ className, size, strokeWidth, style }: IconProps) => (
  <svg className={className} style={style} {...baseProps(size, strokeWidth)}>
    <path d="M5 8h11M5 16h7" />
    <circle cx="18" cy="8" r="2" />
    <circle cx="14" cy="16" r="2" />
  </svg>
)

export const IconProfile = ({ className, size, strokeWidth, style }: IconProps) => (
  <svg className={className} style={style} {...baseProps(size, strokeWidth)}>
    <circle cx="12" cy="8" r="4" />
    <path d="M4 21c0-4 4-7 8-7s8 3 8 7" />
  </svg>
)

export const IconDiscover = ({ className, size, strokeWidth, style }: IconProps) => (
  <svg className={className} style={style} {...baseProps(size, strokeWidth)}>
    <rect x="3" y="3" width="7" height="7" rx="1.5" />
    <rect x="14" y="3" width="7" height="7" rx="1.5" />
    <rect x="3" y="14" width="7" height="7" rx="1.5" />
    <rect x="14" y="14" width="7" height="7" rx="1.5" />
  </svg>
)

export const IconHome = ({ className, size, strokeWidth, style }: IconProps) => (
  <svg className={className} style={style} {...baseProps(size, strokeWidth)}>
    <path d="M4 11l8-7 8 7v9a1 1 0 01-1 1h-4v-6h-6v6H5a1 1 0 01-1-1v-9z" />
  </svg>
)

export const IconSort = ({ className, size, strokeWidth, style }: IconProps) => (
  <svg className={className} style={style} {...baseProps(size, strokeWidth)}>
    <path d="M5 7h14M7 12h10M9 17h6" />
  </svg>
)

export const IconStar = ({ className, size, strokeWidth, style }: IconProps) => (
  <svg className={className} style={style} {...baseProps(size, strokeWidth)}>
    <path d="M12 3l2.7 5.5L21 9.4l-4.5 4.4L17.5 20 12 17l-5.5 3 1-6.2L3 9.4l6.3-.9L12 3z" />
  </svg>
)

export const IconTime = ({ className, size, strokeWidth, style }: IconProps) => (
  <svg className={className} style={style} {...baseProps(size, strokeWidth)}>
    <circle cx="12" cy="13" r="8" />
    <path d="M12 9v4l2.5 2.5M9 3h6" />
  </svg>
)

export const IconSettings = ({ className, size, strokeWidth, style }: IconProps) => (
  <svg className={className} style={style} {...baseProps(size, strokeWidth)}>
    <circle cx="12" cy="12" r="3" />
    <path d="M19.4 15a1.6 1.6 0 00.3 1.7l.1.1a2 2 0 11-2.8 2.8l-.1-.1a1.6 1.6 0 00-1.7-.3 1.6 1.6 0 00-1 1.4V21a2 2 0 11-4 0v-.1a1.6 1.6 0 00-1-1.4 1.6 1.6 0 00-1.7.3l-.1.1a2 2 0 11-2.8-2.8l.1-.1a1.6 1.6 0 00.3-1.7 1.6 1.6 0 00-1.4-1H3a2 2 0 110-4h.1a1.6 1.6 0 001.4-1 1.6 1.6 0 00-.3-1.7l-.1-.1a2 2 0 112.8-2.8l.1.1a1.6 1.6 0 001.7.3H9a1.6 1.6 0 001-1.4V3a2 2 0 114 0v.1a1.6 1.6 0 001 1.4 1.6 1.6 0 001.7-.3l.1-.1a2 2 0 112.8 2.8l-.1.1a1.6 1.6 0 00-.3 1.7V9a1.6 1.6 0 001.4 1H21a2 2 0 110 4h-.1a1.6 1.6 0 00-1.4 1z" />
  </svg>
)

export const IconHint = ({ className, size, strokeWidth, style }: IconProps) => (
  <svg className={className} style={style} {...baseProps(size, strokeWidth)}>
    <path d="M9 18h6M10 21h4" />
    <path d="M12 3a6 6 0 016 6c0 3-2 4.5-3 6H9c-1-1.5-3-3-3-6a6 6 0 016-6z" />
  </svg>
)

export const IconCheck = ({ className, size, strokeWidth, style }: IconProps) => (
  <svg className={className} style={style} {...baseProps(size, strokeWidth)}>
    <circle cx="12" cy="12" r="9" fill="currentColor" stroke="none" />
    <path d="M8 12.5l3 3 5-6" stroke="white" />
  </svg>
)

export const IconWrong = ({ className, size, strokeWidth, style }: IconProps) => (
  <svg className={className} style={style} {...baseProps(size, strokeWidth)}>
    <circle cx="12" cy="12" r="9" fill="currentColor" stroke="none" />
    <path d="M9 9l6 6M15 9l-6 6" stroke="white" />
  </svg>
)

export const IconShare = ({ className, size, strokeWidth, style }: IconProps) => (
  <svg className={className} style={style} {...baseProps(size, strokeWidth)}>
    <path d="M12 4v12" />
    <path d="M8 8l4-4 4 4" />
    <path d="M4 13v5a2 2 0 002 2h12a2 2 0 002-2v-5" />
  </svg>
)

export const IconSwords = ({ className, size, strokeWidth, style }: IconProps) => (
  <svg className={className} style={style} {...baseProps(size, strokeWidth)}>
    <path d="M14 5l5-2-2 5-7 7-3-3 7-7z" />
    <path d="M10 5L5 3l2 5 7 7 3-3-7-7z" />
    <path d="M5 19l3 3M19 19l-3 3" />
  </svg>
)

export const IconLogout = ({ className, size, strokeWidth, style }: IconProps) => (
  <svg className={className} style={style} {...baseProps(size, strokeWidth)}>
    <path d="M9 4H5a2 2 0 00-2 2v12a2 2 0 002 2h4" />
    <path d="M16 17l5-5-5-5M21 12H9" />
  </svg>
)

export const IconUsers = ({ className, size, strokeWidth, style }: IconProps) => (
  <svg className={className} style={style} {...baseProps(size, strokeWidth)}>
    <circle cx="9" cy="8" r="3.5" />
    <path d="M3 20c0-3 2.5-5 6-5s6 2 6 5" />
    <circle cx="17" cy="9" r="2.5" />
    <path d="M15.5 14c2 0 4.5 1.5 4.5 4" />
  </svg>
)

export const IconMenu = ({ className, size, strokeWidth, style }: IconProps) => (
  <svg className={className} style={style} {...baseProps(size, strokeWidth)}>
    <path d="M4 7h16M4 12h16M4 17h16" />
  </svg>
)
