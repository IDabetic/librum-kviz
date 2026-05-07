'use client'

export const dynamic = 'force-dynamic'

import { useEffect, useState, useRef, useCallback } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import { createClient } from '@/lib/supabase/client'
import { IconClose, IconCheck, IconWrong, IconShare } from '@/components/icons'

const ROUND_SECONDS = 60
const TIME_PER_QUESTION = 10
const POINTS_CORRECT = 10
const POINTS_WRONG = 5

type Statement = {
  id: string
  statement: string
  correct_answer: boolean
  explanation: string | null
  category: string | null
}

export default function BrziKvizStart() {
  const router = useRouter()
  const [pool, setPool] = useState<Statement[]>([])
  const [usedIds, setUsedIds] = useState<Set<string>>(new Set())
  const [loading, setLoading] = useState(true)
  const [myId, setMyId] = useState<string | null>(null)

  const [current, setCurrent] = useState<Statement | null>(null)
  const [answered, setAnswered] = useState<boolean | null>(null)
  const [showResult, setShowResult] = useState(false)
  const [questionTime, setQuestionTime] = useState(TIME_PER_QUESTION)
  const [roundTime, setRoundTime] = useState(ROUND_SECONDS)

  const [score, setScore] = useState(0)
  const [correct, setCorrect] = useState(0)
  const [wrong, setWrong] = useState(0)
  const [scoreFlash, setScoreFlash] = useState<{ delta: number; key: number } | null>(null)
  const [gameOver, setGameOver] = useState(false)
  const [shared, setShared] = useState(false)

  const savedRef = useRef(false)
  const startTimeRef = useRef<number>(Date.now())

  // ── Load statements ─────────────────────────────────────────────────────
  useEffect(() => {
    async function load() {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) { router.push('/auth/prijava?redirect=/brzi-kviz'); return }
      setMyId(user.id)

      const { data } = await supabase
        .from('quick_statements')
        .select('id, statement, correct_answer, explanation, category')
        .eq('is_active', true)
        .limit(500)
      if (!data || data.length === 0) { setLoading(false); return }
      const shuffled = (data as Statement[]).sort(() => Math.random() - 0.5)
      setPool(shuffled)
      setLoading(false)
      startTimeRef.current = Date.now()
    }
    load()
  }, [router])

  // ── Pick next statement ─────────────────────────────────────────────────
  const nextStatement = useCallback(() => {
    for (const s of pool) {
      if (!usedIds.has(s.id)) return s
    }
    return null
  }, [pool, usedIds])

  // ── Initial first statement ─────────────────────────────────────────────
  useEffect(() => {
    if (loading || current || gameOver || pool.length === 0) return
    const s = nextStatement()
    if (s) {
      setCurrent(s)
      setUsedIds(prev => new Set(prev).add(s.id))
      setQuestionTime(TIME_PER_QUESTION)
      setShowResult(false)
      setAnswered(null)
    }
  }, [loading, current, gameOver, pool.length, nextStatement])

  // ── Round timer (counts down 60→0) ──────────────────────────────────────
  useEffect(() => {
    if (gameOver || loading) return
    if (roundTime <= 0) {
      finishGame()
      return
    }
    const t = setTimeout(() => setRoundTime(s => s - 1), 1000)
    return () => clearTimeout(t)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [roundTime, gameOver, loading])

  // ── Per-question timer (10s) ────────────────────────────────────────────
  useEffect(() => {
    if (gameOver || loading || showResult || !current) return
    if (questionTime <= 0) {
      handleAnswer(null)
      return
    }
    const t = setTimeout(() => setQuestionTime(s => s - 1), 1000)
    return () => clearTimeout(t)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [questionTime, gameOver, loading, showResult, current])

  function handleAnswer(answer: boolean | null) {
    if (!current || showResult || gameOver) return
    setAnswered(answer)
    setShowResult(true)

    const isCorrect = answer !== null && answer === current.correct_answer
    if (isCorrect) {
      const newScore = score + POINTS_CORRECT
      setScore(newScore)
      setCorrect(c => c + 1)
      setScoreFlash({ delta: POINTS_CORRECT, key: Date.now() })
    } else {
      const newScore = Math.max(0, score - POINTS_WRONG)
      setScore(newScore)
      setWrong(w => w + 1)
      setScoreFlash({ delta: -POINTS_WRONG, key: Date.now() })
    }

    // Auto-advance after ~1.6s
    setTimeout(() => goNext(), 1600)
  }

  function goNext() {
    if (gameOver) return
    const s = nextStatement()
    if (!s) {
      // Pool exhausted
      finishGame()
      return
    }
    setCurrent(s)
    setUsedIds(prev => new Set(prev).add(s.id))
    setQuestionTime(TIME_PER_QUESTION)
    setShowResult(false)
    setAnswered(null)
  }

  async function finishGame() {
    if (savedRef.current) return
    savedRef.current = true
    setGameOver(true)
    if (myId) {
      const supabase = createClient()
      const total = correct + wrong
      const accuracy = total > 0 ? Math.round((correct / total) * 10000) / 100 : 0
      await supabase.from('quick_sessions').insert({
        user_id: myId,
        score,
        correct_count: correct,
        wrong_count: wrong,
        total_answered: total,
        accuracy,
        duration_seconds: ROUND_SECONDS,
      })
    }
  }

  async function handleShare() {
    const url = `${window.location.origin}/brzi-kviz`
    const text = `Postigao/la sam ${score} bodova u Librum Brzom kvizu! ${correct} tačnih u ${ROUND_SECONDS}s.`
    if (typeof navigator.share === 'function') {
      try { await navigator.share({ title: 'Librum Brzi kviz', text, url }) } catch { /* */ }
    } else {
      await navigator.clipboard.writeText(`${text} ${url}`)
      setShared(true)
      setTimeout(() => setShared(false), 2500)
    }
  }

  // ── Render ─────────────────────────────────────────────────────────────
  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center" style={{ background: '#FAFAFA' }}>
        <div className="w-8 h-8 rounded-full border-2 animate-spin"
          style={{ borderColor: '#609DED', borderTopColor: 'transparent' }} />
      </div>
    )
  }

  if (!current && !gameOver) {
    return (
      <div className="min-h-screen flex items-center justify-center px-4" style={{ background: '#FAFAFA' }}>
        <div className="card-soft p-8 max-w-sm text-center">
          <p className="font-bold text-[16px] mb-3" style={{ color: '#343434' }}>Nema dostupnih tvrdnji.</p>
          <Link href="/brzi-kviz" className="btn btn-primary btn-md">Nazad</Link>
        </div>
      </div>
    )
  }

  // End screen
  if (gameOver) {
    const total = correct + wrong
    const accuracy = total > 0 ? Math.round((correct / total) * 100) : 0
    return (
      <div className="min-h-screen py-10 sm:py-14 px-4 sm:px-6" style={{ background: '#FAFAFA' }}>
        <div className="max-w-xl mx-auto">
          <div className="card-soft overflow-hidden">
            <div className="px-7 py-10 text-center" style={{ background: 'linear-gradient(135deg, #BCD9FF 0%, #FFECBC 100%)' }}>
              <p className="text-[12px] font-bold uppercase tracking-widest mb-3" style={{ color: '#343434', opacity: 0.6 }}>
                Kraj runde
              </p>
              <div className="font-black tracking-tight leading-none" style={{ color: '#343434', fontSize: 'clamp(56px, 12vw, 96px)' }}>
                {score}
              </div>
              <p className="text-[14px] font-semibold mt-2" style={{ color: '#609DED' }}>bodova za 60s</p>
            </div>
            <div className="p-7 sm:p-8">
              <div className="grid grid-cols-3 gap-3 mb-6">
                <Stat label="Tačnih" value={correct} accent="#4CAF50" />
                <Stat label="Pogr."  value={wrong}   accent="#E55353" />
                <Stat label="Tačnost" value={`${accuracy}%`} accent="#343434" />
              </div>
              <div className="grid grid-cols-2 gap-3 mb-3">
                <Link href="/brzi-kviz/start" className="btn btn-primary btn-lg">Igraj ponovo</Link>
                <Link href="/leaderboard" className="btn btn-secondary btn-lg">Rang lista</Link>
              </div>
              <button onClick={handleShare} className="btn btn-md w-full"
                style={shared ? { background: '#E8F8F0', color: '#15803d' } : { background: '#BCD9FF', color: '#1e5fa4' }}>
                <IconShare size={16} strokeWidth={2.2} />
                {shared ? 'Link kopiran' : 'Podeli rezultat'}
              </button>
              <Link href="/brzi-kviz" className="block text-center mt-5 text-[13px] font-medium transition-opacity hover:opacity-70"
                style={{ color: '#9C9C9C' }}>
                ← Početna
              </Link>
            </div>
          </div>
        </div>
      </div>
    )
  }

  if (!current) return null

  const roundProgress = roundTime / ROUND_SECONDS
  const qProgress = questionTime / TIME_PER_QUESTION
  const isCorrect = answered !== null && answered === current.correct_answer
  const isTimeout = showResult && answered === null
  const showWrong = showResult && !isCorrect && !isTimeout

  return (
    <div className="min-h-screen flex flex-col" style={{ background: '#FAFAFA' }}>

      {/* HUD */}
      <header className="sticky top-0 z-30 backdrop-blur-xl"
        style={{ background: 'rgba(252,252,252,0.92)', borderBottom: '1px solid rgba(52,52,52,0.06)' }}>
        <div className="max-w-3xl mx-auto px-4 sm:px-6 py-3 flex items-center justify-between gap-3">
          <Link href="/brzi-kviz"
            className="w-10 h-10 rounded-full flex items-center justify-center transition-colors hover:bg-[#F2F2F2] flex-shrink-0"
            style={{ color: '#9C9C9C' }} aria-label="Izađi">
            <IconClose size={20} strokeWidth={2.2} />
          </Link>

          <div className="flex items-center gap-2 flex-1 justify-center">
            <Stat label="Vreme"  value={`${roundTime}s`} bg={roundTime <= 10 ? '#FEE2E2' : '#F2F2F2'} fg={roundTime <= 10 ? '#E55353' : '#343434'} />
            <Stat label="Bodovi" value={score} bg="#FFECBC" fg="#343434" highlight={scoreFlash?.delta} highlightKey={scoreFlash?.key} />
            <Stat label="Tačno"  value={correct} bg="#E8F8F0" fg="#15803d" />
            <Stat label="Pogr."  value={wrong} bg="#FEE2E2" fg="#E55353" />
          </div>

          <div className="w-10 flex-shrink-0" />
        </div>
        {/* Round progress bar */}
        <div className="max-w-3xl mx-auto px-4 sm:px-6 pb-2.5">
          <div className="h-1.5 rounded-full overflow-hidden" style={{ background: 'rgba(52,52,52,0.10)' }}>
            <div className="h-full rounded-full transition-all" style={{
              width: `${roundProgress * 100}%`,
              background: roundProgress > 0.5 ? '#4CAF50' : roundProgress > 0.2 ? '#FFCB46' : '#E55353',
            }} />
          </div>
        </div>
      </header>

      <main className="flex-1 flex flex-col items-center justify-center px-4 sm:px-6 py-6">
        <div className="w-full max-w-2xl">

          {/* Statement */}
          <div className="card-soft p-8 sm:p-10 mb-5 text-center min-h-[200px] flex flex-col justify-center" key={current.id}>
            {/* Question timer dot */}
            <div className="flex justify-center mb-4">
              <div className="w-12 h-12 rounded-full flex items-center justify-center font-black text-[16px]"
                style={{
                  background: qProgress > 0.5 ? '#E8F8F0' : qProgress > 0.2 ? '#FFECBC' : '#FEE2E2',
                  color: qProgress > 0.5 ? '#15803d' : qProgress > 0.2 ? '#9c7a13' : '#E55353',
                }}>
                {questionTime}
              </div>
            </div>
            <p className="text-[18px] sm:text-[22px] font-bold leading-snug tracking-tight"
              style={{ color: '#343434' }}>
              {current.statement}
            </p>

            {/* Result reveal */}
            {showResult && (
              <div className="mt-5">
                <div className="flex items-center justify-center gap-2 mb-2">
                  {isCorrect && (
                    <>
                      <div className="w-7 h-7 rounded-full flex items-center justify-center" style={{ background: '#4CAF50' }}>
                        <IconCheck size={16} className="text-white" />
                      </div>
                      <span className="font-black text-[16px]" style={{ color: '#15803d' }}>Tačno! +10</span>
                    </>
                  )}
                  {(showWrong || isTimeout) && (
                    <>
                      <div className="w-7 h-7 rounded-full flex items-center justify-center" style={{ background: '#E55353' }}>
                        <IconWrong size={16} className="text-white" />
                      </div>
                      <span className="font-black text-[16px]" style={{ color: '#b91c1c' }}>
                        {isTimeout ? 'Vreme isteklo. -5' : 'Pogrešno. -5'}
                      </span>
                    </>
                  )}
                </div>
                {current.explanation && (
                  <p className="text-[13px] leading-relaxed mt-2" style={{ color: '#9C9C9C' }}>
                    {current.explanation}
                  </p>
                )}
              </div>
            )}
          </div>

          {/* Answer buttons */}
          {!showResult && (
            <div className="grid grid-cols-2 gap-3">
              <button onClick={() => handleAnswer(true)}
                className="py-6 rounded-3xl font-black text-[20px] tracking-tight transition-all hover:scale-[1.02] active:scale-95"
                style={{ background: '#E8F8F0', color: '#15803d' }}>
                ✓ Tačno
              </button>
              <button onClick={() => handleAnswer(false)}
                className="py-6 rounded-3xl font-black text-[20px] tracking-tight transition-all hover:scale-[1.02] active:scale-95"
                style={{ background: '#FEE2E2', color: '#b91c1c' }}>
                ✗ Netačno
              </button>
            </div>
          )}
        </div>
      </main>
    </div>
  )
}

