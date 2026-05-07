import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'

// Accepts a "best-effort" save from in-game pagehide/visibilitychange hooks
// (sent via navigator.sendBeacon). The browser may close before async work
// finishes, so this route does the bare minimum: identify the user from
// their cookie session and insert one row into the right session table.
//
// Idempotency is enforced client-side (savedRef) — but we also rely on
// per-mode duplicate-suppression heuristics. The only required field is
// `user_id`; we recompute it from the auth cookie, never trust the body.

type Mode = 'quick' | 'book' | 'survivor' | 'hangman' | 'kafana'

const TABLE: Record<Mode, string> = {
  quick: 'quick_sessions',
  book: 'book_sessions',
  survivor: 'survivor_sessions',
  hangman: 'hangman_sessions',
  kafana: 'kafana_sessions',
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

  // Strip mode + override user_id with the authenticated id (server-derived,
  // never trust the body for identity).
  const rest = { ...body }
  delete rest.mode
  delete rest.user_id
  const payload = { ...rest, user_id: user.id }

  const { error } = await supabase.from(TABLE[mode]).insert(payload)
  if (error) return NextResponse.json({ ok: false, error: error.message }, { status: 500 })
  return NextResponse.json({ ok: true })
}
