# Osvajanje: kako bot razmišlja

Ažurirano: 03.11.2026. · verzija 2 · kod: `Pravila.swift` (iOS) i `Pravila.kt` (Android), odeljak „Mozak bota”, testovi `BotTests` / `BotTest`

Bot igra po istim pravilima kao čovek. Na pitanja odgovara sa tačnošću koju daje težina
(lako 50%, normalno 55%, teško 75%), a pri tome odlučuje u pet koraka.

## 1. Koga cilja

- **Svi ravnopravno** (vlasnik 03.11, v2): cilj je najjači **sused** koji nije saveznik, bio on čovek ili bot;
  kad bot nema suseda, cilj je najjači rival na mapi. Zato se botovi kolju i međusobno.
- Snaga: `države + vojske × 0,5 + bonus celih regiona × 3`. Države cilja vrede +1,5, njegove vojske su pretnja ×1,5.
- Bot koristi ratne karte i traži saveze (docs/OSVAJANJE-STRATEGIJA.md).

## 2. Narav (stalna po igraču, ista na svakom telefonu)

| Narav | Kako igra | Prag napada | Posebno |
|---|---|---|---|
| Napadač | napada i kad je za malo isplativo | 0,10 | — |
| Graditelj | zatvara regione | 0,25 | regioni mu vrede ×1,4 |
| Oprezan | čuva vojsku i prestonicu | 0,50 | gubitak mu teži ×1,3 |

## 3. Raspored vojske (početak poteza)

Svaka vojska ide na **graničnu** državu sa najvećom ocenom:
`pretnja suseda − 0,6 × vojske u državi`. Dodaje se +3 ako odatle može da zatvori region
(fali mu jedna država) i +1,5 za prestonicu. Pretnja je zbir tuđih vojski u susedstvu,
a vojske cilja broje ×1,5.

## 4. Izbor bitke: šansa × dobitak − rizik

Za svaki mogući napad bot računa:

**Šansa (p)**
- Neutralna država (jedno pitanje): p = tačnost bota.
- Država igrača (5 pitanja): tačna binomna verovatnoća da bot ima više tačnih od branioca.
  Kod jednakog broja odlučuje brzina, pa se računa pola-pola. Odbrana „Prednost” traži 2 tačna
  više. Za čoveka bot pretpostavlja 65% tačnih, a za bota njegovu tačnost. U šansu ulazi i
  prednost vojske, Legije, Garde i Zime u Evropi (`pomakBitke`).

**Dobitak** (u „državama”)
- 1 za samu državu;
- region koji se zatvara: bonus × 1,5; region koji se gradi: bonus × 0,3 / broj država koje fale;
- tuđi ceo region koji se ruši: bonus × 1,2;
- tuđa prestonica: +3 (donosi plen od 5 vojski);
- država cilja: +1,5;
- kontinent iz moje tajne misije: +0,8.

**Gubitak**
- Neutralna država: 0,5 (jedna vojska); 0 kad napada sa 3 ili više vojske.
- Država igrača: poraz odnosi i državu iz koje se napada sa preživelim vojskama, pa gubitak =
  `1 + (vojske u izvoru − 2) × 0,4`. Ako je izvor prestonica +4, a ako je izvor deo celog
  regiona, dodaje se još bonus tog regiona.

**Ocena** = `p × dobitak − (1 − p) × gubitak`. Bot bira najbolju ocenu iznad praga svoje naravi.
Kad nijedna nije iznad praga, prestaje da napada. Zato slab bot ne udara iz prestonice na igrača
koga ne može da pobedi.

## 5. Greške (da bot ne bude mašina)

Pre izbora bot sa verovatnoćom **35% (lako), 12% (normalno), 0% (teško)** uzima nasumičan
napad među onima koji nisu očigledno loši (ocena > −1). Šum je vezan za krug, igrača i redni
broj bitke, pa isti potez ispada isto na svakom telefonu.

## 6. Kraj poteza

- **Utvrđivanje:** vojska iz unutrašnjosti (država bez tuđih suseda) prelazi na najugroženiju
  susednu granicu; u izvoru ostaje jedna.
- **Odbrana kontinenta** (kapiten, jednom po krugu): ako cilj ili jak rival preti kontinentu
  (pretnja ≥ 4 na nekoj državi), bira „Prednost”, inače „Brz sat”.

## Testovi

- šansa bitke: jednaki igrači 50%, jači preko 70%, „Prednost” smanjuje šansu;
- botovi ciljaju najjačeg suseda, čoveka ili bota ravnopravno;
- bot zatvara region kad mu fali jedna država;
- bot sa slabim znanjem ne napada igrača iz svoje prestonice (ocena < 0);
- cela partija botova se završava bez greške.
