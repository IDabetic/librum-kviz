# Osvajanje: strategija (vojske, karte, savezi, događaji, misije)

Ažurirano: 04.11.2026. · verzija 5 · kod: `Osvajanje/Strategija.swift`, `Strategija2.swift`, `Pravila.swift` (iOS); Android sledi posle odobrenja iOS-a · testovi `StrategijaTests`

Vlasnik 03.11.2026: Osvajanje je i kviz i strategija; ishod ne zavisi samo od tačnih odgovora.

## Bitka

- Uvod bitke (vlasnik 04.11): napadač prvo bira temu (10 s, inače mešano), pa zanimljivosti o državi stoje **7 s** (bez zanimljivosti 3 s).
- Pitanje traje **20 s** (`Pravila.sekundiPoPitanju`); odbrana „Brz sat” ga skraćuje na 8 s.
- **Vojska daje prednost** u bitki sa igračem: `(vojske u izvoru − 1) − vojske mete`, najviše ±2 tačna.
  Primer: 5 vojski u izvoru (4 napadaju) protiv 1 je +2, pa braniocu trebaju 3 tačna više.
- **Neutralna država:** sa 3 ili više vojske u napadu greška ne košta vojsku.
- Pobeda: `tačni napadača − tačni branioca + prednost ≥ 1` (uz odbranu „Prednost” ≥ 2); kod 0 odlučuje brzina
  (`Stanje.osvaja`, isto pravilo i na telefonu branioca).

## Vrste vojske (bira se pre partije, pamti se)

| Vojska | Prednost | Ko je bira od botova |
|---|---|---|
| Legija | +1 tačan kad napada igrača | napadač |
| Garda | +1 tačan kad brani | oprezan |
| Graditelji | +1 vojska po krugu za svaki ceo region | graditelj |
| Izvidnica | počinje sa Špijunom, karta i za svako drugo osvajanje zaredom | graditelj |
| Konjica | 2 napada više po potezu | napadač |
| Mudraci | +5 s po pitanju u bitki | oprezan |

Legija i Konjica se poklapaju (napad), Garda i Graditelji (odbrana i rast). U timu važi kapitenova vojska.
Preko servera svako bira vojsku u čekaonici (`osvajanje_izaberi_vojsku`, kolona `osvajanje_mesta.vojska`), pa domaćinov telefon pravi početno stanje sa pravim izborom (bag 04.11: gost je dobijao vojsku kao bot). Dodir na vojsku ispisuje njenu prednost i tri pomoći (`MociVojske`).

## Ratne karte (umesto dnevnih pomoći)

- Dobijaju se: pobeda nad igračem (i u odbrani), zatvoren region, proboj (3 osvajanja zaredom); u ruci najviše 5.
- Vrsta karte zavisi od kruga, bitke i tima, pa je ista na svakom telefonu.

| Karta | Gde | Šta radi |
|---|---|---|
| Špijun | uvod bitke | tačan odgovor na prvo pitanje te bitke (vlasnik 03.11) |
| Pojačanje | mapa | +2 vojske na izabranu svoju državu (ili prestonicu) |
| Zamrzni granicu | mapa | državu niko ne napada do kraja sledećeg kruga |
| Drugi pokušaj | pitanje | menja pitanje novim, bez odgovora |
| Sabotaža | napad na igrača | protivnik gubi jedan tačan |

Bot: Pojačanje na najugroženiju granicu, Zamrzni na prestonicu pod pretnjom (≥ 4), Drugi pokušaj i Sabotaža u bitki sa igračem.

## Savezi i brze poruke

- Dodir igrača otvara brze poruke („Napadam te!”, „Savez?”, „Bravo!”, „Čuvaj se!”, „Hvala!”, „Osveta!”); oblačić stoji 6 s.
- „Savez?” je predlog: savez nastaje kad i druga strana predloži (ili bot prihvati) i traje do kraja sledećeg kruga.
  Saveznici se ne napadaju.
- Bot prihvata kad predlagač nije njegov najjači rival (oprezan uvek), i kad već nema dva saveza.
- Bot sam traži savez sa susednim botom kad neko ima 1,4 puta veću snagu od njega.
- Preko servera poruke i savezi idu samo na svom potezu (stanje šalje igrač na potezu).

## Događaji po kontinentima

Na početku kruga 4, 8, 12 bira se kontinent iz igre (isto na svakom telefonu); događaj traje 2 kruga.

| Kontinent | Događaj | Pravilo |
|---|---|---|
| Evropa | Zima | napadaču u Evropi treba jedan tačan više |
| Afrika | Zlatno doba | ceo region u Africi daje duplo vojske |
| Azija | Monsun | države u Aziji ne mogu da se napadnu |
| Severna Amerika | Zlatna groznica | osvojena država daje +1 vojsku |
| Južna Amerika | Karneval | pitanja u bitkama traju 10 s duže |
| Okeanija | Cunami | države gube pola vojske (jednom, na početku) |

