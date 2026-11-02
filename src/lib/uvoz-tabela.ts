import * as XLSX from 'xlsx'

// Čitanje Excel/CSV fajla u redove {question, correct, wrong[], genre}.
//
// Nazivi kolona su isti kao u admin uvozu (/api/admin/questions-import),
// pa isti fajl radi i tamo i ovde. Prihvataju se obe konvencije za
// netačne odgovore („Netačno / Netačno_1 / Netačno_2” i „Pogrešan 1..3”),
// sa ili bez dijakritike, jer ljudi kucaju kako stignu.

export type TabelaStavka = { question: string; correct: string; wrong: string[]; genre: string }

type Red = Record<string, unknown>

function uzmi(red: Red, ...nazivi: string[]): unknown {
  for (const k of nazivi) if (k in red) return red[k]
  const kljucevi = Object.keys(red)
  for (const n of nazivi) {
    const cilj = n.trim().toLowerCase()
    const pogodak = kljucevi.find(k => k.trim().toLowerCase() === cilj)
    if (pogodak) return red[pogodak]
  }
  return undefined
}

function tekst(v: unknown): string {
  if (v == null) return ''
  return String(v).trim()
}

export function procitajTabelu(buf: Buffer, pojam = false): { stavke: TabelaStavka[]; greska?: string } {
  let redovi: Red[]
  try {
    const wb = XLSX.read(buf, { type: 'buffer' })
    const ws = wb.Sheets[wb.SheetNames[0]]
    if (!ws) return { stavke: [], greska: 'prazan-fajl' }
    redovi = XLSX.utils.sheet_to_json<Red>(ws)
  } catch {
    return { stavke: [], greska: 'neispravan-fajl' }
  }
  if (!Array.isArray(redovi) || redovi.length === 0) {
    return { stavke: [], greska: 'nema-redova' }
  }

  // Vešanje ima tri kolone umesto šest: pojam, opis, kategorija. Mapira
  // se u ista polja koja RPC očekuje (question / correct / genre).
  if (pojam) {
    return {
      stavke: redovi.map(r => ({
        question: tekst(uzmi(r, 'Pojam', 'pojam', 'Reč', 'Rec', 'rec')),
        correct: tekst(uzmi(r, 'Opis', 'opis', 'Pomoć', 'Pomoc', 'Hint', 'hint')),
        wrong: [],
        genre: tekst(uzmi(r, 'Kategorija', 'kategorija', 'Category')),
      })),
    }
  }

  // Prazni redovi se ne odbacuju ovde nego se prosleđuju dalje: RPC ih
  // prijavljuje po broju reda, pa korisnik zna gde da popravi fajl.
  const stavke = redovi.map(r => ({
    question: tekst(uzmi(r, 'Pitanje', 'pitanje')),
    correct: tekst(uzmi(r, 'Tačan odgovor', 'Tacan odgovor', 'Tačan_odgovor', 'tacan odgovor')),
    wrong: [
      tekst(uzmi(r, 'Netačno', 'Netacno', 'netacno', 'Pogrešan 1', 'Pogresan 1', 'Pogrešan_1')),
      tekst(uzmi(r, 'Netačno_1', 'Netacno_1', 'Netačno 1', 'netacno_1', 'Pogrešan 2', 'Pogresan 2', 'Pogrešan_2')),
      tekst(uzmi(r, 'Netačno_2', 'Netacno_2', 'Netačno 2', 'netacno_2', 'Pogrešan 3', 'Pogresan 3', 'Pogrešan_3')),
    ].filter(v => v !== ''),
    genre: tekst(uzmi(r, 'Žanr', 'Zanr', 'zanr', 'genre', 'Genre')),
  }))

  return { stavke }
}
