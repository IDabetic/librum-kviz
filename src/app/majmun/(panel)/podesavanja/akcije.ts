'use server'

import { z } from 'zod'
import { createClient as napraviKlijenta } from '@supabase/supabase-js'
import { createClient } from '@/lib/supabase/server'
import { ADMIN_ULOGE, jeDvostrukoPotvrdjen } from '@/lib/admin-pristup'
import { rateLimit } from '@/lib/rate-limit'

type Ishod = { ok: true; poruka: string } | { ok: false; greska: string }

const MIN_LOZINKA = 10
const novaLozinka = z.string().min(MIN_LOZINKA, `Nova lozinka mora imati najmanje ${MIN_LOZINKA} znakova.`).max(128)
const noviMejl = z.string().trim().toLowerCase().email('Upiši ispravan mejl.')

/** Admin sa potvrđenim drugim korakom, ili null. */
async function prijavljeniAdmin() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return null
  const { data: profil } = await supabase.from('profiles').select('role').eq('id', user.id).single()
  if (!profil || !(ADMIN_ULOGE as readonly string[]).includes(profil.role)) return null
  if (!(await jeDvostrukoPotvrdjen(supabase))) return null
  return { supabase, user }
}

/**
 * Promena lozinke admina: traži trenutnu lozinku (otvoren računar sam ne menja lozinku).
 *
 * @example await promeniLozinku('stara-lozinka', 'nova-duga-lozinka')
 */
export async function promeniLozinku(trenutna: string, nova: string): Promise<Ishod> {
  const admin = await prijavljeniAdmin()
  if (!admin) return { ok: false, greska: 'Prijavi se ponovo u admin.' }
  const proverena = novaLozinka.safeParse(nova)
  if (!proverena.success) return { ok: false, greska: proverena.error.issues[0].message }
  if (!rateLimit(`admin-lozinka:${admin.user.id}`, 5, 15 * 60_000).ok) return { ok: false, greska: 'Previše pokušaja. Probaj za 15 minuta.' }

  // Trenutna lozinka se proverava zasebnom, privremenom sesijom: ne dira kolačiće i drugi korak ove prijave.
  const provera = napraviKlijenta(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!, {
    auth: { persistSession: false, autoRefreshToken: false },
  })
  const { error: pogresna } = await provera.auth.signInWithPassword({ email: admin.user.email ?? '', password: trenutna })
  if (pogresna) return { ok: false, greska: 'Trenutna lozinka nije tačna.' }
  await provera.auth.signOut({ scope: 'local' })

  const { error } = await admin.supabase.auth.updateUser({ password: proverena.data })
  if (error) return { ok: false, greska: error.message }
  return { ok: true, poruka: 'Lozinka je promenjena.' }
}

/**
 * Promena mejla admina: Supabase šalje potvrdu na staru i novu adresu, mejl se menja tek posle obe.
 *
 * @example await promeniMejl('novi@librum.club')
 */
export async function promeniMejl(mejl: string): Promise<Ishod> {
  const admin = await prijavljeniAdmin()
  if (!admin) return { ok: false, greska: 'Prijavi se ponovo u admin.' }
  const proveren = noviMejl.safeParse(mejl)
  if (!proveren.success) return { ok: false, greska: proveren.error.issues[0].message }
  if (proveren.data === admin.user.email) return { ok: false, greska: 'To je već tvoj mejl.' }
  if (!rateLimit(`admin-mejl:${admin.user.id}`, 3, 60 * 60_000).ok) return { ok: false, greska: 'Previše pokušaja. Probaj za sat vremena.' }

  const { error } = await admin.supabase.auth.updateUser({ email: proveren.data })
  if (error) return { ok: false, greska: error.message }
  return { ok: true, poruka: `Poslali smo potvrdu na ${admin.user.email} i na ${proveren.data}. Mejl se menja kad potvrdiš oba.` }
}
