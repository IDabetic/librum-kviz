'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'

// Excel import for the public.questions pool (PRO + Brzi + Duel).
// Shuffle tools live separately at /majmun/pitanja/mesanje so the two
// concerns don't share a page — admin can run either without scrolling
// past the other.

type ImportStats = {
  total: number
  valid: number
  invalid: number
  dupe_against_db: number
  dupe_in_file: number
  inserted: number
}
type ImportResult = {
  ok: boolean
  error?: string
  detail?: string
  stats?: ImportStats
  invalidRowsSample?: { rowNum: number; reason: string }[]
}

export default function UvozTools() {
  const router = useRouter()

  const [file, setFile] = useState<File | null>(null)
  const [importing, setImporting] = useState(false)
  const [importResult, setImportResult] = useState<ImportResult | null>(null)

  async function runImport(e: React.FormEvent) {
    e.preventDefault()
    if (!file || importing) return
    setImporting(true)
    setImportResult(null)
    try {
      const fd = new FormData()
      fd.append('file', file)
      const res = await fetch('/api/admin/questions-import', { method: 'POST', body: fd })
      const json = (await res.json()) as ImportResult
      setImportResult(json)
      if (json.ok) router.refresh()
    } catch {
      setImportResult({ ok: false, error: 'network' })
    } finally {
      setImporting(false)
    }
  }

  return (
    <section className="card-soft p-6">
      <h2 className="font-bold text-[16px] mb-2 tracking-tight" style={{ color: '#343434' }}>
        📥 Uvoz pitanja iz Excel-a
      </h2>
      <p className="text-[13px] mb-4 leading-relaxed" style={{ color: '#9C9C9C' }}>
        Excel mora imati ove kolone (prvi red su nazivi, redosled bilo koji):
      </p>

      <div className="rounded-2xl p-4 mb-4 text-[12px] font-mono leading-relaxed"
        style={{ background: '#F2F2F2', color: '#343434' }}>
        <div><strong>Pitanje</strong> · <strong>Tačan odgovor</strong> · <strong>Netačno</strong> · <strong>Netačno_1</strong> · <strong>Netačno_2</strong></div>
      </div>

      <ul className="text-[12px] space-y-1 mb-5 leading-relaxed list-disc pl-5" style={{ color: '#9C9C9C' }}>
        <li>Tačan odgovor se u bazi uvek čuva na indeksu 0 — igre nasumično razbacuju redosled u runtime-u.</li>
        <li>Pitanja koja već postoje u bazi (po tekstu) se preskaču.</li>
        <li>Pitanja sa praznim kolonama ili identičnim odgovorima se preskaču i prijavljuju.</li>
        <li>Max veličina fajla: 10 MB (~50,000 redova).</li>
      </ul>

      <form onSubmit={runImport} className="flex flex-col sm:flex-row gap-3 items-stretch sm:items-center">
        <input
          type="file"
          accept=".xlsx,.xls,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
          onChange={e => { setFile(e.target.files?.[0] ?? null); setImportResult(null) }}
          className="flex-1 text-[13px]"
        />
        <button type="submit" disabled={!file || importing} className="btn btn-primary btn-md whitespace-nowrap">
          {importing ? 'Uvozim…' : 'Uvezi pitanja'}
        </button>
      </form>

      {importResult && <ImportResultPanel result={importResult} />}
    </section>
  )
}

function ImportResultPanel({ result }: { result: ImportResult }) {
  if (!result.ok) {
    return (
      <div className="mt-5 rounded-2xl px-4 py-3 text-[13px]"
        style={{ background: '#FEE2E2', color: '#b91c1c' }}>
        ✗ Greška: <strong>{result.error}</strong>
        {result.detail && <div className="mt-1 text-[11px] opacity-80">{result.detail}</div>}
        {result.invalidRowsSample && result.invalidRowsSample.length > 0 && (
          <div className="mt-2 text-[11px]">
            Problematični redovi: {result.invalidRowsSample.map(r => `red ${r.rowNum} (${r.reason})`).join(', ')}
          </div>
        )}
      </div>
    )
  }
  const s = result.stats!
  return (
    <div className="mt-5 rounded-2xl px-4 py-3 text-[13px]"
      style={{ background: '#E8F8F0', color: '#15803d' }}>
      <p className="font-bold mb-2">✓ Uvoz završen</p>
      <ul className="text-[12px] space-y-1 leading-relaxed">
        <li>📄 Redova u fajlu: <strong>{s.total}</strong></li>
        <li>✓ Validnih pitanja: <strong>{s.valid}</strong></li>
        {s.invalid > 0 && <li>⚠ Nevalidnih (preskočeno): <strong>{s.invalid}</strong></li>}
        {s.dupe_against_db > 0 && <li>♻ Već postoji u bazi: <strong>{s.dupe_against_db}</strong></li>}
        {s.dupe_in_file > 0 && <li>♻ Duplikati u samom fajlu: <strong>{s.dupe_in_file}</strong></li>}
        <li className="pt-1 border-t mt-2" style={{ borderColor: 'rgba(21,128,61,0.2)' }}>
          ➕ <strong>Dodato u bazu: {s.inserted}</strong>
        </li>
      </ul>
      {result.invalidRowsSample && result.invalidRowsSample.length > 0 && (
        <details className="mt-3 text-[11px] opacity-90">
          <summary className="cursor-pointer">Vidi prvih {result.invalidRowsSample.length} problematičnih redova</summary>
          <ul className="mt-2 space-y-0.5 pl-3">
            {result.invalidRowsSample.map((r, i) => (
              <li key={i}>red {r.rowNum}: {r.reason}</li>
            ))}
          </ul>
        </details>
      )}
    </div>
  )
}
