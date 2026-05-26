import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'

// Ask Claude to propose Serbian transcriptions for a batch of Book
// questions that contain non-Serbian Latin characters (Q W X Y).
// Returns one suggestion per id with the proposed new question_text
// and options. The admin reviews + approves in the UI before any DB
// write happens (that goes through /api/admin/book-questions-apply-edits).
//
// Requires ANTHROPIC_API_KEY in Vercel env (server-only).

const ADMIN_ROLES = new Set(['urednik', 'moderator', 'super_admin'])
const BATCH_SIZE = 10  // Claude handles 10 questions per call comfortably
const MODEL = 'claude-sonnet-4-6'  // Sonnet is plenty for transliteration

type Item = { id: string; question_text: string; options: string[] }
type Suggestion = Item & { changed: boolean }

const SYSTEM_PROMPT = `Ti si stručnjak za srpsku latinicu i transkripciju stranih imena.
Tvoj zadatak je da u sledećim kviz pitanjima TRANSKRIBUJEŠ strana imena, naslove
i pojmove na srpsku latinicu, prema pravilima Pravopisa srpskoga jezika.

Pravila:
- Lična imena, naslovi, geografski pojmovi: transkribuj fonetski na srpsku latinicu
  (Harry Potter → Hari Poter; J.K. Rowling → Dž.K. Rouling; The Lord of the Rings → Gospodar prstenova ako postoji ustaljen prevod, inače transkribuj; Sherlock Holmes → Šerlok Holms).
- Ne menjaj značenje. Ne pišti pitanje. Ne menjaj odgovore na nivou činjenice — samo
  pravopisno transkribuj strane reči.
- Brendovi koji se internacionalno ne transkribuju (Apple, McDonald's, iPhone, Netflix)
  ostavi kako jesu — to nije greška.
- Srpsko latinično pismo NEMA: Q, W, X, Y. Ako vidiš ta slova u stranim rečima,
  transkribuj.
- Vrati ISTI broj odgovora i u ISTOM redosledu. Prvi odgovor (index 0) je tačan.
- Ako ne vidiš ništa za transkribovati u pitanju, vrati ga nepromenjenog.

Format izlaza je STRIKTNO JSON niz objekata, BEZ proznog teksta ispred ili posle:
[{"id":"...","question_text":"...","options":["...","...","...","..."]}, ...]`

export async function POST(req: Request) {
  let body: { ids?: string[] }
  try { body = await req.json() } catch { return NextResponse.json({ ok: false, error: 'bad-json' }, { status: 400 }) }
  const ids = Array.isArray(body.ids) ? body.ids.filter(x => typeof x === 'string') : []
  if (ids.length === 0) return NextResponse.json({ ok: false, error: 'no-ids' }, { status: 400 })
  if (ids.length > 50) return NextResponse.json({ ok: false, error: 'too-many', detail: 'Max 50 po pozivu' }, { status: 400 })

  const apiKey = process.env.ANTHROPIC_API_KEY
  if (!apiKey) {
    return NextResponse.json({
      ok: false, error: 'ANTHROPIC_API_KEY nije postavljen u Vercel env.',
    }, { status: 500 })
  }

  // Auth
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ ok: false, error: 'unauth' }, { status: 401 })
  const { data: profile } = await supabase
    .from('profiles').select('role').eq('id', user.id).single()
  if (!profile || !ADMIN_ROLES.has(String(profile.role))) {
    return NextResponse.json({ ok: false, error: 'forbidden' }, { status: 403 })
  }

  // Load the selected rows
  const { data, error } = await supabase
    .from('book_questions')
    .select('id, question_text, options')
    .in('id', ids)
  if (error) return NextResponse.json({ ok: false, error: 'fetch-failed', detail: error.message }, { status: 500 })
  const items = ((data || []) as Item[]).filter(i => Array.isArray(i.options))

  // Batch the Claude calls
  const suggestions: Suggestion[] = []
  for (let i = 0; i < items.length; i += BATCH_SIZE) {
    const batch = items.slice(i, i + BATCH_SIZE)
    try {
      const result = await callClaude(apiKey, batch)
      for (const item of batch) {
        const sug = result.find(r => r.id === item.id)
        if (sug) {
          const changed = sug.question_text !== item.question_text
            || sug.options.some((o, idx) => o !== item.options[idx])
          suggestions.push({ id: sug.id, question_text: sug.question_text, options: sug.options, changed })
        } else {
          // Claude omitted this one — return unchanged
          suggestions.push({ id: item.id, question_text: item.question_text, options: item.options, changed: false })
        }
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : 'unknown'
      return NextResponse.json({
        ok: false, error: 'claude-call-failed', detail: msg,
        partial: suggestions,
      }, { status: 502 })
    }
  }

  return NextResponse.json({ ok: true, suggestions })
}

async function callClaude(apiKey: string, batch: Item[]): Promise<Item[]> {
  const userPayload = batch.map(i => ({
    id: i.id,
    question_text: i.question_text,
    options: i.options,
  }))

  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model: MODEL,
      max_tokens: 4000,
      system: SYSTEM_PROMPT,
      messages: [{
        role: 'user',
        content: `Transkribuj sledeća kviz pitanja. Vrati JSON niz isti dužine, sa istim id-jevima:\n\n${JSON.stringify(userPayload, null, 2)}`,
      }],
    }),
  })

  if (!res.ok) {
    const text = await res.text().catch(() => '')
    throw new Error(`Claude API ${res.status}: ${text.slice(0, 200)}`)
  }
  const json = await res.json() as { content?: { type: string; text?: string }[] }
  const textBlock = json.content?.find(c => c.type === 'text')
  if (!textBlock?.text) throw new Error('Claude vratio prazan odgovor')

  // Extract JSON from text (Claude may wrap in markdown fences)
  let raw = textBlock.text.trim()
  const fence = raw.match(/```(?:json)?\s*([\s\S]*?)```/)
  if (fence) raw = fence[1].trim()

  let parsed: unknown
  try { parsed = JSON.parse(raw) }
  catch { throw new Error(`Claude vratio neispravan JSON: ${raw.slice(0, 200)}`) }
  if (!Array.isArray(parsed)) throw new Error('Claude odgovor nije niz')

  const out: Item[] = []
  for (const p of parsed) {
    if (typeof p !== 'object' || p === null) continue
    const o = p as Record<string, unknown>
    if (typeof o.id !== 'string' || typeof o.question_text !== 'string' || !Array.isArray(o.options)) continue
    out.push({
      id: o.id,
      question_text: o.question_text,
      options: o.options.map(x => String(x ?? '')),
    })
  }
  return out
}
