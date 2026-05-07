// One-shot seed for public.book_questions.
// Reads /Users/idabetic/Downloads/Književnost - sva pitanja.xlsx and inserts
// all 788 rows. Skips ones already in the table (matched by question_text).
//
// Usage:
//   1. Set ADMIN_EMAIL + ADMIN_PASSWORD env vars (a super_admin user)
//   2. From repo root:  node scripts/seed-book.mjs
//
// Why the login dance: book_questions has RLS — admins manage via
// is_admin_user(). The anon key alone can't write. This script signs in
// as super_admin first, then bulk-inserts.

import { createClient } from '@supabase/supabase-js'
import { readFile } from 'node:fs/promises'
import * as XLSX from 'xlsx'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL
const ANON = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
const EMAIL = process.env.ADMIN_EMAIL
const PASSWORD = process.env.ADMIN_PASSWORD

if (!SUPABASE_URL || !ANON) {
  console.error('Missing NEXT_PUBLIC_SUPABASE_URL / NEXT_PUBLIC_SUPABASE_ANON_KEY')
  process.exit(1)
}
if (!EMAIL || !PASSWORD) {
  console.error('Missing ADMIN_EMAIL / ADMIN_PASSWORD env vars')
  process.exit(1)
}

const XLSX_PATH = '/Users/idabetic/Downloads/Književnost - sva pitanja.xlsx'

async function main() {
  console.log(`Reading ${XLSX_PATH}…`)
  const buf = await readFile(XLSX_PATH)
  const wb = XLSX.read(buf)
  const ws = wb.Sheets[wb.SheetNames[0]]
  const rows = XLSX.utils.sheet_to_json(ws)
  console.log(`Found ${rows.length} rows in Excel`)

  const supabase = createClient(SUPABASE_URL, ANON)
  const { error: signInErr } = await supabase.auth.signInWithPassword({ email: EMAIL, password: PASSWORD })
  if (signInErr) { console.error('Sign-in failed:', signInErr.message); process.exit(1) }
  console.log('Signed in as super_admin')

  // Fetch existing question texts to skip
  const { data: existing } = await supabase
    .from('book_questions')
    .select('question_text')
    .limit(10000)
  const existingSet = new Set((existing || []).map(r => r.question_text))
  console.log(`${existingSet.size} questions already in DB`)

  // Build inserts for new ones
  const toInsert = []
  for (const r of rows) {
    const q = String(r['Pitanje']).trim()
    if (existingSet.has(q)) continue
    toInsert.push({
      genre: String(r['Žanr']).trim(),
      question_text: q,
      options: [
        String(r['Tačan odgovor']).trim(),
        String(r['Pogrešan 1']).trim(),
        String(r['Pogrešan 2']).trim(),
        String(r['Pogrešan 3']).trim(),
      ],
      correct_answer: 0,
      difficulty: 'medium',
      is_active: true,
    })
  }
  console.log(`${toInsert.length} new questions to insert`)
  if (toInsert.length === 0) { console.log('Nothing to do'); return }

  // Chunked insert
  const chunkSize = 100
  for (let i = 0; i < toInsert.length; i += chunkSize) {
    const chunk = toInsert.slice(i, i + chunkSize)
    const { error } = await supabase.from('book_questions').insert(chunk)
    if (error) { console.error(`Chunk @ ${i} failed:`, error); process.exit(1) }
    console.log(`Inserted ${Math.min(i + chunkSize, toInsert.length)}/${toInsert.length}`)
  }

  const { count } = await supabase.from('book_questions').select('*', { count: 'exact', head: true })
  console.log(`Done. Total in DB: ${count}`)
}

main().catch(e => { console.error(e); process.exit(1) })
