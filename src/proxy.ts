import { NextResponse, type NextRequest } from 'next/server'
import { createServerClient } from '@supabase/ssr'

// Next.js 16 renamed `middleware.ts` → `proxy.ts`. This file does two things
// on every non-static request:
//
// 1. Refreshes Supabase access tokens. Without this, the in-browser Supabase
//    client can't auto-refresh expired httpOnly cookies, so once a token
//    lapses the <Header /> useEffect's getUser() returns null and the right
//    side of the header (avatar, logout, recent users dropdown) silently
//    disappears. The refresh runs server-side here and writes the rotated
//    cookies back to the response.
// 2. Forces login for legacy `/kvizovi` and for individual duel ROOMS
//    (`/igraj-zajedno/<code>`). The bare `/igraj-zajedno` lobby stays
//    public so Googlebot can crawl + rank it — the lobby's client
//    component itself redirects anon to login the moment they try to
//    create or join a room.
export async function proxy(request: NextRequest) {
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

  // IMPORTANT: don't run anything between createServerClient and getUser.
  // getUser() is what triggers the token refresh + the cookie write above.
  const { data: { user } } = await supabase.auth.getUser()

  // Soft auth gate for routes that require a logged-in user. Page-level
  // checks still run, but redirecting here avoids flashing the page.
  const path = request.nextUrl.pathname
  // /kvizovi (legacy) stays fully gated except public share links.
  // For duels we only gate a specific room (/igraj-zajedno/<code>);
  // the bare /igraj-zajedno lobby is public for SEO.
  const isKvizovi = (path === '/kvizovi' || path.startsWith('/kvizovi/'))
    && !/\/kvizovi\/[^/]+\/share/.test(path)
  const isDuelRoom = /^\/igraj-zajedno\/.+/.test(path)
  const isProtected = isKvizovi || isDuelRoom

  if (!user && isProtected) {
    const url = request.nextUrl.clone()
    url.pathname = '/auth/prijava'
    url.searchParams.set('redirect', path)
    return NextResponse.redirect(url)
  }

  return supabaseResponse
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|api/og|robots.txt|sitemap.xml|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico)$).*)',
  ],
}
