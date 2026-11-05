/** Kampanja 05.11.2026: aplikacija izašla za iPhone i Android (tekst odobrio vlasnik). */
export const KAMPANJA_APLIKACIJA = 'aplikacija-2026-11'

const APP_STORE = 'https://apps.apple.com/rs/app/librum-kviz/id6830091653'
const GOOGLE_PLAY = 'https://play.google.com/store/apps/details?id=club.librum.kviz'
const SAJT = 'https://kviz.librum.club'

export const NASLOV_APLIKACIJA = 'Librum kviz je stigao na telefon'

/** Nadimak ide u HTML: korisnik ga sam bira, pa se mora očistiti. */
function ocisti(tekst: string): string {
  return tekst.replace(/[&<>"']/g, z => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[z]!))
}

/** Adresa za odjavu iz mejla (strana sa potvrdom). */
export function adresaOdjave(token: string): string {
  return `${SAJT}/odjava/${token}`
}

/** Adresa za odjavu jednim klikom (List-Unsubscribe-Post, RFC 8058). */
export function adresaOdjaveJednimKlikom(token: string): string {
  return `${SAJT}/api/v1/odjava/${token}`
}

/**
 * HTML i tekst mejla za jednog primaoca.
 *
 * @example const { html, tekst } = mejlAplikacija('stefan', '5b1c-...')
 */
export function mejlAplikacija(nadimak: string | null, token: string): { html: string; tekst: string } {
  const pozdrav = nadimak ? `Zdravo ${ocisti(nadimak)},` : 'Zdravo,'
  const odjava = adresaOdjave(token)
  const dugme = (href: string, nadnaslov: string, ime: string) =>
    `<a href="${href}" style="display:inline-block;background:#151515;color:#FFFFFF;text-decoration:none;border-radius:12px;padding:10px 18px;margin:0 6px 8px 0;font-family:Helvetica,Arial,sans-serif;">
      <span style="display:block;font-size:11px;opacity:.8;">${nadnaslov}</span><span style="display:block;font-size:17px;font-weight:700;">${ime}</span></a>`

  const html = `<!DOCTYPE html>
<html lang="sr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${NASLOV_APLIKACIJA}</title></head>
<body style="margin:0;padding:0;background:#F3F0E6;">
<div style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif;max-width:520px;margin:0 auto;padding:32px 24px;color:#151515;">
  <p style="font-size:22px;font-weight:900;letter-spacing:-0.5px;margin:0 0 28px;">Librum kviz</p>
  <p style="font-size:16px;line-height:1.55;margin:0 0 14px;">${pozdrav}</p>
  <p style="font-size:16px;line-height:1.55;margin:0 0 18px;">Librum kviz od danas imaš u džepu: aplikacija je izašla za iPhone i Android, besplatno.</p>
  <ul style="font-size:15px;line-height:1.55;margin:0 0 18px;padding-left:20px;">
    <li style="margin-bottom:8px;"><strong>Osvajanje sveta</strong>: strategija na mapi sa 171 državom, svaku bitku dobija tačan odgovor.</li>
    <li style="margin-bottom:8px;"><strong>Karijera</strong>: kreni od probnog rada u Korporaciji, zaposli se, otvori svoju firmu i podigni neboder.</li>
    <li style="margin-bottom:8px;">Duel, PRO kviz, Brzi kviz, Vešanje i Slikari, sam ili sa drugarima.</li>
    <li>Više od 165.000 pitanja na srpskom.</li>
  </ul>
  <p style="font-size:16px;line-height:1.55;margin:0 0 20px;">Prijavi se istim nalogom kao na sajtu: rezultati i rang lista te čekaju.</p>
  <p style="margin:0 0 20px;">${dugme(APP_STORE, 'Preuzmi na', 'App Store')}${dugme(GOOGLE_PLAY, 'Nabavi na', 'Google Play')}</p>
  <p style="font-size:16px;line-height:1.55;margin:0 0 20px;">Uskoro stižu i nagrade za najbolje igrače na rang listi. Što pre kreneš, to bolje stojiš.</p>
  <p style="font-size:16px;line-height:1.55;margin:0 0 32px;">Vidimo se u igri,<br>Librum kviz</p>
  <hr style="border:none;border-top:1px solid #E7E1D0;margin:0 0 16px;">
  <p style="font-size:12px;line-height:1.5;color:#6F6C66;margin:0;">
    Dobijaš ovaj mejl jer imaš nalog na <a href="${SAJT}" style="color:#6F6C66;">kviz.librum.club</a>.
    Ne želiš ovakve poruke? <a href="${odjava}" style="color:#12907E;">Odjavi se</a>.
  </p>
</div></body></html>`

  const tekst = `${nadimak ? `Zdravo ${nadimak},` : 'Zdravo,'}

Librum kviz od danas imaš u džepu: aplikacija je izašla za iPhone i Android, besplatno.

- Osvajanje sveta: strategija na mapi sa 171 državom, svaku bitku dobija tačan odgovor.
- Karijera: kreni od probnog rada u Korporaciji, zaposli se, otvori svoju firmu i podigni neboder.
- Duel, PRO kviz, Brzi kviz, Vešanje i Slikari, sam ili sa drugarima.
- Više od 165.000 pitanja na srpskom.

Prijavi se istim nalogom kao na sajtu: rezultati i rang lista te čekaju.

App Store: ${APP_STORE}
Google Play: ${GOOGLE_PLAY}

Uskoro stižu i nagrade za najbolje igrače na rang listi. Što pre kreneš, to bolje stojiš.

Vidimo se u igri,
Librum kviz

Dobijaš ovaj mejl jer imaš nalog na kviz.librum.club. Odjava: ${odjava}`

  return { html, tekst }
}
