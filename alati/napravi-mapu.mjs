// Pravi src/lib/osvajanje/svet.json iz Natural Earth 1:50m granica država (javno dobro).
// Pokretanje (alati su van repoa, u privremenom folderu sa d3-geo i topojson):
//   node alati/napravi-mapu.mjs <ne_50m_admin_0_countries.geojson> <izlaz.json> <node_modules folder>
// Izgled (ravne boje, susedi različiti, bele granice) prati world-map-infographics paket.
// Isti JSON koriste veb, iOS i Android, pa se mapa menja samo ovde.
import fs from 'node:fs'
import path from 'node:path'
import { createRequire } from 'node:module'

const [, , ulaz, izlaz, moduli] = process.argv
const req = createRequire(path.resolve(moduli, 'x.js'))
const d3 = req('d3-geo')
const { topology } = req('topojson-server')
const { neighbors, merge } = req('topojson-client')
const { presimplify, simplify, quantile } = req('topojson-simplify')

const SIRINA = 2000

// Spajanja: Srbija sa Kosovom, Kipar sa severom, Somalija sa Somalilendom.
const SPOJI = { KOS: 'SRB', CYN: 'CYP', SOL: 'SOM' }
const IZBACI = new Set(['ATA', 'ATF', 'FLK'])

const REGIONI = [
  ['sam', 'Severna Amerika', 'CAN USA GRL'],
  ['kar', 'Srednja Amerika i Karibi', 'MEX GTM BLZ HND SLV NIC CRI PAN CUB JAM HTI DOM PRI BHS TTO'],
  ['jam', 'Južna Amerika', 'COL VEN GUY SUR ECU PER BRA BOL PRY CHL ARG URY'],
  ['sev', 'Severna Evropa', 'ISL NOR SWE FIN DNK EST LVA LTU GBR IRL'],
  ['zev', 'Zapadna Evropa', 'FRA BEL NLD LUX DEU CHE AUT'],
  ['jev', 'Južna Evropa', 'PRT ESP ITA SVN HRV BIH SRB MNE ALB MKD GRC'],
  ['iev', 'Istočna Evropa', 'POL CZE SVK HUN ROU BGR MDA UKR BLR RUS'],
  ['saf', 'Severna Afrika', 'MAR SAH DZA TUN LBY EGY SDN'],
  ['zaf', 'Zapadna Afrika', 'MRT SEN GMB GNB GIN SLE LBR CIV MLI BFA GHA TGO BEN NER NGA'],
  ['caf', 'Centralna Afrika', 'TCD CAF CMR GNQ GAB COG COD'],
  ['iaf', 'Istočna Afrika', 'SDS ETH ERI DJI SOM KEN UGA RWA BDI TZA'],
  ['jaf', 'Južna Afrika', 'AGO ZMB MWI MOZ ZWE BWA NAM ZAF LSO SWZ MDG'],
  ['bli', 'Bliski istok', 'TUR CYP SYR LBN ISR PSX JOR IRQ SAU YEM OMN ARE QAT KWT GEO ARM AZE IRN'],
  ['caz', 'Centralna i Južna Azija', 'KAZ UZB TKM KGZ TJK AFG PAK IND NPL BTN BGD LKA'],
  ['iaz', 'Istočna Azija', 'CHN MNG PRK KOR JPN TWN'],
  ['jia', 'Jugoistočna Azija', 'MMR THA LAO KHM VNM MYS BRN IDN PHL TLS'],
  ['oke', 'Okeanija', 'AUS NZL PNG SLB VUT FJI NCL'],
]