## Tajne misije

30 misija (i „tri čuda”, „tri pohoda”) (kontinenti, regioni, države, vojske, prestonice, tačni odgovori, dobijene bitke). Misije koje je igrač
imao u poslednjih 7 dana (`MisijeIstorija`, na telefonu) idu na kraj reda; ponavljaju se tek kad ponuda ponestane.

## Kraj partije

- Tabela: države, vojske, tačni, dobijene bitke, poeni.
- XP po mestu: 1. +150, 2. +80, 3. +40, ostali +20, pobeda još +50.
- „Pogledaj kako se svet menjao” pušta mapu kroz sve promene vlasnika.
- Partija na telefonu se čuva na svakom potezu; „Nastavi partiju” stoji na početnoj dok partija nije gotova.

## Izgled na mapi

Strela i krug udara posle svake bitke (zelen = osvojeno, crven = odbranjeno), „+2”/„−1” iznad države kad se
vojska promeni, region zasvetli u boji vlasnika kad se zatvori.

## Drugi talas (v2): mapa, bitka, kretanje, diplomatija

| Pravilo | Kako radi | Bot |
|---|---|---|
| Teren | planine (CHE, AUT, NPL, BTN, BOL, PER, GEO, ARM, AZE, AFG, KGZ, TJK): branilac +1; morski put: napadač −1; pustinja: poraz −1 vojska više | ulazi u šansu bitke (`pomakBitke`) |
| Linije snabdevanja | države bez puta do prestonice: bez pojačanja, −1 vojska po krugu; tim bez prestonice snabdeva najveća grupa | raspoređuje samo u snabdevene |
| Čuda sveta | EGY Piramide +2 vojske, CHN Kineski zid +1 odbrana u Aziji, GRC Akropolj karta po krugu, PER Maču Pikču bez magle, USA Kip slobode +1 napad, AUS Opera +5 s | čudo vredi +2,5 u izboru mete |
| Magla rata | tuđe daleke države: procena ≤2 / 3–5 / 6+; svoje, saveznikove i susedne tačno | botovi vide sve |
| Izbor teme | napadač bira jednu od 3 teme koje u špilu imaju dovoljno pitanja; odbrojavanje 7 s | — |
| Povlačenje | bitka od 5 pitanja, posle 2. odgovora: vojska ostaje, potez se završava | oprezan bot se povlači posle dve greške |
| Ulog | 0–2 pre bitke sa igračem: pobeda +u u osvojenoj, branilac −u iz najjače susedne; poraz −u napadaču | šansa > 0,7 → 1, > 0,85 → 2 |
| Marš | jednom po potezu, do 3 koraka kroz svoje države (zamenio „Utvrdi”) | bot i dalje utvrđuje susednu granicu |
| Najava pohoda | tajni region; ceo na početku sledećeg poteza: +3 vojske i karta | najavljuje region kome fale 1–2 države |
| Izdaja | napad na saveznika uz potvrdu: savez pada, izdajnik gubi karte, oznaka, botovi ga odbijaju | napadač bot izdaje upola slabijeg saveznika u poslednja 2 kruga |
| Trgovina | sa saveznikom: daješ kartu, dobijaš onu koju nemaš; bot prihvata kad tu kartu nema | — |
| Ultimatum | jednom po potezu, slabijem susedu: predaje (snaga < 0,6, nije prestonica) ili +1 tačan napadaču do kraja poteza | botovi šalju slabim botovima |

Ograničenja: ultimatum i trgovina rade sa botovima (pravi igrač sa drugog telefona još nema dijalog za odgovor);
bot se ne povlači usred bitke sa čovekom koji brani, jer bot odgovara odmah.

## Partija na poziv (v2)

- „Pozovi prijatelje” u uvodu Osvajanja: privatna soba sa kodom od 6 znakova (`osvajanje_napravi_sobu`), isti način i broj igrača kao izabrani.
- Ulaz: polje „Kod sobe od prijatelja”, link `librumkviz://osvajanje/KOD` ili poruka iz aplikacije (lista: koje pratiš i sa kim si se dopisivao, `osvajanje_za_poziv`).
- Čekaonica (`PozivView`): kod, mesta za stolom po timovima, „Počni partiju” samo za domaćina (bar 2 čoveka); prazna mesta su botovi.
- Javno traženje igrača ne ulazi u privatne sobe. Server: `scripts/2026-11-03_osvajanje-privatne-sobe.sql`.
- Ograničenje: vrsta vojske gostiju zasad se dodeljuje kao botovima (soba još ne prenosi izbor); domaćin bira svoju.

## Posle prvog testa vlasnika (v3)

