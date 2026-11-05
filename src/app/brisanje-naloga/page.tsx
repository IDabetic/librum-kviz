import type { Metadata } from 'next'
import Link from 'next/link'
import Header from '@/components/Header'
import Footer from '@/components/Footer'

export const metadata: Metadata = {
  title: 'Brisanje naloga',
  description: 'Kako da obrišete nalog u aplikaciji Librum kviz i koji se podaci brišu.',
  alternates: { canonical: '/brisanje-naloga' },
}

/** Google Play traži javnu stranu za zahtev brisanja naloga (Data safety); sajt nema prijavu, pa su tu oba puta. */
export default function BrisanjeNaloga() {
  return (
    <div className="min-h-screen flex flex-col" style={{ background: '#F6F1E7' }}>
      <Header />
      <main className="flex-1 max-w-3xl mx-auto px-4 sm:px-6 py-10 sm:py-14 w-full">
        <p className="text-[13px] font-bold uppercase tracking-widest mb-2" style={{ color: '#23845C' }}>Librum kviz</p>
        <h1 className="naslov leading-[1.05] mb-3" style={{ color: '#1A1B3A', fontSize: 'clamp(36px, 7vw, 48px)' }}>Brisanje naloga</h1>
        <p className="text-[13px] mb-8" style={{ color: '#4F5170' }}>Ažurirano: 3. novembar 2026. · verzija 1</p>
        <article className="card-soft p-7 sm:p-10 space-y-7 text-[15px] leading-relaxed" style={{ color: '#1A1B3A' }}>
          <section className="space-y-3">
            <h2 className="font-black text-[20px] tracking-tight">1. U aplikaciji (odmah)</h2>
            <ol className="list-decimal pl-5 space-y-1">
              <li>Otvorite Librum kviz i karticu <strong>Profil</strong>.</li>
              <li>iPhone: dodirnite zupčanik <strong>Podešavanja</strong>, pa na dnu <strong>Obriši nalog</strong>. Android: na dnu profila <strong>Obriši nalog</strong>.</li>
              <li>Potvrdite. Nalog se briše odmah i ne može da se vrati.</li>
            </ol>
          </section>
          <section className="space-y-3">
            <h2 className="font-black text-[20px] tracking-tight">2. Bez aplikacije (e-poštom)</h2>
            <p>
              Pišite sa adrese kojom ste se registrovali na{' '}
              <a href="mailto:info@librum.club?subject=Brisanje%20naloga%20Librum%20kviz" className="underline" style={{ color: '#23845C' }}>info@librum.club</a>{' '}
              sa naslovom „Brisanje naloga Librum kviz” i nadimkom iz igre. Nalog brišemo u roku od 7 dana i javljamo kad je gotovo.
            </p>
          </section>
          <section className="space-y-3">
            <h2 className="font-black text-[20px] tracking-tight">3. Šta se briše</h2>
            <p>Nalog i prijava, profil (nadimak, avatar, ime, prezime, grad, opis), rezultati i rang, objave, komentari, srca, praćenja, poruke, prijave i blokade, partije i izazovi.</p>
          </section>
          <section className="space-y-3">
            <h2 className="font-black text-[20px] tracking-tight">4. Šta ostaje i koliko</h2>
            <p>Tehnički zapisi o greškama i pristupu (bez sadržaja poruka) čuvaju se najviše 90 dana, pa se brišu. Pitanja koja ste predložili, a urednik ih je objavio, ostaju u igri bez vašeg imena. Zbirna statistika odgovora na pitanja ostaje, ali bez ikakve veze sa vama.</p>
          </section>
          <p className="text-[14px]" style={{ color: '#4F5170' }}>
            Više u <Link href="/politika-privatnosti" className="underline" style={{ color: '#23845C' }}>politici privatnosti</Link>.
          </p>
        </article>
      </main>
      <Footer />
    </div>
  )
}
