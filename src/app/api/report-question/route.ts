import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'

// User-facing "Prijavi pitanje" endpoint. Logged-in users only; the
// auth.uid() ends up in `user_id` server-side regardless of body. The
// table itself is gated by RLS for SELECT/UPDATE (admins only) but
// INSERT is permitted for any authed user, mirroring the same shape
// as predlozi-pitanje.

const VALID_SOURCES = new Set(['questions', 'book_questions', 'kafana_questions', 'hangman_words'])

export async function POST(req: Request) {
  let body: { source?: string; question_id?: string; question_text?: string; reason?: string } = {}
  try {
    const text = await req.text()
    body = text ? JSON.parse(text) : {}
  } catch {
    return NextResponse.json({ ok: false, error: 'bad-json' }, { status: 400 })
  }

  if (!body.source || !VALID_SOURCES.has(body.source)) {
    return NextResponse.json({ ok: false, error: 'bad-source' }, { status: 400 })
  }
  if (!body.question_id) {
    return NextResponse.json({ ok: false, error: 'missing-question-id' }, { status: 400 })
  }
  if (!body.reason || body.reason.trim().length < 3) {
    return NextResponse.json({ ok: false, error: 'reason-required' }, { status: 400 })
  }

  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ ok: false, error: 'unauth' }, { status: 401 })

  const { error } = await supabase.from('question_reports').insert({
    source: body.source,
    question_id: body.question_id,
    question_text: body.question_text ?? null,
    user_id: user.id,
    reason: body.reason.trim().slice(0, 1000),
    status: 'pending',
  })
  if (error) {
    return NextResponse.json({ ok: false, error: error.message }, { status: 500 })
  }
  return NextResponse.json({ ok: true })
}
