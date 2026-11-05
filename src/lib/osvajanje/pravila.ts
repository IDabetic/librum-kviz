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
/** Morski putevi: [a, b, x1, y1, x2, y2] sa tačkama obala, za crtanje isprekidane linije. */
export const MORE: [string, string, number, number, number, number][] = svet.more as [string, string, number, number, number, number][]

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
export const TERITORIJA_PO_VOJSCI = 2
/** Napada zaredom po potezu kad svako igra za sebe; u timu po igraču (tim = 2 igrača × 2). */
export const BITAKA_PO_POTEZU = 5
export const BITAKA_U_TIMU_PO_IGRACU = 2
/** Bitka za državu koju drži igrač: niz pitanja, odlučuju tačni pa brzina. */
export const PITANJA_U_BITCI = 5
/** Pobednik bitke od 5 pitanja dobija dodatne pomoći za ovu partiju. */
export const BONUS_POMOCI_POBEDNIKU = 2
/** Napadač koji izgubi bitku od 5 pitanja gubi ovoliko vojski (najmanje 1 ostaje kod kuće). */
export const GUBITAK_PORAZENOG_NAPADACA = 2
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
  /** Tim (vlasnik država). Svako za sebe: tim = id igrača. */
  tim: string
  /** Kapiten bira odbranu kontinenta; u timu je to član sa više tačnih odgovora na profilu. */
  kapiten: boolean
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
  /** Tajna misija po timu (id iz MISIJE) i meta misije „izbaci igrača”. */
  misije: Record<string, string>
  metaMisije: Record<string, string>
  /** Odbrana po kontinentu koji tim drži ceo, i krug kad je poslednji put menjana. */
  odbrane: Record<string, Odbrana>
  promenaOdbrane: Record<string, number>
  /** Tvrđava: krug u kom je kontinent već iskoristio „prvi poraz se ne računa”. */
  tvrdjava: Record<string, number>
  /** Tačni odgovori po timu u partiji (za misiju „25 tačnih”). */
  tacnih: Record<string, number>
  /** Tim koji je ispunio misiju (pobeda pre kraja krugova). */
  pobednik: string | null
  /** Dodatne pomoći po timu, osvojene u bitkama od 5 pitanja. */
  bonusPomoci: Record<string, number>
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
  { id: 'ti', ime: 'Ti', boja: '#23845C', covek: true },
  { id: 'mimi', ime: 'Mimi', boja: '#F8C7D6', covek: false },
  { id: 'zig', ime: 'Zig', boja: '#2C2D81', covek: false },
]

/**
 * Nova partija: prestonice u različitim regionima, po šest država oko njih, ostalo neutralno.
 *
 * @example napraviPartiju({ krugova: 10, tezina: 'normalno', slucajno: napraviSlucajno(7) })
 */
