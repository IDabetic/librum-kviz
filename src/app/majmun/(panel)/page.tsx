import { createClient } from '@/lib/supabase/server'
import Link from 'next/link'
import { IconUsers, IconDiscover, IconHint, IconTime, IconHome, IconSwords, IconTrophy, IconStar } from '@/components/icons'

export const dynamic = 'force-dynamic'

function fmtN(n: number): string {
  return new Intl.NumberFormat('sr').format(n)
}

export default async function AdminDashboard() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  const { data: me } = await supabase.from('profiles').select('first_name').eq('id', user!.id).single()

  const startOfDay = new Date(); startOfDay.setHours(0, 0, 0, 0)
  const startOfWeek = new Date(); startOfWeek.setDate(startOfWeek.getDate() - 7)

  // Counts in parallel
  const [
    usersAll, usersToday, usersWeek,
    surTotal, surToday,
    bookTotal, bookToday,
    duelTotal, duelToday,
    hangmanTotal, hangmanToday,
    quickTotal, quickToday,
    questActive, questInactive,
    bookActive, bookInactive,
    submissions,
  ] = await Promise.all([
    supabase.from('profiles').select('*', { count: 'exact', head: true }),
    supabase.from('profiles').select('*', { count: 'exact', head: true }).gte('created_at', startOfDay.toISOString()),
    supabase.from('profiles').select('*', { count: 'exact', head: true }).gte('created_at', startOfWeek.toISOString()),
    supabase.from('survivor_sessions').select('*', { count: 'exact', head: true }),
    supabase.from('survivor_sessions').select('*', { count: 'exact', head: true }).gte('created_at', startOfDay.toISOString()),
    supabase.from('book_sessions').select('*', { count: 'exact', head: true }),
    supabase.from('book_sessions').select('*', { count: 'exact', head: true }).gte('created_at', startOfDay.toISOString()),
    supabase.from('game_rooms').select('*', { count: 'exact', head: true }).eq('status', 'finished'),
    supabase.from('game_rooms').select('*', { count: 'exact', head: true }).eq('status', 'finished').gte('created_at', startOfDay.toISOString()),
    supabase.from('hangman_sessions').select('*', { count: 'exact', head: true }),
    supabase.from('hangman_sessions').select('*', { count: 'exact', head: true }).gte('created_at', startOfDay.toISOString()),
    supabase.from('quick_sessions').select('*', { count: 'exact', head: true }),
    supabase.from('quick_sessions').select('*', { count: 'exact', head: true }).gte('created_at', startOfDay.toISOString()),
    supabase.from('questions').select('*', { count: 'exact', head: true }).eq('is_active', true),
    supabase.from('questions').select('*', { count: 'exact', head: true }).eq('is_active', false),
    supabase.from('book_questions').select('*', { count: 'exact', head: true }).eq('is_active', true),
    supabase.from('book_questions').select('*', { count: 'exact', head: true }).eq('is_active', false),
    supabase.from('question_submissions').select('*', { count: 'exact', head: true }),
  ])

  // Recent activity
  const [recentSurvivor, recentSubmissionsRaw, recentUsers] = await Promise.all([
    supabase.from('survivor_sessions')
      .select('score, questions_reached, profiles(first_name, nickname), created_at')
      .order('created_at', { ascending: false }).limit(5),
    // FK on submitted_by points at auth.users not profiles, so PostgREST
    // can't embed the relationship. Fetch submissions then look up profiles
    // separately.
    supabase.from('question_submissions')
      .select('question_text, submitted_by, submitter_email, created_at')
      .order('created_at', { ascending: false }).limit(5),
    supabase.from('profiles')
      .select('id, first_name, nickname, created_at')
      .order('created_at', { ascending: false }).limit(5),
  ])

  const submitterIds = (recentSubmissionsRaw.data || [])
    .map(s => s.submitted_by)
    .filter((v): v is string => !!v)
  const { data: submitterProfiles } = submitterIds.length
    ? await supabase.from('profiles').select('id, first_name, nickname').in('id', submitterIds)
    : { data: [] as { id: string; first_name: string | null; nickname: string | null }[] }
  const submitterMap = new Map((submitterProfiles || []).map(p => [p.id, p]))
  const recentSubmissions = (recentSubmissionsRaw.data || []).map(s => ({
    question_text: s.question_text,
    submitter_email: s.submitter_email,
    created_at: s.created_at,
    profile: s.submitted_by ? submitterMap.get(s.submitted_by) ?? null : null,
  }))

  // Top score today (PRO kviz)
  const { data: topToday } = await supabase
    .from('survivor_sessions')
    .select('score, profiles(first_name, nickname)')
    .gte('created_at', startOfDay.toISOString())
    .order('score', { ascending: false })
    .limit(1)
    .maybeSingle()

  const topName = (() => {
    if (!topToday) return null
    const p = Array.isArray(topToday.profiles) ? topToday.profiles[0] : topToday.profiles as { first_name: string; nickname: string } | null
    return p?.nickname || p?.first_name || 'Igrač'
  })()

  // Most popular game (by total partija)
  const games = [
    { name: 'PRO kviz',     count: surTotal.count ?? 0 },
    { name: 'Book kviz',    count: bookTotal.count ?? 0 },
    { name: 'Trivia duel',  count: duelTotal.count ?? 0 },
    { name: 'Vešanje',      count: hangmanTotal.count ?? 0 },
    { name: 'Brzi kviz',    count: quickTotal.count ?? 0 },
  ].sort((a, b) => b.count - a.count)
  const mostPopular = games[0]

  return (
    <div className="space-y-7">

      {/* ── Greeting ─────────────────────────────────────────────────── */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h1 className="font-black tracking-tight" style={{ color: '#343434', fontSize: 'clamp(24px, 4vw, 32px)' }}>
            Dobrodošao, {me?.first_name || 'admine'}!
          </h1>
          <p className="text-[13px] mt-1" style={{ color: '#9C9C9C' }}>Pregled stanja platforme.</p>
        </div>
        <div className="flex gap-2">
          <Link href="/majmun/pitanja/novo" className="btn btn-primary btn-md">
            + Novo PRO pitanje
          </Link>
        </div>
      </div>

      {/* ── KPI cards ────────────────────────────────────────────────── */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
        <Kpi Icon={IconUsers}    label="Korisnika"      value={fmtN(usersAll.count ?? 0)}    sub={`+${usersToday.count ?? 0} danas`}  bg="#BCD9FF" fg="#1e5fa4" />
        <Kpi Icon={IconHome}     label="PRO partija"    value={fmtN(surTotal.count ?? 0)}    sub={`+${surToday.count ?? 0} danas`}    bg="#E8F8F0" fg="#15803d" />
        <Kpi Icon={IconStar}     label="Book partija"   value={fmtN(bookTotal.count ?? 0)}   sub={`+${bookToday.count ?? 0} danas`}    bg="#FFECBC" fg="#9c7a13" />
        <Kpi Icon={IconHint}     label="Vešanje partija" value={fmtN(hangmanTotal.count ?? 0)} sub={`+${hangmanToday.count ?? 0} danas`} bg="#FFECBC" fg="#9c7a13" />
        <Kpi Icon={IconTime}     label="Brzi kviz partija" value={fmtN(quickTotal.count ?? 0)} sub={`+${quickToday.count ?? 0} danas`}  bg="#FEE2E2" fg="#b91c1c" />
        <Kpi Icon={IconSwords}   label="Duela"          value={fmtN(duelTotal.count ?? 0)}   sub={`+${duelToday.count ?? 0} danas`}   bg="#F2F2F2" fg="#343434" />
        <Kpi Icon={IconDiscover} label="Aktivnih PRO pitanja" value={fmtN(questActive.count ?? 0)} sub={`${fmtN(questInactive.count ?? 0)} neaktivnih`} bg="#BCD9FF" fg="#1e5fa4" />
        <Kpi Icon={IconStar}     label="Aktivnih Book pitanja" value={fmtN(bookActive.count ?? 0)} sub={`${fmtN(bookInactive.count ?? 0)} neaktivnih`} bg="#FFECBC" fg="#9c7a13" />
        <Kpi Icon={IconUsers}    label="Predloga"       value={fmtN(submissions.count ?? 0)} sub="čeka pregled" bg="#FFECBC" fg="#9c7a13" />
        <Kpi Icon={IconTrophy}   label="Najpopularnija" value={mostPopular?.name || '—'}     sub={`${fmtN(mostPopular?.count || 0)} partija`} bg="#FFCB46" fg="#343434" />
      </div>

      {/* ── Top score today + new users ─────────────────────────────── */}
      <div className="grid lg:grid-cols-3 gap-4">
        {/* Today's leader */}
        <div className="card-soft p-6 lg:col-span-1">
          <p className="text-[11px] font-bold uppercase tracking-widest mb-3" style={{ color: '#9C9C9C' }}>
            Rekord dana
          </p>
          {topToday && topName ? (
            <>
              <p className="font-black tracking-tight leading-none" style={{ color: '#FFCB46', fontSize: 'clamp(36px, 6vw, 48px)' }}>
                {topToday.score}
              </p>
              <p className="text-[13px] mt-2" style={{ color: '#343434' }}>
                <strong>{topName}</strong> · PRO kviz
              </p>
            </>
          ) : (
            <p className="text-[13px]" style={{ color: '#9C9C9C' }}>Još niko nije igrao danas.</p>
          )}
        </div>

        {/* Recent users */}
        <div className="card-soft p-6 lg:col-span-2">
          <div className="flex items-center justify-between mb-4">
            <p className="text-[11px] font-bold uppercase tracking-widest" style={{ color: '#9C9C9C' }}>
              Novi korisnici (poslednjih 7 dana: {usersWeek.count ?? 0})
            </p>
            <Link href="/majmun/korisnici" className="text-[12px] font-semibold transition-opacity hover:opacity-70" style={{ color: '#609DED' }}>
              Svi →
            </Link>
          </div>
          <div className="space-y-1">
            {(recentUsers.data || []).slice(0, 5).map(u => (
              <div key={u.id} className="flex items-center justify-between py-2 border-b last:border-0" style={{ borderColor: '#F2F2F2' }}>
                <span className="font-semibold text-[13px]" style={{ color: '#343434' }}>
                  {u.nickname || u.first_name || 'Igrač'}
                </span>
                <span className="text-[11px]" style={{ color: '#9C9C9C' }}>
                  {new Date(u.created_at).toLocaleDateString('sr')}
                </span>
              </div>
            ))}
            {(!recentUsers.data || recentUsers.data.length === 0) && (
              <p className="text-[12px]" style={{ color: '#9C9C9C' }}>—</p>
            )}
          </div>
        </div>
      </div>

      {/* ── Recent activity 2-col ───────────────────────────────────── */}
      <div className="grid lg:grid-cols-2 gap-4">
        {/* Recent PRO sessions */}
        <div className="card-soft p-6">
          <p className="text-[11px] font-bold uppercase tracking-widest mb-4" style={{ color: '#9C9C9C' }}>
            Skorašnje PRO partije
          </p>
          <div className="space-y-1">
            {(recentSurvivor.data || []).map((s, i) => {
              const p = Array.isArray(s.profiles) ? s.profiles[0] : s.profiles as { first_name: string; nickname: string } | null
              const name = p?.nickname || p?.first_name || 'Igrač'
              return (
                <div key={i} className="flex items-center justify-between py-2 border-b last:border-0" style={{ borderColor: '#F2F2F2' }}>
                  <div className="min-w-0">
                    <p className="font-semibold text-[13px] truncate" style={{ color: '#343434' }}>{name}</p>
                    <p className="text-[11px]" style={{ color: '#9C9C9C' }}>
                      {s.questions_reached} pit. · {new Date(s.created_at).toLocaleString('sr', { hour: '2-digit', minute: '2-digit' })}
                    </p>
                  </div>
                  <span className="font-black text-[16px]" style={{ color: '#609DED' }}>{s.score}</span>
                </div>
              )
            })}
            {(!recentSurvivor.data || recentSurvivor.data.length === 0) && (
              <p className="text-[12px]" style={{ color: '#9C9C9C' }}>—</p>
            )}
          </div>
        </div>

        {/* Recent submissions */}
        <div className="card-soft p-6">
          <div className="flex items-center justify-between mb-4">
            <p className="text-[11px] font-bold uppercase tracking-widest" style={{ color: '#9C9C9C' }}>
              Korisnički predlozi
            </p>
            <Link href="/majmun/predlozi" className="text-[12px] font-semibold transition-opacity hover:opacity-70" style={{ color: '#609DED' }}>
              Svi →
            </Link>
          </div>
          <div className="space-y-1">
            {recentSubmissions.map((s, i) => {
              const name = s.profile?.nickname || s.profile?.first_name || s.submitter_email || 'Anon'
              return (
                <div key={i} className="py-2 border-b last:border-0" style={{ borderColor: '#F2F2F2' }}>
                  <p className="text-[13px] line-clamp-2" style={{ color: '#343434' }}>{s.question_text}</p>
                  <p className="text-[11px] mt-1" style={{ color: '#9C9C9C' }}>
                    {name} · {new Date(s.created_at).toLocaleDateString('sr')}
                  </p>
                </div>
              )
            })}
            {recentSubmissions.length === 0 && (
              <p className="text-[12px]" style={{ color: '#9C9C9C' }}>—</p>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}

function Kpi({ Icon, label, value, sub, bg, fg }: {
  Icon: React.ComponentType<{ size?: number; strokeWidth?: number; className?: string }>
  label: string; value: string | number; sub: string; bg: string; fg: string
}) {
  return (
    <div className="card-soft p-5">
      <div className="flex items-center gap-3 mb-3">
        <div className="w-9 h-9 rounded-2xl flex items-center justify-center flex-shrink-0" style={{ background: bg }}>
          <Icon size={16} className={`text-[${fg}]`} strokeWidth={2.2} />
        </div>
        <p className="text-[11px] font-bold uppercase tracking-wider" style={{ color: '#9C9C9C' }}>{label}</p>
      </div>
      <p className="font-black tracking-tight leading-none" style={{ color: '#343434', fontSize: 'clamp(20px, 3.5vw, 28px)' }}>
        {value}
      </p>
      <p className="text-[11px] mt-2" style={{ color: '#9C9C9C' }}>{sub}</p>
    </div>
  )
}
