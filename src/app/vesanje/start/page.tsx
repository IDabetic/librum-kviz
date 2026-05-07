'use client'

export const dynamic = 'force-dynamic'

import { useEffect, useState, useRef, useCallback, Suspense } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import Link from 'next/link'
import { createClient } from '@/lib/supabase/client'
import { IconClose, IconCheck, IconWrong, IconHint } from '@/components/icons'

// Serbian Latin alphabet for the keyboard (no Q W X Y; digraphs Dž/Lj/Nj entered as separate letters)
const ALPHABET = ['A','B','C','Č','Ć','D','Đ','E','F','G','H','I','J','K','L','M','N','O','P','R','S','Š','T','U','V','Z','Ž']

const STARTING_LIVES = 6
const POINTS_CORRECT_LETTER = 5
const POINTS_WRONG_LETTER = 2
const POINTS_WORD_BONUS = 20
const POINTS_NO_ERROR_BONUS = 30
const POINTS_LOW_ERROR_BONUS = 15

type WordRow = { id: string; word: string; hint: string; category: string }

function isLetter(ch: string): boolean {
  // Allow any letter (including Serbian Č/Ć/Š/Ž/Đ); skip spaces, hyphens, apostrophes etc.
  return /[\p{L}]/u.test(ch)
}

function normalize(ch: string): string {
  return ch.toLocaleLowerCase('sr-Latn')
}

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
      {/* base */}
      <line x1="10" y1="130" x2="80" y2="130" stroke={stroke} strokeWidth={sw} strokeLinecap="round" />
      {/* pole vertical */}
      {wrongs >= 1 && <line x1="30" y1="130" x2="30" y2="20" stroke={stroke} strokeWidth={sw} strokeLinecap="round" />}
      {/* top beam */}
      {wrongs >= 1 && <line x1="30" y1="20" x2="80" y2="20" stroke={stroke} strokeWidth={sw} strokeLinecap="round" />}
      {/* rope */}
      {wrongs >= 1 && <line x1="80" y1="20" x2="80" y2="35" stroke={stroke} strokeWidth={sw} strokeLinecap="round" />}
      {/* head */}
      {wrongs >= 2 && <circle cx="80" cy="45" r="10" stroke={stroke} strokeWidth={sw} fill="none" />}
      {/* body */}
      {wrongs >= 3 && <line x1="80" y1="55" x2="80" y2="90" stroke={stroke} strokeWidth={sw} strokeLinecap="round" />}
      {/* left arm */}
      {wrongs >= 4 && <line x1="80" y1="65" x2="68" y2="78" stroke={stroke} strokeWidth={sw} strokeLinecap="round" />}
      {/* right arm */}
      {wrongs >= 5 && <line x1="80" y1="65" x2="92" y2="78" stroke={stroke} strokeWidth={sw} strokeLinecap="round" />}
      {/* legs */}
      {wrongs >= 6 && <line x1="80" y1="90" x2="68" y2="110" stroke={stroke} strokeWidth={sw} strokeLinecap="round" />}
      {wrongs >= 6 && <line x1="80" y1="90" x2="92" y2="110" stroke={stroke} strokeWidth={sw} strokeLinecap="round" />}
    </svg>
  )
}