export function napraviPartiju(opcije: {
  krugova: number
  tezina: Tezina
  slucajno: () => number
  ime?: string
  /** Igrači (2 do 12); bez ovoga ti i dva bota, svako za sebe. */
  igraci?: { id: string; ime: string; boja: string; covek: boolean; tim?: string; kapiten?: boolean }[]
  /** Početni kontinent po timu (izbor „zmijom” u čekaonici). */
  pocetak?: Record<string, string>
  /** Tajne misije kao u Risku. */
  misije?: boolean
}): Stanje {
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
  const spisak = opcije.igraci ?? IGRACI_PODRAZUMEVANO
  for (const p of spisak) {
    const tim: string = ('tim' in p && typeof p.tim === 'string' && p.tim) || p.id
    const kontinent = opcije.pocetak?.[tim]
    const slobodna = (o: Oblast) => susedi(o.id).length >= 3 && oblasti[o.id].vlasnik === null
    // Prestonica: na izabranom kontinentu, inače u regionu koji niko drugi nema; država sa
    // bar 3 suseda (ne ostrvo). Rezerva je bilo koja slobodna država kad se mapa napuni.
    let kandidati = kontinent
      ? OBLASTI.filter(o => kontinentOblasti(o.id).id === kontinent && slobodna(o))
      : (() => {
          const region = regioni.find(r => !igraci.some(x => oblast(x.prestonica).region === r.id) && OBLASTI.some(o => o.region === r.id && slobodna(o)))
          return region ? OBLASTI.filter(o => o.region === region.id && slobodna(o)) : []
        })()
    if (!kandidati.length) kandidati = OBLASTI.filter(o => oblasti[o.id].vlasnik === null)
    const prestonica = kandidati[Math.floor(slucajno() * kandidati.length)].id
    igraci.push({
      id: p.id, ime: p.covek && opcije.ime && !opcije.igraci ? opcije.ime : p.ime, boja: p.boja, covek: p.covek,
      prestonica, ispao: false, tim, kapiten: ('kapiten' in p && p.kapiten !== undefined) ? !!p.kapiten : true,
    })
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
    for (const id of posed) oblasti[id] = { vlasnik: tim, vojske: id === prestonica ? POCETNE_VOJSKE_PRESTONICE : POCETNE_VOJSKE_DRZAVE }
  }
  const s: Stanje = {
    igraci, oblasti, krug: 1, ukupnoKrugova: krugova, naPotezu: 0, faza: 'snabdevanje',
    zaRaspored: 0, bitaka: 0, niz: 0, utvrdjeno: false, tacnostBota: TEZINE[tezina],
    misije: {}, metaMisije: {}, odbrane: {}, promenaOdbrane: {}, tvrdjava: {}, tacnih: {}, pobednik: null, bonusPomoci: {},
  }
  if (opcije.misije) dodeliMisije(s, slucajno)
  return s
}

export function trenutni(s: Stanje): Igrac {
  return s.igraci[s.naPotezu]
}

/** Tim igrača (vlasnik država); prima i id igrača i id tima. */
export function timOd(s: Stanje, id: string): string {
  return s.igraci.find(p => p.id === id)?.tim ?? id
}

/** Države igrača, tj. njegovog tima (saigrači dele države i vojske). */
export function oblastiIgraca(s: Stanje, igracId: string): string[] {
  const tim = timOd(s, igracId)
  return OBLASTI.filter(o => s.oblasti[o.id].vlasnik === tim).map(o => o.id)
}

/** Zbir bonusa regiona koje tim igrača drži u celosti. */
export function bonusRegiona(s: Stanje, igracId: string): number {
  const tim = timOd(s, igracId)
  return REGIONI
    .filter(r => OBLASTI.filter(o => o.region === r.id).every(o => s.oblasti[o.id].vlasnik === tim))
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
  const ja = trenutni(s)
  let st: Stanje = { ...s, tacnih: tacno ? { ...s.tacnih, [ja.tim]: (s.tacnih[ja.tim] ?? 0) + 1 } : s.tacnih }
  let vojske = pojacanja(st, ja.id, tacno)
  // Odbrane koštaju vojske jednom po krugu: plaća se na kapitenovom potezu.
  if (ja.kapiten) {
    const odbrane = { ...st.odbrane }
    for (const k of Object.keys(odbrane)) {
      if (!drziKontinent(st, ja.tim, k)) continue
      const cena = ODBRANE[odbrane[k]].cena
      if (cena <= vojske - 1) vojske -= cena
      else odbrane[k] = 'brzSat'
    }
    st = { ...st, odbrane }
  }
  return { ...st, faza: 'raspored', zaRaspored: vojske }
}

/** Jedna vojska na svoju oblast. Kad se sve rasporede, počinje napad. */
export function rasporedi(s: Stanje, oblastId: string): Stanje {
  if (s.faza !== 'raspored' || s.zaRaspored <= 0) return s
  if (s.oblasti[oblastId]?.vlasnik !== trenutni(s).tim) return s
  const oblasti = { ...s.oblasti, [oblastId]: { ...s.oblasti[oblastId], vojske: s.oblasti[oblastId].vojske + 1 } }
  const ostalo = s.zaRaspored - 1
  return { ...s, oblasti, zaRaspored: ostalo, faza: ostalo === 0 ? 'napad' : 'raspored' }
}

