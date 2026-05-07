type Question = {
  id: string
  question_text: string
  options: string[]
  correct_answer: number
}

type Stats = {
  log_count: number
  avg_time_ms: number | null
  min_time_ms: number | null
  max_time_ms: number | null
  median_time_ms: number | null
  log_correct: number
  log_wrong: number
  log_accuracy_pct: number | null
}

type TopWrong = { idx: number; count: number }

function fmtMs(ms: number | null | undefined): string {
  if (ms == null) return '—'
  return `${(ms / 1000).toFixed(1)}s`
}

export default function QuestionStatsPanel({
  question, stats, topWrong,
}: { question: Question; stats: Stats | null; topWrong: TopWrong[] }) {
  const total = stats?.log_count || 0
  const acc = stats?.log_accuracy_pct
  const wrongPickPct = (idx: number, count: number) =>
    stats && stats.log_wrong > 0 ? Math.round((count / stats.log_wrong) * 100) : 0

  return (
    <div className="card-soft p-6">
      <div className="flex items-center justify-between mb-4 flex-wrap gap-2">
        <h2 className="font-bold text-[15px] tracking-tight" style={{ color: '#343434' }}>
          Statistika pitanja
        </h2>
        {total === 0 && (
          <span className="text-[11px]" style={{ color: '#9C9C9C' }}>
            Još nema odgovora — sačekaj da igrači odgovore.
          </span>
        )}
      </div>

      <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 mb-4">
        <Stat label="Odgovora" value={total} />
        <Stat label="Tačnost" value={acc != null ? `${acc}%` : '—'}
          tone={acc != null ? (acc > 90 ? 'warn' : acc < 20 ? 'bad' : 'ok') : undefined} />
        <Stat label="Prosečno vreme" value={fmtMs(stats?.avg_time_ms ?? null)}
          tone={stats?.avg_time_ms != null && stats.avg_time_ms > 12000 ? 'warn' : undefined} />
        <Stat label="Medijana" value={fmtMs(stats?.median_time_ms ?? null)} />
        <Stat label="Najbrže" value={fmtMs(stats?.min_time_ms ?? null)} />
        <Stat label="Najsporije" value={fmtMs(stats?.max_time_ms ?? null)} />
        <Stat label="Tačnih" value={stats?.log_correct ?? 0} tone="ok" />
        <Stat label="Pogrešnih" value={stats?.log_wrong ?? 0} tone="bad" />
      </div>

      {topWrong.length > 0 && (
        <div>
          <p className="text-[11px] font-bold uppercase tracking-widest mb-2" style={{ color: '#9C9C9C' }}>
            Najčešći pogrešni odgovori
          </p>
          <div className="space-y-1.5">
            {topWrong.map(({ idx, count }) => {
              const opt = question.options[idx] ?? `Opcija ${idx}`
              const pct = wrongPickPct(idx, count)
              return (
                <div key={idx} className="flex items-center gap-3 text-[13px]" style={{ color: '#343434' }}>
                  <span className="font-mono text-[11px] flex-shrink-0" style={{ color: '#9C9C9C' }}>
                    #{idx}
                  </span>
                  <span className="flex-1 truncate">{opt}</span>
                  <span className="font-bold flex-shrink-0" style={{ color: '#b91c1c' }}>
                    {count} ({pct}%)
                  </span>
                </div>
              )
            })}
          </div>
        </div>
      )}
    </div>
  )
}

function Stat({ label, value, tone }: {
  label: string; value: number | string; tone?: 'ok' | 'warn' | 'bad'
}) {
  const color =
    tone === 'ok'   ? '#15803d' :
    tone === 'warn' ? '#9c7a13' :
    tone === 'bad'  ? '#b91c1c' :
                      '#343434'
  return (
    <div className="rounded-2xl p-3 text-center" style={{ background: '#F2F2F2' }}>
      <div className="font-black text-[16px] tracking-tight" style={{ color }}>{value}</div>
      <div className="text-[10px] mt-0.5" style={{ color: '#9C9C9C' }}>{label}</div>
    </div>
  )
}
