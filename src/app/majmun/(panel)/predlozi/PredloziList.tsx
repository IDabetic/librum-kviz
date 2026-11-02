'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { IconCheck, IconWrong } from '@/components/icons'
import { segment, jePojam, VESANJE_KATEGORIJE } from '@/lib/segmenti'
import { zamerke, popravi } from '@/lib/pravopis'

type Profile = { first_name: string | null; nickname: string | null }
type Row = {
  id: string
  question_text: string
  correct_answer: string
  // Predlozi sa /dodaj-pitanja nose i tri netačna odgovora i segment;
  // stariji predlozi sa /predlozi-pitanje nemaju ništa od toga, pa se
  // ovde svuda računa sa praznim nizom i podrazumevanim 'pro'.
  wrong_answers: string[] | null
  segment: string | null
  genre: string | null
  source: string | null
  status: string | null
  reject_reason: string | null
  submitted_by: string | null
  submitter_email: string | null
  created_at: string
  profile: Profile | null
}

type Odluka = {
  id: string
  action: 'accept' | 'reject' | 'reopen'
  question?: string
  correct?: string
  wrong?: string[]
  genre?: string
  info?: string
  difficulty?: string
  reason?: string
}

// Sve odluke idu kroz serversku rutu: ona zna u koji fond ide koji
// segment i ona šalje mejl autoru. Iz pregledača se ne piše direktno.
async function posaljiOdluku(o: Odluka): Promise<string | null> {
  try {
    const res = await fetch('/api/admin/predlog-odluka', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(o),
    })
    const json = await res.json()
    return json?.ok ? null : (json?.error ?? 'Nepoznata greška')
  } catch {
    return 'Nema veze sa serverom'
  }
}

// Predlog je „kompletan” kad se može prihvatiti bez dopune: za pitanja
// tri različita netačna odgovora, za vešanje opis i ispravna kategorija.
function kompletan(r: Row): boolean {
  const seg = segment(r.segment ?? 'pro')
  if (jePojam(seg.key)) {
    const slova = r.question_text.replace(/[^\p{L}]/gu, '').length
    return slova >= 4 && slova <= 18
      && Boolean(r.correct_answer.trim())
      && !r.correct_answer.toLowerCase().includes(r.question_text.toLowerCase())
      && VESANJE_KATEGORIJE.some(k => k.toLowerCase() === (r.genre ?? '').toLowerCase())
  }
  const w = (r.wrong_answers ?? []).map(x => x?.trim()).filter(Boolean) as string[]
  if (w.length !== 3) return false
  return new Set([r.correct_answer.trim(), ...w].map(o => o.toLowerCase())).size === 4
}

// Ponuđeni razlozi odbijanja. Slobodan upis ostaje, ali retko je
// potreban: autor tu poruku vidi na svojoj strani, pa je bolje da bude
// ujednačena nego da je svaki urednik piše svojim rečima.
const RAZLOZI = [
  'Netačan podatak',
  'Već postoji slično pitanje',
  'Loše formulisano',
  'Nije u duhu segmenta',
  'Previše opšte poznato',
  'Odgovor nije jednoznačan',
]