- **Mapa:** Francuska Gvajana uklonjena iz Francuske (parče u Južnoj Americi nije moglo da se napadne); Trinidad i Tobago
  morem povezan sa Portorikom (u partiji na Severnoj Americi nije imao suseda). `alati/popravi-mapu.py` i `napravi-mapu.mjs`;
  test `testSvakiKontinentPovezan` proverava svaki kontinent.
- **Pomoći vojske** (`PomocVojske`): tri po vojsci, svaka jednom po krugu (`pomociVojske` u stanju). Dejstva: 50/50, skloni jedan
  netačan, +10 s (Razmišljanje +15), novo pitanje, „dvostruko” (sledeći tačan u napadu vredi dva: Juriš, Galop), „štit”
  (jedna greška u bitki je tačan: Garda). Dnevne pomoći u Osvajanju ne važe.
- **Raspoređivanje:** pojačanja igrač stavlja sam (dodir po državi, samo snabdevene); sat poteza teče, a istek raspoređuje ostatak.
- **Dužina i misije:** 12 / 20 / 30 krugova, podrazumevano po broju igrača (≤3: 12, 4: 20, 5+: 30). Pragovi misija sa
  državama, regionima i vojskama množe se sa `3 / broj strana` (najmanje pola), i tekst misije pokazuje pravi broj.

## Izmene 04.11.2026 (vlasnik)

- **Postavka pre prvog kruga, redom:** pravi igrači (prvi iz svakog tima) jedan po jedan biraju 6 država i raspoređuju vojsku, ostali gledaju uživo (`Stanje.cekaPostavku`). Domaćin čeka igrača sa drugog telefona najviše 120 s, pa ide dalje sa početnim državama.
- **Tajna misija iz okrenutih karata:** posle izbora država igrač prevlači 6 okrenutih karata i dodirom okreće jednu (`KarteMisijaView`). Ponuda je nasumična iz svih dozvoljenih misija (bez tuđih, skorašnje na kraju) i nasumično poređana: od 30 misija to je preko pola miliona rasporeda.
- **Timovi po izboru:** domaćin dodirom na „Tim X” pored mesta sastavlja strane (npr. ja i prijatelj protiv botova, ja i bot protiv prijatelja i bota); server `osvajanje_postavi_timove`, lokalno isto u čekaonici. Redosled poteza se smenjuje po timovima, kapiten je prvi pravi igrač tima.
- **Brze poruke idu odmah** (akcija „poruka”), i kad igrač nije na potezu; vide ih svi, oblačić na vrhu ekrana 6 s. Savez i dalje samo na svom potezu (menja stanje).
- **Tuđi odgovori:** u partiji sa pravim igračima svaki odgovor u bitki ide ostalima (akcija „odgovor”): pitanje, izabrani odgovor i tačno/netačno, bez pomoći.
- **Pomoći vojske vidljive:** Siguran udar prikazuje izabrani odgovor zeleno („računa se kao tačan”), Štit javlja da je greška obrisana.
- **Pauza:** samo u partiji bez pravih igrača; sat poteza i botovi čekaju.
- **Kamera:** na početku mog poteza mapa uokviruje moje države.
- **Mapa:** države manje od 70 jedinica (ostrva) imaju krug u boji vlasnika; morske veze deblje i tamnije, duge (Brazil–Senegal, Aljaska–Rusija) imaju natpis sa imenom druge obale.
- **Uvod:** prvo „Protiv koga” (računar, prijatelji, mreža), dugme za start uvek dole; radnje u potezu su ikonice (Marš, Pohod, Misija) + „Kraj poteza”.

## Izmene 04.11.2026 uveče (vlasnik odobrio)

- **Kontranapad:** ko odbrani državu sa 3+ tačna (i preuzme državu napadača), na sledećem svom potezu ima napad više i +1 prednost iz te države (`Stanje.kontranapad`, `Pravila.tacnihZaKontranapad`).
- **Opsada prestonice:** drugi neuspeli napad zaredom na prestonicu daje braniocu ratnu kartu; pad prestonice briše opsadu (`Stanje.opsada`).
- **Stalni savez ili zajedno:** isti tim u čekaonici bira „Zajedno” (jedna boja, jedna vojska, deljene države) ili „Savez” (svako svoja boja, vojska i države; ne napadaju se, nema izdaje, pobeđuju zajedno). `Stanje.strane`, server `osvajanje_sobe.savez` + `osvajanje_postavi_savez`.
- **Savezničko pojačanje:** jednom po krugu, na svom potezu, 2 vojske sa svoje države (3+) na saveznikovu susednu; dugme u listu saveznika, bot pomaže slaboj granici.
- **Profil:** svaka partija Osvajanja upisuje način (sam, savez, zajedno, `rezultati_igara.nacin`); profil igrača pokazuje najčešći način i brojke (`profil_igraca.osvajanje_nacin`).
- **Vodič za prvu partiju:** kartica pri dnu vodi kroz izbor država, raspored, napad i kraj poteza dok se ne završi prvi krug; „×” ga preskače (`osvajanje.vodicGotov`).
- **„Šta da radim?”** (sijalica): jednom po potezu predlaže najbolji napad (isti mozak kao bot, bez šuma) ili raspored na granice.
- Slikari: izbačena dela 16 autora umrlih posle 1955 (50 slika, autorska prava); alat `slikari-iz-baze.py` ih preskače (`ZASTICENI`).

