'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import { IconShare, IconTrophy, IconStar, IconDiscover } from '@/components/icons'

type Result = {
  score: number
  questionsReached: number
  correct: number
  wrong: number
  skipped: number
  accuracy: number
  bestCombo: number
  totalTime: number
  sessionId?: string
}

function fmtTime(s: number): string {
  const m = Math.floor(s / 60)
  const sec = s % 60
  return `${String(m).padStart(2, '0')}:${String(sec).padStart(2, '0')}`
}

export default function KrajIgrePage() {
  const router = useRouter()
  const [result, setResult] = useState<Result | null>(null)
  const [shared, setShared] = useState(false)

  useEffect(() => {
    const stored = sessionStorage.getItem('survivor-result')
    if (!stored) { router.push('/igraj'); return }
    setResult(JSON.parse(stored))
  }, [router])

  if (!result) return null

  const { score, questionsReached, correct, wrong, skipped, accuracy, bestCombo, totalTime } = result
  const tone = questionsReached >= 100 ? 'epic' : questionsReached >= 50 ? 'great' : questionsReached >= 25 ? 'good' : 'try'
  const headline = tone === 'epic' ? 'Maraton znanja.' : tone === 'great' ? 'Sjajno odigrano.' : tone === 'good' ? 'Solidno!' : 'Probaj ponovo.'
  const accent = tone === 'epic' ? '#FFCB46' : tone === 'great' ? '#4CAF50' : tone === 'good' ? '#609DED' : '#9C9C9C'

  async function handleShare() {
    const url = `${window.location.origin}/igraj`
    const text = `Postigao/la sam ${score} bodova i preživeo/la ${questionsReached} pitanja u Librum Survivor kvizu!`
    if (typeof navigator.share === 'function') {
      try { await navigator.share({ title: 'Librum Kviz', text, url }) }
      catch { /* cancelled */ }
    } else {
      await navigator.clipboard.writeText(`${text} ${url}`)
      setShared(true)
      setTimeout(() => setShared(false), 2500)
    }
  }

  return (
    <div className="min-h-screen py-10 sm:py-14 px-4 sm:px-6" style={{ background: '#FAFAFA' }}>
      <div className="max-w-xl mx-auto">

        {/* Hero */}
        <div className="card-soft overflow-hidden mb-4">
          <div className="px-7 py-10 sm:py-14 text-center" style={{ background: 'linear-gradient(135deg, #BCD9FF 0%, #FFECBC 100%)' }}>
            <p className="text-[12px] font-bold uppercase tracking-widest mb-3" style={{ color: '#343434', opacity: 0.6 }}>
              Kraj igre
            </p>
            <h1 className="font-black tracking-tight mb-2 leading-[1.05]"
              style={{ color: '#343434', fontSize: 'clamp(36px, 7vw, 56px)' }}>
              {headline}
            </h1>
            <p className="text-[13px]" style={{ color: '#343434', opacity: 0.55 }}>
              Stigao/la si do <strong>{questionsReached}</strong> pitanja
            </p>
          </div>

          <div className="p-7 sm:p-8 text-center">
            <div className="font-black tracking-tight" style={{ color: '#343434', fontSize: 'clamp(56px, 12vw, 96px)', lineHeight: 1 }}>
              {score}
            </div>
            <div className="text-[14px] font-semibold mt-1" style={{ color: accent }}>bodova</div>

            {/* Stats grid */}
            <div className="grid grid-cols-3 gap-3 mt-7">
              <Stat label="Tačnih" value={correct} accent="#4CAF50" />
              <Stat label="Pogr." value={wrong} accent="#E55353" />
              <Stat label="Niz" value={bestCombo} accent="#609DED" />
              <Stat label="Tačnost" value={`${Math.round(accuracy)}%`} accent="#343434" />
              <Stat label="Vreme"  value={fmtTime(totalTime)} accent="#343434" />
              <Stat label="Pres."  value={skipped} accent="#9C9C9C" />
            </div>
          </div>
        </div>

        {/* Actions */}
        <div className="grid grid-cols-2 gap-3 mb-3">
          <Link href="/igraj/start" className="btn btn-primary btn-lg">Igraj ponovo</Link>
          <Link href="/leaderboard" className="btn btn-secondary btn-lg">Rang lista</Link>
        </div>
        <button onClick={handleShare} className="btn btn-md w-full"
          style={shared ? { background: '#E8F8F0', color: '#15803d' } : { background: '#BCD9FF', color: '#1e5fa4' }}>
          <IconShare size={16} strokeWidth={2.2} />
          {shared ? 'Link kopiran' : 'Podeli rezultat'}
        </button>

        {/* Back to home */}
        <Link href="/igraj" className="block text-center mt-6 text-[13px] font-medium transition-opacity hover:opacity-70"
          style={{ color: '#9C9C9C' }}>
          ← Glavna stranica
        </Link>
      </div>
    </div>
  )
}

function Stat({ label, value, accent }: { label: string; value: number | string; accent: string }) {
  return (
    <div className="rounded-2xl p-3" style={{ background: '#F2F2F2' }}>
      <div className="font-black text-[18px] tracking-tight" style={{ color: accent }}>{value}</div>
      <div className="text-[11px] font-medium mt-0.5" style={{ color: '#9C9C9C' }}>{label}</div>
    </div>
  )
}
