'use client'

import { useEffect, useState } from 'react'
import { useParams, useRouter } from 'next/navigation'
import Link from 'next/link'
import Image from 'next/image'
import { IconShare, IconCheck, IconWrong, IconTime } from '@/components/icons'

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
  const heroMsg = scorePoints <= 0 ? 'Probaj ponovo — možeš bolje'
    : levelReached >= 3 ? 'Sjajan napredak!' : 'Dobro urađeno'

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
    const text = `Postigao/la sam ${scorePoints} bodova i dostigao/la Nivo ${levelReached} na Librum Kvizu!`
    if (typeof navigator.share === 'function') {
      try { setSharing(true); await navigator.share({ title: 'Librum Kviz', text, url: shareUrl }) }
      catch { /* user cancelled */ }
      finally { setSharing(false) }
    } else {
      await navigator.clipboard.writeText(shareUrl)
      setCopied(true)
      setTimeout(() => setCopied(false), 2500)
    }
  }

  return (
    <div className="min-h-screen py-10 sm:py-14 px-4 sm:px-6" style={{ background: '#FAFAFA' }}>
      <div className="max-w-2xl mx-auto">

        {/* Hero */}
        <div className="card-soft overflow-hidden mb-4">
          <div className="flex items-end justify-center pt-6 px-6"
            style={{ background: 'linear-gradient(135deg, #BCD9FF 0%, #FFECBC 100%)', minHeight: 200 }}>
            <Image src={heroImg} alt="Rezultat" width={240} height={180} className="object-contain"
              style={{ maxHeight: 200 }} priority />
          </div>

          <div className="p-7 sm:p-8 text-center">
            <p className="text-[13px] mb-2" style={{ color: '#9C9C9C' }}>{heroMsg}</p>
            <div className="font-black tracking-tight" style={{ color: '#343434', fontSize: 'clamp(48px, 9vw, 72px)', lineHeight: 1 }}>
              {scorePoints > 0 ? `+${scorePoints}` : scorePoints}
            </div>
            <div className="text-[14px] font-semibold mb-7 mt-1" style={{ color: '#609DED' }}>bodova</div>

            <div className="flex justify-center gap-6 sm:gap-8 mb-6">
              {[
                { value: levelReached, label: levelReached === 1 ? 'Nivo' : 'Nivoa' },
                { value: `${score}/${total}`, label: 'Tačno' },
                { value: `${pct}%`, label: 'Preciznost' },
              ].map(({ value, label }, i) => (
                <div key={i} className="text-center">
                  <div className="font-black text-[22px] tracking-tight" style={{ color: '#343434' }}>{value}</div>
                  <div className="text-[11px] mt-0.5" style={{ color: '#9C9C9C' }}>{label}</div>
                </div>
              ))}
            </div>

            {levelReached < 1 && (
              <div className="rounded-2xl px-4 py-3 text-[13px] font-medium mb-5" style={{ background: '#FFECBC', color: '#9c7a13' }}>
                Nisi završio/la ni jedan nivo — rezultat nije upisan u rang listu.
              </div>
            )}

            <div className="flex gap-3 mb-3">
              <Link href={`/kvizovi/${quizId}/igraj`} className="btn btn-primary btn-md flex-1">
                Igraj ponovo
              </Link>
              <Link href="/kvizovi" className="btn btn-secondary btn-md flex-1">
                Svi kvizovi
              </Link>
            </div>

            <button onClick={handleShare} disabled={sharing}
              className="btn btn-md w-full"
              style={copied
                ? { background: '#E8F8F0', color: '#15803d' }
                : { background: '#BCD9FF', color: '#1e5fa4' }}>
              <IconShare size={16} strokeWidth={2.2} />
              {copied ? 'Link kopiran' : sharing ? '…' : 'Podeli rezultat'}
            </button>
          </div>
        </div>

        {/* Per-level breakdown */}
        {levels.length > 0 && (
          <div className="space-y-3">
            <h2 className="font-bold text-[16px] px-1 tracking-tight" style={{ color: '#343434' }}>
              Pregled odgovora
            </h2>
            {levels.map((levelQuestions, lvlIdx) => {
              const correct = levelQuestions.filter(({ q, answer }) => answer === q.correct_answer).length
              const total = levelQuestions.length
              const isOpen = !!openLevels[lvlIdx]

              return (
                <div key={lvlIdx} className="card-soft overflow-hidden">
                  <button onClick={() => toggleLevel(lvlIdx)}
                    className="w-full flex items-center justify-between px-5 py-4 hover:bg-[#F2F2F2] transition-colors">
                    <div className="flex items-center gap-3">
                      <div className="w-9 h-9 rounded-2xl flex items-center justify-center font-black text-[14px]"
                        style={{ background: '#609DED', color: 'white' }}>
                        {lvlIdx + 1}
                      </div>
                      <div className="text-left">
                        <div className="font-bold text-[14px] tracking-tight" style={{ color: '#343434' }}>Nivo {lvlIdx + 1}</div>
                        <div className="text-[12px]" style={{ color: '#9C9C9C' }}>{correct}/{total} tačnih</div>
                      </div>
                    </div>
                    <div className="flex items-center gap-3">
                      <div className="flex gap-0.5 h-2 w-20 rounded-full overflow-hidden">
                        {levelQuestions.map(({ q, answer }, i) => (
                          <div key={i} className="flex-1 rounded-full"
                            style={{ background: answer === q.correct_answer ? '#4CAF50' : answer === null ? '#FFCB46' : '#E55353' }} />
                        ))}
                      </div>
                      <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="#9C9C9C" strokeWidth="2" strokeLinecap="round"
                        style={{ transform: isOpen ? 'rotate(180deg)' : '', transition: 'transform 0.2s' }}>
                        <polyline points="4,6 8,10 12,6" />
                      </svg>
                    </div>
                  </button>

                  {isOpen && (
                    <div className="px-5 pb-4 space-y-2.5 border-t" style={{ borderColor: '#F2F2F2' }}>
                      <div className="pt-3" />
                      {levelQuestions.map(({ q, answer, index }) => {
                        const isCorrect = answer === q.correct_answer
                        const timedOut = answer === null
                        const bg = isCorrect ? '#E8F8F0' : timedOut ? '#FFECBC' : '#FEE2E2'
                        const border = isCorrect ? '#4CAF50' : timedOut ? '#FFCB46' : '#E55353'
                        return (
                          <div key={index} className="rounded-2xl p-4" style={{ background: bg, border: `1.5px solid ${border}` }}>
                            <div className="flex gap-2 items-start mb-2">
                              {isCorrect ? <IconCheck size={18} className="text-[#4CAF50] flex-shrink-0 mt-0.5" />
                                : timedOut ? <IconTime size={18} className="text-[#9c7a13] flex-shrink-0 mt-0.5" strokeWidth={2.2} />
                                : <IconWrong size={18} className="text-[#E55353] flex-shrink-0 mt-0.5" />}
                              <p className="font-semibold text-[13px]" style={{ color: '#343434' }}>
                                <span className="text-[11px] mr-1.5" style={{ color: '#9C9C9C' }}>Q{(index % 10) + 1}</span>
                                {q.question_text}
                              </p>
                            </div>
                            <div className="ml-7 space-y-1 text-[13px]">
                              {!isCorrect && !timedOut && (
                                <p style={{ color: '#b91c1c' }}>Tvoj odgovor: <span className="font-semibold">{q.options[answer!]}</span></p>
                              )}
                              {timedOut && <p style={{ color: '#9c7a13' }} className="font-semibold">Isteklo vreme</p>}
                              <p style={{ color: '#15803d' }} className="font-semibold">Tačan: {q.options[q.correct_answer]}</p>
                              {q.explanation && <p style={{ color: '#9C9C9C' }} className="mt-1">{q.explanation}</p>}
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
