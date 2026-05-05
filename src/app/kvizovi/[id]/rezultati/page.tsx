'use client'

import { useEffect, useState } from 'react'
import { useParams, useRouter } from 'next/navigation'
import Link from 'next/link'

type ResultData = {
  answers: (number | null)[]
  questions: Array<{ question_text: string; options: string[]; correct_answer: number; explanation: string | null }>
  score: number
  total: number
  timeTaken: number
}

function getEmoji(pct: number) {
  if (pct === 100) return { emoji: '🏆', msg: 'Savršen rezultat! Bravo!', color: '#FDC361' }
  if (pct >= 80) return { emoji: '🎉', msg: 'Odličan rezultat!', color: '#5DBF94' }
  if (pct >= 60) return { emoji: '👍', msg: 'Dobro urađeno!', color: '#3766B0' }
  if (pct >= 40) return { emoji: '📚', msg: 'Ima prostora za napredak.', color: '#FDC361' }
  return { emoji: '💪', msg: 'Probajte ponovo!', color: '#e05252' }
}

export default function RezultatiPage() {
  const params = useParams()
  const router = useRouter()
  const quizId = params.id as string
  const [result, setResult] = useState<ResultData | null>(null)

  useEffect(() => {
    const stored = sessionStorage.getItem(`quiz-result-${quizId}`)
    if (stored) {
      setResult(JSON.parse(stored))
    } else {
      router.push(`/kvizovi/${quizId}`)
    }
  }, [quizId, router])

  if (!result) return null

  const pct = Math.round((result.score / result.total) * 100)
  const { emoji, msg, color } = getEmoji(pct)
  const mins = Math.floor(result.timeTaken / 60)
  const secs = result.timeTaken % 60

  return (
    <div className="min-h-screen bg-[#F5F6FA] py-10 px-4">
      <div className="max-w-2xl mx-auto">
        {/* Result hero */}
        <div className="bg-white rounded-3xl shadow-sm p-8 text-center mb-6 animate-pop-in">
          <div className="text-6xl mb-4">{emoji}</div>
          <h1 className="text-3xl font-bold mb-1" style={{ color }}>
            {result.score}/{result.total}
          </h1>
          <div className="text-5xl font-black mb-2" style={{ color: '#2C2D81' }}>{pct}%</div>
          <p className="text-gray-500 mb-6">{msg}</p>

          {/* Score circle */}
          <div className="flex justify-center mb-6">
            <div className="relative w-32 h-32">
              <svg className="w-full h-full -rotate-90" viewBox="0 0 36 36">
                <circle cx="18" cy="18" r="15.9" fill="none" stroke="#e5e7eb" strokeWidth="3" />
                <circle
                  cx="18" cy="18" r="15.9" fill="none"
                  stroke={color} strokeWidth="3"
                  strokeDasharray={`${pct} 100`}
                  strokeLinecap="round"
                  className="transition-all duration-1000"
                />
              </svg>
              <div className="absolute inset-0 flex items-center justify-center">
                <span className="text-2xl font-bold" style={{ color: '#2C2D81' }}>{pct}%</span>
              </div>
            </div>
          </div>

          <div className="flex justify-center gap-8 text-sm text-gray-500 mb-8">
            <div className="text-center">
              <div className="font-bold text-lg text-gray-700">{result.score}</div>
              <div>Tačno</div>
            </div>
            <div className="text-center">
              <div className="font-bold text-lg text-gray-700">{result.total - result.score}</div>
              <div>Netačno</div>
            </div>
            <div className="text-center">
              <div className="font-bold text-lg text-gray-700">
                {mins > 0 ? `${mins}m ` : ''}{secs}s
              </div>
              <div>Vreme</div>
            </div>
          </div>

          <div className="flex gap-3">
            <Link
              href={`/kvizovi/${quizId}/igraj`}
              className="flex-1 py-3.5 rounded-xl font-bold text-white text-center transition-all hover:scale-[1.02]"
              style={{ background: 'linear-gradient(135deg, #5DBF94, #45a87c)' }}
            >
              Igraj ponovo
            </Link>
            <Link
              href="/kvizovi"
              className="flex-1 py-3.5 rounded-xl font-bold border-2 border-gray-200 text-gray-600 text-center transition-all hover:bg-gray-50"
            >
              Svi kvizovi
            </Link>
          </div>
        </div>

        {/* Question breakdown */}
        <div className="bg-white rounded-2xl shadow-sm p-6 animate-fade-in">
          <h2 className="font-bold text-lg mb-4" style={{ color: '#2C2D81' }}>Pregled odgovora</h2>
          <div className="space-y-4">
            {result.questions.map((q, i) => {
              const userAns = result.answers[i]
              const correct = userAns === q.correct_answer
              const timedOut = userAns === null

              return (
                <div key={i} className={`rounded-xl p-4 border-2 ${correct ? 'border-[#5DBF94] bg-[#E8F8F0]' : 'border-red-200 bg-red-50'}`}>
                  <div className="flex gap-2 items-start mb-2">
                    <span className="text-lg flex-shrink-0">{correct ? '✅' : '❌'}</span>
                    <p className="font-medium text-sm text-gray-800">{q.question_text}</p>
                  </div>
                  <div className="ml-7 space-y-1 text-sm">
                    {!correct && !timedOut && (
                      <p className="text-red-600">
                        Vaš odgovor: <span className="font-medium">{q.options[userAns!]}</span>
                      </p>
                    )}
                    {timedOut && <p className="text-orange-500 font-medium">⏱️ Isteklo vreme</p>}
                    <p className="text-[#0A4C35] font-medium">
                      Tačan odgovor: {q.options[q.correct_answer]}
                    </p>
                    {q.explanation && (
                      <p className="text-gray-500 mt-1">💡 {q.explanation}</p>
                    )}
                  </div>
                </div>
              )
            })}
          </div>
        </div>
      </div>
    </div>
  )
}