/** Mete u koje se može napasti iz date oblasti. */
export function mete(s: Stanje, odakle: string): string[] {
  const izvor = s.oblasti[odakle]
  if (s.faza !== 'napad' || s.bitaka >= napadaPoPotezu(s)) return []
  if (!izvor || izvor.vlasnik !== trenutni(s).tim || izvor.vojske < 2) return []
  return susedi(odakle).filter(id => s.oblasti[id].vlasnik !== izvor.vlasnik)
}

/** Koliko napada zaredom ima igrač na potezu: 5 svako za sebe, 2 po igraču u timu. */
export function napadaPoPotezu(s: Stanje): number {
  const timova = new Set(s.igraci.map(p => p.tim)).size
  return timova < s.igraci.length ? BITAKA_U_TIMU_PO_IGRACU : BITAKA_PO_POTEZU
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

  const odbrana = odbranaMete(s, kuda)
  const k = kontinentOblasti(kuda).id
  let tvrdjava = s.tvrdjava
  if (odbrana === 'zamka' && !napadac.tacan) gubitakNapadaca += 1
  if (odbrana === 'tvrdjava' && gubitakBranioca > 0 && s.tvrdjava[k] !== s.krug) {
    // Prvi poraz u krugu se ne računa; drugi već skida vojsku.
    gubitakBranioca = 0
    tvrdjava = { ...s.tvrdjava, [k]: s.krug }
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
    plen = meta.vlasnik !== null && s.igraci.some(p => p.prestonica === kuda && p.tim === meta.vlasnik)
    oblasti[odakle] = { ...izvor, vojske: 1 }
    oblasti[kuda] = {
      vlasnik: izvor.vlasnik,
      vojske: Math.max(1, prelazi) + (proboj ? PROBOJ_BONUS : 0) + (plen ? PLEN_PRESTONICE : 0),
    }
  } else {
    oblasti[odakle] = { ...izvor, vojske: vojskeNapadaca }
    oblasti[kuda] = { ...meta, vojske: vojskeBranioca }
  }

  const igraci = s.igraci.map(p => (!p.ispao && OBLASTI.every(o => oblasti[o.id].vlasnik !== p.tim) ? { ...p, ispao: true } : p))
  const tacnih = { ...s.tacnih }
  if (napadac.tacan) tacnih[trenutni(s).tim] = (tacnih[trenutni(s).tim] ?? 0) + 1
  if (branilac?.tacan && meta.vlasnik) tacnih[meta.vlasnik] = (tacnih[meta.vlasnik] ?? 0) + 1
  const posle: Stanje = { ...s, oblasti, igraci, bitaka: s.bitaka + 1, niz, tvrdjava, tacnih }
  const pobednik = posle.pobednik ?? timSaIspunjenomMisijom(posle)
  return {
    stanje: pobednik ? { ...posle, pobednik, faza: 'kraj' } : posle,
    ishod: { gubitakNapadaca: izvor.vojske - vojskeNapadaca, gubitakBranioca: meta.vojske - vojskeBranioca, osvojeno, proboj, plen },
  }
}

/** Jednom po potezu: vojske između dve susedne svoje oblasti, u izvoru ostaje 1. */
export function utvrdi(s: Stanje, odakle: string, kuda: string, broj: number): Stanje {
  const a = s.oblasti[odakle]
  const b = s.oblasti[kuda]
  if (s.faza !== 'napad' || s.utvrdjeno) return s
  if (a?.vlasnik !== trenutni(s).tim || b?.vlasnik !== trenutni(s).tim || !susedi(odakle).includes(kuda)) return s
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
  const tim = timOd(s, igracId)
  const moje = oblastiIgraca(s, igracId)
  const vojske = moje.reduce((zbir, id) => zbir + s.oblasti[id].vojske, 0)
  const igrac = s.igraci.find(p => p.id === igracId)
  const prestonica = igrac && s.oblasti[igrac.prestonica].vlasnik === tim ? POENI_PRESTONICA : 0
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
    const tim = trenutni(st).tim
    const moje = oblastiIgraca(st, id)
    const pretnja = (o: string) => susedi(o).filter(n => st.oblasti[n].vlasnik !== tim).length
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
  const tim = trenutni(s).tim
  let najbolji: { odakle: string; kuda: string; ocena: number } | null = null
  for (const odakle of oblastiIgraca(s, id)) {
    for (const kuda of mete(s, odakle)) {
      const prednost = s.oblasti[odakle].vojske - s.oblasti[kuda].vojske
      if (prednost < 1) continue
      const reg = oblast(kuda).region
      const fali = OBLASTI.filter(o => o.region === reg && s.oblasti[o.id].vlasnik !== tim).length
      const ocena = prednost * 2 + (s.oblasti[kuda].vlasnik === null ? 3 : 0) + (fali === 1 ? 5 : 0)
      if (!najbolji || ocena > najbolji.ocena) najbolji = { odakle, kuda, ocena }
    }
  }
  return najbolji ? { odakle: najbolji.odakle, kuda: najbolji.kuda } : null
}

