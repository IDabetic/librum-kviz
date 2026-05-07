'use server'

import { createClient } from '@/lib/supabase/server'

type LookupResult =
  | { ok: true; userId: string; name: string; currentRole: string }
  | { ok: false; error: string }

export async function lookupUserByEmail(email: string): Promise<LookupResult> {
  const trimmed = email.trim().toLowerCase()
  if (!trimmed) return { ok: false, error: 'Upiši email.' }

  const supabase = await createClient()

  // Find profile by email column (mirror of auth.users.email kept on profile)
  const { data: profile } = await supabase
    .from('profiles')
    .select('id, first_name, last_name, nickname, role, email')
    .ilike('email', trimmed)
    .maybeSingle()

  if (!profile) {
    return { ok: false, error: 'Korisnik sa tim email-om ne postoji. Mora prvo da se registruje na sajtu.' }
  }

  const name = profile.nickname || `${profile.first_name || ''} ${profile.last_name || ''}`.trim() || 'Igrač'
  return { ok: true, userId: profile.id, name, currentRole: profile.role }
}

type AssignResult = { ok: true } | { ok: false; error: string }

export async function assignRole(userId: string, newRole: string): Promise<AssignResult> {
  if (!['user', 'urednik', 'moderator', 'super_admin'].includes(newRole)) {
    return { ok: false, error: 'Nepoznata uloga.' }
  }
  const supabase = await createClient()

  // Verify current user is super_admin (only super_admin can manage roles)
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return { ok: false, error: 'Niste prijavljeni.' }
  const { data: me } = await supabase.from('profiles').select('role').eq('id', user.id).single()
  if (!me || me.role !== 'super_admin') {
    return { ok: false, error: 'Samo super admin može da menja uloge.' }
  }

  const { error } = await supabase.from('profiles').update({ role: newRole }).eq('id', userId)
  if (error) return { ok: false, error: error.message }
  return { ok: true }
}
