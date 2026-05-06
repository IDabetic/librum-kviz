import { createClient } from '@/lib/supabase/server'
import Header from '@/components/Header'
import Link from 'next/link'
import type { Quiz } from '@/types/database'

const DIFFICULTY_LABEL = { lako: 'Lako', srednje: 'Srednje', tesko: 'Teško' }
const DIFFICULTY_COLOR = { lako: '#5DBF94', srednje: '#FDC361', tesko: '#e05252' }

export default async function KvizovPage() {
  const supabase = await createClient()
  const { data: user } = await supabase.auth.getUser()

  const { data: quizzes } = await supabase
    .from('quizzes')
    .select('*, question_count:questions(count)')
    .order('created_at', { ascending: false })

  const { data: profile } = await supabase
    .from('profiles')
    .select('first_name')
    .eq('id', user.user!.id)
    .single()

  const processed = (quizzes || []).map((q: Quiz & { question_count: { count: number }[] }) => ({
    ...q,
    question_count: q.question_count?.[0]?.count ?? 0,
  }))

  const categories = [...new Set(processed.map((q: Quiz) => q.category).filter(Boolean))]

  return (
    <div className="min-h-screen bg-[#FAF4EC]">
      <Header />

      <main className="max-w-6xl mx-auto px-4 py-10">
        {/* Welcome */}
        <div className="mb-10">
          <h1 className="text-3xl font-bold mb-1" style={{ color: '#2C2D81' }}>
            Zdravo, {profile?.first_name || 'igraču'}! 👋
          </h1>
          <p className="text-gray-500">Izaberi kviz i testiraj svoje znanje.</p>
        </div>

        {/* Stats bar */}
        <div className="grid grid-cols-3 gap-4 mb-10">
          {[
            { label: 'Dostupnih kvizova', value: processed.length, color: '#2C2D81', bg: '#EEF0FF' },
            { label: 'Kategorija', value: categories.length, color: '#5DBF94', bg: '#E8F8F0' },
            { label: 'Pitanja ukupno', value: processed.reduce((s: number, q: Quiz) => s + (q.question_count as unknown as number || 0), 0), color: '#FDC361', bg: '#FFF8EC' },
          ].map(({ label, value, color, bg }) => (
            <div key={label} className="bg-white rounded-2xl p-5 shadow-sm">
              <div className="text-3xl font-bold mb-1" style={{ color }}>{value}</div>
              <div className="text-xs text-gray-500">{label}</div>
            </div>
          ))}
        </div>

        {/* Quiz grid */}
        {processed.length === 0 ? (
          <div className="text-center py-20 text-gray-400">
            <div className="text-5xl mb-4">📚</div>
            <p className="text-lg font-medium">Kvizovi se pripremaju...</p>
            <p className="text-sm mt-1">Uskoro dolaze nova pitanja!</p>
          </div>
        ) : (
          <div>
            <h2 className="text-lg font-bold text-gray-700 mb-5">Svi kvizovi</h2>
            <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-5">
              {processed.map((quiz: Quiz) => (
                <QuizCard key={quiz.id} quiz={quiz} />
              ))}
            </div>
          </div>
        )}
      </main>
    </div>
  )
}

function QuizCard({ quiz }: { quiz: Quiz }) {
  const diff = quiz.difficulty as keyof typeof DIFFICULTY_LABEL
  return (
    <Link href={`/kvizovi/${quiz.id}`} className="group">
      <div className="bg-white rounded-2xl overflow-hidden shadow-sm hover:shadow-lg transition-all hover:-translate-y-1 cursor-pointer">
        {/* Color banner */}
        <div className="h-3" style={{ background: quiz.cover_color || '#2C2D81' }} />

        <div className="p-6">
          <div className="flex items-start justify-between gap-2 mb-3">
            <h3 className="font-bold text-gray-800 text-lg leading-snug group-hover:text-[#2C2D81] transition-colors">
              {quiz.title}
            </h3>
            <span
              className="text-xs font-semibold px-2.5 py-1 rounded-full flex-shrink-0"
              style={{
                background: `${DIFFICULTY_COLOR[diff] || '#ccc'}20`,
                color: DIFFICULTY_COLOR[diff] || '#666',
              }}
            >
              {DIFFICULTY_LABEL[diff] || diff}
            </span>
          </div>

          {quiz.description && (
            <p className="text-gray-500 text-sm mb-4 line-clamp-2">{quiz.description}</p>
          )}

          <div className="flex items-center justify-between text-xs text-gray-400 pt-3 border-t border-gray-50">
            <span className="flex items-center gap-1">
              <span>❓</span> {(quiz.question_count as unknown as number) || 0} pitanja
            </span>
            {quiz.category && (
              <span className="flex items-center gap-1">
                <span>📂</span> {quiz.category}
              </span>
            )}
            <span className="flex items-center gap-1">
              <span>▶️</span> {quiz.plays} igranja
            </span>
          </div>
        </div>
      </div>
    </Link>
  )
}
