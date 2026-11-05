import { NextResponse } from 'next/server'
import { segment, jeSegment, jePojam, VESANJE_KATEGORIJE } from '@/lib/segmenti'

// XML i CSV šablon koji korisnik preuzme pre nego što pošalje grupu
// pitanja. Isti oblik koji čita parser na strani /dodaj-pitanja i na
// serveru, plus uputstvo u komentaru/zaglavlju, da fajl bude razumljiv
// i kad se otvori bez sajta.
//
// Vešanje ima drugačiji oblik: pojam, opis i kategorija umesto pitanja
// i četiri odgovora.

type Primer = { tekst: string; tacan: string; netacni: string[]; zanr?: string }

const PRIMERI: Record<string, Primer[]> = {
  pro: [
    {
      tekst: 'Koje je najdublje jezero na svetu?',
      tacan: 'Bajkalsko jezero',
      netacni: ['Kaspijsko jezero', 'Jezero Tanganjika', 'Ohridsko jezero'],
    },
    {
      tekst: 'U kojoj godini je počeo Prvi svetski rat?',
      tacan: '1914.',
      netacni: ['1912.', '1918.', '1939.'],
    },
  ],
  book: [
    {
      tekst: 'Ko je napisao roman „Na Drini ćuprija”?',
      tacan: 'Ivo Andrić',
      netacni: ['Meša Selimović', 'Miloš Crnjanski', 'Branko Ćopić'],
      zanr: 'Domaća književnost',
    },
    {
      tekst: 'Kako se zove glavni junak romana „Zločin i kazna”?',
      tacan: 'Rodion Raskoljnikov',
      netacni: ['Aljoša Karamazov', 'Pjer Bezuhov', 'Jevgenij Onjegin'],
      zanr: 'Svetska književnost',
    },
  ],
  kafana: [
    {
      tekst: 'Ko peva pesmu „Miljacka”?',
      tacan: 'Halid Bešlić',
      netacni: ['Šaban Šaulić', 'Toma Zdravković', 'Zdravko Čolić'],
    },
    {
      tekst: 'Koja grupa je otpevala pesmu „Đurđevdan”?',
      tacan: 'Bijelo dugme',
      netacni: ['Riblja čorba', 'Parni valjak', 'Plavi orkestar'],
    },
  ],
  // Vešanje: `tekst` je pojam, `tacan` je opis, `zanr` je kategorija.
  vesanje: [
    {
      tekst: 'Tara',
      tacan: 'Nacionalni park i planina u zapadnoj Srbiji, poznata po omorici',
      netacni: [],
      zanr: 'Geografija',
    },
    {
      tekst: 'Kalemegdan',
      tacan: 'Najstariji i najveći park u Beogradu, na ušću dve reke',
      netacni: [],
      zanr: 'Istorija',
    },
  ],
}

function escape(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
}

// CSV se otvara u Excelu dvoklikom, pa je za većinu ljudi lakši put od
// XML-a. BOM na početku je obavezan: bez njega Excel na Windowsu čita
// UTF-8 kao Windows-1250 i „č” postane „Ä”.
function csvPolje(v: string): string {
  return `"${v.replace(/"/g, '""')}"`
}

function napraviCsv(key: string): string {
  const s = segment(key)
  const zaglavlje = jePojam(key)
    ? ['Pojam', 'Opis', 'Kategorija']
    : ['Pitanje', 'Tačan odgovor', 'Pogrešan 1', 'Pogrešan 2', 'Pogrešan 3']
  if (!jePojam(key) && s.zanr) zaglavlje.push('Žanr')

  const redovi = PRIMERI[key].map(p => {
    const red = jePojam(key)
      ? [p.tekst, p.tacan, p.zanr ?? '']
      : [p.tekst, p.tacan, ...p.netacni]
    if (!jePojam(key) && s.zanr) red.push(p.zanr ?? '')
    return red.map(csvPolje).join(',')
  })

  return '﻿' + [zaglavlje.map(csvPolje).join(','), ...redovi].join('\r\n') + '\r\n'
}

