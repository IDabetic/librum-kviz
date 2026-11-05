import type { Metadata } from 'next'
import Link from 'next/link'
import Header from '@/components/Header'
import Footer from '@/components/Footer'
import { createClient } from '@/lib/supabase/server'

export const dynamic = 'force-dynamic'

export const metadata: Metadata = {
  title: 'Rang lista',
  description: 'Rang lista Librum kviza uživo: Osvajač, PRO kviz, Book kviz, Duel, Slikari, Brzi kviz, Vešanje i Dnevni izazov. Ista lista kao u aplikaciji.',
  alternates: { canonical: '/ranglista' },
}

/** Igre i periodi kao u aplikaciji (RangListaView.swift); lista dolazi iz iste RPC rang_lista_igre. */
const IGRE = [
  ['osvajanje', 'Osvajač'], ['pro', 'PRO'], ['book', 'Book'], ['duel', 'Duel'],
  ['slikari', 'Slikari'], ['brzi', 'Brzi'], ['vesanje', 'Vešanje'], ['dnevni', 'Dnevni'],
] as const
const PERIODI = [['dan', 'Dan'], ['nedelja', 'Nedelja'], ['mesec', 'Mesec'], ['godina', 'Godina']] as const
const BROJ_MESTA = 50

type Red = { mesto: number; user_id: string; nadimak: string | null; avatar: string | null; poeni: number; partija: number }

export default async function RangLista({ searchParams }: { searchParams: Promise<{ igra?: string; period?: string }> }) {
  const p = await searchParams
  // Nepoznata vrednost iz adrese pada na podrazumevanu, da upit ne ode sa proizvoljnim tekstom.
  const igra = IGRE.find(([k]) => k === p.igra)?.[0] ?? 'osvajanje'
  const period = PERIODI.find(([k]) => k === p.period)?.[0] ?? 'nedelja'
  const supabase = await createClient()
  const { data, error } = await supabase.rpc('rang_lista_igre', { p_igra: igra, p_period: period, p_broj: BROJ_MESTA })
  const redovi = (data ?? []) as Red[]
  const veza = (i: string, per: string) => `/ranglista?igra=${i}&period=${per}`

  return (
    <div className="min-h-screen flex flex-col">
      <Header />
      <main className="flex-1 max-w-4xl w-full mx-auto px-4 sm:px-6 pt-10">
        <p className="chip" style={{ color: '#23845C' }}><span className="w-2 h-2 rounded-full animate-pulse" style={{ background: '#5DBF94' }} />Uživo, ista lista kao u aplikaciji</p>
        <h1 className="mt-3" style={{ fontSize: 'clamp(40px, 7vw, 72px)' }}>Rang lista</h1>

        <nav className="mt-6 flex gap-5 overflow-x-auto whitespace-nowrap pb-1" aria-label="Igra">
          {IGRE.map(([k, n]) => (
            <Link key={k} href={veza(k, period)} aria-current={k === igra ? 'page' : undefined}
              className="text-[16px] font-bold py-2" style={{ color: k === igra ? '#1A1B3A' : '#8A8AA0', borderBottom: `3px solid ${k === igra ? '#1A1B3A' : 'transparent'}` }}>
              {n}
            </Link>
          ))}
        </nav>
        <nav className="mt-3 flex gap-5" aria-label="Period">
          {PERIODI.map(([k, n]) => (
            <Link key={k} href={veza(igra, k)} aria-current={k === period ? 'page' : undefined}
              className="text-[14px] font-semibold py-1" style={{ color: k === period ? '#23845C' : '#8A8AA0', borderBottom: `2px solid ${k === period ? '#23845C' : 'transparent'}` }}>
              {n}
            </Link>
          ))}
        </nav>

        {error ? (
          <div className="card-soft p-8 mt-6"><p className="text-[16px]" style={{ color: '#E5385C' }}>Rang lista se trenutno ne učitava. Osveži stranu za minut.</p></div>
        ) : redovi.length === 0 ? (
          <div className="card-soft p-8 mt-6"><p className="text-[16px]" style={{ color: '#4F5170' }}>Još nema partija u ovom periodu. Prvi rezultat iz aplikacije otvara listu.</p></div>
        ) : (
          <ol className="card-soft divide-y divide-[#EDE5D5] mt-6">
            {redovi.map(r => (
              <li key={r.user_id} className="flex items-center gap-4 px-5 py-3.5">
                <span className="w-10 h-10 grid place-items-center rounded-xl font-bold tabular-nums"
                  style={{ background: r.mesto <= 3 ? '#FDC361' : '#F6F1E7', border: r.mesto <= 3 ? '2px solid #1A1B3A' : 'none', color: '#1A1B3A' }}>
                  {r.mesto}
                </span>
                <span className="flex-1 font-semibold truncate">{r.nadimak || 'Igrač'}</span>
                <span className="text-[13px] hidden sm:inline" style={{ color: '#4F5170' }}>{r.partija} partija</span>
                <span className="naslov text-[22px] tabular-nums">{r.poeni.toLocaleString('sr-RS')}</span>
              </li>
            ))}
          </ol>
        )}
      </main>
      <Footer />
    </div>
  )
}
