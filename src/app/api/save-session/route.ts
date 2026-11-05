import { NextResponse } from 'next/server'
import { z } from 'zod'
import { createClient } from '@/lib/supabase/server'
import { rateLimit } from '@/lib/rate-limit'
import { ucitajSuspenziju } from '@/lib/suspenzija'

// Accepts a "best-effort" save from in-game pagehide/visibilitychange hooks
// (sent via navigator.sendBeacon). The browser may close before async work
// finishes, so this route does the bare minimum: identify the user from
// their cookie session and insert one row into the right session table.
//
// Idempotency is enforced client-side (savedRef) — but we also rely on
// per-mode duplicate-suppression heuristics. `user_id` is always recomputed
// from the auth cookie, never trusted from the body. Every other column is
// whitelisted + range-checked per mode below, so a client cannot forge a
// `score` (or any other column) to cheat the leaderboard.

type Mode = 'quick' | 'book' | 'survivor' | 'hangman' | 'kafana'

const TABLE: Record<Mode, string> = {
  quick: 'quick_sessions',
  book: 'book_sessions',
  survivor: 'survivor_sessions',
  hangman: 'hangman_sessions',
  kafana: 'kafana_sessions',
}

// Shared field shapes. Generous upper bounds: they exist to reject absurd
// forged values without risking rejection of a legitimate save.
const count = z.number().int().min(0).max(100_000)
const score = z.number().int().min(-1_000_000).max(10_000_000)
const accuracy = z.number().min(0).max(100)
const seconds = z.number().int().min(0).max(86_400)

// One schema per mode, whitelisting ONLY the columns the client legitimately
// writes. Unknown keys are stripped by default, so forged columns are dropped.
const SCHEMA: Record<Mode, z.ZodType> = {
  quick: z.object({
    score,
    correct_count: count,
    wrong_count: count,
    total_answered: count,
    accuracy,
    duration_seconds: seconds,
  }),
  survivor: z.object({
    score,
    questions_reached: count,
    correct_answers: count,
    wrong_answers: count,
    skipped_questions: count,
    accuracy,
    best_combo: count,
    total_time_seconds: seconds,
    used_lifelines: count,
    risk_attempts: count,
    risk_correct: count,
    risk_wrong: count,
  }),
  kafana: z.object({
    score,
    questions_reached: count,
    correct_answers: count,
    wrong_answers: count,
    accuracy,
    best_combo: count,
    total_time_seconds: seconds,
  }),
  book: z.object({
    score,
    questions_reached: count,
    correct_answers: count,
    wrong_answers: count,
    skipped_questions: count,
    accuracy,
    best_combo: count,
    total_time_seconds: seconds,
    used_lifelines: count,
    top_genre: z.string().max(200).nullable(),
    top_genre_pct: z.number().min(0).max(100).nullable(),
    genre_breakdown: z.record(
      z.string().max(100),
      z.object({ correct: count, total: count }),
    ),
  }),
  hangman: z.object({
    word: z.string().min(1).max(200),
    word_id: z.string().max(64).nullable().optional(),
    word_length: count,
    won: z.boolean(),
    wrong_guesses: count,
    letters_used: count,
    time_seconds: seconds,
    hint: z.string().max(500).nullable(),
    category: z.string().max(200).nullable(),
    score,
  }),
}

export async function POST(req: Request) {
  let body: Record<string, unknown> = {}
  try {
    const text = await req.text()
    body = text ? JSON.parse(text) : {}
  } catch {
    return NextResponse.json({ ok: false, error: 'bad-json' }, { status: 400 })
  }

  const mode = body.mode as Mode | undefined
  if (!mode || !(mode in TABLE)) {
    return NextResponse.json({ ok: false, error: 'bad-mode' }, { status: 400 })
  }

  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ ok: false, error: 'unauth' }, { status: 401 })
  if (await ucitajSuspenziju(supabase, user.id)) {
    return NextResponse.json({ ok: false, error: 'suspended' }, { status: 403 })
  }

  // Rate limit per user: a legit player can't finish anywhere near this many
  // rounds a minute, so this only bites on scripted spam.
  const limit = rateLimit(`save-session:${user.id}`, 30, 60_000)
  if (!limit.ok) {
    return NextResponse.json(
      { ok: false, error: 'rate-limited' },
      { status: 429, headers: { 'Retry-After': String(limit.retryAfter) } },
    )
  }

  // Validate + whitelist the mode's columns. Unknown/forged keys (including a
  // client-supplied user_id) are stripped; user_id is set server-side below.
  const parsed = SCHEMA[mode].safeParse(body)
  if (!parsed.success) {
    return NextResponse.json({ ok: false, error: 'bad-payload' }, { status: 400 })
  }

  const payload = { ...(parsed.data as Record<string, unknown>), user_id: user.id }

  const { error } = await supabase.from(TABLE[mode]).insert(payload)
  if (error) return NextResponse.json({ ok: false, error: error.message }, { status: 500 })
  return NextResponse.json({ ok: true })
}
