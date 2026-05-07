import { createClient } from '@/lib/supabase/server'
import { notFound } from 'next/navigation'
import EditPitanjeForm from './EditPitanjeForm'
import QuestionStatsPanel from './QuestionStatsPanel'

export const dynamic = 'force-dynamic'

export default async function EditPitanjePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const supabase = await createClient()

  const [questionResult, statsResult, logResult] = await Promise.all([
    supabase
      .from('questions')
      .select('id, question_text, options, correct_answer, difficulty, info, tags, is_active, times_shown, times_correct, times_wrong, created_at')
      .eq('id', id)
      .single(),
    supabase
      .from('question_stats')
      .select('log_count, avg_time_ms, min_time_ms, max_time_ms, median_time_ms, log_correct, log_wrong, log_accuracy_pct')
      .eq('question_id', id)
      .maybeSingle(),
    supabase
      .from('question_answer_log')
      .select('picked_idx, was_correct')
      .eq('question_id', id),
  ])

  if (!questionResult.data) notFound()
  const question = questionResult.data
  const stats = statsResult.data
  const logs = logResult.data || []

  // "Most-frequent wrong choice" — count picks per option index where was_correct=false
  const wrongTally: Record<number, number> = {}
  for (const l of logs) {
    if (l.was_correct || l.picked_idx == null) continue
    wrongTally[l.picked_idx] = (wrongTally[l.picked_idx] || 0) + 1
  }
  const topWrong = Object.entries(wrongTally)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 3)
    .map(([idx, count]) => ({ idx: parseInt(idx, 10), count }))

  return (
    <div className="space-y-5">
      <QuestionStatsPanel question={question} stats={stats} topWrong={topWrong} />
      <EditPitanjeForm row={question} />
    </div>
  )
}
