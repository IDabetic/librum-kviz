'use client'

import { useEffect, useMemo, useRef, useState } from 'react'
import { OBLASTI, SIRINA_MAPE, VISINA_MAPE, oblast, type Stanje } from '@/lib/osvajanje/pravila'

type Pogled = { x: number; y: number; w: number }

const ODNOS = VISINA_MAPE / SIRINA_MAPE
const NAJMANJI_W = 260
// Neutralne države su svetle (susedi uvek različiti, kao na infografici), da osvojene
// u punoj boji igrača odmah iskoče.
const NEUTRALNE = ['#CFEDE6', '#FFD9E6', '#FFF0BF', '#DED5F7', '#D3ECFA']
const OKEAN = '#E3EDF2'

function ogranici(p: Pogled): Pogled {
  const w = Math.min(SIRINA_MAPE, Math.max(NAJMANJI_W, p.w))
  const h = w * ODNOS
  return { w, x: Math.min(SIRINA_MAPE - w, Math.max(0, p.x)), y: Math.min(VISINA_MAPE - h, Math.max(0, p.y)) }
}

/**
 * Mapa sveta po državama: boja vlasnika, značka sa vojskama, zum točkićem,
 * prstima ili dugmićima, pomeranje prevlačenjem. Dodir bez pomeranja bira državu.
 *
 * @example <Mapa stanje={s} izabrana="SRB" mete={['BGR']} fokus="SRB" onOblast={id => …} />
 */
