// One-shot seed for public.kafana_questions.
// Reads /Users/idabetic/Downloads/Kafanski kviz.xlsx and inserts all rows.
// Idempotent — skips rows whose question_text already exists (UNIQUE
// constraint + onConflict ignoreDuplicates).
//
// Usage:
//   ADMIN_EMAIL=... ADMIN_PASSWORD='...' node scripts/seed-kafana.mjs

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

const XLSX_PATH = '/Users/idabetic/Downloads/Kafanski kviz.xlsx'

console.log(`Reading ${XLSX_PATH}…`)
const buf = await readFile(XLSX_PATH)
const wb = XLSX.read(buf)
const ws = wb.Sheets[wb.SheetNames[0]]
const rows = XLSX.utils.sheet_to_json(ws)
console.log(`Found ${rows.length} rows in Excel`)

const supabase = createClient(SUPABASE_URL, ANON)
const { error: signInErr } = await supabase.auth.signInWithPassword({ email: EMAIL, password: PASSWORD })
if (signInErr) { console.error('Sign-in failed:', signInErr.message); process.exit(1) }
console.log('Signed in')

const candidates = []
for (const r of rows) {
  const q = String(r['Pitanje'] ?? '').trim()
  const correct = String(r['Tačan odgovor'] ?? '').trim()
  const w1 = String(r['Pogrešan 1'] ?? '').trim()
  const w2 = String(r['Pogrešan 2'] ?? '').trim()
  const w3 = String(r['Pogrešan 3'] ?? '').trim()
  if (!q || !correct || !w1 || !w2 || !w3) continue
  candidates.push({
    question_text: q,
    options: [correct, w1, w2, w3],
    correct_answer: 0,
    difficulty: 'medium',
    is_active: true,
    tags: ['muzika', 'kafana'],
  })
}
console.log(`Prepared ${candidates.length} valid candidates`)

const CHUNK = 100
let inserted = 0
let skipped = 0
let failed = 0
for (let i = 0; i < candidates.length; i += CHUNK) {
  const chunk = candidates.slice(i, i + CHUNK)
  const { data, error } = await supabase
    .from('kafana_questions')
    .upsert(chunk, { onConflict: 'question_text', ignoreDuplicates: true })
    .select('id')
  if (error) {
    console.error(`  chunk ${i}: ${error.message}`)
    failed += chunk.length
    continue
  }
  const got = data?.length ?? 0
  inserted += got
  skipped += chunk.length - got
  console.log(`  chunk ${i}: ${got} inserted, ${chunk.length - got} skipped (dupe text)`)
}

console.log(`\nDone. inserted=${inserted}  skipped=${skipped}  failed=${failed}`)
