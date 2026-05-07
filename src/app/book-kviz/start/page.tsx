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
const MILESTONE_INTERVAL = 50
const MILESTONE_LIVES_BONUS = 5
const COMBO_BONUSES: Record<number, { points: number; msg: string }> = {
  5:   { points: 10,  msg: 'Lep niz!' },
  10:  { points: 25,  msg: 'Odličan ritam!' },
  20:  { points: 60,  msg: 'Ozbiljno znanje!' },
  50:  { points: 150, msg: 'Književni majstor!' },
  100: { points: 400, msg: 'Živa enciklopedija!' },
}

type Lifelines = { fiftyFifty: number; skip: number; extraTime: number }

type Question = {
  id: string
  genre: string
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
  const indices = [0, 1, 2, 3].sort(() => Math.random() - 0.5)
  const shuffled = indices.map(i => q.options[i])
  const correctIdx = indices.indexOf(q.correct_answer)
  return { ...q, shuffled, correctIdx, shuffleMap: indices }
}

function fmtTime(seconds: number): string {
  const m = Math.floor(seconds / 60)
  const s = seconds % 60
  return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`
}

export default function BookKvizStart() {
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
  const [skipped, setSkipped] = useState(0)
  const [combo, setCombo] = useState(0)
  const [bestCombo, setBestCombo] = useState(0)
  const [startTime] = useState(() => Date.now())
  const [totalElapsed, setTotalElapsed] = useState(0)
  const [lifelines, setLifelines] = useState<Lifelines>({ fiftyFifty: 1, skip: 1, extraTime: 1 })
  const [usedLifelinesTotal, setUsedLifelinesTotal] = useState<Lifelines>({ fiftyFifty: 0, skip: 0, extraTime: 0 })
  const [eliminatedOptions, setEliminatedOptions] = useState<Set<number>>(new Set())
  const [scoreFlash, setScoreFlash] = useState<{ delta: number; key: number } | null>(null)
  const [milestone, setMilestone] = useState<string | null>(null)
  const [comboFlash, setComboFlash] = useState<string | null>(null)
  const [gameOver, setGameOver] = useState(false)

  // Genre stats — rebuilt on every answer; persisted to session at end.
  const genreStatsRef = useRef<Record<string, { correct: number; total: number }>>({})

  const savingRef = useRef(false)
  const questionStartRef = useRef<number>(Date.now())

  // ── Load questions ─────────────────────────────────────────────────────────
  useEffect(() => {
    async function load() {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) { router.push('/auth/prijava?redirect=/book-kviz'); return }
      setMyId(user.id)

      const { data } = await supabase
        .from('book_questions')
        .select('id, genre, question_text, options, correct_answer')
        .eq('is_active', true)
        .limit(10000)

      if (!data || data.length === 0) { setLoading(false); return }
      const all = (data as Question[]).sort(() => Math.random() - 0.5)
      setPool(all)
      setLoading(false)
    }
    load()
  }, [router])

  const nextQuestion = useCallback((used: Set<string>): DisplayQuestion | null => {
    for (const q of pool) if (!used.has(q.id)) return shuffleOptions(q)
    return null
  }, [pool])

  // First question
  useEffect(() => {
    if (loading || current || gameOver || pool.length === 0) return
    const q = nextQuestion(new Set())
    if (q) {
      setCurrent(q)
      setUsedIds(prev => new Set(prev).add(q.id))
      questionStartRef.current = Date.now()
    }
  }, [loading, current, gameOver, pool.length, nextQuestion])

  // Per-question countdown
  useEffect(() => {
    if (gameOver || revealed || !current || loading) return
    if (timeLeft <= 0) { handleAnswer(null); return }
    const t = setTimeout(() => setTimeLeft(s => s - 1), 1000)
    return () => clearTimeout(t)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [timeLeft, revealed, gameOver, current, loading])

  // Total elapsed clock
  useEffect(() => {
    if (gameOver) return
    const t = setInterval(() => setTotalElapsed(Math.floor((Date.now() - startTime) / 1000)), 1000)
    return () => clearInterval(t)
  }, [startTime, gameOver])

  async function saveSession(finalScore: number, finalReached: number, finalCorrect: number,
    finalWrong: number, finalSkipped: number, finalBest: number, finalUsedLLines: Lifelines) {
    if (savingRef.current || !myId) return
    savingRef.current = true
    const supabase = createClient()
    const totalAnswered = finalCorrect + finalWrong
    const accuracy = totalAnswered > 0 ? Math.round((finalCorrect / totalAnswered) * 10000) / 100 : 0
    const totalTime = Math.floor((Date.now() - startTime) / 1000)

    // Compute top genre — highest correct count, tiebreaker: highest pct
    const breakdown = genreStatsRef.current
    let topGenre: string | null = null
    let topPct: number | null = null
    let topCorrect = -1
    for (const [g, s] of Object.entries(breakdown)) {
      if (s.total === 0) continue
      const pct = (s.correct / s.total) * 100
      if (s.correct > topCorrect || (s.correct === topCorrect && (topPct ?? 0) < pct)) {
        topGenre = g
        topPct = Math.round(pct * 100) / 100
        topCorrect = s.correct
      }
    }

    const { data } = await supabase.from('book_sessions').insert({
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
      top_genre: topGenre,
      top_genre_pct: topPct,
      genre_breakdown: breakdown,
    }).select('id').single()

    sessionStorage.setItem('book-result', JSON.stringify({
      score: finalScore, questionsReached: finalReached, correct: finalCorrect,
      wrong: finalWrong, skipped: finalSkipped, accuracy, bestCombo: finalBest,
      totalTime, topGenre, topPct, breakdown, sessionId: data?.id,
    }))
    router.push('/book-kviz/kraj')
  }

  function handleAnswer(idx: number | null) {
    if (revealed || !current || gameOver) return
    setSelected(idx)
    setRevealed(true)

    const isCorrect = idx === current.correctIdx
    const newReached = reached + 1
    const elapsedMs = Date.now() - questionStartRef.current

    // Update genre stats locally (used at saveSession)
    const g = current.genre
    const prev = genreStatsRef.current[g] || { correct: 0, total: 0 }
    genreStatsRef.current[g] = { correct: prev.correct + (isCorrect ? 1 : 0), total: prev.total + 1 }

    // Per-answer log (analytics)
    if (myId) {
      const supabase = createClient()
      const pickedOriginalIdx = idx == null ? null : (current.shuffleMap[idx] ?? null)
      supabase.from('book_answer_log').insert({
        question_id: current.id,
        user_id: myId,
        genre: g,
        was_correct: isCorrect,
        picked_idx: pickedOriginalIdx,
        time_ms: elapsedMs,
      }).then(({ error }) => { if (error) console.error('book log insert failed', error) })
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

      if (newReached % MILESTONE_INTERVAL === 0) {
        setLives(l => l + MILESTONE_LIVES_BONUS)
        const lls = ['fiftyFifty', 'skip', 'extraTime'] as const
        const award = lls[Math.floor(Math.random() * lls.length)]
        setLifelines(l => ({ ...l, [award]: l[award] + 1 }))
        setMilestone(`Preživeo/la si ${newReached} pitanja! +${MILESTONE_LIVES_BONUS} života + bonus pomoć`)
        setTimeout(() => setMilestone(null), 3500)
      }
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
          saveSession(newScore, newReached, correct, wrong + 1, skipped, bestCombo, usedLifelinesTotal)
        }, 2200)
        return
      }
    }

    setTimeout(() => goNextQuestion(), 2800)
  }

  function goNextQuestion() {
    setEliminatedOptions(new Set())
    setSelected(null)
    setRevealed(false)
    setTimeLeft(TIME_PER_QUESTION)
    const q = nextQuestion(usedIds)
    if (!q) {
      setGameOver(true)
      saveSession(score, reached, correct, wrong, skipped, bestCombo, usedLifelinesTotal)
      return
    }
    setCurrent(q)
    setUsedIds(prev => new Set(prev).add(q.id))
    questionStartRef.current = Date.now()
  }

  function useFiftyFifty() {
    if (lifelines.fiftyFifty <= 0 || revealed || !current) return
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
    setTimeout(() => { setReached(r => r + 1); goNextQuestion() }, 600)
  }

  function useExtraTime() {
    if (lifelines.extraTime <= 0 || revealed) return
    setTimeLeft(t => t + 15)
    setLifelines(l => ({ ...l, extraTime: l.extraTime - 1 }))
    setUsedLifelinesTotal(t => ({ ...t, extraTime: t.extraTime + 1 }))
  }

  function exitGame() {
    if (confirm('Sigurno želiš da prekineš igru? Rezultat se neće sačuvati.')) {
      router.push('/book-kviz')
    }
  }

  // ── Render ──────────────────────────────────────────────────────────────
  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center" style={{ background: '#FAFAFA' }}>
        <div className="w-8 h-8 rounded-full border-2 animate-spin"
          style={{ borderColor: '#9c7a13', borderTopColor: 'transparent' }} />
      </div>
    )
  }

  if (!current && !gameOver) {
    return (
      <div className="min-h-screen flex items-center justify-center px-4" style={{ background: '#FAFAFA' }}>
        <div className="card-soft p-8 text-center max-w-md">
          <p className="font-bold text-[16px] mb-2" style={{ color: '#343434' }}>Nema pitanja</p>
          <p className="text-[13px] mb-4" style={{ color: '#9C9C9C' }}>Pokušaj kasnije.</p>
          <button onClick={() => router.push('/book-kviz')} className="btn btn-primary btn-md">Nazad</button>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen flex flex-col" style={{ background: '#FAFAFA' }}>

      {/* HUD */}
      <div className="sticky top-0 z-40 backdrop-blur-xl"
        style={{ background: 'rgba(252,252,252,0.92)', borderBottom: '1px solid rgba(52,52,52,0.06)' }}>
        <div className="max-w-2xl mx-auto px-4 sm:px-6 py-3 flex items-center justify-between gap-3">
          <button onClick={exitGame} className="w-9 h-9 rounded-full flex items-center justify-center"
            style={{ background: '#F2F2F2', color: '#9C9C9C' }}>
            <IconClose size={16} strokeWidth={2.2} />
          </button>
          <div className="flex items-center gap-3 text-[13px]" style={{ color: '#343434' }}>
            <span>❤️ {lives}</span>
            <span className="font-bold tabular-nums">{score}</span>
            <span style={{ color: '#9C9C9C' }}>{fmtTime(totalElapsed)}</span>
          </div>
          <div className="text-[11px] tabular-nums" style={{ color: '#9C9C9C' }}>
            #{reached + 1}
          </div>
        </div>
        {/* Per-question time bar */}
        <div className="max-w-2xl mx-auto px-4 sm:px-6 pb-2">
          <div className="h-1.5 rounded-full overflow-hidden" style={{ background: '#F2F2F2' }}>
            <div className="h-full transition-all" style={{
              width: `${(timeLeft / TIME_PER_QUESTION) * 100}%`,
              background: timeLeft <= 5 ? '#E55353' : '#9c7a13',
            }} />
          </div>
        </div>
      </div>

      {current && (
        <main className="flex-1 max-w-2xl mx-auto px-4 sm:px-6 py-6 sm:py-10 w-full">
          <p className="text-[11px] font-bold uppercase tracking-widest mb-3 text-center" style={{ color: '#9c7a13' }}>
            Pitanje #{reached + 1}
          </p>
          <div className="card-soft p-6 sm:p-7 mb-5">
            <p className="text-[18px] sm:text-[20px] font-bold leading-snug" style={{ color: '#343434' }}>
              {current.question_text}
            </p>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 mb-5">
            {current.shuffled.map((opt, i) => {
              const isCorrect = i === current.correctIdx
              const isPicked = i === selected
              const eliminated = eliminatedOptions.has(i)
              let bg = '#FCFCFC', fg = '#343434', border = '1.5px solid rgba(52,52,52,0.10)'
              if (revealed) {
                if (isCorrect) { bg = '#E8F8F0'; fg = '#15803d'; border = '1.5px solid #15803d' }
                else if (isPicked) { bg = '#FEE2E2'; fg = '#b91c1c'; border = '1.5px solid #b91c1c' }
              }
              return (
                <button key={i} onClick={() => handleAnswer(i)}
                  disabled={revealed || eliminated}
                  className="text-left p-4 rounded-2xl transition-all disabled:opacity-40 disabled:cursor-not-allowed"
                  style={{ background: bg, color: fg, border }}>
                  <span className="font-semibold text-[15px]">{opt}</span>
                </button>
              )
            })}
          </div>

          {/* Lifelines */}
          <div className="grid grid-cols-3 gap-2 mb-5">
            <button onClick={useFiftyFifty} disabled={lifelines.fiftyFifty <= 0 || revealed}
              className="rounded-2xl p-3 text-center transition-all disabled:opacity-30" style={{ background: '#F2F2F2' }}>
              <div className="font-bold text-[13px]" style={{ color: '#343434' }}>Pola-pola</div>
              <div className="text-[10px]" style={{ color: '#9C9C9C' }}>{lifelines.fiftyFifty}× preostalo</div>
            </button>
            <button onClick={useSkip} disabled={lifelines.skip <= 0 || revealed}
              className="rounded-2xl p-3 text-center transition-all disabled:opacity-30" style={{ background: '#F2F2F2' }}>
              <div className="font-bold text-[13px]" style={{ color: '#343434' }}>Preskoči</div>
              <div className="text-[10px]" style={{ color: '#9C9C9C' }}>{lifelines.skip}× preostalo</div>
            </button>
            <button onClick={useExtraTime} disabled={lifelines.extraTime <= 0 || revealed}
              className="rounded-2xl p-3 text-center transition-all disabled:opacity-30" style={{ background: '#F2F2F2' }}>
              <div className="font-bold text-[13px]" style={{ color: '#343434' }}>+15 sekundi</div>
              <div className="text-[10px]" style={{ color: '#9C9C9C' }}>{lifelines.extraTime}× preostalo</div>
            </button>
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

      {milestone && (
        <div className="fixed top-1/3 left-1/2 -translate-x-1/2 px-6 py-4 rounded-2xl font-bold text-[15px] text-center max-w-sm z-50"
          style={{ background: '#FFECBC', color: '#9c7a13' }}>
          🎉 {milestone}
        </div>
      )}

      {gameOver && (
        <div className="fixed inset-0 flex items-center justify-center pointer-events-none z-50">
          <div className="card-soft p-8 text-center" style={{ background: '#FCFCFC' }}>
            <p className="font-black text-[24px] mb-2" style={{ color: '#343434' }}>Kraj igre!</p>
            <p className="text-[14px]" style={{ color: '#9C9C9C' }}>Računam rezultat…</p>
          </div>
        </div>
      )}
    </div>
  )
}
