'use client'

import { useEffect, useState, useRef, useCallback } from 'react'
import { useParams, useRouter } from 'next/navigation'
import Link from 'next/link'
import Image from 'next/image'
import { createClient } from '@/lib/supabase/client'
import { shuffle } from '@/lib/shuffle'
import ShareResultButton from '@/components/ShareResultButton'

// Mirrors src/app/igraj-zajedno/page.tsx — kept in sync manually so the
// rematch creates a room with the same length the players just played.
const DUEL_LENGTHS: Record<string, number> = { q10: 10, q25: 25, q50: 50 }

type DuelResult = {
  myScore: number
  opScore: number
  myCorrect: number
  opCorrect: number
  myWrong: number
  opWrong: number
  totalAnswered: number
  totalTime: number
  totalQuestions: number
  goldenRounds: number
  myId: string | null
  opId: string | null
  myName: string
  opName: string
  myAvatar: string | null
  opAvatar: string | null
  iWon: boolean
  isDraw: boolean
}

type RoomRematchState = {
  id: string
  host_id: string
  guest_id: string | null
  game_format: string
  quiz_type: 'pro' | 'kafana'
  host_rematch: boolean
  guest_rematch: boolean
  rematch_room_code: string | null
}

function fmtTime(s: number): string {
  const m = Math.floor(s / 60)
  const sec = s % 60
  return `${String(m).padStart(2, '0')}:${String(sec).padStart(2, '0')}`
}

function generateCode(): string {
  return Math.random().toString(36).substring(2, 8).toUpperCase()
}

