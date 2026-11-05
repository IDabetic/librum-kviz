import type { Metadata } from 'next'
import Link from 'next/link'
import { redirect } from 'next/navigation'
import { z } from 'zod'
import { createAdminClient } from '@/lib/supabase/admin'

export const dynamic = 'force-dynamic'

export const metadata: Metadata = {
  title: 'Odjava od mejlova',
  robots: { index: false, follow: false },
}

/** Server radnja: odjava tek na dugme, jer mejl programi otvaraju linkove sami (provera linkova) i to ne sme da odjavi. */
async function odjavi(formular: FormData) {
  'use server'
  const token = String(formular.get('token') ?? '')
  if (!z.string().uuid().safeParse(token).success) return
  const { error } = await createAdminClient().rpc('mejl_odjavi', { p_token: token })
  if (error) console.error('Odjava od mejlova nije uspela:', error.message)
  redirect(`/odjava/${token}?gotovo=1`)
}

export default async function OdjavaStrana({ params, searchParams }: {
  params: Promise<{ token: string }>
  searchParams: Promise<{ gotovo?: string }>
}) {
  const { token } = await params
  const { gotovo } = await searchParams
  const ispravan = z.string().uuid().safeParse(token).success

  return (
    <main className="min-h-screen grid place-items-center px-4 py-12" style={{ background: '#F6F1E7' }}>
      <div className="w-full max-w-md card-soft p-7 space-y-4">
        <h1 className="font-black tracking-tight" style={{ color: '#1A1B3A', fontSize: 26 }}>
          {gotovo ? 'Odjavljen si' : 'Odjava od mejlova'}
        </h1>
        {!ispravan ? (
          <p className="text-[15px]" style={{ color: '#4F5170' }}>Link za odjavu nije ispravan. Otvori ga ponovo iz mejla.</p>
        ) : gotovo ? (
          <p className="text-[15px]" style={{ color: '#4F5170' }}>Više ti nećemo slati obaveštenja o novostima. Nalog i rezultati ostaju kao što su bili.</p>
        ) : (
          <form action={odjavi} className="space-y-4">
            <p className="text-[15px]" style={{ color: '#4F5170' }}>Ne želiš mejlove o novostima Librum kviza? Nalog i rezultati ostaju, samo prestaju ovakve poruke.</p>
            <input type="hidden" name="token" value={token} />
            <button type="submit" className="w-full rounded-xl px-4 py-3 font-bold text-[15px]" style={{ background: '#1A1B3A', color: '#FFFFFF' }}>
              Odjavi me
            </button>
          </form>
        )}
        <Link href="/" className="inline-block text-[14px] font-semibold underline underline-offset-4" style={{ color: '#23845C' }}>Nazad na kviz</Link>
      </div>
    </main>
  )
}
