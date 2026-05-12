import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createAdminClient } from '@/lib/supabase/admin'

// Single admin endpoint for moderation actions on a target user.
// Authenticates the caller via the regular session cookie + checks
// they have an admin role; only then is the service-role admin client
// instantiated to perform the actual auth-level mutation.
//
// Actions:
//   - block          → bans the user (banned_until = +100y) and flips
//                      profiles.is_blocked = true. Existing sessions
//                      get refused on the next refresh.
//   - unblock        → reverses the above.
//   - approve_email  → marks email_confirmed_at, so the user can log
//                      in without clicking the confirmation link
//                      (useful when their Resend email got blocked).
//   - send_reset     → sends a "reset your password" email via Supabase
//                      → Resend. Same flow the user sees if they click
//                      "Zaboravljena lozinka".
//   - resend_invite  → resends the signup confirmation email.
//   - set_password   → admin types a new password directly. Should be
//                      used sparingly; communicate the new password to
//                      the user out-of-band.

const ADMIN_ROLES = new Set(['urednik', 'moderator', 'super_admin'])
const VALID_ACTIONS = new Set([
  'block', 'unblock', 'approve_email',
  'send_reset', 'resend_invite', 'set_password',
])

type Action = 'block' | 'unblock' | 'approve_email' | 'send_reset' | 'resend_invite' | 'set_password'

export async function POST(req: Request) {
  let body: { action?: string; user_id?: string; password?: string; redirect_to?: string } = {}
  try {
    const text = await req.text()
    body = text ? JSON.parse(text) : {}
  } catch {
    return NextResponse.json({ ok: false, error: 'bad-json' }, { status: 400 })
  }
  const action = body.action as Action
  const userId = body.user_id

  if (!action || !VALID_ACTIONS.has(action)) {
    return NextResponse.json({ ok: false, error: 'bad-action' }, { status: 400 })
  }
  if (!userId || typeof userId !== 'string') {
    return NextResponse.json({ ok: false, error: 'missing-user-id' }, { status: 400 })
  }

  // ── 1. Caller authentication + admin check ──────────────────────
  const supabase = await createClient()
  const { data: { user: caller } } = await supabase.auth.getUser()
  if (!caller) return NextResponse.json({ ok: false, error: 'unauth' }, { status: 401 })

  const { data: callerProfile } = await supabase
    .from('profiles').select('role').eq('id', caller.id).single()
  if (!callerProfile || !ADMIN_ROLES.has(String(callerProfile.role))) {
    return NextResponse.json({ ok: false, error: 'forbidden' }, { status: 403 })
  }

  // Self-action guard — admins shouldn't lock themselves out by clicking
  // "Block" on their own profile.
  if (userId === caller.id && (action === 'block' || action === 'set_password')) {
    return NextResponse.json({ ok: false, error: 'cant-target-self' }, { status: 400 })
  }

  // ── 2. Look up target user ──────────────────────────────────────
  const admin = createAdminClient()
  const { data: targetWrap, error: lookupErr } = await admin.auth.admin.getUserById(userId)
  if (lookupErr || !targetWrap?.user) {
    return NextResponse.json({ ok: false, error: 'user-not-found' }, { status: 404 })
  }
  const target = targetWrap.user
  const targetEmail = target.email
  if (!targetEmail && (action === 'send_reset' || action === 'resend_invite')) {
    return NextResponse.json({ ok: false, error: 'target-has-no-email' }, { status: 400 })
  }

  // ── 3. Dispatch ────────────────────────────────────────────────
  try {
    if (action === 'block') {
      // Ban for ~100 years. Supabase clears active sessions and refuses
      // new logins while banned_until is in the future.
      const { error } = await admin.auth.admin.updateUserById(userId, {
        ban_duration: `${100 * 365 * 24}h`,
      })
      if (error) throw error
      await admin.from('profiles').update({ is_blocked: true }).eq('id', userId)
      return NextResponse.json({ ok: true })
    }

    if (action === 'unblock') {
      const { error } = await admin.auth.admin.updateUserById(userId, {
        ban_duration: 'none',
      })
      if (error) throw error
      await admin.from('profiles').update({ is_blocked: false }).eq('id', userId)
      return NextResponse.json({ ok: true })
    }

    if (action === 'approve_email') {
      // Force-confirm without sending another email. Use this when the
      // confirmation email got blocked by their provider but you've
      // verified the user's identity through another channel.
      const { error } = await admin.auth.admin.updateUserById(userId, {
        email_confirm: true,
      })
      if (error) throw error
      return NextResponse.json({ ok: true })
    }

    if (action === 'send_reset') {
      const redirectTo = body.redirect_to
        || `${new URL(req.url).origin}/auth/reset-password`
      // generateLink with type=recovery + the configured email
      // template + Supabase SMTP (Resend) delivers the "reset your
      // password" mail. We don't ship the link in the response so it
      // can only reach the user via their inbox.
      const { error } = await admin.auth.admin.generateLink({
        type: 'recovery',
        email: targetEmail!,
        options: { redirectTo },
      })
      if (error) throw error
      return NextResponse.json({ ok: true })
    }

    if (action === 'resend_invite') {
      // We send a magic-link instead of regenerating the signup link
      // (which requires the original password). Clicking the magic
      // link logs the user in and confirms their email in one step —
      // which is exactly what "ponovo pošalji potvrdu" is meant to do.
      const redirectTo = body.redirect_to || new URL(req.url).origin
      const { error } = await admin.auth.admin.generateLink({
        type: 'magiclink',
        email: targetEmail!,
        options: { redirectTo },
      })
      if (error) throw error
      return NextResponse.json({ ok: true })
    }

    if (action === 'set_password') {
      const newPassword = body.password
      if (!newPassword || typeof newPassword !== 'string' || newPassword.length < 8) {
        return NextResponse.json({ ok: false, error: 'password-too-short' }, { status: 400 })
      }
      const { error } = await admin.auth.admin.updateUserById(userId, {
        password: newPassword,
      })
      if (error) throw error
      return NextResponse.json({ ok: true })
    }

    return NextResponse.json({ ok: false, error: 'unhandled-action' }, { status: 400 })
  } catch (e) {
    const msg = e instanceof Error ? e.message : 'admin-action-failed'
    return NextResponse.json({ ok: false, error: msg }, { status: 500 })
  }
}
