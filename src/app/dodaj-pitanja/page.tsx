'use client'

import { useEffect, useState } from 'react'
import Link from 'next/link'
import Header from '@/components/Header'
import Footer from '@/components/Footer'
import { createClient } from '@/lib/supabase/client'
import { IconBack, IconCheck, IconWrong, IconLock, IconHint } from '@/components/icons'
import { SEGMENTI, segment, jePojam, VESANJE_KATEGORIJE, type SegmentKey } from '@/lib/segmenti'

// Strana na kojoj prijavljen korisnik šalje pitanja u kviz: prvo bira
// segment (fond pitanja), pa ili popuni obrazac za jedno pitanje ili
// pošalje XML fajl napravljen po šablonu.
//
// XML se raščlanjuje ovde u pregledaču (DOMParser je ugrađen, bez
// dodatne biblioteke), ali se ništa ne veruje na reč: server i RPC
// ponovo proveravaju svaki red. Ovde je raščlanjivanje samo zato da
// korisnik odmah vidi koliko je pitanja pročitano iz fajla.

type Stavka = { question: string; correct: string; wrong: string[]; genre?: string }

type Stats = {
  total: number
  valid: number
  invalid: number
  dupe_in_file: number
  dupe_in_db: number
  dupe_pending: number
  dupe_rejected: number
  similar: number
  inserted: number
}
type NevalidanRed = { row: number; reason: string; question: string }
type Presuda = 'dupe_file' | 'dupe_db' | 'dupe_pending' | 'dupe_rejected' | 'similar'
type DuplRed = { row: number; verdict: Presuda; question: string; match?: string }
type Rezultat = {
  ok: boolean
  segment?: string
  autoAccepted?: number
  error?: string
  detail?: string
  stats?: Stats
  invalidRows?: NevalidanRed[]
  duplicateRows?: DuplRed[]
}

const GRESKE: Record<string, string> = {
  unauth: 'Nisi prijavljen. Prijavi se pa pokušaj ponovo.',
  blocked: 'Tvoj nalog je blokiran za slanje pitanja.',
  'rate-limited': 'Previše pokušaja zaredom. Sačekaj minut pa probaj opet.',
  'bad-segment': 'Nepoznat segment kviza.',
  'no-rows': 'U fajlu nema nijednog pitanja.',
  'too-many': 'Najviše 200 pitanja po fajlu.',
  'too-large': 'Fajl je prevelik.',
  'bad-json': 'Podaci nisu ispravni.',
  'pending-limit': 'Imaš previše predloga koji čekaju proveru. Sačekaj da ih urednik pregleda.',
  'daily-limit': 'Dostigao si dnevnu granicu slanja. Nastavi sutra.',
  'rpc-failed': 'Greška na serveru. Pokušaj ponovo.',
  'no-file': 'Nije izabran fajl.',
  'neispravan-fajl': 'Fajl se ne može pročitati. Da li je zaista Excel ili CSV?',
  'prazan-fajl': 'Fajl je prazan.',
  'nema-redova': 'U fajlu nema nijednog reda sa pitanjem.',
  'bad-sheet-url': 'Link nije adresa Google tabele. Očekuje se docs.google.com/spreadsheets/…',
  'sheet-private': 'Tabela nije javna. U Google tabeli: Deli → Svako sa linkom → Pregledač.',
  'sheet-unreachable': 'Google tabela se ne otvara. Proveri link pa pokušaj ponovo.',
}

// ── XML ────────────────────────────────────────────────────────────
// Očekivani oblik (isti kao u šablonu):
//   <pitanja><pitanje><tekst/><tacan/><netacan/>x3<zanr/></pitanje></pitanja>
// Prihvataju se i varijante naziva sa dijakritikom, jer ih ljudi kucaju.
function tekstDeteta(el: Element, ...nazivi: string[]): string {
  for (const dete of Array.from(el.children)) {
    if (nazivi.includes(dete.tagName.toLowerCase())) return (dete.textContent ?? '').trim()
  }
  return ''
}
function sviTekstovi(el: Element, ...nazivi: string[]): string[] {
  return Array.from(el.children)
    .filter(d => nazivi.includes(d.tagName.toLowerCase()))
    .map(d => (d.textContent ?? '').trim())
}

function parsirajXml(xml: string, pojam = false): { stavke: Stavka[]; greska?: string } {
  let doc: Document
  try {
    doc = new DOMParser().parseFromString(xml, 'application/xml')
  } catch {
    return { stavke: [], greska: 'Fajl nije ispravan XML.' }
  }
  const parseError = doc.querySelector('parsererror')
  if (parseError) {
    return { stavke: [], greska: 'Fajl nije ispravan XML. Proveri da li su svi znakovi < > & zamenjeni i da su svi blokovi zatvoreni.' }
  }
  const koren = doc.documentElement
  if (!koren) return { stavke: [], greska: 'Fajl je prazan.' }

  // Vešanje koristi <pojam> blokove, ostali segmenti <pitanje>. Prihvata
  // se i pogrešan izbor bloka, da fajl napravljen po drugom šablonu ne
  // padne bez objašnjenja.
  const nazivBloka = pojam ? 'pojam' : 'pitanje'
  let blokovi = Array.from(koren.children).filter(d => d.tagName.toLowerCase() === nazivBloka)
  if (blokovi.length === 0) {
    blokovi = Array.from(koren.children)
      .filter(d => ['pojam', 'pitanje'].includes(d.tagName.toLowerCase()))
  }
  if (blokovi.length === 0) {
    return {
      stavke: [],
      greska: `U fajlu nema nijednog <${nazivBloka}> bloka. Preuzmi šablon i popuni ga.`,
    }
  }

  const stavke = pojam
    ? blokovi.map(b => ({
        question: tekstDeteta(b, 'rec', 'reč', 'pojam', 'tekst'),
        correct: tekstDeteta(b, 'opis', 'pomoc', 'pomoć', 'hint', 'tacan'),
        wrong: [],
        genre: tekstDeteta(b, 'kategorija', 'zanr', 'žanr'),
      }))
    : blokovi.map(b => ({
        question: tekstDeteta(b, 'tekst', 'pitanje'),
        correct: tekstDeteta(b, 'tacan', 'tačan', 'tacanodgovor'),
        wrong: sviTekstovi(b, 'netacan', 'netačan', 'pogresan', 'pogrešan'),
        genre: tekstDeteta(b, 'zanr', 'žanr'),
      }))
  return { stavke }
}