## Izmene 04.11.2026 kasno uveče (vlasnik odobrio „da cepaj”)

- **Misije:** 62 (bilo 30). Pragovi zavise od broja strana i od dužine (12 krugova = puno smanjenje, 30 = bez smanjenja). Misija pobeđuje tek kad je tim drži do početka svog sledećeg poteza (`Stanje.misijaOd`); svi vide crvenu traku „X je ispunio misiju, zaustavi ga”.
- **Moći vojske:** 18 različitih, po tri na vojsku, nijedna se ne ponavlja (Legija: Siguran udar, Drugi pokušaj, Plen; Garda: Štit, Bedem, Garnizon; Graditelji: Radionica, Utvrđenje, Temelj; Izvidnica: Nagoveštaj, Prisluškivanje, Špijunska mreža; Konjica: Juriš, Munja, Promena pitanja; Mudraci: Tačan odgovor, Jedan manje, Savet mudraca). Efekti na ishod idu uz `Skor.efekti`.
- **Ratne karte za niz:** 2 osvojene države u potezu i 3 dobijene bitke zaredom; nova karta iskoči i okrene se; dugme „Karte” sa brojem i opisima.
- **Saveznici:** jedan saveznik, do raskida ili izdaje (od prvog kruga iz čekaonice ili u igri). Raskid: važi do kraja kruga, novi saveznik posle kruga. Izdaja: bez karata, dva kruga bez moći vojske i bez pomoći saveznika, broji se na profilu (`rezultati_igara.izdaja`, „Nož u leđa” / „Veran saveznik”). Zamena misija sa saveznikom do 5. kruga. „Traži pomoć”, a stigla pomoć se vidi kao kartica i strelica na mapi.
- **Legenda (?)** objašnjava krunu, zvezdicu (čudo), krug ostrva, morske veze, ivice, maglu i sva čuda.
- **Vreme:** tema 5 s, zanimljivosti 5 s; zvuk upozorenja na 5 sekundi (pitanje i rok poteza).
- **Savet** ne otvara list: strelica i boja na mapi, traka „Napadni X iz Y” sa dugmetom.
- **Siguran udar:** izbor pocrveni, tačan pozeleni, pa izbor pozeleni („Priznato”).
- **Nova partija** vodi na podešavanje. **Izbor kontinenta** je mala mapa sa redosledom imena.
- **Živost:** kombo ×N, ceo region i pala prestonica sa konfetama, „Tvoj potez!”, tresenje ekrana kad izgubiš državu, poeni se vrte, prelazi u bitki.

## Izmene 04.11.2026 noću (vlasnik)

- **Obilazak na početku partije** (`Osvajanje/Obilazak.swift`): 13 koraka, zatamnjen ekran sa žutim okvirom i strelicom na delu koji se objašnjava (igrači, krug, mapa, sat, misija, legenda, savez, pauza, izlaz) i kartica sa Dalje/Nazad. X ga uvek gasi; ponavlja se iz legende („Ponovi vodič kroz igru”). Delovi ekrana se obeležavaju sa `.ciljObilaska(...)`.
- **Vodič dole** se vraća u svakoj partiji tokom prvog kruga (i u partiji sa igračima); X ga skriva samo za tu partiju.
- **Svaki donji list ima X** gore desno (`DonjiList`).
- **Izlaz iz partije gasi sve**: `OsvajanjeModel.napusti()` zaustavlja botove, sat poteza i zvuke (`Zvuk.staniSve`).
- **Savet samo kaže**: sijalica više ne raspoređuje vojsku i ne bira metu. Traka gore piše šta i gde, strelica je na mapi, a igrač sam dodiruje (`OsvajanjeModel.Predlog`).
- **Upozorenje na 5 s**: dvotonska sirena, četvrtasti talas, ujednačena na −10 dBFS RMS (`alati/zvuci.py`, `GLASNIJE`).
- **Sam / Savez / Zajedno protiv računara**: na podešavanju, sekcija „Tvoj saveznik” (`OsvajanjeUvodView.primeniSaveznika`). U igri dugme sa lancem gore otvara pravila saveza i predlog svakom rivalu, a sa saveznikom pomoć, zamenu misije i raskid.
