import { createAdminClient } from '@/lib/supabase/admin'
import { jePojam, segment, VESANJE_KATEGORIJE, type SegmentKey } from '@/lib/segmenti'
import { ucitajSuspenziju } from '@/lib/suspenzija'

// Prijem predloga bez SQL RPC-a: admin klijent čita tuđe redove radi
// duplikata, a autorstvo se uvek piše iz auth.uid().
// shortcut: samo tačan duplikat (normalizovan tekst), ne fuzzy; kad
// baza poraste preko ~50k predloga, vratiti pg_trgm RPC.

export type Stavka = { question: string; correct: string; wrong: string[]; genre?: string }

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

export type SubmitRezultat = {
  ok: boolean
  error?: string
  segment?: string
  stats?: Stats
  insertedIds?: string[]
  invalidRows?: { row: number; reason: string; question: string }[]
  duplicateRows?: { row: number; verdict: string; question: string; match?: string }[]
}

function norm(s: string): string {
  return s.toLocaleLowerCase('sr').replace(/\s+/g, ' ').trim()
}

function prazanStats(): Stats {
  return {
    total: 0, valid: 0, invalid: 0,
    dupe_in_file: 0, dupe_in_db: 0, dupe_pending: 0, dupe_rejected: 0,
    similar: 0, inserted: 0,
  }
}

function validiraj(seg: SegmentKey, s: Stavka): string | null {
  const pitanje = s.question.trim()
  const tacan = s.correct.trim()
  if (!pitanje) return 'nema-pitanja'
  if (pitanje.length > 1000) return 'predugo'
  if (!tacan) return 'nema-odgovora'
  if (jePojam(seg)) {
    const slova = pitanje.replace(/[^\p{L}]/gu, '').length
    if (slova < 4 || slova > 18) return 'pojam-duzina'
    if (tacan.toLowerCase().includes(pitanje.toLowerCase())) return 'opis-sadrzi-pojam'
    const kat = (s.genre ?? '').trim()
    if (!VESANJE_KATEGORIJE.some(k => k.toLowerCase() === kat.toLowerCase())) return 'kategorija'
    return null
  }
  const net = s.wrong.map(w => w.trim()).filter(Boolean)
  if (net.length !== 3) return 'nema-tri-netacna'
  const svi = [tacan, ...net]
  if (new Set(svi.map(o => o.toLowerCase())).size !== 4) return 'isti-odgovori'
  if (seg === 'book' && !(s.genre ?? '').trim()) return 'nema-zanra'
  return null
}

