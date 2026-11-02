// Osvajanje sveta: mapa, pravila i botovi u jednom fajlu bez spoljnih zavisnosti.
// Namerno samostalan: test ga uvozi direktno kroz Node (type stripping), a iOS
// (Pravila.swift) i Android (Pravila.kt) su njegovi verni prevodi. Pravila u
// rečima: docs/OSVAJANJE-PRAVILA.md.

// ── Mapa ─────────────────────────────────────────────────────────────────────

export type Kontinent = { id: string; ime: string; bonus: number }

export const KONTINENTI: Kontinent[] = [
  { id: 'sam', ime: 'Severna Amerika', bonus: 3 },
  { id: 'jam', ime: 'Južna Amerika', bonus: 2 },
  { id: 'evr', ime: 'Evropa', bonus: 3 },
  { id: 'afr', ime: 'Afrika', bonus: 3 },
  { id: 'azi', ime: 'Azija', bonus: 4 },
  { id: 'oke', ime: 'Okeanija', bonus: 2 },
]

/** Oblast sa središtem u koordinatama mape 1040 × 580. */
export type Oblast = { id: string; ime: string; kontinent: string; x: number; y: number }

export const OBLASTI: Oblast[] = [
  { id: 'aljaska', ime: 'Aljaska', kontinent: 'sam', x: 80, y: 90 },
  { id: 'kanada', ime: 'Kanada', kontinent: 'sam', x: 190, y: 80 },
  { id: 'sad', ime: 'SAD', kontinent: 'sam', x: 200, y: 190 },
  { id: 'meksiko', ime: 'Meksiko', kontinent: 'sam', x: 180, y: 295 },
  { id: 'kolumbija', ime: 'Kolumbija', kontinent: 'jam', x: 270, y: 360 },
  { id: 'peru', ime: 'Peru', kontinent: 'jam', x: 250, y: 465 },
  { id: 'brazil', ime: 'Brazil', kontinent: 'jam', x: 360, y: 430 },
  { id: 'argentina', ime: 'Argentina', kontinent: 'jam', x: 330, y: 530 },
  { id: 'skandinavija', ime: 'Skandinavija', kontinent: 'evr', x: 480, y: 70 },
  { id: 'zap-evropa', ime: 'Zapadna Evropa', kontinent: 'evr', x: 430, y: 175 },
  { id: 'sre-evropa', ime: 'Srednja Evropa', kontinent: 'evr', x: 535, y: 165 },
  { id: 'balkan', ime: 'Balkan', kontinent: 'evr', x: 575, y: 260 },
  { id: 'sev-afrika', ime: 'Severna Afrika', kontinent: 'afr', x: 475, y: 310 },
  { id: 'zap-afrika', ime: 'Zapadna Afrika', kontinent: 'afr', x: 440, y: 415 },
  { id: 'ist-afrika', ime: 'Istočna Afrika', kontinent: 'afr', x: 570, y: 400 },
  { id: 'juz-afrika', ime: 'Južna Afrika', kontinent: 'afr', x: 520, y: 505 },
  { id: 'sibir', ime: 'Sibir', kontinent: 'azi', x: 720, y: 85 },
  { id: 'bliski-istok', ime: 'Bliski istok', kontinent: 'azi', x: 670, y: 285 },
  { id: 'indija', ime: 'Indija', kontinent: 'azi', x: 770, y: 335 },
  { id: 'kina', ime: 'Kina', kontinent: 'azi', x: 810, y: 210 },
  { id: 'japan', ime: 'Japan', kontinent: 'azi', x: 925, y: 150 },
  { id: 'indonezija', ime: 'Indonezija', kontinent: 'oke', x: 870, y: 400 },
  { id: 'australija', ime: 'Australija', kontinent: 'oke', x: 920, y: 505 },
  { id: 'novi-zeland', ime: 'Novi Zeland', kontinent: 'oke', x: 1000, y: 430 },
]

/** Veze između oblasti (neusmerene). Morske veze su obične veze. */
export const VEZE: [string, string][] = [
  ['aljaska', 'kanada'], ['aljaska', 'sibir'], ['aljaska', 'sad'], ['kanada', 'sad'], ['kanada', 'skandinavija'],
  ['sad', 'meksiko'], ['meksiko', 'kolumbija'],
  ['kolumbija', 'peru'], ['kolumbija', 'brazil'], ['peru', 'brazil'], ['peru', 'argentina'], ['brazil', 'argentina'],
  ['brazil', 'zap-afrika'],
  ['skandinavija', 'zap-evropa'], ['skandinavija', 'sre-evropa'], ['skandinavija', 'sibir'],
  ['zap-evropa', 'sre-evropa'], ['zap-evropa', 'sev-afrika'], ['sre-evropa', 'balkan'], ['sre-evropa', 'sibir'],
  ['balkan', 'bliski-istok'], ['balkan', 'sev-afrika'],
  ['sev-afrika', 'zap-afrika'], ['sev-afrika', 'ist-afrika'], ['sev-afrika', 'bliski-istok'],
  ['zap-afrika', 'ist-afrika'], ['zap-afrika', 'juz-afrika'], ['ist-afrika', 'juz-afrika'], ['ist-afrika', 'bliski-istok'],
  ['bliski-istok', 'indija'], ['bliski-istok', 'sibir'], ['sibir', 'kina'], ['sibir', 'japan'],
  ['kina', 'indija'], ['kina', 'japan'], ['kina', 'indonezija'], ['indija', 'indonezija'],
  ['indonezija', 'australija'], ['australija', 'novi-zeland'], ['indonezija', 'novi-zeland'],
]

