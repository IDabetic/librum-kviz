import Link from 'next/link'
import { LibrumIcon } from '@/components/Header'

export default function Home() {
  return (
    <div className="min-h-screen flex flex-col">
      {/* Nav */}
      <nav className="absolute top-0 left-0 right-0 z-10 px-6 py-5 flex items-center justify-between max-w-6xl mx-auto w-full">
        <div className="flex items-center">
          <LibrumIcon size={36} dark={true} />
        </div>
        <div className="flex items-center gap-3">
          <Link href="/auth/prijava" className="text-white/80 hover:text-white text-sm font-medium transition-colors">
            Prijava
          </Link>
          <Link href="/auth/registracija" className="bg-[#5DBF94] hover:bg-[#45a87c] text-white text-sm font-semibold px-5 py-2.5 rounded-xl transition-colors">
            Registracija
          </Link>
        </div>
      </nav>

      {/* Hero */}
      <section className="relative min-h-[90vh] flex items-center justify-center overflow-hidden" style={{ background: 'linear-gradient(135deg, #2C2D81 0%, #3766B0 100%)' }}>
        <div className="absolute inset-0 overflow-hidden pointer-events-none">
          <div className="absolute -top-20 -right-20 w-96 h-96 rounded-full opacity-10" style={{ background: '#5DBF94' }} />
          <div className="absolute bottom-0 -left-20 w-80 h-80 rounded-full opacity-10" style={{ background: '#FDC361' }} />
        </div>

        <div className="relative text-center px-6 max-w-4xl mx-auto animate-fade-in">
          <div className="inline-flex items-center gap-2 bg-white/10 backdrop-blur-sm rounded-full px-4 py-2 mb-8">
            <span className="w-2 h-2 rounded-full bg-[#5DBF94] animate-pulse" />
            <span className="text-white/90 text-sm font-medium">Librum.club platforma</span>
          </div>

          <h1 className="text-5xl md:text-7xl font-bold text-white mb-6 leading-tight">
            Testiraj svoje
            <span className="block" style={{ color: '#FDC361' }}>znanje</span>
          </h1>
          <p className="text-xl text-white/70 mb-10 max-w-2xl mx-auto leading-relaxed">
            Kvizovi iz različitih oblasti, rang lista, i zabavan način da proverite koliko znate.
            Pridružite se Librum zajednici!
          </p>

          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <Link
              href="/auth/registracija"
              className="inline-flex items-center justify-center gap-2 bg-[#5DBF94] hover:bg-[#45a87c] text-white font-bold text-lg px-8 py-4 rounded-2xl transition-all hover:scale-105 shadow-lg shadow-teal-500/30"
            >
              Počni besplatno
              <svg width="20" height="20" viewBox="0 0 20 20" fill="none"><path d="M4 10h12M11 5l5 5-5 5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/></svg>
            </Link>
            <Link
              href="/auth/prijava"
              className="inline-flex items-center justify-center bg-white/10 hover:bg-white/20 text-white font-semibold text-lg px-8 py-4 rounded-2xl transition-all border border-white/20"
            >
              Već imam nalog
            </Link>
          </div>
        </div>
      </section>

      {/* Stats */}
      <section className="bg-white py-16">
        <div className="max-w-5xl mx-auto px-6">
          <div className="grid grid-cols-3 gap-8 text-center">
            {[
              { num: '100+', label: 'Pitanja', color: '#2C2D81' },
              { num: '10+', label: 'Kategorija', color: '#5DBF94' },
              { num: '∞', label: 'Znatiželje', color: '#FDC361' },
            ].map(({ num, label, color }) => (
              <div key={label}>
                <div className="text-4xl font-bold mb-1" style={{ color }}>{num}</div>
                <div className="text-gray-500 text-sm">{label}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Features */}
      <section className="py-20 bg-[#F5F6FA]">
        <div className="max-w-5xl mx-auto px-6">
          <h2 className="text-3xl font-bold text-center mb-4" style={{ color: '#2C2D81' }}>Zašto Librum Kviz?</h2>
          <p className="text-gray-500 text-center mb-12 max-w-xl mx-auto">Zabavan, izazovan i besplatan način da proverite i unapredite svoje znanje.</p>

          <div className="grid md:grid-cols-3 gap-6">
            {features.map(f => (
              <div key={f.title} className="bg-white rounded-2xl p-6 shadow-sm hover:shadow-md transition-shadow">
                <div className="w-12 h-12 rounded-xl flex items-center justify-center text-2xl mb-4" style={{ background: f.bg }}>
                  {f.icon}
                </div>
                <h3 className="font-bold text-lg mb-2" style={{ color: '#2C2D81' }}>{f.title}</h3>
                <p className="text-gray-500 text-sm leading-relaxed">{f.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="py-20" style={{ background: 'linear-gradient(135deg, #2C2D81 0%, #3766B0 100%)' }}>
        <div className="max-w-2xl mx-auto px-6 text-center">
          <h2 className="text-4xl font-bold text-white mb-4">Spreman/na za izazov?</h2>
          <p className="text-white/70 mb-8 text-lg">Registruj se besplatno i odmah počni da igraš.</p>
          <Link
            href="/auth/registracija"
            className="inline-flex items-center gap-2 bg-[#FDC361] hover:bg-[#f0b64e] text-[#2C2D81] font-bold text-lg px-10 py-4 rounded-2xl transition-all hover:scale-105 shadow-lg"
          >
            Registruj se odmah
          </Link>
        </div>
      </section>

      <footer className="bg-white py-8 text-center text-sm text-gray-400">
        © 2024 Librum.club · Kviz platforma
      </footer>
    </div>
  )
}

const features = [
  {
    icon: '🧠',
    title: 'Raznolika pitanja',
    desc: 'Opšte znanje, nauka, istorija, kultura i još mnogo toga. Za svakoga po nešto.',
    bg: '#EEF0FF',
  },
  {
    icon: '⏱️',
    title: 'Vremenski izazov',
    desc: 'Svako pitanje ima tajmer. Razmišljaj brzo — poeni zavise od brzine!',
    bg: '#E8F8F0',
  },
  {
    icon: '🏆',
    title: 'Rang lista',
    desc: 'Poređajte se sa ostalim igračima. Ko je najbrži i najtačniji?',
    bg: '#FFF8EC',
  },
]
