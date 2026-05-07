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

// Raw question pulled from DB
type QuestionRow = {
  id: string
  question_text: string
  options: string[]
  correct_answer: number
}

// Statement we present in the game
type Statement = {
  id: string
  question: string
  shownAnswer: string
  isShownCorrect: boolean
  correctAnswer: string
}

function buildStatement(q: QuestionRow): Statement {
  const correctIdx = q.correct_answer ?? 0
  const correct = q.options[correctIdx] ?? ''
  const wrongs = q.options.filter((_, i) => i !== correctIdx)
  const showCorrect = Math.random() < 0.5
  const shown = showCorrect
    ? correct
    : (wrongs[Math.floor(Math.random() * wrongs.length)] ?? correct)
  return {
    id: q.id,
    question: q.question_text,
    shownAnswer: shown,
    isShownCorrect: shown === correct,
    correctAnswer: correct,
  }
}

export default function BrziKvizStart() {
  const router = useRouter()
  const [pool, setPool] = useState<QuestionRow[]>([])
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
  const questionStartRef = useRef<number>(Date.now())

  // ── Load random batch of questions, excluding ones seen in last 24h ────
  useEffect(() => {
    async function load() {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) { router.push('/auth/prijava?redirect=/brzi-kviz'); return }
      setMyId(user.id)

      // Fetch question IDs seen in last 24h
      const dayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString()
      const { data: seen } = await supabase
        .from('quick_seen')
        .select('question_id')
        .eq('user_id', user.id)
        .gte('seen_at', dayAgo)
      const seenSet = new Set((seen || []).map(s => s.question_id))

      // Pull a chunk and shuffle client-side
      const { data } = await supabase
        .from('questions')
        .select('id, question_text, options, correct_answer')
        .eq('is_active', true)
        .limit(800)
      if (!data || data.length === 0) { setLoading(false); return }

      // Exclude recently seen
      let fresh = (data as QuestionRow[]).filter(q => !seenSet.has(q.id))
      // Fallback: if pool too small, allow seen ones too (rare, <100 fresh)
      if (fresh.length < 30) fresh = data as QuestionRow[]

      const shuffled = fresh.sort(() => Math.random() - 0.5)
      setPool(shuffled)
      setLoading(false)
    }
    load()
  }, [router])

  // ── Pick next question (no repeats) ─────────────────────────────────────
  const pickNext = useCallback(() => {
    for (const q of pool) {
      if (!usedIds.has(q.id)) return q
    }
    return null
  }, [pool, usedIds])

  // ── Initial first statement ─────────────────────────────────────────────
  useEffect(() => {
    if (loading || current || gameOver || pool.length === 0) return
    const q = pickNext()
    if (q) {
      setCurrent(buildStatement(q))
      setUsedIds(prev => new Set(prev).add(q.id))
      setQuestionTime(TIME_PER_QUESTION)
      setShowResult(false)
      setAnswered(null)
      questionStartRef.current = Date.now()
    }
  }, [loading, current, gameOver, pool.length, pickNext])

  // ── Round timer ─────────────────────────────────────────────────────────
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

  // ── Per-question timer ──────────────────────────────────────────────────
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

    const isUserCorrect = answer !== null && answer === current.isShownCorrect
    const elapsedMs = Date.now() - questionStartRef.current
    if (isUserCorrect) {
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

    // Mark this question as seen (upsert so seen_at refreshes if already there)
    if (myId && current.id) {
      const supabase = createClient()
      supabase.from('quick_seen').upsert({
        user_id: myId,
        question_id: current.id,
        seen_at: new Date().toISOString(),
      }, { onConflict: 'user_id,question_id' }).then(() => {})

      // Log per-answer for analytics (powers admin /pitanja stats panel).
      // Brzi kviz reuses PRO question pool, so this lands in the same table.
      supabase.from('question_answer_log').insert({
        question_id: current.id,
        user_id: myId,
        was_correct: isUserCorrect,
        picked_idx: null,                     // brzi kviz is true/false; option pick is N/A
        time_ms: elapsedMs,
      }).then(({ error }) => {
        if (error) console.error('answer log insert failed', error)
      })
    }

    setTimeout(() => goNext(), 1800)
  }

  function goNext() {
    if (gameOver) return
    const q = pickNext()
    if (!q) { finishGame(); return }
    setCurrent(buildStatement(q))
    setUsedIds(prev => new Set(prev).add(q.id))
    setQuestionTime(TIME_PER_QUESTION)
    setShowResult(false)
    setAnswered(null)
    questionStartRef.current = Date.now()
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
          <p className="font-bold text-[16px] mb-3" style={{ color: '#343434' }}>Nema dostupnih pitanja.</p>
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
  const isUserCorrect = answered !== null && answered === current.isShownCorrect
  const isTimeout = showResult && answered === null

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

          {/* Question card */}
          <div className="card-soft overflow-hidden mb-5" key={current.id}>

            {/* Header strip with timer */}
            <div className="px-6 sm:px-8 py-4 flex items-center justify-between gap-3"
              style={{ background: '#F2F2F2', borderBottom: '1px solid rgba(52,52,52,0.06)' }}>
              <span className="text-[11px] font-bold uppercase tracking-widest" style={{ color: '#9C9C9C' }}>
                Pitanje
              </span>
              <div className="flex items-center gap-2">
                <span className="text-[11px] font-bold uppercase tracking-wider"
                  style={{ color: qProgress > 0.5 ? '#15803d' : qProgress > 0.2 ? '#9c7a13' : '#E55353' }}>
                  {questionTime}s
                </span>
                <div className="w-9 h-9 rounded-full flex items-center justify-center font-black text-[14px]"
                  style={{
                    background: qProgress > 0.5 ? '#E8F8F0' : qProgress > 0.2 ? '#FFECBC' : '#FEE2E2',
                    color: qProgress > 0.5 ? '#15803d' : qProgress > 0.2 ? '#9c7a13' : '#E55353',
                  }}>
                  {questionTime}
                </div>
              </div>
            </div>

            {/* QUESTION — hero */}
            <div className="px-6 sm:px-8 py-7">
              <p className="font-black tracking-tight leading-[1.2]"
                style={{ color: '#343434', fontSize: 'clamp(20px, 4vw, 28px)' }}>
                {current.question}
              </p>
            </div>

            {/* Divider with "ODGOVOR" label */}
            <div className="px-6 sm:px-8 flex items-center gap-3" style={{ marginTop: -4 }}>
              <div className="flex-1 h-px" style={{ background: 'rgba(52,52,52,0.12)' }} />
              <span className="text-[10px] font-bold uppercase tracking-[3px]" style={{ color: '#9C9C9C' }}>
                Predloženi odgovor
              </span>
              <div className="flex-1 h-px" style={{ background: 'rgba(52,52,52,0.12)' }} />
            </div>

            {/* SHOWN ANSWER — clear claim card */}
            <div className="px-6 sm:px-8 py-7 text-center"
              style={{
                background: showResult
                  ? (isUserCorrect ? '#E8F8F0' : '#FEE2E2')
                  : '#FFECBC',
                transition: 'background 0.3s',
              }}>
              <p className="font-black tracking-tight leading-tight"
                style={{
                  color: showResult ? (isUserCorrect ? '#15803d' : '#b91c1c') : '#343434',
                  fontSize: 'clamp(28px, 6vw, 44px)',
                }}>
                {current.shownAnswer}
              </p>
            </div>

            {/* Result reveal */}
            {showResult && (
              <div className="px-6 sm:px-8 py-5 border-t" style={{ borderColor: 'rgba(52,52,52,0.06)' }}>
                <div className="flex items-center justify-center gap-2 mb-2">
                  {isUserCorrect ? (
                    <>
                      <div className="w-7 h-7 rounded-full flex items-center justify-center" style={{ background: '#4CAF50' }}>
                        <IconCheck size={16} className="text-white" />
                      </div>
                      <span className="font-black text-[16px]" style={{ color: '#15803d' }}>Tačno! +10</span>
                    </>
                  ) : (
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
                {!current.isShownCorrect && (
                  <p className="text-[13px] leading-relaxed mt-2 text-center" style={{ color: '#9C9C9C' }}>
                    Tačan odgovor je: <strong style={{ color: '#343434' }}>{current.correctAnswer}</strong>
                  </p>
                )}
                {current.isShownCorrect && (
                  <p className="text-[13px] leading-relaxed mt-2 text-center" style={{ color: '#9C9C9C' }}>
                    Da, to je tačan odgovor.
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
