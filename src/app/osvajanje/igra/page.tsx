import type { Metadata } from 'next'
import { TEZINE, type Tezina } from '@/lib/osvajanje/pravila'
import { Igra } from './Igra'

export const metadata: Metadata = {
  title: 'Osvajač – partija',
  robots: { index: false },
}

const DOZVOLJENI_KRUGOVI = [8, 12]

export default async function IgraPage({ searchParams }: { searchParams: Promise<Record<string, string | undefined>> }) {
  const q = await searchParams
  const tezina: Tezina = q.tezina && q.tezina in TEZINE ? (q.tezina as Tezina) : 'normalno'
  const krugova = DOZVOLJENI_KRUGOVI.includes(Number(q.krugova)) ? Number(q.krugova) : 12
  return <Igra key={`${tezina}-${krugova}`} krugova={krugova} tezina={tezina} />
}
