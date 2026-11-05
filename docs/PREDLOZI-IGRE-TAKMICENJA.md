# Librum Kviz: predlozi novih igara, takmičenja i pravila

Ažurirano: 02.11.2026 · verzija 0.1 (nacrt za dogovor, ništa od ovoga nije u kodu dok vlasnik ne kaže „uradi”)

Postojeće igre (aplikacija): Osvajanje sveta, PRO kviz, Book kviz, Trivia duel, Vešanje, Brzi kviz.
Ovaj dokument predlaže šta dodati, sa tačnim pravilima, da bismo zajedno izabrali i doradili.
Za svaku stavku su date tri varijante gde odluka nije očigledna.

---

## 1. Zajednička ekonomija (temelj za sve ostalo)

Kit već ima novčiće, XP, nivoe, bedževe, prodavnicu i sanduče. Predlog pravila:

| Šta | Kako se dobija | Na šta se troši |
|---|---|---|
| **XP** | +1 po tačnom odgovoru, +5 za završenu igru, ×2 u dnevnom izazovu | Ne troši se; određuje nivo |
| **Nivo** | Nivo n traži `250 × n` XP (1→2 = 250, 12→13 = 3.000) | Otključava ulog u duelu, teže lige |
| **Novčići** | Dnevna nagrada (10/20/30/40/50/60/100 po danu niza), pobeda u duelu (ulog ×2), bedž (+50…+500), nedeljna liga (top 3) | Pomoći (50/50, Nagoveštaj, +10 s, Preskok), ulog u duelu, ponovni pokušaj dnevnog izazova |
| **Bedževi** | 40 bedževa u 5 grupa (vidi 1.2) | Ne troše se; prikaz na profilu |

**Pravilo bez novca (predlog A, preporuka):** novčići se NE kupuju pravim novcem. Prodavnica prodaje samo pomoći za novčiće.
Razlog: nema IAP/Apple provizije, nema „plati da pobediš”, rang lista ostaje fer.
- B: paketi novčića za novac (Apple/Google IAP, 30 % provizija), samo kozmetika (okviri avatara, maskote).
- C: „Librum+” pretplata (bez reklama, dupli XP, neograničen dnevni izazov) preko pay.librum.rs na vebu.

### 1.1 Cene pomoći (predlog)
| Pomoć | Cena | Ograničenje |
|---|---|---|
| 50/50 ×5 | 100 | najviše 1 po pitanju |
| Nagoveštaj ×5 | 150 | maskota kaže trag (polje `hint` iz baze ili prvo slovo odgovora) |
| +10 s ×5 | 120 | ne važi u duelu |
| Preskok ×5 | 200 | ne važi u duelu i Osvajanju |

### 1.2 Bedževi (40)
- **Niz:** 3, 7, 30, 100, 365 dana zaredom
- **Znanje:** 10/10 u kvizu, 100 tačnih, 1.000 tačnih, 10.000 tačnih, 50 zaredom u PRO
- **Brzina:** 10 odgovora ispod 2 s, Brzi kviz 400+ poena, sve tačno u Get Ready ispod 3 s
- **Duel:** prva pobeda, 10 pobeda, niz od 5, pobeda posle zaostatka, 100 duela
- **Osvajanje:** osvojen ceo kontinent, svih 171 država (nijedna nije neutralna), odbrana prestonice 3 puta, pobeda na Teškoj, proboj 3 puta u potezu
- **Knjige:** 50 Book pitanja tačno, svi žanrovi, Knjiški detektiv iz 1. traga
- **Zajednica:** 5 prijatelja, dodato pitanje odobreno, 10 odobrenih pitanja, član tima, pozvao 3 igrača
- **Liga:** unapređenje, top 3, Dijamantska liga, 10 nedelja bez ispadanja
- … (ostatak dopunjujemo zajedno)

---

## 2. Nove igre

### 2.1 Dnevni izazov (preporuka br. 1, najmanje posla, najviše povratka)
- Svi igrači dobijaju **istih 10 pitanja** tog dana (seme = datum, ista funkcija kao u duelu).
- 15 s po pitanju, bez pomoći. Poeni: tačno 100 + brzinski bonus `floor(ostatak sekundi × 5)`.
- Jednom dnevno. Rezultat se deli kao mreža kvadrata (zeleno/crveno) bez otkrivanja pitanja.
- Rang lista dana + niz dana (streak). Propušten dan: niz se gubi, osim ako se plati „zamrzavanje niza” 200 novčića (najviše 2 nedeljno).
- Ponoć po beogradskom vremenu (Europe/Belgrade), bez obzira na zonu telefona.

### 2.2 Mapa pogodak (koristi postojeću mapu sveta)
- Na mapi se zatraži država („Pokaži Bocvanu”), igrač tapne.
- Tačno = 100; susedna država = 40; isti region = 15; inače 0. 10 rundi, 10 s po rundi.
- Varijante: prestonice, zastave, „gde se dešava radnja romana” (veza sa Librumom).
- Tri težine: Evropa, ceo svet, samo male države.

### 2.3 Knjiški detektiv (Librum DNK)
- Pogađa se **knjiga** iz 5 tragova koji se otvaraju jedan po jedan: žanr → godina → citat → lik → autor.
- Poeni: pogodak posle traga 1 = 50, 2 = 40, 3 = 30, 4 = 20, 5 = 10. Unos sa automatskim predlozima iz kataloga (Postgres trigram, bez `LIKE '%…%'`).
- Dnevno 3 knjige + beskonačni režim. Dobar most ka librum.rs (dugme „Pročitaj” posle pogotka).