const IMENA = {
  AFG: 'Avganistan', AGO: 'Angola', ALB: 'Albanija', ARE: 'Emirati', ARG: 'Argentina', ARM: 'Jermenija', AUS: 'Australija',
  AUT: 'Austrija', AZE: 'Azerbejdžan', BDI: 'Burundi', BEL: 'Belgija', BEN: 'Benin', BFA: 'Burkina Faso', BGD: 'Bangladeš',
  BGR: 'Bugarska', BHS: 'Bahami', BIH: 'Bosna i Hercegovina', BLR: 'Belorusija', BLZ: 'Belize', BOL: 'Bolivija', BRA: 'Brazil',
  BRN: 'Brunej', BTN: 'Butan', BWA: 'Bocvana', CAF: 'Centralnoafrička Republika', CAN: 'Kanada', CHE: 'Švajcarska', CHL: 'Čile',
  CHN: 'Kina', CIV: 'Obala Slonovače', CMR: 'Kamerun', COD: 'DR Kongo', COG: 'Kongo', COL: 'Kolumbija', CRI: 'Kostarika',
  CUB: 'Kuba', CYP: 'Kipar', CZE: 'Češka', DEU: 'Nemačka', DJI: 'Džibuti', DNK: 'Danska', DOM: 'Dominikanska Republika',
  DZA: 'Alžir', ECU: 'Ekvador', EGY: 'Egipat', ERI: 'Eritreja', ESP: 'Španija', EST: 'Estonija', ETH: 'Etiopija', FIN: 'Finska',
  FJI: 'Fidži', FRA: 'Francuska', GAB: 'Gabon', GBR: 'Velika Britanija', GEO: 'Gruzija', GHA: 'Gana', GIN: 'Gvineja',
  GMB: 'Gambija', GNB: 'Gvineja Bisao', GNQ: 'Ekvatorijalna Gvineja', GRC: 'Grčka', GRL: 'Grenland', GTM: 'Gvatemala',
  GUY: 'Gvajana', HND: 'Honduras', HRV: 'Hrvatska', HTI: 'Haiti', HUN: 'Mađarska', IDN: 'Indonezija', IND: 'Indija',
  IRL: 'Irska', IRN: 'Iran', IRQ: 'Irak', ISL: 'Island', ISR: 'Izrael', ITA: 'Italija', JAM: 'Jamajka', JOR: 'Jordan',
  JPN: 'Japan', KAZ: 'Kazahstan', KEN: 'Kenija', KGZ: 'Kirgistan', KHM: 'Kambodža', KOR: 'Južna Koreja', KWT: 'Kuvajt',
  LAO: 'Laos', LBN: 'Liban', LBR: 'Liberija', LBY: 'Libija', LKA: 'Šri Lanka', LSO: 'Lesoto', LTU: 'Litvanija',
  LUX: 'Luksemburg', LVA: 'Letonija', MAR: 'Maroko', MDA: 'Moldavija', MDG: 'Madagaskar', MEX: 'Meksiko',
  MKD: 'Severna Makedonija', MLI: 'Mali', MMR: 'Mjanmar', MNE: 'Crna Gora', MNG: 'Mongolija', MOZ: 'Mozambik',
  MRT: 'Mauritanija', MWI: 'Malavi', MYS: 'Malezija', NAM: 'Namibija', NCL: 'Nova Kaledonija', NER: 'Niger', NGA: 'Nigerija',
  NIC: 'Nikaragva', NLD: 'Holandija', NOR: 'Norveška', NPL: 'Nepal', NZL: 'Novi Zeland', OMN: 'Oman', PAK: 'Pakistan',
  PAN: 'Panama', PER: 'Peru', PHL: 'Filipini', PNG: 'Papua Nova Gvineja', POL: 'Poljska', PRI: 'Portoriko',
  PRK: 'Severna Koreja', PRT: 'Portugalija', PRY: 'Paragvaj', PSX: 'Palestina', QAT: 'Katar', ROU: 'Rumunija',
  RUS: 'Rusija', RWA: 'Ruanda', SAH: 'Zapadna Sahara', SAU: 'Saudijska Arabija', SDN: 'Sudan', SDS: 'Južni Sudan',
  SEN: 'Senegal', SLB: 'Solomonska Ostrva', SLE: 'Sijera Leone', SLV: 'Salvador', SOM: 'Somalija', SRB: 'Srbija',
  SUR: 'Surinam', SVK: 'Slovačka', SVN: 'Slovenija', SWE: 'Švedska', SWZ: 'Esvatini', SYR: 'Sirija', TCD: 'Čad',
  TGO: 'Togo', THA: 'Tajland', TJK: 'Tadžikistan', TKM: 'Turkmenistan', TLS: 'Istočni Timor', TTO: 'Trinidad i Tobago',
  TUN: 'Tunis', TUR: 'Turska', TWN: 'Tajvan', TZA: 'Tanzanija', UGA: 'Uganda', UKR: 'Ukrajina', URY: 'Urugvaj',
  USA: 'SAD', UZB: 'Uzbekistan', VEN: 'Venecuela', VNM: 'Vijetnam', VUT: 'Vanuatu', YEM: 'Jemen', ZAF: 'Južnoafrička Republika',
  ZMB: 'Zambija', ZWE: 'Zimbabve',
}

