import Header from './Header'
import Footer from './Footer'
import pravno from '@/lib/igre/pravno.json'

type Deo = { naslov: string; tekst: string[] }
type Dokument = { naslov: string; azurirano: string; delovi: Deo[] }

/**
 * Pravni tekst sajta iz istog fajla koji čita aplikacija (src/lib/igre/pravno.json), da web i app nikad ne kažu različito.
 *
 * @example <PravniDokument vrsta="privatnost" />
 */
export default function PravniDokument({ vrsta }: { vrsta: 'privatnost' | 'uslovi' | 'licence' }) {
  const d = (pravno as Record<string, Dokument>)[vrsta]
  return (
    <div className="min-h-screen flex flex-col" style={{ background: '#F3F0E6' }}>
      <Header />
      <main className="flex-1 max-w-3xl mx-auto px-4 sm:px-6 py-10 sm:py-14 w-full">
        <p className="text-[13px] font-bold uppercase tracking-widest mb-2" style={{ color: '#12907E' }}>Pravna obaveštenja</p>
        <h1 className="naslov leading-[1.05] mb-3" style={{ color: '#151515', fontSize: 'clamp(36px, 7vw, 48px)' }}>{d.naslov}</h1>
        <p className="text-[13px] mb-8" style={{ color: '#6F6C66' }}>{d.azurirano}</p>
        <article className="card-soft p-7 sm:p-10 space-y-7 text-[15px] leading-relaxed" style={{ color: '#151515' }}>
          {d.delovi.map((deo, i) => (
            <section key={deo.naslov} className="space-y-3">
              <h2 className="font-black text-[20px] tracking-tight">{i + 1}. {deo.naslov}</h2>
              {deo.tekst.map(t => <p key={t}>{t}</p>)}
            </section>
          ))}
        </article>
      </main>
      <Footer />
    </div>
  )
}
