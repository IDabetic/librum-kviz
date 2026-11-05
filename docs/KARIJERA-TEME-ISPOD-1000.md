# Karijera: teme struke ispod 1.000 pitanja (05.11.2026)

## Rešeno 05.11 (vlasnik: „Spoji, pa dopiši”)

- Uže teme su spojene u šire (`karijera_teme_spoj`, 25 širih tema), oznaka šire teme je dodata na kraj `tags`
  (prva oznaka, po kojoj ostale igre biraju kategoriju, ostaje ista). Pet tema koje su i posle spajanja bile kratke
  (politika, društvo, tehnologija, mediji i marketing, računari) dopunjene su postojećim pitanjima iz opšteg fonda po
  strogim rečima (proveren uzorak). Nova pitanja nisu morala da se pišu.
- Dodato 15.799 oznaka, sve zapisane u `karijera_oznake_dodate` (može da se vrati).
- Teme struka su sada samo šire teme; najmanja ima 1.015 pitanja (moda), zatim tehnologija 1.034, pravo 1.055,
  opšte znanje 1.061. Ključne oblasti postojećih firmi prebačene su na šire teme.
- Fokus u opštem delu broji ceo fond i nudi samo teme sa ≥ 1.000.
- SQL: `scripts/2026-11-05_karijera-spoj-tema.sql` (`karijera_38`, `karijera_39`).

## Stanje pre spajanja

Ažurirano: 05.11.2026. · verzija 2 (REŠENO: spajanje + dopuna iz opšteg fonda, sve teme ≥ 1.000)

Vlasnik traži: svaka tema u svakoj struci najmanje 1.000 pitanja. Brojano u `karijera_fond` (opšti fond + 24.911 pitanja
struke iz `kviz-pozicije.xlsx`). Lokalna baza `kviz-baze/pozicije` je isti skup koji je već uvezen; ostatak
`kviz-baze` (1,04 miliona) je u prevodu u drugoj sesiji i još nije spreman za uvoz.

| Struka | Tema ispod 1.000 (broj pitanja) |
|---|---|
| Advokat | međunarodne institucije (0), ustav (0), pravo (0), ljudska prava (48), istorija prava (63), EU i UN institucije (63), poznata suđenja (70), rimsko pravo (102), filozofija (297), društvo (297), pravo i ustav (709) |
| Bankar | finansije (0), valute (0), kompanije (0), procenti i računica (21), istorija ekonomije (23), berza (39), matematika (54), slogani (81), novac i valute (105), poznate kompanije (381), društvo i kultura (417), opšte znanje (644), ekonomija (931) |
| Diplomata | politika (0), međunarodne organizacije (29), međunarodni odnosi (60), društvo (297), društvo i kultura (417), opšte znanje (644) |
| Filmski producent | pozorište (0), glumci (0), serije (0), Film (154) |
| Inženjer | izumi (0), arhitektura (1), poznate građevine (51), izumi i izumitelji (53), matematika (54), saobraćaj i vozila (59), fizika (95), društvo i kultura (417), tehnologija (481) |
| Istoričar | vladari (0), vladari i dinastije (5), svetska istorija (11), arheologija (39), ratovi (46), Srbija i Balkan (58), antika (66), Vladari (161), Godine događaja (281), društvo i kultura (417), opšte znanje (644) |
| Izdavač | mitologija (31), knjige i izdavaštvo (31), književne nagrade (45), Književni pravci (136), Pisci i dela (268), umetnost i književnost (369), društvo i kultura (417), opšte znanje (644), Književna dela (674) |
| Kustos | skulptura (0), muzeji (0), arhitektura (1), likovna umetnost (6), muzeji sveta (33), umetnički pravci (39), slikari (288), umetnost i književnost (369), društvo i kultura (417), opšte znanje (644) |
| Šef kuhinje | vino (0), poznati kuvari (12), hrana (15), začini (39), vino i pića (39), namirnice (40), nacionalna jela (84), gastronomija (162) |
| Lekar | biologija (34), istorija medicine (50), biologija čoveka (58), ishrana (60), bolesti (75), anatomija (194) |
| Marketing | brendovi (0), reklame (0), marketing (0), psihologija kupca (61), mediji (75), slogani (81), društvene mreže (86), marketing i reklame (201), brendovi i logotipi (215), društvo (297), poznate kompanije (381), ekonomija (931) |
| Modni dizajner | moda (0), dizajn (12), moda i modni brendovi (405), društvo i kultura (417), istorija odevanja (598) |
| Muzički producent | opera (0), evrovizija (0), opera i klasika (1), instrumenti (22), kompozitori (37) |
| Naučnik | astronomija (0), otkrića (4), geologija (32), biologija (34), astronomija i svemir (51), matematika (54), hemija (62), fizika (95) |
| Novinar | politika (0), mediji (75), mediji i novine (103), svetska politika (123), poznate ličnosti (136), savremena istorija (158), društvo (297), opšte znanje (644) |
| Programer | it kompanije (0), video-igre (0), logika (19), video igre (23), matematika (54), tehnološke kompanije (63), istorija IT-a (76), internet (161), društvo i kultura (417), tehnologija (481), računari (602) |
| Psiholog | ljudsko ponašanje (2), sociologija (9), religije i verovanja (51), psihologija (89), filozofija (297), društvo (297), umetnost i književnost (369), društvo i kultura (417) |
| Sportski menadžer | 26 tema, od surfovanja (1) do Sportisti (680); široka tema sport ima 9.382 |
| Turistički menadžer | glavni gradovi (0), valute (0), zastave (12), jezici (19), znamenitosti (37), Gradovi i reke (162), turizam (195), Znamenitosti (211), umetnost i književnost (369), društvo i kultura (417), opšte znanje (644) |
| Veterinar | klima (0), okeani (1), biljke (14), veterina (15), mitologija (31), priroda i klima (31), namirnice (40), ekologija (88), anatomija (194), životinje (356), umetnost i književnost (369), društvo i kultura (417), opšte znanje (644) |

Teme sa 0 pitanja su stari nazivi koji se ponavljaju (npr. „pravo” pored „pravo i ustav”, „astronomija” pored
„astronomija i svemir”).

## Putevi

1. **Spojiti srodne teme** u šire (npr. Advokat: pravo, ustav, ljudska prava, istorija prava, rimsko pravo, suđenja →
   „pravo”, oko 1.050). Brzo, bez novih pitanja; ali neke struke ni zbirno ne dostižu 1.000 (muzički producent, kuvar, lekar).
2. **Novih ~150.000 pitanja** za uže teme (pisanje po struci, pa provera i Gram), kao kod `kviz-pozicije.xlsx`.
3. **Kombinacija:** odmah spojiti duplikate i srodne teme, a za struke koje i dalje fale (lekar, kuvar, muzika, film,
   naučnik, kustos) napisati nova pitanja.