function napraviXml(key: string): string {
  const s = segment(key)
  const primeri = PRIMERI[key]

  if (jePojam(key)) {
    const telo = primeri.map(p => [
      '  <pojam>',
      `    <rec>${escape(p.tekst)}</rec>`,
      `    <opis>${escape(p.tacan)}</opis>`,
      `    <kategorija>${escape(p.zanr ?? '')}</kategorija>`,
      '  </pojam>',
    ].join('\n')).join('\n')

    return `<?xml version="1.0" encoding="UTF-8"?>
<!--
  ŠABLON ZA SLANJE POJMOVA — kviz.librum.club
  Segment: Vešanje

  KAKO SE POPUNJAVA
  1. Za svaki pojam napravi jedan <pojam> blok, po uzoru na primere ispod.
  2. <rec>        pojam koji se pogađa       (obavezno, 4 do 18 slova)
  3. <opis>       kratka pomoć igraču        (obavezno, do 200 znakova)
  4. <kategorija> jedna od šest ispod        (obavezno)

  KATEGORIJE
  ${VESANJE_KATEGORIJE.join(' · ')}

  PRAVILA
  · Opis NE SME da sadrži sam pojam, inače je pogađanje besmisleno.
  · Pojam može biti i više reči, ali ukupno 4 do 18 slova.
  · Najviše 200 pojmova po fajlu. Fajl se snima kao .xml, kodiranje UTF-8.
  · Svi predlozi idu na uredničku proveru pre nego što se pojave u igri.

  ZNAKOVI KOJI SE MORAJU ZAMENITI U TEKSTU
  &  ->  &amp;        <  ->  &lt;        >  ->  &gt;
-->
<pojmovi segment="vesanje">
${telo}
</pojmovi>
`
  }

  const zanrRed = s.zanr
    ? '\n  <!-- <zanr> je opcion. Ako ga izostaviš, pitanje ide u žanr „Razno”. -->'
    : ''
  // „Book kviz (Book kviz)” bi bilo smešno — igre se ispisuju samo kad
  // segment pokriva više igara od svog imena.
  const igre = s.igre === s.label ? '' : ` (${s.igre})`

  const telo = primeri.map(p => [
    '  <pitanje>',
    `    <tekst>${escape(p.tekst)}</tekst>`,
    `    <tacan>${escape(p.tacan)}</tacan>`,
    ...p.netacni.map(n => `    <netacan>${escape(n)}</netacan>`),
    ...(s.zanr && p.zanr ? [`    <zanr>${escape(p.zanr)}</zanr>`] : []),
    '  </pitanje>',
  ].join('\n')).join('\n')

  return `<?xml version="1.0" encoding="UTF-8"?>
<!--
  ŠABLON ZA SLANJE PITANJA — kviz.librum.club
  Segment: ${s.label}${igre}

  KAKO SE POPUNJAVA
  1. Za svako pitanje napravi jedan <pitanje> blok, po uzoru na primere ispod.
  2. <tekst>    tekst pitanja                      (obavezno, do 1000 znakova)
  3. <tacan>    tačan odgovor                      (obavezno, do 500 znakova)
  4. <netacan>  netačan odgovor — tačno tri komada (obavezno, do 500 znakova)${s.zanr ? '\n  5. <zanr>     žanr, npr. Roman, Poezija, Drama  (opciono)' : ''}

  PRAVILA
  · Sva četiri odgovora moraju biti različita.
  · Redosled odgovora nije bitan — igra ih ionako meša u toku igranja.
  · Obriši ova dva primera pre slanja, ili ih ostavi: prepoznaće se kao
    duplikat ako su već u bazi.
  · Najviše 200 pitanja po fajlu. Fajl se snima kao .xml, kodiranje UTF-8.
  · Svi predlozi idu na uredničku proveru pre nego što se pojave u kvizu.

  ZNAKOVI KOJI SE MORAJU ZAMENITI U TEKSTU
  &  ->  &amp;        <  ->  &lt;        >  ->  &gt;
-->
<pitanja segment="${s.key}">${zanrRed}
${telo}
</pitanja>
`
}

export async function GET(req: Request) {
  const params = new URL(req.url).searchParams
  const key = params.get('segment') ?? 'pro'
  if (!jeSegment(key)) {
    return NextResponse.json({ ok: false, error: 'bad-segment' }, { status: 400 })
  }
  const s = segment(key)

  if (params.get('format') === 'csv') {
    return new NextResponse(napraviCsv(key), {
      headers: {
        'Content-Type': 'text/csv; charset=utf-8',
        'Content-Disposition': `attachment; filename="sablon-${s.key}.csv"`,
        'Cache-Control': 'public, max-age=3600',
      },
    })
  }

  return new NextResponse(napraviXml(key), {
    headers: {
      'Content-Type': 'application/xml; charset=utf-8',
      'Content-Disposition': `attachment; filename="sablon-${s.key}.xml"`,
      'Cache-Control': 'public, max-age=3600',
    },
  })
}
