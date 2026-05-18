import type { Metadata } from 'next'
import Link from 'next/link'
import Header from '@/components/Header'
import Footer from '@/components/Footer'
import { IconHome, IconStar, IconSwords, IconHint, IconTime } from '@/components/icons'

export const metadata: Metadata = {
  title: 'Stranica ne postoji',
  description: 'Tražena stranica ne postoji ili je premeštena. Vrati se na Igre i odaberi kviz.',
  robots: { index: false, follow: false },
}

// Global 404 — rendered for every route that doesn't match anything,
// and whenever a page calls `notFound()` (e.g. profile by id, user
// detail in admin, etc.). Visually consistent with the rest of the
// site so anonymous visitors land on something friendly instead of
// the default black Next.js error screen.
export default function NotFound() {
  return (
    <div className="min-h-screen flex flex-col" style={{ background: '#FAFAFA' }}>
      <Header />

      <main className="flex-1 max-w-3xl mx-auto w-full px-4 sm:px-6 py-14 sm:py-20">
        {/* ── Hero ──────────────────────────────────────────────── */}
        <section className="relative text-center mb-10 overflow-hidden">
          {/* Soft ambient blobs — matches the landing-page aesthetic. */}
          <div className="absolute inset-0 -z-10 pointer-events-none">
            <div className="absolute top-0 -right-32 w-[360px] h-[360px] rounded-full opacity-40"
              style={{ background: 'radial-gradient(circle, #BCD9FF 0%, transparent 70%)' }} />
            <div className="absolute -bottom-20 -left-24 w-[320px] h-[320px] rounded-full opacity-40"
              style={{ background: 'radial-gradient(circle, #FFECBC 0%, transparent 70%)' }} />
          </div>

          <p className="text-[13px] font-bold uppercase tracking-widest mb-3" style={{ color: '#609DED' }}>
            404
          </p>
          <h1 className="font-black tracking-tight leading-[1.05] mb-5"
            style={{ color: '#343434', fontSize: 'clamp(40px, 8vw, 80px)' }}>
            Stranica ne postoji
          </h1>
          <p className="text-[15px] sm:text-[17px] max-w-md mx-auto mb-8 leading-relaxed"
            style={{ color: '#343434', opacity: 0.65 }}>
            Možda si link kucao ručno, ili je sadržaj premešten. Probaj sa jednom od igara ispod —
            ili se vrati na hub stranicu.
          </p>

          <div className="flex flex-col sm:flex-row gap-3 justify-center items-center">
            <Link href="/igre" className="btn btn-primary btn-lg w-full sm:w-auto sm:min-w-[200px]">
              ← Nazad na Igre
            </Link>
            <Link href="/" className="btn btn-secondary btn-lg w-full sm:w-auto sm:min-w-[200px]">
              Početna
            </Link>
          </div>
        </section>

        {/* ── Quick game shortcuts ─────────────────────────────── */}
        <section>
          <p className="text-[12px] font-bold uppercase tracking-widest text-center mb-4" style={{ color: '#9C9C9C' }}>
            Ili odmah skoči u kviz
          </p>
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
            {[
              { href: '/pro-kviz',          label: 'PRO kviz',      Icon: IconHome,   bg: '#BCD9FF', fg: '#1e5fa4' },
              { href: '/book-kviz',      label: 'Book kviz',     Icon: IconStar,   bg: '#FFECBC', fg: '#9c7a13' },
              { href: '/kafanski-kviz',  label: 'Kafanski',      Icon: IconStar,   bg: '#FEE2E2', fg: '#b91c1c' },
              { href: '/igraj-zajedno',  label: 'Trivia duel',   Icon: IconSwords, bg: '#FFECBC', fg: '#9c7a13' },
              { href: '/vesanje',        label: 'Vešanje',       Icon: IconHint,   bg: '#E8F8F0', fg: '#15803d' },
              { href: '/brzi-kviz',      label: 'Brzi kviz',     Icon: IconTime,   bg: '#FEE2E2', fg: '#b91c1c' },
            ].map(g => (
              <Link
                key={g.href}
                href={g.href}
                className="card-soft p-4 sm:p-5 flex items-center gap-3 transition-transform hover:-translate-y-0.5">
                <div className="w-10 h-10 rounded-2xl flex items-center justify-center flex-shrink-0" style={{ background: g.bg }}>
                  <g.Icon size={18} strokeWidth={2.2} />
                </div>
                <span className="font-bold text-[14px] tracking-tight" style={{ color: g.fg }}>
                  {g.label}
                </span>
              </Link>
            ))}
          </div>
        </section>
      </main>

      <Footer />
    </div>
  )
}
