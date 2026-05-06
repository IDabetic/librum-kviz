'use client'

import { useEffect, useState } from 'react'
import { useParams, useRouter } from 'next/navigation'
import Link from 'next/link'
import Image from 'next/image'
import { IconShare } from '@/components/icons'

type DuelResult = {
  myScore: number
  opScore: number
  myCorrect: number
  opCorrect: number
  myWrong: number
  opWrong: number
  totalAnswered: number
  totalTime: number
  totalQuestions: number
  goldenRounds: number
  myId: string | null
  opId: string | null
  myName: string
  opName: string
  myAvatar: string | null
  opAvatar: string | null
  iWon: boolean
  isDraw: boolean
}

function fmtTime(s: number): string {
  const m = Math.floor(s / 60)
  const sec = s % 60
  return `${String(m).padStart(2, '0')}:${String(sec).padStart(2, '0')}`
}

export default function DuelEndPage() {
  const params = useParams()
  const router = useRouter()
  const code = params.code as string
  const [r, setR] = useState<DuelResult | null>(null)
  const [shared, setShared] = useState(false)

  useEffect(() => {
    const stored = sessionStorage.getItem(`duel-result-${code}`)
    if (!stored) { router.push('/igraj-zajedno'); return }
    setR(JSON.parse(stored))
  }, [code, router])

  if (!r) return null

  const myAccuracy = r.totalAnswered > 0 ? Math.round((r.myCorrect / r.totalAnswered) * 100) : 0
  const opAccuracy = r.totalAnswered > 0 ? Math.round((r.opCorrect / r.totalAnswered) * 100) : 0
  const diff = Math.abs(r.myScore - r.opScore)

  const heroBg = r.isDraw ? '#FFECBC' : r.iWon ? '#E8F8F0' : '#FEE2E2'
  const heroFg = r.isDraw ? '#9c7a13' : r.iWon ? '#15803d' : '#b91c1c'
  const headline = r.isDraw ? 'Nerešeno!' : r.iWon ? 'Pobedio/la si!' : 'Izgubio/la si!'

  async function handleShare() {
    if (!r) return
    const shareUrl = `${window.location.origin}/igraj-zajedno`
    const text = r.iWon
      ? `Pobedio/la sam u Librum duelu ${r.myScore}-${r.opScore} protiv ${r.opName}!`
      : r.isDraw
        ? `Nerešeno ${r.myScore}-${r.opScore} u Librum duelu protiv ${r.opName}.`
        : `Igrao/la sam Librum duel protiv ${r.opName}: ${r.myScore}-${r.opScore}`
    if (typeof navigator.share === 'function') {
      try { await navigator.share({ title: 'Librum duel', text, url: shareUrl }) }
      catch { /* cancelled */ }
    } else {
      await navigator.clipboard.writeText(`${text} ${shareUrl}`)
      setShared(true)
      setTimeout(() => setShared(false), 2500)
    }
  }

  return (
    <div className="min-h-screen py-10 sm:py-14 px-4 sm:px-6" style={{ background: '#FAFAFA' }}>
      <div className="max-w-xl mx-auto">

        {/* Hero */}
        <div className="card-soft overflow-hidden mb-4">
          <div className="px-7 py-10 sm:py-12 text-center" style={{ background: heroBg }}>
            <p className="text-[12px] font-bold uppercase tracking-widest mb-3" style={{ color: heroFg, opacity: 0.7 }}>
              Kraj duela
            </p>
            <h1 className="font-black tracking-tight mb-3 leading-[1.05]"
              style={{ color: heroFg, fontSize: 'clamp(36px, 7vw, 56px)' }}>
              {headline}
            </h1>
            {!r.isDraw && (
              <p className="text-[13px] font-semibold" style={{ color: heroFg, opacity: 0.7 }}>
                Razlika: {diff} bodova
              </p>
            )}
            {r.goldenRounds > 0 && (
              <p className="text-[12px] font-bold mt-2" style={{ color: heroFg, opacity: 0.6 }}>
                ⚡ {r.goldenRounds} zlatno {r.goldenRounds === 1 ? 'pitanje' : 'pitanja'}
              </p>
            )}
          </div>

          {/* Score battle */}
          <div className="p-7 sm:p-8">
            <div className="grid grid-cols-2 gap-3 mb-7">
              <PlayerCol userId={r.myId} name={r.myName} avatar={r.myAvatar} score={r.myScore} accent="#609DED" you winner={r.iWon && !r.isDraw} />
              <PlayerCol userId={r.opId} name={r.opName} avatar={r.opAvatar} score={r.opScore} accent="#FFCB46" winner={!r.iWon && !r.isDraw} />
            </div>

            {/* Stats grid */}
            <div className="space-y-3">
              <StatRow label="Tačnih"   me={r.myCorrect} op={r.opCorrect} />
              <StatRow label="Pogr."    me={r.myWrong}   op={r.opWrong} />
              <StatRow label="Tačnost"  me={`${myAccuracy}%`} op={`${opAccuracy}%`} />
              <div className="rounded-2xl px-4 py-3 flex items-center justify-between" style={{ background: '#F2F2F2' }}>
                <span className="text-[12px] font-medium" style={{ color: '#9C9C9C' }}>Vreme duela</span>
                <span className="font-bold text-[13px]" style={{ color: '#343434' }}>{fmtTime(r.totalTime)}</span>
              </div>
            </div>
          </div>
        </div>

        {/* Actions */}
        <div className="grid grid-cols-2 gap-3 mb-3">
          <Link href="/igraj-zajedno" className="btn btn-primary btn-lg">Revanš</Link>
          <Link href="/leaderboard" className="btn btn-secondary btn-lg">Rang lista</Link>
        </div>
        <button onClick={handleShare} className="btn btn-md w-full"
          style={shared ? { background: '#E8F8F0', color: '#15803d' } : { background: '#BCD9FF', color: '#1e5fa4' }}>
          <IconShare size={16} strokeWidth={2.2} />
          {shared ? 'Link kopiran' : 'Podeli rezultat'}
        </button>

        <Link href="/igraj-zajedno" className="block text-center mt-6 text-[13px] font-medium transition-opacity hover:opacity-70"
          style={{ color: '#9C9C9C' }}>
          ← Izazovi drugog
        </Link>
      </div>
    </div>
  )
}

