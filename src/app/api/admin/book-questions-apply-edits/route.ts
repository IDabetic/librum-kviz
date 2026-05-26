import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createAdminClient } from '@/lib/supabase/admin'

// Apply a list of admin-approved edits to book_questions. Used by the
// AI-assisted transcription flow — the admin reviews Claude's
// suggestions, checks the ones to keep, and posts those here. Service
// role + bounded concurrency for the bulk UPDATE.

const ADMIN_ROLES = new Set(['urednik', 'moderator', 'super_admin'])
const CONCURRENCY = 20

type Edit = { id: string; question_text: string; options: string[] }

export async function POST(req: Request) {
  let body: { edits?: Edit[] }
  try { body = await req.json() } catch { return NextResponse.json({ ok: false, error: 'bad-json' }, { status: 400 }) }
  const edits = Array.isArray(body.edits) ? body.edits : []
  if (edits.length === 0) return NextResponse.json({ ok: false, error: 'no-edits' }, { status: 400 })

  // Validate
  for (const e of edits) {
    if (typeof e.id !== 'string' || typeof e.question_text !== 'string' || !Array.isArray(e.options)) {
      return NextResponse.json({ ok: false, error: 'bad-edit-shape' }, { status: 400 })
    }
    if (!e.question_text.trim()) {
      return NextResponse.json({ ok: false, error: `empty-text-for-${e.id}` }, { status: 400 })
    }
    if (e.options.length !== 4 || e.options.some(o => !o || !String(o).trim())) {
      return NextResponse.json({ ok: false, error: `bad-options-for-${e.id}` }, { status: 400 })
    }
  }

  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ ok: false, error: 'unauth' }, { status: 401 })
  const { data: profile } = await supabase
    .from('profiles').select('role').eq('id', user.id).single()
  if (!profile || !ADMIN_ROLES.has(String(profile.role))) {
    return NextResponse.json({ ok: false, error: 'forbidden' }, { status: 403 })
  }

  const admin = createAdminClient()
  let updated = 0
  let failed = 0
  let cursor = 0
  async function worker() {
    while (true) {
      const i = cursor++
      if (i >= edits.length) return
      const e = edits[i]
      const { error } = await admin
        .from('book_questions')
        .update({ question_text: e.question_text, options: e.options })
        .eq('id', e.id)
      if (error) failed++; else updated++
    }
  }
  await Promise.all(Array.from({ length: CONCURRENCY }, () => worker()))

  return NextResponse.json({ ok: true, updated, failed })
}
