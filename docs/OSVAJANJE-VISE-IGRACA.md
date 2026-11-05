# Osvajanje sveta: igra više igrača (timovi, misije, odbrana)

Ažurirano: 02.11.2026 · verzija 3.0 nacrt (po vlasnikovom toku od 02.11)

Dopunjuje [OSVAJANJE-PRAVILA.md](OSVAJANJE-PRAVILA.md) (mapa, vojske, bitka su isti).
Novo: čekaonica sa ljudima, timovi po dvoje, izbor kontinenta, tajne misije kao u Risku,
odbrana kontinenta po izboru, kapiten tima i pitanja koja se nikad ne ponavljaju.

---

## 1. Kontinenti

Mapa ima 17 regiona (bonus vojske ostaje po regionu). Za početak, misije i odbranu
regioni se grupišu u 6 kontinenata:

| Kontinent | Regioni | Država |
|---|---|---|
| Severna Amerika | Severna Amerika, Srednja Amerika i Karibi | 18 |
| Južna Amerika | Južna Amerika | 12 |
| Evropa | Severna, Zapadna, Južna i Istočna Evropa | 38 |
| Afrika | Severna, Zapadna, Centralna, Istočna i Južna Afrika | 50 |
| Azija | Bliski istok, Centralna i Južna, Istočna, Jugoistočna Azija | 46 |
| Okeanija | Okeanija | 7 |

Kontinent je „osvojen” kad igrač (ili tim) drži svaku njegovu državu.

## 2. Načini igre

| Način | Igrača | Kako |
|---|---|---|
| **Jedan na jedan** | 2 | svako za sebe |
| **Timovi** | 4, 6, 8, 10, 12 | timovi po dvoje (2 do 6 timova) |
| **Svako za sebe** | 3 do 6 | bez saveza |
| **Protiv botova** | 1 + 2 bota | kao sada, bez mreže |

Tim deli države, vojske i misiju. Svaki član igra svoj potez (snabdevanje i napadi),
redom: tim A igrač 1, tim B igrač 1, … pa drugi igrači timova.

## 3. Čekaonica (pre partije)

1. Domaćin bira način, broj igrača i dužinu (8 ili 12 krugova), pa dobija kod sobe.
2. Ostali ulaze kodom, iz izazova sa profila (obaveštenje) ili brzim mečom (nasumično).
3. Čekaonica pokazuje: ko je ušao (avatar, nadimak, nivo), slobodna mesta, timove, pravila.
4. Kad su sva mesta puna, kreće odbrojavanje od 10 sekundi. Ako posle 2 minuta mesta
   nisu puna, domaćin može da popuni prazna mesta botovima ili da čeka dalje.
5. **Kapiten tima** je član sa više tačnih odgovora ukupno (statistika na profilu,
   `rezultati_igara`). Pri istom broju, onaj sa više partija. Kapiten je označen krunom.

## 4. Izbor početka

- Redosled izbora je nasumičan, „zmija” (1-2-3-3-2-1) da prvi ne dobije sve najbolje.
- Svaki igrač ili tim bira **kontinent** na kome počinje (jedan kontinent po igraču/timu;
  u partiji od 6 timova svaki dobija svoj).
- Unutar kontinenta bira **prestonicu** (5 vojski); 5 najbližih država dobija po 2 vojske.
- Sat za izbor: 20 sekundi, posle toga bira se nasumično.

## 5. Tajna misija (kao u Risku)

Posle izbora početka svako (tim) dobija jednu tajnu misiju. Vidi je samo on (i saigrač).
Misija se ispunjava odmah kad se uslov stekne; to je pobeda pre kraja krugova.

1. Osvoji Evropu i Južnu Ameriku.
2. Osvoji Evropu i Okeaniju, plus još jedan kontinent po izboru.
3. Osvoji Severnu i Južnu Ameriku.
4. Osvoji Aziju i Južnu Ameriku.
5. Osvoji Afriku i Okeaniju.
6. Osvoji Severnu Ameriku i Okeaniju.
7. Drži 60 država.
8. Drži 45 država sa najmanje 2 vojske u svakoj.
9. Drži 8 regiona istovremeno na kraju svog poteza.
10. Zauzmi prestonice dva rivala.
11. (svako za sebe) Izbaci određenog igrača iz igre; ako ga izbaci neko drugi, misija postaje „drži 60 država”.
12. Odgovori tačno na 25 pitanja u partiji i drži bar 30 država.

