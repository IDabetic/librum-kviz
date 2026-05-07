'use client'

export const dynamic = 'force-dynamic'

import { useEffect, useState, useRef, useCallback } from 'react'
import { useParams, useRouter } from 'next/navigation'
import Link from 'next/link'
import Image from 'next/image'
import { createClient } from '@/lib/supabase/client'
import { IconClose, IconCheck, IconWrong, IconHint, IconShare, IconUsers } from '@/components/icons'

const ALPHABET = ['A','B','C','Č','Ć','D','Đ','E','F','G','H','I','J','K','L','M','N','O','P','R','S','Š','T','U','V','Z','Ž']

const STARTING_LIVES = 6
const POINTS_CORRECT_LETTER = 5
const POINTS_WRONG_LETTER = 2
const POINTS_WORD_BONUS = 20
const POINTS_NO_ERROR_BONUS = 30
const POINTS_LOW_ERROR_BONUS = 15

type Room = {
  id: string
  code: string
  host_id: string
  guest_id: string | null
  word: string
  hint: string
  category: string
  status: 'waiting' | 'playing' | 'finished' | 'abandoned'
  guessed_letters: string[]
  wrong_letters: string[]
  lives: number
  score: number
  result_won: boolean | null
}

function isLetter(ch: string): boolean { return /[\p{L}]/u.test(ch) }
function normalize(ch: string): string { return ch.toLocaleLowerCase('sr-Latn') }

function buildDisplay(word: string, guessed: Set<string>): string[] {
  return word.split('').map(ch => {
    if (!isLetter(ch)) return ch
    return guessed.has(normalize(ch)) ? ch.toUpperCase() : '_'
  })
}

function isAllRevealed(word: string, guessed: Set<string>): boolean {
  return word.split('').every(ch => !isLetter(ch) || guessed.has(normalize(ch)))
}

// ── Hangman drawing ───────────────────────────────────────────────────────
function HangmanDrawing({ wrongs }: { wrongs: number }) {
  const stroke = '#343434'
  const sw = 3.5
  return (
    <svg width="120" height="140" viewBox="0 0 120 140" fill="none">
      <line x1="10" y1="130" x2="80" y2="130" stroke={stroke} strokeWidth={sw} strokeLinecap="round" />
      {wrongs >= 1 && <line x1="30" y1="130" x2="30" y2="20" stroke={stroke} strokeWidth={sw} strokeLinecap="round" />}
      {wrongs >= 1 && <line x1="30" y1="20" x2="80" y2="20" stroke={stroke} strokeWidth={sw} strokeLinecap="round" />}
      {wrongs >= 1 && <line x1="80" y1="20" x2="80" y2="35" stroke={stroke} strokeWidth={sw} strokeLinecap="round" />}
      {wrongs >= 2 && <circle cx="80" cy="45" r="10" stroke={stroke} strokeWidth={sw} fill="none" />}
      {wrongs >= 3 && <line x1="80" y1="55" x2="80" y2="90" stroke={stroke} strokeWidth={sw} strokeLinecap="round" />}
      {wrongs >= 4 && <line x1="80" y1="65" x2="68" y2="78" stroke={stroke} strokeWidth={sw} strokeLinecap="round" />}
      {wrongs >= 5 && <line x1="80" y1="65" x2="92" y2="78" stroke={stroke} strokeWidth={sw} strokeLinecap="round" />}
      {wrongs >= 6 && <line x1="80" y1="90" x2="68" y2="110" stroke={stroke} strokeWidth={sw} strokeLinecap="round" />}
      {wrongs >= 6 && <line x1="80" y1="90" x2="92" y2="110" stroke={stroke} strokeWidth={sw} strokeLinecap="round" />}
    </svg>
  )
}

