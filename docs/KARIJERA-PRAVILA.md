# Karijera: pravila igre

Ažurirano: 05.11.2026. · verzija 13 (teme struka spojene u šire, sve ≥ 1.000 pitanja; povlačenje odmora, jedinstveno ime firme, moja firma prva na berzi, niz rasta zgrade, oštrije zgrade; izometrijski grad, napuštena runda = 0 tačnih, tračevi iz kancelarije u pripremi; Grad: sve firme kao zgrade u ulicama, pretraga, balončići; priprema 4 s sa zanimljivošću, probni do 10 rundi dnevno, objava u Igračima, Karijera u Skorašnjoj aktivnosti, 8 stilova zgrade; duge rečenice šefa u dva reda; + slobodni dani i prekovremeno, pitanja struka samo za Karijeru, nov ekran posle runde) · grana `redizajn-quizpop`

Druga glavna igra pored Osvajanja sveta. Igrač počinje kao zaposleni u korporaciji, polaže
probni rad, otvara svoj office, zapošljava botove, prima druge igrače i brani firmu u duelu.
Sva ekonomija se računa na serveru (`scripts/2026-11-04_karijera.sql`), aplikacija samo prikazuje.
Brojevi su u SQL funkcijama kao imenovane konstante; menjaju se jednom migracijom, bez nove verzije aplikacije.

## 1. Tok

1. **Pozicija.** Igrač bira jednu od 20 pozicija (`karijera_pozicije`). Pozicija nosi spisak tema
   (oznake u `questions.tags`). U rundi je 6 od 10 pitanja iz struke, 4 iz opšteg znanja.
   Veza pozicija → teme je u bazi: nove oznake iz generisanja pitanja rade odmah.
2. **Probni rad.** 10 rundi po 10 pitanja, najviše 10 rundi dnevno (od 05.11; ranije 4), može u jednom danu. Server `karijera_29_probni_10_dnevno`.
   Igra se u Korporaciji, uz šefa.

   | Tačnih od 100 | Ishod |
   |---|---|
   | 90+ | svoj office, izbor zgrade, 2 bota |
   | 75–89 | office, 1 bot |
   | 60–74 | office bez botova |
   | ispod 60 | ostaje u Korporaciji; novi probni posle 3 radna dana u Korporaciji |

   Bivši vlasnik (izgubio ili zatvorio firmu) ima skraćeni probni: 3 runde.
3. **Korporacija.** Difolt firma, uvek otvorena. Plata 40%. Šef komentariše svaki odgovor kad igrač radi
   kod drugog (Korporacija, NPC ili tuđa firma; u svojoj firmi nema šefa). `Karijera/Sef.swift`: 110 pohvala,
   120 „mobing” rečenica i 50 za isteklo vreme, parodija bez psovki; oblik `{muški|ženski}` bira se po polu.
4. **Svoj office.** Ime upisuje igrač (3–32 znaka, filter ružnih reči, jedinstveno; posle 3 prijave
   drugih igrača ime se skida i vlasnik bira novo), izgled zgrade (4 varijante), asistenti
   (u bazi `karijera_botovi`; u aplikaciji „asistenti”).
   U igri je kartica pitanja plava i stoji preko officea; posle odgovora kartica ode, vidi se
   ceo office (u Korporaciji i šef), pa dolazi sledeće pitanje.
5. **Rad kod drugih.** Berza poslova: Korporacija, firme igrača i NPC firme.

## 2. Tri vrednosti

| Vrednost | Troši se | Raste od |
|---|---|---|
| Kapital (lični) | da | plata, dividenda, otpremnina |
| Ugled | nikad | +10 po tačnom bez pomoći, +20 po rundi |
| Ekspertiza po temi | nikad (pad posle 14 dana neigranja, kasnije) | tačan bez pomoći +5 × težina, netačan −2 |

**Ugled i ekspertiza rastu samo na odgovorima bez pomoći.** Plata se dobija i sa pomoćima.

Titula po ugledu: junior (0), senior (3.000), menadžer (10.000), direktor (30.000).
Nivo ugleda = ugled / 1.000 + 1.

## 3. Vrednost jednog tačnog odgovora (promet)

`10 × kurs firme × težina × brzina × niz × titula × pomoć`

