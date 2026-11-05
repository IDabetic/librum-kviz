'use client'

type Tema = 'light' | 'dark'

/** Skripta za <head>: postavlja izabranu temu pre prvog iscrtavanja (bez treptanja). */
export const TEMA_SKRIPTA =
  "try{var t=localStorage.getItem('tema');if(t==='light'||t==='dark')document.documentElement.dataset.theme=t}catch(e){}"

function trenutnaTema(): Tema {
  const izabrana = document.documentElement.dataset.theme
  if (izabrana === 'light' || izabrana === 'dark') return izabrana
  return matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
}

/**
 * Dugme svetla/tamna tema (samo ikonica). Prvi put prati sistem, posle pamti izbor.
 *
 * @example <TemaPrekidac />
 */
export function TemaPrekidac() {
  function prebaci() {
    const nova: Tema = trenutnaTema() === 'dark' ? 'light' : 'dark'
    document.documentElement.dataset.theme = nova
    try { localStorage.setItem('tema', nova) } catch { /* privatni prozor: tema važi do osvežavanja */ }
  }

  // Ikonica se bira u CSS-u po temi (.logo-svetli/.logo-tamni), pa nema stanja ni treptanja.
  return (
    <button type="button" onClick={prebaci} aria-label="Promeni svetlu ili tamnu temu" title="Svetla / tamna tema"
      className="w-10 h-10 grid place-items-center rounded-xl"
      style={{ border: '1px solid var(--line)', color: 'var(--ink)', background: 'var(--surface)' }}>
      <svg className="logo-svetli" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
        <path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z" />
      </svg>
      <svg className="logo-tamni" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
        <circle cx="12" cy="12" r="4" /><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" />
      </svg>
    </button>
  )
}
