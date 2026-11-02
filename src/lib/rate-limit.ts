// Minimal in-memory rate limiter for public POST routes (spam / DB-bloat guard).
//
// NOTE: state lives in the module scope of a single server instance. On
// multi-instance or serverless deployments each instance keeps its own
// window, so limits are per-instance, not global. For strict global limits
// move this to Redis (e.g. Upstash) keyed the same way.

type Bucket = { count: number; resetAt: number }

const buckets = new Map<string, Bucket>()

// Occasionally sweep expired buckets so the Map doesn't grow unbounded.
let lastSweep = 0
function sweep(now: number) {
  if (now - lastSweep < 60_000) return
  lastSweep = now
  for (const [key, b] of buckets) {
    if (b.resetAt <= now) buckets.delete(key)
  }
}

export type RateLimitResult = { ok: true } | { ok: false; retryAfter: number }

// Fixed-window limiter: allows `limit` hits per `windowMs` for a given key.
export function rateLimit(key: string, limit: number, windowMs: number): RateLimitResult {
  const now = Date.now()
  sweep(now)
  const bucket = buckets.get(key)
  if (!bucket || bucket.resetAt <= now) {
    buckets.set(key, { count: 1, resetAt: now + windowMs })
    return { ok: true }
  }
  if (bucket.count >= limit) {
    return { ok: false, retryAfter: Math.ceil((bucket.resetAt - now) / 1000) }
  }
  bucket.count++
  return { ok: true }
}

// Best-effort client IP, used for rate-limit keys on anonymous routes.
export function clientIp(req: Request): string {
  const xff = req.headers.get('x-forwarded-for')
  if (xff) return xff.split(',')[0].trim()
  return req.headers.get('x-real-ip') ?? 'unknown'
}
