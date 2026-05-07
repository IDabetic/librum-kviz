import { createClient } from '@/lib/supabase/server'
import { notFound } from 'next/navigation'
import EditKafanaForm from './EditKafanaForm'

export const dynamic = 'force-dynamic'

export default async function EditKafanaPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const supabase = await createClient()
  const { data } = await supabase
    .from('kafana_questions')
    .select('id, question_text, options, correct_answer, difficulty, is_active')
    .eq('id', id)
    .single()
  if (!data) notFound()
  return <EditKafanaForm row={data} />
}
