import { createClient } from '@/lib/supabase/server'
import RangListaTabs from './RangListaTabs'

export const dynamic = 'force-dynamic'

export default async function RangListaAdmin() {
  const supabase = await createClient()

  const [survivor, hangman, quick] = await Promise.all([
    supabase.from('survivor_sessions')
      .select('id, score, questions_reached, accuracy, total_time_seconds, created_at, profiles(first_name, nickname)')
      .order('score', { ascending: false }).limit(100),
    supabase.from('hangman_sessions')
      .select('id, won, score, word, category, created_at, profiles(first_name, nickname)')
      .order('created_at', { ascending: false }).limit(100),
    supabase.from('quick_sessions')
      .select('id, score, correct_count, accuracy, created_at, profiles(first_name, nickname)')
      .order('score', { ascending: false }).limit(100),
  ])

  return (
    <div className="space-y-5">
      <div>
        <h1 className="font-black tracking-tight" style={{ color: '#343434', fontSize: 'clamp(22px, 4vw, 28px)' }}>Rang liste</h1>
        <p className="text-[13px] mt-1" style={{ color: '#9C9C9C' }}>
          Pregled i moderacija sesija. Sumnjive partije se mogu obrisati.
        </p>
      </div>

      <RangListaTabs survivor={survivor.data || []} hangman={hangman.data || []} quick={quick.data || []} />
    </div>
  )
}
