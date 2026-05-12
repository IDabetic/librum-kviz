'use client'

import { useState } from 'react'

// Shared "Podeli rezultat" button for every end-of-game screen.
// Centralizing it gives us one consistent text template across PRO,
// Book, Kafanski, Trivia duel, Vešanje, Brzi kviz — and makes future
// edits (different copy, native share sheet behavior, analytics) a
// single-file change instead of six.
//
// Template:
//   "Osvojio/la sam <score> bodova u <gameLabel> na Librum kvizu!
//    <extra>
//    Probaj i ti: <url>"
//
// Native Web Share API is used when available (mobile + most desktops),
// with a clipboard fallback for browsers that don't expose it.

type Accent = 'blue' | 'gold' | 'red' | 'green' | 'yellow' | 'purple'

const ACCENT_STYLES: Record<Accent, { idle: React.CSSProperties; done: React.CSSProperties }> = {
  blue:   { idle: { background: '#BCD9FF', color: '#1e5fa4' }, done: { background: '#E8F8F0', color: '#15803d' } },
  gold:   { idle: { background: '#FFECBC', color: '#9c7a13' }, done: { background: '#E8F8F0', color: '#15803d' } },
  red:    { idle: { background: '#FEE2E2', color: '#b91c1c' }, done: { background: '#E8F8F0', color: '#15803d' } },
  green:  { idle: { background: '#E8F8F0', color: '#15803d' }, done: { background: '#BCD9FF', color: '#1e5fa4' } },
  yellow: { idle: { background: '#FFCB46', color: '#343434' }, done: { background: '#E8F8F0', color: '#15803d' } },
  purple: { idle: { background: '#EDE4FF', color: '#5b21b6' }, done: { background: '#E8F8F0', color: '#15803d' } },
}

export default function ShareResultButton({
  gameLabel, score, extra, accent = 'blue', size = 'md', className = '',
}: {
  gameLabel: string
  score: number | string
  /** Optional appendix line, e.g. "12 tačnih · 3 pogrešna" or "vs Marko 100:80". */
  extra?: string
  accent?: Accent
  size?: 'sm' | 'md' | 'lg'
  className?: string
}) {
  const [shared, setShared] = useState(false)
  const [error, setError] = useState(false)

  async function onClick() {
    if (shared) return
    setError(false)

    const url = typeof window !== 'undefined'
      ? `${window.location.origin}`
      : 'https://kviz.librum.club'

    // Build the share copy. Keep it short — most platforms truncate
    // after ~280 chars, and a tighter line gets shared more often.
    const lines = [
      `Osvojio/la sam ${score} bodova u ${gameLabel} na Librum kvizu! 🎯`,
    ]
    if (extra) lines.push(extra)
    lines.push(`Probaj i ti: ${url}`)
    const text = lines.join('\n')

    try {
      if (typeof navigator !== 'undefined' && typeof navigator.share === 'function') {
        await navigator.share({ title: `Librum kviz — ${gameLabel}`, text, url })
      } else if (typeof navigator !== 'undefined' && navigator.clipboard) {
        await navigator.clipboard.writeText(text)
      } else {
        setError(true)
        return
      }
      setShared(true)
      setTimeout(() => setShared(false), 2400)
    } catch (e) {
      // User cancelled the share sheet — silent. Anything else flashes
      // a brief error so they know to try again.
      const name = e instanceof Error ? e.name : ''
      if (name !== 'AbortError') setError(true)
    }
  }

  const styles = ACCENT_STYLES[accent]
  const sizeCls = size === 'sm' ? 'btn-sm' : size === 'lg' ? 'btn-lg' : 'btn-md'

  return (
    <button
      type="button"
      onClick={onClick}
      className={`btn ${sizeCls} ${className}`}
      style={shared ? styles.done : styles.idle}
    >
      {shared
        ? '✓ Podeljeno'
        : error
          ? 'Pokušaj ponovo'
          : 'Podeli rezultat'}
    </button>
  )
}
