import Image from 'next/image'
import Link from 'next/link'
import type { Maskota } from '@/lib/igre-katalog'

type Igra = {
  href: string
  kratko: string
  desc: string
  boja: string
  tekst: string
  maskota: Maskota
}

/**
 * Šarena kartica igre iz kita (kategorija): debela ivica, tvrda senka,
 * naslov u kurzivu i maskota koja viri iz ugla.
 *
 * @example <KarticaIgre igra={IGRE[0]} href="/pro-kviz" velika />
 */
export function KarticaIgre({ igra, href, velika = false }: { igra: Igra; href: string; velika?: boolean }) {
  return (
    <Link
      href={href}
      className={`card-pop group relative overflow-hidden flex flex-col justify-end transition-transform hover:-translate-y-0.5 active:translate-y-1 ${velika ? 'min-h-[260px] p-7' : 'min-h-[170px] p-5'}`}
      style={{ background: igra.boja, color: igra.tekst }}
    >
      {/* Svetliji krug iza maskote, kao na karticama u kitu. */}
      <span aria-hidden className="absolute rounded-full"
        style={{ background: 'rgba(255,255,255,0.22)', width: velika ? 260 : 150, height: velika ? 260 : 150, right: velika ? -40 : -36, top: velika ? -30 : -34 }} />
      <Image
        src={`/maskote/${igra.maskota}.png`}
        alt=""
        width={velika ? 200 : 110}
        height={velika ? 200 : 110}
        className="absolute transition-transform group-hover:rotate-6"
        style={{ right: velika ? -6 : -14, top: velika ? 4 : -12 }}
        aria-hidden
      />
      <h2 className="relative" style={{ fontSize: velika ? 'clamp(38px, 6vw, 56px)' : '28px' }}>{igra.kratko}</h2>
      <p className="relative mt-1 text-[14px] font-semibold opacity-85 max-w-[75%]">{igra.desc}</p>
    </Link>
  )
}
