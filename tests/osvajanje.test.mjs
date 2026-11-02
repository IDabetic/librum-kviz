// Pokretanje: npm test  (Node 23+ sam skida tipove sa .ts fajla)
import { test } from 'node:test'
import assert from 'node:assert/strict'
import * as P from '../src/lib/osvajanje/pravila.ts'

const nova = (seme = 1) => P.napraviPartiju({ krugova: 12, tezina: 'normalno', slucajno: P.napraviSlucajno(seme) })

/** Stanje u fazi napada sa zadatim vlasnicima, bez ostalih igrača u blizini. */
function napad(vlasnici) {
  const s = { ...nova(), faza: 'napad', oblasti: { ...nova().oblasti } }
  for (const o of P.OBLASTI) s.oblasti[o.id] = { vlasnik: null, vojske: 1 }
  for (const [id, vlasnik, vojske] of vlasnici) s.oblasti[id] = { vlasnik, vojske }
  return s
}

test('mapa: 171 država, svaka ima region i ime, veze simetrične, sve povezano', () => {
  assert.equal(P.OBLASTI.length, 171)
  for (const o of P.OBLASTI) {
    assert.ok(P.REGIONI.some(r => r.id === o.region), o.id)
    assert.ok(o.ime && o.d.startsWith('M'), o.id)
    for (const n of P.susedi(o.id)) assert.ok(P.susedi(n).includes(o.id), `${o.id} ↔ ${n}`)
  }
  const vidjeno = new Set(['SRB'])
  const red = ['SRB']
  while (red.length) for (const n of P.susedi(red.pop())) if (!vidjeno.has(n)) { vidjeno.add(n); red.push(n) }
  assert.equal(vidjeno.size, 171)
  assert.ok(P.susedi('SRB').includes('BGR') && P.susedi('SRB').includes('HUN'))
})

test('početak: tri prestonice u različitim regionima, po šest država svakom', () => {
  for (const seme of [1, 2, 3, 4, 5]) {
    const s = nova(seme)
    assert.equal(new Set(s.igraci.map(p => P.oblast(p.prestonica).region)).size, 3)
    for (const p of s.igraci) {
      assert.equal(P.oblastiIgraca(s, p.id).length, P.POCETNIH_DRZAVA)
      assert.equal(s.oblasti[p.prestonica].vojske, P.POCETNE_VOJSKE_PRESTONICE)
    }
  }
})

test('snabdevanje: tačno daje najmanje 3, netačno pola, pa raspored prelazi u napad', () => {
  const s = nova()
  assert.equal(P.snabdevanje(s, true).zaRaspored, 3)
  let r = P.snabdevanje(s, false)
  assert.equal(r.zaRaspored, 1)
  r = P.rasporedi(r, s.igraci[0].prestonica)
  assert.equal(r.faza, 'napad')
})

test('bitka protiv neutralne: tačno osvaja, vojske prelaze i može se dalje', () => {
  const s = napad([['SRB', 'ti', 5]])
  const { stanje, ishod } = P.razresiBitku(s, 'SRB', 'BGR', { tacan: true, ms: 1 }, null)
  assert.ok(ishod.osvojeno)
  assert.equal(stanje.oblasti.BGR.vlasnik, 'ti')
  assert.equal(stanje.oblasti.SRB.vojske, 1)
  assert.equal(stanje.oblasti.BGR.vojske, 4)
  assert.ok(P.mete(stanje, 'BGR').includes('TUR'), 'iz Bugarske dalje na Tursku')
})

test('bitka protiv igrača: brži tačan pobeđuje, oba netačna gube po jednu', () => {
  const s = napad([['SRB', 'ti', 5], ['BGR', 'mimi', 4]])
  let r = P.razresiBitku(s, 'SRB', 'BGR', { tacan: true, ms: 2000 }, { tacan: true, ms: 5000 })
  assert.equal(r.stanje.oblasti.BGR.vojske, 3)
  r = P.razresiBitku(s, 'SRB', 'BGR', { tacan: false, ms: 1 }, { tacan: false, ms: 1 })
  assert.equal(r.stanje.oblasti.SRB.vojske, 4)
  assert.equal(r.stanje.oblasti.BGR.vojske, 3)
  r = P.razresiBitku(s, 'SRB', 'BGR', { tacan: false, ms: 1 }, { tacan: true, ms: 1 })
  assert.equal(r.stanje.oblasti.SRB.vojske, 3)
})

test('treće osvajanje u nizu donosi proboj (+2), tuđa prestonica plen (+5)', () => {
  let s = napad([['SRB', 'ti', 12]])
  let tren = 'SRB'
  let poslednji
  for (const meta of ['BGR', 'TUR', 'GRC']) {
    const r = P.razresiBitku(s, tren, meta, { tacan: true, ms: 1 }, null)
    s = r.stanje; tren = meta; poslednji = r.ishod
  }
  assert.ok(poslednji.proboj)
  const t = napad([['SRB', 'ti', 6], ['HUN', 'mimi', 1]])
  t.igraci = t.igraci.map(p => (p.id === 'mimi' ? { ...p, prestonica: 'HUN' } : p))
  const r = P.razresiBitku(t, 'SRB', 'HUN', { tacan: true, ms: 1 }, { tacan: false, ms: 1 })
  assert.ok(r.ishod.plen)
  assert.equal(r.stanje.oblasti.HUN.vojske, 5 + P.PLEN_PRESTONICE)
})

test('ceo region donosi bonus u pojačanjima', () => {
  const s = napad(P.OBLASTI.filter(o => o.region === 'zev').map(o => [o.id, 'ti', 1]))
  const bonus = P.REGIONI.find(r => r.id === 'zev').bonus
  assert.equal(P.bonusRegiona({ ...s, faza: 'snabdevanje' }, 'ti'), bonus)
  assert.equal(P.pojacanja(s, 'ti', true), 3 + bonus)
})

test('zavrsiPotez vrti igrače i završava posle poslednjeg kruga', () => {
  let s = P.napraviPartiju({ krugova: 1, tezina: 'lako', slucajno: P.napraviSlucajno(9) })
  s = P.zavrsiPotez(s); assert.equal(s.naPotezu, 1)
  s = P.zavrsiPotez(s); assert.equal(s.naPotezu, 2)
  s = P.zavrsiPotez(s); assert.equal(s.faza, 'kraj')
})

test('cela partija samih botova se završi i botovi osvajaju', () => {
  const rnd = P.napraviSlucajno(42)
  let s = P.napraviPartiju({ krugova: 12, tezina: 'tesko', slucajno: rnd })
  let koraka = 0
  while (s.faza !== 'kraj' && koraka++ < 5000) {
    s = P.botRasporedi(P.snabdevanje(s, rnd() < 0.6))
    let n
    while ((n = P.botSledeciNapad(s))) {
      const branilac = s.oblasti[n.kuda].vlasnik ? P.botOdgovor(s, rnd) : null
      s = P.razresiBitku(s, n.odakle, n.kuda, P.botOdgovor(s, rnd), branilac).stanje
    }
    s = P.zavrsiPotez(s)
  }
  assert.equal(s.faza, 'kraj')
  const zauzeto = P.OBLASTI.filter(o => s.oblasti[o.id].vlasnik).length
  assert.ok(zauzeto > 60, `zauzeto ${zauzeto} od 171`)
})
