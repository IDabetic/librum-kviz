import { createClient } from '@supabase/supabase-js'

// Server-only Supabase client using the service role key. Never import
// this in a "use client" file or any code that ships to the browser —
// the service role key bypasses RLS and would be a full breach if it
// leaked. Only API routes and server actions that have already verified
// the caller is an admin should ever instantiate this.
//
// Throws on construction if SUPABASE_SERVICE_ROLE_KEY is missing so a
// misconfigured Vercel env surfaces immediately instead of silently
// downgrading to anon and returning empty data.
export function createAdminClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY
  if (!url) throw new Error('Missing NEXT_PUBLIC_SUPABASE_URL')
  if (!key) throw new Error('Missing SUPABASE_SERVICE_ROLE_KEY — set this in Vercel env (server-only, never NEXT_PUBLIC_*).')
  return createClient(url, key, {
    auth: { autoRefreshToken: false, persistSession: false },
  })
}
