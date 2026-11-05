// Obaveštenja za aplikaciju Librum kviz: izazov na duel i novi pratilac.
// Poziva je okidač obavesti_okidac (pg_net) na INSERT u `izazovi` i `pracenja` (telo: { type, table, record }),
// vidi scripts/2026-11-05_push-obavestenja.sql. Objavljuje se sa verify_jwt=false: proverava deljenu tajnu sama.
// iOS ide direktno na APNs (ključ AuthKey p8), Android preko Firebase Cloud Messaging HTTP v1
// (servisni nalog projekta librum-ebook-c0f24, u kome je registrovan club.librum.kviz).
//
// Tajne nikad u kodu: Edge Functions → Secrets ako postoje, inače Supabase Vault preko push_tajne() (05.11, bez CLI pristupa):
//   APNS_KEY (sadržaj .p8), APNS_KEY_ID, APNS_TEAM_ID, APNS_PRODUKCIJA ("1" za App Store, inače sandbox)
//   FIREBASE_SA (ceo JSON servisnog naloga)
//   OBAVESTI_TAJNA (deljena tajna koju webhook šalje u zaglavlju x-obavesti-tajna)
import { createClient } from 'jsr:@supabase/supabase-js@2'

const BUNDLE = 'club.librum.kviz'
const baza = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)

type Poruka = { naslov: string; tekst: string; podaci: Record<string, string> }

let izVaulta: Record<string, string> | null = null
async function tajna(ime: string): Promise<string> {
  const izOkruzenja = Deno.env.get(ime)
  if (izOkruzenja) return izOkruzenja
  if (!izVaulta) {
    const { data, error } = await baza.rpc('push_tajne')
    if (error) throw new Error(`push_tajne: ${error.message}`)
    izVaulta = data as Record<string, string>
  }
  return izVaulta[ime] ?? ''
}

Deno.serve(async (zahtev) => {
  const ocekivana = await tajna('OBAVESTI_TAJNA')
  if (!ocekivana || zahtev.headers.get('x-obavesti-tajna') !== ocekivana) return new Response('zabranjeno', { status: 401 })
  const { table, record } = await zahtev.json()
  let primalac: string | null = null
  let poruka: Poruka | null = null
  if (table === 'izazovi' && record.status === 'ceka') {
    primalac = record.za
    poruka = { naslov: 'Izazov na duel', tekst: `${await ime(record.od)} te izaziva na duel. Prihvati u sandučetu.`, podaci: { vrsta: 'izazov', kod: record.kod_sobe ?? '' } }
  } else if (table === 'pracenja') {
    primalac = record.koga
    poruka = { naslov: 'Novi pratilac', tekst: `${await ime(record.ko)} te sada prati.`, podaci: { vrsta: 'pratilac', id: record.ko } }
  }
  if (!primalac || !poruka) return new Response('preskočeno')

  const { data: tokeni } = await baza.from('push_tokeni').select('token, platforma').eq('user_id', primalac)
  const ishodi = await Promise.allSettled((tokeni ?? []).map(t => t.platforma === 'ios' ? apns(t.token, poruka!) : fcm(t.token, poruka!)))
  // Uređaj koji više ne postoji (odjavljen, obrisana aplikacija) briše se, da se ne šalje uzalud.
  for (const [i, r] of ishodi.entries()) {
    if (r.status === 'fulfilled' && r.value === 'nevazeci') await baza.from('push_tokeni').delete().eq('token', tokeni![i].token)
  }
  return Response.json({ poslato: ishodi.filter(r => r.status === 'fulfilled' && r.value === 'ok').length })
})

async function ime(id: string): Promise<string> {
  const { data } = await baza.from('public_profiles').select('nickname, first_name').eq('id', id).maybeSingle()
  return data?.nickname ?? data?.first_name ?? 'Igrač'
}

// ── APNs ────────────────────────────────────────────────────────────────────

let apnsJwt: { token: string; do: number } | null = null

