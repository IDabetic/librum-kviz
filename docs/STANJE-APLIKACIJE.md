# Librum kviz aplikacija: šta postoji i šta fali

Ažurirano: 05.11.2026. · verzija 11 (ADMIN ZATVOREN: ispravljena rupa gde je svaki korisnik sebi mogao da upiše role=super_admin, admin /majmun i admin funkcije u bazi traže dvostruku verifikaciju (TOTP, /majmun/zastita), Podešavanja: mejl, lozinka uz trenutnu, uređaji; push radi: funkcija `obavesti` objavljena, ključevi u Supabase Vault-u, okidači na izazovi/pracenja, Android 1.0.3 sa Firebase Messaging; iOS 1.0 u App Store-u; nadzor varanja: /majmun/sumnjivo, Nadzor na profilu igrača, Karijera meri pravo trajanje runde, IP 90 dana; admin /majmun: Aktivnost svih igara, Karijera, pitanja struka, Osvajanje, Padovi; Android 1.0.2 ispravka pada u meniju objave; Android usklađen sa iOS-om: Karijera, Podešavanja, uređivanje profila, blokirani, tema, podsetnik, bedževi, statistika, fokus profila; Karijera: šef po firmi, ometanja, mirni režim, pitanja u firmi; Karijera na iOS-u; ranije: iOS i Android izjednačeni; 75.702 pitanja; bot, sat poteza, pitanja bez ponavljanja) · grana `redizajn-quizpop`

Pregled svakog toka u iOS aplikaciji (Android prati isti spisak), poređen sa QuizPop kitom
i sa vebom kviz.librum.club. Kolona „Gradi se” je redosled rada.

## 1. Šta kit ima, a šta mi

Kit (Figma, oko 150 ekrana) pokriva: uvod (dobrodošlica, interesovanja, drugar, dnevni cilj,
obaveštenja, kako se igra), nalog (prijava, registracija, potvrda mejla, zaboravljena i nova
lozinka), kviz (početna, istraži, kategorija, detalji, spremi se, pitanje u 8 varijanti,
odgovor, rezultat, pregled odgovora, rang lista), borbu (lobi, traženje rivala, rival nađen,
pitanje, ishod runde, pobeda, izazov prijatelju, privatna soba, poziv linkom) i profil
(statistika, bedževi, prodavnica, sanduče, podešavanja, izmena profila).

**Kit nema dodatnih igara.** Sve što ima već je u aplikaciji. Mi imamo više: Osvajanje sveta,
PRO, Book, Slikari, Brzi kviz, Vešanje, Duel, teme. Prodavnicu i novčiće smo namerno izbacili.

## 2. Tokovi i stanje

