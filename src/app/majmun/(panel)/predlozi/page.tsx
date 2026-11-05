import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import PredloziList from './PredloziList'
import { SEGMENTI, segment } from '@/lib/segmenti'

export const dynamic = 'force-dynamic'

type SP = { status?: string }

const STATUSI = [
  { key: 'pending',  naziv: 'Na čekanju' },
  { key: 'accepted', naziv: 'Prihvaćeno' },
  { key: 'rejected', naziv: 'Odbijeno' },
]

export default async function PredloziPage({ searchParams }: { searchParams: Promise<SP> }) {
  const sp = await searchParams
  const status = STATUSI.some(s => s.key === sp.status) ? sp.status! : 'pending'
  const supabase = await createClient()

  // FK on submitted_by points at auth.users, not public.profiles, so we
  // can't use a Supabase `profiles(...)` embed here. Pull submissions
  // first, then look up matching profiles by id (auth.users.id == profiles.id).
  const { data: submissions, count } = await supabase
    .from('question_submissions')
    .select('id, question_text, correct_answer, wrong_answers, segment, genre, source, status, reject_reason, submitted_by, submitter_email, created_at', { count: 'exact' })
    .eq('status', status)
    .order('created_at', { ascending: false })
    .limit(200)

  // Brojači po statusu, da urednik vidi koliko je obradio bez menjanja taba.
  const brojevi = Object.fromEntries(await Promise.all(
    STATUSI.map(async s => {
      const { count: c } = await supabase
        .from('question_submissions')
        .select('id', { count: 'exact', head: true })
        .eq('status', s.key)
      return [s.key, c ?? 0] as const
    }),
  ))

  // Nedeljni pregled stanja. Stoji na strani koju urednik ionako otvara,
  // pa nema potrebe ni za izveštajem ni za slanjem bilo čega.
  // Serverska komponenta se izvršava jednom po zahtevu, pa je Date.now()
  // ovde bezbedan; pravilo o čistoći se okida odbrambeno.
  // eslint-disable-next-line react-hooks/purity
  const sada = Date.now()
  const odKad = new Date(sada - 7 * 24 * 60 * 60 * 1000).toISOString()
  const [{ data: sedmica }, { data: cekaju }] = await Promise.all([
    supabase.from('question_submissions')
      .select('segment, status').gte('created_at', odKad).limit(5000),
    supabase.from('question_submissions')
      .select('segment, created_at').eq('status', 'pending')
      .order('created_at', { ascending: true }).limit(5000),
  ])
  const sedam = (sedmica ?? []) as { segment: string | null; status: string }[]
  const cekanje = (cekaju ?? []) as { segment: string | null; created_at: string }[]
  const pregled = {
    stiglo: sedam.length,
    prihvaceno: sedam.filter(r => r.status === 'accepted').length,
    odbijeno: sedam.filter(r => r.status === 'rejected').length,
    ceka: cekanje.length,
    danaCeka: cekanje[0]
      ? Math.floor((sada - new Date(cekanje[0].created_at).getTime()) / 86_400_000)
      : 0,
    poSegmentu: SEGMENTI.map(sg => ({
      key: sg.key,
      ceka: cekanje.filter(r => (r.segment ?? 'pro') === sg.key).length,
    })).filter(r => r.ceka > 0),
  }

  const ids = (submissions || [])
    .map(s => s.submitted_by)
    .filter((v): v is string => !!v)
  const { data: profiles } = ids.length
    ? await supabase.from('profiles').select('id, first_name, nickname').in('id', ids)
    : { data: [] as { id: string; first_name: string | null; nickname: string | null }[] }

  const profileMap = new Map((profiles || []).map(p => [p.id, p]))
  const rows = (submissions || []).map(s => ({
    ...s,
    profile: s.submitted_by ? profileMap.get(s.submitted_by) ?? null : null,
  }))

  return (
    <div className="space-y-5">
      <div>
        <h1 className="font-black tracking-tight" style={{ color: '#151515', fontSize: 'clamp(22px, 4vw, 28px)' }}>
          Korisnički predlozi
        </h1>
        <p className="text-[13px] mt-1" style={{ color: '#6F6C66' }}>
          {count ?? 0} predloga u ovom pregledu · Prihvatanje upisuje u fond koji je korisnik izabrao.
        </p>
      </div>

      <section className="card-soft p-5">
        <p className="text-[11px] font-bold uppercase tracking-widest mb-3" style={{ color: '#6F6C66' }}>
          Poslednjih 7 dana
        </p>
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
          <Brojka naziv="Stiglo" broj={pregled.stiglo} />
          <Brojka naziv="Prihvaćeno" broj={pregled.prihvaceno} boja="#0E6F61" />
          <Brojka naziv="Odbijeno" broj={pregled.odbijeno} boja="#C42B4F" />
          <Brojka naziv="Čeka ukupno" broj={pregled.ceka}
            boja={pregled.ceka > 0 ? '#8A6A12' : undefined} />
        </div>
        {pregled.ceka > 0 && (
          <p className="text-[12px] mt-3" style={{ color: pregled.danaCeka > 14 ? '#C42B4F' : '#6F6C66' }}>
            Najstariji nepregledan predlog čeka <strong>{pregled.danaCeka}</strong>{' '}
            {pregled.danaCeka === 1 ? 'dan' : 'dana'}.
          </p>
        )}
        {pregled.poSegmentu.length > 0 && (
          <div className="flex flex-wrap gap-1.5 mt-3">
            {pregled.poSegmentu.map(r => {
              const sg = segment(r.key)
              return (
                <Link key={r.key} href={`/majmun/predlozi?status=pending`} className="chip"
                  style={{ background: sg.tint, color: sg.accent }}>
                  {sg.emoji} {sg.label} · {r.ceka}
                </Link>
              )
            })}
          </div>
        )}
      </section>

      <div className="flex flex-wrap gap-2">
        {STATUSI.map(s => {
          const aktivan = s.key === status
          return (
            <Link key={s.key} href={`/majmun/predlozi?status=${s.key}`} scroll={false}
              className="px-4 py-2 rounded-full text-[13px] font-semibold transition-all"
              style={aktivan
                ? { background: '#151515', color: 'white' }
                : { background: '#E7E1D0', color: '#151515' }}>
              {s.naziv} ({brojevi[s.key] ?? 0})
            </Link>
          )
        })}
      </div>

      <PredloziList rows={rows} status={status} />
    </div>
  )
}

function Brojka({ naziv, broj, boja }: { naziv: string; broj: number; boja?: string }) {
  return (
    <div className="rounded-2xl px-4 py-3" style={{ background: '#E7E1D0' }}>
      <p className="font-black text-[22px] leading-none mb-1" style={{ color: boja ?? '#151515' }}>
        {broj}
      </p>
      <p className="text-[11px] font-semibold" style={{ color: '#6F6C66' }}>{naziv}</p>
    </div>
  )
}
