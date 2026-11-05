'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { IconCheck } from '@/components/icons'

// Podešavanja prijema korisničkih pitanja. Čuvaju se u `admin_settings`
// kao tekst, a baza ih čita kroz `podesavanje_broj(kljuc, podrazumevano)`,
// koja loše upisanu vrednost tiho zameni podrazumevanom, pa greška ovde
// ne može da obori prijem pitanja.

export type Vrednosti = Record<string, string>

const POLJA = [
  {
    key: 'slicnost_prag',
    naziv: 'Prag sličnosti',
    podrazumevano: '0.85',
    korak: '0.01', min: '0.3', max: '1',
    opis: 'Koliko dva pitanja moraju da liče da bi novo bilo odbijeno kao blizanac. 1 je potpuno isti tekst, 0.85 hvata izmenjenu reč ili dve. Niže od 0.7 počinje da odbija ispravna pitanja.',
  },
  {
    key: 'slicnost_min_duzina',
    naziv: 'Najkraće pitanje koje se poredi',
    podrazumevano: '25',
    korak: '1', min: '10', max: '200',
    opis: 'Kratka pitanja liče na sve, pa se ispod ove dužine sličnost ne proverava. Broj znakova.',
  },
  {
    key: 'dnevni_limit_predloga',
    naziv: 'Dnevna granica po korisniku',
    podrazumevano: '100',
    korak: '1', min: '1', max: '1000',
    opis: 'Koliko predloga jedan nalog sme da pošalje u 24 sata, bez obzira na ishod.',
  },
  {
    key: 'limit_na_cekanju',
    naziv: 'Najviše nepregledanih po korisniku',
    podrazumevano: '500',
    korak: '1', min: '10', max: '5000',
    opis: 'Kad nalog nagomila ovoliko predloga koji čekaju proveru, ne prima se novi dok se ne pregledaju.',
  },
  {
    key: 'prag_bedza',
    naziv: 'Prag za bedž „Autor pitanja”',
    podrazumevano: '3',
    korak: '1', min: '1', max: '1000',
    opis: 'Koliko prihvaćenih pitanja nosi bedž. Vidi se na rang listi autora, u headeru, na profilu i na „Moja pitanja”.',
  },
  {
    key: 'auto_prihvatanje',
    naziv: 'Automatsko prihvatanje: 1 uključeno, 0 isključeno',
    podrazumevano: '0',
    korak: '1', min: '0', max: '1',
    opis: '⚠ Kad je uključeno, pitanja dokazanih autora ulaze u kviz BEZ uredničke provere. Uslovi su dva polja ispod.',
  },
  {
    key: 'auto_min_prihvacenih',
    naziv: 'Automatsko prihvatanje: najmanje prihvaćenih',
    podrazumevano: '25',
    korak: '1', min: '1', max: '1000',
    opis: 'Koliko pitanja autoru mora već biti prihvaćeno da bi mu se verovalo na reč.',
  },
  {
    key: 'auto_min_procenat',
    naziv: 'Automatsko prihvatanje: najmanji procenat prolaznosti',
    podrazumevano: '90',
    korak: '1', min: '50', max: '100',
    opis: 'Odnos prihvaćenih prema zbiru prihvaćenih i odbijenih, izražen u procentima.',
  },
]

export default function PredloziPodesavanja({ pocetne }: { pocetne: Vrednosti }) {
  const router = useRouter()
  const [vrednosti, setVrednosti] = useState<Vrednosti>(() =>
    Object.fromEntries(POLJA.map(p => [p.key, pocetne[p.key] ?? p.podrazumevano])),
  )
  const [busy, setBusy] = useState(false)
  const [poruka, setPoruka] = useState('')
  const [greska, setGreska] = useState('')

  async function sacuvaj() {
    setBusy(true); setGreska(''); setPoruka('')
    const supabase = createClient()
    const { data: { user } } = await supabase.auth.getUser()
    const redovi = POLJA.map(p => ({
      key: p.key,
      value: String(vrednosti[p.key] ?? p.podrazumevano),
      updated_at: new Date().toISOString(),
      updated_by: user?.id ?? null,
    }))
    const { error } = await supabase.from('admin_settings').upsert(redovi, { onConflict: 'key' })
    setBusy(false)
    if (error) { setGreska(error.message); return }
    setPoruka('Sačuvano.')
    setTimeout(() => setPoruka(''), 2500)
    router.refresh()
  }

  return (
    <section className="card-soft p-6">
      <h2 className="font-bold text-[16px] mb-1 tracking-tight" style={{ color: '#151515' }}>
        Prijem korisničkih pitanja
      </h2>
      <p className="text-[13px] mb-5 leading-relaxed" style={{ color: '#6F6C66' }}>
        Važi za stranu „Dodaj pitanja”. Vrednosti se primenjuju odmah, bez novog objavljivanja sajta.
      </p>

      <div className="space-y-5">
        {POLJA.map(p => (
          <div key={p.key}>
            <label className="block text-[13px] font-bold mb-1 tracking-tight" style={{ color: '#151515' }}>
              {p.naziv}
              <span className="font-normal ml-2" style={{ color: '#6F6C66' }}>
                podrazumevano {p.podrazumevano}
              </span>
            </label>
            <input type="number" step={p.korak} min={p.min} max={p.max}
              value={vrednosti[p.key]}
              onChange={e => setVrednosti(v => ({ ...v, [p.key]: e.target.value }))}
              className="input" />
            <p className="text-[11px] mt-1.5 leading-relaxed" style={{ color: '#6F6C66' }}>{p.opis}</p>
          </div>
        ))}
      </div>

      {greska && (
        <div className="rounded-2xl px-4 py-3 mt-4 text-[13px]" style={{ background: '#FFE3EA', color: '#C42B4F' }}>
          {greska}
        </div>
      )}
      {poruka && (
        <div className="rounded-2xl px-4 py-3 mt-4 text-[13px] flex items-center gap-2"
          style={{ background: '#DFF3EE', color: '#0E6F61' }}>
          <IconCheck size={14} className="text-[#0E6F61]" /> {poruka}
        </div>
      )}

      <button onClick={sacuvaj} disabled={busy} className="btn btn-primary btn-md w-full mt-5">
        {busy ? 'Čuvam…' : 'Sačuvaj podešavanja'}
      </button>
    </section>
  )
}
