# Osvajanje sveta — pravila

Ažurirano: 02.11.2026 · verzija 1.0

Glavna igra Librum kviza. Strateška igra na mapi sveta u kojoj svaku bitku
odlučuje pitanje. Žanr je isti kao kod ConQUIZtadora i Riska (teritorije +
kviz), ali pravila su naša: vojske po oblastima, kontinenti sa bonusom i
**proboj** — posle osvajanja napadaš dalje iz osvojene oblasti.

Jedan izvor istine za pravila je `src/lib/osvajanje/pravila.ts`. iOS
(`mobile/ios/…/Pravila.swift`) i Android (`mobile/android/…/Pravila.kt`) su
verni prevodi istog fajla; kad se ovde nešto menja, menja se na sva tri mesta
i u testu `tests/osvajanje.test.mjs`.

## Mapa

24 oblasti u 6 kontinenata. Veze su nacrtane linijama (i preko mora:
Aljaska–Sibir, Kanada–Skandinavija, Brazil–Zapadna Afrika).

| Kontinent | Oblasti | Bonus po potezu |
|---|---|---|
| Severna Amerika | Aljaska, Kanada, SAD, Meksiko | +3 |
| Južna Amerika | Kolumbija, Peru, Brazil, Argentina | +2 |
| Evropa | Skandinavija, Zapadna Evropa, Srednja Evropa, Balkan | +3 |
| Afrika | Severna, Zapadna, Istočna, Južna Afrika | +3 |
| Azija | Sibir, Bliski istok, Indija, Kina, Japan | +4 |
| Okeanija | Indonezija, Australija, Novi Zeland | +2 |

## Početak

- Igraju tri igrača: ti i dva rivala (Mimi i Zig). Rivali su botovi tri
  jačine: lako (50% tačnih), normalno (62%), teško (75%).
- Svako dobija **prestonicu** na drugom kontinentu sa 4 vojske.
- Sve ostale oblasti su neutralne sa po 1 vojskom.
- Partija traje **10 krugova** (brza partija 6). U krugu svako igra jedan potez.

## Potez

1. **Snabdevanje.** Jedno pitanje. Tačno: dobijaš
   `max(3, oblasti / 2) + bonusi kontinenata` vojski. Netačno: pola toga
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
   - Najviše **6 bitaka** po potezu, da potez ostane kratak.
3. **Utvrđivanje.** Jednom po potezu možeš da prebaciš vojske između dve
   susedne svoje oblasti (u izvoru ostaje bar 1).

## Prestonica

Ko osvoji tuđu prestonicu, dobija **+5 vojski plena**. Igrač bez ijedne
oblasti ispada iz partije.

## Kraj i poeni

Partija se završava posle poslednjeg kruga ili kad jedan igrač drži sve
oblasti koje nisu neutralne, a ostali su ispali.

Poeni = `oblasti × 10 + vojske + bonus kontinenata × 10 + 20 ako držiš svoju prestonicu`.

## Pitanja

Igra uzima nasumičan paket pitanja (RPC `osvajanje_pitanja`) jednom na početku
partije, umesto da povlači celu bazu. U aplikacijama se paket kešira.

## Šta namerno NIJE kao kod drugih

- Nema kula/tornjeva na prestonici, nema procenjivanja broja kao razrešenja.
- Mapa je ceo svet po kontinentima, ne jedna država.
- Vojske i proboj umesto fiksne vrednosti teritorije.
