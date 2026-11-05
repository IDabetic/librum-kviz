import type { Metadata } from 'next'
import Link from 'next/link'
import Image from 'next/image'
import { notFound } from 'next/navigation'
import Header from '@/components/Header'
import Footer from '@/components/Footer'
import { createClient } from '@/lib/supabase/server'
import { IconBack } from '@/components/icons'
import { segment } from '@/lib/segmenti'
import { ucitajPragBedza, jeAutorPitanja } from '@/lib/bedzevi'

// Javna strana autora: šta je taj korisnik dao kvizu.
//
// Čita se iz pogleda `public_accepted_submissions`, koji namerno NEMA
// tačan odgovor ni netačne odgovore — strana sme da pokaže doprinos, ali
// ne sme da postane spisak rešenja.

export const dynamic = 'force-dynamic'

type Params = { params: Promise<{ id: string }> }

export async function generateMetadata({ params }: Params): Promise<Metadata> {
  const { id } = await params
  const supabase = await createClient()
  const { data } = await supabase
    .from('public_profiles').select('first_name, last_name, nickname').eq('id', id).single()
  const ime = data
    ? (data.nickname || `${data.first_name ?? ''} ${data.last_name ?? ''}`.trim() || 'Autor')
    : 'Autor'
  return {
    title: `${ime} – pitanja u Librum kvizu`,
    description: `Pitanja koja je ${ime} dao Librum kvizu i koja su prošla uredničku proveru.`,
    alternates: { canonical: `/autor/${id}` },
  }
}

type Pitanje = {
  id: string
  question_text: string
  segment: string | null
  genre: string | null
  reviewed_at: string | null
}

export default async function AutorPage({ params }: Params) {
  const { id } = await params
  const supabase = await createClient()

  const [{ data: profil }, { data: brojaci }, { data: pitanja }] = await Promise.all([
    supabase.from('public_profiles')
      .select('id, first_name, last_name, nickname, avatar, created_at').eq('id', id).single(),
    supabase.from('contributor_counts')
      .select('accepted, submissions, reports').eq('user_id', id).maybeSingle(),
    supabase.from('public_accepted_submissions')
      .select('id, question_text, segment, genre, reviewed_at')
      .eq('submitted_by', id)
      .order('reviewed_at', { ascending: false })
      .limit(200),
  ])

  if (!profil) notFound()

  const prag = await ucitajPragBedza(supabase)
  const ime = profil.nickname || `${profil.first_name ?? ''} ${profil.last_name ?? ''}`.trim() || 'Igrač'
  const lista = (pitanja ?? []) as Pitanje[]
  const prihvacenih = brojaci?.accepted ?? lista.length

  // Koliko je pitanja dao po segmentu — kratak pregled iznad spiska.
  const poSegmentu = new Map<string, number>()
  for (const p of lista) {
    const k = p.segment ?? 'pro'
    poSegmentu.set(k, (poSegmentu.get(k) ?? 0) + 1)
  }

  return (
    <div className="min-h-screen">
      <Header />

      <main className="max-w-3xl mx-auto px-4 sm:px-6 py-10 sm:py-14">
        <Link href="/autori-pitanja"
          className="inline-flex items-center gap-1.5 text-[13px] font-medium mb-6 transition-opacity hover:opacity-70"
          style={{ color: 'var(--ok)' }}>
          <IconBack size={16} strokeWidth={2.2} />
          Autori pitanja
        </Link>

        <div className="card-soft p-6 sm:p-7 mb-6">
          <div className="flex items-center gap-4">
            <div className="w-16 h-16 rounded-full overflow-hidden flex-shrink-0 bg-[var(--line)]">
              {profil.avatar
                ? <Image src={`/avatars/${profil.avatar}`} alt={ime} width={64} height={64} className="w-full h-full object-cover" />
                : <div className="w-full h-full flex items-center justify-center text-xl font-bold"
                    style={{ background: '#FDC361', color: 'var(--ink)' }}>{ime[0]}</div>}
            </div>
            <div className="min-w-0 flex-1">
              <h1 className="font-black tracking-tight truncate"
                style={{ color: 'var(--ink)', fontSize: 'clamp(22px, 4vw, 30px)' }}>
                {ime}
              </h1>
              <p className="text-[13px] mt-0.5" style={{ color: 'var(--ink-2)' }}>
                {prihvacenih} {prihvacenih === 1 ? 'pitanje' : 'pitanja'} u kvizu
              </p>
              {jeAutorPitanja(prihvacenih, prag) && (
                <span className="chip mt-2 inline-flex" style={{ background: 'var(--warn-50)', color: 'var(--warn-t)' }}>
                  🏅 Autor pitanja
                </span>
              )}
            </div>
            <Link href={`/profil/${id}`} className="btn btn-secondary btn-sm flex-shrink-0">
              Rezultati
            </Link>
          </div>

          {poSegmentu.size > 0 && (
            <div className="flex flex-wrap gap-1.5 mt-5">
              {[...poSegmentu.entries()].map(([k, n]) => {
                const seg = segment(k)
                return (
                  <span key={k} className="chip" style={{ background: seg.tint, color: seg.accent }}>
                    {seg.emoji} {seg.label} · {n}
                  </span>
                )
              })}
            </div>
          )}
        </div>

        {lista.length === 0 ? (
          <div className="card-soft p-10 text-center">
            <p className="text-[14px]" style={{ color: 'var(--ink-2)' }}>
              Ovaj korisnik još nema prihvaćeno pitanje.
            </p>
          </div>
        ) : (
          <div className="card-soft overflow-hidden">
            {lista.map(p => {
              const seg = segment(p.segment ?? 'pro')
              return (
                <div key={p.id} className="px-5 py-4 border-b border-[var(--line)] last:border-0">
                  <div className="flex items-start gap-3">
                    <span className="chip flex-shrink-0 mt-0.5" style={{ background: seg.tint, color: seg.accent }}>
                      {seg.emoji}
                    </span>
                    <div className="min-w-0">
                      <p className="text-[14px] font-semibold" style={{ color: 'var(--ink)' }}>
                        {p.question_text}
                      </p>
                      <p className="text-[11px] mt-0.5" style={{ color: 'var(--ink-2)' }}>
                        {seg.label}{p.genre ? ` · ${p.genre}` : ''}
                      </p>
                    </div>
                  </div>
                </div>
              )
            })}
          </div>
        )}

        <p className="text-[12px] text-center mt-6" style={{ color: 'var(--ink-2)' }}>
          Odgovori se ne prikazuju — ovde stoji samo šta je autor dao kvizu.{' '}
          <Link href="/dodaj-pitanja" className="font-semibold underline" style={{ color: 'var(--ok)' }}>
            Pošalji i ti
          </Link>
        </p>
      </main>
      <Footer />
    </div>
  )
}
