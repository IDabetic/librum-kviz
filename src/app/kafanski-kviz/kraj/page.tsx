'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import ShareResultButton from '@/components/ShareResultButton'

type Result = {
  score: number
  questionsReached: number
  correct: number
  wrong: number
  accuracy: number
  bestCombo: number
  totalTime: number
}

function fmtTime(s: number): string {
  const m = Math.floor(s / 60)
  const sec = s % 60
  return `${String(m).padStart(2, '0')}:${String(sec).padStart(2, '0')}`
}

export default function KafanskiKvizEnd() {
  const router = useRouter()
  const [r] = useState<Result | null>(() => {
    if (typeof window === 'undefined') return null
    const raw = sessionStorage.getItem('kafana-result')
    if (!raw) return null
    try { return JSON.parse(raw) as Result } catch { return null }
  })
  useEffect(() => { if (!r) router.push('/kafanski-kviz') }, [r, router])

  if (!r) return null

  return (
    <div className="min-h-screen flex flex-col" style={{ background: 'var(--bg)' }}>
      <main className="flex-1 max-w-2xl mx-auto px-4 sm:px-6 py-10 sm:py-14 w-full">

        <div className="text-center mb-8">
          <p className="text-[13px] font-bold uppercase tracking-widest mb-2" style={{ color: 'var(--bad-t)' }}>
            Kraj
          </p>
          <h1 className="font-black tracking-tight leading-[1.05] mb-3"
            style={{ color: 'var(--ink)', fontSize: 'clamp(36px, 7vw, 56px)' }}>
            {r.score}
          </h1>
          <p className="text-[14px]" style={{ color: 'var(--ink-2)' }}>bodova u Kafanskom kvizu</p>
        </div>

        <div className="grid grid-cols-3 gap-3 mb-5">
          <Stat label="Pitanja" value={r.questionsReached} />
          <Stat label="Tačnost" value={`${Math.round(r.accuracy)}%`} />
          <Stat label="Najbolji niz" value={r.bestCombo} />
          <Stat label="Tačno" value={r.correct} accent="#0A4C35" />
          <Stat label="Pogrešno" value={r.wrong} accent="#C42B4F" />
          <Stat label="Vreme" value={fmtTime(r.totalTime)} />
        </div>

        <div className="space-y-2">
          <Link href="/kafanski-kviz/start" className="btn btn-primary btn-lg w-full" style={{ background: '#C42B4F' }}>
            Igraj ponovo
          </Link>
          <Link href="/ranglista" className="btn btn-secondary btn-md w-full">Rang lista</Link>
          <ShareResultButton
            gameLabel="Kafanskom kvizu"
            score={r.score}
            extra={`${r.correct} tačnih · ${Math.round(r.accuracy)}% tačnosti.`}
            accent="red"
            className="w-full"
          />
          <Link href="/" className="block text-center text-[13px] font-medium mt-3" style={{ color: 'var(--ink-2)' }}>
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
      <p className="font-black text-[18px] tracking-tight" style={{ color: accent || '#1A1B3A' }}>{value}</p>
      <p className="text-[10px] mt-1" style={{ color: 'var(--ink-2)' }}>{label}</p>
    </div>
  )
}