| Množilac | Vrednost |
|---|---|
| Kurs firme | ključna oblast ×2, ostalo ×1 (Korporacija sve ×1) |
| Težina | lako ×1, srednje ×2, teško i nemoguće ×4 |
| Brzina (20 s) | do 5 s ×1,5, do 10 s ×1,2, posle ×1 |
| Niz u rundi | od 5. tačnog zaredom ×1,2, od 10. ×1,5 |
| Titula | junior ×1, senior ×1,3, menadžer ×1,6, direktor ×2 |
| Pomoć | kolega ×0,7, asistent ×0,6, bot ×0,6, guglanje ×0,5 |

Plaćeno je **10 rundi dnevno** ukupno (u svim firmama). Posle toga igra se za ugled i ekspertizu.
Dan počinje u ponoć po beogradskom vremenu.

## 4. Podela prometa

| Gde radiš | Tebi (plata) | Kasi firme |
|---|---|---|
| Korporacija | 40% | — |
| Firma, nivo „škrt” | 50% | 50% |
| Firma, nivo „pošten” | 65% | 35% |
| Firma, nivo „izdašan” | 80% | 20% |
| Svoja firma | 0% | 100% |

Nivo udela vlasnik menja najviše jednom u 7 dana.
Kasa firme i lični kapital su odvojeni. **Dividenda:** vlasnik dnevno podiže do 10% kase u lični kapital.

## 5. Firma

| Nivo | Zgrada | Cena (kasa) | Aktivnih zaposlenih (7 dana) | Botova | Održavanje dnevno |
|---|---|---|---|---|---|
| 1 | Garaža | — | — | 1 | 40 + 25 po botu |
| 2 | Kancelarija | 2.000 | 1 | 2 | 80 + 25 po botu |
| 3 | Sprat | 10.000 | 3 | 3 | 120 + 25 po botu |
| 4 | Poslovna zgrada | 40.000 | 8 | 4 | 160 + 25 po botu |
| 5 | Neboder | 150.000 | 20 | 5 | 200 + 25 po botu |

- Održavanje se skida iz kase. Ako kase nema dovoljno, jedan bot daje otkaz za svaki takav dan.
- **Neaktivnost vlasnika** (ulazak = odigrana runda u toj firmi): 1 propušten dan → bot daje otkaz,
  2 → drugi bot, 3 → firma se zatvara (zaposleni su slobodni, kasa propada).
- **Godišnji odmor:** 3 dana mesečno, unapred; tada se dani ne računaju kao propušteni.
- **Botovi:** zapošljavanje 1.000, obuka 60% → 75% za 3.000, 75% → 90% za 8.000.
  Svaki bot pomaže na 5 pitanja dnevno u svojoj temi, svima u firmi.
- Vlasnik bira 3 ključne oblasti (kurs ×2) i može da otpusti zaposlenog.
- Do 4 officea: 2. na nivou ugleda 10, 3. na 25, 4. na 50. Novi office košta 5.000 ličnog kapitala.

## 6. Rekord i preuzimanje

- **Rekord firme:** najviše poena jednog igrača za jedan dan u plaćenim rundama te firme.
- Zaposleni koji drži rekord i u firmi je bar 3 dana šalje **izazov** i bira svoju temu.
- Vlasnik ima 24 h da prihvati i izabere 1. i 3. temu. Bez odgovora firma prelazi na izazivača.
- **Duel:** 3 runde po 10 pitanja (20 s), teme vlasnik, izazivač, vlasnik. Pobeđuje veći zbir tačnih,
  kod istog broja manje ukupno vreme. Oba igrača imaju ista pitanja i igraju kad stignu, u roku od 24 h;
  ko ne odigra, gubi (ako niko, firma ostaje vlasniku).
- **Botovi vlasnika u duelu:** svaki bot najviše 2 pitanja, samo u svojoj temi.

  | Pokušaj istog izazivača | Botovi vlasnika | Teme |
  |---|---|---|
  | 1. | svi | vlasnik, izazivač, vlasnik |
  | 2. | 1 | vlasnik, izazivač, vlasnik |
  | 3. | 0 | vlasnik, izazivač, vlasnik |
  | 4.+ | 0 | vlasnik, izazivač, nasumična |

- Između dva izazova istog para 5 dana; vlasnik posle pobede 5 dana zaštićen od svih;
  nova firma 3 dana zaštićena; firma posle preuzimanja 5 dana zaštićena.
