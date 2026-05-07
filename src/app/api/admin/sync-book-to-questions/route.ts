import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'

// One-click "mirror book_questions into questions" for the admin panel.
// Same logic as scripts/sync-book-to-questions.mjs but executed from the
// admin's authenticated session — no service role key required, RLS
// permits insert because the same role flag already lets admins create
// questions via /majmun/pitanja/novo.
//
// Idempotent: relies on the UNIQUE constraint on questions.question_text
// + onConflict ignoreDuplicates. Re-running after seeding new book rows
// only inserts the newcomers.

const DIFF_MAP: Record<string, 'easy' | 'medium' | 'hard' | 'impossible'> = {
  easy: 'easy', medium: 'medium', hard: 'hard', impossible: 'impossible',
  lako: 'easy', srednje: 'medium', tesko: 'hard', 'teško': 'hard',
}

type BookRow = {
  genre: string | null
  question_text: string
  options: string[]
  correct_answer: number | null
  difficulty: string | null
  is_active: boolean
}

export async function POST() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ ok: false, error: 'unauth' }, { status: 401 })

  const { data: profile } = await supabase
    .from('profiles').select('role').eq('id', user.id).single()
  const role = profile?.role ?? ''
  if (!['urednik', 'moderator', 'super_admin'].includes(role)) {
    return NextResponse.json({ ok: false, error: 'forbidden' }, { status: 403 })
  }

  const { data: book, error: bookErr } = await supabase
    .from('book_questions')
    .select('genre, question_text, options, correct_answer, difficulty, is_active')
    .limit(20000)
  if (bookErr) return NextResponse.json({ ok: false, error: bookErr.message }, { status: 500 })

  const rows: BookRow[] = (book ?? []) as BookRow[]
  const candidates = rows
    .filter(b => b.is_active)
    .map(b => {
      const tags = ['književnost']
      if (b.genre && b.genre.trim()) tags.push(b.genre.trim().toLowerCase())
      return {
        question_text: b.question_text,
        options: b.options,
        correct_answer: b.correct_answer ?? 0,
        difficulty: DIFF_MAP[(b.difficulty ?? '').toLowerCase()] ?? 'medium',
        is_active: true,
        info: null,
        tags,
      }
    })

  if (candidates.length === 0) {
    return NextResponse.json({ ok: true, total: 0, inserted: 0, skipped: 0 })
  }

  // Chunked upsert — DB UNIQUE on question_text dedupes via ON CONFLICT
  // DO NOTHING. .select('id') tells us how many actually landed.
  const CHUNK = 100
  let inserted = 0
  let failed = 0
  for (let i = 0; i < candidates.length; i += CHUNK) {
    const chunk = candidates.slice(i, i + CHUNK)
    const { data, error } = await supabase
      .from('questions')
      .upsert(chunk, { onConflict: 'question_text', ignoreDuplicates: true })
      .select('id')
    if (error) { failed += chunk.length; continue }
    inserted += data?.length ?? 0
  }

  return NextResponse.json({
    ok: true,
    total: candidates.length,
    inserted,
    skipped: candidates.length - inserted - failed,
    failed,
  })
}