export default function PredloziList({ rows, status }: { rows: Row[]; status: string }) {
  const router = useRouter()
  const [busy, setBusy] = useState<string | null>(null)
  const [openId, setOpenId] = useState<string | null>(null)
  const [oznaceni, setOznaceni] = useState<Set<string>>(new Set())
  const [grupno, setGrupno] = useState<string>('')
  const [odbijam, setOdbijam] = useState<Row | null>(null)

  const naCekanju = status === 'pending'
  const spremni = rows.filter(kompletan)

  function prebaci(id: string) {
    setOznaceni(prev => {
      const n = new Set(prev)
      if (n.has(id)) n.delete(id); else n.add(id)
      return n
    })
  }

  async function odbijSa(id: string, razlog: string) {
    setOdbijam(null)
    setBusy(id)
    const greska = await posaljiOdluku({ id, action: 'reject', reason: razlog })
    setBusy(null)
    if (greska) alert(`Nije prošlo: ${greska}`)
    router.refresh()
  }

  async function vrati(id: string) {
    setBusy(id)
    const greska = await posaljiOdluku({ id, action: 'reopen' })
    setBusy(null)
    if (greska) alert(`Nije prošlo: ${greska}`)
    router.refresh()
  }

  async function obrisi(id: string) {
    if (!confirm('Trajno obrisati ovaj predlog? Autor ga više neće videti u „Moja pitanja”.')) return
    setBusy(id)
    await createClient().from('question_submissions').delete().eq('id', id)
    setBusy(null); router.refresh()
  }

  // Grupno prihvatanje ide red po red namerno: fondovi su četiri
  // različite tabele, a ako jedan upis pukne treba znati koji i nastaviti.
  async function prihvatiOznacene() {
    const spisak = rows.filter(r => oznaceni.has(r.id) && kompletan(r))
    if (spisak.length === 0) return
    if (!confirm(`Prihvatiti ${spisak.length} ${spisak.length === 1 ? 'predlog' : 'predloga'} i upisati ih u fondove?`)) return

    setGrupno(`0 / ${spisak.length}`)
    let uspelo = 0
    const pali: string[] = []
    for (const r of spisak) {
      const greska = await posaljiOdluku({ id: r.id, action: 'accept' })
      if (greska) { pali.push(`${r.question_text.slice(0, 40)}… (${greska})`); continue }
      uspelo++
      setGrupno(`${uspelo} / ${spisak.length}`)
    }
    setGrupno('')
    setOznaceni(new Set())
    if (pali.length) alert(`Prihvaćeno ${uspelo}, nije prošlo ${pali.length}:\n\n${pali.join('\n')}`)
    router.refresh()
  }

  if (rows.length === 0) {
    return (
      <div className="card-soft py-16 text-center">
        <p className="font-bold text-[16px] mb-2" style={{ color: '#1A1A1E' }}>Nema predloga</p>
        <p className="text-[13px]" style={{ color: '#6B6760' }}>
          {naCekanju ? 'Sve je pregledano.' : 'U ovom pregledu nema ničega.'}
        </p>
      </div>
    )
  }

  return (
    <div className="space-y-3">
      {naCekanju && spremni.length > 0 && (
        <div className="card-soft p-4 flex flex-wrap items-center gap-3 sticky top-2 z-10">
          <button onClick={() => setOznaceni(new Set(oznaceni.size === spremni.length ? [] : spremni.map(r => r.id)))}
            className="text-[12px] font-semibold" style={{ color: '#3A36A0' }}>
            {oznaceni.size === spremni.length ? 'Poništi izbor' : `Označi sve kompletne (${spremni.length})`}
          </button>
          <span className="text-[12px]" style={{ color: '#6B6760' }}>
            Označeno: <strong>{oznaceni.size}</strong>
          </span>
          <button onClick={prihvatiOznacene} disabled={oznaceni.size === 0 || grupno !== ''}
            className="btn btn-sm ml-auto" style={{ background: '#2FBF8A', color: 'white' }}>
            <IconCheck size={14} className="text-white" />
            {grupno ? `Prihvatam ${grupno}…` : 'Prihvati označeno'}
          </button>
        </div>
      )}

      {odbijam && (
        <OdbijanjeModal row={odbijam} onZatvori={() => setOdbijam(null)}
          onPotvrdi={razlog => odbijSa(odbijam.id, razlog)} />
      )}

      {rows.map(r => {
        const submitter = r.profile?.nickname || r.profile?.first_name || r.submitter_email || 'Anon'
        const isOpen = openId === r.id
        const seg = segment(r.segment ?? 'pro')
        const pojam = jePojam(seg.key)
        const netacni = (r.wrong_answers ?? []).filter(Boolean)
        const potpun = kompletan(r)
        return (
          <div key={r.id} className="card-soft p-5 sm:p-6">
            <div className="flex items-start justify-between gap-3 mb-3">
              <div className="min-w-0 flex-1 flex items-start gap-3">
                {naCekanju && potpun && (
                  <input type="checkbox" checked={oznaceni.has(r.id)} onChange={() => prebaci(r.id)}
                    className="mt-1 w-4 h-4 flex-shrink-0" aria-label="Označi predlog" />
                )}
                <div className="min-w-0">
                  <p className="text-[11px] font-bold uppercase tracking-widest mb-1" style={{ color: '#6B6760' }}>
                    Predlog · {new Date(r.created_at).toLocaleDateString('sr')}
                  </p>
                  <p className="text-[14px]" style={{ color: '#6B6760' }}>{submitter}</p>
                </div>
              </div>
              {naCekanju && (
                <button onClick={() => setOpenId(isOpen ? null : r.id)}
                  className="text-[12px] font-semibold transition-opacity hover:opacity-70"
                  style={{ color: '#3A36A0' }}>
                  {isOpen ? 'Zatvori' : 'Uredi i prihvati →'}
                </button>
              )}
            </div>

            <div className="flex flex-wrap gap-1.5 mb-3">
              <span className="chip" style={{ background: seg.tint, color: seg.accent }}>
                {seg.emoji} {seg.label}
              </span>
              {r.genre && (
                <span className="chip" style={{ background: '#EBE8E1', color: '#1A1A1E' }}>{r.genre}</span>
              )}
              <span className="chip" style={{ background: '#EBE8E1', color: '#6B6760' }}>
                {r.source === 'xml' ? 'XML uvoz' : r.source === 'xlsx' ? 'Excel uvoz' : 'obrazac'}
              </span>
              <span className="chip" style={{
                background: potpun ? '#D4F3E7' : '#F5E6B8',
                color: potpun ? '#1F8A62' : '#8A6A12',
              }}>
                {potpun ? 'kompletno' : pojam ? 'treba dopuniti' : 'fale netačni'}
              </span>
            </div>

            <p className="font-bold text-[15px] mb-2" style={{ color: '#1A1A1E' }}>
              {r.question_text}
            </p>
            <div className="rounded-2xl px-4 py-3 mb-2" style={{ background: '#D4F3E7' }}>
              <p className="text-[11px] font-bold uppercase tracking-widest" style={{ color: '#1F8A62' }}>
                {pojam ? 'Opis' : 'Tačan odgovor'}
              </p>
              <p className="font-bold text-[14px] mt-1" style={{ color: '#1F8A62' }}>{r.correct_answer}</p>
            </div>

            {netacni.length > 0 && (
              <div className="rounded-2xl px-4 py-3 mb-3" style={{ background: '#FEE2E2' }}>
                <p className="text-[11px] font-bold uppercase tracking-widest mb-1" style={{ color: '#b91c1c' }}>
                  Netačni odgovori
                </p>
                <ul className="text-[13px] space-y-0.5" style={{ color: '#b91c1c' }}>
                  {netacni.map((n, i) => <li key={i}>· {n}</li>)}
                </ul>
              </div>
            )}

            {r.status === 'rejected' && r.reject_reason && (
              <p className="text-[12px] mb-3" style={{ color: '#b91c1c' }}>
                <strong>Razlog odbijanja:</strong> {r.reject_reason}
              </p>
            )}

            {isOpen && (
              <ConvertForm row={r} onSuccess={() => { setOpenId(null); router.refresh() }} />
            )}

            <div className="flex gap-2 mt-3">
              {naCekanju ? (
                <button onClick={() => setOdbijam(r)} disabled={busy === r.id}
                  className="btn btn-md flex-1" style={{ background: '#FEE2E2', color: '#b91c1c' }}>
                  <IconWrong size={14} /> Odbij
                </button>
              ) : (
                <>
                  <button onClick={() => vrati(r.id)} disabled={busy === r.id}
                    className="btn btn-md flex-1" style={{ background: '#EBE8E1', color: '#1A1A1E' }}>
                    Vrati na čekanje
                  </button>
                  <button onClick={() => obrisi(r.id)} disabled={busy === r.id}
                    className="btn btn-md" style={{ background: '#FEE2E2', color: '#b91c1c' }}>
                    <IconWrong size={14} /> Obriši
                  </button>
                </>
              )}
            </div>
          </div>
        )
      })}
    </div>
  )
}

