import { createClient } from '@/lib/supabase/server'
import { notFound } from 'next/navigation'
import EditBrzi from './EditBrzi'

export const dynamic = 'force-dynamic'

export default async function EditBrziPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const supabase = await createClient()
  const { data } = await supabase
    .from('questions')
    .select('id, question_text, options, correct_answer, difficulty, is_active, tags')
    .eq('id', id)
    .single()

  if (!data) notFound()

  return <EditBrzi row={data} />
}