- **Preuzimanje:** zgrada, botovi, kasa i ime idu novom vlasniku. Bivši vlasnik dobija 20% kase kao
  otpremninu i pravo na jedan **revanš** u 14 dana bez obaranja rekorda.
- **NPC firme** (40, po dve za svaku poziciju) imaju izmišljene vlasnike; preuzimaju se istim duelom,
  NPC rezultat zavisi od nivoa firme.

## 7. CV i liste

- CV: pozicija, titula, firma u kojoj radi, firme koje drži, kapital, neto vrednost, ugled,
  ekspertiza po temama, vremenska linija (`karijera_dogadjaji`).
- Liste: neto vrednost (kapital + kasa + vrednost zgrada), najveće firme (zaposleni),
  sezona (poeni u tekućem tromesečju; zgrada i CV ostaju).

## 8. Varanje (blaži start)

Na startu važe samo: ekspertiza bez pomoći, 10 plaćenih rundi dnevno i kapital se ne prodaje.
Server čuva istoriju rundi i duela, da se ostale zaštite mogu uključiti kad se pojavi varanje.
Tačnost odgovora računa server iz `questions.correct_answer`, ne veruje aplikaciji.

## 9. Brisanje naloga

Brisanje naloga briše igrača, runde, ekspertizu i CV. Njegove firme postaju NPC firme
(„Uprava”) i mogu se preuzeti duelom.

## 10. Prečice (svesno, za kasnije)

- Nerešen duel se ne igra dodatnim pitanjem, već odlučuje ukupno vreme.
- Napredovanje u tituli ide samo po ugledu; duel za unapređenje i co-op „zajedno u officu” dolaze posle.
- Firme brisanog vlasnika ne prelaze na najboljeg zaposlenog, nego postaju NPC.
- Druge vrste kviza u firmi (slikari, vešanje, brzi) još nisu uključene.

## 11. Pol, talenti i nebo (04.11, verzija 3)

- Na početku igrač bira **struku → muško ili žensko → 3 talenta** (`karijera_izaberi_poziciju(p_pozicija, p_pol, p_talenti)`).
  Pol menja naziv struke („Lekarka”), događaje u CV-u i obraćanje šefa.
- **20 talenata** (`karijera_talenti`): 14 računa server (Pregovarač, Štediša, Lider, Maratonac, Brzinac, Stručnjak,
  Svestran, Upornost, Druga šansa, Mentor, Neumorni tim, Ekspert, Rođeni talenat, Branilac), 6 aplikacija
  (Brz um, Dobar kolega, Istraživač, Intuicija, Prvi utisak, Duelista). Opisi su u tabeli i prikazuju se iz nje.
- **Napredovanje:** na svakih 200 tačnih odgovora jedna zamena talenta (`karijera_promeni_talenat`), u meniju „Talenti”.
- **Nebo** iza svakog officea prati sat na telefonu: jutro (5–9), dan (9–18), veče (18–21), noć; danju oblaci i ptice,
  noću zvezde i mesec (`Karijera/Nebo.swift`, crta se u kodu).
