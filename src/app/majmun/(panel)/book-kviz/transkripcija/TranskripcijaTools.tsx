'use client'

import { useState, useMemo } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'

// Three-tab admin tool over the flagged Book questions:
//   🔍 Detekcija  — list flagged rows, edit each manually
//   🔧 Zameni     — bulk find / replace across all Book questions
//   🤖 AI predlog — Claude proposes Serbian transcriptions; admin approves
//
// The detection list is computed server-side and passed in. Everything
// else is client-side state until the admin commits via API.

export type Part = { text: string; foreign: boolean }
export type FlaggedRow = {
  id: string
  genre: string | null
  questionParts: Part[]
  optionsParts: Part[][]
  raw: { question_text: string; options: string[] }
}

type Tab = 'detekcija' | 'zameni' | 'ai'

export default function TranskripcijaTools({ flagged }: { flagged: FlaggedRow[] }) {
  const [tab, setTab] = useState<Tab>('detekcija')

  return (
    <>
      <div className="flex p-1 rounded-full mb-2 overflow-x-auto" style={{ background: '#F2F2F2' }}>
        {([
          { id: 'detekcija', label: `🔍 Detekcija (${flagged.length})` },
          { id: 'zameni',    label: '🔧 Zameni' },
          { id: 'ai',        label: '🤖 AI predlog' },
        ] as { id: Tab; label: string }[]).map(t => (
          <button key={t.id} onClick={() => setTab(t.id)}
            className="flex-1 py-2.5 px-3 rounded-full text-[12px] font-semibold transition-all whitespace-nowrap"
            style={tab === t.id
              ? { background: '#FCFCFC', color: '#343434', boxShadow: '0 2px 8px rgba(52,52,52,0.06)' }
              : { color: '#9C9C9C' }}>
            {t.label}
          </button>
        ))}
      </div>

      {tab === 'detekcija' && <DetectionTab flagged={flagged} />}
      {tab === 'zameni'    && <BulkReplaceTab />}
      {tab === 'ai'        && <AiTab flagged={flagged} />}
    </>
  )
}

// ─── Tab 1: Detection ──────────────────────────────────────────────
function DetectionTab({ flagged }: { flagged: FlaggedRow[] }) {
  if (flagged.length === 0) {
    return (
      <div className="card-soft p-10 text-center text-[15px]" style={{ color: '#15803d' }}>
        🎉 Nijedno Book pitanje ne sadrži strana slova (Q · W · X · Y). Čista baza!
      </div>
    )
  }
  return (
    <div className="card-soft overflow-hidden">
      <div className="divide-y" style={{ borderColor: '#F2F2F2' }}>
        {flagged.map(r => (
          <div key={r.id} className="px-5 py-4">
            <div className="flex items-start justify-between gap-3 mb-2">
              <p className="text-[14px] leading-snug" style={{ color: '#343434' }}>
                <RenderParts parts={r.questionParts} />
              </p>
              <Link href={`/majmun/book-kviz/${r.id}`}
                className="btn btn-secondary btn-sm flex-shrink-0"
                style={{ background: '#BCD9FF', color: '#1e5fa4' }}>
                ✎ Uredi
              </Link>
            </div>
            <div className="grid grid-cols-2 gap-1.5 text-[12px]">
              {r.optionsParts.map((opt, i) => (
                <div key={i} className="rounded-lg px-2 py-1.5"
                  style={{ background: i === 0 ? '#E8F8F0' : '#F2F2F2' }}>
                  <span style={{ color: i === 0 ? '#15803d' : '#343434', fontWeight: i === 0 ? 600 : 400 }}>
                    <RenderParts parts={opt} />
                  </span>
                </div>
              ))}
            </div>
            {r.genre && (
              <p className="text-[10px] mt-2" style={{ color: '#9C9C9C' }}>
                Žanr: {r.genre} · ID: {r.id.substring(0, 8)}…
              </p>
            )}
          </div>
        ))}
      </div>
    </div>
  )
}

function RenderParts({ parts }: { parts: Part[] }) {
  return (
    <>
      {parts.map((p, i) => p.foreign
        ? <mark key={i} style={{ background: '#FEE2E2', color: '#b91c1c', padding: '0 2px', borderRadius: 3 }}>{p.text}</mark>
        : <span key={i}>{p.text}</span>)}
    </>
  )
}

