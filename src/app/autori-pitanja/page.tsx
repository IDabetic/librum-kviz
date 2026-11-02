import type { Metadata } from 'next'
import Link from 'next/link'
import Image from 'next/image'
import Header from '@/components/Header'
import Footer from '@/components/Footer'
import { createClient } from '@/lib/supabase/server'
import { IconBack } from '@/components/icons'
import { ucitajPragBedza, jeAutorPitanja } from '@/lib/bedzevi'

// Rang lista autora pitanja. Namerno odvojena od /ranglista: tamo se
// meri igranje po periodima, ovde doprinos bazi, i te dve stvari nemaju
// isti period ni isto merilo.

export const dynamic = 'force-dynamic'

export const metadata: Metadata = {
  title: 'Autori pitanja – ko gradi bazu Librum kviza',
  description: 'Rang lista korisnika čija su pitanja prihvaćena i ušla u Librum kviz. Pošalji svoja pitanja i nađi se na listi.',
  alternates: { canonical: '/autori-pitanja' },
  openGraph: {
    title: 'Autori pitanja | Librum Kviz',
    description: 'Ko gradi bazu pitanja Librum kviza.',
    url: 'https://kviz.librum.club/autori-pitanja',
    type: 'website',
    images: ['/og-share.jpg?v=6'],
  },
}

const MEDALJE = ['🥇', '🥈', '🥉']

type Autor = {
  id: string
  first_name: string | null
  last_name: string | null
  nickname: string | null
  avatar: string | null
  accepted: number
  submissions: number
}

export default async function AutoriPitanjaPage() {
  const supabase = await createClient()
  const prag = await ucitajPragBedza(supabase)
  const { data } = await supabase
    .from('public_question_authors')
    .select('id, first_name, last_name, nickname, avatar, accepted, submissions')
    .order('accepted', { ascending: false })
    .limit(100)

  const autori = (data ?? []) as Autor[]
  const ukupno = autori.reduce((a, b) => a + b.accepted, 0)

  return (
    <div className="min-h-screen">
      <Header />

      <main className="max-w-3xl mx-auto px-4 sm:px-6 py-10 sm:py-14">
        <Link href="/ranglista"
          className="inline-flex items-center gap-1.5 text-[13px] font-medium mb-6 transition-opacity hover:opacity-70"
          style={{ color: '#12907E' }}>
          <IconBack size={16} strokeWidth={2.2} />
          Rang lista
        </Link>

        <div className="text-center mb-10">
          <div className="text-[34px] leading-none mb-3">🏅</div>
          <h1 className="font-black tracking-tight mb-2 leading-[1.1]"
            style={{ color: '#151515', fontSize: 'clamp(28px, 5vw, 40px)' }}>
            Autori pitanja
          </h1>
          <p className="text-[14px] sm:text-[15px]" style={{ color: '#6F6C66' }}>
            {autori.length === 0
              ? 'Još niko nema prihvaćeno pitanje. Budi prvi.'
              : `${autori.length} ${autori.length === 1 ? 'autor' : 'autora'} · ${ukupno} prihvaćenih pitanja u kvizu.`}
          </p>
        </div>

        {autori.length === 0 ? (
          <div className="card-soft p-10 text-center">
            <Link href="/dodaj-pitanja" className="btn btn-primary btn-md">Dodaj pitanja</Link>
          </div>
        ) : (
          <div className="card-soft overflow-hidden">
            {autori.map((a, i) => {
              const ime = a.nickname || `${a.first_name ?? ''} ${a.last_name ?? ''}`.trim() || 'Igrač'
              const naCekanju = Math.max(0, a.submissions - a.accepted)
              return (
                <Link key={a.id} href={`/autor/${a.id}`}
                  className="flex items-center gap-3 px-5 py-3.5 border-b border-[#E7E1D0] last:border-0 hover:bg-[#E7E1D0] transition-colors">
                  <span className="w-8 text-center text-[15px] font-bold flex-shrink-0"
                    style={{ color: i < 3 ? '#151515' : '#6F6C66' }}>
                    {MEDALJE[i] ?? i + 1}
                  </span>
                  <div className="w-10 h-10 rounded-full overflow-hidden flex-shrink-0 bg-[#E7E1D0]">
                    {a.avatar
                      ? <Image src={`/avatars/${a.avatar}`} alt={ime} width={40} height={40} className="w-full h-full object-cover" />
                      : <div className="w-full h-full flex items-center justify-center text-sm font-bold"
                          style={{ background: '#FFD84D', color: '#151515' }}>{ime[0]}</div>}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="font-semibold text-[14px] truncate flex items-center gap-1.5" style={{ color: '#151515' }}>
                      {ime}
                      {jeAutorPitanja(a.accepted, prag) && (
                        <span className="chip" style={{ background: '#FFF3C4', color: '#8A6A12' }}>
                          🏅 Autor pitanja
                        </span>
                      )}
                    </p>
                    <p className="text-[12px]" style={{ color: '#6F6C66' }}>
                      {naCekanju > 0 ? `još ${naCekanju} čeka proveru` : 'sve pregledano'}
                    </p>
                  </div>
                  <span className="chip flex-shrink-0" style={{ background: '#DFF3EE', color: '#0E6F61' }}>
                    {a.accepted}
                  </span>
                </Link>
              )
            })}
          </div>
        )}

        <p className="text-[12px] text-center mt-6 leading-relaxed" style={{ color: '#6F6C66' }}>
          Bedž „Autor pitanja” dobija se sa {prag} prihvaćenih pitanja.{' '}
          <Link href="/dodaj-pitanja" className="font-semibold underline" style={{ color: '#12907E' }}>
            Pošalji svoja
          </Link>
        </p>
      </main>
      <Footer />
    </div>
  )
}