Misija ne sme biti nemoguća na početku: ne dodeljuje se misija čiji su oba kontinenta
početni kontinenti drugih igrača u igri od 2 igrača.

**Kraj partije:** prva ispunjena misija pobeđuje odmah. Ako je niko ne ispuni do kraja
krugova, pobeđuje najviše poena (države ×10 + vojske + bonusi regiona ×10 + 20 za svoju
prestonicu, kao sada), a ispunjenost misije u procentima je prvi kriterijum za nerešeno.

## 6. Odbrana kontinenta (strategija)

Kad igrač (tim) osvoji ceo kontinent, bira **jednu odbranu** za taj kontinent. Važi dok
drži kontinent; menja se najviše jednom po krugu, na početku svog poteza. U timu je
bira **kapiten**, saigrač je vidi i ne može da je menja.

| Odbrana | Šta napadač dobija | Cena |
|---|---|---|
| **Brz sat** | 8 sekundi umesto 15 | besplatno |
| **Bez pomoći** | napadač ne sme da koristi pomoć na ovom kontinentu | besplatno |
| **Teško pitanje** | pitanje samo iz teških (hard/impossible) | 1 vojska po krugu |
| **Dva zaredom** | mora tačno na dva pitanja za redom da bi osvojio | 2 vojske po krugu |
| **Tema branioca** | branilac bira oblast pitanja (npr. Knjige, Slikari, Geografija) | besplatno |
| **Tvrđava** | prva bitka svakog kruga na tom kontinentu: branilac gubi vojsku tek posle drugog poraza | 2 vojske po krugu |
| **Zamka** | ako napadač pogreši, gubi 2 vojske umesto 1 | 1 vojska po krugu |

Cena se naplaćuje iz pojačanja na početku poteza vlasnika. Ako nema dovoljno, odbrana
se gasi i prelazi na „Brz sat”.

## 7. Pitanja

- **Nijedno pitanje se ne ponavlja u partiji.** Server vodi listu iskorišćenih ID-jeva
  za celu partiju; svaki napad na Pariz (i bilo koju državu) dobija novo pitanje.
- Snabdevanje, napad i odbrana vuku iz istog fonda bez ponavljanja.
- Kad oboje odgovore tačno, pobeđuje brži (kao sada). Branilac odgovara na isto pitanje
  sa svog telefona; ako ne odgovori u roku, računa se netačno.
- Pomoć: jedna po partiji iz dnevnog fonda (7 za sve igre), osim ako odbrana kaže „Bez pomoći”.

## 8. Šta igrač vidi (info)

- **Kartica misije** (dodir na zastavicu): tekst misije i napredak u procentima.
- **Legenda kontinenata:** ko drži koji kontinent i koju odbranu je izabrao (ikonica na mapi).
- **Pre napada:** koja odbrana štiti metu i šta to znači („Brz sat: imaš 8 sekundi”).
- **Dnevnik bitaka:** ko je koga napao, ishod, osvojene države.
- **Tabla igrača/timova:** države, vojske, regioni, kapiten (kruna), ko je na potezu.
- **Kraj:** pobednik, ispunjena misija, statistika po igraču (tačno, brzina, osvojeno).

## 9. Tehnika (kako to radi)

- Stanje partije vodi server (Supabase): tabele `osvajanje_partije`, `osvajanje_igraci`,
  `osvajanje_potezi`; telefon šalje samo nameru (napadni X iz Y, odgovor, odbrana), a
  server proverava pravila i bira pitanje. Tako niko ne vara i pitanja se ne ponavljaju.
- Promene stižu preko Supabase Realtime kanala (ne pozivom svake sekunde).
- Motor pravila ostaje u `pravila.ts` (i prevodima); server ga koristi kroz Edge funkciju.
- Botovi popunjavaju prazna mesta istim kodom kao u igri protiv botova.
- ⚠ Preduslov: Supabase saobraćaj (402) mora biti rešen pre igre više igrača.

## 10. Redosled izrade

1. Pravila u motoru (kontinenti, misije, odbrane, timovi, pitanja bez ponavljanja) + testovi, igra protiv botova sa novim pravilima (radi bez mreže).
2. Čekaonica i izbor početka sa botovima umesto ljudi.
3. Server: tabele, Edge funkcija, Realtime; ljudi umesto botova.
4. Izazov sa profila i obaveštenja (Firebase).
