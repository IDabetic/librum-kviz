import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'

export async function POST(req: NextRequest) {
  const { question, answer } = await req.json()

  if (!question?.trim() || !answer?.trim()) {
    return NextResponse.json({ error: 'Nedostaju podaci' }, { status: 400 })
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
