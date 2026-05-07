'use server'

import { createAdminClient } from '@/lib/supabase/admin'

type Result = { ok: true } | { ok: false; error: string }

const FROM = 'Librum Kviz <noreply@librum.club>'
const SUPPORT = 'info@librum.club'

function emailHtml(resetUrl: string): string {
  return `<!DOCTYPE html>
<html>
<body style="margin:0; padding:0; background:#FAFAFA;">
<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 32px 24px; color: #343434;">
  <div style="text-align:center; margin-bottom: 32px;">
    <span style="font-size: 24px; font-weight: 900; letter-spacing: -1px;">Librum<span style="color:#609DED;">.</span></span>
  </div>
  <h1 style="font-size: 26px; font-weight: 900; letter-spacing: -1px; margin: 0 0 12px;">Resetuj lozinku</h1>
  <p style="font-size: 15px; color: #9C9C9C; line-height: 1.55; margin: 0 0 28px;">
    Primili smo zahtev da resetuješ lozinku za nalog na Librum Kvizu. Klikni na dugme da postaviš novu.
  </p>
  <p style="text-align:center; margin: 0 0 24px;">
    <a href="${resetUrl}" style="display:inline-block; background:#609DED; color:white; font-weight:600; font-size:15px; padding:14px 32px; border-radius:999px; text-decoration:none;">
      Postavi novu lozinku
    </a>
  </p>
  <p style="font-size: 13px; color: #9C9C9C; line-height: 1.5; margin: 0 0 8px;">
    Link važi 1 sat. Ako nisi tražio reset, slobodno ignoriši ovaj mejl — niko ne može da pristupi tvom nalogu bez ovog linka.
  </p>
  <p style="font-size: 12px; color: #9C9C9C; word-break: break-all; margin: 16px 0 0;">
    Ako dugme ne radi, otvori ovaj URL ručno:<br/>
    <a href="${resetUrl}" style="color:#609DED;">${resetUrl}</a>
  </p>
  <hr style="border:none; border-top:1px solid #F2F2F2; margin: 32px 0 16px;" />
  <p style="font-size: 11px; color: #9C9C9C;">
    Librum Kviz · <a href="https://kviz.librum.club" style="color:#9C9C9C;">kviz.librum.club</a> · ${SUPPORT}
  </p>
</div>
</body></html>`
}

export async function sendCustomPasswordResetEmail(rawEmail: string): Promise<Result> {
  const email = rawEmail.trim().toLowerCase()
  if (!email) return { ok: false, error: 'Upiši email.' }

  let resetUrl: string
  try {
    const admin = createAdminClient()
    const { data, error } = await admin.auth.admin.generateLink({
      type: 'recovery',
      email,
      options: { redirectTo: 'https://kviz.librum.club/auth/nova-lozinka' },
    })
    if (error || !data?.properties?.action_link) {
      return { ok: true } // be silent — don't reveal whether email exists
    }
    resetUrl = data.properties.action_link
  } catch {
    return { ok: false, error: 'Servis privremeno nedostupan. Pokušaj ponovo kasnije.' }
  }

  const resendKey = process.env.RESEND_API_KEY
  if (!resendKey) {
    return { ok: false, error: 'Email servis nije konfigurisan.' }
  }

  try {
    const r = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${resendKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: FROM,
        to: email,
        subject: 'Resetuj lozinku — Librum Kviz',
        html: emailHtml(resetUrl),
      }),
    })
    if (!r.ok) {
      const text = await r.text()
      console.error('Resend error:', r.status, text)
      return { ok: false, error: 'Slanje emaila nije uspelo.' }
    }
  } catch (e) {
    console.error('Resend fetch error:', e)
    return { ok: false, error: 'Slanje emaila nije uspelo.' }
  }

  return { ok: true }
}
