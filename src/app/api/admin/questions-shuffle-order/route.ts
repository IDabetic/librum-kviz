import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createAdminClient } from '@/lib/supabase/admin'

// Randomize the `order_num` field across every row in public.questions.
// The games already pick questions randomly per match (Fisher-Yates on
// the fetched pool), so this is purely an admin-facing operation —
// when sorting the question list by `order_num` or running any export
// in that order, the sequence is now a fresh random permutation.
//
// Service-role + chunked UPDATEs so a 3k-row pool finishes in a few
// seconds without holding a long transaction.

const ADMIN_ROLES = new Set(['urednik', 'moderator', 'super_admin'])
const CONCURRENCY = 20

export async function POST() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ ok: false, error: 'unauth' }, { status: 401 })

  const { data: profile } = await supabase
    .from('profiles').select('role').eq('id', user.id).single()
  if (!profile || !ADMIN_ROLES.has(String(profile.role))) {
    return NextResponse.json({ ok: false, error: 'forbidden' }, { status: 403 })
  }

  const admin = createAdminClient()

  // Pull just the IDs — we don't need the rest.
  const ids: string[] = []
  const PAGE = 1000
  for (let from = 0; ; from += PAGE) {
    const { data, error } = await admin
      .from('questions').select('id').range(from, from + PAGE - 1)
    if (error) {
      return NextResponse.json({ ok: false, error: 'fetch-failed', detail: error.message }, { status: 500 })
    }
    if (!data || data.length === 0) break
    ids.push(...data.map(r => r.id as string))
    if (data.length < PAGE) break
  }

  if (ids.length === 0) {
    return NextResponse.json({ ok: true, stats: { total: 0, updated: 0 } })
  }

  // Build a random permutation of [0..N-1] and assign each row a new
  // order_num. Fisher–Yates over the index array — guarantees every
  // row gets a unique integer.
  const order = Array.from({ length: ids.length }, (_, i) => i)
  for (let i = order.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[order[i], order[j]] = [order[j], order[i]]
  }

  // Apply with bounded concurrency.
  let updated = 0
  let failed = 0
  let cursor = 0
  async function worker() {
    while (true) {
      const i = cursor++
      if (i >= ids.length) return
      const { error } = await admin
        .from('questions')
        .update({ order_num: order[i] })
        .eq('id', ids[i])
      if (error) failed++
      else updated++
    }
  }
  await Promise.all(Array.from({ length: CONCURRENCY }, () => worker()))

  return NextResponse.json({
    ok: true,
    stats: { total: ids.length, updated, failed },
  })
}
