import { createClient } from '@/lib/supabase/server'
import PredloziList from './PredloziList'

export const dynamic = 'force-dynamic'

export default async function PredloziPage() {
  const supabase = await createClient()

  // FK on submitted_by points at auth.users, not public.profiles, so we
  // can't use a Supabase `profiles(...)` embed here. Pull submissions
  // first, then look up matching profiles by id (auth.users.id == profiles.id).
  const { data: submissions, count } = await supabase
    .from('question_submissions')
    .select('id, question_text, correct_answer, submitted_by, submitter_email, created_at', { count: 'exact' })
    .order('created_at', { ascending: false })
    .limit(100)

  const ids = (submissions || [])
    .map(s => s.submitted_by)
    .filter((v): v is string => !!v)
  const { data: profiles } = ids.length
    ? await supabase.from('profiles').select('id, first_name, nickname').in('id', ids)
    : { data: [] as { id: string; first_name: string | null; nickname: string | null }[] }

  const profileMap = new Map((profiles || []).map(p => [p.id, p]))
  const rows = (submissions || []).map(s => ({
    ...s,
    profile: s.submitted_by ? profileMap.get(s.submitted_by) ?? null : null,
  }))

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

      <PredloziList rows={rows} />
    </div>
  )
}
