import type { Metadata } from 'next'
import { createClient } from '@/lib/supabase/server'
import Header from '@/components/Header'
import Link from 'next/link'
import { redirect } from 'next/navigation'
import { IconHint, IconUsers, IconStar, IconTrophy } from '@/components/icons'

export const metadata: Metadata = {
  title: 'Vešanje – igra pogađanja reči po kategorijama',
  description: 'Igraj vešanje online. Izaberi kategoriju, pročitaj hint i pogodi skrivenu reč iz sporta, geografije, istorije, kulture, prirode ili predmeta.',
  alternates: { canonical: '/vesanje' },
  openGraph: {
    title: 'Vešanje – pogodi skrivenu reč | Librum Kviz',
    description: 'Klasična igra pogađanja reči po kategorijama.',
    url: 'https://kviz.librum.club/vesanje',
    type: 'website',
  },
}

const CATEGORIES = [
  { id: 'Sport',      label: 'Sport',      bg: '#BCD9FF', fg: '#1e5fa4', emoji: '⚽' },
  { id: 'Geografija', label: 'Geografija', bg: '#E8F8F0', fg: '#15803d', emoji: '🌍' },
  { id: 'Istorija',   label: 'Istorija',   bg: '#FFECBC', fg: '#9c7a13', emoji: '📜' },
  { id: 'Kultura',    label: 'Kultura',    bg: '#FEE2E2', fg: '#b91c1c', emoji: '🎭' },
  { id: 'Priroda',    label: 'Priroda',    bg: '#E8F8F0', fg: '#15803d', emoji: '🌿' },
  { id: 'Predmeti',   label: 'Predmeti',   bg: '#F2F2F2', fg: '#343434', emoji: '⚙️' },
]