// ── Kontinenti, misije, odbrane (v3, docs/OSVAJANJE-VISE-IGRACA.md) ───────────

export type Kontinent = { id: string; ime: string; regioni: string[] }

/** 17 regiona grupisano u 6 kontinenata kao u Risku (izbor početka, misije, odbrana). */
export const KONTINENTI: Kontinent[] = [
  { id: 'sam', ime: 'Severna Amerika', regioni: ['sam', 'kar'] },
  { id: 'jam', ime: 'Južna Amerika', regioni: ['jam'] },
  { id: 'evr', ime: 'Evropa', regioni: ['sev', 'zev', 'jev', 'iev'] },
  { id: 'afr', ime: 'Afrika', regioni: ['saf', 'zaf', 'caf', 'iaf', 'jaf'] },
  { id: 'azi', ime: 'Azija', regioni: ['bli', 'caz', 'iaz', 'jia'] },
  { id: 'oke', ime: 'Okeanija', regioni: ['oke'] },
]

export function kontinentOblasti(oblastId: string): Kontinent {
  const r = oblast(oblastId).region
  return KONTINENTI.find(k => k.regioni.includes(r))!
}

export function oblastiKontinenta(kontinentId: string): string[] {
  const k = KONTINENTI.find(x => x.id === kontinentId)
  return k ? OBLASTI.filter(o => k.regioni.includes(o.region)).map(o => o.id) : []
}

export function drziKontinent(s: Stanje, tim: string, kontinentId: string): boolean {
  const oblasti = oblastiKontinenta(kontinentId)
  return oblasti.length > 0 && oblasti.every(id => s.oblasti[id].vlasnik === tim)
}

// Odbrane

export type Odbrana = 'brzSat' | 'bezPomoci' | 'teskoPitanje' | 'prednost' | 'temaBranioca' | 'tvrdjava' | 'zamka'

export const ODBRANE: Record<Odbrana, { naziv: string; opis: string; cena: number }> = {
  brzSat: { naziv: 'Brz sat', opis: 'Napadač ima 8 sekundi umesto 15.', cena: 0 },
  bezPomoci: { naziv: 'Bez pomoći', opis: 'Napadač ne sme da koristi pomoć na ovom kontinentu.', cena: 0 },
  teskoPitanje: { naziv: 'Teško pitanje', opis: 'Napadač dobija samo teška pitanja.', cena: 1 },
  prednost: { naziv: 'Prednost', opis: 'Napadaču trebaju bar 2 tačna više od branioca da osvoji.', cena: 2 },
  temaBranioca: { naziv: 'Tema branioca', opis: 'Pitanja za napadača su iz teme koju je branilac izabrao.', cena: 0 },
  tvrdjava: { naziv: 'Tvrđava', opis: 'Prvi poraz branioca u krugu se ne računa.', cena: 2 },
  zamka: { naziv: 'Zamka', opis: 'Kad napadač pogreši, gubi 2 vojske umesto 1.', cena: 1 },
}

export const SEKUNDI_BRZ_SAT = 8

/** Odbrana koja štiti metu: važi samo dok vlasnik mete drži ceo njen kontinent. */
export function odbranaMete(s: Stanje, kuda: string): Odbrana | null {
  const vlasnik = s.oblasti[kuda]?.vlasnik
  if (!vlasnik) return null
  const k = kontinentOblasti(kuda).id
  const o = s.odbrane[k]
  return o && drziKontinent(s, vlasnik, k) ? o : null
}

