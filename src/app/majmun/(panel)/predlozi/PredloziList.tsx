'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { IconCheck, IconWrong } from '@/components/icons'

type Profile = { first_name: string | null; nickname: string | null }
type Row = {
  id: string
  question_text: string
  correct_answer: string
  submitted_by: string | null
  submitter_email: string | null
  created_at: string
  profile: Profile | null
}

export default function PredloziList({ rows }: { rows: Row[] }) {
  const router = useRouter()
  const [busy, setBusy] = useState<string | null>(null)
  const [openId, setOpenId] = useState<string | null>(null)

  async function reject(id: string) {
    if (!confirm('Odbiti i obrisati ovaj predlog?')) return
    setBusy(id)
    await createClient().from('question_submissions').delete().eq('id', id)
    setBusy(null); router.refresh()
  }

  if (rows.length === 0) {
    return (
      <div className="card-soft py-16 text-center">
        <p className="font-bold text-[16px] mb-2" style={{ color: '#343434' }}>Nema predloga</p>
        <p className="text-[13px]" style={{ color: '#9C9C9C' }}>Korisnici još nisu poslali predlog.</p>
      </div>
    )
  }

  return (
    <div className="space-y-3">
      {rows.map(r => {
        const submitter = r.profile?.nickname || r.profile?.first_name || r.submitter_email || 'Anon'
        const isOpen = openId === r.id
        return (
          <div key={r.id} className="card-soft p-5 sm:p-6">
            <div className="flex items-start justify-between gap-3 mb-3">
              <div className="min-w-0 flex-1">
                <p className="text-[11px] font-bold uppercase tracking-widest mb-1" style={{ color: '#9C9C9C' }}>
                  Predlog · {new Date(r.created_at).toLocaleDateString('sr')}
                </p>
                <p className="text-[14px]" style={{ color: '#9C9C9C' }}>{submitter}</p>
              </div>
              <button onClick={() => setOpenId(isOpen ? null : r.id)}
                className="text-[12px] font-semibold transition-opacity hover:opacity-70"
                style={{ color: '#609DED' }}>
                {isOpen ? 'Zatvori' : 'Pretvori u pitanje →'}
              </button>
            </div>

            <p className="font-bold text-[15px] mb-2" style={{ color: '#343434' }}>
              {r.question_text}
            </p>
            <div className="rounded-2xl px-4 py-3 mb-3" style={{ background: '#E8F8F0' }}>
              <p className="text-[11px] font-bold uppercase tracking-widest" style={{ color: '#15803d' }}>Tačan odgovor</p>
              <p className="font-bold text-[14px] mt-1" style={{ color: '#15803d' }}>{r.correct_answer}</p>
            </div>

            {isOpen && (
              <ConvertForm row={r} onSuccess={() => { setOpenId(null); router.refresh() }} />
            )}

            <div className="flex gap-2 mt-3">
              <button onClick={() => reject(r.id)} disabled={busy === r.id}
                className="btn btn-md flex-1" style={{ background: '#FEE2E2', color: '#b91c1c' }}>
                <IconWrong size={14} /> Odbij
              </button>
            </div>
          </div>
        )
      })}
    </div>
  )
}

function ConvertForm({ row, onSuccess }: { row: Row; onSuccess: () => void }) {
  const [w1, setW1] = useState('')
  const [w2, setW2] = useState('')
  const [w3, setW3] = useState('')
  const [info, setInfo] = useState('')
  const [difficulty, setDifficulty] = useState('medium')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  async function accept() {
    setError('')
    if (!w1.trim() || !w2.trim() || !w3.trim()) {
      setError('Sva 3 pogrešna odgovora moraju biti popunjena.')
      return
    }
    const opts = [row.correct_answer.trim(), w1.trim(), w2.trim(), w3.trim()]
    if (new Set(opts.map(o => o.toLowerCase())).size !== 4) {
      setError('Odgovori ne smeju biti identični.'); return
    }

    setBusy(true)
    const supabase = createClient()
    const { error: e } = await supabase.from('questions').insert({
      question_text: row.question_text,
      options: opts,
      correct_answer: 0,
      difficulty,
      info: info.trim() || null,
      is_active: true,
    })
    if (e) { setError(e.message); setBusy(false); return }
    // Delete from submissions
    await supabase.from('question_submissions').delete().eq('id', row.id)
    setBusy(false)
    onSuccess()
  }

  return (
    <div className="rounded-2xl p-4 mt-3" style={{ background: '#F2F2F2' }}>
      <p className="text-[11px] font-bold uppercase tracking-widest mb-3" style={{ color: '#9C9C9C' }}>
        Dopuni za PRO kviz format
      </p>

      {error && <div className="rounded-xl px-3 py-2 text-[12px] mb-3" style={{ background: '#FEE2E2', color: '#b91c1c' }}>{error}</div>}

      <div className="space-y-2 mb-3">
        <input value={w1} onChange={e => setW1(e.target.value)} className="input" placeholder="Pogrešan 1" />
        <input value={w2} onChange={e => setW2(e.target.value)} className="input" placeholder="Pogrešan 2" />
        <input value={w3} onChange={e => setW3(e.target.value)} className="input" placeholder="Pogrešan 3" />
      </div>

      <textarea value={info} onChange={e => setInfo(e.target.value)} className="input resize-none mb-3" rows={2}
        placeholder="Objašnjenje (opciono)" />

      <select value={difficulty} onChange={e => setDifficulty(e.target.value)} className="input mb-3">
        <option value="easy">Lako</option>
        <option value="medium">Srednje</option>
        <option value="hard">Teško</option>
        <option value="impossible">Nemoguće</option>
      </select>

      <button onClick={accept} disabled={busy} className="btn btn-md w-full" style={{ background: '#4CAF50', color: 'white' }}>
        <IconCheck size={14} className="text-white" />
        {busy ? 'Prihvatanje…' : 'Prihvati i dodaj u bazu'}
      </button>
    </div>
  )
}