export function Mapa({ stanje, izabrana, mete, fokus, onOblast }: {
  stanje: Stanje
  izabrana: string | null
  mete: string[]
  fokus: string | null
  onOblast: (id: string) => void
}) {
  const okvir = useRef<HTMLDivElement>(null)
  // Mapa se crta tek kad pitanja stignu (samo u pregledaču), pa je prozor dostupan od početka.
  const [sirinaPx, setSirinaPx] = useState(() => (typeof window === 'undefined' ? 800 : Math.min(window.innerWidth, 1280)))
  const [pogled, setPogled] = useState<Pogled>({ x: 0, y: 0, w: SIRINA_MAPE })
  const pokazivaci = useRef(new Map<number, { x: number; y: number }>())
  const pomereno = useRef(0)

  useEffect(() => {
    const el = okvir.current
    if (!el) return
    const ro = new ResizeObserver(([e]) => setSirinaPx(e.contentRect.width))
    ro.observe(el)
    return () => ro.disconnect()
  }, [])

  // Na uskom ekranu mapa dolazi do fokusa (prestonica ili bitka) u krupnijem kadru.
  // Podešava se tokom crtanja kad se fokus promeni (React obrazac umesto efekta).
  const usko = sirinaPx < 900
  const kljucFokusa = `${fokus}|${usko}`
  const [prethodniFokus, setPrethodniFokus] = useState('')
  if (fokus && kljucFokusa !== prethodniFokus) {
    setPrethodniFokus(kljucFokusa)
    const o = oblast(fokus)
    setPogled(p => {
      const w = usko ? Math.min(p.w, 820) : p.w
      const unutra = o.x > p.x + w * 0.15 && o.x < p.x + w * 0.85 && o.y > p.y + w * ODNOS * 0.15 && o.y < p.y + w * ODNOS * 0.85
      return unutra && w === p.w ? p : ogranici({ w, x: o.x - w / 2, y: o.y - (w * ODNOS) / 2 })
    })
  }

  const jedinica = pogled.w / sirinaPx // koliko jedinica mape staje u jedan piksel ekrana

  function zumiraj(faktor: number, ox = 0.5, oy = 0.5) {
    setPogled(p => {
      const w = Math.min(SIRINA_MAPE, Math.max(NAJMANJI_W, p.w * faktor))
      return ogranici({ w, x: p.x + (p.w - w) * ox, y: p.y + (p.w - w) * ODNOS * oy })
    })
  }

  function tacka(e: React.PointerEvent | React.WheelEvent) {
    const r = okvir.current!.getBoundingClientRect()
    return { ox: (e.clientX - r.left) / r.width, oy: (e.clientY - r.top) / r.height }
  }

  function naDole(e: React.PointerEvent) {
    pokazivaci.current.set(e.pointerId, { x: e.clientX, y: e.clientY })
    pomereno.current = 0
  }

  function naPomeranje(e: React.PointerEvent) {
    const stara = pokazivaci.current.get(e.pointerId)
    if (!stara) return
    const sve = [...pokazivaci.current.entries()]
    if (sve.length === 2) {
      // Dva prsta: odnos rastojanja pre i posle pomeranja je faktor zuma.
      const druga = sve.find(([id]) => id !== e.pointerId)![1]
      const pre = Math.hypot(stara.x - druga.x, stara.y - druga.y)
      const posle = Math.hypot(e.clientX - druga.x, e.clientY - druga.y)
      if (pre > 0 && posle > 0) {
        const { ox, oy } = tacka(e)
        zumiraj(pre / posle, ox, oy)
      }
    } else {
      const dx = e.clientX - stara.x
      const dy = e.clientY - stara.y
      pomereno.current += Math.abs(dx) + Math.abs(dy)
      if (pomereno.current > 6) {
        if (!okvir.current!.hasPointerCapture(e.pointerId)) okvir.current!.setPointerCapture(e.pointerId)
        setPogled(p => ogranici({ ...p, x: p.x - dx * jedinica, y: p.y - dy * jedinica }))
      }
    }
    pokazivaci.current.set(e.pointerId, { x: e.clientX, y: e.clientY })
  }

  function naGore(e: React.PointerEvent) {
    pokazivaci.current.delete(e.pointerId)
  }

  function klik(id: string) {
    if (pomereno.current > 6) return
    onOblast(id)
  }

  const boja = (vlasnik: string | null, neutralna: number) =>
    stanje.igraci.find(p => p.id === vlasnik)?.boja ?? NEUTRALNE[neutralna]
  const prestonice = useMemo(() => new Set(stanje.igraci.map(p => p.prestonica)), [stanje.igraci])
  const krupno = pogled.w < 520 // neutralne značke i imena tek pri jakom zumu, inače prekriju mapu
  const r = 11 * jedinica
  const izabranaO = izabrana ? oblast(izabrana) : null

  return (
    <div className="relative h-full w-full select-none">
      <div ref={okvir} className="h-full w-full overflow-hidden rounded-[24px] touch-none"
        style={{ background: OKEAN, border: '2.5px solid #151515', boxShadow: '0 5px 0 #151515' }}
        onPointerDown={naDole} onPointerMove={naPomeranje} onPointerUp={naGore} onPointerCancel={naGore} onPointerLeave={naGore}
        onWheel={e => { const { ox, oy } = tacka(e); zumiraj(e.deltaY > 0 ? 1.15 : 1 / 1.15, ox, oy) }}>
        <svg viewBox={`${pogled.x} ${pogled.y} ${pogled.w} ${pogled.w * ODNOS}`} className="h-full w-full"
          preserveAspectRatio="xMidYMid meet" role="group" aria-label="Mapa sveta">
          <defs>
            <pattern id="talasi" width="80" height="28" patternUnits="userSpaceOnUse">
              <path d="M0 14c10-6 30-6 40 0s30 6 40 0" fill="none" stroke="#D5E3EA" strokeWidth="1.5" />
            </pattern>
          </defs>
          <rect x="0" y="0" width={SIRINA_MAPE} height={VISINA_MAPE} fill="url(#talasi)" />

          {OBLASTI.map(o => {
            const st = stanje.oblasti[o.id]
            return (
              <path key={o.id} d={o.d} fill={boja(st.vlasnik, o.boja)} stroke="#FFFFFF" strokeWidth={1.1}
                vectorEffect="non-scaling-stroke" strokeLinejoin="round" onClick={() => klik(o.id)}
                className="cursor-pointer transition-[fill] duration-500" aria-label={`${o.ime}, ${st.vojske}`}>
                <title>{o.ime}</title>
              </path>
            )
          })}

          {/* Imena država verzalom kao na infografici; manja se pojavljuju sa zumom. */}
          {OBLASTI.map(o => {
            const naEkranu = o.povrsina / (jedinica * jedinica)
            if (naEkranu < 9000 || krupno) return null
            const st = stanje.oblasti[o.id]
            return (
              <text key={`n-${o.id}`} x={o.x} y={o.y + 22 * jedinica} textAnchor="middle" pointerEvents="none"
                fontSize={Math.min(13, Math.max(8, Math.sqrt(naEkranu) / 14)) * jedinica} fontWeight={700} letterSpacing={0.6 * jedinica}
                fill={st.vlasnik ? '#FFFFFF' : '#151515'} opacity={st.vlasnik ? 0.9 : 0.55}>
                {o.ime.toUpperCase()}
              </text>
            )
          })}

          {/* Mete i izabrana preko ostalih, da se ivica ne izgubi ispod suseda. */}
          {mete.map(id => (
            <path key={`m-${id}`} d={oblast(id).d} fill="#151515" fillOpacity={0.08} stroke="#151515" strokeWidth={2.5}
              strokeDasharray="6 5" vectorEffect="non-scaling-stroke" onClick={() => klik(id)} className="cursor-pointer">
              <animate attributeName="stroke-dashoffset" from="0" to="22" dur="0.9s" repeatCount="indefinite" />
            </path>
          ))}
          {izabranaO && (
            <path d={izabranaO.d} fill="none" stroke="#FFD84D" strokeWidth={5} vectorEffect="non-scaling-stroke"
              strokeLinejoin="round" pointerEvents="none" />
          )}
          {izabranaO && mete.map(id => {
            const m = oblast(id)
            return <line key={`l-${id}`} x1={izabranaO.x} y1={izabranaO.y} x2={m.x} y2={m.y} stroke="#151515"
              strokeWidth={2} strokeDasharray="4 4" vectorEffect="non-scaling-stroke" pointerEvents="none" opacity={0.6} />
          })}

          {OBLASTI.map(o => {
            const st = stanje.oblasti[o.id]
            const vlasnik = stanje.igraci.find(p => p.id === st.vlasnik)
            const vidljiva = vlasnik || krupno || mete.includes(o.id)
            if (!vidljiva) return null
            return (
              <g key={`z-${o.id}`} onClick={() => klik(o.id)} className="cursor-pointer">
                <circle cx={o.x} cy={o.y + r * 0.18} r={r} fill="#151515" />
                <circle cx={o.x} cy={o.y} r={r} fill={vlasnik?.boja ?? '#FFFFFF'} stroke="#151515" strokeWidth={r * 0.16} />
                <text x={o.x} y={o.y + r * 0.36} textAnchor="middle" fontSize={r * 1.05} fontStyle="italic"
                  fontFamily="var(--font-archivo), 'Archivo Black', sans-serif" fill={vlasnik ? '#FFFFFF' : '#151515'}
                  pointerEvents="none">
                  {st.vojske}
                </text>
                {prestonice.has(o.id) && (
                  <path transform={`translate(${o.x - r * 0.7} ${o.y - r * 2.05}) scale(${r / 10})`}
                    d="M0 9V2l3.5 3L7 0l3.5 5L14 2v7z" fill="#FFD84D" stroke="#151515" strokeWidth={1.4} strokeLinejoin="round" />
                )}
                {krupno && (o.povrsina / (jedinica * jedinica) > 2200 || mete.includes(o.id) || o.id === izabrana) && (
                  <text x={o.x} y={o.y + r * 2.15} textAnchor="middle" fontSize={r * 0.95} fontWeight={700} fill="#151515"
                    stroke="#F3F0E6" strokeWidth={r * 0.28} paintOrder="stroke" pointerEvents="none">
                    {o.ime}
                  </text>
                )}
              </g>
            )
          })}
        </svg>
      </div>

      <div className="absolute right-3 top-3 flex flex-col gap-2">
        {[
          { natpis: 'Uvećaj', znak: '+', radnja: () => zumiraj(1 / 1.5) },
          { natpis: 'Umanji', znak: '−', radnja: () => zumiraj(1.5) },
          { natpis: 'Ceo svet', znak: '⤢', radnja: () => setPogled({ x: 0, y: 0, w: SIRINA_MAPE }) },
        ].map(d => (
          <button key={d.natpis} onClick={d.radnja} aria-label={d.natpis} title={d.natpis}
            className="w-11 h-11 grid place-items-center rounded-full bg-white text-[20px] font-bold"
            style={{ border: '2px solid #151515', boxShadow: '0 3px 0 #151515' }}>
            {d.znak}
          </button>
        ))}
      </div>
    </div>
  )
}
