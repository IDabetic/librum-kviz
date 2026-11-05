# Bezbednosna i pravna provera Librum kviza

Ažurirano: 05.11.2026. · verzija 1

## Kritično (popravljeno i na produkciji 05.11)

| Nalaz | Uticaj | Ispravka |
|---|---|---|
| `admin_delete_users` bez prijave: uloga je NULL, a `NULL <> 'super_admin'` nije tačno, pa je brisanje prolazilo | svako sa javnim ključem je mogao da obriše naloge svih Librum aplikacija u ovoj bazi | `auth.uid() is null or caller_role is distinct from 'super_admin'`, oduzet `anon` |
| `request_password_reset` prima heš tokena od pozivaoca, a `reset_password_with_token` prihvata taj heš | preuzimanje bilo kog naloga uz poznat mejl | obe funkcije samo `service_role`; `src/lib/password-reset.ts` zove ih preko `createAdminClient`; najviše 3 mejla za reset po adresi u 15 min |
| Next.js 16.3.8 na produkciji (zakrpa 16.4.x sa `main` nije preneta u granu redizajna) | izvršavanje koda bez prijave preko optimizacije slika (SVG) | next i eslint-config-next 16.4.5, `npm audit fix` (zod, source-map-js); `npm audit --omit=dev` = 0 |

## Srednje (popravljeno)

- Unutrašnje Karijera funkcije (prenos firme, rešavanje duela, novi asistent, upis u CV) bile su pozive spolja → zaključane; 32 funkcije koje aplikacija zove traže prijavu; nijedna Karijera funkcija bez prijave. `search_path` postavljen svima.
- `question_reports`: svaki prijavljeni je čitao sve prijave → samo moderatori.
- `question_submissions`: predlog se mogao upisati u tuđe ime (bedž autora) → `submitted_by` prazno ili svoj ID.
- `verify_unlock_code` (niko ne koristi) i funkcije okidača više nisu RPC.

Migracija `bezbednost_2026_11_05` u bazi htnfatughrtmbgtekxfs.

## Ostalo (poznato, nije menjano)

- Zaštita od procurelih lozinki (HaveIBeenPwned) je isključena: na Supabase Free planu nije dostupna.
- Baza je zajednička sa drugim Librum aplikacijama (eBook čitači, tenants): njihove funkcije i tabele nisu dirane.
- Android sesija je u privatnim podešavanjima aplikacije (bez dodatnog šifrovanja, bekap isključen); iOS je u Keychainu (samo ovaj uređaj).
- Pitanja stižu u aplikaciju sa tačnim odgovorom (server ipak sam računa tačnost); svesno, „blaži start” protiv varanja.
- `pg_trgm` u šemi public, pogled `public_accepted_submissions` je SECURITY DEFINER namerno (pokazuje doprinos bez rešenja).
- Nove Karijera funkcije: Postgres po difoltu daje EXECUTE svima → svaka nova mora `revoke … from public, anon`.

## Objava sajta

Lokalno stablo je deljeno sa drugim sesijama. Objava ide iz kopije produkcije (SHA1 svakog fajla iz Vercel liste = lokalni fajl), uz samo izmene ove provere; nedovršeni Slikari druge sesije nisu objavljeni.

## Pravno

- Politika privatnosti v5: rukovalac Go Simple, Ivan Dabetić (MB, PIB, adresa), Karijera i pol, pravni osnov, 15 godina po ZZPL čl. 16.
- Uslovi v4: pružalac imenovan, Karijera (virtuelne vrednosti bez novčane vrednosti i bez naknade, šef kao parodija, efekti i mirni režim, imena firmi), ograničenje odgovornosti uz izuzetak namere/krajnje nepažnje i prava potrošača, nagrade samo uz posebna pravila.
- Licence i izvori (nov): Freepik, Wikimedia Commons, Envato/Freepik muzika, fontovi SIL OFL 1.1.
- Na sajtu: /politika-privatnosti, /uslovi-koriscenja, /licence-i-izvori (podnožje i sitemap); u aplikaciji Podešavanja → Podrška (iOS i Android); podrška ujednačena na info@librum.club.
- PrivacyInfo: dodat Other Data Types (pol).
