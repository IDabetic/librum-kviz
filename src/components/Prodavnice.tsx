/**
 * Dugmad za App Store i Google Play (obe aplikacije objavljene 05.11.2026).
 * Bez linka dugme prikazuje „Uskoro” (ostaje za neku buduću prodavnicu).
 *
 * @example <Prodavnice tamno />
 */
const APP_STORE: string | null = 'https://apps.apple.com/rs/app/librum-kviz/id6830091653'
const GOOGLE_PLAY: string | null = 'https://play.google.com/store/apps/details?id=club.librum.kviz'

export function Prodavnice({ tamno = false }: { tamno?: boolean }) {
  const stavke = [
    { ime: 'App Store', nadnaslov: 'Preuzmi na', href: APP_STORE, ikonica: 'M16.4 12.6c0-2.6 2.1-3.8 2.2-3.9-1.2-1.8-3.1-2-3.7-2-1.6-.2-3.1.9-3.9.9-.8 0-2-.9-3.4-.9-1.7 0-3.3 1-4.2 2.6-1.8 3.1-.5 7.7 1.3 10.2.9 1.2 1.9 2.6 3.2 2.6 1.3-.1 1.8-.8 3.3-.8 1.6 0 2 .8 3.4.8 1.4 0 2.3-1.3 3.1-2.5 1-1.4 1.4-2.8 1.4-2.9-.1 0-2.7-1-2.7-4.1zM13.9 5c.7-.9 1.2-2 1-3.2-1 .1-2.2.7-3 1.6-.6.7-1.2 1.9-1 3.1 1.1.1 2.3-.6 3-1.5z' },
    { ime: 'Google Play', nadnaslov: 'Nabavi na', href: GOOGLE_PLAY, ikonica: 'M3.6 1.8 13.4 12 3.6 22.2c-.4-.2-.6-.7-.6-1.2V3c0-.5.2-1 .6-1.2zm11 11.4 2.6 2.6-11.5 6.6 8.9-9.2zm3.9-2.9 2.6 1.5c.8.5.8 1.6 0 2.1l-2.6 1.5-2.9-2.6 2.9-2.5zM5.7 1.6 17.2 8.2l-2.6 2.6-8.9-9.2z' },
  ]
  return (
    <div className="flex flex-wrap gap-3">
      {stavke.map(s => {
        const sadrzaj = (
          <>
            <svg width="26" height="26" viewBox="0 0 24 24" aria-hidden fill="currentColor"><path d={s.ikonica} /></svg>
            <span className="text-left leading-tight">
              <span className="block text-[11px] font-semibold opacity-80">{s.href ? s.nadnaslov : 'Uskoro na'}</span>
              <span className="block text-[17px] font-bold">{s.ime}</span>
            </span>
          </>
        )
        const stil = { border: `2px solid ${tamno ? '#F3F0E6' : '#151515'}`, boxShadow: `0 4px 0 ${tamno ? '#F3F0E6' : '#151515'}` }
        const klase = `inline-flex items-center gap-3 rounded-2xl px-5 py-3 ${tamno ? 'bg-[#F3F0E6] text-[#151515]' : 'bg-[#151515] text-white'}`
        return s.href
          ? <a key={s.ime} href={s.href} className={klase} style={stil}>{sadrzaj}</a>
          : <span key={s.ime} className={`${klase} opacity-90`} style={stil} aria-label={`${s.ime}, uskoro`}>{sadrzaj}</span>
      })}
    </div>
  )
}

/**
 * Male ikonice prodavnica za zaglavlje (bez natpisa; naziv je u pristupačnosti).
 *
 * @example <ProdavniceIkonice />
 */
export function ProdavniceIkonice() {
  const stavke = [
    { ime: 'App Store', href: APP_STORE, put: 'M16.4 12.6c0-2.6 2.1-3.8 2.2-3.9-1.2-1.8-3.1-2-3.7-2-1.6-.2-3.1.9-3.9.9-.8 0-2-.9-3.4-.9-1.7 0-3.3 1-4.2 2.6-1.8 3.1-.5 7.7 1.3 10.2.9 1.2 1.9 2.6 3.2 2.6 1.3-.1 1.8-.8 3.3-.8 1.6 0 2 .8 3.4.8 1.4 0 2.3-1.3 3.1-2.5 1-1.4 1.4-2.8 1.4-2.9-.1 0-2.7-1-2.7-4.1zM13.9 5c.7-.9 1.2-2 1-3.2-1 .1-2.2.7-3 1.6-.6.7-1.2 1.9-1 3.1 1.1.1 2.3-.6 3-1.5z' },
    { ime: 'Google Play', href: GOOGLE_PLAY, put: 'M3.6 1.8 13.4 12 3.6 22.2c-.4-.2-.6-.7-.6-1.2V3c0-.5.2-1 .6-1.2zm11 11.4 2.6 2.6-11.5 6.6 8.9-9.2zm3.9-2.9 2.6 1.5c.8.5.8 1.6 0 2.1l-2.6 1.5-2.9-2.6 2.9-2.5zM5.7 1.6 17.2 8.2l-2.6 2.6-8.9-9.2z' },
  ]
  return (
    <div className="flex items-center gap-2">
      {stavke.map(s => {
        const ikonica = <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden fill="currentColor"><path d={s.put} /></svg>
        const klase = 'w-10 h-10 grid place-items-center rounded-xl'
        const stil = { background: '#151515', color: '#FFFFFF' }
        return s.href
          ? <a key={s.ime} href={s.href} className={klase} style={stil} aria-label={`Preuzmi na ${s.ime}`}>{ikonica}</a>
          : <span key={s.ime} className={klase} style={stil} aria-label={`${s.ime}, uskoro`} title={`${s.ime}, uskoro`}>{ikonica}</span>
      })}
    </div>
  )
}
