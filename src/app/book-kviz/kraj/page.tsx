'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import { IconTrophy, IconStar, IconDiscover } from '@/components/icons'

type GenreBreakdown = Record<string, { correct: number; total: number }>

type Result = {
  score: number
  questionsReached: number
  correct: number
  wrong: number
  skipped: number
  accuracy: number
  bestCombo: number
  totalTime: number
  topGenre: string | null
  topPct: number | null
  breakdown: GenreBreakdown
  sessionId?: string
}

const GENRE_COLOR: Record<string, { bg: string; fg: string }> = {
  'Drama':       { bg: '#FFECBC', fg: '#9c7a13' },
  'Fantastika':  { bg: '#BCD9FF', fg: '#1e5fa4' },
  'Ljubavni':    { bg: '#FEE2E2', fg: '#b91c1c' },
  'Istorijski':  { bg: '#E8F8F0', fg: '#15803d' },
  'Krimi':       { bg: '#F2F2F2', fg: '#343434' },
  'Triler':      { bg: '#FFECBC', fg: '#9c7a13' },
  'Domaći':      { bg: '#BCD9FF', fg: '#1e5fa4' },
  'Horor':       { bg: '#FEE2E2', fg: '#b91c1c' },
}

function fmtTime(s: number): string {
  const m = Math.floor(s / 60)
  const sec = s % 60
  return `${String(m).padStart(2, '0')}:${String(sec).padStart(2, '0')}`
}

export default function BookKvizEnd() {
  const router = useRouter()
  const [r, setR] = useState<Result | null>(null)

  useEffect(() => {
    const raw = sessionStorage.getItem('book-result')
    if (!raw) { router.push('/book-kviz'); return }
    try { setR(JSON.parse(raw)) } catch { router.push('/book-kviz') }
  }, [router])

  if (!r) {
    return (
      <div className="min-h-screen flex items-center justify-center" style={{ background: '#FAFAFA' }}>
        <div className="w-8 h-8 rounded-full border-2 animate-spin"
          style={{ borderColor: '#9c7a13', borderTopColor: 'transparent' }} />
      </div>
    )
  }

  const breakdownEntries = Object.entries(r.breakdown)
    .filter(([_, s]) => s.total > 0)
    .map(([g, s]) => ({ genre: g, correct: s.correct, total: s.total, pct: (s.correct / s.total) * 100 }))
    .sort((a, b) => b.pct - a.pct || b.correct - a.correct)

  const topStyle = r.topGenre ? GENRE_COLOR[r.topGenre] || { bg: '#FFECBC', fg: '#9c7a13' } : null

  return (
    <div className="min-h-screen flex flex-col" style={{ background: '#FAFAFA' }}>
      <main className="flex-1 max-w-2xl mx-auto px-4 sm:px-6 py-10 sm:py-14 w-full">

        <div className="text-center mb-8">
          <p className="text-[13px] font-bold uppercase tracking-widest mb-2" style={{ color: '#9c7a13' }}>
            Kraj
          </p>
          <h1 className="font-black tracking-tight leading-[1.05] mb-3"
            style={{ color: '#343434', fontSize: 'clamp(36px, 7vw, 56px)' }}>
            {r.score}
          </h1>
          <p className="text-[14px]" style={{ color: '#9C9C9C' }}>
            bodova u Book kvizu
          </p>
        </div>

        {/* Top genre */}
        {r.topGenre && topStyle && (
          <div className="card-soft p-6 mb-5 text-center" style={{ background: topStyle.bg }}>
            <div className="inline-flex items-center justify-center w-12 h-12 rounded-2xl mb-3"
              style={{ background: 'rgba(252,252,252,0.7)' }}>
              <IconTrophy size={22} className={`text-[${topStyle.fg}]`} strokeWidth={2.2} />
            </div>
            <p className="text-[12px] font-bold uppercase tracking-widest mb-1" style={{ color: topStyle.fg }}>
              Najjači si u
            </p>
            <p className="font-black tracking-tight mb-1" style={{ color: topStyle.fg, fontSize: 'clamp(28px, 5vw, 40px)' }}>
              {r.topGenre}
            </p>
            {r.topPct != null && (
              <p className="text-[13px]" style={{ color: topStyle.fg, opacity: 0.8 }}>
                {r.topPct.toFixed(0)}% tačnih u ovom žanru
              </p>
            )}
          </div>
        )}

        {/* Stats */}
        <div className="grid grid-cols-3 gap-3 mb-5">
          <Stat label="Pitanja" value={r.questionsReached} />
          <Stat label="Tačnost" value={`${Math.round(r.accuracy)}%`} />
          <Stat label="Najbolji niz" value={r.bestCombo} />
          <Stat label="Tačno" value={r.correct} accent="#15803d" />
          <Stat label="Pogrešno" value={r.wrong} accent="#b91c1c" />
          <Stat label="Vreme" value={fmtTime(r.totalTime)} />
        </div>

        {/* Genre breakdown */}
        {breakdownEntries.length > 0 && (
          <div className="card-soft p-5 mb-5">
            <p className="text-[11px] font-bold uppercase tracking-widest mb-3" style={{ color: '#9C9C9C' }}>
              Po žanrovima
            </p>
            <div className="space-y-2">
              {breakdownEntries.map(b => {
                const style = GENRE_COLOR[b.genre] || { bg: '#F2F2F2', fg: '#343434' }
                return (
                  <div key={b.genre} className="flex items-center gap-3">
                    <span className="chip flex-shrink-0" style={{ background: style.bg, color: style.fg }}>
                      {b.genre}
                    </span>
                    <div className="flex-1 h-2 rounded-full overflow-hidden" style={{ background: '#F2F2F2' }}>
                      <div className="h-full" style={{ width: `${b.pct}%`, background: style.fg, opacity: 0.7 }} />
                    </div>
                    <span className="text-[12px] tabular-nums flex-shrink-0" style={{ color: '#9C9C9C' }}>
                      {b.correct}/{b.total}
                    </span>
                  </div>
                )
              })}
            </div>
          </div>
        )}

        <div className="space-y-2">
          <Link href="/book-kviz/start" className="btn btn-primary btn-lg w-full">
            Igraj ponovo
          </Link>
          <Link href="/leaderboard" className="btn btn-secondary btn-md w-full">
            Rang lista
          </Link>
          <Link href="/" className="block text-center text-[13px] font-medium mt-3" style={{ color: '#9C9C9C' }}>
            ← Početna
          </Link>
        </div>
      </main>
    </div>
  )
}

function Stat({ label, value, accent }: { label: string; value: number | string; accent?: string }) {
  return (
    <div className="card-soft p-4 text-center">
      <p className="font-black text-[18px] tracking-tight" style={{ color: accent || '#343434' }}>{value}</p>
      <p className="text-[10px] mt-1" style={{ color: '#9C9C9C' }}>{label}</p>
    </div>
  )
}
