import { type NextRequest, NextResponse } from 'next/server'
import { createServerClient } from '@supabase/ssr'

export async function middleware(request: NextRequest) {
  let supabaseResponse = NextResponse.next({ request })

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll()
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value))
          supabaseResponse = NextResponse.next({ request })
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, options))
        },
      },
    }
  )

  // IMPORTANT: do not run anything between createServerClient and getUser.
  // getUser() is what triggers the token refresh + cookie write.
  let userId: string | null = null
  let errMsg: string | null = null
  try {
    const { data, error } = await supabase.auth.getUser()
    userId = data.user?.id ?? null
    errMsg = error?.message ?? null
  } catch (e) {
    errMsg = e instanceof Error ? e.message : String(e)
  }

  // Debug headers so we can see middleware behavior in production without
  // relying on logs we can't access.
  supabaseResponse.headers.set('x-mw-ran', '1')
  supabaseResponse.headers.set('x-mw-user', userId ? 'yes' : 'no')
  if (errMsg) supabaseResponse.headers.set('x-mw-err', errMsg.slice(0, 120))

  return supabaseResponse
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|api/og|robots.txt|sitemap.xml|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico)$).*)',
  ],
}
