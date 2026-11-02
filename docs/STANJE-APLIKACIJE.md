# Librum kviz aplikacija: šta postoji i šta fali

Ažurirano: 03.11.2026. · verzija 2 (urađeno na iOS-u: tačke 1–8 iz redosleda) · grana `redizajn-quizpop`

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
| Igrači (društvo) | objave, srca, komentari, blokada, prijava, poruke | **spisak blokiranih** (odblokiraj), **pravila zajednice** pre prve objave (Apple 1.2), obaveštenja o komentaru i poruci, broj nepročitanih poruka na kartici |
| Profil | kao Instagram, Uredi profil, Dodaj pitanje/reč | — |
| Rang liste | po igri, dan/nedelja/mesec/godina | **samo igrači koje pratim** (kit: Friends) |
| Sanduče | lokalne poruke (bedževi, nivo) | **obaveštenja sa servera**: izazov, novi pratilac, komentar, odgovor, poruka |
| Pozivnice | — | **link** kviz.librum.club/duel/KOD i /igrac/ID otvara aplikaciju (deljenje izazova van aplikacije) |
| Podešavanja | zvuk, podsetnik, tema, nalog, pravno | vibracija uključi/isključi; „Pošalji pitanje” vodi na veb umesto na ekran u aplikaciji |
| Admin /majmun | pitanja, reči, predlozi | **prijave objava i komentara** (moderacija), opcije aplikacije (verzija, poruka svima) |
| Obaveštenja (push) | kod za APNs/FCM napisan | Firebase/APNs ključevi i objava funkcije `obavesti` |
| Android | Osvajanje v3, stare igre | sve ostalo iz ove tabele |

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