/** Uslovi bitke za napadača (sat, pomoć, težina, broj pitanja) prema odbrani mete. */
export function uslovBitke(s: Stanje, kuda: string): { sekundi: number; bezPomoci: boolean; tesko: boolean; pitanja: number; temaBranioca: boolean; prednost: number } {
  const o = odbranaMete(s, kuda)
  return {
    sekundi: o === 'brzSat' ? SEKUNDI_BRZ_SAT : SEKUNDI_PO_PITANJU,
    bezPomoci: o === 'bezPomoci',
    tesko: o === 'teskoPitanje',
    pitanja: s.oblasti[kuda]?.vlasnik ? PITANJA_U_BITCI : 1,
    temaBranioca: o === 'temaBranioca',
    prednost: o === 'prednost' ? 2 : 0,
  }
}

/** Rezultat jedne strane u bitki od 5 pitanja: tačni odgovori i ukupno vreme. */
export type Skor = { tacnih: number; ms: number }

/**
 * Bitka za državu koju drži igrač (5 pitanja). Pobeđuje više tačnih, pa brži; potpuno
 * isto ide braniocu. Napadač koji pobedi osvaja državu, branilac koji pobedi je zadržava;
 * pobednik dobija dodatne pomoći za partiju.
 *
 * @example razresiBitkuSkorom(s, 'ESP', 'FRA', { tacnih: 4, ms: 31000 }, { tacnih: 3, ms: 28000 })
 */
export function razresiBitkuSkorom(s: Stanje, odakle: string, kuda: string, napadac: Skor, branilac: Skor): { stanje: Stanje; ishod: Ishod & { pobedioNapadac: boolean } } {
  if (!mete(s, odakle).includes(kuda)) throw new Error(`Napad ${odakle} → ${kuda} nije dozvoljen`)
  const izvor = s.oblasti[odakle]
  const meta = s.oblasti[kuda]
  if (!meta.vlasnik) throw new Error('Bitka skorom je samo za državu koju drži igrač')
  const odbrana = odbranaMete(s, kuda)
  const k = kontinentOblasti(kuda).id
  const potrebno = odbrana === 'prednost' ? 2 : 1
  const razlika = napadac.tacnih - branilac.tacnih
  let pobedioNapadac = razlika >= potrebno || (potrebno === 1 && razlika === 0 && napadac.ms < branilac.ms)
  let tvrdjava = s.tvrdjava
  let gubitakBranioca = 0
  if (pobedioNapadac && odbrana === 'tvrdjava' && s.tvrdjava[k] !== s.krug) {
    // Prvi poraz u krugu: branilac zadržava državu, ali gubi jednu vojsku.
    pobedioNapadac = false
    gubitakBranioca = Math.min(1, meta.vojske - 1)
    tvrdjava = { ...s.tvrdjava, [k]: s.krug }
  }
  const oblasti = { ...s.oblasti }
  const napadacTim = izvor.vlasnik!
  const pobednikTim = pobedioNapadac ? napadacTim : meta.vlasnik
  let niz = s.niz
  let proboj = false
  let plen = false
  let gubitakNapadaca = 0
  if (pobedioNapadac) {
    niz += 1
    proboj = niz % PROBOJ_SVAKIH === 0
    plen = s.igraci.some(p => p.prestonica === kuda && p.tim === meta.vlasnik)
    gubitakBranioca = meta.vojske
    oblasti[odakle] = { ...izvor, vojske: 1 }
    oblasti[kuda] = { vlasnik: napadacTim, vojske: Math.max(1, izvor.vojske - 1) + (proboj ? PROBOJ_BONUS : 0) + (plen ? PLEN_PRESTONICE : 0) }
  } else {
    const gubitak = GUBITAK_PORAZENOG_NAPADACA + (odbrana === 'zamka' ? 1 : 0)
    const ostaje = Math.max(1, izvor.vojske - gubitak)
    gubitakNapadaca = izvor.vojske - ostaje
    oblasti[odakle] = { ...izvor, vojske: ostaje }
    oblasti[kuda] = { ...meta, vojske: meta.vojske - gubitakBranioca }
  }
  const igraci = s.igraci.map(p => (!p.ispao && OBLASTI.every(o => oblasti[o.id].vlasnik !== p.tim) ? { ...p, ispao: true } : p))
  const tacnih = { ...s.tacnih, [napadacTim]: (s.tacnih[napadacTim] ?? 0) + napadac.tacnih, [meta.vlasnik]: (s.tacnih[meta.vlasnik] ?? 0) + branilac.tacnih }
  const bonusPomoci = { ...s.bonusPomoci, [pobednikTim]: (s.bonusPomoci[pobednikTim] ?? 0) + BONUS_POMOCI_POBEDNIKU }
  const posle: Stanje = { ...s, oblasti, igraci, bitaka: s.bitaka + 1, niz, tvrdjava, tacnih, bonusPomoci }
  const pobednik = posle.pobednik ?? timSaIspunjenomMisijom(posle)
  return {
    stanje: pobednik ? { ...posle, pobednik, faza: 'kraj' } : posle,
    ishod: { gubitakNapadaca, gubitakBranioca, osvojeno: pobedioNapadac, proboj, plen, pobedioNapadac },
  }
}