function GameInner() {
  const router = useRouter()
  const sp = useSearchParams()
  const cat = sp.get('cat') || 'random'
  const mode = sp.get('mode') // 'custom' for 2-player

  // Game state
  const [wordRow, setWordRow] = useState<WordRow | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [myId, setMyId] = useState<string | null>(null)
  const [round, setRound] = useState(0)

  const [guessed, setGuessed] = useState<Set<string>>(new Set())   // correct letters guessed (lowercased)
  const [wrongs, setWrongs] = useState<Set<string>>(new Set())     // wrong letters (lowercased)
  const [lives, setLives] = useState(STARTING_LIVES)
  const [score, setScore] = useState(0)
  const [status, setStatus] = useState<'playing' | 'won' | 'lost'>('playing')
  const [showWordGuess, setShowWordGuess] = useState(false)
  const [wordGuess, setWordGuess] = useState('')
  const [wordGuessError, setWordGuessError] = useState('')
  const [scoreFlash, setScoreFlash] = useState<{ delta: number; key: number } | null>(null)
  // Initialised lazily on mount instead of in the useRef call — keeps the
  // component pure during render (Date.now is non-deterministic).
  const startRef = useRef<number>(0)
  const savedRef = useRef(false)
  useEffect(() => { startRef.current = Date.now() }, [])

  // Mirror live game state in a ref so pagehide / exit handlers can flush
  // the latest score without depending on render closures.
  const liveRef = useRef({
    score: 0, wrongs: 0, guessed: 0, status: 'playing' as 'playing' | 'won' | 'lost',
    anyMove: false,
  })
  useEffect(() => {
    liveRef.current = {
      score, wrongs: wrongs.size, guessed: guessed.size,
      status, anyMove: guessed.size + wrongs.size > 0,
    }
  }, [score, wrongs, guessed, status])

  // ── Load word ──────────────────────────────────────────────────────────
  useEffect(() => {
    async function load() {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) { router.push('/auth/prijava'); return }
      setMyId(user.id)

      // Custom 2-player mode: read from sessionStorage
      if (mode === 'custom') {
        const stored = sessionStorage.getItem('vesanje-custom')
        if (!stored) { router.push('/vesanje/dvoje'); return }
        const c = JSON.parse(stored) as { word: string; hint: string; category: string }
        setWordRow({ id: '', word: c.word.toLowerCase(), hint: c.hint, category: c.category || 'Igrač' })
        setLoading(false)
        return
      }

      // System words: pull from DB
      let q = supabase.from('hangman_words').select('id, word, hint, category').eq('is_active', true)
      if (cat !== 'random') q = q.eq('category', cat)
      const { data, error } = await q.limit(80)
      if (error || !data || data.length === 0) {
        setError('Nema reči u toj kategoriji.')
        setLoading(false)
        return
      }
      const r = data[Math.floor(Math.random() * data.length)] as WordRow
      setWordRow(r)
      setLoading(false)
    }
    load()
  }, [cat, mode, router, round])

  // ── Reset state when word changes (i.e., new game) ─────────────────────
  function resetGame() {
    setGuessed(new Set())
    setWrongs(new Set())
    setLives(STARTING_LIVES)
    setScore(0)
    setStatus('playing')
    setShowWordGuess(false)
    setWordGuess('')
    setWordGuessError('')
    startRef.current = Date.now()
    savedRef.current = false
  }

  // ── Save session on terminal state ─────────────────────────────────────
  useEffect(() => {
    if (status === 'playing' || savedRef.current || !myId || !wordRow) return
    savedRef.current = true
    const supabase = createClient()
    supabase.from('hangman_sessions').insert({
      user_id: myId,
      word: wordRow.word,
      word_id: wordRow.id || null,
      word_length: wordRow.word.replace(/[^\p{L}]/gu, '').length,
      won: status === 'won',
      wrong_guesses: wrongs.size,
      letters_used: guessed.size + wrongs.size,
      time_seconds: Math.floor((Date.now() - startRef.current) / 1000),
      hint: wordRow.hint,
      category: wordRow.category,
      score,
    }).then(() => {})
  }, [status, myId, wordRow, wrongs, guessed, score])

  // Best-effort save when the user leaves before reaching won/lost.
  // hangman_sessions row carries won=false + whatever score they had,
  // so the leaderboard counts the partial play (no win, but score).
  const persistSession = useCallback(async (opts: { useBeacon?: boolean } = {}) => {
    if (savedRef.current || !myId || !wordRow) return
    const live = liveRef.current
    if (!live.anyMove) return
    if (live.status !== 'playing') return  // terminal-state useEffect already handled it
    savedRef.current = true
    const payload = {
      user_id: myId,
      word: wordRow.word,
      word_id: wordRow.id || null,
      word_length: wordRow.word.replace(/[^\p{L}]/gu, '').length,
      won: false,
      wrong_guesses: live.wrongs,
      letters_used: live.guessed + live.wrongs,
      time_seconds: Math.floor((Date.now() - startRef.current) / 1000),
      hint: wordRow.hint,
      category: wordRow.category,
      score: live.score,
    }
    if (opts.useBeacon && typeof navigator !== 'undefined' && 'sendBeacon' in navigator) {
      try {
        const blob = new Blob([JSON.stringify({ mode: 'hangman', ...payload })], { type: 'application/json' })
        navigator.sendBeacon('/api/save-session', blob)
        return
      } catch { /* fall through */ }
    }
    const supabase = createClient()
    await supabase.from('hangman_sessions').insert(payload)
  }, [myId, wordRow])

  useEffect(() => {
    function flush() { void persistSession({ useBeacon: true }) }
    function onVis() { if (document.visibilityState === 'hidden') flush() }
    window.addEventListener('pagehide', flush)
    document.addEventListener('visibilitychange', onVis)
    return () => {
      window.removeEventListener('pagehide', flush)
      document.removeEventListener('visibilitychange', onVis)
    }
  }, [persistSession])

  async function handleExit() {
    await persistSession()
    router.push('/vesanje')
  }

  // ── Handle letter click ────────────────────────────────────────────────
  const handleLetter = useCallback((letter: string) => {
    if (!wordRow || status !== 'playing') return
    const norm = normalize(letter)
    if (guessed.has(norm) || wrongs.has(norm)) return // already used — no penalty

    const wordLow = wordRow.word.toLowerCase()
    if (wordLow.includes(norm)) {
      const ng = new Set(guessed); ng.add(norm)
      // Count how many positions this letter fills (each one earns +5)
      const occurrences = (wordLow.match(new RegExp(norm, 'g')) || []).length
      const delta = occurrences * POINTS_CORRECT_LETTER
      const newScore = Math.max(0, score + delta)
      setGuessed(ng)
      setScore(newScore)
      setScoreFlash({ delta, key: Date.now() })

      // Check win
      if (isAllRevealed(wordRow.word, ng)) {
        // Final bonuses: no errors → +30; 1-2 errors → +15
        let bonus = 0
        if (wrongs.size === 0) bonus = POINTS_NO_ERROR_BONUS
        else if (wrongs.size <= 2) bonus = POINTS_LOW_ERROR_BONUS
        if (bonus > 0) {
          setScore(s => s + bonus)
          setTimeout(() => setScoreFlash({ delta: bonus, key: Date.now() + 1 }), 350)
        }
        setStatus('won')
      }
    } else {
      const nw = new Set(wrongs); nw.add(norm)
      const newLives = lives - 1
      const newScore = Math.max(0, score - POINTS_WRONG_LETTER)
      setWrongs(nw)
      setLives(newLives)
      setScore(newScore)
      setScoreFlash({ delta: -POINTS_WRONG_LETTER, key: Date.now() })
      if (newLives <= 0) setStatus('lost')
    }
  }, [wordRow, status, guessed, wrongs, lives, score])

  // ── Whole word guess ───────────────────────────────────────────────────
  function submitWordGuess() {
    if (!wordRow || status !== 'playing') return
    const guess = wordGuess.trim().toLocaleLowerCase('sr-Latn')
    if (!guess) { setWordGuessError('Upiši reč.'); return }
    setWordGuessError('')

    if (guess === wordRow.word.toLowerCase()) {
      // Reveal all
      const all = new Set<string>()
      wordRow.word.split('').forEach(ch => { if (isLetter(ch)) all.add(normalize(ch)) })
      let bonus = POINTS_WORD_BONUS
      if (wrongs.size === 0) bonus += POINTS_NO_ERROR_BONUS
      else if (wrongs.size <= 2) bonus += POINTS_LOW_ERROR_BONUS
      const newScore = score + bonus
      setGuessed(all)
      setScore(newScore)
      setScoreFlash({ delta: bonus, key: Date.now() })
      setStatus('won')
      setShowWordGuess(false)
    } else {
      // Wrong: -2 lives
      const newLives = lives - 2
      setLives(newLives)
      setShowWordGuess(false)
      setWordGuess('')
      if (newLives <= 0) setStatus('lost')
    }
  }

  // ── Render ─────────────────────────────────────────────────────────────
  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center" style={{ background: '#FAFAFA' }}>
        <div className="w-8 h-8 rounded-full border-2 animate-spin"
          style={{ borderColor: '#609DED', borderTopColor: 'transparent' }} />
      </div>
    )
  }

  if (error || !wordRow) {
    return (
      <div className="min-h-screen flex items-center justify-center px-4" style={{ background: '#FAFAFA' }}>
        <div className="card-soft p-8 max-w-sm text-center">
          <p className="font-bold text-[16px] mb-3" style={{ color: '#343434' }}>{error || 'Greška'}</p>
          <Link href="/vesanje" className="btn btn-primary btn-md">Nazad</Link>
        </div>
      </div>
    )
  }

  const display = buildDisplay(wordRow.word, guessed)

  return (
    <div className="min-h-screen flex flex-col" style={{ background: '#FAFAFA' }}>

      {/* HUD */}
      <header className="sticky top-0 z-30 backdrop-blur-xl"
        style={{ background: 'rgba(252,252,252,0.92)', borderBottom: '1px solid rgba(52,52,52,0.06)' }}>
        <div className="max-w-3xl mx-auto px-4 sm:px-6 py-3 flex items-center justify-between gap-3">
          <button onClick={handleExit}
            className="w-10 h-10 rounded-full flex items-center justify-center transition-colors hover:bg-[#F2F2F2] flex-shrink-0"
            style={{ color: '#9C9C9C' }} aria-label="Izađi">
            <IconClose size={20} strokeWidth={2.2} />
          </button>

          <div className="flex items-center gap-2 flex-1 justify-center">
            <Stat label="Životi" value={`${lives}/${STARTING_LIVES}`} bg={lives <= 2 ? '#FEE2E2' : '#F2F2F2'} fg={lives <= 2 ? '#E55353' : '#343434'} />
            <Stat label="Bodovi" value={score} bg="#FFECBC" fg="#343434" highlight={scoreFlash?.delta} highlightKey={scoreFlash?.key} />
            <Stat label="Greške" value={wrongs.size} bg="#BCD9FF" fg="#1e5fa4" />
          </div>

          <div className="w-10 flex-shrink-0" />
        </div>
        {/* Lives bar */}
        <div className="max-w-3xl mx-auto px-4 sm:px-6 pb-2.5 flex gap-1">
          {Array.from({ length: STARTING_LIVES }).map((_, i) => (
            <div key={i} className="flex-1 h-1.5 rounded-full transition-all"
              style={{ background: i < lives ? '#4CAF50' : 'rgba(52,52,52,0.10)' }} />
          ))}
        </div>
      </header>

      {/* Game body */}
      <main className="flex-1 px-4 sm:px-6 py-6">
        <div className="max-w-2xl mx-auto">

          {/* Category + hint */}
          <div className="card-soft p-5 mb-4">
            <div className="flex items-start gap-3 mb-3">
              <div className="chip flex-shrink-0" style={{ background: '#BCD9FF', color: '#1e5fa4' }}>
                {wordRow.category}
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
                {wordRow.hint}
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
                const isLetter = ch !== '_' && !isGap
                const isPunct = !isLetter && !isGap && ch !== '_'
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
                            minHeight: 36,
                            lineHeight: 1,
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

          {/* Whole word guess */}
          {!showWordGuess && status === 'playing' && (
            <button onClick={() => setShowWordGuess(true)}
              className="w-full mb-4 py-3 rounded-2xl text-[13px] font-bold transition-all"
              style={{ background: '#FFECBC', color: '#9c7a13' }}>
              ⚡ Pogodi celu reč (-2 života ako pogrešiš)
            </button>
          )}
          {showWordGuess && status === 'playing' && (
            <div className="card-soft p-5 mb-4">
              <p className="text-[12px] font-bold mb-3" style={{ color: '#343434' }}>
                Pokušaj celu reč:
              </p>
              <input value={wordGuess} onChange={e => setWordGuess(e.target.value)}
                onKeyDown={e => e.key === 'Enter' && submitWordGuess()}
                className="input mb-3 uppercase font-bold tracking-wider"
                placeholder="Cela reč…"
                autoFocus />
              {wordGuessError && (
                <p className="text-[12px] mb-2" style={{ color: '#E55353' }}>{wordGuessError}</p>
              )}
              <div className="flex gap-2">
                <button onClick={() => { setShowWordGuess(false); setWordGuess('') }}
                  className="btn btn-secondary btn-md flex-1">Nazad</button>
                <button onClick={submitWordGuess} className="btn btn-primary btn-md flex-1">Pogodi</button>
              </div>
            </div>
          )}

          {/* Keyboard */}
          {status === 'playing' && (
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
                      isCorrect
                        ? { background: '#4CAF50', color: 'white' }
                        : isWrong
                          ? { background: '#FEE2E2', color: '#E55353', textDecoration: 'line-through' }
                          : { background: '#F2F2F2', color: '#343434' }
                    }>
                    {L}
                  </button>
                )
              })}
            </div>
          )}

          {/* End screen */}
          {status !== 'playing' && (
            <EndCard
              status={status}
              wordRow={wordRow}
              wrongs={wrongs.size}
              score={score}
              isCustom={mode === 'custom'}
              onPlayAgainSameCat={() => {
                if (mode === 'custom') {
                  // Custom word can't be replayed — go back to landing
                  router.push('/vesanje')
                  return
                }
                resetGame()
                setRound(r => r + 1)
              }}
            />
          )}
        </div>
      </main>
    </div>
  )
}