// Provera dok korisnik kuca. Okida se sa zadrškom da svaki pritisak
// tastera ne gađa bazu, i pamti za koji tačno tekst je nalaz dobijen —
// bez toga bi se posle izmene teksta na ekranu držao stari nalaz.
type Nalaz = { status: string; match?: string; zaTekst: string }

function useZivaProvera(seg: SegmentKey, tekst: string): Nalaz | null {
  const [nalaz, setNalaz] = useState<Nalaz | null>(null)

  useEffect(() => {
    const t = tekst.trim()
    if (t.length < 8) return
    let otkazano = false
    const id = setTimeout(async () => {
      try {
        const res = await fetch('/api/dodaj-pitanja/provera', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ segment: seg, text: t }),
        })
        const json = await res.json()
        if (!otkazano) setNalaz({ ...json, zaTekst: t })
      } catch {
        // Tiho: provera je pomoć, ne uslov za slanje.
      }
    }, 700)
    return () => { otkazano = true; clearTimeout(id) }
  }, [seg, tekst])

  return nalaz && nalaz.zaTekst === tekst.trim() ? nalaz : null
}

const ZIVA_PORUKA: Record<string, string> = {
  dupe_db: 'Ovo već postoji u bazi. Pošalji nešto drugo.',
  dupe_pending: 'Ovo je već poslato i čeka uredničku proveru.',
  dupe_rejected: 'Ovo je već slato ranije i urednik ga je odbio.',
  similar: 'U bazi postoji vrlo slično:',
}

function ZivaNapomena({ nalaz }: { nalaz: Nalaz | null }) {
  if (!nalaz || !ZIVA_PORUKA[nalaz.status]) return null
  return (
    <div className="rounded-2xl px-4 py-2.5 mt-2 text-[12px] leading-relaxed"
      style={{ background: '#FFF3C4', color: '#8A6A12' }}>
      {ZIVA_PORUKA[nalaz.status]}
      {nalaz.match && <div className="mt-0.5 font-semibold">„{nalaz.match}”</div>}
    </div>
  )
}

export default function DodajPitanjaPage() {
  const [auth, setAuth] = useState<'proverava' | 'da' | 'ne'>('proverava')
  const [seg, setSeg] = useState<SegmentKey>('pro')
  const [tab, setTab] = useState<'jedno' | 'fajl'>('jedno')

  useEffect(() => {
    createClient().auth.getUser().then(({ data: { user } }) => setAuth(user ? 'da' : 'ne'))
  }, [])

  const s = segment(seg)

  return (
    <div className="min-h-screen">
      <Header />

      <main className="max-w-3xl mx-auto px-4 sm:px-6 py-10 sm:py-14">
        <Link href="/igre"
          className="inline-flex items-center gap-1.5 text-[13px] font-medium mb-6 transition-opacity hover:opacity-70"
          style={{ color: '#12907E' }}>
          <IconBack size={16} strokeWidth={2.2} />
          Igre
        </Link>

        <div className="text-center mb-10">
          <div className="w-14 h-14 rounded-2xl flex items-center justify-center mx-auto mb-5"
            style={{ background: '#FFF3C4' }}>
            <IconHint size={26} className="text-[#8A6A12]" strokeWidth={2.2} />
          </div>
          <h1 className="font-black tracking-tight mb-2 leading-[1.1]"
            style={{ color: '#151515', fontSize: 'clamp(36px, 7vw, 56px)', fontWeight: 500 }}>
            Dodaj pitanja
          </h1>
          <p className="text-[14px] sm:text-[15px]" style={{ color: '#6F6C66' }}>
            Pošalji svoja pitanja ili pojmove za vešanje, jedno po jedno ili ceo fajl odjednom.
          </p>
        </div>

        {auth === 'proverava' && (
          <div className="card-soft p-10 text-center text-[14px]" style={{ color: '#6F6C66' }}>
            Učitavanje…
          </div>
        )}

        {auth === 'ne' && <Kapija />}

        {auth === 'da' && (
          <div className="space-y-5">
            <IzborSegmenta seg={seg} onChange={setSeg} />

            <div className="card-soft p-2 flex gap-2">
              <TabDugme aktivan={tab === 'jedno'} onClick={() => setTab('jedno')} accent={s.accent}>
                Jedno po jedno
              </TabDugme>
              <TabDugme aktivan={tab === 'fajl'} onClick={() => setTab('fajl')} accent={s.accent}>
                Uvoz fajla
              </TabDugme>
            </div>

            {tab === 'jedno'
              ? <JednoPitanje key={seg} seg={seg} />
              : <>
                  <UvozFajla key={seg} seg={seg} />
                  <Uputstvo seg={seg} />
                </>}

            <p className="text-[11px] text-center leading-relaxed" style={{ color: '#6F6C66' }}>
              Sva poslata pitanja prolaze kroz uredničku proveru pre nego što se pojave u kvizu.
              Poslata pitanja se broje u „Doprinos kvizu”.
              <br />
              <Link href="/moja-pitanja" className="font-semibold underline" style={{ color: '#12907E' }}>
                Vidi svoja poslata pitanja i njihov status
              </Link>
            </p>
          </div>
        )}
      </main>
      <Footer />
    </div>
  )
}

