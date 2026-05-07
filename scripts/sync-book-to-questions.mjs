// Mirror public.book_questions into public.questions so PRO kviz, Brzi kviz
// and Trivia duel — all of which read from `questions` — start serving the
// literature pool too. Book kviz keeps its own table because it needs the
// per-genre breakdown.
//
// Idempotent: matches by question_text (UNIQUE in questions), so re-running
// after `npm run seed:book` only inserts the newcomers.
//
// Usage:
//   1. Set ADMIN_EMAIL + ADMIN_PASSWORD env vars (a super_admin user)
//   2. From repo root:  node scripts/sync-book-to-questions.mjs

import { createClient } from '@supabase/supabase-js'

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

const supabase = createClient(SUPABASE_URL, ANON)

const { error: signInErr } = await supabase.auth.signInWithPassword({ email: EMAIL, password: PASSWORD })
if (signInErr) { console.error('Sign-in failed:', signInErr.message); process.exit(1) }
console.log('Signed in')

// ── Pull both tables ───────────────────────────────────────────────────────
const { data: book, error: bookErr } = await supabase
  .from('book_questions')
  .select('genre, question_text, options, correct_answer, difficulty, is_active')
  .limit(20000)
if (bookErr) { console.error('Read book_questions failed:', bookErr.message); process.exit(1) }
console.log(`book_questions: ${book.length}`)

// Pull existing question_text in chunks (single select with .limit(20000) is fine for now)
const { data: existing, error: exErr } = await supabase
  .from('questions')
  .select('question_text')
  .limit(50000)
if (exErr) { console.error('Read questions failed:', exErr.message); process.exit(1) }
const existingSet = new Set((existing || []).map(r => r.question_text))
console.log(`questions already in DB: ${existingSet.size}`)

// ── Build inserts ──────────────────────────────────────────────────────────
// Map book.difficulty (lako/srednje/tesko/medium/etc.) → questions difficulty
// (easy/medium/hard/impossible). Book seed currently writes 'medium' for
// everything, but be lenient in case it's edited later.
const DIFF_MAP = {
  easy: 'easy', medium: 'medium', hard: 'hard', impossible: 'impossible',
  lako: 'easy', srednje: 'medium', tesko: 'hard', teško: 'hard',
}

const toInsert = []
let skippedDupes = 0
let skippedInactive = 0
for (const b of book) {
  if (!b.is_active) { skippedInactive++; continue }
  if (existingSet.has(b.question_text)) { skippedDupes++; continue }
  const diff = DIFF_MAP[(b.difficulty || '').toLowerCase()] || 'medium'
  // Tag with 'književnost' + the genre so admins can filter later.
  // Genre comes back in original case (Drama, Fantastika, …).
  const tags = ['književnost']
  if (b.genre && typeof b.genre === 'string' && b.genre.trim()) {
    tags.push(b.genre.trim().toLowerCase())
  }
  toInsert.push({
    question_text: b.question_text,
    options: b.options,
    correct_answer: b.correct_answer ?? 0,
    difficulty: diff,
    is_active: true,
    info: null,
    tags,
  })
}

console.log(`new to insert: ${toInsert.length}  (dupes: ${skippedDupes}, inactive: ${skippedInactive})`)
if (toInsert.length === 0) { console.log('Nothing to do.'); process.exit(0) }

// ── Chunked insert ─────────────────────────────────────────────────────────
const CHUNK = 100
let inserted = 0
let failed = 0
for (let i = 0; i < toInsert.length; i += CHUNK) {
  const chunk = toInsert.slice(i, i + CHUNK)
  const { error } = await supabase.from('questions').insert(chunk)
  if (error) {
    // 23505 = unique violation. Possible if a concurrent insert happened
    // between our SELECT and INSERT — re-pull the question_text set and
    // filter the chunk down to brand-new rows, then retry once.
    if (error.code === '23505') {
      const { data: fresh } = await supabase.from('questions').select('question_text').limit(50000)
      const freshSet = new Set((fresh || []).map(r => r.question_text))
      const retry = chunk.filter(r => !freshSet.has(r.question_text))
      if (retry.length === 0) { console.log(`  chunk ${i}: all already present, skipped`); continue }
      const { error: e2 } = await supabase.from('questions').insert(retry)
      if (e2) { console.error(`  chunk ${i}: retry failed:`, e2.message); failed += retry.length; continue }
      inserted += retry.length
      console.log(`  chunk ${i}: ${retry.length} inserted (after dedupe retry)`)
    } else {
      console.error(`  chunk ${i}: ${error.message}`)
      failed += chunk.length
    }
  } else {
    inserted += chunk.length
    console.log(`  chunk ${i}: ${chunk.length} inserted`)
  }
}

console.log(`\nDone. inserted=${inserted}  failed=${failed}`)
