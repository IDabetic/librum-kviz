'use client'

import { useRef, useState } from 'react'

/**
 * Snimak prave runde Karijeriste sa telefona (iPhone 17 Pro Max simulator, demo nalog, 05.11.2026): grad, firma,
 * runda sa 50:50 i ishod. Natpis prati video po sekundama; muzika je Karijerina (`karijera_korporacija`) i pali se dodirom.
 * Snimak: public/video/karijera-telefon.mp4 (720×1478).
 *
 * @example <KarijeraVideo />
 */
const NATPISI: [number, string, string][] = [
  [0, 'Karijerista', 'Nova igra u aplikaciji: posao, firme i grad, sve na znanju.'],
  [5, 'Probni rad', 'Deset rundi u Korporaciji odlučuje gde možeš da se zaposliš.'],
  [12, 'Grad firmi', 'Svaka zgrada je firma. Pomeraj, zumiraj i dodirni da vidiš ko je vodi.'],
  [24.5, 'Firma', 'Plata, šef, asistenti i rekord koji vlasnik brani.'],
  [32.5, 'Runda', 'Deset pitanja iz struke i opšteg znanja, svako na sat.'],
  [44, 'Pomoć kad zapne', 'Pola-pola, insajder i kolege, ali svaka pomoć se troši.'],
  [58.5, 'Plata i ugled', 'Tačni odgovori donose platu i ugled, a sa ugledom raste i pozicija.'],
]

export function KarijeraVideo() {
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
    <div className="grid md:grid-cols-[1fr_auto] gap-8 items-center">
      {/* Natpis prati snimak; aria-live čita promenu i bez slike. */}
      <div key={natpis} aria-live="polite" className="natpis-ulaz order-2 md:order-1 md:max-w-[420px]">
        <p className="naslov text-[30px] sm:text-[36px] leading-tight" style={{ color: 'var(--brand)' }}>{naslov}</p>
        <p className="mt-2 text-[17px] leading-snug" style={{ color: 'var(--ink-2)' }}>{tekst}</p>
      </div>
      <div className="order-1 md:order-2 relative mx-auto w-full max-w-[300px] rounded-[46px] p-[9px]"
        style={{ background: '#0B0B14', boxShadow: '0 0 0 1px rgba(255,255,255,.08) inset, var(--senka-jaka)' }}>
        <video ref={video} className="block w-full rounded-[37px]" src="/video/karijera-telefon.mp4" poster="/video/karijera-telefon.jpg"
          width={720} height={1478} autoPlay muted loop playsInline preload="metadata" onTimeUpdate={prati}
          aria-label="Snimak igre Karijerista na telefonu: grad sa firmama, firma i runda pitanja" />
        <button type="button" onClick={prebaciZvuk} aria-pressed={zvuk} aria-label={zvuk ? 'Isključi zvuk' : 'Uključi zvuk'}
          className="absolute right-5 bottom-5 w-11 h-11 grid place-items-center rounded-full"
          style={{ background: 'rgba(13,14,28,.55)', backdropFilter: 'blur(8px)', color: '#FFFFFF' }}>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
            <path d="M11 5 6 9H3v6h3l5 4V5z" fill="currentColor" />
            {zvuk ? <><path d="M15.5 8.5a5 5 0 0 1 0 7" /><path d="M18.5 5.5a9 9 0 0 1 0 13" /></> : <><path d="m16 9 5 6" /><path d="m21 9-5 6" /></>}
          </svg>
        </button>
      </div>
    </div>
  )
}
