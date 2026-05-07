import { createClient } from '@/lib/supabase/server'
import { notFound } from 'next/navigation'
import EditPitanjeForm from './EditPitanjeForm'

export const dynamic = 'force-dynamic'

export default async function EditPitanjePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const supabase = await createClient()
  const { data } = await supabase
    .from('questions')
    .select('id, question_text, options, correct_answer, difficulty, info, tags, is_active, times_shown, times_correct, times_wrong, created_at')
    .eq('id', id)
    .single()
  if (!data) notFound()
  return <EditPitanjeForm row={data} />
}