export default function HangmanLivePage() {
  const params = useParams()
  const router = useRouter()
  const code = (params.code as string).toUpperCase()

  const [myId, setMyId] = useState<string | null>(null)
  const [room, setRoom] = useState<Room | null>(null)
  const [hostName, setHostName] = useState<string>('')
  const [hostAvatar, setHostAvatar] = useState<string | null>(null)
  const [guestName, setGuestName] = useState<string>('')
  const [guestAvatar, setGuestAvatar] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string>('')
  const [joining, setJoining] = useState(false)
  const [showWordGuess, setShowWordGuess] = useState(false)
  const [wordGuess, setWordGuess] = useState('')
  const [wordGuessError, setWordGuessError] = useState('')
  const [shared, setShared] = useState(false)

  const isHost = !!myId && !!room && myId === room.host_id
  const isGuest = !!myId && !!room && myId === room.guest_id
  const canJoin = !!myId && !!room && room.guest_id === null && room.host_id !== myId && room.status === 'waiting'

  const savedSessionRef = useRef(false)

  // ── Load + realtime ─────────────────────────────────────────────────────
  useEffect(() => {
    async function load() {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) { router.push('/auth/prijava?redirect=' + encodeURIComponent(`/vesanje/uzivo/${code}`)); return }
      setMyId(user.id)

      const { data, error: e } = await supabase
        .from('hangman_rooms').select('*').eq('code', code).maybeSingle()
      if (e || !data) { setError('Soba nije pronađena.'); setLoading(false); return }
      setRoom(data as Room)
      // Load names
      const ids = [data.host_id, data.guest_id].filter(Boolean) as string[]
      if (ids.length) {
        const { data: profs } = await supabase
          .from('profiles').select('id, first_name, nickname, avatar').in('id', ids)
        ;(profs || []).forEach((p: { id: string; first_name: string; nickname: string; avatar: string }) => {
          if (p.id === data.host_id) {
            setHostName(p.nickname || p.first_name || 'Domaćin')
            setHostAvatar(p.avatar || null)
          }
          if (p.id === data.guest_id) {
            setGuestName(p.nickname || p.first_name || 'Igrač')
            setGuestAvatar(p.avatar || null)
          }
        })
      }
      setLoading(false)
    }
    load()
  }, [code, router])

  useEffect(() => {
    if (!room?.id) return
    const supabase = createClient()
    const channel = supabase.channel(`hangman-${room.id}`)
      .on('postgres_changes', {
        event: 'UPDATE', schema: 'public', table: 'hangman_rooms', filter: `id=eq.${room.id}`,
      }, async (payload) => {
        const updated = payload.new as Room
        setRoom(prev => ({ ...(prev as Room), ...updated }))
        // If guest just joined, fetch their profile
        if (updated.guest_id && !guestName) {
          const supabase2 = createClient()
          const { data: prof } = await supabase2.from('profiles')
            .select('first_name, nickname, avatar').eq('id', updated.guest_id).single()
          if (prof) {
            setGuestName(prof.nickname || prof.first_name || 'Igrač')
            setGuestAvatar(prof.avatar || null)
          }
        }
      })
      .subscribe()
    return () => { supabase.removeChannel(channel) }
  }, [room?.id, guestName])

  // ── Save hangman_session on finish (guest only) ─────────────────────────
  useEffect(() => {
    if (!room || room.status !== 'finished' || !isGuest || savedSessionRef.current) return
    savedSessionRef.current = true
    const supabase = createClient()
    supabase.from('hangman_sessions').insert({
      user_id: myId,
      word: room.word,
      word_length: room.word.replace(/[^\p{L}]/gu, '').length,
      won: !!room.result_won,
      wrong_guesses: room.wrong_letters.length,
      letters_used: room.guessed_letters.length + room.wrong_letters.length,
      time_seconds: 0,
      hint: room.hint,
      category: room.category,
      score: room.score,
    }).then(() => {})
  }, [room, isGuest, myId])

  // ── Join room (guest) ───────────────────────────────────────────────────
  async function handleJoin() {
    if (!room || joining) return
    setJoining(true)
    const supabase = createClient()
    const { data: updated } = await supabase
      .from('hangman_rooms')
      .update({ guest_id: myId, status: 'playing', started_at: new Date().toISOString() })
      .eq('id', room.id)
      .is('guest_id', null)
      .select()
      .maybeSingle()
    if (!updated) { setError('Soba je već zauzeta.'); setJoining(false); return }
    setRoom(updated as Room)
    setJoining(false)
  }

  // ── Letter click (guest only) ───────────────────────────────────────────
  const handleLetter = useCallback(async (letter: string) => {
    if (!room || !isGuest || room.status !== 'playing') return
    const norm = normalize(letter)
    const guessedSet = new Set(room.guessed_letters)
    const wrongsSet = new Set(room.wrong_letters)
    if (guessedSet.has(norm) || wrongsSet.has(norm)) return

    const wordLow = room.word.toLowerCase()
    let newGuessed = room.guessed_letters
    let newWrongs = room.wrong_letters
    let newLives = room.lives
    let newScore = room.score
    let newStatus: Room['status'] = room.status
    let resultWon: boolean | null = room.result_won

    if (wordLow.includes(norm)) {
      newGuessed = [...room.guessed_letters, norm]
      const occurrences = (wordLow.match(new RegExp(norm, 'g')) || []).length
      newScore = Math.max(0, room.score + occurrences * POINTS_CORRECT_LETTER)

      const ng = new Set(newGuessed)
      if (isAllRevealed(room.word, ng)) {
        let bonus = 0
        if (newWrongs.length === 0) bonus = POINTS_NO_ERROR_BONUS
        else if (newWrongs.length <= 2) bonus = POINTS_LOW_ERROR_BONUS
        newScore += bonus
        newStatus = 'finished'
        resultWon = true
      }
    } else {
      newWrongs = [...room.wrong_letters, norm]
      newLives = Math.max(0, room.lives - 1)
      newScore = Math.max(0, room.score - POINTS_WRONG_LETTER)
      if (newLives <= 0) { newStatus = 'finished'; resultWon = false }
    }

    const update: Partial<Room> & { finished_at?: string } = {
      guessed_letters: newGuessed,
      wrong_letters: newWrongs,
      lives: newLives,
      score: newScore,
      status: newStatus,
      result_won: resultWon,
    }
    if (newStatus === 'finished') update.finished_at = new Date().toISOString()

    // Optimistic local update
    setRoom(prev => prev ? { ...prev, ...update } as Room : prev)
    const supabase = createClient()
    await supabase.from('hangman_rooms').update(update).eq('id', room.id)
  }, [room, isGuest])

  // ── Whole word guess ────────────────────────────────────────────────────
  async function submitWordGuess() {
    if (!room || !isGuest || room.status !== 'playing') return
    const guess = wordGuess.trim().toLocaleLowerCase('sr-Latn')
    if (!guess) { setWordGuessError('Upiši reč.'); return }
    setWordGuessError('')

    if (guess === room.word.toLowerCase()) {
      const all = new Set<string>()
      room.word.split('').forEach(ch => { if (isLetter(ch)) all.add(normalize(ch)) })
      let bonus = POINTS_WORD_BONUS
      if (room.wrong_letters.length === 0) bonus += POINTS_NO_ERROR_BONUS
      else if (room.wrong_letters.length <= 2) bonus += POINTS_LOW_ERROR_BONUS
      const update = {
        guessed_letters: [...all],
        score: room.score + bonus,
        status: 'finished' as const,
        result_won: true,
        finished_at: new Date().toISOString(),
      }
      setRoom(prev => prev ? { ...prev, ...update } as Room : prev)
      const supabase = createClient()
      await supabase.from('hangman_rooms').update(update).eq('id', room.id)
      setShowWordGuess(false)
    } else {
      const newLives = Math.max(0, room.lives - 2)
      const update: Partial<Room> & { finished_at?: string } = {
        lives: newLives,
        status: newLives <= 0 ? 'finished' : 'playing',
        result_won: newLives <= 0 ? false : null,
      }
      if (newLives <= 0) update.finished_at = new Date().toISOString()
      setRoom(prev => prev ? { ...prev, ...update } as Room : prev)
      const supabase = createClient()
      await supabase.from('hangman_rooms').update(update).eq('id', room.id)
      setShowWordGuess(false)
      setWordGuess('')
    }
  }

  async function handleShare() {
    if (!room) return
    const link = `${window.location.origin}/vesanje/uzivo/${code}`
    const text = `Pozivam te na Vešanje! Kategorija: ${room.category}. Otvori link i pogađaj reč: ${link}`
    if (typeof navigator.share === 'function') {
      try { await navigator.share({ title: 'Librum Vešanje', text, url: link }) } catch { /* */ }
    } else {
      await navigator.clipboard.writeText(text)
      setShared(true)
      setTimeout(() => setShared(false), 2500)
    }
  }

  // ── Loading / error states ─────────────────────────────────────────────
  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center" style={{ background: '#FAFAFA' }}>
        <div className="w-8 h-8 rounded-full border-2 animate-spin"
          style={{ borderColor: '#609DED', borderTopColor: 'transparent' }} />
      </div>
    )
  }

  if (error || !room) {
    return (
      <div className="min-h-screen flex items-center justify-center px-4" style={{ background: '#FAFAFA' }}>
        <div className="card-soft p-8 max-w-sm text-center">
          <p className="font-bold text-[16px] mb-3" style={{ color: '#343434' }}>{error || 'Soba ne postoji.'}</p>
          <Link href="/vesanje" className="btn btn-primary btn-md">Nazad na Vešanje</Link>
        </div>
      </div>
    )
  }

  // ── Join screen (third party that knows code) ──────────────────────────
  if (canJoin) {
    return (
      <div className="min-h-screen flex items-center justify-center px-4" style={{ background: '#FAFAFA' }}>
        <div className="card-soft p-8 max-w-sm text-center w-full">
          <div className="w-14 h-14 rounded-2xl flex items-center justify-center mx-auto mb-5" style={{ background: '#FFCB46' }}>
            <IconUsers size={28} className="text-[#343434]" strokeWidth={2.2} />
          </div>
          <h1 className="font-black text-[24px] mb-2 tracking-tight" style={{ color: '#343434' }}>
            {hostName} te poziva
          </h1>
          <p className="text-[13px] mb-2" style={{ color: '#9C9C9C' }}>Kategorija</p>
          <div className="chip mx-auto mb-7" style={{ background: '#BCD9FF', color: '#1e5fa4' }}>
            {room.category}
          </div>
          <button onClick={handleJoin} disabled={joining} className="btn btn-primary btn-lg w-full">
            {joining ? 'Spajamo se…' : 'Pridruži se i pogađaj'}
          </button>
        </div>
      </div>
    )
  }

  // ── Host waiting screen ────────────────────────────────────────────────
  if (isHost && room.status === 'waiting') {
    return (
      <div className="min-h-screen flex items-center justify-center px-4 py-10" style={{ background: '#FAFAFA' }}>
        <div className="card-soft p-7 sm:p-8 max-w-md text-center w-full">
          <p className="text-[12px] font-bold uppercase tracking-widest mb-3" style={{ color: '#609DED' }}>
            Soba je otvorena
          </p>
          <h1 className="font-black tracking-tight mb-3 leading-[1.05]"
            style={{ color: '#343434', fontSize: 'clamp(28px, 6vw, 40px)' }}>
            Pošalji kod
          </h1>
          <p className="text-[14px] mb-5" style={{ color: '#9C9C9C' }}>
            Drugi igrač upiše ovaj kod ili otvori link sa svog telefona.
          </p>
          <div className="font-black py-7 px-8 rounded-3xl mb-5 inline-block"
            style={{ background: '#BCD9FF', color: '#343434', letterSpacing: '0.25em', fontSize: 'clamp(36px, 7vw, 56px)' }}>
            {code}
          </div>
          <div className="flex flex-col gap-2 mb-5">
            <button onClick={handleShare} className="btn btn-primary btn-md w-full">
              <IconShare size={16} strokeWidth={2.2} />
              {shared ? 'Link kopiran' : 'Podeli link'}
            </button>
            <button onClick={() => navigator.clipboard.writeText(code)}
              className="btn btn-secondary btn-md w-full">
              Kopiraj samo kod
            </button>
          </div>
          <div className="flex items-center justify-center gap-2 mb-3">
            <div className="w-2 h-2 rounded-full animate-pulse" style={{ background: '#609DED' }} />
            <p className="text-[12px]" style={{ color: '#9C9C9C' }}>Čekamo igrača…</p>
          </div>
          <Link href="/vesanje" className="text-[12px] font-medium transition-opacity hover:opacity-70"
            style={{ color: '#9C9C9C' }}>
            ← Otkaži i nazad
          </Link>
        </div>
      </div>
    )
  }

  // ── Live game screen (host watching, guest playing) ─────────────────────
  const guessed = new Set(room.guessed_letters)
  const wrongs = new Set(room.wrong_letters)
  const display = buildDisplay(room.word, guessed)
  const isFinished = room.status === 'finished'
  const isPlaying = room.status === 'playing'

  return (
    <div className="min-h-screen flex flex-col" style={{ background: '#FAFAFA' }}>

      {/* HUD */}
      <header className="sticky top-0 z-30 backdrop-blur-xl"
        style={{ background: 'rgba(252,252,252,0.92)', borderBottom: '1px solid rgba(52,52,52,0.06)' }}>
        <div className="max-w-3xl mx-auto px-4 sm:px-6 py-3 flex items-center justify-between gap-3">
          <Link href="/vesanje"
            className="w-10 h-10 rounded-full flex items-center justify-center transition-colors hover:bg-[#F2F2F2] flex-shrink-0"
            style={{ color: '#9C9C9C' }} aria-label="Izađi">
            <IconClose size={20} strokeWidth={2.2} />
          </Link>

          <div className="flex items-center gap-2 flex-1 justify-center">
            <Stat label="Životi" value={`${room.lives}/${STARTING_LIVES}`} bg={room.lives <= 2 ? '#FEE2E2' : '#F2F2F2'} fg={room.lives <= 2 ? '#E55353' : '#343434'} />
            <Stat label="Bodovi" value={room.score} bg="#FFECBC" fg="#343434" />
            <Stat label="Greške" value={wrongs.size} bg="#BCD9FF" fg="#1e5fa4" />
          </div>

          {/* Live indicator */}
          <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-full" style={{ background: '#E8F8F0' }}>
            <div className="w-2 h-2 rounded-full animate-pulse" style={{ background: '#4CAF50' }} />
            <span className="text-[10px] font-bold uppercase tracking-wider" style={{ color: '#15803d' }}>UŽIVO</span>
          </div>
        </div>
        <div className="max-w-3xl mx-auto px-4 sm:px-6 pb-2.5 flex gap-1">
          {Array.from({ length: STARTING_LIVES }).map((_, i) => (
            <div key={i} className="flex-1 h-1.5 rounded-full transition-all"
              style={{ background: i < room.lives ? '#4CAF50' : 'rgba(52,52,52,0.10)' }} />
          ))}
        </div>
      </header>

      <main className="flex-1 px-4 sm:px-6 py-6">
        <div className="max-w-2xl mx-auto">

          {/* Players */}
          <div className="card-soft p-4 mb-4 flex items-center justify-between gap-3">
            <PlayerBadge name={hostName} avatar={hostAvatar} role="Smišlja" you={isHost} accent="#FFCB46" />
            <div className="text-2xl">⚔</div>
            <PlayerBadge name={guestName || 'Čeka se...'} avatar={guestAvatar} role="Pogađa" you={isGuest} accent="#609DED" />
          </div>

          {/* Category + hint */}
          <div className="card-soft p-5 mb-4">
            <div className="flex items-start gap-3 mb-3">
              <div className="chip flex-shrink-0" style={{ background: '#BCD9FF', color: '#1e5fa4' }}>
                {room.category}
              </div>
              {wrongs.size > 0 && (
                <div className="ml-auto text-[12px] font-medium" style={{ color: '#E55353' }}>
                  Pogrešno: {[...wrongs].map(l => l.toUpperCase()).join(' ')}
                </div>
              )}
            </div>
            <div className="flex items-start gap-3">
              <IconHint size={18} className="text-[#FFCB46] flex-shrink-0 mt-0.5" strokeWidth={2.2} />
              <p className="text-[14px] sm:text-[15px] leading-relaxed font-medium" style={{ color: '#343434' }}>
                {room.hint}
              </p>
            </div>
          </div>

          {/* Hangman + word */}
          <div className="card-soft p-6 sm:p-8 mb-4">
            <div className="flex items-center justify-center mb-6">
              <HangmanDrawing wrongs={wrongs.size} />
            </div>
            <div className="flex items-center justify-center flex-wrap gap-x-2 gap-y-3">
              {display.map((ch, i) => {
                const isGap = ch === ' '
                const isLet = ch !== '_' && !isGap
                const isPunct = !isLet && !isGap && ch !== '_'
                return (
                  <div key={i} className="flex flex-col items-center" style={{ minWidth: 24 }}>
                    {isGap ? (
                      <span style={{ width: 16, display: 'inline-block' }}> </span>
                    ) : (
                      <>
                        <span className="font-black tracking-tight"
                          style={{
                            fontSize: 'clamp(22px, 4.5vw, 32px)',
                            color: ch === '_' ? '#9C9C9C' : '#343434',
                            opacity: ch === '_' ? 0.5 : 1,
                            minHeight: 36, lineHeight: 1,
                          }}>
                          {ch === '_' ? ' ' : ch}
                        </span>
                        <span style={{ width: 24, height: 2, background: isPunct ? 'transparent' : '#343434', display: 'block', marginTop: 4, borderRadius: 1 }} />
                      </>
                    )}
                  </div>
                )
              })}
            </div>
          </div>

          {/* Whole word guess (guest only, while playing) */}
          {isGuest && isPlaying && !showWordGuess && (
            <button onClick={() => setShowWordGuess(true)}
              className="w-full mb-4 py-3 rounded-2xl text-[13px] font-bold transition-all"
              style={{ background: '#FFECBC', color: '#9c7a13' }}>
              ⚡ Pogodi celu reč (-2 života ako pogrešiš)
            </button>
          )}
          {isGuest && isPlaying && showWordGuess && (
            <div className="card-soft p-5 mb-4">
              <p className="text-[12px] font-bold mb-3" style={{ color: '#343434' }}>Pokušaj celu reč:</p>
              <input value={wordGuess} onChange={e => setWordGuess(e.target.value)}
                onKeyDown={e => e.key === 'Enter' && submitWordGuess()}
                className="input mb-3 uppercase font-bold tracking-wider"
                placeholder="Cela reč…" autoFocus />
              {wordGuessError && <p className="text-[12px] mb-2" style={{ color: '#E55353' }}>{wordGuessError}</p>}
              <div className="flex gap-2">
                <button onClick={() => { setShowWordGuess(false); setWordGuess('') }} className="btn btn-secondary btn-md flex-1">Nazad</button>
                <button onClick={submitWordGuess} className="btn btn-primary btn-md flex-1">Pogodi</button>
              </div>
            </div>
          )}

          {/* Guest's keyboard */}
          {isGuest && isPlaying && (
            <div className="grid grid-cols-7 sm:grid-cols-9 gap-1.5 mt-4">
              {ALPHABET.map(L => {
                const norm = normalize(L)
                const isUsed = guessed.has(norm) || wrongs.has(norm)
                const isWrong = wrongs.has(norm)
                const isCorrect = guessed.has(norm)
                return (
                  <button key={L} onClick={() => handleLetter(L)} disabled={isUsed}
                    className="aspect-square rounded-xl font-bold text-[15px] sm:text-[16px] transition-all disabled:cursor-not-allowed"
                    style={
                      isCorrect ? { background: '#4CAF50', color: 'white' }
                      : isWrong ? { background: '#FEE2E2', color: '#E55353', textDecoration: 'line-through' }
                      : { background: '#F2F2F2', color: '#343434' }
                    }>
                    {L}
                  </button>
                )
              })}
            </div>
          )}

          {/* Host watching */}
          {isHost && isPlaying && (
            <div className="card-soft p-4 mt-4 text-center" style={{ background: '#F2F2F2' }}>
              <p className="text-[13px] font-medium" style={{ color: '#9C9C9C' }}>
                <span className="font-bold" style={{ color: '#343434' }}>{guestName}</span> trenutno pogađa…
              </p>
            </div>
          )}

          {/* End screen */}
          {isFinished && (
            <EndCard room={room} isHost={isHost} isGuest={isGuest} />
          )}
        </div>
      </main>
    </div>
  )
}

