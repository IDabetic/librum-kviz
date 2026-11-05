# Pregled aplikacije i predlozi (05.11.2026)

Ažurirano: 05.11.2026. · verzija 2 (grad i pretraga urađeni, vidi KARIJERA-PRAVILA §19) · grana `redizajn-quizpop`

Ovo je samo predlog. Ništa iz ovog dokumenta nije urađeno: vlasnik bira šta ide, pa se onda gradi.

## 1. Šta fali (rupe koje igrač oseti)

| # | Šta | Zašto je bitno | Veličina |
|---|-----|----------------|----------|
| 1 | **Obaveštenja sa servera (push)** na oba telefona: izazov za firmu, otkaz bota, duel, komentar, poruka | Bez njih igrač ne zna da ga neko napada i izgubi firmu bez borbe. Kod postoji; fale Firebase/APNs ključevi i funkcija `obavesti` | srednje |
| 2 | ✔ 05.11 **Pretraga firmi** po imenu, poziciji i nivou, plus filter „može da se napadne” | Sa 300+ firmi skrol ne radi. Kratko rešenje pre mape (tačka 3) | malo |
| 3 | ✔ 05.11 (faze 1–3) **Mapa grada** za Karijeru (vlasnikova ideja, opis ispod) | Glavni način da se nađe firma i oseti da grad živi | veliko |
| 4 | **Prijava netačnog pitanja** u Karijeri (zastavica već postoji u ostalim igrama) | 24.911 novih pitanja struke nije niko proverio | malo |
| 5 | **Sanduče sa servera** za Karijeru: „Firmu X napao je Y”, „Bot je dao otkaz”, „Probni rad položen” | Danas te poruke postoje u bazi (`karijera_dogadjaj`), ali ih igrač vidi samo kad otvori Karijeru | malo |
| 6 | **Automatska objava u Igračima** za velike trenutke: položen probni rad, nov nivo zgrade, osvojena firma (uz prekidač u Podešavanjima) | Igrači vide da se nešto dešava, više ulazaka | malo |
| 7 | **Dnevni zadaci Karijere** (3 mala cilja dnevno: npr. 7/10 u struci, jedna runda bez pomoći) sa nagradom u kasi | Razlog da se vrati svaki dan, pored niza | srednje |
| 8 | **Sezona** (mesec dana): rang firmi se zatvara, prve tri dobijaju trofej u CV-u | Takmičenje bez kraja dosadi | srednje |
| 9 | **Poziv prijatelja u moju firmu linkom** (`kviz.librum.club/firma/ID`) | Najjeftiniji rast: igrač dovodi igrača | malo |
| 10 | **Vibracija** uključi/isključi u Podešavanjima | Neko igra u tišini na poslu | malo |

## 2. Prodavnice (pre slanja)

Iz provere 03.11 i dalje treba proveriti: demo nalog za Apple pregled, gost bez naloga (Apple traži da igra radi i bez prijave),
odjava „Prijava preko Apple” (revoke) ako se doda Apple prijava, brisanje naloga i preko veba. Android: Play konzola,
SHA-1 za Google prijavu.

## 3. Mapa grada za Karijeru (vlasnikova ideja, samo predlog)

**Ideja:** umesto spiska, grad gledan odozgo kao SimCity. Prstima se pomera i zumira. Svaka firma je zgrada na svojoj parceli
(veličina po nivou: garaža, kuća, zgrada, kula, neboder). Ulicama voze automobili, staju na semaforima, pešaci idu trotoarom,
ponekad prođe hitna ili policija sa sirenom (zvuk samo ako je uključen). Iznad zgrade se povremeno digne balončić kao dim iz
dimnjaka: „+20 poena”, „Novi rekord”, „Traži zaposlene”, „Napadnuta!”. Dodir na zgradu otvara karticu firme (zaposli se, izazovi,
CV vlasnika).

**Kako bi radilo:**
- Grad je mreža blokova. Server svakoj firmi pri otvaranju dodeli parcelu (kolona `parcela` u `karijera_firme`), kvartovi po
  delatnosti (IT kvart, pravni kvart, medicina…). Korporacija je u centru.
- Aplikacija traži samo firme u delu grada koji se vidi (upit po pravougaoniku parcela, indeks), pa radi i sa 3.000 firmi.
- Saobraćaj i ljudi su ukras koji se računa na telefonu i ne ide preko servera.
- Balončići dolaze iz istih događaja koje već pišemo (`karijera_dogadjaj`), samo za firme na ekranu.
- Crtanje: iOS SpriteKit, Android Canvas u Compose; zgrade su postojeće slike (ravan crtež spreda), pa bi za mapu trebao novi
  set slika **odozgo, pod uglom** (to je izometrija koju je vlasnik ranije odbio za kartice; za mapu bi bila druga stvar).
- Pretraga (tačka 2) ostaje: „Nađi firmu” centrira mapu na tu zgradu.

**Faze:** (1) statična mapa sa zgradama i dodirom, (2) balončići iz događaja, (3) saobraćaj, pešaci, semafori, sirene,
(4) kvartovi i parcele koje se kupuju (strategija: bolja lokacija, više prometa).

**Rizik:** najveći posao do sada u Karijeri (nov set slika, dve platforme, performanse na starijim telefonima). Predlog je
da prvo ide pretraga (tačka 2), a mapa kad bude stvarno 100+ igrača sa firmom.

## 4. Male stvari primećene usput

- Činjenice o državama (Osvajanje) su suve (glavni grad, valuta); priprema runde Karijere sada ima posebne zanimljivosti
  (`src/lib/igre/zanimljivosti.json`, 94 komada); mogu da se koriste i u ostalim igrama na čekanju.
- Ponuđeni odgovori u opštem fondu su imali navodnike (1.704 pitanja, očišćeno 05.11, kopija u `questions_navodnici_kopija`).
  Uvoz novih pitanja treba da ih skida automatski (`alati/uvoz-pitanja.py`).
- Tabela u `STANJE-APLIKACIJE.md` §2 delom zaostaje (blokirani, rang „Koje pratim” i Sanduče su urađeni).
