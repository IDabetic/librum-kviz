import { createClient } from '@/lib/supabase/server'
import { notFound } from 'next/navigation'
import EditBookForm from './EditBookForm'

export const dynamic = 'force-dynamic'

export default async function EditBookPitanjePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const supabase = await createClient()
  const { data } = await supabase
    .from('book_questions')
    .select('id, genre, question_text, options, correct_answer, is_active, times_shown, times_correct, times_wrong, created_at')
    .eq('id', id)
    .single()
  if (!data) notFound()
  return <EditBookForm row={data} />
}