export default async function VesanjeLanding() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/auth/prijava?redirect=/vesanje')

  const { data: profile } = await supabase
    .from('profiles').select('first_name').eq('id', user.id).single()

  const { data: stats } = await supabase
    .from('hangman_sessions')
    .select('won, score')
    .eq('user_id', user.id)
  const total = stats?.length || 0
  const wins = (stats || []).filter(s => s.won).length
  const totalScore = (stats || []).reduce((s, r) => s + (r.score ?? 0), 0)
  const winRate = total > 0 ? Math.round((wins / total) * 100) : 0

  return (
    <div className="min-h-screen" style={{ background: '#FAFAFA' }}>
      <Header />
      <main className="max-w-2xl mx-auto px-4 sm:px-6 py-10 sm:py-14">

        <div className="text-center mb-8">
          <p className="text-[13px] font-bold uppercase tracking-widest mb-2" style={{ color: '#609DED' }}>
            Igra Vešanja
          </p>
          <h1 className="font-black tracking-tight leading-[1.05] mb-3"
            style={{ color: '#343434', fontSize: 'clamp(40px, 8vw, 64px)' }}>
            Pogodi reč.
          </h1>
          <p className="text-[15px] sm:text-[17px] leading-relaxed" style={{ color: '#9C9C9C' }}>
            Imaš <strong>6 života</strong>. Pročitaj hint i pogađaj slovo po slovo —<br />ili se usudi da pogodiš celu reč.
          </p>
        </div>

        {/* Personal stats */}
        {total > 0 ? (
          <div className="card-soft p-5 mb-5">
            <div className="flex items-center gap-3 mb-3">
              <div className="w-10 h-10 rounded-2xl flex items-center justify-center flex-shrink-0" style={{ background: '#FFECBC' }}>
                <IconTrophy size={20} className="text-[#9c7a13]" strokeWidth={2.2} />
              </div>
              <p className="font-bold text-[15px] tracking-tight" style={{ color: '#343434' }}>Tvoja statistika</p>
            </div>
            <div className="grid grid-cols-4 gap-2">
              {[
                { label: 'Igara',   value: total },
                { label: 'Pobeda',  value: wins },
                { label: 'Bodovi',  value: totalScore },
                { label: 'Uspeh',   value: `${winRate}%` },
              ].map(({ label, value }) => (
                <div key={label} className="rounded-xl p-2.5 text-center" style={{ background: '#F2F2F2' }}>
                  <div className="font-black text-[15px] tracking-tight" style={{ color: '#343434' }}>{value}</div>
                  <div className="text-[10px] mt-0.5" style={{ color: '#9C9C9C' }}>{label}</div>
                </div>
              ))}
            </div>
          </div>
        ) : (
          <div className="card-soft p-5 mb-5 flex items-center gap-3">
            <div className="w-10 h-10 rounded-2xl flex items-center justify-center flex-shrink-0" style={{ background: '#BCD9FF' }}>
              <IconStar size={20} className="text-[#1e5fa4]" strokeWidth={2.2} />
            </div>
            <p className="text-[14px]" style={{ color: '#343434' }}>
              Još nisi igrao. <strong>Vreme za prvi pokušaj.</strong>
            </p>
          </div>
        )}

        {/* Categories */}
        <div className="card-soft p-6 sm:p-8 mb-4">
          <h2 className="font-bold text-[16px] mb-4 tracking-tight" style={{ color: '#343434' }}>
            Izaberi kategoriju
          </h2>
          <div className="grid grid-cols-2 gap-3 mb-5">
            {CATEGORIES.map(c => (
              <Link key={c.id} href={`/vesanje/start?cat=${encodeURIComponent(c.id)}`}
                className="rounded-2xl p-5 transition-all hover:scale-[1.02]"
                style={{ background: c.bg }}>
                <div className="text-3xl mb-2">{c.emoji}</div>
                <div className="font-bold text-[15px] tracking-tight" style={{ color: c.fg }}>{c.label}</div>
              </Link>
            ))}
          </div>
          <Link href="/vesanje/start?cat=random"
            className="btn btn-secondary btn-md w-full">
            🎲 Nasumična kategorija
          </Link>
        </div>

        {/* 2-player mode */}
        <div className="card-soft p-6 mb-4">
          <div className="flex items-center gap-3 mb-3">
            <div className="w-10 h-10 rounded-2xl flex items-center justify-center flex-shrink-0" style={{ background: '#FFCB46' }}>
              <IconUsers size={20} className="text-[#343434]" strokeWidth={2.2} />
            </div>
            <div>
              <p className="font-bold text-[15px] tracking-tight" style={{ color: '#343434' }}>Igra za dvoje</p>
              <p className="text-[12px]" style={{ color: '#9C9C9C' }}>Jedan smišlja reč i hint, drugi pogađa</p>
            </div>
          </div>
          <Link href="/vesanje/dvoje" className="btn btn-md w-full"
            style={{ background: '#FFCB46', color: '#343434' }}>
            Dodaj reč
          </Link>
        </div>

        {/* Rules — collapsed-ish */}
        <div className="card-soft p-6 sm:p-7">
          <h2 className="font-bold text-[15px] mb-4 tracking-tight" style={{ color: '#343434' }}>
            Pravila
          </h2>
          <div className="space-y-3 text-[13px] leading-relaxed" style={{ color: '#343434' }}>
            <div className="flex gap-2"><span style={{ color: '#609DED' }}>•</span> <span>Imaš <strong>6 života</strong>. Pogrešno slovo = -1 život, -2 boda. Tačno slovo = +5 bodova.</span></div>
            <div className="flex gap-2"><span style={{ color: '#609DED' }}>•</span> <span>Možeš da rizikuješ i pogodiš celu reč. Tačno = pobeda + bonus. Pogrešno = -2 života.</span></div>
            <div className="flex gap-2"><span style={{ color: '#609DED' }}>•</span> <span>Bonus za pobedu bez greške: <strong>+30</strong>. Sa 1-2 greške: <strong>+15</strong>.</span></div>
            <div className="flex gap-2"><span style={{ color: '#609DED' }}>•</span> <span>Razmaci, crtice i interpunkcija se prikazuju odmah.</span></div>
          </div>
        </div>

        <p className="text-center text-[11px] mt-5" style={{ color: '#9C9C9C' }}>
          {profile?.first_name ? `Spreman/na, ${profile.first_name}?` : 'Spreman/na?'}
        </p>
      </main>
    </div>
  )
}
