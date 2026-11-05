import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createAdminClient } from '@/lib/supabase/admin'
import { rateLimit } from '@/lib/rate-limit'
import { PRAG_PRIJAVA, povuciPitanjaAutora, suspendujAutora } from '@/lib/suspenzija'

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

  const limit = rateLimit(`report-question:${user.id}`, 10, 60_000)
  if (!limit.ok) {
    return NextResponse.json(
      { ok: false, error: 'rate-limited' },
      { status: 429, headers: { 'Retry-After': String(limit.retryAfter) } },
    )
  }

  const { error } = await supabase.from('question_reports').insert({
    source: body.source,
    question_id: body.question_id,
    question_text: body.question_text ?? null,
    user_id: user.id,
    reason: body.reason.trim().slice(0, 1000),
    status: 'pending',
  })
  if (error) {
    if (error.code === '23505') return NextResponse.json({ ok: true, already: true })
    return NextResponse.json({ ok: false, error: error.message }, { status: 500 })
  }

  try {
    await posleDrugePrijave(body.source, body.question_id)
  } catch {
    // Prijava je upisana; suspenzija čeka da SQL kolone postoje.
  }

  return NextResponse.json({ ok: true })
}

async function posleDrugePrijave(source: string, questionId: string) {
  const admin = createAdminClient()
  const { data: prijave } = await admin
    .from('question_reports')
    .select('user_id')
    .eq('source', source)
    .eq('question_id', questionId)

  const jedinstveni = new Set((prijave ?? []).map(r => r.user_id).filter(Boolean))
  if (jedinstveni.size < PRAG_PRIJAVA) return

  await admin.from(source).update({ is_active: false }).eq('id', questionId)

  const { data: predlog } = await admin
    .from('question_submissions')
    .select('submitted_by')
    .eq('accepted_id', questionId)
    .eq('accepted_table', source)
    .eq('status', 'accepted')
    .maybeSingle()

  let autor = predlog?.submitted_by as string | null
  if (!autor && source === 'hangman_words') {
    const { data: pojam } = await admin
      .from('hangman_words')
      .select('created_by')
      .eq('id', questionId)
      .maybeSingle()
    autor = (pojam?.created_by as string | null) ?? null
  }
  if (!autor) return

  await suspendujAutora(autor)
  await povuciPitanjaAutora(autor)
}