function Kapija() {
  return (
    <div className="card-soft p-10 text-center">
      <div className="w-14 h-14 rounded-2xl flex items-center justify-center mx-auto mb-5"
        style={{ background: 'rgba(21,21,21,0.06)' }}>
        <IconLock size={26} style={{ color: '#151515' }} strokeWidth={2.2} />
      </div>
      <h2 className="font-black tracking-tight mb-2" style={{ color: '#151515', fontSize: '22px' }}>
        Samo za prijavljene
      </h2>
      <p className="text-[14px] mb-7 max-w-md mx-auto leading-relaxed" style={{ color: '#6F6C66' }}>
        Pitanja u kvizu se vode uz ime autora, pa slanje ide preko naloga.
        Prijavi se ili napravi nalog, traje pola minuta.
      </p>
      <div className="flex gap-3 justify-center flex-wrap">
        <Link href="/auth/prijava?redirect=/dodaj-pitanja" className="btn btn-primary btn-md">
          Prijavi se
        </Link>
        <Link href="/auth/registracija" className="btn btn-secondary btn-md">
          Napravi nalog
        </Link>
      </div>
    </div>
  )
}

function IzborSegmenta({ seg, onChange }: { seg: SegmentKey; onChange: (k: SegmentKey) => void }) {
  return (
    <section className="card-soft p-6 sm:p-7">
      <p className="text-[11px] font-bold uppercase tracking-widest mb-1" style={{ color: '#6F6C66' }}>
        Korak 1
      </p>
      <h2 className="font-bold text-[16px] mb-4 tracking-tight" style={{ color: '#151515' }}>
        Za koji segment kviza šalješ pitanja?
      </h2>

      <div className="grid gap-2.5 grid-cols-2 lg:grid-cols-4">
        {SEGMENTI.map(s => {
          const aktivan = s.key === seg
          return (
            <button key={s.key} type="button" onClick={() => onChange(s.key)}
              className="text-left rounded-2xl p-4 transition-all border-2"
              style={{
                borderColor: aktivan ? s.accent : 'transparent',
                background: aktivan ? s.tint : '#E7E1D0',
              }}>
              <div className="text-[20px] leading-none mb-2">{s.emoji}</div>
              <p className="font-bold text-[14px] mb-0.5" style={{ color: aktivan ? s.accent : '#151515' }}>
                {s.label}
              </p>
              <p className="text-[11px] leading-snug" style={{ color: '#6F6C66' }}>{s.kratko}</p>
            </button>
          )
        })}
      </div>

      <p className="text-[12px] mt-4 leading-relaxed" style={{ color: '#6F6C66' }}>
        {segment(seg).desc}
      </p>
    </section>
  )
}

function TabDugme({ aktivan, onClick, accent, children }: {
  aktivan: boolean; onClick: () => void; accent: string; children: React.ReactNode
}) {
  return (
    <button type="button" onClick={onClick}
      className="flex-1 py-3 rounded-2xl text-[13px] font-bold transition-all"
      style={aktivan
        ? { background: accent, color: 'white' }
        : { background: 'transparent', color: '#6F6C66' }}>
      {children}
    </button>
  )
}