| Tok | Stanje | Šta fali |
|---|---|---|
| Uvod (6 ekrana) | gotovo | — |
| Nalog: prijava, registracija, potvrda koda, zaboravljena lozinka, brisanje naloga | gotovo | prijava preko Apple/Google (nije obavezna jer nemamo druge društvene prijave) |
| Početna, teme, kategorije | gotovo | Dnevni izazov (isti 10 pitanja za sve, jedna rang lista dana) |
| Klasičan kviz, Slikari, PRO, Book, Brzi, Vešanje | gotovo, 4 pomoći svuda | **prijava netačnog pitanja** iz igre (veb je ima) |
| Vešanje | vešala + tastatura telefona | 6 reči sa Q/W/X/Y u bazi (preskaču se; urednik da ih ispravi u /majmun) |
| Duel | lobi, brzi meč, privatna soba kodom, izazov sa profila | **igra traži da rival bude onlajn u istom trenutku**; sa malo igrača „Nema rivala”. Fali **izazov bez čekanja**: ja odigram 10 pitanja, rival odigra kad stigne (do 24 h), pa ishod |
| Osvajanje | svet ili kontinent, sobe, pravi igrači preko servera | nastavak partije posle zatvaranja aplikacije; napuštanje sobe tokom partije |
| Karijera (04.11, iOS i Android 05.11) | pozicije, probni rad uz šefa, svoj office, botovi, berza, NPC firme, rekord, duel za firmu, CV, rang, šef i pitanja po firmi, ometanja, mirni režim ([KARIJERA-PRAVILA.md](KARIJERA-PRAVILA.md)) | obaveštenja (izazov, otkaz bota); duel za unapređenje i „zajedno u officu”; slikari/vešanje u firmi |
| Igrači (društvo) | objave, srca, komentari, blokada, prijava, poruke | **spisak blokiranih** (odblokiraj), **pravila zajednice** pre prve objave (Apple 1.2), obaveštenja o komentaru i poruci, broj nepročitanih poruka na kartici |
| Profil | kao Instagram, Uredi profil, Dodaj pitanje/reč | — |
| Rang liste | po igri, dan/nedelja/mesec/godina | **samo igrači koje pratim** (kit: Friends) |
| Sanduče | lokalne poruke (bedževi, nivo) | **obaveštenja sa servera**: izazov, novi pratilac, komentar, odgovor, poruka |
| Pozivnice | — | **link** kviz.librum.club/duel/KOD i /igrac/ID otvara aplikaciju (deljenje izazova van aplikacije) |
| Podešavanja | zvuk, podsetnik, tema, nalog, pravno | vibracija uključi/isključi; „Pošalji pitanje” vodi na veb umesto na ekran u aplikaciji |
| Admin /majmun | pitanja, reči, predlozi | **prijave objava i komentara** (moderacija), opcije aplikacije (verzija, poruka svima) |
| Obaveštenja (push) | radi 05.11: izazov na duel i novi pratilac (APNs + FCM; okidač pg_net → funkcija `obavesti`, ključevi u Vault-u, `scripts/2026-11-05_push-obavestenja.sql`); proba na Android emulatoru prošla | poruke u razgovoru i poziv u sobu kao push (sada samo dok je app otvorena) |
| Android | Osvajanje v3; Igrači (objave, komentari u granama, poruke, pravila, blokada, prijava), profil igrača i pretraga, moj profil kao IG + Dodaj pitanje/reč, Vešanje (vešala, tastatura telefona), 4 pomoći u Vešanju/Brzom/Duelu/Dnevnom, Dnevni izazov | Slikari, kvizovi po temi, duel bez čekanja, rang „Koje pratim”, Sanduče sa servera, linkovi `librumkviz://`, Osvajanje preko servera |

## 2a. Urađeno 03.11 (druga polovina dana)

- **Android 05.11 (usklađen):** Karijera ceo tok (šef, ometanja, slobodni dani, pitanja struke), Podešavanja (nalog, zvuk, dnevni podsetnik 19:30 lokalno, izgled Auto/Svetla/Tamna, Karijera, podrška, odjava, brisanje naloga), Uredi profil (avatar, drugar, nadimak, ime, grad, O meni), Blokirani, bedževi i statistika, fokus profila (Osvajač + Karijera + krugovi), rang tabovi, Dodaj pitanje sa nacrtom. Push sa servera ugrađen u 1.0.3 (Firebase Messaging, projekat librum-ebook-c0f24). Osvajanje radi druga sesija.
- **Android sustigao iOS:** rang lista (sve igre, „Koje pratim”), Sanduče i brojači, duel bez čekanja, Slikari i kvizovi po temi, linkovi `librumkviz://`, Osvajanje preko servera (isti JSON kao iOS, test formata).
- **Osvajanje (obe platforme):**
  - Pojačanja = max(3, države/2) + bonus kontinenta.
  - Pre prvog kruga igrač sam bira 6 država i raspoređuje 15 vojski.
  - Zum drži centar ekrana i ne beži pri dodiru.
  - Mozak bota opisan u `docs/OSVAJANJE-BOT.md`.
  - 30 s za potez; 3 propusta zaredom = ispadanje; ekran ne gasi.
- **Pitanja:**
  - Uvezeno 58.899 (kviz-srpski.xlsx) + 10.033 (srbija-kviz.xlsx), alat `alati/uvoz-pitanja.py`, izveštaji u `docs/uvoz/`.
  - 51.284 otvorena pitanja (bez netačnih) nije uvezeno.
  - Igraču se pitanja ne ponavljaju 7 dana (`scripts/2026-11-03_vidjena-pitanja.sql`).
  - Redosled odgovora se meša svakog ponedeljka u 04:00 (pg_cron) i ručno u /majmun/podesavanja.
