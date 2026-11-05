import Link from 'next/link'
import { notFound } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import IzmenaPitanjaStruke from './IzmenaPitanjaStruke'

export const dynamic = 'force-dynamic'

export default async function PitanjeStrukePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  if (!/^[0-9a-f-]{36}$/i.test(id)) notFound()
  const supabase = await createClient()
  const [{ data }, { data: prijave }, { data: pozicije }] = await Promise.all([
    supabase.rpc('admin_karijera_pitanja', { p_id: id, p_broj: 1 }),
    supabase.from('question_reports').select('id, reason, status, created_at').eq('question_id', id).order('created_at', { ascending: false }),
    supabase.from('karijera_pozicije').select('id, naziv'),
  ])
  const struka = (pozicije ?? []).find(p => p.id === (data ?? [])[0]?.pozicija)?.naziv
  const pitanje = (data ?? [])[0]
  if (!pitanje) notFound()

  return (
    <div className="max-w-3xl space-y-5">
      <Link href="/majmun/karijera/pitanja" className="text-[13px] font-medium hover:underline" style={{ color: '#12907E' }}>← Pitanja struka</Link>
      <div>
        <h1 className="font-black tracking-tight" style={{ color: '#151515', fontSize: 'clamp(22px, 4vw, 28px)' }}>Izmeni pitanje struke</h1>
        <p className="text-[12px] mt-1" style={{ color: '#6F6C66' }}>Struka: {struka ?? pitanje.pozicija} · teme: {(pitanje.tags ?? []).join(', ') || '—'}</p>
      </div>
      <IzmenaPitanjaStruke pitanje={pitanje} prijave={prijave ?? []} />
    </div>
  )
}
