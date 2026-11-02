// Činjenice o državama za ekran pre bitke u Osvajanju (glavni grad, stanovništvo, površina,
// jezik, valuta, najviši vrh). Izvor je Wikidata (CC0), po ISO 3166-1 alpha-3 kodu države;
// nazivi na srpskom latinicom, a ćirilica se preslovljava kad latinice nema.
// Pokretanje: node alati/cinjenice-drzava.mjs  →  src/lib/osvajanje/cinjenice.json
import fs from 'node:fs'

const svet = JSON.parse(fs.readFileSync('src/lib/osvajanje/svet.json', 'utf8'))
const kodovi = svet.drzave.map(d => d.id)

const CIR = { А: 'A', Б: 'B', В: 'V', Г: 'G', Д: 'D', Ђ: 'Đ', Е: 'E', Ж: 'Ž', З: 'Z', И: 'I', Ј: 'J', К: 'K', Л: 'L', Љ: 'Lj', М: 'M', Н: 'N', Њ: 'Nj', О: 'O', П: 'P', Р: 'R', С: 'S', Т: 'T', Ћ: 'Ć', У: 'U', Ф: 'F', Х: 'H', Ц: 'C', Ч: 'Č', Џ: 'Dž', Ш: 'Š' }
const cisto = t => t ? t.replace(/\s*\(.*\)$/, '').replace(/^./, z => z.toLowerCase()) : t
const latinica = t => t ? [...t].map(z => CIR[z] ?? (CIR[z.toUpperCase()] ? CIR[z.toUpperCase()].toLowerCase() : z)).join('') : t

const upit = `SELECT ?kod ?drzava ?glavni ?stanovnika ?povrsina ?jezik ?valuta ?vrh ?visina WHERE {
  VALUES ?kod { ${kodovi.map(k => `"${k}"`).join(' ')} }
  ?drzava wdt:P298 ?kod .
  OPTIONAL { ?drzava wdt:P36 ?g . OPTIONAL { ?g rdfs:label ?glavniEl FILTER(lang(?glavniEl) = "sr-el") } OPTIONAL { ?g rdfs:label ?glavniSr FILTER(lang(?glavniSr) = "sr") } BIND(COALESCE(?glavniSr, ?glavniEl) AS ?glavni) }
  OPTIONAL { ?drzava wdt:P1082 ?stanovnika }
  OPTIONAL { ?drzava wdt:P2046 ?povrsina }
  OPTIONAL { ?drzava wdt:P37 ?j . OPTIONAL { ?j rdfs:label ?jezikEl FILTER(lang(?jezikEl) = "sr-el") } OPTIONAL { ?j rdfs:label ?jezikSr FILTER(lang(?jezikSr) = "sr") } BIND(COALESCE(?jezikSr, ?jezikEl) AS ?jezik) }
  OPTIONAL { ?drzava wdt:P38 ?v . OPTIONAL { ?v rdfs:label ?valutaEl FILTER(lang(?valutaEl) = "sr-el") } OPTIONAL { ?v rdfs:label ?valutaSr FILTER(lang(?valutaSr) = "sr") } BIND(COALESCE(?valutaSr, ?valutaEl) AS ?valuta) }
  OPTIONAL { ?drzava wdt:P610 ?h . ?h wdt:P2044 ?visina . OPTIONAL { ?h rdfs:label ?vrhEl FILTER(lang(?vrhEl) = "sr-el") } OPTIONAL { ?h rdfs:label ?vrhSr FILTER(lang(?vrhSr) = "sr") } OPTIONAL { ?h rdfs:label ?vrhEn FILTER(lang(?vrhEn) = "en") } BIND(COALESCE(?vrhSr, ?vrhEl, ?vrhEn) AS ?vrh) }
}`

const odgovor = await fetch('https://query.wikidata.org/sparql?format=json&query=' + encodeURIComponent(upit), {
  headers: { 'User-Agent': 'LibrumKviz/1.0 (https://kviz.librum.club; info@librum.club)', Accept: 'application/sparql-results+json' },
})
if (!odgovor.ok) throw new Error(`Wikidata ${odgovor.status}`)
const redovi = (await odgovor.json()).results.bindings

