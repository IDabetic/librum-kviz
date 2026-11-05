import { NextResponse } from 'next/server'
import { z } from 'zod'
import { createAdminClient } from '@/lib/supabase/admin'

// Odjava jednim klikom iz mejl programa (List-Unsubscribe-Post, RFC 8058): Gmail i Apple Mail šalju POST bez kolačića.
export async function POST(_zahtev: Request, { params }: { params: Promise<{ token: string }> }) {
  const { token } = await params
  if (!z.string().uuid().safeParse(token).success) {
    return NextResponse.json({ error: { message: 'neispravan link' } }, { status: 422 })
  }
  const { error } = await createAdminClient().rpc('mejl_odjavi', { p_token: token })
  if (error) return NextResponse.json({ error: { message: error.message } }, { status: 500 })
  return NextResponse.json({ data: { odjavljen: true } })
}
