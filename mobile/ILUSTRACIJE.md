# Ilustracije igara (kartice na početnoj)

Ažurirano: 05.11.2026 · v3 (šefovi i šefice Karijere)

Izvor: Freepik (premium nalog vlasnika), vektori bez AI, preuzet pregled 626 px, bela pozadina skinuta.
Isti PNG ide u iOS (`Assets.xcassets/Igra_*`) i Android (`res/drawable-nodpi/igra_*`).

| Igra | Freepik ID |
|---|---|
| Osvajanje sveta | 178641267 |
| PRO kviz | 178636651 |
| Book kviz | 420580618 |
| Duel | 415841684 |
| Slikari | 268506857 |
| Brzi kviz | 195539634 |
| Vešanje | 195539253 |

## Karijera (04.11.2026)

Imena u Assets: `Karijera_*`. Android ih još nema (prvo iOS).

**Zgrade** `Karijera_Zgrada_<nivo>_<varijanta>` (nivo 1 garaža … 5 neboder, 8 varijanti; 5–8 dodate 05.11 skriptom
`ravno3.py`, isti opis stila, uz „orthographic front elevation” gde je ispalo iskosa) i
`Karijera_Korporacija_1/2`: ravan vektorski crtež gledan spreda, po vlasnikovim primerima
(`Downloads/modern-office-building-illustration.png`, `vector-illustration-office-building.png`, `22424.jpg`).
Izometrijski crteži su odbijeni („nemoj 3D”, pogrešan ugao).
Napravljeno Freepik AI-jem (Mystic, `engine: magnific_sharpy`) po vlasnikovom zahtevu, isti opis stila
za sve; bela pozadina i oblaci skinuti skriptom. Opisi su u skripti `ravno2.py` u scratchpadu sesije,
a stil je u ovoj rečenici: „seen straight from the front at eye level, flat vector illustration,
muted teal-blue glass, off-white walls, simple stylized trees, thin ground line, plain white background”.

**Šef** `Karijera_Sef_<lik>_<poza>` (05.11): Freepik AI Mystic `magnific_sharpy`, stripovski stil po vlasnikovom primeru
(`Downloads/cartoon-set-businessmen-men.png`), svaka poza posebna slika uz šefa Korporacije kao referencu stila.
Likovi: korporacija (6 poza), m_mladi, m_srednji, m_stari, z_mlada, z_srednja, z_starija (zadovoljan, ljut, nervozan, smeh).
!! Šefice u odelima sa pantalonama, bez mini suknji i štikli. Prvi pokušaj (listovi sa više poza) odbačen: poza smeha je kod žena ispala kao trudnoća.
**Botovi** `Karijera_Bot_1…6`: Freepik 82900324 (robot chat bot characters).

## Poslovni avatari (04.11.2026)

83 avatara `p1:*`…`p4:*` (`public/avatari/p<list>_<red>_<kolona>.jpg`, 160 px, isti folder za veb i aplikaciju),
isečeni iz četiri vlasnikova kompleta u Downloads („business men women avatars circle set”). Stoje na početku
`public/avatari/spisak.json`, pa su prvi u izboru u „Uredi profil”. Čuvaju se u `profiles.avatar` kao `p1:0:0`.

**Tračevi iz kancelarije** `Karijera_Trac_1…14` (05.11): 1–3 vlasnikove Freepik slike (`Downloads/20311052_office2.jpg`,
`13818716_5359509.jpg`, `178785317_…jpg`), 4–14 Freepik premium vektori preko API-ja (ID: 37472871, 154587294, 41798097, 13146328,
19426888, 417636165, 418005726, 417636167, 418681706, 418005722, 158348510), JPG iz paketa, 1080 px. Preskočene scene sa mini suknjama.

**Grad** (05.11): izometrijski grad je nacrtan u kodu po vlasnikovim primerima (Freepik paketi „isometric city” u `Downloads/`);
paketi su cele ilustracije, ne pojedinačne zgrade, pa se ne koriste kao slike.