// Morske veze kao u Risku (pored automatskih za ostrva i nepovezane delove).
const MORSKE = [
  ['USA', 'RUS'], ['GRL', 'ISL'], ['ISL', 'NOR'], ['GRL', 'CAN'], ['GBR', 'FRA'], ['GBR', 'NLD'], ['ESP', 'MAR'],
  ['ITA', 'TUN'], ['ITA', 'LBY'], ['GRC', 'EGY'], ['BRA', 'SEN'], ['JPN', 'KOR'], ['JPN', 'RUS'], ['MDG', 'MOZ'],
  ['LKA', 'IND'], ['AUS', 'IDN'], ['AUS', 'NZL'], ['AUS', 'PNG'], ['CUB', 'USA'], ['CUB', 'MEX'], ['TWN', 'CHN'],
  ['PHL', 'TWN'], ['PHL', 'MYS'], ['SWE', 'FIN'], ['DNK', 'SWE'], ['DNK', 'NOR'], ['SAU', 'EGY'], ['YEM', 'DJI'],
  ['CYP', 'TUR'], ['TTO', 'VEN'], ['JAM', 'CUB'], ['BHS', 'USA'], ['PRI', 'DOM'],
]

const sirovo = JSON.parse(fs.readFileSync(ulaz, 'utf8')).features
  .map(f => ({ ...f, properties: { id: SPOJI[f.properties.ADM0_A3] ?? f.properties.ADM0_A3 } }))
  .filter(f => !IZBACI.has(f.properties.id) && IMENA[f.properties.id])

const regionOd = {}
for (const [r, , spisak] of REGIONI) for (const id of spisak.split(' ')) regionOd[id] = r
for (const f of sirovo) if (!regionOd[f.properties.id] || !IMENA[f.properties.id]) throw new Error(`Bez regiona ili imena: ${f.properties.id}`)

// Topologija pa spajanje delova iste države (Kosovo u Srbiju itd.).
// Pojednostavljenje drži 20% najvažnijih tačaka: obale ostaju prepoznatljive, a fajl mali za telefon.
const sirovaTopologija = presimplify(topology({ d: { type: 'FeatureCollection', features: sirovo } }, 1e5))
const topo = simplify(sirovaTopologija, quantile(sirovaTopologija, 0.2))
const geom = topo.objects.d.geometries
const ids = [...new Set(geom.map(g => g.properties.id))]
const zemlje = ids.map(id => ({ id, f: { type: 'Feature', properties: { id }, geometry: merge(topo, geom.filter(g => g.properties.id === id)) } }))

const projekcija = d3.geoNaturalEarth1().rotate([-11, 0])
  .fitWidth(SIRINA, { type: 'FeatureCollection', features: zemlje.map(z => z.f) })
const putanja = d3.geoPath(projekcija)
const [[, y0], [, y1]] = putanja.bounds({ type: 'FeatureCollection', features: zemlje.map(z => z.f) })
projekcija.translate([projekcija.translate()[0], projekcija.translate()[1] - y0 + 10])
const VISINA = Math.ceil(y1 - y0 + 20)

