// Segmenti kviza u koje korisnik može da pošalje pitanje.
//
// Jedan izvor istine za: nazive na strani „Dodaj pitanja”, XML šablon,
// prikaz u admin panelu i tabelu u koju urednik prihvata predlog.
// `table` mora da prati POOLS iz /api/admin/questions-import.
//
// `igre` je pun spisak igara koje crpe taj fond (ide u zaglavlje XML
// šablona), `kratko` je potpis ispod imena na kartici za izbor — tamo
// „Book kviz / Book kviz” ne bi imalo smisla.

export const SEGMENTI = [
  {
    key: 'pro' as const,
    label: 'Opšti fond',
    igre: 'PRO kviz · Brzi kviz · Trivia duel',
    kratko: 'PRO · Brzi · Duel',
    desc: 'Opšte znanje: istorija, geografija, sport, film, nauka, kultura.',
    emoji: '🎯',
    accent: '#0E6F61',
    tint: 'rgba(18,144,126,0.12)',
    table: 'questions',
    zanr: false,
  },
  {
    key: 'book' as const,
    label: 'Book kviz',
    igre: 'Book kviz',
    kratko: 'Književnost',
    desc: 'Isključivo književnost: pisci, dela, likovi, nagrade, žanrovi.',
    emoji: '📚',
    accent: '#8A6A12',
    tint: 'rgba(255,216,77,0.18)',
    table: 'book_questions',
    zanr: true,
  },
  {
    key: 'kafana' as const,
    label: 'Kafanski kviz',
    igre: 'Kafanski kviz',
    kratko: 'Muzika i kafana',
    desc: 'Muzika i kafanski hitovi: narodnjaci, pop, rok klasici, izvođači.',
    emoji: '🎵',
    accent: '#C42B4F',
    tint: 'rgba(229,83,83,0.12)',
    table: 'kafana_questions',
    zanr: false,
  },
  {
    key: 'vesanje' as const,
    label: 'Vešanje',
    igre: 'Vešanje',
    kratko: 'Pojmovi za pogađanje',
    desc: 'Pojam koji se pogađa slovo po slovo, uz kratak opis i kategoriju.',
    emoji: '🪢',
    accent: '#0E6F61',
    tint: 'rgba(76,175,80,0.12)',
    table: 'hangman_words',
    zanr: false,
  },
]

// Vešanje nema ponuđene odgovore: umesto pitanja i četiri odgovora šalje
// se pojam, opis i kategorija. U bazi se to smešta u ista polja
// (question_text = pojam, correct_answer = opis, genre = kategorija), pa
// je ovaj spisak jedini način da kod zna koji obrazac da prikaže.
export const POJAM_SEGMENTI = ['vesanje']

// Šest kategorija koje `hangman_words.category` prihvata.
export const VESANJE_KATEGORIJE = [
  'Sport', 'Geografija', 'Istorija', 'Kultura', 'Priroda', 'Predmeti',
]

export function jePojam(key: string): boolean {
  return POJAM_SEGMENTI.includes(key)
}

export type SegmentKey = (typeof SEGMENTI)[number]['key']

export const SEGMENT_KLJUCEVI: SegmentKey[] = SEGMENTI.map(s => s.key)

export function segment(key: string) {
  return SEGMENTI.find(s => s.key === key) ?? SEGMENTI[0]
}

export function jeSegment(key: unknown): key is SegmentKey {
  return typeof key === 'string' && SEGMENT_KLJUCEVI.includes(key as SegmentKey)
}
