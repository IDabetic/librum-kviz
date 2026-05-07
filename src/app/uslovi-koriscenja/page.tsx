import type { Metadata } from 'next'
import Header from '@/components/Header'
import Footer from '@/components/Footer'
import { createClient } from '@/lib/supabase/server'
import Link from 'next/link'
import { Logo } from '@/components/Logo'

export const metadata: Metadata = {
  title: 'Uslovi korišćenja | Librum Kviz',
  description: 'Uslovi korišćenja servisa Librum kviz — pravila i obaveze korisnika i pružaoca usluge.',
  alternates: { canonical: '/uslovi-koriscenja' },
}

export default async function UsloviKoriscenja() {
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
            <Logo height={28} />
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
          Uslovi korišćenja
        </h1>
        <p className="text-[13px] mb-8" style={{ color: '#9C9C9C' }}>
          Poslednja izmena: maj 2026.
        </p>

        <article className="card-soft p-7 sm:p-10 space-y-6 text-[15px] leading-relaxed" style={{ color: '#343434' }}>
          <Section title="1. Prihvatanje uslova">
            <p>
              Pristupom platformi Librum kviz na adresi <strong>kviz.librum.club</strong> (u daljem tekstu „Servis“) i njenom upotrebom
              prihvatate ove uslove korišćenja u celosti. Ako se ne slažete sa njima, molimo vas da ne koristite Servis.
              Ovi uslovi predstavljaju ugovor između vas (u daljem tekstu „Korisnik“) i Librum tima koji vodi Servis.
            </p>
          </Section>

          <Section title="2. Šta je Servis">
            <p>
              Servis je besplatna onlajn platforma za kratke igre znanja na srpskom jeziku — PRO kviz, Brzi kviz, Trivia duel,
              Vešanje, Book kviz i Kafanski kviz. Korišćenjem Servisa pristajete na ova pravila.
            </p>
          </Section>

          <Section title="3. Registracija i nalog">
            <p>
              Za pristup većini funkcionalnosti potrebna je registracija. Tom prilikom dajete tačne i ažurne podatke
              i preuzimate odgovornost za sve aktivnosti pod svojim nalogom. Lozinku ne smete deliti sa trećim licima.
              Ako uočite neovlašćen pristup, obavezni ste da nas obavestite na <a href="mailto:info@librum.club" className="underline" style={{ color: '#609DED' }}>info@librum.club</a>.
            </p>
            <p>Servis je namenjen korisnicima starijim od 13 godina. Ako ste mlađi, potrebna vam je saglasnost roditelja ili staratelja.</p>
          </Section>

          <Section title="4. Pravila ponašanja">
            <p>Korišćenjem Servisa obavezujete se da nećete:</p>
            <ul className="list-disc pl-5 space-y-1">
              <li>Koristiti automatske alate, skripte ili botove za igranje, prikupljanje pitanja ili manipulaciju rezultatima.</li>
              <li>Prijavljivati se sa više naloga radi varanja, manipulacije rang liste ili izbegavanja zabrane.</li>
              <li>Postavljati uvredljiv, vulgaran, diskriminatoran, klevetnički ili sadržaj koji krši važeće zakone (ovo važi za nadimke, predloge pitanja i druge unose).</li>
              <li>Pokušavati da provalite, narušite bezbednost ili preopterećujete infrastrukturu Servisa.</li>
              <li>Reverse-engineering-ujete kod, kopirate bazu pitanja u celosti ili je ponovo objavljujete bez dozvole.</li>
            </ul>
            <p>Kršenje ovih pravila može dovesti do <strong>privremene ili trajne suspenzije naloga</strong> bez prethodnog upozorenja, kao i do uklanjanja unetog sadržaja.</p>
          </Section>

          <Section title="5. Sadržaj koji ti uneseš">
            <p>
              Kada predložiš pitanje, prijaviš grešku ili napišeš javni komentar, daješ Librum-u <strong>neisključivu, besplatnu i opozivu licencu</strong>
              da taj sadržaj koristi, prilagođava i objavljuje u okviru Servisa. Zadržavaš autorska prava na svoj originalni sadržaj.
              Garantuješ da uneti sadržaj ne krši autorska prava trećih lica niti druge zakone.
            </p>
            <p>
              Pitanja u igrama mogu sadržati informacije iz javno dostupnih izvora (Wikipedia, enciklopedije i sl.). Ako smatraš da neko pitanje
              krši nečija prava, javi nam preko opcije <strong>„Prijavi pitanje“</strong> ili na e-mail.
            </p>
          </Section>

          <Section title="6. Intelektualna svojina Librum-a">
            <p>
              Sav vizuelni identitet, logo, dizajn aplikacije, ilustracije i kod su vlasništvo Librum-a, osim onoga što je posebno označeno kao tuđe.
              Bez pisane saglasnosti ne smete kopirati, modifikovati niti distribuirati ove materijale.
            </p>
          </Section>

          <Section title="7. Besplatno korišćenje">
            <p>
              Servis je trenutno besplatan. Zadržavamo pravo da ubuduće uvedemo opcione plaćene funkcionalnosti (npr. eksluzivne kvizove, takmičenja),
              ali postojeći besplatan deo neće biti ukinut bez prethodnog obaveštenja.
            </p>
          </Section>

          <Section title="8. Dostupnost servisa">
            <p>
              Trudimo se da Servis bude dostupan 24/7, ali ne garantujemo neprekidan rad. Možemo privremeno obustaviti rad zbog održavanja,
              nadogradnje ili više sile, bez prethodne najave. U skladu sa zakonom, ne odgovaramo za štetu nastalu zbog nedostupnosti Servisa.
            </p>
          </Section>

          <Section title="9. Ograničenje odgovornosti">
            <p>
              Servis je namenjen zabavi i obrazovanju. Pitanja se prikupljaju iz različitih izvora i premda se trudimo da budu tačna,
              <strong> ne garantujemo apsolutnu tačnost</strong> svakog pitanja niti odgovornost za bilo kakve odluke koje korisnici donesu na osnovu sadržaja.
            </p>
            <p>
              Librum nije odgovoran za bilo kakvu posrednu, posledičnu ili slučajnu štetu koja proistekne iz korišćenja Servisa, u meri u kojoj
              to dozvoljava važeći zakon.
            </p>
          </Section>

          <Section title="10. Brisanje naloga">
            <p>
              U svakom trenutku možeš da zatražiš brisanje naloga i svih povezanih podataka slanjem e-maila na
              {' '}<a href="mailto:info@librum.club" className="underline" style={{ color: '#609DED' }}>info@librum.club</a>.
              Brisanje izvršavamo u roku od 7 dana.
            </p>
            <p>
              Sa naše strane, možemo ukloniti nalog koji prekrši ova pravila, sa ili bez prethodne opomene.
            </p>
          </Section>

          <Section title="11. Izmene uslova">
            <p>
              Ove uslove možemo da izmenimo. Bitne izmene najavljujemo na ovoj stranici i, kada je primereno, e-mailom registrovanim korisnicima.
              Nastavak korišćenja Servisa nakon objave izmena znači da ih prihvataš.
            </p>
          </Section>

          <Section title="12. Merodavno pravo">
            <p>
              Na ove uslove primenjuje se <strong>pravo Republike Srbije</strong>. Sva sporna pitanja koja ne mogu biti rešena dogovorom rešavaće
              stvarno nadležan sud u Beogradu.
            </p>
          </Section>

          <Section title="13. Kontakt">
            <p>
              Pitanja u vezi sa ovim uslovima šalji na <a href="mailto:info@librum.club" className="underline" style={{ color: '#609DED' }}>info@librum.club</a>.
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
