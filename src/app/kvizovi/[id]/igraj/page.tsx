'use client'

import { useEffect, useState, useCallback, useRef } from 'react'
import { useParams, useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import type { Question, Quiz } from '@/types/database'
import Image from 'next/image'

const QUESTIONS_PER_LEVEL = 10
const WRONG_PENALTY = 5

function getTimePerQuestion(difficulty: string | undefined): number {
  return difficulty === 'lako' ? 10 : 15
}

function getPointsPerCorrect(difficulty: string | undefined): number {
  if (difficulty === 'lako') return 5
  if (difficulty === 'srednje') return 10
  return 25
}

function getDifficultyMeta(difficulty: string | undefined) {
  if (difficulty === 'lako')    return { label: 'Lako',    color: '#5DBF94', bg: '#E8F8F0', textDark: '#0A4C35' }
  if (difficulty === 'srednje') return { label: 'Srednje', color: '#FDC361', bg: '#FFF9EC', textDark: '#7a4e00' }
  return                               { label: 'Teško',   color: '#e05252', bg: '#FEF2F2', textDark: '#b91c1c' }
}

function getCharacter(revealed: boolean, selected: number | null, correctAnswer: number, timeLeft: number): string {
  if (!revealed) return timeLeft <= 3 ? '/chars-timeout.png' : '/chars-neutral.png'
  if (selected === null) return '/chars-laugh.png'
  return selected === correctAnswer ? '/chars-correct.png' : '/chars-wrong.png'
}

// ── Circular timer ─────────────────────────────────────────────────────────

function CircularTimer({ timeLeft, total }: { timeLeft: number; total: number }) {
  const r = 22
  const circ = 2 * Math.PI * r
  const progress = timeLeft / total
  const offset = circ * (1 - progress)
  const color = progress > 0.5 ? '#5DBF94' : progress > 0.25 ? '#FDC361' : '#e05252'
  return (
    <div className="relative flex items-center justify-center" style={{ width: 56, height: 56 }}>
      <svg width="56" height="56" style={{ transform: 'rotate(-90deg)' }}>
        <circle cx="28" cy="28" r={r} fill="none" stroke="rgba(0,0,0,0.06)" strokeWidth="3.5" />
        <circle cx="28" cy="28" r={r} fill="none" stroke={color} strokeWidth="3.5"
          strokeDasharray={circ} strokeDashoffset={offset} strokeLinecap="round"
          style={{ transition: 'stroke-dashoffset 0.9s linear, stroke 0.3s' }} />
      </svg>
      <span className="absolute text-sm font-black" style={{ color }}>{timeLeft}</span>
    </div>
  )
}

// ── Confirm popup ──────────────────────────────────────────────────────────

function ConfirmPopup({ title, message, confirmLabel = 'Da', cancelLabel = 'Ne', onConfirm, onCancel, disabled = false }: {
  title: string; message: string; confirmLabel?: string; cancelLabel?: string
  onConfirm: () => void; onCancel: () => void; disabled?: boolean
}) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm px-6">
      <div className="bg-white rounded-3xl shadow-2xl max-w-sm w-full p-8 text-center animate-pop-in">
        <div className="text-4xl mb-3">❓</div>
        <h3 className="text-xl font-bold text-gray-800 mb-2">{title}</h3>
        <p className="text-gray-500 text-sm mb-8">{message}</p>
        <div className="flex gap-3">
          <button onClick={onCancel} className="flex-1 py-3 rounded-xl border-2 border-gray-200 font-semibold text-gray-600 hover:bg-gray-50">
            {cancelLabel}
          </button>
          <button onClick={disabled ? undefined : onConfirm} disabled={disabled}
            className="flex-1 py-3 rounded-xl font-semibold text-white disabled:opacity-50"
            style={{ background: disabled ? '#ccc' : 'linear-gradient(135deg, #2C2D81, #3766B0)' }}>
            {confirmLabel}
          </button>
        </div>
      </div>
    </div>
  )
}

// ── Level end screen ───────────────────────────────────────────────────────

