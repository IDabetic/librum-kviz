import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'

export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url)
  const code = searchParams.get('code')
  const tokenHash = searchParams.get('token_hash')
  const type = searchParams.get('type')
  const next = searchParams.get('next')

  const supabase = await createClient()

  // ── Password recovery ─────────────────────────────────────────────────
  // Keep the session active and route the user to the new-password screen
  // so they can immediately set a password.
  const isRecovery = type === 'recovery'

  if (code) {
    const { error } = await supabase.auth.exchangeCodeForSession(code)
    if (!error) {
      if (isRecovery) {
        return NextResponse.redirect(`${origin}${next || '/auth/nova-lozinka'}`)
      }
      // Email confirmation: sign out so user logs in manually
      await supabase.auth.signOut()
      return NextResponse.redirect(`${origin}/auth/prijava?potvrdjeno=1`)
    }
  }

  if (tokenHash && type) {
    const { error } = await supabase.auth.verifyOtp({
      token_hash: tokenHash,
      type: type as 'email' | 'signup' | 'magiclink' | 'recovery' | 'invite',
    })
    if (!error) {
      if (isRecovery) {
        return NextResponse.redirect(`${origin}${next || '/auth/nova-lozinka'}`)
      }
      await supabase.auth.signOut()
      return NextResponse.redirect(`${origin}/auth/prijava?potvrdjeno=1`)
    }
  }

  return NextResponse.redirect(`${origin}/auth/prijava?greska=potvrda`)
}
