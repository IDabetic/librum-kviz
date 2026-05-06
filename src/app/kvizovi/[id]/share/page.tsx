import { headers } from 'next/headers'
import type { Metadata } from 'next'
import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { Logo } from '@/components/Logo'

type Props = { params: Promise<{ id: string }>; searchParams: Promise<{ score?: string; level?: string }> }

export async function generateMetadata({ params, searchParams }: Props): Promise<Metadata> {
  await params
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
    ? `Dostigao/la sam Nivo ${level} sa ${score} bodova na Librum Kvizu. Možeš li bolje?`
    : 'Testiraj svoje znanje na Librum Kviz platformi.'

  return {
    title,
    description,
    openGraph: {
      title, description,
      images: [{ url: ogImage, width: 1200, height: 628, alt: 'Librum Kviz rezultat' }],
      type: 'website',
    },
    twitter: { card: 'summary_large_image', title, description, images: [ogImage] },
  }
}

export default async function SharePage({ params, searchParams }: Props) {
  const { id } = await params
  const { score = '0', level = '0' } = await searchParams

  const supabase = await createClient()
  const { data: quiz } = await supabase.from('quizzes').select('title, difficulty').eq('id', id).single()

  const hasScore = score !== '0'

  return (
    <div className="min-h-screen flex items-center justify-center px-4 py-10" style={{ background: '#FAFAFA' }}>
      <div className="w-full max-w-md text-center">

        <div className="mb-7 flex justify-center">
          <Logo height={32} />
        </div>

        {hasScore ? (
          <div className="card-soft p-9 mb-6">
            <p className="text-[13px] mb-2" style={{ color: '#9C9C9C' }}>Rezultat igrača</p>
            {quiz?.title && (
              <p className="font-bold text-[15px] mb-7" style={{ color: '#343434' }}>{quiz.title}</p>
            )}
            <div className="font-black tracking-tight" style={{ color: '#343434', fontSize: 'clamp(64px, 12vw, 96px)', lineHeight: 1 }}>
              {score}
            </div>
            <div className="text-[14px] font-semibold mb-6 mt-2" style={{ color: '#609DED' }}>bodova</div>
            <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full text-[13px] font-bold"
              style={{ background: '#FFECBC', color: '#9c7a13' }}>
              Nivo {level}
            </div>
          </div>
        ) : (
          <div className="card-soft p-9 mb-6">
            <h1 className="font-black tracking-tight mb-3" style={{ color: '#343434', fontSize: 'clamp(28px, 5vw, 36px)' }}>
              Proveri svoje znanje
            </h1>
            <p className="text-[14px]" style={{ color: '#9C9C9C' }}>
              Testiraj svoje znanje na Librum Kviz platformi.
            </p>
          </div>
        )}

        <div className="flex flex-col gap-3">
          <Link href={`/kvizovi/${id}/igraj`} className="btn btn-primary btn-lg">
            Igraj ovaj kviz
          </Link>
          <Link href="/kvizovi" className="btn btn-secondary btn-lg">
            Svi kvizovi
          </Link>
        </div>
      </div>
    </div>
  )
}
