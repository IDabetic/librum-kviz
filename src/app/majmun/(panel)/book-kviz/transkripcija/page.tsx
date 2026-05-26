import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { IconBack } from '@/components/icons'
import TranskripcijaTools, { type FlaggedRow } from './TranskripcijaTools'

export const dynamic = 'force-dynamic'

// Srpsko latinično pismo NEMA Q W X Y. Bilo koje pitanje u Book pulu
// koje sadrži neko od ovih slova u tekstu ili među odgovorima skoro
// sigurno ima netranskribovano strano ime/naslov ("Harry Potter",
// "The Lord of the Rings", "Wuthering Heights"…). Filter pravimo u
// JS-u nad svim redovima — book_questions je mali pul (~par hiljada
// redova), pa je 1MB transfer prihvatljiv i ne treba SQL regex.
const FOREIGN_CHARS = /[QqWwXxYy]/

function hasForeign(text: string): boolean {
  return FOREIGN_CHARS.test(text)
}

// Highlight foreign chars u tekstu — vrati niz delova {text, foreign}
function markForeign(text: string) {
  const parts: { text: string; foreign: boolean }[] = []
  let buf = ''
  let bufForeign = false
  for (const ch of text) {
    const isForeign = FOREIGN_CHARS.test(ch)
    if (isForeign !== bufForeign && buf) {
      parts.push({ text: buf, foreign: bufForeign })
      buf = ''
    }
    buf += ch
    bufForeign = isForeign
  }
  if (buf) parts.push({ text: buf, foreign: bufForeign })
  return parts
}

export default async function TranskripcijaPage() {
  const supabase = await createClient()

  // Učitavanje SVIH book_questions u jednoj rundi — pa filter u JS.
  // Limit visok da pokrije ceo pool (book ima ~800-2000 redova).
  const { data, error } = await supabase
    .from('book_questions')
    .select('id, question_text, options, genre')
    .order('created_at', { ascending: false })
    .limit(10000)

  if (error) {
    return (
      <div className="card-soft p-6 text-[14px]" style={{ color: '#b91c1c' }}>
        Greška pri učitavanju pitanja: {error.message}
      </div>
    )
  }

  type Row = { id: string; question_text: string; options: string[]; genre: string | null }
  const allRows = (data || []) as Row[]
  const flagged: FlaggedRow[] = []
  for (const r of allRows) {
    const opts = Array.isArray(r.options) ? r.options : []
    const textHits = hasForeign(r.question_text)
    const optsHits = opts.some(o => typeof o === 'string' && hasForeign(o))
    if (!textHits && !optsHits) continue
    flagged.push({
      id: r.id,
      genre: r.genre,
      questionParts: markForeign(r.question_text),
      optionsParts: opts.map(o => markForeign(String(o ?? ''))),
      raw: { question_text: r.question_text, options: opts },
    })
  }

  return (
    <div className="max-w-4xl space-y-5">
      <Link href="/majmun/book-kviz"
        className="inline-flex items-center gap-1.5 text-[13px] font-medium transition-opacity hover:opacity-70"
        style={{ color: '#609DED' }}>
        <IconBack size={16} strokeWidth={2.2} /> Sva Book pitanja
      </Link>

      <div>
        <h1 className="font-black tracking-tight" style={{ color: '#343434', fontSize: 'clamp(22px, 4vw, 28px)' }}>
          🔤 Transkripcija stranih imena
        </h1>
        <p className="text-[13px] mt-1 leading-relaxed" style={{ color: '#9C9C9C' }}>
          Srpsko latinično pismo nema slova <strong>Q · W · X · Y</strong>. Svako Book pitanje
          ili odgovor koji ih sadrži najverovatnije ima netranskribovano strano ime
          („Harry Potter” → „Hari Poter”). Detekcija ispod nađe sva takva pitanja, pa onda
          možeš da ih ispraviš ručno, masovnom zamenom, ili AI-asistirano (Claude predlaže).
        </p>
      </div>

      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
        <Stat label="Sva Book pitanja" value={allRows.length} />
        <Stat label="Sumnjivih (sadrže Q/W/X/Y)" value={flagged.length} accent="#b91c1c" />
        <Stat label="Čistih" value={allRows.length - flagged.length} accent="#15803d" />
        <Stat label="% sumnjivih" value={allRows.length ? `${Math.round(100 * flagged.length / allRows.length)}%` : '0%'} />
      </div>

      <TranskripcijaTools flagged={flagged} />
    </div>
  )
}

function Stat({ label, value, accent }: { label: string; value: number | string; accent?: string }) {
  return (
    <div className="card-soft p-4 text-center">
      <p className="font-black text-[20px] tracking-tight" style={{ color: accent || '#343434' }}>{value}</p>
      <p className="text-[10px] mt-1" style={{ color: '#9C9C9C' }}>{label}</p>
    </div>
  )
}
