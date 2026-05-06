'use client'

export const dynamic = 'force-dynamic'

import { useEffect, useState, useCallback, useRef } from 'react'
import { useParams, useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import type { Question } from '@/types/database'
import Image from 'next/image'

const QUESTIONS_PER_LEVEL = 10
const WRONG_PENALTY = 5
const OPTION_LABELS = ['A', 'B', 'C', 'D']

type GameRoom = {
  id: string; room_code: string; quiz_id: string
  host_id: string; guest_id: string | null
  status: 'waiting' | 'playing' | 'finished'
  question_ids: string[]
  host_answers: (number | null)[]; guest_answers: (number | null)[]
  host_score: number; guest_score: number
  host_finished: boolean; guest_finished: boolean
  host_level_scores: number[]; guest_level_scores: number[]
  total_questions: number
  game_format: string; target_wins: number | null; time_limit_seconds: number | null
  game_start_time: string | null
}

function getPointsPerCorrect(difficulty: string | undefined): number {
  if (difficulty === 'lako') return 5
  if (difficulty === 'srednje') return 10
  return 25
}

function formatLabel(fmt: string): string {
  const map: Record<string, string> = {
    best_of_3: '3 pobede', best_of_5: '5 pobeda', best_of_11: '11 pobeda',
    time_5: '5 minuta', time_15: '15 minuta', time_30: '30 minuta',
  }
  return map[fmt] ?? fmt
}

function ConfirmPopup({ title, message, onConfirm, onCancel }: {
  title: string; message: string; onConfirm: () => void; onCancel: () => void
}) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm px-6">
      <div className="bg-white rounded-3xl shadow-2xl max-w-sm w-full p-8 text-center">
        <div className="text-4xl mb-3">❓</div>
        <h3 className="text-xl font-bold text-gray-800 mb-2">{title}</h3>
        <p className="text-gray-500 text-sm mb-8">{message}</p>
        <div className="flex gap-3">
          <button onClick={onCancel}
            className="flex-1 py-3 rounded-xl border-2 border-gray-200 font-semibold text-gray-600">Ne</button>
          <button onClick={onConfirm}
            className="flex-1 py-3 rounded-xl font-semibold text-white"
            style={{ background: '#609DED' }}>Da</button>
        </div>
      </div>
    </div>
  )
}

// Side panel shown during active play on large screens
function PlayerCard({ name, score, wins, color, label }: {
  name: string; score: number; wins: number; color: string; label: string
}) {
  return (
    <div style={{
      width: 148,
      background: 'rgba(255,255,255,0.07)',
      backdropFilter: 'blur(12px)',
      border: `1.5px solid ${color}40`,
      borderRadius: 20,
      padding: '18px 12px',
      textAlign: 'center',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      gap: 2,
    }}>
      <div style={{ fontSize: 26, marginBottom: 4 }}>{label === 'Ti' ? '👤' : '⚔️'}</div>
      <div style={{
        color: color, fontWeight: 800, fontSize: 12, letterSpacing: 1,
        textTransform: 'uppercase', marginBottom: 4,
      }}>{label}</div>
      <div style={{
        color: 'rgba(255,255,255,0.92)', fontWeight: 700, fontSize: 13,
        overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
        maxWidth: '100%', marginBottom: 10,
      }}>{name}</div>
      <div style={{ color, fontSize: 42, fontWeight: 900, lineHeight: 1 }}>{score}</div>
      <div style={{ fontSize: 11, color: 'rgba(255,255,255,0.45)', marginBottom: 10 }}>bodova</div>
      <div style={{
        width: '100%', background: 'rgba(255,255,255,0.07)',
        borderRadius: 10, padding: '8px 4px',
      }}>
        <div style={{ fontSize: 20, fontWeight: 800, color: 'rgba(255,255,255,0.85)' }}>{wins}</div>
        <div style={{ fontSize: 10, color: 'rgba(255,255,255,0.4)', marginTop: 1 }}>duet pobeda</div>
      </div>
    </div>
  )
}