/** Troši jednu dodatnu pomoć tima (osvojenu u bitkama); false kad nema. */
export function iskoristiBonusPomoc(s: Stanje, tim: string): Stanje | null {
  if ((s.bonusPomoci[tim] ?? 0) <= 0) return null
  return { ...s, bonusPomoci: { ...s.bonusPomoci, [tim]: s.bonusPomoci[tim] - 1 } }
}

/** Bot u bitki od 5 pitanja: svako pitanje tačno sa verovatnoćom jačine. */
export function botSkor(s: Stanje, slucajno: () => number, pitanja = PITANJA_U_BITCI): Skor {
  let tacnih = 0
  let ms = 0
  for (let i = 0; i < pitanja; i++) {
    const o = botOdgovor(s, slucajno)
    if (o.tacan) tacnih++
    ms += o.ms
  }
  return { tacnih, ms }
}

/**
 * Kapiten tima koji drži ceo kontinent bira odbranu; menja je najviše jednom po krugu.
 *
 * @example postaviOdbranu(s, 'evr', 'brzSat')
 */
export function postaviOdbranu(s: Stanje, kontinentId: string, odbrana: Odbrana): Stanje {
  const ja = trenutni(s)
  if (!ja.kapiten || s.faza === 'kraj' || !drziKontinent(s, ja.tim, kontinentId)) return s
  if (s.promenaOdbrane[kontinentId] === s.krug) return s
  return { ...s, odbrane: { ...s.odbrane, [kontinentId]: odbrana }, promenaOdbrane: { ...s.promenaOdbrane, [kontinentId]: s.krug } }
}

/** Bot kapiten: besplatna odbrana na svakom kontinentu koji drži bez odbrane. */
export function botOdbrana(s: Stanje): Stanje {
  let st = s
  for (const k of KONTINENTI) if (!st.odbrane[k.id] && drziKontinent(st, trenutni(st).tim, k.id)) st = postaviOdbranu(st, k.id, 'brzSat')
  return st
}

// Misije

export type Misija = { id: string; tekst: string; samoPojedinacno?: boolean }

export const MISIJE: Misija[] = [
  { id: 'evr-jam', tekst: 'Osvoji Evropu i Južnu Ameriku.' },
  { id: 'evr-oke-jos', tekst: 'Osvoji Evropu i Okeaniju, plus još jedan kontinent po izboru.' },
  { id: 'sam-jam', tekst: 'Osvoji Severnu i Južnu Ameriku.' },
  { id: 'azi-jam', tekst: 'Osvoji Aziju i Južnu Ameriku.' },
  { id: 'afr-oke', tekst: 'Osvoji Afriku i Okeaniju.' },
  { id: 'sam-oke', tekst: 'Osvoji Severnu Ameriku i Okeaniju.' },
  { id: 'drzava60', tekst: 'Drži 60 država.' },
  { id: 'drzava45x2', tekst: 'Drži 45 država sa najmanje 2 vojske u svakoj.' },
  { id: 'regiona8', tekst: 'Drži 8 regiona u celosti.' },
  { id: 'prestonice2', tekst: 'Zauzmi prestonice dva rivala.' },
  { id: 'izbaci', tekst: 'Izbaci određenog rivala iz igre.', samoPojedinacno: true },
  { id: 'tacnih25', tekst: 'Odgovori tačno na 25 pitanja i drži bar 30 država.' },
]