function LevelEndScreen({ level, levelScore, totalScore, pointsPerCorrect, onContinue, onFinish }: {
  level: number; levelScore: number; totalScore: number; pointsPerCorrect: number
  onContinue: () => void; onFinish: () => void
}) {
  return (
    <div className="fixed inset-0 z-40 flex flex-col items-center justify-center px-6"
      style={{ background: 'linear-gradient(160deg, #1A1C4E 0%, #2C2D81 50%, #3766B0 100%)' }}>
      <Image src="/chars-correct.png" alt="" width={220} height={220} className="mb-2" priority />
      <div className="bg-white rounded-3xl shadow-2xl max-w-sm w-full p-8 text-center">
        <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full text-sm font-bold mb-6"
          style={{ background: '#EEF0FF', color: '#2C2D81' }}>
          ✅ Nivo {level} završen!
        </div>
        <div className="flex gap-4 mb-6">
          <div className="flex-1 rounded-2xl p-4" style={{ background: levelScore >= 0 ? '#E8F8F0' : '#FEF2F2' }}>
            <div className="text-3xl font-black" style={{ color: levelScore >= 0 ? '#5DBF94' : '#e05252' }}>
              {levelScore > 0 ? '+' : ''}{levelScore}
            </div>
            <div className="text-xs text-gray-400 mt-1">Ovaj nivo</div>
          </div>
          <div className="flex-1 rounded-2xl p-4" style={{ background: '#EEF0FF' }}>
            <div className="text-3xl font-black" style={{ color: '#2C2D81' }}>{totalScore}</div>
            <div className="text-xs text-gray-400 mt-1">Ukupno</div>
          </div>
        </div>
        <div className="flex gap-3 text-xs text-gray-400 justify-center mb-6">
          <span className="flex items-center gap-1">
            <span className="w-4 h-4 rounded-full flex items-center justify-center text-white text-xs" style={{ background: '#5DBF94' }}>✓</span>
            +{pointsPerCorrect} bod
          </span>
          <span className="text-gray-300">·</span>
          <span className="flex items-center gap-1">
            <span className="w-4 h-4 rounded-full flex items-center justify-center text-white text-xs" style={{ background: '#e05252' }}>✗</span>
            -{WRONG_PENALTY} bod
          </span>
        </div>
        <div className="flex gap-3">
          <button onClick={onFinish} className="flex-1 py-3 rounded-xl border-2 border-gray-200 font-semibold text-gray-600 hover:bg-gray-50 text-sm">
            Završi igru
          </button>
          <button onClick={onContinue} className="flex-1 py-3 rounded-xl font-bold text-white text-sm"
            style={{ background: 'linear-gradient(135deg, #5DBF94, #45a87c)' }}>
            Nivo {level + 1} →
          </button>
        </div>
      </div>
    </div>
  )
}

// ── Main component ─────────────────────────────────────────────────────────

