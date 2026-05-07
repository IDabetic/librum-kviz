'use server'

import { cookies } from 'next/headers'
import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { signUnlockToken } from '@/lib/admin-auth'

type ActionState = { error?: string } | undefined

export async function adminLoginAction(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const email = String(formData.get('email') || '').trim()
  const password = String(formData.get('password') || '')
  const code = String(formData.get('code') || '').trim()

  if (!email || !password || !code) {
    return { error: 'Sva polja su obavezna.' }
  }

  // Step 1: validate admin code via SECURITY DEFINER RPC (code never leaves DB)
  const supabaseAnon = await createClient()
  const { data: validCode } = await supabaseAnon.rpc('verify_unlock_code', { candidate: code })
  if (!validCode) {
    return { error: 'Pogrešni podaci.' }
  }

  // Step 2: sign in via Supabase
  const supabase = supabaseAnon
  const { data: signIn, error: signErr } = await supabase.auth.signInWithPassword({ email, password })
  if (signErr || !signIn.user) {
    return { error: 'Pogrešni podaci.' }
  }

  // Step 3: must have admin role
  const { data: profile } = await supabase
    .from('profiles')
    .select('role')
    .eq('id', signIn.user.id)
    .single()
  if (!profile || !['urednik', 'moderator', 'super_admin'].includes(profile.role)) {
    // Sign back out — non-admins shouldn't get a session via this route
    await supabase.auth.signOut()
    return { error: 'Pogrešni podaci.' }
  }

  // Step 4: set unlock cookie bound to user_id
  const token = signUnlockToken(signIn.user.id)
  const cookieStore = await cookies()
  cookieStore.set('majmun_unlock', token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict',
    path: '/majmun',
    maxAge: 8 * 60 * 60, // 8h
  })

  redirect('/majmun')
}

export async function adminLogoutAction() {
  const supabase = await createClient()
  await supabase.auth.signOut()
  const cookieStore = await cookies()
  cookieStore.delete({ name: 'majmun_unlock', path: '/majmun' })
  redirect('/')
}

