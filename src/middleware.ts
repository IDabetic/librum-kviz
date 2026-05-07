import { type NextRequest, NextResponse } from 'next/server'
import { createServerClient } from '@supabase/ssr'

// Refreshes the Supabase access token on every request and writes the new
// cookies back to both the inbound request (so Server Components see the
// refreshed session for THIS render) and the outbound response (so the
// browser persists them for the next request).
//
// Without this middleware, expired access tokens never get refreshed in the
// browser, which causes <Header />'s client-side `auth.getUser()` to return
// null even though the server-side render still works for the same user.
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
  await supabase.auth.getUser()

  return supabaseResponse
}

export const config = {
  matcher: [
    // Run on all paths except static assets and the OG image route.
    '/((?!_next/static|_next/image|favicon.ico|api/og|robots.txt|sitemap.xml|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico)$).*)',
  ],
}