- **Admin:** /majmun/zajednica (moderacija objava i komentara).
- **Admin od 05.11 (migracije `karijera_40`–`karijera_43`, `scripts/2026-11-05_admin-aktivnost-karijera.sql`):**
  - /majmun/aktivnost: sve partije svih igara (aplikacija `rezultati_igara`, Karijera `karijera_runde`, stare veb igre), filter po igri i igraču, keyset „Starije”; sa profila igrača link „Sva aktivnost”.
  - /majmun/karijera: firme (vlasnik ili bot, nivo, kasa, zaposleni) sa moderacijom imena („Skini ime” = isto kao tri prijave, „Odbaci prijave”) i igrači Karijere.
  - /majmun/karijera/pitanja: pitanja struka, pretraga (trigram), filter po struci, izmena i zamena (tačno 4 odgovora); čuvanje rešava prijave igrača.
  - /majmun/osvajanje: sobe za igru preko mreže; /majmun/padovi: izveštaji o padu aplikacije sa stekom.
  - Kontrolna tabla: partije u aplikaciji, Karijera, Osvajanje, padovi (RPC `admin_pregled`).
  - Prijava pitanja iz aplikacije (`prijavi_pitanje`) sada prepoznaje i Kafanski kviz i pitanja struka.
- **Nadzor varanja od 05.11 (`scripts/2026-11-05_nadzor-varanja.sql`, migracije `karijera_47`–`karijera_50`, bez izmena aplikacija):**
  - Karijera: `karijera_runda_pitanja` upisuje izdata pitanja (`karijera_izdate`), `karijera_zavrsi_rundu` meri pravo trajanje; runda za manje od 15 s ostaje bez dodatka za brzinu; `karijera_runde.trajanje_ms/prosek_ms/sumnja`.
  - Mreža: okidači na `rezultati_igara`, `karijera_runde`, `osvajanje_potezi`, `question_answer_log` upisuju IP i user-agent u `igraci_mreza` (90 dana, briše se usput).
  - /majmun/sumnjivo (`admin_sumnjivo`): Karijera (server), nemoguća brzina, rezultat iskače, isti par u duelima, isti IP, međusobno praćenje novih naloga; jačina 3/2/1.
  - Profil igrača, deo Nadzor (`admin_igrac_detalji`): sumnje, vreme i tačnost po igri, Karijera, prati/pratioci, blokade, mreža i povezani nalozi.
  - Politika privatnosti v6 (veb) navodi IP i uređaj za zaštitu od varanja i rok 90 dana.
  - OSTAJE (traži izmenu aplikacija, posle odobrenja): `karijera_runda_pitanja` vraća tačan odgovor telefonu; vreme po odgovoru (`ms`) šalje telefon. App Privacy u App Store Connect dopuniti (IP adresa) sa sledećom verzijom.

## 3. Redosled gradnje

Urađeno 03.11 na iOS-u (commit 36d5859 do 1a6f7fa): prijava pitanja, pravila zajednice i blokirani,
Sanduče sa servera i brojači, rang lista „Koje pratim”, duel bez čekanja, linkovi `librumkviz://`,
„Pošalji pitanje” u aplikaciji, Dnevni izazov. Ostaje: vibracija (prekidač), Osvajanje nastavak,
Android, admin, Firebase/App Store. Linkovi `https://kviz.librum.club/...` (universal links) traže
apple-app-site-association na vebu, ide sa sledećom objavom sajta.


1. Prijava netačnog pitanja iz igre.
2. Pravila zajednice pre prve objave i spisak blokiranih (uslov za App Store).
3. Obaveštenja sa servera u Sandučetu + broj nepročitanih poruka na kartici Igrači.
4. Rang lista „Koje pratim”.
5. Duel bez čekanja (izazov koji rival igra kasnije).
6. Linkovi koji otvaraju aplikaciju (duel, profil).
7. Podešavanja: vibracija, „Pošalji pitanje” u aplikaciji.
8. Dnevni izazov.
9. Osvajanje: nastavak partije i izlazak iz sobe.
10. Android: sve iznad.
11. Admin: moderacija prijava i opcije aplikacije.
12. Firebase, APNs, App Store Connect.
