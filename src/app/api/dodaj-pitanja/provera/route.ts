import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { rateLimit } from '@/lib/rate-limit'
import { jeSegment } from '@/lib/segmenti'
import { proveriPitanje } from '@/lib/submit-pitanja'

export async function POST(req: Request) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ status: 'unauth' }, { status: 401 })

  const limit = rateLimit(`provera-pitanja:${user.id}`, 60, 60_000)
  if (!limit.ok) {
    return NextResponse.json({ status: 'rate-limited' }, { status: 429 })
  }

  let telo: { segment?: unknown; text?: unknown }
  try {
    telo = await req.json()
  } catch {
    return NextResponse.json({ status: 'bad-json' }, { status: 400 })
  }

  const seg = String(telo.segment ?? '')
  const tekst = typeof telo.text === 'string' ? telo.text.slice(0, 1000) : ''
  if (!jeSegment(seg)) {
    return NextResponse.json({ status: 'bad-segment' }, { status: 400 })
  }

  try {
    const data = await proveriPitanje(seg, tekst)
    return NextResponse.json(data)
  } catch {
    return NextResponse.json({ status: 'greska' }, { status: 500 })
  }
}
