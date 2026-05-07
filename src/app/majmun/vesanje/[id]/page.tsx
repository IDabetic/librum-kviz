import { createClient } from '@/lib/supabase/server'
import { notFound } from 'next/navigation'
import EditPojam from './EditPojam'

export const dynamic = 'force-dynamic'

export default async function Page({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const supabase = await createClient()
  const { data } = await supabase.from('hangman_words').select('*').eq('id', id).single()
  if (!data) notFound()
  return <EditPojam row={data} />
}
