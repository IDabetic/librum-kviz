import { createClient } from '@/lib/supabase/server'
import Header from '@/components/Header'
import Link from 'next/link'
import { redirect } from 'next/navigation'
import type { Quiz } from '@/types/database'
import { IconDiscover, IconStar, IconTime } from '@/components/icons'

const DIFFICULTY_LABEL: Record<string, string> = { lako: 'Lako', srednje: 'Srednje', tesko: 'Teško', teško: 'Teško' }
const DIFFICULTY_STYLE: Record<string, { bg: string; fg: string }> = {
  lako:    { bg: '#E8F8F0', fg: '#15803d' },
  srednje: { bg: '#FFECBC', fg: '#9c7a13' },
  tesko:   { bg: '#FEE2E2', fg: '#b91c1c' },
  teško:   { bg: '#FEE2E2', fg: '#b91c1c' },
}

const QUIZ_ACCENTS: Record<string, string> = {
  'Opšte znanje':       '#609DED',
  'Sport':              '#FFCB46',
  'Istorija':           '#E55353',
  'Geografija':         '#4CAF50',
  'Kultura i umetnost': '#BCD9FF',
  'Nauka i priroda':    '#9C9C9C',
  'Književnost':        '#343434',
}

export default async function KvizovPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/auth/prijava')

  const { data: quizzes } = await supabase
    .from('quizzes')
    .select('*, question_count:questions(count)')
    .order('created_at', { ascending: false })

  const { data: profile } = await supabase
    .from('profiles')
    .select('first_name')
    .eq('id', user.id)
    .single()

  const processed = (quizzes || []).map((q: Quiz & { question_count: { count: number }[] }) => ({
    ...q,
    question_count: q.question_count?.[0]?.count ?? 0,
  }))

  const categories = [...new Set(processed.map((q: Quiz) => q.category).filter(Boolean))]
  const totalQuestions = processed.reduce((s, q) => s + (q.question_count as unknown as number || 0), 0)

  return (
    <div className="min-h-screen" style={{ background: '#FAFAFA' }}>
      <Header />

      <main className="max-w-6xl mx-auto px-4 sm:px-6 py-10 sm:py-14">
        {/* ─ Welcome ─────────────────────────────────────────────── */}
        <div className="mb-10">
          <p className="text-[13px] font-bold uppercase tracking-widest mb-2" style={{ color: '#609DED' }}>
            Zdravo, {profile?.first_name || 'igraču'}
          </p>
          <h1 className="font-black tracking-tight leading-[1.1]"
            style={{ color: '#343434', fontSize: 'clamp(32px, 5vw, 48px)' }}>
            Šta ćemo da igramo<br />danas?
          </h1>
        </div>

        {/* ─ Stats strip ─────────────────────────────────────────── */}
        <div className="grid grid-cols-3 gap-3 sm:gap-4 mb-12">
          {[
            { label: 'Kvizova',  value: processed.length,  bg: '#BCD9FF', fg: '#1e5fa4' },
            { label: 'Kategorija', value: categories.length, bg: '#FFECBC', fg: '#9c7a13' },
            { label: 'Pitanja',   value: totalQuestions.toLocaleString('sr'),    bg: '#F2F2F2', fg: '#343434' },
          ].map(({ label, value, bg, fg }) => (
            <div key={label} className="rounded-3xl px-4 py-5 sm:p-6" style={{ background: bg }}>
              <div className="font-black tracking-tight" style={{ color: fg, fontSize: 'clamp(22px, 4vw, 32px)' }}>
                {value}
              </div>
              <div className="text-[12px] sm:text-[13px] font-medium mt-1" style={{ color: fg, opacity: 0.7 }}>
                {label}
              </div>
            </div>
          ))}
        </div>

        {/* ─ Quizzes ─────────────────────────────────────────────── */}
        {processed.length === 0 ? (
          <div className="card-soft py-20 text-center">
            <div className="w-14 h-14 rounded-2xl flex items-center justify-center mx-auto mb-4" style={{ background: '#F2F2F2' }}>
              <IconDiscover size={24} className="text-[#9C9C9C]" />
            </div>
            <p className="font-bold text-[17px] mb-1" style={{ color: '#343434' }}>Kvizovi se pripremaju</p>
            <p className="text-[14px]" style={{ color: '#9C9C9C' }}>Uskoro nova pitanja.</p>
          </div>
        ) : (
          <div>
            <div className="flex items-baseline justify-between mb-5">
              <h2 className="font-bold text-[18px] tracking-tight" style={{ color: '#343434' }}>Svi kvizovi</h2>
              <p className="text-[13px]" style={{ color: '#9C9C9C' }}>{processed.length} kvizova</p>
            </div>
            <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-4">
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
  const diffStyle = DIFFICULTY_STYLE[diff] || { bg: '#F2F2F2', fg: '#9C9C9C' }
  const accent = QUIZ_ACCENTS[quiz.title] || quiz.cover_color || '#609DED'

  return (
    <Link href={`/kvizovi/${quiz.id}`} className="group block">
      <article className="card-soft overflow-hidden h-full transition-all duration-300 group-hover:-translate-y-1 group-hover:shadow-lg">
        {/* Top accent — minimal stripe */}
        <div className="h-2 transition-all" style={{ background: accent }} />

        <div className="p-6">
          <div className="flex items-start justify-between gap-3 mb-3">
            <h3 className="font-bold text-[18px] leading-tight tracking-tight transition-colors"
              style={{ color: '#343434' }}>
              {quiz.title}
            </h3>
            <span className="chip flex-shrink-0" style={{ background: diffStyle.bg, color: diffStyle.fg }}>
              {DIFFICULTY_LABEL[diff] || diff}
            </span>
          </div>

          {quiz.description && (
            <p className="text-[14px] leading-relaxed mb-5 line-clamp-2" style={{ color: '#9C9C9C' }}>
              {quiz.description}
            </p>
          )}

          <div className="flex items-center justify-between text-[12px] pt-4 border-t" style={{ borderColor: '#F2F2F2', color: '#9C9C9C' }}>
            <span className="flex items-center gap-1.5 font-medium">
              <IconDiscover size={13} strokeWidth={2.2} />
              {(quiz.question_count as unknown as number) || 0} pitanja
            </span>
            <span className="flex items-center gap-1.5 font-medium">
              <IconStar size={13} strokeWidth={2.2} />
              {quiz.plays} igranja
            </span>
          </div>
        </div>
      </article>
    </Link>
  )
}
