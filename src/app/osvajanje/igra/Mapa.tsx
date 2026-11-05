'use client'

import { useEffect, useMemo, useRef, useState } from 'react'
import { MORE, OBLASTI, SIRINA_MAPE, VISINA_MAPE, oblast, type Stanje } from '@/lib/osvajanje/pravila'

type Pogled = { x: number; y: number; w: number }
type Velicina = { w: number; h: number }

const NAJMANJI_W = 110 // najjači zum: Luksemburg i Liban postanu dovoljno veliki za prst
// Neutralne države su svetle (susedi uvek različiti, kao na infografici), da osvojene
// u punoj boji igrača odmah iskoče.
const NEUTRALNE = ['#D3EEE0', '#FDF0F4', '#FFF5E0', '#E1E1F3', '#EBF1FA']
const OKEAN = '#E3EDF2'
const MORSKI_PUT = '#4F7486'

/** Pogled uvek ispunjava ceo okvir; van mape se ne pomera, a kad je mapa uža od okvira, centrira se. */
function ogranici(p: Pogled, odnos: number): Pogled {
  const w = Math.min(SIRINA_MAPE, Math.max(NAJMANJI_W, p.w))
  const h = w * odnos
  const x = Math.min(SIRINA_MAPE - w, Math.max(0, p.x))
  const y = h >= VISINA_MAPE ? (VISINA_MAPE - h) / 2 : Math.min(VISINA_MAPE - h, Math.max(0, p.y))
  return { w, x, y }
}

/** Kadar koji obuhvata tačke (država i njene mete) sa vazduhom oko njih. */
function kadar(tacke: { x: number; y: number }[], odnos: number, sirinaPx: number): Pogled {
  const xs = tacke.map(t => t.x)
  const ys = tacke.map(t => t.y)
  const [x0, x1, y0, y1] = [Math.min(...xs), Math.max(...xs), Math.min(...ys), Math.max(...ys)]
  const najmanji = sirinaPx < 700 ? 420 : 640
  const w = Math.max(najmanji, (x1 - x0) * 1.5 + 140, ((y1 - y0) * 1.5 + 140) / odnos)
  return ogranici({ w, x: (x0 + x1) / 2 - w / 2, y: (y0 + y1) / 2 - (w * odnos) / 2 }, odnos)
}

