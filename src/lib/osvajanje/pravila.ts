// Osvajanje sveta: mapa država, pravila i botovi bez spoljnih zavisnosti.
// Test ga uvozi direktno kroz Node (type stripping), a iOS
// (Pravila.swift) i Android (Pravila.kt) su njegovi verni prevodi. Pravila u
// rečima: docs/OSVAJANJE-PRAVILA.md.

import svet from './svet.json' with { type: 'json' }

// ── Mapa ─────────────────────────────────────────────────────────────────────
// Države sveta iz Natural Earth (alati/napravi-mapu.mjs → svet.json). Region je
// grupa država sa bonusom kao kontinent u Risku; veze su kopnene granice i more.

export type Region = { id: string; ime: string; bonus: number }

/** Država sa tačkom za natpis i SVG putanjom u koordinatama mape SIRINA_MAPE × VISINA_MAPE. */
export type Oblast = { id: string; ime: string; region: string; x: number; y: number; boja: number; povrsina: number; d: string }

export const SIRINA_MAPE: number = svet.sirina
export const VISINA_MAPE: number = svet.visina
export const REGIONI: Region[] = svet.regioni
export const OBLASTI: Oblast[] = svet.drzave
export const VEZE: [string, string][] = svet.veze as [string, string][]

const SUSEDI: Record<string, string[]> = {}
for (const [a, b] of VEZE) {
  ;(SUSEDI[a] ??= []).push(b)
  ;(SUSEDI[b] ??= []).push(a)
}

/** @example susedi('SRB') // ['BGR', 'BIH', 'HRV', 'HUN', 'MKD', 'MNE', 'ROU', …] */
export function susedi(oblastId: string): string[] {
  return SUSEDI[oblastId] ?? []
}

const PO_ID = new Map(OBLASTI.map(o => [o.id, o]))
export function oblast(id: string): Oblast {
  return PO_ID.get(id)!
}

// ── Konstante pravila ────────────────────────────────────────────────────────

export const POCETNE_VOJSKE_PRESTONICE = 5
export const POCETNIH_DRZAVA = 6
export const POCETNE_VOJSKE_DRZAVE = 2
export const NEUTRALNE_VOJSKE = 1
export const NAJMANJE_POJACANJA = 3
export const TERITORIJA_PO_VOJSCI = 3
export const BITAKA_PO_POTEZU = 8
export const PROBOJ_SVAKIH = 3
export const PROBOJ_BONUS = 2
export const PLEN_PRESTONICE = 5
export const POENI_PO_OBLASTI = 10
export const POENI_PO_BONUSU = 10
export const POENI_PRESTONICA = 20
export const SEKUNDI_PO_PITANJU = 15

export const TEZINE = { lako: 0.5, normalno: 0.62, tesko: 0.75 } as const
export type Tezina = keyof typeof TEZINE

// ── Stanje ───────────────────────────────────────────────────────────────────

export type Igrac = {
  id: string
  ime: string
  boja: string
  covek: boolean
  prestonica: string
  ispao: boolean
}

export type StanjeOblasti = { vlasnik: string | null; vojske: number }

export type Faza = 'snabdevanje' | 'raspored' | 'napad' | 'kraj'

export type Stanje = {
  igraci: Igrac[]
  oblasti: Record<string, StanjeOblasti>
  krug: number
  ukupnoKrugova: number
  naPotezu: number
  faza: Faza
  zaRaspored: number
  bitaka: number
  niz: number
  utvrdjeno: boolean
  tacnostBota: number
}

