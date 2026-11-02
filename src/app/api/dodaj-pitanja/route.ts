import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { rateLimit } from '@/lib/rate-limit'
import { jeSegment, jePojam } from '@/lib/segmenti'
import { procitajTabelu } from '@/lib/uvoz-tabela'
import { submitPitanja } from '@/lib/submit-pitanja'

// Prijem korisničkih predloga pitanja sa strane /dodaj-pitanja:
// jedno pitanje iz obrasca, grupa iz XML fajla (JSON telo, fajl je
// raščlanjen u pregledaču) ili grupa iz Excel/CSV fajla (multipart,
// raščlanjava se ovde da se u pregledač ne šalje cela xlsx biblioteka).
//
// Sav posao (validacija reda po reda, provera duplikata i sličnih
// pitanja, upis) radi RPC `submit_questions`. On je SECURITY DEFINER jer
// običan korisnik po RLS-u ne sme da čita tuđe predloge, a duplikate
// mora da proveri i protiv njih. Autorstvo se nikad ne uzima iz tela
// zahteva — funkcija sama upisuje auth.uid().
//
// Pojedinačni redovi se NE odbacuju ovde: red koji ne valja mora da
// stigne do RPC-a da bi korisnik dobio izveštaj „pitanje #7: nema tri
// netačna odgovora” umesto tihe tišine.

// Google tabela se ne otvara u pregledaču nego se ovde povuče njen CSV
// izvoz. Dozvoljen je samo Google domen: ruta inače postaje otvoreni
// posrednik kojim bi neko mogao da gađa proizvoljne adrese sa našeg
// servera.
const GOOGLE_HOST = 'docs.google.com'

function csvIzGoogleLinka(url: string): string | null {
  let u: URL
  try { u = new URL(url) } catch { return null }
  if (u.protocol !== 'https:' || u.hostname !== GOOGLE_HOST) return null
  const m = u.pathname.match(/\/spreadsheets\/d\/([a-zA-Z0-9-_]+)/)
  if (!m) return null
  // gid određuje list u dokumentu; stoji ili u #gid=… ili u ?gid=…,
  // a bez njega Google izvozi prvi list.
  const gid = u.hash.match(/gid=([0-9]+)/)?.[1] ?? u.searchParams.get('gid')
  return `https://docs.google.com/spreadsheets/d/${m[1]}/export?format=csv${gid ? `&gid=${gid}` : ''}`
}

const MAX_BODY_BYTES = 1_000_000    // ~1 MB za JSON telo
const MAX_FILE_BYTES = 2 * 1024 * 1024
const MAX_ITEMS = 200
const MAX_FIELD = 5000              // grubi plafon; RPC javlja pravi (1000/500)

type Stavka = { question: string; correct: string; wrong: string[]; genre?: string }

function ociscen(v: unknown): string {
  return typeof v === 'string' ? v.slice(0, MAX_FIELD) : ''
}

function normalizuj(r: unknown): Stavka {
  const o = (r ?? {}) as Record<string, unknown>
  return {
    question: ociscen(o.question),
    correct: ociscen(o.correct),
    wrong: Array.isArray(o.wrong) ? o.wrong.slice(0, 10).map(ociscen) : [],
    genre: ociscen(o.genre),
  }
}

