import { NextResponse, type NextRequest } from 'next/server'

export function proxy(request: NextRequest) {
  const protectedRoutes = ['/kvizovi', '/profil', '/igraj-zajedno']
  const isSharePage = /\/kvizovi\/[^/]+\/share/.test(request.nextUrl.pathname)
  const isProtected = !isSharePage && protectedRoutes.some(r => request.nextUrl.pathname.startsWith(r))

  const hasSession = request.cookies.getAll().some(c => c.name.startsWith('sb-'))

  if (!hasSession && isProtected) {
    const url = request.nextUrl.clone()
    url.pathname = '/auth/prijava'
    url.searchParams.set('redirect', request.nextUrl.pathname)
    return NextResponse.redirect(url)
  }

  if (hasSession && request.nextUrl.pathname.startsWith('/auth/')) {
    return NextResponse.redirect(new URL('/kvizovi', request.url))
  }

  return NextResponse.next({ request })
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)'],
}