/**
 * Mapa sveta po državama sa morskim putevima: zum točkićem, prstima, dvoklikom ili
 * dugmićima, pomeranje prevlačenjem. Izbor države sam uokviri nju i njene mete.
 *
 * @example <Mapa stanje={s} izabrana="BRA" mete={['ARG', 'SEN']} fokus="BRA" onOblast={id => …} />
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
  const [velicina, setVelicina] = useState<Velicina>(() =>
    typeof window === 'undefined' ? { w: 800, h: 600 } : { w: Math.min(window.innerWidth, 1600), h: window.innerHeight * 0.6 })
  const odnos = velicina.h / velicina.w
  const [pogled, setPogled] = useState<Pogled>({ x: 0, y: 0, w: SIRINA_MAPE })
  const pokazivaci = useRef(new Map<number, { x: number; y: number }>())
  const pomereno = useRef(0)

  useEffect(() => {
    const el = okvir.current
    if (!el) return
    const ro = new ResizeObserver(([e]) => setVelicina({ w: e.contentRect.width, h: e.contentRect.height }))
    ro.observe(el)
    return () => ro.disconnect()
  }, [])

  // Kadar se podešava tokom crtanja kad se promeni izbor ili fokus (React obrazac umesto efekta):
  // izabrana država sa metama staje cela u kadar, inače mapa dolazi do fokusa (prestonica, bitka).
  const tacke = izabrana && mete.length ? [izabrana, ...mete] : fokus ? [fokus] : []
  const kljucKadra = `${tacke.join(',')}|${Math.round(velicina.w)}x${Math.round(velicina.h)}`
  const [prethodniKadar, setPrethodniKadar] = useState('')
  if (tacke.length && kljucKadra !== prethodniKadar) {
    setPrethodniKadar(kljucKadra)
    setPogled(p => {
      if (tacke.length > 1) return kadar(tacke.map(oblast), odnos, velicina.w)
      const o = oblast(tacke[0])
      const w = velicina.w < 700 ? Math.min(p.w, 560) : Math.min(p.w, 1100)
      const h = w * odnos
      const unutra = o.x > p.x + w * 0.2 && o.x < p.x + w * 0.8 && o.y > p.y + h * 0.2 && o.y < p.y + h * 0.8
      return unutra && w === p.w ? ogranici(p, odnos) : ogranici({ w, x: o.x - w / 2, y: o.y - h / 2 }, odnos)
    })
  }

  const jedinica = pogled.w / velicina.w // koliko jedinica mape staje u jedan piksel ekrana

  function zumiraj(faktor: number, ox = 0.5, oy = 0.5) {
    setPogled(p => {
      const w = Math.min(SIRINA_MAPE, Math.max(NAJMANJI_W, p.w * faktor))
      return ogranici({ w, x: p.x + (p.w - w) * ox, y: p.y + (p.w - w) * odnos * oy }, odnos)
    })
  }

  function tacka(e: React.PointerEvent | React.WheelEvent | React.MouseEvent) {
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
      pomereno.current += 10
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
        setPogled(p => ogranici({ ...p, x: p.x - dx * jedinica, y: p.y - dy * jedinica }, odnos))
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
  const aktivniPut = (a: string, b: string) => !!izabrana && ((a === izabrana && mete.includes(b)) || (b === izabrana && mete.includes(a)))

  return (
    <div className="relative h-full w-full select-none">
      <div ref={okvir} className="h-full w-full overflow-hidden rounded-[24px] touch-none"
        style={{ background: OKEAN, border: '1.5px solid #1A1B3A', boxShadow: 'var(--senka)' }}
        onPointerDown={naDole} onPointerMove={naPomeranje} onPointerUp={naGore} onPointerCancel={naGore} onPointerLeave={naGore}
        onDoubleClick={e => { const { ox, oy } = tacka(e); zumiraj(1 / 2, ox, oy) }}
        onWheel={e => { const { ox, oy } = tacka(e); zumiraj(e.deltaY > 0 ? 1.15 : 1 / 1.15, ox, oy) }}>
        <svg viewBox={`${pogled.x} ${pogled.y} ${pogled.w} ${pogled.w * odnos}`} className="h-full w-full"
          preserveAspectRatio="xMidYMid meet" role="group" aria-label="Mapa sveta">
          <defs>
            <pattern id="talasi" width="80" height="28" patternUnits="userSpaceOnUse">
              <path d="M0 14c10-6 30-6 40 0s30 6 40 0" fill="none" stroke="#D5E3EA" strokeWidth="1.5" />
            </pattern>
          </defs>
          <rect x={-SIRINA_MAPE} y={-VISINA_MAPE} width={SIRINA_MAPE * 3} height={VISINA_MAPE * 3} fill="url(#talasi)" />

          {/* Morski putevi: isprekidane linije preko mora, kao u Risku. */}
          {MORE.map(([a, b, x1, y1, x2, y2]) => {
            const jak = aktivniPut(a, b)
            const stil = { stroke: jak ? '#1A1B3A' : MORSKI_PUT, strokeWidth: jak ? 3 : 1.8, strokeDasharray: jak ? '7 5' : '5 6', opacity: jak ? 1 : 0.75 }
            if (Math.abs(x1 - x2) > SIRINA_MAPE / 2) {
              // Put preko ivice karte (Aljaska–Čukotka): dva kraka ka ivicama.
              const [levo, desno] = x1 < x2 ? [[x1, y1], [x2, y2]] : [[x2, y2], [x1, y1]]
              return (
                <g key={`${a}-${b}`} pointerEvents="none">
                  <line x1={levo[0]} y1={levo[1]} x2={0} y2={levo[1] - 8} {...stil} vectorEffect="non-scaling-stroke" />
                  <line x1={desno[0]} y1={desno[1]} x2={SIRINA_MAPE} y2={desno[1] - 8} {...stil} vectorEffect="non-scaling-stroke" />
                </g>
              )
            }
            // Blago savijena linija, da se dva paralelna puta ne preklope.
            const mx = (x1 + x2) / 2 - (y2 - y1) * 0.12
            const my = (y1 + y2) / 2 + (x2 - x1) * 0.12
            return (
              <g key={`${a}-${b}`} pointerEvents="none">
                <path d={`M${x1} ${y1}Q${mx} ${my} ${x2} ${y2}`} fill="none" {...stil} strokeLinecap="round" vectorEffect="non-scaling-stroke" />
                <circle cx={x1} cy={y1} r={3 * jedinica} fill={stil.stroke} />
                <circle cx={x2} cy={y2} r={3 * jedinica} fill={stil.stroke} />
              </g>
            )
          })}

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
                fill={st.vlasnik ? '#FFFFFF' : '#1A1B3A'} opacity={st.vlasnik ? 0.9 : 0.55}>
                {o.ime.toUpperCase()}
              </text>
            )
          })}

          {/* Mete i izabrana preko ostalih, da se ivica ne izgubi ispod suseda. */}
          {mete.map(id => (
            <path key={`m-${id}`} d={oblast(id).d} fill="#1A1B3A" fillOpacity={0.08} stroke="#1A1B3A" strokeWidth={2.5}
              strokeDasharray="6 5" vectorEffect="non-scaling-stroke" onClick={() => klik(id)} className="cursor-pointer">
              <animate attributeName="stroke-dashoffset" from="0" to="22" dur="0.9s" repeatCount="indefinite" />
            </path>
          ))}
          {izabranaO && (
            <path d={izabranaO.d} fill="none" stroke="#FDC361" strokeWidth={5} vectorEffect="non-scaling-stroke"
              strokeLinejoin="round" pointerEvents="none" />
          )}

          {OBLASTI.map(o => {
            const st = stanje.oblasti[o.id]
            const vlasnik = stanje.igraci.find(p => p.id === st.vlasnik)
            const vidljiva = vlasnik || krupno || mete.includes(o.id)
            if (!vidljiva) return null
            return (
              <g key={`z-${o.id}`} onClick={() => klik(o.id)} className="cursor-pointer">
                <circle cx={o.x} cy={o.y + r * 0.18} r={r} fill="#1A1B3A" />
                <circle cx={o.x} cy={o.y} r={r} fill={vlasnik?.boja ?? '#FFFFFF'} stroke="#1A1B3A" strokeWidth={r * 0.16} />
                <text x={o.x} y={o.y + r * 0.36} textAnchor="middle" fontSize={r * 1.05} fontStyle="italic"
                  fontFamily="var(--font-archivo), 'Archivo Black', sans-serif" fill={vlasnik ? '#FFFFFF' : '#1A1B3A'}
                  pointerEvents="none">
                  {st.vojske}
                </text>
                {prestonice.has(o.id) && (
                  <path transform={`translate(${o.x - r * 0.7} ${o.y - r * 2.05}) scale(${r / 10})`}
                    d="M0 9V2l3.5 3L7 0l3.5 5L14 2v7z" fill="#FDC361" stroke="#1A1B3A" strokeWidth={1.4} strokeLinejoin="round" />
                )}
                {(krupno || mete.includes(o.id) || o.id === izabrana) && (o.povrsina / (jedinica * jedinica) > 2200 || mete.includes(o.id) || o.id === izabrana) && (
                  <text x={o.x} y={o.y + r * 2.15} textAnchor="middle" fontSize={r * 0.95} fontWeight={700} fill="#1A1B3A"
                    stroke="#F6F1E7" strokeWidth={r * 0.28} paintOrder="stroke" pointerEvents="none">
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
          { natpis: 'Uvećaj', znak: '+', radnja: () => zumiraj(1 / 1.6) },
          { natpis: 'Umanji', znak: '−', radnja: () => zumiraj(1.6) },
          { natpis: 'Ceo svet', znak: '⤢', radnja: () => setPogled(ogranici({ x: 0, y: 0, w: SIRINA_MAPE }, odnos)) },
        ].map(d => (
          <button key={d.natpis} onClick={d.radnja} aria-label={d.natpis} title={d.natpis}
            className="w-11 h-11 grid place-items-center rounded-full bg-white text-[20px] font-bold"
            style={{ border: '2px solid #1A1B3A', boxShadow: 'var(--senka)' }}>
            {d.znak}
          </button>
        ))}
      </div>

      <p className="absolute left-3 bottom-3 rounded-xl bg-white/90 px-3 py-2 text-[12px] font-semibold leading-tight"
        style={{ border: '1.5px solid #EDE5D5' }}>
        <svg width="26" height="8" className="inline mr-1.5 align-middle" aria-hidden><line x1="1" y1="4" x2="25" y2="4" stroke={MORSKI_PUT} strokeWidth="2" strokeDasharray="5 4" /></svg>
        morski put · napadaš samo susede
      </p>
    </div>
  )
}