export default function DuelEndPage() {
  const params = useParams()
  const router = useRouter()
  const code = params.code as string

  // Lazy initialiser — sessionStorage is read once on mount and stays there
  // for the whole page lifetime, so a setState-in-effect would just churn.
  const [r] = useState<DuelResult | null>(() => {
    if (typeof window === 'undefined') return null
    const stored = sessionStorage.getItem(`duel-result-${code}`)
    if (!stored) return null
    try { return JSON.parse(stored) as DuelResult } catch { return null }
  })
  const [room, setRoom] = useState<RoomRematchState | null>(null)
  const [rematchBusy, setRematchBusy] = useState(false)
  const [rematchError, setRematchError] = useState('')

  // Track whether we already started the redirect — sometimes realtime
  // delivers the same `rematch_room_code` twice and we don't want to push
  // navigation twice.
  const navigatedRef = useRef(false)

  // ── Load + subscribe to game_rooms ────────────────────────────────────────
  useEffect(() => {
    if (!r) return
    const supabase = createClient()
    let cancelled = false

    async function load() {
      const { data } = await supabase
        .from('game_rooms')
        .select('id, host_id, guest_id, game_format, quiz_type, host_rematch, guest_rematch, rematch_room_code')
        .eq('room_code', code)
        .single()
      if (cancelled) return
      if (data) setRoom(data as RoomRematchState)
    }
    load()

    return () => { cancelled = true }
  }, [code, r])

  useEffect(() => {
    if (!room?.id) return
    const supabase = createClient()
    const channel = supabase
      .channel(`duel-end-${room.id}`)
      .on('postgres_changes', {
        event: 'UPDATE', schema: 'public', table: 'game_rooms', filter: `id=eq.${room.id}`,
      }, payload => {
        const next = payload.new as RoomRematchState
        setRoom(prev => prev ? { ...prev, ...next } : next)
      })
      .subscribe()
    return () => { supabase.removeChannel(channel) }
  }, [room?.id])

  // Realtime can drop events on flaky mobile connections — fall back to a
  // 2s poll on the same row so the partner ALWAYS sees "X traži revanš"
  // within a couple seconds even if the WebSocket doesn't deliver. We stop
  // polling the moment a rematch_room_code lands (everyone navigates).
  useEffect(() => {
    if (!room?.id || room.rematch_room_code) return
    const supabase = createClient()
    const id = room.id
    const t = setInterval(async () => {
      const { data } = await supabase
        .from('game_rooms')
        .select('host_rematch, guest_rematch, rematch_room_code')
        .eq('id', id)
        .single()
      if (!data) return
      setRoom(prev => prev ? { ...prev, ...data } : prev)
    }, 2000)
    return () => clearInterval(t)
  }, [room?.id, room?.rematch_room_code])

  useEffect(() => {
    if (!r) router.push('/igraj-zajedno')
  }, [r, router])

  // ── Derived rematch state ─────────────────────────────────────────────────
  const isHost = !!r && !!room && r.myId === room.host_id
  const myReady = !!room && (isHost ? room.host_rematch : room.guest_rematch)
  const opReady = !!room && (isHost ? room.guest_rematch : room.host_rematch)
  const bothReady = !!room && room.host_rematch && room.guest_rematch
  const rematchCode = room?.rematch_room_code ?? null

  // ── If the host is "us" and both clicked rematch, mint the new room ───────
  // Guest waits for the room_code to land and just navigates.
  const mintingRef = useRef(false)
  const mintRematchRoom = useCallback(async () => {
    if (mintingRef.current || !room || !isHost || rematchCode) return
    if (!room.guest_id) return
    mintingRef.current = true
    setRematchBusy(true)

    const supabase = createClient()
    const targetCount = DUEL_LENGTHS[room.game_format] ?? 25

    // 72h dedupe scan + question pull from the same pool the original
    // duel used. PRO duels read from `questions`/`question_answer_log`;
    // Kafanski duels from kafana_*. The new room inherits quiz_type so
    // the [code]/page.tsx loads from the right pool too.
    const isKafana = room.quiz_type === 'kafana'
    const logTable = isKafana ? 'kafana_answer_log' : 'question_answer_log'
    const poolTable = isKafana ? 'kafana_questions' : 'questions'

    const cutoff = new Date(Date.now() - 72 * 60 * 60 * 1000).toISOString()
    const { data: seen } = await supabase
      .from(logTable)
      .select('question_id')
      .eq('user_id', room.host_id)
      .gte('created_at', cutoff)
    const seenSet = new Set((seen || []).map(s => s.question_id))

    const { data: all } = await supabase
      .from(poolTable).select('id').eq('is_active', true).limit(500)
    let pool = (all || []).filter((q: { id: string }) => !seenSet.has(q.id))
    if (pool.length < targetCount + 10) pool = all || []
    const ids = shuffle(pool).map((q: { id: string }) => q.id).slice(0, targetCount + 10)

    // Find a fresh room code that isn't taken yet.
    let newCode = generateCode()
    for (let i = 0; i < 5; i++) {
      const { data: ex } = await supabase.from('game_rooms').select('id').eq('room_code', newCode).maybeSingle()
      if (!ex) break
      newCode = generateCode()
    }

    const { error: insertErr } = await supabase.from('game_rooms').insert({
      room_code: newCode,
      quiz_id: null,
      host_id: room.host_id,
      guest_id: room.guest_id,
      question_ids: ids,
      total_questions: targetCount,
      // Skip the lobby — both players are already paired; jump straight
      // into 'playing' so the [code] page doesn't show a waiting screen.
      status: 'playing',
      game_format: room.game_format,
      quiz_type: room.quiz_type,
      target_wins: null,
      time_limit_seconds: null,
    })
    if (insertErr) {
      mintingRef.current = false
      setRematchBusy(false)
      setRematchError('Greška pri pokretanju revanša. Pokušaj ponovo.')
      return
    }

    // Stamp the old room so the guest's realtime subscription fires and
    // both clients can navigate.
    await supabase.from('game_rooms')
      .update({ rematch_room_code: newCode })
      .eq('id', room.id)
  }, [room, isHost, rematchCode])

  useEffect(() => {
    // mintRematchRoom does its own busy/idempotency check via mintingRef;
    // calling it here is the right "react to realtime data" pattern even
    // though the effect kicks off setState chains downstream.
    if (bothReady && !rematchCode && isHost) void mintRematchRoom() // eslint-disable-line react-hooks/set-state-in-effect
  }, [bothReady, rematchCode, isHost, mintRematchRoom])

  // ── Both clients navigate when the new room code is published ─────────────
  useEffect(() => {
    if (!rematchCode || navigatedRef.current) return
    navigatedRef.current = true
    router.push(`/igraj-zajedno/${rematchCode}`)
  }, [rematchCode, router])

  // ── Click handler ─────────────────────────────────────────────────────────
  async function clickRematch() {
    if (!room || myReady || rematchBusy) return
    setRematchBusy(true)
    setRematchError('')
    const supabase = createClient()
    const update = isHost ? { host_rematch: true } : { guest_rematch: true }
    const { error } = await supabase.from('game_rooms').update(update).eq('id', room.id)
    setRematchBusy(false)
    if (error) setRematchError(error.message)
    // Optimistic local update so the UI flips immediately even before the
    // realtime echo arrives.
    if (!error) setRoom(prev => prev ? { ...prev, ...update } as RoomRematchState : prev)
  }

  if (!r) return null

  const myAccuracy = r.totalAnswered > 0 ? Math.round((r.myCorrect / r.totalAnswered) * 100) : 0
  const opAccuracy = r.totalAnswered > 0 ? Math.round((r.opCorrect / r.totalAnswered) * 100) : 0
  const diff = Math.abs(r.myScore - r.opScore)

  const heroBg = r.isDraw ? '#FFECBC' : r.iWon ? '#E8F8F0' : '#FEE2E2'
  const heroFg = r.isDraw ? '#9c7a13' : r.iWon ? '#15803d' : '#b91c1c'
  const headline = r.isDraw ? 'Nerešeno!' : r.iWon ? 'Pobedio/la si!' : 'Izgubio/la si!'

  // Pick the rematch button label based on the joint state.
  let rematchLabel: string
  let rematchDisabled = false
  if (rematchCode) {
    rematchLabel = 'Pokrećemo revanš…'
    rematchDisabled = true
  } else if (bothReady) {
    rematchLabel = 'Pokrećemo revanš…'
    rematchDisabled = true
  } else if (myReady && !opReady) {
    rematchLabel = `Čekaš ${r.opName.split(' ')[0]}…`
    rematchDisabled = true
  } else if (!myReady && opReady) {
    rematchLabel = `${r.opName.split(' ')[0]} traži revanš · prihvati`
  } else {
    rematchLabel = 'Revanš'
  }

  return (
    <div className="min-h-screen py-10 sm:py-14 px-4 sm:px-6" style={{ background: '#FAFAFA' }}>
      <div className="max-w-xl mx-auto">

        {/* Hero */}
        <div className="card-soft overflow-hidden mb-4">
          <div className="px-7 py-10 sm:py-12 text-center" style={{ background: heroBg }}>
            <p className="text-[12px] font-bold uppercase tracking-widest mb-3" style={{ color: heroFg, opacity: 0.7 }}>
              Kraj duela
            </p>
            <h1 className="font-black tracking-tight mb-3 leading-[1.05]"
              style={{ color: heroFg, fontSize: 'clamp(36px, 7vw, 56px)' }}>
              {headline}
            </h1>
            {!r.isDraw && (
              <p className="text-[13px] font-semibold" style={{ color: heroFg, opacity: 0.7 }}>
                Razlika: {diff} bodova
              </p>
            )}
            {r.goldenRounds > 0 && (
              <p className="text-[12px] font-bold mt-2" style={{ color: heroFg, opacity: 0.6 }}>
                ⚡ {r.goldenRounds} zlatno {r.goldenRounds === 1 ? 'pitanje' : 'pitanja'}
              </p>
            )}
          </div>

          {/* Score battle */}
          <div className="p-7 sm:p-8">
            <div className="grid grid-cols-2 gap-3 mb-7">
              <PlayerCol userId={r.myId} name={r.myName} avatar={r.myAvatar} score={r.myScore} accent="#609DED" you winner={r.iWon && !r.isDraw} />
              <PlayerCol userId={r.opId} name={r.opName} avatar={r.opAvatar} score={r.opScore} accent="#FFCB46" winner={!r.iWon && !r.isDraw} />
            </div>

            {/* Stats grid */}
            <div className="space-y-3">
              <StatRow label="Tačnih"   me={r.myCorrect} op={r.opCorrect} />
              <StatRow label="Pogr."    me={r.myWrong}   op={r.opWrong} />
              <StatRow label="Tačnost"  me={`${myAccuracy}%`} op={`${opAccuracy}%`} />
              <div className="rounded-2xl px-4 py-3 flex items-center justify-between" style={{ background: '#F2F2F2' }}>
                <span className="text-[12px] font-medium" style={{ color: '#9C9C9C' }}>Vreme duela</span>
                <span className="font-bold text-[13px]" style={{ color: '#343434' }}>{fmtTime(r.totalTime)}</span>
              </div>
            </div>
          </div>
        </div>

        {/* Actions */}
        <div className="grid grid-cols-2 gap-3 mb-3">
          <button
            onClick={clickRematch}
            disabled={rematchDisabled || rematchBusy || !room}
            className="btn btn-primary btn-lg"
            style={rematchDisabled ? { opacity: 0.7, cursor: 'not-allowed' } : undefined}>
            {rematchLabel}
          </button>
          <Link href="/leaderboard" className="btn btn-secondary btn-lg">Rang lista</Link>
        </div>
        {opReady && !myReady && (
          <p className="text-center text-[12px] font-semibold mb-3" style={{ color: '#9c7a13' }}>
            ⚡ {r.opName.split(' ')[0]} čeka revanš
          </p>
        )}
        {rematchError && (
          <p className="text-center text-[12px] font-medium mb-3" style={{ color: '#E55353' }}>
            {rematchError}
          </p>
        )}
        <ShareResultButton
          gameLabel="Trivia duelu"
          score={r.myScore}
          extra={r.iWon
            ? `Pobedio/la sam ${r.opName} sa ${r.myScore}:${r.opScore}!`
            : r.isDraw
              ? `Nerešeno ${r.myScore}:${r.opScore} protiv ${r.opName}.`
              : `Igrao/la sam protiv ${r.opName}: ${r.myScore}:${r.opScore}.`}
          accent="blue"
          className="w-full"
        />

        <Link href="/igraj-zajedno" className="block text-center mt-6 text-[13px] font-medium transition-opacity hover:opacity-70"
          style={{ color: '#9C9C9C' }}>
          ← Izazovi drugog
        </Link>
      </div>
    </div>
  )
}

