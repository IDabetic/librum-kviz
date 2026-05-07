import { createClient } from '@/lib/supabase/server'
import Link from 'next/link'
import BrziList from './BrziList'

export const dynamic = 'force-dynamic'

// Brzi-only questions live in the same `questions` table as PRO/Duel
// but are tagged 'brzi-only'. The PRO and Duel loaders explicitly
// filter that tag out, so anything you create here only shows up in
// /brzi-kviz/start.
export const BRZI_ONLY_TAG = 'brzi-only'

export default async function BrziKvizAdminPage() {
  const supabase = await createClient()

  const { data, count } = await supabase
    .from('questions')
    .select('id, question_text, options, correct_answer, difficulty, is_active, created_at', { count: 'exact' })
    .contains('tags', [BRZI_ONLY_TAG])
    .order('created_at', { ascending: false })
    .limit(500)

  const rows = (data ?? []).map(q => ({
    id: q.id,
    question_text: q.question_text,
    options: q.options,
    correct_answer: q.correct_answer,
    difficulty: q.difficulty,
    is_active: q.is_active,
    created_at: q.created_at,
  }))

  return (
    <div className="space-y-5">

      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h1 className="font-black tracking-tight" style={{ color: '#343434', fontSize: 'clamp(22px, 4vw, 28px)' }}>
            Brzi kviz pitanja
          </h1>
          <p className="text-[13px] mt-1" style={{ color: '#9C9C9C' }}>
            {count ?? 0} pitanja samo za Brzi kviz
          </p>
        </div>
        <Link href="/majmun/brzi-kviz/novo" className="btn btn-primary btn-md">
          + Novo Brzi pitanje
        </Link>
      </div>

      <div className="rounded-2xl px-4 py-3 text-[12px] font-medium flex items-start gap-2"
        style={{ background: '#FFECBC', color: '#9c7a13' }}>
        <span className="text-[14px] leading-none mt-px">⚡</span>
        <span>
          Pitanja koja ovde dodaješ <strong>vide se samo u Brzom kvizu</strong>.
          Ne ulaze u PRO kviz ni u Trivia duel. (Tehnički: tag <code>brzi-only</code>.)
          {' '}Brzi kviz takođe pokupi i sva PRO pitanja iz <Link href="/majmun/pitanja" className="underline">Pitanja</Link> sekcije.
        </span>
      </div>

      <BrziList rows={rows} />
    </div>
  )
}
