import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'

export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url)
  const code = searchParams.get('code')
  const tokenHash = searchParams.get('token_hash')
  const type = searchParams.get('type')

  const supabase = await createClient()

  if (code) {
    // PKCE flow — exchange code for session
    const { error } = await supabase.auth.exchangeCodeForSession(code)
    if (!error) {
      // Sign out immediately so user logs in manually
      await supabase.auth.signOut()
      return NextResponse.redirect(`${origin}/auth/prijava?potvrdjeno=1`)
    }
  }

  if (tokenHash && type) {
    // OTP/magic link flow
    const { error } = await supabase.auth.verifyOtp({ token_hash: tokenHash, type: type as 'email' | 'signup' | 'magiclink' })
    if (!error) {
      await supabase.auth.signOut()
      return NextResponse.redirect(`${origin}/auth/prijava?potvrdjeno=1`)
    }
  }

  // Something went wrong — redirect to login with error
  return NextResponse.redirect(`${origin}/auth/prijava?greska=potvrda`)
}
