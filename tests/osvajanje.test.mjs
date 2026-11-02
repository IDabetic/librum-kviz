// Pokretanje: node --test tests/  (Node 23+ sam skida tipove sa .ts fajla)
import { test } from 'node:test'
import assert from 'node:assert/strict'
import * as P from '../src/lib/osvajanje/pravila.ts'

const nova = (seme = 1) => P.napraviPartiju({ krugova: 10, tezina: 'normalno', slucajno: P.napraviSlucajno(seme) })

test('mapa: 24 oblasti, veze simetrične i sve oblasti povezane', () => {
  assert.equal(P.OBLASTI.length, 24)
  for (const o of P.OBLASTI) {
    for (const n of P.susedi(o.id)) assert.ok(P.susedi(n).includes(o.id), `${o.id} ↔ ${n}`)
  }
  const vidjeno = new Set(['aljaska'])
  const red = ['aljaska']
  while (red.length) for (const n of P.susedi(red.pop())) if (!vidjeno.has(n)) { vidjeno.add(n); red.push(n) }
  assert.equal(vidjeno.size, 24)
})

test('početak: tri prestonice na različitim kontinentima', () => {
  const s = nova(3)
  const kont = s.igraci.map(p => P.OBLASTI.find(o => o.id === p.prestonica).kontinent)
  assert.equal(new Set(kont).size, 3)
  assert.equal(s.oblasti[s.igraci[0].prestonica].vojske, P.POCETNE_VOJSKE_PRESTONICE)
})

test('snabdevanje: tačno 3, netačno 1, pa raspored prelazi u napad', () => {
  const s = nova()
  assert.equal(P.snabdevanje(s, true).zaRaspored, 3)
  let r = P.snabdevanje(s, false)
  assert.equal(r.zaRaspored, 1)
  r = P.rasporedi(r, s.igraci[0].prestonica)
  assert.equal(r.faza, 'napad')
})

test('bitka protiv neutralne: tačno osvaja i vojske prelaze, pa proboj iz nove oblasti', () => {
  let s = P.snabdevanje(nova(), true)
  const dom = s.igraci[0].prestonica
  while (s.faza === 'raspored') s = P.rasporedi(s, dom)
  const meta = P.mete(s, dom)[0]
  const { stanje, ishod } = P.razresiBitku(s, dom, meta, { tacan: true, ms: 1 }, null)
  assert.ok(ishod.osvojeno)
  assert.equal(stanje.oblasti[meta].vlasnik, 'ti')
  assert.equal(stanje.oblasti[dom].vojske, 1)
  assert.equal(stanje.oblasti[meta].vojske, 6)
  assert.ok(P.mete(stanje, meta).length > 0, 'iz osvojene oblasti može dalje')
})

test('bitka protiv igrača: brži tačan pobeđuje, oba netačna gube po jednu', () => {
  let s = P.snabdevanje(nova(), true)
  s = { ...s, faza: 'napad', oblasti: { ...s.oblasti, balkan: { vlasnik: 'ti', vojske: 5 }, 'bliski-istok': { vlasnik: 'mimi', vojske: 4 } } }
  let r = P.razresiBitku(s, 'balkan', 'bliski-istok', { tacan: true, ms: 2000 }, { tacan: true, ms: 5000 })
  assert.equal(r.stanje.oblasti['bliski-istok'].vojske, 3)
  r = P.razresiBitku(s, 'balkan', 'bliski-istok', { tacan: false, ms: 1 }, { tacan: false, ms: 1 })
  assert.equal(r.stanje.oblasti.balkan.vojske, 4)
  assert.equal(r.stanje.oblasti['bliski-istok'].vojske, 3)
  r = P.razresiBitku(s, 'balkan', 'bliski-istok', { tacan: false, ms: 1 }, { tacan: true, ms: 1 })
  assert.equal(r.stanje.oblasti.balkan.vojske, 3)
})

test('treće osvajanje u nizu donosi proboj (+2)', () => {
  let s = { ...nova(), faza: 'napad' }
  s.oblasti = { ...s.oblasti, peru: { vlasnik: 'ti', vojske: 10 } }
  let tren = 'peru'
  let poslednji
  for (let i = 0; i < 3; i++) {
    const meta = P.mete(s, tren).find(m => s.oblasti[m].vlasnik === null)
    const r = P.razresiBitku(s, tren, meta, { tacan: true, ms: 1 }, null)
    s = r.stanje; tren = meta; poslednji = r.ishod
  }
  assert.ok(poslednji.proboj)
})

test('zavrsiPotez vrti igrače i završava posle poslednjeg kruga', () => {
  let s = P.napraviPartiju({ krugova: 1, tezina: 'lako', slucajno: P.napraviSlucajno(9) })
  s = P.zavrsiPotez(s); assert.equal(s.naPotezu, 1)
  s = P.zavrsiPotez(s); assert.equal(s.naPotezu, 2)
  s = P.zavrsiPotez(s); assert.equal(s.faza, 'kraj')
})

test('cela partija samih botova se završi bez greške', () => {
  const rnd = P.napraviSlucajno(42)
  let s = P.napraviPartiju({ krugova: 10, tezina: 'tesko', slucajno: rnd })
  let koraka = 0
  while (s.faza !== 'kraj' && koraka++ < 5000) {
    s = P.botRasporedi(P.snabdevanje(s, rnd() < 0.6))
    let napad
    while ((napad = P.botSledeciNapad(s))) {
      const branilac = s.oblasti[napad.kuda].vlasnik ? P.botOdgovor(s, rnd) : null
      s = P.razresiBitku(s, napad.odakle, napad.kuda, P.botOdgovor(s, rnd), branilac).stanje
    }
    s = P.zavrsiPotez(s)
  }
  assert.equal(s.faza, 'kraj')
  assert.equal(P.poredak(s).length, 3)
})
