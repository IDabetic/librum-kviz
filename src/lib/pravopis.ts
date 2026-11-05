// Lake provere teksta pitanja pred objavljivanje.
//
// Namerno NIJE pravi pravopisni rečnik: takav bi na srpskom tražio
// ozbiljan rečnik i i dalje grešio na imenima. Ovo hvata samo ono što se
// u praksi ponavlja u korisničkim predlozima i što se popravlja mehanički,
// pa urednik odlučuje da li da primeni.

export type Zamerka = { kod: string; poruka: string }

const CIRILICA = /[Ѐ-ӿ]/
const LATINICA = /[A-Za-zČčĆćĐđŠšŽž]/

export function zamerke(pitanje: string, odgovori: string[] = []): Zamerka[] {
  const z: Zamerka[] = []
  const t = pitanje.trim()
  if (!t) return z

  if (/\s{2,}/.test(pitanje) || pitanje !== t) {
    z.push({ kod: 'razmaci', poruka: 'Višak razmaka (dupli razmak ili razmak na krajevima).' })
  }
  if (t[0] && t[0] !== t[0].toLocaleUpperCase('sr')) {
    z.push({ kod: 'veliko', poruka: 'Pitanje ne počinje velikim slovom.' })
  }
  if (!/[?!.]$/.test(t)) {
    z.push({ kod: 'upitnik', poruka: 'Pitanje se ne završava upitnikom.' })
  }
  if (CIRILICA.test(t) && LATINICA.test(t)) {
    z.push({ kod: 'pismo', poruka: 'Pomešane su ćirilica i latinica u istom pitanju.' })
  }
  if (/\s+[?!,.]/.test(t)) {
    z.push({ kod: 'interpunkcija', poruka: 'Razmak pre znaka interpunkcije.' })
  }
  if (t.length > 3 && t === t.toLocaleUpperCase('sr')) {
    z.push({ kod: 'velika', poruka: 'Pitanje je napisano svim velikim slovima.' })
  }
  for (const o of odgovori) {
    const oo = o.trim()
    if (oo && (oo !== o || /\s{2,}/.test(o))) {
      z.push({ kod: 'odgovor-razmaci', poruka: `Višak razmaka u odgovoru „${oo.slice(0, 30)}”.` })
      break
    }
  }
  return z
}

// Mehaničke ispravke: samo one kod kojih ne postoji dilema šta je tačno.
// Pismo se NE dira (ne zna se koje je htelo), a veliko početno slovo se
// popravlja jer je jedina alternativa da ostane greška.
export function popravi(pitanje: string): string {
  let t = pitanje.replace(/\s+/g, ' ').trim()
  t = t.replace(/\s+([?!,.])/g, '$1')
  if (t.length > 3 && t === t.toLocaleUpperCase('sr')) {
    t = t.charAt(0) + t.slice(1).toLocaleLowerCase('sr')
  }
  if (t[0]) t = t[0].toLocaleUpperCase('sr') + t.slice(1)
  if (t && !/[?!.]$/.test(t)) t += '?'
  return t
}