// ─── Tab 2: Bulk find & replace ────────────────────────────────────
type ReplaceScope = 'both' | 'question' | 'options'
type ReplacePreview = {
  total_matches: number
  rows_affected: number
  sample: { id: string; before: string; after: string }[]
}
type ReplaceResult = { ok: boolean; error?: string; rows_affected?: number; total_replacements?: number }

function BulkReplaceTab() {
  const router = useRouter()
  const [find, setFind] = useState('')
  const [replace, setReplace] = useState('')
  const [scope, setScope] = useState<ReplaceScope>('both')
  const [caseSensitive, setCaseSensitive] = useState(true)
  const [preview, setPreview] = useState<ReplacePreview | null>(null)
  const [result, setResult] = useState<ReplaceResult | null>(null)
  const [busy, setBusy] = useState<'preview' | 'apply' | null>(null)

  async function call(dryRun: boolean) {
    if (!find) return
    setBusy(dryRun ? 'preview' : 'apply')
    setResult(null)
    if (dryRun) setPreview(null)
    try {
      const res = await fetch('/api/admin/book-questions-bulk-replace', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ find, replace, scope, caseSensitive, dryRun }),
      })
      const json = await res.json()
      if (!json.ok) {
        setResult({ ok: false, error: json.error || 'unknown' })
        return
      }
      if (dryRun) setPreview(json as ReplacePreview)
      else { setResult(json as ReplaceResult); router.refresh() }
    } catch {
      setResult({ ok: false, error: 'network' })
    } finally {
      setBusy(null)
    }
  }

  return (
    <div className="card-soft p-6 space-y-4">
      <p className="text-[13px] leading-relaxed" style={{ color: '#9C9C9C' }}>
        Pronađi tekst (npr. <code className="font-mono">Harry Potter</code>) i zameni ga
        srpskom transkripcijom (<code className="font-mono">Hari Poter</code>) u svim Book
        pitanjima odjednom. <strong>Uvek prvo pokreni Pregled</strong> da vidiš šta će biti
        izmenjeno pre primene.
      </p>

      <div className="grid sm:grid-cols-2 gap-3">
        <div>
          <label className="text-[12px] font-semibold mb-1 block" style={{ color: '#343434' }}>Pronađi</label>
          <input className="input" value={find} onChange={e => { setFind(e.target.value); setPreview(null); setResult(null) }}
            placeholder="Harry Potter" />
        </div>
        <div>
          <label className="text-[12px] font-semibold mb-1 block" style={{ color: '#343434' }}>Zameni sa</label>
          <input className="input" value={replace} onChange={e => { setReplace(e.target.value); setPreview(null); setResult(null) }}
            placeholder="Hari Poter" />
        </div>
      </div>

      <div className="flex flex-wrap gap-3 items-center">
        <div>
          <label className="text-[12px] font-semibold mr-2" style={{ color: '#343434' }}>Polja:</label>
          <select className="input" style={{ width: 'auto', display: 'inline-block' }}
            value={scope} onChange={e => setScope(e.target.value as ReplaceScope)}>
            <option value="both">Pitanje + odgovori</option>
            <option value="question">Samo pitanje</option>
            <option value="options">Samo odgovori</option>
          </select>
        </div>
        <label className="text-[12px] flex items-center gap-2" style={{ color: '#343434' }}>
          <input type="checkbox" checked={caseSensitive} onChange={e => setCaseSensitive(e.target.checked)} />
          Razlikuj velika/mala slova
        </label>
      </div>

      <div className="flex gap-2 pt-2">
        <button onClick={() => call(true)} disabled={!find || busy !== null}
          className="btn btn-secondary btn-md">
          {busy === 'preview' ? 'Pretražujem…' : '🔍 Pregled'}
        </button>
        {preview && preview.rows_affected > 0 && (
          <button onClick={() => {
            if (!confirm(`Stvarno primeniti zamenu na ${preview.rows_affected} redova? Ovo se ne može lako poništiti.`)) return
            call(false)
          }} disabled={busy !== null}
            className="btn btn-md" style={{ background: '#b91c1c', color: 'white' }}>
            {busy === 'apply' ? 'Primenjujem…' : `✓ Primeni na ${preview.rows_affected} redova`}
          </button>
        )}
      </div>

      {preview && (
        <div className="rounded-2xl px-4 py-3 text-[13px]"
          style={{ background: '#FFECBC', color: '#9c7a13' }}>
          <p className="font-bold mb-2">📋 Pregled</p>
          <p>• Ukupno pojavljivanja: <strong>{preview.total_matches}</strong></p>
          <p>• Redova koji bi bili izmenjeni: <strong>{preview.rows_affected}</strong></p>
          {preview.rows_affected === 0 && <p className="mt-1">Nijedan red ne sadrži taj tekst.</p>}
          {preview.sample.length > 0 && (
            <details className="mt-2">
              <summary className="cursor-pointer font-semibold">Primeri ({preview.sample.length})</summary>
              <div className="mt-2 space-y-2 text-[12px]">
                {preview.sample.map(s => (
                  <div key={s.id} className="rounded-lg px-2 py-1.5" style={{ background: 'rgba(252,252,252,0.6)' }}>
                    <p style={{ color: '#b91c1c' }}>− {s.before}</p>
                    <p style={{ color: '#15803d' }}>+ {s.after}</p>
                  </div>
                ))}
              </div>
            </details>
          )}
        </div>
      )}

      {result && (
        <div className="rounded-2xl px-4 py-3 text-[13px]"
          style={result.ok
            ? { background: '#E8F8F0', color: '#15803d' }
            : { background: '#FEE2E2', color: '#b91c1c' }}>
          {result.ok
            ? <>✓ Primenjeno. Redova izmenjeno: <strong>{result.rows_affected}</strong> · ukupno zamena: <strong>{result.total_replacements}</strong></>
            : <>✗ Greška: {result.error}</>}
        </div>
      )}
    </div>
  )
}

