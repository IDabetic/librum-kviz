'use client'

export const dynamic = 'force-dynamic'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import Header from '@/components/Header'
import { createClient } from '@/lib/supabase/client'
import type { Quiz } from '@/types/database'

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

  const [quizzes, setQuizzes] = useState<Quiz[]>([])
  const [selectedQuiz, setSelectedQuiz] = useState('mix')
  const [selectedFormat, setSelectedFormat] = useState('best_of_5')
  const [creating, setCreating] = useState(false)
  const [createdCode, setCreatedCode] = useState('')
  const [waitingForGuest, setWaitingForGuest] = useState(false)

  const [joinCode, setJoinCode] = useState('')
  const [joining, setJoining] = useState(false)
  const [joinError, setJoinError] = useState('')

  useEffect(() => {
    const supabase = createClient()
    supabase.from('quizzes').select('id, title, difficulty').order('title').then(({ data }) => {
      setQuizzes((data as Quiz[]) || [])
    })
  }, [])

  // Watch for guest joining
  useEffect(() => {
    if (!createdCode || !waitingForGuest) return
    const supabase = createClient()
    const channel = supabase
      .channel(`room-watch-${createdCode}`)
      .on('postgres_changes', {
        event: 'UPDATE', schema: 'public', table: 'game_rooms',
        filter: `room_code=eq.${createdCode}`,
      }, (payload) => {
        if (payload.new.guest_id && payload.new.status === 'playing') {
          router.push(`/igraj-zajedno/${createdCode}`)
        }
      })
      .subscribe()
    return () => { supabase.removeChannel(channel) }
  }, [createdCode, waitingForGuest, router])

  async function handleCreate() {
    setCreating(true)
    const supabase = createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { router.push('/auth/prijava'); return }

    let questionIds: string[]
    if (selectedQuiz === 'mix') {
      const { data: all } = await supabase.from('questions').select('id')
      questionIds = (all || []).sort(() => Math.random() - 0.5).map((q: { id: string }) => q.id)
    } else {
      const { data: questions } = await supabase.from('questions').select('id').eq('quiz_id', selectedQuiz)
      questionIds = (questions || []).sort(() => Math.random() - 0.5).map((q: { id: string }) => q.id)
    }

    // Determine format params
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
      quiz_id: selectedQuiz === 'mix' ? null : selectedQuiz,
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

    await supabase.from('game_rooms').update({
      guest_id: user.id,
      status: 'playing',
      game_start_time: new Date().toISOString(),
    }).eq('room_code', code)

    setJoining(false)
    router.push(`/igraj-zajedno/${code}`)
  }

  const allFormats = [...WIN_FORMATS, ...TIME_FORMATS]
  const formatLabels: Record<string, string> = Object.fromEntries(allFormats.map(f => [f.id, f.label]))

  return (
    <div className="min-h-screen bg-[#FAF4EC]">
      <Header />
      <main className="max-w-lg mx-auto px-4 py-10">
        <div className="text-center mb-10">
          <div className="text-5xl mb-4">⚔️</div>
          <h1 className="text-3xl font-bold mb-2" style={{ color: '#2C2D81' }}>Igraj zajedno</h1>
          <p className="text-gray-500">Izazovi prijatelja i vidi ko zna više!</p>
        </div>

        <div className="flex bg-white rounded-2xl p-1 shadow-sm mb-6">
          {(['create', 'join'] as const).map(t => (
            <button key={t} onClick={() => setTab(t)}
              className="flex-1 py-2.5 rounded-xl text-sm font-semibold transition-all"
              style={tab === t ? { background: '#2C2D81', color: 'white' } : { color: '#6b7280' }}>
              {t === 'create' ? '+ Kreiraj sobu' : '→ Pridruži se'}
            </button>
          ))}
        </div>

        {tab === 'create' && (
          <div className="bg-white rounded-3xl shadow-sm overflow-hidden">
            <div className="h-1.5" style={{ background: 'linear-gradient(90deg, #2C2D81, #5DBF94)' }} />
            <div className="p-8">
              {!createdCode ? (
                <>
                  <label className="block text-sm font-semibold text-gray-700 mb-3">Tema kviza</label>
                  <div className="space-y-2 mb-6">
                    {/* Mix option — default */}
                    <button
                      onClick={() => setSelectedQuiz('mix')}
                      className="w-full flex items-center gap-3 px-4 py-3.5 rounded-2xl border-2 text-left transition-all"
                      style={selectedQuiz === 'mix'
                        ? { borderColor: '#2C2D81', background: '#EEF0FF' }
                        : { borderColor: '#e5e7eb', background: 'white' }}>
                      <span className="text-xl">🔀</span>
                      <div className="flex-1">
                        <div className="font-bold text-sm" style={{ color: selectedQuiz === 'mix' ? '#2C2D81' : '#374151' }}>
                          Mix — sve teme
                        </div>
                        <div className="text-xs text-gray-400">Pitanja iz svih kategorija pomešana</div>
                      </div>
                      {selectedQuiz === 'mix' && (
                        <span className="w-5 h-5 rounded-full flex items-center justify-center text-white text-xs flex-shrink-0"
                          style={{ background: '#2C2D81' }}>✓</span>
                      )}
                    </button>

                    {/* Individual quizzes */}
                    <div className="max-h-40 overflow-y-auto space-y-1.5 pr-0.5">
                      {quizzes.map(q => (
                        <button key={q.id} onClick={() => setSelectedQuiz(q.id)}
                          className="w-full flex items-center gap-3 px-4 py-3 rounded-xl border-2 text-left transition-all"
                          style={selectedQuiz === q.id
                            ? { borderColor: '#3766B0', background: '#f0f4ff' }
                            : { borderColor: '#f0f0f0', background: '#fafafa' }}>
                          <span className="text-sm">📚</span>
                          <span className="flex-1 text-sm font-medium truncate"
                            style={{ color: selectedQuiz === q.id ? '#2C2D81' : '#6b7280' }}>
                            {q.title}
                          </span>
                          {selectedQuiz === q.id && (
                            <span className="w-4 h-4 rounded-full flex items-center justify-center text-white text-xs flex-shrink-0"
                              style={{ background: '#3766B0' }}>✓</span>
                          )}
                        </button>
                      ))}
                    </div>
                  </div>

                  <label className="block text-sm font-semibold text-gray-700 mb-3">Format igre</label>

                  <div className="mb-3">
                    <p className="text-xs text-gray-400 font-semibold uppercase tracking-wide mb-2">Pobede</p>
                    <div className="grid grid-cols-3 gap-2">
                      {WIN_FORMATS.map(f => (
                        <button key={f.id} onClick={() => setSelectedFormat(f.id)}
                          className="py-3 rounded-xl text-sm font-bold transition-all border-2"
                          style={selectedFormat === f.id
                            ? { background: '#EEF0FF', borderColor: '#2C2D81', color: '#2C2D81' }
                            : { background: '#F5F6FA', borderColor: 'transparent', color: '#6b7280' }}>
                          {f.label}
                        </button>
                      ))}
                    </div>
                  </div>

                  <div className="mb-6">
                    <p className="text-xs text-gray-400 font-semibold uppercase tracking-wide mb-2">Vremenski</p>
                    <div className="grid grid-cols-3 gap-2">
                      {TIME_FORMATS.map(f => (
                        <button key={f.id} onClick={() => setSelectedFormat(f.id)}
                          className="py-3 rounded-xl text-sm font-bold transition-all border-2"
                          style={selectedFormat === f.id
                            ? { background: '#E8F8F0', borderColor: '#5DBF94', color: '#065f46' }
                            : { background: '#F5F6FA', borderColor: 'transparent', color: '#6b7280' }}>
                          {f.label}
                        </button>
                      ))}
                    </div>
                  </div>

                  {selectedFormat && (
                    <p className="text-xs text-gray-400 text-center mb-4">
                      {allFormats.find(f => f.id === selectedFormat)?.desc}
                    </p>
                  )}

                  <button onClick={handleCreate} disabled={creating || !selectedQuiz}
                    className="w-full py-4 rounded-xl font-bold text-white transition-all disabled:opacity-50 hover:opacity-90"
                    style={{ background: 'linear-gradient(135deg, #2C2D81, #3766B0)' }}>
                    {creating ? 'Kreiranje...' : 'Kreiraj sobu'}
                  </button>
                </>
              ) : (
                <div className="text-center">
                  <p className="text-sm text-gray-500 mb-1">Format: <strong>{formatLabels[selectedFormat]}</strong></p>
                  <p className="text-sm text-gray-500 mb-3">Pošalji ovaj kod prijatelju:</p>
                  <div className="text-5xl font-black py-6 px-8 rounded-2xl mb-4 inline-block"
                    style={{ background: '#EEF0FF', color: '#2C2D81', letterSpacing: '0.25em' }}>
                    {createdCode}
                  </div>
                  <div className="flex items-center gap-2 justify-center mb-6">
                    <div className="w-2 h-2 rounded-full bg-[#5DBF94] animate-pulse" />
                    <p className="text-sm text-gray-500">Čekamo da se prijatelj pridruži...</p>
                  </div>
                  <button onClick={() => navigator.clipboard.writeText(createdCode)}
                    className="px-6 py-2.5 rounded-xl border border-gray-200 text-sm font-medium text-gray-600 hover:bg-gray-50">
                    Kopiraj kod
                  </button>
                </div>
              )}
            </div>
          </div>
        )}

        {tab === 'join' && (
          <div className="bg-white rounded-3xl shadow-sm overflow-hidden">
            <div className="h-1.5" style={{ background: 'linear-gradient(90deg, #5DBF94, #2C2D81)' }} />
            <div className="p-8">
              <label className="block text-sm font-semibold text-gray-700 mb-2">Upiši kod sobe</label>
              <input type="text" value={joinCode} onChange={e => setJoinCode(e.target.value.toUpperCase())}
                onKeyDown={e => e.key === 'Enter' && handleJoin()} placeholder="npr. AB12CD"
                maxLength={6}
                className="w-full px-4 py-4 rounded-xl border border-gray-200 focus:border-[#2C2D81] outline-none text-2xl font-black text-center tracking-[0.3em] uppercase mb-4"
                style={{ color: '#2C2D81' }} />
              {joinError && <div className="bg-red-50 text-red-600 rounded-xl px-4 py-3 text-sm mb-4">{joinError}</div>}
              <button onClick={handleJoin} disabled={joining || joinCode.length < 6}
                className="w-full py-4 rounded-xl font-bold text-white transition-all disabled:opacity-50 hover:opacity-90"
                style={{ background: 'linear-gradient(135deg, #5DBF94, #3766B0)' }}>
                {joining ? 'Spajamo se...' : 'Pridruži se'}
              </button>
            </div>
          </div>
        )}
      </main>
    </div>
  )
}
