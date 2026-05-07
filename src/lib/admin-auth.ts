/**
 * Admin unlock token (the second factor for /majmun).
 *
 * The user-facing flow:
 *   1. Visit /majmun/prijava
 *   2. Enter email + password (Supabase auth) + admin code
 *   3. If all match → server signs a token bound to the user_id
 *   4. Token is set as httpOnly cookie `majmun_unlock` with 8h expiry
 *   5. /majmun/(panel)/layout.tsx checks token + role on every request
 *
 * Token format: base64(payload).base64(hmac)
 *   payload = JSON({ uid: <user_id>, exp: <unix_ms> })
 *   hmac = HMAC-SHA256(payload, ADMIN_SECRET)
 */
import crypto from 'crypto'

const SECRET = process.env.ADMIN_SECRET || 'fallback-dev-secret-not-for-prod'
const TTL_MS = 8 * 60 * 60 * 1000 // 8 hours

function hmac(payload: string): string {
  return crypto.createHmac('sha256', SECRET).update(payload).digest('base64url')
}

export function signUnlockToken(userId: string): string {
  const payload = JSON.stringify({ uid: userId, exp: Date.now() + TTL_MS })
  const b64 = Buffer.from(payload).toString('base64url')
  const sig = hmac(b64)
  return `${b64}.${sig}`
}

export function verifyUnlockToken(token: string, expectedUserId: string): boolean {
  const parts = token.split('.')
  if (parts.length !== 2) return false
  const [b64, sig] = parts
  if (hmac(b64) !== sig) return false
  try {
    const payload = JSON.parse(Buffer.from(b64, 'base64url').toString('utf8'))
    if (payload.uid !== expectedUserId) return false
    if (typeof payload.exp !== 'number' || payload.exp < Date.now()) return false
    return true
  } catch {
    return false
  }
}

export function getAdminUnlockCode(): string {
  return process.env.ADMIN_UNLOCK_CODE || 'majmun'
}