function EndCard({ room, isHost, isGuest }: { room: Room; isHost: boolean; isGuest: boolean }) {
  const won = !!room.result_won
  const headline = isGuest
    ? (won ? 'Bravo!' : 'Kraj igre')
    : (won ? 'Pogodili su!' : 'Pobedio si — nisu pogodili')

  return (
    <div className="card-soft p-7 mt-4 text-center" style={{ background: won ? '#E8F8F0' : '#FEE2E2' }}>
      <div className="flex items-center justify-center mb-3">
        <div className="w-14 h-14 rounded-full flex items-center justify-center"
          style={{ background: won ? '#4CAF50' : '#E55353' }}>
          {won ? <IconCheck size={28} className="text-white" /> : <IconWrong size={28} className="text-white" />}
        </div>
      </div>
      <h2 className="font-black text-[22px] mb-1 tracking-tight" style={{ color: won ? '#15803d' : '#b91c1c' }}>
        {headline}
      </h2>
      <p className="text-[13px] mb-2" style={{ color: won ? '#15803d' : '#b91c1c' }}>
        {won ? 'Pogođena reč:' : 'Tačna reč je bila:'}
      </p>
      <p className="font-black tracking-widest mb-4 uppercase" style={{ color: '#343434', fontSize: 'clamp(22px, 4vw, 32px)' }}>
        {room.word}
      </p>
      <div className="grid grid-cols-3 gap-2 mb-5">
        <div className="rounded-xl p-2.5" style={{ background: 'rgba(255,255,255,0.6)' }}>
          <div className="font-black text-[16px]" style={{ color: '#343434' }}>{room.score}</div>
          <div className="text-[10px]" style={{ color: '#9C9C9C' }}>Bodovi</div>
        </div>
        <div className="rounded-xl p-2.5" style={{ background: 'rgba(255,255,255,0.6)' }}>
          <div className="font-black text-[16px]" style={{ color: '#343434' }}>{room.wrong_letters.length}</div>
          <div className="text-[10px]" style={{ color: '#9C9C9C' }}>Grešaka</div>
        </div>
        <div className="rounded-xl p-2.5" style={{ background: 'rgba(255,255,255,0.6)' }}>
          <div className="font-black text-[14px]" style={{ color: '#343434' }}>{room.category}</div>
          <div className="text-[10px]" style={{ color: '#9C9C9C' }}>Kategorija</div>
        </div>
      </div>
      <div className="flex gap-2">
        <Link href={isHost ? '/vesanje/dvoje' : '/vesanje'} className="btn btn-primary btn-md flex-1">
          {isHost ? 'Nova soba' : 'Igraj sam'}
        </Link>
        <Link href="/vesanje" className="btn btn-secondary btn-md flex-1">Početna</Link>
      </div>
    </div>
  )
}