function EndCard({ status, wordRow, wrongs, score, isCustom, onPlayAgainSameCat }: {
  status: 'won' | 'lost'; wordRow: WordRow; wrongs: number; score: number
  isCustom: boolean
  onPlayAgainSameCat: () => void
}) {
  const isWon = status === 'won'
  return (
    <div className="card-soft p-7 mt-4 text-center" style={{ background: isWon ? '#E8F8F0' : '#FEE2E2' }}>
      <div className="flex items-center justify-center mb-3">
        <div className="w-14 h-14 rounded-full flex items-center justify-center"
          style={{ background: isWon ? '#4CAF50' : '#E55353' }}>
          {isWon ? <IconCheck size={28} className="text-white" /> : <IconWrong size={28} className="text-white" />}
        </div>
      </div>
      <h2 className="font-black text-[22px] mb-1 tracking-tight" style={{ color: isWon ? '#15803d' : '#b91c1c' }}>
        {isWon ? 'Bravo!' : 'Kraj igre'}
      </h2>
      <p className="text-[13px] mb-2" style={{ color: isWon ? '#15803d' : '#b91c1c' }}>
        {isWon ? 'Pogodio/la si reč:' : 'Tačna reč je bila:'}
      </p>
      <p className="font-black tracking-widest mb-4 uppercase" style={{ color: '#343434', fontSize: 'clamp(22px, 4vw, 32px)' }}>
        {wordRow.word}
      </p>
      <div className="grid grid-cols-3 gap-2 mb-5">
        <div className="rounded-xl p-2.5" style={{ background: 'rgba(255,255,255,0.6)' }}>
          <div className="font-black text-[16px]" style={{ color: '#343434' }}>{score}</div>
          <div className="text-[10px]" style={{ color: '#9C9C9C' }}>Bodovi</div>
        </div>
        <div className="rounded-xl p-2.5" style={{ background: 'rgba(255,255,255,0.6)' }}>
          <div className="font-black text-[16px]" style={{ color: '#343434' }}>{wrongs}</div>
          <div className="text-[10px]" style={{ color: '#9C9C9C' }}>Grešaka</div>
        </div>
        <div className="rounded-xl p-2.5" style={{ background: 'rgba(255,255,255,0.6)' }}>
          <div className="font-black text-[14px]" style={{ color: '#343434' }}>{wordRow.category}</div>
          <div className="text-[10px]" style={{ color: '#9C9C9C' }}>Kategorija</div>
        </div>
      </div>
      <div className="flex gap-2">
        <button onClick={onPlayAgainSameCat} className="btn btn-primary btn-md flex-1">
          {isCustom ? 'Nova igra' : 'Nova reč'}
        </button>
        <Link href="/vesanje" className="btn btn-secondary btn-md flex-1">
          {isCustom ? 'Početna' : 'Promeni'}
        </Link>
      </div>
    </div>
  )
}

