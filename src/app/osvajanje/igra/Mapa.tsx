'use client'

import { KONTINENTI, OBLASTI, VEZE, type Stanje } from '@/lib/osvajanje/pravila'

const SIRINA = 1080
const VISINA = 600
const R = 44
const POZICIJA = new Map(OBLASTI.map(o => [o.id, o]))

// Natpisi kontinenata stoje uz ivicu svoje grupe, ne preko oblasti.
const NATPIS: Record<string, { x: number; y: number }> = {
  sam: { x: 20, y: 398 }, jam: { x: 120, y: 585 }, evr: { x: 560, y: 30 },
  afr: { x: 600, y: 560 }, azi: { x: 840, y: 40 }, oke: { x: 960, y: 580 },
}

function sesougao(x: number, y: number, r: number): string {
  return Array.from({ length: 6 }, (_, i) => {
    const ugao = (Math.PI / 3) * i - Math.PI / 6
    return `${(x + r * Math.cos(ugao)).toFixed(1)},${(y + r * Math.sin(ugao)).toFixed(1)}`
  }).join(' ')
}

/**
 * Mapa sveta: šestougaone oblasti sa brojem vojski, veze kao linije.
 *
 * @example <Mapa stanje={s} izabrana="balkan" mete={['bliski-istok']} onOblast={id => …} />
 */
export function Mapa({ stanje, izabrana, mete, onOblast }: {
  stanje: Stanje
  izabrana: string | null
  mete: string[]
  onOblast: (id: string) => void
}) {
  const boja = (vlasnik: string | null) => stanje.igraci.find(p => p.id === vlasnik)?.boja ?? '#FFFFFF'
  const prestonice = new Set(stanje.igraci.map(p => p.prestonica))

  return (
    <svg viewBox={`0 0 ${SIRINA} ${VISINA}`} className="w-full h-auto select-none" role="group" aria-label="Mapa sveta">
      {KONTINENTI.map(k => (
        <text key={k.id} x={NATPIS[k.id].x} y={NATPIS[k.id].y} fontSize="13" fontWeight="700"
          letterSpacing="1.5" fill="#6F6C66">
          {k.ime.toUpperCase()} +{k.bonus}
        </text>
      ))}

      {VEZE.map(([a, b]) => {
        const p = POZICIJA.get(a)!
        const q = POZICIJA.get(b)!
        const morska = Math.hypot(p.x - q.x, p.y - q.y) > 150
        return (
          <line key={a + b} x1={p.x} y1={p.y} x2={q.x} y2={q.y} stroke="#151515" strokeOpacity={morska ? 0.35 : 0.55}
            strokeWidth={morska ? 2 : 3} strokeDasharray={morska ? '6 7' : undefined} strokeLinecap="round" />
        )
      })}

      {OBLASTI.map(o => {
        const st = stanje.oblasti[o.id]
        const jeMeta = mete.includes(o.id)
        const jeIzabrana = izabrana === o.id
        const tamna = st.vlasnik !== null
        return (
          <g key={o.id} onClick={() => onOblast(o.id)} role="button" tabIndex={0}
            aria-label={`${o.ime}, ${st.vojske} vojski${st.vlasnik ? '' : ', neutralno'}`}
            onKeyDown={e => { if (e.key === 'Enter' || e.key === ' ') onOblast(o.id) }}
            className="cursor-pointer outline-none">
            {(jeIzabrana || jeMeta) && (
              <polygon points={sesougao(o.x, o.y, R + 9)} fill="none" stroke={jeIzabrana ? '#FFD84D' : '#151515'}
                strokeWidth={jeIzabrana ? 7 : 3} strokeDasharray={jeMeta ? '7 6' : undefined}>
                {jeMeta && <animate attributeName="stroke-dashoffset" from="0" to="26" dur="1s" repeatCount="indefinite" />}
              </polygon>
            )}
            <polygon points={sesougao(o.x, o.y + 5, R)} fill="#151515" />
            <polygon points={sesougao(o.x, o.y, R)} fill={boja(st.vlasnik)} stroke="#151515" strokeWidth="3" />
            <text x={o.x} y={o.y + 9} textAnchor="middle" fontSize="27" fontStyle="italic"
              fontFamily="var(--font-archivo), 'Archivo Black', sans-serif" fill={tamna ? '#FFFFFF' : '#151515'}>
              {st.vojske}
            </text>
            {prestonice.has(o.id) && (
              <polygon points={`${o.x - 10},${o.y - 22} ${o.x - 10},${o.y - 31} ${o.x - 5},${o.y - 26} ${o.x},${o.y - 33} ${o.x + 5},${o.y - 26} ${o.x + 10},${o.y - 31} ${o.x + 10},${o.y - 22}`}
                fill="#FFD84D" stroke="#151515" strokeWidth="2" strokeLinejoin="round" />
            )}
            <text x={o.x} y={o.y + R + 21} textAnchor="middle" fontSize="13" fontWeight="700" fill="#151515"
              stroke="#F3F0E6" strokeWidth="4" paintOrder="stroke" strokeLinejoin="round">
              {o.ime}
            </text>
          </g>
        )
      })}
    </svg>
  )
}
