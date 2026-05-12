'use client'

export const dynamic = 'force-dynamic'





import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import Header from '@/components/Header'
import { createClient } from '@/lib/supabase/client'
import { shuffle } from '@/lib/shuffle'

import Footer from '@/components/Footer'

// Standalone lobby for the Kafanski duel — same shape as /igraj-zajedno
// but locked to quiz_type='kafana' and themed in red/yellow. Once the
// room is created and started, navigation goes to the shared duel game
// at /igraj-zajedno/[code] (single source of truth for the playing UI;
// the room itself carries quiz_type so questions come from the right pool).

function generateCode(): string {
  return Math.random().toString(36).substring(2, 8).toUpperCase()
}

const DUEL_LENGTHS = [
  { id: 'q10', label: '10 pitanja', desc: 'Brzi duel',       count: 10 },
  { id: 'q25', label: '25 pitanja', desc: 'Standardni duel', count: 25 },
  { id: 'q50', label: '50 pitanja', desc: 'Veliki duel',     count: 50 },
] as const

const ACCENT = '#b91c1c'

export default function KafanaDuelLobby() {
  const router = useRouter()
  const [tab, setTab] = useState<'create' | 'join'>('create')

  const [selectedFormat, setSelectedFormat] = useState<typeof DUEL_LENGTHS[number]['id']>('q25')
  const [creating, setCreating] = useState(false)
  const [createdCode, setCreatedCode] = useState('')
  const [waitingForGuest, setWaitingForGuest] = useState(false)
  const [guestJoined, setGuestJoined] = useState(false)
  const [guestName, setGuestName] = useState('')
  const [starting, setStarting] = useState(false)

  const [joinCode, setJoinCode] = useState('')
  const [joining, setJoining] = useState(false)
  const [joinError, setJoinError] = useState('')

  // Watch for guest joining — show Start button when they arrive
  useEffect(() => {
    if (!createdCode || !waitingForGuest) return
    const supabase = createClient()
    const channel = supabase
      .channel(`kafana-room-watch-${createdCode}`)
      .on('postgres_changes', {
        event: 'UPDATE', schema: 'public', table: 'game_rooms',
        filter: `room_code=eq.${createdCode}`,
      }, async (payload) => {
        if (payload.new.guest_id && !guestJoined) {
          const { data: prof } = await supabase
            .from('public_profiles').select('first_name').eq('id', payload.new.guest_id).single()
          setGuestName(prof?.first_name ?? 'Prijatelj')
          setGuestJoined(true)
        }
      })
      .subscribe()
    return () => { supabase.removeChannel(channel) }
  }, [createdCode, waitingForGuest, guestJoined])

  async function handleCreate() {
    setCreating(true)
    const supabase = createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { router.push('/auth/prijava?redirect=/kafanski-kviz/duel'); return }

    const fmt = DUEL_LENGTHS.find(f => f.id === selectedFormat)!
    const targetCount = fmt.count

    // 72h dedupe — kafana_answer_log is the recent-set for this pool.
    const cutoff = new Date(Date.now() - 72 * 60 * 60 * 1000).toISOString()
    const { data: seen } = await supabase
      .from('kafana_answer_log')
      .select('question_id')
      .eq('user_id', user.id)
      .gte('created_at', cutoff)
    const seenSet = new Set((seen || []).map(s => s.question_id))

    const { data: all } = await supabase
      .from('kafana_questions').select('id').eq('is_active', true).limit(500)
    let pool = (all || []).filter((q: { id: string }) => !seenSet.has(q.id))
    if (pool.length < targetCount + 10) pool = all || []
    const ids = shuffle(pool).map((q: { id: string }) => q.id).slice(0, targetCount + 10)

    let code = generateCode()
    for (let i = 0; i < 5; i++) {
      const { data: ex } = await supabase.from('game_rooms').select('id').eq('room_code', code).maybeSingle()
      if (!ex) break
      code = generateCode()
    }

    const { error } = await supabase.from('game_rooms').insert({
      room_code: code,
      quiz_id: null,
      host_id: user.id,
      question_ids: ids,
      total_questions: targetCount,
      status: 'waiting',
      game_format: selectedFormat,
      quiz_type: 'kafana',
      target_wins: null,
      time_limit_seconds: null,
    })

    setCreating(false)
    if (error) return
    setCreatedCode(code)
    setWaitingForGuest(true)
  }

  async function handleStart() {
    if (!createdCode || starting) return
    setStarting(true)
    const supabase = createClient()
    await supabase.from('game_rooms').update({
      status: 'playing',
      game_start_time: new Date().toISOString(),
    }).eq('room_code', createdCode)
    router.push(`/igraj-zajedno/${createdCode}`)
  }

  async function handleJoin() {
    const code = joinCode.trim().toUpperCase()
    if (!code) return
    setJoining(true)
    setJoinError('')

    const supabase = createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { router.push('/auth/prijava?redirect=/kafanski-kviz/duel'); return }

    const { data: room } = await supabase
      .from('game_rooms').select('*').eq('room_code', code).maybeSingle()

    if (!room) { setJoinError('Soba sa tim kodom ne postoji.'); setJoining(false); return }
    if (room.quiz_type !== 'kafana') {
      setJoinError('Taj kod je za drugi tip duela. Probaj pod Trivia duel.')
      setJoining(false); return
    }
    if (room.status !== 'waiting') { setJoinError('Igra je već počela ili završena.'); setJoining(false); return }
    if (room.host_id === user.id) { setJoinError('Ne možeš da se pridružiš sopstvenoj sobi.'); setJoining(false); return }
    if (room.guest_id) { setJoinError('Neko je već zauzeo ovo mesto.'); setJoining(false); return }

    const { data: updated } = await supabase
      .from('game_rooms').update({ guest_id: user.id })
      .eq('room_code', code).is('guest_id', null).select().maybeSingle()

    if (!updated) { setJoinError('Neko je već zauzeo ovo mesto.'); setJoining(false); return }

    setJoining(false)
    router.push(`/igraj-zajedno/${code}`)
  }

  return (
    <div className="min-h-screen" style={{ background: '#FAFAFA' }}>
      <Header />
      <main className="max-w-xl mx-auto px-4 sm:px-6 py-10 sm:py-14">
        <div className="text-center mb-10">
          <p className="text-[13px] font-bold uppercase tracking-widest mb-2" style={{ color: ACCENT }}>
            Kafanski multiplayer
          </p>
          <h1 className="font-black tracking-tight leading-[1.1] mb-3"
            style={{ color: '#343434', fontSize: 'clamp(32px, 5vw, 48px)' }}>
            Kafanski duel
          </h1>
          <p className="text-[14px] sm:text-[15px]" style={{ color: '#9C9C9C' }}>
            Izazovi prijatelja u znanju kafanskih hitova.
          </p>
        </div>

        <div className="flex p-1 rounded-full mb-6 max-w-md mx-auto" style={{ background: '#F2F2F2' }}>
          {(['create', 'join'] as const).map(t => (
            <button key={t} onClick={() => setTab(t)}
              className="flex-1 py-2.5 rounded-full text-[14px] font-semibold transition-all"
              style={tab === t
                ? { background: '#FCFCFC', color: '#343434', boxShadow: '0 2px 8px rgba(52,52,52,0.06)' }
                : { color: '#9C9C9C' }}>
              {t === 'create' ? 'Kreiraj' : 'Pridruži se'}
            </button>
          ))}
        </div>

        {tab === 'create' && (
          <div className="card-soft p-6 sm:p-8">
            {!createdCode ? (
              <>
                <label className="block text-[13px] font-bold mb-3 tracking-tight" style={{ color: '#343434' }}>
                  Dužina duela
                </label>

                <div className="space-y-2 mb-5">
                  {DUEL_LENGTHS.map(f => {
                    const sel = selectedFormat === f.id
                    return (
                      <button key={f.id} onClick={() => setSelectedFormat(f.id)}
                        className="w-full flex items-center gap-3 px-4 py-4 rounded-2xl text-left transition-all"
                        style={sel
                          ? { background: '#FEE2E2', border: `1.5px solid ${ACCENT}` }
                          : { background: '#F2F2F2', border: '1.5px solid transparent' }}>
                        <div className="w-5 h-5 rounded-full border-2 flex items-center justify-center flex-shrink-0 transition-all"
                          style={sel
                            ? { borderColor: ACCENT, background: ACCENT }
                            : { borderColor: 'rgba(52,52,52,0.20)', background: 'white' }}>
                          {sel && <div className="w-2 h-2 rounded-full bg-white" />}
                        </div>
                        <div className="flex-1">
                          <div className="font-bold text-[15px] tracking-tight" style={{ color: '#343434' }}>{f.label}</div>
                          <div className="text-[12px]" style={{ color: '#9C9C9C' }}>{f.desc}</div>
                        </div>
                      </button>
                    )
                  })}
                </div>

                <div className="rounded-2xl p-4 mb-5" style={{ background: '#FFECBC' }}>
                  <p className="text-[12px] font-semibold leading-relaxed" style={{ color: '#9c7a13' }}>
                    Oba igrača dobijaju <strong>ista pitanja iz Kafanskog kviza</strong>. Tačan +10, pogrešan -5, vreme istekne -5. 15 sekundi po pitanju. Bez života, bez pomoći.
                  </p>
                </div>

                <button onClick={handleCreate} disabled={creating}
                  className="btn btn-primary btn-lg w-full"
                  style={{ background: ACCENT }}>
                  {creating ? 'Pravim sobu…' : 'Kreiraj sobu'}
                </button>
              </>
            ) : (
              <>
                <p className="text-[13px] mb-2 text-center" style={{ color: '#9C9C9C' }}>
                  {guestJoined ? `${guestName} se pridružio/la` : 'Podeli kod sa prijateljem'}
                </p>
                <div className="font-black text-center py-5 px-7 rounded-2xl mb-5 mx-auto"
                  style={{ background: '#FEE2E2', color: ACCENT, letterSpacing: '0.25em', fontSize: 'clamp(28px, 5vw, 40px)' }}>
                  {createdCode}
                </div>

                {!guestJoined ? (
                  <p className="text-center text-[13px]" style={{ color: '#9C9C9C' }}>
                    Čekamo {waitingForGuest && '…'}
                  </p>
                ) : (
                  <button onClick={handleStart} disabled={starting}
                    className="btn btn-primary btn-lg w-full"
                    style={{ background: ACCENT }}>
                    {starting ? 'Pokrećem…' : 'Pokreni duel'}
                  </button>
                )}
              </>
            )}
          </div>
        )}

        {tab === 'join' && (
          <div className="card-soft p-6 sm:p-8">
            <label className="block text-[13px] font-bold mb-3 tracking-tight" style={{ color: '#343434' }}>
              Šifra sobe
            </label>
            <input
              value={joinCode}
              onChange={e => setJoinCode(e.target.value.toUpperCase())}
              placeholder="ABC123"
              maxLength={6}
              className="input w-full mb-5 text-center font-bold"
              style={{ letterSpacing: '0.25em', fontSize: 22 }}
            />
            {joinError && (
              <p className="text-[13px] font-medium mb-3 text-center" style={{ color: ACCENT }}>{joinError}</p>
            )}
            <button onClick={handleJoin} disabled={joining || joinCode.length < 4}
              className="btn btn-primary btn-lg w-full"
              style={{ background: ACCENT }}>
              {joining ? 'Pridružujem…' : 'Pridruži se'}
            </button>
          </div>
        )}
      </main>
      <Footer />
    </div>
  )
}
