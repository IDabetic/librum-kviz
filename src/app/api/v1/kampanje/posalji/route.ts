import { NextResponse } from 'next/server'
import { timingSafeEqual } from 'crypto'
import { z } from 'zod'
import { createAdminClient } from '@/lib/supabase/admin'
import {
  KAMPANJA_APLIKACIJA, NASLOV_APLIKACIJA, adresaOdjave, adresaOdjaveJednimKlikom, mejlAplikacija,
} from '@/lib/mejlovi/poziv-aplikacija'

// Slanje kampanje u turama (Resend batch API prima najviše 100 mejlova po pozivu).
// Poziva je samo vlasnik sistema sa tajnom KAMPANJA_TAJNA iz Vercel env-a, nikad pregledač.
const POSILJALAC = 'Librum kviz <noreply@librum.club>'
const ODGOVOR_NA = 'info@librum.club'

const Telo = z.object({
  broj: z.number().int().min(1).max(100).default(50),
  probaKorisnik: z.string().uuid().optional(),
})

type Primalac = { user_id: string; email: string; nadimak: string | null; token: string }

function tajnaJeIspravna(dobijena: string | null): boolean {
  const ocekivana = process.env.KAMPANJA_TAJNA
  if (!ocekivana || !dobijena) return false
  const a = Buffer.from(dobijena), b = Buffer.from(ocekivana)
  return a.length === b.length && timingSafeEqual(a, b)
}

function mejlZa(p: Primalac) {
  const { html, tekst } = mejlAplikacija(p.nadimak, p.token)
  return {
    from: POSILJALAC,
    to: [p.email],
    reply_to: ODGOVOR_NA,
    subject: NASLOV_APLIKACIJA,
    html,
    text: tekst,
    headers: {
      'List-Unsubscribe': `<${adresaOdjaveJednimKlikom(p.token)}>, <${adresaOdjave(p.token)}>`,
      'List-Unsubscribe-Post': 'List-Unsubscribe=One-Click',
    },
  }
}

export async function POST(zahtev: Request) {
  if (!tajnaJeIspravna(zahtev.headers.get('x-kampanja-tajna'))) {
    return NextResponse.json({ error: { message: 'zabranjeno' } }, { status: 401 })
  }
  const resend = process.env.RESEND_API_KEY
  if (!resend) return NextResponse.json({ error: { message: 'RESEND_API_KEY nije podešen' } }, { status: 500 })

  const parsirano = Telo.safeParse(await zahtev.json().catch(() => ({})))
  if (!parsirano.success) {
    return NextResponse.json({ error: { message: 'neispravan zahtev', polja: parsirano.error.issues } }, { status: 422 })
  }
  const { broj, probaKorisnik } = parsirano.data
  const baza = createAdminClient()

  let primaoci: Primalac[]
  if (probaKorisnik) {
    // Proba: jedan mejl jednom korisniku (vlasniku), označen kao poslat da ga tura ne pošalje dvaput.
    const { data: red } = await baza.from('mejl_kampanje_primaoci').select('user_id, token')
      .eq('kampanja', KAMPANJA_APLIKACIJA).eq('user_id', probaKorisnik).maybeSingle()
    const { data: korisnik } = await baza.auth.admin.getUserById(probaKorisnik)
    const { data: profil } = await baza.from('profiles').select('nickname, first_name').eq('id', probaKorisnik).maybeSingle()
    if (!red || !korisnik?.user?.email) return NextResponse.json({ error: { message: 'primalac nije u kampanji' } }, { status: 404 })
    primaoci = [{ user_id: red.user_id, email: korisnik.user.email, nadimak: profil?.nickname || profil?.first_name || null, token: red.token }]
  } else {
    const { data, error } = await baza.rpc('mejl_kampanja_tura', { p_kampanja: KAMPANJA_APLIKACIJA, p_broj: broj })
    if (error) return NextResponse.json({ error: { message: error.message } }, { status: 500 })
    primaoci = (data ?? []) as Primalac[]
  }
  if (primaoci.length === 0) return NextResponse.json({ data: { poslato: 0, ostalo: 0 } })

  const odgovor = await fetch('https://api.resend.com/emails/batch', {
    method: 'POST',
    headers: { Authorization: `Bearer ${resend}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(primaoci.map(mejlZa)),
  })
  const telo = await odgovor.json().catch(() => null) as { data?: { id: string }[]; message?: string } | null
  const sad = new Date().toISOString()

  if (!odgovor.ok || !telo?.data) {
    const poruka = telo?.message ?? `Resend ${odgovor.status}`
    await baza.from('mejl_kampanje_primaoci').update({ greska: poruka })
      .eq('kampanja', KAMPANJA_APLIKACIJA).in('user_id', primaoci.map(p => p.user_id))
    return NextResponse.json({ error: { message: poruka } }, { status: 502 })
  }

  // Resend vraća id-jeve istim redom kao poslate mejlove.
  await Promise.all(primaoci.map((p, i) => baza.from('mejl_kampanje_primaoci')
    .update({ poslato: sad, resend_id: telo.data![i]?.id ?? null, greska: null })
    .eq('kampanja', KAMPANJA_APLIKACIJA).eq('user_id', p.user_id)))

  const { count } = await baza.from('mejl_kampanje_primaoci').select('user_id', { count: 'exact', head: true })
    .eq('kampanja', KAMPANJA_APLIKACIJA).is('poslato', null)
  return NextResponse.json({ data: { poslato: primaoci.length, ostalo: count ?? null } })
}
