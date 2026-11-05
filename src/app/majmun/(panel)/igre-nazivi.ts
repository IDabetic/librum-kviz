/** Nazivi igara kako ih vraća admin_aktivnost (rezultati_igara.igra, 'karijera' i stare veb tabele sa sufiksom -veb). */
export const NAZIVI_IGARA: Record<string, string> = {
  pro: 'PRO kviz',
  brzi: 'Brzi kviz',
  duel: 'Duel',
  book: 'Book kviz',
  tema: 'Kviz po temi',
  slikari: 'Slikari',
  vesanje: 'Vešanje',
  osvajanje: 'Osvajanje sveta',
  karijera: 'Karijera',
  'pro-veb': 'PRO kviz (veb)',
  'book-veb': 'Book kviz (veb)',
  'kafanski-veb': 'Kafanski kviz (veb)',
  'vesanje-veb': 'Vešanje (veb)',
  'brzi-veb': 'Brzi kviz (veb)',
}

/**
 * Datum i vreme u kratkom srpskom obliku.
 * @example vremeKratko('2026-11-05T11:26:34Z') // "05.11. 12:26"
 */
export function vremeKratko(s: string | null): string {
  if (!s) return '—'
  return new Date(s).toLocaleString('sr', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit', timeZone: 'Europe/Belgrade' })
}

/**
 * Da li je avatar slika sa sajta (public/avatars); avatari iz aplikacije imaju drugi zapis (npr. "p1:0:6").
 * @example jeAvatarSajta('animal_12.png') // true
 */
export function jeAvatarSajta(a: string | null | undefined): a is string {
  return !!a && /^animal_\d{2}\.png$/.test(a)
}

/**
 * Broj sa srpskim razdvajanjem hiljada.
 * @example brojSr(12500) // "12.500"
 */
export function brojSr(n: number | null | undefined): string {
  return new Intl.NumberFormat('sr').format(Math.round(Number(n ?? 0)))
}
