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

// ── Pull source rows ──────────────────────────────────────────────────────
const { data: book, error: bookErr } = await supabase
  .from('book_questions')
  .select('genre, question_text, options, correct_answer, difficulty, is_active')
  .limit(20000)
if (bookErr) { console.error('Read book_questions failed:', bookErr.message); process.exit(1) }
console.log(`book_questions: ${book.length}`)

// ── Build inserts ──────────────────────────────────────────────────────────
// Map book.difficulty (lako/srednje/tesko/medium/…) → questions difficulty
// (easy/medium/hard/impossible). Book seed currently writes 'medium' for
// everything, but stay lenient.
const DIFF_MAP = {
  easy: 'easy', medium: 'medium', hard: 'hard', impossible: 'impossible',
  lako: 'easy', srednje: 'medium', tesko: 'hard', teško: 'hard',
}

const toInsert = []
let skippedInactive = 0
for (const b of book) {
  if (!b.is_active) { skippedInactive++; continue }
  const diff = DIFF_MAP[(b.difficulty || '').toLowerCase()] || 'medium'
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

console.log(`candidates: ${toInsert.length}  (inactive skipped: ${skippedInactive})`)
if (toInsert.length === 0) { console.log('Nothing to do.'); process.exit(0) }

// ── Chunked upsert (DB UNIQUE on question_text dedupes; ignore conflicts) ─
const CHUNK = 100
let inserted = 0
let skipped = 0
let failed = 0
for (let i = 0; i < toInsert.length; i += CHUNK) {
  const chunk = toInsert.slice(i, i + CHUNK)
  // ignoreDuplicates = ON CONFLICT DO NOTHING. Returning the rows tells us
  // which ones actually landed vs. were silently dropped as text-dupes.
  const { data, error } = await supabase
    .from('questions')
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
