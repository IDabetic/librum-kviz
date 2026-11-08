# Igre reči

Ažurirano: 08.11.2026 · v1

Šest dnevnih igara u aplikaciji (iOS `mobile/ios/LibrumKviz/IgreReci/`, Android `mobile/android/.../reci/`):
Premetaljka, Pet slova, Lanac, Šifra, Mini ukrštenica, Zmija. Ista zagonetka za sve igrače po beogradskom danu,
rang lista dana, niz rešenih dana. Unos ide tastaturom telefona (vidljivo polje), ne tastaturom u igri.

## Težina
- Dnevne: pon–uto lako, sre–pet srednje, sub–ned teško (`tezina_dana` u generatoru).
- Igra sa drugima („Igraj sa drugima”, sobe `takmicenja`): domaćin bira težinu; zagonetka je nasumična iz `igre_reci_izazovi`
  (oko 120 po igri i težini). Rok: Premetaljka 3 min, Pet slova i Lanac 4, Zmija 5, Šifra i Ukrštenica 6.
  Brzina donosi do rok/6 poena, pomoć skida 5. Botovi su isti na iPhonu i Androidu (test `otisakBotova` / `testBotIstiKaoAndroid`).

## Generator
```bash
python3 alati/igre_reci.py recnik
python3 alati/igre_reci.py zagonetke 2026-11-08 181
python3 alati/igre_reci.py izazovi 120
python3 alati/igre_reci.py provera
```
Izvori: srLex (`../Claude/librum-gram/data`), Vešanje (`alati/igre_reci_vesanje.json`), teme Zmije (`alati/igre_reci_teme.json`).

## Baza
`scripts/2026-11-08_igre-reci.sql`, `scripts/2026-11-08_igre-reci-takmicenje.sql`. Uvoz JSON-a ide preko pg_net
(push na GitHub, pa `net.http_get` na raw adresu); tačni upiti su na dnu oba SQL fajla. Server sam ocenjuje rešenje
(`igre_reci_zavrsi`); u Lancu postojanje reči proverava aplikacija.
