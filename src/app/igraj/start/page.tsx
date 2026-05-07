'use client'

export const dynamic = 'force-dynamic'

import { useEffect, useState, useRef, useCallback } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { IconClose, IconHint, IconCheck, IconWrong } from '@/components/icons'

// ── Game constants ──────────────────────────────────────────────────────────
const TIME_PER_QUESTION = 15
const STARTING_LIVES = 10
const POINTS_CORRECT = 10
const POINTS_WRONG = 5
const RISK_BONUS = 10              // +10 extra (so total +20 instead of +10)
const RISK_PENALTY_LIVES = 2       // 2 lives lost on wrong risk
const RISK_PENALTY_POINTS = 10     // 10 points lost on wrong risk
const MILESTONE_INTERVAL = 50      // every 50 questions
const MILESTONE_LIVES_BONUS = 5    // +5 lives + 1 random lifeline
const COMBO_BONUSES: Record<number, { points: number; msg: string }> = {
  5:   { points: 10,  msg: 'Lep niz!' },
  10:  { points: 25,  msg: 'Odličan ritam!' },
  20:  { points: 60,  msg: 'Ozbiljno znanje!' },
  50:  { points: 150, msg: 'Librum mašina!' },
  100: { points: 400, msg: 'Živa enciklopedija!' },
}

type Question = {
  id: string
  question_text: string
  options: string[]            // [correct, wrong1, wrong2, wrong3] in DB order
  correct_answer: number       // always 0 in DB
  difficulty: 'easy' | 'medium' | 'hard' | 'impossible'
  info: string | null
}

type DisplayQuestion = Question & {
  shuffled: string[]           // randomized order
  correctIdx: number           // index of correct in shuffled
  shuffleMap: number[]         // shuffleMap[shuffled_idx] = original DB option index
}

// Difficulty weights per progression bucket — see spec section 7
function difficultyWeights(reached: number): Record<string, number> {
  if (reached < 30)  return { easy: 60, medium: 35, hard: 5,  impossible: 0  }
  if (reached < 70)  return { easy: 25, medium: 50, hard: 25, impossible: 0  }
  if (reached < 100) return { easy: 10, medium: 35, hard: 45, impossible: 10 }
  if (reached < 200) return { easy: 0,  medium: 20, hard: 55, impossible: 25 }
  return                    { easy: 0,  medium: 10, hard: 50, impossible: 40 }
}

function pickDifficulty(reached: number): string {
  const w = difficultyWeights(reached)
  const total = Object.values(w).reduce((a, b) => a + b, 0)
  let r = Math.random() * total
  for (const [diff, weight] of Object.entries(w)) {
    if (r < weight) return diff
    r -= weight
  }
  return 'medium'
}

function shuffleOptions(q: Question): DisplayQuestion {
  const indices = [0, 1, 2, 3].sort(() => Math.random() - 0.5)
  const shuffled = indices.map(i => q.options[i])
  const correctIdx = indices.indexOf(q.correct_answer)
  return { ...q, shuffled, correctIdx, shuffleMap: indices }
}

function fmtTime(seconds: number): string {
  const m = Math.floor(seconds / 60)
  const s = seconds % 60
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
}

// ── Circular timer ──────────────────────────────────────────────────────────
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

// ── Main ────────────────────────────────────────────────────────────────────

type Lifelines = { fiftyFifty: number; skip: number; extraTime: number }

