import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createAdminClient } from '@/lib/supabase/admin'

// Database-level shuffle of answer positions across the entire PRO /
// Brzi / Duel question pool.
//
// All three games already shuffle answers at render time (igraj/start
// uses shuffleOptions, igraj-zajedno uses seededShuffle), so this is
// belt-and-suspenders. But it's the simplest way to guarantee that
// even if shuffle logic regresses, a player who memorized "A je tačan
// odgovor" for a specific question loses that signal.
//
// Strategy: for each row, pick a uniformly-random permutation of
// indices [0,1,2,3], rewrite options[] in that order, and set
// correct_answer to the new index where the original correct option
// landed. Uses the service-role admin client so RLS doesn't get in
// the way of UPDATE on every row.

const ADMIN_ROLES = new Set(['urednik', 'moderator', 'super_admin'])
const CONCURRENCY = 20  // parallel updates per batch — keeps it under a minute for ~3000 rows

function shuffleIndices(): number[] {
  // Fisher-Yates over [0,1,2,3]
  const a = [0, 1, 2, 3]
  for (let i = 3; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[a[i], a[j]] = [a[j], a[i]]
  }
  return a
}

export async function POST() {
  // Auth + role check via the regular session-bound client.
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ ok: false, error: 'unauth' }, { status: 401 })

  const { data: profile } = await supabase
    .from('profiles').select('role').eq('id', user.id).single()
  if (!profile || !ADMIN_ROLES.has(String(profile.role))) {
    return NextResponse.json({ ok: false, error: 'forbidden' }, { status: 403 })
  }

  // From here on use service-role for the bulk update (each row is its
  // own UPDATE, RLS would have to evaluate is_admin() per row otherwise).
  const admin = createAdminClient()

  // ── Load all questions in pages ────────────────────────────────
  type Row = { id: string; options: string[]; correct_answer: number }
  const all: Row[] = []
  const PAGE = 1000
  for (let from = 0; ; from += PAGE) {
    const { data, error } = await admin
      .from('questions')
      .select('id, options, correct_answer')
      .range(from, from + PAGE - 1)
    if (error) {
      return NextResponse.json({ ok: false, error: 'fetch-failed', detail: error.message }, { status: 500 })
    }
    if (!data || data.length === 0) break
    all.push(...(data as Row[]))
    if (data.length < PAGE) break
  }

  if (all.length === 0) {
    return NextResponse.json({ ok: true, stats: { total: 0, updated: 0 } })
  }

  // ── Compute new row payloads ───────────────────────────────────
  type Update = { id: string; options: string[]; correct_answer: number }
  const updates: Update[] = []
  for (const r of all) {
    if (!Array.isArray(r.options) || r.options.length < 2) continue
    const correctOpt = r.options[r.correct_answer]
    const idxs = shuffleIndices()
    const newOptions = idxs.map(i => r.options[i] ?? '').filter(Boolean)
    // If shuffle would drop options (defensive), skip.
    if (newOptions.length !== r.options.length) continue
    const newCorrect = newOptions.indexOf(correctOpt)
    if (newCorrect < 0) continue
    // Skip rows where the shuffle happened to be a no-op (correct
    // landed in the same slot AND every other option is at the same
    // position). Cheap — saves the DB round-trip.
    let identical = newCorrect === r.correct_answer
    if (identical) {
      for (let i = 0; i < r.options.length; i++) {
        if (r.options[i] !== newOptions[i]) { identical = false; break }
      }
    }
    if (identical) continue
    updates.push({ id: r.id, options: newOptions, correct_answer: newCorrect })
  }

  // ── Apply with bounded concurrency ─────────────────────────────
  let updated = 0
  let failed = 0
  let cursor = 0
  async function worker() {
    while (true) {
      const i = cursor++
      if (i >= updates.length) return
      const u = updates[i]
      const { error } = await admin
        .from('questions')
        .update({ options: u.options, correct_answer: u.correct_answer })
        .eq('id', u.id)
      if (error) failed++
      else updated++
    }
  }
  await Promise.all(Array.from({ length: CONCURRENCY }, () => worker()))

  return NextResponse.json({
    ok: true,
    stats: {
      total: all.length,
      candidates_for_update: updates.length,
      updated,
      failed,
    },
  })
}
