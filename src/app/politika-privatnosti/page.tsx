import type { Metadata } from 'next'
import Header from '@/components/Header'
import Footer from '@/components/Footer'
import { createClient } from '@/lib/supabase/server'
import Link from 'next/link'
import { Logo } from '@/components/Logo'

export const metadata: Metadata = {
  title: 'Politika privatnosti | Librum Kviz',
  description: 'Politika privatnosti — kako Librum kviz prikuplja, koristi i čuva podatke korisnika.',
  alternates: { canonical: '/politika-privatnosti' },
}

export default async function PolitikaPrivatnosti() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  return (
    <div className="min-h-screen flex flex-col" style={{ background: '#FAFAFA' }}>
      {user ? (
        <Header />
      ) : (
        <nav className="sticky top-0 z-40 backdrop-blur-xl"
          style={{ background: 'rgba(252,252,252,0.78)', borderBottom: '1px solid rgba(52,52,52,0.06)' }}>
          <div className="max-w-6xl mx-auto px-4 sm:px-6 h-16 flex items-center justify-between">
            <Logo height={36} />
            <Link href="/auth/prijava" className="btn btn-primary btn-sm">Prijava</Link>
          </div>
        </nav>
      )}

      <main className="flex-1 max-w-3xl mx-auto px-4 sm:px-6 py-10 sm:py-14 w-full">
        <p className="text-[13px] font-bold uppercase tracking-widest mb-2" style={{ color: '#609DED' }}>
          Pravna obaveštenja
        </p>
        <h1 className="font-black tracking-tight leading-[1.05] mb-3"
          style={{ color: '#343434', fontSize: 'clamp(36px, 7vw, 48px)' }}>
          Politika privatnosti
        </h1>
        <p className="text-[13px] mb-8" style={{ color: '#9C9C9C' }}>
          Poslednja izmena: maj 2026.
        </p>

        <article className="card-soft p-7 sm:p-10 space-y-6 text-[15px] leading-relaxed" style={{ color: '#343434' }}>
          <Section title="1. Ko smo">
            <p>
              Librum kviz (u daljem tekstu „Servis“) je besplatna onlajn platforma za igre znanja na srpskom jeziku,
              dostupna na adresi <strong>kviz.librum.club</strong>. Servis vodi <strong>Librum</strong>, a kontakt za sva pitanja vezana
              za privatnost je <a href="mailto:info@librum.club" className="underline" style={{ color: '#609DED' }}>info@librum.club</a>.
            </p>
            <p>
              Ova politika opisuje koje podatke prikupljamo, zašto ih prikupljamo, kako ih koristimo i čuvamo, sa kim ih delimo
              i koja prava imate u vezi sa svojim podacima. Politika je usaglašena sa Zakonom o zaštiti podataka o ličnosti
              Republike Srbije i Opštom uredbom Evropske unije o zaštiti podataka (GDPR).
            </p>
          </Section>

          <Section title="2. Koje podatke prikupljamo">
            <p>Da biste igrali kao prijavljen korisnik, prikupljamo:</p>
            <ul className="list-disc pl-5 space-y-1">
              <li><strong>E-mail adresa</strong> — koristi se za prijavu, oporavak lozinke i obavezna obaveštenja vezana za nalog.</li>
              <li><strong>Ime i prezime</strong> (opciono) — koje unesete pri registraciji ili u podešavanjima.</li>
              <li><strong>Nadimak (nickname)</strong> i <strong>avatar</strong> — vidljivi na rang listi i javnim profilima.</li>
              <li><strong>Lozinka</strong> — čuva se isključivo u kriptovanom obliku (hash); mi joj nikada nemamo pristup.</li>
              <li><strong>Rezultati igara</strong> — bodovi, broj odgovorenih pitanja, tačnost, vreme, datum partije; potrebno za rang listu i statistiku.</li>
              <li><strong>Tehnički podaci</strong> — anonimizovana IP adresa, tip uređaja i pregledača; koriste se za bezbednost i otkrivanje zloupotreba.</li>
            </ul>
            <p>Nikada ne prikupljamo osetljive podatke (zdravstvene, biometrijske, podatke o veroispovesti i sl.) niti tražimo brojeve dokumenata, kartica ili sličnih ličnih isprava.</p>
          </Section>

          <Section title="3. Zašto koristimo podatke">
            <ul className="list-disc pl-5 space-y-1">
              <li>Da vam omogućimo prijavu, čuvanje rezultata i prikaz na rang listi.</li>
              <li>Da održavamo servis bezbednim (sprečavanje varanja, spama i zloupotrebe).</li>
              <li>Da vam pošaljemo važna obaveštenja o nalogu (npr. oporavak lozinke).</li>
              <li>Da unapređujemo Servis na osnovu agregirane statistike (broj partija, populacija pitanja, tačnost — bez identifikacije pojedinaca).</li>
            </ul>
            <p>Vaše podatke <strong>ne prodajemo</strong> trećim licima i ne koristimo ih za reklamno targetiranje van platforme.</p>
          </Section>

          <Section title="4. Pravni osnov">
            <p>
              Obrada se vrši na osnovu vaše <strong>saglasnosti</strong> (registracija) i <strong>izvršenja ugovora</strong> o korišćenju
              Servisa, u skladu sa članom 12 Zakona o zaštiti podataka o ličnosti („Sl. glasnik RS“ br. 87/2018).
              Tehnički logovi se čuvaju po osnovu legitimnog interesa (bezbednost servisa).
            </p>
          </Section>

          <Section title="5. Sa kim delimo podatke">
            <p>
              Za hostovanje aplikacije i bazu podataka koristimo proverene partnere:
            </p>
            <ul className="list-disc pl-5 space-y-1">
              <li><strong>Vercel Inc.</strong> (hosting Web aplikacije, EU regije)</li>
              <li><strong>Supabase</strong> (baza podataka i autentifikacija, EU regija — Frankfurt)</li>
              <li><strong>Resend</strong> (slanje obaveznih e-mail poruka kao što je oporavak lozinke)</li>
              <li><strong>Google Analytics</strong> (anonimna analitika posete)</li>
            </ul>
            <p>
              Sa ovim partnerima imamo sklopljene ugovore o obradi podataka (DPA) koji obezbeđuju isti nivo zaštite kao i mi.
              Podatke ne prosleđujemo organima izvan EU/EEA osim ako to ne zahteva zakon.
            </p>
          </Section>

          <Section title="6. Kolačići">
            <p>
              Servis koristi minimalan broj kolačića: <strong>tehnički neophodne</strong> (sesija prijave, CSRF zaštita) i <strong>analitičke</strong> (anonimna posećenost preko Google Analytics).
              Tehnički kolačići se ne mogu isključiti bez gubitka funkcionalnosti. Analitičke možete isključiti u podešavanjima vašeg pregledača.
            </p>
          </Section>

          <Section title="7. Koliko dugo čuvamo podatke">
            <ul className="list-disc pl-5 space-y-1">
              <li>Podaci o nalogu — dok je nalog aktivan, ili dok ne zatražite brisanje.</li>
              <li>Rezultati partija — dok je nalog aktivan; brišu se kada obrišete nalog.</li>
              <li>Tehnički logovi — najviše 90 dana.</li>
            </ul>
          </Section>

          <Section title="8. Vaša prava">
            <p>Kao korisnik imate pravo da:</p>
            <ul className="list-disc pl-5 space-y-1">
              <li>Pristupite svojim podacima i dobijete kopiju.</li>
              <li>Izmenite ili dopunite netačne podatke (kroz podešavanja profila).</li>
              <li>Zatražite brisanje naloga i svih povezanih podataka.</li>
              <li>Povučete saglasnost u svakom trenutku.</li>
              <li>Podnesete prigovor Povereniku za informacije od javnog značaja i zaštitu podataka o ličnosti
                (<a href="https://poverenik.rs" target="_blank" rel="noopener" className="underline" style={{ color: '#609DED' }}>poverenik.rs</a>).</li>
            </ul>
            <p>Zahtev za bilo koje od ovih prava šaljete na <a href="mailto:info@librum.club" className="underline" style={{ color: '#609DED' }}>info@librum.club</a> sa naslovom „Zahtev za zaštitu podataka“. Odgovaramo u roku od 30 dana.</p>
          </Section>

          <Section title="9. Bezbednost">
            <p>
              Komunikacija sa Servisom je u potpunosti šifrovana (HTTPS/TLS). Lozinke su hash-ovane (bcrypt). Pristup bazi imaju samo administratori,
              a sva pisanja se evidentiraju. U slučaju proboja koji bi mogao da ugrozi vaše podatke, obavestićemo vas i Poverenika u zakonskom roku
              od 72 sata.
            </p>
          </Section>

          <Section title="10. Maloletnici">
            <p>
              Servis je namenjen korisnicima starijim od <strong>13 godina</strong>. Ako imate manje, pre registracije neophodna je saglasnost roditelja ili staratelja.
              Ne tražimo namerno podatke od dece mlađe od 13 godina i takve naloge ćemo obrisati čim ih identifikujemo.
            </p>
          </Section>

          <Section title="11. Izmene politike">
            <p>
              Ovu politiku možemo da izmenimo. Bitne izmene najavljujemo na ovoj stranici i, kada je to primereno, e-mailom.
              Datum poslednje izmene je naveden pri vrhu stranice.
            </p>
          </Section>

          <Section title="12. Kontakt">
            <p>
              Za sva pitanja o privatnosti pišite nam na <a href="mailto:info@librum.club" className="underline" style={{ color: '#609DED' }}>info@librum.club</a>.
              Trudimo se da odgovorimo u roku od 5 radnih dana.
            </p>
          </Section>
        </article>
      </main>

      <Footer />
    </div>
  )
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="space-y-3">
      <h2 className="font-black text-[20px] tracking-tight" style={{ color: '#343434' }}>{title}</h2>
      <div className="space-y-3">{children}</div>
    </section>
  )
}