function Stat({ label, value, bg, fg, highlight, highlightKey }: {
  label: string; value: number | string; bg: string; fg: string
  highlight?: number; highlightKey?: number
}) {
  return (
    <div className="relative px-3 sm:px-4 py-2 rounded-2xl flex-1 sm:flex-initial sm:min-w-[80px] text-center" style={{ background: bg }}>
      <div className="text-[10px] font-bold uppercase tracking-wider" style={{ color: fg, opacity: 0.65 }}>{label}</div>
      <div className="font-black text-[20px] sm:text-[24px] tracking-tight leading-none mt-0.5" style={{ color: fg }}>{value}</div>
      {highlight !== undefined && (
        <span key={highlightKey} className="absolute -top-2 left-1/2 -translate-x-1/2 font-black text-[13px] whitespace-nowrap"
          style={{ color: highlight > 0 ? '#4CAF50' : '#E55353', animation: 'floatUp 0.9s ease-out forwards' }}>
          {highlight > 0 ? `+${highlight}` : highlight}
        </span>
      )}
      <style jsx>{`
        @keyframes floatUp {
          0%   { opacity: 1; transform: translate(-50%, 0); }
          100% { opacity: 0; transform: translate(-50%, -20px); }
        }
      `}</style>
    </div>
  )
}

export default function VesanjeStartPage() {
  return (
    <Suspense>
      <GameInner />
    </Suspense>
  )
}