function OdbijanjeModal({ row, onZatvori, onPotvrdi }: {
  row: Row; onZatvori: () => void; onPotvrdi: (razlog: string) => void
}) {
  const [izabrani, setIzabrani] = useState<string>(RAZLOZI[0])
  const [dodatno, setDodatno] = useState('')

  const razlog = [izabrani, dodatno.trim()].filter(Boolean).join(' — ')

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4"
      style={{ background: 'rgba(26,26,30,0.45)' }} onClick={onZatvori}>
      <div className="card-soft p-6 max-w-lg w-full" onClick={e => e.stopPropagation()}>
        <h3 className="font-bold text-[16px] mb-1 tracking-tight" style={{ color: '#1A1A1E' }}>
          Odbijanje predloga
        </h3>
        <p className="text-[12px] mb-4 leading-relaxed" style={{ color: '#6B6760' }}>
          Autor vidi razlog na svojoj strani „Moja pitanja”.
        </p>
        <p className="text-[13px] font-semibold mb-4 line-clamp-2" style={{ color: '#1A1A1E' }}>
          {row.question_text}
        </p>

        <div className="flex flex-wrap gap-2 mb-4">
          {RAZLOZI.map(r => (
            <button key={r} type="button" onClick={() => setIzabrani(r)}
              className="px-3 py-1.5 rounded-full text-[12px] font-semibold transition-all"
              style={izabrani === r
                ? { background: '#1A1A1E', color: 'white' }
                : { background: '#EBE8E1', color: '#1A1A1E' }}>
              {r}
            </button>
          ))}
        </div>

        <textarea value={dodatno} onChange={e => setDodatno(e.target.value)} rows={2}
          className="input resize-none mb-4" placeholder="Dopuna (opciono)" />

        <div className="flex gap-2">
          <button onClick={onZatvori} className="btn btn-md flex-1"
            style={{ background: '#EBE8E1', color: '#1A1A1E' }}>
            Odustani
          </button>
          <button onClick={() => onPotvrdi(razlog)} className="btn btn-md flex-1"
            style={{ background: '#FEE2E2', color: '#b91c1c' }}>
            <IconWrong size={14} /> Odbij
          </button>
        </div>
      </div>
    </div>
  )
}

