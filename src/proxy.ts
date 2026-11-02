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
//
// ⚠ ZAŠTO OVDE STOJE ROK I PROVERA KOLAČIĆA (27.08.2026)
// -----------------------------------------------------
// Sajt je danima štucao: naslovna je nasumično stajala 5 s, 12 s, pa i preko
// 30 s, dok je `/robots.txt` (izuzet iz matcher-a) uvek išao za 0,15 s. Vercel
// pritom nije prijavio NIJEDNU grešku, sve je bilo 200, samo sporo.
//
// Uzrok: `getUser()` je mrežni poziv ka Supabase auth servisu, išao je na
// SVAKI zahtev koji nije statički fajl, i to bez ikakvog roka. Kad taj poziv
// zastane, zastane cela strana. Plaćali su ga i anonimni posetioci i Googlebot,
// kojima nema šta da se osveži jer nemaju sesiju.
//
// Dva pojasa, oba čuvaju postojeće ponašanje:
//   1. nema `sb-` kolačića → nema sesije → NIJEDAN mrežni poziv,
//   2. ima kolačić → poziv sa rokom; ako rok istekne, propuštamo zahtev
//      umesto da ga oborimo. Provera na nivou strane i dalje radi, pa
//      zastoj kod Supabase-a više ne može da zaključa ceo sajt.
const ROK_MS = 3000

export async function proxy(request: NextRequest) {
  const path = request.nextUrl.pathname

  // /kvizovi (legacy) stays fully gated except public share links.
  // For duels we only gate a specific room (/igraj-zajedno/<code>);
  // the bare /igraj-zajedno lobby is public for SEO.
  const isKvizovi = (path === '/kvizovi' || path.startsWith('/kvizovi/'))
    && !/\/kvizovi\/[^/]+\/share/.test(path)
  const isDuelRoom = /^\/igraj-zajedno\/.+/.test(path)
  const isProtected = isKvizovi || isDuelRoom
  const isPlay =
    /\/start\/?$/.test(path) ||
    isDuelRoom ||
    path.startsWith('/vesanje/uzivo') ||
    path === '/vesanje/dvoje' ||
    path === '/kafanski-kviz/duel' ||
    path.startsWith('/dodaj-pitanja')

  // Pojas 1: bez Supabase kolačića posetilac sigurno nije prijavljen. Nema se
  // šta osvežiti ni proveriti, pa se mrežni poziv preskače u celosti. Ovo nosi
  // najveći deo saobraćaja: svi anonimni pregledi i sve posete pretraživača.
  // Provera je namerno šira nego što mora: `@supabase/ssr` bez podеšenog
  // `cookieOptions.name` pravi `sb-<ref>-auth-token` (i deljene `.0`, `.1`
  // kod dugih tokena). Hvatamo i bilo koji `auth-token`, jer je cena lažnog
  // pozitiva jedan suvišan poziv, a cena lažnog negativa je prijavljen
  // korisnik izbačen na prijavu. Nesimetrično, pa idemo na sigurniju stranu.
  const imaSesiju = request.cookies
    .getAll()
    .some((c) => c.name.startsWith('sb-') || c.name.includes('auth-token'))
  if (!imaSesiju) {
    return isProtected ? naPrijavu(request, path) : NextResponse.next({ request })
  }

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
  let user = null
  let posrnuo = false

  let tajmer: ReturnType<typeof setTimeout> | undefined
  try {
    const odgovor = await Promise.race([
      supabase.auth.getUser(),
      new Promise<never>((_, odbij) => {
        tajmer = setTimeout(() => odbij(new Error('SUPABASE_ROK')), ROK_MS)
      }),
    ])
    user = odgovor?.data?.user ?? null
  } catch {
    // Rok je istekao ili je mreža pukla. NE obaramo zahtev i NE šaljemo
    // prijavljenog korisnika na prijavu samo zato što je Supabase spor.
    posrnuo = true
  } finally {
    clearTimeout(tajmer)
  }

  // Soft auth gate for routes that require a logged-in user. Page-level
  // checks still run, but redirecting here avoids flashing the page.
  if (!user && isProtected && !posrnuo) {
    return naPrijavu(request, path)
  }

  if (user && isPlay && !posrnuo) {
    try {
      const { data } = await supabase
        .from('profiles')
        .select('suspended_until')
        .eq('id', user.id)
        .maybeSingle()
      const doKad = data?.suspended_until as string | null | undefined
      if (doKad && Date.parse(doKad) > Date.now()) {
        const url = request.nextUrl.clone()
        url.pathname = '/profil'
        url.search = 'suspendovan=1'
        return NextResponse.redirect(url)
      }
    } catch {
      // Kolona još ne postoji — ne blokiramo igru.
    }
  }

  return supabaseResponse
}

/** Preusmerenje na prijavu, sa pamćenjem strane sa koje je posetilac došao. */
function naPrijavu(request: NextRequest, path: string) {
  const url = request.nextUrl.clone()
  url.pathname = '/auth/prijava'
  url.searchParams.set('redirect', path)
  return NextResponse.redirect(url)
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|api/og|robots.txt|sitemap.xml|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico)$).*)',
  ],
}