const po = {}
for (const r of redovi) {
  const k = r.kod.value
  const d = (po[k] ??= { jezici: new Set(), glavni: null, stanovnika: 0, povrsina: 0, valute: new Set(), vrh: null, visina: 0 })
  if (r.glavni && !d.glavni) d.glavni = latinica(r.glavni.value)
  if (r.stanovnika) d.stanovnika = Math.max(d.stanovnika, Number(r.stanovnika.value))
  if (r.povrsina) d.povrsina = Math.max(d.povrsina, Number(r.povrsina.value))
  if (r.jezik) d.jezici.add(cisto(latinica(r.jezik.value)).replace(/ jezik$/, ''))
  if (r.valuta) d.valute.add(cisto(latinica(r.valuta.value)))
  if (r.vrh && Number(r.visina.value) > d.visina) { d.vrh = latinica(r.vrh.value).replace(/\s*\(.*\)$/, ''); d.visina = Math.round(Number(r.visina.value)) }
}

const broj = n => n.toLocaleString('sr-Latn-RS')
// Kad država ima više valuta (Francuska: evro i pacifički franak), uzima se evro ili dolar, inače najkraći naziv.
// Najviše dva jezika; svetski jezici imaju prednost (SAD imaju desetak zvaničnih po saveznim državama).
const SVETSKI = ['engleski', 'francuski', 'španski', 'arapski', 'portugalski', 'ruski', 'nemački', 'kineski', 'hindi']
const jezici = l => [...l].sort((a, b) => (SVETSKI.indexOf(a) + 1 || 99) - (SVETSKI.indexOf(b) + 1 || 99)).slice(0, 2)
const glavnaValuta = v => v.find(x => /^(evro|euro)$/i.test(x)) ?? v.find(x => /dolar/.test(x) && v.length > 1 && !/istočnokaripski/.test(x)) ?? v.sort((a, b) => a.length - b.length)[0]
// Ispravke gde Wikidata daje nešto tačno ali nezgodno za kviz (više glavnih gradova,
// jezici po saveznim državama, jezik većine nije prvi u spisku).
const ISPRAVKE = {
  USA: { jezik: 'Jezik: engleski' },
  BEL: { jezik: 'Jezik: holandski, francuski, nemački' },
  CHE: { jezik: 'Jezik: nemački, francuski, italijanski' },
  CHN: { jezik: 'Jezik: kineski' },
  ZAF: { glavni: 'Glavni grad: Pretorija (vlada), Kejptaun i Blumfontejn' },
  BOL: { glavni: 'Glavni grad: Sukre (ustavni), La Paz (vlada)' },
}

const izlaz = {}
for (const k of kodovi) {
  const d = po[k]
  if (!d) continue
  const cinjenice = []
  if (d.glavni) cinjenice.push(`Glavni grad: ${d.glavni}`)
  if (d.stanovnika) cinjenice.push(d.stanovnika >= 1e9 ? `${broj(Math.round(d.stanovnika / 1e7) / 100)} milijardi stanovnika` : d.stanovnika >= 1e6 ? `${broj(Math.round(d.stanovnika / 1e5) / 10)} miliona stanovnika` : `${broj(d.stanovnika)} stanovnika`)
  if (d.povrsina) cinjenice.push(`Površina ${broj(Math.round(d.povrsina))} km²`)
  if (d.jezici.size) cinjenice.push(`Jezik: ${jezici([...d.jezici]).join(', ')}`)
  const valuta = glavnaValuta([...d.valute])
  if (valuta) cinjenice.push(`Valuta: ${valuta}`)
  if (d.vrh) cinjenice.push(`Najviši vrh: ${d.vrh}, ${broj(d.visina)} m`)
  const ispravka = ISPRAVKE[k] ?? {}
  for (const [vrsta, tekst] of Object.entries(ispravka)) {
    const i = cinjenice.findIndex(c => c.startsWith(vrsta === 'jezik' ? 'Jezik:' : 'Glavni grad:'))
    if (i >= 0) cinjenice[i] = tekst; else cinjenice.splice(vrsta === 'jezik' ? 3 : 0, 0, tekst)
  }
  izlaz[k] = cinjenice
}
fs.writeFileSync('src/lib/osvajanje/cinjenice.json', JSON.stringify(izlaz))
console.log(Object.keys(izlaz).length, 'država od', kodovi.length, '· bez podataka:', kodovi.filter(k => !izlaz[k]).join(' '))