// ─── Tab 3: AI-assisted ────────────────────────────────────────────
type Suggestion = {
  id: string
  question_text: string
  options: string[]
  changed: boolean
}
type AiResponse = { ok: boolean; error?: string; suggestions?: Suggestion[] }

function AiTab({ flagged }: { flagged: FlaggedRow[] }) {
  const router = useRouter()
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const [busy, setBusy] = useState<'fetch' | 'apply' | null>(null)
  const [error, setError] = useState('')
  const [suggestions, setSuggestions] = useState<Suggestion[]>([])
  const [approved, setApproved] = useState<Set<string>>(new Set())

  const flaggedById = useMemo(() => {
    const m = new Map<string, FlaggedRow>()
    for (const f of flagged) m.set(f.id, f)
    return m
  }, [flagged])

  function toggle(id: string) {
    setSelected(s => {
      const next = new Set(s)
      if (next.has(id)) next.delete(id); else next.add(id)
      return next
    })
  }
  function toggleAll() {
    if (selected.size === flagged.length) setSelected(new Set())
    else setSelected(new Set(flagged.map(f => f.id)))
  }

  async function fetchSuggestions() {
    if (selected.size === 0 || busy) return
    setBusy('fetch'); setError(''); setSuggestions([]); setApproved(new Set())
    try {
      const res = await fetch('/api/admin/book-questions-ai-translate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ids: [...selected] }),
      })
      const json = (await res.json()) as AiResponse
      if (!json.ok) { setError(json.error || 'unknown'); return }
      setSuggestions(json.suggestions || [])
      // Default-select all changed suggestions
      setApproved(new Set((json.suggestions || []).filter(s => s.changed).map(s => s.id)))
    } catch { setError('network') } finally { setBusy(null) }
  }

  async function applyApproved() {
    if (approved.size === 0 || busy) return
    if (!confirm(`Primeniti AI predloge za ${approved.size} pitanja?`)) return
    setBusy('apply'); setError('')
    const toApply = suggestions.filter(s => approved.has(s.id))
    try {
      const res = await fetch('/api/admin/book-questions-apply-edits', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ edits: toApply.map(s => ({ id: s.id, question_text: s.question_text, options: s.options })) }),
      })
      const json = await res.json()
      if (!json.ok) { setError(json.error || 'unknown'); return }
      // Success — clear and refresh
      setSuggestions([]); setApproved(new Set()); setSelected(new Set())
      router.refresh()
    } catch { setError('network') } finally { setBusy(null) }
  }

  function toggleApprove(id: string) {
    setApproved(a => {
      const next = new Set(a)
      if (next.has(id)) next.delete(id); else next.add(id)
      return next
    })
  }

  return (
    <div className="space-y-4">

      <div className="card-soft p-6">
        <p className="text-[13px] leading-relaxed mb-4" style={{ color: '#9C9C9C' }}>
          Selektuj sumnjiva pitanja, klikni „Zatraži AI predlog” i Claude će predložiti srpsku
          transkripciju za svako (zadržava značenje, samo transkribuje strana imena/naslove
          po pravilima srpske latinice). Vidiš diff pre primene — odobravaš ručno.
          <br /><br />
          ⚠️ Zahteva <code>ANTHROPIC_API_KEY</code> u Vercel env. Trošak ~$0.02 po 10 pitanja.
        </p>

        <div className="flex items-center justify-between mb-3 pb-3 border-b" style={{ borderColor: '#F2F2F2' }}>
          <button onClick={toggleAll} className="text-[12px] font-semibold underline"
            style={{ color: '#609DED' }}>
            {selected.size === flagged.length ? 'Poništi sve' : `Selektuj sva (${flagged.length})`}
          </button>
          <button onClick={fetchSuggestions} disabled={selected.size === 0 || busy !== null}
            className="btn btn-primary btn-sm">
            {busy === 'fetch' ? 'AI razmišlja…' : `🤖 Zatraži AI predlog (${selected.size})`}
          </button>
        </div>

        <div className="max-h-96 overflow-y-auto -mx-2">
          {flagged.map(r => {
            const checked = selected.has(r.id)
            return (
              <label key={r.id} className="flex items-start gap-3 px-3 py-2 rounded-lg cursor-pointer hover:bg-[#F2F2F2]">
                <input type="checkbox" checked={checked} onChange={() => toggle(r.id)}
                  className="mt-0.5 flex-shrink-0" />
                <span className="text-[12px] leading-snug" style={{ color: '#343434' }}>
                  <RenderParts parts={r.questionParts} />
                </span>
              </label>
            )
          })}
        </div>
      </div>

      {error && (
        <div className="rounded-2xl px-4 py-3 text-[13px]" style={{ background: '#FEE2E2', color: '#b91c1c' }}>
          ✗ Greška: {error}
        </div>
      )}

      {suggestions.length > 0 && (
        <div className="card-soft p-6">
          <div className="flex items-center justify-between mb-4 pb-3 border-b" style={{ borderColor: '#F2F2F2' }}>
            <p className="font-bold text-[15px]" style={{ color: '#343434' }}>
              📝 AI predlozi ({suggestions.filter(s => s.changed).length} promenjenih od {suggestions.length})
            </p>
            <button onClick={applyApproved} disabled={approved.size === 0 || busy !== null}
              className="btn btn-md" style={{ background: '#15803d', color: 'white' }}>
              {busy === 'apply' ? 'Primenjujem…' : `✓ Primeni ${approved.size} odobrenih`}
            </button>
          </div>

          <div className="space-y-3 max-h-[600px] overflow-y-auto">
            {suggestions.map(s => {
              const orig = flaggedById.get(s.id)
              if (!orig) return null
              const isApproved = approved.has(s.id)
              return (
                <div key={s.id} className={`rounded-2xl p-4 border-2 transition-all ${s.changed ? '' : 'opacity-50'}`}
                  style={{ borderColor: isApproved ? '#15803d' : 'rgba(52,52,52,0.10)', background: '#FCFCFC' }}>
                  <div className="flex items-start gap-3 mb-2">
                    <input type="checkbox" checked={isApproved} disabled={!s.changed}
                      onChange={() => toggleApprove(s.id)} className="mt-1 flex-shrink-0" />
                    <div className="flex-1 min-w-0">
                      <p className="text-[12px] mb-1" style={{ color: '#b91c1c' }}>
                        − {orig.raw.question_text}
                      </p>
                      <p className="text-[12px]" style={{ color: '#15803d' }}>
                        + {s.question_text}
                      </p>
                    </div>
                  </div>
                  <div className="grid grid-cols-2 gap-1.5 mt-2 pl-7">
                    {orig.raw.options.map((o, i) => {
                      const newOpt = s.options[i] ?? ''
                      const changed = o !== newOpt
                      return (
                        <div key={i} className="text-[11px] rounded px-2 py-1"
                          style={{ background: i === 0 ? '#E8F8F0' : '#F2F2F2' }}>
                          {changed ? (
                            <>
                              <span style={{ color: '#b91c1c' }}>− {o}</span><br />
                              <span style={{ color: '#15803d' }}>+ {newOpt}</span>
                            </>
                          ) : (
                            <span style={{ color: '#9C9C9C' }}>{o}</span>
                          )}
                        </div>
                      )
                    })}
                  </div>
                  {!s.changed && (
                    <p className="text-[11px] mt-2 pl-7" style={{ color: '#9C9C9C' }}>
                      (AI nije našao šta da promeni)
                    </p>
                  )}
                </div>
              )
            })}
          </div>
        </div>
      )}
    </div>
  )
}
