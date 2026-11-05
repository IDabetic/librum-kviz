import Image from 'next/image'

/**
 * Snimak aplikacije u okviru telefona (debela ivica i tvrda senka iz kita).
 *
 * @example <Telefon src="/aplikacija/mapa.jpg" alt="Mapa sveta u aplikaciji" />
 */
export function Telefon({ src, alt, nagib = 0, className = '', prioritet = false }: { src: string; alt: string; nagib?: number; className?: string; prioritet?: boolean }) {
  return (
    <div className={`relative aspect-[1206/2622] w-full rounded-[34px] bg-[#1A1B3A] p-[7px] ${className}`}
      style={{ boxShadow: 'var(--senka)', transform: nagib ? `rotate(${nagib}deg)` : undefined }}>
      <Image src={src} alt={alt} width={414} height={900} priority={prioritet} className="h-full w-full rounded-[28px] object-cover" />
    </div>
  )
}