function udeoKontinenata(s: Stanje, tim: string, ids: string[]): number {
  const sve = ids.flatMap(oblastiKontinenta)
  return sve.filter(id => s.oblasti[id].vlasnik === tim).length / sve.length
}

/**
 * Napredak misije tima od 0 do 1 (1 = ispunjena).
 *
 * @example napredakMisije(s, 'ti') // 0.42
 */
export function napredakMisije(s: Stanje, tim: string): number {
  const drzave = OBLASTI.filter(o => s.oblasti[o.id].vlasnik === tim)
  const do1 = (x: number) => Math.min(1, x)
  switch (s.misije[tim]) {
    case 'evr-jam': return udeoKontinenata(s, tim, ['evr', 'jam'])
    case 'evr-oke-jos': {
      const ostali = KONTINENTI.filter(k => k.id !== 'evr' && k.id !== 'oke').map(k => udeoKontinenata(s, tim, [k.id]))
      const osnova = udeoKontinenata(s, tim, ['evr', 'oke'])
      return osnova < 1 ? osnova * 0.75 : 0.75 + 0.25 * Math.max(...ostali)
    }
    case 'sam-jam': return udeoKontinenata(s, tim, ['sam', 'jam'])
    case 'azi-jam': return udeoKontinenata(s, tim, ['azi', 'jam'])
    case 'afr-oke': return udeoKontinenata(s, tim, ['afr', 'oke'])
    case 'sam-oke': return udeoKontinenata(s, tim, ['sam', 'oke'])
    case 'drzava60': return do1(drzave.length / 60)
    case 'drzava45x2': return do1(drzave.filter(o => s.oblasti[o.id].vojske >= 2).length / 45)
    case 'regiona8': return do1(REGIONI.filter(r => OBLASTI.filter(o => o.region === r.id).every(o => s.oblasti[o.id].vlasnik === tim)).length / 8)
    case 'prestonice2': return do1(s.igraci.filter(p => p.tim !== tim && s.oblasti[p.prestonica].vlasnik === tim).length / 2)
    case 'izbaci': {
      const meta = s.metaMisije[tim]
      return s.igraci.filter(p => p.tim === meta).every(p => p.ispao) ? 1 : 0
    }
    case 'tacnih25': return do1((s.tacnih[tim] ?? 0) / 25) * 0.5 + do1(drzave.length / 30) * 0.5
    default: return 0
  }
}

export function timSaIspunjenomMisijom(s: Stanje): string | null {
  for (const tim of Object.keys(s.misije)) if (napredakMisije(s, tim) >= 1) return tim
  return null
}

/** Svakom timu druga misija; „izbaci rivala” samo kad svako igra za sebe. */
function dodeliMisije(s: Stanje, slucajno: () => number): void {
  const timovi = [...new Set(s.igraci.map(p => p.tim))]
  const pojedinacno = timovi.length === s.igraci.length
  const ponuda = MISIJE.filter(m => pojedinacno || !m.samoPojedinacno).map(m => m.id)
  for (let i = ponuda.length - 1; i > 0; i--) {
    const j = Math.floor(slucajno() * (i + 1))
    ;[ponuda[i], ponuda[j]] = [ponuda[j], ponuda[i]]
  }
  timovi.forEach((tim, i) => {
    const m = ponuda[i % ponuda.length]
    s.misije[tim] = m
    if (m === 'izbaci') {
      const drugi = timovi.filter(t => t !== tim)
      s.metaMisije[tim] = drugi[Math.floor(slucajno() * drugi.length)]
    }
  })
}

/** Redosled izbora kontinenata „zmijom” (1-2-3-3-2-1…), da prvi ne uzme sve. */
export function redosledIzbora(timovi: string[], krugova = 1): string[] {
  const red: string[] = []
  for (let i = 0; i < krugova; i++) red.push(...(i % 2 === 0 ? timovi : [...timovi].reverse()))
  return red
}