export default function IgrajPage() {
  const params = useParams()
  const router = useRouter()
  const supabase = createClient()
  const quizId = params.id as string

  const [quiz, setQuiz] = useState<Quiz | null>(null)
  const [questions, setQuestions] = useState<Question[]>([])
  const [loading, setLoading] = useState(true)

  const [current, setCurrent] = useState(0)
  const [selected, setSelected] = useState<number | null>(null)
  const [revealed, setRevealed] = useState(false)
  const [timePerQ, setTimePerQ] = useState(15)
  const [timeLeft, setTimeLeft] = useState(15)

  const [totalScore, setTotalScore] = useState(0)
  const [levelScore, setLevelScore] = useState(0)
  const [levelsCompleted, setLevelsCompleted] = useState(0)
  const [allAnswers, setAllAnswers] = useState<(number | null)[]>([])
  const [scoreChange, setScoreChange] = useState<{ delta: number; id: number } | null>(null)

  const [showLevelEnd, setShowLevelEnd] = useState(false)
  const [showResetConfirm, setShowResetConfirm] = useState(false)
  const [showFinishConfirm, setShowFinishConfirm] = useState(false)

  // Question reporting
  const [reportedIds, setReportedIds] = useState<Set<string>>(new Set())

  const savingRef = useRef(false)

  useEffect(() => {
    async function load() {
      const [{ data: q }, { data: qs }] = await Promise.all([
        supabase.from('quizzes').select('*').eq('id', quizId).single(),
        supabase.from('questions').select('*').eq('quiz_id', quizId),
      ])
      const shuffled = (qs || []).sort(() => Math.random() - 0.5)
      const tpq = getTimePerQuestion(q?.difficulty)
      setQuiz(q)
      setQuestions(shuffled)
      setTimePerQ(tpq)
      setTimeLeft(tpq)
      setLoading(false)
    }
    load()
  }, [quizId])

  const currentLevel = Math.floor(current / QUESTIONS_PER_LEVEL) + 1
  const questionInLevel = current % QUESTIONS_PER_LEVEL
  const pointsPerCorrect = getPointsPerCorrect(quiz?.difficulty)
  const diffMeta = getDifficultyMeta(quiz?.difficulty)

  async function handleReport(questionId: string) {
    if (reportedIds.has(questionId)) return
    const { data: { user } } = await supabase.auth.getUser()
    await supabase.from('question_reports').insert({
      question_id: questionId,
      quiz_id: quizId,
      reported_by: user?.id ?? null,
    })
    setReportedIds(prev => new Set(prev).add(questionId))
  }

  async function saveAndNavigate(finalScore: number, finalLevel: number, finalAnswers: (number | null)[]) {
    if (savingRef.current) return
    savingRef.current = true
    const { data: { user } } = await supabase.auth.getUser()
    if (user && finalLevel >= 1) {
      const correctCount = finalAnswers.filter((a, i) => a === questions[i]?.correct_answer).length
      await supabase.from('quiz_results').insert({
        user_id: user.id, quiz_id: quizId,
        score: correctCount, total: finalAnswers.length,
        time_taken: null, score_points: finalScore, level_reached: finalLevel,
      })
      supabase.from('quizzes').update({ plays: (quiz?.plays || 0) + 1 }).eq('id', quizId)
    }
    sessionStorage.setItem(`quiz-result-${quizId}`, JSON.stringify({
      score: finalAnswers.filter((a, i) => a === questions[i]?.correct_answer).length,
      total: finalAnswers.length, scorePoints: finalScore, levelReached: finalLevel,
      questions: questions.slice(0, finalAnswers.length).map(q => ({
        question_text: q.question_text, options: q.options,
        correct_answer: q.correct_answer, explanation: q.explanation,
      })),
      answers: finalAnswers, timeTaken: 0,
    }))
    router.push(`/kvizovi/${quizId}/rezultati`)
  }

  const goNext = useCallback((forcedAnswer?: number | null) => {
    const ans = forcedAnswer !== undefined ? forcedAnswer : selected
    const q = questions[current]
    if (!q) return

    let delta = 0
    if (ans === q.correct_answer) delta = pointsPerCorrect
    else if (ans !== null) delta = -WRONG_PENALTY

    const newTotalScore = totalScore + delta
    const newLevelScore = levelScore + delta
    const newAnswers = [...allAnswers, ans ?? null]

    setTotalScore(newTotalScore)
    setLevelScore(newLevelScore)
    setAllAnswers(newAnswers)
    if (delta !== 0) {
      setScoreChange({ delta, id: Date.now() })
      setTimeout(() => setScoreChange(null), 900)
    }

    if (questionInLevel === QUESTIONS_PER_LEVEL - 1) {
      const newLevels = levelsCompleted + 1
      setLevelsCompleted(newLevels)
      setTimeout(() => { setLevelScore(newLevelScore); setShowLevelEnd(true) }, 50)
      return
    }

    setCurrent(c => c + 1)
    setSelected(null)
    setRevealed(false)
    setTimeLeft(timePerQ)
  }, [selected, questions, current, totalScore, levelScore, allAnswers, questionInLevel, levelsCompleted, pointsPerCorrect, timePerQ])

  useEffect(() => {
    if (loading || revealed || showLevelEnd) return
    if (timeLeft <= 0) { goNext(null); return }
    const t = setTimeout(() => setTimeLeft(l => l - 1), 1000)
    return () => clearTimeout(t)
  }, [timeLeft, loading, revealed, showLevelEnd, goNext])

  function handleSelect(idx: number) {
    if (revealed) return
    setSelected(idx)
    setRevealed(true)
    // No auto-advance — user clicks "Nastavi" to proceed at their own pace
  }

  function handleContinueLevel() {
    setShowLevelEnd(false); setLevelScore(0)
    setCurrent(c => c + 1); setSelected(null)
    setRevealed(false); setTimeLeft(timePerQ)
  }
  function handleFinishFromLevel() { setShowLevelEnd(false); saveAndNavigate(totalScore, levelsCompleted, allAnswers) }
  function handleFinishConfirmed() { setShowFinishConfirm(false); saveAndNavigate(totalScore, levelsCompleted, allAnswers) }

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center"
        style={{ background: 'linear-gradient(135deg, #1A1C4E 0%, #2C2D81 100%)' }}>
        <div className="text-white text-center">
          <Image src="/chars-neutral.png" alt="" width={180} height={180} className="mx-auto mb-4 animate-bounce" />
          <p className="text-xl font-semibold">Učitavanje pitanja...</p>
        </div>
      </div>
    )
  }

  if (questions.length === 0) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-[#FAF4EC]">
        <p className="text-xl font-semibold text-gray-600">Ovaj kviz nema pitanja.</p>
      </div>
    )
  }

  const q = questions[current]
  const characterSrc = getCharacter(revealed, selected, q.correct_answer, timeLeft)
  const OPTION_LABELS = ['A', 'B', 'C', 'D']
  const isReported = reportedIds.has(q.id)

  return (
    <div className="min-h-screen flex flex-col relative overflow-hidden"
      style={{ background: 'linear-gradient(160deg, #1A1C4E 0%, #2C2D81 55%, #3766B0 100%)' }}>

      <div className="pointer-events-none fixed inset-0 z-0"
        style={{ background: 'radial-gradient(ellipse at 70% 10%, rgba(253,195,97,0.07) 0%, transparent 50%), radial-gradient(ellipse at 20% 90%, rgba(93,191,148,0.06) 0%, transparent 50%)' }} />

      {/* ── Top control bar ── */}
      <div className="sticky top-0 z-20 px-4 py-2.5 relative"
        style={{ background: 'rgba(26,28,78,0.88)', backdropFilter: 'blur(12px)', borderBottom: '1px solid rgba(253,195,97,0.15)' }}>
        <div className="max-w-2xl mx-auto flex items-center justify-between">
          <button onClick={() => setShowResetConfirm(true)}
            className="flex items-center gap-1.5 text-sm font-medium transition-all px-3 py-1.5 rounded-xl"
            style={{ color: 'rgba(255,255,255,0.6)', border: '1px solid rgba(255,255,255,0.12)' }}>
            ↩ <span className="hidden sm:inline">Resetuj</span>
          </button>

          <div className="flex items-center gap-3">
            <div className="text-center">
              <div className="text-xs font-semibold uppercase tracking-widest mb-0.5" style={{ color: 'rgba(255,255,255,0.45)' }}>Nivo</div>
              <div className="text-2xl font-black leading-none" style={{ color: '#FDC361' }}>{currentLevel}</div>
            </div>
            <div className="w-px h-8" style={{ background: 'rgba(255,255,255,0.12)' }} />
            <div className="text-center relative">
              <div className="text-xs font-semibold uppercase tracking-widest mb-0.5" style={{ color: 'rgba(255,255,255,0.45)' }}>Bodovi</div>
              <div className="text-2xl font-black leading-none text-white">{totalScore}</div>
              {scoreChange && (
                <span key={scoreChange.id} className="absolute -top-5 left-1/2 text-sm font-black"
                  style={{ color: scoreChange.delta > 0 ? '#5DBF94' : '#e05252', transform: 'translateX(-50%)', animation: 'floatUp 0.9s ease-out forwards' }}>
                  {scoreChange.delta > 0 ? `+${scoreChange.delta}` : scoreChange.delta}
                </span>
              )}
            </div>
          </div>

          <button onClick={() => setShowFinishConfirm(true)}
            className="flex items-center gap-1.5 text-sm font-medium transition-all px-3 py-1.5 rounded-xl"
            style={{ color: 'rgba(255,255,255,0.6)', border: '1px solid rgba(255,255,255,0.12)' }}>
            <span className="hidden sm:inline">Završi</span> ⏹
          </button>
        </div>
      </div>

      {/* ── Level progress dots ── */}
      <div className="px-4 pt-4 pb-2 max-w-2xl mx-auto w-full relative z-10">
        <div className="flex items-center justify-between mb-2">
          <span className="text-xs font-semibold" style={{ color: 'rgba(255,255,255,0.5)' }}>
            Pitanje {questionInLevel + 1} od {QUESTIONS_PER_LEVEL}
          </span>
          <span className="text-xs font-semibold" style={{ color: levelScore >= 0 ? '#5DBF94' : '#e05252' }}>
            {levelScore > 0 ? '+' : ''}{levelScore} ovaj nivo
          </span>
        </div>
        <div className="flex gap-1.5">
          {Array.from({ length: QUESTIONS_PER_LEVEL }).map((_, i) => (
            <div key={i} className="flex-1 h-1.5 rounded-full transition-all duration-300"
              style={{ background: i < questionInLevel ? '#5DBF94' : i === questionInLevel ? '#FDC361' : 'rgba(255,255,255,0.15)' }} />
          ))}
        </div>
      </div>

      {/* ── Question card ── */}
      <div className="flex-1 flex items-start justify-center px-4 pb-8 md:pb-32 pt-2 relative z-10">
        <div className="w-full max-w-2xl" key={current}>

          {/* Points at stake banner */}
          <div className="flex items-center justify-between mb-3 px-1">
            <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-xl text-xs font-bold"
              style={{ background: diffMeta.bg, color: diffMeta.textDark, border: `1.5px solid ${diffMeta.color}40` }}>
              <span className="w-2 h-2 rounded-full flex-shrink-0" style={{ background: diffMeta.color }} />
              {diffMeta.label}
            </div>
            <div className="flex items-center gap-2 text-xs font-semibold">
              <span className="flex items-center gap-1 px-2.5 py-1 rounded-lg"
                style={{ background: 'rgba(93,191,148,0.15)', color: '#5DBF94', border: '1px solid rgba(93,191,148,0.25)' }}>
                ✓ +{pointsPerCorrect}
              </span>
              <span className="flex items-center gap-1 px-2.5 py-1 rounded-lg"
                style={{ background: 'rgba(224,82,82,0.15)', color: '#e05252', border: '1px solid rgba(224,82,82,0.25)' }}>
                ✗ -{WRONG_PENALTY}
              </span>
            </div>
          </div>

          <div className="bg-white rounded-3xl shadow-2xl overflow-hidden"
            style={{ boxShadow: '0 25px 60px rgba(26,28,78,0.35)' }}>

            {/* Question header */}
            <div className="px-6 pt-6 pb-4"
              style={{ background: 'linear-gradient(135deg, #f8f9ff 0%, #ffffff 100%)', borderBottom: '1px solid #f0f0f8' }}>
              <div className="flex items-start justify-between gap-4">
                <h2 className="text-lg font-bold text-gray-800 leading-snug flex-1">{q.question_text}</h2>
                <div className="flex items-center gap-2 flex-shrink-0">
                  {/* Report button */}
                  <button onClick={() => handleReport(q.id)} title="Prijavi grešku u pitanju"
                    className="w-8 h-8 rounded-lg flex items-center justify-center transition-all mt-1"
                    style={{
                      background: isReported ? 'rgba(93,191,148,0.1)' : 'transparent',
                      color: isReported ? '#5DBF94' : 'rgba(156,163,175,0.5)',
                    }}>
                    {isReported ? (
                      <span className="text-xs font-bold">✓</span>
                    ) : (
                      <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
                        <path d="M2 2h9.5L9 6l2.5 4H2" /><line x1="2" y1="2" x2="2" y2="13" />
                      </svg>
                    )}
                  </button>
                  <CircularTimer timeLeft={timeLeft} total={timePerQ} />
                </div>
              </div>
            </div>

            {/* Answer options */}
            <div className="px-5 py-5 grid grid-cols-1 gap-2.5">
              {q.options.map((option: string, idx: number) => {
                const isCorrect = idx === q.correct_answer
                const isSelected = idx === selected
                let bg = 'white', borderColor = '#e5e7eb', textColor = '#374151'
                let labelBg = '#F5F6FA', labelColor = '#6b7280'
                let labelText: string = OPTION_LABELS[idx]
                let scale = ''
                if (revealed) {
                  if (isCorrect)       { bg = '#E8F8F0'; borderColor = '#5DBF94'; textColor = '#0A4C35'; labelBg = '#5DBF94'; labelColor = 'white'; labelText = '✓'; scale = 'scale-[1.01]' }
                  else if (isSelected) { bg = '#FEF2F2'; borderColor = '#e05252'; textColor = '#b91c1c'; labelBg = '#e05252'; labelColor = 'white'; labelText = '✗' }
                  else                 { bg = '#fafafa'; borderColor = '#f0f0f0'; textColor = '#c4c4c4'; labelBg = '#f0f0f0'; labelColor = '#c4c4c4' }
                }
                return (
                  <button key={idx} onClick={() => handleSelect(idx)} disabled={revealed}
                    className={`flex items-center gap-3 w-full px-4 py-3.5 rounded-2xl border-2 text-left transition-all duration-200 ${!revealed ? 'hover:border-[#2C2D81] hover:bg-[#f5f6ff] hover:scale-[1.01]' : scale} disabled:cursor-default`}
                    style={{ background: bg, borderColor, color: textColor }}>
                    <span className="w-8 h-8 rounded-xl flex-shrink-0 flex items-center justify-center text-sm font-bold transition-all duration-200"
                      style={{ background: labelBg, color: labelColor }}>
                      {labelText}
                    </span>
                    <span className="flex-1 text-sm font-medium">{option}</span>
                  </button>
                )
              })}
            </div>

            {/* Explanation */}
            {revealed && q.explanation && (
              <div className="mx-5 mb-4 rounded-2xl px-4 py-3 text-sm"
                style={{ background: '#EEF0FF', color: '#2C2D81', border: '1px solid #d4d8f8' }}>
                <span className="font-bold">💡 </span>{q.explanation}
              </div>
            )}

            {/* Nastavi button */}
            {revealed && !showLevelEnd && (
              <div className="px-5 pb-4">
                <button onClick={() => goNext()}
                  className="w-full py-3.5 rounded-2xl font-bold text-white text-base transition-all hover:scale-[1.01] active:scale-[0.99]"
                  style={{ background: 'linear-gradient(135deg, #5DBF94, #45a87c)' }}>
                  Nastavi →
                </button>
              </div>
            )}

            {/* Prijavi pitanje */}
            <div className="px-5 pb-5 text-center">
              {!isReported ? (
                <button onClick={() => handleReport(q.id)}
                  className="text-xs transition-colors"
                  style={{ color: 'rgba(156,163,175,0.6)' }}
                  onMouseEnter={e => (e.currentTarget.style.color = '#e05252')}
                  onMouseLeave={e => (e.currentTarget.style.color = 'rgba(156,163,175,0.6)')}>
                  🚩 Prijavi grešku u pitanju
                </button>
              ) : (
                <span className="text-xs font-medium" style={{ color: '#5DBF94' }}>✓ Prijava zabeležena — hvala!</span>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* ── Character — hidden on mobile ── */}
      <div className="fixed bottom-0 right-0 pointer-events-none transition-all duration-300 z-10 hidden md:block"
        style={{ width: revealed ? 190 : 130 }}>
        <Image key={characterSrc} src={characterSrc} alt="" width={190} height={190} className="w-full h-auto" priority />
      </div>

      {/* ── Overlays ── */}
      {showLevelEnd && (
        <LevelEndScreen level={levelsCompleted} levelScore={levelScore} totalScore={totalScore}
          pointsPerCorrect={pointsPerCorrect} onContinue={handleContinueLevel} onFinish={handleFinishFromLevel} />
      )}
      {showResetConfirm && (
        <ConfirmPopup title="Resetuj igru?" message="Vratiš se na početak kviza. Svi bodovi se gube."
          onConfirm={() => router.push(`/kvizovi/${quizId}`)} onCancel={() => setShowResetConfirm(false)} />
      )}
      {showFinishConfirm && (
        <ConfirmPopup
          title={levelsCompleted < 1 ? 'Previše rano!' : 'Završi igru?'}
          message={levelsCompleted < 1
            ? 'Moraš završiti bar jedan nivo (10 pitanja) da bi rezultat bio upisan u rang listu.'
            : `Završiš sa ukupno ${totalScore} bodova i ${levelsCompleted} ${levelsCompleted === 1 ? 'nivoem' : 'nivoa'}.`}
          confirmLabel={levelsCompleted < 1 ? 'Razumem' : 'Da, završi'}
          cancelLabel="Nastavi igru"
          onConfirm={levelsCompleted >= 1 ? handleFinishConfirmed : () => setShowFinishConfirm(false)}
          onCancel={() => setShowFinishConfirm(false)} />
      )}

      <style jsx global>{`
        @keyframes floatUp {
          0%   { opacity: 1; transform: translateX(-50%) translateY(0); }
          100% { opacity: 0; transform: translateX(-50%) translateY(-24px); }
        }
        @keyframes pop-in {
          0%   { transform: scale(0.7); opacity: 0; }
          70%  { transform: scale(1.05); }
          100% { transform: scale(1); opacity: 1; }
        }
        .animate-pop-in { animation: pop-in 0.35s ease both; }
      `}</style>
    </div>
  )
}