// ── Jedno pitanje / jedan pojam ────────────────────────────────────
function JednoPitanje({ seg }: { seg: SegmentKey }) {
  const s = segment(seg)
  const pojam = jePojam(seg)
  const [pitanje, setPitanje] = useState('')
  const [tacan, setTacan] = useState('')
  const [netacni, setNetacni] = useState(['', '', ''])
  const [zanr, setZanr] = useState(pojam ? VESANJE_KATEGORIJE[0] : '')
  const [salje, setSalje] = useState(false)
  const [rez, setRez] = useState<Rezultat | null>(null)
  const [greska, setGreska] = useState('')

  const nalaz = useZivaProvera(seg, pitanje)

  const popunjeno = pojam
    ? Boolean(pitanje.trim() && tacan.trim() && zanr)
    : Boolean(pitanje.trim() && tacan.trim() && netacni.every(n => n.trim()))

  function postavi(i: number, v: string) {
    setNetacni(prev => prev.map((n, j) => (j === i ? v : n)))
  }

  async function posalji(e: React.FormEvent) {
    e.preventDefault()
    if (!popunjeno || salje) return
    setSalje(true); setGreska(''); setRez(null)
    try {
      const res = await fetch('/api/dodaj-pitanja', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          segment: seg,
          source: 'form',
          items: [{
            question: pitanje.trim(),
            correct: tacan.trim(),
            wrong: pojam ? [] : netacni.map(n => n.trim()),
            genre: pojam || s.zanr ? zanr.trim() : '',
          }],
        }),
      })
      const json = (await res.json()) as Rezultat
      if (!json.ok) {
        setGreska(GRESKE[json.error ?? ''] ?? 'Nešto nije u redu. Pokušaj ponovo.')
      } else {
        setRez(json)
        if (json.stats?.inserted === 1) {
          setPitanje(''); setTacan(''); setNetacni(['', '', ''])
          if (!pojam) setZanr('')
        }
      }
    } catch {
      setGreska('Nema veze sa serverom. Pokušaj ponovo.')
    } finally {
      setSalje(false)
    }
  }

  const st = rez?.stats
  const primljeno = st?.inserted === 1
  const poklapanje = rez?.duplicateRows?.[0]?.match
  const razlogOdbijanja = !st ? null
    : st.invalid > 0 ? (rez?.invalidRows?.[0]?.reason ?? 'nije ispravno')
    : st.dupe_in_db > 0 ? 'ovo već postoji u bazi'
    : st.dupe_pending > 0 ? 'ovo je već poslato i čeka uredničku proveru'
    : (st.dupe_rejected ?? 0) > 0 ? 'ovo je već slato i urednik ga je odbio'
    : (st.similar ?? 0) > 0
      ? `u bazi već postoji vrlo slično pitanje${poklapanje ? `: „${poklapanje}”` : ''}`
      : null

  return (
    <section className="card-soft p-6 sm:p-8">
      <p className="text-[11px] font-bold uppercase tracking-widest mb-1" style={{ color: '#6F6C66' }}>
        Korak 2
      </p>
      <h2 className="font-bold text-[16px] mb-5 tracking-tight" style={{ color: '#151515' }}>
        {pojam ? 'Pojam za' : 'Pitanje za'}: <span style={{ color: s.accent }}>{s.label}</span>
      </h2>

      <form onSubmit={posalji} className="flex flex-col gap-5">
        <div>
          <label className="block text-[13px] font-bold mb-2 tracking-tight" style={{ color: '#151515' }}>
            {pojam ? 'Pojam koji se pogađa' : 'Pitanje'}
          </label>
          {pojam ? (
            <input value={pitanje} onChange={e => setPitanje(e.target.value)}
              placeholder="npr. Kalemegdan" maxLength={60} required className="input" />
          ) : (
            <textarea value={pitanje} onChange={e => setPitanje(e.target.value)}
              placeholder="Upiši pitanje…" rows={3} maxLength={1000} required
              className="input resize-none" />
          )}
          <ZivaNapomena nalaz={nalaz} />
          {pojam && (
            <p className="text-[11px] mt-2" style={{ color: '#6F6C66' }}>
              Od 4 do 18 slova. Može biti i više reči.
            </p>
          )}
        </div>

        <div>
          <label className="block text-[13px] font-bold mb-2 tracking-tight"
            style={{ color: pojam ? '#151515' : '#0E6F61' }}>
            {pojam ? 'Opis (pomoć igraču)' : 'Tačan odgovor'}
          </label>
          {pojam ? (
            <textarea value={tacan} onChange={e => setTacan(e.target.value)}
              placeholder="Kratak opis koji navodi na pojam, a ne sadrži ga"
              rows={2} maxLength={200} required className="input resize-none" />
          ) : (
            <input value={tacan} onChange={e => setTacan(e.target.value)}
              placeholder="Tačan odgovor" maxLength={500} required className="input" />
          )}
          {pojam && (
            <p className="text-[11px] mt-2" style={{ color: '#6F6C66' }}>
              Opis ne sme da sadrži sam pojam, inače pogađanje nema smisla.
            </p>
          )}
        </div>

        {!pojam && (
          <div>
            <label className="block text-[13px] font-bold mb-2 tracking-tight" style={{ color: '#C42B4F' }}>
              Tri netačna odgovora
            </label>
            <div className="space-y-2">
              {netacni.map((n, i) => (
                <input key={i} value={n} onChange={e => postavi(i, e.target.value)}
                  placeholder={`Netačan odgovor ${i + 1}`} maxLength={500} required className="input" />
              ))}
            </div>
            <p className="text-[11px] mt-2" style={{ color: '#6F6C66' }}>
              Sva četiri odgovora moraju biti različita. Igra ih meša, pa redosled nije bitan.
            </p>
          </div>
        )}

        {pojam && (
          <div>
            <label className="block text-[13px] font-bold mb-2 tracking-tight" style={{ color: '#151515' }}>
              Kategorija
            </label>
            <select value={zanr} onChange={e => setZanr(e.target.value)} className="input" required>
              {VESANJE_KATEGORIJE.map(k => <option key={k} value={k}>{k}</option>)}
            </select>
          </div>
        )}

        {!pojam && s.zanr && (
          <div>
            <label className="block text-[13px] font-bold mb-2 tracking-tight" style={{ color: '#151515' }}>
              Žanr <span className="font-normal" style={{ color: '#6F6C66' }}>(opciono)</span>
            </label>
            <input value={zanr} onChange={e => setZanr(e.target.value)}
              placeholder="npr. Roman, Poezija, Drama…" maxLength={100} className="input" />
          </div>
        )}

        {greska && (
          <div className="rounded-2xl px-4 py-3 text-[13px] font-medium"
            style={{ background: '#FFE3EA', color: '#C42B4F' }}>
            {greska}
          </div>
        )}

        {primljeno && (
          <div className="rounded-2xl px-4 py-3 text-[13px] font-medium flex items-center gap-2"
            style={{ background: '#DFF3EE', color: '#0E6F61' }}>
            <IconCheck size={16} className="text-[#0E6F61]" />
            {(rez?.autoAccepted ?? 0) > 0
              ? `${pojam ? 'Pojam je' : 'Pitanje je'} odmah objavljeno u kvizu. Hvala!`
              : `${pojam ? 'Pojam je primljen' : 'Pitanje je primljeno'} i čeka uredničku proveru. Hvala!`}
          </div>
        )}

        {!primljeno && razlogOdbijanja && (
          <div className="rounded-2xl px-4 py-3 text-[13px] font-medium flex items-start gap-2"
            style={{ background: '#FFF3C4', color: '#8A6A12' }}>
            <IconWrong size={16} className="mt-0.5 flex-shrink-0" />
            <span>Nije primljeno: {razlogOdbijanja}.</span>
          </div>
        )}

        <button type="submit" disabled={salje || !popunjeno} className="btn btn-primary btn-lg w-full">
          {salje ? 'Šaljemo…' : pojam ? 'Pošalji pojam' : 'Pošalji pitanje'}
        </button>
      </form>
    </section>
  )
}