function PlayerBadge({ name, avatar, role, you, accent }: {
  name: string; avatar: string | null; role: string; you?: boolean; accent: string
}) {
  return (
    <div className="flex items-center gap-2 min-w-0 flex-1">
      <div className="w-9 h-9 rounded-2xl overflow-hidden flex-shrink-0 bg-[#F2F2F2]" style={{ border: `2px solid ${accent}` }}>
        {avatar
          ? <Image src={`/avatars/${avatar}`} alt={name} width={36} height={36} className="w-full h-full object-cover" />
          : <div className="w-full h-full flex items-center justify-center text-[12px] font-bold" style={{ background: accent, color: 'white' }}>{name[0]}</div>}
      </div>
      <div className="min-w-0">
        <div className="text-[10px] font-bold uppercase tracking-wider" style={{ color: '#9C9C9C' }}>
          {role}{you && ' · ti'}
        </div>
        <div className="font-bold text-[13px] truncate tracking-tight" style={{ color: '#343434' }}>{name}</div>
      </div>
    </div>
  )
}

function Stat({ label, value, bg, fg }: { label: string; value: number | string; bg: string; fg: string }) {
  return (
    <div className="px-3 sm:px-4 py-2 rounded-2xl flex-1 sm:flex-initial sm:min-w-[80px] text-center" style={{ background: bg }}>
      <div className="text-[10px] font-bold uppercase tracking-wider" style={{ color: fg, opacity: 0.65 }}>{label}</div>
      <div className="font-black text-[20px] sm:text-[24px] tracking-tight leading-none mt-0.5" style={{ color: fg }}>{value}</div>
    </div>
  )
}
