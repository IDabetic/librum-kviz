import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createAdminClient } from '@/lib/supabase/admin'

// Bulk find & replace across public.book_questions.
//
// Two-phase: send { dryRun: true } first to get a preview (matches +
// sample rows + total affected) without touching the DB. After admin
// reviews, send { dryRun: false } to actually apply. The whole
// operation runs as a service-role bulk update — same admin auth
// gate as the rest of /api/admin/*.

const ADMIN_ROLES = new Set(['urednik', 'moderator', 'super_admin'])
const SAMPLE_SIZE = 5
const CONCURRENCY = 20

type Scope = 'both' | 'question' | 'options'
type Body = {
  find?: string
  replace?: string
  scope?: Scope
  caseSensitive?: boolean
  dryRun?: boolean
}

function escapeRegExp(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

function replaceAllIn(text: string, re: RegExp, replacement: string): { out: string; count: number } {
  let count = 0
  const out = text.replace(re, () => { count++; return replacement })
  return { out, count }
}

export async function POST(req: Request) {
  let body: Body
  try { body = await req.json() } catch { return NextResponse.json({ ok: false, error: 'bad-json' }, { status: 400 }) }

  const find = String(body.find ?? '')
  const replace = String(body.replace ?? '')
  const scope: Scope = body.scope === 'question' || body.scope === 'options' ? body.scope : 'both'
  const caseSensitive = body.caseSensitive !== false
  const dryRun = body.dryRun === true

  if (!find) return NextResponse.json({ ok: false, error: 'missing-find' }, { status: 400 })

  // Auth
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ ok: false, error: 'unauth' }, { status: 401 })
  const { data: profile } = await supabase
    .from('profiles').select('role').eq('id', user.id).single()
  if (!profile || !ADMIN_ROLES.has(String(profile.role))) {
    return NextResponse.json({ ok: false, error: 'forbidden' }, { status: 403 })
  }

  const admin = createAdminClient()

  // Load all book_questions
  type Row = { id: string; question_text: string; options: string[] }
  const all: Row[] = []
  const PAGE = 1000
  for (let from = 0; ; from += PAGE) {
    const { data, error } = await admin
      .from('book_questions')
      .select('id, question_text, options')
      .range(from, from + PAGE - 1)
    if (error) return NextResponse.json({ ok: false, error: 'fetch-failed', detail: error.message }, { status: 500 })
    if (!data || data.length === 0) break
    all.push(...(data as Row[]))
    if (data.length < PAGE) break
  }

  const re = new RegExp(escapeRegExp(find), caseSensitive ? 'g' : 'gi')

  type Update = { id: string; question_text?: string; options?: string[]; matches: number }
  const updates: Update[] = []
  for (const r of all) {
    let matches = 0
    let newText: string | undefined
    let newOpts: string[] | undefined

    if (scope === 'both' || scope === 'question') {
      const { out, count } = replaceAllIn(r.question_text, re, replace)
      if (count > 0) { matches += count; newText = out }
    }
    if (scope === 'both' || scope === 'options') {
      const opts = Array.isArray(r.options) ? r.options : []
      const next: string[] = []
      let optsChanged = false
      for (const o of opts) {
        const s = typeof o === 'string' ? o : String(o ?? '')
        const { out, count } = replaceAllIn(s, re, replace)
        if (count > 0) { matches += count; optsChanged = true }
        next.push(out)
      }
      if (optsChanged) newOpts = next
    }

    if (matches > 0) updates.push({ id: r.id, question_text: newText, options: newOpts, matches })
  }

  const totalMatches = updates.reduce((s, u) => s + u.matches, 0)

  if (dryRun) {
    const sample = updates.slice(0, SAMPLE_SIZE).map(u => {
      const orig = all.find(a => a.id === u.id)!
      const before = u.question_text !== undefined ? orig.question_text : (u.options ? orig.options.find(o => re.test(o)) ?? '' : '')
      const after  = u.question_text !== undefined ? u.question_text   : (u.options?.find((o, i) => o !== orig.options[i]) ?? '')
      return { id: u.id, before, after }
    })
    return NextResponse.json({
      ok: true,
      total_matches: totalMatches,
      rows_affected: updates.length,
      sample,
    })
  }

  // Apply with bounded concurrency
  let updated = 0
  let failed = 0
  let cursor = 0
  async function worker() {
    while (true) {
      const i = cursor++
      if (i >= updates.length) return
      const u = updates[i]
      const patch: Record<string, unknown> = {}
      if (u.question_text !== undefined) patch.question_text = u.question_text
      if (u.options !== undefined) patch.options = u.options
      const { error } = await admin.from('book_questions').update(patch).eq('id', u.id)
      if (error) failed++; else updated++
    }
  }
  await Promise.all(Array.from({ length: CONCURRENCY }, () => worker()))

  return NextResponse.json({
    ok: true,
    rows_affected: updated,
    total_replacements: totalMatches,
    failed,
  })
}