export async function submitPitanja(
  userId: string,
  seg: SegmentKey,
  stavke: Stavka[],
  izvor: string,
): Promise<SubmitRezultat> {
  const admin = createAdminClient()

  const { data: profil } = await admin
    .from('profiles')
    .select('is_blocked, suspended_until')
    .eq('id', userId)
    .maybeSingle()
  if (profil?.is_blocked) return { ok: false, error: 'blocked' }
  if (await ucitajSuspenziju(admin, userId)) return { ok: false, error: 'blocked' }

  const od = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString()
  const [{ count: danas }, { count: ceka }] = await Promise.all([
    admin.from('question_submissions').select('id', { count: 'exact', head: true })
      .eq('submitted_by', userId).gte('created_at', od),
    admin.from('question_submissions').select('id', { count: 'exact', head: true })
      .eq('submitted_by', userId).eq('status', 'pending'),
  ])
  if ((ceka ?? 0) >= 500) return { ok: false, error: 'pending-limit' }
  if ((danas ?? 0) + stavke.length > 100) return { ok: false, error: 'daily-limit' }

  const tabela = segment(seg).table
  const kolona = jePojam(seg) ? 'word' : 'question_text'
  const { data: postojeća } = await admin.from(tabela).select(kolona)
  const uBazi = new Set((postojeća ?? []).map(r => norm(String((r as Record<string, unknown>)[kolona] ?? ''))))

  const { data: stari } = await admin
    .from('question_submissions')
    .select('question_text, status')
    .eq('segment', seg)
  const pending = new Set<string>()
  const rejected = new Set<string>()
  const accepted = new Set<string>()
  for (const r of stari ?? []) {
    const k = norm(String(r.question_text ?? ''))
    if (r.status === 'pending') pending.add(k)
    else if (r.status === 'rejected') rejected.add(k)
    else if (r.status === 'accepted') accepted.add(k)
  }

  const stats = prazanStats()
  stats.total = stavke.length
  const invalidRows: SubmitRezultat['invalidRows'] = []
  const duplicateRows: SubmitRezultat['duplicateRows'] = []
  const zaUpis: Stavka[] = []
  const vidjeno = new Set<string>()

  stavke.forEach((s, i) => {
    const row = i + 1
    const greska = validiraj(seg, s)
    if (greska) {
      stats.invalid++
      invalidRows!.push({ row, reason: greska, question: s.question })
      return
    }
    const k = norm(s.question)
    if (vidjeno.has(k)) {
      stats.dupe_in_file++
      duplicateRows!.push({ row, verdict: 'dupe_file', question: s.question })
      return
    }
    vidjeno.add(k)
    if (uBazi.has(k) || accepted.has(k)) {
      stats.dupe_in_db++
      duplicateRows!.push({ row, verdict: 'dupe_db', question: s.question })
      return
    }
    if (pending.has(k)) {
      stats.dupe_pending++
      duplicateRows!.push({ row, verdict: 'dupe_pending', question: s.question })
      return
    }
    if (rejected.has(k)) {
      stats.dupe_rejected++
      duplicateRows!.push({ row, verdict: 'dupe_rejected', question: s.question })
      return
    }
    stats.valid++
    zaUpis.push(s)
  })

  const insertedIds: string[] = []
  if (zaUpis.length) {
    const redovi = zaUpis.map(s => ({
      question_text: s.question.trim(),
      correct_answer: s.correct.trim(),
      wrong_answers: jePojam(seg) ? [] : s.wrong.map(w => w.trim()).filter(Boolean),
      segment: seg,
      genre: (s.genre ?? '').trim() || null,
      source: izvor,
      status: 'pending',
      submitted_by: userId,
    }))
    const { data, error } = await admin.from('question_submissions').insert(redovi).select('id')
    if (error) return { ok: false, error: 'rpc-failed', stats }
    for (const r of data ?? []) insertedIds.push(r.id as string)
    stats.inserted = insertedIds.length
  }

  return {
    ok: true,
    segment: seg,
    stats,
    insertedIds,
    invalidRows,
    duplicateRows,
  }
}

export async function proveriPitanje(seg: SegmentKey, tekst: string): Promise<{ status: string; match?: string }> {
  const t = tekst.trim()
  if (t.length < 8) return { status: 'ok' }
  const admin = createAdminClient()
  const k = norm(t)
  const tabela = segment(seg).table
  const kolona = jePojam(seg) ? 'word' : 'question_text'
  const { data: uFondu } = await admin.from(tabela).select(kolona).limit(8000)
  for (const r of uFondu ?? []) {
    const v = String((r as Record<string, unknown>)[kolona] ?? '')
    if (norm(v) === k) return { status: 'dupe_db', match: v }
  }
  const { data: predlozi } = await admin
    .from('question_submissions')
    .select('question_text, status')
    .eq('segment', seg)
    .limit(4000)
  for (const r of predlozi ?? []) {
    if (norm(String(r.question_text ?? '')) !== k) continue
    if (r.status === 'pending') return { status: 'dupe_pending', match: r.question_text }
    if (r.status === 'rejected') return { status: 'dupe_rejected', match: r.question_text }
    if (r.status === 'accepted') return { status: 'dupe_db', match: r.question_text }
  }
  return { status: 'ok' }
}
