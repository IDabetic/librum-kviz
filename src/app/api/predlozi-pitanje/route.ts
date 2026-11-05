import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { rateLimit, clientIp } from '@/lib/rate-limit'

// Upper bounds on submitted text — a question/answer longer than this is spam,
// not a genuine suggestion. Guards the DB and the notification email.
const MAX_QUESTION = 1000
const MAX_ANSWER = 500

export async function POST(req: NextRequest) {
  // Anonymous submissions are allowed, so key the limiter by IP.
  const limit = rateLimit(`predlozi-pitanje:${clientIp(req)}`, 5, 60_000)
  if (!limit.ok) {
    return NextResponse.json(
      { error: 'Previše zahteva, pokušajte ponovo za koji minut' },
      { status: 429, headers: { 'Retry-After': String(limit.retryAfter) } },
    )
  }

  const { question, answer } = await req.json()

  if (!question?.trim() || !answer?.trim()) {
    return NextResponse.json({ error: 'Nedostaju podaci' }, { status: 400 })
  }
  if (question.trim().length > MAX_QUESTION || answer.trim().length > MAX_ANSWER) {
    return NextResponse.json({ error: 'Predlog je predugačak' }, { status: 400 })
  }

  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  // Save to DB (works always)
  await supabase.from('question_submissions').insert({
    question_text: question.trim(),
    correct_answer: answer.trim(),
    submitted_by: user?.id ?? null,
    submitter_email: user ? undefined : null,
  })

  // Send email via Resend if API key is configured
  const resendKey = process.env.RESEND_API_KEY
  if (resendKey) {
    const profile = user
      ? await supabase.from('profiles').select('first_name, last_name').eq('id', user.id).single()
      : null
    const senderName = profile?.data
      ? `${profile.data.first_name} ${profile.data.last_name}`
      : 'Anonimni korisnik'

    await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${resendKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: 'Librum Kviz <noreply@librum.club>',
        to: 'info@librum.club',
        subject: '💡 Novo predloženo pitanje za kviz',
        html: `
          <h2>Novo predloženo pitanje</h2>
          <p><strong>Od:</strong> ${senderName}</p>
          <hr/>
          <p><strong>Pitanje:</strong><br/>${question.trim()}</p>
          <p><strong>Tačan odgovor:</strong><br/>${answer.trim()}</p>
        `,
      }),
    }).catch(() => {
      // Email failure doesn't fail the request — DB save succeeded
    })
  }

  return NextResponse.json({ ok: true })
}