function ConvertForm({ row, onSuccess }: { row: Row; onSuccess: () => void }) {
  const seg = segment(row.segment ?? 'pro')
  const pojam = jePojam(seg.key)
  const postojeci = (row.wrong_answers ?? []).filter(Boolean)
  // Tekst i odgovor su izmenjivi: urednik često treba samo da doda
  // upitnik ili popravi padež, a do sad je morao u bazu ručno.
  const [pitanje, setPitanje] = useState(row.question_text)
  const [tacan, setTacan] = useState(row.correct_answer)
  const [w1, setW1] = useState(postojeci[0] ?? '')
  const [w2, setW2] = useState(postojeci[1] ?? '')
  const [w3, setW3] = useState(postojeci[2] ?? '')
  const [info, setInfo] = useState('')
  const [zanr, setZanr] = useState(
    pojam
      ? (VESANJE_KATEGORIJE.find(k => k.toLowerCase() === (row.genre ?? '').toLowerCase()) ?? VESANJE_KATEGORIJE[0])
      : (row.genre ?? 'Razno'),
  )
  const [difficulty, setDifficulty] = useState('medium')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  // Zamerke se računaju pri svakom kucanju: spisak je kratak i sve
  // provere su obične provere teksta.
  const nadjene = pojam ? [] : zamerke(pitanje, [tacan, w1, w2, w3])

  async function accept() {
    setError('')
    if (!pitanje.trim() || !tacan.trim()) {
      setError(pojam ? 'Pojam i opis moraju biti popunjeni.' : 'Pitanje i tačan odgovor moraju biti popunjeni.')
      return
    }
    if (!pojam && (!w1.trim() || !w2.trim() || !w3.trim())) {
      setError('Sva 3 pogrešna odgovora moraju biti popunjena.')
      return
    }
    setBusy(true)
    const greska = await posaljiOdluku({
      id: row.id,
      action: 'accept',
      question: pitanje,
      correct: tacan,
      wrong: pojam ? [] : [w1, w2, w3],
      genre: zanr,
      info,
      difficulty,
    })
    setBusy(false)
    if (greska) { setError(greska); return }
    onSuccess()
  }

  return (
    <div className="rounded-2xl p-4 mt-3" style={{ background: '#EBE8E1' }}>
      <p className="text-[11px] font-bold uppercase tracking-widest mb-3" style={{ color: '#6B6760' }}>
        Prihvatanje u fond: <span style={{ color: seg.accent }}>{seg.label}</span>
        <span style={{ color: '#6B6760' }}> · {seg.table}</span>
      </p>

      {error && <div className="rounded-xl px-3 py-2 text-[12px] mb-3" style={{ background: '#FEE2E2', color: '#b91c1c' }}>{error}</div>}

      <label className="block text-[11px] font-bold mb-1" style={{ color: '#6B6760' }}>
        {pojam ? 'Pojam' : 'Pitanje'}
      </label>
      {pojam ? (
        <input value={pitanje} onChange={e => setPitanje(e.target.value)} className="input mb-3" />
      ) : (
        <textarea value={pitanje} onChange={e => setPitanje(e.target.value)} rows={2}
          className="input resize-none mb-3" />
      )}

      {nadjene.length > 0 && (
        <div className="rounded-xl px-3 py-2.5 mb-3 text-[12px]"
          style={{ background: '#F5E6B8', color: '#8A6A12' }}>
          <ul className="space-y-0.5 mb-2">
            {nadjene.map(z => <li key={z.kod}>· {z.poruka}</li>)}
          </ul>
          <button type="button" onClick={() => setPitanje(popravi(pitanje))}
            className="font-bold underline">
            Popravi automatski
          </button>
          <span className="opacity-80"> (razmaci, veliko početno slovo, upitnik; pismo se ne dira)</span>
        </div>
      )}

      <label className="block text-[11px] font-bold mb-1" style={{ color: '#6B6760' }}>
        {pojam ? 'Opis' : 'Tačan odgovor'}
      </label>
      <input value={tacan} onChange={e => setTacan(e.target.value)} className="input mb-3" />

      {!pojam && (
        <div className="space-y-2 mb-3">
          <input value={w1} onChange={e => setW1(e.target.value)} className="input" placeholder="Pogrešan 1" />
          <input value={w2} onChange={e => setW2(e.target.value)} className="input" placeholder="Pogrešan 2" />
          <input value={w3} onChange={e => setW3(e.target.value)} className="input" placeholder="Pogrešan 3" />
        </div>
      )}

      {pojam ? (
        <select value={zanr} onChange={e => setZanr(e.target.value)} className="input mb-3">
          {VESANJE_KATEGORIJE.map(k => <option key={k} value={k}>{k}</option>)}
        </select>
      ) : seg.key === 'book' ? (
        <input value={zanr} onChange={e => setZanr(e.target.value)} className="input mb-3" placeholder="Žanr (npr. Roman)" />
      ) : (
        <textarea value={info} onChange={e => setInfo(e.target.value)} className="input resize-none mb-3" rows={2}
          placeholder="Objašnjenje (opciono)" />
      )}

      {!pojam && (
        <select value={difficulty} onChange={e => setDifficulty(e.target.value)} className="input mb-3">
          <option value="easy">Lako</option>
          <option value="medium">Srednje</option>
          <option value="hard">Teško</option>
          <option value="impossible">Nemoguće</option>
        </select>
      )}

      <button onClick={accept} disabled={busy} className="btn btn-md w-full" style={{ background: '#2FBF8A', color: 'white' }}>
        <IconCheck size={14} className="text-white" />
        {busy ? 'Prihvatanje…' : 'Prihvati i dodaj u bazu'}
      </button>
    </div>
  )
}
