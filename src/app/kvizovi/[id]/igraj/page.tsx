'use client'

import { useEffect, useState, useCallback } from 'react'
import { useParams, useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import type { Question, Quiz } from '@/types/database'

const TIME_PER_QUESTION = 30

export default function IgrajPage() {
  const params = useParams()
  const router = useRouter()
  const supabase = createClient()
  const quizId = params.id as string

  const [quiz, setQuiz] = useState<Quiz | null>(null)
  const [questions, setQuestions] = useState<Question[]>([])
  const [current, setCurrent] = useState(0)
  const [selected, setSelected] = useState<number | null>(null)
  const [revealed, setRevealed] = useState(false)
  const [answers, setAnswers] = useState<(number | null)[]>([])
  const [timeLeft, setTimeLeft] = useState(TIME_PER_QUESTION)
  const [totalTime, setTotalTime] = useState(0)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function load() {
      const [{ data: q }, { data: qs }] = await Promise.all([
        supabase.from('quizzes').select('*').eq('id', quizId).single(),
        supabase.from('questions').select('*').eq('quiz_id', quizId).order('order_num'),
      ])
      setQuiz(q)
      setQuestions(qs || [])
      setAnswers(new Array((qs || []).length).fill(null))
      setLoading(false)
    }
    load()
  }, [quizId])

  const goNext = useCallback(
    (forcedAnswer?: number | null) => {
      const ans = forcedAnswer !== undefined ? forcedAnswer : selected
      const newAnswers = [...answers]
      newAnswers[current] = ans ?? null
      setAnswers(newAnswers)

      if (current + 1 >= questions.length) {
        const score = newAnswers.filter((a, i) => a === questions[i]?.correct_answer).length
        supabase.auth.getUser().then(({ data: { user } }) => {
          if (user) {
            supabase.from('quiz_results').insert({
              user_id: user.id,
              quiz_id: quizId,
              score,
              total: questions.length,
              time_taken: totalTime + (TIME_PER_QUESTION - timeLeft),
            }).then(() => {
              supabase.from('quizzes').update({ plays: (quiz?.plays || 0) + 1 }).eq('id', quizId)
            })
          }
        })
        sessionStorage.setItem(`quiz-result-${quizId}`, JSON.stringify({
          answers: newAnswers,
          questions,
          score,
          total: questions.length,
          timeTaken: totalTime + (TIME_PER_QUESTION - timeLeft),
        }))
        router.push(`/kvizovi/${quizId}/rezultati`)
        return
      }

      setTotalTime(t => t + (TIME_PER_QUESTION - timeLeft))
      setCurrent(c => c + 1)
      setSelected(null)
      setRevealed(false)
      setTimeLeft(TIME_PER_QUESTION)
    },
    [answers, current, questions, selected, timeLeft, totalTime, quiz, quizId, router, supabase]
  )

  useEffect(() => {
    if (loading || revealed) return
    if (timeLeft <= 0) {
      setRevealed(true)
      setTimeout(() => goNext(null), 1500)
      return
    }
    const t = setTimeout(() => setTimeLeft(l => l - 1), 1000)
    return () => clearTimeout(t)
  }, [timeLeft, loading, revealed, goNext])

  function handleSelect(idx: number) {
    if (revealed) return
    setSelected(idx)
    setRevealed(true)
    setTimeout(() => goNext(idx), 1200)
  }

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center" style={{ background: 'linear-gradient(135deg, #2C2D81 0%, #3766B0 100%)' }}>
        <div className="text-white text-center">
          <div className="text-5xl mb-4 animate-bounce">📚</div>
          <p className="text-xl font-semibold">Učitavanje pitanja...</p>
        </div>
      </div>
    )
  }

  if (questions.length === 0) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-[#F5F6FA]">
        <div className="text-center">
          <div className="text-5xl mb-4">😅</div>
          <p className="text-xl font-semibold text-gray-600">Ovaj kviz nema pitanja.</p>
        </div>
      </div>
    )
  }

  const q = questions[current]
  const progress = ((current) / questions.length) * 100
  const timerColor = timeLeft > 15 ? '#5DBF94' : timeLeft > 7 ? '#FDC361' : '#e05252'

  const OPTION_LABELS = ['A', 'B', 'C', 'D']

  return (
    <div className="min-h-screen flex flex-col" style={{ background: 'linear-gradient(160deg, #2C2D81 0%, #3766B0 60%, #F5F6FA 100%)' }}>
      {/* Header */}
      <div className="px-4 pt-6 pb-4 max-w-2xl mx-auto w-full">
        <div className="flex items-center justify-between mb-3">
          <span className="text-white/70 text-sm font-medium">{quiz?.title}</span>
          <span className="text-white font-bold text-sm">{current + 1} / {questions.length}</span>
        </div>
        {/* Progress bar */}
        <div className="h-2 bg-white/20 rounded-full overflow-hidden">
          <div
            className="h-full rounded-full transition-all duration-500"
            style={{ width: `${progress}%`, background: '#5DBF94' }}
          />
        </div>
      </div>

      {/* Main card */}
      <div className="flex-1 flex items-start justify-center px-4 pb-8">
        <div className="w-full max-w-2xl animate-pop-in" key={current}>
          <div className="bg-white rounded-3xl shadow-2xl overflow-hidden">
            {/* Timer + question */}
            <div className="p-6 pb-4">
              <div className="flex items-center justify-between mb-5">
                <span className="text-xs font-semibold uppercase tracking-wide text-gray-400">
                  Pitanje {current + 1}
                </span>
                <div
                  className="flex items-center gap-1.5 px-3 py-1.5 rounded-full text-sm font-bold transition-colors"
                  style={{ background: `${timerColor}20`, color: timerColor }}
                >
                  <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
                    <circle cx="7" cy="7" r="6" stroke="currentColor" strokeWidth="1.5" />
                    <path d="M7 4v3l2 2" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
                  </svg>
                  {timeLeft}s
                </div>
              </div>

              <h2 className="text-xl font-bold text-gray-800 leading-snug mb-2">
                {q.question_text}
              </h2>
            </div>

            {/* Options */}
            <div className="px-6 pb-6 grid grid-cols-1 gap-3">
              {q.options.map((option: string, idx: number) => {
                const isCorrect = idx === q.correct_answer
                const isSelected = idx === selected

                let style: React.CSSProperties = { borderColor: '#e5e7eb', background: 'white', color: '#374151' }
                if (revealed) {
                  if (isCorrect) style = { borderColor: '#5DBF94', background: '#E8F8F0', color: '#0A4C35' }
                  else if (isSelected) style = { borderColor: '#e05252', background: '#FEF2F2', color: '#b91c1c' }
                  else style = { borderColor: '#e5e7eb', background: '#fafafa', color: '#9ca3af' }
                }

                return (
                  <button
                    key={idx}
                    onClick={() => handleSelect(idx)}
                    disabled={revealed}
                    className="flex items-center gap-3 w-full px-4 py-3.5 rounded-2xl border-2 text-left transition-all hover:scale-[1.01] disabled:cursor-default font-medium"
                    style={style}
                  >
                    <span
                      className="w-8 h-8 rounded-xl flex-shrink-0 flex items-center justify-center text-sm font-bold"
                      style={{ background: revealed && isCorrect ? '#5DBF94' : revealed && isSelected ? '#e05252' : '#F5F6FA', color: revealed && (isCorrect || isSelected) ? 'white' : '#6b7280' }}
                    >
                      {revealed && isCorrect ? '✓' : revealed && isSelected && !isCorrect ? '✗' : OPTION_LABELS[idx]}
                    </span>
                    <span className="flex-1 text-sm">{option}</span>
                  </button>
                )
              })}
            </div>

            {/* Explanation */}
            {revealed && q.explanation && (
              <div className="mx-6 mb-6 bg-[#EEF0FF] rounded-xl px-4 py-3 text-sm text-[#2C2D81]">
                <span className="font-semibold">💡 Objašnjenje: </span>{q.explanation}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