// Putanja samo sa M/L/Z i jednom decimalom: lako se čita i u Swiftu i u Kotlinu.
function kratka(d) {
  return d.replace(/(-?\d+\.\d+)/g, n => (Math.round(Number(n) * 10) / 10).toString())
}

// Natpis ide u središte najvećeg dela (Francuska ne sme da dobije broj u Gvajani).
function sredina(f) {
  const delovi = f.geometry.type === 'MultiPolygon' ? f.geometry.coordinates.map(c => ({ type: 'Polygon', coordinates: c })) : [f.geometry]
  const najveci = delovi.reduce((a, b) => (putanja.area(b) > putanja.area(a) ? b : a))
  return putanja.centroid(najveci).map(v => Math.round(v * 10) / 10)
}

// Susedi po kopnenoj granici.
const susedi = new Map(ids.map(id => [id, new Set()]))
const susGeom = neighbors(geom)
geom.forEach((g, i) => susGeom[i].forEach(j => {
  const a = g.properties.id, b = geom[j].properties.id
  if (a !== b) { susedi.get(a).add(b); susedi.get(b).add(a) }
}))

// Boja neutralne države: pohlepno bojenje kopnenih suseda u 5 boja, da susedi nikad nisu isti.
const BOJA = {}
for (const id of [...ids].sort((a, b) => susedi.get(b).size - susedi.get(a).size)) {
  const zauzete = new Set([...susedi.get(id)].map(n => BOJA[n]))
  BOJA[id] = [0, 1, 2, 3, 4].find(b => !zauzete.has(b))
}
for (const [a, b] of MORSKE) { susedi.get(a).add(b); susedi.get(b).add(a) }

const centar = Object.fromEntries(zemlje.map(z => [z.id, sredina(z.f)]))
const dist = (a, b) => Math.hypot(centar[a][0] - centar[b][0], centar[a][1] - centar[b][1])
// Ostrva bez suseda dobijaju dve najbliže države.
for (const id of ids) if (susedi.get(id).size === 0) {
  ids.filter(o => o !== id).sort((a, b) => dist(id, a) - dist(id, b)).slice(0, 2).forEach(o => { susedi.get(id).add(o); susedi.get(o).add(id) })
}
// Graf mora biti povezan: spajaju se najbliži parovi između komponenti.
for (;;) {
  const komp = new Map()
  let br = 0
  for (const id of ids) if (!komp.has(id)) {
    const red = [id]; komp.set(id, br)
    while (red.length) for (const n of susedi.get(red.pop())) if (!komp.has(n)) { komp.set(n, br); red.push(n) }
    br++
  }
  if (br === 1) break
  let par = null
  for (const a of ids) for (const b of ids) if (komp.get(a) === 0 && komp.get(b) !== 0 && (!par || dist(a, b) < dist(par[0], par[1]))) par = [a, b]
  susedi.get(par[0]).add(par[1]); susedi.get(par[1]).add(par[0])
}

const veze = []
for (const [a, s] of susedi) for (const b of s) if (a < b) veze.push([a, b])

const izlazniPodaci = {
  sirina: SIRINA,
  visina: VISINA,
  regioni: REGIONI.map(([id, ime, spisak]) => {
    const n = spisak.split(' ').filter(x => ids.includes(x)).length
    return { id, ime, bonus: Math.max(2, Math.ceil(n / 3)) }
  }),
  drzave: zemlje.map(z => ({
    id: z.id, ime: IMENA[z.id], region: regionOd[z.id],
    x: centar[z.id][0], y: centar[z.id][1],
    boja: BOJA[z.id],
    povrsina: Math.round(putanja.area(z.f.geometry)),
    d: kratka(putanja(z.f.geometry)),
  })).sort((a, b) => a.id.localeCompare(b.id)),
  veze: veze.sort(),
}
fs.writeFileSync(izlaz, JSON.stringify(izlazniPodaci))
console.log(`${izlazniPodaci.drzave.length} država, ${veze.length} veza, ${izlazniPodaci.regioni.length} regiona, ${SIRINA}×${VISINA}, ${(fs.statSync(izlaz).size / 1024).toFixed(0)} KB`)
