import { createClient } from '@/lib/supabase/server'
import Header from '@/components/Header'
import Link from 'next/link'
import { notFound } from 'next/navigation'
import { IconBack, IconDiscover, IconStar, IconCheck, IconTime, IconTrophy } from '@/components/icons'

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

export default async function QuizDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const supabase = await createClient()

  const { data: quiz } = await supabase.from('quizzes').select('*').eq('id', id).single()
  if (!quiz) notFound()

  const { count } = await supabase
    .from('questions')
    .select('*', { count: 'exact', head: true })
    .eq('quiz_id', id)

  const { data: topResults } = await supabase
    .from('quiz_results')
    .select('score, total, time_taken, profiles(first_name, last_name, avatar)')
    .eq('quiz_id', id)
    .order('score', { ascending: false })
    .order('time_taken', { ascending: true })
    .limit(5)

  const diff = quiz.difficulty as keyof typeof DIFFICULTY_LABEL
  const diffStyle = DIFFICULTY_STYLE[diff] || { bg: '#F2F2F2', fg: '#9C9C9C' }
  const accent = QUIZ_ACCENTS[quiz.title] || quiz.cover_color || '#609DED'

  return (
    <div className="min-h-screen" style={{ background: '#FAFAFA' }}>
      <Header />

      <main className="max-w-3xl mx-auto px-4 sm:px-6 py-10 sm:py-14">
        <Link href="/kvizovi"
          className="inline-flex items-center gap-1.5 text-[13px] font-medium mb-6 transition-opacity hover:opacity-70"
          style={{ color: '#609DED' }}>
          <IconBack size={16} strokeWidth={2.2} />
          Kvizovi
        </Link>

        {/* Quiz hero */}
        <div className="card-soft overflow-hidden mb-6">
          <div className="h-2.5" style={{ background: accent }} />
          <div className="p-7 sm:p-9">
            <div className="flex items-start justify-between gap-4 mb-4">
              <h1 className="font-black tracking-tight leading-[1.1] flex-1"
                style={{ color: '#343434', fontSize: 'clamp(28px, 5vw, 42px)' }}>
                {quiz.title}
              </h1>
              <span className="chip flex-shrink-0" style={{ background: diffStyle.bg, color: diffStyle.fg }}>
                {DIFFICULTY_LABEL[diff] || diff}
              </span>
            </div>

            {quiz.description && (
              <p className="text-[15px] leading-relaxed mb-7" style={{ color: '#9C9C9C' }}>
                {quiz.description}
              </p>
            )}

            <div className="grid grid-cols-3 gap-3 mb-7">
              {[
                { Icon: IconDiscover, label: 'Pitanja',     value: count || 0 },
                { Icon: IconStar,     label: 'Kategorija',  value: quiz.category || '—' },
                { Icon: IconTime,     label: 'Igranja',     value: quiz.plays },
              ].map(({ Icon, label, value }) => (
                <div key={label} className="rounded-2xl p-4" style={{ background: '#F2F2F2' }}>
                  <Icon size={16} strokeWidth={2.2} style={{ color: '#9C9C9C' }} />
                  <div className="font-black tracking-tight mt-2 truncate" style={{ color: '#343434', fontSize: 'clamp(16px, 3vw, 20px)' }}>
                    {value}
                  </div>
                  <div className="text-[11px] font-medium mt-0.5" style={{ color: '#9C9C9C' }}>{label}</div>
                </div>
              ))}
            </div>

            <div className="rounded-2xl p-5 mb-7" style={{ background: '#BCD9FF' }}>
              <h3 className="font-bold text-[14px] mb-3 tracking-tight" style={{ color: '#1e5fa4' }}>
                Kako funkcioniše
              </h3>
              <ul className="space-y-2 text-[13px]" style={{ color: '#1e5fa4' }}>
                <li className="flex items-start gap-2">
                  <IconCheck size={14} className="mt-0.5 flex-shrink-0" />
                  Svako pitanje ima 4 ponuđena odgovora
                </li>
                <li className="flex items-start gap-2">
                  <IconCheck size={14} className="mt-0.5 flex-shrink-0" />
                  {quiz.difficulty === 'lako' ? '10' : '15'} sekundi po pitanju
                </li>
                <li className="flex items-start gap-2">
                  <IconCheck size={14} className="mt-0.5 flex-shrink-0" />
                  Skupljaj poene i penji se na rang listu
                </li>
              </ul>
            </div>

            <Link href={`/kvizovi/${quiz.id}/igraj`} className="btn btn-primary btn-lg w-full">
              Počni kviz
            </Link>
          </div>
        </div>

        {/* Top results */}
        {topResults && topResults.length > 0 && (
          <div className="card-soft p-6 sm:p-7">
            <h2 className="font-bold text-[16px] mb-5 tracking-tight flex items-center gap-2" style={{ color: '#343434' }}>
              <IconTrophy size={18} strokeWidth={2.2} className="text-[#FFCB46]" />
              Najbolji rezultati
            </h2>
            <div className="space-y-1">
              {(topResults as Array<{ score: number; total: number; time_taken: number | null; profiles: { first_name: string; last_name: string; avatar?: string } | { first_name: string; last_name: string; avatar?: string }[] | null }>).map((r, i) => {
                const profile = Array.isArray(r.profiles) ? r.profiles[0] : r.profiles
                const medal = i === 0 ? '🥇' : i === 1 ? '🥈' : i === 2 ? '🥉' : null
                return (
                  <div key={i} className="flex items-center gap-3 py-2.5 border-b last:border-0" style={{ borderColor: '#F2F2F2' }}>
                    <span className="w-7 text-center text-[13px] font-bold flex-shrink-0">
                      {medal ? <span className="text-lg">{medal}</span> : <span style={{ color: '#9C9C9C' }}>{i + 1}</span>}
                    </span>
                    <span className="flex-1 text-[14px] font-semibold tracking-tight truncate" style={{ color: '#343434' }}>
                      {profile ? `${profile.first_name} ${profile.last_name}` : 'Igrač'}
                    </span>
                    <span className="font-bold text-[13px]" style={{ color: '#4CAF50' }}>
                      {r.score}/{r.total}
                    </span>
                    {r.time_taken && (
                      <span className="text-[11px]" style={{ color: '#9C9C9C' }}>{r.time_taken}s</span>
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
