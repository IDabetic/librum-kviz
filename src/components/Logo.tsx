import Image from 'next/image'
import Link from 'next/link'

// Aspect ratio is ~3:1 (1800×596). Pick height; width auto-scales.
export function Logo({ height = 32, href = '/', priority = false }: {
  height?: number
  href?: string | null
  priority?: boolean
}) {
  const width = Math.round(height * (1800 / 596))
  const img = (
    <Image
      src="/librum-logo.png"
      alt="Librum club"
      width={width}
      height={height}
      priority={priority}
      style={{ height, width: 'auto', objectFit: 'contain' }}
    />
  )
  return href ? <Link href={href} className="flex-shrink-0 inline-flex items-center">{img}</Link> : img
}
