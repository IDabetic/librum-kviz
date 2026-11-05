'use client'

import Image from 'next/image'
import Link from 'next/link'
import { useCallback, useEffect, useRef, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { shuffle } from '@/lib/shuffle'
import { IconClose } from '@/components/icons'
import * as P from '@/lib/osvajanje/pravila'
import { Mapa } from './Mapa'

type Pitanje = { id: string; question_text: string; options: string[]; correct_answer: number }
type Prikaz = { tekst: string; opcije: string[]; tacan: number }
type Vrsta = 'snabdevanje' | 'napad' | 'odbrana'
type Otvoreno = { vrsta: Vrsta; pitanje: Prikaz; pocetak: number; odakle?: string; kuda?: string; rival?: P.Odgovor | null }

const PAKET = 60
const PAUZA_BOTA_MS = 700
const PRIKAZ_ODGOVORA_MS = 1500
const MASKOTA: Record<string, string> = { ti: 'Bloop', mimi: 'Mimi', zig: 'Zig' }
const KLJUC_REKORDA = 'osvajanje-rekord'

const cekaj = (ms: number) => new Promise(r => setTimeout(r, ms))

/** Pitanje iz baze u oblik za prikaz, sa promešanim ponudama. */
function pripremi(q: Pitanje): Prikaz {
  const red = shuffle([0, 1, 2, 3])
  return { tekst: q.question_text, opcije: red.map(i => q.options[i]), tacan: red.indexOf(q.correct_answer) }
}

async function ucitajPaket(): Promise<Pitanje[]> {
  const { data, error } = await createClient().rpc('osvajanje_pitanja', { p_broj: PAKET })
  if (!error && data?.length) return data as Pitanje[]
  // Baza ne odgovara (npr. 402 kad se potroši izlaz): igra ide iz rezervnog paketa ugrađenog u sajt.
  const rezerva = (await import('@/lib/osvajanje/rezervna-pitanja.json')).default as [string, string[], number][]
  return rezerva.map(([question_text, options, correct_answer], i) => ({ id: `r${i}`, question_text, options, correct_answer }))
}

/**
 * Cela partija Osvajača protiv dva bota.
 *
 * @example <Igra krugova={10} tezina="normalno" />
 */
export function Igra({ krugova, tezina }: { krugova: number; tezina: P.Tezina }) {
  const slucajno = useRef(P.napraviSlucajno(Date.now()))
  const [s, setS] = useState<P.Stanje>(() => P.napraviPartiju({ krugova, tezina, slucajno: slucajno.current }))
  const sRef = useRef(s)
  const postavi = useCallback((novo: P.Stanje) => { sRef.current = novo; setS(novo) }, [])

  const paket = useRef<Pitanje[]>([])
  const [greska, setGreska] = useState<string | null>(null)
  const [spremno, setSpremno] = useState(false)
  const [izabrana, setIzabrana] = useState<string | null>(null)
  const [utvrdjivanje, setUtvrdjivanje] = useState(false)
  const [otvoreno, setOtvoreno] = useState<Otvoreno | null>(null)
  const [odgovor, setOdgovor] = useState<number | null>(null)
  const [preostalo, setPreostalo] = useState(P.SEKUNDI_PO_PITANJU)
  const [poruka, setPoruka] = useState<string | null>(null)
  const odbranaResi = useRef<((o: P.Odgovor) => void) | null>(null)
  const botRadi = useRef(false)

  useEffect(() => {
    ucitajPaket().then(p => {
      paket.current = shuffle(p)
      setSpremno(true)
      pocniPotez(sRef.current)
    })
      .catch(e => setGreska(e instanceof Error ? e.message : 'Greška'))
    // eslint-disable-next-line react-hooks/exhaustive-deps -- paket se učitava jednom po partiji
  }, [])

  const javi = useCallback((tekst: string) => {
    setPoruka(tekst)
    setTimeout(() => setPoruka(t => (t === tekst ? null : t)), 2200)
  }, [])

  const sledecePitanje = useCallback((): Prikaz => {
    if (paket.current.length === 0) return { tekst: 'Pitanja su potrošena.', opcije: ['U redu', '—', '—', '—'], tacan: 0 }
    const q = paket.current.shift()!
    paket.current.push(q) // shortcut: paket se vrti u krug, novi se ne povlači usred partije
    return pripremi(q)
  }, [])

  const otvori = useCallback((o: Omit<Otvoreno, 'pitanje' | 'pocetak'>) => {
    setOdgovor(null)
    setPreostalo(P.SEKUNDI_PO_PITANJU)
    setOtvoreno({ ...o, pitanje: sledecePitanje(), pocetak: Date.now() })
  }, [sledecePitanje])

  const covekNaPotezu = s.faza !== 'kraj' && P.trenutni(s).covek

  // Novi potez: ako je čovekov, odmah ide pitanje za snabdevanje.
  const pocniPotez = useCallback((novo: P.Stanje) => {
    postavi(novo)
    if (novo.faza === 'snabdevanje' && P.trenutni(novo).covek) otvori({ vrsta: 'snabdevanje' })
  }, [postavi, otvori])

  // Tajmer pitanja; istek se računa kao netačan odgovor.
  useEffect(() => {
    if (!otvoreno || odgovor !== null) return
    const t = setInterval(() => {
      const ostalo = P.SEKUNDI_PO_PITANJU - Math.floor((Date.now() - otvoreno.pocetak) / 1000)
      setPreostalo(Math.max(0, ostalo))
      if (ostalo <= 0) odgovori(-1)
    }, 250)
    return () => clearInterval(t)
  })

  function odgovori(i: number) {
    if (!otvoreno || odgovor !== null) return
    setOdgovor(i)
    const moj: P.Odgovor = { tacan: i === otvoreno.pitanje.tacan, ms: Date.now() - otvoreno.pocetak }
    setTimeout(() => zatvori(otvoreno, moj), PRIKAZ_ODGOVORA_MS)
  }

  function zatvori(o: Otvoreno, moj: P.Odgovor) {
    setOtvoreno(null)
    const st = sRef.current
    if (o.vrsta === 'snabdevanje') {
      const novo = P.snabdevanje(st, moj.tacan)
      postavi(novo)
      javi(moj.tacan ? `Tačno! Raspoređuješ ${novo.zaRaspored} vojske` : `Netačno. Dobijaš samo ${novo.zaRaspored}`)
      return
    }
    if (o.vrsta === 'odbrana') {
      odbranaResi.current?.(moj)
      odbranaResi.current = null
      return
    }
    const { stanje, ishod } = P.razresiBitku(st, o.odakle!, o.kuda!, moj, o.rival ?? null)
    postavi(stanje)
    if (ishod.osvojeno) {
      javi(ishod.plen ? 'Prestonica pala! +5 plena' : ishod.proboj ? 'Proboj! +2 vojske' : 'Osvojeno! Cepaj dalje')
      setIzabrana(P.mete(stanje, o.kuda!).length ? o.kuda! : null)
    } else {
      javi(ishod.gubitakBranioca > 0 && ishod.gubitakNapadaca === 0 ? `Branilac gubi ${ishod.gubitakBranioca}` : `Gubiš ${ishod.gubitakNapadaca}`)
      if (P.mete(stanje, o.odakle!).length === 0) setIzabrana(null)
    }
  }

  function naOblast(id: string) {
    if (!covekNaPotezu || otvoreno) return
    const st = sRef.current
    const moja = st.oblasti[id].vlasnik === P.trenutni(st).id
    if (st.faza === 'raspored') { if (moja) postavi(P.rasporedi(st, id)); return }
    if (st.faza !== 'napad') return
    if (utvrdjivanje) {
      if (izabrana && moja && P.susedi(izabrana).includes(id)) {
        postavi(P.utvrdi(st, izabrana, id, st.oblasti[izabrana].vojske - 1))
        setUtvrdjivanje(false); setIzabrana(null); javi('Vojske prebačene')
      } else setIzabrana(moja ? id : null)
      return
    }
    if (moja) { setIzabrana(P.mete(st, id).length ? id : null); return }
    if (izabrana && P.mete(st, izabrana).includes(id)) {
      const branilac = st.oblasti[id].vlasnik
      otvori({ vrsta: 'napad', odakle: izabrana, kuda: id, rival: branilac ? P.botOdgovor(st, slucajno.current) : null })
    }
  }

  function krajPoteza() {
    setIzabrana(null); setUtvrdjivanje(false)
    pocniPotez(P.zavrsiPotez(sRef.current))
  }

  // Potez bota: snabdevanje, raspored, napadi sa pauzom; čovek brani svoje oblasti.
  useEffect(() => {
    if (!spremno || s.faza === 'kraj' || P.trenutni(s).covek || botRadi.current) return
    botRadi.current = true
    ;(async () => {
      const rnd = slucajno.current
      let st = P.botRasporedi(P.snabdevanje(sRef.current, rnd() < sRef.current.tacnostBota))
      postavi(st)
      await cekaj(PAUZA_BOTA_MS)
      let napad: ReturnType<typeof P.botSledeciNapad>
      while ((napad = P.botSledeciNapad(st))) {
        setIzabrana(napad.odakle)
        await cekaj(PAUZA_BOTA_MS)
        const napadac = P.botOdgovor(st, rnd)
        const vlasnik = st.oblasti[napad.kuda].vlasnik
        let branilac: P.Odgovor | null = null
        if (vlasnik && st.igraci.find(p => p.id === vlasnik)?.covek) {
          const oblast = P.oblast(napad!.kuda).ime
          javi(`${P.trenutni(st).ime} napada ${oblast}! Brani se`)
          branilac = await new Promise<P.Odgovor>(resi => {
            odbranaResi.current = resi
            otvori({ vrsta: 'odbrana', odakle: napad!.odakle, kuda: napad!.kuda })
          })
        } else if (vlasnik) {
          branilac = P.botOdgovor(st, rnd)
        }
        st = P.razresiBitku(sRef.current, napad.odakle, napad.kuda, napadac, branilac).stanje
        postavi(st)
        await cekaj(PAUZA_BOTA_MS)
      }
      setIzabrana(null)
      botRadi.current = false
      pocniPotez(P.zavrsiPotez(sRef.current))
    })()
  }, [spremno, s, postavi, javi, otvori, pocniPotez])

  const poredak = P.poredak(s)
  const ti = s.igraci.find(p => p.covek)!

  useEffect(() => {
    if (s.faza !== 'kraj') return
    try {
      const moji = P.poeni(s, ti.id)
      if (moji > Number(localStorage.getItem(KLJUC_REKORDA) ?? 0)) localStorage.setItem(KLJUC_REKORDA, String(moji))
    } catch { /* lokalno skladište nije obavezno; rekord se samo ne pamti */ }
  }, [s, ti.id])

  if (greska) {
    return (
      <div className="min-h-screen grid place-items-center p-6">
        <div className="card-soft p-8 max-w-sm text-center">
          <h2 className="text-[28px] mb-2">Pitanja nisu stigla</h2>
          <p className="text-[14px] mb-5" style={{ color: '#4F5170' }}>Baza trenutno ne odgovara. Pokušaj ponovo za koji minut.</p>
          <button onClick={() => location.reload()} className="btn btn-primary btn-md">Pokušaj ponovo</button>
        </div>
      </div>
    )
  }

  if (!spremno) {
    return <div className="min-h-screen grid place-items-center"><div className="skeleton w-64 h-40" aria-label="Učitavanje" /></div>
  }

  const naPotezu = P.trenutni(s)
  const mete = izabrana && !utvrdjivanje && covekNaPotezu ? P.mete(s, izabrana) : []
  const uputstvo = !covekNaPotezu ? `${naPotezu.ime} je na potezu…`
    : s.faza === 'raspored' ? `Dodirni svoje oblasti: još ${s.zaRaspored} vojske`
    : s.faza === 'napad' ? (utvrdjivanje ? 'Izaberi oblast pa susednu svoju za prebacivanje'
      : izabrana ? 'Izaberi metu označenu isprekidano' : `Izaberi svoju oblast sa 2+ vojske · bitka ${s.bitaka}/${P.BITAKA_PO_POTEZU}`)
    : 'Snabdevanje…'

  return (
    <div className="h-[100dvh] flex flex-col overflow-hidden">
      <header className="px-4 sm:px-6 pt-4 pb-2 max-w-7xl w-full mx-auto flex items-center gap-3">
        <Link href="/osvajanje" aria-label="Izađi" className="w-11 h-11 grid place-items-center rounded-full bg-white shrink-0" style={{ border: '1.5px solid #EDE5D5' }}>
          <IconClose size={20} />
        </Link>
        <div className="flex-1 min-w-0">
          <p className="chip" style={{ color: '#4F5170' }}>Krug {Math.min(s.krug, s.ukupnoKrugova)} od {s.ukupnoKrugova}</p>
          <div className="h-2.5 rounded-full mt-1.5 overflow-hidden bg-white" style={{ border: '1.5px solid #1A1B3A' }}>
            <div className="h-full" style={{ width: `${(Math.min(s.krug, s.ukupnoKrugova) / s.ukupnoKrugova) * 100}%`, background: '#23845C' }} />
          </div>
        </div>
      </header>

      <div className="px-4 sm:px-6 max-w-7xl w-full mx-auto grid grid-cols-3 gap-2 sm:gap-3">
        {s.igraci.map(p => (
          <div key={p.id} className="flex items-center gap-2 rounded-2xl px-2.5 py-2"
            style={{ background: '#FFFFFF', border: p.id === naPotezu.id && s.faza !== 'kraj' ? '2.5px solid #1A1B3A' : '1.5px solid #EDE5D5', opacity: p.ispao ? 0.4 : 1 }}>
            <span className="w-9 h-9 rounded-xl grid place-items-center shrink-0 overflow-hidden" style={{ background: p.boja }}>
              <Image src={`/maskote/${MASKOTA[p.id]}.png`} alt="" width={34} height={34} />
            </span>
            <span className="min-w-0">
              <span className="block text-[13px] font-bold truncate">{p.ime}</span>
              <span className="block naslov text-[17px] tabular-nums">{P.poeni(s, p.id)}</span>
            </span>
          </div>
        ))}
      </div>

      <main className="flex-1 min-h-0 w-full px-2 sm:px-4 pt-3 pb-2">
        <Mapa stanje={s} izabrana={izabrana} mete={mete} onOblast={naOblast}
          fokus={otvoreno?.kuda ?? izabrana ?? ti.prestonica} />
      </main>

      <footer className="px-4 sm:px-6 pb-4 pt-2 max-w-7xl w-full mx-auto">
        <div className="card-soft px-4 py-3 flex flex-wrap items-center gap-3">
          <p className="flex-1 min-w-[180px] text-[14px] font-semibold" aria-live="polite">{uputstvo}</p>
          {covekNaPotezu && s.faza === 'raspored' && (
            <button className="btn btn-secondary btn-sm" onClick={() => postavi(P.botRasporedi(sRef.current))}>Rasporedi sam</button>
          )}
          {covekNaPotezu && s.faza === 'napad' && !s.utvrdjeno && (
            <button className="btn btn-secondary btn-sm" aria-pressed={utvrdjivanje}
              onClick={() => { setUtvrdjivanje(u => !u); setIzabrana(null) }}>
              {utvrdjivanje ? 'Odustani' : 'Utvrdi'}
            </button>
          )}
          {covekNaPotezu && s.faza === 'napad' && (
            <button className="btn btn-primary btn-sm" onClick={krajPoteza}>Kraj poteza</button>
          )}
        </div>
      </footer>

      {poruka && (
        <div className="fixed inset-x-0 top-20 z-40 flex justify-center pointer-events-none px-4">
          <div className="card-pop px-5 py-3 font-bold text-[15px] animate-pop-in" style={{ background: '#FDC361' }} role="status">{poruka}</div>
        </div>
      )}

      {otvoreno && (
        <div className="fixed inset-0 z-50 grid place-items-center p-4" style={{ background: 'rgba(26,27,58,0.6)' }}>
          <div className="w-full max-w-lg animate-pop-in" role="dialog" aria-modal="true" aria-label="Pitanje">
            <div className="card-pop p-5 sm:p-6" style={{ background: '#FDC361' }}>
              <div className="flex items-center justify-between gap-3 mb-3">
                <p className="chip">
                  {otvoreno.vrsta === 'snabdevanje' ? 'Snabdevanje'
                    : otvoreno.vrsta === 'odbrana' ? `Odbrana · ${P.oblast(otvoreno.kuda!).ime}`
                    : `Napad · ${P.oblast(otvoreno.kuda!).ime}`}
                </p>
                <span className="naslov text-[22px] tabular-nums" aria-label={`${preostalo} sekundi`}>{preostalo}</span>
              </div>
              <div className="h-2 rounded-full bg-white/60 mb-4 overflow-hidden">
                <div className="h-full transition-[width] duration-200" style={{ width: `${(preostalo / P.SEKUNDI_PO_PITANJU) * 100}%`, background: preostalo <= 5 ? '#E5385C' : '#1A1B3A' }} />
              </div>
              <h2 className="text-[22px] sm:text-[26px] leading-snug mb-5">{otvoreno.pitanje.tekst}</h2>
              <div className="space-y-2.5">
                {otvoreno.pitanje.opcije.map((op, i) => {
                  const stanjeKlase = odgovor === null ? '' : i === otvoreno.pitanje.tacan ? 'tacan' : i === odgovor ? 'netacan' : ''
                  return (
                    <button key={i} className={`odgovor ${stanjeKlase}`} disabled={odgovor !== null}
                      style={odgovor !== null && !stanjeKlase ? { opacity: 0.5 } : undefined} onClick={() => odgovori(i)}>
                      <span className="slovo">{'ABCD'[i]}</span>{op}
                    </button>
                  )
                })}
              </div>
              {odgovor !== null && otvoreno.rival && (
                <p className="mt-4 text-[14px] font-bold">
                  Rival je odgovorio {otvoreno.rival.tacan ? 'tačno' : 'netačno'} za {(otvoreno.rival.ms / 1000).toFixed(1)} s
                </p>
              )}
            </div>
          </div>
        </div>
      )}

      {s.faza === 'kraj' && (
        <div className="fixed inset-0 z-50 grid place-items-center p-4" style={{ background: 'rgba(26,27,58,0.6)' }}>
          <div className="card-pop w-full max-w-md p-6 text-center animate-pop-in" style={{ background: poredak[0].igrac.covek ? '#23845C' : '#FFFFFF', color: poredak[0].igrac.covek ? '#FFFFFF' : '#1A1B3A' }}>
            <Image src={`/maskote/${MASKOTA[poredak[0].igrac.id]}.png`} alt="" width={120} height={120} className="mx-auto maskota-lebdi" />
            <h2 className="text-[44px] mt-2">{poredak[0].igrac.covek ? 'Svet je tvoj!' : `Pobeđuje ${poredak[0].igrac.ime}`}</h2>
            <ol className="mt-5 space-y-2 text-left">
              {poredak.map((r, i) => (
                <li key={r.igrac.id} className="flex items-center gap-3 rounded-2xl px-4 py-3 bg-white" style={{ color: '#1A1B3A', border: '2px solid #1A1B3A' }}>
                  <span className="font-bold w-5">{i + 1}.</span>
                  <span className="w-4 h-4 rounded" style={{ background: r.igrac.boja }} />
                  <span className="flex-1 font-semibold">{r.igrac.ime}</span>
                  <span className="naslov text-[20px] tabular-nums">{r.poeni}</span>
                </li>
              ))}
            </ol>
            <div className="mt-6 grid gap-3">
              <button className="btn btn-yellow btn-lg w-full" onClick={() => location.reload()}>Nova partija</button>
              <Link href="/osvajanje" className="btn btn-secondary btn-lg w-full">Nazad</Link>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
