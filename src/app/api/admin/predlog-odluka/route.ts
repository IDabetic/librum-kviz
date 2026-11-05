import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { segment, jePojam, VESANJE_KATEGORIJE } from '@/lib/segmenti'

// Odluka urednika o korisničkom predlogu: prihvatanje (uz upis u fond
// pitanja), odbijanje sa razlogom ili vraćanje na čekanje.
//
// Radi se na serveru, a ne iz admin panela direktno u bazu, da postoji
// jedno mesto koje zna kako se koji od četiri fonda puni i koje validira
// pre upisa. Urednik može da ispravi tekst pre prihvatanja, pa se
// ispravka upisuje i u predlog, da autor na „Moja pitanja” vidi ono što
// je zaista ušlo u kviz.

const ADMIN_ROLES = new Set(['urednik', 'moderator', 'super_admin'])

type Telo = {
  id?: string
  action?: 'accept' | 'reject' | 'reopen'
  question?: string
  correct?: string
  wrong?: string[]
  genre?: string
  info?: string
  difficulty?: string
  reason?: string
}

type Predlog = {
  id: string
  question_text: string
  correct_answer: string
  wrong_answers: string[] | null
  segment: string | null
  genre: string | null
  status: string
  submitted_by: string | null
}

function ocisti(v: unknown, max: number): string {
  return typeof v === 'string' ? v.trim().slice(0, max) : ''
}

export async function POST(req: Request) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ ok: false, error: 'unauth' }, { status: 401 })

  const { data: profil } = await supabase
    .from('profiles').select('role').eq('id', user.id).single()
  if (!profil || !ADMIN_ROLES.has(String(profil.role))) {
    return NextResponse.json({ ok: false, error: 'forbidden' }, { status: 403 })
  }

  let telo: Telo
  try {
    telo = await req.json()
  } catch {
    return NextResponse.json({ ok: false, error: 'bad-json' }, { status: 400 })
  }
  if (!telo.id || !['accept', 'reject', 'reopen'].includes(telo.action ?? '')) {
    return NextResponse.json({ ok: false, error: 'bad-request' }, { status: 400 })
  }

  const { data: predlog } = await supabase
    .from('question_submissions')
    .select('id, question_text, correct_answer, wrong_answers, segment, genre, status, submitted_by')
    .eq('id', telo.id)
    .single()
  if (!predlog) return NextResponse.json({ ok: false, error: 'not-found' }, { status: 404 })

  const p = predlog as Predlog
  const seg = segment(p.segment ?? 'pro')
  const sada = new Date().toISOString()

  if (telo.action === 'reopen') {
    const { error } = await supabase.from('question_submissions').update({
      status: 'pending', reject_reason: null, reviewed_at: null, reviewed_by: null,
    }).eq('id', p.id)
    if (error) return NextResponse.json({ ok: false, error: error.message }, { status: 500 })
    return NextResponse.json({ ok: true })
  }

  if (telo.action === 'reject') {
    const razlog = ocisti(telo.reason, 500)
    const { error } = await supabase.from('question_submissions').update({
      status: 'rejected',
      reject_reason: razlog || null,
      reviewed_at: sada,
      reviewed_by: user.id,
    }).eq('id', p.id)
    if (error) return NextResponse.json({ ok: false, error: error.message }, { status: 500 })
    return NextResponse.json({ ok: true })
  }

  // ── Prihvatanje ─────────────────────────────────────────────────
  const pitanje = ocisti(telo.question, 1000) || p.question_text
  const odgovor = ocisti(telo.correct, 500) || p.correct_answer
  const netacni = (telo.wrong ?? p.wrong_answers ?? [])
    .map(v => ocisti(v, 500)).filter(Boolean)
  const kategorija = ocisti(telo.genre, 100) || p.genre || ''

  let tabela: string
  let red: Record<string, unknown>

  if (jePojam(seg.key)) {
    const slova = pitanje.replace(/[^\p{L}]/gu, '').length
    if (slova < 4 || slova > 18) {
      return NextResponse.json({ ok: false, error: 'Pojam mora imati 4 do 18 slova.' }, { status: 400 })
    }
    if (!odgovor) {
      return NextResponse.json({ ok: false, error: 'Opis je obavezan.' }, { status: 400 })
    }
    if (odgovor.toLowerCase().includes(pitanje.toLowerCase())) {
      return NextResponse.json({ ok: false, error: 'Opis ne sme da sadrži sam pojam.' }, { status: 400 })
    }
    const kat = VESANJE_KATEGORIJE.find(k => k.toLowerCase() === kategorija.toLowerCase())
    if (!kat) {
      return NextResponse.json({ ok: false, error: 'Kategorija mora biti jedna od šest ponuđenih.' }, { status: 400 })
    }
    tabela = 'hangman_words'
    red = {
      // hangman_words čuva reč malim slovima i ima jedinstven indeks po njoj.
      word: pitanje.toLowerCase(),
      word_length: slova,
      hint: odgovor,
      category: kat,
      is_active: true,
      created_by: p.submitted_by,
    }
  } else {
    if (netacni.length !== 3) {
      return NextResponse.json({ ok: false, error: 'Potrebna su tačno tri netačna odgovora.' }, { status: 400 })
    }
    const opcije = [odgovor, ...netacni]
    if (new Set(opcije.map(o => o.toLowerCase())).size !== 4) {
      return NextResponse.json({ ok: false, error: 'Odgovori ne smeju biti identični.' }, { status: 400 })
    }
    const zajednicko = {
      question_text: pitanje,
      // Tačan odgovor uvek stoji na indeksu 0, igre mešaju redosled.
      options: opcije,
      correct_answer: 0,
      difficulty: ocisti(telo.difficulty, 20) || 'medium',
      is_active: true,
    }
    tabela = seg.table
    red = seg.key === 'book'
      // book_questions nema kolonu `info`, a `genre` joj je obavezan.
      ? { ...zajednicko, genre: kategorija || 'Razno' }
      : seg.key === 'kafana'
        ? { ...zajednicko, info: ocisti(telo.info, 1000) || null, tags: ['muzika', 'kafana'] }
        : { ...zajednicko, info: ocisti(telo.info, 1000) || null }
  }

  // Id novog reda se pamti uz predlog: bez te veze se posle prihvatanja
  // gubi trag, pa autor ne bi mogao da vidi kako mu pitanje prolazi u igri.
  const { data: upisan, error: greskaUpisa } = await supabase
    .from(tabela).insert(red).select('id').single()
  if (greskaUpisa) {
    const poruka = greskaUpisa.code === '23505'
      ? 'Već postoji u bazi (isti unos).'
      : greskaUpisa.message
    return NextResponse.json({ ok: false, error: poruka }, { status: 400 })
  }

  const { error: greskaStatusa } = await supabase.from('question_submissions').update({
    status: 'accepted',
    // Ispravka urednika se čuva, da autor vidi tačno ono što je objavljeno.
    question_text: pitanje,
    correct_answer: odgovor,
    wrong_answers: jePojam(seg.key) ? [] : netacni,
    genre: kategorija || null,
    reviewed_at: sada,
    reviewed_by: user.id,
    accepted_id: upisan?.id ?? null,
    accepted_table: tabela,
  }).eq('id', p.id)
  if (greskaStatusa) {
    return NextResponse.json({ ok: false, error: greskaStatusa.message }, { status: 500 })
  }

  return NextResponse.json({ ok: true })
}
