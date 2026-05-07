'use server'

import { createClient } from '@/lib/supabase/server'

type Result = { ok: true } | { ok: false; error: string }

export async function changeUnlockCode(newCode: string): Promise<Result> {
  const trimmed = newCode.trim()
  if (trimmed.length < 6) return { ok: false, error: 'Kod mora imati najmanje 6 karaktera.' }

  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return { ok: false, error: 'Niste prijavljeni.' }

  const { data: me } = await supabase.from('profiles').select('role').eq('id', user.id).single()
  if (!me || me.role !== 'super_admin') {
    return { ok: false, error: 'Samo super admin može da menja admin kod.' }
  }

  const { error } = await supabase
    .from('admin_settings')
    .update({ value: trimmed, updated_at: new Date().toISOString(), updated_by: user.id })
    .eq('key', 'unlock_code')
  if (error) return { ok: false, error: error.message }

  return { ok: true }
}