export default function SurvivorGame() {
  const router = useRouter()
  const [pool, setPool] = useState<Question[]>([])
  const [poolByDiff, setPoolByDiff] = useState<Record<string, Question[]>>({})
  const [usedIds, setUsedIds] = useState<Set<string>>(new Set())
  const [loading, setLoading] = useState(true)
  const [myId, setMyId] = useState<string | null>(null)

  // Game state
  const [current, setCurrent] = useState<DisplayQuestion | null>(null)
  const [selected, setSelected] = useState<number | null>(null)
  const [revealed, setRevealed] = useState(false)
  const [timeLeft, setTimeLeft] = useState(TIME_PER_QUESTION)
  const [lives, setLives] = useState(STARTING_LIVES)
  const [score, setScore] = useState(0)
  const [reached, setReached] = useState(0)
  const [correct, setCorrect] = useState(0)
  const [wrong, setWrong] = useState(0)
  const [skipped, setSkipped] = useState(0)
  const [combo, setCombo] = useState(0)
  const [bestCombo, setBestCombo] = useState(0)
  const [startTime] = useState(() => Date.now())
  const [totalElapsed, setTotalElapsed] = useState(0)
  const [lifelines, setLifelines] = useState<Lifelines>({ fiftyFifty: 1, skip: 1, extraTime: 1 })
  const [usedLifelinesTotal, setUsedLifelinesTotal] = useState<Lifelines>({ fiftyFifty: 0, skip: 0, extraTime: 0 })
  const [eliminatedOptions, setEliminatedOptions] = useState<Set<number>>(new Set())
  const [riskActive, setRiskActive] = useState(false)
  const [lastRiskQuestion, setLastRiskQuestion] = useState(0) // 1-indexed question number when risk last used
  const [riskAttempts, setRiskAttempts] = useState(0)
  const [riskCorrect, setRiskCorrect] = useState(0)
  const [riskWrong, setRiskWrong] = useState(0)
  const [scoreFlash, setScoreFlash] = useState<{ delta: number; key: number } | null>(null)
  const [milestone, setMilestone] = useState<string | null>(null)
  const [comboFlash, setComboFlash] = useState<string | null>(null)
  const [gameOver, setGameOver] = useState(false)

  const savingRef = useRef(false)
  const questionStartRef = useRef<number>(Date.now())

  // ── Load questions ─────────────────────────────────────────────────────────
  useEffect(() => {
    async function load() {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) { router.push('/auth/prijava'); return }
      setMyId(user.id)

      // Pull every active question — players can keep going until the DB is exhausted
      const { data } = await supabase
        .from('questions')
        .select('id, question_text, options, correct_answer, difficulty, info')
        .eq('is_active', true)
        .limit(10000)

      if (!data || data.length === 0) { setLoading(false); return }

      const all = (data as Question[])
      // Shuffle once at session start
      all.sort(() => Math.random() - 0.5)

      const byDiff: Record<string, Question[]> = { easy: [], medium: [], hard: [], impossible: [] }
      all.forEach(q => { (byDiff[q.difficulty] ?? byDiff.medium).push(q) })

      setPool(all)
      setPoolByDiff(byDiff)
      setLoading(false)
    }
    load()
  }, [router])

  // ── Pick next question ────────────────────────────────────────────────────
  const nextQuestion = useCallback((reachedNow: number, used: Set<string>) => {
    const wantedDiff = pickDifficulty(reachedNow)
    const order = ['easy', 'medium', 'hard', 'impossible']
    // Prefer wanted, then walk outwards
    const idx = order.indexOf(wantedDiff)
    const candidates: string[] = [wantedDiff]
    for (let d = 1; d < order.length; d++) {
      if (idx - d >= 0) candidates.push(order[idx - d])
      if (idx + d < order.length) candidates.push(order[idx + d])
    }

    for (const diff of candidates) {
      const list = poolByDiff[diff] ?? []
      for (const q of list) {
        if (!used.has(q.id)) return shuffleOptions(q)
      }
    }
    // Fallback: any unused
    for (const q of pool) if (!used.has(q.id)) return shuffleOptions(q)
    return null
  }, [pool, poolByDiff])

  // ── Start first question ──────────────────────────────────────────────────
  useEffect(() => {
    if (loading || current || gameOver || pool.length === 0) return
    const q = nextQuestion(0, new Set())
    if (q) {
      setCurrent(q)
      setUsedIds(prev => new Set(prev).add(q.id))
      questionStartRef.current = Date.now()
    }
  }, [loading, current, gameOver, pool.length, nextQuestion])

  // ── Tick timer ────────────────────────────────────────────────────────────
  useEffect(() => {
    if (gameOver || revealed || !current || loading) return
    if (timeLeft <= 0) {
      handleAnswer(null) // timeout
      return
    }
    const t = setTimeout(() => setTimeLeft(s => s - 1), 1000)
    return () => clearTimeout(t)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [timeLeft, revealed, gameOver, current, loading])

  // ── Total elapsed clock ───────────────────────────────────────────────────
  useEffect(() => {
    if (gameOver) return
    const t = setInterval(() => {
      setTotalElapsed(Math.floor((Date.now() - startTime) / 1000))
    }, 1000)
    return () => clearInterval(t)
  }, [startTime, gameOver])

  // ── Save & exit on game over ──────────────────────────────────────────────
  async function saveSession(finalScore: number, finalReached: number, finalCorrect: number,
    finalWrong: number, finalSkipped: number, finalBest: number,
    finalUsedLLines: Lifelines, finalRiskA: number, finalRiskC: number, finalRiskW: number) {
    if (savingRef.current || !myId) return
    savingRef.current = true
    const supabase = createClient()
    const totalAnswered = finalCorrect + finalWrong
    const accuracy = totalAnswered > 0 ? Math.round((finalCorrect / totalAnswered) * 10000) / 100 : 0
    const totalTime = Math.floor((Date.now() - startTime) / 1000)

    const { data } = await supabase.from('survivor_sessions').insert({
      user_id: myId,
      score: finalScore,
      questions_reached: finalReached,
      correct_answers: finalCorrect,
      wrong_answers: finalWrong,
      skipped_questions: finalSkipped,
      accuracy,
      best_combo: finalBest,
      total_time_seconds: totalTime,
      used_lifelines: finalUsedLLines,
      risk_attempts: finalRiskA,
      risk_correct: finalRiskC,
      risk_wrong: finalRiskW,
    }).select('id').single()

    sessionStorage.setItem('survivor-result', JSON.stringify({
      score: finalScore, questionsReached: finalReached, correct: finalCorrect,
      wrong: finalWrong, skipped: finalSkipped, accuracy, bestCombo: finalBest,
      totalTime, sessionId: data?.id,
    }))
    router.push('/igraj/kraj')
  }

  // ── Handle answer ─────────────────────────────────────────────────────────
  function handleAnswer(idx: number | null) {
    if (revealed || !current || gameOver) return
    setSelected(idx)
    setRevealed(true)

    const isCorrect = idx === current.correctIdx
    const newReached = reached + 1
    const elapsedMs = Date.now() - questionStartRef.current

    // Map shuffled-index back to the original DB option index so analytics
    // know which actual answer the user picked. picked = null on timeout.
    const pickedOriginalIdx = idx == null ? null : (current.shuffleMap[idx] ?? null)

    // Fire-and-forget log; failure here must never block the game.
    if (myId) {
      const supabase = createClient()
      supabase.from('question_answer_log').insert({
        question_id: current.id,
        user_id: myId,
        was_correct: isCorrect,
        picked_idx: pickedOriginalIdx,
        time_ms: elapsedMs,
      }).then(({ error }) => {
        if (error) console.error('answer log insert failed', error)
      })
    }

    if (isCorrect) {
      const baseDelta = riskActive ? POINTS_CORRECT + RISK_BONUS : POINTS_CORRECT
      const newCombo = combo + 1
      let newScore = score + baseDelta

      // Combo bonus
      const bonus = COMBO_BONUSES[newCombo]
      if (bonus) {
        newScore += bonus.points
        setComboFlash(`${bonus.msg} +${bonus.points}`)
        setTimeout(() => setComboFlash(null), 2500)
      }

      const newRiskC = riskActive ? riskCorrect + 1 : riskCorrect
      setScore(newScore)
      setReached(newReached)
      setCorrect(c => c + 1)
      setCombo(newCombo)
      setBestCombo(b => Math.max(b, newCombo))
      setRiskCorrect(newRiskC)
      setScoreFlash({ delta: baseDelta, key: Date.now() })

      // Milestones — every 50 → +5 lives + bonus lifeline
      if (newReached % MILESTONE_INTERVAL === 0) {
        setLives(l => l + MILESTONE_LIVES_BONUS)
        // Award one random lifeline
        const lls = ['fiftyFifty', 'skip', 'extraTime'] as const
        const award = lls[Math.floor(Math.random() * lls.length)]
        setLifelines(l => ({ ...l, [award]: l[award] + 1 }))
        setMilestone(`Preživeo/la si ${newReached} pitanja! +${MILESTONE_LIVES_BONUS} života + bonus pomoć`)
        setTimeout(() => setMilestone(null), 3500)
      } else if ([10, 25, 100, 200, 300, 500, 1000].includes(newReached)) {
        const msgs: Record<number, string> = {
          10:  'Krenulo je! 10 pitanja.',
          25:  'Dobro ide! 25 pitanja.',
          100: 'Stigao/la si do 100 pitanja.',
          200: 'Ovo je već ozbiljan maraton znanja.',
          300: 'Ulaziš u zonu najjačih igrača.',
          500: 'Librum legenda u nastajanju.',
          1000: 'Živa enciklopedija. Ovo se pamti.',
        }
        setMilestone(msgs[newReached])
        setTimeout(() => setMilestone(null), 3000)
      }
    } else {
      // Wrong or timeout
      const livesLost = riskActive ? RISK_PENALTY_LIVES : 1
      const pointsLost = riskActive ? RISK_PENALTY_POINTS : POINTS_WRONG
      const newLives = lives - livesLost
      const newScore = Math.max(0, score - pointsLost)
      const newRiskW = riskActive ? riskWrong + 1 : riskWrong

      setLives(newLives)
      setScore(newScore)
      setReached(newReached)
      setWrong(w => w + 1)
      setCombo(0)
      setRiskWrong(newRiskW)
      setScoreFlash({ delta: -pointsLost, key: Date.now() })

      if (newLives <= 0) {
        // Game over after reveal animation
        setGameOver(true)
        setTimeout(() => {
          saveSession(newScore, newReached, correct, wrong + 1, skipped, bestCombo,
            usedLifelinesTotal, riskAttempts, riskCorrect, newRiskW)
        }, 2200)
        return
      }
    }

    // Auto-advance after 3s
    setTimeout(() => goNextQuestion(newReached), 2800)
  }

  function goNextQuestion(newReached: number) {
    setRiskActive(false)
    setEliminatedOptions(new Set())
    setSelected(null)
    setRevealed(false)
    setTimeLeft(TIME_PER_QUESTION)
    const q = nextQuestion(newReached, usedIds)
    if (!q) {
      // Out of questions — end game
      setGameOver(true)
      saveSession(score, newReached, correct, wrong, skipped, bestCombo,
        usedLifelinesTotal, riskAttempts, riskCorrect, riskWrong)
      return
    }
    setCurrent(q)
    setUsedIds(prev => new Set(prev).add(q.id))
    questionStartRef.current = Date.now()
  }

  // ── Lifelines ─────────────────────────────────────────────────────────────
  function useFiftyFifty() {
    if (lifelines.fiftyFifty <= 0 || revealed || !current) return
    // Eliminate 2 wrong options
    const wrongIdxs: number[] = []
    current.shuffled.forEach((_, i) => { if (i !== current.correctIdx) wrongIdxs.push(i) })
    wrongIdxs.sort(() => Math.random() - 0.5)
    setEliminatedOptions(new Set(wrongIdxs.slice(0, 2)))
    setLifelines(l => ({ ...l, fiftyFifty: l.fiftyFifty - 1 }))
    setUsedLifelinesTotal(t => ({ ...t, fiftyFifty: t.fiftyFifty + 1 }))
  }

  function useSkip() {
    if (lifelines.skip <= 0 || revealed || !current) return
    setSkipped(s => s + 1)
    setLifelines(l => ({ ...l, skip: l.skip - 1 }))
    setUsedLifelinesTotal(t => ({ ...t, skip: t.skip + 1 }))
    setRevealed(true)
    setTimeout(() => goNextQuestion(reached + 1), 600)
    setReached(r => r + 1)
  }

  function useExtraTime() {
    if (lifelines.extraTime <= 0 || revealed) return
    setTimeLeft(t => t + 15)
    setLifelines(l => ({ ...l, extraTime: l.extraTime - 1 }))
    setUsedLifelinesTotal(t => ({ ...t, extraTime: t.extraTime + 1 }))
  }

  // Risk available once per 10-question bucket
  const currentBucket = Math.floor(reached / 10)
  const lastRiskBucket = Math.floor((lastRiskQuestion - 1) / 10)
  const riskAvailable = !revealed && current && (lastRiskQuestion === 0 || currentBucket > lastRiskBucket) && !riskActive

  function activateRisk() {
    if (!riskAvailable) return
    setRiskActive(true)
    setLastRiskQuestion(reached + 1)
    setRiskAttempts(a => a + 1)
  }

  // ── Confirm exit ───────────────────────────────────────────────────────────
  const [showExitConfirm, setShowExitConfirm] = useState(false)

  // ── Render ─────────────────────────────────────────────────────────────────
  if (loading || !current) {
    return (
      <div className="min-h-screen flex items-center justify-center" style={{ background: '#FAFAFA' }}>
        <div className="w-8 h-8 rounded-full border-2 animate-spin"
          style={{ borderColor: '#609DED', borderTopColor: 'transparent' }} />
      </div>
    )
  }

  return (
    <div className="min-h-screen flex flex-col" style={{ background: '#FAFAFA' }}>

      {/* ── Top HUD ────────────────────────────────────────────────────── */}
      <header className="sticky top-0 z-30 backdrop-blur-xl"
        style={{ background: 'rgba(252,252,252,0.92)', borderBottom: '1px solid rgba(52,52,52,0.06)' }}>
        <div className="max-w-5xl mx-auto px-4 sm:px-6 py-3 flex items-center justify-between gap-3">
          <button onClick={() => setShowExitConfirm(true)}
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

          <Timer left={timeLeft} total={TIME_PER_QUESTION + (lifelines.extraTime < 1 && timeLeft > TIME_PER_QUESTION ? 15 : 0)} />
        </div>
        {/* Progress dots within current 10-bucket */}
        <div className="max-w-5xl mx-auto px-4 sm:px-6 pb-2.5 flex gap-1">
          {Array.from({ length: 10 }).map((_, i) => {
            const idx = (reached % 10)
            const bg = i < idx ? '#4CAF50' : i === idx ? '#FFCB46' : 'rgba(52,52,52,0.10)'
            return <div key={i} className="flex-1 h-1.5 rounded-full transition-all" style={{ background: bg }} />
          })}
        </div>
      </header>

      {/* ── Main play area ─────────────────────────────────────────────── */}
      <main className="flex-1 flex flex-col items-center justify-start px-4 sm:px-6 py-6">
        <div className="w-full max-w-3xl" key={current.id}>

          {/* Risk banner */}
          {riskActive && (
            <div className="rounded-2xl px-4 py-3 mb-4 text-center text-[13px] font-bold animate-fade-in"
              style={{ background: '#FFCB46', color: '#343434' }}>
              ⚡ Risk aktiviran — duplo dobit, duplo gubitak
            </div>
          )}

          {/* Question card */}
          <div className="card-soft p-6 sm:p-8 mb-4">
            <p className="text-[11px] font-bold uppercase tracking-widest mb-3" style={{ color: '#9C9C9C' }}>
              Pitanje {reached + 1}
            </p>
            <h2 className="font-bold tracking-tight leading-snug mb-7"
              style={{ color: '#343434', fontSize: 'clamp(18px, 3vw, 22px)' }}>
              {current.question_text}
            </h2>

            <div className="space-y-2.5">
              {current.shuffled.map((opt, i) => {
                const isCorrect = i === current.correctIdx
                const isSelected = i === selected
                const isEliminated = eliminatedOptions.has(i)
                let bg = '#FCFCFC'
                let border = 'rgba(52,52,52,0.10)'
                let fg = '#343434'
                let labelBg = '#F2F2F2'
                let labelFg = '#9C9C9C'
                if (revealed) {
                  if (isCorrect) {
                    bg = '#E8F8F0'; border = '#4CAF50'; fg = '#15803d'; labelBg = '#4CAF50'; labelFg = 'white'
                  } else if (isSelected) {
                    bg = '#FEE2E2'; border = '#E55353'; fg = '#b91c1c'; labelBg = '#E55353'; labelFg = 'white'
                  } else {
                    bg = '#F2F2F2'; border = 'transparent'; fg = '#9C9C9C'
                  }
                } else if (isEliminated) {
                  bg = '#F2F2F2'; border = 'transparent'; fg = '#d1d1d1'; labelBg = '#e5e5e5'; labelFg = '#d1d1d1'
                }
                return (
                  <button key={i} onClick={() => handleAnswer(i)}
                    disabled={revealed || isEliminated}
                    className="w-full flex items-center gap-3 px-4 py-3.5 rounded-2xl text-left transition-all disabled:cursor-default"
                    style={{ background: bg, border: `1.5px solid ${border}`, color: fg }}>
                    <span className="w-8 h-8 rounded-xl flex items-center justify-center text-[13px] font-black flex-shrink-0"
                      style={{ background: labelBg, color: labelFg }}>
                      {revealed && isCorrect ? <IconCheck size={14} className="text-white" />
                        : revealed && isSelected ? <IconWrong size={14} className="text-white" />
                        : ['A', 'B', 'C', 'D'][i]}
                    </span>
                    <span className="flex-1 text-[14px] sm:text-[15px] font-medium">{opt}</span>
                  </button>
                )
              })}
            </div>

            {/* Info after reveal */}
            {revealed && current.info && (
              <div className="mt-5 rounded-2xl px-4 py-3 text-[13px] font-medium" style={{ background: '#BCD9FF', color: '#1e5fa4' }}>
                {current.info}
              </div>
            )}
          </div>

          {/* Lifelines / Risk row */}
          {!revealed && (
            <div className="grid grid-cols-4 gap-2">
              <LifelineBtn label="50/50" remaining={lifelines.fiftyFifty} onClick={useFiftyFifty} />
              <LifelineBtn label="Preskoči" remaining={lifelines.skip} onClick={useSkip} />
              <LifelineBtn label="+15s" remaining={lifelines.extraTime} onClick={useExtraTime} />
              <button onClick={activateRisk} disabled={!riskAvailable}
                className="rounded-2xl py-3 text-center transition-all disabled:opacity-40 disabled:cursor-not-allowed"
                style={{ background: riskAvailable ? '#FFCB46' : '#F2F2F2', color: riskAvailable ? '#343434' : '#9C9C9C' }}>
                <div className="font-black text-[12px] tracking-tight">Risk</div>
                <div className="text-[10px] font-medium opacity-70">×2</div>
              </button>
            </div>
          )}

        </div>
      </main>

      {/* ── Floating notifications ─────────────────────────────────────── */}
      {milestone && (
        <div className="fixed inset-x-0 top-24 z-40 px-4 flex justify-center pointer-events-none">
          <div className="rounded-2xl px-5 py-3 text-center font-bold text-[14px] animate-pop-in shadow-2xl max-w-sm"
            style={{ background: '#343434', color: '#FCFCFC' }}>
            🎉 {milestone}
          </div>
        </div>
      )}
      {comboFlash && !milestone && (
        <div className="fixed inset-x-0 top-24 z-40 px-4 flex justify-center pointer-events-none">
          <div className="rounded-2xl px-5 py-3 text-center font-bold text-[14px] animate-pop-in shadow-2xl"
            style={{ background: '#609DED', color: 'white' }}>
            {comboFlash}
          </div>
        </div>
      )}

      {/* Game over overlay */}
      {gameOver && (
        <div className="fixed inset-0 z-50 flex items-center justify-center px-4 backdrop-blur-sm"
          style={{ background: 'rgba(52,52,52,0.40)' }}>
          <div className="card-soft p-8 text-center max-w-sm w-full animate-pop-in">
            <div className="text-5xl mb-4">💀</div>
            <h3 className="font-black text-[24px] tracking-tight mb-2" style={{ color: '#343434' }}>Kraj igre</h3>
            <p className="text-[13px]" style={{ color: '#9C9C9C' }}>Računamo rezultat…</p>
          </div>
        </div>
      )}

      {/* Exit confirm */}
      {showExitConfirm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center px-4 backdrop-blur-sm"
          style={{ background: 'rgba(52,52,52,0.40)' }}>
          <div className="card-soft p-7 text-center max-w-sm w-full">
            <h3 className="font-black text-[20px] tracking-tight mb-2" style={{ color: '#343434' }}>Izađi iz igre?</h3>
            <p className="text-[13px] mb-6" style={{ color: '#9C9C9C' }}>Trenutni rezultat se NEĆE upisati.</p>
            <div className="flex gap-3">
              <button onClick={() => setShowExitConfirm(false)} className="btn btn-secondary btn-md flex-1">
                Nastavi
              </button>
              <button onClick={() => router.push('/igraj')} className="btn btn-md flex-1"
                style={{ background: '#E55353', color: 'white' }}>
                Izađi
              </button>
            </div>
          </div>
        </div>
      )}

      <div className="px-4 pb-4 text-center text-[11px]" style={{ color: '#9C9C9C' }}>
        ukupno: {fmtTime(totalElapsed)} · najbolji niz: {bestCombo} · tačno: {correct} · pogr: {wrong}
      </div>
    </div>
  )
}

function Stat({ label, value, color, bg, highlight, highlightKey }: {
  label: string; value: number; color: string; bg: string; highlight?: number; highlightKey?: number
}) {
  return (
    <div className="relative px-3 sm:px-4 py-2 rounded-2xl flex-1 sm:flex-initial sm:min-w-[80px] text-center" style={{ background: bg }}>
      <div className="text-[10px] font-bold uppercase tracking-wider" style={{ color: color, opacity: 0.65 }}>{label}</div>
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

function LifelineBtn({ label, remaining, onClick }: { label: string; remaining: number; onClick: () => void }) {
  const enabled = remaining > 0
  return (
    <button onClick={onClick} disabled={!enabled}
      className="rounded-2xl py-3 text-center transition-all disabled:opacity-40 disabled:cursor-not-allowed"
      style={{ background: enabled ? '#BCD9FF' : '#F2F2F2', color: enabled ? '#1e5fa4' : '#9C9C9C' }}>
      <div className="font-black text-[12px] tracking-tight">{label}</div>
      <div className="text-[10px] font-medium opacity-70">{remaining}×</div>
    </button>
  )
}