function PlayerCol({ userId, name, avatar, score, accent, you, winner }: {
  userId: string | null; name: string; avatar: string | null; score: number; accent: string; you?: boolean; winner?: boolean
}) {
  const inner = (
    <>
      <div className="w-14 h-14 rounded-2xl overflow-hidden mx-auto mb-3" style={{ background: '#FCFCFC', border: `2px solid ${accent}` }}>
        {avatar
          ? <Image src={`/avatars/${avatar}`} alt={name} width={56} height={56} className="w-full h-full object-cover" />
          : <div className="w-full h-full flex items-center justify-center text-[18px] font-bold" style={{ background: accent, color: 'white' }}>{name[0]}</div>}
      </div>
      <div className="text-[11px] font-bold uppercase tracking-wider" style={{ color: '#9C9C9C' }}>{you ? 'Ti' : name.split(' ')[0]}</div>
      <div className="font-black tracking-tight" style={{ color: accent, fontSize: 'clamp(28px, 5vw, 36px)' }}>{score}</div>
      <div className="text-[10px] font-medium mt-0.5" style={{ color: '#9C9C9C' }}>bodova</div>
      {winner && <div className="mt-2 text-[18px]">🏆</div>}
    </>
  )
  const cls = "rounded-2xl p-5 text-center transition-all hover:scale-[1.02]"
  const style = {
    background: winner ? '#FFECBC' : '#F2F2F2',
    border: winner ? '2px solid #FFCB46' : '2px solid transparent',
  }
  return userId
    ? <Link href={you ? '/profil' : `/profil/${userId}`} className={cls} style={style}>{inner}</Link>
    : <div className={cls} style={style}>{inner}</div>
}

function StatRow({ label, me, op }: { label: string; me: number | string; op: number | string }) {
  return (
    <div className="rounded-2xl px-4 py-3 flex items-center justify-between" style={{ background: '#F2F2F2' }}>
      <span className="font-bold text-[13px]" style={{ color: '#609DED' }}>{me}</span>
      <span className="text-[11px] font-bold uppercase tracking-wider" style={{ color: '#9C9C9C' }}>{label}</span>
      <span className="font-bold text-[13px]" style={{ color: '#FFCB46' }}>{op}</span>
    </div>
  )
}
