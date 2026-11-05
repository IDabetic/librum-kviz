import type { SupabaseClient } from '@supabase/supabase-js'

/** Uloge koje vide admin panel /majmun (ista lista kao `is_admin_user()` u bazi). */
export const ADMIN_ULOGE = ['urednik', 'moderator', 'super_admin'] as const

/**
 * Admin radnje traže i drugi korak prijave (kod iz aplikacije za autentifikaciju), ne samo ulogu:
 * ukradena lozinka sama ne otvara admin. Isto proverava baza (`is_admin_user()` traži aal2).
 *
 * @example
 * if (!(await jeDvostrukoPotvrdjen(supabase))) return NextResponse.json({ error: 'potreban drugi korak' }, { status: 403 })
 */
export async function jeDvostrukoPotvrdjen(supabase: SupabaseClient): Promise<boolean> {
  const { data, error } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel()
  if (error) {
    console.error('Provera drugog koraka prijave nije uspela:', error.message)
    return false
  }
  return data.currentLevel === 'aal2'
}
