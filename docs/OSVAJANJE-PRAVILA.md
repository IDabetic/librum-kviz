# Osvajanje sveta — pravila

Ažurirano: 02.11.2026 · verzija 2.0 (mapa po državama)

Glavna igra Librum kviza. Strateška igra na mapi sveta u kojoj svaku bitku
odlučuje pitanje. Žanr je isti kao kod ConQUIZtadora i Riska (teritorije +
kviz), ali pravila su naša: vojske po oblastima, kontinenti sa bonusom i
**proboj** — posle osvajanja napadaš dalje iz osvojene oblasti.

Jedan izvor istine za pravila je `src/lib/osvajanje/pravila.ts`. iOS
(`mobile/ios/…/Pravila.swift`) i Android (`mobile/android/…/Pravila.kt`) su
verni prevodi istog fajla; kad se ovde nešto menja, menja se na sva tri mesta
i u testu `tests/osvajanje.test.mjs`.

## Mapa

Prava mapa sveta: **171 država** iz Natural Earth 1:50m (javno dobro), u 17
regiona sa bonusom kao kontinenti u Risku (Severna Evropa, Južna Evropa,
Južna Amerika, Bliski istok…). Susedi su države sa kopnenom granicom, plus
morske veze (SAD–Rusija, Velika Britanija–Francuska, Španija–Maroko, Brazil–
Senegal, ostrva ka najbližim državama). Kosovo je deo Srbije, Severni Kipar
deo Kipra, Somalilend deo Somalije.

Mapu pravi `alati/napravi-mapu.mjs` u `src/lib/osvajanje/svet.json`; isti fajl
koriste iOS i Android. Bonus regiona = trećina broja država, najmanje 2.

## Početak

- Igraju tri igrača: ti i dva rivala (Mimi i Zig), tri jačine botova.
- Svako dobija **prestonicu** (5 vojski) u drugom regionu i još **5 najbližih
  država** (po 2 vojske). Sve ostale države su neutralne sa 1 vojskom.
- Partija traje **8 ili 12 krugova**.

## Potez

1. **Snabdevanje.** Jedno pitanje. Tačno: dobijaš
   `max(3, države / 3) + bonusi regiona` vojski. Netačno: pola toga
   (najmanje 1). Vojske raspoređuješ dodirom po svojim oblastima.
2. **Napad.** Biraš svoju oblast sa bar 2 vojske i susednu tuđu ili
   neutralnu oblast. Bitka je jedno pitanje od 15 sekundi.
   - Protiv **neutralne**: tačno → braniocu −1; netačno → napadaču −1.
   - Protiv **igrača** odgovaraju oba:
     - samo napadač tačno → branilac −2
     - samo branilac tačno → napadač −2
     - oba tačno → brži odgovor pobeđuje, poraženi −1
     - oba netačno → oba −1
   - Kad branilac ostane bez vojske, oblast je tvoja: u nju prelaze sve
     vojske napadačke oblasti osim jedne.
   - **Proboj:** posle osvajanja izabrana oblast postaje osvojena, pa možeš
     odmah da „cepaš dalje” iz nje. Svako treće osvajanje u nizu donosi
     **+2 vojske** na mestu proboja.
   - Najviše **8 bitaka** po potezu, da potez ostane kratak.
3. **Utvrđivanje.** Jednom po potezu možeš da prebaciš vojske između dve
   susedne svoje oblasti (u izvoru ostaje bar 1).

## Prestonica

Ko osvoji tuđu prestonicu, dobija **+5 vojski plena**. Igrač bez ijedne
oblasti ispada iz partije.

## Kraj i poeni

Partija se završava posle poslednjeg kruga ili kad jedan igrač drži sve
oblasti koje nisu neutralne, a ostali su ispali.

Poeni = `države × 10 + vojske + bonus regiona × 10 + 20 ako držiš svoju prestonicu`.

## Pitanja

Igra uzima nasumičan paket pitanja (RPC `osvajanje_pitanja`) jednom na početku
partije, umesto da povlači celu bazu. U aplikacijama se paket kešira.

## Šta namerno NIJE kao kod drugih

- Nema kula/tornjeva na prestonici, nema procenjivanja broja kao razrešenja.
- Mapa je ceo svet po državama, ne jedna zemlja po oblastima.
- Vojske i proboj umesto fiksne vrednosti teritorije.
