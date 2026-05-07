'use client'

export const dynamic = 'force-dynamic'

import { useEffect, useState, useRef, useCallback } from 'react'
import { useParams, useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import Image from 'next/image'
import Link from 'next/link'
import { IconClose, IconCheck, IconWrong } from '@/components/icons'
import ReportQuestionButton from '@/components/ReportQuestionButton'

const TIME_PER_QUESTION = 15
const POINTS_CORRECT = 10
const POINTS_WRONG = 5
// Forfeit: when one player walks out mid-duel, the other gets a flat
// bonus on top of whatever score they already had.
const FORFEIT_BONUS = 50

type GameRoom = {
  id: string
  room_code: string
  host_id: string
  guest_id: string | null
  status: 'waiting' | 'playing' | 'finished'
  question_ids: string[]
  host_answers: (number | null)[]
  guest_answers: (number | null)[]
  host_score: number
  guest_score: number
  total_questions: number
  game_format: string
  game_start_time: string | null
  quiz_type: 'pro' | 'kafana'
}

type Question = {
  id: string
  question_text: string
  options: string[]
  correct_answer: number
  info: string | null
}

type DisplayQuestion = Question & {
  shuffled: string[]
  shuffleMap: number[]   // shuffled[i] = options[shuffleMap[i]]
  correctIdx: number     // index in shuffled where correct lives
}

// Shuffle answers — but use a deterministic seed based on question.id so both players see same order
function seededShuffle(q: Question): DisplayQuestion {
  const seed = q.id.split('').reduce((acc, c) => acc + c.charCodeAt(0), 0)
  const indices = [0, 1, 2, 3]
  // Fisher-Yates with seeded RNG
  let s = seed
  function rand() { s = (s * 1103515245 + 12345) & 0x7fffffff; return s / 0x7fffffff }
  for (let i = 3; i > 0; i--) {
    const j = Math.floor(rand() * (i + 1));
    [indices[i], indices[j]] = [indices[j], indices[i]]
  }
  const shuffled = indices.map(i => q.options[i])
  const correctIdx = indices.indexOf(q.correct_answer)
  return { ...q, shuffled, shuffleMap: indices, correctIdx }
}

function fmtTime(s: number): string {
  const m = Math.floor(s / 60)
  const sec = s % 60
  return `${String(m).padStart(2, '0')}:${String(sec).padStart(2, '0')}`
}

// ── Circular timer ────────────────────────────────────────────────────────
function Timer({ left, total }: { left: number; total: number }) {
  const r = 22
  const circ = 2 * Math.PI * r
  const progress = Math.max(0, left / total)
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

export default function DuelGamePage() {
  const params = useParams()
  const router = useRouter()
  const code = params.code as string

  const [room, setRoom] = useState<GameRoom | null>(null)
  const [questions, setQuestions] = useState<Question[]>([])
  const [profiles, setProfiles] = useState<Record<string, { name: string; avatar: string | null }>>({})
  const [myId, setMyId] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)

  // Per-question state
  const [current, setCurrent] = useState(0)            // index into question_ids
  const [revealed, setRevealed] = useState(false)
  const [timeLeft, setTimeLeft] = useState(TIME_PER_QUESTION)

  // Local copies (mirror DB but updated optimistically)
  const [myScore, setMyScore] = useState(0)
  const [opScore, setOpScore] = useState(0)
  const [myAnswers, setMyAnswers] = useState<(number | null)[]>([])
  const [opAnswers, setOpAnswers] = useState<(number | null)[]>([])

  // Tiebreaker
  const [goldenRound, setGoldenRound] = useState(0)    // 0 = main game, 1+ = golden questions
  const [duelEnded, setDuelEnded] = useState(false)

  // Result page navigation
  const [navigatingToEnd, setNavigatingToEnd] = useState(false)
  // Set when realtime tells us status flipped to 'finished' WITHOUT us
  // running endDuel ourselves — i.e. the other player exited mid-duel.
  const [opponentLeft, setOpponentLeft] = useState(false)

  const savedRef = useRef(false)
  const startTimeRef = useRef<number>(Date.now())

  const isHost = !!myId && !!room && myId === room.host_id
  const totalMain = room?.total_questions ?? 0
  const isGolden = current >= totalMain
  const goldenIdx = isGolden ? current - totalMain + 1 : 0

  // ── Load room & questions ────────────────────────────────────────────────
  useEffect(() => {
    async function load() {
      try {
        const supabase = createClient()
        const { data: { user } } = await supabase.auth.getUser()
        if (!user) { router.push('/auth/prijava'); return }
        setMyId(user.id)

        const { data: roomData } = await supabase
          .from('game_rooms').select('*').eq('room_code', code).single()
        if (!roomData) { router.push('/igraj-zajedno'); return }
        setRoom(roomData as GameRoom)

        // Pull from the right pool — Kafanski duels use kafana_questions,
        // everything else (PRO) uses the shared questions table.
        const poolTable = roomData.quiz_type === 'kafana' ? 'kafana_questions' : 'questions'
        const ids = roomData.question_ids as string[]
        const chunkSize = 50
        const all: Question[] = []
        for (let i = 0; i < ids.length; i += chunkSize) {
          const { data } = await supabase
            .from(poolTable).select('id, question_text, options, correct_answer, info')
            .in('id', ids.slice(i, i + chunkSize))
          if (data) all.push(...(data as Question[]))
        }
        const ordered = ids.map(id => all.find(q => q.id === id)).filter(Boolean) as Question[]
        setQuestions(ordered)

        const playerIds = [roomData.host_id, roomData.guest_id].filter(Boolean) as string[]
        if (playerIds.length > 0) {
          const { data: profData } = await supabase
            .from('profiles').select('id, first_name, nickname, avatar').in('id', playerIds)
          const map: Record<string, { name: string; avatar: string | null }> = {}
          ;(profData || []).forEach((p: { id: string; first_name: string; nickname: string; avatar: string }) => {
            map[p.id] = { name: p.nickname || p.first_name || 'Igrač', avatar: p.avatar || null }
          })
          setProfiles(map)
        }

        // Sync from DB
        setMyScore(roomData.host_id === user.id ? (roomData.host_score ?? 0) : (roomData.guest_score ?? 0))
        setOpScore(roomData.host_id === user.id ? (roomData.guest_score ?? 0) : (roomData.host_score ?? 0))
        setMyAnswers(roomData.host_id === user.id ? (roomData.host_answers ?? []) : (roomData.guest_answers ?? []))
        setOpAnswers(roomData.host_id === user.id ? (roomData.guest_answers ?? []) : (roomData.host_answers ?? []))
        // Resume to next unanswered question
        const myA = roomData.host_id === user.id ? (roomData.host_answers ?? []) : (roomData.guest_answers ?? [])
        setCurrent(myA.length)
        setTimeLeft(TIME_PER_QUESTION)
      } finally {
        setLoading(false)
      }
    }
    load()
  }, [code, router])

  // ── Realtime sync ─────────────────────────────────────────────────────────
  useEffect(() => {
    if (!room?.id || !myId) return
    const supabase = createClient()
    const channel = supabase.channel(`duel-${room.id}`)
      .on('postgres_changes', {
        event: 'UPDATE', schema: 'public', table: 'game_rooms', filter: `id=eq.${room.id}`,
      }, (payload) => {
        const u = payload.new as GameRoom
        setRoom(prev => ({ ...(prev as GameRoom), ...u }))
        const opAns = isHost ? (u.guest_answers ?? []) : (u.host_answers ?? [])
        const opSc = isHost ? (u.guest_score ?? 0) : (u.host_score ?? 0)
        setOpAnswers(opAns)
        setOpScore(opSc)
      })
      .subscribe()
    return () => { supabase.removeChannel(channel) }
  }, [room?.id, myId, isHost])

  // ── Per-question countdown ────────────────────────────────────────────────
  useEffect(() => {
    if (loading || revealed || duelEnded || navigatingToEnd) return
    if (!questions[current]) return
    if (timeLeft <= 0) {
      handleAnswer(null)
      return
    }
    const t = setTimeout(() => setTimeLeft(s => s - 1), 1000)
    return () => clearTimeout(t)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [timeLeft, revealed, loading, current, duelEnded, navigatingToEnd, questions])

  // ── Detect both answered or timeout — reveal & advance ────────────────────
  // Watch revealed: when both answers exist for current question OR timeout, show reveal
  // Sync from realtime: when both players have an answer for the current
  // question, flip into the reveal phase. Setting state in this effect is
  // legitimate — the input (myAnswers/opAnswers) comes from the realtime
  // channel, not from props/derived state.
  useEffect(() => {
    if (loading || revealed || duelEnded || !room || !questions[current]) return
    const myAnswered = myAnswers[current] !== undefined
    const opAnswered = opAnswers[current] !== undefined
    if (myAnswered && opAnswered) setRevealed(true) // eslint-disable-line react-hooks/set-state-in-effect
  }, [myAnswers, opAnswers, current, revealed, loading, duelEnded, room, questions])

  // ── After reveal: pause 3s then advance ───────────────────────────────────
  useEffect(() => {
    if (!revealed || duelEnded) return
    const t = setTimeout(() => advanceQuestion(), 3500)
    return () => clearTimeout(t)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [revealed, duelEnded])

  // ── Detect opponent-left ─────────────────────────────────────────────────
  // If realtime delivers status='finished' but we haven't called endDuel
  // ourselves (savedRef + duelEnded), the other player exited via the
  // confirm-modal Exit (which calls persistExit → status='finished'). Show
  // a banner, then auto-end so this side gets a /kraj page with their
  // current score instead of being stuck on "čekamo protivnika".
  useEffect(() => {
    if (!room || savedRef.current || duelEnded || opponentLeft) return
    if (room.status !== 'finished') return
    // Sync from realtime — partner exited externally, so we react.
    setOpponentLeft(true) // eslint-disable-line react-hooks/set-state-in-effect
    const t = setTimeout(() => endDuel(), 2200)
    return () => clearTimeout(t)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [room?.status, duelEnded, opponentLeft])

  // ── Answer ───────────────────────────────────────────────────────────────
  async function handleAnswer(shuffledIdx: number | null) {
    if (revealed || !questions[current] || !room || !myId) return
    if (myAnswers[current] !== undefined) return // already answered

    const q = seededShuffle(questions[current])
    const isCorrect = shuffledIdx !== null && shuffledIdx === q.correctIdx
    const delta = isCorrect ? POINTS_CORRECT : -POINTS_WRONG
    const newScore = Math.max(0, myScore + delta)
    const newAnswers = [...myAnswers]
    newAnswers[current] = shuffledIdx

    setMyScore(newScore)
    setMyAnswers(newAnswers)

    const supabase = createClient()
    const update = isHost
      ? { host_answers: newAnswers, host_score: newScore }
      : { guest_answers: newAnswers, guest_score: newScore }
    await supabase.from('game_rooms').update(update).eq('id', room.id)

    // Log to the right answer log so the 72h dedupe matches the pool
    // this duel actually drew from. PRO/Brzi/PRO duel share
    // question_answer_log; Kafanski duel uses kafana_answer_log.
    const pickedOriginalIdx = shuffledIdx == null
      ? null
      : (q.shuffleMap[shuffledIdx] ?? null)
    const logTable = room.quiz_type === 'kafana' ? 'kafana_answer_log' : 'question_answer_log'
    supabase.from(logTable).insert({
      question_id: q.id,
      user_id: myId,
      was_correct: isCorrect,
      picked_idx: pickedOriginalIdx,
      time_ms: 0,
    }).then(({ error }) => { if (error) console.error('duel answer log failed', error) })
  }

  // ── Advance to next question (or golden round, or end) ────────────────────
  function advanceQuestion() {
    if (!room || duelEnded) return

    const nextIdx = current + 1
    const finishedMain = nextIdx >= totalMain

    if (finishedMain) {
      // Check tie
      if (myScore === opScore && questions[nextIdx]) {
        // Continue with golden question
        setCurrent(nextIdx)
        setRevealed(false)
        setTimeLeft(TIME_PER_QUESTION)
        setGoldenRound(g => g + 1)
        return
      }
      // Resolve and end
      endDuel()
      return
    }

    setCurrent(nextIdx)
    setRevealed(false)
    setTimeLeft(TIME_PER_QUESTION)
  }

  async function endDuel() {
    if (savedRef.current || duelEnded) return
    savedRef.current = true
    setDuelEnded(true)

    let finalMyScore = myScore
    let finalOpScore = opScore

    if (room && myId) {
      const supabase = createClient()
      // Mark as finished, then read scores back fresh — the partner's
      // persistExit may have just stamped a +FORFEIT_BONUS on our row,
      // and our local myScore wouldn't see that without a refetch.
      await supabase.from('game_rooms').update({ status: 'finished' }).eq('id', room.id)
      const { data: fresh } = await supabase
        .from('game_rooms').select('host_score, guest_score').eq('id', room.id).single()
      if (fresh) {
        finalMyScore = isHost ? (fresh.host_score ?? 0) : (fresh.guest_score ?? 0)
        finalOpScore = isHost ? (fresh.guest_score ?? 0) : (fresh.host_score ?? 0)
      }
    }

    // Persist result for end screen
    const totalAnswered = myAnswers.length
    const myCorrect: number = myAnswers.reduce<number>((acc, ans, i) => {
      if (ans === null || ans === undefined || !questions[i]) return acc
      return acc + (ans === seededShuffle(questions[i]).correctIdx ? 1 : 0)
    }, 0)
    const opCorrect: number = opAnswers.reduce<number>((acc, ans, i) => {
      if (ans === null || ans === undefined || !questions[i]) return acc
      return acc + (ans === seededShuffle(questions[i]).correctIdx ? 1 : 0)
    }, 0)
    const totalTime = Math.floor((Date.now() - startTimeRef.current) / 1000)
    const opId = isHost ? room?.guest_id : room?.host_id

    sessionStorage.setItem(`duel-result-${code}`, JSON.stringify({
      myScore: finalMyScore, opScore: finalOpScore,
      myCorrect, opCorrect,
      myWrong: totalAnswered - myCorrect,
      opWrong: totalAnswered - opCorrect,
      totalAnswered,
      totalTime,
      totalQuestions: totalMain,
      goldenRounds: goldenRound,
      myId: myId || null,
      opId: opId || null,
      myName: myId ? profiles[myId]?.name : 'Ti',
      opName: opId ? profiles[opId]?.name : 'Protivnik',
      myAvatar: myId ? profiles[myId]?.avatar : null,
      opAvatar: opId ? profiles[opId]?.avatar : null,
      iWon: finalMyScore > finalOpScore,
      isDraw: finalMyScore === finalOpScore,
    }))

    setNavigatingToEnd(true)
    setTimeout(() => router.push(`/igraj-zajedno/${code}/kraj`), 1200)
  }

  // ── Confirm exit ──────────────────────────────────────────────────────────
  const [showExitConfirm, setShowExitConfirm] = useState(false)

  // Exit mid-duel: mark the room as finished so the current scores count on
  // the leaderboard. The exiter forfeits any remaining questions; the
  // partner gets a +FORFEIT_BONUS bump so abandoning a losing duel isn't
  // a free escape. Reads fresh state right before the write so we don't
  // race with the partner's last-second answer.
  const persistExit = useCallback(async () => {
    if (savedRef.current || !room?.id) return
    savedRef.current = true
    const supabase = createClient()
    const { data: fresh } = await supabase
      .from('game_rooms')
      .select('host_id, host_score, guest_score, status')
      .eq('id', room.id)
      .single()
    if (!fresh || fresh.status === 'finished') return  // partner already closed it
    const leaverIsHost = !!myId && myId === fresh.host_id
    const oppScore = leaverIsHost ? (fresh.guest_score ?? 0) : (fresh.host_score ?? 0)
    const update: Record<string, unknown> = { status: 'finished' }
    if (leaverIsHost) update.guest_score = oppScore + FORFEIT_BONUS
    else update.host_score = oppScore + FORFEIT_BONUS
    await supabase.from('game_rooms').update(update).eq('id', room.id)
  }, [room?.id, myId])

  useEffect(() => {
    if (duelEnded || !room?.id) return
    const roomId = room.id
    function flush() {
      if (savedRef.current) return
      savedRef.current = true
      try {
        const blob = new Blob([JSON.stringify({ room_id: roomId })], { type: 'application/json' })
        navigator.sendBeacon('/api/duel-finalize', blob)
      } catch { /* best effort */ }
    }
    function onVis() { if (document.visibilityState === 'hidden') flush() }
    window.addEventListener('pagehide', flush)
    document.addEventListener('visibilitychange', onVis)
    return () => {
      window.removeEventListener('pagehide', flush)
      document.removeEventListener('visibilitychange', onVis)
    }
  }, [duelEnded, room?.id])

  // ── Render ───────────────────────────────────────────────────────────────
  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center" style={{ background: '#FAFAFA' }}>
        <div className="w-8 h-8 rounded-full border-2 animate-spin"
          style={{ borderColor: '#609DED', borderTopColor: 'transparent' }} />
      </div>
    )
  }

  // Guest waiting for host start
  if (room?.status === 'waiting') {
    const amGuest = myId === room.guest_id
    return (
      <div className="min-h-screen flex items-center justify-center px-4" style={{ background: '#FAFAFA' }}>
        <div className="card-soft p-9 max-w-sm text-center">
          <div className="text-5xl mb-5">⏳</div>
          {amGuest ? (
            <>
              <h2 className="font-black text-[22px] mb-2 tracking-tight" style={{ color: '#343434' }}>Ušao/la si u sobu!</h2>
              <p className="text-[14px] mb-2" style={{ color: '#9C9C9C' }}>Čekamo da domaćin počne duel…</p>
            </>
          ) : (
            <>
              <h2 className="font-black text-[22px] mb-2 tracking-tight" style={{ color: '#343434' }}>Čekamo protivnika…</h2>
              <div className="font-black py-5 px-7 rounded-2xl my-4 inline-block"
                style={{ background: '#BCD9FF', color: '#343434', letterSpacing: '0.25em', fontSize: 'clamp(28px, 5vw, 40px)' }}>
                {code}
              </div>
            </>
          )}
        </div>
      </div>
    )
  }

  if (!questions[current]) return null

  const q = seededShuffle(questions[current])
  const myAns = myAnswers[current]
  const opAns = opAnswers[current]
  const opAnswered = opAns !== undefined && opAns !== null || (revealed && opAns === null)
  const myAnswered = myAns !== undefined

  const opId = isHost ? room?.guest_id : room?.host_id
  const myProf = myId ? profiles[myId] : null
  const opProf = opId ? profiles[opId] : null

  return (
    <div className="min-h-screen flex flex-col" style={{ background: '#FAFAFA' }}>

      {/* HUD */}
      <header className="sticky top-0 z-30 backdrop-blur-xl"
        style={{ background: 'rgba(252,252,252,0.92)', borderBottom: '1px solid rgba(52,52,52,0.06)' }}>
        <div className="max-w-3xl mx-auto px-4 sm:px-6 py-2.5 flex items-center justify-between gap-3">
          <button onClick={() => setShowExitConfirm(true)}
            className="w-9 h-9 rounded-full flex items-center justify-center transition-colors hover:bg-[#F2F2F2]"
            style={{ color: '#9C9C9C' }} aria-label="Izađi">
            <IconClose size={18} strokeWidth={2.2} />
          </button>

          <div className="flex items-center gap-3 sm:gap-5 flex-1 justify-center">
            <PlayerScore userId={myId || ''} name={myProf?.name || 'Ti'} avatar={myProf?.avatar} score={myScore} accent="#609DED" you />
            <div className="text-center">
              {isGolden ? (
                <>
                  <div className="text-[10px] font-bold uppercase tracking-widest" style={{ color: '#FFCB46' }}>Zlatno</div>
                  <div className="font-black text-[16px]" style={{ color: '#FFCB46' }}>{goldenIdx}</div>
                </>
              ) : (
                <>
                  <div className="text-[10px] font-bold uppercase tracking-widest" style={{ color: '#9C9C9C' }}>Pitanje</div>
                  <div className="font-black text-[16px]" style={{ color: '#343434' }}>{current + 1}/{totalMain}</div>
                </>
              )}
            </div>
            <PlayerScore userId={opId || ''} name={opProf?.name || 'Protivnik'} avatar={opProf?.avatar} score={opScore} accent="#FFCB46" />
          </div>

          <Timer left={Math.max(0, timeLeft)} total={TIME_PER_QUESTION} />
        </div>
      </header>

      {/* Game body */}
      <main className="flex-1 px-4 sm:px-6 py-5">
        <div className="max-w-2xl mx-auto" key={q.id}>

          {isGolden && (
            <div className="rounded-2xl px-4 py-3 mb-4 text-center font-bold text-[13px]"
              style={{ background: '#FFCB46', color: '#343434' }}>
              ⚡ Zlatno pitanje — odlučuje pobednika
            </div>
          )}

          <div className="card-soft p-6 sm:p-8 mb-4">
            <div className="flex items-start justify-between gap-3 mb-3">
              <h2 className="font-bold tracking-tight leading-snug flex-1"
                style={{ color: '#343434', fontSize: 'clamp(18px, 3vw, 22px)' }}>
                {q.question_text}
              </h2>
              <ReportQuestionButton
                source={room?.quiz_type === 'kafana' ? 'kafana_questions' : 'questions'}
                questionId={q.id}
                questionText={q.question_text} />
            </div>
            <div className="mb-4" />

            <div className="space-y-2.5">
              {q.shuffled.map((opt, i) => {
                const isCorrect = i === q.correctIdx
                const myPicked = i === myAns
                const opPicked = revealed && i === opAns
                let bg = '#FCFCFC', border = 'rgba(52,52,52,0.10)', fg = '#343434'
                let labelBg = '#F2F2F2', labelFg = '#9C9C9C'

                if (revealed) {
                  if (isCorrect) { bg = '#E8F8F0'; border = '#4CAF50'; fg = '#15803d'; labelBg = '#4CAF50'; labelFg = 'white' }
                  else if (myPicked || opPicked) { bg = '#FEE2E2'; border = '#E55353'; fg = '#b91c1c'; labelBg = '#E55353'; labelFg = 'white' }
                  else { bg = '#F2F2F2'; border = 'transparent'; fg = '#9C9C9C' }
                } else if (myAnswered) {
                  if (myPicked) { bg = '#BCD9FF'; border = '#609DED'; fg = '#1e5fa4'; labelBg = '#609DED'; labelFg = 'white' }
                  else { bg = '#F2F2F2'; border = 'transparent'; fg = '#9C9C9C' }
                }

                return (
                  <button key={i} onClick={() => handleAnswer(i)}
                    disabled={myAnswered || revealed}
                    className="w-full flex items-center gap-3 px-4 py-3.5 rounded-2xl text-left transition-all disabled:cursor-default relative"
                    style={{ background: bg, border: `1.5px solid ${border}`, color: fg }}>
                    <span className="w-8 h-8 rounded-xl flex items-center justify-center text-[13px] font-black flex-shrink-0"
                      style={{ background: labelBg, color: labelFg }}>
                      {revealed && isCorrect ? <IconCheck size={14} className="text-white" />
                        : revealed && (myPicked || opPicked) ? <IconWrong size={14} className="text-white" />
                        : ['A', 'B', 'C', 'D'][i]}
                    </span>
                    <span className="flex-1 text-[14px] sm:text-[15px] font-medium">{opt}</span>
                    {/* Player markers when revealed */}
                    {revealed && (myPicked || opPicked) && (
                      <div className="flex items-center gap-1.5 flex-shrink-0">
                        {myPicked && (
                          <span className="text-[10px] font-bold px-2 py-0.5 rounded-full"
                            style={{ background: '#609DED', color: 'white' }}>
                            Ti
                          </span>
                        )}
                        {opPicked && (
                          <span className="text-[10px] font-bold px-2 py-0.5 rounded-full"
                            style={{ background: '#FFCB46', color: '#343434' }}>
                            Protivnik
                          </span>
                        )}
                      </div>
                    )}
                  </button>
                )
              })}
            </div>

            {/* Status / info */}
            {!revealed && myAnswered && (
              <div className="mt-5 rounded-2xl px-4 py-3 text-[13px] font-medium text-center" style={{ background: '#F2F2F2', color: '#9C9C9C' }}>
                {opAnswered ? 'Otkrivamo odgovor…' : 'Odgovorio/la si — čekamo protivnika…'}
              </div>
            )}
            {revealed && q.info && (
              <div className="mt-5 rounded-2xl px-4 py-3 text-[13px] font-medium" style={{ background: '#BCD9FF', color: '#1e5fa4' }}>
                {q.info}
              </div>
            )}
            {revealed && !q.info && (
              <div className="mt-5 grid grid-cols-2 gap-2 text-[12px]">
                <div className="rounded-2xl px-3 py-2 text-center" style={{ background: '#F2F2F2' }}>
                  <span className="font-bold" style={{ color: '#609DED' }}>Ti:</span>{' '}
                  {myAns === null ? <span style={{ color: '#9c7a13' }}>Vreme isteklo</span>
                    : myAns === q.correctIdx ? <span style={{ color: '#15803d' }}>tačno +10</span>
                    : <span style={{ color: '#b91c1c' }}>pogrešno -5</span>}
                </div>
                <div className="rounded-2xl px-3 py-2 text-center" style={{ background: '#F2F2F2' }}>
                  <span className="font-bold" style={{ color: '#FFCB46' }}>Protivnik:</span>{' '}
                  {opAns === null ? <span style={{ color: '#9c7a13' }}>Vreme isteklo</span>
                    : opAns === q.correctIdx ? <span style={{ color: '#15803d' }}>tačno +10</span>
                    : <span style={{ color: '#b91c1c' }}>pogrešno -5</span>}
                </div>
              </div>
            )}
          </div>
        </div>
      </main>

      {/* End overlay */}
      {navigatingToEnd && (
        <div className="fixed inset-0 z-50 flex items-center justify-center px-4 backdrop-blur-sm"
          style={{ background: 'rgba(52,52,52,0.40)' }}>
          <div className="card-soft p-8 text-center max-w-sm w-full animate-pop-in">
            <div className="text-5xl mb-4">🏁</div>
            <h3 className="font-black text-[22px] tracking-tight mb-2" style={{ color: '#343434' }}>Kraj duela</h3>
            <p className="text-[13px]" style={{ color: '#9C9C9C' }}>Računamo rezultat…</p>
          </div>
        </div>
      )}

      {/* Opponent-left overlay — covers the in-game UI so the player isn't
          stuck on "Čekamo protivnika..." after the partner exited. Auto-
          ends to /kraj after 2.2s so the score still gets recorded. */}
      {opponentLeft && !navigatingToEnd && (
        <div className="fixed inset-0 z-50 flex items-center justify-center px-4 backdrop-blur-sm"
          style={{ background: 'rgba(52,52,52,0.40)' }}>
          <div className="card-soft p-8 text-center max-w-sm w-full animate-pop-in">
            <div className="text-5xl mb-4">🚪</div>
            <h3 className="font-black text-[22px] tracking-tight mb-2" style={{ color: '#343434' }}>
              {opProf?.name?.split(' ')[0] || 'Protivnik'} je napustio kviz
            </h3>
            <p className="text-[13px]" style={{ color: '#9C9C9C' }}>
              Tvoj rezultat se upisuje na rang listu.
            </p>
          </div>
        </div>
      )}

      {/* Exit confirm */}
      {showExitConfirm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center px-4 backdrop-blur-sm"
          style={{ background: 'rgba(52,52,52,0.40)' }}>
          <div className="card-soft p-7 text-center max-w-sm w-full">
            <h3 className="font-black text-[20px] tracking-tight mb-2" style={{ color: '#343434' }}>Izađi iz duela?</h3>
            <p className="text-[13px] mb-6" style={{ color: '#9C9C9C' }}>Trenutni rezultat se upisuje na rang listu — predaješ duel.</p>
            <div className="flex gap-3">
              <button onClick={() => setShowExitConfirm(false)} className="btn btn-secondary btn-md flex-1">
                Nastavi
              </button>
              <button
                onClick={async () => { await persistExit(); router.push('/igraj-zajedno') }}
                className="btn btn-md flex-1"
                style={{ background: '#E55353', color: 'white' }}>
                Izađi
              </button>
            </div>
          </div>
        </div>
      )}

      <div className="px-4 pb-4 text-center text-[11px]" style={{ color: '#9C9C9C' }}>
        ukupno: {fmtTime(Math.floor((Date.now() - startTimeRef.current) / 1000))}
      </div>
    </div>
  )
}

function PlayerScore({ userId, name, avatar, score, accent, you }: {
  userId: string; name: string; avatar: string | null | undefined; score: number; accent: string; you?: boolean
}) {
  const inner = (
    <>
      <div className="w-9 h-9 rounded-2xl overflow-hidden flex-shrink-0" style={{ background: '#F2F2F2', border: `2px solid ${accent}` }}>
        {avatar
          ? <Image src={`/avatars/${avatar}`} alt={name} width={36} height={36} className="w-full h-full object-cover" />
          : <div className="w-full h-full flex items-center justify-center text-[12px] font-bold" style={{ background: accent, color: 'white' }}>{name[0]}</div>}
      </div>
      <div className="min-w-0">
        <div className="text-[10px] font-bold uppercase tracking-wider truncate" style={{ color: '#9C9C9C' }}>
          {you ? 'Ti' : name.split(' ')[0]}
        </div>
        <div className="font-black text-[18px] tracking-tight" style={{ color: accent }}>{score}</div>
      </div>
    </>
  )
  const cls = "flex items-center gap-2 min-w-0 transition-opacity hover:opacity-80"
  return userId
    ? <Link href={you ? '/profil' : `/profil/${userId}`} className={cls}>{inner}</Link>
    : <div className={cls}>{inner}</div>
}
