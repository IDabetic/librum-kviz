import { test } from 'node:test'
import assert from 'node:assert/strict'
import { mejlAplikacija, adresaOdjave } from '../src/lib/mejlovi/poziv-aplikacija.ts'

test('nadimak se čisti pre ubacivanja u HTML mejla', () => {
  const { html } = mejlAplikacija('<img src=x onerror=alert(1)>', '11111111-1111-1111-1111-111111111111')
  assert.ok(!html.includes('<img src=x'))
  assert.ok(html.includes('&lt;img src=x onerror=alert(1)&gt;'))
})

test('mejl bez nadimka i sa linkom za odjavu', () => {
  const token = '22222222-2222-2222-2222-222222222222'
  const { html, tekst } = mejlAplikacija(null, token)
  assert.ok(html.includes('Zdravo,'))
  assert.ok(html.includes(adresaOdjave(token)))
  assert.ok(tekst.includes(adresaOdjave(token)))
})
