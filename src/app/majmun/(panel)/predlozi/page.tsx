import { createClient } from '@/lib/supabase/server'
import PredloziList from './PredloziList'

export const dynamic = 'force-dynamic'

export default async function PredloziPage() {
  const supabase = await createClient()
  const { data, count } = await supabase
    .from('question_submissions')
    .select('id, question_text, correct_answer, submitted_by, submitter_email, created_at, profiles(first_name, nickname)', { count: 'exact' })
    .order('created_at', { ascending: false })
    .limit(100)

  return (
    <div className="space-y-5">
      <div>
        <h1 className="font-black tracking-tight" style={{ color: '#343434', fontSize: 'clamp(22px, 4vw, 28px)' }}>
          Korisnički predlozi
        </h1>
        <p className="text-[13px] mt-1" style={{ color: '#9C9C9C' }}>
          {count ?? 0} predloga · Pregledaj i prebaci u glavnu bazu pitanja.
        </p>
      </div>

      <PredloziList rows={data || []} />
    </div>
  )
}