// ── Uvoz fajla (XML ili Excel/CSV) ─────────────────────────────────
const MAX_FAJL = 2 * 1024 * 1024

// XML se raščlanjuje ovde u pregledaču jer je DOMParser ugrađen i daje
// trenutan broj pročitanih pitanja. Excel i CSV se šalju serveru kakvi
// jesu: raščlanjava ih `xlsx`, biblioteka koju nema smisla slati u
// pregledač zbog jednog dugmeta.
type VrstaFajla = 'xml' | 'tabela'

function vrstaPoImenu(ime: string): VrstaFajla | null {
  const n = ime.toLowerCase()
  if (n.endsWith('.xml')) return 'xml'
  if (n.endsWith('.xlsx') || n.endsWith('.xls') || n.endsWith('.csv')) return 'tabela'
  return null
}

function UvozFajla({ seg }: { seg: SegmentKey }) {
  const s = segment(seg)
  const pojam = jePojam(seg)
  const [ime, setIme] = useState('')
  const [vrsta, setVrsta] = useState<VrstaFajla | null>(null)
  const [stavke, setStavke] = useState<Stavka[]>([])
  const [fajl, setFajl] = useState<File | null>(null)
  const [parseGreska, setParseGreska] = useState('')
  const [salje, setSalje] = useState(false)
  const [rez, setRez] = useState<Rezultat | null>(null)
  const [greska, setGreska] = useState('')
  const [link, setLink] = useState('')

  function ocisti() {
    setStavke([]); setFajl(null); setVrsta(null)
    setParseGreska(''); setRez(null); setGreska('')
  }

  // Uvoz iz Google tabele: server povlači CSV izvoz, pa se ovde šalje
  // samo link. Tabela mora biti javna za čitanje.
  async function posaljiLink() {
    if (!link.trim() || salje) return
    setSalje(true); setGreska(''); setRez(null); setParseGreska('')
    try {
      const res = await fetch('/api/dodaj-pitanja', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ segment: seg, sheetUrl: link.trim() }),
      })
      const json = (await res.json()) as Rezultat
      if (!json.ok) setGreska(GRESKE[json.error ?? ''] ?? 'Nešto nije u redu. Pokušaj ponovo.')
      else { setRez(json); setLink('') }
    } catch {
      setGreska('Nema veze sa serverom. Pokušaj ponovo.')
    } finally {
      setSalje(false)
    }
  }

  async function izaberi(e: React.ChangeEvent<HTMLInputElement>) {
    const f = e.target.files?.[0]
    ocisti()
    setIme(f?.name ?? '')
    if (!f) return
    if (f.size > MAX_FAJL) { setParseGreska('Fajl je veći od 2 MB.'); return }

    const v = vrstaPoImenu(f.name)
    if (!v) {
      setParseGreska('Podržani su .xml, .xlsx, .xls i .csv fajlovi.')
      return
    }
    setVrsta(v)

    if (v === 'tabela') { setFajl(f); return }

    const { stavke: st, greska: g } = parsirajXml(await f.text(), jePojam(seg))
    if (g) { setParseGreska(g); return }
    if (st.length > 200) {
      setParseGreska(`Fajl ima ${st.length} pitanja, a najviše sme 200. Podeli ga na više fajlova.`)
      return
    }
    setStavke(st)
  }

  const spremno = vrsta === 'xml' ? stavke.length > 0 : fajl !== null

  async function posalji() {
    if (!spremno || salje) return
    setSalje(true); setGreska(''); setRez(null)
    try {
      const zahtev: RequestInit = vrsta === 'xml'
        ? {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ segment: seg, source: 'xml', items: stavke }),
          }
        : (() => {
            const fd = new FormData()
            fd.append('segment', seg)
            fd.append('file', fajl!)
            return { method: 'POST', body: fd }
          })()

      const res = await fetch('/api/dodaj-pitanja', zahtev)
      const json = (await res.json()) as Rezultat
      if (!json.ok) setGreska(GRESKE[json.error ?? ''] ?? 'Nešto nije u redu. Pokušaj ponovo.')
      else setRez(json)
    } catch {
      setGreska('Nema veze sa serverom. Pokušaj ponovo.')
    } finally {
      setSalje(false)
    }
  }

  return (
    <section className="card-soft p-6 sm:p-8">
      <p className="text-[11px] font-bold uppercase tracking-widest mb-1" style={{ color: '#6F6C66' }}>
        Korak 2
      </p>
      <h2 className="font-bold text-[16px] mb-2 tracking-tight" style={{ color: '#151515' }}>
        Grupni uvoz za: <span style={{ color: s.accent }}>{s.label}</span>
      </h2>
      <p className="text-[13px] mb-5 leading-relaxed" style={{ color: '#6F6C66' }}>
        Preuzmi šablon, popuni ga i vrati ovde. Excel šablon je lakši ako radiš u
        tabeli, XML ako radiš u uređivaču teksta. Šablon je različit za svaki segment.
      </p>

      <div className="flex flex-col sm:flex-row gap-2.5 mb-6">
        <a href={`/api/dodaj-pitanja/sablon?segment=${seg}&format=csv`}
          className="btn btn-secondary btn-md flex-1 justify-center">
          ⬇ Excel šablon (CSV)
        </a>
        <a href={`/api/dodaj-pitanja/sablon?segment=${seg}`}
          className="btn btn-secondary btn-md flex-1 justify-center">
          ⬇ XML šablon
        </a>
      </div>

      <div className="rounded-2xl p-4 mb-3 text-[12px] leading-relaxed"
        style={{ background: '#E7E1D0', color: '#151515' }}>
        <p className="font-bold mb-1.5">Kolone u Excel/CSV šablonu</p>
        <p className="font-mono text-[11px]">
          {pojam
            ? 'Pojam · Opis · Kategorija'
            : `Pitanje · Tačan odgovor · Pogrešan 1 · Pogrešan 2 · Pogrešan 3${s.zanr ? ' · Žanr' : ''}`}
        </p>
      </div>

      <details className="mb-5">
        <summary className="text-[12px] font-semibold" style={{ color: '#12907E' }}>
          Kako izgleda XML
        </summary>
        <div className="rounded-2xl p-4 mt-2 text-[12px] font-mono leading-relaxed overflow-x-auto"
          style={{ background: '#E7E1D0', color: '#151515' }}>
          <pre className="whitespace-pre">{pojam
            ? `<pojmovi segment="vesanje">
  <pojam>
    <rec>Kalemegdan</rec>
    <opis>Najveći park u Beogradu, na ušću dve reke</opis>
    <kategorija>Istorija</kategorija>
  </pojam>
</pojmovi>`
            : `<pitanja segment="${s.key}">
  <pitanje>
    <tekst>Tekst pitanja</tekst>
    <tacan>Tačan odgovor</tacan>
    <netacan>Netačan 1</netacan>
    <netacan>Netačan 2</netacan>
    <netacan>Netačan 3</netacan>${s.zanr ? '\n    <zanr>Roman</zanr>' : ''}
  </pitanje>
</pitanja>`}</pre>
        </div>
      </details>

      <ul className="text-[12px] space-y-1 mb-6 leading-relaxed list-disc pl-5" style={{ color: '#6F6C66' }}>
        {pojam ? (
          <>
            <li>Pojam od 4 do 18 slova, opis do 200 znakova i ne sme sadržati sam pojam.</li>
            <li>Kategorija mora biti jedna od: {VESANJE_KATEGORIJE.join(', ')}.</li>
            <li>Najviše 200 pojmova po fajlu, kodiranje UTF-8.</li>
            <li>Pojmovi koji već postoje ili su već poslati se preskaču i prijavljuju.</li>
          </>
        ) : (
          <>
            <li>Tačno tri netačna odgovora po pitanju, sva četiri odgovora različita.</li>
            {s.zanr && <li>Žanr je opcion — bez njega pitanje ide u žanr „Razno”.</li>}
            <li>Najviše 200 pitanja po fajlu, kodiranje UTF-8.</li>
            <li>Pitanja koja već postoje u bazi, koja su već poslata ili su vrlo slična
                postojećima se preskaču i prijavljuju.</li>
          </>
        )}
      </ul>

      <div className="flex flex-col sm:flex-row gap-3 items-stretch sm:items-center">
        <input type="file" accept=".xml,.xlsx,.xls,.csv,application/xml,text/xml,text/csv"
          onChange={izaberi} className="flex-1 text-[13px]" />
        <button type="button" onClick={posalji} disabled={!spremno || salje}
          className="btn btn-primary btn-md whitespace-nowrap">
          {salje ? 'Šaljemo…' : `Pošalji${vrsta === 'xml' && stavke.length ? ` (${stavke.length})` : ''}`}
        </button>
      </div>

      <div className="mt-5 pt-5 border-t border-[#E7E1D0]">
        <label className="block text-[13px] font-bold mb-2 tracking-tight" style={{ color: '#151515' }}>
          …ili nalepi link ka Google tabeli
        </label>
        <div className="flex flex-col sm:flex-row gap-3">
          <input value={link} onChange={e => setLink(e.target.value)}
            placeholder="https://docs.google.com/spreadsheets/d/…"
            className="input flex-1" />
          <button type="button" onClick={posaljiLink} disabled={!link.trim() || salje}
            className="btn btn-secondary btn-md whitespace-nowrap">
            {salje ? 'Čitam…' : 'Uvezi iz tabele'}
          </button>
        </div>
        <p className="text-[11px] mt-2 leading-relaxed" style={{ color: '#6F6C66' }}>
          Tabela mora biti javna za čitanje: <em>Deli → Svako sa linkom → Pregledač</em>.
          Kolone su iste kao u šablonu, ništa se ne preuzima ni ne vraća.
        </p>
      </div>

      {parseGreska && (
        <div className="mt-4 rounded-2xl px-4 py-3 text-[13px] font-medium"
          style={{ background: '#FFE3EA', color: '#C42B4F' }}>
          {parseGreska}
        </div>
      )}

      {!parseGreska && spremno && !rez && (
        <div className="mt-4 rounded-2xl px-4 py-3 text-[13px]"
          style={{ background: '#E7E1D0', color: '#151515' }}>
          {vrsta === 'xml'
            ? <>Pročitano <strong>{stavke.length}</strong> {rec(stavke.length, pojam)} iz fajla <strong>{ime}</strong>.</>
            : <>Izabran fajl <strong>{ime}</strong>. Broj redova se prebrojava na serveru.</>}
          {' '}Klikni „Pošalji” da ih proverimo i primimo.
        </div>
      )}

      {greska && (
        <div className="mt-4 rounded-2xl px-4 py-3 text-[13px] font-medium"
          style={{ background: '#FFE3EA', color: '#C42B4F' }}>
          {greska}
        </div>
      )}

      {rez?.ok && <IzvestajPanel rez={rez} />}
    </section>
  )
}

