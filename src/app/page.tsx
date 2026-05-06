import Link from 'next/link'
import Image from 'next/image'

function BookMascot() {
  return (
    <svg width="180" height="200" viewBox="0 0 180 200" fill="none" xmlns="http://www.w3.org/2000/svg">
      <rect x="20" y="30" width="140" height="155" rx="12" fill="#1A1C4E"/>
      <rect x="20" y="30" width="12" height="155" rx="6" fill="#0f1033"/>
      <rect x="36" y="42" width="112" height="131" rx="6" fill="#FAF4EC"/>
      <line x1="92" y1="42" x2="92" y2="173" stroke="#e0d8ce" strokeWidth="2"/>
      <rect x="44" y="62" width="40" height="5" rx="2.5" fill="#c8c0b4"/>
      <rect x="44" y="74" width="36" height="5" rx="2.5" fill="#c8c0b4"/>
      <rect x="44" y="86" width="40" height="5" rx="2.5" fill="#c8c0b4"/>
      <rect x="44" y="98" width="32" height="5" rx="2.5" fill="#c8c0b4"/>
      <rect x="100" y="62" width="40" height="5" rx="2.5" fill="#c8c0b4"/>
      <rect x="100" y="74" width="36" height="5" rx="2.5" fill="#c8c0b4"/>
      <rect x="100" y="86" width="40" height="5" rx="2.5" fill="#c8c0b4"/>
      <rect x="100" y="98" width="32" height="5" rx="2.5" fill="#c8c0b4"/>
      <circle cx="68" cy="128" r="10" fill="white"/>
      <circle cx="112" cy="128" r="10" fill="white"/>
      <circle cx="70" cy="128" r="5" fill="#1A1C4E"/>
      <circle cx="114" cy="128" r="5" fill="#1A1C4E"/>
      <circle cx="72" cy="126" r="2" fill="white"/>
      <circle cx="116" cy="126" r="2" fill="white"/>
      <path d="M74 148 Q90 162 106 148" stroke="#1A1C4E" strokeWidth="3" strokeLinecap="round" fill="none"/>
      <circle cx="58" cy="143" r="7" fill="#FDC361" opacity="0.5"/>
      <circle cx="122" cy="143" r="7" fill="#FDC361" opacity="0.5"/>
      <path d="M20 90 Q4 100 8 115" stroke="#1A1C4E" strokeWidth="8" strokeLinecap="round"/>
      <circle cx="8" cy="117" r="6" fill="#1A1C4E"/>
      <path d="M160 90 Q176 100 172 115" stroke="#1A1C4E" strokeWidth="8" strokeLinecap="round"/>
      <circle cx="172" cy="117" r="6" fill="#1A1C4E"/>
      <text x="148" y="28" fontSize="18" fill="#FDC361">✦</text>
    </svg>
  )
}

function BookmarkMascot() {
  return (
    <svg width="120" height="200" viewBox="0 0 120 200" fill="none" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <linearGradient id="bmGrad" x1="15" y1="10" x2="105" y2="190" gradientUnits="userSpaceOnUse">
          <stop offset="0%" stopColor="#FDC361"/>
          <stop offset="100%" stopColor="#f0a832"/>
        </linearGradient>
      </defs>
      <path d="M15 10 H105 V165 L60 190 L15 165 Z" fill="url(#bmGrad)"/>
      <path d="M25 20 H95 V158 L60 181 L25 158 Z" fill="#fdd07a" opacity="0.4"/>
      <circle cx="44" cy="90" r="11" fill="white"/>
      <circle cx="76" cy="90" r="11" fill="white"/>
      <circle cx="46" cy="90" r="5.5" fill="#1A1C4E"/>
      <circle cx="78" cy="90" r="5.5" fill="#1A1C4E"/>
      <circle cx="48" cy="88" r="2" fill="white"/>
      <circle cx="80" cy="88" r="2" fill="white"/>
      <path d="M36 76 Q44 71 52 76" stroke="#1A1C4E" strokeWidth="2.5" strokeLinecap="round" fill="none"/>
      <path d="M68 76 Q76 71 84 76" stroke="#1A1C4E" strokeWidth="2.5" strokeLinecap="round" fill="none"/>
      <path d="M42 112 Q60 128 78 112" stroke="#1A1C4E" strokeWidth="3" strokeLinecap="round" fill="none"/>
      <circle cx="33" cy="106" r="8" fill="#e8944a" opacity="0.4"/>
      <circle cx="87" cy="106" r="8" fill="#e8944a" opacity="0.4"/>
      <rect x="42" y="4" width="36" height="10" rx="5" fill="#2C2D81"/>
      <circle cx="60" cy="9" r="5" fill="#3766B0"/>
    </svg>
  )
}