export default function MultiplayerGamePage() {
  const params = useParams()
  const router = useRouter()
  const code = params.code as string

  const [room, setRoom] = useState<GameRoom | null>(null)
  const [questions, setQuestions] = useState<Question[]>([])
  const [quizDifficulty, setQuizDifficulty] = useState<string>('srednje')
  const [myId, setMyId] = useState<string | null>(null)
  const [profiles, setProfiles] = useState<Record<string, string>>({})
  const [myDuetWins, setMyDuetWins] = useState(0)
  const [opDuetWins, setOpDuetWins] = useState(0)
  const [loading, setLoading] = useState(true)

  // Game state
  const [current, setCurrent] = useState(0)
  const [selected, setSelected] = useState<number | null>(null)
  const [revealed, setRevealed] = useState(false)
  const [myAnswers, setMyAnswers] = useState<(number | null)[]>([])
  const [totalScore, setTotalScore] = useState(0)
  const [levelScore, setLevelScore] = useState(0)
  const [myLevelScores, setMyLevelScores] = useState<number[]>([])
  const [finished, setFinished] = useState(false)
  const [showLevelEnd, setShowLevelEnd] = useState(false)
  const [showResetConfirm, setShowResetConfirm] = useState(false)
  const [showFinishConfirm, setShowFinishConfirm] = useState(false)

  const [timeRemaining, setTimeRemaining] = useState<number | null>(null)
  const savingRef = useRef(false)

  const isHost = myId && room ? myId === room.host_id : false
  // After finish, use DB as authoritative source — local state may be stale on refresh
  const isFinishedView = room?.status === 'finished'
  const myDbLvlScores: number[] = isHost ? (room?.host_level_scores ?? []) : (room?.guest_level_scores ?? [])
  const myDbScore: number = isHost ? (room?.host_score ?? 0) : (room?.guest_score ?? 0)
  const myLvlScores = isFinishedView ? myDbLvlScores : myLevelScores
  const myFinalScore = isFinishedView ? myDbScore : totalScore
  const opponentLvlScores: number[] = isHost ? (room?.guest_level_scores ?? []) : (room?.host_level_scores ?? [])
  const opponentScore: number = isHost ? (room?.guest_score ?? 0) : (room?.host_score ?? 0)
  const opponentFinished = isHost ? room?.guest_finished : room?.host_finished
  const opponentName = (() => {
    if (!room) return 'Protivnik'
    const opId = isHost ? room.guest_id : room.host_id
    return opId ? (profiles[opId] ?? 'Igrač') : 'Čeka se...'
  })()
  const myName = myId ? (profiles[myId] ?? 'Ti') : 'Ti'

  const myWins = myLvlScores.filter((s, i) => s > (opponentLvlScores[i] ?? -Infinity)).length
  const opponentWins = opponentLvlScores.filter((s, i) => s > (myLvlScores[i] ?? -Infinity)).length
  const targetWins = room?.target_wins ?? 5
  const isTimed = room?.game_format?.startsWith('time_') ?? false

  const currentLevel = Math.floor(current / QUESTIONS_PER_LEVEL) + 1
  const questionInLevel = current % QUESTIONS_PER_LEVEL
  const pointsPerCorrect = getPointsPerCorrect(quizDifficulty)

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

        if (roomData.quiz_id) {
          const { data: quizData } = await supabase
            .from('quizzes').select('difficulty').eq('id', roomData.quiz_id).single()
          if (quizData) setQuizDifficulty(quizData.difficulty)
        }

        // Fetch questions in chunks to avoid URL length limits
        const qIds = roomData.question_ids as string[]
        const chunkSize = 50
        const allQData: Question[] = []
        for (let i = 0; i < qIds.length; i += chunkSize) {
          const { data: chunk } = await supabase
            .from('questions').select('*').in('id', qIds.slice(i, i + chunkSize))
          if (chunk) allQData.push(...(chunk as Question[]))
        }
        const ordered = qIds
          .map(id => allQData.find((q: Question) => q.id === id))
          .filter(Boolean) as Question[]
        setQuestions(ordered)

        const playerIds = [roomData.host_id, roomData.guest_id].filter(Boolean) as string[]
        if (playerIds.length > 0) {
          const { data: profData } = await supabase
            .from('profiles').select('id, first_name').in('id', playerIds)
          const map: Record<string, string> = {}
          ;(profData || []).forEach((p: { id: string; first_name: string }) => { map[p.id] = p.first_name })
          setProfiles(map)

          // Fetch duet wins with simple per-player queries (avoids OR+IN filter issues)
          const opId = roomData.host_id === user.id ? roomData.guest_id : roomData.host_id
          const [mh, mg, oh, og] = await Promise.all([
            supabase.from('game_rooms').select('host_score, guest_score').eq('status', 'finished').eq('host_id', user.id).limit(200),
            supabase.from('game_rooms').select('host_score, guest_score').eq('status', 'finished').eq('guest_id', user.id).limit(200),
            opId ? supabase.from('game_rooms').select('host_score, guest_score').eq('status', 'finished').eq('host_id', opId).limit(200) : Promise.resolve({ data: [] }),
            opId ? supabase.from('game_rooms').select('host_score, guest_score').eq('status', 'finished').eq('guest_id', opId).limit(200) : Promise.resolve({ data: [] }),
          ])
          const myW = [
            ...((mh.data || []) as {host_score:number;guest_score:number}[]).filter(g => g.host_score > g.guest_score),
            ...((mg.data || []) as {host_score:number;guest_score:number}[]).filter(g => g.guest_score > g.host_score),
          ].length
          const opW = [
            ...((oh.data || []) as {host_score:number;guest_score:number}[]).filter(g => g.host_score > g.guest_score),
            ...((og.data || []) as {host_score:number;guest_score:number}[]).filter(g => g.guest_score > g.host_score),
          ].length
          setMyDuetWins(myW)
          setOpDuetWins(opW)
        }

        // Initialize timer if time-based and already started
        if (roomData.time_limit_seconds && roomData.game_start_time) {
          const elapsed = Math.floor((Date.now() - new Date(roomData.game_start_time).getTime()) / 1000)
          const remaining = Math.max(0, roomData.time_limit_seconds - elapsed)
          setTimeRemaining(remaining)
        }
      } finally {
        setLoading(false)
      }
    }
    load()
  }, [code, router])

  // Real-time subscription — profiles deliberately excluded from deps to keep channel stable
  const profilesRef = useRef(profiles)
  useEffect(() => { profilesRef.current = profiles }, [profiles])

  useEffect(() => {
    if (!room?.id) return
    const supabase = createClient()
    const channel = supabase.channel(`game-${room.id}`)
      .on('postgres_changes', {
        event: 'UPDATE', schema: 'public', table: 'game_rooms', filter: `id=eq.${room.id}`,
      }, (payload) => {
        const updated = payload.new as GameRoom

        // When game finishes, re-fetch authoritative data from DB
        if (updated.status === 'finished') {
          supabase.from('game_rooms').select('*').eq('id', updated.id).single().then(({ data }) => {
            if (data) setRoom(data as GameRoom)
          })
          return
        }

        setRoom(prev => ({ ...prev, ...updated }))

        // Guest was waiting for host to start — initialize timer now
        if (updated.status === 'playing' && updated.game_start_time && updated.time_limit_seconds) {
          const elapsed = Math.floor((Date.now() - new Date(updated.game_start_time).getTime()) / 1000)
          const remaining = Math.max(0, updated.time_limit_seconds - elapsed)
          setTimeRemaining(remaining)
        }

        if (updated.guest_id && !profilesRef.current[updated.guest_id]) {
          supabase.from('profiles').select('id, first_name').eq('id', updated.guest_id).single().then(({ data }) => {
            if (data) setProfiles(p => ({ ...p, [data.id]: data.first_name }))
          })
        }
        if (updated.host_finished && updated.guest_finished) {
          supabase.from('game_rooms').update({ status: 'finished' }).eq('id', updated.id)
        }
        if (updated.status === 'waiting') router.push('/igraj-zajedno')
      })
      .subscribe()
    return () => { supabase.removeChannel(channel) }
  }, [room?.id, router])

  // Countdown timer for time-based games
  useEffect(() => {
    if (!isTimed || timeRemaining === null || finished) return
    if (timeRemaining <= 0) {
      handleForceFinish()
      return
    }
    const t = setTimeout(() => setTimeRemaining(s => (s ?? 1) - 1), 1000)
    return () => clearTimeout(t)
  }, [timeRemaining, isTimed, finished])

  function handleForceFinish() {
    if (savingRef.current) return
    setFinished(true)
    submitFinished(totalScore, myLevelScores, myAnswers)
  }

  async function submitFinished(score: number, levelScores: number[], answers: (number | null)[]) {
    if (!room?.id || !myId || savingRef.current) return
    savingRef.current = true
    const supabase = createClient()
    const update = isHost
      ? { host_score: score, host_level_scores: levelScores, host_answers: answers, host_finished: true }
      : { guest_score: score, guest_level_scores: levelScores, guest_answers: answers, guest_finished: true }
    await supabase.from('game_rooms').update(update).eq('id', room.id)

    // After saving own result, check if opponent already finished.
    // The realtime handler also does this, but if the opponent left the page,
    // nobody else will trigger the status update — so we do it ourselves here.
    const { data: latest } = await supabase
      .from('game_rooms').select('host_finished, guest_finished').eq('id', room.id).single()
    if (latest?.host_finished && latest?.guest_finished) {
      await supabase.from('game_rooms').update({ status: 'finished' }).eq('id', room.id)
    }
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
    const newAnswers = [...myAnswers, ans ?? null]

    setTotalScore(newTotalScore)
    setLevelScore(newLevelScore)
    setMyAnswers(newAnswers)

    const update = isHost ? { host_answers: newAnswers } : { guest_answers: newAnswers }
    if (room?.id) createClient().from('game_rooms').update(update).eq('id', room.id)

    if (questionInLevel === QUESTIONS_PER_LEVEL - 1) {
      const newLevelScores = [...myLevelScores, newLevelScore]
      setMyLevelScores(newLevelScores)

      const newMyWins = newLevelScores.filter((s, i) => s > (opponentLvlScores[i] ?? -Infinity)).length
      if (!isTimed && newMyWins >= targetWins) {
        setFinished(true)
        submitFinished(newTotalScore, newLevelScores, newAnswers)
        return
      }

      const levelUpdate = isHost
        ? { host_level_scores: newLevelScores, host_score: newTotalScore }
        : { guest_level_scores: newLevelScores, guest_score: newTotalScore }
      if (room?.id) createClient().from('game_rooms').update(levelUpdate).eq('id', room.id)

      setTimeout(() => { setLevelScore(newLevelScore); setShowLevelEnd(true) }, 50)
      return
    }

    setCurrent(c => c + 1)
    setSelected(null)
    setRevealed(false)
  }, [selected, questions, current, totalScore, levelScore, myAnswers, myLevelScores, questionInLevel, pointsPerCorrect, isTimed, targetWins, opponentLvlScores, isHost, room?.id])

  function handleSelect(idx: number) {
    if (revealed || finished) return
    setSelected(idx)
    setRevealed(true)
    setTimeout(() => goNext(idx), 1200)
  }

  function handleContinueLevel() {
    setShowLevelEnd(false)
    setLevelScore(0)
    setCurrent(c => c + 1)
    setSelected(null)
    setRevealed(false)
  }

  function handleManualFinish() {
    setShowFinishConfirm(false)
    const completedLevels = myLevelScores.length
    if (completedLevels < 1) return
    setFinished(true)
    submitFinished(totalScore, myLevelScores, myAnswers)
  }

  async function handleReset() {
    if (!room?.id) return
    await createClient().from('game_rooms').update({ status: 'waiting', guest_id: null }).eq('id', room.id)
    router.push('/igraj-zajedno')
  }

  // ── Screens ────────────────────────────────────────────────────────────────

  // Guest waiting for host to start (status = 'waiting' with guest_id set)
  if (!loading && room?.status === 'waiting') {
    const amGuest = myId === room.guest_id
    return (
      <div className="min-h-screen flex items-center justify-center"
        style={{ background: 'linear-gradient(135deg, #2a2a2a 0%, #404040 100%)' }}>
        <div className="text-white text-center px-6">
          {amGuest ? (
            <>
              <div className="text-6xl mb-6">⏳</div>
              <h2 className="text-2xl font-bold mb-2">Ušao/la si u sobu!</h2>
              <p className="text-white/70 mb-4">Čekamo da domaćin počne meč...</p>
              <div className="flex items-center gap-2 justify-center">
                <div className="w-2 h-2 rounded-full bg-[#4CAF50] animate-pulse" />
                <span className="text-white/50 text-sm">Format: {formatLabel(room.game_format)}</span>
              </div>
            </>
          ) : (
            <>
              <div className="text-6xl mb-6">⏳</div>
              <h2 className="text-2xl font-bold mb-2">Čekamo protivnika...</h2>
              <p className="text-white/70 mb-6">Format: <strong>{formatLabel(room.game_format)}</strong></p>
              <div className="text-5xl font-black py-6 px-8 rounded-2xl mb-4 inline-block"
                style={{ background: 'rgba(255,255,255,0.15)', letterSpacing: '0.25em' }}>{code}</div>
            </>
          )}
        </div>
      </div>
    )
  }

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center"
        style={{ background: 'linear-gradient(135deg, #2a2a2a 0%, #404040 100%)' }}>
        <div className="text-white text-center">
          <Image src="/chars-neutral.png" alt="" width={160} height={160} className="mx-auto mb-4 animate-bounce" />
          <p className="text-xl font-semibold">Pripremamo meč...</p>
        </div>
      </div>
    )
  }

  // Both finished — results
  if (room?.status === 'finished') {
    // Wins-based: whoever has more level wins; draws if equal.
    // Timed: compare total scores from DB.
    const iWon = isTimed ? myFinalScore > opponentScore : myWins > opponentWins
    const draw = isTimed ? myFinalScore === opponentScore : myWins === opponentWins
    return (
      <div className="min-h-screen flex flex-col items-center justify-center px-4 py-10"
        style={{ background: 'linear-gradient(135deg, #2a2a2a 0%, #404040 100%)' }}>
        <Image src={draw ? '/chars-neutral.png' : iWon ? '/chars-winner.png' : '/chars-loser.png'}
          alt="" width={200} height={200} className="mb-4" />
        <div className="w-full max-w-md bg-white rounded-3xl shadow-2xl overflow-hidden">
          <div className="p-6 text-center"
            style={{ background: draw ? '#FFECBC' : iWon ? '#E8F8F0' : '#FEE2E2' }}>
            <h2 className="text-2xl font-black" style={{ color: draw ? '#92400e' : iWon ? '#065f46' : '#b91c1c' }}>
              {draw ? 'Nerešeno!' : iWon ? 'Pobedio/la si!' : 'Izgubio/la si!'}
            </h2>
            {!isTimed && <p className="text-sm mt-1" style={{ color: draw ? '#92400e' : iWon ? '#065f46' : '#b91c1c' }}>
              {myWins} – {opponentWins} u nivoima
            </p>}
          </div>
          <div className="p-6">
            <div className="flex gap-4 mb-6">
              <div className="flex-1 bg-[#BCD9FF] rounded-2xl p-4 text-center">
                <p className="text-xs text-gray-500 mb-1">Ti</p>
                <p className="text-3xl font-black" style={{ color: '#343434' }}>{myFinalScore}</p>
                <p className="text-xs text-gray-400">bodova</p>
              </div>
              <div className="flex-1 bg-[#FAFAFA] rounded-2xl p-4 text-center">
                <p className="text-xs text-gray-500 mb-1">{opponentName}</p>
                <p className="text-3xl font-black text-gray-700">{opponentScore}</p>
                <p className="text-xs text-gray-400">bodova</p>
              </div>
            </div>
            <div className="flex gap-3">
              <button onClick={() => router.push('/igraj-zajedno')}
                className="flex-1 py-3 rounded-xl border border-gray-200 font-semibold text-sm text-gray-600">
                Nova igra
              </button>
              <button onClick={() => router.push('/kvizovi')}
                className="flex-1 py-3 rounded-xl font-semibold text-sm text-white"
                style={{ background: '#343434' }}>
                Kvizovi
              </button>
            </div>
          </div>
        </div>
      </div>
    )
  }

  // Waiting for opponent to finish
  if (finished && !opponentFinished) {
    return (
      <div className="min-h-screen flex items-center justify-center"
        style={{ background: 'linear-gradient(135deg, #2a2a2a 0%, #404040 100%)' }}>
        <div className="text-white text-center px-6 max-w-sm">
          <div className="text-6xl mb-4 animate-bounce">⏰</div>
          <h2 className="text-2xl font-bold mb-2">Završio/la si!</h2>
          <p className="text-white/70">Tvoj rezultat: <strong className="text-white">{totalScore} bodova</strong></p>
          <p className="text-white/50 text-sm mt-4 mb-8">Čekamo da {opponentName} završi...</p>
          <p className="text-white/30 text-xs mb-3">Ako protivnik ne završi, možeš otići — tvoj rezultat je sačuvan.</p>
          <button
            onClick={() => router.push('/igraj-zajedno')}
            className="w-full py-3 rounded-xl font-semibold text-sm"
            style={{ background: 'rgba(255,255,255,0.15)', color: 'rgba(255,255,255,0.7)' }}>
            Idi na lobi →
          </button>
        </div>
      </div>
    )
  }

  if (questions.length === 0) return null
  const q = questions[current]

  const opponentAnswers = isHost ? (room?.guest_answers ?? []) : (room?.host_answers ?? [])
  const opponentProgress = Math.round((opponentAnswers.length / Math.max(questions.length, 1)) * 100)
  const formatTimeRemaining = (s: number) => `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`

  return (
    <div className="min-h-screen flex flex-col relative overflow-hidden"
      style={{ background: 'linear-gradient(160deg, #2a2a2a 0%, #343434 50%, #FAFAFA 100%)' }}>

      {/* ── Side panels (desktop only) ── */}
      <div className="hidden xl:block fixed z-10" style={{ left: 16, top: '50%', transform: 'translateY(-50%)' }}>
        <PlayerCard
          name={myName}
          score={totalScore}
          wins={myDuetWins}
          color="#4CAF50"
          label="Ti"
        />
      </div>
      <div className="hidden xl:block fixed z-10" style={{ right: 16, top: '50%', transform: 'translateY(-50%)' }}>
        <PlayerCard
          name={opponentName}
          score={opponentScore}
          wins={opDuetWins}
          color="#FFCB46"
          label="Protivnik"
        />
      </div>

      {/* ── Top control bar ── */}
      <div className="sticky top-0 z-20 px-4 py-2"
        style={{ background: 'rgba(52,52,52,0.92)', backdropFilter: 'blur(8px)' }}>
        <div className="max-w-2xl mx-auto flex items-center justify-between">
          <button onClick={() => setShowResetConfirm(true)}
            className="text-white/80 hover:text-white text-sm font-medium px-3 py-1.5 rounded-lg hover:bg-white/10">
            ↩ Resetuj
          </button>
          <div className="text-center">
            <div className="text-white font-bold text-sm">
              {isTimed
                ? timeRemaining !== null ? formatTimeRemaining(timeRemaining) : '—'
                : `${myWins} – ${opponentWins} (${formatLabel(room?.game_format ?? '')})`}
            </div>
            <div className="text-white/60 text-xs">Nivo {currentLevel}</div>
          </div>
          <button onClick={() => setShowFinishConfirm(true)}
            className="text-white/80 hover:text-white text-sm font-medium px-3 py-1.5 rounded-lg hover:bg-white/10">
            Završi ⏹
          </button>
        </div>
      </div>

      {/* ── Dual progress ── */}
      <div className="px-4 pt-3 pb-1 max-w-2xl mx-auto w-full">
        <div className="flex items-center justify-between text-xs text-white/60 mb-1">
          <span>{myName} · {totalScore} bod.</span>
          <span>Pit. {questionInLevel + 1}/10</span>
          <span>{opponentName} · {opponentScore} bod.</span>
        </div>
        <div className="flex gap-2">
          <div className="flex-1 h-1.5 bg-white/20 rounded-full overflow-hidden">
            <div className="h-full rounded-full transition-all duration-500"
              style={{ width: `${((questionInLevel + 1) / QUESTIONS_PER_LEVEL) * 100}%`, background: '#4CAF50' }} />
          </div>
          <div className="flex-1 h-1.5 bg-white/20 rounded-full overflow-hidden">
            <div className="h-full rounded-full transition-all duration-500"
              style={{ width: `${opponentProgress}%`, background: '#FFCB46' }} />
          </div>
        </div>
      </div>

      {/* ── Question card ── */}
      <div className="flex-1 flex items-start justify-center px-4 pb-32 pt-3">
        <div className="w-full max-w-2xl" key={current}>
          <div className="bg-white rounded-3xl shadow-2xl overflow-hidden">
            <div className="p-6 pb-4">
              <span className="text-xs font-semibold uppercase tracking-wide text-gray-400">
                Nivo {currentLevel} · Pitanje {questionInLevel + 1}
              </span>
              <h2 className="text-xl font-bold text-gray-800 leading-snug mt-3">{q.question_text}</h2>
            </div>
            <div className="px-6 pb-6 grid grid-cols-1 gap-3">
              {q.options.map((option: string, idx: number) => {
                const isCorrect = idx === q.correct_answer
                const isSelected = idx === selected
                let style: React.CSSProperties = { borderColor: '#e5e7eb', background: 'white', color: '#374151' }
                if (revealed) {
                  if (isCorrect) style = { borderColor: '#4CAF50', background: '#E8F8F0', color: '#15803d' }
                  else if (isSelected) style = { borderColor: '#E55353', background: '#FEE2E2', color: '#b91c1c' }
                  else style = { borderColor: '#e5e7eb', background: '#fafafa', color: '#9ca3af' }
                }
                return (
                  <button key={idx} onClick={() => handleSelect(idx)} disabled={revealed}
                    className="flex items-center gap-3 w-full px-4 py-3.5 rounded-2xl border-2 text-left transition-all hover:scale-[1.01] disabled:cursor-default font-medium"
                    style={style}>
                    <span className="w-8 h-8 rounded-xl flex-shrink-0 flex items-center justify-center text-sm font-bold"
                      style={{ background: revealed && isCorrect ? '#4CAF50' : revealed && isSelected ? '#E55353' : '#F5F6FA', color: revealed && (isCorrect || isSelected) ? 'white' : '#6b7280' }}>
                      {revealed && isCorrect ? '✓' : revealed && isSelected && !isCorrect ? '✗' : OPTION_LABELS[idx]}
                    </span>
                    <span className="flex-1 text-sm">{option}</span>
                  </button>
                )
              })}
            </div>
          </div>
        </div>
      </div>

      {/* ── Level end overlay ── */}
      {showLevelEnd && (
        <div className="fixed inset-0 z-40 flex flex-col items-center justify-center px-6"
          style={{ background: 'linear-gradient(160deg, #343434 0%, #609DED 100%)' }}>
          <Image src="/chars-correct.png" alt="" width={180} height={180} className="mb-2" />
          <div className="bg-white rounded-3xl shadow-2xl max-w-sm w-full p-8 text-center">
            <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full text-sm font-bold mb-4"
              style={{ background: '#BCD9FF', color: '#343434' }}>⚔️ Nivo {currentLevel} završen!</div>
            <div className="flex gap-4 mb-4">
              <div className="flex-1 bg-[#FAFAFA] rounded-2xl p-4">
                <div className="text-2xl font-black" style={{ color: levelScore >= 0 ? '#4CAF50' : '#E55353' }}>
                  {levelScore > 0 ? '+' : ''}{levelScore}
                </div>
                <div className="text-xs text-gray-400 mt-1">Ovaj nivo</div>
              </div>
              <div className="flex-1 bg-[#BCD9FF] rounded-2xl p-4">
                <div className="text-2xl font-black" style={{ color: '#343434' }}>{totalScore}</div>
                <div className="text-xs text-gray-400 mt-1">Ukupno</div>
              </div>
            </div>
            {!isTimed && (
              <p className="text-sm font-bold mb-4" style={{ color: '#343434' }}>
                Pobede: Ti {myWins} – {opponentWins} {opponentName}
              </p>
            )}
            <div className="flex gap-3">
              <button onClick={() => { setShowLevelEnd(false); setFinished(true); submitFinished(totalScore, myLevelScores, myAnswers) }}
                className="flex-1 py-3 rounded-xl border-2 border-gray-200 font-semibold text-gray-600 text-sm">
                Završi
              </button>
              <button onClick={handleContinueLevel}
                className="flex-1 py-3 rounded-xl font-semibold text-white text-sm"
                style={{ background: '#4CAF50' }}>
                Nivo {currentLevel + 1} →
              </button>
            </div>
          </div>
        </div>
      )}

      {showResetConfirm && (
        <ConfirmPopup
          title="Resetuj meč?"
          message="Oba igrača se vraćaju u lobi. Svi bodovi se gube."
          onConfirm={handleReset}
          onCancel={() => setShowResetConfirm(false)}
        />
      )}

      {showFinishConfirm && (
        <ConfirmPopup
          title={myLevelScores.length < 1 ? 'Previše rano!' : 'Završi meč?'}
          message={myLevelScores.length < 1
            ? 'Moraš završiti bar jedan nivo da bi rezultat bio sačuvan.'
            : `Završiš sa ${totalScore} bodova. Rezultat se čuva.`}
          onConfirm={myLevelScores.length >= 1 ? handleManualFinish : () => setShowFinishConfirm(false)}
          onCancel={() => setShowFinishConfirm(false)}
        />
      )}
    </div>
  )
}
