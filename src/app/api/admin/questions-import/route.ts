import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import * as XLSX from 'xlsx'

// Bulk-import questions from an uploaded Excel file into one of the
// three question pools. Pool is chosen via ?pool=pro|book|kafana
// (default pro for back-compat with the original PRO/Brzi/Duel UI).
//
//   pro    → public.questions       (PRO + Brzi + Trivia duel)
//   book   → public.book_questions  (Book kviz, requires a Žanr column)
//   kafana → public.kafana_questions(Kafanski kviz, tagged muzika)
//
// Accepted Excel headers (case/space-insensitive, both wrong-answer
// conventions supported so the same template works everywhere):
//   - Pitanje                         → question_text
//   - Tačan odgovor                   → options[0]  (kept at index 0;
//                                        games shuffle at render)
//   - Netačno / Pogrešan 1            → options[1]
//   - Netačno_1 / Pogrešan 2          → options[2]
//   - Netačno_2 / Pogrešan 3          → options[3]
//   - Žanr  (book pool only, required)→ genre
//
// Duplicates are skipped both against the DB (by question_text) and
// within the uploaded file itself.

const ADMIN_ROLES = new Set(['urednik', 'moderator', 'super_admin'])
const MAX_BYTES = 10 * 1024 * 1024

type Pool = 'pro' | 'book' | 'kafana'
type PoolConfig = {
  table: string
  // book_questions.genre is NOT NULL. A Žanr column in the Excel is
  // OPTIONAL — the template is identical to PRO. When the column is
  // absent or a cell is empty, the row gets `defaultGenre` so the
  // insert never fails and the admin doesn't have to categorize 2000
  // rows by hand. A power user can still add a Žanr column to label
  // them (drives the "najjači žanr" stat on the result screen).
  defaultGenre: string | null
  // Extra columns merged into every inserted row.
  extra: Record<string, unknown>
}
const POOLS: Record<Pool, PoolConfig> = {
  pro:    { table: 'questions',        defaultGenre: null,    extra: { difficulty: 'medium', is_active: true } },
  book:   { table: 'book_questions',   defaultGenre: 'Razno', extra: { is_active: true } },
  kafana: { table: 'kafana_questions', defaultGenre: null,    extra: { difficulty: 'medium', is_active: true, tags: ['muzika', 'kafana'] } },
}

type Row = Record<string, unknown>

function pickKey(row: Row, ...candidates: string[]): unknown {
  for (const k of candidates) if (k in row) return row[k]
  const keys = Object.keys(row)
  for (const c of candidates) {
    const target = c.trim().toLowerCase()
    const hit = keys.find(k => k.trim().toLowerCase() === target)
    if (hit) return row[hit]
  }
  return undefined
}
function asTrimmed(v: unknown): string {
  if (v == null) return ''
  return String(v).trim()
}

