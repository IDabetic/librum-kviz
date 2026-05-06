import { headers } from 'next/headers'
import type { Metadata } from 'next'
import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'

type Props = { params: Promise<{ id: string }>; searchParams: Promise<{ score?: string; level?: string }> }

export async function generateMetadata({ params, searchParams }: Props): Promise<Metadata> {
  const { id } = await params
  const { score = '0', level = '0' } = await searchParams

  const headersList = await headers()
  const host = headersList.get('host') || 'localhost:3000'
  const proto = host.includes('localhost') ? 'http' : 'https'
  const base = `${proto}://${host}`

  const ogImage = `${base}/api/og?score=${score}&level=${level}`
  const title = score !== '0'
    ? `Postigao/la sam ${score} bodova — Librum Kviz`
    : 'Proveri svoje znanje — Librum Kviz'
  const description = score !== '0'
    ? `Dostigao/la sam Nivo ${level} sa ${score} bodova na Librum Kvizt. Možeš li bolje?`
    : 'Testiraj literarno znanje na Librum Kviz platformi!'

  return {
    title,
    description,
    openGraph: {
      title,
      description,
      images: [{ url: ogImage, width: 1200, height: 628, alt: 'Librum Kviz rezultat' }],
      type: 'website',
    },
    twitter: {
      card: 'summary_large_image',
      title,
      description,
      images: [ogImage],
    },
  }
}

export default async function SharePage({ params, searchParams }: Props) {
  const { id } = await params
  const { score = '0', level = '0' } = await searchParams

  const supabase = await createClient()
  const { data: quiz } = await supabase.from('quizzes').select('title, difficulty').eq('id', id).single()

  const hasScore = score !== '0'

  return (
    <div className="min-h-screen flex items-center justify-center px-4"
      style={{ background: 'linear-gradient(135deg, #1A1C4E 0%, #2C2D81 60%, #3766B0 100%)' }}>
      <div className="w-full max-w-md text-center">

        {/* Logo area */}
        <div className="mb-8">
          <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full text-sm font-bold mb-4"
            style={{ background: 'rgba(253,195,97,0.15)', border: '1.5px solid rgba(253,195,97,0.3)', color: '#FDC361' }}>
            📚 Librum Kviz
          </div>
        </div>

        {hasScore ? (
          <div className="bg-white rounded-3xl shadow-2xl p-8 mb-6">
            <p className="text-gray-400 text-sm mb-2">Rezultat igrača</p>
            {quiz?.title && (
              <p className="font-semibold text-gray-700 mb-6">{quiz.title}</p>
            )}
            <div className="text-7xl font-black mb-1" style={{ color: '#2C2D81' }}>{score}</div>
            <div className="text-lg font-semibold mb-6" style={{ color: '#5DBF94' }}>bodova</div>
            <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full text-sm font-bold"
              style={{ background: '#EEF0FF', color: '#2C2D81' }}>
              🎯 Nivo {level} dostignut
            </div>
          </div>
        ) : (
          <div className="bg-white rounded-3xl shadow-2xl p-8 mb-6">
            <div className="text-5xl mb-4">📚</div>
            <h1 className="text-2xl font-black mb-2" style={{ color: '#2C2D81' }}>Proveri svoje znanje!</h1>
            <p className="text-gray-500">Testiraj literarno znanje na Librum Kviz platformi</p>
          </div>
        )}

        <div className="flex flex-col gap-3">
          <Link href={`/kvizovi/${id}/igraj`}
            className="w-full py-4 rounded-2xl font-bold text-white text-center transition-all hover:scale-[1.02]"
            style={{ background: 'linear-gradient(135deg, #5DBF94, #45a87c)' }}>
            🎯 Igraj ovaj kviz
          </Link>
          <Link href="/kvizovi"
            className="w-full py-3.5 rounded-2xl font-semibold text-center transition-all"
            style={{ background: 'rgba(255,255,255,0.1)', color: 'rgba(255,255,255,0.8)', border: '1px solid rgba(255,255,255,0.2)' }}>
            Svi kvizovi
          </Link>
        </div>
      </div>
    </div>
  )
}
