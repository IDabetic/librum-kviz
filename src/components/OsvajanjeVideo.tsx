'use client'

import { useRef, useState } from 'react'

/**
 * Snimak prave partije Osvajača na širokom ekranu (potez igrača i botova, `-demo -demoIgrac` na iPadu), bez okvira telefona.
 * Natpis prati video po sekundama; ratna muzika (Pixabay, „Epic War Background Music”, HitsLab; Pixabay licenca bez navođenja) pali se dodirom, jer pregledači
 * ne puštaju zvuk bez dodira. Snimak: public/video/osvajanje-siroko.mp4 .
 *
 * @example <OsvajanjeVideo />
 */
const NATPISI: [number, string, string][] = [
  [0, 'Biraš metu', 'Dodirneš svoju državu, pa susednu koju napadaš.'],
  [4, 'Bitka', 'Pred bitku biraš temu pitanja; prednost daju vojska, teren i ratne karte.'],
  [8, 'Svaka bitka je pitanje', 'Tačan odgovor ruši branioca. Kad oboje znate, pobeđuje brži.'],
  [14, 'Osvojeno!', 'Država prelazi u tvoje boje i odatle napadaš dalje.'],
  [20, 'Država igrača: 5 pitanja', 'Više tačnih pobeđuje; poraz te košta i državu iz koje napadaš.'],
  [29, 'Odbranila se', 'Ne pada svaka država iz prve. Sledeći potez donosi pojačanja.'],
  [32, 'Rivali na potezu', 'Botovi i prijatelji osvajaju, sklapaju saveze i izdaju.'],
  [48, 'Opet ti', 'Ratne karte, tajne misije i čuda sveta: 171 država čeka.'],
  [56, 'Pitanje odlučuje', 'Više od 165.000 pitanja na srpskom, iz svih oblasti.'],
  [64, 'Osvoji svet znanjem', 'Besplatno za iPhone i Android.'],
]

export function OsvajanjeVideo() {
  const video = useRef<HTMLVideoElement>(null)
  const [natpis, setNatpis] = useState(0)
  const [zvuk, setZvuk] = useState(false)

  function prati() {
    const t = video.current?.currentTime ?? 0
    let i = 0
    for (let k = 0; k < NATPISI.length; k++) if (t >= NATPISI[k][0]) i = k
    if (i !== natpis) setNatpis(i)
  }

  function prebaciZvuk() {
    const v = video.current
    if (!v) return
    v.muted = zvuk
    if (!zvuk) { v.currentTime = 0; void v.play() }
    setZvuk(!zvuk)
  }

  const [, naslov, tekst] = NATPISI[natpis]
  return (
    <div className="relative w-full overflow-hidden rounded-[28px]" style={{ border: '3px solid #151515', boxShadow: '0 8px 0 #0B0A09, 0 40px 80px rgba(0,0,0,.45)' }}>
      <video ref={video} className="block w-full" src="/video/osvajanje-siroko.mp4" poster="/video/osvajanje-siroko.jpg"
        autoPlay muted loop playsInline preload="metadata" onTimeUpdate={prati}
        aria-label="Snimak partije Osvajača: vojske osvajaju države na mapi sveta" />
      <button type="button" onClick={prebaciZvuk} aria-pressed={zvuk} aria-label={zvuk ? 'Isključi zvuk' : 'Uključi zvuk'}
        className="absolute right-4 top-4 w-12 h-12 grid place-items-center rounded-full"
        style={{ background: '#FFD84D', border: '2.5px solid #151515', boxShadow: '0 3px 0 #151515' }}>
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#151515" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
          <path d="M11 5 6 9H3v6h3l5 4V5z" fill="#151515" />
          {zvuk ? <><path d="M15.5 8.5a5 5 0 0 1 0 7" /><path d="M18.5 5.5a9 9 0 0 1 0 13" /></> : <><path d="m16 9 5 6" /><path d="m21 9-5 6" /></>}
        </svg>
      </button>
      {/* Natpis prati snimak; aria-live čita promenu i bez slike. */}
      <div key={natpis} aria-live="polite" className="natpis-ulaz sm:absolute sm:left-5 sm:bottom-5 sm:max-w-[420px] px-5 py-4 sm:rounded-2xl"
        style={{ background: '#FFD84D', color: '#151515', borderTop: '2.5px solid #151515' }}>
        <p className="naslov text-[22px] leading-tight">{naslov}</p>
        <p className="mt-1 text-[15px] font-semibold leading-snug">{tekst}</p>
      </div>
    </div>
  )
}