export async function POST(req: Request) {
  const url = new URL(req.url)
  const poolParam = (url.searchParams.get('pool') || 'pro') as Pool
  const cfg = POOLS[poolParam]
  if (!cfg) {
    return NextResponse.json({ ok: false, error: 'bad-pool' }, { status: 400 })
  }

  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ ok: false, error: 'unauth' }, { status: 401 })

  const { data: profile } = await supabase
    .from('profiles').select('role').eq('id', user.id).single()
  if (!profile || !ADMIN_ROLES.has(String(profile.role))) {
    return NextResponse.json({ ok: false, error: 'forbidden' }, { status: 403 })
  }

  // ── Parse the upload ─────────────────────────────────────────────
  let formData: FormData
  try {
    formData = await req.formData()
  } catch {
    return NextResponse.json({ ok: false, error: 'bad-form-data' }, { status: 400 })
  }
  const file = formData.get('file')
  if (!(file instanceof File)) {
    return NextResponse.json({ ok: false, error: 'no-file' }, { status: 400 })
  }
  if (file.size > MAX_BYTES) {
    return NextResponse.json({ ok: false, error: 'file-too-large' }, { status: 413 })
  }

  let rows: Row[]
  try {
    const buf = Buffer.from(await file.arrayBuffer())
    const wb = XLSX.read(buf, { type: 'buffer' })
    const ws = wb.Sheets[wb.SheetNames[0]]
    if (!ws) return NextResponse.json({ ok: false, error: 'empty-workbook' }, { status: 400 })
    rows = XLSX.utils.sheet_to_json<Row>(ws)
  } catch (e) {
    return NextResponse.json({
      ok: false, error: 'parse-failed',
      detail: e instanceof Error ? e.message : 'unknown',
    }, { status: 400 })
  }

  if (!Array.isArray(rows) || rows.length === 0) {
    return NextResponse.json({ ok: false, error: 'no-rows' }, { status: 400 })
  }

  // ── Normalize + validate ────────────────────────────────────────
  type Candidate = { question_text: string; options: string[]; genre?: string }
  const candidates: Candidate[] = []
  const invalidRows: { rowNum: number; reason: string }[] = []
  for (let i = 0; i < rows.length; i++) {
    try {
      const r = rows[i] as Row
      const q       = asTrimmed(pickKey(r, 'Pitanje', 'pitanje'))
      const correct = asTrimmed(pickKey(r, 'Tačan odgovor', 'Tacan odgovor', 'Tačan_odgovor', 'tacan odgovor'))
      const w1      = asTrimmed(pickKey(r, 'Netačno', 'Netacno', 'netacno', 'Pogrešan 1', 'Pogresan 1', 'Pogrešan_1'))
      const w2      = asTrimmed(pickKey(r, 'Netačno_1', 'Netacno_1', 'Netačno 1', 'netacno_1', 'Pogrešan 2', 'Pogresan 2', 'Pogrešan_2'))
      const w3      = asTrimmed(pickKey(r, 'Netačno_2', 'Netacno_2', 'Netačno 2', 'netacno_2', 'Pogrešan 3', 'Pogresan 3', 'Pogrešan_3'))
      const genre   = asTrimmed(pickKey(r, 'Žanr', 'Zanr', 'zanr', 'genre', 'Genre'))

      if (!q) { invalidRows.push({ rowNum: i + 2, reason: 'prazno pitanje' }); continue }
      if (!correct || !w1 || !w2 || !w3) {
        invalidRows.push({ rowNum: i + 2, reason: 'fali odgovor' })
        continue
      }
      const opts = [correct, w1, w2, w3]
      if (new Set(opts.map(o => o.toLowerCase())).size !== 4) {
        invalidRows.push({ rowNum: i + 2, reason: 'duplikati odgovora' })
        continue
      }
      // Žanr optional: use the cell if present, else the pool default.
      candidates.push(cfg.defaultGenre !== null
        ? { question_text: q, options: opts, genre: genre || cfg.defaultGenre }
        : { question_text: q, options: opts })
    } catch (e) {
      invalidRows.push({
        rowNum: i + 2,
        reason: `parse error: ${e instanceof Error ? e.message : 'unknown'}`,
      })
    }
  }

  if (candidates.length === 0) {
    return NextResponse.json({
      ok: false, error: 'no-valid-rows',
      stats: { total: rows.length, invalid: invalidRows.length },
      invalidRowsSample: invalidRows.slice(0, 20),
    }, { status: 400 })
  }

  // ── Dedupe against the chosen pool ──────────────────────────────
  const existingTexts = new Set<string>()
  const PAGE = 1000
  for (let from = 0; ; from += PAGE) {
    const { data, error } = await supabase
      .from(cfg.table)
      .select('question_text')
      .range(from, from + PAGE - 1)
    if (error) {
      return NextResponse.json({ ok: false, error: 'fetch-existing-failed', detail: error.message }, { status: 500 })
    }
    if (!data || data.length === 0) break
    for (const r of data) existingTexts.add(String(r.question_text))
    if (data.length < PAGE) break
  }

  const seenInUpload = new Set<string>()
  const toInsert: Candidate[] = []
  let dupeAgainstDb = 0
  let dupeInFile = 0
  for (const c of candidates) {
    if (existingTexts.has(c.question_text)) { dupeAgainstDb++; continue }
    if (seenInUpload.has(c.question_text)) { dupeInFile++; continue }
    seenInUpload.add(c.question_text)
    toInsert.push(c)
  }

  // ── Bulk insert ─────────────────────────────────────────────────
  const CHUNK = 500
  let inserted = 0
  for (let i = 0; i < toInsert.length; i += CHUNK) {
    const slice = toInsert.slice(i, i + CHUNK)
    const { error } = await supabase.from(cfg.table).insert(
      slice.map(c => ({
        question_text: c.question_text,
        options: c.options,
        correct_answer: 0,
        ...(c.genre ? { genre: c.genre } : {}),
        ...cfg.extra,
      }))
    )
    if (error) {
      return NextResponse.json({
        ok: false, error: 'insert-failed', detail: error.message,
        stats: { inserted, remaining: toInsert.length - inserted },
      }, { status: 500 })
    }
    inserted += slice.length
  }

  return NextResponse.json({
    ok: true,
    pool: poolParam,
    stats: {
      total: rows.length,
      valid: candidates.length,
      invalid: invalidRows.length,
      dupe_against_db: dupeAgainstDb,
      dupe_in_file: dupeInFile,
      inserted,
    },
    invalidRowsSample: invalidRows.slice(0, 20),
  })
}