### 2.4 Vremeplov
- 6 događaja se slažu hronološki prevlačenjem. Svaki na tačnom mestu = 20; sve tačno = +30.
- Kategorije: istorija Srbije, svet, književnost (godine izdanja), sport, nauka.

### 2.5 Lanac pojmova (asocijacije u našem stilu)
- 4 kolone po 4 pojma + rešenje kolone + konačno rešenje. Otvaranje pojma −1 poen od maksimuma.
- Rešenje kolone 5 + broj zatvorenih pojmova; konačno 10 + 5 po nerešenoj koloni.
- Igra se sam ili u duelu (naizmenično, 30 s po potezu).
- Napomena: format asocijacija je opšti žanr; ne koristimo ime, izgled ni zvuk TV emisije.

### 2.6 Kviz za društvo (jedan telefon)
- 2–6 igrača, telefon se dodaje. Svako dobija svoje pitanje, 20 s.
- Bez naloga i bez interneta (rezervni paket od 125+ pitanja), rezultat se ne upisuje u rang listu.

### 2.7 Osvajanje sveta: igra protiv ljudi
- 2–4 igrača, **potezi bez čekanja** (kao dopisni šah): 24 h po potezu, obaveštenje kad si na redu.
- Napad na državu drugog igrača = mini duel od 1 pitanja oba igrača (brži tačan pobeđuje), umesto pitanja samo napadaču.
- Savezi: dva igrača mogu da potpišu primirje na 3 kruga (bez napada jedan na drugog).
- Kraj: 12 krugova ili kad neko drži 50 % država.
- Server mora da vodi stanje (sada je motor samo u telefonu); pravila ostaju u `pravila.ts`, a ponavljanje odigranog poteza na serveru proverava da niko ne vara.

---

## 3. Takmičenja

### 3.1 Nedeljna liga (preporuka br. 1)
- Grupe od 30 igrača sličnog nivoa. Liga: Papir → Bronza → Srebro → Zlato → Smaragd → Dijamant.
- Bodovi lige = zbir poena iz svih igara te nedelje (dnevni izazov ×2).
- Ponedeljak 00:00 (Beograd): top 7 ide gore, poslednjih 5 dole. Top 3 dobijaju 300/200/100 novčića.
- Neaktivni (0 bodova) se ne računaju u ispadanje, da prazne grupe ne kažnjavaju aktivne.

### 3.2 Vikend turnir
- Subota 18:00–20:00: kostur od 32 igrača (prijava do 17:55), duel na 5 pitanja, ispadanje.
- Kotizacija 100 novčića, nagrade: 1. 2.000, 2. 1.000, 3–4. 400.
- Ne pojavi se za 60 s = predaja (protivnik prolazi).

### 3.3 Škole, firme, klubovi (timski rang)
- Tim se pravi kodom (npr. `GIMN-ZEMUN`). Rang tima = prosek 10 najboljih članova za nedelju.
- Posebna tabela „Škole Srbije” uz pristanak roditelja za mlađe od 15 (pravno: zakon o zaštiti podataka).
- Firme: privatni turnir za kolektiv (team building), kasnije plaćena usluga.

### 3.4 Sezona osvajanja (mesečno)
- Svaki mesec nova mapa (ili ista sa drugim početnim pravilima): npr. „Balkan”, „Afrika”, „Ceo svet bez mora”.
- Sezonski rang = najbolji rezultat Osvajanja u mesecu. Pobednik dobija trajni bedž sa imenom sezone.

### 3.5 Tematske nedelje sa izdavačima
- Nedelja knjige jednog izdavača (pitanja o njihovim naslovima), nagrada = knjige ili vaučer na librum.rs.
- Veza sa Librum Marketom; izdavač plaća promociju.

---

## 4. Pravila fer igre (važe za sve)
1. **Rezultat računa server**, ne telefon: aplikacija šalje odgovore i vreme, server proverava i upisuje poene (sada telefon upisuje poene, što omogućava varanje).
2. Pitanje se šalje bez tačnog odgovora; tačnost se proverava na serveru (RPC), da se odgovor ne može pročitati iz mreže.
3. Ograničenje: najviše 1 rezultat dnevnog izazova po nalogu i uređaju; sumnjivo brzi odgovori (ispod 0,6 s u nizu) idu na pregled.
4. Prijava pitanja sa greškom iz svake igre (ikonica zastavice), admin ih vidi u redu.
5. Brisanje naloga briše i sve rezultate (već radi preko `obrisi_moj_nalog`).

---

## 5. Šta treba da odlučimo (redom)
1. Ekonomija: A (bez pravog novca), B (kozmetika za novac) ili C (pretplata)?
2. Koje dve igre prve: predlog **Dnevni izazov + Mapa pogodak** (najmanje novog koda, koriste postojeće pitanje i mapu).
3. Nedeljna liga odmah ili posle izlaska u prodavnice?
4. Osvajanje protiv ljudi: da li je 24 h po potezu dobro ili hoćemo i „brzu partiju” (60 s po potezu, svi online)?
5. Škole: da li ulazimo u priču sa maloletnicima (pristanak roditelja) ili samo 15+?
6. Preduslov za sve: Supabase saobraćaj (402) mora prvo da se reši, inače takmičenja ne mogu da rade.
