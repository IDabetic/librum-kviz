'use client'

export const dynamic = 'force-dynamic'

import { useEffect, useState, useRef, useCallback } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { shuffle } from '@/lib/shuffle'
import { IconClose } from '@/components/icons'

const TIME_PER_QUESTION = 15
const STARTING_LIVES = 10
const POINTS_CORRECT = 10
const POINTS_WRONG = 5
const COMBO_BONUSES: Record<number, { points: number; msg: string }> = {
  5:   { points: 10,  msg: 'Lep niz!' },
  10:  { points: 25,  msg: 'Odličan ritam!' },
  20:  { points: 60,  msg: 'Kafanska legenda!' },
  50:  { points: 150, msg: 'Stari mačak!' },
  100: { points: 400, msg: 'Živi pevač!' },
}

type Question = {
  id: string
  question_text: string
  options: string[]
  correct_answer: number
}

type DisplayQuestion = Question & {
  shuffled: string[]
  correctIdx: number
  shuffleMap: number[]
}

function shuffleOptions(q: Question): DisplayQuestion {
  const indices = [0, 1, 2, 3]
  // Fisher–Yates so the correct answer doesn't lean toward index 0.
  for (let i = 3; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[indices[i], indices[j]] = [indices[j], indices[i]]
  }
  const shuffled = indices.map(i => q.options[i])
  const correctIdx = indices.indexOf(q.correct_answer)
  return { ...q, shuffled, correctIdx, shuffleMap: indices }
}

