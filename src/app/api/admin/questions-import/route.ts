import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import * as XLSX from 'xlsx'

// Bulk-import PRO/Brzi/Duel questions from an uploaded Excel file.
// All three games share the public.questions table, so a single import
// here populates all of them.
//
// Expected columns (Serbian header names, matching the user's
// `Pitanja - sveža.xlsx` template):
//   - Pitanje          → question_text
//   - Tačan odgovor    → options[0]   (we keep correct at index 0
//                                       in DB; per-render shuffle in
//                                       the games randomizes display)
//   - Netačno          → options[1]
//   - Netačno_1        → options[2]
//   - Netačno_2        → options[3]
//
// Duplicate strategy: skip any row whose question_text already exists
// in the table (case-sensitive, trimmed). The endpoint returns the
// raw count of inserted vs. skipped vs. invalid rows so the admin UI
// can show a clean summary.

const ADMIN_ROLES = new Set(['urednik', 'moderator', 'super_admin'])
const MAX_BYTES = 10 * 1024 * 1024  // 10 MB, plenty for ~10k rows

// XLSX preserves Excel cell types — a year answer like 1945 comes
// through as `number`, not `string`. We accept anything stringifiable
// and coerce with String() in the loop.
type Row = Record<string, unknown>

// Normalize a header to its canonical key by stripping whitespace
// and unifying common Serbian variants the user might type into
// the Excel header row. Lets us match "Tačan odgovor", "tacan odgovor",
// or " Tačan Odgovor " to the same canonical column.
function pickKey(row: Row, ...candidates: string[]): unknown {
  // Exact-match first (cheap path).
  for (const k of candidates) {
    if (k in row) return row[k]
  }
  // Fallback: case-insensitive + trimmed lookup over all keys.
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
      ok: false,
      error: 'parse-failed',
      detail: e instanceof Error ? e.message : 'unknown',
    }, { status: 400 })
  }

  if (!Array.isArray(rows) || rows.length === 0) {
    return NextResponse.json({ ok: false, error: 'no-rows' }, { status: 400 })
  }

  // ── Normalize + validate ────────────────────────────────────────
  // Per-row try/catch so a single weird cell (e.g. an embedded
  // formula or formatting object) doesn't 500 the whole request.
  type Candidate = { question_text: string; options: string[]; correct_answer: 0 }
  const candidates: Candidate[] = []
  const invalidRows: { rowNum: number; reason: string }[] = []
  for (let i = 0; i < rows.length; i++) {
    try {
      const r = rows[i] as Row
      const q       = asTrimmed(pickKey(r, 'Pitanje', 'pitanje'))
      const correct = asTrimmed(pickKey(r, 'Tačan odgovor', 'Tacan odgovor', 'Tačan_odgovor', 'tacan odgovor'))
      const w1      = asTrimmed(pickKey(r, 'Netačno', 'Netacno', 'netacno'))
      const w2      = asTrimmed(pickKey(r, 'Netačno_1', 'Netacno_1', 'Netačno 1', 'netacno_1'))
      const w3      = asTrimmed(pickKey(r, 'Netačno_2', 'Netacno_2', 'Netačno 2', 'netacno_2'))

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
      candidates.push({ question_text: q, options: opts, correct_answer: 0 })
    } catch (e) {
      invalidRows.push({
        rowNum: i + 2,
        reason: `parse error: ${e instanceof Error ? e.message : 'unknown'}`,
      })
    }
  }

  if (candidates.length === 0) {
    return NextResponse.json({
      ok: false,
      error: 'no-valid-rows',
      stats: { total: rows.length, invalid: invalidRows.length },
      invalidRows: invalidRows.slice(0, 20),
    }, { status: 400 })
  }

  // ── Detect duplicates against existing questions ────────────────
  // Fetch all question_texts in chunks. We can't IN() 2000 strings in
  // one shot (URL length), so we just read everything and dedupe in
  // memory. The questions table is bounded (~few thousand rows).
  const existingTexts = new Set<string>()
  const PAGE = 1000
  for (let from = 0; ; from += PAGE) {
    const { data, error } = await supabase
      .from('questions')
      .select('question_text')
      .range(from, from + PAGE - 1)
    if (error) {
      return NextResponse.json({ ok: false, error: 'fetch-existing-failed', detail: error.message }, { status: 500 })
    }
    if (!data || data.length === 0) break
    for (const r of data) existingTexts.add(String(r.question_text))
    if (data.length < PAGE) break
  }

  // Also dedupe WITHIN the upload (same question appearing twice in
  // the same file should only insert once).
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

  // ── Bulk insert in batches ──────────────────────────────────────
  const CHUNK = 500
  let inserted = 0
  for (let i = 0; i < toInsert.length; i += CHUNK) {
    const slice = toInsert.slice(i, i + CHUNK)
    const { error } = await supabase.from('questions').insert(
      slice.map(c => ({
        question_text: c.question_text,
        options: c.options,
        correct_answer: c.correct_answer,
        difficulty: 'medium',
        is_active: true,
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
    stats: {
      total: rows.length,
      valid: candidates.length,
      invalid: invalidRows.length,
      dupe_against_db: dupeAgainstDb,
      dupe_in_file: dupeInFile,
      inserted,
    },
    // Echo back the first 20 problematic rows so the admin can fix
    // the source spreadsheet.
    invalidRowsSample: invalidRows.slice(0, 20),
  })
}