- Kartica Karijere na početnoj je plava (#2F6FD6), sa jednim neboderom desno i tekstom levo.

## 12. Prvi ulazak, pomoći i raspored (04.11, verzija 4)

- **Prvi ulazak u 5 koraka:** struka → pol → 4 pomoći → 3 talenta → priča „Tvoj prvi dan” (Korporacija, nebo,
  muzika, tekst u rodu igrača, napomena da niko ne vređa i da je cilj zabava i učenje) → „Prijavljujem se za posao”.
  Strelica nazad ide korak po korak; izbor se šalje serveru tek na prijavu.
- **18 pomoći** (`Karijera/Pomoci.swift`, server `karijera_pomoci_spisak`): moći iz Osvajača preimenovane za
  kancelariju (Pola stola, Crvena olovka, Insajder, Mentor, Prvo slovo, Produžen rok, Pauza za kafu, Prekovremeno,
  Ekspres, Hodnik priča, Ćaskanje na kafi, Mreža kontakata, Ceo tim, Zaključan sat, Sigurna odluka, Brainstorming,
  Dvostruka provera, Sabotaža konkurencije). Igrač bira 4, svaka 1× po rundi; odgovor sa pomoći ×0,7, Insajder ×0,4.
- **Posle runde:** „Sledeća runda” (odmah nova) ili „Idi kući”; u probnom radu posle 4. dnevne runde samo „Idi kući”.
- **Korporacija** u firmi prikazuje „Kako se napreduje” u 3 koraka.
- **Profil:** kartica Karijere otvara CV, ispod su Talenti (dodir → zamena). **Rang lista** je na glavnoj tabli
  (Osvajač · Karijera · Ostale igre), ne u meniju Karijere.

## 13. Muzika i zvuci (05.11)

Paketi koje je vlasnik kupio (AudioJungle/Freepik, zip u Downloads) prolaze kroz `alati/karijera_muzika.py`
→ `mobile/zvuci/karijera_*.m4a`. Petlje se ne seku (osim tišine), muzika −20 LUFS, kratki zvuci −16 LUFS.

| Fajl | Izvor | Gde svira |
|---|---|---|
| karijera_uvod | Corporate Loop (31,7 s) | priča „Tvoj prvi dan” |
| karijera_korporacija | Jazz Swing Piano LOOP (79 s) | runda u Korporaciji |
| karijera_probni_kraj | This Jazz 180 Version 2 (66 s) | 10. (poslednja) runda probnog rada |
| karijera_firma | Soul jazz 45 sec loop (48 s) | runda u svojoj firmi |
| karijera_posao | Jazz Waltz loop (16,8 s) | runda kod drugog vlasnika ili NPC |
| karijera_office | Corporate Upbeat Loop (73 s) | otvaranje officea |
| karijera_duel | Tension LOOP (54 s) | duel, izazivač |
| karijera_odbrana | Boss Battle Loop (67,7 s) | duel, vlasnik brani firmu |
| karijera_unapredjenje | Game Win Logo 04 (4,2 s) | položen probni rad, otvoren office |
| karijera_rekord | Fanfares 4,2–9 s | nov rekord firme, pobeda u duelu |
| karijera_uspeh | Success Corporate 17–23,5 s | runda sa 7+ tačnih |
| karijera_kasa | sinteza („ka-čing”) | plata posle runde, dividenda |
| karijera_zvono | sinteza („ding-dong”) | prijava za posao, zaposlenje u firmi |

## 14. Šef i pitanja po firmi (05.11, verzija 5)

Migracije `karijera_20_sef_i_teme`, `karijera_21_fokus_najvise_10`; skripta `scripts/2026-11-05_karijera-sef.sql`.

**Jačine komentara** (0 isključen, 1 blag, 2 srednji, 3 jak), posebno za tačne i za netačne. Isteklo vreme
koristi jačinu za netačne. Banke (`Sef.swift`, `SefBanke.swift`): blago 40+40, srednje 110+120+50 (isteklo),
jako 40+60, smeh 20+20. Od 05.11 nema kratkih uzvika („Pff”, „Jes”): smeh je cela rečenica u kojoj šef
podbada ili grdi. Oblačić ima najviše dva reda: svaka rečenica ≤ 52 znaka u svakom obliku (test `testDvaReda` /
`dvaReda`), slova 15. Komentar stoji 2,7 s pre sledećeg pitanja (bilo 2,2 s). Provera izgleda: iOS `-sefProba`. Jako je oštro, ali bez psovki i ličnih uvreda: kritikuje se posao, ne čovek.
Smeh (ako je uključen) zameni rečenicu u 1 od 4 odgovora.

**Ometanja** usred pitanja: najviše jedno po pitanju, nikad dva pitanja zaredom, nikad u poslednjih 7 s,
sat se nikad ne zaustavlja; čim igrač izabere odgovor, ometanje nestaje i ne sme da iskoči.
Retko 1, ponekad 2–3, često 4–5 po rundi. Skoro sva su **upad** (traka gore, sama nestaje za 1,5 s).
**Zadatak** (kartica preko odgovora, sat ostaje vidljiv, dugme „Odmah, šefe”) i **haos** (trese ili zamagli
pitanje 1,8 s) su retki jer baš ometaju (vlasnik 05.11): najviše jedan u rundi, i to „često” jednom po rundi
(svako ~10. pitanje), „ponekad” u svakoj drugoj rundi (~20. pitanje), „retko” nikad (`Sef.velikoPitanje`).
Na „često” je veliko ometanje haos u 1 od 3, inače zadatak. 60 tekstova: 25 upada, 25 zadataka, 10 haosa.

**Podešavanje**: vlasnik u svojoj firmi (Upravljanje → Šef). Korporacija i NPC firme: srednji/srednji,
ometanja ponekad, smeh da. U svojoj firmi šef ne komentariše vlasnika.

**Dodatak za stres** (`karijera_stres`): srednji šef +5% plate, jak +10% (po jačem od dva komentara),
česta ometanja još +5%. Dodatak ide iz dela koji bi otišao u kasu firme; ne važi u Korporaciji ni u svojoj firmi.
Berza i firma prikazuju šefa i dodatak.

**Mirni režim** (Podešavanja → „Mirni šef u Karijeri”, `karijera_igraci.mirni`): kod svakog poslodavca šef
najviše blag, bez ometanja i smeha; igrač nema dodatak za stres.

**Pitanja u firmi** (Upravljanje → Pitanja u firmi): struka 40–80% (podrazumevano 60), do 2 teme fokusa
u opštem delu, svaka 20–50% opšteg dela, težina normalno/teže (teža firma prvo vuče teška pitanja).
Nude se samo opšte teme sa bar 200 pitanja (`karijera_teme_fokusa`). Runda je uvek 10: zaokruživanje dve
teme se seče na ostatak (server i aplikacija isto, test `testMesavinaKaoServer`). Pravilo 2× u 7 dana važi
za svaki deo. Duel ostaje kakav je bio. DEBUG: `-ometanjeSvako` daje ometanje na svakom pitanju (upad, zadatak, haos redom).

## 15. Izgled šefa, uvod i pravila (05.11, verzija 6)

**Izgled šefa** (`karijera_firme.sef_lik`, migracija `karijera_22_lik_sefa`): šef Korporacije postoji samo u
Korporaciji (6 poza: zadovoljan, ljut, nervozan, smeh, šok, kafa). Vlasnik u Upravljanje → Šef bira jedan od 6
likova: mladi, srednji i stari šef, mlada, srednja i iskusna šefica (po 4 poze). NPC firme dobijaju lik po id-ju.
Slike `Karijera_Sef_<lik>_<poza>`, Freepik AI (Mystic `magnific_sharpy`, stil po šefu Korporacije), stripovski
crtež kao vlasnikov primer. **Šefice nose odela sa pantalonama i niske cipele, bez mini suknji, štikli i
izazovnih poza** (vlasnik 05.11), karikirane isto kao muški likovi.

**Rod šefa u rečenicama**: `{muški|ženski}` je rod igrača, `[muški|ženski]` rod šefa kad govori o sebi
(„[Ponosan|Ponosna] sam”). Natpis „Šef kaže”/„Šefica kaže”, dugme „Odmah, šefe”/„Odmah, šefice”.

**Prvi ulazak** (10 koraka, `KarijeraVodic.swift`): strana priče pa izbor, naizmenično: šta je Karijera → struka →
probni rad → pol → pomoći i asistenti → izbor pomoći → tvoja firma → talenti → rivali i duel → tvoj prvi dan.

**Lobi → Pravila i saveti**: istih 5 strana i 11 saveta. Predlog strategije: `docs/KARIJERA-STRATEGIJA-PREDLOG.md`.

## 16. Slobodni dani, pitanja struka, ekran posle runde (05.11, verzija 7)

**Slobodni dani** (`karijera_firme.slobodni`, ISO 1 = ponedeljak … 7 = nedelja; migracije karijera_24 i karijera_26):
vlasnik bira do 3 dana pri otvaranju officea i u Upravljanju, menja ih jednom u 7 dana. Korporacija: subota i nedelja.
NPC firme nemaju slobodne dane. Na slobodan dan: izostanak vlasnika se ne računa, izazov se ne može poslati, rok
izazova (24 h) se produžava za svaki slobodan dan, a runda u toj firmi je **prekovremeno**: plata i kasa ×1,1
(„Opa, prekovremeno!” posle runde; na kartici firme „Danas je slobodan dan · prekovremeno +10%”).

**Pitanja struka** (migracije karijera_27 i karijera_28): 24.911 pitanja iz „novo kviz-pozicije.xlsx” u tabeli
`karijera_pitanja`, samo za Karijeru (druge igre ih ne vide). Pogled `karijera_fond` = opšta + pitanja struka;
koriste ga struka, duel, asistenti i obračun. Opšti deo runde (40% kod podrazumevane mešavine) i dalje je iz celog
opšteg fonda. Teme iz fajla (prevedene sa engleskog gde treba) dodate su temama struke.

**Ekran posle runde**: rezultat na plavoj kartici sa zgradom firme, sve brojke u jednom redu, dugmad na dnu.
**Greške servera**: igrač vidi samo naše poruke (22023, P0001, P0002, 42501); tehničke greške baze se zamenjuju opštom porukom.

## 17. Android (05.11)

Karijera je preneta na Android (`mobile/android/.../karijera/`): model i svi pozivi, šef (iste banke rečenica, generisano iz
Swift izvora: `SefTekstovi.kt`), 18 pomoći, nebo (isto vreme po firmi i danu kao iPhone, isti SplitMix), prvi ulazak u 10 koraka,
runda sa ometanjima i asistentima, ekran posle runde, duel, firma sa upravljanjem (šef, pitanja, slobodni dani, ključne oblasti),
berza, otvaranje officea, CV, rang (karta „Karijera” u Rang listi), Pravila i saveti, Podešavanja (Mirni šef, Reset Karijere).
Slike u `res/drawable-nodpi/karijera_*.webp` (58, 2,1 MB). Greške baze se ne prikazuju igraču (isto kao iOS).
Provera: `./gradlew :app:testDebugUnitTest --tests club.librum.kviz.KarijeraTest` (3/3), vizuelno
`./gradlew assembleDebug -Pproba` + `adb shell am start -n club.librum.kviz.proba/club.librum.kviz.MainActivity --ez karijeraProba true`
(debug pored Play verzije, izmišljeni podaci). Prava runda na Androidu nije igrana (emulator bez naloga).

## 18. Priprema, objava i aktivnost (05.11)

- **Priprema runde:** pre svake runde 4 sekunde odbrojavanja (4, 3, 2, 1) i jedna zanimljivost „Da li si znao?”
  iz `src/lib/igre/zanimljivosti.json` (isti fajl za iOS i Android). Pitanja se učitavaju za to vreme.
- **Objava:** posle runde ikonica za deljenje: slika za story/objavu (iOS), tekst drugim aplikacijama (Android) i
  „Objavi u Igračima” (`nova_objava`, igra `karijera`).
- **Skorašnja aktivnost** na profilu prikazuje i runde Karijere (`profil_igraca` čita `karijera_runde`).
- **Probni rad:** najviše 10 rundi dnevno (bilo 4), pa može da se završi u jednom danu.
- **Zgrade:** 8 stilova po nivou (bilo 4): Moderno, Cigla, Belo, Kreativno, Kontejner, Loft, Zeleno, Kruna.
  Server prima stil 1–8 (`karijera_30_osam_stilova_zgrade`); stara verzija aplikacije prikazuje 5–8 kao 4.
- **Ulica ispred zgrade** (`Karijera/Ulica.swift`, `karijera/Ulica.kt`): pešaci, bicikl, automobili, taksi, kombi, hitna i
  autobus nacrtani u kodu kao ptice na nebu; pešaci koračaju, točkovi se okreću, hitnoj trepće rotacija. Sa „Smanji pokrete”
  (iOS) ili isključenim animacijama (Android) ulica miruje.
- **Muzika u mojoj firmi:** 4 džez numere (`karijera_firma`, `_2`, `_3`, `_4`, ujednačene na −20 LUFS), svakog dana druga
  i različito po firmi (`KarijeraMuzika.zaMojuFirmu`).
- **Uvod:** tekstovi kažu jasno da posle probnog rada možeš da otvoriš firmu, da kod tebe dolaze pravi igrači i da ti oni
  mogu preoteti firmu; botovi su asistenti i firmu ne preuzimaju.
- **Pomoć „Prvo slovo”** pokazuje prvo pravo slovo (preskače navodnike), bez dvostrukog natpisa.

## 19. Grad (05.11)

- U lobiju Karijere red **Grad**: jedna velika **izometrijska mapa** (pogled koso odozgo, po vlasnikovim primerima),
  nacrtana u kodu (`Karijera/IsoGrad.swift`, `karijera/IsoGrad.kt`): bele kutije sa plavim prozorima, ravni krovovi sa
  ventilacijom, okruglo drveće, tamni putevi, kolica i pešaci (crtaju se u istom redosledu kao zgrade, ne preko krovova).
- **Raspored:** blok = 2×2 parcele + put; Korporacija zauzima centralni blok, ostali blokovi se nižu **spiralno** oko nje
  (`IsoRaspored`). Parcela iz baze (`karijera_firme.parcela`) određuje mesto. Grad uvek ima pune prstenove i još jedan prsten
  parkova za nove igrače; kad dođu nove firme, grad se sam širi. Oko grada je zelenilo sa drvećem, a pomeranje ne pušta van grada.
- **Zgrada:** visina po nivou (garaža, kancelarija, sprat, poslovna zgrada, neboder), boja po stilu (8), zlatna kruna za stil 8.
  Moja firma, firma gde radim i nađena firma imaju žut obod krova. Prazna parcela je travnjak sa drvećem.
- **Balončić** iznad krova (`karijera_balon`): „Probni rad”, „Napadnuta!”, „+N poena”, „Traži zaposlene” (samo firme pravih igrača).
- **Učitavanje:** `karijera_grad_mapa(p_posle)` po 500 firmi, keyset po parceli. **Nađi firmu** (`karijera_trazi_firmu`,
  trigram) centrira mapu na zgradu; ikonica lokacije vodi do moje firme. Dodir na zgradu otvara firmu.
- Zum prstima od cele mape do jedne zgrade; imena firmi se vide kad je zum blizu.
- SQL: `scripts/2026-11-05_karijera-grad.sql` (`karijera_31`–`karijera_35`). Usput: tabela je dozvoljavala samo stil 1–4 (`karijera_33`).
- Još nije: kvartovi po delatnosti, parcele koje se kupuju.

## 20. Napuštena runda i priprema (05.11)

- **Izlazak usred runde** (X, a na Androidu i sistemsko nazad) traži potvrdu; posle potvrde runda se šalje kao 10 netačnih
  odgovora: **0 tačnih**, plaćena runda se troši. Ako se aplikacija ugasi usred runde, runda se ne šalje (još nije rešeno na serveru).
- **Priprema runde:** 4 s odbrojavanja, ilustracija kolega (14 slika `Karijera_Trac_1…14`) i jedan **trač iz kancelarije**
  (izmišljen, šaljiv) ili **istina, proveri** (stvarna činjenica o poslu i kancelarijama), iz `src/lib/igre/kancelarija.json`
  (79 stavki: 50 tračeva, 29 činjenica), isto na obe platforme.

## 21. Sitnice 05.11 popodne

- **Godišnji odmor** može da se povuče: neiskorišćeni dani se vraćaju u mesečni fond (`karijera_odmor_povuci`). Stanje vraća
  `odmor_do` samo dok odmor traje.
- **Ime firme** je jedinstveno po punom imenu (jedinstven indeks na `ime_trazi`); poruka „Firma sa tim imenom već postoji”
  stiže do igrača (kod 22023). Ime se menja u Upravljanje → Ime firme (i olovkom pored naslova).
- **Berza:** moja firma je prva.
- **Pitanja u firmi:** bez broja pitanja pored teme; teme za fokus su jedan spisak sa linijama i krugom za izbor (ne odvojene zaobljene kartice).
- **Upravljanje** (nov izgled 05.11): dugme za rundu i jedna napomena; **Kasa** je tamna kartica sa krupnim iznosom i tri radnje
  (Dividenda, Asistent, Nadogradi); kad radnja ne može, piše zašto („kasa prazna”, „nema mesta”, „zaposleni 0/3”), ne bledi.
  Plata zaposlenima, pa **Podešavanja firme** sa obojenim kvadratima za ikonice; bez kartice u kartici. iOS `-upravljanjeProba` (DEBUG) prikazuje ga na tuđoj firmi.
- **Otvaranje firme:** ispod velike slike niz garaža → neboder za izabrani izgled.
- **Zgrade** ponovo obrađene iz izvornih slika na 1.200 px uz izoštravanje (bile 720 px, mutne na velikoj slici).
- **Teme struke** su spojene u šire teme i svaka ima najmanje 1.000 pitanja (`docs/KARIJERA-TEME-ISPOD-1000.md`).