function fmtTime(seconds: number): string {
  const m = Math.floor(seconds / 60)
  const s = seconds % 60
  return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`
}

export default function KafanskiKvizStart() {
  const router = useRouter()
  const [pool, setPool] = useState<Question[]>([])
  const [usedIds, setUsedIds] = useState<Set<string>>(new Set())
  const [loading, setLoading] = useState(true)
  const [myId, setMyId] = useState<string | null>(null)

  const [current, setCurrent] = useState<DisplayQuestion | null>(null)
  const [selected, setSelected] = useState<number | null>(null)
  const [revealed, setRevealed] = useState(false)
  const [timeLeft, setTimeLeft] = useState(TIME_PER_QUESTION)
  const [lives, setLives] = useState(STARTING_LIVES)
  const [score, setScore] = useState(0)
  const [reached, setReached] = useState(0)
  const [correct, setCorrect] = useState(0)
  const [wrong, setWrong] = useState(0)
  const [combo, setCombo] = useState(0)
  const [bestCombo, setBestCombo] = useState(0)
  const [startTime] = useState(() => Date.now())
  const [totalElapsed, setTotalElapsed] = useState(0)
  const [scoreFlash, setScoreFlash] = useState<{ delta: number; key: number } | null>(null)
  const [comboFlash, setComboFlash] = useState<string | null>(null)
  const [gameOver, setGameOver] = useState(false)

  const savingRef = useRef(false)
  const questionStartRef = useRef<number>(Date.now())

  // Auto-clear the centred ±N flash so it doesn't freeze on screen.
  useEffect(() => {
    if (!scoreFlash) return
    const t = setTimeout(() => setScoreFlash(null), 900)
    return () => clearTimeout(t)
  }, [scoreFlash])

  // Mirror live state in a ref so pagehide / exit handlers can flush
  // the latest score without depending on render closures.
  const liveRef = useRef({
    score: 0, reached: 0, correct: 0, wrong: 0, bestCombo: 0, anyAnswered: false,
  })
  useEffect(() => {
    liveRef.current = { score, reached, correct, wrong, bestCombo, anyAnswered: correct + wrong > 0 }
  }, [score, reached, correct, wrong, bestCombo])

  // ── Load questions ─────────────────────────────────────────────────────────
  useEffect(() => {
    async function load() {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) { router.push('/auth/prijava?redirect=/kafanski-kviz'); return }
      setMyId(user.id)

      // 72h dedupe — exclude questions answered in this mode lately.
      const cutoff = new Date(Date.now() - 72 * 60 * 60 * 1000).toISOString()
      const { data: seen } = await supabase
        .from('kafana_answer_log')
        .select('question_id')
        .eq('user_id', user.id)
        .gte('created_at', cutoff)
      const seenSet = new Set((seen || []).map(s => s.question_id))

      const { data } = await supabase
        .from('kafana_questions')
        .select('id, question_text, options, correct_answer')
        .eq('is_active', true)
        .limit(10000)
      if (!data || data.length === 0) { setLoading(false); return }

      let fresh = (data as Question[]).filter(q => !seenSet.has(q.id))
      if (fresh.length < 30) fresh = data as Question[]
      const all = shuffle(fresh)

      const first = all[0]
      setPool(all)
      if (first) {
        setCurrent(shuffleOptions(first))
        setUsedIds(new Set([first.id]))
        questionStartRef.current = Date.now()
      }
      setLoading(false)
    }
    load()
  }, [router])

  const nextQuestion = useCallback((used: Set<string>): DisplayQuestion | null => {
    for (const q of pool) if (!used.has(q.id)) return shuffleOptions(q)
    return null
  }, [pool])

  // Per-question countdown
  useEffect(() => {
    if (gameOver || revealed || !current || loading) return
    if (timeLeft <= 0) { handleAnswer(null); return }
    const t = setTimeout(() => setTimeLeft(s => s - 1), 1000)
    return () => clearTimeout(t)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [timeLeft, revealed, gameOver, current, loading])

  // Total elapsed
  useEffect(() => {
    if (gameOver) return
    const t = setInterval(() => setTotalElapsed(Math.floor((Date.now() - startTime) / 1000)), 1000)
    return () => clearInterval(t)
  }, [startTime, gameOver])

  async function saveSession(finalScore: number, finalReached: number, finalCorrect: number,
    finalWrong: number, finalBest: number) {
    if (savingRef.current || !myId) return
    savingRef.current = true
    const supabase = createClient()
    const totalAnswered = finalCorrect + finalWrong
    const accuracy = totalAnswered > 0 ? Math.round((finalCorrect / totalAnswered) * 10000) / 100 : 0
    const totalTime = Math.floor((Date.now() - startTime) / 1000)

    const { data } = await supabase.from('kafana_sessions').insert({
      user_id: myId,
      score: finalScore,
      questions_reached: finalReached,
      correct_answers: finalCorrect,
      wrong_answers: finalWrong,
      accuracy,
      best_combo: finalBest,
      total_time_seconds: totalTime,
    }).select('id').single()

    sessionStorage.setItem('kafana-result', JSON.stringify({
      score: finalScore, questionsReached: finalReached, correct: finalCorrect,
      wrong: finalWrong, accuracy, bestCombo: finalBest, totalTime, sessionId: data?.id,
    }))
    router.push('/kafanski-kviz/kraj')
  }

  // Best-effort save used by exit + pagehide.
  const persistSession = useCallback(async (opts: { useBeacon?: boolean } = {}) => {
    if (savingRef.current || !myId || !liveRef.current.anyAnswered) return
    savingRef.current = true
    const live = liveRef.current
    const totalAnswered = live.correct + live.wrong
    const accuracy = totalAnswered > 0 ? Math.round((live.correct / totalAnswered) * 10000) / 100 : 0
    const totalTime = Math.floor((Date.now() - startTime) / 1000)
    const payload = {
      user_id: myId,
      score: live.score,
      questions_reached: live.reached,
      correct_answers: live.correct,
      wrong_answers: live.wrong,
      accuracy,
      best_combo: live.bestCombo,
      total_time_seconds: totalTime,
    }
    if (opts.useBeacon && typeof navigator !== 'undefined' && 'sendBeacon' in navigator) {
      try {
        const blob = new Blob([JSON.stringify({ mode: 'kafana', ...payload })], { type: 'application/json' })
        navigator.sendBeacon('/api/save-session', blob)
        return
      } catch { /* fall through */ }
    }
    const supabase = createClient()
    await supabase.from('kafana_sessions').insert(payload)
  }, [myId, startTime])

  useEffect(() => {
    if (gameOver) return
    function flush() { void persistSession({ useBeacon: true }) }
    function onVis() { if (document.visibilityState === 'hidden') flush() }
    window.addEventListener('pagehide', flush)
    document.addEventListener('visibilitychange', onVis)
    return () => {
      window.removeEventListener('pagehide', flush)
      document.removeEventListener('visibilitychange', onVis)
    }
  }, [gameOver, persistSession])

  const [showExitConfirm, setShowExitConfirm] = useState(false)
  function exitGame() { setShowExitConfirm(true) }
  async function confirmExit() {
    await persistSession()
    router.push('/kafanski-kviz')
  }

  function handleAnswer(idx: number | null) {
    if (revealed || !current || gameOver) return
    setSelected(idx)
    setRevealed(true)

    const isCorrect = idx === current.correctIdx
    const newReached = reached + 1
    const elapsedMs = Date.now() - questionStartRef.current

    // Per-answer log (analytics + 72h dedupe)
    if (myId) {
      const supabase = createClient()
      const pickedOriginalIdx = idx == null ? null : (current.shuffleMap[idx] ?? null)
      supabase.from('kafana_answer_log').insert({
        question_id: current.id,
        user_id: myId,
        was_correct: isCorrect,
        picked_idx: pickedOriginalIdx,
        time_ms: elapsedMs,
      }).then(({ error }) => { if (error) console.error('kafana log insert failed', error) })
    }

    if (isCorrect) {
      const newCombo = combo + 1
      let newScore = score + POINTS_CORRECT
      const bonus = COMBO_BONUSES[newCombo]
      if (bonus) {
        newScore += bonus.points
        setComboFlash(`${bonus.msg} +${bonus.points}`)
        setTimeout(() => setComboFlash(null), 2500)
      }
      setScore(newScore)
      setReached(newReached)
      setCorrect(c => c + 1)
      setCombo(newCombo)
      setBestCombo(b => Math.max(b, newCombo))
      setScoreFlash({ delta: POINTS_CORRECT, key: Date.now() })
    } else {
      const newLives = lives - 1
      const newScore = Math.max(0, score - POINTS_WRONG)
      setLives(newLives)
      setScore(newScore)
      setReached(newReached)
      setWrong(w => w + 1)
      setCombo(0)
      setScoreFlash({ delta: -POINTS_WRONG, key: Date.now() })

      if (newLives <= 0) {
        setGameOver(true)
        setTimeout(() => {
          saveSession(newScore, newReached, correct, wrong + 1, bestCombo)
        }, 2200)
        return
      }
    }

    setTimeout(() => goNextQuestion(), 2400)
  }

  function goNextQuestion() {
    setSelected(null)
    setRevealed(false)
    setTimeLeft(TIME_PER_QUESTION)
    const q = nextQuestion(usedIds)
    if (!q) {
      setGameOver(true)
      saveSession(score, reached, correct, wrong, bestCombo)
      return
    }
    setCurrent(q)
    setUsedIds(prev => new Set(prev).add(q.id))
    questionStartRef.current = Date.now()
  }

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center" style={{ background: '#FAFAFA' }}>
        <div className="w-8 h-8 rounded-full border-2 animate-spin"
          style={{ borderColor: '#b91c1c', borderTopColor: 'transparent' }} />
      </div>
    )
  }

  if (!current && !gameOver) {
    return (
      <div className="min-h-screen flex items-center justify-center px-4" style={{ background: '#FAFAFA' }}>
        <div className="card-soft p-8 text-center max-w-md">
          <p className="font-bold text-[16px] mb-2" style={{ color: '#343434' }}>Nema pitanja</p>
          <button onClick={() => router.push('/kafanski-kviz')} className="btn btn-primary btn-md">Nazad</button>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen flex flex-col" style={{ background: '#FAFAFA' }}>

      {/* Top HUD */}
      <header className="sticky top-0 z-30 backdrop-blur-xl"
        style={{ background: 'rgba(252,252,252,0.92)', borderBottom: '1px solid rgba(52,52,52,0.06)' }}>
        <div className="max-w-5xl mx-auto px-4 sm:px-6 py-3 flex items-center justify-between gap-3">
          <button onClick={exitGame}
            className="w-10 h-10 rounded-full flex items-center justify-center transition-colors hover:bg-[#F2F2F2] flex-shrink-0"
            style={{ color: '#9C9C9C' }} aria-label="Izađi">
            <IconClose size={20} strokeWidth={2.2} />
          </button>

          <div className="flex items-center gap-2 sm:gap-4 flex-1 justify-center">
            <Stat label="Životi"  value={lives} color={lives <= 3 ? '#E55353' : '#343434'} bg={lives <= 3 ? '#FEE2E2' : '#F2F2F2'} />
            <Stat label="Bodovi"  value={score} color="#343434" bg="#FFECBC" highlight={scoreFlash?.delta} highlightKey={scoreFlash?.key} />
            <Stat label="Pitanje" value={reached} color="#1e5fa4" bg="#BCD9FF" />
            <Stat label="Niz"     value={combo} color="#15803d" bg="#E8F8F0" />
          </div>

          <Timer left={timeLeft} total={TIME_PER_QUESTION} />
        </div>
        <div className="max-w-5xl mx-auto px-4 sm:px-6 pb-2 flex justify-center">
          <span className="text-[11px] tabular-nums" style={{ color: '#9C9C9C' }}>{fmtTime(totalElapsed)}</span>
        </div>
      </header>

      {current && (
        <main className="flex-1 max-w-2xl mx-auto px-4 sm:px-6 py-6 sm:py-10 w-full">
          <p className="text-[11px] font-bold uppercase tracking-widest mb-3 text-center" style={{ color: '#b91c1c' }}>
            Pitanje #{reached + 1}
          </p>
          <div className="card-soft p-6 sm:p-7 mb-5">
            <p className="text-[18px] sm:text-[20px] font-bold leading-snug" style={{ color: '#343434' }}>
              {current.question_text}
            </p>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            {current.shuffled.map((opt, i) => {
              const isCorrect = i === current.correctIdx
              const isPicked = i === selected
              let bg = '#FCFCFC', fg = '#343434', border = '1.5px solid rgba(52,52,52,0.10)'
              if (revealed) {
                if (isCorrect) { bg = '#E8F8F0'; fg = '#15803d'; border = '1.5px solid #15803d' }
                else if (isPicked) { bg = '#FEE2E2'; fg = '#b91c1c'; border = '1.5px solid #b91c1c' }
              }
              return (
                <button key={i} onClick={() => handleAnswer(i)}
                  disabled={revealed}
                  className="text-left p-4 rounded-2xl transition-all disabled:opacity-40 disabled:cursor-not-allowed"
                  style={{ background: bg, color: fg, border }}>
                  <span className="font-semibold text-[15px]">{opt}</span>
                </button>
              )
            })}
          </div>
        </main>
      )}

      {scoreFlash && (
        <div key={scoreFlash.key} className="fixed top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 pointer-events-none z-50 font-black text-[48px] animate-pulse"
          style={{ color: scoreFlash.delta > 0 ? '#15803d' : '#b91c1c' }}>
          {scoreFlash.delta > 0 ? '+' : ''}{scoreFlash.delta}
        </div>
      )}

      {comboFlash && (
        <div className="fixed top-24 left-1/2 -translate-x-1/2 px-4 py-2 rounded-full font-bold text-[14px] z-50"
          style={{ background: '#FFCB46', color: '#343434' }}>
          {comboFlash}
        </div>
      )}

      {gameOver && (
        <div className="fixed inset-0 flex items-center justify-center pointer-events-none z-50">
          <div className="card-soft p-8 text-center" style={{ background: '#FCFCFC' }}>
            <p className="font-black text-[24px] mb-2" style={{ color: '#343434' }}>Kraj!</p>
            <p className="text-[14px]" style={{ color: '#9C9C9C' }}>Računam rezultat…</p>
          </div>
        </div>
      )}

      {showExitConfirm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center px-4 backdrop-blur-sm"
          style={{ background: 'rgba(52,52,52,0.40)' }}>
          <div className="card-soft p-7 text-center max-w-sm w-full">
            <h3 className="font-black text-[20px] tracking-tight mb-2" style={{ color: '#343434' }}>Izađi iz kviza?</h3>
            <p className="text-[13px] mb-6" style={{ color: '#9C9C9C' }}>Trenutni rezultat se upisuje na rang listu.</p>
            <div className="flex gap-3">
              <button onClick={() => setShowExitConfirm(false)} className="btn btn-secondary btn-md flex-1">Nastavi</button>
              <button onClick={confirmExit} className="btn btn-md flex-1" style={{ background: '#E55353', color: 'white' }}>Izađi</button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

function Timer({ left, total }: { left: number; total: number }) {
  const r = 22
  const circ = 2 * Math.PI * r
  const progress = left / total
  const offset = circ * (1 - progress)
  const color = progress > 0.4 ? '#4CAF50' : progress > 0.2 ? '#FFCB46' : '#E55353'
  const pulse = left <= 5 ? 'animate-pulse' : ''
  return (
    <div className={`relative flex items-center justify-center ${pulse}`} style={{ width: 56, height: 56 }}>
      <svg width="56" height="56" style={{ transform: 'rotate(-90deg)' }}>
        <circle cx="28" cy="28" r={r} fill="none" stroke="rgba(52,52,52,0.10)" strokeWidth="3.5" />
        <circle cx="28" cy="28" r={r} fill="none" stroke={color} strokeWidth="3.5"
          strokeDasharray={circ} strokeDashoffset={offset} strokeLinecap="round"
          style={{ transition: 'stroke-dashoffset 0.95s linear, stroke 0.3s' }} />
      </svg>
      <span className="absolute font-black text-[15px]" style={{ color }}>{left}</span>
    </div>
  )
}

function Stat({ label, value, color, bg, highlight, highlightKey }: {
  label: string; value: number; color: string; bg: string; highlight?: number; highlightKey?: number
}) {
  return (
    <div className="relative px-3 sm:px-4 py-2 rounded-2xl flex-1 sm:flex-initial sm:min-w-[80px] text-center" style={{ background: bg }}>
      <div className="text-[10px] font-bold uppercase tracking-wider" style={{ color, opacity: 0.65 }}>{label}</div>
      <div className="font-black text-[22px] sm:text-[26px] tracking-tight leading-none mt-0.5" style={{ color }}>{value}</div>
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