export default function Home() {
  return (
    <div className="min-h-screen flex flex-col" style={{ background: '#FAF4EC' }}>
      {/* Nav */}
      <nav style={{ background: 'linear-gradient(135deg, #1A1C4E 0%, #2C2D81 60%, #3766B0 100%)', borderBottom: '2px solid #FDC361' }}>
        <div className="max-w-6xl mx-auto px-4 md:px-6 h-16 flex items-center justify-between">
          <a href="https://www.librum.club" rel="noopener noreferrer">
            <Image src="/logo-dark.png" alt="Librum club" height={32} width={140} style={{ objectFit: 'contain', objectPosition: 'left' }} />
          </a>
          <div className="flex items-center gap-2">
            <Link href="/auth/prijava"
              className="text-sm font-medium px-3 md:px-4 py-2 rounded-xl transition-all"
              style={{ color: 'rgba(255,255,255,0.8)', border: '1px solid rgba(255,255,255,0.2)' }}>
              Prijava
            </Link>
            <Link href="/auth/registracija"
              className="text-sm font-semibold px-3 md:px-5 py-2 rounded-xl transition-all"
              style={{ background: '#FDC361', color: '#1A1C4E' }}>
              Registracija
            </Link>
          </div>
        </div>
      </nav>

      {/* Hero */}
      <section className="relative overflow-hidden py-12 md:py-20" style={{ background: 'linear-gradient(135deg, #1A1C4E 0%, #2C2D81 60%, #3766B0 100%)' }}>
        <div className="absolute inset-0 pointer-events-none overflow-hidden">
          <div className="absolute -top-32 -right-32 w-96 h-96 rounded-full opacity-10" style={{ background: '#FDC361' }} />
          <div className="absolute -bottom-20 -left-20 w-80 h-80 rounded-full opacity-10" style={{ background: '#5DBF94' }} />
        </div>

        <div className="relative max-w-6xl mx-auto px-6">
          {/* Desktop: mascots on sides */}
          <div className="hidden md:flex items-center gap-0">
            <div className="flex-1 flex justify-center">
              <div style={{ filter: 'drop-shadow(0 20px 40px rgba(0,0,0,0.3))', transform: 'rotate(-8deg)' }}>
                <BookmarkMascot />
              </div>
            </div>

            <div className="flex-1 text-center">
              <h1 className="text-5xl lg:text-6xl font-bold text-white mb-5 leading-tight">
                Testiraj svoje<br/>
                <span style={{ color: '#FDC361' }}>znanje!</span>
              </h1>
              <p className="text-lg mb-10 max-w-md mx-auto leading-relaxed" style={{ color: 'rgba(255,255,255,0.7)' }}>
                Kvizovi iz književnosti, istorije, kulture i još mnogo toga. Takmiči se sa prijateljima!
              </p>
              <div className="flex flex-col gap-3 items-center">
                <Link href="/auth/registracija"
                  className="inline-flex items-center justify-center gap-2 font-bold text-lg px-8 py-4 rounded-2xl transition-all hover:scale-105 w-64"
                  style={{ background: '#FDC361', color: '#1A1C4E', boxShadow: '0 8px 32px rgba(253,195,97,0.35)' }}>
                  Počni besplatno →
                </Link>
                <Link href="/auth/prijava"
                  className="inline-flex items-center justify-center font-medium text-base px-8 py-3 rounded-2xl transition-all w-64"
                  style={{ color: 'rgba(255,255,255,0.7)', border: '1px solid rgba(255,255,255,0.2)' }}>
                  Već imam nalog
                </Link>
              </div>
            </div>

            <div className="flex-1 flex justify-center">
              <div style={{ filter: 'drop-shadow(0 20px 40px rgba(0,0,0,0.3))', transform: 'rotate(5deg)' }}>
                <BookMascot />
              </div>
            </div>
          </div>

          {/* Mobile: stacked layout */}
          <div className="md:hidden text-center">
            <h1 className="text-4xl font-bold text-white mb-4 leading-tight">
              Testiraj svoje<br/>
              <span style={{ color: '#FDC361' }}>znanje!</span>
            </h1>
            <p className="text-base mb-8 leading-relaxed px-2" style={{ color: 'rgba(255,255,255,0.7)' }}>
              Kvizovi iz književnosti, istorije, kulture i još mnogo toga. Takmiči se sa prijateljima!
            </p>
            <div className="flex flex-col gap-3 mb-10">
              <Link href="/auth/registracija"
                className="inline-flex items-center justify-center gap-2 font-bold text-lg px-8 py-4 rounded-2xl transition-all"
                style={{ background: '#FDC361', color: '#1A1C4E', boxShadow: '0 8px 32px rgba(253,195,97,0.35)' }}>
                Počni besplatno →
              </Link>
              <Link href="/auth/prijava"
                className="inline-flex items-center justify-center font-medium text-base px-8 py-3 rounded-2xl"
                style={{ color: 'rgba(255,255,255,0.7)', border: '1px solid rgba(255,255,255,0.2)' }}>
                Već imam nalog
              </Link>
            </div>
            {/* Mascots row on mobile */}
            <div className="flex justify-center items-end gap-8">
              <div style={{ transform: 'rotate(-10deg)' }}><BookmarkMascot /></div>
              <div style={{ transform: 'rotate(6deg)', marginBottom: '-8px' }}><BookMascot /></div>
            </div>
          </div>
        </div>
      </section>

      {/* Stats */}
      <section className="py-8" style={{ background: '#0f1033' }}>
        <div className="max-w-4xl mx-auto px-6">
          <div className="grid grid-cols-3 gap-4 text-center">
            {[
              { num: '500+', label: 'Pitanja', color: '#FDC361' },
              { num: '10+', label: 'Kategorija', color: '#5DBF94' },
              { num: '∞', label: 'Radoznalosti', color: '#3766B0' },
            ].map(({ num, label, color }) => (
              <div key={label}>
                <div className="text-3xl font-bold mb-1" style={{ color }}>{num}</div>
                <div className="text-xs font-medium" style={{ color: 'rgba(255,255,255,0.45)' }}>{label}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Features */}
      <section className="py-16 md:py-20" style={{ background: '#FAF4EC' }}>
        <div className="max-w-5xl mx-auto px-6">
          <h2 className="text-2xl md:text-3xl font-bold text-center mb-3" style={{ color: '#2C2D81' }}>Zašto Librum Kviz?</h2>
          <p className="text-center mb-10 text-sm md:text-base" style={{ color: '#888' }}>Zabavan, izazovan i besplatan način da proveriš svoje znanje.</p>

          <div className="grid md:grid-cols-3 gap-5">
            {features.map(f => (
              <div key={f.title} className="bg-white rounded-2xl p-6 shadow-sm hover:shadow-md transition-all hover:-translate-y-1">
                <div className="w-12 h-12 rounded-xl flex items-center justify-center text-2xl mb-4" style={{ background: f.bg }}>
                  {f.icon}
                </div>
                <h3 className="font-bold text-base mb-2" style={{ color: '#2C2D81' }}>{f.title}</h3>
                <p className="text-sm leading-relaxed" style={{ color: '#888' }}>{f.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="py-16 relative overflow-hidden" style={{ background: 'linear-gradient(135deg, #1A1C4E 0%, #2C2D81 60%, #3766B0 100%)' }}>
        <div className="absolute -top-20 right-0 w-72 h-72 rounded-full opacity-10 pointer-events-none" style={{ background: '#FDC361' }} />
        <div className="relative max-w-xl mx-auto px-6 text-center">
          <div className="text-5xl mb-4">🏆</div>
          <h2 className="text-2xl md:text-4xl font-bold text-white mb-4">Spreman/na za izazov?</h2>
          <p className="mb-8 text-base md:text-lg" style={{ color: 'rgba(255,255,255,0.65)' }}>Registruj se besplatno i odmah počni da igraš.</p>
          <Link href="/auth/registracija"
            className="inline-flex items-center gap-2 font-bold text-lg px-10 py-4 rounded-2xl transition-all hover:scale-105"
            style={{ background: '#FDC361', color: '#1A1C4E', boxShadow: '0 8px 32px rgba(253,195,97,0.35)' }}>
            Registruj se — besplatno
          </Link>
        </div>
      </section>

      <footer className="py-6 text-center text-sm" style={{ background: '#0f1033', color: 'rgba(255,255,255,0.3)' }}>
        © {new Date().getFullYear()}{' '}
        <a href="https://www.librum.club" className="hover:text-white/60 transition-colors">Librum.club</a>
        {' '}· Kviz platforma
      </footer>
    </div>
  )
}

const features = [
  {
    icon: '📚',
    title: 'Kvizovi o knjigama',
    desc: 'Književnost, istorija, kultura, nauka i opšte znanje. Nešto za svakoga.',
    bg: '#EEF0FF',
  },
  {
    icon: '⚔️',
    title: 'Igraj zajedno',
    desc: 'Izazovi prijatelja u realnom vremenu. Ko je brži i precizniji?',
    bg: '#FFF8EC',
  },
  {
    icon: '🏆',
    title: 'Rang lista',
    desc: 'Poređaj se sa ostalim igračima. Skupljaj poene i penjaj se na vrh!',
    bg: '#E8F8F0',
  },
]
