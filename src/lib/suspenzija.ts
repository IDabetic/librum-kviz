import type { SupabaseClient } from '@supabase/supabase-js'
import { createAdminClient } from '@/lib/supabase/admin'

export const SUSPENZIJA_DANI = 3
export const PRAG_PRIJAVA = 2

const FONDOVI = ['questions', 'book_questions', 'kafana_questions', 'hangman_words'] as const

export function josTraje(iso: string | null | undefined): boolean {
  if (!iso) return false
  const t = Date.parse(iso)
  return Number.isFinite(t) && t > Date.now()
}

export async function ucitajSuspenziju(
  supabase: SupabaseClient,
  userId: string,
): Promise<string | null> {
  const { data, error } = await supabase
    .from('profiles')
    .select('suspended_until')
    .eq('id', userId)
    .maybeSingle()
  if (error) return null
  const doKad = (data as { suspended_until?: string | null } | null)?.suspended_until
  return josTraje(doKad) ? doKad! : null
}

export async function povuciPitanjaAutora(userId: string): Promise<number> {
  const admin = createAdminClient()
  const { data } = await admin
    .from('question_submissions')
    .select('accepted_id, accepted_table')
    .eq('submitted_by', userId)
    .eq('status', 'accepted')

  const poTabeli = new Map<string, string[]>()
  for (const r of data ?? []) {
    const id = r.accepted_id as string | null
    const tabela = r.accepted_table as string | null
    if (!id || !tabela || !FONDOVI.includes(tabela as typeof FONDOVI[number])) continue
    const lista = poTabeli.get(tabela) ?? []
    lista.push(id)
    poTabeli.set(tabela, lista)
  }

  let n = 0
  for (const [tabela, ids] of poTabeli) {
    const { error } = await admin.from(tabela).update({ is_active: false }).in('id', ids)
    if (!error) n += ids.length
  }
  const { data: vesanje } = await admin
    .from('hangman_words')
    .update({ is_active: false })
    .eq('created_by', userId)
    .eq('is_active', true)
    .select('id')
  n += vesanje?.length ?? 0
  return n
}

export async function suspendujAutora(userId: string): Promise<string> {
  const admin = createAdminClient()
  const doKad = new Date(Date.now() + SUSPENZIJA_DANI * 24 * 60 * 60 * 1000).toISOString()
  await admin.from('profiles').update({ suspended_until: doKad }).eq('id', userId)
  return doKad
}