/** Deterministički generator (mulberry32), da partija može da se ponovi u testu. */
export function napraviSlucajno(seme: number): () => number {
  let a = seme >>> 0
  return () => {
    a = (a + 0x6d2b79f5) >>> 0
    let t = a
    t = Math.imul(t ^ (t >>> 15), t | 1)
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

const IGRACI_PODRAZUMEVANO = [
  { id: 'ti', ime: 'Ti', boja: '#12907E', covek: true },
  { id: 'mimi', ime: 'Mimi', boja: '#FF5FA2', covek: false },
  { id: 'zig', ime: 'Zig', boja: '#6D4BC9', covek: false },
]

/**
 * Nova partija: prestonice u različitim regionima, po šest država oko njih, ostalo neutralno.
 *
 * @example napraviPartiju({ krugova: 10, tezina: 'normalno', slucajno: napraviSlucajno(7) })
 */
export function napraviPartiju(opcije: { krugova: number; tezina: Tezina; slucajno: () => number; ime?: string }): Stanje {
  const { krugova, tezina, slucajno } = opcije
  // Fisher–Yates: sort sa nasumičnim poređenjem je pristrasan.
  const regioni = [...REGIONI]
  for (let i = regioni.length - 1; i > 0; i--) {
    const j = Math.floor(slucajno() * (i + 1))
    ;[regioni[i], regioni[j]] = [regioni[j], regioni[i]]
  }
  const oblasti: Record<string, StanjeOblasti> = {}
  for (const o of OBLASTI) oblasti[o.id] = { vlasnik: null, vojske: NEUTRALNE_VOJSKE }

  const igraci: Igrac[] = []
  for (const p of IGRACI_PODRAZUMEVANO) {
    // Prestonica je država sa bar 3 suseda (ne ostrvo), u regionu koji niko drugi nema.
    const region = regioni.find(r => !igraci.some(x => oblast(x.prestonica).region === r.id)
      && OBLASTI.some(o => o.region === r.id && susedi(o.id).length >= 3 && oblasti[o.id].vlasnik === null))!
    const kandidati = OBLASTI.filter(o => o.region === region.id && susedi(o.id).length >= 3 && oblasti[o.id].vlasnik === null)
    const prestonica = kandidati[Math.floor(slucajno() * kandidati.length)].id
    igraci.push({ ...p, ime: p.covek && opcije.ime ? opcije.ime : p.ime, prestonica, ispao: false })
    // Početni posed: prestonica i najbliže slobodne države po vezama (pretraga u širinu).
    const posed = [prestonica]
    const red = [prestonica]
    const vidjeno = new Set(red)
    while (red.length && posed.length < POCETNIH_DRZAVA) {
      for (const n of susedi(red.shift()!)) {
        if (vidjeno.has(n)) continue
        vidjeno.add(n)
        red.push(n)
        if (oblasti[n].vlasnik === null && posed.length < POCETNIH_DRZAVA) posed.push(n)
      }
    }
    for (const id of posed) oblasti[id] = { vlasnik: p.id, vojske: id === prestonica ? POCETNE_VOJSKE_PRESTONICE : POCETNE_VOJSKE_DRZAVE }
  }
  return {
    igraci, oblasti, krug: 1, ukupnoKrugova: krugova, naPotezu: 0, faza: 'snabdevanje',
    zaRaspored: 0, bitaka: 0, niz: 0, utvrdjeno: false, tacnostBota: TEZINE[tezina],
  }
}

export function trenutni(s: Stanje): Igrac {
  return s.igraci[s.naPotezu]
}

export function oblastiIgraca(s: Stanje, igracId: string): string[] {
  return OBLASTI.filter(o => s.oblasti[o.id].vlasnik === igracId).map(o => o.id)
}

/** Zbir bonusa regiona koje igrač drži u celosti. */
export function bonusRegiona(s: Stanje, igracId: string): number {
  return REGIONI
    .filter(r => OBLASTI.filter(o => o.region === r.id).every(o => s.oblasti[o.id].vlasnik === igracId))
    .reduce((zbir, r) => zbir + r.bonus, 0)
}

/** @example pojacanja(s, 'ti', true) // 3 na početku (6 država / 3 = 2, najmanje 3) */
export function pojacanja(s: Stanje, igracId: string, tacno: boolean): number {
  const puno = Math.max(NAJMANJE_POJACANJA, Math.floor(oblastiIgraca(s, igracId).length / TERITORIJA_PO_VOJSCI)) + bonusRegiona(s, igracId)
  return tacno ? puno : Math.max(1, Math.floor(puno / 2))
}

// ── Potez ────────────────────────────────────────────────────────────────────

/** Ishod pitanja za snabdevanje: prelazak u raspored. */
export function snabdevanje(s: Stanje, tacno: boolean): Stanje {
  if (s.faza !== 'snabdevanje') return s
  return { ...s, faza: 'raspored', zaRaspored: pojacanja(s, trenutni(s).id, tacno) }
}

/** Jedna vojska na svoju oblast. Kad se sve rasporede, počinje napad. */
export function rasporedi(s: Stanje, oblastId: string): Stanje {
  if (s.faza !== 'raspored' || s.zaRaspored <= 0) return s
  if (s.oblasti[oblastId]?.vlasnik !== trenutni(s).id) return s
  const oblasti = { ...s.oblasti, [oblastId]: { ...s.oblasti[oblastId], vojske: s.oblasti[oblastId].vojske + 1 } }
  const ostalo = s.zaRaspored - 1
  return { ...s, oblasti, zaRaspored: ostalo, faza: ostalo === 0 ? 'napad' : 'raspored' }
}

/** Mete u koje se može napasti iz date oblasti. */
export function mete(s: Stanje, odakle: string): string[] {
  const izvor = s.oblasti[odakle]
  if (s.faza !== 'napad' || s.bitaka >= BITAKA_PO_POTEZU) return []
  if (!izvor || izvor.vlasnik !== trenutni(s).id || izvor.vojske < 2) return []
  return susedi(odakle).filter(id => s.oblasti[id].vlasnik !== izvor.vlasnik)
}

export function mozeDaNapada(s: Stanje): boolean {
  return oblastiIgraca(s, trenutni(s).id).some(id => mete(s, id).length > 0)
}

export type Odgovor = { tacan: boolean; ms: number }

export type Ishod = {
  gubitakNapadaca: number
  gubitakBranioca: number
  osvojeno: boolean
  proboj: boolean
  plen: boolean
}

/**
 * Razrešava bitku. Branilac je `null` kad je oblast neutralna.
 *
 * @example razresiBitku(s, 'SRB', 'BGR', { tacan: true, ms: 4000 }, null)
 */
export function razresiBitku(s: Stanje, odakle: string, kuda: string, napadac: Odgovor, branilac: Odgovor | null): { stanje: Stanje; ishod: Ishod } {
  if (!mete(s, odakle).includes(kuda)) throw new Error(`Napad ${odakle} → ${kuda} nije dozvoljen`)
  const izvor = s.oblasti[odakle]
  const meta = s.oblasti[kuda]

  let gubitakNapadaca = 0
  let gubitakBranioca = 0
  if (meta.vlasnik === null || branilac === null) {
    if (napadac.tacan) gubitakBranioca = 1
    else gubitakNapadaca = 1
  } else if (napadac.tacan && !branilac.tacan) {
    gubitakBranioca = 2
  } else if (!napadac.tacan && branilac.tacan) {
    gubitakNapadaca = 2
  } else if (napadac.tacan && branilac.tacan) {
    // Neresen odgovor rešava brzina; jednako vreme ide braniocu.
    if (napadac.ms < branilac.ms) gubitakBranioca = 1
    else gubitakNapadaca = 1
  } else {
    gubitakNapadaca = 1
    gubitakBranioca = 1
  }

  // Napadač uvek zadržava bar jednu vojsku kod kuće.
  const vojskeNapadaca = Math.max(1, izvor.vojske - gubitakNapadaca)
  const vojskeBranioca = Math.max(0, meta.vojske - gubitakBranioca)
  const oblasti = { ...s.oblasti }
  const osvojeno = vojskeBranioca === 0
  let niz = s.niz
  let proboj = false
  let plen = false

  if (osvojeno) {
    const prelazi = vojskeNapadaca - 1
    niz += 1
    proboj = niz % PROBOJ_SVAKIH === 0
    plen = meta.vlasnik !== null && s.igraci.some(p => p.prestonica === kuda && p.id === meta.vlasnik)
    oblasti[odakle] = { ...izvor, vojske: 1 }
    oblasti[kuda] = {
      vlasnik: izvor.vlasnik,
      vojske: Math.max(1, prelazi) + (proboj ? PROBOJ_BONUS : 0) + (plen ? PLEN_PRESTONICE : 0),
    }
  } else {
    oblasti[odakle] = { ...izvor, vojske: vojskeNapadaca }
    oblasti[kuda] = { ...meta, vojske: vojskeBranioca }
  }

  const igraci = s.igraci.map(p => (!p.ispao && OBLASTI.every(o => oblasti[o.id].vlasnik !== p.id) ? { ...p, ispao: true } : p))
  return {
    stanje: { ...s, oblasti, igraci, bitaka: s.bitaka + 1, niz },
    ishod: { gubitakNapadaca: izvor.vojske - vojskeNapadaca, gubitakBranioca: meta.vojske - vojskeBranioca, osvojeno, proboj, plen },
  }
}

/** Jednom po potezu: vojske između dve susedne svoje oblasti, u izvoru ostaje 1. */
export function utvrdi(s: Stanje, odakle: string, kuda: string, broj: number): Stanje {
  const id = trenutni(s).id
  const a = s.oblasti[odakle]
  const b = s.oblasti[kuda]
  if (s.faza !== 'napad' || s.utvrdjeno) return s
  if (a?.vlasnik !== id || b?.vlasnik !== id || !susedi(odakle).includes(kuda)) return s
  const n = Math.min(broj, a.vojske - 1)
  if (n <= 0) return s
  return {
    ...s,
    utvrdjeno: true,
    oblasti: { ...s.oblasti, [odakle]: { ...a, vojske: a.vojske - n }, [kuda]: { ...b, vojske: b.vojske + n } },
  }
}

/** Kraj poteza: sledeći živi igrač, novi krug ili kraj partije. */
export function zavrsiPotez(s: Stanje): Stanje {
  if (s.faza === 'kraj') return s
  const zivi = s.igraci.filter(p => !p.ispao)
  if (zivi.length <= 1) return { ...s, faza: 'kraj' }
  let sledeci = s.naPotezu
  let krug = s.krug
  do {
    sledeci = (sledeci + 1) % s.igraci.length
    if (sledeci === 0) krug += 1
  } while (s.igraci[sledeci].ispao)
  if (krug > s.ukupnoKrugova) return { ...s, faza: 'kraj' }
  return { ...s, naPotezu: sledeci, krug, faza: 'snabdevanje', zaRaspored: 0, bitaka: 0, niz: 0, utvrdjeno: false }
}

export function poeni(s: Stanje, igracId: string): number {
  const moje = oblastiIgraca(s, igracId)
  const vojske = moje.reduce((zbir, id) => zbir + s.oblasti[id].vojske, 0)
  const igrac = s.igraci.find(p => p.id === igracId)
  const prestonica = igrac && s.oblasti[igrac.prestonica].vlasnik === igracId ? POENI_PRESTONICA : 0
  return moje.length * POENI_PO_OBLASTI + vojske + bonusRegiona(s, igracId) * POENI_PO_BONUSU + prestonica
}

/** Igrači od prvog do poslednjeg po poenima. */
export function poredak(s: Stanje): { igrac: Igrac; poeni: number }[] {
  return s.igraci.map(igrac => ({ igrac, poeni: poeni(s, igrac.id) })).sort((a, b) => b.poeni - a.poeni)
}

// ── Botovi ───────────────────────────────────────────────────────────────────

/** Bot „odgovara”: tačan sa verovatnoćom jačine, vreme 3 do 12 s. */
export function botOdgovor(s: Stanje, slucajno: () => number): Odgovor {
  return { tacan: slucajno() < s.tacnostBota, ms: 3000 + Math.floor(slucajno() * 9000) }
}

/** Granična oblast bota sa najviše tuđih suseda dobija pojačanje. */
export function botRasporedi(s: Stanje): Stanje {
  let st = s
  while (st.faza === 'raspored') {
    const id = trenutni(st).id
    const moje = oblastiIgraca(st, id)
    const pretnja = (o: string) => susedi(o).filter(n => st.oblasti[n].vlasnik !== id).length
    const cilj = moje.reduce((najbolja, o) => (pretnja(o) > pretnja(najbolja) ? o : najbolja), moje[0])
    st = rasporedi(st, cilj)
  }
  return st
}

/**
 * Sledeći napad bota ili `null` kad staje: napada samo uz brojčanu prednost,
 * neutralne i regione koje skoro drži pretpostavlja ostalima.
 */
export function botSledeciNapad(s: Stanje): { odakle: string; kuda: string } | null {
  const id = trenutni(s).id
  let najbolji: { odakle: string; kuda: string; ocena: number } | null = null
  for (const odakle of oblastiIgraca(s, id)) {
    for (const kuda of mete(s, odakle)) {
      const prednost = s.oblasti[odakle].vojske - s.oblasti[kuda].vojske
      if (prednost < 1) continue
      const reg = oblast(kuda).region
      const fali = OBLASTI.filter(o => o.region === reg && s.oblasti[o.id].vlasnik !== id).length
      const ocena = prednost * 2 + (s.oblasti[kuda].vlasnik === null ? 3 : 0) + (fali === 1 ? 5 : 0)
      if (!najbolji || ocena > najbolji.ocena) najbolji = { odakle, kuda, ocena }
    }
  }
  return najbolji ? { odakle: najbolji.odakle, kuda: najbolji.kuda } : null
}
