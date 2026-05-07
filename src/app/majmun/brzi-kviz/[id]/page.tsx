import { createClient } from '@/lib/supabase/server'
import { notFound } from 'next/navigation'
import EditTvrdnja from './EditTvrdnja'

export const dynamic = 'force-dynamic'

export default async function Page({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const supabase = await createClient()
  const { data } = await supabase.from('quick_statements').select('*').eq('id', id).single()
  if (!data) notFound()
  return <EditTvrdnja row={data} />
}