// ── Uputstvo ───────────────────────────────────────────────────────
// Tri koraka sa nacrtanom tabelom. Crtež je SVG a ne slika ekrana:
// slika ekrana zastari čim se promeni izgled Excela ili sajta, a ovo
// pokazuje samo ono što je bitno — koja kolona nosi šta.
function Uputstvo({ seg }: { seg: SegmentKey }) {
  const pojam = jePojam(seg)
  const s = segment(seg)

  const kolone = pojam
    ? ['Pojam', 'Opis', 'Kategorija']
    : ['Pitanje', 'Tačan odgovor', 'Pogrešan 1', 'Pogrešan 2', 'Pogrešan 3']
  const red = pojam
    ? ['Kalemegdan', 'Najveći park u Beogradu', 'Istorija']
    : ['Koje je najdublje jezero?', 'Bajkalsko', 'Kaspijsko', 'Tanganjika', 'Ohridsko']

  // Širine kolona su ručno podešene: prva kolona nosi najduži tekst.
  const sirine = pojam ? [230, 300, 150] : [220, 140, 140, 140, 140]
  const ukupno = sirine.reduce((a, b) => a + b, 0)
  const x = sirine.map((_, i) => sirine.slice(0, i).reduce((a, b) => a + b, 0))

  return (
    <details className="card-soft p-6 sm:p-7">
      <summary className="font-bold text-[15px] tracking-tight" style={{ color: '#151515' }}>
        Kako se popunjava Excel šablon
      </summary>

      <ol className="mt-5 space-y-4 text-[13px] leading-relaxed" style={{ color: '#151515' }}>
        <li className="flex gap-3">
          <Korak broj={1} accent={s.accent} />
          <span>
            Klikni <strong>Excel šablon (CSV)</strong> gore i otvori preuzeti fajl
            dvoklikom. Otvoriće se u Excelu ili u Google tabelama.
          </span>
        </li>
        <li className="flex gap-3">
          <Korak broj={2} accent={s.accent} />
          <span>
            <strong>Prvi red su nazivi kolona, njega ne diraj.</strong> Ispod njega
            su dva primera: prekucaj ih svojim {pojam ? 'pojmovima' : 'pitanjima'} ili
            ih obriši, pa dodaj svoje redove.
          </span>
        </li>
        <li className="flex gap-3">
          <Korak broj={3} accent={s.accent} />
          <span>
            Sačuvaj fajl (u Excelu <em>Sačuvaj kao</em> → CSV UTF-8, u Google
            tabelama <em>Preuzmi</em> → CSV) i vrati ga ovde dugmetom ispod.
          </span>
        </li>
      </ol>

      <div className="mt-5 -mx-2 overflow-x-auto">
        <svg viewBox={`0 0 ${ukupno + 44} 118`} className="min-w-[560px] w-full" role="img"
          aria-label={`Prikaz tabele sa kolonama ${kolone.join(', ')}`}>
          {/* Traka sa brojevima redova, kao u Excelu */}
          <rect x="0" y="0" width={ukupno + 44} height="118" rx="10" fill="#E7E1D0" />
          <rect x="8" y="10" width="26" height="98" rx="6" fill="#E6E6E6" />
          <text x="21" y="34" textAnchor="middle" fontSize="11" fill="#6F6C66">1</text>
          <text x="21" y="66" textAnchor="middle" fontSize="11" fill="#6F6C66">2</text>
          <text x="21" y="98" textAnchor="middle" fontSize="11" fill="#6F6C66">3</text>

          {kolone.map((k, i) => (
            <g key={k}>
              {/* Red 1: nazivi kolona */}
              <rect x={40 + x[i]} y={10} width={sirine[i] - 4} height={28} rx="6" fill={s.accent} opacity="0.14" />
              <text x={40 + x[i] + 10} y={29} fontSize="12" fontWeight="700" fill={s.accent}>{k}</text>

              {/* Red 2: primer koji korisnik prekucava */}
              <rect x={40 + x[i]} y={42} width={sirine[i] - 4} height={28} rx="6" fill="#FFFFFF" />
              <text x={40 + x[i] + 10} y={61} fontSize="11.5" fill="#151515">
                {red[i].length > sirine[i] / 6.6 ? red[i].slice(0, Math.floor(sirine[i] / 6.6)) + '…' : red[i]}
              </text>

              {/* Red 3: prazan red koji korisnik popunjava */}
              <rect x={40 + x[i]} y={74} width={sirine[i] - 4} height={28} rx="6" fill="#FFFFFF"
                stroke="#D8D8D8" strokeDasharray="4 3" />
            </g>
          ))}
        </svg>
      </div>

      <p className="text-[12px] mt-3 leading-relaxed" style={{ color: '#6F6C66' }}>
        Isti fajl radi i kao <strong>.xlsx</strong>: ako ti je lakše, sačuvaj ga kao
        Excel radnu svesku, prihvataju se oba oblika.
        {pojam
          ? ' Kolona Kategorija mora biti jedna od šest ponuđenih.'
          : ' Redosled kolona nije bitan, samo nazivi u prvom redu.'}
      </p>
    </details>
  )
}

