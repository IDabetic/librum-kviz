import { createClient } from '@/lib/supabase/server'
import Header from '@/components/Header'
import Link from 'next/link'
import { notFound } from 'next/navigation'

const DIFFICULTY_LABEL = { lako: 'Lako', srednje: 'Srednje', tesko: 'Teško' }
const DIFFICULTY_COLOR = { lako: '#5DBF94', srednje: '#FDC361', tesko: '#e05252' }

export default async function QuizDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const supabase = await createClient()

  const { data: quiz } = await supabase
    .from('quizzes')
    .select('*')
    .eq('id', id)
    .single()

  if (!quiz) notFound()

  const { count } = await supabase
    .from('questions')
    .select('*', { count: 'exact', head: true })
    .eq('quiz_id', id)

  const { data: topResults } = await supabase
    .from('quiz_results')
    .select('score, total, time_taken, profiles(first_name, last_name)')
    .eq('quiz_id', id)
    .order('score', { ascending: false })
    .order('time_taken', { ascending: true })
    .limit(5)

  const diff = quiz.difficulty as keyof typeof DIFFICULTY_LABEL

  return (
    <div className="min-h-screen bg-[#F5F6FA]">
      <Header />

      <main className="max-w-3xl mx-auto px-4 py-10">
        {/* Back */}
        <Link href="/kvizovi" className="inline-flex items-center gap-2 text-sm text-gray-500 hover:text-[#2C2D81] mb-6 transition-colors">
          <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M10 3L5 8l5 5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/></svg>
          Nazad na kvizove
        </Link>

        {/* Quiz hero card */}
        <div className="bg-white rounded-2xl overflow-hidden shadow-sm mb-6">
          <div className="h-2" style={{ background: quiz.cover_color || '#2C2D81' }} />
          <div className="p-8">
            <div className="flex items-start justify-between gap-4 mb-4">
              <h1 className="text-3xl font-bold" style={{ color: '#2C2D81' }}>{quiz.title}</h1>
              <span
                className="text-sm font-semibold px-3 py-1.5 rounded-full flex-shrink-0"
                style={{
                  background: `${DIFFICULTY_COLOR[diff] || '#ccc'}20`,
                  color: DIFFICULTY_COLOR[diff] || '#666',
                }}
              >
                {DIFFICULTY_LABEL[diff] || diff}
              </span>
            </div>

            {quiz.description && (
              <p className="text-gray-600 mb-6 leading-relaxed">{quiz.description}</p>
            )}

            <div className="grid grid-cols-3 gap-4 mb-8">
              {[
                { icon: '❓', label: 'Pitanja', value: count || 0 },
                { icon: '📂', label: 'Kategorija', value: quiz.category || '—' },
                { icon: '▶️', label: 'Igranja', value: quiz.plays },
              ].map(({ icon, label, value }) => (
                <div key={label} className="bg-[#F5F6FA] rounded-xl p-4 text-center">
                  <div className="text-2xl mb-1">{icon}</div>
                  <div className="font-bold text-gray-800">{value}</div>
                  <div className="text-xs text-gray-400 mt-0.5">{label}</div>
                </div>
              ))}
            </div>

            <div className="bg-[#EEF0FF] rounded-xl p-4 mb-8">
              <h3 className="font-semibold text-sm mb-2" style={{ color: '#2C2D81' }}>📋 Kako funkcioniše:</h3>
              <ul className="text-sm text-gray-600 space-y-1.5">
                <li>✅ Svako pitanje ima 4 ponuđena odgovora</li>
                <li>⏱️ Imate 30 sekundi po pitanju</li>
                <li>📊 Na kraju vidite vaš rezultat i tačne odgovore</li>
              </ul>
            </div>

            <Link
              href={`/kvizovi/${quiz.id}/igraj`}
              className="flex items-center justify-center gap-2 w-full py-4 rounded-2xl font-bold text-white text-lg transition-all hover:scale-[1.02] shadow-lg"
              style={{ background: 'linear-gradient(135deg, #5DBF94, #45a87c)', boxShadow: '0 8px 24px rgba(93,191,148,0.35)' }}
            >
              ▶ Počni kviz
            </Link>
          </div>
        </div>

        {/* Top results */}
        {topResults && topResults.length > 0 && (
          <div className="bg-white rounded-2xl p-6 shadow-sm">
            <h2 className="font-bold text-lg mb-4" style={{ color: '#2C2D81' }}>🏆 Najbolji rezultati</h2>
            <div className="space-y-3">
              {(topResults as Array<{ score: number; total: number; time_taken: number | null; profiles: { first_name: string; last_name: string } | { first_name: string; last_name: string }[] | null }>).map((r, i) => {
                const profile = Array.isArray(r.profiles) ? r.profiles[0] : r.profiles
                return (
                  <div key={i} className="flex items-center gap-3 py-2 border-b border-gray-50 last:border-0">
                    <span className="w-7 h-7 rounded-full flex items-center justify-center text-sm font-bold"
                      style={{ background: i === 0 ? '#FDC361' : i === 1 ? '#e8e8e8' : i === 2 ? '#f0c59a' : '#F5F6FA', color: '#2C2D81' }}>
                      {i + 1}
                    </span>
                    <span className="flex-1 text-sm font-medium text-gray-700">
                      {profile ? `${profile.first_name} ${profile.last_name}` : 'Igrač'}
                    </span>
                    <span className="font-bold text-sm" style={{ color: '#5DBF94' }}>
                      {r.score}/{r.total}
                    </span>
                    {r.time_taken && (
                      <span className="text-xs text-gray-400">{r.time_taken}s</span>
                    )}
                  </div>
                )
              })}
            </div>
          </div>
        )}
      </main>
    </div>
  )
}