const SUSEDI: Record<string, string[]> = {}
for (const [a, b] of VEZE) {
  ;(SUSEDI[a] ??= []).push(b)
  ;(SUSEDI[b] ??= []).push(a)
}

/** @example susedi('balkan') // ['sre-evropa', 'bliski-istok', 'sev-afrika'] */
export function susedi(oblastId: string): string[] {
  return SUSEDI[oblastId] ?? []
}

// ── Konstante pravila ────────────────────────────────────────────────────────

export const POCETNE_VOJSKE_PRESTONICE = 4
export const NEUTRALNE_VOJSKE = 1
export const NAJMANJE_POJACANJA = 3
export const BITAKA_PO_POTEZU = 6
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
 * Nova partija: prestonice na različitim kontinentima, ostalo neutralno.
 *
 * @example napraviPartiju({ krugova: 10, tezina: 'normalno', slucajno: napraviSlucajno(7) })
 */
export function napraviPartiju(opcije: { krugova: number; tezina: Tezina; slucajno: () => number; ime?: string }): Stanje {
  const { krugova, tezina, slucajno } = opcije
  // Fisher–Yates: sort sa nasumičnim poređenjem je pristrasan.
  const kontinenti = [...KONTINENTI]
  for (let i = kontinenti.length - 1; i > 0; i--) {
    const j = Math.floor(slucajno() * (i + 1))
    ;[kontinenti[i], kontinenti[j]] = [kontinenti[j], kontinenti[i]]
  }
  const igraci: Igrac[] = IGRACI_PODRAZUMEVANO.map((p, i) => {
    const kandidati = OBLASTI.filter(o => o.kontinent === kontinenti[i].id)
    const prestonica = kandidati[Math.floor(slucajno() * kandidati.length)].id
    return { ...p, ime: p.covek && opcije.ime ? opcije.ime : p.ime, prestonica, ispao: false }
  })
  const oblasti: Record<string, StanjeOblasti> = {}
  for (const o of OBLASTI) oblasti[o.id] = { vlasnik: null, vojske: NEUTRALNE_VOJSKE }
  for (const p of igraci) oblasti[p.prestonica] = { vlasnik: p.id, vojske: POCETNE_VOJSKE_PRESTONICE }
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

/** Zbir bonusa kontinenata koje igrač drži u celosti. */
export function bonusKontinenata(s: Stanje, igracId: string): number {
  return KONTINENTI
    .filter(k => OBLASTI.filter(o => o.kontinent === k.id).every(o => s.oblasti[o.id].vlasnik === igracId))
    .reduce((zbir, k) => zbir + k.bonus, 0)
}

/** @example pojacanja(s, 'ti', true) // 3 na početku */
export function pojacanja(s: Stanje, igracId: string, tacno: boolean): number {
  const puno = Math.max(NAJMANJE_POJACANJA, Math.floor(oblastiIgraca(s, igracId).length / 2)) + bonusKontinenata(s, igracId)
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
 * @example razresiBitku(s, 'balkan', 'bliski-istok', { tacan: true, ms: 4000 }, null)
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
  return moje.length * POENI_PO_OBLASTI + vojske + bonusKontinenata(s, igracId) * POENI_PO_BONUSU + prestonica
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
 * neutralne i kontinente koje skoro drži pretpostavlja ostalima.
 */
export function botSledeciNapad(s: Stanje): { odakle: string; kuda: string } | null {
  const id = trenutni(s).id
  let najbolji: { odakle: string; kuda: string; ocena: number } | null = null
  for (const odakle of oblastiIgraca(s, id)) {
    for (const kuda of mete(s, odakle)) {
      const prednost = s.oblasti[odakle].vojske - s.oblasti[kuda].vojske
      if (prednost < 1) continue
      const kont = OBLASTI.find(o => o.id === kuda)!.kontinent
      const fali = OBLASTI.filter(o => o.kontinent === kont && s.oblasti[o.id].vlasnik !== id).length
      const ocena = prednost * 2 + (s.oblasti[kuda].vlasnik === null ? 3 : 0) + (fali === 1 ? 5 : 0)
      if (!najbolji || ocena > najbolji.ocena) najbolji = { odakle, kuda, ocena }
    }
  }
  return najbolji ? { odakle: najbolji.odakle, kuda: najbolji.kuda } : null
}