function Korak({ broj, accent }: { broj: number; accent: string }) {
  return (
    <span className="flex-shrink-0 w-6 h-6 rounded-full flex items-center justify-center text-[12px] font-bold"
      style={{ background: accent, color: 'white' }}>
      {broj}
    </span>
  )
}

// ── Izveštaj posle slanja ──────────────────────────────────────────
const DUPL_NAZIV: Record<Presuda, string> = {
  dupe_file: 'duplikat unutar fajla',
  dupe_db: 'već postoji u bazi',
  dupe_pending: 'već poslato, čeka proveru',
  dupe_rejected: 'već poslato ranije i odbijeno',
  similar: 'vrlo slično postojećem pitanju',
}

function IzvestajPanel({ rez }: { rez: Rezultat }) {
  const s = rez.stats!
  const pojam = jePojam(rez.segment ?? '')
  const ukupnoDupli = s.dupe_in_file + s.dupe_in_db + s.dupe_pending
    + (s.dupe_rejected ?? 0) + (s.similar ?? 0)

  return (
    <div className="mt-5 rounded-2xl p-5" style={{ background: s.inserted > 0 ? '#DFF3EE' : '#FFF3C4' }}>
      <p className="font-bold text-[15px] mb-3" style={{ color: s.inserted > 0 ? '#0E6F61' : '#8A6A12' }}>
        {s.inserted > 0
          ? `✓ Primljeno ${s.inserted} ${rec(s.inserted, pojam)}`
          : pojam ? 'Nijedan pojam nije primljen' : 'Nijedno pitanje nije primljeno'}
      </p>

      <div className="space-y-1.5 text-[13px]" style={{ color: '#151515' }}>
        <Red naziv={pojam ? 'Pojmova u fajlu' : 'Pitanja u fajlu'} broj={s.total} />
        <Red naziv="Ispravno popunjeno" broj={s.valid} />
        {s.invalid > 0 && <Red naziv="Neispravno (preskočeno)" broj={s.invalid} boja="#C42B4F" />}
        <div className="h-px my-2" style={{ background: 'rgba(21,21,21,0.10)' }} />
        <Red naziv="Duplikata ukupno" broj={ukupnoDupli} boja={ukupnoDupli > 0 ? '#8A6A12' : undefined} />
        <Red naziv="— duplikat unutar samog fajla" broj={s.dupe_in_file} />
        <Red naziv={pojam ? '— već se nalazi među pojmovima' : '— već se nalazi u bazi pitanja'} broj={s.dupe_in_db} />
        <Red naziv="— već poslato, čeka proveru" broj={s.dupe_pending} />
        <Red naziv="— već poslato ranije i odbijeno" broj={s.dupe_rejected ?? 0} />
        {!pojam && <Red naziv="— vrlo slično postojećem pitanju" broj={s.similar ?? 0} />}
        <div className="h-px my-2" style={{ background: 'rgba(21,21,21,0.10)' }} />
        <Red naziv="Primljeno u bazu predloga" broj={s.inserted} boja="#0E6F61" podebljano />
        {(rez.autoAccepted ?? 0) > 0 && (
          <Red naziv="— odmah objavljeno u kvizu" broj={rez.autoAccepted!} boja="#0E6F61" />
        )}
      </div>

      {(rez.invalidRows?.length ?? 0) > 0 && (
        <details className="mt-4 text-[12px]">
          <summary className="font-semibold" style={{ color: '#C42B4F' }}>
            Zašto {pojam ? 'neki pojmovi nisu primljeni' : 'su neka pitanja odbijena'} ({rez.invalidRows!.length}
            {s.invalid > rez.invalidRows!.length ? ` od ${s.invalid}` : ''})
          </summary>
          <ul className="mt-2 space-y-1 pl-1" style={{ color: '#151515' }}>
            {rez.invalidRows!.map(r => (
              <li key={r.row}>
                <strong>{pojam ? 'pojam' : 'pitanje'} #{r.row}</strong> — {r.reason}
                {r.question && <span style={{ color: '#6F6C66' }}> · „{r.question}”</span>}
              </li>
            ))}
          </ul>
        </details>
      )}

      {(rez.duplicateRows?.length ?? 0) > 0 && (
        <details className="mt-3 text-[12px]">
          <summary className="font-semibold" style={{ color: '#8A6A12' }}>
            {pojam ? 'Koji pojmovi su duplikati' : 'Koja pitanja su duplikati'} ({rez.duplicateRows!.length}
            {ukupnoDupli > rez.duplicateRows!.length ? ` od ${ukupnoDupli}` : ''})
          </summary>
          <ul className="mt-2 space-y-1 pl-1" style={{ color: '#151515' }}>
            {rez.duplicateRows!.map(r => (
              <li key={r.row}>
                <strong>{pojam ? 'pojam' : 'pitanje'} #{r.row}</strong> — {DUPL_NAZIV[r.verdict]}
                {r.question && <span style={{ color: '#6F6C66' }}> · „{r.question}”</span>}
                {r.match && (
                  <div className="pl-4 mt-0.5" style={{ color: '#6F6C66' }}>
                    postojeće: „{r.match}”
                  </div>
                )}
              </li>
            ))}
          </ul>
        </details>
      )}
    </div>
  )
}

function Red({ naziv, broj, boja, podebljano }: {
  naziv: string; broj: number; boja?: string; podebljano?: boolean
}) {
  return (
    <div className="flex items-baseline justify-between gap-3">
      <span style={{ color: boja ?? '#6F6C66' }} className={podebljano ? 'font-bold' : ''}>{naziv}</span>
      <span className="font-bold tabular-nums" style={{ color: boja ?? '#151515' }}>{broj}</span>
    </div>
  )
}

function rec(n: number, pojam = false): string {
  const jednina = n % 10 === 1 && n % 100 !== 11
  if (pojam) return jednina ? 'pojam' : 'pojmova'
  return jednina ? 'pitanje' : 'pitanja'
}
