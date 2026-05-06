'use client'

export const dynamic = 'force-dynamic'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import Header from '@/components/Header'
import { createClient } from '@/lib/supabase/client'

function generateCode(): string {
  return Math.random().toString(36).substring(2, 8).toUpperCase()
}

const WIN_FORMATS = [
  { id: 'best_of_3', label: '3 pobede', desc: 'Ko prvi osvoji 3 nivoa', wins: 3 },
  { id: 'best_of_5', label: '5 pobeda', desc: 'Ko prvi osvoji 5 nivoa', wins: 5 },
  { id: 'best_of_11', label: '11 pobeda', desc: 'Ko prvi osvoji 11 nivoa', wins: 11 },
]
const TIME_FORMATS = [
  { id: 'time_5', label: '5 minuta', desc: 'Ko više bodova za 5 min', seconds: 300 },
  { id: 'time_15', label: '15 minuta', desc: 'Ko više bodova za 15 min', seconds: 900 },
  { id: 'time_30', label: '30 minuta', desc: 'Ko više bodova za 30 min', seconds: 1800 },
]

export default function IgrajZajednoPage() {
  const router = useRouter()
  const [tab, setTab] = useState<'create' | 'join'>('create')

  const [selectedFormat, setSelectedFormat] = useState('best_of_5')
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
      .channel(`room-watch-${createdCode}`)
      .on('postgres_changes', {
        event: 'UPDATE', schema: 'public', table: 'game_rooms',
        filter: `room_code=eq.${createdCode}`,
      }, async (payload) => {
        if (payload.new.guest_id && !guestJoined) {
          const { data: prof } = await supabase
            .from('profiles').select('first_name').eq('id', payload.new.guest_id).single()
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
    if (!user) { router.push('/auth/prijava'); return }

    // Single shared pool — pull random active questions
    const { data: all } = await supabase
      .from('questions').select('id').eq('is_active', true).limit(500)
    const questionIds = (all || []).sort(() => Math.random() - 0.5).map((q: { id: string }) => q.id).slice(0, 200)

    const winFmt = WIN_FORMATS.find(f => f.id === selectedFormat)
    const timeFmt = TIME_FORMATS.find(f => f.id === selectedFormat)

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
      question_ids: questionIds,
      total_questions: questionIds.length,
      status: 'waiting',
      game_format: selectedFormat,
      target_wins: winFmt?.wins ?? null,
      time_limit_seconds: timeFmt?.seconds ?? null,
    })

    setCreating(false)
    if (error) return
    setCreatedCode(code)
    setWaitingForGuest(true)
  }

  // Host explicitly starts the match
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
    if (!user) { router.push('/auth/prijava'); return }

    const { data: room } = await supabase
      .from('game_rooms').select('*').eq('room_code', code).maybeSingle()

    if (!room) { setJoinError('Soba sa tim kodom ne postoji.'); setJoining(false); return }
    if (room.status !== 'waiting') { setJoinError('Igra je već počela ili završena.'); setJoining(false); return }
    if (room.host_id === user.id) { setJoinError('Ne možeš da se pridružiš sopstvenoj sobi.'); setJoining(false); return }
    if (room.guest_id) { setJoinError('Neko je već zauzeo ovo mesto.'); setJoining(false); return }

    // Atomic update: only succeeds if guest_id is still null (race-condition safe)
    const { data: updated } = await supabase
      .from('game_rooms')
      .update({ guest_id: user.id })
      .eq('room_code', code)
      .is('guest_id', null)
      .select()
      .maybeSingle()

    if (!updated) { setJoinError('Neko je već zauzeo ovo mesto.'); setJoining(false); return }

    setJoining(false)
    router.push(`/igraj-zajedno/${code}`)
  }

  const allFormats = [...WIN_FORMATS, ...TIME_FORMATS]
  const formatLabels: Record<string, string> = Object.fromEntries(allFormats.map(f => [f.id, f.label]))

  return (
    <div className="min-h-screen" style={{ background: '#FAFAFA' }}>
      <Header />
      <main className="max-w-xl mx-auto px-4 sm:px-6 py-10 sm:py-14">
        <div className="text-center mb-10">
          <p className="text-[13px] font-bold uppercase tracking-widest mb-2" style={{ color: '#609DED' }}>
            Multiplayer
          </p>
          <h1 className="font-black tracking-tight leading-[1.1] mb-3"
            style={{ color: '#343434', fontSize: 'clamp(32px, 5vw, 48px)' }}>
            Igraj zajedno
          </h1>
          <p className="text-[14px] sm:text-[15px]" style={{ color: '#9C9C9C' }}>
            Izazovi prijatelja i vidi ko zna više.
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
                  Format igre
                </label>

                <div className="mb-3">
                  <p className="text-[11px] font-bold uppercase tracking-widest mb-2" style={{ color: '#9C9C9C' }}>Po pobedama</p>
                  <div className="grid grid-cols-3 gap-2">
                    {WIN_FORMATS.map(f => (
                      <button key={f.id} onClick={() => setSelectedFormat(f.id)}
                        className="py-3 rounded-xl text-[13px] font-bold transition-all"
                        style={selectedFormat === f.id
                          ? { background: '#609DED', color: 'white' }
                          : { background: '#F2F2F2', color: '#9C9C9C' }}>
                        {f.label}
                      </button>
                    ))}
                  </div>
                </div>

                <div className="mb-6">
                  <p className="text-[11px] font-bold uppercase tracking-widest mb-2" style={{ color: '#9C9C9C' }}>Po vremenu</p>
                  <div className="grid grid-cols-3 gap-2">
                    {TIME_FORMATS.map(f => (
                      <button key={f.id} onClick={() => setSelectedFormat(f.id)}
                        className="py-3 rounded-xl text-[13px] font-bold transition-all"
                        style={selectedFormat === f.id
                          ? { background: '#FFCB46', color: '#343434' }
                          : { background: '#F2F2F2', color: '#9C9C9C' }}>
                        {f.label}
                      </button>
                    ))}
                  </div>
                </div>

                {selectedFormat && (
                  <p className="text-[12px] text-center mb-5" style={{ color: '#9C9C9C' }}>
                    {allFormats.find(f => f.id === selectedFormat)?.desc}
                  </p>
                )}

                <button onClick={handleCreate} disabled={creating}
                  className="btn btn-primary btn-lg w-full">
                  {creating ? 'Kreiranje…' : 'Kreiraj sobu'}
                </button>
              </>
            ) : (
              <div className="text-center">
                <p className="text-[13px] mb-1" style={{ color: '#9C9C9C' }}>
                  Format: <strong style={{ color: '#343434' }}>{formatLabels[selectedFormat]}</strong>
                </p>
                <p className="text-[13px] mb-4" style={{ color: '#9C9C9C' }}>Pošalji ovaj kod prijatelju:</p>
                <div className="font-black py-7 px-8 rounded-3xl mb-6 inline-block"
                  style={{ background: '#BCD9FF', color: '#343434', letterSpacing: '0.25em', fontSize: 'clamp(36px, 7vw, 56px)' }}>
                  {createdCode}
                </div>

                {guestJoined ? (
                  <div>
                    <div className="flex items-center gap-3 justify-center mb-5 px-4 py-3 rounded-2xl"
                      style={{ background: '#E8F8F0' }}>
                      <div className="w-2 h-2 rounded-full flex-shrink-0" style={{ background: '#4CAF50' }} />
                      <p className="text-[13px] font-semibold" style={{ color: '#15803d' }}>
                        {guestName} se pridružio/la
                      </p>
                    </div>
                    <button onClick={handleStart} disabled={starting}
                      className="btn btn-primary btn-lg w-full">
                      {starting ? 'Pokretamo…' : 'Započni meč'}
                    </button>
                  </div>
                ) : (
                  <div className="flex flex-col items-center gap-4">
                    <div className="flex items-center gap-2">
                      <div className="w-2 h-2 rounded-full animate-pulse" style={{ background: '#609DED' }} />
                      <p className="text-[13px]" style={{ color: '#9C9C9C' }}>Čekamo da se prijatelj pridruži…</p>
                    </div>
                    <button onClick={() => navigator.clipboard.writeText(createdCode)}
                      className="btn btn-secondary btn-md">
                      Kopiraj kod
                    </button>
                  </div>
                )}
              </div>
            )}
          </div>
        )}

        {tab === 'join' && (
          <div className="card-soft p-6 sm:p-8">
            <label className="block text-[13px] font-bold mb-3 tracking-tight" style={{ color: '#343434' }}>
              Upiši kod sobe
            </label>
            <input type="text" value={joinCode} onChange={e => setJoinCode(e.target.value.toUpperCase())}
              onKeyDown={e => e.key === 'Enter' && handleJoin()} placeholder="AB12CD"
              maxLength={6}
              className="input mb-4 font-black text-center uppercase"
              style={{ fontSize: 'clamp(28px, 6vw, 36px)', letterSpacing: '0.3em', color: '#343434' }} />
            {joinError && (
              <div className="rounded-2xl px-4 py-3 text-[13px] font-medium mb-4" style={{ background: '#FEE2E2', color: '#b91c1c' }}>
                {joinError}
              </div>
            )}
            <button onClick={handleJoin} disabled={joining || joinCode.length < 6}
              className="btn btn-primary btn-lg w-full">
              {joining ? 'Spajamo se…' : 'Pridruži se'}
            </button>
          </div>
        )}
      </main>
    </div>
  )
}
