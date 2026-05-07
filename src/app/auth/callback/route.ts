import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'

export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url)
  const code = searchParams.get('code')
  const tokenHash = searchParams.get('token_hash')
  const type = searchParams.get('type')
  const next = searchParams.get('next')

  // If `next` is set, the caller wants the user to land somewhere with an
  // active session (e.g. password recovery → /auth/nova-lozinka). Otherwise
  // this is an email-confirm flow and we sign the user out so they log in
  // manually.
  const keepSession = !!next || type === 'recovery'

  const supabase = await createClient()

  if (code) {
    const { error } = await supabase.auth.exchangeCodeForSession(code)
    if (!error) {
      if (keepSession) {
        return NextResponse.redirect(`${origin}${next || '/auth/nova-lozinka'}`)
      }
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
      if (keepSession) {
        return NextResponse.redirect(`${origin}${next || '/auth/nova-lozinka'}`)
      }
      await supabase.auth.signOut()
      return NextResponse.redirect(`${origin}/auth/prijava?potvrdjeno=1`)
    }
  }

  return NextResponse.redirect(`${origin}/auth/prijava?greska=potvrda`)
}
