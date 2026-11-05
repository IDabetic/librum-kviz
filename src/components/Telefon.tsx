import Image from 'next/image'

/**
 * Snimak aplikacije u okviru telefona (tanak okvir i ostrvo, kao iPhone).
 * Snimci iz `mobile/snimci/iphone` su 1320×2868, pa je odnos stranica 1320/2868.
 *
 * @example <Telefon src="/aplikacija/karijera-grad.jpg" alt="Grad firmi u Karijeristi" />
 */
export function Telefon({ src, alt, nagib = 0, className = '', prioritet = false }: { src: string; alt: string; nagib?: number; className?: string; prioritet?: boolean }) {
  return (
    <div className={`relative w-full rounded-[44px] p-[9px] ${className}`}
      style={{ background: '#0B0B14', boxShadow: '0 0 0 1px rgba(255,255,255,.08) inset, var(--senka-jaka)', transform: nagib ? `rotate(${nagib}deg)` : undefined }}>
      <div className="relative aspect-[1320/2868] overflow-hidden rounded-[36px]">
        <Image src={src} alt={alt} fill sizes="(min-width: 1024px) 260px, 45vw" priority={prioritet} className="object-cover" />
        <span aria-hidden className="absolute left-1/2 top-[1.6%] h-[3.4%] w-[31%] -translate-x-1/2 rounded-full" style={{ background: '#0B0B14' }} />
      </div>
    </div>
  )
}
