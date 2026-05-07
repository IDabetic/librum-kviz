import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'

// Mark a duel room as finished. Called from the in-game exit button and
// from pagehide/visibilitychange (via sendBeacon) so a player closing the
// tab still gets the current scores counted on the leaderboard.
//
// Authorization: the caller must be host or guest of the room. RLS would
// likely allow this anyway, but we double-check here so a stray request
// can't flip an unrelated room to 'finished'.

export async function POST(req: Request) {
  let body: { room_id?: string } = {}
  try {
    const text = await req.text()
    body = text ? JSON.parse(text) : {}
  } catch {
    return NextResponse.json({ ok: false }, { status: 400 })
  }
  if (!body.room_id) return NextResponse.json({ ok: false }, { status: 400 })

  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ ok: false }, { status: 401 })

  const { data: room } = await supabase
    .from('game_rooms')
    .select('id, host_id, guest_id, status')
    .eq('id', body.room_id)
    .single()

  if (!room) return NextResponse.json({ ok: false }, { status: 404 })
  if (room.host_id !== user.id && room.guest_id !== user.id) {
    return NextResponse.json({ ok: false }, { status: 403 })
  }
  if (room.status === 'finished') return NextResponse.json({ ok: true, already: true })

  await supabase.from('game_rooms').update({ status: 'finished' }).eq('id', body.room_id)
  return NextResponse.json({ ok: true })
}