function Stat({ label, value, bg, fg, accent, highlight, highlightKey }: {
  label: string; value: number | string
  bg?: string; fg?: string; accent?: string
  highlight?: number; highlightKey?: number
}) {
  // Two modes: HUD tile (bg+fg) or end-card tile (accent only)
  if (accent) {
    return (
      <div className="rounded-2xl p-3 text-center" style={{ background: '#F2F2F2' }}>
        <div className="font-black text-[18px] tracking-tight" style={{ color: accent }}>{value}</div>
        <div className="text-[11px] font-medium mt-0.5" style={{ color: '#9C9C9C' }}>{label}</div>
      </div>
    )
  }
  return (
    <div className="relative px-3 sm:px-4 py-2 rounded-2xl flex-1 sm:flex-initial sm:min-w-[80px] text-center" style={{ background: bg }}>
      <div className="text-[10px] font-bold uppercase tracking-wider" style={{ color: fg, opacity: 0.65 }}>{label}</div>
      <div className="font-black text-[18px] sm:text-[22px] tracking-tight leading-none mt-0.5" style={{ color: fg }}>{value}</div>
      {highlight !== undefined && (
        <span key={highlightKey} className="absolute -top-2 left-1/2 -translate-x-1/2 font-black text-[13px] whitespace-nowrap"
          style={{ color: highlight > 0 ? '#4CAF50' : '#E55353', animation: 'floatUp 0.9s ease-out forwards' }}>
          {highlight > 0 ? `+${highlight}` : highlight}
        </span>
      )}
      <style jsx>{`
        @keyframes floatUp {
          0%   { opacity: 1; transform: translate(-50%, 0); }
          100% { opacity: 0; transform: translate(-50%, -20px); }
        }
      `}</style>
    </div>
  )
}