export async function POST(req: Request) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ ok: false, error: 'unauth' }, { status: 401 })

  const limit = rateLimit(`dodaj-pitanja:${user.id}`, 10, 60_000)
  if (!limit.ok) {
    return NextResponse.json(
      { ok: false, error: 'rate-limited' },
      { status: 429, headers: { 'Retry-After': String(limit.retryAfter) } },
    )
  }

  const tip = req.headers.get('content-type') ?? ''
  let seg = ''
  let izvor = 'form'
  let stavke: Stavka[] = []

  if (tip.includes('multipart/form-data')) {
    let fd: FormData
    try {
      fd = await req.formData()
    } catch {
      return NextResponse.json({ ok: false, error: 'bad-body' }, { status: 400 })
    }
    seg = String(fd.get('segment') ?? '')
    const fajl = fd.get('file')
    if (!(fajl instanceof File)) {
      return NextResponse.json({ ok: false, error: 'no-file' }, { status: 400 })
    }
    if (fajl.size > MAX_FILE_BYTES) {
      return NextResponse.json({ ok: false, error: 'too-large' }, { status: 413 })
    }
    const { stavke: iz, greska } = procitajTabelu(Buffer.from(await fajl.arrayBuffer()), jePojam(seg))
    if (greska) return NextResponse.json({ ok: false, error: greska }, { status: 400 })
    izvor = 'xlsx'
    stavke = iz.map(normalizuj)
  } else {
    let sirovo: string
    try {
      sirovo = await req.text()
    } catch {
      return NextResponse.json({ ok: false, error: 'bad-body' }, { status: 400 })
    }
    if (sirovo.length > MAX_BODY_BYTES) {
      return NextResponse.json({ ok: false, error: 'too-large' }, { status: 413 })
    }
    let telo: { segment?: unknown; source?: unknown; items?: unknown; sheetUrl?: unknown }
    try {
      telo = sirovo ? JSON.parse(sirovo) : {}
    } catch {
      return NextResponse.json({ ok: false, error: 'bad-json' }, { status: 400 })
    }
    seg = String(telo.segment ?? '')

    // Uvoz iz Google tabele: povuče se CSV izvoz i raščlani istim
    // parserom kao otpremljeni fajl.
    if (typeof telo.sheetUrl === 'string' && telo.sheetUrl.trim()) {
      const csvUrl = csvIzGoogleLinka(telo.sheetUrl.trim())
      if (!csvUrl) {
        return NextResponse.json({ ok: false, error: 'bad-sheet-url' }, { status: 400 })
      }
      let odgovor: Response
      try {
        odgovor = await fetch(csvUrl, { redirect: 'follow' })
      } catch {
        return NextResponse.json({ ok: false, error: 'sheet-unreachable' }, { status: 400 })
      }
      if (!odgovor.ok) {
        // 401/403 znači da tabela nije javna — najčešća greška u praksi.
        return NextResponse.json({ ok: false, error: 'sheet-private' }, { status: 400 })
      }
      const buf = Buffer.from(await odgovor.arrayBuffer())
      if (buf.length > MAX_FILE_BYTES) {
        return NextResponse.json({ ok: false, error: 'too-large' }, { status: 413 })
      }
      const { stavke: iz, greska } = procitajTabelu(buf, jePojam(seg))
      if (greska) return NextResponse.json({ ok: false, error: greska }, { status: 400 })
      izvor = 'xlsx'
      stavke = iz.map(normalizuj)
    } else {
      izvor = telo.source === 'xml' ? 'xml' : 'form'
      if (!Array.isArray(telo.items)) {
        return NextResponse.json({ ok: false, error: 'no-rows' }, { status: 400 })
      }
      stavke = telo.items.map(normalizuj)
    }
  }

  if (!jeSegment(seg)) {
    return NextResponse.json({ ok: false, error: 'bad-segment' }, { status: 400 })
  }
  if (stavke.length === 0) {
    return NextResponse.json({ ok: false, error: 'no-rows' }, { status: 400 })
  }
  if (stavke.length > MAX_ITEMS) {
    return NextResponse.json({ ok: false, error: 'too-many' }, { status: 400 })
  }

  const rezultat = await submitPitanja(user.id, seg, stavke, izvor)
  if (!rezultat.ok) {
    const status = rezultat.error === 'unauth' ? 401 : rezultat.error === 'blocked' ? 403 : 400
    return NextResponse.json(rezultat, { status })
  }
  return NextResponse.json({ ...rezultat, autoAccepted: 0 })
}
