// Bedž „Autor pitanja”.
//
// Prag se čuva u `admin_settings` pod ključem `prag_bedza`, a čita se
// kroz RPC `prag_bedza()` — `admin_settings` po RLS-u čita samo
// super_admin, a bedž treba da vidi svako. Podrazumevano je 3: dok se
// baza autora ne razmrda, deset prihvaćenih je predaleko da bi iko
// stigao do bedža.

import type { SupabaseClient } from '@supabase/supabase-js'

export const PRAG_PODRAZUMEVANO = 3

export function jeAutorPitanja(prihvacenih: number, prag: number = PRAG_PODRAZUMEVANO): boolean {
  return prihvacenih >= prag
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function ucitajPragBedza(supabase: SupabaseClient<any, any, any>): Promise<number> {
  const { data } = await supabase.rpc('prag_bedza')
  const n = Number(data)
  return Number.isFinite(n) && n > 0 ? n : PRAG_PODRAZUMEVANO
}
