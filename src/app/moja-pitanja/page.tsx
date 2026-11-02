import Link from 'next/link'
import { redirect } from 'next/navigation'
import Header from '@/components/Header'
import Footer from '@/components/Footer'
import { createClient } from '@/lib/supabase/server'
import { IconBack, IconCheck, IconWrong, IconTime } from '@/components/icons'
import { segment } from '@/lib/segmenti'
import { ucitajPragBedza, jeAutorPitanja } from '@/lib/bedzevi'

// Pregled sopstvenih predloga. Čita se pod korisnikovom sesijom, kroz
// RLS politiku „users read own submissions” — nema šanse da se vidi tuđe
// pitanje ni kad bi se ruta pogodila sa strane.

export const dynamic = 'force-dynamic'

export const metadata = {
  title: 'Moja pitanja | Librum Kviz',
  description: 'Pregled pitanja koja si poslao u Librum kviz i njihov status.',
  robots: { index: false, follow: false },
}

type Predlog = {
  id: string
  question_text: string
  correct_answer: string
  wrong_answers: string[] | null
  segment: string | null
  genre: string | null
  status: string
  reject_reason: string | null
  created_at: string
  reviewed_at: string | null
  accepted_id: string | null
  accepted_table: string | null
}

// Koliko je puta prihvaćeno pitanje odigrano i koliko tačno. Kafanski
// kviz nema te brojače u tabeli, pa se za njega ništa ne prikazuje.
type Ucinak = { prikazano: number; tacno: number | null }

const STATUSI: Record<string, { naziv: string; boja: string; pozadina: string }> = {
  pending:  { naziv: 'Čeka proveru', boja: '#8A6A12', pozadina: '#F5E6B8' },
  accepted: { naziv: 'Prihvaćeno',   boja: '#1F8A62', pozadina: '#D4F3E7' },
  rejected: { naziv: 'Odbijeno',     boja: '#b91c1c', pozadina: '#FEE2E2' },
}

function datum(s: string): string {
  return new Date(s).toLocaleDateString('sr-RS', { day: 'numeric', month: 'long', year: 'numeric' })
}

