import type { Metadata } from 'next'
import Image from 'next/image'
import Link from 'next/link'
import Header from '@/components/Header'
import Footer from '@/components/Footer'

export const metadata: Metadata = {
  title: 'Osvajanje sveta – strateški kviz na mapi sveta',
  description: 'Osvajaj kontinente odgovorima na pitanja. Vojske, proboj i bitke znanja protiv dva rivala. Besplatna igra znanja na srpskom.',
  alternates: { canonical: '/osvajanje' },
}

const PRAVILA = [
  ['Snabdevanje', 'Na početku poteza jedno pitanje. Tačno donosi pune vojske, netačno pola. Raspoređuješ ih dodirom po svojim oblastima.'],
  ['Napad', 'Iz oblasti sa bar 2 vojske napadaš susednu. Svaka bitka je pitanje od 15 sekundi; protiv rivala odgovarate oboje, a izjednačenje rešava brzina.'],
  ['Proboj', 'Kad osvojiš oblast, vojske prelaze u nju i odmah možeš da cepaš dalje. Svako treće osvajanje u nizu donosi +2 vojske.'],
  ['Kontinenti', 'Ceo kontinent donosi bonus vojske svakog poteza: Azija +4, Evropa, Afrika i Severna Amerika +3, Južna Amerika i Okeanija +2.'],
  ['Prestonica', 'Svaki igrač počinje iz prestonice. Tuđa prestonica nosi +5 vojski plena, a svoja na kraju 20 poena.'],
] as const

const TEZINE = [
  { id: 'lako', ime: 'Lako', opis: 'Rivali greše svako drugo pitanje' },
  { id: 'normalno', ime: 'Normalno', opis: 'Rivali znaju oko 6 od 10' },
  { id: 'tesko', ime: 'Teško', opis: 'Rivali znaju 3 od 4' },
]

export default function OsvajanjePage() {
  return (
    <div className="min-h-screen flex flex-col">
      <Header />
      <main className="flex-1 max-w-6xl w-full mx-auto px-4 sm:px-6 py-10 sm:py-14">
        <div className="card-pop relative overflow-hidden p-7 sm:p-10" style={{ background: '#12907E', color: '#FFFFFF' }}>
          <span aria-hidden className="absolute rounded-full" style={{ width: 340, height: 340, right: -60, top: -40, background: 'rgba(255,255,255,0.14)' }} />
          <Image src="/maskote/Mimi.png" alt="" width={220} height={220} className="absolute right-2 top-6 maskota-lebdi hidden sm:block" aria-hidden priority />
          <p className="chip relative" style={{ color: '#FFD84D' }}>Glavna igra · 3 igrača</p>
          <h1 className="relative mt-3" style={{ fontSize: 'clamp(46px, 9vw, 92px)' }}>Osvajanje<br />sveta</h1>
          <p className="relative mt-4 text-[17px] font-semibold max-w-md opacity-90">
            Šest kontinenata, dvadeset četiri oblasti i dva rivala. Svaku bitku odlučuje pitanje.
          </p>
        </div>

        <section className="mt-8 grid md:grid-cols-[1fr_1fr] gap-5">
          <div className="card-soft p-6">
            <h2 className="text-[28px] mb-4">Nova partija</h2>
            <ul className="divide-y divide-[#E7E1D0]">
              {TEZINE.map(t => (
                <li key={t.id} className="py-3 flex items-center gap-3">
                  <span className="flex-1">
                    <span className="block font-bold">{t.ime}</span>
                    <span className="block text-[13px]" style={{ color: '#6F6C66' }}>{t.opis}</span>
                  </span>
                  <Link href={`/osvajanje/igra?tezina=${t.id}&krugova=6`} className="btn btn-secondary btn-sm">6 krugova</Link>
                  <Link href={`/osvajanje/igra?tezina=${t.id}&krugova=10`} className="btn btn-primary btn-sm">10 krugova</Link>
                </li>
              ))}
            </ul>
          </div>

          <div className="card-soft p-6">
            <h2 className="text-[28px] mb-4">Pravila</h2>
            <ol className="space-y-3">
              {PRAVILA.map(([naslov, tekst], i) => (
                <li key={naslov} className="flex gap-3">
                  <span className="w-7 h-7 shrink-0 rounded-lg grid place-items-center text-[13px] font-bold" style={{ background: '#FFD84D', border: '1.5px solid #151515' }}>{i + 1}</span>
                  <p className="text-[14px] leading-relaxed"><strong>{naslov}.</strong> {tekst}</p>
                </li>
              ))}
            </ol>
          </div>
        </section>
      </main>
      <Footer />
    </div>
  )
}