async function apns(token: string, p: Poruka): Promise<'ok' | 'nevazeci' | 'greska'> {
  const host = (await tajna('APNS_PRODUKCIJA')) === '1' ? 'api.push.apple.com' : 'api.sandbox.push.apple.com'
  const odgovor = await fetch(`https://${host}/3/device/${token}`, {
    method: 'POST',
    headers: { authorization: `bearer ${await apnsToken()}`, 'apns-topic': BUNDLE, 'apns-push-type': 'alert', 'content-type': 'application/json' },
    body: JSON.stringify({ aps: { alert: { title: p.naslov, body: p.tekst }, sound: 'default' }, ...p.podaci }),
  })
  if (odgovor.ok) return 'ok'
  return odgovor.status === 410 || odgovor.status === 400 ? 'nevazeci' : 'greska'
}

// APNs token važi sat vremena; obnavlja se posle 50 minuta.
async function apnsToken(): Promise<string> {
  if (apnsJwt && apnsJwt.do > Date.now()) return apnsJwt.token
  const kljuc = await crypto.subtle.importKey('pkcs8', pemUBajtove(await tajna('APNS_KEY')), { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign'])
  const token = await jwt({ alg: 'ES256', kid: await tajna('APNS_KEY_ID') }, { iss: await tajna('APNS_TEAM_ID'), iat: sekunde() }, kljuc, { name: 'ECDSA', hash: 'SHA-256' })
  apnsJwt = { token, do: Date.now() + 50 * 60_000 }
  return token
}

// ── FCM HTTP v1 ─────────────────────────────────────────────────────────────

let fcmPristup: { token: string; do: number } | null = null

async function fcm(token: string, p: Poruka): Promise<'ok' | 'nevazeci' | 'greska'> {
  const sa = JSON.parse(await tajna('FIREBASE_SA'))
  const odgovor = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
    method: 'POST',
    headers: { authorization: `Bearer ${await fcmToken(sa)}`, 'content-type': 'application/json' },
    body: JSON.stringify({ message: { token, notification: { title: p.naslov, body: p.tekst }, data: p.podaci, android: { priority: 'high' } } }),
  })
  if (odgovor.ok) return 'ok'
  const telo = await odgovor.text()
  return odgovor.status === 404 || telo.includes('UNREGISTERED') ? 'nevazeci' : 'greska'
}

async function fcmToken(sa: { client_email: string; private_key: string; token_uri: string }): Promise<string> {
  if (fcmPristup && fcmPristup.do > Date.now()) return fcmPristup.token
  const kljuc = await crypto.subtle.importKey('pkcs8', pemUBajtove(sa.private_key), { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign'])
  const sad = sekunde()
  const potpisan = await jwt({ alg: 'RS256', typ: 'JWT' },
    { iss: sa.client_email, scope: 'https://www.googleapis.com/auth/firebase.messaging', aud: sa.token_uri, iat: sad, exp: sad + 3600 }, kljuc, { name: 'RSASSA-PKCS1-v1_5' })
  const r = await fetch(sa.token_uri, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: potpisan }),
  })
  const { access_token } = await r.json()
  fcmPristup = { token: access_token, do: Date.now() + 50 * 60_000 }
  return access_token
}

// ── Pomoćno ─────────────────────────────────────────────────────────────────

const sekunde = () => Math.floor(Date.now() / 1000)
const b64url = (b: Uint8Array) => btoa(String.fromCharCode(...b)).replace(/=+$/, '').replace(/\+/g, '-').replace(/\//g, '_')
const tekstUB64 = (o: unknown) => b64url(new TextEncoder().encode(JSON.stringify(o)))

function pemUBajtove(pem: string): ArrayBuffer {
  const telo = pem.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '')
  return Uint8Array.from(atob(telo), c => c.charCodeAt(0)).buffer
}

async function jwt(zaglavlje: object, sadrzaj: object, kljuc: CryptoKey, algoritam: AlgorithmIdentifier | EcdsaParams): Promise<string> {
  const ulaz = `${tekstUB64(zaglavlje)}.${tekstUB64(sadrzaj)}`
  const potpis = new Uint8Array(await crypto.subtle.sign(algoritam, kljuc, new TextEncoder().encode(ulaz)))
  return `${ulaz}.${b64url(potpis)}`
}
