'use client'

import { useEffect, useState } from 'react'
import { useParams, useRouter } from 'next/navigation'
import Link from 'next/link'
import Image from 'next/image'

type Q = { question_text: string; options: string[]; correct_answer: number; explanation: string | null }
type ResultData = {
  answers: (number | null)[]
  questions: Q[]
  score: number
  total: number
  timeTaken: number
  scorePoints: number
  levelReached: number
}

export default function RezultatiPage() {
  const params = useParams()
  const router = useRouter()
  const quizId = params.id as string
  const [result, setResult] = useState<ResultData | null>(null)
  const [openLevels, setOpenLevels] = useState<Record<number, boolean>>({ 0: true })
  const [copied, setCopied] = useState(false)
  const [sharing, setSharing] = useState(false)

  useEffect(() => {
    const stored = sessionStorage.getItem(`quiz-result-${quizId}`)
    if (stored) setResult(JSON.parse(stored))
    else router.push(`/kvizovi/${quizId}`)
  }, [quizId, router])

  if (!result) return null

  const { scorePoints, levelReached, score, total, answers, questions } = result
  const pct = total > 0 ? Math.round((score / total) * 100) : 0
  const isWinner = scorePoints >= 0 && levelReached >= 1 && pct >= 50
  const heroImg = isWinner ? '/chars-winner.png' : '/chars-loser.png'
  const heroMsg = scorePoints <= 0 ? 'Probajte ponovo — možete bolje!'
    : levelReached >= 3 ? 'Sjajan napredak!' : 'Dobro urađeno!'
  const heroColor = isWinner ? '#5DBF94' : '#FDC361'

  // Group questions by level (10 per level)
  const levels: { q: Q; answer: number | null; index: number }[][] = []
  questions.forEach((q, i) => {
    const lvl = Math.floor(i / 10)
    if (!levels[lvl]) levels[lvl] = []
    levels[lvl].push({ q, answer: answers[i], index: i })
  })

  function toggleLevel(lvl: number) {
    setOpenLevels(prev => ({ ...prev, [lvl]: !prev[lvl] }))
  }

  async function handleShare() {
    const shareUrl = `${window.location.origin}/kvizovi/${quizId}/share?score=${scorePoints}&level=${levelReached}`
    const text = `Postigao/la sam ${scorePoints} bodova i dostigao/la Nivo ${levelReached} na Librum Kvizt! 📚`
    if (typeof navigator.share === 'function') {
      try {
        setSharing(true)
        await navigator.share({ title: 'Librum Kviz', text, url: shareUrl })
      } catch { /* user cancelled */ }
      finally { setSharing(false) }
    } else {
      await navigator.clipboard.writeText(shareUrl)
      setCopied(true)
      setTimeout(() => setCopied(false), 2500)
    }
  }

  return (
    <div className="min-h-screen bg-[#FAF4EC] py-10 px-4">
      <div className="max-w-2xl mx-auto">

        {/* ── Result hero ── */}
        <div className="bg-white rounded-3xl shadow-sm overflow-hidden mb-4">
          <div className="flex items-end justify-center pt-4 px-6"
            style={{ background: 'linear-gradient(160deg, #1A1C4E 0%, #2C2D81 50%, #3766B0 100%)', minHeight: 180 }}>
            <Image src={heroImg} alt="Rezultat" width={240} height={180} className="object-contain"
              style={{ maxHeight: 180 }} priority />
          </div>

          <div className="p-8 text-center">
            <p className="text-gray-400 text-sm mb-1">{heroMsg}</p>
            <div className="text-6xl font-black mb-1" style={{ color: '#2C2D81' }}>
              {scorePoints > 0 ? `+${scorePoints}` : scorePoints}
            </div>
            <div className="text-lg font-semibold mb-6" style={{ color: heroColor }}>bodova</div>

            <div className="flex justify-center gap-6 text-sm text-gray-500 mb-6">
              <div className="text-center">
                <div className="text-2xl font-bold text-gray-800">{levelReached}</div>
                <div className="text-xs">{levelReached === 1 ? 'Nivo' : 'Nivoa'}</div>
              </div>
              <div className="w-px bg-gray-100" />
              <div className="text-center">
                <div className="text-2xl font-bold text-gray-800">{score}</div>
                <div className="text-xs">Tačno od {total}</div>
              </div>
              <div className="w-px bg-gray-100" />
              <div className="text-center">
                <div className="text-2xl font-bold text-gray-800">{pct}%</div>
                <div className="text-xs">Preciznost</div>
              </div>
            </div>

            {levelReached < 1 && (
              <div className="bg-amber-50 border border-amber-200 rounded-xl px-4 py-3 text-sm text-amber-700 mb-5">
                ⚠️ Nisi završio/la ni jedan nivo — rezultat nije upisan u rang listu.
              </div>
            )}

            <div className="flex gap-3 mb-3">
              <Link href={`/kvizovi/${quizId}/igraj`}
                className="flex-1 py-3.5 rounded-xl font-bold text-white text-center hover:scale-[1.02] transition-all"
                style={{ background: 'linear-gradient(135deg, #5DBF94, #45a87c)' }}>
                Igraj ponovo
              </Link>
              <Link href="/kvizovi"
                className="flex-1 py-3.5 rounded-xl font-bold border-2 border-gray-200 text-gray-600 text-center hover:bg-gray-50 transition-all">
                Svi kvizovi
              </Link>
            </div>

            {/* Share button */}
            <button onClick={handleShare} disabled={sharing}
              className="w-full py-3 rounded-xl font-semibold text-sm transition-all hover:scale-[1.01] flex items-center justify-center gap-2"
              style={{ background: copied ? '#E8F8F0' : '#EEF0FF', color: copied ? '#0A4C35' : '#2C2D81', border: `1.5px solid ${copied ? '#5DBF94' : '#c7cbf0'}` }}>
              {copied ? '✓ Link kopiran!' : sharing ? '...' : (
                <>
                  <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                    <circle cx="12" cy="3" r="1.5" /><circle cx="12" cy="13" r="1.5" /><circle cx="3" cy="8" r="1.5" />
                    <line x1="4.4" y1="7.2" x2="10.6" y2="4.3" /><line x1="4.4" y1="8.8" x2="10.6" y2="11.7" />
                  </svg>
                  Podeli rezultat
                </>
              )}
            </button>
          </div>
        </div>

        {/* ── Question breakdown by level ── */}
        {levels.length > 0 && (
          <div className="space-y-3">
            <h2 className="font-bold text-lg px-1" style={{ color: '#2C2D81' }}>Pregled odgovora</h2>
            {levels.map((levelQuestions, lvlIdx) => {
              const correct = levelQuestions.filter(({ q, answer }) => answer === q.correct_answer).length
              const total = levelQuestions.length
              const isOpen = !!openLevels[lvlIdx]

              return (
                <div key={lvlIdx} className="bg-white rounded-2xl shadow-sm overflow-hidden">
                  <button
                    onClick={() => toggleLevel(lvlIdx)}
                    className="w-full flex items-center justify-between px-5 py-4 hover:bg-gray-50 transition-colors"
                  >
                    <div className="flex items-center gap-3">
                      <div className="w-9 h-9 rounded-xl flex items-center justify-center font-black text-white text-sm"
                        style={{ background: 'linear-gradient(135deg, #2C2D81, #3766B0)' }}>
                        {lvlIdx + 1}
                      </div>
                      <div className="text-left">
                        <div className="font-bold text-gray-800 text-sm">Nivo {lvlIdx + 1}</div>
                        <div className="text-xs text-gray-400">{correct}/{total} tačnih</div>
                      </div>
                    </div>
                    <div className="flex items-center gap-3">
                      {/* Correct/wrong mini bar */}
                      <div className="flex gap-0.5 h-2 w-20 rounded-full overflow-hidden">
                        {levelQuestions.map(({ q, answer }, i) => (
                          <div key={i} className="flex-1 rounded-full"
                            style={{ background: answer === q.correct_answer ? '#5DBF94' : answer === null ? '#FDC361' : '#e05252' }} />
                        ))}
                      </div>
                      <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="#9ca3af" strokeWidth="2" strokeLinecap="round"
                        style={{ transform: isOpen ? 'rotate(180deg)' : '', transition: 'transform 0.2s' }}>
                        <polyline points="4,6 8,10 12,6" />
                      </svg>
                    </div>
                  </button>

                  {isOpen && (
                    <div className="px-5 pb-4 space-y-2.5 border-t border-gray-50">
                      <div className="pt-3" />
                      {levelQuestions.map(({ q, answer, index }) => {
                        const correct = answer === q.correct_answer
                        const timedOut = answer === null
                        return (
                          <div key={index}
                            className={`rounded-xl p-4 border-2 ${correct ? 'border-[#5DBF94] bg-[#E8F8F0]' : timedOut ? 'border-amber-200 bg-amber-50' : 'border-red-200 bg-red-50'}`}>
                            <div className="flex gap-2 items-start mb-2">
                              <span className="text-base flex-shrink-0">{correct ? '✅' : timedOut ? '⏱️' : '❌'}</span>
                              <p className="font-medium text-sm text-gray-800">
                                <span className="text-gray-400 text-xs mr-1.5">Q{(index % 10) + 1}</span>
                                {q.question_text}
                              </p>
                            </div>
                            <div className="ml-7 space-y-1 text-sm">
                              {!correct && !timedOut && (
                                <p className="text-red-600">Vaš odgovor: <span className="font-medium">{q.options[answer!]}</span></p>
                              )}
                              {timedOut && <p className="text-amber-600 font-medium">Isteklo vreme</p>}
                              <p className="text-[#0A4C35] font-medium">Tačan: {q.options[q.correct_answer]}</p>
                              {q.explanation && <p className="text-gray-500 mt-1">💡 {q.explanation}</p>}
                            </div>
                          </div>
                        )
                      })}
                    </div>
                  )}
                </div>
              )
            })}
          </div>
        )}
      </div>
    </div>
  )
}