export default async function MojaPitanjaPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/auth/prijava?redirect=/moja-pitanja')

  const prag = await ucitajPragBedza(supabase)
  const { data } = await supabase
    .from('question_submissions')
    .select('id, question_text, correct_answer, wrong_answers, segment, genre, status, reject_reason, created_at, reviewed_at, accepted_id, accepted_table')
    .eq('submitted_by', user.id)
    .order('created_at', { ascending: false })
    .limit(500)

  const redovi = (data ?? []) as Predlog[]

  // Učinak se čita po tabelama, jednim upitom po tabeli, i vezuje za
  // predlog preko `accepted_id`.
  const ucinak = new Map<string, Ucinak>()
  const poTabeli = new Map<string, string[]>()
  for (const r of redovi) {
    if (r.status !== 'accepted' || !r.accepted_id || !r.accepted_table) continue
    const lista = poTabeli.get(r.accepted_table) ?? []
    lista.push(r.accepted_id)
    poTabeli.set(r.accepted_table, lista)
  }
  for (const [tabela, ids] of poTabeli) {
    if (tabela === 'kafana_questions') continue
    const kolone = tabela === 'hangman_words'
      ? 'id, times_used, times_guessed'
      : 'id, times_shown, times_correct'
    const { data: statovi } = await supabase.from(tabela).select(kolone).in('id', ids)
    for (const red of (statovi ?? []) as unknown as Record<string, number | string>[]) {
      ucinak.set(String(red.id), tabela === 'hangman_words'
        ? { prikazano: Number(red.times_used ?? 0), tacno: Number(red.times_guessed ?? 0) }
        : { prikazano: Number(red.times_shown ?? 0), tacno: Number(red.times_correct ?? 0) })
    }
  }
  const broj = {
    pending: redovi.filter(r => r.status === 'pending').length,
    accepted: redovi.filter(r => r.status === 'accepted').length,
    rejected: redovi.filter(r => r.status === 'rejected').length,
  }

  return (
    <div className="page-ink min-h-screen">
      <Header />

      <main className="max-w-3xl mx-auto px-4 sm:px-6 py-10 sm:py-14">
        <Link href="/dodaj-pitanja"
          className="inline-flex items-center gap-1.5 text-[13px] font-medium mb-6 transition-opacity hover:opacity-70"
          style={{ color: '#3A36A0' }}>
          <IconBack size={16} strokeWidth={2.2} />
          Dodaj pitanja
        </Link>

        <h1 className="font-black tracking-tight mb-2 leading-[1.1]"
          style={{ color: '#1A1A1E', fontSize: 'clamp(26px, 5vw, 36px)' }}>
          Moja pitanja
        </h1>
        <p className="text-[14px] mb-8" style={{ color: '#6B6760' }}>
          {redovi.length === 0
            ? 'Još nisi poslao nijedno pitanje.'
            : `Poslao si ${redovi.length} ${redovi.length === 1 ? 'pitanje' : 'pitanja'}.`}
        </p>

        {broj.accepted > 0 && (
          <div className="rounded-2xl px-5 py-4 mb-6 flex items-center gap-3"
            style={{ background: jeAutorPitanja(broj.accepted, prag) ? '#F5E6B8' : '#EBE8E1' }}>
            <span className="text-[24px] leading-none">🏅</span>
            <div className="flex-1">
              <p className="font-bold text-[14px]" style={{ color: jeAutorPitanja(broj.accepted, prag) ? '#8A6A12' : '#1A1A1E' }}>
                {jeAutorPitanja(broj.accepted, prag)
                  ? 'Bedž „Autor pitanja” je tvoj'
                  : `Još ${prag - broj.accepted} do bedža „Autor pitanja”`}
              </p>
              <p className="text-[12px] mt-0.5" style={{ color: '#6B6760' }}>
                {broj.accepted} od {prag} prihvaćenih ·{' '}
                <Link href="/autori-pitanja" className="underline">rang lista autora</Link>
              </p>
            </div>
          </div>
        )}

        {redovi.length > 0 && (
          <div className="grid grid-cols-3 gap-2.5 mb-8">
            <Kartica ikona={<IconTime size={18} style={{ color: '#8A6A12' }} strokeWidth={2.2} />}
              naziv="Čeka proveru" broj={broj.pending} boja="#8A6A12" pozadina="#F5E6B8" />
            <Kartica ikona={<IconCheck size={18} className="text-[#1F8A62]" />}
              naziv="Prihvaćeno" broj={broj.accepted} boja="#1F8A62" pozadina="#D4F3E7" />
            <Kartica ikona={<IconWrong size={18} style={{ color: '#b91c1c' }} />}
              naziv="Odbijeno" broj={broj.rejected} boja="#b91c1c" pozadina="#FEE2E2" />
          </div>
        )}

        {redovi.length === 0 ? (
          <div className="card-soft p-10 text-center">
            <p className="text-[14px] mb-6" style={{ color: '#6B6760' }}>
              Pošalji prvo pitanje i pojavićeš se u „Doprinos kvizu”.
            </p>
            <Link href="/dodaj-pitanja" className="btn btn-primary btn-md">Dodaj pitanja</Link>
          </div>
        ) : (
          <div className="space-y-3">
            {redovi.map(r => {
              const st = STATUSI[r.status] ?? STATUSI.pending
              const seg = segment(r.segment ?? 'pro')
              const netacni = (r.wrong_answers ?? []).filter(Boolean)
              return (
                <article key={r.id} className="card-soft p-5 sm:p-6">
                  <div className="flex flex-wrap items-center gap-1.5 mb-3">
                    <span className="chip" style={{ background: st.pozadina, color: st.boja }}>
                      {st.naziv}
                    </span>
                    <span className="chip" style={{ background: seg.tint, color: seg.accent }}>
                      {seg.emoji} {seg.label}
                    </span>
                    {r.genre && (
                      <span className="chip" style={{ background: '#EBE8E1', color: '#1A1A1E' }}>{r.genre}</span>
                    )}
                    <span className="text-[11px] ml-auto" style={{ color: '#6B6760' }}>
                      {datum(r.created_at)}
                    </span>
                  </div>

                  <p className="font-bold text-[15px] mb-3" style={{ color: '#1A1A1E' }}>
                    {r.question_text}
                  </p>

                  <ul className="text-[13px] space-y-1">
                    <li style={{ color: '#1F8A62' }}>✓ {r.correct_answer}</li>
                    {netacni.map((n, i) => (
                      <li key={i} style={{ color: '#6B6760' }}>· {n}</li>
                    ))}
                  </ul>

                  {(() => {
                    const u = r.accepted_id ? ucinak.get(r.accepted_id) : undefined
                    if (!u) return null
                    const procenat = u.prikazano > 0 && u.tacno !== null
                      ? Math.round((u.tacno / u.prikazano) * 100)
                      : null
                    return (
                      <div className="rounded-2xl px-4 py-3 mt-3 text-[12px]"
                        style={{ background: '#EBE8E1', color: '#1A1A1E' }}>
                        <strong>U igri:</strong>{' '}
                        {u.prikazano === 0
                          ? 'još nije došlo na red'
                          : `odigrano ${u.prikazano} ${u.prikazano === 1 ? 'put' : 'puta'}${
                              procenat !== null ? `, tačno ${procenat}%` : ''}`}
                      </div>
                    )
                  })()}

                  {r.status === 'rejected' && r.reject_reason && (
                    <div className="rounded-2xl px-4 py-3 mt-3 text-[13px]"
                      style={{ background: '#FEE2E2', color: '#b91c1c' }}>
                      <strong>Razlog odbijanja:</strong> {r.reject_reason}
                    </div>
                  )}
                </article>
              )
            })}
          </div>
        )}
      </main>
      <Footer />
    </div>
  )
}

function Kartica({ ikona, naziv, broj, boja, pozadina }: {
  ikona: React.ReactNode; naziv: string; broj: number; boja: string; pozadina: string
}) {
  return (
    <div className="rounded-2xl p-4 text-center" style={{ background: pozadina }}>
      <div className="flex justify-center mb-1.5">{ikona}</div>
      <p className="font-black text-[22px] leading-none mb-1" style={{ color: boja }}>{broj}</p>
      <p className="text-[11px] font-semibold" style={{ color: boja }}>{naziv}</p>
    </div>
  )
}