function PlayerCol({ userId, name, avatar, score, accent, you, winner }: {
  userId: string | null; name: string; avatar: string | null; score: number; accent: string; you?: boolean; winner?: boolean
}) {
  const inner = (
    <>
      <div className="w-14 h-14 rounded-2xl overflow-hidden mx-auto mb-3" style={{ background: '#FCFCFC', border: `2px solid ${accent}` }}>
        {avatar
          ? <Image src={`/avatars/${avatar}`} alt={name} width={56} height={56} className="w-full h-full object-cover" />
          : <div className="w-full h-full flex items-center justify-center text-[18px] font-bold" style={{ background: accent, color: 'white' }}>{name[0]}</div>}
      </div>
      <div className="text-[11px] font-bold uppercase tracking-wider" style={{ color: '#9C9C9C' }}>{you ? 'Ti' : name.split(' ')[0]}</div>
      <div className="font-black tracking-tight" style={{ color: accent, fontSize: 'clamp(28px, 5vw, 36px)' }}>{score}</div>
      <div className="text-[10px] font-medium mt-0.5" style={{ color: '#9C9C9C' }}>bodova</div>
      {winner && <div className="mt-2 text-[18px]">🏆</div>}
    </>
  )
  const cls = "rounded-2xl p-5 text-center transition-all hover:scale-[1.02]"
  const style = {
    background: winner ? '#FFECBC' : '#F2F2F2',
    border: winner ? '2px solid #FFCB46' : '2px solid transparent',
  }
  return userId
    ? <Link href={you ? '/profil' : `/profil/${userId}`} className={cls} style={style}>{inner}</Link>
    : <div className={cls} style={style}>{inner}</div>
}

function StatRow({ label, me, op }: { label: string; me: number | string; op: number | string }) {
  return (
    <div className="rounded-2xl px-4 py-3 flex items-center justify-between" style={{ background: '#F2F2F2' }}>
      <span className="font-bold text-[13px]" style={{ color: '#609DED' }}>{me}</span>
      <span className="text-[11px] font-bold uppercase tracking-wider" style={{ color: '#9C9C9C' }}>{label}</span>
      <span className="font-bold text-[13px]" style={{ color: '#FFCB46' }}>{op}</span>
    </div>
  )
}
